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

## Phase 1 — Mastery Aggregate (V19, 1 PR) ✅

- [x] **MA-1** new `processing/processing_config.go` — `MasteryConfig` struct, env loader, package singleton; `processing_config_test.go` covers defaults / env override / zero-weight fallback / band mapping (4 tests)
- [x] **MA-2** `store/skill_mastery_store.go` (memory + Postgres) + `contracts/skill_mastery.go` + `store/postgres_v17_constructors.go` URL ctor + `skill_mastery_store_test.go` covering insert / composite-key update / Get / List ordering / empty user / exam-pool empty module_id / missing user-skill rejection (7 tests)
- [x] **MA-3** new `processing/mastery_updater.go` (kept in-package to avoid cycle) + `mastery_updater_test.go` covering first attempt / EMA convergence / decay / idempotency on `last_attempt_id` / exam-pool empty module_id / missing user-skill-feedback no-op / `last_attempt_at` from `CompletedAt` (7 tests)
- [x] **MA-4** `processor.go` — `WithMasteryUpdater` setter + new `completeAttempt` helper that wraps `repo.CompleteAttempt` + mastery hook; all 5 `CompleteAttempt` call sites (speaking / writing / interview / objective / dictation) funnel through it; processor wiring tests (2 tests)
- [x] **MA-5** new `contracts/progress.go` (`Progress`, `SkillProgress`, `ModuleProgress`, `ProgressBands`); new `httpapi/progress_handler.go` (`GET /v1/users/me/progress` + `SetMasteryDeps`); `auth_handlers.go` `AuthDeps.SkillMastery` field + applyTo wiring (auto-installs mastery store + processor updater); `cmd/api/main.go` Postgres mastery store + AuthDeps; `progress_handler_test.go` covering 401 / empty user / populated weighted overall / env-overridden weights (4 tests)
- [x] **MA-6** `scripts/smoke_test_attempt_flow.py` — after attempt completion, GET `/v1/users/me/progress`, assert noi `attempts_count >= 1` and `mastery > 0`; tolerates 404/501 for deployments without V19 enabled

**Checkpoint 1:** ✅ `make backend-build` (success) + `make backend-test` (570/570 pass). `make smoke-attempt-flow` deferred to deploy step (needs running backend + seeded courses).

---

## Phase 2 — Validation Window (gate before V21 spaced repetition)

Tooling shipped (run-and-record):

- [ ] **Gate 1 — Staging deploy.** Runbook: `docs/validation/v19-staging-deploy.md`.
- [ ] **Gate 2 — 30-attempt teacher review** of `readiness_level` agreement.
      Template: `docs/validation/v19-teacher-review-template.md` (≥ 70 % exact
      agreement, ≥ 90 % off-by-1).
- [ ] **Gate 3 — p95 attempt-persist latency** before/after V19.
      `make mastery-latency` (post/pre p95 ratio ≤ 1.20).
- [x] **Gate 4 — Notebook simulation** of 20 attempt sequences.
      `make mastery-sim` (20/20 sane on production constants —
      `early_alpha=0.5 / steady_alpha=0.3 / cap=3`, bands
      `0.40/0.70/0.85`).

If any gate fails, capture findings in Phase 4 below and tune before
starting V21.

---

## Phase 3 — Flutter UI (V20, 1 PR)

- [x] **UI-1** new `core/api/progress_api.dart` + `progress_models.dart` — typed wrapper, `UserProgress.fromJson`, in-memory + `shared_preferences` 24h cache; new `test/api/progress_api_test.dart` covering parse / round-trip / empty / fetch+cache / memory-cache hit / forceRefresh / cold-start prefs / 24h expiry / stale fallback / offline rethrow (10 tests)
- [x] **UI-2** new `features/progress/widgets/mastery_bar.dart` + `skill_mastery_row.dart` — band → colour from API, 56dp row, `MergeSemantics`, tabular figures, reduced-motion path; new `test/widgets/mastery_bar_test.dart` covering 4 band cases + unknown fallback + clamp + semantics + reduced-motion + row layout + tap + merged semantics + tabular figures (12 tests)
- [x] **UI-3** new `features/progress/widgets/progress_empty_state.dart` + `progress_error_state.dart` — empty CTA "Bắt đầu học", error retry; strings injected by caller (ARB lands in UI-6); `progress_states_test.dart` covers render + tap + null-callback hide (6 tests)
- [x] **UI-4** new `features/progress/widgets/home_progress_card.dart` w/ ProgressFetcher typedef + HomeProgressCardLabels bag; mount in `features/home/screens/course_list_screen.dart` above existing course grid (inline VI strings pending UI-6 ARB); `home_progress_card_test.dart` covers loading → populated, empty + CTA, error + retry refetch, offline chip, tap-row fires kind callback (5 tests). Hardened `progress_models.dart` parser to accept Map/List with any element types
- [x] **UI-5** new `features/progress/screens/progress_detail_screen.dart` (`skillKind` nullable; AppBar title + offline chip; pull-to-refresh forces refetch; per-skill section w/ MasteryBar + SkillMasteryRow modules); profile entry tile pushes detail w/ `skillKind: null`; HomeProgressCard onSkillTap pushes detail w/ skillKind set; `progress_detail_screen_test.dart` covers all-skills, single-skill filter, empty, error+retry, pull-to-refresh forceRefresh, offline chip (6 tests)
- [x] **UI-6** `l10n/app_vi.arb` + `app_en.arb` — 24 new progress keys per spec (homeProgressCardTitle, progressOverallTitle/Percent, 7 progressSkill*, 4 progressBand*, progressEmpty/Error/Offline + Detail title/attempts/lastAttempt/relativeFormat, profileProgressEntry); ran `flutter gen-l10n`; replaced inline VI strings in `course_list_screen.dart` + `profile_screen.dart` with `AppLocalizations`; VI=EN parity verified (376=376 keys)

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
