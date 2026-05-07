# Production Attempt Smoke Test

## Purpose
This guide is the shortest repeatable check for the live learner flow on the deployed EC2 stack.

It verifies:
- learner login
- attempt creation
- upload target issuance
- binary upload
- `upload-complete`
- async processing through `transcribing -> scoring -> completed`

It does not require Flutter.

## Main Files
- [scripts/smoke_test_attempt_flow.py](/Users/daniel.dev/Desktop/czech-go-system/scripts/smoke_test_attempt_flow.py)
- [docs/deploy-first-release-checklist.md](/Users/daniel.dev/Desktop/czech-go-system/docs/deploy-first-release-checklist.md)
- [docs/features/attempt-lifecycle-and-feedback.md](/Users/daniel.dev/Desktop/czech-go-system/docs/features/attempt-lifecycle-and-feedback.md)

## Defaults
The smoke script uses:
- learner login: `learner@example.com`
- password: `demo123`
- exercise: `exercise-uloha1-weather`
- reported client platform: `smoke-test`

If no audio file is passed, the script creates a tiny temporary `.m4a`-named file. That is enough for the current local upload plus dev transcription path because the backend only needs:
- uploaded bytes to exist
- `duration_ms > 0`

If the upload target comes back as cloud storage instead of the backend host, the script now refuses to use the dummy file and asks for a real audio sample.

## Run From Your Workstation
```bash
rtk python3 scripts/smoke_test_attempt_flow.py --base-url https://apicz.hadoo.eu
```

## Run With A Real Audio File
```bash
rtk python3 scripts/smoke_test_attempt_flow.py \
  --base-url https://apicz.hadoo.eu \
  --audio-file /absolute/path/to/sample.m4a
```

## Run Against Real `S3` + `Amazon Transcribe`
When production is switched to:
- `ATTEMPT_UPLOAD_PROVIDER=s3`
- `TRANSCRIBER_PROVIDER=amazon_transcribe`

use a real audio sample and let the script auto-pick the longer cloud timeout:

```bash
rtk python3 scripts/smoke_test_attempt_flow.py \
  --base-url https://apicz.hadoo.eu \
  --audio-file /absolute/path/to/sample.m4a
```

If your transcription jobs are slower than usual, raise the timeout explicitly:

```bash
rtk python3 scripts/smoke_test_attempt_flow.py \
  --base-url https://apicz.hadoo.eu \
  --audio-file /absolute/path/to/sample.m4a \
  --timeout-sec 300
```

When testing a real cloud upload, do not force `--sample-rate-hz` unless you know the actual encoded sample rate of the audio file. The smoke script now omits `sample_rate_hz` by default so `Amazon Transcribe` can detect it itself.

The backend also no longer forwards client-reported `sample_rate_hz` into `StartTranscriptionJob` for V1. We still keep the field as stored metadata, but we do not trust guessed values enough to make the transcription job depend on them.

Before the real cloud smoke run on EC2, you can also check IAM reachability with:

```bash
sh scripts/check-aws-audio-pipeline.sh .env.ec2
```

## Run On The EC2 Host
If the deploy bundle has been refreshed to include the smoke script:

```bash
cd ~/czech-go-system
sh scripts/check-aws-audio-pipeline.sh .env.ec2
python3 scripts/smoke_test_attempt_flow.py --base-url https://apicz.hadoo.eu
```

If the EC2 host does not have `make`, keep using the bundled shell scripts directly. The production bundle does not require a git checkout or Makefile tooling on the host.

## Expected Output
Successful output looks like:

```json
{
  "attempt_id": "attempt-...",
  "status": "completed",
  "failure_code": null,
  "readiness_level": "almost_ready",
  "upload_mode": "cloud",
  "audio_storage_key": "attempt-audio/attempt-.../audio.m4a",
  "transcript_preview": "...",
  "feedback_summary": "..."
}
```

One real production result on EC2 is already in this shape:

```json
{
  "attempt_id": "b9a080e5-4c66-49aa-97fb-05d38534ceb4",
  "status": "completed",
  "failure_code": null,
  "readiness_level": "almost_ready",
  "upload_mode": "cloud",
  "audio_storage_key": "attempt-audio/b9a080e5-4c66-49aa-97fb-05d38534ceb4/audio.mp4",
  "transcript_preview": "Dobry den, ja jsem Daniel. Mam na TP po- pocasi, protoze muzu byt dlouho venku s rodinou.",
  "feedback_summary": "Ban dang o gan muc on, chi can them vai chi tiet cu the de bai noi thuyet phuc hon."
}
```

If the attempt ends in `failed`, the script exits non-zero.

The summary also includes `failure_code` so the first debug pass can usually stay at the API layer before opening container logs.

When a cloud attempt fails with `failure_code=transcription_failed`, the next command on EC2 should be:

```bash
docker compose --env-file .env.ec2 -f docker-compose.ec2.yml logs --tail=200 backend
```

The backend now logs the transcriber error together with:
- `attempt_id`
- `storage_key`
- `mime_type`
- `duration_ms`

That is the fastest way to tell whether the failure came from:
- the uploaded object format
- `Amazon Transcribe` job startup
- transcript download from `S3`

One real production failure before the final pass was a file that mostly contained wind noise. That run reached `upload_mode=cloud`, but the backend marked the transcript as unusable and the attempt ended with `failure_code=transcription_failed`. In practice, that means the cloud path was healthy, but the audio content itself was not usable for scoring.

One later production run with a spoken Czech sample completed successfully end-to-end:

```json
{
  "attempt_id": "b9a080e5-4c66-49aa-97fb-05d38534ceb4",
  "status": "completed",
  "failure_code": null,
  "readiness_level": "almost_ready",
  "upload_mode": "cloud",
  "audio_storage_key": "attempt-audio/b9a080e5-4c66-49aa-97fb-05d38534ceb4/audio.mp4",
  "transcript_preview": "Dobry den, ja jsem Daniel. Mam na TP po- pocasi, protoze muzu byt dlouho venku s rodinou.",
  "feedback_summary": "Ban dang o gan muc on, chi can them vai chi tiet cu the de bai noi thuyet phuc hon."
}
```

When `TRANSCRIBE_OUTPUT_BUCKET` is configured, the backend now prefers downloading the finished transcript directly from `s3://<bucket>/<prefix>/<job>.json` via IAM instead of relying on the HTTP `TranscriptFileUri`. This avoids the common case where the transcription job succeeds but the public download URL returns `403`.

## MIME Notes For Real `.m4a` Files
Some Linux and Python runtimes infer `.m4a` as `audio/mp4a-latm` instead of `audio/m4a`.

The backend and smoke script now normalize those common aliases so real `.m4a` uploads still get:
- `audio.m4a` storage keys
- the correct `Amazon Transcribe` media format

If an older deploy bundle or image is still running, a real `.m4a` smoke run may fall back to `audio.bin` and end with `transcription_failed`. In that case, refresh the backend image before continuing.

## DB Verification Queries
After a successful smoke run, these queries should show a new row:

```bash
docker run --rm postgres:16-alpine psql "host=database-odoo-2.cvundtaezu15.eu-central-1.rds.amazonaws.com port=5432 user=czech_user password=<password> dbname=czech_go_system sslmode=require" -c 'select id,user_id,exercise_id,status,attempt_no,started_at,completed_at,failed_at from attempts order by started_at desc limit 20;'
```

```bash
docker run --rm postgres:16-alpine psql "host=database-odoo-2.cvundtaezu15.eu-central-1.rds.amazonaws.com port=5432 user=czech_user password=<password> dbname=czech_go_system sslmode=require" -c '\d attempt_audio'
```

```bash
docker run --rm postgres:16-alpine psql "host=database-odoo-2.cvundtaezu15.eu-central-1.rds.amazonaws.com port=5432 user=czech_user password=<password> dbname=czech_go_system sslmode=require" -c '\d attempt_transcripts'
```

```bash
docker run --rm postgres:16-alpine psql "host=database-odoo-2.cvundtaezu15.eu-central-1.rds.amazonaws.com port=5432 user=czech_user password=<password> dbname=czech_go_system sslmode=require" -c '\d attempt_feedback'
```

Use the schema output above to shape exact `select` statements if the persistence schema evolves.

## Current Limitations
- this can validate either the current local upload path or the real `S3` plus `Amazon Transcribe` path
- for the cloud path, it needs a real audio file instead of the dummy temporary file
- it still depends on the dev learner login and password

## Next Step
The real cloud path has now passed once on production.

Recommended next order:
- map provider-specific upload and transcription failures into cleaner learner-safe learner messages
- keep one short spoken Czech sample around as a reusable EC2 smoke-test fixture
- move back to product feature work instead of more infrastructure expansion
