# Attempt State Machine

## Purpose
This document defines the lifecycle rules for learner attempts and mock oral exam sessions in `A2 Mluveni Sprint` V1.

It exists to answer four practical questions before implementation:
- which states are valid
- what event moves an object from one state to another
- what data must exist before the transition is allowed
- what the learner should see when the object is in that state

This is a product and backend contract, not just a database concern. The `Go` service, `Flutter` learner app, and `Next.js` CMS should all treat these transitions consistently.

## Scope
This spec covers:
- single exercise attempt lifecycle
- attempt failure and retry behavior
- mock oral exam session lifecycle
- learner-facing UI expectations per state

This spec does not yet cover:
- websocket partial transcript events
- background worker internals
- moderation or manual review workflows

## Design Principles
- Keep the number of states small and explicit.
- Use terminal states only when the learner-facing outcome is clear.
- Avoid hidden state transitions that only exist in provider integrations.
- Treat retry as a new attempt, not a mutation of a completed or failed attempt.

## Attempt Lifecycle Summary
```text
created
  -> recording_started
  -> recording_uploaded
  -> transcribing
  -> scoring
  -> completed

created
recording_started
recording_uploaded
transcribing
scoring
  -> failed
```

## Attempt States

### `created`
The backend has created the attempt record, but recording has not been confirmed yet.

Entry conditions:
- `POST /v1/attempts` succeeded
- attempt row exists
- no audio has been uploaded

Expected data:
- `attempt.id`
- `attempt.user_id`
- `attempt.exercise_id`
- `attempt.started_at`
- `attempt.status = created`

Learner UI:
- learner can start recording
- learner can abandon this attempt and start over later

Allowed transitions:
- `recording_started`
- `failed`

### `recording_started`
The learner has begun recording or the client has explicitly notified the backend that recording started.

Entry trigger:
- `POST /v1/attempts/:attempt_id/recording-started`
- or a server-side inference from upload initialization if this endpoint is skipped

Expected data:
- everything from `created`
- `recording_started_at`

Learner UI:
- recording UI active
- timer visible if relevant
- learner can stop recording and upload

Allowed transitions:
- `recording_uploaded`
- `failed`

### `recording_uploaded`
The full audio file has been safely uploaded and registered, but processing has not begun or has not yet been reflected as `transcribing`.

Entry trigger:
- upload completes successfully
- `POST /v1/attempts/:attempt_id/upload-complete` succeeds

Expected data:
- `AttemptAudio` row exists
- storage key is valid
- file metadata is stored

Learner UI:
- upload success confirmation
- learner sees processing spinner

Allowed transitions:
- `transcribing`
- `failed`

### `transcribing`
Speech-to-text is in progress.

Entry trigger:
- backend dispatches transcription job or starts direct transcription processing

Expected data:
- uploaded audio exists
- provider job or provider request context has been created

Learner UI:
- learner sees `processing transcript`
- no final transcript shown yet

Allowed transitions:
- `scoring`
- `failed`

### `scoring`
The transcript exists and the backend is generating learner-facing feedback.

Entry trigger:
- final transcript available
- scoring pipeline started

Expected data:
- `AttemptTranscript.full_text` exists
- transcript locale is known
- scoring template resolved for the exercise

Learner UI:
- learner sees transcript-ready or final-processing state
- app may show the transcript once available, even if feedback is still loading

Allowed transitions:
- `completed`
- `failed`

### `completed`
The attempt is finished and learner-facing feedback is available.

Entry trigger:
- transcript finalized
- feedback finalized
- attempt marked successful

Expected data:
- `AttemptAudio` exists
- `AttemptTranscript` exists
- `AttemptFeedback` exists
- `completed_at` exists

Learner UI:
- transcript shown
- strengths, improvements, and retry advice shown
- sample answer shown if enabled
- learner may create a new attempt

Allowed transitions:
- none

### `failed`
The attempt cannot proceed and did not produce a usable learner-facing result.

Entry triggers:
- upload validation failed
- audio file invalid
- transcription failed
- scoring failed
- processing timeout
- unexpected backend error

Expected data:
- `failed_at` exists
- `failure_code` exists
- transcript or feedback may be partially present, but should not be considered canonical

Learner UI:
- learner sees a friendly error state
- retry option should create a new attempt
- internal details must not leak

Allowed transitions:
- none

## Allowed Attempt Transitions

| From | To | Trigger | Notes |
|------|----|---------|------|
| `created` | `recording_started` | learner starts recording | Explicit or inferred |
| `created` | `failed` | unrecoverable setup error | Rare |
| `recording_started` | `recording_uploaded` | upload complete confirmed | Full audio required |
| `recording_started` | `failed` | upload or client error | Retry creates new attempt |
| `recording_uploaded` | `transcribing` | STT begins | Usually immediate |
| `recording_uploaded` | `failed` | audio invalid or processing dispatch error | Terminal |
| `transcribing` | `scoring` | transcript ready | Final transcript only |
| `transcribing` | `failed` | STT failed or timed out | Terminal |
| `scoring` | `completed` | feedback finalized | Final success state |
| `scoring` | `failed` | scoring failed or timed out | Terminal |

## Invalid Attempt Transitions

These transitions must be rejected by the backend:
- `completed -> any other state`
- `failed -> any other state`
- `created -> transcribing`
- `created -> scoring`
- `recording_started -> scoring`
- `recording_uploaded -> completed`
- `transcribing -> completed` when no feedback exists

## Attempt Transition Guards

### `created -> recording_started`
Required:
- attempt belongs to authenticated learner
- attempt is not terminal

### `recording_started -> recording_uploaded`
Required:
- upload target was issued for the attempt
- uploaded file metadata is within allowed limits
- storage key matches the issued upload target

### `recording_uploaded -> transcribing`
Required:
- audio exists in storage
- MIME type is supported
- duration is within configured bounds

### `transcribing -> scoring`
Required:
- transcript text is non-empty or explicitly accepted as low-confidence
- scoring template exists for the exercise

### `scoring -> completed`
Required:
- learner-facing feedback payload validates against the result schema
- readiness level is set
- strengths and improvements are populated, even if short

### `* -> failed`
Required:
- `failure_code` is set
- error is logged internally
- terminal state is persisted once only

## Failure Codes and Meanings

| Failure Code | Meaning | Retryable | Learner Message Style |
|------|---------|-----------|------|
| `upload_failed` | audio could not be stored | yes | ask learner to retry upload |
| `audio_invalid` | file format or duration invalid | yes | ask learner to record again |
| `transcription_failed` | STT could not return a usable result | yes | ask learner to retry |
| `scoring_failed` | transcript existed but feedback generation failed | yes | ask learner to retry |
| `timeout` | processing exceeded service timeout | yes | ask learner to retry later |
| `internal_error` | unexpected server issue | yes | generic fallback |

## Retry Rules
- A retry always creates a new attempt.
- A failed attempt remains stored for debugging and analytics.
- A learner must not resume a failed attempt in V1.
- A learner must not have more than one active attempt for the same exercise at the same time.

## Abandonment Rules
V1 should handle silent abandonment without requiring a dedicated `abandoned` state.

Rules:
- attempts stuck in `created` or `recording_started` beyond the configured TTL may be treated as stale
- stale attempts remain in storage for audit, but do not block a new attempt forever
- the backend may allow a new attempt if the old one is stale and non-terminal

Suggested TTLs:
- `created`: 30 minutes
- `recording_started`: 60 minutes

## Learner-Facing Status Mapping

| Backend State | Learner Copy Intent |
|------|------|
| `created` | ready to record |
| `recording_started` | recording in progress |
| `recording_uploaded` | upload complete, preparing analysis |
| `transcribing` | creating transcript |
| `scoring` | preparing feedback |
| `completed` | result ready |
| `failed` | something went wrong, please retry |

## Mock Exam Session Lifecycle
Mock exam sessions group multiple exercise attempts into one exam-like flow.

### Mock Exam States
- `created`
- `in_progress`
- `completed`
- `failed`

### State Meanings

#### `created`
Session exists but no section attempt has started yet.

#### `in_progress`
At least one section has started, and the session is not terminal.

#### `completed`
All required section attempts for the session have completed successfully, and the aggregated summary exists.

#### `failed`
The session cannot continue as a coherent mock exam. V1 should use this sparingly.

## Allowed Mock Exam Transitions

| From | To | Trigger | Notes |
|------|----|---------|------|
| `created` | `in_progress` | first section attempt created | happy path |
| `in_progress` | `completed` | all required sections completed and aggregate summary generated | happy path |
| `created` | `failed` | unrecoverable setup issue | rare |
| `in_progress` | `failed` | session-level integrity failure | rare in V1 |

## Mock Exam Session Item Rules
- each session item points to one exercise
- each session item may link to one attempt in V1
- once an item has a completed attempt, it should not be replaced inside the same session
- if a learner retries a section, V1 should create a new mock exam session instead of mutating the old one

## Aggregation Rules for Mock Exam Completion
Before `in_progress -> completed`:
- all required section items must have linked attempts
- all linked attempts must be `completed`
- an overall readiness label must be generated
- an overall summary must be generated

## Observability Requirements
Each attempt transition should log:
- `attempt_id`
- previous state
- next state
- trigger source
- timestamp
- failure code if relevant

Each mock exam transition should log:
- `session_id`
- previous state
- next state
- timestamp

## Open Questions
- Should we expose stale-attempt cleanup behavior in the API, or keep it server-side only?
- Do we want a future `completed_with_warnings` state if transcript confidence is low but usable?
- Should mock exam failure remain a backend-only state in V1, with the learner app simply offering a restart?
