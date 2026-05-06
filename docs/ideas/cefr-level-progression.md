# CEFR Level Progression (A0 → B1)

> Status: idea — not yet specced. Pair with `docs/specs/cefr-level-progression.md`
> when promoting to a slice. Decided 2026-05-06.

## Problem Statement

How might we gate learners to content matching their CEFR level (A0/A1/A2/B1),
require them to earn enough practice mastery to unlock a level-up exam, and
only promote them after they pass that exam — without breaking the existing
A2-focused product or over-engineering for content that does not yet exist?

## Recommended Direction

**Linear-by-course ladder, 2-gate promotion, MVP = A2 + B1 only.**

Each `course` is tagged with a CEFR `level`. Learners have a single
`current_level` and a set of `unlocked_levels`. To progress:

1. **Mastery gate** — accumulate skill mastery across the current level's
   courses (reuse V19 `mastery_aggregate` per `skill_kind`) above a threshold
   per skill (e.g. ≥70%) AND reach a coverage minimum (e.g. ≥80% of modules
   touched). This unlocks the level-up exam.
2. **Promotion exam gate** — a dedicated `MockTest` flagged
   `is_promotion=true` for the target level. Pass score ≥ Czech state-exam
   threshold (60% per section). On pass, set `users.current_level = next_level`
   and append to `unlocked_levels`.

Onboarding starts with a **mandatory placement test** (15–20 min, multi-skill)
that sets the initial `current_level` (default A0 if skipped or insufficient).
Upper-level content stays locked, with **one demo exercise per upper level**
visible to create pull (taste-test, no mastery recorded).

Why this shape:

- Reuses **V8 schema + V19 mastery** instead of inventing new aggregates.
- Reuses **MockTest infrastructure** for promotion exams — no parallel
  scoring path.
- Adding A0 / A1 later is a content question, not a re-architecture.
- The 2-gate ceremony aligns with VN learner expectations of "passing an
  exam to advance" — important UX signal.

## Key Assumptions to Validate

- [ ] **B1 content viability** — do we have (or can we author) at least 30
  exercises across `noi`/`viet`/`nghe`/`doc`/`tu_vung`/`ngu_phap` for B1
  before shipping? *Test:* author B1 module 0 first; if it takes >2 weeks,
  defer B1 launch.
- [ ] **Placement test drop-off** — does a mandatory 15–20 min onboarding
  test kill day-0 retention? *Test:* prototype with 5 learners, measure
  abandon rate; if >40%, switch to "skip but default A0".
- [ ] **Mastery threshold calibration** — is ≥70% mastery × ≥80% coverage
  the right unlock bar for A2 → B1? *Test:* run threshold against existing
  A2 power-users in V19 data; aim for 30–60% of active users qualifying.
- [ ] **Promotion exam authenticity** — does the promotion test feel
  meaningfully different from regular MockTest? *Test:* learner survey post
  first promotion exam; if "felt the same as practice mock" >50%, redesign
  format (shorter, stricter time, no retry within 24h).
- [ ] **A0 / A1 demand** — do learners actually want A0 / A1 content, or do
  they self-select into A2 because that's the exam they need? *Test:*
  placement-test results distribution after first 100 onboardings.

## MVP Scope

**In:**
- Schema: `courses.level enum(a0,a1,a2,b1)`, `users.current_level`,
  `users.unlocked_levels[]`, `mock_tests.is_promotion bool`,
  `mock_tests.target_level enum`.
- Placement test: 1 multi-skill MockTest tagged `is_placement=true` —
  result maps score bands to `current_level`.
- Promotion exam: 1 MockTest per level transition (A2 → B1) with
  `is_promotion=true`, `target_level=b1`.
- Backend gating endpoint: `GET /v1/users/me/level-progress` returns per-skill
  mastery, coverage, unlock status, next promotion test ID.
- Course list filters by `level <= current_level OR demo flag`.
- Flutter UI: locked-course state with "Hoàn thành mastery để mở khoá" copy
  + 1 demo exercise per upper level.
- CMS: `level` field on course form, `is_promotion` / `is_placement` flags
  on MockTest form.

**Out (deferred):**
- A0 and A1 courses (content-bound — ship empty or hide until authored).
- Skill-wise CEFR per learner (Direction B).
- Auto-demotion on long inactivity.
- Promotion exam analytics dashboard.
- Certificate / badge generation.
- Retake cooldown logic beyond a simple "1 attempt / 24h" rule.

## Not Doing (and Why)

- **Skill-wise CEFR (per-skill level per user)** — accurate but UI-heavy
  (24-cell mastery surface), and CMS becomes a matrix editor. Wait until
  we have 1000+ active learners showing real cross-skill divergence.
- **Soft gating / recommendation-only** — directly contradicts the
  requested behaviour ("không thể tham gia A2"). Saved as fallback if
  placement-test drop-off proves fatal.
- **Generic "any-exam-type" abstraction** — AGENTS.md scope discipline says
  no. We model `is_promotion` and `is_placement` as flags, not a plugin
  system.
- **A0 / A1 launch in same slice** — content does not exist; shipping empty
  course shells is worse than not shipping.
- **Auto-promote on streak (V4 idea)** — removes the ceremony users
  expect. Revisit if promotion-exam UX surveys show frustration.
- **Replacing MockTest with a new "PromotionExam" entity** — unnecessary
  divergence. Flags on existing entity are enough.

## Open Questions

- Where does `current_level` live — `users` table or new `user_levels`
  history table? History matters if we ever show a learner timeline.
- Does failing a promotion exam reset mastery threshold, or just gate the
  retake by cooldown? (Lean: cooldown only — don't punish twice.)
- Should the placement test write per-skill `current_level` even in
  Direction A, so we can migrate to Direction B later without re-testing?
- How do we communicate to existing A2-pool users (pre-launch) what their
  starting level is — auto-assign A2, or force placement test?
- Does `pool=exam` exercise list need a `level` filter too, or only
  `course`?

## Surfaced Risks

- **Content authoring is the bottleneck**, not engineering. Slice will
  feel "done" backend-wise but block on B1 content production.
- **Locking content is a retention risk for adult learners** who paid /
  installed expecting to study what they want. Mitigation: demo-per-level
  + clear progress UI showing exact distance to unlock.
- **Promotion exam == MockTest reuse** is convenient but couples two
  features — changes to MockTest scoring will affect promotion behaviour.
  Add a regression suite specifically for `is_promotion` paths.
