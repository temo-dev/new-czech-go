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
- exercise type
- learner instruction
- prompt questions for `Uloha 1` in separate card rows
- a short coach note before the attempt area
- attempt status
- elapsed recording time
- progress bar against the current recording timer
- action buttons for start and stop
- local recording file status after capture starts or finishes
- transcript and feedback result card when the attempt completes
- uploaded audio metadata card inside the result state
- grouped feedback sections for strengths, improvements, and retry guidance

## Visual Direction
- single-task learner screen with generous whitespace
- soft blue coaching surface for guidance
- orange used for the live attempt state and primary CTA
- feedback grouped into supportive color-tinted sections rather than one dense text block
- Playfair Display is bundled locally for heading hierarchy rather than fetched at runtime

## Actions
- start practice
- stop and analyze

## Data Dependencies
- `GET /v1/exercises/:exercise_id`
- `POST /v1/attempts`
- `POST /v1/attempts/:attempt_id/recording-started`
- `POST /v1/attempts/:attempt_id/upload-url`
- `POST /v1/attempts/:attempt_id/upload-complete`
- `GET /v1/attempts/:attempt_id`

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
- binary upload currently goes to the backend dev host rather than durable object storage
- transcript is mocked
- result polling assumes a simple success path
- the timer still depends on the UI ticker rather than measured recorder duration
- there is no playback control for the recorded file yet

## Next Step
Keep the local recording flow, then replace the dev-host binary upload target with durable storage and real transcript processing.
