# Feature: Uloha 1 Practice

## Purpose
This feature lets a learner open a topic-based speaking exercise, record a real local speaking attempt, wait for transcript and feedback processing, and review a result aligned to the `Uloha 1` oral exam format.

## User Flow
1. Learner opens the Flutter app.
2. Learner sees available modules and exercises.
3. Learner opens a `Uloha 1` exercise.
4. Learner starts practice.
5. App creates an attempt, requests microphone access, and starts a real local recording.
6. Learner stops practice.
7. App requests an upload target, uploads the recorded audio binary to either the backend local target or an `S3` presigned target, then completes the upload contract and polls the backend.
8. Backend progresses the attempt through `transcribing -> scoring -> completed`.
9. Learner sees transcript, readiness level, strengths, improvements, retry advice, and a sample answer.

## Surfaces
- `Flutter`
- `Go backend`

## Main Files
- [flutter_app/lib/main.dart](/Users/daniel.dev/Desktop/czech-go-system/flutter_app/lib/main.dart)
- [flutter_app/lib/api_client.dart](/Users/daniel.dev/Desktop/czech-go-system/flutter_app/lib/api_client.dart)
- [flutter_app/lib/models.dart](/Users/daniel.dev/Desktop/czech-go-system/flutter_app/lib/models.dart)
- [backend/internal/httpapi/server.go](/Users/daniel.dev/Desktop/czech-go-system/backend/internal/httpapi/server.go)
- [backend/internal/store/exercise_store.go](/Users/daniel.dev/Desktop/czech-go-system/backend/internal/store/exercise_store.go)
- [backend/internal/store/attempt_store.go](/Users/daniel.dev/Desktop/czech-go-system/backend/internal/store/attempt_store.go)

## Graph Notes
`code-review-graph` confirms this feature is currently concentrated in a few key files:
- `flutter_app/lib/main.dart` contains `21` graph nodes, including `LearnerShell`, `ExerciseScreen`, `_startRecording`, `_stopRecording`, and `_ResultCard`
- `flutter_app/lib/api_client.dart` contains `12` graph nodes centered around `ApiClient` and the learner attempt/content methods
- `backend/internal/httpapi/server.go` contains `31` graph nodes and currently acts as the central HTTP coordination file
- backend persistence is now split between a thin in-memory fallback and opt-in `Postgres` stores for attempts and exercises

This is a good early slice shape, but it also means the feature is not yet decomposed into smaller backend or Flutter modules.

## APIs Involved
- `POST /v1/auth/login`
- `GET /v1/modules`
- `GET /v1/modules/:module_id/exercises`
- `GET /v1/exercises/:exercise_id`
- `POST /v1/attempts`
- `POST /v1/attempts/:attempt_id/recording-started`
- `POST /v1/attempts/:attempt_id/upload-url`
- `POST /v1/attempts/:attempt_id/upload-complete`
- `GET /v1/attempts/:attempt_id`

## Current Status
Implemented today:
- exercise list
- exercise detail fetch
- attempt creation
- real local microphone recording
- local recording file path handling
- binary audio upload through a stable upload-target contract
- audio metadata returned on the attempt result
- staged backend processing through a dedicated dev processor
- pluggable transcription layer with a default dev transcriber
- opt-in `Amazon Transcribe` backend path prepared behind environment flags
- local upload target remains the default, and opt-in `S3` presigned upload targets are now available behind environment flags
- backend validates that `upload-complete` matches the most recently issued attempt `storage_key`
- exercise and attempt persistence can be backed by `Postgres` when `DATABASE_URL` is configured
- learner-facing result rendering
- real production `S3 + Amazon Transcribe` path has now been smoke-tested successfully end-to-end on EC2

Still mocked:
- real scoring pipeline

## Out Of Scope
- pronunciation scoring
- free-form chat
- teacher review workflow
- durable learner history beyond the current backend slice

## Risks
- transcript and feedback quality still depend heavily on input audio quality; a noisy clip can still fail with `transcription_failed` even when infrastructure is healthy
- backend content and attempts still reset on restart if `DATABASE_URL` is not configured
- learner-facing error copy for unusable audio is still generic and should be made more actionable

## Next Step
Keep the same client upload contract and expand the learner plus CMS slice from `Uloha 2` to `Uloha 3`.
