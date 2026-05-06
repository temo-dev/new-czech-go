# Skill Mastery & Progress — Todo

Spec: `docs/specs/skill-mastery-progress.md`
Plan: `tasks/skill-mastery-progress-plan.md`
Idea: `docs/ideas/skill-mastery-progress.md`

---

## Phase 0 — Vocab Unify (Prerequisite, 1 PR) ✅

- [x] **V0-1** `processing/llm_prompts.go` + `llm_feedback.go` — drop `exam_ready`, add `needs_work` to schema; extend `normalizeReadinessLevel` legacy mapping; add `ReadinessToScore`
- [x] **V0-2** `processing/objective_scorer.go` + `dictation_processor.go` — re-threshold to `0.85 / 0.60 / 0.30`; split `objectiveScoreBand` for legacy `weak/ok/strong` ScoreBand; rewrite `TestReadinessLevelFromObjective` table; add `TestObjectiveScoreBand` + `TestBuildObjectiveFeedback_VocabSplit`
- [x] **V0-3** `processing/llm_fallbacks.go` — replace `"ok"` ReadinessLevel literals with `"needs_work"`; Flutter `interview_result_screen.dart` default `'ok'` → `'needs_work'` + `_readinessToScore`/`_readinessLabel` map 4-band tokens; `writing_scorer_test.go` table update; ARB pillReadiness keys verified intact

**Checkpoint 0:** ✅ `make backend-build` (success) + `make backend-test` (543/543 pass) + `make flutter-analyze` (clean) + `make flutter-test` (226/226 pass). Smoke deferred — needs running backend; will run alongside Checkpoint 1.

---

## Phase 1 — Mastery Aggregate (V19, 1 PR)

- [ ] **MA-1** new `processing/processing_config.go` — `MasteryConfig` struct, env loader, package singleton; `processing_config_test.go` covers env override + zero-weight fallback
- [ ] **MA-2** `store/postgres_migrate.go` — `CREATE TABLE IF NOT EXISTS user_skill_mastery` + UNIQUE index `(user_id, skill_kind, module_id)` + covering index `(user_id, updated_at desc)`; new `store/postgres_mastery.go` (`GetForKey`, `Upsert`, `ListForUser`); new `store/postgres_mastery_test.go`
- [ ] **MA-3** new `processing/mastery/updater.go` — `Update(ctx, attempt)` with idempotency on `last_attempt_id`, EMA branch (`<3 attempts → 0.5/0.5`, else `0.7/0.3`); new `processing/mastery/updater_test.go` covering first attempt, convergence, decay, idempotency, exam-pool empty `module_id`, missing-user no-op
- [ ] **MA-4** `processing/processor.go` — inject `mastery.Updater`, call after `PersistAttemptFeedback`, log error don't propagate; existing `processor_test.go` still green with no-op stub
- [ ] **MA-5** new `contracts/progress.go` (`Progress`, `SkillProgress`, `ModuleProgress`, `Bands`, `Weights`); new `httpapi/progress_handler.go` (`GET /v1/users/me/progress`); `httpapi/server.go` route wire; new `httpapi/progress_handler_test.go` covering 401, empty user, populated weighted overall, env-overridden weights, exam-pool row
- [ ] **MA-6** `scripts/smoke/attempt_flow.sh` — after attempt completion, `curl /v1/users/me/progress` and `jq` assert `.skills | length == 1 && .skills[0].attempts_count == 1 && .skills[0].mastery > 0`

**Checkpoint 1:** `make backend-build && make backend-test && make smoke-attempt-flow && make smoke-course-flow` — all green. PR `feat(backend): user skill mastery aggregate + progress endpoint (V19)`.

---

## Phase 2 — Validation Window (no code — gate before V20)

- [ ] V19 deployed to staging
- [ ] 30-attempt teacher review of `readiness_level` agreement
- [ ] p95 attempt-persist latency snapshot before/after V19
- [ ] Notebook simulation of 20 attempt sequences against production formula

If any gate fails, fix Phase 1 before starting Phase 3.

---

## Phase 3 — Flutter UI (V20, 1 PR)

- [ ] **UI-1** new `core/api/progress_api.dart` + `progress_models.dart` — typed wrapper, `UserProgress.fromJson`, in-memory + `shared_preferences` 24h cache; new `test/api/progress_api_test.dart`
- [ ] **UI-2** new `features/progress/widgets/mastery_bar.dart` + `skill_mastery_row.dart` — band → colour from API, 56dp row, `MergeSemantics`, tabular figures, reduced-motion path; new `test/widgets/mastery_bar_test.dart` covering 4 band cases + semantics
- [ ] **UI-3** new `features/progress/widgets/progress_empty_state.dart` + `progress_error_state.dart` — empty CTA "Bắt đầu học", error retry
- [ ] **UI-4** new `features/progress/widgets/home_progress_card.dart`; mount in `features/home/screens/course_list_screen.dart` above existing course grid; new `test/widgets/home_progress_card_test.dart` covering loading → populated, empty, tap-row → detail
- [ ] **UI-5** new `features/progress/screens/progress_detail_screen.dart` (`skillKind` nullable); add list tile in `features/profile/screens/profile_screen.dart` → push detail with `skillKind: null`; new `test/screens/progress_detail_screen_test.dart`
- [ ] **UI-6** `l10n/app_vi.arb` + `app_en.arb` — 24 new keys per spec; codegen + commit generated file; VI=EN key parity check

**Checkpoint 3:** `make flutter-analyze && make flutter-test`. Manual: iPhone SE 375 + iPhone 14 Pro × light/dark × reduced-motion + largest Dynamic Type. PR `feat(flutter): home progress card + skill detail screen (V20)`.

---

## Phase 4 — Post-ship Validation (blocks V21 spaced repetition)

- [ ] 30-attempt teacher-agreement review ≥ 70%
- [ ] 5-learner pilot interview on module-level guidance
- [ ] 20-sequence notebook curve sanity check
- [ ] Attempt-persist p95 within current SLO
- [ ] CHANGELOG entry recording outcome of each gate

---

## Reject in PR review (per AGENTS.md)

- Prompt strings outside `llm_prompts.go` / `llm_user_prompts.go`
- LLM model literals outside `llm_config.go`
- `os.Getenv("MASTERY_*")` outside `processing/processing_config.go`
- Inline VI/EN strings in mastery/updater/handler Go files
- Inline VI strings in Flutter widgets (must go through ARB)
- Backfill of historical attempts (explicitly out of scope)
- Adding `confidence_score` / `next_review_at` / `status` columns (deferred slices)
