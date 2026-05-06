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
- [ ] **V21-B3** `LevelService` gating math (`processing/level_service.go`, `contracts/level.go`)
  - **AC:** `ComputeLevelProgress`, `MapPlacementScoreToLevel` (B1 cap when content flag false); pure orchestration
  - **Verify:** +8 unit tests (gating, cooldown, band edges, B1 cap)
  - **Size:** L
- [ ] **V21-B4** `GET /v1/users/me/level-progress` (`httpapi/level_handler.go`)
  - **AC:** returns spec payload; 401 unauth; `Cache-Control: no-store`
  - **Verify:** +4 integration tests
  - **Size:** M
- [ ] **V21-B5** Placement endpoints (`httpapi/placement_handler.go`)
  - **AC:** start (409 already-taken w/o `?force`), complete (atomic write user level)
  - **Verify:** +5 integration tests
  - **Size:** L
- [ ] **V21-B6** `POST /v1/promotion-attempts` (`httpapi/promotion_handler.go`)
  - **AC:** error precedence per spec (404 → 400 not_promotion → 409 already_unlocked → 400 promotion_locked → 400 cooldown_active); creates session + attempt
  - **Verify:** +6 integration tests (happy + each error)
  - **Size:** L
- [ ] **V21-B7** Course handler modifications (`httpapi/courses_handler.go`)
  - **AC:** `?level=` filter; `unlock_state` + `level` + `demo_exercise_id` per item; `403 level_locked` on exercise reads except demo; demo attempts tagged `is_demo=true`
  - **Verify:** +5 integration tests
  - **Size:** L
- [ ] **V21-B8** Atomic promotion hook + demo-skip (`processing/level_promotion.go`, `processing/mastery_updater.go`, `store/persist_attempt_feedback.go`)
  - **AC:** mastery-updater skips when `is_demo`; promotion hook updates attempt + sets user level on pass; idempotent on replay
  - **Verify:** +5 unit tests (demo skip, pass, fail, replay, non-promotion untouched)
  - **Size:** L

**[CHECKPOINT V21-B]** `make backend-build && make backend-test` pass; +45 backend tests

---

## Phase C — CMS authoring

- [ ] **V21-C1** Course form `LevelField` + `DemoExerciseField` (+ payload + Vitest)
  - **AC:** A0/A1/A2/B1 select default `a2`; demo dropdown nullable, hidden at lowest level
  - **Verify:** +3 Vitest
  - **Size:** M
- [ ] **V21-C2** MockTest form `PromotionFlagsField` (+ payload + Vitest)
  - **AC:** mutex `is_promotion`/`is_placement`; `target_level` required when promotion
  - **Verify:** +3 Vitest
  - **Size:** M

**[CHECKPOINT V21-C]** `make cms-lint && make cms-build && cd cms && npm test` pass; +6 Vitest

---

## Phase D — Flutter

- [ ] **V21-D1** Models + level utils (`models/level.dart`, `shared/util/level.dart`, `models/course.dart`)
  - **AC:** `Level` enum + helpers; `LevelProgressResponse` parses; `Course` parses new fields
  - **Verify:** +4 unit tests
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
