# Feature: Attempt Lifecycle And Feedback

## Purpose
This feature coordinates the backend attempt lifecycle from creation through learner-facing result delivery.

## User Flow
1. Learner creates an attempt.
2. Backend stores the attempt in `created`.
3. Learner starts recording.
4. Backend moves the attempt to `recording_started`.
5. Learner completes upload.
6. Backend moves the attempt to `recording_uploaded`, then asynchronously through `transcribing` and `scoring`.
7. Backend stores transcript and feedback.
8. Learner polls until the result is `completed`.

## Surfaces
- `Go backend`
- `Flutter`

## Main Files
- [backend/internal/httpapi/server.go](/Users/daniel.dev/Desktop/czech-go-system/backend/internal/httpapi/server.go)
- [backend/internal/store/memory.go](/Users/daniel.dev/Desktop/czech-go-system/backend/internal/store/memory.go)
- [backend/internal/contracts/types.go](/Users/daniel.dev/Desktop/czech-go-system/backend/internal/contracts/types.go)
- [flutter_app/lib/api_client.dart](/Users/daniel.dev/Desktop/czech-go-system/flutter_app/lib/api_client.dart)
- [docs/specs/attempt-state-machine.md](/Users/daniel.dev/Desktop/czech-go-system/docs/specs/attempt-state-machine.md)
- [docs/specs/scoring-pipeline.md](/Users/daniel.dev/Desktop/czech-go-system/docs/specs/scoring-pipeline.md)

## Graph Notes
Graph inspection shows this feature is structurally backend-heavy today:
- `backend/internal/httpapi/server.go` contains the full HTTP orchestration path for attempts, admin flows, auth helpers, and mock scoring
- `backend/internal/store/memory.go` contains the attempt state mutation methods such as `CreateAttempt`, `UpdateAttemptRecordingStarted`, `MarkUploadComplete`, `SetAttemptStatus`, and `CompleteAttempt`

This confirms that the lifecycle logic is currently split across two files:
- transport and async coordination in `server.go`
- state mutation and seed data in `memory.go`

That split is workable for V1, but future persistence and real scoring integration should keep the external contracts stable while reducing how much logic lives in the HTTP layer.

## Current Status
Implemented today:
- state transitions in-memory
- async mock progression
- transcript payload
- feedback payload matching the agreed contract
- Flutter now sends real local recording metadata through the upload lifecycle
- backend now accepts a real binary upload on the dev upload target before `upload-complete`
- completed attempts now retain audio metadata on the attempt record

Not implemented yet:
- transcript validation against real provider data
- scoring based on actual learner transcript
- failure branches beyond basic placeholders
- persistence and retry history

## API Endpoints
- `POST /v1/attempts`
- `POST /v1/attempts/:attempt_id/recording-started`
- `POST /v1/attempts/:attempt_id/upload-url`
- `POST /v1/attempts/:attempt_id/upload-complete`
- `GET /v1/attempts/:attempt_id`
- `GET /v1/attempts`

## Out Of Scope
- pronunciation scoring
- real-time partial transcript events
- worker queue orchestration

## Risks
- the current backend progression is optimistic and always succeeds
- polling UX has not yet been tested against real cloud latency

## Next Step
Swap the simulated scoring path for the real transcript and scoring pipeline while preserving the same external result shape.
