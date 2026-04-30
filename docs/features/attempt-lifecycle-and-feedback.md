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
- [backend/internal/httpapi/upload_targets.go](/Users/daniel.dev/Desktop/czech-go-system/backend/internal/httpapi/upload_targets.go)
- [backend/internal/processing/processor.go](/Users/daniel.dev/Desktop/czech-go-system/backend/internal/processing/processor.go)
- [backend/internal/processing/transcriber.go](/Users/daniel.dev/Desktop/czech-go-system/backend/internal/processing/transcriber.go)
- [backend/internal/processing/transcriber_amazon.go](/Users/daniel.dev/Desktop/czech-go-system/backend/internal/processing/transcriber_amazon.go)
- [backend/internal/store/attempt_store.go](/Users/daniel.dev/Desktop/czech-go-system/backend/internal/store/attempt_store.go)
- [backend/internal/contracts/types.go](/Users/daniel.dev/Desktop/czech-go-system/backend/internal/contracts/types.go)
- [flutter_app/lib/api_client.dart](/Users/daniel.dev/Desktop/czech-go-system/flutter_app/lib/api_client.dart)
- [docs/specs/attempt-state-machine.md](/Users/daniel.dev/Desktop/czech-go-system/docs/specs/attempt-state-machine.md)
- [docs/specs/scoring-pipeline.md](/Users/daniel.dev/Desktop/czech-go-system/docs/specs/scoring-pipeline.md)

## Graph Notes
Graph inspection shows this feature is structurally backend-heavy today:
- `backend/internal/httpapi/server.go` contains the full HTTP orchestration path for attempts, admin flows, auth helpers, and mock scoring
- `backend/internal/httpapi/upload_targets.go` now owns how upload targets are produced for local and `S3` modes
- `backend/internal/store/attempt_store.go` contains the attempt state mutation methods and the in-memory implementation that backs the default dev flow

This confirms that the lifecycle logic is currently split across two files:
- transport and async coordination in `server.go`
- upload-target strategy in `upload_targets.go`
- state mutation and attempt persistence in `attempt_store.go`

That split is workable for V1, but future persistence and real scoring integration should keep the external contracts stable while reducing how much logic lives in the HTTP layer.

## Current Status
Implemented today:
- state transitions in-memory
- async staged processing through a dedicated backend processor
- pluggable transcription layer with a default dev transcriber
- opt-in `Amazon Transcribe` path gated by environment configuration
- pluggable upload target provider with local same-host upload as the default
- opt-in `S3` presigned upload target path gated by environment configuration
- transcript payload
- feedback payload matching the agreed contract
- Flutter now sends real local recording metadata through the upload lifecycle
- backend now accepts a real binary upload on the local dev upload target before `upload-complete`
- completed attempts now retain audio metadata on the attempt record
- failed attempts now expose `failure_code` and `failed_at`
- attempt persistence can now be backed by `Postgres` when `DATABASE_URL` is configured
- attempt creation now stores `user_id`, `client_platform`, and `app_version`
- `upload-complete` now validates that the submitted `storage_key` matches the upload target most recently issued for that attempt
- the learner can now replay the just-recorded local file from the exercise screen before starting another attempt
- the learner can now replay the completed-attempt audio from backend storage through `GET /v1/attempts/:attempt_id/audio/file`
- the learner result card now clearly shows the backend transcript and exposes playback for the submitted attempt audio
- iOS playback of completed-attempt audio now downloads the backend audio file into local temp storage before playing it, instead of asking `AVPlayer` to stream the authenticated backend URL directly
- backend now logs every HTTP request plus attempt-audio-file failure reasons so audio replay issues are visible in local backend logs
- learner shell now shows recent attempts with readiness, feedback summary, and transcript preview so progress can be reviewed across multiple tries
- feedback summaries and retry advice for `Uloha 1` and `Uloha 2` are now task-aware instead of generic, so learners see guidance tied to topic coverage, supporting detail, question form, required info slots, and follow-up questions
- transcript payloads now include provenance metadata so the app can distinguish synthetic dev transcripts from real provider transcripts
- local and compose dev can now opt into a strict `REQUIRE_REAL_TRANSCRIPT=true` mode that refuses to boot if the backend would otherwise fall back to the synthetic dev transcript path
- the smoke script can now assert `--require-real-transcript`, so transcript provenance is checked automatically during end-to-end testing
- local compose has now been proven to reach the `S3` upload path for learner attempts; the current blocker on that path is IAM permission for `transcribe:StartTranscriptionJob` on the local AWS identity, not the upload contract itself
- completed `Uloha 1` and `Uloha 2` attempts can now generate a persisted review artifact with corrected transcript text, model answer text, readable diff chunks, practical speaking-focus items, and one model-answer audio artifact generated by the pluggable `TTSProvider`
- the first TTS slice is backend-only and provider-based: `TTS_PROVIDER=dev` writes a local debug WAV, while `TTS_PROVIDER=amazon_polly` can synthesize a Czech model answer through `Amazon Polly`
- learner-authenticated backend routes now expose the first review-artifact slice through `GET /v1/attempts/:attempt_id/review` and `GET /v1/attempts/:attempt_id/review/audio/file`
- when no full review artifact has been stored yet, the review endpoint now returns a lightweight `pending` stub instead of breaking the attempt flow
- local-backed review-audio playback now works through the same backend temp-storage pattern already used for completed-attempt audio replay
- provider-aware attempt-audio playback now uses `GET /v1/attempts/:attempt_id/audio/url`: local attempts receive an HMAC-signed backend stream URL, while S3-backed attempts receive a presigned S3 `GET` URL
- when `ATTEMPT_AUDIO_URL_PROVIDER` is unset, `ATTEMPT_UPLOAD_PROVIDER=s3` automatically selects S3 playback for submitted attempt audio
- Flutter result UI now renders a dedicated `Repair and shadowing` block after a completed attempt
- that review block now polls the backend review endpoint until the artifact is `ready` or `failed`
- the learner can now see `Transcript cua ban`, `Ban nen noi`, `Ban mau de shadow`, readable diff items, practical speaking-focus items, and playback for the model-answer audio
- when the review artifact is ready, the learner can now tap `Retry with this model` to clear the old result and return the same exercise to a fresh `ready` recording state
- `Uloha 2` review generation now keeps the corrected/model output in question form, uses required slot sample questions to fill missing information coverage, and can suggest one extra natural follow-up question

Not implemented yet:
- module/content persistence beyond the current exercise rows
- provider-aware failure branches and retry history
- end-to-end cloud verification that learner uploads really land in `S3` and then pass through the `Amazon Transcribe` path
- task-aware repair-and-shadowing refinement for `Uloha 3` and `Uloha 4`
- retry-focused compare flow in attempt history

## API Endpoints
- `POST /v1/attempts`
- `POST /v1/attempts/:attempt_id/recording-started`
- `POST /v1/attempts/:attempt_id/upload-url`
- `POST /v1/attempts/:attempt_id/upload-complete`
- `GET /v1/attempts/:attempt_id`
- `GET /v1/attempts/:attempt_id/audio/file`
- `GET /v1/attempts/:attempt_id/audio/url`
- `GET /v1/attempts/:attempt_id/review/audio/url`
- `GET /v1/attempts`

## Out Of Scope
- pronunciation scoring
- real-time partial transcript events
- worker queue orchestration

## Risks
- transcript generation still falls back to the dev transcriber unless `TRANSCRIBER_PROVIDER=amazon_transcribe` and `S3`-backed audio storage are configured
- the strict real-transcript guard only proves configuration intent; it does not replace an actual smoke test against `S3 + Amazon Transcribe`
- polling UX has not yet been tested against real cloud latency
- the current backend still auto-creates the attempt persistence schema on startup, so migration orchestration is not separated yet
- the `S3` upload and `Amazon Transcribe` path has not yet been smoke-tested with a real bucket and AWS credentials in this workspace
- completed-attempt playback is now provider-aware through signed URLs, but old `/audio/file` callers can still fail for S3-only attempts
- the local compose stack now reaches `S3` upload successfully, but real transcript mode still fails until the active local AWS identity is allowed to call `transcribe:StartTranscriptionJob`
- in `s3` mode, use `GET /v1/attempts/:attempt_id/audio/url` for replay; `GET /audio/file` remains local-file oriented

## Next Step
Extend the same repair-and-shadowing loop to `Uloha 2`, then add the history compare view that can line up a retry against the previous review artifact.
