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

### S1 — Display_order persistence
- [ ] **S1.1** Migration 030 — `addColumnIfMissing("mock_exam_sections", "display_order", "INT NOT NULL DEFAULT 0")`
- [ ] **S1.2** Backfill — `UPDATE mock_exam_sections SET display_order = sequence_no WHERE display_order = 0`
- [ ] **S1.3** `CreateMockExam` second pass — sort by `(max_points ASC, sequence_no ASC)`, write `display_order`
- [ ] **S1.4** `GetMockExam` SELECT extended + `ORDER BY display_order ASC`
- [ ] **S1.5** `contracts.MockExamSection.DisplayOrder int` + JSON tag
- [ ] **S1.6** Tests — `MockExamDisplayOrderStable`, `MockExamDisplayOrderMatchesMaxPoints`
- [ ] **S1.7** `go test ./...` green
- [ ] **S1.8** Manual curl smoke — create session, GET, `jq` to verify order

### S2 — Skip endpoint + status='skipped'
- [ ] **S2.1** Migration 031 — `CHECK (status IN ('pending','completed','skipped'))` via DO-block (Postgres)
- [ ] **S2.2** `MockExamStore.SkipSection(ctx, sessionID, displayOrder int)` — atomic guarded UPDATE
- [ ] **S2.3** Memory store parity for `SkipSection`
- [ ] **S2.4** Route dispatch in `handleMockExamByID` — `/skip` suffix
- [ ] **S2.5** `handleMockExamSkip` — decode body, auth + ownership, store call, return updated session
- [ ] **S2.6** `apiClient.skipMockExamSection(String sessionId, int displayOrder)` in Dart
- [ ] **S2.7** Tests `mock_exam_skip_test.go` — happy / 404 / 409×2 / 400 / ownership 404
- [ ] **S2.8** `go test ./...` green
- [ ] **S2.9** `flutter analyze` green

### S3 — Server-anchored timer + auto-submit
- [ ] **S3.1** Migration 032 — `mock_exam_sessions.started_at TIMESTAMPTZ DEFAULT now()` (defensive)
- [ ] **S3.2** Migration 033 — `mock_exam_sessions.duration_sec INT NOT NULL DEFAULT 0`
- [ ] **S3.3** `CreateMockExam` sets `duration_sec = 5400`
- [ ] **S3.4** `contracts.MockExamSession.StartedAt / DurationSec / ExpiresAt`
- [ ] **S3.5** `MockExamStore.ListExpired(ctx, now time.Time) ([]string, error)`
- [ ] **S3.6** `processing/mock_exam_timer.go` — `StartMockExamTimerSweeper(ctx, store, completer, interval)`
- [ ] **S3.7** `cmd/api/main.go` wiring — `go processing.StartMockExamTimerSweeper(...)`
- [ ] **S3.8** `GET /v1/mock-exams/:id?include_server_time=true` — returns `meta.server_time`
- [ ] **S3.9** Tests — expiry completes, pre-V39 ignored, double-tick idempotent
- [ ] **S3.10** `go test ./...` green

### ✅ Checkpoint 1
- [ ] `make backend-build && make backend-test` green
- [ ] `make smoke-exam-flow` still green (legacy path unaffected)

---

## Window 2 — Flutter player scaffold (S4)

### S4 — Player screen scaffold rewrite
- [ ] **S4.1** `models/exam_section_state.dart` — `SectionState` enum + `fromWire`
- [ ] **S4.2** `controllers/exam_session_controller.dart` — pointer + timer stream + server refresh
- [ ] **S4.3** Controller: 30 s polling + on-resume refresh via `WidgetsBindingObserver`
- [ ] **S4.4** `widgets/exam_app_bar.dart` — timer tabular figures + progress + sheet btn + ⋮
- [ ] **S4.5** `widgets/question_status_chip.dart` — 64 pt cell, 3 + current states, icon-paired
- [ ] **S4.6** `screens/mock_exam_player_screen.dart` — orchestrates controller + body
- [ ] **S4.7** Re-use existing skill-dispatch (`getExercise` → per-type screens)
- [ ] **S4.8** `mock_test_intro_screen.dart` — swap to `MockExamPlayerScreen` in `pushReplacement`
- [ ] **S4.9** Delete `screens/mock_exam_screen.dart`
- [ ] **S4.10** Delete `test/mock_exam_screen_test.dart`
- [ ] **S4.11** New `test/mock_exam_player_test.dart` — boot, timer ticks, app-bar renders
- [ ] **S4.12** `flutter analyze && flutter test` green

---

## Window 3 — Skip UX + read-only sheet (S5 + S6)

### S5 — Sticky action bar + Skip wiring
- [ ] **S5.1** `widgets/exam_action_bar.dart` — sticky bottom, safe-area + keyboard inset
- [ ] **S5.2** Submit enablement matrix — MCQ / writing / dictation / speaking / interview
- [ ] **S5.3** "Bỏ qua" → `controller.skip(displayOrder)` → `apiClient.skipMockExamSection`
- [ ] **S5.4** Loading spinner inside "Nộp câu" while async pending
- [ ] **S5.5** Hide action bar for `interview_*` sections
- [ ] **S5.6** Mount action bar in `mock_exam_player_screen.dart` as `bottomNavigationBar`
- [ ] **S5.7** `test/exam_action_bar_test.dart` — enable matrix + skip flow + spinner
- [ ] **S5.8** `flutter test` green

### S6 — Answer sheet (read-only)
- [ ] **S6.1** `screens/answer_sheet_screen.dart` — fullscreen route, 5-col grid
- [ ] **S6.2** Cosmetic skill-section headers (ČTENÍ / PSANÍ / POSLECH / MLUVENÍ / INTERVIEW)
- [ ] **S6.3** Summary footer — "M/24 đã làm · K bỏ qua · X chưa"
- [ ] **S6.4** Open animation — 200 ms scale 0.95→1 + fade; 150 ms fade when reduce-motion
- [ ] **S6.5** Hook `exam_app_bar.onSheetTap` → `Navigator.push(MaterialPageRoute(fullscreenDialog: true))`
- [ ] **S6.6** `test/answer_sheet_screen_test.dart` — 3-state render + summary + reduce-motion
- [ ] **S6.7** `flutter test` green

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
