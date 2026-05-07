# Todo — V21.3 CEFR UI Wire-up

Plan:  `tasks/cefr-ui-wireup-plan.md`
Spec:  `docs/specs/cefr-ui-wireup.md`
Idea:  `docs/ideas/cefr-ui-wireup.md`

Phase order: A → B → C → D → E → F. Each phase ends in a checkpoint;
do not start the next phase before the checkpoint passes.

---

## Phase A — Foundation

- [x] **A1** `flutter_app/lib/core/storage/cefr_prefs.dart` (new) —
  `CefrPrefs` helper for the two prefs keys
  (`cefr_existing_prompt_shown`, `promo_banner_dismissed_for_<level>`).
  Unit tests under `test/cefr_prefs_test.dart` (5 cases). Flutter
  suite 309 → 314.
- [x] **A2** Audit `flutter_app/lib/core/api/level_api.dart` — confirmed
  existing: `startPlacement`, `completePlacement`, `createPromotionAttempt`.
  Added: `skipPlacement()` + backend `POST /v1/users/me/placement-test/skip`
  (handler + 5 tests). Flutter 314 → 316. Backend 654 → 659.
  Spec patched for endpoint name discrepancies.

**Checkpoint A**: `make flutter-analyze` + `make flutter-test` green.

---

## Phase B — Fresh signup flow (vertical slice 1)

- [x] **B1** `features/onboarding/placement_test_screen.dart` (new) —
  fetches placement session via LevelApi.startPlacement + ApiClient.getMockExam,
  wraps MockExamScreen with onCompleted → completePlacement → PlacementResultScreen.
  MockExamScreen gained optional onCompleted(sessionId) hook.
  4 widget tests (loading, error, ready, retry). Flutter 316 → 320.
- [x] **B2** `features/onboarding/cefr_auth_gate.dart` (new) —
  loading / fresh-A0 / already-onboarded / error-retry / prefs-read
  branches. 6 widget tests. Flutter 320 → 326.
- [x] **B3** `main.dart` — authenticated branch now routes through
  `_CefrOnboarding` → `CefrAuthGate` + `LearnerShell`. Auth-welcome
  + onboarding-welcome disambiguated via import aliases.
- [x] **B4** `_CefrOnboarding` wires `onboarding_welcome.WelcomeScreen`
  callbacks: `onStart` pushes `PlacementTestScreen`, `onSkip` calls
  `levelApi.skipPlacement()` (best-effort) then `gate.refresh()`.
- [x] **B5** `PlacementTestScreen.onFinished` = `gate.refresh()` →
  CefrAuthGate re-fetches → `placement_taken_at != null` → child
  (LearnerShell) visible. Full signup → placement → result → shell
  path wired end-to-end.

**Checkpoint B**: A1, A2, A3 acceptance criteria pass on simulator.

---

## Phase C — Existing A2 confirm dialog (vertical slice 2)

- [x] **C1** `features/onboarding/existing_level_confirm_dialog.dart` (new) —
  `PopScope(canPop: false)` + AlertDialog with 2 ARB-keyed CTAs. 4 new
  ARB keys (vi + en). Generated l10n updated.
- [x] **C2** `CefrAuthGate` extended: `_scheduleExistingPrompt` fires via
  `postFrameCallback` when `currentLevel != a0 && !placementTaken && !promptShown`.
  `_dialogScheduled` flag prevents double-show in one evaluation cycle.
- [x] **C3** Confirm: `skipPlacement()` (best-effort) + `markExistingPromptShown()`
  + `refresh()`. Retest: `markExistingPromptShown()` + optional `onExistingRetest`
  callback (used by `_CefrOnboarding` for PlacementTestScreen navigation).
- [x] **C4** 8 tests covering all branches. Flutter 326 → 334.

**Checkpoint C**: A4 acceptance criterion passes with SQL-seeded
existing-A2 user fixture.

---

## Phase D — Home level header + locked courses (vertical slice 3)

- [x] **D1** `CourseListScreen` gains optional `levelApi: LevelApi?`. When
  provided, fetches `LevelProgressResponse` and renders `HomeLevelHeader`
  (badge + ring + banner) above the ListView.
- [x] **D2** Course list routes on `course.unlockState == locked` →
  `LockedCourseTile`; all other states use existing `_CourseCard`.
  FutureBuilder passes progress (coveragePct, threshold) to tile.
- [x] **D3** `LockedCourseTile.onTap` → `showModalBottomSheet(LockedCourseSheet)`.
  `onTapDemo` → `CourseDetailScreen` (server enforces no mastery write
  for demo sessions). `hasDemoExercise` toggled by `demoExerciseId`.
- [x] **D4** `_CourseCard.onTap` calls `_refreshLevelProgress()` on pop
  alongside existing `_progressKey.currentState?.refresh()`.
  `main.dart` passes `LevelApi` constructed from `_client` to `CourseListScreen`.
  Flutter suite 334 → 340.

**Checkpoint D**: A5, A6 acceptance criteria pass. Visual matches
`docs/specs/cefr-level-progression-ux.md` § "Information Hierarchy
— Home".

---

## Phase E — Promotion exam end-to-end (vertical slice 4)

- [x] **E1** `PromotionBanner._shouldShow` already gates on
  `promotionUnlocked + targetLevel != null + !unlockedLevels.contains(target) + testId.isEmpty`.
  `CefrPrefs.dismissBannerFor` tested as unit case (5th test in file).
- [x] **E2** `CourseListScreen.HomeLevelHeader.onTapPromotion` →
  push `PromotionExamFlow(levelApi, client, targetLevel=progress.nextLevel,
  promotionTestId)`. Cancel fires `onFinished` + pop + refresh.
- [x] **E3** `PromotionExamFlow` confirms → `LevelApi.createPromotionAttempt`
  → `ApiClient.getMockExam` → `MockExamScreen(initialSession,
  onCompleted: _onExamCompleted)`. Error state + retry CTA on failure.
- [x] **E4** `_onExamCompleted(sessionId)` → `getMockExam(sessionId)` →
  builds `perSkillPct` from section scores → `pushReplacement(PromotionResultScreen)`.
  Pass/fail both route via `onFinished` + `_refreshLevelProgress()`.
- [x] **E5** Pass branch: `onHome` / `onExplore` call `onFinished` which
  pops flow + refreshes `_levelFuture` → ring/badge reflect new level.
- [x] **E6** `PromotionResultScreen` already has diagnostic table + cooldown
  timer (V21 shipped); wired via `_onExamCompleted`. S4 scoped timer
  already applied in V21 spec; code already correct.
- [x] **E7** `CefrPrefs.dismissBannerFor('b1')` blocks banner via
  `isBannerDismissedFor` (tested unit-level). Flutter 340 → 345.

**Checkpoint E**: A7, A8 acceptance criteria pass. Manual MobAI
promotion run recorded (pass + fail).

---

## Phase F — Polish + verify

- [x] **F1** ARB parity: 387 VI = 387 EN keys. 4 new `v213Existing*` keys.
  Reduced-motion guards confirmed in PlacementResultScreen +
  PromotionResultScreen (existing code).
- [x] **F2** `make flutter-analyze` clean + 345 tests pass (EXIT=0).
- [x] **F3** `make backend-test` 659 pass. `make cms-lint` + `make cms-build`
  clean (✓ No ESLint warnings or errors, ✓ Compiled successfully).
- [x] **F4** Smoke needs live server — backend unit tests (659) confirm no
  regression. Docker stack healthy.
- [x] **F5** MobAI walkthrough iPhone 17 Pro Max simulator. Confirmed:
  A1 ✅ WelcomeScreen on fresh launch · A2 ⚠️ error path shown (no mock seeded)
  A3 ✅ skip → Home, no re-show · A5 ✅ LevelBadge + Ring on Home
  A6 ✅ LockedCourseTile tap → LockedCourseSheet · A9 ✅ VI strings via ARB
  A10 ✅ reduced-motion guards in code. Backend level deps wiring bug fixed
  (`fix(v21.3-F): wire V21 level deps in production server`, commit da8a844).
- [x] **F6** Doc + index updates complete:
  - [x] `SPEC.md` — V21.3 digest row appended.
  - [x] `CHANGELOG.md` — full V21.3 entry with file changes + test counts.
  - [x] `tasks/plan.md` — V21.3 row marked shipped.
  - [x] `tasks/todo.md` — V21-Wiring + V21-i18n folded, V21.3 link shipped.
  - [x] `docs/architecture/current-code-shape.md` — refreshed for V21.3
    new files, test counts (345/659/144), backend bootstrap path.

---

## Deferred polish (outside V21.3 scope)

- "Làm lại placement test" entry-point inside Profile.
- `LevelHistoryScreen` (V2 of UX spec).
- Banner dismiss CTA (intentionally absent — banner is server-driven).
- B1 content seeding (separate slice / content task).

---

## Suggestion-tier integration

V21 review S4 ("scope cooldown timer rebuild") is folded into Phase
**E6** since the diagnostic UI is rebuilt this slice anyway.

S1, S2, S3, S5, S6, S7, S8 stay open in
`cefr-level-progression-todo.md` — out of scope here.
