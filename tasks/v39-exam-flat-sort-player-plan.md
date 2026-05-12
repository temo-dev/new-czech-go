# V39 Exam Flat-Sort Player — Plan

> **Status**: 🟡 planned 2026-05-12.
>
> **Spec**: [`docs/specs/v39-exam-flat-sort-player.md`](../docs/specs/v39-exam-flat-sort-player.md).
>
> **Todo**: [`v39-exam-flat-sort-player-todo.md`](v39-exam-flat-sort-player-todo.md).

---

## Overview

Ten vertical slices, ordered by dependency. Each slice is a shippable
commit — backend + Flutter + tests for one user-perceivable change.
Horizontal phasing (all migrations, then all stores, then all UI) is
explicitly avoided: it produces 4 unshippable commits and one huge
final commit that breaks everything together.

Estimated effort: ~3.5 dev-days end-to-end. S1/S2/S3 are parallelisable.

---

## Dependency Graph

```
S1 display_order ───┐
                    ├──▶ S4 player scaffold ──▶ S5 sticky-bar+skip-UI ──┐
S2 skip endpoint ───┤                                                    │
                    │                          S6 sheet read-only ──┐    │
S3 server timer ────┤                                               │    │
                    └──▶ ─────────────────────────────────────────  │    │
                                                                    ▼    ▼
                                                S7 sheet jump-back + advance-at
                                                                    │
                                                                    ▼
                                                S8 speaking re-record overwrite
                                                                    │
                                                                    ▼
                                S9 intro polish + Nộp-bài-ngay + auto-submit UI
                                                                    │
                                                                    ▼
                                                            S10 docs + ship
```

**Parallelism windows:**
- Window 1 (day 1 AM): S1 ∥ S2 ∥ S3 — independent backend slices.
- Window 2 (day 2): S4 (largest single slice) once S1/S3 done.
- Window 3 (day 3): S6 ∥ S7-prep once S5 lands.

---

## Vertical Slice Principle

Each slice owns one user-visible behaviour, including its tests and
contract-doc deltas. A slice is **not** "one layer of the stack."
Example: `S2 skip endpoint` includes the Go endpoint, the Go test
suite, **and** the Dart `apiClient.skipMockExamSection` wrapper, even
though no UI yet calls it. That keeps the Dart wire surface honest
and prevents the typical "backend ready, client never wired" rot.

---

## Checkpoint Gates

After each window, run **all three** before opening the next:

```
make backend-build && make backend-test
make flutter-analyze && make flutter-test
make cms-lint && make cms-build   # cheap sanity — V39 doesn't touch CMS
```

After **S7**, run `make smoke-exam-flow` manually against the local
stack — that is the last gate before S8 (which touches the speaking
attempt lifecycle).

---

## Slice S1 — Display_order persistence (~0.5 day)

**Commit:** `feat(v39) backend display_order on mock_exam_sections`

**Files:**
- `backend/internal/store/postgres_mock_exams.go`
- `backend/internal/store/postgres_migrate.go` (call site for migration 030)
- `backend/internal/contracts/types.go`
- `backend/internal/store/sprint_mocktest_test.go` (add tests)

**Steps:**
1. `addColumnIfMissing("mock_exam_sections", "display_order", "INT NOT NULL DEFAULT 0")` in `RunMigrations`.
2. After insert in `CreateMockExam`, second pass: sort sections in-memory by `(max_points ASC, sequence_no ASC)` and `UPDATE mock_exam_sections SET display_order = $1 WHERE session_id = $2 AND sequence_no = $3`.
3. Backfill existing rows: `UPDATE mock_exam_sections SET display_order = sequence_no WHERE display_order = 0` (idempotent — guard by `WHERE display_order = 0`).
4. Extend SELECT in `GetMockExam` to include `display_order` and `ORDER BY display_order ASC`.
5. Add `DisplayOrder int` JSON field on `contracts.MockExamSection`.

**Acceptance:**
- A new session with sections of `max_points = [8, 12, 10, 7]` returns sections with `display_order = [3, 4, 2, 1]` (i.e. the 7-point section is `display_order=1`).
- An existing pre-V39 session has `display_order` matching its original `sequence_no` after migration.
- `GET /v1/mock-exams/:id` returns sections sorted by `display_order ASC`.

**Verification:**
```bash
cd backend && go test ./internal/store/... -run 'MockExam.*DisplayOrder' -count=1
make backend-test
```
Manual curl:
```bash
curl -s -H "Authorization: Bearer $LEARNER_TOKEN" -X POST $API/v1/mock-exams | jq '.data.sections[] | {display_order, max_points}'
```

---

## Slice S2 — Skip endpoint + status enum (~0.5 day)

**Commit:** `feat(v39) backend skip endpoint + status='skipped'`

**Files:**
- `backend/internal/store/postgres_mock_exams.go`
- `backend/internal/store/postgres_migrate.go`
- `backend/internal/store/memory.go` (in-memory store parity)
- `backend/internal/httpapi/server.go` (route dispatch + handler)
- `backend/internal/httpapi/mock_exam_skip_test.go` (new)
- `flutter_app/lib/core/api/api_client.dart`

**Steps:**
1. Migration 031 — add explicit CHECK constraint via `DO $$ BEGIN ... EXCEPTION WHEN duplicate_object THEN ... END $$` pattern (Postgres can't `IF NOT EXISTS` on constraints directly). Constraint allows `pending|completed|skipped`.
2. `MockExamStore.SkipSection(ctx, sessionID, displayOrder int) error` — atomic guarded UPDATE: `WHERE session_id=$1 AND display_order=$2 AND status='pending'`. Affected rows = 0 → return `ErrSectionNotSkippable` (caller maps to 409).
3. In-memory store parity for tests that don't hit Postgres.
4. Handler in `handleMockExamByID` dispatch: `case strings.HasSuffix(path, "/skip"): s.handleMockExamSkip(...)`.
5. `handleMockExamSkip` — decode `{section_id}` (string carrying display_order or section UUID — pick one and document; recommend the `display_order` int for cheap lookup), auth gate via existing `withAuth` + ownership check on session.
6. `apiClient.skipMockExamSection(String sessionId, int displayOrder)` — wraps POST.

**Acceptance:**
- POST `/skip` on a pending section returns the updated session with that section's `status='skipped'` and `attempt_id=''`.
- POST `/skip` on a completed section returns 409.
- POST `/skip` on a skipped section returns 409 (idempotent failure, not success — see D4).
- POST `/skip` on a session owned by another learner returns 404 (not 403, to avoid leaking existence).
- POST `/skip` on a completed session returns 409.

**Verification:**
```bash
cd backend && go test ./internal/httpapi/... -run TestMockExamSkip -count=1
make backend-test
cd ../flutter_app && flutter analyze
```

---

## Slice S3 — Server-anchored timer + auto-submit (~0.5 day)

**Commit:** `feat(v39) backend server-anchored exam timer + auto-submit sweeper`

**Files:**
- `backend/internal/store/postgres_mock_exams.go`
- `backend/internal/store/postgres_migrate.go`
- `backend/internal/contracts/types.go`
- `backend/internal/processing/mock_exam_timer.go` (new)
- `backend/cmd/api/main.go`
- `backend/internal/processing/mock_exam_timer_test.go` (new)

**Steps:**
1. Migration 032 — `mock_exam_sessions.started_at TIMESTAMPTZ` (`addColumnIfMissing`, default `now()`; defensive — most rows already have it).
2. Migration 033 — `mock_exam_sessions.duration_sec INT NOT NULL DEFAULT 0`. Default 0 means "no timer" — pre-V39 rows invisible to the sweeper.
3. `CreateMockExam` sets `duration_sec = 5400` (90 min) on new rows.
4. `contracts.MockExamSession.StartedAt`, `DurationSec`, `ExpiresAt` (computed at marshal time).
5. `MockExamStore.ListExpired(ctx, now time.Time) ([]string, error)` — returns session IDs where `status='in_progress' AND duration_sec > 0 AND now > started_at + duration_sec * interval '1 second'`.
6. `processing.StartMockExamTimerSweeper(ctx, store, completer, interval)` — goroutine, default `interval = 60 * time.Second`. Calls `completer.CompleteMockExam(sessionID)` per expired ID; logs each completion.
7. `main.go` boot: `go processing.StartMockExamTimerSweeper(ctx, mockExamStore, processor, 60*time.Second)`.
8. `GET /v1/mock-exams/:id?include_server_time=true` — returns `meta.server_time` (RFC3339).

**Acceptance:**
- New session has `started_at` ≈ now, `duration_sec=5400`, `expires_at = started_at + 90min`.
- Pre-V39 session (existing in fixture data, `duration_sec=0`) is ignored by the sweeper.
- Forcing `started_at` to 91 minutes ago in a test → next sweep tick marks the session `completed`.
- Double-tick is idempotent (`CompleteMockExam` already idempotent on status='in_progress' guard).

**Verification:**
```bash
cd backend && go test ./internal/processing/... -run TestMockExamTimerSweeper -count=1
```

---

## ✅ Checkpoint 1 — after S1 + S2 + S3

All backend foundations land before any Flutter changes. Old Flutter
clients keep working: they don't call `/skip`, don't read `display_order`
(sections still arrive in `sequence_no` order for pre-V39 sessions),
and don't render timer (no client expects it yet).

Run:
```bash
make backend-build && make backend-test
make smoke-exam-flow   # uses existing curl-based smoke; should still pass
```

---

## Slice S4 — Player screen scaffold rewrite (~0.75 day)

**Commit:** `feat(v39) flutter mock-exam player scaffold + app bar + controller`

**Files (new):**
- `flutter_app/lib/features/mock_exam/controllers/exam_session_controller.dart`
- `flutter_app/lib/features/mock_exam/widgets/exam_app_bar.dart`
- `flutter_app/lib/features/mock_exam/widgets/question_status_chip.dart`
- `flutter_app/lib/features/mock_exam/models/exam_section_state.dart`
- `flutter_app/lib/features/mock_exam/screens/mock_exam_player_screen.dart`

**Files (modified/deleted):**
- `flutter_app/lib/features/mock_exam/screens/mock_exam_screen.dart` → **deleted**
- `flutter_app/lib/features/mock_exam/screens/mock_test_intro_screen.dart` → push `MockExamPlayerScreen` instead of `MockExamScreen` (one-line nav change)
- `flutter_app/test/mock_exam_screen_test.dart` → **deleted**, replaced by new tests in S5-S6

**Steps:**
1. `SectionState` enum + `SectionState fromWire(String status, int? displayOrder, int currentDisplayOrder)` mapping.
2. `ExamSessionController extends ChangeNotifier` — owns: `MockExamSession` + current `displayOrder` + timer `Stream<Duration>` derived from `started_at + duration_sec`. Refresh via `apiClient.getMockExam(sessionId, includeServerTime: true)` every 30 s and on app resume.
3. `ExamAppBar` — preferredSize 96, top row: ⏱ tabular-figures timer (red <5 min) + spacer + 🗂 sheet IconButton + ⋮ overflow with "Nộp bài ngay" entry. Bottom row: linear progress (`done+skipped` ÷ N).
4. `QuestionStatusChip` — 64×64 pt cell, accepts `(SectionState, int displayOrder, int? maxPoints)`. Uses `AppColors.successContainer/onSuccess` for done, `surfaceContainer/outline-dashed` for skipped, `surfaceContainerLowest/outlineVariant` for empty, `primary/onPrimary` for current. Each pairs color **with** an icon (✓/⊘/○/•).
5. `MockExamPlayerScreen` — stateful, owns `ExamSessionController`. Body shows the current section via the existing skill-dispatch helpers (re-used from old `mock_exam_screen.dart`). No sheet, no sticky bar yet — those land in S5 + S6.
6. Intro screen swap: change `pushReplacement(MaterialPageRoute(builder: (_) => MockExamScreen(...)))` to `pushReplacement(MaterialPageRoute(builder: (_) => MockExamPlayerScreen(...)))`.

**Acceptance:**
- Launching a mock exam shows the new player; timer counts down from 90:00.
- App backgrounded for 10 seconds → resume → timer reflects elapsed wall-clock (no pause).
- Auto-advance after submit still works (we re-used `_advanceSection` logic, just relocated).
- `flutter test` passes the new `mock_exam_player_test.dart`.
- Old `mock_exam_screen.dart` + test file deleted; nothing imports them.

**Verification:**
```bash
cd flutter_app && flutter analyze
flutter test test/mock_exam_player_test.dart
make flutter-test
```

---

## Slice S5 — Sticky action bar + Skip wiring (~0.5 day)

**Commit:** `feat(v39) flutter sticky skip+submit bar wired to /skip`

**Files (new):**
- `flutter_app/lib/features/mock_exam/widgets/exam_action_bar.dart`
- `flutter_app/test/exam_action_bar_test.dart`

**Files (modified):**
- `mock_exam_player_screen.dart` — mount `ExamActionBar` as `bottomNavigationBar`.
- `exam_session_controller.dart` — add `skip(int displayOrder)` calling `apiClient.skipMockExamSection`.

**Steps:**
1. `ExamActionBar` — pinned bottom, safe-area aware + `MediaQuery.viewInsets.bottom` for keyboard. Layout: "Bỏ qua" outlined (left, flex 1), gap 12, "Nộp câu" filled primary (right, flex 2).
2. Submit enablement per `exercise_type`:
   - `cteni_*` / `poslech_*` MCQ → enabled when at least 1 option selected.
   - `psani_*` → enabled when text non-empty.
   - `psani_3_dictation` → enabled when ≥1 char in any field.
   - `uloha_1..4` speaking → enabled only after recording upload completes (existing `_PendingAnalysis` pattern; surface via controller flag).
   - `interview_*` → managed by `InterviewSessionScreen` already (skip the action bar entirely for interview sections).
3. Skip → confirm only when current question shows partial input (MCQ selected but not submitted, recording mid-take); otherwise jump.
4. Loading spinner inside "Nộp câu" while upload/score request inflight; bar disabled until controller resolves.

**Acceptance:**
- "Bỏ qua" tap → calls `/skip` → controller advances to next display_order → previous chip becomes `skipped` (renders in S6's sheet).
- "Nộp câu" disabled on empty MCQ.
- "Nộp câu" disabled mid-recording-upload; spinner visible.
- Interview section does not show the action bar.

**Verification:**
```bash
cd flutter_app && flutter test test/exam_action_bar_test.dart
make flutter-test
```

---

## Slice S6 — Answer sheet (read-only) (~0.5 day)

**Commit:** `feat(v39) flutter fullscreen answer sheet (read-only)`

**Files (new):**
- `flutter_app/lib/features/mock_exam/screens/answer_sheet_screen.dart`
- `flutter_app/test/answer_sheet_screen_test.dart`

**Files (modified):**
- `exam_app_bar.dart` — `onSheetTap` callback pushes the sheet route.

**Steps:**
1. `AnswerSheetScreen` — stateless, takes `ExamSessionController`. `Navigator.push(MaterialPageRoute(fullscreenDialog: true))` from the app bar's 🗂 button.
2. Body: `Scrollable` `GridView.count(crossAxisCount: 5)` of `QuestionStatusChip`s, ordered by `display_order ASC`. No tap handler yet (lands in S7).
3. Above the grid: optional skill-section headers (`ČTENÍ`, `PSANÍ`, `POSLECH`, `MLUVENÍ`, `INTERVIEW`) — purely cosmetic grouping inside a flat sort.
4. Below the grid (sticky): `2/24 đã làm · 1 bỏ qua · 21 chưa` summary text.
5. Sheet open animation: 200 ms scale 0.95 → 1.0 + fade. Drop to 150 ms fade only when `MediaQuery.disableAnimations`.

**Acceptance:**
- Sheet opens via top-right button.
- 3 states + current render correctly (visual diff test in test file).
- Summary string updates as the controller's state changes.
- Reduce-motion path uses fade, not scale.

**Verification:**
```bash
cd flutter_app && flutter test test/answer_sheet_screen_test.dart
make flutter-test
```

---

## ✅ Checkpoint 2 — after S4 + S5 + S6

Player + skip + read-only sheet usable end-to-end. The sheet shows
state but doesn't jump yet. Manually pilot the flow on iOS simulator:

```bash
make dev-backend &     # in background; first start may take 30s
make dev-ios            # launches Flutter on simulator
# manual: trigger a mock exam, skip a few, open sheet, observe states
```

---

## Slice S7 — Sheet jump-back + advance-at (~0.5 day)

**Commit:** `feat(v39) backend advance accepts target_display_order; flutter sheet tap jumps`

**Files (backend):**
- `backend/internal/store/postgres_mock_exams.go` — `AdvanceSectionAt`
- `backend/internal/httpapi/server.go` — `handleMockExamAdvance` extension
- `backend/internal/httpapi/mock_exam_advance_at_test.go` (new)

**Files (flutter):**
- `flutter_app/lib/core/api/api_client.dart` — advance overload with `targetDisplayOrder`
- `flutter_app/lib/features/mock_exam/controllers/exam_session_controller.dart` — `jumpTo(int displayOrder)`
- `flutter_app/lib/features/mock_exam/screens/answer_sheet_screen.dart` — `onCellTap`

**Steps:**
1. `AdvanceSectionAt(ctx, sessionID, attemptID, displayOrder)` — UPDATE that section's `attempt_id` + `status='completed'` without bumping the next-pending pointer (the existing `AdvanceMockExamSection` *does* bump, which is wrong for jump-back).
2. Extend `handleMockExamAdvance` body decode: optional `target_display_order *int`. When set, route to `AdvanceSectionAt`; otherwise legacy behaviour.
3. `apiClient.advanceMockExam(sessionId, attemptId, {int? targetDisplayOrder})`.
4. `ExamSessionController.jumpTo(int displayOrder)` — set local current, refresh server snapshot.
5. `AnswerSheetScreen` cell `onTap`: pop sheet → `controller.jumpTo(cell.displayOrder)`.

**Acceptance:**
- Tap a `done` cell in the sheet → player re-loads that section; chip stays `done`; user can submit again to overwrite.
- Tap a `skipped` cell → player loads that section in `empty`-input state; submit transitions chip to `done`.
- Tap an `empty` cell → player loads that section; behaves as first visit.
- Server-side advance-at on a `pending` section flips it to `completed` without auto-advancing pointer; legacy clients still get pointer-bump on no-target advances.

**Verification:**
```bash
cd backend && go test ./internal/httpapi/... -run TestMockExamAdvanceAt -count=1
cd ../flutter_app && flutter test test/answer_sheet_screen_test.dart
```

Manual smoke: jump back to a done section, re-answer, observe state remains consistent.

---

## Slice S8 — Speaking re-record overwrite (~0.5 day)

**Commit:** `feat(v39) flutter speaking re-record from sheet overwrites attempt audio`

**Files (flutter):**
- `flutter_app/lib/features/mock_exam/screens/mock_exam_player_screen.dart` — re-record entry path
- `flutter_app/lib/features/mock_exam/widgets/rerecord_confirm_dialog.dart` (new)
- `flutter_app/test/rerecord_confirm_dialog_test.dart` (new)

**Files (backend, minimal):**
- `backend/internal/httpapi/attempt_upload.go` — verify the existing upload-url + upload-complete handlers support reusing an existing `attempt_id` (re-issue presigned URL for same key). If not, add a guarded `?overwrite=true` query param.

**Steps:**
1. Audit existing speaking upload path. Today `POST /v1/attempts/:id/upload-url` issues a fresh presigned URL; if it always overwrites the S3 key (key derived from `attempt_id`), no backend change needed. Confirm in the audit.
2. `RerecordConfirmDialog` — modal alert "Ghi đè recording cũ?" with destructive "Ghi đè" + safe "Huỷ".
3. Player re-record entry path: when current section is `uloha_1..4` and `attempt_id != ''`, show the dialog before tearing down and re-creating the recorder UI.
4. **Guard**: skip the dialog (and skip the overwrite path entirely) for `interview_*` sections — those have a different lifecycle.

**Acceptance:**
- Jump back to a done speaking section → tap mic → confirm dialog appears.
- Confirm → recorder UI mounts; new recording overwrites the S3 object at the same key on submit.
- Cancel → no state change, recorder stays unmounted.
- Interview section does **not** show the dialog.

**Verification:**
```bash
cd flutter_app && flutter test test/rerecord_confirm_dialog_test.dart
make flutter-test
```

Manual smoke: record, jump back, re-record, complete exam, verify backend has the second audio (S3 timestamp newer).

---

## Slice S9 — Intro polish + Nộp bài ngay UI + auto-submit (~0.5 day)

**Commit:** `feat(v39) flutter intro warning + Nộp-bài-ngay confirm + timer-expiry UI`

**Files:**
- `flutter_app/lib/features/mock_exam/screens/mock_test_intro_screen.dart`
- `flutter_app/lib/features/mock_exam/screens/answer_sheet_screen.dart` (bottom CTA)
- `flutter_app/lib/features/mock_exam/widgets/exam_app_bar.dart` (⋮ menu)
- `flutter_app/lib/features/mock_exam/controllers/exam_session_controller.dart` (auto-submit)

**Steps:**
1. Intro screen: add a `_WarningBanner` widget with "⚠ Timer KHÔNG dừng khi rời app" using `AppColors.warningContainer` (if missing, add a token via `app_colors.dart` — minor token addition allowed). Show total questions + 90 min stat boxes.
2. Sheet bottom CTA: "Nộp bài ngay (M/24)" filled with `AppColors.error` background. Confirm dialog appears when M < 24 — "Còn X câu chưa làm. Vẫn nộp?".
3. App bar ⋮ entry: "Nộp bài ngay" — same flow as the sheet CTA.
4. Controller `autoSubmit()` — invoked by the timer stream when remaining = 0. Calls `apiClient.completeMockExam` and navigates to result screen. Server-side sweeper (S3) is the real backstop; this is a client-side UX hint so the result screen appears immediately.
5. Result navigation: keep the existing `_MockExamResultView` (or extract it to a separate file as a small follow-up — defer, not in scope).

**Acceptance:**
- Intro shows the warning banner; primary CTA "Bắt đầu" still works.
- "Nộp bài ngay" from sheet with 5/24 done → confirm dialog appears with the count.
- "Nộp bài ngay" with 24/24 done → no dialog, direct complete.
- Timer expiry → auto-navigate to result; no toast / no dialog.

**Verification:**
```bash
cd flutter_app && flutter test test/mock_test_intro_screen_test.dart test/answer_sheet_screen_test.dart
make flutter-test
```

---

## ✅ Checkpoint 3 — after S7 + S8 + S9

End-to-end flow is feature-complete. Run the full local smoke:

```bash
make verify
make smoke-exam-flow
```

If smoke fails, the failure points at a slice — re-run that slice's test
in isolation and patch within the slice before opening S10.

---

## Slice S10 — Docs + reference fold + ship (~0.25 day)

**Commit:** `docs(v39) CHANGELOG + SPEC digest + api-contracts fold + status flip`

**Files:**
- `CHANGELOG.md` — V39 entry at top
- `SPEC.md` — confirm row added in spec-writing pass; date may need bumping if ship day differs
- `docs/reference/api-contracts.md` — `/skip` endpoint, `target_display_order` on `/advance`, `started_at`/`duration_sec`/`expires_at` on session
- `docs/reference/attempt-state-machine.md` — speaking re-record-in-place note
- `docs/ideas/exam-flat-sort-player.md` — status flip → promoted
- `docs/specs/v39-exam-flat-sort-player.md` — status flip → frozen
- `tasks/plan.md` — status flip to `✅ shipped`
- `tasks/todo.md` — fold S10 acceptance
- `docs/specs/README.md` — verify index includes V39 (already updated in spec pass)

**Steps:**
1. CHANGELOG entry follows the V37 template — files changed + final test counts.
2. Fold reference contracts. Don't backfill the slice spec.
3. Status flips.

**Acceptance:**
- `make verify` green.
- All status flips applied.
- CHANGELOG entry mirrors final test counts (backend + Flutter + CMS).

**Verification:**
```bash
make verify
git diff --stat
```

---

## Risks Revisited

- **Big-bang of the 942-line file (S4) breaks every mock-exam test.** Mitigation: delete old tests with the old file; add fresh tests aligned with the new widget tree in S4 + S5 + S6. Don't try to keep both alive.
- **Server timer race vs manual submit.** Mitigation: `MarkSessionCompleted` is already idempotent on `status='in_progress'`. Both paths converge harmlessly.
- **S8 backend audit may surface "overwrite-by-default not safe."** Mitigation: if S3 object semantics already overwrite, no change needed. If not, add an explicit `?overwrite=true` and document. If neither is acceptable, escalate to a separate slice — do **not** block V39 ship on it; remove S8 from MVP and ship S1..S7 + S9.
- **Per-skill audio replay on revisit (D12).** Out of scope by decision; if pilot data shows it matters, file a follow-up.
- **`display_order` desync when an admin edits a MockTest template after sessions exist.** Mitigation: snapshot-at-create (already true) — document this in `docs/reference/api-contracts.md` so the support team can reproduce.
