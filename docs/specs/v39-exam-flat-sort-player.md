# V39 Exam Flat-Sort Player — Spec

> **Status**: ✅ frozen on 2026-05-12 (slice shipped — all 10 slices landed across S1–S10; S4 + S5 ship as documented partial scopes with the inline player rewrite deferred to a follow-up polish slice).
>
> **Process-flow amendment (2026-05-12)**: the shipped existing
> `MockExamScreen` must still behave like an exam process: after the intro
> CTA, it opens the first `display_order` question immediately; after a
> successful section submit or skip, it opens the next pending question. The
> section overview is only a fallback when the learner backs out or an error
> interrupts the process.
>
> **Level-gate amendment (2026-05-12)**: `GET /v1/exercises/:id` accepts
> `mock_exam_session_id` for mock-exam playback. A locked course exercise is
> readable only when that session belongs to the learner and includes the
> exercise; this prevents the V21 course gate from bouncing exam sections back
> to the overview while keeping normal course locks intact.
>
> **Linked idea**: [`docs/ideas/exam-flat-sort-player.md`](../ideas/exam-flat-sort-player.md).
>
> **Plan**: [`tasks/v39-exam-flat-sort-player-plan.md`](../../tasks/v39-exam-flat-sort-player-plan.md).
>
> **Todo**: [`tasks/v39-exam-flat-sort-player-todo.md`](../../tasks/v39-exam-flat-sort-player-todo.md).

---

## 1. Slice Goal

Replace today's strict-linear MockExam player with a flat-sort, skip-and-revisit player:

- Tap "Bắt đầu thi" on the intro screen → first question of a flat,
  cross-skill list sorted by `max_points` ascending. There is no in-exam
  section-list stop between the CTA and question 1.
- Submitting a question auto-advances; "Bỏ qua" marks the section
  `status='skipped'` and also advances.
- A top-right button opens a fullscreen Answer Sheet (3 states: done /
  skipped / empty). Tap a cell to jump back; re-answering overwrites.
- Single global timer 90 min, server-authoritative; expiry auto-submits.
- Speaking re-record from the sheet overwrites the prior attempt's
  audio in place (same `attempt_id`, S3 object replaced).

End-to-end across backend (Go), Flutter (learner app), and docs. No CMS work.

---

## 2. Decisions (frozen)

| # | Decision | Resolution |
|---|---|---|
| D1 | Section ordering | Cross-skill flat sort by `mock_test_sections.max_points` ASC. Stable across reads via persisted `mock_exam_sections.display_order` (server-computed at `POST /v1/mock-exams`). Ties break by original `sequence_no`. |
| D2 | Answer Sheet states | 3 states — `done` / `skipped` / `empty`, plus a transient `current` highlight. Each state pairs color **and** icon (✓ / ⊘ / ○) so the UI never relies on color alone. |
| D3 | Answer Sheet presentation | Fullscreen modal route (`Navigator.push(..., fullscreenDialog: true)`). Not a bottom-sheet — bottom-sheet height fights the nested scroll grid. |
| D4 | Skip semantic | `POST /v1/mock-exams/:id/skip {section_id}` sets `mock_exam_sections.status='skipped'`, leaves `attempt_id=''`, advances to next display-order section. Skipped sections remain revisitable from the sheet. |
| D5 | Re-record on revisit (speaking) | **Logical overwrite**: a new attempt is created and linked via `target_display_order` on `/advance`; the section's `attempt_id` swaps to the new one. The previous attempt + audio become inert (no longer referenced by the session) but are not physically deleted from storage. User experience matches "the newest recording wins"; no audit trail of overwritten audio. Confirm dialog required before launching the recorder. Amendment 2026-05-12 (S8): the original spec said "same attempt_id, same S3 key" — implementation uses logical overwrite because `ExerciseScreen` always creates a fresh attempt. Same-key byte-replace would require lifting attempt state up; deferred. |
| D6 | Timer authority | Server-authoritative: `mock_exam_sessions.started_at + duration_sec`. Client polls every 30s and on app resume; server triggers auto-submit at expiry. Duration default 5400 (90 min). |
| D7 | Background behaviour | Timer does **not** pause when the app is backgrounded — mirrors the paper exam. Intro screen warns the learner. |
| D8 | Per-skill timer | Dropped. Incompatible with cross-skill flat sort. One global 90-min timer applies to the whole session. |
| D9 | Intro screen | Tap "Làm bài" → intro screen showing question count + 90 min + no-pause warning + "Bắt đầu thi" CTA. Server timer only starts on that CTA (POST creates the session), then the runner immediately opens the first pending section by `display_order`. |
| D10 | Submit-button enablement | MCQ: any choice selected. Speaking: recording upload completed. Dictation: at least 1 character. Disabled with helper text otherwise. |
| D11 | Auto-advance | After successful section submit, transition to the next pending section by `display_order`; wrap to the first pending section when revisiting a later item. If no pending section remains, proceed to bulk analysis / final submit. Back/cancel returns to the fallback overview instead of re-opening the same section. The future inline player may add the planned 400 ms scale-feedback (1.0 → 1.05 → 1.0) on the ✓ icon; reduce-motion drops to 150 ms fade. |
| D12 | Listening replay budget on revisit | Keep the existing 2-replay default; revisits do not refresh the budget. Anti-cheat behaviour is part of the listening contract, not the player slice. |
| D13 | "Nộp bài ngay" guard | Confirm dialog with the unanswered count when at least 1 section is still `empty`. Skip the dialog when all 24 sections are `done` or `skipped`. |
| D14 | Status enum extension | `mock_exam_sections.status` gains `'skipped'`. No existing rows touched by the migration. |
| D15 | Backward compat for old clients | Old Flutter builds keep working: they never call `/skip`, never read `display_order` (sort by `sequence_no` still resolves to the same wire order for new sessions), and see no `skipped` rows because they never produce them. |

---

## 3. Contracts

### 3.1 Wire (Go)

`contracts.MockExamSection` gains:

```go
type MockExamSection struct {
    // ...existing fields...
    Status       string `json:"status"`        // pending | completed | skipped (new)
    DisplayOrder int    `json:"display_order"` // 1..N — flat sort by max_points ASC
}
```

`contracts.MockExamSession` gains:

```go
type MockExamSession struct {
    // ...existing fields...
    StartedAt   time.Time `json:"started_at"`   // server-anchored, RFC3339
    DurationSec int       `json:"duration_sec"` // 5400 default
    ExpiresAt   time.Time `json:"expires_at"`   // derived = started_at + duration_sec; included for client convenience
}
```

### 3.2 HTTP

**`POST /v1/mock-exams`** (existing, response extended)

Request unchanged.

Response now includes `started_at`, `duration_sec`, `expires_at` on the session, and `display_order` on each section. Sections in the array are sorted by `display_order ASC`.

**`POST /v1/mock-exams/:session_id/skip`** (new, learner role)

Request:
```json
{ "section_id": "<sequence_no-as-uuid-or-int>" }
```

Identifies the section to skip. Implementation uses `(session_id, display_order)` lookup.

Responses:
- 200 OK → updated session (same shape as GET)
- 404 not_found → session or section missing
- 409 conflict → session already `completed`, or section already `completed`/`skipped`
- 400 validation_error → missing `section_id`

**`POST /v1/mock-exams/:session_id/advance`** (existing, semantics tightened)

Request unchanged in shape; new optional field:
```json
{ "attempt_id": "...", "target_display_order": 5 }
```

When `target_display_order` is omitted, behaviour is unchanged (advance the next `pending` by display_order). When set, the server validates that the attempt belongs to the section at that order, updates that section, and does **not** advance the pointer — the client decides what to load next from the response.

**`POST /v1/mock-exams/:session_id/complete`** (existing)

Now callable by the server itself when the timer expires. The current authenticated-only requirement is preserved by issuing a server-internal call from the timer expiry path; the wire shape does not change.

**Timer drift**

A new query parameter `?include_server_time=true` on `GET /v1/mock-exams/:session_id` adds `meta.server_time` (RFC3339) so the client can compute drift on resume without an extra endpoint.

**Exercise detail during mock exam**

`GET /v1/exercises/:exercise_id?mock_exam_session_id=<session_id>` allows
the runner to fetch a section exercise even when the underlying course is
not unlocked yet, but only if the authenticated learner owns that session
and the session contains the exercise.

### 3.3 Flutter

New files under `flutter_app/lib/features/mock_exam/`:

- `controllers/exam_session_controller.dart` — owns timer, current section pointer, sheet open/close, dispatch.
- `widgets/exam_app_bar.dart` — timer (tabular figures), "N/24 · Mđ" progress, sheet button, ⋮ "Nộp bài ngay".
- `widgets/exam_action_bar.dart` — sticky bottom: "Bỏ qua" + "Nộp câu" with disable rules per skill kind.
- `widgets/question_status_chip.dart` — 64×64 pt cell with 3-state visuals.
- `screens/answer_sheet_screen.dart` — fullscreen modal grid, "Nộp bài ngay (M/24)" CTA at bottom.
- `screens/mock_exam_player_screen.dart` — rewritten from the existing 942-line `mock_exam_screen.dart`.
- `models/exam_section_state.dart` — `enum SectionState { done, skipped, empty, current }` + helpers.

Modified:

- `core/api/api_client.dart` — `skipMockExamSection`, `advanceMockExam(sessionId, attemptId, {int? targetDisplayOrder})`, `getMockExam(sessionId, {bool includeServerTime})`.
- `features/mock_exam/screens/mock_test_intro_screen.dart` — adds no-pause warning + question count.
- `features/mock_exam/screens/mock_exam_screen.dart` — until the inline player
  rewrite replaces it, the legacy runner owns process-mode: auto-open the first
  pending section after intro, auto-open the next pending section after submit
  or skip, and keep the section overview only as a fallback navigation surface.

The legacy `mock_exam_screen.dart` is deleted in Phase B (the new `mock_exam_player_screen.dart` replaces it).

### 3.4 Backend

Storage layer (`backend/internal/store/postgres_mock_exams.go`):

- Migration 030 — `ALTER TABLE mock_exam_sections ADD COLUMN IF NOT EXISTS display_order INT NOT NULL DEFAULT 0` plus a backfill `UPDATE mock_exam_sections SET display_order = sequence_no WHERE display_order = 0`.
- Migration 031 — extend the implicit `status` check constraint to include `'skipped'` (Postgres TEXT column has no constraint today; add explicit one for safety).
- Session creation: after inserting sections by `sequence_no`, run a second pass that sorts by `max_points ASC, sequence_no ASC` and writes `display_order = idx+1`.
- New methods: `SkipMockExamSection(sessionID, displayOrder int) error`, `AdvanceMockExamSectionAt(sessionID string, attemptID string, displayOrder int) error`.

Timer expiry path (`backend/internal/processing/`):

- New `mock_exam_timer.go` — a single goroutine, started at boot, scans `mock_exam_sessions WHERE status='in_progress' AND now() > started_at + duration_sec * interval '1 second'` every 60 s and triggers `CompleteMockExam` for each. No queue, no cron — fits the V1 infrastructure baseline.

### 3.5 CMS

No CMS work in this slice.

---

## 4. Test Plan (to implement)

- **Backend** (`mock_exam_skip_test.go` + extensions to `mock_exam_store_test.go`):
  - happy-path skip
  - 404 missing session / section
  - 409 session already completed
  - 409 section already completed or already skipped
  - `display_order` stable across two reads
  - `display_order` matches `max_points ASC` after creation
  - timer-expiry path completes the session and computes overall_score
  - advance with `target_display_order` updates the right section
- **Flutter** (`mock_exam_player_test.dart`, `answer_sheet_test.dart`):
  - existing runner opens the first question immediately after intro
  - successful section submit opens the next pending question
  - sheet renders 3 states with correct icon + color
  - tapping a sheet cell calls the controller's `jumpTo(displayOrder)`
  - "Nộp câu" disabled on empty MCQ / mid-upload speaking / empty dictation
  - timer text turns red and ticks haptic at the 5-minute boundary
  - auto-advance triggers within 500 ms of submit success
  - reduce-motion path uses 150 ms fade, not scale
  - "Nộp bài ngay (M/24)" confirm dialog appears when M < 24
- **Integration** (`mock_exam_flat_sort_integration_test.go`):
  - full happy path — create → answer all 24 cross-skill → complete
  - skip 3 questions → revisit → re-answer → complete
  - speaking re-record from sheet replaces audio (S3 object key reuse)
  - timer expiry path auto-submits with whatever was answered

Target deltas: backend +12 tests, Flutter +15 widget tests.

---

## 5. Rollout

- Migrations 030 + 031 land via `addColumnIfMissing` / `CREATE OR ALTER` style helpers on startup — no downtime.
- The skip endpoint is feature-flagged off the client side, not the server: old clients never call it, so the server can ship first.
- Server timer goroutine starts unconditionally; pre-V39 sessions have `duration_sec=0`, so the `WHERE` clause skips them.
- Operator runs `make smoke-exam-flow` after deploy.

---

## 6. References

- [docs/ideas/exam-flat-sort-player.md](../ideas/exam-flat-sort-player.md) — pre-spec idea.
- [docs/reference/api-contracts.md](../reference/api-contracts.md) §§ "Mock Exam Endpoints" — fold-in target after ship.
- [docs/reference/attempt-state-machine.md](../reference/attempt-state-machine.md) — keep aligned for the speaking re-record path.
- `backend/internal/store/postgres_mock_exams.go` — session + section persistence.
- `backend/internal/httpapi/server.go` — route registration.
- `flutter_app/lib/features/mock_exam/screens/mock_exam_screen.dart` — file being replaced.
