# Plan: Attempt Repair And Shadowing

> **Status (2026-04-25):** Phase 1–5 shipped. Backend emits review artifacts with corrected transcript + model answer + Polly TTS, Flutter renders review card with shadow playback. Task 9 shipped: Uloha 3 evaluator uses `NarrativeCheckpoints` coverage + ordering + past-tense detection; Uloha 4 evaluator resolves option via label/key + checks reasoning axes + choice-reason co-occurrence. LLM prompt carries per-task rubric blocks for Uloha 3 and 4.

## Overview
This plan covers the first build-ready sequence for a new post-attempt coaching layer:
- corrected Czech text
- task-aware model answer
- learner-vs-corrected diff
- short speaking focus items
- TTS audio for shadowing

The plan is intentionally incremental. Each slice should leave the repo in a working state and preserve the current attempt result flow.

## Delivery Principles
- Do not break the current `completed attempt` experience while adding the new artifact.
- Keep `Uloha 1` and `Uloha 2` as the first delivery target.
- Separate `learner transcript`, `corrected transcript`, and `model answer` in both API and UI.
- Do not promise phoneme-level pronunciation scoring in the first build.

## Dependency Graph
```text
real transcript path
    |
    +-- review artifact model
           |
           +-- repair generation
           |      |
           |      +-- diff generation
           |      +-- speaking focus extraction
           |
           +-- model answer generation
                  |
                  +-- TTS audio generation
                         |
                         +-- Flutter review UI
                                |
                                +-- retry-from-model loop
```

## Phase 1: Contracts And Persistence

## Task 1: Define review artifact contracts

**Description:** Add the build-ready contract for the post-attempt review artifact without breaking existing attempt contracts.

**Acceptance criteria:**
- [ ] A new review artifact shape is documented with `status`, corrected text, model answer, speaking focus items, diff chunks, and TTS audio metadata.
- [ ] The current `AttemptStatus` remains unchanged.
- [ ] The main attempt payload can surface lightweight review status without returning the full artifact every time.

**Verification:**
- [ ] Manual check: docs clearly separate learner transcript, corrected transcript, and model answer.
- [ ] Manual check: docs show how the current result flow stays backward-compatible.

**Dependencies:** real transcript path is already available for cloud mode

**Files likely touched:**
- `docs/specs/attempt-repair-and-shadowing.md`
- `docs/specs/api-contracts.md`
- `docs/specs/content-and-attempt-model.md`

## Task 2: Add backend persistence for review artifacts

**Description:** Persist the new review artifact separately from the main transcript and feedback payload.

**Acceptance criteria:**
- [ ] Memory and `Postgres` stores can save and fetch one review artifact per attempt.
- [ ] Failed review generation does not corrupt the main attempt result.
- [ ] Review artifact persistence supports `pending`, `ready`, and `failed`.

**Verification:**
- [ ] Backend tests cover create, update, and read of the review artifact.
- [ ] `GET /v1/attempts/:attempt_id` still works unchanged for old clients.

**Dependencies:** Task 1

**Files likely touched:**
- `backend/internal/contracts/types.go`
- `backend/internal/store/...`
- `backend/internal/httpapi/server.go`

## Phase 2: Text Repair Core

## Task 3: Build text-only repair generation for `Uloha 1`

**Description:** Generate corrected transcript and model answer for `Uloha 1` only, without TTS yet.

**Acceptance criteria:**
- [ ] Backend can create a `ready` review artifact after a completed `Uloha 1` attempt.
- [ ] Corrected transcript stays close to learner intent.
- [ ] Model answer is slightly stronger but still task-bound.
- [ ] If generation fails, the attempt still stays `completed`.

**Verification:**
- [ ] Golden-style tests cover at least one strong and one weak `Uloha 1` transcript.
- [ ] Manual check: corrected transcript is not a completely different answer.

**Dependencies:** Tasks 1-2

**Files likely touched:**
- `backend/internal/processing/...`
- `backend/internal/httpapi/server.go`
- `tests/...`

## Task 4: Add diff generation and speaking focus extraction for `Uloha 1`

**Description:** Turn the repair output into something the learner can act on immediately.

**Acceptance criteria:**
- [ ] Backend returns readable diff chunks between learner transcript and corrected transcript.
- [ ] Backend returns 1-3 speaking focus items.
- [ ] Focus items never claim deep pronunciation certainty.

**Verification:**
- [ ] Tests cover replacement, insertion, and no-change scenarios.
- [ ] Manual check: focus items are practical and short.

**Dependencies:** Task 3

**Files likely touched:**
- `backend/internal/processing/...`
- `backend/internal/contracts/types.go`
- `tests/...`

## Phase 3: TTS And API

## Task 5: Add TTS generation for the model answer

**Description:** Generate one audio file from the model answer so the learner can shadow it.

**Acceptance criteria:**
- [ ] Backend can generate and store one TTS file per ready review artifact.
- [ ] TTS failure does not erase the text artifact.

**Verification:**
- [ ] Backend tests cover TTS metadata persistence.
- [ ] Manual check: generated review artifact carries `tts_audio` metadata when TTS succeeds.

**Dependencies:** Tasks 3-4

**Files likely touched:**
- `backend/internal/processing/...`
- `backend/cmd/api/main.go`
- `docs/specs/attempt-repair-and-shadowing.md`

## Task 6: Add review artifact API

**Description:** Expose the artifact to Flutter through stable learner endpoints.

**Acceptance criteria:**
- [ ] `GET /v1/attempts/:attempt_id/review` returns `pending`, `ready`, or `failed`
- [ ] `GET /v1/attempts/:attempt_id/review/audio/file` returns the model audio when ready
- [ ] `GET /v1/attempts/:attempt_id` includes lightweight review status

**Verification:**
- [ ] Backend tests cover auth, not-found, and ready states.
- [ ] Manual check: old attempt polling flow still works without the new endpoint.

**Dependencies:** Tasks 1-5

**Files likely touched:**
- `backend/internal/httpapi/server.go`
- `backend/internal/httpapi/server_test.go`
- `docs/specs/api-contracts.md`
- `flutter_app/lib/api_client.dart`

**Status note:**
- backend route + tests are now landed
- Flutter client wiring remains for Task 7

## Phase 4: Flutter Result Experience

## Task 7: Render the repair-and-shadowing block in Flutter

**Description:** Extend the result card to show the new artifact after a completed attempt.

**Acceptance criteria:**
- [ ] Flutter shows pending state while the review artifact is still generating.
- [ ] Flutter renders corrected transcript, model answer, diff, and speaking focus items.
- [ ] Flutter can play the model-answer audio.

**Verification:**
- [ ] Flutter model parsing tests cover the new artifact shape.
- [ ] Manual check: learners can clearly distinguish transcript, corrected text, and model answer.

**Dependencies:** Task 6

**Files likely touched:**
- `flutter_app/lib/models.dart`
- `flutter_app/lib/api_client.dart`
- `flutter_app/lib/main.dart`
- `flutter_app/test/...`

## Task 8: Add `Retry with this model`

**Description:** Let the learner immediately retry the same exercise after hearing the model answer.

**Acceptance criteria:**
- [ ] Result screen has a clear retry CTA after the artifact is ready.
- [ ] Retry starts a new normal attempt; it does not mutate the old attempt.
- [ ] The new attempt can be compared against the previous review artifact in history later.

**Verification:**
- [ ] Manual check: tapping retry returns the learner to a ready recording state for the same exercise.
- [ ] Backend attempt history still shows separate attempts.

**Dependencies:** Task 7

**Files likely touched:**
- `flutter_app/lib/main.dart`
- `backend/internal/httpapi/server.go` if any helper route is needed

## Phase 5: Expand To `Uloha 2`

## Task 9: Make repair prompts task-aware for `Uloha 2`

**Description:** Extend the repair/model generation to dialogue-question tasks.

**Acceptance criteria:**
- [ ] Corrected transcript respects question form
- [ ] Model answer includes required info-slot coverage
- [ ] Speaking focus can mention missing question form or missing info slots

**Verification:**
- [ ] Tests cover at least one partial and one strong `Uloha 2` transcript.
- [ ] Manual check: model answer still sounds like a question sequence, not a statement paragraph.

**Dependencies:** Tasks 3-8

**Files likely touched:**
- `backend/internal/processing/...`
- `tests/...`

## Later, Not In First Build
- expand to `Uloha 3`
- expand to `Uloha 4`
- provider-aware replay for all cloud-only audio assets
- richer comparison view in attempt history
- deeper pronunciation scoring beyond transcript repair and confidence hints

## Recommended Build Order
1. Tasks 1-2
2. Tasks 3-4
3. Tasks 5-6
4. Tasks 7-8
5. Task 9

## Definition Of Ready
Before implementation starts:
- [ ] The team accepts the distinction between corrected transcript and model answer.
- [ ] The first build is intentionally limited to `Uloha 1` and `Uloha 2`.
- [ ] TTS provider choice is accepted for MVP.
- [ ] Local and production real-transcript paths are available for testing.
