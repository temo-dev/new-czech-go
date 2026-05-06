# Skill Mastery & Progress (Babbel-like aggregate)

> Status: idea (refined 2026-05-06). Pair spec at
> `docs/specs/skill-mastery-progress.md` (TBD).
> Pair plan at `docs/plans/skill-mastery-progress-plan.md` (TBD).

## Problem Statement

How might we turn the stream of independent attempt feedback into a
durable picture of learner skill mastery — so an A2 *trvalý pobyt*
candidate always knows which skill is weak, what to practise next,
and when they are ready for a mock exam?

Today: each attempt produces `AttemptFeedback.readiness_level` in
isolation. The learner sees a single label per attempt. Nothing
aggregates across attempts, modules, or skill kinds. Therefore the
app cannot answer:

- Where am I weak?
- Have I actually mastered this exercise / module?
- Should I do a new lesson or review?
- Am I ready for a mock test?

## Recommended Direction

Add one aggregate table — `user_skill_mastery` keyed by
`(user_id, skill_kind, module_id)` — that is updated synchronously
after each `AttemptFeedback` is persisted. Expose it via a single
read endpoint `GET /v1/users/me/progress`.

EMA smoothing: `new = old * 0.7 + attempt_score * 0.3`. Map the
unified readiness band to `attempt_score`. Persist `mastery_score`,
`attempts_count`, `last_attempt_id`, `last_attempt_at`, `updated_at`.

Defer: `confidence_score`, `status`, `next_review_at`, recommendation
engine, spaced repetition, Flutter UI, progress delta in attempt
response, exam-readiness materialised view, A1/B1 levels.

The point of a thin first slice is to validate that aggregated
readiness behaves sensibly across a real learner's history before
building the surface area on top of it.

## Prerequisite (P0 — must land before MVP)

Unify readiness vocabulary. Currently:

- Objective scorer (`objective_scorer.go:107-109`,
  `dictation_processor.go:85`): `weak / ok / strong` from
  `frac >= 0.5 / 0.8`.
- LLM scorer (`llm_prompts.go:52`,
  `llm_feedback.go:193 normalizeReadinessLevel`):
  `not_ready / almost_ready / ready_for_mock / exam_ready`.

Pick one 4-band scale (proposal: `not_ready / needs_work /
almost_ready / ready_for_mock`) and remap both code paths. Aggregate
math is meaningless until this is consistent.

## MVP Scope (V19)

1. Unify readiness vocab — separate commit.
2. Migration: `user_skill_mastery (id, user_id, skill_kind,
   module_id, mastery_score, attempts_count, last_attempt_id,
   last_attempt_at, created_at, updated_at)` with
   `UNIQUE(user_id, skill_kind, module_id)`. Add via
   `addColumnIfMissing` pattern.
3. `MasteryUpdater` invoked synchronously inside the
   `AttemptFeedback` persist path in `processing/processor.go`.
   Idempotent on re-run.
4. `GET /v1/users/me/progress` — returns array of
   `{skill_kind, module_id, mastery_score, attempts_count,
   last_attempt_at}` plus `aggregate_by_skill[]`.
5. Backend tests:
   - readiness vocab unification round-trip
   - mastery EMA monotonicity given a clean sequence
   - mastery decay given mixed sequence
   - endpoint shape + auth gating

No Flutter UI in this slice. Surface via API only; iterate UI in V20
once aggregate values are validated against real attempt data.

## Key Assumptions to Validate

- [ ] Per-attempt readiness label is reliable enough to feed
      aggregate. Gate: 30 attempts manually reviewed by an
      admin/teacher; agreement with `readiness_level` ≥ 70%.
- [ ] `(skill_kind, module_id)` is the right granularity for
      recommendation later. Gate: 5-learner pilot — interview
      whether module-level guidance feels actionable.
- [ ] EMA `0.7 / 0.3` does not produce misleading progress curves.
      Gate: simulate 20 attempt sequences (good / bad / mixed) and
      eyeball the mastery curve.
- [ ] Aggregate is cheap to update synchronously. Gate: p95 of
      attempt persist remains within current SLO after the update
      hook is added.

## Not Doing (and Why)

- A1 / B1 level field — product scope is A2 *trvalý pobyt* only;
  multi-level is out of scope per `AGENTS.md`.
- `confidence_score` — the convergence formula proposed in the
  brief (`+0.1 per attempt`) is not well grounded; defer until we
  see real data.
- `next_review_at` and spaced repetition — needs validated mastery
  signal first; rule-based scheduler can land in V20.
- `ExamReadiness` table — derive from aggregate on read; do not
  materialise until the read shape is stable.
- Recommendation engine — out of slice; needs mastery + review
  scheduling first.
- Flutter UI — backend ships and is validated against real attempt
  data first.
- `progress_delta` inside the attempt response — risky contract
  change; let learners poll `/progress` for now.
- Public pass-likelihood number — too strong a commitment with a
  shallow signal; revisit after pilot.
- Streak / XP / leaderboard — stays Babbel-like, not Duolingo-like.

## Open Questions

- Which modules are "required" for A2? Needed before computing
  per-skill aggregate weights.
- Backfill mastery from existing attempts on rollout? Proposed: no
  — start everyone at zero, update from new attempts only. This
  also avoids contaminating the validation gate above.
- Topic granularity (`topic_id` in the original brief) — current
  schema has `module_id` only; skip topics in V19 and revisit only
  if pilot shows module-level recommendations are too coarse.
- Interview attempts: do they roll into `noi` or stay as their own
  `skill_kind=interview` track? Proposed: keep separate; conflating
  speaking + interview may distort both.
