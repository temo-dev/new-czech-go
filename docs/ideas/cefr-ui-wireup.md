# CEFR UI Wire-up — Idea Note

> Pre-spec one-pager. Decided 2026-05-07. Pairs with
> `docs/specs/cefr-ui-wireup.md`.

## Problem

V21 + V21.1 + V21.2 shipped the full backend for CEFR level
progression (placement test, mastery aggregate, promotion exam,
gating). The Flutter app contains all the V21 widgets — `LevelBadge`,
`LevelProgressRing`, `HomeLevelHeader`, `LockedCourseTile`,
`LockedCourseSheet`, `PromotionBanner`, `PreExamScreen`,
`PromotionResultScreen`, `placement_result_screen.dart`,
`onboarding/welcome_screen.dart` — but **none of them are wired into
the router or any parent screen**. Concretely:

- `_V17AuthGate` (`flutter_app/lib/main.dart:104`) goes
  unauthenticated → `auth/WelcomeScreen` and authenticated →
  `LearnerShell`. There is no placement gate in between.
- `LearnerShell` Home tab (`main.dart:294`) renders
  `CourseListScreen` directly. No `HomeLevelHeader`, no
  `PromotionBanner`, no level chip.
- `CourseListScreen` does not import any V21 lock/level widgets.
- `PreExamScreen` and `PromotionResultScreen` have zero call sites.
- No `PlacementTestScreen` wrapper exists; the placement flow simply
  cannot be reached from the app.

Net effect: a learner installs → signs up → lands on the same A0/A2
Course list as before. CEFR progression is invisible. The full
backend investment from V21..V21.2 is dormant.

## Why now

- V21.2 just shipped the runtime hotfixes from the MobAI test;
  backend is the most stable it has been since V21 cut.
- Existing users were already flipped to `current_level=a2` by
  migration 026, so the moment the UI surfaces it they will see the
  correct level — no data backfill required.
- Promotion exam is the headline feature for B1 expansion. Without
  wire-up it ships as code-only.

## Decisions (locked from clarification)

| Question | Choice | Reason |
|---|---|---|
| Scope | Full wire-up (auth gate + Home header + locked courses + promotion flow + new `PlacementTestScreen` wrapper) | Anything less leaves a half-built feature visible to the learner. |
| Placement test length | 12-min full (15 × 4 skills) | Higher signal beats lower drop-off for a one-time onboarding. |
| Promotion banner timing | End-of-session only | Avoids cutting into an in-progress exercise. Matches UX spec lean. |
| Existing A2 user | Force prompt once | Migration 026 set `current_level=a2` but `placement_taken_at IS NULL`. Existing users deserve one explicit confirmation modal with Skip. |

## Out of scope

- New CEFR levels beyond A0..B1 (schema is ready, content is not).
- Placement test content authoring — reuses the
  `mock_tests.is_placement=true` row that V21 already seeded.
- Re-design of `CourseListScreen` layout — only adds lock state
  rendering for courses where `required_level > current_level`.
- Mastery tuning, scoring, or backend changes — V21..V21.2 already
  shipped these.
- `LevelHistoryScreen` (UX spec called it optional V2) — defer.

## Risk register

- **Force-prompt collision** with V21.2 attempts-quota toast — both
  fire on first home mount. Mitigation: prompt runs after quota
  refresh completes; both keyed on `SharedPreferences` so no
  duplicate dispatch.
- **Placement abandonment** — 12 min is long. Mitigation: explicit
  "Bỏ qua" skip CTA on `WelcomeScreen` (already implemented) routes
  user to A0; banner returns later from Profile.
- **Banner spam** — end-of-session trigger can re-fire on every
  return to Home. Mitigation: state is server-driven
  (`promotion_unlocked`); once user enters PreExamScreen and either
  passes or enters cooldown, banner reflects new server state.
