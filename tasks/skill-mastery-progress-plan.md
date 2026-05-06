# Plan: Skill Mastery & Progress (V19 backend + V20 Flutter)

Source: `docs/specs/skill-mastery-progress.md`
Idea: `docs/ideas/skill-mastery-progress.md`

---

## Architecture Decision

**Aggregate at persist boundary, not inside scoring.**
The scoring pipeline (`processing/processor.go`,
`processing/objective_scorer.go`,
`processing/llm_feedback.go`) stays pure. A new `mastery.Update`
side-effect runs synchronously after `store.PersistAttemptFeedback`.

**Single 4-band readiness vocabulary.**
LLM and objective scorers currently disagree
(`weak/ok/strong` vs `not_ready/almost_ready/ready_for_mock/exam_ready`).
This is a P0 prerequisite — aggregate math is meaningless until
both code paths emit the same 4 tokens
(`not_ready / needs_work / almost_ready / ready_for_mock`).

**1 table, no derived materialised views.**
`user_skill_mastery (user_id, skill_kind, module_id)` UNIQUE.
`overall_progress` and `band` are derived on **read** in the HTTP
handler, so weight/band tuning never requires a backfill.

**Backend ships and validates before Flutter.**
V19 lands first; idea file's validation gates run against real
attempt data before V20 UI work begins.

---

## Dependency Graph

```
Phase 0 — Vocab Unify (P0, separate commit)
   │
   ├─ processing/llm_prompts.go (drop exam_ready, add needs_work)
   ├─ processing/llm_feedback.go (normalizeReadinessLevel + ReadinessToScore)
   ├─ processing/objective_scorer.go (re-threshold 0.3/0.6/0.85)
   └─ processing/dictation_processor.go (use shared helper)
        │
        └── existing tests rewritten for 4-band scale
              │
              └── ⬇ Phase 1 starts ─────────────────────

Phase 1 — Mastery Aggregate
   │
   ├─ processing/processing_config.go (NEW — env vars)
   ├─ store/postgres_migrate.go (NEW table)
   ├─ store/postgres_mastery.go (NEW upsert + read)
   │     │
   │     └─ processing/mastery/updater.go (NEW — uses store + config)
   │           │
   │           └─ processing/processor.go (wire updater after persist)
   │
   ├─ contracts/progress.go (NEW types)
   ├─ httpapi/progress_handler.go (NEW handler — uses store + config)
   └─ httpapi/server.go (route)

Phase 2 — Smoke + Validation Hooks
   └─ scripts/smoke/attempt_flow.sh (assert /progress row exists)

Phase 3 — Flutter UI (V20, after V19 ships)
   │
   ├─ core/api/progress_api.dart + progress_models.dart
   │     │
   │     ├─ features/progress/widgets/mastery_bar.dart
   │     ├─ features/progress/widgets/skill_mastery_row.dart
   │     ├─ features/progress/widgets/progress_empty_state.dart
   │     └─ features/progress/widgets/progress_error_state.dart
   │           │
   │           ├─ features/progress/widgets/home_progress_card.dart
   │           │     │
   │           │     └─ features/home/screens/course_list_screen.dart (mount)
   │           │
   │           └─ features/progress/screens/progress_detail_screen.dart
   │                 │
   │                 └─ features/profile/screens/profile_screen.dart (entry tile)
   │
   └─ l10n/app_vi.arb + app_en.arb (24 keys, parity)

Phase 4 — Validation Gates (post-ship gate for V21)
   └─ Manual gates listed in spec § "Validation Gates"
```

**Critical ordering**:
- Phase 0 must merge before Phase 1; `ReadinessToScore` lives in
  `llm_feedback.go` and is the only mapping band → number.
- Phase 1 task `MA-3` (updater) blocks `MA-4` (processor wire);
  `MA-4` blocks `MA-5` (handler) functionally but they can be
  developed in parallel and integration-tested together.
- Phase 3 cannot start until Phase 1 endpoint is reachable on
  staging.

---

## Phase 0 — Vocab Unify (Prerequisite, 1 PR)

### V0-1: Add `needs_work` token + drop `exam_ready` in LLM prompt

**Files changed:** `processing/llm_prompts.go`,
`processing/llm_feedback.go`

- Update `FeedbackSystemPrompt` schema string at line 52:
  `readiness_level MUST be one of: not_ready, needs_work,
  almost_ready, ready_for_mock`.
- Extend `normalizeReadinessLevel` legacy mapping:
  - `weak`, `not_ready` → `not_ready`
  - `ok`, `almost_ready` → `almost_ready` (existing)
  - `strong`, `ready_for_mock`, `exam_ready` → `ready_for_mock`
  - new: empty / unknown → `needs_work` (was `ok`)
- Add `ReadinessToScore(level string) float64` returning
  `0.20 / 0.45 / 0.70 / 0.90 / 0.40` (default).

**Verification:** `go test ./internal/processing -run
TestNormalizeReadiness -v` — extend table to cover all legacy and
new tokens.

### V0-2: Re-threshold objective scorer

**Files changed:** `processing/objective_scorer.go`,
`processing/dictation_processor.go`,
`processing/objective_scorer_test.go`

- Replace `frac >= 0.8 / >= 0.5` with `frac >= 0.85 / >= 0.60 /
  >= 0.30` mapping to the 4 new tokens.
- Extract `ReadinessFromObjective(frac float64) string` into
  `processing/objective_scorer.go` and call from
  `dictation_processor.go` (eliminate `readinessFromDictationScore`
  divergence).
- Update `TestReadinessLevelFromObjective` to a 4-row table.

**Verification:** `go test ./internal/processing -v` clean.

### V0-3: Update LLM fallbacks + processor merge

**Files changed:** `processing/llm_fallbacks.go`,
`processing/processor.go`

- Replace fallback `"ok"` literals (lines 13, 43) with
  `"needs_work"` to match the new vocabulary.
- Sanity-pass `processor.go:189-190 / :256` — confirm
  `merged.ReadinessLevel` is always passed through
  `normalizeReadinessLevel` before being persisted (it already is
  via `llm_feedback.go:164`).

**Verification:** `make backend-test` clean. **`make smoke-attempt-flow`** still passes (no semantic regression for learner UI, since new tokens render via existing l10n keys — verify VI strings exist for `needs_work` in any current Flutter consumer; if missing, add ARB entry as part of this PR).

**Checkpoint 0:** `make backend-build && make backend-test && make smoke-attempt-flow` all green. Single commit:
`refactor(processing): unify readiness vocab to 4 bands`.

---

## Phase 1 — Mastery Aggregate (V19, 1 PR)

### MA-1: Config loader

**Files changed:** new `processing/processing_config.go`

- Define `MasteryConfig` struct: 3 band thresholds + 7 skill
  weights + `EarlyAttemptCap=3`, `EarlyAlpha=0.5`,
  `SteadyAlpha=0.3` constants.
- `LoadMasteryConfig() MasteryConfig` reads env vars per spec
  table; defaults baked in.
- Export package-level singleton `Mastery` initialised in
  `LoadProcessingConfig()` (called once at server boot from
  `httpapi/server.go`).

**Verification:** new test `processing_config_test.go` covers env
override + zero-weight fallback.

### MA-2: Schema migration + store

**Files changed:** `store/postgres_migrate.go`, new
`store/postgres_mastery.go`, new `store/postgres_mastery_test.go`

- Add `CREATE TABLE IF NOT EXISTS user_skill_mastery (...)`
  block per spec § "Data Model".
- Add `CREATE UNIQUE INDEX IF NOT EXISTS
  user_skill_mastery_uniq` on `(user_id, skill_kind, module_id)`.
- Add covering index `user_skill_mastery_user_updated` on
  `(user_id, updated_at desc)`.
- `MasteryStore` methods:
  - `GetForKey(ctx, user_id, skill_kind, module_id) (Row, ok,
    err)`
  - `Upsert(ctx, Row) error` — `INSERT ... ON CONFLICT (...) DO
    UPDATE` setting all mutable fields.
  - `ListForUser(ctx, user_id) ([]Row, error)` ordered by
    `(skill_kind, module_id)`.
- Test against the in-repo Postgres fixture (`make backend-test`
  spins it up); cover unique-constraint enforcement and idempotent
  upsert.

**Verification:** `go test ./internal/store -run TestMastery -v`.

### MA-3: Mastery updater

**Files changed:** new `processing/mastery/updater.go`, new
`processing/mastery/updater_test.go`

- `Updater` constructor takes `MasteryStore` + `MasteryConfig`.
- `Update(ctx, attempt) error`:
  1. Resolve `(user_id, skill_kind, module_id)`. `module_id` is
     empty string for `pool=exam`.
  2. `attempt_score = ReadinessToScore(attempt.Feedback
     .ReadinessLevel)`.
  3. Read current row; if `last_attempt_id == attempt.ID`, return
     nil (idempotent).
  4. Compute new mastery using EMA branch (`<3 attempts → 0.5/0.5`,
     else `0.7/0.3`); first attempt → score directly.
  5. Upsert with bumped `attempts_count`,
     `last_attempt_id/at`, `updated_at = now()`.
- Tests cover: first attempt, EMA convergence on 5 strong attempts,
  decay on alternating sequence, idempotency on duplicate
  `attempt.ID`, exam-pool empty `module_id`, missing user (no-op
  with logged warning).

**Verification:** `go test ./internal/processing/mastery -v`.

### MA-4: Wire updater into processor

**Files changed:** `processing/processor.go`,
`processing/processor_test.go`

- Inject `mastery.Updater` into the `Processor` struct.
- After `store.PersistAttemptFeedback`, call
  `updater.Update(ctx, attempt)`. Errors are logged at error level
  with `attempt_id`; do **not** propagate (must not roll back
  attempt completion).
- Existing `processor_test.go` cases pass unchanged with the new
  field default-initialised to a no-op stub when not set.

**Verification:** `go test ./internal/processing -run
TestProcessor -v`.

### MA-5: Progress endpoint + contracts

**Files changed:** new `contracts/progress.go`, new
`httpapi/progress_handler.go`, new
`httpapi/progress_handler_test.go`, `httpapi/server.go`

- Wire types: `Progress`, `SkillProgress`, `ModuleProgress`, plus
  inline `Bands` and `Weights` blobs.
- Handler:
  - Auth: existing JWT middleware; 401 on missing/invalid.
  - `store.ListForUser` → group by `skill_kind` → compute weighted
    `overall_progress` using normalised non-zero weights → return
    serialised `Progress`.
  - Empty user (no rows): return `overall_progress=0`,
    `overall_band=needs_work`, `skills=[]`, plus `bands` +
    `weights` from config.
- Route `GET /v1/users/me/progress` registered in
  `server.go` next to other authenticated user routes.
- Tests cover: 401 unauth, empty user shape, populated weighted
  overall, custom env weights normalised correctly, exam-pool row
  exposed under empty `module_id`.

**Verification:** `go test ./internal/httpapi -run TestProgress
-v`.

### MA-6: Smoke test extension

**Files changed:** `scripts/smoke/attempt_flow.sh` (or whichever
script `make smoke-attempt-flow` runs)

- After completing one attempt, `curl -H "Authorization: Bearer
  $TOKEN" $BASE/v1/users/me/progress` and assert via `jq`:
  - `.skills | length == 1`
  - `.skills[0].attempts_count == 1`
  - `.skills[0].mastery > 0`

**Verification:** `make smoke-attempt-flow` green.

**Checkpoint 1:** `make backend-build && make backend-test &&
make smoke-attempt-flow && make smoke-course-flow` all green. PR
title: `feat(backend): user skill mastery aggregate + progress
endpoint (V19)`.

---

## Phase 2 — Validation Window (no code, between V19 and V20)

Block V20 start until validation gates from spec are at least
**provisionally** met:

- [ ] V19 deployed to staging.
- [ ] Run 30-attempt manual review against teacher rating.
- [ ] Snapshot p95 attempt-persist latency before/after V19.
- [ ] Notebook simulation of 20 attempt sequences against the
      production formula; sanity-check curves.

If gates fail, fix data/formula in Phase 1 before V20.

---

## Phase 3 — Flutter UI (V20, 1 PR)

### UI-1: API client + models

**Files changed:** new `core/api/progress_api.dart`, new
`core/api/progress_models.dart`, new
`test/api/progress_api_test.dart`

- `UserProgress.fromJson` round-trips the `MA-5` shape.
- `ProgressApi.fetch({Cancelable token})` returns
  `Future<UserProgress>`; throws typed `ProgressApiException` on
  HTTP error.
- In-memory cache + `shared_preferences` 24h TTL fallback for
  offline.

**Verification:** `flutter test test/api/progress_api_test.dart`.

### UI-2: `MasteryBar` + `SkillMasteryRow` primitives

**Files changed:** new
`features/progress/widgets/mastery_bar.dart`, new
`features/progress/widgets/skill_mastery_row.dart`, new
`test/widgets/mastery_bar_test.dart`

- `MasteryBar(value, bands, height: 8)` paints fill width based on
  band thresholds returned by API; respects
  `MediaQuery.disableAnimations`.
- `SkillMasteryRow(icon, labelKey, value, attemptsCount,
  lastAttemptAt, onTap)` — 56dp min height, full-row `InkWell`,
  `MergeSemantics` block with descriptive label, percent text uses
  `FontFeature.tabularFigures()`.
- Tests cover: band → colour selection (4 cases), semantics label
  format, reduced-motion path.

**Verification:** `flutter test test/widgets/mastery_bar_test.dart`.

### UI-3: State widgets — empty + error

**Files changed:** new
`features/progress/widgets/progress_empty_state.dart`, new
`features/progress/widgets/progress_error_state.dart`

- Empty state: title + body + CTA button "Bắt đầu học" → pop back
  to course list (caller passes `onCta`).
- Error state: message + retry button.

**Verification:** golden tests optional; analyzer + smoke render in
`HomeScreen`.

### UI-4: `HomeProgressCard` + mount in `HomeScreen`

**Files changed:** new
`features/progress/widgets/home_progress_card.dart`,
`features/home/screens/course_list_screen.dart`,
new `test/widgets/home_progress_card_test.dart`

- Card shows: greeting label, overall bar + percent + band label,
  divider, 7 skill rows (only those returned by API; if API
  returns `<7`, omit missing skills rather than padding zero).
- States: loading skeleton (7 shimmer rows), populated, error,
  empty (delegates to `progress_empty_state.dart`).
- Mounted in `course_list_screen.dart` above the existing course
  grid as a `Sliver` or top widget — preserve existing scroll
  behaviour.
- Widget test covers: loading → populated transition, empty state,
  tap row pushes detail with correct `skill_kind`.

**Verification:** `flutter test test/widgets/home_progress_card
_test.dart`. Manual: 375px width portrait + landscape, light + dark.

### UI-5: `ProgressDetailScreen` + Profile entry

**Files changed:** new
`features/progress/screens/progress_detail_screen.dart`,
`features/profile/screens/profile_screen.dart`, new
`test/screens/progress_detail_screen_test.dart`

- Constructor takes `String? skillKind`. `null` = show all skills
  collapsed, scroll to top; non-null = filter to that skill.
- AppBar: localised title, info action shows formula bottom sheet.
- Body: summary row + module list; pull-to-refresh; same state
  machinery as `HomeProgressCard`.
- `ProfileScreen` adds a list tile above existing settings:
  "Tiến độ học tập" → push `ProgressDetailScreen(skillKind: null)`.

**Verification:** widget test for deep-link to a skill;
`flutter analyze` clean.

### UI-6: l10n keys

**Files changed:** `l10n/app_vi.arb`, `l10n/app_en.arb`

- Add 24 keys per spec § "UI Spec → Required ARB keys".
- Run codegen (`flutter pub run flutter_gen` or whatever the repo
  script is); commit generated file.
- VI=EN key parity check (existing l10n test or a quick `jq` in
  CI).

**Verification:** `make flutter-analyze` clean; key parity test
green.

**Checkpoint 3:** `make flutter-analyze && make flutter-test`.
Manual matrix:

| Device | Light | Dark | Reduced motion | Largest Dynamic Type |
|---|---|---|---|---|
| iPhone SE (375) | ✅ | ✅ | ✅ | ✅ |
| iPhone 14 Pro | ✅ | ✅ | — | — |

PR title: `feat(flutter): home progress card + skill detail screen
(V20)`.

---

## Phase 4 — Validation Gates (post-ship, blocks V21)

Per spec § "Validation Gates". No code; recorded in CHANGELOG.

- [ ] 30-attempt teacher-agreement review ≥ 70%
- [ ] 5-learner pilot interview re module-level guidance
- [ ] 20-sequence notebook curve sanity check
- [ ] Attempt-persist p95 within current SLO

---

## Risks + Mitigations

| Risk | Mitigation |
|---|---|
| Vocab unify breaks existing learner-visible feedback strings | Phase 0 includes ARB sweep for `needs_work`; smoke test surfaces any missing key |
| Sync `mastery.Update` adds unacceptable attempt latency | Validation gate measures p95; if breached, swap to async goroutine fire-and-forget (no schema change required) |
| Empty `module_id` for exam pool collides with future module-`""` rows | UNIQUE index already accommodates; document in spec; CMS validation rejects empty `module_id` for course pool |
| Weight defaults wrong for A2 exam | Configurable via env; pilot interview surfaces miscalibration |
| Backfill skipped → returning users see zero progress | Acceptable; spec § "Rollout" documents this; in-app empty state already addresses UX |
| LLM omits `needs_work` in practice (model bias toward edges) | `objective_scorer_test.go` table verifies all four bands at the boundary; Phase 4 teacher review surfaces if LLM avoids the band |

---

## Out of Scope (will be follow-up slices)

- V21: spaced repetition (`next_review_at` column, scheduler).
- V22: rule-based recommendation engine (`/v1/users/me/next`).
- V23: `confidence_score` once we have data on transcript-noisy
  attempts.
- V24+: ExamReadiness gauge with target-exam config.
