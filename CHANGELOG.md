# Changelog

Detailed history of completed slices. Newest first. AGENTS.md keeps the
operational guide; this file keeps the receipts.

For each slice the entry lists: scope, key file changes, decisions
worth remembering, and final test counts. When a slice introduces a new
contract or convention, the canonical home is its own spec under
`docs/specs/` — the entry here points there rather than inlining.

---

## V21.1 — V21 review hotfixes — 2026-05-07

Five-axis review on the V21 slice surfaced 2 Critical + 5 Important
findings. V21.1 lands the lot in two atomic batches.

### V21.1 Batch 1 — Critical + first 2 Important (commit `fix(v21):`)

- **C1 placement non-placement-session**: `placement-test/complete`
  now validates `session.MockTestID` belongs to a `is_placement=true`
  MockTest. Without this guard a learner could submit any of their
  regular `mock_exam_session` ids and have its score map to a level —
  silently skipping placement.
- **C2 score scale**: `OverallScore` is raw points (sum of
  `section_score + pronunciation bonus` per `mock_test_store.computeScoring`),
  not a percentage. Both the promotion hook and the placement complete
  handler now route through `processing.OverallScorePctFromSession`,
  which divides by `sum(MaxPoints)`. Tests updated to use realistic
  raw inputs.
- **I1 N+1 in course list**: `handleCourses` reads `userLevelStore.GetUserLevel`
  once per request, then resolves unlock per course via the new pure
  helper `processing.ResolveCourseUnlockWith(unlockedLevels, ...)`.
- **I3 published-only placement mock**: `LatestPlacementMockTest`
  filters by `status='published'` (memory + Postgres). Drafts no
  longer leak to learners.

### V21.1 Batch 2 — remaining Important + I6 doc (commit `fix(v21.1):`)

- **I4 FK on full_session_id**: migration 027 drops the `NOT NULL DEFAULT ''`
  on `promotion_attempts.full_session_id`, normalises sentinel empty
  rows to NULL, and adds a foreign key to `mock_exam_sessions(id)`
  with `ON DELETE SET NULL`. Ledger row survives session pruning
  (audit trail) but never points to a stale id again.
- **I5 PromotionTestForLevel resolver wired**: `SetLevelDeps` installs
  a default resolver that calls `MockTestStore.LatestPromotionMockTest(targetLevel)`
  so `GET /v1/users/me/level-progress` surfaces `promotion_test_id` —
  the home banner can now deep-link to PreExam without a follow-up
  `listMockTests` round trip.
- **I2 + I8 placement rate limit**: new `placementRateLimiter` (5
  RPM per user) installed by `SetLevelDeps`. Cap closes the TOCTOU
  race between two concurrent first-placement calls AND throttles
  malicious / buggy clients hammering `?force=true`. Returns
  `429 rate_limited` once the window is exhausted.
- **I6 V19/V21 mastery aggregation policy documented**: V21 takes
  *max* across modules per skill (gating threshold favours the
  learner's strongest module so they're not blocked by weak ones);
  V19 progress takes *mean* (honest signal of typical performance).
  Different metrics, different purposes — comment in
  `processing/level_service.go.computeSkillMastery` cross-references
  this CHANGELOG entry so the divergence stays intentional.

### V21.1 deferred to future slices

- I7 hook short-circuit before `GetByFullSessionID` — accepted as-is;
  the lookup is O(1) and the cost is acceptable for V21 traffic.
- S1–S8 — suggestion-tier polish; no behaviour change.

### V21.1 final test counts

- Backend: **647** (V21 baseline 636 → +11 from V21.1: C1+C2 added 7,
  V21.1 batch 2 added 4: migration shape, LatestPromotionMockTest,
  promotion_test_id resolver, placement rate limit).
- Flutter: 309 (no Flutter changes — all V21.1 work is server-side).
- CMS: 144 (no CMS changes).
- `make verify` + `make smoke-promotion-flow` both green.

---

## V21 — CEFR Level Progression (A0 → B1) — 2026-05-07

Pivot from "A2-only sprint" to a level-gated CEFR ladder. Each
learner has a `users.current_level`; content above their level is
locked behind a 2-gate promotion (mastery threshold unlocks a
promotion exam, passing the exam promotes the learner). MVP ships
A2 + B1 only — A0/A1 schema-ready, content deferred. Existing users
backfill to A2 with `{a0,a1,a2}` unlocked.

Per-slice docs: idea `docs/ideas/cefr-level-progression.md`,
spec `docs/specs/cefr-level-progression.md`, UX
`docs/specs/cefr-level-progression-ux.md`, plan
`tasks/cefr-level-progression-plan.md`.

### V21 schema (migrations 025 + 026)

- `courses` `+level enum(a0,a1,a2,b1) DEFAULT 'a2'`,
  `+demo_exercise_id`, `courses_level_idx`. Existing courses backfill
  to `a2`.
- `users` `+current_level`, `+unlocked_levels TEXT[] DEFAULT {a0}`,
  `+placement_taken_at`. Migration 026 backfills pre-V21 users to
  `current_level='a2'` + `{a0,a1,a2}` (idempotent — guarded by
  `current_level='a0' AND placement_taken_at IS NULL` so re-runs and
  greenfield deploys are no-ops).
- `mock_tests` `+is_promotion`, `+is_placement`, `+target_level` with
  three CHECK constraints (target enum, promotion-target-required,
  promotion/placement mutex).
- `promotion_attempts` (new): per-attempt ledger with FKs to
  `users(id)` + `mock_tests(id)`, descending composite index
  `(user_id, target_level, created_at DESC)`.

### V21 endpoints

- `GET /v1/users/me/level-progress` — server-authoritative gating
  state for the home screen. Returns per-skill mastery vs threshold,
  coverage pct, `promotion_unlocked` flag, optional cooldown
  timestamp. `Cache-Control: no-store`.
- `POST /v1/users/me/placement-test/start` — picks the latest
  `is_placement=true` MockTest, creates a session, returns
  `{mock_test_id, full_session_id}`. `409 placement_already_taken`
  unless `?force=true`.
- `POST /v1/users/me/placement-test/complete` — reads session
  `OverallScore`, maps via `LevelService.MapPlacementScoreToLevel`,
  persists `current_level + placement_taken_at`. `404` hides
  wrong-owner / missing-session identically.
- `POST /v1/promotion-attempts` — error precedence: `404
  mock_test_not_found` → `400 mock_test_not_promotion` → `409
  level_already_unlocked` → `400 promotion_locked` → `400
  cooldown_active` (with `retry_after`). On pass creates
  `mock_exam_session` + `promotion_attempts` row.
- `GET /v1/courses(/:id)` — adds `?level=` filter, per-item
  `level / unlock_state / demo_exercise_id`. `unlock_state` ∈
  `{unlocked, demo, locked}` — server is sole authority.
- `GET /v1/exercises/:id` — `403 level_locked` unless caller's level
  unlocks the parent course OR exercise == course's `demo_exercise_id`.

### V21 backend layout

Code lands across the existing package split (no new
`internal/level/` package — matches V19 mastery layout):

- `processing/level_service.go` — gating math (`ComputeLevelProgress`,
  `ResolveCourseUnlock`).
- `processing/level_promotion.go` — `HandlePromotionOutcome` post-
  scoring hook; idempotent on replay.
- `processing/level_config.go` — env loader (sole owner of `LEVEL_*`
  reads).
- `processing/mastery_updater.go` — extended with `WithDemoCheck` so
  demo attempts skip mastery aggregate writes.
- `store/user_level_store.go` — interface + memory + Postgres impls.
- `store/promotion_attempts_store.go` — interface + memory + Postgres
  impls + schema helper.
- `contracts/level.go`, `contracts/user_level.go`,
  `contracts/promotion_attempt.go` — DTOs.
- `httpapi/level_handler.go`, `placement_handler.go`,
  `promotion_handler.go` — wire the four endpoints + `LevelDeps`.
- `httpapi/level_flow_test.go` — E2E smoke (V21-E1).
- Hook fired from `httpapi/server.go.handleMockExamComplete` after
  `repo.CompleteMockExam` returns the finalised session.

### V21 CMS

- Course form: `<select>` over CEFR levels (`cms/lib/level.ts` shared
  helpers) + optional `demo_exercise_id` text input (hidden at
  lowest level). `coursePayload` carries both fields.
- MockTest form: mutex `is_promotion`/`is_placement` checkboxes via
  `cms/lib/mockTestFlags.ts` helpers (`togglePromotion`,
  `togglePlacement`, `setTargetLevel`, `validateMockTestFlags`,
  `mockTestFlagsPayload`); target_level select reveals only when
  promotion is on; `validateMockTestFlags` blocks submit when
  promotion lacks target.

### V21 Flutter

- `core/level_utils.dart` — `CefrLevel` enum + parsers + ladder
  helpers + `CourseUnlockState`.
- `core/api/level_api.dart` — typed client; `LevelApiException`
  collapses both backend envelope shapes (`{error: {code, ...}}` and
  flat `{error: "code"}`).
- `models/models.dart` extended — `LevelProgressResponse`,
  `SkillMasteryInfo`, `Course.level/unlockState/demoExerciseId`.
- `features/home/widgets/level_badge.dart`,
  `level_progress_ring.dart`, `promotion_banner.dart`,
  `home_level_header.dart` — home composer.
- `features/courses/widgets/locked_course_tile.dart`,
  `locked_course_sheet.dart` — locked-state UI.
- `features/onboarding/welcome_screen.dart`,
  `placement_result_screen.dart` — first-launch flow.
- `features/promotion/pre_exam_screen.dart`,
  `promotion_result_screen.dart` — pre-exam confirm + pass/fail
  result with diagnostic table + live cooldown timer.
- ARB additions (matched VI = EN counts): six `v21*` keys for badge
  / banner / locked / promotion copy.

### V21 boundaries

- Server is sole authority for `unlock_state` and `promotion_unlocked`.
  Client never recomputes gates.
- Promotion fail does **not** decrement mastery — only writes the
  ledger row + 24h cooldown.
- Demo attempts (`exercise == course.demo_exercise_id`) skip mastery
  aggregate via `WithDemoCheck` callback so taste-test runs leave no
  trace.
- Reuse `MockTest` via flags. No new `PromotionTest` entity.

### V21 deferred (per scope discipline)

- A0 / A1 module + exercise authoring (content question, not
  engineering).
- `home_screen.dart` integration of `HomeLevelHeader`.
- Onboarding router gate (first-launch routing through Welcome →
  placement → result → home).
- Per-screen ARB-routed copy across the V21 widgets (queued for
  deploy-time wiring pass).

### V21 final test counts

- Backend: **636** (baseline 570, +66 net — A1+A2: +7, B1: +6, B2:
  +4, B3: +10, B4: +4, B5: +7, B6: +7, B7: +5, B8: +5, E1: +2 —
  exceeds plan budget +45).
- CMS Vitest: **144** (baseline ~123, +21 — C1: +6, C2: +15;
  exceeds plan budget +6).
- Flutter: **309** (baseline 266, +43 — D1: +11, D2: +6, D3: +4,
  D4: +4, D5: +3, D6: +3, D7: +4, D8: +5, D9: +3; exceeds plan
  budget +32).
- `make verify` exits 0; `make smoke-promotion-flow` exits 0.

---

## V20.1 — Hotfixes from learner-flow simulation — 2026-05-06

End-to-end MobAI simulation through the demo course surfaced 7 bugs in
the V20 learner flow. All fixed in this slice. No new product scope.

- **B5+B6 (P0): `cteni_4` answers never persist.** `_buildAnswerWidgets`
  in `features/exercise/screens/reading_exercise_screen.dart` was
  pulling options from the global `cteniOptions` (empty for cteni_4
  where each question carries its own option set) and keying answers by
  1-based loop index. Backend `extractCorrectAnswers` keys
  `correct_answers` by `question_no` (15..20 for cteni_4), so every
  submission scored 0/N. Fix: extend `FillQuestionView`
  (`models/models.dart`) with `options: List<PoslechOptionView>`; rewrite
  `_buildAnswerWidgets` + `_hasAllAnswers` to use per-question options
  and `q.questionNo` as the answer-map key. Per-question prompts now
  render via the caller; `MultipleChoiceWidget` skips its own number
  prefix when `questionNo == 0`.
- **Cast crash (P0): `String?['message']` on flat error.** Backend
  returns two error envelopes — `{"error":{"code","message"}}` (most
  endpoints) and `{"error":"<code>","message":"..."}` (auth gates like
  `email_verify_required`, `attempts_quota_exceeded`). `api_client.dart`
  assumed Map and crashed `type 'String' is not a subtype of type 'int'
  of 'index'` when `payload['error']` was a String. Now checks shape and
  falls back to top-level `message` field.
- **B7 (P1): `HomeProgressCard` stale after attempts.** Cache only
  refreshed on app launch / pull on detail screen. Fix: promote
  `_HomeProgressCardState` → `HomeProgressCardState` and expose
  `refresh()`; `CourseListScreen` holds a
  `GlobalKey<HomeProgressCardState>` and awaits the course-detail push
  before calling `refresh()` so mastery accrued inside an attempt is
  visible on return.
- **B8 (P1): Vocab flashcard never logged an attempt** → `tu_vung`
  mastery stayed at zero. `deck_session_screen.dart` now fires a
  background `createAttempt` + `submitAnswers({'1': choice})` per
  flashcard mark for `quizcard_basic` only. The backend's existing
  `QuizcardBasicDetail.correct_answers = {"1": "known"}` makes "known"
  score 1/1 and "again" 0/1 through the standard objective scorer →
  V19 EMA pipeline. Errors are swallowed (logged) so the local Anki UX
  does not stall.
- **B4 (P3): Course-detail stat row lied.** "KỸ NĂNG" was
  `modules.length * 4` and "PHÚT" was `modules.length * 45` — both
  arbitrary multipliers. `CourseDetailScreen` now fans out
  `listModuleSkills` per module in parallel and shows real totals
  (KỸ NĂNG = sum of returned skill summaries; PHÚT replaced with
  BÀI TẬP = sum of `exercise_count`).
- **B3 (P2): "Bắt đầu tất cả" did not actually queue.** Reading +
  listening result screens only had "Làm lại" — pressing the sprint CTA
  opened the first exercise then dropped the learner back to the list.
  `ObjectiveResultCard` gains an optional `onNext` (renders primary
  "Bài tiếp theo →" + outlined retry); `ReadingExerciseScreen` and
  `ListeningExerciseScreen` accept `onOpenNext`; `_openExercise` in
  `exercise_list_screen.dart` computes the next item and routes via
  `pushReplacement` so the navigation stack stays flat (matches the
  pre-existing vocab/uloha pattern).
- **B1 (P2): Wrong subtitle for non-speaking skills.**
  `exerciseListSubtitle` ARB key was hard-coded to a speaking-specific
  string ("Tập trung vào sự trôi chảy và phát âm…") and shown on every
  skill detail. Replaced with the skill-neutral
  "Chọn bài tập để bắt đầu luyện ngay." in both VI and EN ARBs.

Tests: Flutter 265 → 266 (+1: `HomeProgressCard.refresh()` re-fetches
with `forceRefresh=true`, plus +2 inside `section_result_card_test.dart`
covering ObjectiveResultCard sprint queue render/hide). Backend test
suite unchanged (no contract changes).

Files touched:
- `flutter_app/lib/core/api/api_client.dart` — error envelope handling.
- `flutter_app/lib/models/models.dart` — `FillQuestionView.options`.
- `flutter_app/lib/features/exercise/screens/reading_exercise_screen.dart`
  — per-question options + question_no keys + onOpenNext.
- `flutter_app/lib/features/exercise/screens/listening_exercise_screen.dart`
  — onOpenNext.
- `flutter_app/lib/features/exercise/screens/deck_session_screen.dart`
  — flashcard attempt logging.
- `flutter_app/lib/features/exercise/widgets/multiple_choice_widget.dart`
  — skip "0." when caller renders prompt.
- `flutter_app/lib/features/exercise/widgets/objective_result_card.dart`
  — onNext CTA.
- `flutter_app/lib/features/mock_exam/widgets/section_result_card.dart`
  — thread onNext.
- `flutter_app/lib/features/home/screens/exercise_list_screen.dart`
  — sprint queue routing for cteni/poslech.
- `flutter_app/lib/features/home/screens/course_list_screen.dart`
  — GlobalKey + refresh on push return.
- `flutter_app/lib/features/home/screens/course_detail_screen.dart`
  — real skill / exercise totals.
- `flutter_app/lib/features/progress/widgets/home_progress_card.dart`
  — public state + `refresh()`.
- `flutter_app/lib/l10n/app_{vi,en}.arb` — `exerciseListSubtitle`
  rewrite.
- `flutter_app/test/widgets/home_progress_card_test.dart`,
  `flutter_app/test/section_result_card_test.dart` — coverage for the
  new APIs.

Out of scope (open):
- B9 — `cteni_5` exercise listed twice in seed; `cteni_6` exercise has
  empty `module_id` in the API response. Both are seed-data issues, not
  app code; CMS reseed needed.

---

## V20 — Flutter Skill Mastery UI — 2026-05-06

- Renders the V19 progress aggregate as a home-screen card + drill-down
  detail screen, plus a profile entry tile. Strings flow through ARB
  (24 new keys, VI=EN parity at 376=376) so the UI stays free of
  hardcoded VI copy outside the call sites.
- Wire layer: `core/api/progress_models.dart` (typed `UserProgress`,
  `SkillProgress`, `ModuleProgress`, `ProgressBands` with permissive
  `fromApiJson` that accepts `Map<dynamic,dynamic>` const fixtures);
  `core/api/progress_api.dart` (typed wrapper + 24 h cache via
  in-memory `_Cached` + `SharedPreferences`; on network error returns
  the prior cache with `isStale=true`); `ApiClient.getProgress()` raw
  fetch.
- Widgets under `features/progress/widgets/`:
  - `MasteryBar` — 8 dp track + animated fill via `TweenAnimationBuilder`,
    band → colour from `AppColors.score{Poor|Fair|Good|Excellent}`,
    collapses tween to zero duration when
    `MediaQuery.disableAnimations` so reduced-motion paints final value
    immediately. Optional `Semantics(label, value)`.
  - `SkillMasteryRow` — 56 dp min-height row, label + bar +
    tabular-figure percent. `MergeSemantics` + `Semantics(button: true,
    onTap)` + `InkWell(excludeFromSemantics: true)` so screen readers
    announce one node, not three.
  - `ProgressEmptyState` / `ProgressErrorState` — icon + title +
    optional message + optional FilledButton/OutlinedButton CTA.
- Screens under `features/progress/screens/`:
  - `HomeProgressCard` (mounted above the course grid in
    `course_list_screen.dart`) — loading → populated / empty / error
    states; offline chip when stale; optional onSkillTap pushes the
    drilldown filtered to that `skill_kind`.
  - `ProgressDetailScreen` (`skillKind` nullable) — `RefreshIndicator`
    pull-to-refresh re-runs the fetcher with `forceRefresh: true`;
    AppBar offline chip mirrors `HomeProgressCard`.
- Profile: new "Tiến độ học tập" tile on `ProfileScreen` pushes
  `ProgressDetailScreen(skillKind: null)` (all-skills view) by lazy-
  building `ProgressApi` from `SharedPreferences` on tap.
- Shared util: `features/progress/skill_labels.dart#skillKindLabel(l, kind)`
  resolves the 7 skill_kind tokens to their localised display name —
  consumed by both the home card and detail screen.
- ARB: 24 new keys per spec — `homeProgressCardTitle`,
  `progressOverallTitle`, `progressOverallPercent({percent})`,
  `progressSkill{Noi,Viet,Nghe,Doc,TuVung,NguPhap,Interview}`,
  `progressBand{NeedsWork,Learning,Solid,Ready}`,
  `progressEmpty{Title,Cta}`, `progressError{Title,Retry}`,
  `progressOfflineChip`, `progressDetailTitle`,
  `progressDetailAttemptsLabel({count})`,
  `progressDetailLastAttemptLabel`,
  `progressLastAttemptRelativeFormat({when})`, `profileProgressEntry`.
- Spec: `docs/specs/skill-mastery-progress.md` (covers V19 + V20)
  · plan: `tasks/skill-mastery-progress-plan.md`
  · todo: `tasks/skill-mastery-progress-todo.md`.
- Tests: Flutter +43 widget/unit (222 → 265): `test/api/progress_api_test.dart`
  (10 — parse, round-trip, empty, network hit, memory cache, force
  refresh, prefs cold start, 24 h expiry, stale fallback, offline
  rethrow); `test/widgets/mastery_bar_test.dart` (12 — 4 band colours
  + unknown fallback + clamp + semantics + reduced-motion + row
  layout + tap + merged semantics + tabular figures);
  `test/widgets/progress_states_test.dart` (6 — render + tap +
  null-callback hide); `test/widgets/home_progress_card_test.dart`
  (5 — loading→populated, empty + CTA, error + retry refetch, offline
  chip, tap-row); `test/screens/progress_detail_screen_test.dart`
  (6 — all-skills, single-skill filter, empty, error + retry,
  pull-to-refresh forceRefresh, offline chip). `flutter analyze`
  clean.
- Manual UI verify (Checkpoint 3) outstanding: iPhone SE 375 +
  iPhone 14 Pro × light/dark × reduced-motion + largest Dynamic Type.

---

## V19 — Skill Mastery Aggregate + Progress Endpoint — 2026-05-06

- Turns the per-attempt `AttemptFeedback.readiness_level` stream into a
  durable per-skill / per-module mastery signal keyed by
  `(user_id, skill_kind, module_id)`. Updated synchronously after each
  feedback persists; failures log at error level, never roll back the
  attempt.
- Schema (Postgres, idempotent via `CREATE TABLE IF NOT EXISTS`):
  `user_skill_mastery (id, user_id, skill_kind, module_id,
  mastery_score, attempts_count, last_attempt_id, last_attempt_at,
  created_at, updated_at)` with `UNIQUE (user_id, skill_kind,
  module_id)` and `INDEX (user_id, updated_at DESC)`. `module_id=""`
  reserved for exam-pool attempts so the unique index still holds.
- Vocabulary unify (Phase 0, separate commit `f20fbee` shipped
  alongside): the 4-band scale `not_ready / needs_work /
  almost_ready / ready_for_mock` is now used by both the LLM scorer
  (`exam_ready` collapsed into `ready_for_mock`, explicit
  `needs_work` token added to the prompt) and the objective scorer
  (`frac` thresholds 0.85 / 0.60 / 0.30). `normalizeReadinessLevel`
  preserves backwards compat for legacy persisted feedback
  (`weak → needs_work`, `ok → almost_ready`, `strong → ready_for_mock`,
  `exam_ready → ready_for_mock`). New `ReadinessToScore` returns the
  numeric mastery contribution: 0.20 / 0.45 / 0.70 / 0.90.
- EMA update rule (`processing/mastery_updater.go`):
  - First attempt sets `mastery = score` directly.
  - `attempts_count ≤ EarlyAttemptCap (3)` → `0.5*old + 0.5*score`.
  - Otherwise → `0.7*old + 0.3*score`.
  - Idempotent on `last_attempt_id`: if the same attempt is replayed
    (e.g. retried persist), the upsert is skipped.
- Config (`processing/processing_config.go`, sibling to `llm_config.go`
  per AGENTS.md SoT rule): `MasteryConfig{BandLearning, BandSolid,
  BandReady, EarlyAttemptCap, EarlyAlpha, SteadyAlpha, weights}`.
  Env-overridable via `MASTERY_BAND_{LEARNING,SOLID,READY}` and
  `MASTERY_OVERALL_{NOI,VIET,NGHE,DOC,NGU_PHAP,TU_VUNG,INTERVIEW}`.
  `LoadMasteryConfig` clamps band floors to [0, 1], weights to [0,
  100], swaps non-monotonic floors, and warns on env parse errors so
  operator typos (e.g. comma-decimal) are visible in logs.
- Endpoint: `GET /v1/users/me/progress` (auth required via
  `withAuth`, 401 without bearer, 200 always for authenticated users
  even with zero rows). Returns
  `{overall_progress, overall_band, skills[], bands{needs_work,
  solid, ready}, weights{...}}`. Per-skill mastery is the unweighted
  mean across the skill's modules; `overall_progress` is the
  weighted mean across non-zero-weight skills with fallback to
  equal-weight when every weight is zero.
- Wiring: `Processor.completeAttempt` (processor.go) is the single
  funnel — all 5 `CompleteAttempt` call sites (speaking, writing,
  interview, objective, dictation) route through it so adding a new
  attempt path can't accidentally skip the mastery hook.
  `httpapi.MasteryDeps{Store, Config}` + `NewServerWithMastery`
  decouples mastery wiring from the V17 self-serve auth bundle so the
  dev fixture build path also records progress.
- Dev fixtures: `EnsureDevFixtureUsers(databaseURL)` runs at server
  boot when `ENV != "production"`, idempotently INSERTs the 3
  fixture user IDs (`user-learner-1`, `user-learner-2`,
  `user-admin-1`) into Postgres `users` with `email_verified_at =
  now()` and a high `grace_attempts_left` so the V17 verify gate
  doesn't fire after 3 attempts. Without this, mastery (and every
  other V17 store FK on `users(id)`) silently rolled back every
  insert from the dev fixture path.
- Smoke: `scripts/smoke_progress_flow.py` + `make smoke-progress-flow`
  cover auth gate (401), wire shape, monotonic bands, band
  classification mirroring backend, weights non-negative,
  per-skill + per-module ranges, idempotent re-read, optional
  `--require-rows` assertion. Folded into `make smoke-all`.
  `smoke_test_attempt_flow.py` + `smoke_course_flow.py` migrated to
  the V8 `/v1/modules/{id}/exercises?skill_kind=...` path so they
  no longer reference the dropped `skills` table.
- Spec: `docs/specs/skill-mastery-progress.md`
  · idea: `docs/ideas/skill-mastery-progress.md`.
- Tests: backend +27 (532 → 570 inc. processing config clamp/swap +
  smoke add): `processing_config_test.go` (8 — defaults, env override,
  band classification, unknown skill, clamp band, clamp weight,
  monotonic swap, parse fallback); `mastery_updater_test.go` (7 —
  first attempt, EMA convergence, decay, idempotency,
  exam-pool empty `module_id`, missing user-skill-feedback no-op,
  `last_attempt_at` from `CompletedAt`); `skill_mastery_store_test.go`
  (7 — insert, composite-key update, get, list ordering, empty user,
  exam-pool empty `module_id`, missing user-skill rejection);
  `progress_handler_test.go` (4 — 401, empty user, populated weighted
  overall, env-overridden weights). All tests green; smoke E2E PASS.
- Validation gates (post-ship, blocks V21): 30-attempt teacher
  agreement ≥ 70 %, 5-learner pilot interview, 20-sequence notebook
  curve check, p95 attempt-persist latency within current SLO.
  Recorded in `tasks/skill-mastery-progress-todo.md § Phase 4`.

---

## V18.1 — Dictation OCR Submission — 2026-05-05

- Extends `psani_3_dictation` with handwriting-photo input via
  Claude Vision OCR (zero new vendor — reuses `ANTHROPIC_API_KEY`).
- `DictationDetail.submission_mode: "type" | "ocr" | "both"`, default
  `"type"` for V18 backward-compat. `Mode()` getter normalises.
- Backend: `processing/dictation_ocr.go` (`OCRProvider` interface +
  `ClaudeVisionOCR` + `NoopOCR` fallback); `LLM_OCR_MODEL` env (default
  `claude-opus-4-7`). Prompts in SoT files. Fail-soft: OCR error returns
  `("", nil)` so the endpoint never 5xx because of OCR.
- Endpoints (multipart):
  - `POST /v1/attempts/:id/dictation-ocr-preview` — single image,
    5 MB cap, MIME jpeg/png/webp, idx 0..7, per-user RL 30/min.
    Returns `{idx, text, asset_id}`. OCR fail → 200 with empty text.
  - `POST /v1/attempts/:id/submit-dictation-ocr` — `sentences` JSON form
    field, 64 KB cap. Reuses `ProcessDictationAttempt` so scoring is
    identical to V18 type-mode (AC: score parity).
- Storage: file-based under `dictation-ocr/<attempt_id>/img-<nanos>.<ext>`
  via `LOCAL_ASSETS_DIR`. No new DB table — storage key serves as
  `asset_id`.
- Compose: `LLM_OCR_PROVIDER` + `LLM_OCR_MODEL` threaded through
  `docker-compose.yml` + `docker-compose.ec2.yml`. Without the host
  shell setting these, backend defaults to `NoopOCR` (silent empty
  preview).
- Server hooks: `Server.ocrProvider` field + `dictationOCRRL`
  rate limiter; new `NewServerForTest` + `Handler()` + `SetOCRProvider`
  for fake-OCR injection in widget tests.
- CMS: `DictationFields.tsx` adds "Chế độ nộp bài" select + per-mode
  hint paragraph. `DictationFormState.submissionMode` parsed safely
  (`"type"` default for unknown/missing). `validateDictation` rejects
  invalid enum values.
- Flutter: `ExerciseDetail.dictationSubmissionMode` + `isOCRMode` /
  `isTypeMode` / `isBothMode` getters. `DictationOCRPreviewCard` widget
  (thumbnail + editable TextField + Retake/Confirm + isUploading
  spinner + optional failedBanner). `DictationExerciseScreen` branches
  on submission mode: "type" keeps V18 flow, "ocr" replaces TextField
  with camera CTA, "both" adds per-sentence ChoiceChip toggle. Lazy-
  creates the attempt at first OCR preview (preview endpoint needs
  attemptId). Submit dispatches OCR endpoint when any sentence used the
  photo path.
- Camera: `image_picker: ^1.1.2` (already in pubspec from V17.2),
  `pickImage(source: camera, maxWidth: 1024, imageQuality: 85)`.
  Injectable via `DictationImagePicker` typedef so widget tests stub
  the platform channel.
- API client: `dictationOCRPreview()` + `submitDictationOCR()` use the
  same dart:io HttpClient multipart helper as V17.2 avatar upload.
  Reuses existing `AuthException`.
- i18n: 8 new ARB keys VI + EN (mode labels, preview titles/hints,
  buttons, banners). 4 admin-side hint strings inline in
  `DictationFields.tsx` (matches existing exercise-form-fields
  convention; `cms/lib/i18n.tsx` scope is sidebar/dashboards only).
- Spec: `docs/specs/dictation-ocr.md` · idea: `docs/ideas/dictation-ocr.md`
  · plan: `tasks/plan.md § V18.1` · summary: `SPEC.md § V18.1`.
- Tests: backend +22 (510 → 532), Flutter +11 (211 → 222), CMS +5
  (116 → 121); analyze + lint + build clean across all three.
- E2E + pilot remain manual: TestFlight smoke MAN-1..MAN-8 + 20×6 photo
  gold set across 5 learners measuring CER ≤10% before promoting OCR
  to default mode in V18.2.

---

## V18 — Dictation Exercise (`psani_3_dictation`) — 2026-05-05

- New exercise type under `viet`: 3–8 Czech sentences, per-sentence
  Polly TTS, learner stepper UI (auto-play once + manual repeats with
  client-side cap), keyboard-typing input + Czech diacritic chip row.
- Backend: `processing/dictation_scorer.go` weighted Levenshtein
  (diacritic substitution weight 0.5, NFC-normalized) →
  `DictationFeedback`; `processing/dictation_processor.go` orchestrator;
  `processing/dictation_llm.go` async Claude annotator (fail-soft to
  deterministic-only diff). `POST /v1/attempts/:id/submit-text`
  branches on exercise_type to dispatch the dictation goroutine.
- Storage: `exercise_audios.sentence_idx` nullable column added via
  `addColumnIfMissing`; `ExerciseSentenceAudioStore` interface; admin
  per-sentence audio endpoint `POST/DELETE /v1/admin/exercises/:id/dictation/sentences/:idx/audio`.
- CMS: `DictationFields.tsx` (transcript paste → auto-split with Czech
  abbreviation handling: Mgr./Dr./Bc./Ph.D./pan./ing.; per-row Polly
  button + preview; replay-cap + max_points + threshold + voice inputs;
  inline validation banner). `validateExercise` blocks publish when a
  sentence lacks audio.
- Flutter: `DictationExerciseScreen` stepper + `DictationAudioCard` +
  `CzechKeyboardChips` + `DictationResultCard` 3-tab (Score / Sửa bài
  diff / Phản hồi). `submitDictation` API client.
- Spec: `docs/specs/dictation-exercise.md` · summary: `SPEC.md § V18`.
- Tests: backend 510, Flutter 211, CMS 116; smoke pass; verify green.
- Hot fixes: Postgres `ExerciseSentenceAudioStore` wired in main.go;
  audio_asset_id hydrated from sentence_audio store at exercise read;
  edit dialog rehydrates the transcript textarea.

---

## V17.2 — Learner Profile Identity (Avatar + Nickname) — 2026-05-05

- `POST /v1/users/me/avatar` (multipart, 5 MB cap, jpg/png/webp) +
  `DELETE /v1/users/me/avatar`. `patchMeRequest.avatar_asset_id`
  optional pointer; `display_name` 60-rune cap via
  `utf8.RuneCountInString` (Vietnamese-safe).
- Backend reuses V11 `uploadItemImage` helper with
  `storagePrefix=avatars`. Storage key
  `avatars/<user_id>/img-<nanos>.<ext>`; old file removed on rewrite or
  delete.
- Flutter: `image_picker: ^1.1.2`, `ApiClient.uploadAvatarV17(File)`
  via `dart:io HttpClient` multipart, `mediaUri(asset_id)` reused for
  serve. ProfileScreen redesign: V17AccountSection promotes to top as
  centered hero (avatar 96pt + name 22pt + edit pencil + email + chip
  pills + email-verify warning).
- `_AvatarTile` `Stack(fit: StackFit.expand)` + `Image.network(width,
  height, fit: BoxFit.cover)` to fix avatar circle clipping. Action
  sheet: capture / pick from library / delete / cancel; client-side
  resize via `pickImage(maxWidth: 1024, maxHeight: 1024, imageQuality:
  85)`.
- Bug fix `AuthService._adoptUser`: always `notifyListeners()` when
  `_user` mutates so `AnimatedBuilder` rebuilds.
- iOS Info.plist: `NSPhotoLibraryUsageDescription` (camera permission
  was already added in V14).
- Initials fallback derived from `display_name` (first 2 chars) or
  email local-part when avatar is absent.
- Specs: `docs/specs/learner-profile-identity.md` · idea:
  `docs/ideas/learner-profile-identity.md`.
- Tests: 452 backend (+5), 201 Flutter, 95 CMS Vitest.

---

## V17.1 — Admin User Management — 2026-05-05

- `GET /v1/admin/users` (paginate + search + role filter), `DELETE
  /v1/admin/users/:id` (soft-delete + revoke tokens; frees email for
  re-register), `POST /v1/admin/users/:id/reset-password` (admin sets
  password directly; validates strength via `auth.ValidatePassword`;
  revokes sessions; resets login RL).
- `UserStore.ListUsers(opts)` added to interface + memory + postgres
  impls (LIKE search on email + display_name + COUNT total).
- Sub-route dispatch in `handleAdminUserByID` on path suffix after
  `:id` (`/reset-password`).
- Security guards: refuse self-delete (`caller.ID == target.ID`),
  refuse admin-role target (delete + reset-password both 403), 4 KiB
  body cap.
- CMS `/users` page: search input + paginate footer + Reset/Delete row
  actions. Admin row shows `—`. Reset modal: 2 password inputs +
  confirm + inline strength hint; success state nudges admin to share
  via secure channel (chat/sms, not email).
- Soft-delete keeps `attempts.user_id` for audit; partial unique index
  `WHERE deleted_at IS NULL` allows re-register.
- Specs: `docs/specs/admin-user-management.md`.
- Tests: 447 backend (+12), 95 CMS Vitest.

---

## V17 — Self-serve Learner Auth — earlier 2026-05

- Signup/login/IAP/quota gates (see `docs/specs/self-serve-learner-spec.md`).

---

## V16 — Interview First-Turn Fix + Push-to-Talk + UX Polish — 2026-05-04

- Audio gate routes Simli chunks on `onVideoReady` (first frame), not
  WS START. Buffer pending chunks, flush on ready, fallback timer
  `audio_buffer_timeout_ms` (default 1500ms; 500..5000 clamp) →
  `PcmAudioPlayer` local.
- Simli opt-in via Profile (`InterviewPreferenceService.avatarEnabled`,
  default false). Disabled mode uses sound wave + local PCM player and
  removes the 11–15s SPEAK delay we saw in production logs.
- Local examiner volume slider 100–180% (`localAudioVolume`, default
  135%). PCM16 gain with safe clipping.
- Server-derived `display_prompt` from `system_prompt` (strip "You
  are…", extract `ÚKOL`/`TASK` block, drop `{selected_option}`
  placeholder). Helper `processing.DerivePromptForLearner` +
  `processing.EnrichInterviewDetail`.
- Admin preview endpoint: `POST /v1/admin/interview/preview-prompt`
  (RL 30/min/admin); CMS `PromptPreview` debounced 400ms.
- `InterviewPromptCard` bottom panel widget; pulse 1.5s on
  `agent_response_complete` (skip first); "Hoàn thành" / "Finish"
  sticky CTA → `popUntil(home)`.
- Push-to-talk mic (`_PttMicButton`): tap toggle replaces always-on
  VAD. State authoritative from Simli SPEAK/SILENT WS messages. 12s
  agent-wait timer after user turn. 550ms preroll buffer + 1600 byte
  minimum before flushing to ElevenLabs. Sound-wave mode applies fixed
  outbound PCM gain `2.4×` with safe clipping for VAD sensitivity.
  `canStartInterviewMic` + `shouldReleaseInterviewMicPreroll` pure
  helpers for tests.
- Empty-turn filter (`_isMeaningfulTranscript`): `\p{L}|\p{N}` regex
  drops "..." / whitespace turns from VAD false positives.
- Defensive state in `_startConversation`: flip `_state`
  speaking→ready so mic enables even when the safety timer fires
  outside `agent_response_complete`. 3s no-audio fallback enables mic
  for learner-speaks-first scenarios.
- iOS audio session switching: Simli duplex uses `playAndRecord +
  videoChat`; sound-wave PTT uses `playAndRecord + measurement` to
  avoid AEC/noise gate suppressing ElevenLabs detection. Sound-wave
  examiner playback returns to `AudioSessionConfiguration.speech()`
  before each turn to dodge iOS ducking attenuation.
- Local playback turn gate: sound-wave mode waits for
  `PcmAudioPlayer.flushAndPlay()` before re-enabling mic; chunks
  auto-flush to reduce latency, mic only re-opens on
  `agent_response_complete` or silence timeout. `flushAndPlay` defers
  while mic active to avoid iOS `AVAudioSession` `!pri`.
- Responsive layout: bottom panel scroll lane for transcript + prompt
  card, separate fixed control lane for timer/mic/end. Compact-height
  uses prompt max-height; widget tests at 360×640 catch overflow.
- Audio diagnostics: per-turn counter logs
  `Interview turn=N audio chunks: simli=X local=Y buffered=Z
  useSimliAudio=A videoReady=B`; mic `rawPeak`/`sentPeak`/`micGain`;
  ElevenLabs `vad_score` max log; `flushAndPlay` logs sample rate +
  gain + bytes + duration.
- ElevenLabs agent settings required (in Security): "Allow client
  override system_prompt", "first_message", "TTS voice". Without
  first_message override, the 3s fallback enables mic.
- Specs: `docs/specs/interview-first-turn-fix.md` · plan:
  `docs/plans/interview-first-turn-fix-plan.md`.
- Tests: 298 backend, 159 Flutter, 95 CMS Vitest.

---

## V15 — AI Image Generation in CMS — 2026-05-03

- "✨ Tạo bằng AI" button next to upload at exercise context_image,
  cteni_1 per-item, Course banner, MockTest banner (4 sites).
- Backend: `POST /v1/admin/ai/generate-image` (Replicate Flux.1-schnell,
  poll + download + local save) + `POST /v1/admin/ai/set-banner`. RL
  5/min/admin. `REPLICATE_API_KEY` env.
- CMS `AiImageButton.tsx`: 6-state machine
  (idle→open→generating→preview→uploading→done/error). Confirm flow:
  generate → preview Replicate CDN → "Dùng ảnh này" → POST `/assets`
  register → reload.
- Image format JPEG 512×512; output_format `"jpg"` (not `"jpeg"`).
  Compose adds `REPLICATE_API_KEY`. DNS fix (8.8.8.8) for Docker.
- Specs: `docs/ideas/ai-image-generation.md`.
- Tests: backend +10 (rate limiter + mock Replicate), CMS +17 Vitest.

---

## V14 — Interview Skill — 2026-05-02

- `skill_kind = "interview"` with 2 exercise types:
  `interview_conversation` + `interview_choice_explain`.
- Backend: `POST /v1/interview-sessions/token` (ephemeral ElevenLabs
  signed URL, injects `{selected_option}`); `POST
  /v1/attempts/:id/submit-interview`; `interview_scorer.go` post-
  session LLM scoring.
- CMS: `InterviewConversationFields.tsx` +
  `InterviewChoiceExplainFields.tsx` with `system_prompt`, `max_turns`,
  `show_transcript` toggle. `interview_choice_explain.options[].tips`
  for per-option learner hints.
- Flutter: `ElevenLabsWsClient` (custom Dart WS, PCM16 streaming) +
  `SimliSessionManager` (wraps `simli_client`); InterviewList →
  InterviewIntro → InterviewSession → InterviewResult screens.
- Audio pipeline: PCM16 buffer → WAV → `just_audio` (Sprint 1); pipe
  to `simliClient.sendAudioData()` for avatar lip-sync (Sprint 2).
- Security: API key server-side only; Flutter receives ephemeral
  signed URL.
- iOS deployment target 13.0 (flutter_webrtc requirement); camera +
  mic permissions added.
- `SIMLI_API_KEY` + `SIMLI_FACE_ID` via `--dart-define`; avatar
  disabled when key empty.
- `ELEVENLABS_VOICE_ID_C` env: when set, backend returns `voice_id` in
  `InterviewTokenResponse`; Flutter injects into
  `conversation_config_override.tts.voice_id`. **Requires** "Allow
  client to override TTS voice" in ElevenLabs agent Security settings —
  WS reject otherwise.
- Specs: `docs/ideas/interview-skill.md` · `docs/designs/interview-skill.html`.
- Tests: 263 backend, 61 CMS Vitest, 102 Flutter.

---

## V13 — Ano/Ne Exercise Type — 2026-05-02

- Two new exercise types: `cteni_6` (read passage → Ano/Ne) +
  `poslech_6` (TTS passage → Ano/Ne). 1–5 statements each.
- Backend: `AnoNeDetail`/`AnoNeStatement` contracts;
  `extractQuestionTexts` branch on `statements[].statement`;
  `BuildExerciseAudioText` case `poslech_6`; `isAnoNeKey()` exact-match
  guard prevents substring collision ("NEANO" ≠ "ANO").
- CMS: `AnoNeFields.tsx` (passage textarea + statement repeater +
  ANO/NE toggle + max_points + Polly button); wired before
  `startsWith` checks in `exercise-form/index.tsx`. 4 Vitest tests.
- Flutter: `AnoNeWidget` + `_AnoNeRow` (44pt tap target, animated
  states); `_buildCteni6Layout` + poslech_6 branch; `_hasAllAnswers`
  empty-guard; `AnoNeStatementView` model. 5 i18n keys VI+EN. 5 widget
  tests.
- Scoring reuses `objective_scorer.go` — no LLM, no migrations, no new
  endpoints.
- Specs: `docs/specs/ano-ne-exercise-type.md`.
- Tests: 243 backend, 53 CMS Vitest, 69 Flutter.

---

## V12 — Deck Session Mode — 2026-05-01

- `TypeGroupScreen`: tu_vung/ngu_phap groups exercises by exerciseType
  in 2-col grid with count badge.
- `DeckSessionScreen`: queue (`ListQueue`), progress bar, 4 card types
  (quizcard_basic, choice_word, fill_blank, matching).
- Local scoring on choice_word / fill_blank (substring check) — no
  backend round-trip.
- `_CompletionView` shows Đã biết / Ôn lại counts.
- 11 widget tests in `deck_session_test.dart`.

---

## V11 — Media Enrichment — 2026-05-01

- `image_asset_id` added to `VocabularyItem`, `GrammarRule`,
  `MultipleChoiceOption`, `MatchOption` (contracts + migrations
  020/021).
- `QuizcardBasicDetail.ImageAssetID` injected at publish time from the
  vocab item; `ApiClient.mediaUri(key)` → `GET /v1/media/file?key=`.
- `QuizcardWidget` 16:9 image slot (priority: context_image asset >
  flashcardImageAssetId).
- `MultipleChoiceWidget` switches to 2×2 image grid when all options
  carry `imageAssetId`. `MatchingWidget` right column shows image card.
- `ExerciseContextImage` widget on all 4 exercise screens
  (listening/reading/writing/vocab-grammar) + `DeckSessionScreen`.
- Exercise form: "🖼 Ảnh minh họa" collapsible section for every
  exercise type; `DELETE /admin/exercises/:id/assets/:assetId`.
- cteni_1 per-item image upload in CMS (CteniFields image/text
  toggle); Flutter `_buildCteni1Layout` redesign.
- `Course.BannerImageID` + `MockTest.BannerImageID` with
  `POST/DELETE /admin/{courses,mock-tests}/:id/banner`. CMS card
  header + Flutter Course/MockTest cards show banner.
- Security fix: `isSafeAssetKey()` uses `filepath.Clean + HasPrefix`
  instead of `strings.Contains("..")`.
- DB: inline `ALTER TABLE ADD COLUMN IF NOT EXISTS` at startup for all
  stores — no manual goose run. **RDS caveat**: `ALTER TABLE` requires
  table owner; if goose ran as a different user, app user can't ALTER.
  Fix: (1) one-time `ALTER TABLE ... OWNER TO <app_user>` after
  initial migration (see `deploy-first-release-checklist.md`); (2)
  `addColumnIfMissing()` checks `information_schema` first.
- Specs: `docs/specs/media-enrichment.md`.

---

## V10 — Exam Result Flow Redesign — 2026-04-30

- `MockExamSectionDetailScreen` accepts `skillKind` + `maxPoints`,
  dispatches `SectionResultCard` instead of always `ResultCard`.
- `SectionResultCard`: unified header (skill icon + label + score +
  progress bar) + body per skill (noi/viet → `ResultCard`, nghe/doc →
  `ObjectiveResultCard`).
- `ObjectiveResultCard`: card-per-question (green/red bg), 2-line
  wrong-answer layout, passage collapsible for doc.
- `_buildAnalyzingView`: LinearProgressIndicator + step list per
  speaking section (✓/⏳/○).
- 4 i18n keys: `objectiveYourAnswer`, `objectiveCorrectAnswer`,
  `viewPassage`, `hidePassage`.
- Bug fix `AdvanceMockExam`: query went from "first pending" to JOIN
  attempts ON exercise_id — fixes 400 on mixed-skill exams.
- Feature: `QuestionResult.question_text`,
  `QuestionResult.learner_answer_text` + `correct_answer_text` —
  backend extracts option text so Flutter renders "A — Nová kavárna".
- Bug fix: overall score invisible in result hero — `RichText` root
  `TextSpan` did not inherit `DefaultTextStyle`; explicit `color:
  AppColors.onSurface` added.
- Specs: `docs/specs/exam-result-flow-redesign.md` +
  `exam-result-flow-implementation.md`.
- Tests: 16 widget tests in `section_result_card_test.dart`.

---

## V9 — CMS Exercise Dashboard Upgrade — 2026-04-30

- `exercise-dashboard.tsx` 2036 lines → 5 files: `exercise-utils.ts`,
  `exercise-list.tsx`, `exercise-form/index.tsx`, `exercise-matrix.tsx`,
  `exercise-dashboard.tsx` (thin orchestrator, 211 lines).
- Coverage Matrix: Module rows × 4 cols (Nói/Nghe/Viết/Đọc), color by
  published count vs target 20, grouped by Course, sorted by
  sequence_no.
- Cell click → set module+skill_kind filter + smooth scroll; toggle
  cell → clear filter.
- Tab "Exam Pool": mini-matrix per exercise_type (Tổng / Published /
  Có ảnh) + flat list; click row → filter.
- Form prefill: matrix-cell-active tap on "+ Tạo exercise" auto-fills
  moduleId + skillKind and advances wizard to step 2.
- Loading skeleton + API error banner with retry.
- Vitest 49 unit tests on `buildMatrix`, parse/build, payload builders.
- Specs: `docs/specs/exercise-dashboard-upgrade.md`.

---

## V8 — Schema Flatten — 2026-04-30

- `skills` table dropped (migrations 017–019).
- `exercises.module_id` + `exercises.skill_kind` replaces
  `exercises.skill_id → skills`.
- `vocabulary_sets.module_id`, `grammar_rules.module_id` replace
  `skill_id`.
- `GET /v1/modules/:id/skills` returns computed `SkillSummary[]`.
- `GET /v1/modules/:id/exercises?skill_kind=X` filters server-side.
- CMS removed `/skills` page; exercise form picks module directly.
- Flutter: `SkillSummary` replaces `Skill`.
- Specs: `docs/specs/schema-flatten-skills.md`.

---

## V7 — Flexible Sprint MockTest — 2026-04-29

- Per-MockTest `pass_threshold_percent` (default 80 sprint / 60 full).
- Admin picks any exercise types per section (not locked to
  session_type).
- Flutter `MockExamScreen` routes section to correct screen
  (speaking/listening/reading/writing).
- `computeScoring` uses dynamic threshold (no hardcoded 24).
- CMS removes `session_type`; adds `pass_threshold_percent` input.
- Intro screen passScore from threshold; result shows % threshold met.

---

## V6 — LLM-Assisted Vocab & Grammar — 2026-04-28

- Async LLM job (Claude tool_use) → admin review/edit → publish atomic.
- Postgres tables: `vocabulary_sets`, `vocabulary_items`,
  `grammar_rules`, `content_generation_jobs`.
- CMS `/vocabulary`: VocabularySet list + edit/delete + Generate →
  inline editors → Save draft / resume / Publish. CMS `/grammar`: full
  parity.
- Flutter: `VocabGrammarExerciseScreen` + `QuizcardWidget` (flip) +
  `MatchingWidget` + filter pills.
- Rate limit: 1 active generation job per admin per module.

---

## Earlier slices (V2–V5) — late 2026-04

- **V2 Writing** (`psani_1_formular`, `psani_2_email`): submit-text
  endpoint, writing scorer, LLM feedback with diff highlight,
  `WritingExerciseScreen` with word-count gate. Bug fixes: parser
  type-coercion for `detail['questions']`, `writingMinWords` defaults
  per type, `_WritingResultPoller` 2-min timeout, `LocaleScope.code`
  used everywhere, `defer recover()` on async scoring goroutine,
  `MaxBytesReader(64KB)` + 500-word cap, Czech UTF-8 fix in
  `api_client.dart` (`_IOSinkImpl` was latin1).
- **V3 Listening** (`poslech_1-5`): submit-answers sync, Polly TTS
  per exercise (2 voices for poslech_4), audio store +
  `GET/POST /v1/exercises/:id/audio`, MultipleChoice/FillIn widgets,
  ObjectiveResultCard.
- **V4 Reading** (`cteni_1-5`): reuses objective scorer with
  case-insensitive substring match for fill-in; SelectableText passage
  in Flutter.
- **V5 Full MockTest**: `session_type` (speaking/pisemna/full) +
  `FullExamSession` (pisemna_score ≥42/70 + ustni_score ≥24/40);
  `POST /v1/full-exams`, `GET /v1/full-exams/:id`, `complete`. Auto-link
  speaking session into open FullExamSession.

---

## V1 baseline (mock + AWS path verified)

- Go backend with attempt upload, learner polling, transcript
  provenance, task-aware feedback for all four oral task types.
- Postgres persistence (opt-in) for exercises, attempts, transcripts,
  feedback.
- S3 + Amazon Transcribe path (verified end-to-end on production).
- LLMFeedbackProvider + LLMReviewProvider (Claude), fail-soft to
  rule-based on error or when unset.
- Amazon Polly TTS for model-answer audio in review artifacts.
- CMS CRUD for all four oral task types with status select; only
  `published` exercises surface to learners.
- CMS prompt-asset upload + preview for `Uloha 3` and `Uloha 4`.
- Compose: named volumes for `backend_assets` + `backend_attempts`;
  `AUDIO_SIGN_SECRET` threaded; `TRANSCRIBE_TIMEOUT` default 3m;
  `LOCAL_ASSETS_DIR` set to volume path.
- Flutter learner flow for all four oral tasks: split Stop/Analyze,
  AnalysisScreen, ResultCard, recent attempts, audio replay, review
  artifact.
- i18n VI + EN via ARB / `cms/lib/i18n.tsx`.
- Provider-aware audio streaming with short-lived signed URLs.
- Mock exam V2: per-section max_points, intro screen, scored result.
- V2 UI design system (Babbel orange `#FF6A14` + warm cream `#FBF3E7` +
  teal `#0F3D3A`; Inter / Fraunces; CMS sidebar; Flutter screen
  redesigns).
- `criteria_results` parsed in Flutter `AttemptFeedbackView` as
  `CriterionCheckView`.
- Admin content guide: `docs/admin-guide.md`.

---

## Cross-cutting hardening rounds

### Infrastructure (2026-04-29 + 2026-05-01)

- `ExerciseAudioStore` + `postgresExerciseAudioStore`: audio metadata
  persists across restart. `LOCAL_ASSETS_DIR` must point to a named
  volume so the MP3 also persists.
- `FullExamStore` + `postgresFullExamStore`: full exam sessions
  persist.
- Polly 2-voice dialog generator for `poslech_4`:
  `DialogExerciseAudioGenerator` + `GenerateDialogAudio()` alternating
  voices + MP3 concat. `POLLY_VOICE_ID_2` env.
- Polly TTS for writing `model_answer_text` in `ProcessWritingAttempt`.

### Security (2026-04-29)

- Dev tokens (`dev-admin-token`, `dev-learner-token`,
  `dev-learner-2-token`) only seed when `ENV != production`. Production
  must set `ENV=production` before deploy.
- `ADMIN_PASSWORD` startup guard: fatal exit if empty or `"demo123"`
  in production. Bcrypt support (`$2a$`/`$2b$` prefix) via
  `golang.org/x/crypto/bcrypt`; dev still plaintext.
- `handleSubmitText`: `MaxBytesReader(64KB)` + 500-word cap.
- CORS: `withCORS` reads `CORS_ALLOWED_ORIGINS` (comma-separated).
  Production without var → no ACAO header. Dev without var → wildcard.
- Audio upload ownership: `handleRecordingStarted`, `handleUploadURL`,
  `handleAttemptAudioUpload`, `handleUploadComplete` all run
  `authorizedAttemptForUser`.
- CMS `admin_token` cookie: `secure: true` when `NODE_ENV=production`.
- `CORS_ALLOWED_ORIGINS` required in `.env.ec2` production.
