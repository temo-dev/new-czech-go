# Todo — V21 CEFR Level Progression

Plan: `tasks/cefr-level-progression-plan.md`
Spec: `docs/specs/cefr-level-progression.md`
UX:   `docs/specs/cefr-level-progression-ux.md`

---

## Phase A — Schema + Config

- [x] **V21-A1** Schema migrations (`db/migrations/025_v21_cefr_levels.sql`, `postgres_courses_modules_skills.go`, `postgres_users.go`, `postgres_mock_tests.go`, `promotion_attempts_store.go`, `v21_levels_migration_test.go`)
  - **AC:** all columns + index + table + CHECK added; existing courses backfilled `a2`; idempotent
  - **Verify:** `go build ./...` clean; `TestV21LevelsMigration_*` pass (2 tests + 4 subtests); full suite `581` tests
  - **Size:** M
- [x] **V21-A2** `LoadLevelConfig()` env loader (`processing/level_config.go` — placed alongside V19 `processing_config.go` per repo convention; spec said `config/level.go` but no such package exists, processing/ already owns mastery + LLM config)
  - **AC:** sole owner of `LEVEL_*` env reads; defaults per spec; `LEVEL_PLACEMENT_BANDS_JSON` parsed; values clamp to [0,100] / ≥0; `LevelConfig.LevelFromPlacementScore` exposes band logic; B1 cap when `AllowB1Placement=false`
  - **Verify:** +5 unit tests (defaults, env override, custom bands JSON, malformed/empty JSON fallback, OOB clamp)
  - **Size:** S

**[CHECKPOINT V21-A]** `make backend-build && make backend-test` pass; +3 tests

---

## Phase B — Backend service + handlers

- [x] **V21-B1** `UserLevelStore` (`contracts/user_level.go`, `store/user_level_store.go`, `db/migrations/026_v21_backfill_user_levels.sql`)
  - **AC:** legacy backfill moved to migration 026 (one-shot UPDATE guarded by `current_level='a0' AND placement_taken_at IS NULL` so it is no-op on re-run and on greenfield); `SetUserLevel` uses single SQL `array_append` w/ `ANY` guard for race-safe idempotency; `MarkPlacementTaken` sets level + timestamp atomically; memory + Postgres impls share `appendUniqueSorted` helper
  - **Verify:** +5 memory unit tests + 1 migration shape test
  - **Size:** M
- [x] **V21-B2** `PromotionAttemptsStore` (`contracts/promotion_attempt.go`, `store/promotion_attempts_store.go`)
  - **AC:** `Create` (auto ID + zero-time), `GetLatestFailedAttempt(userID, targetLevel)` ignores passed + other-user + other-target rows, `MarkResult` updates passed/score/per-skill idempotent, returns not-found on unknown ID; per-skill JSONB round-trip in Postgres
  - **Verify:** +4 memory unit tests
  - **Size:** M
- [x] **V21-B3** `LevelService` gating math (`processing/level_service.go`, `contracts/level.go`)
  - **AC:** `ComputeLevelProgress` returns full payload incl. server-derived `PromotionUnlocked`; `MapPlacementScoreToLevel` delegates to config; coverage = % of expected skills with ≥1 attempt (anti-farming proxy in lieu of module-count lookup); `nextLevelAfter` central ladder; cooldown expiry computed from latest failed attempt; pure orchestration (no HTTP/DB writes); read-only deps via `LevelMasteryReader` / `LevelUserReader` / `LevelPromoReader`
  - **Verify:** +10 unit tests (fresh user, all-pass, one-below, coverage gap, cooldown active, cooldown expired, top-level, band edges + B1 cap, ladder helper, key set exhaustive)
  - **Size:** L
- [x] **V21-B4** `GET /v1/users/me/level-progress` (`httpapi/level_handler.go`, `server.go` field + route)
  - **AC:** returns `LevelProgressResponse` payload via `LevelService`; 401 when unauth; 404 when service nil (feature disabled); `Cache-Control: no-store` set on success
  - **Verify:** +4 integration tests (auth required, fresh user, ready-to-promote unlock, cooldown active locks with `promotion_cooldown_until`)
  - **Size:** M
- [x] **V21-B5** Placement endpoints (`httpapi/placement_handler.go` + test, `contracts/types.go` MockTest extension, `store/mock_test_store.go` `LatestPlacementMockTest`, Postgres scan/insert/update for new flag columns, `store/memory.go` test seeder, route wiring)
  - **AC:** start picks latest `is_placement=true` MockTest, creates `mock_exam_session`, returns `{mock_test_id, full_session_id}`; 409 `placement_already_taken` w/o `?force=true`; 404 `placement_not_configured` when no placement mock seeded; complete trusts session `OverallScore`, maps via `LevelService.MapPlacementScoreToLevel`, writes `current_level + placement_taken_at`; 404 hides wrong-owner and missing-session identically; 400 `missing_full_session_id`
  - **Verify:** +7 integration tests (auth required, fresh start, no config 404, already-taken 409 + force ok, complete happy, complete wrong-owner 404, complete missing body 400)
  - **Size:** L
- [x] **V21-B6** `POST /v1/promotion-attempts` (`httpapi/promotion_handler.go` + test, `LevelDeps.PromoAttempts`, route)
  - **AC:** error precedence enforced (404 mock_test_not_found → 400 mock_test_not_promotion → 409 level_already_unlocked → 400 promotion_locked → 400 cooldown_active w/ retry_after); promotion_locked also fires when target ≠ NextLevel(current); on success creates `mock_exam_session` + `promotion_attempts` row, returns 201 `{promotion_attempt_id, full_session_id, target_level}`
  - **Verify:** +7 integration tests (auth, not-found, not-promotion, already-unlocked, locked, cooldown, happy)
  - **Size:** L
- [x] **V21-B7** Course handler modifications (`httpapi/server.go` `handleCourses`/`handleCourseByID`/`handleExercise`, `contracts.Course` `Level`/`DemoExerciseID`/`UnlockState`, memory + Postgres course store SELECT/INSERT/UPDATE, `LevelService.ResolveCourseUnlock`)
  - **AC:** `?level=` filter on `GET /v1/courses`; per-item `level` + `unlock_state` (`unlocked`/`demo`/`locked`) + `demo_exercise_id` populated by service; `GET /v1/courses/:id` carries the same fields; `GET /v1/exercises/:id` returns `403 level_locked` when course locked unless exercise == `demo_exercise_id`; gating bypassed when level service is not wired so legacy fixture builds keep working; **`is_demo` attempt tagging deferred to V21-B8** (touches the attempt creation path which B8 owns end-to-end)
  - **Verify:** +5 integration tests (list adds level+unlock_state, level filter, course-by-id fields, locked exercise 403, demo exercise allowed)
  - **Size:** L
- [x] **V21-B8** Atomic promotion hook + demo-skip (`processing/level_promotion.go` (new) + test, `processing/mastery_updater.go` `WithDemoCheck`, `httpapi/server.go` `handleMockExamComplete` wires hook, `store/promotion_attempts_store.go` `GetByFullSessionID`)
  - **AC:** `MasteryUpdater.WithDemoCheck(fn)` callback skips Update when fn(exerciseID) returns true; `HandlePromotionOutcome(deps, session)` looks up promotion_attempts by full_session_id, computes per-skill % from sections (sum_score / sum_max × 100), `MarkResult` then on pass `SetUserLevel(targetLevel)`; both writes idempotent so replay leaves state identical; non-linked sessions return processed=false; hook wired in `handleMockExamComplete` after `CompleteMockExam`, errors logged not surfaced
  - **Verify:** +5 unit tests (demo skip, pass promotes, fail records but no promotion, no-link returns false, replay idempotent)
  - **Size:** L

**[CHECKPOINT V21-B]** `make backend-build && make backend-test` pass; +45 backend tests

---

## Phase C — CMS authoring

- [x] **V21-C1** Course form CEFR level + demo exercise (`cms/lib/level.ts` (new) + test, `cms/components/course-dashboard.tsx` extension; spec called for split `LevelField.tsx`/`DemoExerciseField.tsx` but the Course form lives inline in the dashboard, matching the existing form-fields convention — kept inline)
  - **AC:** `<select>` over A0/A1/A2/B1 with VI labels (`Mới bắt đầu` / `Cơ bản` / `Trvalý pobyt (mặc định)` / `Občanství`), default `a2` via `DEFAULT_COURSE_LEVEL`; sanitizeLevel coerces unknown server values; demo_exercise_id text input hidden when `isLowestLevel(form.level)`; `coursePayload` carries `level` + `demo_exercise_id`
  - **Verify:** +6 Vitest (level constants order/default, sanitize fallbacks, isCefrLevel narrowing, label fallback, isLowestLevel only flags a0); `make cms-lint` clean; `make cms-build` ok
  - **Size:** M
- [x] **V21-C2** MockTest form gating flags (`cms/lib/mockTestFlags.ts` (new) + test, `cms/components/mock-test-dashboard.tsx` extension; spec called for split `PromotionFlagsField.tsx` but kept inline matching the existing form-fields convention)
  - **AC:** two checkboxes for `is_promotion` / `is_placement` enforce mutex (toggling one clears the other; placement also clears `target_level` since placement carries no target); `target_level` `<select>` appears only when `is_promotion` is on, lists A0/A1/A2/B1 with VI labels; `validateMockTestFlags` blocks submit when promotion lacks target or both flags set; `mockTestFlagsPayload` produces clean JSON (target_level omitted unless valid)
  - **Verify:** +15 Vitest (toggle mutex both directions, target setter coercion, validate happy + 3 error paths, payload shape variants); `make cms-lint` clean; `make cms-build` ok; suite total 144
  - **Size:** M

**[CHECKPOINT V21-C]** `make cms-lint && make cms-build && cd cms && npm test` pass; +6 Vitest

---

## Phase D — Flutter

- [x] **V21-D1** Level models + utils (`flutter_app/lib/core/level_utils.dart` (new), `flutter_app/lib/models/models.dart` (extend `Course` + add `LevelProgressResponse` + `SkillMasteryInfo`), `flutter_app/test/level_model_test.dart` (new); spec called for `models/level.dart` + `shared/util/level.dart` but the repo uses single `models/models.dart` + `core/skill_utils.dart` pattern — kept those conventions)
  - **AC:** `CefrLevel` enum (a0–b1); `parseLevel`/`cefrLevelCode`/`nextCefrLevel`/`cefrLevelOrder`/`cefrLevelLabel`/`cefrLevelChipColor` helpers; `CourseUnlockState` enum (`unknown`/`unlocked`/`demo`/`locked`) + parser; `Course.fromJson` parses `level`/`unlock_state`/`demo_exercise_id` (legacy fallback default = `a2` to match backend migration 025); `LevelProgressResponse.fromJson` parses full payload incl. nested `skill_mastery` map, `unlocked_levels` set, optional timestamps; missing optional fields default safely
  - **Verify:** +11 unit tests (4 ladder, 2 LevelProgress, 4 Course states, 1 round-trip); `make flutter-analyze` clean; full Flutter suite 277 tests pass
  - **Size:** M
- [ ] **V21-D2** `LevelApi` client (`core/api/level_api.dart`)
  - **AC:** 4 methods; tolerates flat `{"error":"<code>"}` envelopes
  - **Verify:** +4 unit tests
  - **Size:** M
- [ ] **V21-D3** `LevelBadge` widget
  - **AC:** chip + 4-dot ladder; tokens only; ≥48dp; semantics; reduced-motion safe
  - **Verify:** +3 widget tests
  - **Size:** S
- [ ] **V21-D4** `LevelProgressRing` widget
  - **AC:** 6-arc skill ring; scoreband colors; pulse on unlock respects reduced-motion
  - **Verify:** +4 widget tests
  - **Size:** L
- [ ] **V21-D5** `PromotionBanner` widget
  - **AC:** visible only when unlocked + target not yet in `unlocked_levels`; CTA navigates to `PreExamScreen`
  - **Verify:** +2 widget tests
  - **Size:** S
- [ ] **V21-D6** `LockedCourseSheet` + `CourseListScreen` lock state
  - **AC:** Lucide padlock SVG; mastery delta bar; ghost demo CTA; bottom sheet with primary CTA back to lower-level course
  - **Verify:** +3 widget tests
  - **Size:** M
- [ ] **V21-D7** Onboarding flow (`WelcomeScreen` + `PlacementResultScreen` + router gate)
  - **AC:** first launch routes through Welcome → placement → result → home; skip = A0; reduced-motion safe reveal
  - **Verify:** +4 widget tests
  - **Size:** L
- [ ] **V21-D8** Promotion flow (`PreExamScreen` + `PromotionResultScreen` pass/fail)
  - **AC:** rules + confirm + result variants; live cooldown timer; weakest-skill deep link; haptic on pass
  - **Verify:** +5 widget tests
  - **Size:** L
- [ ] **V21-D9** Home wiring + ARB strings + provider
  - **AC:** embeds badge + ring + banner; `level-progress` re-fetch on pop-back; VI = EN key count
  - **Verify:** +3 widget tests; `make flutter-analyze` no missing-l10n
  - **Size:** M

**[CHECKPOINT V21-D]** `make flutter-analyze && make flutter-test` pass; +32 widget tests; manual TestFlight smoke (placement → first exercise → home)

---

## Phase E — End-to-end + verify

- [ ] **V21-E1** Smoke `make smoke-promotion-flow` (script or `tests/level_flow_test.go`)
  - **AC:** signup → skip placement → seed mastery → unlocked → pass → B1 unlocked; also fail → cooldown
  - **Verify:** `make smoke-promotion-flow` exits 0
  - **Size:** L
- [ ] **V21-E2** Manual MAN-1..MAN-10 on TestFlight
  - Per plan E2 — onboarding, placement bands, locked card, demo no-write, banner, pass celebration, fail diagnostic, existing-user backfill, reduced-motion, VoiceOver
- [ ] **V21-E3** `make verify` final
  - **AC:** Backend +45, Flutter +32, CMS +6; full verify green; no V19/V20 regression

**[CHECKPOINT V21-FINAL]**
- [ ] Backend test target ≥ 615
- [ ] Flutter test target ≥ 298
- [ ] CMS test target ≥ 127
- [ ] MAN-1 .. MAN-10 pass on TestFlight
- [ ] V19 `/v1/users/me/progress` payload byte-identical
- [ ] V20 home progress refresh still works
- [ ] Pre-V21 users land on `current_level=a2` with `{a0,a1,a2}` unlocked
- [ ] CMS author 1 A2-promotion mock + 1 B1 course end-to-end
- [ ] `SPEC.md` § V21 file paths reconciled with final layout (handler in `httpapi/`, store in `store/`, hook in `processing/`)
- [ ] `CHANGELOG.md` V21 entry written
