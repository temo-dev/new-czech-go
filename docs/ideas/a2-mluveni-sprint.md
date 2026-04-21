# A2 Mluveni Sprint

## Problem Statement
How might we help Vietnamese candidates pass the `trvaly pobyt A2` speaking exam by practicing the exact exam format with clear, immediate feedback in short daily sessions?

## Recommended Direction
Build a narrow speaking coach focused on the oral portion of the `trvaly pobyt A2` exam. The product should simulate the real exam structure instead of trying to become a general Czech-learning app.

The core experience is simple: the learner chooses a task, hears or reads the prompt, records an answer, receives a transcript, and gets feedback on task completion, clarity, and basic grammar. The app should also offer a full mock oral exam and a short 14-day practice path.

V1 should follow the four oral task types from the official model test:
- `Uloha 1`: answer questions about a topic
- `Uloha 2`: ask questions in a short dialogue
- `Uloha 3`: narrate a story from four images
- `Uloha 4`: choose an option and explain why

The technical shape for V1 is:
- `Flutter` for the learner app
- `Next.js` for a thin CMS used to upload prompts, images, audio, rubrics, and templates
- `Go` for auth, attempts, scoring orchestration, and result delivery
- `Amazon Transcribe` for Czech speech-to-text
- `Amazon Polly` for prompt and sample-answer audio

`Azure pronunciation assessment` is not part of the V1 critical path. The current product goal is pass-oriented speaking practice, and the available support for Czech pronunciation assessment is too risky to anchor the MVP around.

## Key Assumptions to Validate
- [ ] Vietnamese A2 candidates want a speaking-only prep tool rather than a full language app.
- [ ] Transcript plus rubric-based feedback is enough to improve performance before adding advanced pronunciation scoring.
- [ ] A 10-15 minute daily flow is short enough to keep learners engaged for 14 days.
- [ ] The official oral exam format is a stronger differentiator than generic AI conversation.
- [ ] A lightweight CMS is sufficient for content operations in the first release.

## MVP Scope
In scope:
- iOS learner app for speaking practice
- the four oral task types from the official exam
- guided practice sessions
- full mock oral exam
- recording, upload, transcript, replay
- rubric-based feedback and readiness summary
- 14-day speaking plan
- CMS for prompts, images, audio, rubrics, and feedback templates

Out of scope:
- reading, listening, and writing practice
- free-form AI chat tutor
- teacher marketplace or live tutoring
- advanced gamification
- deep analytics
- production pronunciation scoring for Czech

## Not Doing (and Why)
- Full A2 exam prep app: too broad for a two-week V1 and weakens the pass-rate focus.
- Pronunciation-first positioning: pronunciation carries too little exam weight to be the main value proposition.
- Heavy realtime speech infrastructure: the user benefit is smaller than the complexity cost at this stage.
- Complex admin workflows: a thin content CMS is enough for the first release.

## Open Questions
- Should V1 show a numeric `pass likelihood`, or only rubric-based strengths and weaknesses?
- Should `Uloha 2` ship in the first cut or at the end of week two after the other three tasks are stable?
- Is a learner web app needed early, or should web remain CMS-only until the iOS flow proves useful?
