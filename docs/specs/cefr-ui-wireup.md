# CEFR UI Wire-up — Spec

> Slice: V21.3. Frozen on ship. Pair with
> `docs/ideas/cefr-ui-wireup.md` (idea note) and the existing
> `docs/specs/cefr-level-progression.md` /
> `docs/specs/cefr-level-progression-ux.md` (functional + UX) which
> remain authoritative for CEFR semantics. This slice spec only owns
> **wire-up + new wrappers**.

## 1. Objective

Make every V21 CEFR widget reachable in the Flutter learner app so
that:

1. A fresh signup is asked to take a placement test before reaching
   the course list.
2. An existing A2 user is prompted once to confirm or replace their
   level.
3. The Home screen visibly shows the learner's current level,
   per-skill mastery ring, and a promotion-ready banner when
   eligible.
4. The course list visually distinguishes unlocked / current / demo /
   locked courses.
5. The promotion exam can be reached, taken, scored, and concluded
   end-to-end through the existing `MockTestRunner`.

This is a wire-up slice. No new backend endpoints. No new content.
No CEFR algorithmic changes.

## 2. Target users

- **Fresh signup** (zero attempts, `placement_taken_at IS NULL`,
  `current_level='a0'`): lands on placement onboarding.
- **Existing A2** (migration 026 backfilled `current_level='a2'`,
  `placement_taken_at IS NULL`, attempts may exist): sees the
  one-time confirmation prompt.
- **Promotion-ready** (mastery aggregate ≥ threshold, server returns
  `promotion_unlocked=true`): sees end-of-session banner on next
  return to Home.

## 3. User flows

### 3.1 Fresh signup

```
SignupScreen → AuthService.authenticated
  → AuthGate fetches GET /v1/users/me/progress
  → progress.placementTakenAt == null && currentLevel == 'a0'
  → onboarding/WelcomeScreen
       ├─ "Bắt đầu kiểm tra phân loại" → PlacementTestScreen
       │     → MockTestRunner(is_placement=true, mockTestId from
       │                      GET /v1/placement-test/start)
       │     → submit → PlacementResultScreen(level)
       │     → "Tiếp tục" → LearnerShell(Home)
       └─ "Bỏ qua — bắt đầu từ A0"
             → POST /v1/placement-test/skip (sets placement_taken_at)
             → LearnerShell(Home)
```

### 3.2 Existing A2 first launch after release

```
LoginScreen → AuthService.authenticated
  → AuthGate fetches progress
  → currentLevel == 'a2' && placementTakenAt == null
       && SharedPreferences['cefr_existing_prompt_shown'] != true
  → ExistingLevelConfirmDialog (modal over LearnerShell)
       ├─ "Đúng — tôi đang ở A2"
       │     → POST /v1/placement-test/skip
       │     → SharedPreferences set true
       │     → dismiss → Home
       └─ "Làm test phân loại lại"
             → PlacementTestScreen flow (same as 3.1)
             → on result, set SharedPreferences true
```

The dialog fires exactly once per device. If the user dismisses via
back gesture without choosing, `SharedPreferences` is **not** set —
the prompt returns next launch (force prompt is non-skippable
without an explicit choice).

### 3.3 Promotion-ready end-of-session

```
ExerciseScreen finish → pop back to LearnerShell(Home)
  → HomeLevelHeader._refresh() re-fetches progress
  → progress.promotionUnlocked == true
       && SharedPreferences['promo_banner_dismissed_for_<level>']
          != true
  → PromotionBanner becomes visible (sticky under ring)
  → tap → PreExamScreen(targetLevel, promotionMockTestId)
       → "Bắt đầu thi" → MockTestRunner(is_promotion=true)
       → submit → PromotionResultScreen(outcome)
            ├─ pass → celebration + auto pop to Home
            │         → next-level courses unlock
            └─ fail → diagnostic table + 24h cooldown timer
                      → "Luyện skill yếu nhất" deep-link
```

Banner is **not** shown mid-session. End-of-session = the
`AnimatedBuilder` listening on `AuthService` re-runs after
`Navigator.pop` from the exercise screen, triggering
`HomeLevelHeader._refresh()`.

## 4. Screen and component inventory

| File | Status | Notes |
|---|---|---|
| `flutter_app/lib/main.dart` | modify | Add CEFR auth gate between `AuthState.authenticated` and `LearnerShell`. |
| `flutter_app/lib/features/onboarding/cefr_auth_gate.dart` | **new** | Owns progress fetch + routing decision (welcome / dialog / shell). |
| `flutter_app/lib/features/onboarding/placement_test_screen.dart` | **new** | Wraps `MockTestRunner` with `is_placement=true`; calls `GET /v1/placement-test/start` first. |
| `flutter_app/lib/features/onboarding/existing_level_confirm_dialog.dart` | **new** | Stateless dialog used by gate for §3.2. |
| `flutter_app/lib/features/onboarding/welcome_screen.dart` | reuse | Already exists; gate wires `onStart` / `onSkip` callbacks. |
| `flutter_app/lib/features/onboarding/placement_result_screen.dart` | reuse | Already exists. |
| `flutter_app/lib/features/home/screens/course_list_screen.dart` | modify | Render `HomeLevelHeader` above the course list; switch each course tile to `LockedCourseTile` when `required_level > current_level`. |
| `flutter_app/lib/features/home/widgets/home_level_header.dart` | reuse | Mount inside `CourseListScreen`. |
| `flutter_app/lib/features/home/widgets/promotion_banner.dart` | reuse | Tap handler navigates to `PreExamScreen`. |
| `flutter_app/lib/features/promotion/pre_exam_screen.dart` | reuse | Wired from banner. |
| `flutter_app/lib/features/promotion/promotion_result_screen.dart` | reuse | Returned from `MockTestRunner` post-submit. |
| `flutter_app/lib/features/courses/widgets/locked_course_tile.dart` | reuse | Mounted by `CourseListScreen`. |
| `flutter_app/lib/features/courses/widgets/locked_course_sheet.dart` | reuse | Triggered when learner taps a locked tile. |
| `flutter_app/lib/core/storage/cefr_prefs.dart` | **new** | Thin `SharedPreferences` wrapper for the two keys (`cefr_existing_prompt_shown`, `promo_banner_dismissed_for_<level>`). |

## 5. Backend contract (no changes)

This slice consumes existing endpoints only:

| Endpoint | Used by |
|---|---|
| `GET /v1/users/me/progress` | `CefrAuthGate`, `HomeLevelHeader._refresh`, post-attempt refresh |
| `GET /v1/placement-test/start` | `PlacementTestScreen` |
| `POST /v1/placement-test/skip` | `WelcomeScreen.onSkip`, existing-A2 dialog confirm |
| `GET /v1/promotion-exam/start` | `PreExamScreen` |
| `POST /v1/mock-exam-sessions/:id/submit` | `MockTestRunner` (existing) |

If any field needed by the wire-up is missing from
`/v1/users/me/progress` (e.g. `promotionMockTestId`), file an issue
and block this slice rather than adding it ad-hoc.

## 6. Acceptance criteria

A1. Fresh signup ends on `WelcomeScreen` (placement intro), not
   `LearnerShell`.
A2. Tapping "Bắt đầu kiểm tra phân loại" submits a placement attempt
   end-to-end and lands on `PlacementResultScreen`. The reported
   level matches the value of `users.current_level` written by the
   backend.
A3. Tapping "Bỏ qua" calls `POST /v1/placement-test/skip`, sets
   `placement_taken_at`, and lands on Home. A subsequent app launch
   does not re-show the welcome screen.
A4. An existing A2 user (seeded via SQL: `current_level='a2'`,
   `placement_taken_at IS NULL`) sees the confirm dialog exactly
   once. After a choice is recorded, the dialog never returns on
   that device.
A5. Home tab shows `HomeLevelHeader` above the course list.
   `LevelBadge` reports the current level. `LevelProgressRing`
   renders six arcs filled per skill mastery from
   `/v1/users/me/progress`.
A6. Course list renders any course with `required_level >
   current_level` as a `LockedCourseTile`. Tap opens
   `LockedCourseSheet`. Demo button on the sheet opens the demo
   exercise without writing mastery.
A7. When `progress.promotionUnlocked == true`, returning to Home
   from a finished exercise reveals `PromotionBanner` within one
   refresh cycle. Mid-exercise the banner does not appear.
A8. Banner tap → `PreExamScreen` → "Bắt đầu thi" →
   `MockTestRunner(is_promotion=true)` → submit →
   `PromotionResultScreen`. Pass branch returns to Home with
   next-level courses unlocked. Fail branch shows diagnostic +
   live cooldown.
A9. All new strings flow through `app_vi.arb` + `app_en.arb` with
   matching key counts.
A10. Reduced-motion is honored — placement reveal, ring pulse, and
   pass celebration each fall back to a static state when
   `MediaQuery.disableAnimations` is true.

## 7. Verification

| Layer | Command | Expectation |
|---|---|---|
| Flutter | `make flutter-analyze` | clean |
| Flutter | `make flutter-test` | new tests for `CefrAuthGate`, `PlacementTestScreen`, existing-level dialog, course list lock rendering, promotion banner gating |
| Backend | `make backend-test` | unchanged (regression only) |
| Smoke | `make smoke-attempt-flow` + `make smoke-exam-flow` | unchanged |
| Manual | iPhone 17 Pro Max simulator via MobAI | walk all three flows in §3 |

The slice ships when all four automated commands pass and the MobAI
walkthrough records each acceptance criterion.

## 8. Code style

- Reuse existing tokens (`AppColors`, `AppSpacing`,
  `AppTypography`); no new design system.
- Lucide / Material vector icons only — no emoji as structural
  icons (per `AGENTS.md` § "Common Rules").
- `CefrAuthGate` is a `StatefulWidget` that owns one
  `Future<UserProgress>`; do **not** introduce a Provider / Riverpod
  / Bloc just for this slice — match the existing
  `_V17AuthGate` style.
- `SharedPreferences` access goes through `core/storage/cefr_prefs.dart`
  only; no scattered `getInstance()` calls.
- Prompts and copy live in ARB; no inline VI/EN string literals in
  widget code (matches V20 conventions).
- Any LLM-related changes (none expected) must respect the
  `backend/internal/processing` single-source-of-truth rule from
  `AGENTS.md`.

## 9. Project structure deltas

```
flutter_app/lib/
  core/
    storage/
      cefr_prefs.dart                            (new)
  features/
    onboarding/
      cefr_auth_gate.dart                        (new)
      placement_test_screen.dart                 (new)
      existing_level_confirm_dialog.dart         (new)
      placement_result_screen.dart               (existing)
      welcome_screen.dart                        (existing)
    home/
      screens/
        course_list_screen.dart                  (modify)
      widgets/
        home_level_header.dart                   (existing, mounted)
        level_badge.dart                         (existing)
        level_progress_ring.dart                 (existing)
        promotion_banner.dart                    (existing)
    promotion/
      pre_exam_screen.dart                       (existing, wired)
      promotion_result_screen.dart               (existing, wired)
    courses/
      widgets/
        locked_course_tile.dart                  (existing, mounted)
        locked_course_sheet.dart                 (existing, mounted)
  main.dart                                      (modify)
  l10n/
    app_vi.arb                                   (new keys)
    app_en.arb                                   (new keys)
```

No backend / CMS files change.

## 10. Testing strategy

- **Widget tests** (`flutter_app/test/features/onboarding/`):
  `cefr_auth_gate_test.dart` covers the four routing branches
  (loading, fresh A0, existing A2, already-onboarded). Mock
  `LevelApi`. Use `SharedPreferences.setMockInitialValues`.
- **Widget tests** for `placement_test_screen.dart` verifying it
  delegates submit to `MockTestRunner` and pushes
  `PlacementResultScreen` on completion.
- **Widget tests** for `course_list_screen.dart` that locked tiles
  appear when `required_level > current_level` and tapping opens
  the sheet.
- **Widget tests** for `promotion_banner.dart` gating: not visible
  during exercise, visible after pop with `promotionUnlocked=true`,
  cooldown state suppresses banner.
- **Golden tests** are not introduced this slice — keep parity with
  the existing test pattern in `flutter_app/test/`.
- **Manual MobAI run** documented in the slice CHANGELOG entry on
  ship.

## 11. Boundaries

**Always do**

- Fetch CEFR progress through `LevelApi` only; no direct
  `_client.get` for these endpoints in widget code.
- Push routes via `Navigator.of(context)` matching the existing
  pattern in `LearnerShell._openAttemptExercise` — no new
  router package.
- Reuse `MockTestRunner` for both placement and promotion. Do not
  fork it.
- Honor `MediaQuery.disableAnimations` for every motion added by
  this slice.
- Update `app_vi.arb` and `app_en.arb` together; keep key counts
  equal.

**Ask first**

- If `/v1/users/me/progress` lacks any field needed for routing or
  rendering. Surface the gap; do not paper over with a default.
- If acceptance criteria conflict with what `MockTestRunner`
  currently emits when `is_placement=true` or `is_promotion=true`.
- If the force-prompt-once policy is fighting the V21.2 attempts
  quota toast on first launch — the two compete for the same
  modal slot.

**Never do**

- Do not introduce a new state-management library.
- Do not duplicate `MockTestRunner` UI for placement / promotion.
- Do not write CEFR semantics (gating math, mastery thresholds,
  cooldown durations) on the client. The server is the sole
  authority (`docs/specs/cefr-level-progression.md`).
- Do not mutate `users.current_level` from the client. Only the
  server promotes / demotes.
- Do not surface the placement onboarding to a user with
  `placement_taken_at != null`. They have already chosen.
- Do not animate the confirm dialog dismissal in a way that lets
  the modal disappear without recording a choice.

## 12. Open questions resolved

| UX spec open Q | Resolution this slice |
|---|---|
| Placement length 6 min vs 12 min | **12 min full** (15 × 4 skills). |
| Banner timing — instant vs end-of-session | **End-of-session.** |
| B1 demo selection — `nghe` vs `viet` | Out of scope; demo selection stays as content authoring. |
| Promotion fail mastery effect | Already locked in V21 spec — **no decrement**, only cooldown. |
| Re-onboarding existing A2 users | **Force prompt once** with explicit Skip. |

## 13. Out of scope

- Adding `LevelHistoryScreen`.
- Designing or shipping B1 content beyond what already seeds.
- Tuning placement scoring or mastery thresholds.
- iOS / Android platform-specific affordances beyond the
  existing safe-area handling.
- Pricing, paywall, or quota changes (V21.2 already shipped these).
