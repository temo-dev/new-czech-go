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
- [ ] **B2** `features/onboarding/cefr_auth_gate.dart` (new) —
  loading / fresh-A0 / already-onboarded branches. Three test cases.
- [ ] **B3** `main.dart` — `_V17AuthGate.authenticated` branch wraps
  `LearnerShell` with `CefrAuthGate`. Regression test:
  already-onboarded user sees no extra UI.
- [ ] **B4** Wire `WelcomeScreen.onStart` → `PlacementTestScreen`.
  Wire `WelcomeScreen.onSkip` → `levelApi.skipPlacementTest()` then
  `gate.refresh()`.
- [ ] **B5** `PlacementResultScreen` "Tiếp tục" CTA pops to root +
  triggers `gate.refresh()`. Manual run: signup → welcome →
  placement → result → shell.

**Checkpoint B**: A1, A2, A3 acceptance criteria pass on simulator.

---

## Phase C — Existing A2 confirm dialog (vertical slice 2)

- [ ] **C1** `features/onboarding/existing_level_confirm_dialog.dart`
  (new) — `barrierDismissible: false` + `WillPopScope` absorbing
  back. ARB keys for the two CTAs.
- [ ] **C2** Extend `CefrAuthGate` with the existing-A2 branch (gated
  on `prefs.isExistingPromptShown()`).
- [ ] **C3** Wire dialog choices: "Đúng" → skip API + prefs flag;
  "Làm lại" → push `PlacementTestScreen`.
- [ ] **C4** Tests for one-time prompt (3 cases): not shown → appears;
  shown → hidden; back-gesture → flag stays false.

**Checkpoint C**: A4 acceptance criterion passes with SQL-seeded
existing-A2 user fixture.

---

## Phase D — Home level header + locked courses (vertical slice 3)

- [ ] **D1** `features/home/screens/course_list_screen.dart` mounts
  `HomeLevelHeader` above the course list. Scroll regression test.
- [ ] **D2** Course rows switch to `LockedCourseTile` when
  `required_level > current_level`. Test fixtures with mixed
  unlocked / current / demo / locked rows.
- [ ] **D3** Tap-locked-tile opens `LockedCourseSheet` via
  `showModalBottomSheet`. Demo CTA opens demo exercise with
  `recordMastery: false`. Test: post-demo progress diff is zero.
- [ ] **D4** Refresh `_progressFuture` on `Navigator.pop` from any
  exercise screen (mirror V20.1 `HomeProgressCard.refresh()`).

**Checkpoint D**: A5, A6 acceptance criteria pass. Visual matches
`docs/specs/cefr-level-progression-ux.md` § "Information Hierarchy
— Home".

---

## Phase E — Promotion exam end-to-end (vertical slice 4)

- [ ] **E1** `PromotionBanner` visibility gated on
  `progress.promotionUnlocked` + `prefs.isBannerDismissedFor(level)`.
- [ ] **E2** Banner tap → `PreExamScreen(targetLevel,
  promotionMockTestId)`.
- [ ] **E3** `PreExamScreen` "Bắt đầu thi" pushes
  `MockTestRunner(session, isPromotion: true)`.
- [ ] **E4** Runner submit → `PromotionResultScreen` (pass / fail
  routing).
- [ ] **E5** Pass branch: `prefs.dismissBannerFor(prevLevel)` +
  `gate.refresh()` + `popUntil(root)`. Visual: next-level courses
  unlock within one frame.
- [ ] **E6** Fail branch: diagnostic table + cooldown timer scoped
  to caption (apply suggestion S4 here). "Luyện skill yếu nhất"
  deep-link.
- [ ] **E7** Test: banner not visible during exercise; visible
  after pop with `promotionUnlocked=true`.

**Checkpoint E**: A7, A8 acceptance criteria pass. Manual MobAI
promotion run recorded (pass + fail).

---

## Phase F — Polish + verify

- [ ] **F1** ARB keys for new strings (existing-A2 dialog, etc.).
  `app_vi.arb` and `app_en.arb` key counts equal. Reduced-motion
  guards on placement reveal, ring pulse, pass celebration.
- [ ] **F2** `make flutter-analyze` + `make flutter-test` clean.
- [ ] **F3** `make backend-test` regression. `make cms-lint` +
  `make cms-build` regression.
- [ ] **F4** `make smoke-attempt-flow` + `make smoke-exam-flow`
  clean.
- [ ] **F5** Manual MobAI walkthrough on iPhone 17 Pro Max
  simulator; capture A1..A10 acceptance evidence for the V21.3
  CHANGELOG entry.
- [ ] **F6** Doc + index updates:
  - [ ] `SPEC.md` — append V21.3 digest row.
  - [ ] `CHANGELOG.md` — V21.3 entry with file changes + final test
    counts.
  - [ ] `tasks/plan.md` — V21.3 row in the per-slice plan table.
  - [ ] `tasks/todo.md` — tick V21-Wiring + V21-i18n if subsumed;
    move outstanding polish into V21.3 deferred list.
  - [ ] `docs/architecture/current-code-shape.md` — refresh Flutter
    feature tree if file count changes materially.

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
