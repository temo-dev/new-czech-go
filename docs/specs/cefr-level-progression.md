# V21 — CEFR Level Progression (A0 → B1)

> Pair docs:
> - `docs/ideas/cefr-level-progression.md` — idea note (decided 2026-05-06)
> - `docs/specs/cefr-level-progression-ux.md` — screen inventory + flow + tokens
>
> Status: **Spec frozen, awaiting plan + impl.**

## Objective

Pivot the product from "A2-only sprint" to a level-gated CEFR ladder
(A0 → A1 → A2 → B1). Each learner has a `current_level`. Content above
that level is locked behind a **2-gate promotion**: skill mastery
threshold unlocks a **promotion exam** (a `MockTest` flagged
`is_promotion=true`); passing the exam promotes the learner.

This spec covers MVP = **A2 + B1** only. A0 / A1 are out-of-scope for
content; the schema and gating mechanism must accommodate them without
re-architecture.

## Non-Goals

- Skill-wise CEFR per learner (Direction B in idea note). Future slice.
- Adaptive promotion exam generation. MockTest reuse only.
- Auto-demotion on inactivity.
- Certificate / badge sharing.
- A0 / A1 content authoring (defer until learner demand observed).

## Schema Changes

All migrations use `addColumnIfMissing()` per backend conventions.

### `courses`

```sql
ALTER TABLE courses
  ADD COLUMN level TEXT NOT NULL DEFAULT 'a2'
    CHECK (level IN ('a0','a1','a2','b1'));
CREATE INDEX courses_level_idx ON courses(level);
```

Existing courses backfilled to `a2` (matches current product scope).

### `users`

```sql
ALTER TABLE users
  ADD COLUMN current_level TEXT NOT NULL DEFAULT 'a0'
    CHECK (current_level IN ('a0','a1','a2','b1'));
ALTER TABLE users
  ADD COLUMN unlocked_levels TEXT[] NOT NULL DEFAULT ARRAY['a0'];
ALTER TABLE users
  ADD COLUMN placement_taken_at TIMESTAMPTZ NULL;
```

**Migration policy for existing users**: pre-V21 users get
`current_level='a2'`, `unlocked_levels=ARRAY['a0','a1','a2']`,
`placement_taken_at=NULL`. They can opt into a placement re-test from
Settings.

### `mock_tests`

```sql
ALTER TABLE mock_tests
  ADD COLUMN is_promotion BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE mock_tests
  ADD COLUMN is_placement BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE mock_tests
  ADD COLUMN target_level TEXT NULL
    CHECK (target_level IN ('a0','a1','a2','b1'));
-- Promotion exam must declare its target level; placement does not.
ALTER TABLE mock_tests
  ADD CONSTRAINT mock_tests_promotion_target_required
  CHECK ((is_promotion = FALSE) OR (target_level IS NOT NULL));
```

### `promotion_attempts` (new table)

```sql
CREATE TABLE promotion_attempts (
  id              UUID PRIMARY KEY,
  user_id         UUID NOT NULL REFERENCES users(id),
  mock_test_id    UUID NOT NULL REFERENCES mock_tests(id),
  source_level    TEXT NOT NULL,
  target_level    TEXT NOT NULL,
  full_session_id UUID NOT NULL REFERENCES full_exam_sessions(id),
  passed          BOOLEAN NOT NULL,
  score_pct       NUMERIC(5,2) NOT NULL,
  per_skill_pct   JSONB NOT NULL,        -- {"noi":72.5,"viet":68.0,...}
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX promotion_attempts_user_idx
  ON promotion_attempts(user_id, created_at DESC);
```

Cooldown: server rejects new promotion attempt for the same
`(user_id, target_level)` if a `promotion_attempts` row exists with
`created_at > NOW() - INTERVAL '24 hours'` and `passed = FALSE`.

## Configuration (defaults — overridable via env)

| Env var | Default | Meaning |
|---|---|---|
| `LEVEL_MASTERY_THRESHOLD_PCT` | `70.0` | Min mastery per skill to unlock promotion |
| `LEVEL_COVERAGE_THRESHOLD_PCT` | `80.0` | Min `% of modules with at least one attempt` |
| `LEVEL_PROMOTION_PASS_PCT` | `60.0` | Score per section to pass promotion |
| `LEVEL_PROMOTION_COOLDOWN_HOURS` | `24` | Cooldown between failed attempts |
| `LEVEL_DEMO_EXERCISE_PER_LEVEL` | `1` | Number of demo exercises shown per locked upper level |

Place loaders in `backend/internal/config/level.go` (new file). Do
**not** spread `os.Getenv` calls across handlers.

## API Contracts

All routes versioned under `/v1`. Align with
`docs/specs/api-contracts.md`.

### `GET /v1/users/me/level-progress`

Returns the gating state for the home screen and promotion banner.

```json
{
  "current_level": "a2",
  "unlocked_levels": ["a0","a1","a2"],
  "next_level": "b1",
  "placement_taken_at": "2026-05-01T08:12:00Z",
  "skill_mastery": {
    "noi":      { "pct": 78.0, "threshold_pct": 70.0, "passes": true },
    "viet":     { "pct": 65.0, "threshold_pct": 70.0, "passes": false },
    "nghe":     { "pct": 80.0, "threshold_pct": 70.0, "passes": true },
    "doc":      { "pct": 74.0, "threshold_pct": 70.0, "passes": true },
    "tu_vung":  { "pct": 71.0, "threshold_pct": 70.0, "passes": true },
    "ngu_phap": { "pct": 70.0, "threshold_pct": 70.0, "passes": true }
  },
  "coverage_pct": 82.0,
  "coverage_threshold_pct": 80.0,
  "all_skills_pass": false,
  "promotion_unlocked": false,
  "promotion_test_id": "mt_b1_promote_v1",
  "promotion_cooldown_until": null
}
```

`promotion_unlocked = all_skills_pass AND coverage_pct >= coverage_threshold_pct AND cooldown_until IS NULL`.

### `POST /v1/promotion-attempts`

```json
// Request
{ "mock_test_id": "mt_b1_promote_v1" }

// Response 201
{
  "promotion_attempt_id": "pa_...",
  "full_session_id": "fes_...",
  "target_level": "b1"
}

// Errors
400 { "error": "promotion_locked" }     // mastery/coverage not met
400 { "error": "cooldown_active",
      "retry_after": "2026-05-07T12:00:00Z" }
404 { "error": "mock_test_not_found" }
409 { "error": "level_already_unlocked" }
```

The endpoint creates a `full_exam_sessions` row reusing the existing
exam runner. On submit, the existing scoring path writes back; a
post-scoring hook updates `promotion_attempts.passed/score_pct` and,
if passed, atomically:

```sql
UPDATE users
SET current_level = $target,
    unlocked_levels = array_append(unlocked_levels, $target)
WHERE id = $user AND NOT ($target = ANY(unlocked_levels));
```

### `GET /v1/courses` (modify)

- Add `?level=<a0|a1|a2|b1>` filter (optional).
- Default behavior: returns all courses. Add per-item field
  `unlock_state: "unlocked" | "demo" | "locked"` derived from caller's
  `current_level` (requires auth).
- Locked courses still return module/exercise counts (for delta UI),
  but exercise endpoints reject access (`403 level_locked`) except for
  the demo exercise flagged on the course.

### `GET /v1/courses/:id` (modify)

- Add `unlock_state`, `demo_exercise_id` (nullable), `level`.

### `POST /v1/users/me/placement-test/start`

Returns the placement `MockTest` ID + `full_session_id`. Rejects if
`placement_taken_at IS NOT NULL` unless `?force=true`.

### `POST /v1/users/me/placement-test/complete`

Triggered by client on submit; reads the `full_exam_sessions` score,
maps to a level (band table below), writes
`users.current_level` and `placement_taken_at`.

| Total score | Assigned level |
|---|---|
| < 30 | `a0` |
| 30–54 | `a1` |
| 55–74 | `a2` |
| ≥ 75 | `b1` (only assignable if B1 content exists; else cap at `a2`) |

(Bands tunable via env `LEVEL_PLACEMENT_BANDS_JSON` for future calibration.)

## Backend Layout

| File | Responsibility |
|---|---|
| `backend/internal/level/service.go` | Pure logic: thresholds, gating, level math |
| `backend/internal/level/repository.go` | DB reads/writes for users + promotion_attempts |
| `backend/internal/level/handlers.go` | HTTP wiring for the 4 new endpoints |
| `backend/internal/level/deps.go` | `LevelDeps` struct, mirrors `MasteryDeps` pattern (V19) |
| `backend/internal/config/level.go` | Env loader for thresholds + cooldown |
| `backend/internal/store/postgres_migrate.go` | New `addColumnIfMissing` calls + `promotion_attempts` create |
| `backend/internal/processing/...` | **No prompt changes**. Reuse `MasteryAggregate` (V19) |

`LevelService` depends on `MasteryDeps` (V19) for skill mastery reads.
**Do not duplicate mastery aggregation logic.**

## CMS Changes

| File | Change |
|---|---|
| `cms/components/course-form/*` | Add `Level` select (a0/a1/a2/b1) |
| `cms/components/mock-test-form/*` | Add `is_promotion`, `is_placement`, `target_level` fields. Mutually exclusive: a mock cannot be both placement and promotion |
| `cms/components/course-form/DemoExerciseField.tsx` | New — pick 1 exercise to mark as the level-locked demo |
| `cms/lib/api/courses.ts` | Pass new fields through |

CMS keeps inline VI strings per AGENTS.md convention.

## Flutter Changes

| File / Path | Change |
|---|---|
| `flutter_app/lib/core/api/level_api.dart` | New client for the 4 endpoints |
| `flutter_app/lib/features/onboarding/welcome_screen.dart` | New |
| `flutter_app/lib/features/onboarding/placement_result_screen.dart` | New |
| `flutter_app/lib/features/home/home_screen.dart` | Add `LevelBadge` + `LevelProgressRing` + `PromotionBanner` |
| `flutter_app/lib/features/home/widgets/level_badge.dart` | New |
| `flutter_app/lib/features/home/widgets/level_progress_ring.dart` | New |
| `flutter_app/lib/features/home/widgets/promotion_banner.dart` | New |
| `flutter_app/lib/features/courses/course_list_screen.dart` | Add lock/demo states |
| `flutter_app/lib/features/courses/widgets/locked_course_sheet.dart` | New |
| `flutter_app/lib/features/promotion/pre_exam_screen.dart` | New |
| `flutter_app/lib/features/promotion/promotion_result_screen.dart` | New (pass + fail variants) |
| `flutter_app/lib/l10n/app_vi.arb` + `app_en.arb` | New keys (see UX spec) |
| `flutter_app/lib/shared/util/level.dart` | `levelLabel`, `levelOrder`, helpers |

Reuse `AppColors`, `AppSpacing`, `AppTypography`. **No new style
system.** Icons via Lucide vector pack already in repo.

## Behavior Rules

- **Onboarding**: every new user routed through `WelcomeScreen` →
  placement test. Skip → `current_level='a0'`. Submit →
  `placement-test/complete` writes assigned level.
- **Existing users (migration)**: backfilled to `a2` with all lower
  levels unlocked. `placement_taken_at = NULL`. Settings shows "Làm
  bài kiểm tra phân loại" CTA.
- **Locked content access**: backend `403 level_locked` for
  exercise-level reads on locked courses. Exception: the demo
  exercise per upper level (resolved by `Course.demo_exercise_id`).
  Demo attempts **do not** write to mastery aggregates.
- **Promotion gate** evaluated server-side on every
  `level-progress` read. Client never decides unlock state.
- **Promotion fail** does NOT decrement mastery. Only writes a
  `promotion_attempts` row + sets cooldown.
- **Promotion pass** is atomic: scoring write + level promotion in
  the same transaction (or compensating retry). Idempotent — replay
  must not double-add level.
- **Demo exercise resolution**: `Course.demo_exercise_id` is a single
  exercise per upper-level course chosen by CMS author. Default if
  unset: server picks the lowest-position exercise in the course's
  first module.

## V19 Compatibility

- `GET /v1/users/me/progress` (V19) **unchanged** payload. Returns
  global mastery across all attempts. Level-aware gating lives in the
  new `level-progress` endpoint.
- `MasteryAggregate` aggregates per `skill_kind` regardless of course
  level. Level-progress endpoint **filters mastery by attempts whose
  course matches `users.current_level`** when computing
  `skill_mastery`. This means promoting a learner does not "reset"
  their progress — it shifts the denominator to the new level.

## Boundaries

| Always | Ask first | Never |
|---|---|---|
| Reuse `AppColors` tokens, Lucide icons | Add A0/A1 placeholder courses | Introduce a new style system (claymorphism, etc.) |
| Use existing `MockTestRunner` for placement + promotion | Decrement mastery on fail | Add a new exam entity/scoring path |
| Write level math in `backend/internal/level/service.go` | Change thresholds away from defaults | Inline LLM prompt strings (see AGENTS.md) |
| Localize new strings via ARB | Tweak placement bands | Skip placement test entirely (must be skippable, not removable) |
| Filter mastery by current_level in `level-progress` | Auto-demote inactive learners | Allow client to compute unlock state |

## Verification Expectations

| Layer | Commands | Pass criteria |
|---|---|---|
| Backend unit | `make backend-test` | +20 tests min covering: gating math, cooldown, placement band mapping, atomic promotion, V19 mastery still passing |
| Backend integration | new `tests/level_flow_test.go` | Full simulate: signup → skip placement → A0 → exercises → mastery → promotion attempt → fail → cooldown → retry → pass → B1 unlocked |
| CMS | `make cms-lint && make cms-build && cd cms && npm test` | +6 Vitest min for new form fields |
| Flutter analyze + test | `make flutter-analyze && make flutter-test` | +12 widget tests min for `LevelBadge`, `LevelProgressRing`, `LockedCourseSheet`, `PromotionResultScreen` (pass + fail) |
| Smoke | new `make smoke-promotion-flow` | End-to-end via API: placement → mastery seed → promotion pass |
| Full | `make verify` | All green |

## Avoid in V21

- ❌ Skill-wise CEFR per learner (defer)
- ❌ Adaptive promotion exam generation
- ❌ A0/A1 content authoring inside this slice
- ❌ Auto-demotion / level expiry
- ❌ Certificate/badge sharing
- ❌ Per-screen ad-hoc colors (must use `AppColors`)
- ❌ Emoji icons (use Lucide SVG)
- ❌ Client-side gate computation (server is source of truth)
- ❌ Inlining prompt/model strings (see `llm_prompts.go` rule)
- ❌ Decrementing mastery on promotion fail
- ❌ A new `PromotionTest` entity (use `MockTest` flags)

## Open Questions (must resolve in plan, not at impl time)

1. Where exactly does the post-scoring hook for promotion live —
   inside the existing scoring pipeline, or a separate listener? Lean
   toward a sync hook in the same transaction for atomicity.
2. Migration timing for existing users — run on next login or as a
   one-shot? Lean: idempotent backfill on `users` row read.
3. Should the placement test result be **revealable to the learner**
   (showing per-skill bands) or only the assigned level? Lean: assigned
   level only on V21; per-skill detail in a later "diagnostic profile"
   slice.
4. How does the existing `GET /v1/modules/:id/skills` (V8 computed
   `SkillSummary[]`) interact with locked courses? Confirm it stays
   accessible for locked courses so the lock UI can show skill
   coverage previews.
5. What is the minimum content seeding needed to ship V21 to one
   learner — does the placement test reuse existing A2 mocks, or do we
   author a new `is_placement=true` mock? Lean: author a new short
   placement mock (15 items × 4 skills) before V21 GA.
