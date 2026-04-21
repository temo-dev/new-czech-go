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
7. App requests an upload target, uploads the recorded audio binary to the backend dev target, then completes the upload contract and polls the backend.
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
- [backend/internal/store/memory.go](/Users/daniel.dev/Desktop/czech-go-system/backend/internal/store/memory.go)

## Graph Notes
`code-review-graph` confirms this feature is currently concentrated in a few key files:
- `flutter_app/lib/main.dart` contains `21` graph nodes, including `LearnerShell`, `ExerciseScreen`, `_startRecording`, `_stopRecording`, and `_ResultCard`
- `flutter_app/lib/api_client.dart` contains `12` graph nodes centered around `ApiClient` and the learner attempt/content methods
- `backend/internal/httpapi/server.go` contains `31` graph nodes and currently acts as the central HTTP coordination file
- `backend/internal/store/memory.go` contains `22` graph nodes and currently holds the in-memory feature state and attempt progression data

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
- binary audio upload to the backend dev target
- audio metadata returned on the attempt result
- mock async processing
- learner-facing result rendering

Still mocked:
- real transcript generation
- real scoring pipeline

## Out Of Scope
- pronunciation scoring
- free-form chat
- teacher review workflow
- persistent progress history beyond the in-memory backend

## Risks
- current transcript and feedback are synthetic, so UX is real but learning quality is not yet validated
- backend data resets on restart because storage is in-memory
- uploaded audio is stored in local temp storage on the backend host, not durable cloud storage

## Next Step
Keep the same client upload contract, then swap the local backend upload target for durable object storage and real transcription.
