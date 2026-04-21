# Implementation Plan: A2 Mluveni Sprint V1

## Overview
This plan covers the first shippable version of a speaking-only prep app for Vietnamese learners taking the Czech `trvaly pobyt A2` exam. The goal is to deliver a working learner flow on iOS, a thin web CMS for content entry, and a backend pipeline that stores attempts, transcribes Czech audio, and returns exam-oriented feedback.

## Architecture Decisions
- Keep V1 narrow: only the oral exam flow is in scope.
- Prefer a hybrid or upload-first attempt flow over fully realtime streaming to reduce complexity.
- Use one `Go` backend service for auth, attempts, content delivery, and scoring orchestration.
- Use `Amazon Transcribe` for Czech STT and `Amazon Polly` for prompt/sample audio.
- Do not depend on `Azure pronunciation assessment` in V1.
- Keep the CMS thin: content CRUD only, not a full teacher product.

## Dependency Graph
```text
Content model + attempt model
    |
    +-- Backend APIs
    |      |
    |      +-- Learner app flows
    |      |
    |      +-- CMS content management
    |
    +-- Scoring pipeline
           |
           +-- Attempt results UI
```

## Task List

### Phase 1: Foundation

## Task 1: Define core data contracts

**Description:** Define the minimal shared model for content, oral tasks, attempts, transcripts, and feedback so backend, Flutter, and CMS can all build against the same shape.

**Acceptance criteria:**
- [ ] The plan documents the core entities and required fields for `Task`, `Prompt`, `Attempt`, `Transcript`, and `Feedback`.
- [ ] Each of the four oral task types has a clear content schema.
- [ ] The result payload shape is stable enough for both learner UI and CMS review.

**Verification:**
- [ ] Manual check: the entity list covers learner flow, content ops, and scoring output without undefined gaps.
- [ ] Manual check: each task type can be represented without custom one-off fields.

**Dependencies:** None

**Files likely touched:**
- `docs/plans/v1-implementation-plan.md`
- `docs/specs/content-and-attempt-model.md`

**Estimated scope:** Small: 1-2 files

## Task 2: Choose V1 infrastructure baseline

**Description:** Lock the simplest deployable baseline for storage, backend runtime, audio handling, and environment configuration so implementation does not drift into over-engineered infra.

**Acceptance criteria:**
- [ ] Backend hosting choice is explicit.
- [ ] Storage choices for audio and relational data are explicit.
- [ ] Attempt processing mode is explicit: upload-first or hybrid.

**Verification:**
- [ ] Manual check: every core component has one chosen home and one backup option.
- [ ] Manual check: the baseline fits the two-week timeline and sub-50-dollar prototype budget.

**Dependencies:** Task 1

**Files likely touched:**
- `docs/plans/v1-implementation-plan.md`
- `docs/specs/infrastructure-baseline.md`

**Estimated scope:** Small: 1-2 files

## Task 3: Define API and session flow

**Description:** Specify the request and response contracts for auth, content fetch, attempt creation, audio upload, scoring start, and result fetch.

**Acceptance criteria:**
- [ ] The learner attempt lifecycle is documented from `attempt_created` to `attempt_completed`.
- [ ] CMS endpoints for content CRUD are listed.
- [ ] Error states are named for failed upload, failed transcript, and failed scoring.

**Verification:**
- [ ] Manual check: a learner can complete one attempt end-to-end on paper using only the documented APIs.
- [ ] Manual check: API sequence does not require hidden service behavior.

**Dependencies:** Tasks 1-2

**Files likely touched:**
- `docs/specs/api-contracts.md`
- `docs/specs/attempt-state-machine.md`

**Estimated scope:** Medium: 3-5 files

### Checkpoint: Foundation
- [ ] Core entities, infra baseline, and API contracts are documented.
- [ ] The attempt lifecycle is unambiguous.
- [ ] The chosen baseline still fits the two-week delivery window.

### Phase 2: Core Product Slices

## Task 4: Ship one vertical slice for `Uloha 1`

**Description:** Implement the smallest full path for topic-question speaking practice, including content entry, prompt display, recording, transcript, and feedback.

**Acceptance criteria:**
- [ ] A CMS admin can create a `Uloha 1` item with prompt text, topic metadata, and feedback template.
- [ ] A learner can open the item, record an answer, and receive a transcript and feedback.
- [ ] The result screen shows task-specific guidance rather than generic text.

**Verification:**
- [ ] Manual check: create one `Uloha 1` exercise in CMS and complete it from the learner app.
- [ ] Manual check: stored attempt includes audio location, transcript, and feedback payload.

**Dependencies:** Tasks 1-3

**Files likely touched:**
- `backend/...`
- `flutter_app/...`
- `cms/...`
- `tests/...`

**Estimated scope:** Medium: 3-5 files per app surface

## Task 5: Add `Uloha 3` story narration

**Description:** Extend the first slice to support the four-image storytelling task, including image-driven content, longer recordings, and past-tense oriented feedback.

**Acceptance criteria:**
- [ ] CMS supports four images plus prompt metadata for `Uloha 3`.
- [ ] Learner app renders the image set and records one narration attempt.
- [ ] Feedback includes coverage of all images and narrative coherence checks.

**Verification:**
- [ ] Manual check: a user can complete a full story narration exercise from the learner app.
- [ ] Manual check: feedback flags missing image coverage when the answer skips part of the story.

**Dependencies:** Task 4

**Files likely touched:**
- `backend/...`
- `flutter_app/...`
- `cms/...`
- `tests/...`

**Estimated scope:** Medium: 3-5 files per app surface

## Task 6: Add `Uloha 4` choose-and-explain task

**Description:** Implement the decision task where the learner must choose from visible options and justify the choice.

**Acceptance criteria:**
- [ ] CMS supports three options plus prompt framing for `Uloha 4`.
- [ ] Learner app renders the choices clearly and records one response.
- [ ] Feedback checks whether the learner made a choice and supported it with a reason.

**Verification:**
- [ ] Manual check: a learner can complete the exercise and receive a choice-plus-reason assessment.
- [ ] Manual check: the result distinguishes between missing choice and weak justification.

**Dependencies:** Task 4

**Files likely touched:**
- `backend/...`
- `flutter_app/...`
- `cms/...`
- `tests/...`

**Estimated scope:** Medium: 3-5 files per app surface

### Checkpoint: Core Slices
- [ ] Three exam task types work end-to-end.
- [ ] CMS can create content for all shipped task types.
- [ ] Attempt data and feedback are visible and reviewable.
- [ ] The product already delivers a meaningful speaking workflow even before mock exam mode.

### Phase 3: Exam Flow and Content Ops

## Task 7: Add full mock oral exam mode

**Description:** Combine shipped task types into one timed oral exam flow that feels like a realistic practice session rather than isolated drills.

**Acceptance criteria:**
- [ ] A learner can start a guided mock oral exam with multiple sections.
- [ ] The app preserves section order and timing rules defined for V1.
- [ ] Final results show per-section feedback and an overall readiness summary.

**Verification:**
- [ ] Manual check: complete one mock oral exam from start to finish.
- [ ] Manual check: the final result page includes both section-level and overall feedback.

**Dependencies:** Tasks 4-6

**Files likely touched:**
- `backend/...`
- `flutter_app/...`
- `tests/...`

**Estimated scope:** Medium: 3-5 files per app surface

## Task 8: Add 14-day plan and attempt history

**Description:** Introduce the simple habit loop that helps users train daily and see progress over time.

**Acceptance criteria:**
- [ ] Learner app shows a day-by-day practice path.
- [ ] Completed attempts appear in history with task type, date, and result summary.
- [ ] The current day is clear without requiring a complex recommendation engine.

**Verification:**
- [ ] Manual check: a learner can navigate from the plan into an exercise and back into history.
- [ ] Manual check: history reflects the latest attempt data accurately.

**Dependencies:** Tasks 4-7

**Files likely touched:**
- `backend/...`
- `flutter_app/...`
- `tests/...`

**Estimated scope:** Medium: 3-5 files per app surface

## Task 9: Add `Uloha 2` dialogue question task

**Description:** Implement the dialogue task last because it requires the most interaction design and can ship after the other three task types are stable.

**Acceptance criteria:**
- [ ] CMS supports the dialogue setup, expected question slots, and scoring template.
- [ ] Learner app can present the scenario and collect the learner's spoken questions.
- [ ] Feedback distinguishes between missing information requests and acceptable custom questions.

**Verification:**
- [ ] Manual check: a dialogue exercise can be completed end-to-end.
- [ ] Manual check: the result correctly captures whether required information was requested.

**Dependencies:** Tasks 4-8

**Files likely touched:**
- `backend/...`
- `flutter_app/...`
- `cms/...`
- `tests/...`

**Estimated scope:** Medium: 3-5 files per app surface

### Checkpoint: Feature Complete
- [ ] All four oral task types are available.
- [ ] Mock oral exam works end-to-end.
- [ ] 14-day plan and history are visible.
- [ ] CMS can support all shipped learner content.

### Phase 4: Hardening and Release Prep

## Task 10: Add operational guardrails

**Description:** Add the minimal hardening needed for a small real-user release: authentication rules, upload validation, retry handling, and audit-friendly logging.

**Acceptance criteria:**
- [ ] Invalid audio uploads are rejected safely.
- [ ] Failed transcript or scoring jobs surface a user-safe retry state.
- [ ] Basic logs exist for attempt lifecycle debugging.

**Verification:**
- [ ] Manual check: simulated upload and transcript failures result in recoverable UI states.
- [ ] Manual check: logs are sufficient to trace one attempt through the system.

**Dependencies:** Tasks 4-9

**Files likely touched:**
- `backend/...`
- `flutter_app/...`
- `tests/...`

**Estimated scope:** Small: 1-2 files per app surface

## Task 11: Prepare initial seed content and launch checklist

**Description:** Create the minimum content pack and release checklist needed to test the product with real learners.

**Acceptance criteria:**
- [ ] At least one complete content set exists for each shipped task type.
- [ ] The release checklist covers environments, secrets, seed content, smoke tests, and rollback basics.
- [ ] The team can onboard one new learner without ad hoc setup work.

**Verification:**
- [ ] Manual check: a fresh environment can be seeded and used for one learner smoke test.
- [ ] Manual check: launch checklist can be followed step by step without missing prerequisites.

**Dependencies:** Tasks 7-10

**Files likely touched:**
- `docs/content/seed-plan.md`
- `docs/release/v1-launch-checklist.md`
- `cms/...`

**Estimated scope:** Small: 1-2 files plus content entries

### Checkpoint: Ready for Build Execution
- [ ] Every task has acceptance criteria and a verification path.
- [ ] The riskiest areas are front-loaded.
- [ ] The product can be built as a sequence of working slices rather than one large merge.
- [ ] Scope still matches a first release rather than a platform rewrite.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Czech speech-to-text quality is weaker than expected for some accents | High | Validate with real sample audio in week one and adjust feedback logic to be tolerant of transcript noise |
| The scoring prompt becomes too generic to feel useful | High | Start with task-specific feedback templates and only add more model flexibility after real samples |
| CMS grows into a second product | Medium | Freeze the CMS scope at content CRUD plus preview |
| Audio upload or playback issues slow learner trust | High | Ship one end-to-end slice early and test on target devices immediately |
| Mock exam timing adds complexity too early | Medium | Build on top of already working single-task attempts instead of inventing a separate flow |

## Open Questions
- Is V1 strictly `iOS + CMS web`, or should the Flutter codebase also target web for internal QA?
- Should readiness be shown as a score, a label, or a checklist?
- Do you want account creation in V1, or is invite-only access acceptable for the first pilot?
