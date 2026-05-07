# Plan — V21.3 CEFR UI Wire-up

Source spec:    `docs/specs/cefr-ui-wireup.md`
Idea:           `docs/ideas/cefr-ui-wireup.md`
Related specs:  `docs/specs/cefr-level-progression.md`,
                `docs/specs/cefr-level-progression-ux.md`
SPEC summary:   `SPEC.md` § V21.3 (added on ship)

---

## Architecture Decisions

**No new state-management library.**
`CefrAuthGate` is a `StatefulWidget` owning one `Future<UserProgress>`,
matching the existing `_V17AuthGate` pattern in `main.dart`. Adding
Provider / Riverpod / Bloc just for a single gate would double the
slice's surface area for zero readability win.

**Server is sole authority — client only routes.**
The gate, banner, and locked tiles read flags from
`/v1/users/me/progress` and never recompute. If the server says
`promotion_unlocked=true`, banner shows; if a course's
`required_level` exceeds `current_level`, lock tile renders. Mirrors
the V21 architecture decision in `cefr-level-progression-plan.md`.

**Reuse `MockTestRunner` for both placement and promotion.**
The existing runner already accepts `is_placement` / `is_promotion`
flags through the mock-exam payload. `PlacementTestScreen` and the
existing `PreExamScreen` are thin wrappers that fetch the right
mock-test id, push the runner, and dispatch the result screen on
submit. No fork.

**`SharedPreferences` access funnels through one helper.**
`core/storage/cefr_prefs.dart` owns the two keys
(`cefr_existing_prompt_shown`, `promo_banner_dismissed_for_<level>`).
Widgets read/write only through this helper so test setup can call
`SharedPreferences.setMockInitialValues` without scattering keys
across the tree.

**Force-prompt-once is the strict policy.**
Existing-A2 confirm dialog records its decision **only** when the
learner taps "Đúng" or finishes a re-test. Back-gesture or
ambient-dismiss leaves prefs unset on purpose, so the prompt
returns next launch. The dialog therefore uses `barrierDismissible:
false` and intercepts the system back button.

**Banner is end-of-session, not in-session.**
Discovery is driven by `HomeLevelHeader._refresh()` running on
`AnimatedBuilder` rebuild after `Navigator.pop` from an exercise.
There is no global event bus — the existing rebuild path is
sufficient.

**No backend changes.**
If a needed field on `/v1/users/me/progress` is missing, this slice
blocks rather than papers over. The slice ships as a Flutter-only
diff so the V21 backend stays the auditable source.

---

## Dependency Graph

```
[A] Foundation
    A1 CefrPrefs storage helper
    A2 LevelApi method audit (placement-test/skip, promotion-exam/start)
       │
       ├──► [B] Fresh signup flow (vertical slice 1)
       │      B1 PlacementTestScreen wrapper
       │      B2 CefrAuthGate skeleton (loading + fresh-A0 + already-onboarded)
       │      B3 Wire gate into main.dart
       │      B4 Welcome onStart/onSkip → placement / skip API
       │      B5 PlacementResultScreen continue → gate re-fetch → LearnerShell
       │            │
       │            └──► Checkpoint B: A1, A2, A3 acceptance criteria met
       │
       ├──► [C] Existing A2 confirm dialog (vertical slice 2)
       │      C1 ExistingLevelConfirmDialog (barrierDismissible:false)
       │      C2 Extend CefrAuthGate with existing-A2 branch
       │      C3 Wire choices (skip API + prefs vs re-test)
       │      C4 Force-prompt regression tests
       │            │
       │            └──► Checkpoint C: A4 met
       │
       ├──► [D] Home level header + locked courses (vertical slice 3)
       │      D1 Mount HomeLevelHeader inside CourseListScreen
       │      D2 LockedCourseTile rendering by required_level
       │      D3 Tap → LockedCourseSheet + demo CTA
       │      D4 Refresh on pop-back (V20.1 pattern parity)
       │            │
       │            └──► Checkpoint D: A5, A6 met
       │
       └──► [E] Promotion exam end-to-end (vertical slice 4)
              E1 PromotionBanner gating (unlocked + not dismissed)
              E2 Banner tap → PreExamScreen(target, mockTestId)
              E3 PreExamScreen → MockTestRunner(is_promotion=true)
              E4 Submit → PromotionResultScreen (pass / fail)
              E5 Pass → progress refresh + next-level courses unlock
              E6 Fail → diagnostic + 24h cooldown timer
              E7 Mid-exercise suppression test
                    │
                    └──► Checkpoint E: A7, A8 met

[F] Polish + verify
    F1 ARB keys (vi/en parity), reduced-motion fallbacks (A9, A10)
    F2 make flutter-analyze + make flutter-test clean
    F3 make smoke-attempt-flow + make smoke-exam-flow regression
    F4 Manual MobAI walkthrough on iPhone 17 Pro Max simulator
    F5 SPEC.md row + CHANGELOG entry + plan.md/todo.md index update
```

Phases A → B → C → D → E run sequentially because each phase wires
the next user-visible surface. F runs last as the verification gate.

Within each phase, tasks are vertical slices: one complete path
through the layers (storage → api → widget → router → test) rather
than horizontal layers across the codebase.

---

## Phase A — Foundation

### A1. CefrPrefs storage helper

**File**: `flutter_app/lib/core/storage/cefr_prefs.dart` (new)

```dart
class CefrPrefs {
  static const _existingPromptKey = 'cefr_existing_prompt_shown';
  static String _bannerDismissKey(String level) =>
      'promo_banner_dismissed_for_$level';

  Future<bool> isExistingPromptShown();
  Future<void> markExistingPromptShown();
  Future<bool> isBannerDismissedFor(String level);
  Future<void> dismissBannerFor(String level);
}
```

**Acceptance**

- All read/write of the two keys go through this helper. Grep for
  raw key strings outside this file returns zero hits.
- Unit tests cover both keys with
  `SharedPreferences.setMockInitialValues`.

**Verify**: `cd flutter_app && flutter test test/core/storage/`

### A2. LevelApi method audit

**File**: `flutter_app/lib/core/api/level_api.dart` (modify if needed)

Confirm presence of:

- `Future<PlacementSession> startPlacementTest()`
- `Future<void> skipPlacementTest()`
- `Future<PromotionSession> startPromotionExam(String targetLevel)`

**Acceptance**

- Each method has a narrow, typed return shape — no
  `Map<String, dynamic>` leaking into widget code.
- If any endpoint returns a field not yet modelled (e.g.
  `promotionMockTestId`), add it to the model class with a unit
  test covering JSON parse.
- Phase blocks if an endpoint is missing from the backend; surface
  the gap before continuing.

**Verify**: `make flutter-analyze` + `flutter test test/core/api/`

**Checkpoint A**: `make flutter-analyze` + `make flutter-test` pass.
No user-visible change yet.

---

## Phase B — Fresh signup flow

### B1. PlacementTestScreen wrapper

**File**: `flutter_app/lib/features/onboarding/placement_test_screen.dart`
(new)

`StatefulWidget` that:

1. On `initState` calls `LevelApi.startPlacementTest()`.
2. Renders `MockTestRunner(session, isPlacement: true)`.
3. On runner submit, captures the result, then
   `Navigator.pushReplacement` → `PlacementResultScreen(level)`.

**Acceptance**

- Loading state: shows `CircularProgressIndicator` while session
  fetch is in flight.
- Error state: shows retry CTA on fetch failure; back returns to
  `WelcomeScreen` without setting `placement_taken_at`.
- Submit calls the same scoring path `MockTestRunner` already uses;
  no duplicate logic.

**Test**: `flutter_app/test/features/onboarding/placement_test_screen_test.dart`
covers loading / error / submit branches with a mocked `LevelApi`.

### B2. CefrAuthGate skeleton

**File**: `flutter_app/lib/features/onboarding/cefr_auth_gate.dart`
(new)

Routing decision:

| Condition | Render |
|---|---|
| `progress` future loading | `CircularProgressIndicator` |
| `placement_taken_at != null` | `child` (LearnerShell) |
| `current_level == 'a0' && placement_taken_at == null` | `WelcomeScreen` |
| (existing-A2 branch — added in Phase C) | TBD |

Phase B wires only the loading + fresh-A0 + already-onboarded
branches.

**Acceptance**

- Refetch is exposed as `gate.refresh()` and called by the
  result screen.
- Tests cover three branches (loading, fresh A0 → welcome, already
  onboarded → child).

### B3. Wire gate into main.dart

**File**: `flutter_app/lib/main.dart` (modify)

In `_V17AuthGate.build`, replace
`return const LearnerShell();` with
`return CefrAuthGate(child: const LearnerShell());`.

**Acceptance**

- Authenticated users with `placement_taken_at != null` see exactly
  the same shell as before — no regression.

### B4. Welcome onStart / onSkip wiring

**File**: `flutter_app/lib/features/onboarding/welcome_screen.dart`
(reuse — `onStart` / `onSkip` callbacks already declared)

Inside `CefrAuthGate`, supply:

- `onStart: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlacementTestScreen()))`
- `onSkip: () async { await levelApi.skipPlacementTest(); gate.refresh(); }`

**Acceptance**

- Skip flow ends with the gate re-evaluating and rendering
  `LearnerShell`.
- A subsequent app cold start does not re-show `WelcomeScreen`.

### B5. PlacementResultScreen continue

**File**: `flutter_app/lib/features/onboarding/placement_result_screen.dart`
(reuse)

"Tiếp tục" CTA does `Navigator.popUntil(_isFirstRoute)` then calls
`gate.refresh()` so the gate transitions to `LearnerShell`.

**Acceptance**

- A1, A2, A3 acceptance criteria from the spec all pass on a
  manual run.

**Checkpoint B**

- `make flutter-test` clean.
- Manual: fresh signup → welcome → placement test → result →
  shell.
- Manual: skip flow → shell.

---

## Phase C — Existing A2 confirm dialog

### C1. ExistingLevelConfirmDialog

**File**: `flutter_app/lib/features/onboarding/existing_level_confirm_dialog.dart`
(new)

`StatelessWidget` rendering an `AlertDialog` with:

- Headline: "Bạn đang ở cấp độ A2"
- Body: "Bạn có muốn làm lại bài test phân loại?"
- Primary CTA: "Đúng — tôi đang ở A2"
- Ghost CTA: "Làm test phân loại lại"

Use `barrierDismissible: false` and a `WillPopScope` that absorbs
the back gesture (returns `false` without popping).

**Acceptance**

- No way to dismiss without choosing.
- Dialog announces itself via `Semantics(container: true, ...)`.
- ARB keys for both CTAs in vi + en.

### C2. Extend CefrAuthGate

Add branch:

```
current_level == 'a2'
  && placement_taken_at == null
  && !(await prefs.isExistingPromptShown())
→ schedule postFrameCallback to show ExistingLevelConfirmDialog
  over the LearnerShell child
```

**Acceptance**

- Dialog shows over the rendered shell, not in a separate route.

### C3. Wire dialog choices

- "Đúng": `levelApi.skipPlacementTest()` →
  `prefs.markExistingPromptShown()` → close dialog.
- "Làm lại": close dialog → push `PlacementTestScreen`. On result,
  `prefs.markExistingPromptShown()`.

**Acceptance**

- Flag is set only on a recorded choice. Back-gesture leaves it
  unset (test asserts).

### C4. Force-prompt regression tests

`flutter_app/test/features/onboarding/cefr_auth_gate_test.dart`:

- `existing A2, prompt not shown → dialog appears once`
- `existing A2, prompt already shown → dialog does not appear`
- `back-gesture absorbed → flag still false`

**Checkpoint C**

- A4 acceptance criterion met.
- SQL-seeded existing A2 fixture run on simulator confirms one-time
  prompt.

---

## Phase D — Home level header + locked courses

### D1. Mount HomeLevelHeader

**File**: `flutter_app/lib/features/home/screens/course_list_screen.dart`
(modify)

Replace the current top of the scroll view with a `Column`:

```
Column(
  HomeLevelHeader(progress, onTapBanner, onTapLockedSheet),
  ...existing course list,
)
```

**Acceptance**

- Above fold: badge + ring + (conditional) banner.
- Mounting does not break existing scroll position handling.

### D2. LockedCourseTile rendering

For each course row, choose between:

- existing tile when `course.required_level <= currentLevel`
- `LockedCourseTile(course)` when `required_level > currentLevel`
- existing tile + "Demo" chip when course is the demo for an
  upper level (server-flagged)

**Acceptance**

- A6 acceptance criterion: locked tiles render exclusively for
  upper-level courses.

### D3. Tap-locked-tile → sheet

`LockedCourseTile.onTap` opens
`showModalBottomSheet(builder: LockedCourseSheet(course, mastery))`.
Demo CTA inside sheet pushes the demo exercise via the existing
exercise screen route, with `recordMastery: false`.

**Acceptance**

- Demo run does not write to mastery (asserted via post-run progress
  diff).

### D4. Refresh on pop-back

After `Navigator.pop` from any exercise screen,
`CourseListScreen` calls `setState(() => _progressFuture = levelApi.fetchProgress())`.
Matches the V20.1 `HomeProgressCard.refresh()` pattern.

**Acceptance**

- A5 acceptance criterion: the badge / ring reflect the new
  mastery within one frame after pop.

**Checkpoint D**

- A5, A6 met.
- Visual on simulator matches `cefr-level-progression-ux.md`
  § "Information Hierarchy — Home".

---

## Phase E — Promotion exam end-to-end

### E1. PromotionBanner gating

`HomeLevelHeader` shows `PromotionBanner` when
`progress.promotionUnlocked == true`
&& `!(await prefs.isBannerDismissedFor(progress.targetLevel))`.

The banner has no explicit dismiss CTA in V21.3 — the dismissal flag
is set by E5 (post-pass) only. Failing the exam keeps the banner
visible during cooldown so the user can retry.

**Acceptance**

- A7 acceptance criterion: banner does not appear mid-exercise.

### E2. Banner tap

`PromotionBanner.onTap` →
`Navigator.push(MaterialPageRoute(builder: (_) =>
PreExamScreen(targetLevel, promotionMockTestId)))`.

### E3. PreExamScreen → runner

`PreExamScreen` "Bắt đầu thi" CTA pushes
`MockTestRunner(session, isPromotion: true)`.

**Acceptance**

- Reuses existing runner. No duplicated UI.

### E4. Submit → PromotionResultScreen

Runner's submit handler returns the outcome to the caller. The
caller (`PreExamScreen`'s push handler) maps the outcome to
`PromotionResultScreen.pass(...)` or
`PromotionResultScreen.fail(diagnostic, cooldownEnd)`.

### E5. Pass branch

- `prefs.dismissBannerFor(prevLevel)` so the banner does not return
  for the same target.
- `gate.refresh()` (or equivalent) so `current_level`,
  `unlocked_levels`, and the course list update.
- `Navigator.popUntil(_isFirstRoute)` ends back on Home.

**Acceptance**

- A8 acceptance criterion pass branch: next-level courses unlock
  visibly within one frame.

### E6. Fail branch

- Render diagnostic table from spec § 6.
- Live cooldown caption updated by a `Timer.periodic(1s)` scoped
  to the caption (suggestion S4 — apply now since it lives in the
  same render).
- "Luyện skill yếu nhất" CTA pops to the course list filtered by
  failing skill_kind.

**Acceptance**

- Cooldown timer reaches `00:00:00` and CTA re-enables. (Live
  re-attempt is separately covered by V21 backend tests; this
  slice only verifies the UI clears.)

### E7. Mid-exercise suppression test

`promotion_banner_test.dart`:

- `promotionUnlocked=true && exercise route on stack → banner not
  visible` (we assert on `CourseListScreen` build state with a
  faked navigator history).
- `promotionUnlocked=true && popped back → banner visible after
  refresh`.

**Checkpoint E**

- A7, A8 met.
- Manual MobAI promotion run (pass + fail) recorded for the
  CHANGELOG entry.

---

## Phase F — Polish + verify

### F1. ARB keys + reduced-motion

Add new keys for: welcome CTAs already exist (V20+); add for
existing-A2 dialog headlines + CTAs, banner text if not already in
`v21*` ARB block. Confirm vi + en counts match. Add
`MediaQuery.disableAnimations` guards on placement reveal, ring
pulse, pass celebration.

**Acceptance**

- `make flutter-analyze` clean.
- A9, A10 acceptance criteria met.

### F2. Automated suite

- `make flutter-analyze`
- `make flutter-test`
- `make backend-test` (regression — should be unchanged)
- `make cms-lint` + `make cms-build` (regression)

### F3. Smoke

- `make smoke-attempt-flow`
- `make smoke-exam-flow`

### F4. Manual MobAI walkthrough

iPhone 17 Pro Max simulator; record screen for each acceptance
criterion A1..A10. Attach the run summary to the V21.3 CHANGELOG
entry.

### F5. Doc + index update

- `SPEC.md`: append a row to the digest table for V21.3.
- `CHANGELOG.md`: full entry with file changes + final test counts.
- `tasks/plan.md`: add V21.3 row to the per-slice plan table.
- `tasks/todo.md`: tick this slice's open items, leave V21.3
  deferred polish (if any) in the index.
- `docs/architecture/current-code-shape.md`: refresh the Flutter
  feature tree if file count changes materially.

---

## Risk Register

| Risk | Mitigation |
|---|---|
| Force-prompt collides with V21.2 attempts-quota toast on first launch | Show dialog after one frame so the toast (already enqueued) clears first. Both keyed on prefs to avoid duplicate dispatch. |
| `MockTestRunner` does not currently route back the placement / promotion outcome shape we need | Phase A2 audits this. If a gap exists, the slice blocks at A2 and surfaces the runner change as a prerequisite — not as scope creep here. |
| Placement abandonment due to 12-min length | Welcome screen already exposes "Bỏ qua". Result screen post-skip lands on A0; user can re-enter from Profile (out of scope this slice — track as deferred polish). |
| Banner re-fires on every Home return after pass | E5 sets `prefs.dismissBannerFor(prevLevel)` and the server returns `promotion_unlocked=false` for the new state, double-protecting against re-fire. |
| Hidden coupling between auth gate refresh and existing `_V17AuthGate` rebuild | Confirm in B3 that the gate sits **inside** the authenticated branch only, not above it. The dialog (Phase C) attaches to the inner gate's context, never the outer one. |

## Estimated Scope

- ~6 new Dart files, ~4 modified.
- New tests: 5 widget files (~20 cases).
- ARB delta: ≤ 8 new keys per locale.
- No backend / CMS / migration / smoke-script changes.

## Out of Scope (carried forward)

- `LevelHistoryScreen` (UX spec optional V2 deferment).
- B1 content seeding.
- "Làm lại placement test" entry-point inside Profile for users who
  already onboarded.
- Re-introducing dismiss CTA on `PromotionBanner`.
