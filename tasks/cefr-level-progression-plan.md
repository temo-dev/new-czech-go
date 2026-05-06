# Plan — V21 CEFR Level Progression (A0 → B1)

Source spec:    `docs/specs/cefr-level-progression.md`
UX spec:        `docs/specs/cefr-level-progression-ux.md`
Idea:           `docs/ideas/cefr-level-progression.md`
SPEC summary:   `SPEC.md` § V21

---

## Architecture Decisions

**Reuse V19 mastery, never duplicate aggregation.**
`LevelService` consumes the existing `SkillMasteryStore` + `MasteryConfig`
(V19). Gating math is a thin layer that reads mastery rows, applies
`LEVEL_MASTERY_THRESHOLD_PCT` and `LEVEL_COVERAGE_THRESHOLD_PCT`, and
returns booleans. No new aggregation tables.

**Server is sole authority for unlock state.**
Client never recomputes `promotion_unlocked` or `unlock_state`. All
gating fields are server-derived in `GET /v1/users/me/level-progress`
and `GET /v1/courses(/:id)`. This removes drift risk and makes
threshold tuning a config-only change.

**Promotion is atomic at scoring boundary, not in client.**
The post-scoring hook (mirrors V19 mastery-updater pattern) runs in
the same transaction as the final attempt persist. On pass, it appends
to `users.unlocked_levels` and updates `current_level`. Idempotent —
replaying the hook with the same `promotion_attempt_id` is a no-op.

**Reuse MockTest infra for placement + promotion.**
No `PromotionTest` entity. `mock_tests.is_promotion`,
`mock_tests.is_placement`, `mock_tests.target_level` are flags. The
placement and promotion runners reuse `full_exam_sessions` +
existing scoring path verbatim.

**Existing users backfilled to A2 on first login.**
Idempotent backfill in `users` repository read path: if
`current_level` is empty (legacy row), populate to `a2` +
`unlocked_levels = {a0,a1,a2}`. Avoids one-shot migration risk and
lets the same code branch handle new + migrated users.

**Layout follows V19 convention, not a new `internal/level/` package.**
Files split across `contracts/`, `store/`, `processing/`, `httpapi/` —
matches the V19 mastery layout. (The original spec mentioned
`internal/level/` but repo convention places handler + deps inside
`httpapi/`, store inside `store/`, hooks inside `processing/`. Plan
follows convention, spec to be reconciled at end of slice.)

**B1 content seeding is a separate concern.**
This slice ships the **mechanism**. B1 module/exercise authoring is
tracked outside the plan. Slice can ship and demo with B1 placeholder
courses + a single `is_promotion=true, target_level=b1` mock authored
in CMS.

---

## Dependency Graph

```
[A] Schema migrations + config loader
        │
        ├──► [B1] LevelStore (read/write users.current_level, unlocked_levels)
        ├──► [B2] PromotionAttemptsStore
        │           │
        │           └──► [B3] LevelService (gating math, consumes V19 SkillMasteryStore)
        │                    │
        │                    ├──► [B4] LevelProgress handler (GET /v1/users/me/level-progress)
        │                    ├──► [B5] Placement handlers (start + complete)
        │                    ├──► [B6] Promotion handler (POST /v1/promotion-attempts)
        │                    └──► [B7] Course handler modifications (level filter, unlock_state, demo gating)
        │                                  │
        │                                  └──► [B8] Post-scoring hook (atomic promotion on pass)
        │
        ├──► [C] CMS form fields (level on Course, flags on MockTest, demo picker)
        │
        └──► [D] Flutter API client + screens + widgets
                       │
                       └──► [E] E2E smoke + manual TestFlight + verify
```

Critical path: **A → B1/B2 → B3 → (B4..B8) → D → E**.
Parallelizable: **C** can land any time after A; **D** widgets can be
mocked against contracts before B is fully wired.

---

## Vertical Slicing Strategy

Each task owns **one user-visible behavior end-to-end** wherever
possible. Pure infra tasks (schema, config) are minimized and
front-loaded so subsequent tasks can each light up one route or one
screen. CMS tasks are grouped because they are a small surface (3
field additions) and shipping them all in one increment matches the
form-field convention.

---

## Phase A — Schema + Config (0.5 ngày)

### V21-A1 — Schema migrations

- **Files:**
  - `backend/internal/store/postgres_migrate.go` (modify)
  - `backend/internal/store/promotion_attempts_store.go` (new — `CREATE TABLE`)
- **AC:**
  - `addColumnIfMissing` adds: `courses.level`, `users.current_level`,
    `users.unlocked_levels`, `users.placement_taken_at`,
    `mock_tests.is_promotion`, `mock_tests.is_placement`,
    `mock_tests.target_level`.
  - Index `courses_level_idx` created.
  - `promotion_attempts` table created idempotently.
  - CHECK constraint `mock_tests_promotion_target_required` added.
  - Existing courses backfilled to `a2`. Existing users get `a2` +
    `{a0,a1,a2}` on next read (handled in B1, not here).
- **Verify:** `make backend-build` passes. Restart backend against an
  existing DB does not error. New `TestMigrate_V21_*` integration test
  verifies columns exist.
- **Size:** M

### V21-A2 — Config loader

- **Files:**
  - `backend/internal/config/level.go` (new)
  - `backend/internal/config/level_test.go` (new)
- **AC:**
  - `LoadLevelConfig()` returns `LevelConfig{MasteryThresholdPct,
    CoverageThresholdPct, PromotionPassPct,
    PromotionCooldownHours, DemoExercisePerLevel,
    PlacementBands}` from env with defaults per spec.
  - `os.Getenv("LEVEL_*")` calls live **only** in this file.
  - PlacementBands parsed from `LEVEL_PLACEMENT_BANDS_JSON` (optional).
- **Verify:** `+3 unit tests` (defaults / overrides / malformed JSON).
- **Size:** S

**[CHECKPOINT V21-A]** `make backend-build && make backend-test` pass with `+3` tests.

---

## Phase B — Backend service + handlers (3 ngày)

### V21-B1 — LevelStore (user_level reads + writes)

- **Files:**
  - `backend/internal/store/user_level_store.go` (new)
  - `backend/internal/store/user_level_store_test.go` (new)
- **AC:**
  - `GetUserLevel(ctx, userID)` returns
    `{CurrentLevel, UnlockedLevels[], PlacementTakenAt}` with **idempotent
    backfill**: if `current_level` is the zero/legacy value,
    write `a2` + `{a0,a1,a2}` and return the populated row.
  - `SetUserLevel(ctx, userID, target)` updates `current_level`,
    appends to `unlocked_levels` (no-op if already present), in a
    single statement (no read-modify-write race).
  - `MarkPlacementTaken(ctx, userID, level, ts)`.
- **Verify:** `+5 unit tests` (fresh user, legacy backfill, double
  promotion idempotent, concurrent SetUserLevel safe via SQL).
- **Size:** M

### V21-B2 — PromotionAttemptsStore

- **Files:**
  - `backend/internal/store/promotion_attempts_store.go` (extend from A1)
  - `backend/internal/store/promotion_attempts_store_test.go` (new)
- **AC:**
  - `CreatePromotionAttempt(ctx, params)` returns row with `id`.
  - `GetLatestFailedAttempt(ctx, userID, targetLevel)` returns the most
    recent unsuccessful attempt or nil — used for cooldown check.
  - `MarkPromotionAttemptResult(ctx, id, passed, scorePct, perSkillPct)`.
- **Verify:** `+4 unit tests` (create, cooldown lookup hit, cooldown
  lookup miss, mark result idempotent).
- **Size:** M

### V21-B3 — LevelService (gating math)

- **Files:**
  - `backend/internal/processing/level_service.go` (new)
  - `backend/internal/processing/level_service_test.go` (new)
  - `backend/internal/contracts/level.go` (new — DTOs)
- **AC:**
  - `LevelService` depends on `SkillMasteryStore` (V19) +
    `LevelConfig` + `UserLevelStore` + `PromotionAttemptsStore`.
  - `ComputeLevelProgress(ctx, userID)` returns
    `contracts.LevelProgressResponse` populated end-to-end including
    `promotion_unlocked` (server-derived).
  - `MapPlacementScoreToLevel(scorePct)` returns level via configured
    bands; caps at `a2` if B1 placeholder content unavailable
    (config flag `LEVEL_PLACEMENT_ALLOW_B1`, default `false` for V21).
  - **No HTTP, no DB writes** in this file — pure orchestration.
- **Verify:** `+8 unit tests` covering: all-skills-pass + coverage =
  unlocked; missing one skill = locked; cooldown active = locked;
  placement band edge cases (29/30/54/55/74/75); B1 cap when content
  flag false.
- **Size:** L

### V21-B4 — LevelProgress endpoint

- **Files:**
  - `backend/internal/httpapi/level_handler.go` (new)
  - `backend/internal/httpapi/level_handler_test.go` (new)
  - `backend/internal/httpapi/server.go` (modify — wire route + `LevelDeps`)
- **AC:**
  - `GET /v1/users/me/level-progress` returns `LevelProgressResponse`
    per spec.
  - 401 when unauthenticated.
  - Cache header `Cache-Control: no-store` (gating must always be
    fresh).
- **Verify:** `+4 integration tests` — fresh user, mid-mastery user,
  ready-to-promote user, in-cooldown user.
- **Size:** M

### V21-B5 — Placement test endpoints

- **Files:**
  - `backend/internal/httpapi/placement_handler.go` (new)
  - `backend/internal/httpapi/placement_handler_test.go` (new)
- **AC:**
  - `POST /v1/users/me/placement-test/start` returns
    `{mock_test_id, full_session_id}`. Rejects with `409
    placement_already_taken` when `placement_taken_at IS NOT NULL`
    and `?force=true` not passed.
  - `POST /v1/users/me/placement-test/complete` reads the
    `full_exam_sessions` score, calls
    `LevelService.MapPlacementScoreToLevel`, writes
    `users.current_level` and `placement_taken_at` atomically. 404
    when session not found or not owned.
  - Placement test selection: server picks the single
    `is_placement=true` mock; if multiple exist, picks the
    most-recently created.
- **Verify:** `+5 integration tests` — fresh start, repeat without
  force, repeat with force, complete happy, complete unauth/wrong
  owner.
- **Size:** L

### V21-B6 — Promotion-attempts endpoint

- **Files:**
  - `backend/internal/httpapi/promotion_handler.go` (new)
  - `backend/internal/httpapi/promotion_handler_test.go` (new)
- **AC:**
  - `POST /v1/promotion-attempts` body `{mock_test_id}`.
  - Pre-checks (in order, returning the **first** matching error):
    1. `404 mock_test_not_found`
    2. `400 mock_test_not_promotion` (mock missing `is_promotion=true`)
    3. `409 level_already_unlocked`
    4. `400 promotion_locked` (gating not met)
    5. `400 cooldown_active` with `retry_after`
  - On success: creates `full_exam_sessions` row, `promotion_attempts`
    row (passed=false initially, score_pct=0), returns 201 with
    `{promotion_attempt_id, full_session_id, target_level}`.
- **Verify:** `+6 integration tests` — happy, each error branch.
- **Size:** L

### V21-B7 — Course endpoint modifications

- **Files:**
  - `backend/internal/httpapi/courses_handler.go` (modify)
  - `backend/internal/httpapi/courses_handler_test.go` (modify)
- **AC:**
  - `GET /v1/courses` accepts `?level=<a0|a1|a2|b1>` filter.
  - Each item gains `unlock_state` (`unlocked` | `demo` | `locked`),
    `level`, `demo_exercise_id` (nullable). Computed via
    `LevelService.ResolveCourseUnlock(userID, course)`.
  - `GET /v1/courses/:id` adds the same fields.
  - Existing payload fields **unchanged** (additive only).
  - `GET /v1/exercises/:id` returns `403 level_locked` when caller's
    `current_level` does not include the course's level **and** the
    exercise is not the course's `demo_exercise_id`. Demo attempts:
    backend tags the attempt with `is_demo=true` so V19
    mastery-updater can skip aggregate writes (next task).
- **Verify:** `+5 integration tests` — locked block, demo allowed, unlocked
  passes, list filter, response additivity.
- **Size:** L

### V21-B8 — Atomic promotion hook + demo skip

- **Files:**
  - `backend/internal/processing/mastery_updater.go` (modify — add
    `is_demo` skip)
  - `backend/internal/processing/level_promotion.go` (new)
  - `backend/internal/processing/level_promotion_test.go` (new)
  - `backend/internal/store/persist_attempt_feedback.go` (modify — call
    promotion hook after mastery write)
- **AC:**
  - Mastery-updater skips writes when `attempt.is_demo == true`.
  - Promotion hook: when the persisting attempt belongs to a
    `full_exam_session` linked to a `promotion_attempts` row,
    re-evaluate gating and (in the same transaction):
    - Update `promotion_attempts.passed`, `score_pct`, `per_skill_pct`.
    - On pass: call `UserLevelStore.SetUserLevel(target)`.
  - Idempotent — replaying with the same `promotion_attempt_id`
    leaves DB unchanged.
- **Verify:** `+5 unit tests` — demo skip, promotion pass write,
  promotion fail write, replay idempotency, non-promotion attempt
  untouched.
- **Size:** L

**[CHECKPOINT V21-B]** `make backend-build && make backend-test` pass; `+45` backend tests.

---

## Phase C — CMS authoring (1 ngày)

### V21-C1 — Course form `Level` field + demo picker

- **Files:**
  - `cms/components/course-form/CourseForm.tsx` (modify)
  - `cms/components/course-form/LevelField.tsx` (new)
  - `cms/components/course-form/DemoExerciseField.tsx` (new)
  - `cms/lib/api/courses.ts` (modify)
  - `cms/components/__tests__/course-form-level.test.tsx` (new)
- **AC:**
  - `LevelField`: `<select>` of A0/A1/A2/B1 with inline VI labels per
    AGENTS.md form-field convention. Defaults to `a2`.
  - `DemoExerciseField`: dropdown of exercises in the course's first
    module; nullable. Hidden when course is at the system's lowest
    level (no upper level needs a demo).
  - `coursePayload` carries new fields.
- **Verify:** `+3 Vitest`.
- **Size:** M

### V21-C2 — MockTest form promotion + placement flags

- **Files:**
  - `cms/components/mock-test-form/MockTestForm.tsx` (modify)
  - `cms/components/mock-test-form/PromotionFlagsField.tsx` (new)
  - `cms/lib/api/mockTests.ts` (modify)
  - `cms/components/__tests__/mock-test-form-promotion.test.tsx` (new)
- **AC:**
  - Two checkboxes (`is_promotion`, `is_placement`) — mutually
    exclusive (toggling one clears the other).
  - When `is_promotion=true`: `target_level` select appears
    (required).
  - Inline VI strings; payload carries new fields.
- **Verify:** `+3 Vitest` — mutex, target required when promotion,
  payload shape.
- **Size:** M

**[CHECKPOINT V21-C]** `make cms-lint && make cms-build && cd cms && npm test` pass; `+6` Vitest.

---

## Phase D — Flutter (3.5 ngày)

### V21-D1 — Models + level utils

- **Files:**
  - `flutter_app/lib/models/level.dart` (new)
  - `flutter_app/lib/shared/util/level.dart` (new)
  - `flutter_app/lib/models/course.dart` (modify — add `level`,
    `unlockState`, `demoExerciseId`)
  - `flutter_app/test/level_model_test.dart` (new)
- **AC:**
  - `Level` enum + `levelLabel(Level)` + `levelOrder(Level)` +
    `nextLevel(Level)`.
  - `LevelProgressResponse` model parses backend payload including
    nested `skill_mastery` map.
  - `Course` model parses `level`, `unlock_state` (`unlocked` |
    `demo` | `locked`), `demo_exercise_id`.
- **Verify:** `+4 unit tests` — parse all states + enum round-trip.
- **Size:** M

### V21-D2 — `LevelApi` client

- **Files:**
  - `flutter_app/lib/core/api/level_api.dart` (new)
  - `flutter_app/lib/core/api/level_api_test.dart` (new)
- **AC:**
  - Methods: `fetchLevelProgress()`, `startPlacement()`,
    `completePlacement()`, `createPromotionAttempt(mockTestId)`.
  - Tolerates flat `{"error": "<code>"}` envelopes (V20.1 hotfix
    pattern).
- **Verify:** `+4 unit tests` — happy + each error envelope.
- **Size:** M

### V21-D3 — `LevelBadge` widget

- **Files:**
  - `flutter_app/lib/features/home/widgets/level_badge.dart` (new)
  - `flutter_app/test/widgets/level_badge_test.dart` (new)
- **AC:**
  - Renders chip + 4-dot ladder per UX spec.
  - Uses `AppColors.primaryContainer` / `onPrimaryContainer` /
    `success` / `surfaceContainerHighest`.
  - Tap target ≥48dp; `Semantics(label: ...)` reads current + studying.
  - Reduced-motion: skip any pulse.
- **Verify:** `+3 widget tests` — render at A0/A1/A2/B1, semantics
  label, tap callback.
- **Size:** S

### V21-D4 — `LevelProgressRing` widget

- **Files:**
  - `flutter_app/lib/features/home/widgets/level_progress_ring.dart` (new)
  - `flutter_app/test/widgets/level_progress_ring_test.dart` (new)
- **AC:**
  - 6 arcs from `LevelProgressResponse.skillMastery`.
  - Arc colors via `AppColors.scoreExcellent/Good/Fair/Poor` (existing
    scoreband logic).
  - Center label `"<current> → <next>"` + `"<percent>% sẵn sàng"`.
  - Pulse animation when `promotionUnlocked == true`; respects
    `MediaQuery.disableAnimations`.
- **Verify:** `+4 widget tests` — partial mastery, all-pass triggers
  pulse, reduced-motion fallback, copy.
- **Size:** L

### V21-D5 — `PromotionBanner` widget

- **Files:**
  - `flutter_app/lib/features/home/widgets/promotion_banner.dart` (new)
  - `flutter_app/test/widgets/promotion_banner_test.dart` (new)
- **AC:**
  - Shows only when `promotionUnlocked == true` and target level
    not yet unlocked.
  - Sticky home card; CTA navigates to `PreExamScreen` with the
    promotion mock test ID.
- **Verify:** `+2 widget tests` — visibility + CTA payload.
- **Size:** S

### V21-D6 — `LockedCourseSheet` + `CourseListScreen` lock state

- **Files:**
  - `flutter_app/lib/features/courses/widgets/locked_course_sheet.dart` (new)
  - `flutter_app/lib/features/courses/course_list_screen.dart` (modify)
  - `flutter_app/test/widgets/locked_course_sheet_test.dart` (new)
- **AC:**
  - Locked card per UX spec — Lucide padlock SVG, mastery delta
    progress bar, ghost demo CTA.
  - Tapping locked card opens bottom sheet with the same delta + a
    primary "Tiếp tục luyện" CTA back to lower-level course.
  - Demo CTA navigates straight into the demo exercise (no mastery
    write — backend B7/B8 enforce, client just opens normally).
- **Verify:** `+3 widget tests` — locked render, demo CTA dispatch,
  sheet opens.
- **Size:** M

### V21-D7 — Onboarding flow (Welcome + Placement Result)

- **Files:**
  - `flutter_app/lib/features/onboarding/welcome_screen.dart` (new)
  - `flutter_app/lib/features/onboarding/placement_result_screen.dart` (new)
  - `flutter_app/lib/router.dart` (modify — gate first launch)
  - `flutter_app/test/widgets/welcome_screen_test.dart` (new)
  - `flutter_app/test/widgets/placement_result_screen_test.dart` (new)
- **AC:**
  - First launch (when `placementTakenAt == null`) routes to Welcome
    → placement test (existing `MockTestRunner`) → result screen →
    home.
  - Welcome offers "Bắt đầu kiểm tra" + "Bỏ qua" (skip → A0).
  - Placement result animates assigned level reveal; respects
    reduced-motion.
- **Verify:** `+4 widget tests`.
- **Size:** L

### V21-D8 — Promotion exam flow (PreExam + Result pass/fail)

- **Files:**
  - `flutter_app/lib/features/promotion/pre_exam_screen.dart` (new)
  - `flutter_app/lib/features/promotion/promotion_result_screen.dart` (new)
  - `flutter_app/test/widgets/pre_exam_screen_test.dart` (new)
  - `flutter_app/test/widgets/promotion_result_pass_test.dart` (new)
  - `flutter_app/test/widgets/promotion_result_fail_test.dart` (new)
- **AC:**
  - PreExam: rules, time, retake policy, confirm/cancel CTAs.
  - Result-pass: success gradient, badge spring drop-in (or fade
    fallback), explore + home CTAs, single heavy haptic on enter.
  - Result-fail: neutral surface, diagnostic table per skill, live
    cooldown timer (24h), deep-link CTA to weakest skill course.
- **Verify:** `+5 widget tests`.
- **Size:** L

### V21-D9 — Home wiring + ARB strings

- **Files:**
  - `flutter_app/lib/features/home/home_screen.dart` (modify)
  - `flutter_app/lib/features/home/state/level_progress_provider.dart` (new)
  - `flutter_app/lib/l10n/app_vi.arb` (modify — add keys per UX spec)
  - `flutter_app/lib/l10n/app_en.arb` (modify — match key count)
  - `flutter_app/test/widgets/home_screen_v21_test.dart` (new)
- **AC:**
  - Home embeds `LevelBadge` + `LevelProgressRing` +
    `PromotionBanner` + existing `Continue learning` card + course list.
  - Provider re-fetches `level-progress` on `pop-back` (V20.1
    `HomeProgressCard.refresh()` pattern).
  - VI = EN ARB key count.
- **Verify:** `+3 widget tests`; `make flutter-analyze` no missing-l10n.
- **Size:** M

**[CHECKPOINT V21-D]** `make flutter-analyze && make flutter-test` pass; `+32` widget tests; manual TestFlight smoke (placement → first exercise → home).

---

## Phase E — End-to-end + smoke + verify (1 ngày)

### V21-E1 — Smoke target

- **Files:**
  - `Makefile` (modify — add `smoke-promotion-flow`)
  - `scripts/smoke_promotion_flow.sh` (new) **or** `tests/level_flow_test.go` (new — preferred for stability)
- **AC:**
  - End-to-end via API: signup → skip placement → seed enough
    attempts to clear thresholds → call `level-progress` and confirm
    `promotion_unlocked=true` → submit promotion attempt with passing
    answers → confirm `current_level=b1` and B1 courses unlocked.
  - Also exercises the failing path with cooldown verification.
- **Verify:** `make smoke-promotion-flow` exits 0.
- **Size:** L

### V21-E2 — Manual TestFlight acceptance

- Per UX spec checklist:
  - MAN-1: First launch onboarding routes correctly; skip = A0.
  - MAN-2: Placement test 12-min run sets correct level via bands.
  - MAN-3: Locked B1 course shows padlock + delta + demo CTA.
  - MAN-4: Demo exercise opens, completes, no mastery write
    (verify via `level-progress` no change).
  - MAN-5: Promotion banner appears when thresholds met (manual
    seeding via dev tools).
  - MAN-6: Promotion pass → celebration → B1 unlocked instantly on
    return to home.
  - MAN-7: Promotion fail → diagnostic table + live cooldown timer
    counts down.
  - MAN-8: Existing user (pre-V21 backfill) lands on home with
    `current_level=a2`, sees Settings opt-in placement re-test.
  - MAN-9: Reduced-motion mode disables pulse, confetti, badge spring
    without breaking layout.
  - MAN-10: VoiceOver reads locked card delta + CTAs correctly.

### V21-E3 — `make verify` final

- **AC:** Backend `+45`, Flutter `+32`, CMS `+6`. Full `make verify`
  green. No regression in V19/V20 progress endpoints or home UI.

**[CHECKPOINT V21-FINAL]**
- [ ] Backend test target ≥ 615 (current 570 + 45)
- [ ] Flutter test target ≥ 298 (current 266 + 32)
- [ ] CMS test target ≥ 127 (current 121 + 6)
- [ ] MAN-1 .. MAN-10 pass on TestFlight
- [ ] No regression: V19 `GET /v1/users/me/progress` payload byte-identical
- [ ] No regression: V20 home progress card refresh still works
- [ ] Pre-V21 users land on `current_level=a2` with all lower levels unlocked
- [ ] CMS authoring of one A2-promotion mock + one B1 course succeeds
- [ ] `SPEC.md` § V21 path layout reconciled with actual layout
  (handler in `httpapi/`, store in `store/`, hook in `processing/`)
- [ ] `CHANGELOG.md` V21 entry written with file changes + final test counts

---

## Risk Register

| Risk | Mitigation |
|---|---|
| Atomic promotion hook leaks transactions | Hook lives inside the same `persist_attempt_feedback` tx; covered by replay test in B8 |
| Threshold tuning requires migration | Thresholds are env-only and read on every request — no backfill ever required |
| Existing user disruption from backfill | Idempotent backfill on read in B1; covered by tests; never blocks login |
| B1 content gap makes locked UI feel hollow | Demo exercise per upper level provides discovery; CMS can author 1 B1 placeholder course before launch |
| MockTest reuse couples promotion to scoring changes | E2E test in E1 catches regression; risk register update if future scoring change touches promotion path |
| Placement test drop-off >40% | Skip is supported, defaults to A0; instrument start/complete metrics in dev console for first 10 testers (out of slice scope but flagged) |

## Out of Slice (do not start)

- A0 / A1 module + exercise authoring
- Per-skill CEFR per learner (Direction B in idea note)
- Adaptive promotion exam generation
- Auto-demotion on inactivity
- Certificate / badge sharing
- Re-onboarding wizard for existing users beyond a Settings opt-in
