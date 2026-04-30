# Screen: Flutter Exercise Practice

## Surface
`Flutter`

## Main File
- [flutter_app/lib/main.dart](/Users/daniel.dev/Desktop/czech-go-system/flutter_app/lib/main.dart)

## Graph Notes
`code-review-graph` identifies the key practice-screen nodes inside `main.dart`:
- `ExerciseScreen`
- `_ExerciseScreenState`
- `_startRecording`
- `_stopRecording`
- `_ResultCard`

This confirms that the current practice screen bundles:
- attempt action orchestration
- polling logic
- status rendering
- result rendering

That is acceptable for the first slice, but it will likely want extraction once real audio capture and richer result states arrive.

## Purpose
This screen renders one exercise and drives the first speaking attempt flow.

## What The User Sees
- recent-attempt summary cards on the learner shell before entering a module
- exercise type
- learner instruction
- prompt questions for `Uloha 1` in separate card rows
- a short coach note before the attempt area
- attempt status
- elapsed recording time
- progress bar against the current recording timer
- action buttons for start and stop
- local recording file status after capture starts or finishes
- local playback controls for the just-recorded file before the next retry
- transcript and feedback result card when the attempt completes
- uploaded audio metadata plus backend playback card inside the result state
- grouped feedback sections for strengths, improvements, and retry guidance
- a dedicated `Repair and shadowing` block after completed attempts
- pending review state while the backend is still generating the repair artifact
- corrected transcript, model answer, diff hints, and speaking-focus cards when the review artifact is ready
- backend-backed playback for the model-answer audio used for shadowing
- a `Retry with this model` CTA that clears the completed result and returns the learner to the same exercise in a fresh `ready` state

## Visual Direction
- single-task learner screen with generous whitespace
- soft blue coaching surface for guidance
- orange used for the live attempt state and primary CTA
- feedback grouped into supportive color-tinted sections rather than one dense text block
- Playfair Display is bundled locally for heading hierarchy rather than fetched at runtime

## Actions
- start practice
- stop and analyze
- retry with this model

## Data Dependencies
- `GET /v1/attempts`
- `GET /v1/exercises/:exercise_id`
- `POST /v1/attempts`
- `POST /v1/attempts/:attempt_id/recording-started`
- `POST /v1/attempts/:attempt_id/upload-url`
- `POST /v1/attempts/:attempt_id/upload-complete`
- `GET /v1/attempts/:attempt_id`
- `GET /v1/attempts/:attempt_id/audio/file`
- `GET /v1/attempts/:attempt_id/review`
- `GET /v1/attempts/:attempt_id/review/audio/file`

## Main States
- ready
- starting
- recording
- uploading
- processing
- completed
- failed

## Current Limitations
- recording is captured to a real local audio file
- binary upload can target either the backend dev host or S3 depending on `ATTEMPT_UPLOAD_PROVIDER`
- transcript is synthetic only when `TRANSCRIBER_PROVIDER=dev`; real transcript mode uses S3 plus Amazon Transcribe
- result polling assumes a simple success path
- the timer still depends on the UI ticker rather than measured recorder duration
- remote attempt playback now streams a signed URL from `GET /v1/attempts/:attempt_id/audio/url`; local attempts use an HMAC backend stream and S3 attempts use a presigned S3 GET URL
- recent-attempt history currently opens the exercise again rather than a dedicated attempt-detail screen
- the review block exists across oral task types, but sample-answer content remains lighter for `Uloha 3/4`
- review-audio playback uses `GET /v1/attempts/:attempt_id/review/audio/url` and currently streams backend-generated local TTS audio

## Next Step
Keep the retry loop on the same screen, then add a compare view in history so a new attempt can be read against the previous review artifact later.
