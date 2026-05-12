# V39 Exam Flat-Sort Player — Todo

> **Status**: 🟡 planned 2026-05-12.
>
> **Plan**: [`v39-exam-flat-sort-player-plan.md`](v39-exam-flat-sort-player-plan.md) — dependency graph + slice acceptance.
>
> Each slice is one commit. Run the slice's verification command before
> ticking its final box. Do not start the next slice until the current
> one is green.

---

## Window 1 — Backend foundations (S1 ∥ S2 ∥ S3)

### S1 — Display_order persistence  ✅ landed 2026-05-12
- [x] **S1.1** Schema — `ADD COLUMN IF NOT EXISTS display_order INT NOT NULL DEFAULT 0` (inline in `ensureSchema`)
- [x] **S1.2** Backfill — `UPDATE mock_exam_sections SET display_order = sequence_no WHERE display_order = 0` (idempotent guard)
- [x] **S1.3** `assignDisplayOrder` helper — `(max_points ASC, sequence_no ASC)` sort + DisplayOrder=rank+1; called by memory + postgres `CreateMockExam`
- [x] **S1.4** Postgres `MockExamByID` — SELECT includes `display_order`, `ORDER BY display_order ASC`
- [x] **S1.5** `contracts.MockExamSessionItem.DisplayOrder int` + JSON tag `display_order,omitempty`
- [x] **S1.6** 3 new tests in `sprint_mocktest_test.go` — `DisplayOrderSortsByMaxPointsAsc`, `DisplayOrderTiesBreakBySequenceNoAsc`, `DisplayOrderStableAcrossReads`
- [x] **S1.7** `go test ./...` 888 green (was 887 → +3 new, -2 fixed regressions: `TestCompleteMockExamDoesNotAddPronunciationBonusToMixedSprint` advance order, `TestCreateMockExamDecodesChunkedMockTestID` wantTypes)
- [x] **S1.8** `make backend-build` green

### S2 — Skip endpoint + status='skipped'  ✅ landed 2026-05-12
- [x] **S2.1** Status enum extended at storage layer — Postgres `status` TEXT accepts `'skipped'` (no CHECK constraint today; new value treated as data, not schema). Defer explicit CHECK to a hardening pass.
- [x] **S2.2** `MockExamStore.SkipSection(sessionID string, displayOrder int) (Session, error)` — interface + sentinel errors `ErrSectionNotFound`, `ErrSectionNotSkippable`
- [x] **S2.3** Memory store parity — guard pending status, mutate to skipped
- [x] **S2.4** Postgres `SkipSection` — atomic guarded UPDATE + 404/409 disambiguation via second SELECT
- [x] **S2.5** Route dispatch in `handleMockExamByID` — `/skip` suffix added
- [x] **S2.6** `handleMockExamSkip` — body decode, ownership 403, sentinel→status mapping
- [x] **S2.7** `apiClient.skipMockExamSection(String sessionId, {required int displayOrder})` in Dart
- [x] **S2.8** Tests `mock_exam_skip_test.go` — 8 cases: happy / missing field 400 / zero-value 400 / session 404 / out-of-range 404 / already-completed 409 / already-skipped 409 / different-learner 403
- [x] **S2.9** `go test ./...` 896 green (was 888 → +8 new S2)
- [x] **S2.10** `flutter analyze` clean (11 pre-existing infos unrelated)
- [x] **S2.11** `flutter test` 397 green (no regression)

### S3 — Server-anchored timer + auto-submit  ✅ landed 2026-05-12
- [x] **S3.1** Re-use `mock_exam_sessions.created_at` as the timer anchor (saves 1 migration); `StartedAt` JSON field maps from `created_at` on read
- [x] **S3.2** Migration — `ADD COLUMN IF NOT EXISTS duration_sec INT NOT NULL DEFAULT 0` inline in `ensureSchema`
- [x] **S3.3** `CreateMockExam` writes `duration_sec = DefaultMockExamDurationSec` (5400)
- [x] **S3.4** `contracts.MockExamSession.StartedAt / DurationSec / ExpiresAt` + `time` import
- [x] **S3.5** `MockExamStore.ListExpired(now time.Time)` + `ExpireMockExam(sessionID)`; memory + postgres impls; new sentinel reuse
- [x] **S3.6** `processing/mock_exam_timer.go` — `StartMockExamTimerSweeper` goroutine + `runMockExamTimerSweep` testable helper
- [x] **S3.7** `cmd/api/main.go` wiring — sweep starts after handler ready, polls every 60 s with immediate first-tick
- [x] **S3.8** `GET /v1/mock-exams/:id?include_server_time=true` — adds `meta.server_time` (RFC3339Nano)
- [x] **S3.9** Tests: 6 store-side (timer fields, ListExpired returns/ignores, ExpireMockExam flip+idempotent+not-found) + 3 sweeper + 2 server_time = 11
- [x] **S3.10** `go test ./...` 907 green (was 896 → +11)
- [x] **S3.11** `make backend-build` green

### ✅ Checkpoint 1  — landed 2026-05-12
- [x] `make backend-build && make backend-test` — 907 green
- [ ] `make smoke-exam-flow` (deferred to Checkpoint 2 — needs Flutter scaffold)

---

## Window 2 — Flutter player scaffold (S4)

### S4 — Player screen scaffold rewrite  🟢 partial (foundation landed 2026-05-12)
- [x] **S4.1** `models/exam_section_state.dart` — `SectionState` enum (done / skipped / current / empty) + `sectionStateFor` mapper
- [x] **S4.2** `controllers/exam_session_controller.dart` — pointer + 1-s ticker + `skipCurrent`/`advanceAfterAttempt`/`jumpTo`/`refresh` + injectable clock for tests
- [ ] **S4.3** 30 s polling + on-resume `WidgetsBindingObserver` (deferred — added when intro swaps to new player in S5/S6)
- [x] **S4.4** `widgets/exam_app_bar.dart` — timer tabular figures, error color <5 min, progress bar, sheet btn, ⋮ Nộp bài ngay
- [x] **S4.5** `widgets/question_status_chip.dart` — 64 pt cell, 4 states icon-paired (color-not-only)
- [ ] **S4.6** `screens/mock_exam_player_screen.dart` — **deferred to S5/S6** so the player ships with feature parity (skip UI + sheet)
- [x] **S4.7** Existing `mock_exam_skill_dispatch.dart` re-used unchanged — controller delegates body to current per-type screens
- [ ] **S4.8** `mock_test_intro_screen.dart` swap — deferred (depends on S4.6)
- [ ] **S4.9** Delete `screens/mock_exam_screen.dart` — deferred until S5/S6 reach parity
- [ ] **S4.10** Delete `test/mock_exam_screen_test.dart` — deferred
- [x] **S4.11** Dart model V39 updates — `MockExamSection.displayOrder`/`isSkipped`, `MockExamSessionView.startedAt`/`durationSec`/`expiresAt` + `hasTimer`/`remainingAt(now)` helpers; `MockExamSection.fromJson` falls back `displayOrder=sequenceNo` for pre-V39 sessions
- [x] **S4.12** 19 new tests (5 section state + 5 controller + 5 chip + 4 app bar); `flutter analyze` clean; `flutter test` 416 green (was 397 → +19)

**Scope cut note**: S4 plan called for the full 942-line `mock_exam_screen.dart` rewrite + delete + intro swap in one slice. Doing that in isolation produces a regressed player (no skip UI, no sheet) and breaks production flow until S5/S6 catch up. Instead, S4 ships the foundation modules (model, controller, app bar, chip) with full test coverage; S5/S6 absorb the screen rewrite + intro swap + delete once skip + sheet land. Old `mock_exam_screen.dart` stays live in the meantime. No new slice added — net work moves into S5/S6.

---

## Window 3 — Skip UX + read-only sheet (S5 + S6)

### S5 — Sticky action bar + Skip wiring  🟢 partial (Skip UI landed 2026-05-12)
- [x] **S5.1** Backend `CompleteMockExam` tolerates `'skipped'` sections — they score 0 and don't block Complete. Memory + Postgres impls updated; new test `TestCompleteMockExamScoresOnlyCompletedSkippedDoNotBlock` pins it.
- [x] **S5.2** Per-tile Skip UI in `mock_exam_screen.dart::_SectionTile` — `TextButton('Bỏ qua')` for pending sections, hidden for completed/skipped
- [x] **S5.3** `_skipSection` wired to `apiClient.skipMockExamSection(displayOrder)` + updates `_session` state
- [x] **S5.4** Skipped sections render with neutral `Đã bỏ qua` pill + `surfaceContainer` background; main button disabled (no re-enter until S7 jump-back lands)
- [ ] **S5.5** `widgets/exam_action_bar.dart` (sticky bottom Skip+Submit bar with safe-area+keyboard inset) — deferred to S6/S7 when the new player screen is wired (S6 sheet introduces a sticky-bottom context that pairs naturally with the action bar)
- [ ] **S5.6** Submit enablement matrix per skill_kind (MCQ / writing / dictation / speaking / interview) — deferred (lives in per-type screens today; lifts into action bar when the inline player ships)
- [x] **S5.7** Tests: 2 new widget tests in `mock_exam_screen_test.dart` (Bỏ qua appears for pending only; hides on skipped/completed) + 1 new store test
- [x] **S5.8** `go test ./...` 908 green (was 907 → +1); `flutter test` 418 green (was 416 → +2)

**Scope cut note**: full sticky action bar replaces today's per-type submit buttons via lifted state. That refactor is larger than 1 slice. S5 ships the V39 Skip UI users can hit immediately (per-tile button) + backend support for Skip-then-Complete. Inline player + action bar land in S6/S7 alongside the answer sheet.

### S6 — Answer sheet (read-only)  ✅ landed 2026-05-12
- [x] **S6.1** `screens/answer_sheet_screen.dart` — fullscreen route, `Wrap` grid of `QuestionStatusChip` per skill section
- [x] **S6.2** Cosmetic skill-section headers — uppercase localized skill labels (ĐỌC / VIẾT / NGHE / NÓI / HỘI THOẠI AI), grouped from `sectionSkillKind`
- [x] **S6.3** Summary footer — "N/total đã làm · K bỏ qua · X chưa" in `surfaceContainerLow`
- [ ] **S6.4** Open animation — default Material fullscreenDialog transition (system handles reduce-motion). Custom 200 ms scale+fade deferred — system default is acceptable + respects accessibility.
- [x] **S6.5** Sheet entry on `MockExamScreen`'s AppBar — top-right `grid_view_rounded` icon pushes `AnswerSheetScreen` via `MaterialPageRoute(fullscreenDialog: true)`. Disabled while session loading.
- [x] **S6.6** Legend strip (✓ Đã làm / ⊘ Bỏ qua / ○ Chưa làm) right under the AppBar
- [x] **S6.7** `test/answer_sheet_screen_test.dart` — 4 tests: chip-per-section, summary footer counts, skill headers when sections exist, legend renders 3 states
- [x] **S6.8** `test/mock_exam_screen_test.dart` — AppBar grid icon pushes sheet + sheet content visible
- [x] **S6.9** `flutter test` 423 green (was 418 → +5)
- [x] **S6.10** `flutter analyze` clean (no new issues)

**Tap-to-jump (S7) follow-up**: chip's `onTap` left null in S6. S7 will pop with `displayOrder` so the player jumps back.

### ✅ Checkpoint 2
- [ ] `make verify` green
- [ ] Manual iOS simulator: trigger exam, skip 2, open sheet, see states correct

---

## Window 4 — Sheet jump + speaking re-record + final polish (S7 + S8 + S9)

### S7 — Sheet jump-back + advance-at
- [ ] **S7.1** `MockExamStore.AdvanceSectionAt(ctx, sessionID, attemptID, displayOrder)` — no pointer bump
- [ ] **S7.2** Memory-store parity for `AdvanceSectionAt`
- [ ] **S7.3** Extend `handleMockExamAdvance` — decode optional `target_display_order *int`
- [ ] **S7.4** `apiClient.advanceMockExam(..., {int? targetDisplayOrder})` overload
- [ ] **S7.5** `ExamSessionController.jumpTo(int displayOrder)` — local set + server refresh
- [ ] **S7.6** `AnswerSheetScreen.onCellTap` → pop sheet → `controller.jumpTo(...)`
- [ ] **S7.7** Tests `mock_exam_advance_at_test.go` — happy + target-pending + target-completed-overwrite
- [ ] **S7.8** `answer_sheet_screen_test.dart` extended — tap flow
- [ ] **S7.9** `make backend-test && flutter test` green

### S8 — Speaking re-record overwrite
- [ ] **S8.1** Audit `attempt_upload.go` — does upload-url + S3 key naturally overwrite? Document finding.
- [ ] **S8.2** If audit fails, scope an `?overwrite=true` flag here (else skip this sub-task)
- [ ] **S8.3** `widgets/rerecord_confirm_dialog.dart` — destructive confirm
- [ ] **S8.4** Player re-record entry — dialog gate for `uloha_1..4` only (interview skipped)
- [ ] **S8.5** `test/rerecord_confirm_dialog_test.dart` — show + confirm + cancel + interview-skipped
- [ ] **S8.6** Manual smoke — record, jump back, re-record, verify S3 object newer

### S9 — Intro polish + Nộp-bài-ngay + auto-submit UI
- [ ] **S9.1** Intro warning banner — "Timer KHÔNG dừng khi rời app"
- [ ] **S9.2** Intro stat boxes — câu count + 90 phút + điểm tổng
- [ ] **S9.3** Sheet bottom CTA "Nộp bài ngay (M/24)" with destructive color
- [ ] **S9.4** Confirm dialog when M < 24
- [ ] **S9.5** App-bar ⋮ "Nộp bài ngay" entry (same flow)
- [ ] **S9.6** Controller `autoSubmit()` — invoked when timer remaining = 0
- [ ] **S9.7** Navigate to result screen on auto-submit
- [ ] **S9.8** `test/mock_test_intro_screen_test.dart` updates — banner present
- [ ] **S9.9** `test/answer_sheet_screen_test.dart` — Nộp-bài-ngay confirm path
- [ ] **S9.10** `flutter test` green

### ✅ Checkpoint 3
- [ ] `make verify` green
- [ ] `make smoke-exam-flow` green
- [ ] Manual iOS sim — full happy + skip-and-revisit + timer-expiry flows

---

## Window 5 — Docs + ship (S10)

### S10 — Docs + reference fold + ship
- [ ] **S10.1** `CHANGELOG.md` V39 entry — files + final test counts
- [ ] **S10.2** Re-verify `SPEC.md` V39 row (already added at spec time; bump date if ship-day differs)
- [ ] **S10.3** `docs/reference/api-contracts.md` — `/skip` + advance-at + session timer fields
- [ ] **S10.4** `docs/reference/attempt-state-machine.md` — speaking re-record overwrite note
- [ ] **S10.5** `docs/ideas/exam-flat-sort-player.md` status → promoted
- [ ] **S10.6** `docs/specs/v39-exam-flat-sort-player.md` status → frozen
- [ ] **S10.7** `tasks/plan.md` row → ✅ shipped
- [ ] **S10.8** `tasks/todo.md` index — note V39 shipped
- [ ] **S10.9** `make verify` green
- [ ] **S10.10** Final commit `docs(v39) CHANGELOG + SPEC digest + reference fold`

---

## Out of scope (defer to follow-up if pilot demands)

- [ ] Skill-wise CEFR exam variants (B1 promotion exam uses the same player; verify no regression but don't add B1-specific UX in V39)
- [ ] Replay budget restriction on revisit (D12 — keep current 2-replay default)
- [ ] Audit trail for overwritten speaking recordings
- [ ] Per-skill timer
- [ ] Multi-device exam resume
- [ ] Pause-when-backgrounded
