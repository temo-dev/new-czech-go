# V19 Phase 2 Gate — Teacher Readiness Review (30 attempts)

Spec: `docs/specs/skill-mastery-progress.md` § "Validation Gates".

Goal: confirm `AttemptFeedback.readiness_level` produced by V19 LLM +
objective scorers agrees with a Czech A2 teacher's manual rating ≥ 70 %
of the time before V21 spaced repetition consumes the signal.

## Procedure

1. Deploy V19 to staging.
2. Pick **30 real attempts** spanning all 4 readiness bands. Mix of:
   - 8 speaking (`noi`) — 2 per úloha (1–4)
   - 6 writing (`viet`) — 2 each formulář / e-mail / dictation
   - 6 listening (`nghe`) — across `poslech_1..6`
   - 6 reading (`doc`) — across `cteni_1..6`
   - 4 interview
3. For each attempt, the teacher rates the same readiness band on a
   blind copy of the transcript + exercise prompt (NO peek at LLM
   output). Record below.
4. Compare bands; compute exact agreement and "off by 1 band"
   tolerance.

## Sheet

| # | Attempt ID | Skill | Exercise type | Backend `readiness_level` | Teacher rating | Agree (exact) | Off-by-1 OK |
|---|------------|-------|---------------|---------------------------|----------------|---------------|-------------|
| 1 |            |       |               |                           |                |               |             |
| 2 |            |       |               |                           |                |               |             |
| 3 |            |       |               |                           |                |               |             |
| 4 |            |       |               |                           |                |               |             |
| 5 |            |       |               |                           |                |               |             |
| 6 |            |       |               |                           |                |               |             |
| 7 |            |       |               |                           |                |               |             |
| 8 |            |       |               |                           |                |               |             |
| 9 |            |       |               |                           |                |               |             |
| 10 |           |       |               |                           |                |               |             |
| 11 |           |       |               |                           |                |               |             |
| 12 |           |       |               |                           |                |               |             |
| 13 |           |       |               |                           |                |               |             |
| 14 |           |       |               |                           |                |               |             |
| 15 |           |       |               |                           |                |               |             |
| 16 |           |       |               |                           |                |               |             |
| 17 |           |       |               |                           |                |               |             |
| 18 |           |       |               |                           |                |               |             |
| 19 |           |       |               |                           |                |               |             |
| 20 |           |       |               |                           |                |               |             |
| 21 |           |       |               |                           |                |               |             |
| 22 |           |       |               |                           |                |               |             |
| 23 |           |       |               |                           |                |               |             |
| 24 |           |       |               |                           |                |               |             |
| 25 |           |       |               |                           |                |               |             |
| 26 |           |       |               |                           |                |               |             |
| 27 |           |       |               |                           |                |               |             |
| 28 |           |       |               |                           |                |               |             |
| 29 |           |       |               |                           |                |               |             |
| 30 |           |       |               |                           |                |               |             |

Bands: `not_ready` / `needs_work` / `almost_ready` / `ready_for_mock`.

## Outcome

- Exact agreement: __ / 30 = __ % (threshold ≥ 70 %)
- Off-by-1 tolerance: __ / 30 = __ % (sanity threshold ≥ 90 %)
- Direction bias: backend rates HIGHER than teacher in __ cases, LOWER
  in __ cases. (Symmetric is good; one-sided ≥ 5 indicates calibration
  drift — file a tuning ticket.)

## Decision

- [ ] PASS — proceed to V21 spaced repetition design
- [ ] FAIL — record lowest-agreement skill kind + specific examples in
      `tasks/skill-mastery-progress-todo.md § Phase 4`; tune prompts /
      thresholds before retrying.

Reviewer: ____________________
Date: ____________________
Backend commit: ____________________
