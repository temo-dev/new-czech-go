# Tasks — Plan Index

**Active backlog only.** V2..V20 history lives in
[`plan-archive-v2-to-v20.md`](plan-archive-v2-to-v20.md) (138 KB
mega-file, frozen). V19+ slices each have their own plan/todo pair.

## Per-slice plan files

| Slice | Plan | Todo | Spec | Status |
|---|---|---|---|---|
| V39 Exam Flat-Sort Player | [v39-exam-flat-sort-player-plan.md](v39-exam-flat-sort-player-plan.md) | [v39-exam-flat-sort-player-todo.md](v39-exam-flat-sort-player-todo.md) | [docs/specs/v39-exam-flat-sort-player.md](../docs/specs/v39-exam-flat-sort-player.md) | ✅ shipped 2026-05-12 (S4+S5 partial — inline player rewrite deferred) |
| V37 Vocab Item Per-item Polly TTS | [v37-vocab-item-polly-tts-plan.md](v37-vocab-item-polly-tts-plan.md) | [v37-vocab-item-polly-tts-todo.md](v37-vocab-item-polly-tts-todo.md) | [docs/specs/v37-vocab-item-polly-tts.md](../docs/specs/v37-vocab-item-polly-tts.md) | ✅ shipped |
| V36 Interview-in-Mock-Exam | [v36-interview-in-mock-exam-plan.md](v36-interview-in-mock-exam-plan.md) | [v36-interview-in-mock-exam-todo.md](v36-interview-in-mock-exam-todo.md) | [docs/specs/v36-interview-in-mock-exam.md](../docs/specs/v36-interview-in-mock-exam.md) | ✅ implemented — Phase E smoke pending |
| V25 IAP Wire Real | [v25-iap-wire-real-plan.md](v25-iap-wire-real-plan.md) | [v25-iap-wire-real-todo.md](v25-iap-wire-real-todo.md) | [docs/specs/iap-wire-real.md](../docs/specs/iap-wire-real.md) | ✅ implemented (Phase A-G + H1; H2 App Store Connect + H3 TestFlight remain operator-side) |
| V24 Doc Draft Generator | [v24-doc-draft-generator-plan.md](v24-doc-draft-generator-plan.md) | [v24-doc-draft-generator-todo.md](v24-doc-draft-generator-todo.md) | [docs/specs/v24-doc-draft-generator.md](../docs/specs/v24-doc-draft-generator.md) | ✅ implemented (C4 manual Czech-quality gate pending before prod promotion) |
| V23 Exercise Authoring Polish | [v23-exercise-authoring-polish-plan.md](v23-exercise-authoring-polish-plan.md) | [v23-exercise-authoring-polish-todo.md](v23-exercise-authoring-polish-todo.md) | [docs/specs/v23-exercise-authoring-polish.md](../docs/specs/v23-exercise-authoring-polish.md) | ✅ implemented (C8 deferred V24; awaiting commit + manual smoke) |
| V22 CMS Catch-Up | [v22-cms-catch-up-plan.md](v22-cms-catch-up-plan.md) | [v22-cms-catch-up-todo.md](v22-cms-catch-up-todo.md) | [docs/specs/v22-cms-catch-up.md](../docs/specs/v22-cms-catch-up.md) | ✅ implemented (awaiting commit + manual smoke) |
| V21.3 CEFR UI Wire-up | [cefr-ui-wireup-plan.md](cefr-ui-wireup-plan.md) | [cefr-ui-wireup-todo.md](cefr-ui-wireup-todo.md) | [docs/specs/cefr-ui-wireup.md](../docs/specs/cefr-ui-wireup.md) | ✅ shipped |
| V21 CEFR Level Progression (A0→B1) | [cefr-level-progression-plan.md](cefr-level-progression-plan.md) | [cefr-level-progression-todo.md](cefr-level-progression-todo.md) | [docs/specs/cefr-level-progression.md](../docs/specs/cefr-level-progression.md) | ✅ shipped + V21.1 hotfixes |
| V19 Skill Mastery Progress | [skill-mastery-progress-plan.md](skill-mastery-progress-plan.md) | [skill-mastery-progress-todo.md](skill-mastery-progress-todo.md) | [docs/specs/skill-mastery-progress.md](../docs/specs/skill-mastery-progress.md) | ✅ shipped |
| V11 Exercise Dashboard upgrade | [exercise-dashboard-plan.md](exercise-dashboard-plan.md) | [exercise-dashboard-todo.md](exercise-dashboard-todo.md) | [docs/specs/exercise-dashboard-upgrade.md](../docs/specs/exercise-dashboard-upgrade.md) | ✅ shipped |
| Admin auth | [plan-admin-auth.md](plan-admin-auth.md) | — | [docs/specs/admin-user-management.md](../docs/specs/admin-user-management.md) | ✅ shipped |
| Exercise form upgrade | [plan-exercise-form-upgrade.md](plan-exercise-form-upgrade.md) | — | [docs/specs/exercise-dashboard-upgrade.md](../docs/specs/exercise-dashboard-upgrade.md) | ✅ shipped |
| V6 Vocab + Grammar LLM authoring | [plan-vocab-grammar.md](plan-vocab-grammar.md) | — | [docs/specs/deck-session-vocab-grammar.md](../docs/specs/deck-session-vocab-grammar.md) | ✅ shipped |

## Active TODOs (V21.1 + remaining)

See [todo.md](todo.md) — re-written as a thin index too.

### V21.1 deferred (suggestion-tier)

S1–S8 from the V21 review remain open as polish; none are deploy
blockers. See `cefr-level-progression-todo.md` for the full V21 task
ledger.

### Remaining V21 backlog

1. Manual TestFlight MAN-1..10 acceptance (V21-E2; deploy-time).
2. ~~Home `home_screen.dart` integration of `HomeLevelHeader` +
   onboarding router gate~~ → folded into **V21.3 CEFR UI Wire-up**
   (see slice plan).
3. ~~ARB-routed copy across V21 widgets~~ → folded into V21.3 § F1.

### Future-slice candidates

| Idea | Doc | Status |
|---|---|---|
| Attempt Repair And Shadowing | [docs/ideas/attempt-repair-and-shadowing.md](../docs/ideas/attempt-repair-and-shadowing.md) + [docs/specs/attempt-repair-and-shadowing.md](../docs/specs/attempt-repair-and-shadowing.md) | Spec written, not yet planned |
| Skill-wise CEFR per learner (Direction B) | Notes inside [docs/ideas/cefr-level-progression.md](../docs/ideas/cefr-level-progression.md) | Deferred — V21 picked Direction A |
| A0 / A1 content authoring | — | Content question, not engineering |
| Adaptive promotion exam generation | — | Mentioned in V21 § Avoid |

## How to add a new slice

1. Refine the idea → `docs/ideas/<slice>.md`.
2. Spec → `docs/specs/<slice>.md` (folds into `docs/reference/` once
   shipped if it changes a stable contract).
3. Plan → `tasks/<slice>-plan.md` + `tasks/<slice>-todo.md` (this
   file). Per-slice files keep the slice-spanning git diff in one place.
4. Build → TDD per task; commit per checkpoint.
5. Verify → `make verify` + `make smoke-<slice>-flow`.
6. Add a row to the table above; add a CHANGELOG entry; SPEC.md row.

## Archive

The old `tasks/plan.md` (V2..V20 inline mega-file, 3715 lines) lives
at [`plan-archive-v2-to-v20.md`](plan-archive-v2-to-v20.md). Don't
update it — it is a historical record. New slice plans go into their
own `<slice>-plan.md` file.
