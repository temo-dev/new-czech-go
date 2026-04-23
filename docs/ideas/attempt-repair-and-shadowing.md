# Attempt Repair And Shadowing

## Problem Statement
How might we turn every completed speaking attempt into an immediate repair-and-shadowing loop where the learner sees what they said, sees a better Czech version, and hears a clean model answer they can repeat right away?

## Recommended Direction
Build a `dual output` post-attempt experience on top of the existing attempt pipeline.

After each `completed` attempt, the learner should receive:
- `Transcript cua ban`: the transcript we recognized from the submitted audio
- `Ban nen noi`: a corrected and exam-ready Czech version that stays close to the learner intent
- diff-style highlighting between the learner transcript and the corrected version
- `audio mau TTS` generated from the corrected version so the learner can shadow it immediately

This feature should be `task-aware` instead of generic:
- `Uloha 1`: prioritize direct answer + one supporting reason
- `Uloha 2`: prioritize full question form + required info slots + one natural extra question
- `Uloha 3`: prioritize sequence and event coverage
- `Uloha 4`: prioritize explicit choice + reason

The first build should start with `Uloha 1` and `Uloha 2`, because they are simpler to validate and easier to compare against the existing feedback pipeline.

## Key Assumptions To Validate
- [ ] Learners will find a corrected Czech version more useful than only a readiness summary.
- [ ] A repaired transcript can stay close enough to learner intent without turning into a completely new answer.
- [ ] `TTS` audio from the corrected version is good enough for shadowing in V1.
- [ ] Highlighting 3-8 key differences is more helpful than showing a fully rewritten paragraph with no explanation.
- [ ] We can infer useful `pronunciation/speaking focus` from transcript diffs and STT confidence signals without needing phoneme-level pronunciation scoring in V1.
- [ ] Learners will actually retry immediately if the model answer is shown right after the attempt result.

## MVP Scope
In scope:
- run after each `completed` attempt
- generate a corrected Czech text that stays close to learner meaning
- generate a more exam-ready `model answer` for shadowing when needed
- highlight major learner-vs-corrected differences
- generate one TTS audio file for the model answer
- show the corrected result inside the learner result screen
- support `Uloha 1` and `Uloha 2` first

Out of scope for the first cut:
- phoneme-level pronunciation scoring
- real-time correction while the learner is still recording
- teacher review workflow
- all four oral tasks at once
- multiple TTS voice choices
- sentence-by-sentence tutoring chat

## Not Doing (And Why)
- Full pronunciation engine: too heavy, too risky, and not necessary to prove value in the first iteration.
- “Rewrite everything” AI behavior: this would blur the difference between what the learner said and what the app invented.
- Task-agnostic generic repair: it would be faster to ship, but weaker for exam preparation.
- Immediate rollout to all four tasks: better to prove the loop on `Uloha 1` and `Uloha 2` first.
- Replacing the existing readiness feedback: the repair-and-shadowing layer should extend the result, not remove the current exam-oriented guidance.

## Open Questions
- Should we show both `Corrected transcript` and `Model answer`, or collapse them into one surface when they are almost identical?
- Should the corrected/model audio come from `Amazon Polly`, or should TTS remain provider-abstract until implementation starts?
- Should the learner retry button reopen the same exercise with a “practice the corrected answer” mode, or simply start a new normal attempt?
