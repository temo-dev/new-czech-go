# Spec: Skill Mastery & Progress

## Status
Not started. Planned slices V19 (backend) + V20 (Flutter UI). This
spec covers both. Pair files:

- Idea: `docs/ideas/skill-mastery-progress.md`
- Plan: `docs/plans/skill-mastery-progress-plan.md` (TBD)

## Purpose
Turn the stream of independent `AttemptFeedback.readiness_level`
into a durable per-skill / per-module mastery signal so an A2
*trvalý pobyt* candidate sees where they are weak and what to
practise next.

The current attempt feedback path is preserved untouched. This
slice adds an **aggregate layer** keyed by
`(user_id, skill_kind, module_id)` updated synchronously after each
`AttemptFeedback` is persisted, plus a single read endpoint.

This is **not** a recommendation engine, **not** spaced repetition,
**not** a pass-likelihood predictor. Those are separate slices.

## Current Implementation Snapshot
Backend has:

- `users` table + JWT auth (`backend/internal/store/postgres_users.go`,
  `backend/internal/httpapi/auth_handlers.go`)
- `attempts.user_id` populated at create time
  (`backend/internal/store/attempt_store.go:54`)
- Per-attempt `AttemptFeedback.ReadinessLevel` produced by:
  - LLM scorer — `processing/llm_prompts.go:52`,
    `processing/llm_feedback.go:193 normalizeReadinessLevel`,
    vocabulary `not_ready / almost_ready / ready_for_mock /
    exam_ready`
  - Objective scorer — `processing/objective_scorer.go:107-109`,
    `processing/dictation_processor.go:85`, vocabulary
    `weak / ok / strong` derived from `frac >= 0.5 / 0.8`
- Score band tokens reusable in Flutter:
  `flutter_app/lib/core/theme/app_colors.dart` lines 64-67
  (`scoreExcellent / scoreGood / scoreFair / scorePoor`)

No aggregate exists today. No `user_skill_mastery` table. No
progress endpoint. The two readiness vocabularies are inconsistent.

## Graph Notes
Aggregate write path lives at the persist boundary of
`AttemptFeedback`, not inside the scoring pipeline itself. Scoring
remains pure; the updater is a side-effect attached to persistence.
Read path is a new HTTP handler returning a flat aggregate plus a
weighted `overall_progress` derived on read.

## Goals
- One unified 4-band readiness vocabulary across LLM and objective
  scorers.
- One row per `(user_id, skill_kind, module_id)` reflecting EMA-
  smoothed mastery.
- One endpoint `GET /v1/users/me/progress` returning per-skill,
  per-module mastery and a weighted overall.
- Flutter `HomeScreen` shows a progress card; `ProgressDetailScreen`
  drills into one skill.
- All copy goes through ARB; VI=EN key parity preserved.

## Non-Goals
- A1 / B1 levels (scope is A2 only per `AGENTS.md`).
- `confidence_score`, `status`, `next_review_at` columns.
- Recommendation engine, "next best lesson", spaced repetition.
- Backfill of historical attempts on rollout.
- Topic-level granularity beyond `module_id`.
- `progress_delta` inside the attempt response.
- Public pass-likelihood number, streak, XP, leaderboard.
- `ExamReadiness` materialised view.

## Readiness Vocabulary (P0 — separate commit before V19 main)
Single 4-band scale used by both scorers and the aggregate input:

| Band | Numeric | Source mapping |
|---|---|---|
| `not_ready` | 0.20 | LLM `not_ready`, objective `frac < 0.30` |
| `needs_work` | 0.45 | objective `0.30 <= frac < 0.60`, LLM `needs_work` (new) |
| `almost_ready` | 0.70 | LLM `almost_ready`, objective `0.60 <= frac < 0.85` |
| `ready_for_mock` | 0.90 | LLM `ready_for_mock` & `exam_ready`, objective `frac >= 0.85` |

Notes:
- Drop the LLM `exam_ready` token from the prompt; collapse into
  `ready_for_mock`. Avoids overpromising.
- Add `needs_work` to LLM prompt schema explicitly so the LLM no
  longer skips the middle-low band.
- `objective_scorer.go` band thresholds change from `0.5 / 0.8` to
  `0.3 / 0.6 / 0.85`. Existing `objective_scorer_test.go` cases
  must be updated and a new `TestReadinessLevelFromObjective`
  table added covering all four bands.
- `normalizeReadinessLevel` keeps backwards compatibility for any
  legacy persisted feedback (`weak -> needs_work`, `ok ->
  almost_ready`, `strong -> ready_for_mock`, `exam_ready ->
  ready_for_mock`).

## Data Model

### Table: `user_skill_mastery`

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid pk` | gen by Go |
| `user_id` | `uuid not null` | FK `users(id)` (logical) |
| `skill_kind` | `text not null` | one of `noi / viet / nghe / doc / tu_vung / ngu_phap / interview` |
| `module_id` | `text not null` | empty string allowed for exam-pool aggregate row |
| `mastery_score` | `double precision not null default 0` | range `[0,1]` |
| `attempts_count` | `integer not null default 0` | total attempts feeding this row |
| `last_attempt_id` | `uuid` | nullable |
| `last_attempt_at` | `timestamptz` | nullable |
| `created_at` | `timestamptz not null default now()` | |
| `updated_at` | `timestamptz not null default now()` | |

Constraints / indexes:

- `UNIQUE (user_id, skill_kind, module_id)`
- `INDEX (user_id, updated_at desc)` for read endpoint
- Migrated via `addColumnIfMissing` pattern; new table created by a
  guarded `CREATE TABLE IF NOT EXISTS` in `postgres_migrate.go`.

No `confidence_score`, no `status`, no `next_review_at` in V19.

### EMA update rule

```
attempt_score = ReadinessToScore(feedback.readiness_level)

if attempts_count == 0:
    new_mastery = attempt_score
else if attempts_count < 3:
    new_mastery = old_mastery * 0.5 + attempt_score * 0.5
else:
    new_mastery = old_mastery * 0.7 + attempt_score * 0.3
```

Faster-converging window for the first 3 attempts so the bar feels
responsive early. After that, smoother. Numeric constants live in
`processing/mastery_config.go` (new file).

`ReadinessToScore` lives next to `normalizeReadinessLevel` in
`processing/llm_feedback.go` and is the **only** mapping from band
string to numeric.

## Configuration (env vars, `processing/llm_config.go`)

| Var | Default | Purpose |
|---|---|---|
| `MASTERY_BAND_LEARNING` | `0.40` | UI band threshold (also returned by API) |
| `MASTERY_BAND_SOLID` | `0.70` | UI band threshold |
| `MASTERY_BAND_READY` | `0.85` | UI band threshold |
| `MASTERY_OVERALL_NOI` | `25` | Weight in overall (percent) |
| `MASTERY_OVERALL_NGHE` | `20` | |
| `MASTERY_OVERALL_DOC` | `20` | |
| `MASTERY_OVERALL_VIET` | `20` | |
| `MASTERY_OVERALL_NGU_PHAP` | `10` | |
| `MASTERY_OVERALL_TU_VUNG` | `5` | |
| `MASTERY_OVERALL_INTERVIEW` | `0` | Excluded from overall by default |

Env loader extends `LoadLLMModels()` (rename or split into
`LoadProcessingConfig()` if it grows; do not pollute the LLM
loader with non-LLM config — split into
`processing/processing_config.go`).

Weights are normalised on read so they don't have to sum to 100; if
all weights are zero, fall back to equal weight across non-zero
mastery rows to avoid `NaN`.

## Update Flow

```
processing.processor.go:
  ... existing scoring ...
  store.PersistAttemptFeedback(ctx, attempt)
  mastery.Update(ctx, attempt)        ← NEW, sync, error logged not propagated
```

`mastery.Update`:

1. Resolve `(user_id, skill_kind, module_id)` from the attempt.
   - `module_id` empty when `pool=exam`; aggregate row uses the
     empty string. (Keeps the unique index simple. UI shows exam-
     pool rows under a virtual "Đề thi" group on read side.)
2. `INSERT ... ON CONFLICT (user_id, skill_kind, module_id) DO
   UPDATE` with the EMA expression computed in Go (not in SQL — we
   need the `attempts_count` branch logic).
3. `attempts_count = old + 1`, `last_attempt_id = attempt.id`,
   `last_attempt_at = attempt.completed_at`, `updated_at = now()`.
4. Idempotency: if `last_attempt_id == attempt.id` already, skip.
   Allows the persist path to be retried without double-counting.

Failure of `mastery.Update` **must not** roll back the attempt.
Logged at `error` level with `attempt_id`. Surfaces a minor
observability gap, not a learner-facing failure.

## API

### `GET /v1/users/me/progress`

Auth: bearer JWT. Returns 401 unauthenticated, 200 always for
authenticated users (even when no rows exist).

Response shape:

```json
{
  "overall_progress": 0.62,
  "overall_band": "learning",
  "skills": [
    {
      "skill_kind": "noi",
      "mastery": 0.55,
      "band": "learning",
      "attempts_count": 12,
      "last_attempt_at": "2026-05-05T10:14:22Z",
      "modules": [
        {
          "module_id": "giao-tiep-co-ban",
          "mastery": 0.60,
          "band": "learning",
          "attempts_count": 8,
          "last_attempt_at": "2026-05-05T10:14:22Z"
        }
      ]
    }
  ],
  "bands": {
    "needs_work": 0.40,
    "solid": 0.70,
    "ready": 0.85
  },
  "weights": {
    "noi": 25, "viet": 20, "nghe": 20, "doc": 20,
    "ngu_phap": 10, "tu_vung": 5, "interview": 0
  }
}
```

- `bands` and `weights` are returned so Flutter never has to know
  the config; backend stays the single source of truth for both.
- `band` is computed: `mastery < bands.needs_work` → `needs_work`,
  `< bands.solid` → `learning`, `< bands.ready` → `solid`, else
  `ready`.
- Empty user: `overall_progress = 0`, `overall_band = needs_work`,
  `skills = []`. Flutter renders empty state from this.

Add to `docs/specs/api-contracts.md` after V19 ships.

## Backend File Layout

| File | Role | Status |
|---|---|---|
| `processing/llm_prompts.go` | Drop `exam_ready`, add `needs_work` to readiness schema string | edit |
| `processing/llm_feedback.go` | Extend `normalizeReadinessLevel` legacy mapping; add `ReadinessToScore` | edit |
| `processing/objective_scorer.go` | Re-thresholds `frac` to 4 bands | edit |
| `processing/dictation_processor.go` | Use new `ReadinessFromObjective` helper | edit |
| `processing/processing_config.go` | NEW — `LoadMasteryConfig()` env loader, weight + band defaults | new |
| `processing/mastery/updater.go` | NEW — `Update(ctx, attempt)` |  new |
| `processing/mastery/updater_test.go` | NEW — EMA, idempotency, missing-module cases | new |
| `processing/processor.go` | Call `mastery.Update` after persist | edit |
| `store/postgres_mastery.go` | NEW — upsert + read | new |
| `store/postgres_mastery_test.go` | NEW — upsert race, unique constraint | new |
| `store/postgres_migrate.go` | Add `CREATE TABLE IF NOT EXISTS user_skill_mastery` block | edit |
| `httpapi/progress_handler.go` | NEW — `GET /v1/users/me/progress` | new |
| `httpapi/progress_handler_test.go` | NEW — auth, shape, weighted overall, empty user | new |
| `httpapi/server.go` | Wire route | edit |
| `contracts/progress.go` | NEW — wire types `Progress`, `SkillProgress`, `ModuleProgress` | new |

Reject in code review (per `AGENTS.md`):
- Any new prompt string outside `llm_prompts.go`.
- Any inline LLM model literal outside `llm_config.go`.
- Inline VI/EN string literals in `mastery/updater.go` or the
  handler — this slice has no learner-visible strings on the
  backend side.

## Flutter File Layout (V20)

| File | Role |
|---|---|
| `core/api/progress_api.dart` | NEW — typed wrapper over `GET /v1/users/me/progress` |
| `core/api/progress_models.dart` | NEW — `UserProgress`, `SkillProgress`, `ModuleProgress` |
| `features/progress/screens/progress_detail_screen.dart` | NEW — Screen 2 |
| `features/progress/widgets/home_progress_card.dart` | NEW — mounted into `HomeScreen` top |
| `features/progress/widgets/skill_mastery_row.dart` | NEW — reusable row |
| `features/progress/widgets/mastery_bar.dart` | NEW — band-coloured 8dp bar |
| `features/progress/widgets/progress_empty_state.dart` | NEW |
| `features/progress/widgets/progress_error_state.dart` | NEW |
| `features/home/screens/course_list_screen.dart` | EDIT — mount `HomeProgressCard` above existing course list |
| `features/profile/screens/profile_screen.dart` | EDIT — list tile "Tiến độ học tập" → push `ProgressDetailScreen(skillKind: null)` |
| `l10n/app_vi.arb`, `app_en.arb` | EDIT — new keys (see UI Spec) |
| `models/progress_test.dart` | NEW — JSON round-trip |
| `widgets/mastery_bar_test.dart` | NEW — band selection, semantics label |

Pull-to-refresh on `ProgressDetailScreen` via `RefreshIndicator`.
Cache last response in memory + `shared_preferences` for offline
fallback (TTL 24h, displayed with "Đang offline" chip).

## UI Spec
See `docs/ideas/skill-mastery-progress.md` § "UI specs" for ASCII
wireframes and band mapping. Tokens to reuse:

| UI element | Token |
|---|---|
| Card surface | `AppColors.surfaceContainerLow` |
| Card padding | `AppSpacing.md` (16) |
| Card radius | `AppRadius.lg` |
| Bar height | 8 |
| Bar background | `AppColors.surfaceContainerHigh` |
| Bar fill `needs_work` | `AppColors.scorePoor` |
| Bar fill `learning` | `AppColors.scoreFair` |
| Bar fill `solid` | `AppColors.scoreGood` |
| Bar fill `ready` | `AppColors.scoreExcellent` |
| Skill row min height | 56 |
| Percent text style | `labelLg` with `FontFeature.tabularFigures()` |
| Tap area | full row, `InkWell` |

Required ARB keys (VI=EN parity):

```
progressOverallTitle
progressOverallPercent
progressSkillNoi
progressSkillViet
progressSkillNghe
progressSkillDoc
progressSkillTuVung
progressSkillNguPhap
progressSkillInterview
progressBandNeedsWork
progressBandLearning
progressBandSolid
progressBandReady
progressEmptyTitle
progressEmptyCta
progressErrorTitle
progressErrorRetry
progressOfflineChip
progressDetailTitle
progressDetailAttemptsLabel
progressDetailLastAttemptLabel
progressLastAttemptRelativeFormat
profileProgressEntry
homeProgressCardTitle
```

## Acceptance Criteria

### V19 backend

- [ ] `make backend-build` passes.
- [ ] `make backend-test` passes; existing tests still green.
- [ ] New tests cover: 4-band readiness mapping (LLM + objective +
      dictation), EMA progression on a 5-attempt sequence, EMA
      decay on alternating sequence, idempotency on duplicate
      `last_attempt_id`, exam-pool empty `module_id` row, weighted
      overall with custom weights, empty-user response.
- [ ] `GET /v1/users/me/progress` returns 401 without bearer, 200
      with bearer (even when zero rows).
- [ ] Smoke: `make smoke-attempt-flow` still passes; add a step
      that calls `/progress` after a single attempt and asserts
      one row exists with `attempts_count=1`.
- [ ] LLM prompt no longer mentions `exam_ready`; explicit
      `needs_work` token added.
- [ ] No prompt / model / env-var literals outside the four
      designated files (`llm_config.go`, `llm_prompts.go`,
      `llm_user_prompts.go`, `llm_fallbacks.go`,
      `processing_config.go`).

### V20 Flutter

- [ ] `make flutter-analyze` clean.
- [ ] `make flutter-test` passes; new widget tests for
      `MasteryBar` (band selection, semantics) and
      `HomeProgressCard` (loading, empty, error, populated).
- [ ] VI=EN ARB key count parity verified.
- [ ] `HomeScreen` renders progress card above course list on
      375 px width without overflow; tested in light + dark.
- [ ] `ProgressDetailScreen` pull-to-refresh re-fetches.
- [ ] All tap rows ≥ 48 dp; `MasteryBar` has descriptive
      `Semantics(label: ...)`.
- [ ] Reduced-motion: bar paints at final value without
      animation.
- [ ] Dynamic Type at largest size: percent text scales, bar
      height fixed, no clipping.
- [ ] Offline: stale data shown with `progressOfflineChip`.

## Validation Gates (post-ship, before V21)

- [ ] 30-attempt manual review: `readiness_level` agreement with
      teacher rating ≥ 70%.
- [ ] 5-learner pilot: module-level guidance feels actionable in
      interview feedback.
- [ ] Simulate 20 attempt sequences in a notebook against the
      production formula; mastery curves visually sane.
- [ ] p95 latency of attempt persist within current SLO after the
      `mastery.Update` hook.

If any validation gate fails, `next_review_at` and recommendation
work in V21 is blocked until the input signal is reliable.

## Rollout

- Migration runs on backend startup via existing
  `addColumnIfMissing` / `CREATE TABLE IF NOT EXISTS` pattern;
  zero-downtime.
- No backfill of historical attempts. Mastery starts at zero for
  every user. Acceptable trade-off because the validation gates
  measure the post-rollout signal, not historical replay.
- V20 Flutter ships behind no flag; if backend response is empty,
  Flutter renders the empty state.

## Open Questions
- Per-skill bottom nav tab — explicitly decided against in V19/V20
  to preserve the 4-tab layout. Revisit only if pilot shows
  Profile-entry route is undiscoverable.
- Weight defaults (`25/20/20/20/10/5/0`) are an A2-exam guess;
  validation gate should re-confirm after pilot.
- Whether `interview` should ever roll into overall — currently
  excluded by `MASTERY_OVERALL_INTERVIEW=0`. Keep zero default;
  document the env override path.
