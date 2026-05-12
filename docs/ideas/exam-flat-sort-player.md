# exam-flat-sort-player

**Decided:** 2026-05-12

## Problem Statement

How might we let A2 learners hit "Làm bài" and jump into the first
question immediately, then move freely between questions via a sheet,
with timer auto-submit — without rebuilding the per-skill exam template?

## Recommended Direction

A "flat-sort exam player" slice that:

- Sorts all sections cross-skill by `max_points` asc (1đ → 5đ).
  Lowest-stakes warm-up first, highest-stakes finale last.
- Auto-advances on submit; "Bỏ qua" marks `status='skipped'` and jumps
  to the next section.
- Top-right opens a **fullscreen Answer Sheet** with 3 states (done /
  skipped / empty). Tap any cell to jump back; re-answer overwrites.
- Single global timer (90 min total), server-authoritative
  (`exam_session.started_at + duration`), auto-submits when hits 0.
- Speaking re-record from sheet **overwrites** the prior attempt's
  audio in place (same `attempt_id`, S3 object replaced — no audit
  trail).
- Intro screen warns: timer does **not** pause when the app is
  backgrounded — mirrors the real paper exam.

**Why this, not today's linear flow:**

- Today's MockExam = strict linear, no skip, no jumping → learners
  report friction when stuck on a single question.
- Flat point-sort softens stakes at the start (1đ MCQ before 5đ
  Mluvení) — a psychological warm-up.
- Paper-exam `Odpovědní list` mental model maps cleanly to the
  fullscreen answer sheet.

**Why this is risky:**

- Cross-skill sort breaks the per-skill timer of the real A2 exam
  (Čtení 50' / Psaní 60' / Poslech 30' / Mluvení 10'). Collapsing to
  one 90' timer lowers exam fidelity.
- Poslech audio context becomes fragmented when Čtení / Mluvení items
  interleave — listening comprehension value drops.
- Mluvení 60-90s recording sitting mid-sequence breaks rhythm and may
  pressure learners into rushed recordings.

## Key Assumptions to Validate

- [ ] Learners prefer cross-skill flat sort over per-skill grouping —
      validate via in-app prompt after first run: "Quen hơn không?"
- [ ] 1-timer-toàn-bài 90 phút does not cause panic-skip of Mluvení at
      the end — measure: % Mluvení completed vs. % Čtení completed.
- [ ] Poslech accuracy holds ≥60% despite fragmented context — pilot
      with 5 learners before broad rollout.
- [ ] Re-record-overwrite does not generate regret support tickets —
      track "lỡ ghi đè recording" requests post-launch.

## MVP Scope

**In:**

- Intro screen polish: 24 câu / 90' / no-pause warning / "Bắt đầu" CTA
  that starts the server timer.
- Player rewrite: split the 942-line `mock_exam_screen.dart` into
  smaller widgets (`exam_app_bar.dart`, `exam_action_bar.dart`,
  `question_status_chip.dart`).
- Top-left timer with tabular figures; <5 min remaining flips colour
  to error + light haptic every minute.
- Top-right sheet button (safe-area aware vs. Dynamic Island).
- Sticky bottom action bar: secondary "Bỏ qua" + primary "Nộp câu",
  gap ≥12px, Submit shows loading spinner during async work.
- Fullscreen `AnswerSheetScreen` with 64×64pt grid cells, 3-state
  visuals (color + icon + text — never colour-only), skill-grouped
  section labels even though the underlying order is flat.
- Backend: `mock_exam_sections.status` enum gains `'skipped'`; new
  `POST /v1/mock-exams/:id/skip {section_id}`; `display_order` int
  column persisted at session creation so sort is stable across
  reads.
- Speaking re-record overwrites the same `attempt_id` (replace the S3
  object, leave the DB row in place).
- Auto-submit when the server-computed timer reaches 0.

**Out (defer or drop entirely):**

- Per-skill timer.
- Audit trail for overwritten recordings.
- Pause-when-backgrounded.
- Multi-device resume.
- "Save draft" exit flow.
- Per-section retry limit.
- Listening-replay restriction on revisit (keep the current 2-replay
  default).

## Not Doing (and Why)

- **Per-skill timer** — Incompatible with the chosen flat cross-skill
  sort. We accept lower exam fidelity for UX simplicity. If the
  fidelity loss bites in pilot, the fix is to revert to per-skill
  grouping, not to staple per-skill timers on top of a flat list.
- **Audit trail for overwritten recordings** — Storage cost and
  privacy concerns outweigh the recovery use case at this scale. The
  user explicitly chose simplicity.
- **Bottom-sheet for the answer sheet** — Height-limited and nests
  awkwardly with a scrollable grid. The user chose fullscreen.
- **Folding into `flexible-sprint-mocktest`** — The user asked for a
  standalone slice. Revisit only if a later slice surfaces real
  contract overlap.
- **Background-pause timer** — Mô phỏng thi thật.
- **Per-skill A/B test in the MVP** — Only add if Assumption 1 fails
  after the first rollout.

## Open Questions (non-blocking)

- Listening replay budget when revisiting from the sheet: keep the
  current 2-replay default, or 0-replay-on-revisit as an anti-cheat
  measure?
- 3-state grid VoiceOver labels — confirm "Câu 5, đã làm" / "Câu 7,
  đã bỏ qua" / "Câu 12, chưa làm, đang chọn" reads naturally on
  iOS + Android screen readers.
- `reduce-motion` — the 400ms scale animation on auto-advance must
  collapse to a 150ms fade when `MediaQuery.disableAnimations` is on.
- Confirm dialog before destructive "Nộp bài ngay (2/24)" when most
  questions are still empty?
- Timer authority sync cadence — server `started_at + duration` is
  the source of truth; clients refresh every 30s or on app resume.
  Acceptable drift?

## Next

→ `tasks/exam-flat-sort-player-plan.md` (slice plan, phases A..E per
  AGENTS.md slice lifecycle).
→ Re-read `docs/ideas/flexible-sprint-mocktest.md` and
  `docs/ideas/exam-result-flow-redesign.md` before plan freeze to
  surface any contract overlap.
