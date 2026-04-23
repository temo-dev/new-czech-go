# Dev Workflow

## Purpose
This document is the fastest way to bring up the local development stack for:
- `Go` backend
- `Next.js` CMS
- `Flutter` iOS learner app

The workflow is intentionally simple. Use separate terminals and keep each surface easy to restart.

## Recommended Startup Order
1. Start the backend
2. Start the CMS
3. Start the Flutter iOS app

This order makes it easier to verify dependencies:
- CMS depends on the backend API
- Flutter depends on the backend API

## Terminal 1: Backend
From the repo root:

```bash
make dev-backend
```

Expected result:
- backend listens on `http://localhost:8080`
- health endpoint responds at `http://localhost:8080/healthz`
- if `TRANSCRIBER_PROVIDER` is left at `dev`, the backend now logs a warning that transcript and feedback are synthetic and do not reflect the spoken audio

## Terminal 2: CMS
From the repo root:

```bash
make dev-cms
```

Expected result:
- CMS dev server runs at `http://localhost:3000`

Open:
- [CMS](http://localhost:3000)

## Terminal 3: Flutter
From the repo root:

```bash
make dev-ios
```

Expected result:
- Flutter launches the learner app on the iOS simulator or connected device

If Flutter cannot resolve the default iOS target, list devices first:

```bash
make flutter-devices
```

Then run with an explicit device name:

```bash
make dev-ios IOS_DEVICE="iPhone 17 Pro Max"
```

Or with a connected phone:

```bash
make dev-ios IOS_DEVICE="00008110-00182CC20C2B801E"
```

## Quick Health Check
After backend and CMS are up:

```bash
make dev-check
```

This checks:
- backend health on `:8080`
- CMS response on `:3000`

## Container Workflow
Use this when you want a deploy-shaped local stack for `backend + cms + postgres`.

1. Copy the compose env template:

```bash
cp .env.compose.example .env
```

2. Build and start the stack:

```bash
make compose-up
```

Expected result:
- backend listens on `http://localhost:8080`
- CMS listens on `http://localhost:3000`
- Postgres listens on `localhost:5432`

Useful commands:

```bash
make compose-logs
make compose-down
make compose-config
make smoke-attempt-flow
```

Notes:
- this local stack uses containerized `Postgres` to mirror the production shape where the backend will point at `RDS`
- the CMS now calls the backend through same-origin Next.js API routes, and the container reads `API_BASE_URL` plus `CMS_ADMIN_TOKEN` at runtime
- if `CMS_BASIC_AUTH_USER` and `CMS_BASIC_AUTH_PASSWORD` are set, the CMS web layer will prompt for `HTTP Basic Auth` while leaving `/api/healthz` open for health checks
- `Flutter` still runs outside compose and can continue talking to `http://localhost:8080` during simulator-based development
- the backend now also reads `TTS_PROVIDER`; leave it at `dev` for a local debug WAV output, or switch to `amazon_polly` when you want the review-artifact model answer to use real Czech TTS
- for the EC2 host pattern that uses shared `nginx-proxy` and `acme-companion`, use [deploy-ec2-nginx-proxy.md](/Users/daniel.dev/Desktop/czech-go-system/docs/deploy-ec2-nginx-proxy.md) instead of the local compose file
- the EC2 path now includes helper targets such as `make release-images` and `make compose-ec2-up`
- pass extra smoke-test flags with `SMOKE_ATTEMPT_ARGS`, for example `make smoke-attempt-flow SMOKE_BASE_URL=https://apicz.hadoo.eu SMOKE_ATTEMPT_ARGS="--audio-file /absolute/path/to/sample.m4a"`
- when you need proof that the stack is returning real transcript data, add `--require-real-transcript`; the smoke script now fails if the backend still reports `is_synthetic=true`

### Real Transcript Dev Mode
If you want local or compose-based testing to use real transcript data instead of the synthetic dev transcript:

1. set `ATTEMPT_UPLOAD_PROVIDER=s3`
2. set `TRANSCRIBER_PROVIDER=amazon_transcribe`
3. fill the AWS bucket and Transcribe env vars
4. set `REQUIRE_REAL_TRANSCRIPT=true`
5. decide whether review-artifact model audio should stay on `TTS_PROVIDER=dev` or move to `TTS_PROVIDER=amazon_polly`

For local `docker compose`, also make sure the backend container can see AWS credentials:

1. set `AWS_PROFILE=<your-profile>` in `.env`
2. or pass `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_SESSION_TOKEN` directly
3. keep `AWS_EC2_METADATA_DISABLED=true` on local machines so the container does not waste 5 seconds trying `EC2 IMDS`

The local compose file now mounts `${HOME}/.aws` into the backend container as read-only, so profile-based auth works as long as the profile is valid on your Mac.

In the current architecture, `REQUIRE_REAL_TRANSCRIPT=true` is the guard that prevents the backend from silently falling back to the synthetic `DevTranscriber` path.

Current TTS behavior:
- `TTS_PROVIDER=dev` writes one local debug WAV for the review-artifact model answer
- `TTS_PROVIDER=amazon_polly` uses `AWS_REGION` plus optional `POLLY_VOICE_ID` and `POLLY_SAMPLE_RATE`
- review-artifact TTS failure does not block the main attempt from reaching `completed`

If you leave `TRANSCRIBER_PROVIDER=dev`, the app still works, but transcript and feedback are only suitable for contract/UI testing, not serious scoring validation.

Suggested smoke check once the stack is up:

```bash
make smoke-attempt-flow \
  SMOKE_BASE_URL=http://localhost:8080 \
  SMOKE_ATTEMPT_ARGS="--audio-file /absolute/path/to/sample.m4a --require-real-transcript"
```

Current known local-compose behavior:
- `upload-url` and `upload-complete` can now succeed in `s3` mode on a local Mac if the backend container can read valid AWS credentials from `${HOME}/.aws` or direct env vars
- if the backend log shows `AccessDeniedException` on `transcribe:StartTranscriptionJob`, the `S3` upload path is already working and the remaining blocker is IAM for the local AWS identity
- in local `s3` mode, `GET /v1/attempts/:attempt_id/audio/file` may still return `404` because the current playback route is strongest for backend-stored local files, not for audio that only lives in `S3`

## Recommended Daily Flow
1. `make dev-backend`
2. `make dev-cms`
3. `make dev-ios`
4. `make dev-check`

Use this when resuming work after a pause.

## Stop Workflow

### Stop Backend
```bash
make dev-stop-backend
```

### Stop CMS
```bash
make dev-stop-cms
```

### Stop Both Web Services
```bash
make dev-stop
```

This stops processes by port:
- backend on `:8080`
- CMS on `:3000`

### Stop Flutter
Stop Flutter from the terminal running `make dev-ios`:
- press `q` inside `flutter run`
- or press `Ctrl+C`

## Verification Flow Before Stopping
Run these before ending a meaningful coding session:

```bash
make backend-build
make cms-lint
make cms-build
make flutter-analyze
make flutter-test
```

Or run:

```bash
make verify
```

## Common Issues

### Port Already In Use
If `:8080` or `:3000` is already in use, one of the services may already be running from an earlier session.

In that case:
- reuse the running process if it is healthy
- or stop it with `make dev-stop-backend`, `make dev-stop-cms`, or `make dev-stop` and restart with the `make dev-*` commands above

### Flutter Startup Lock
If Flutter says another command holds the startup lock:
- wait a few seconds
- rerun the command

### Flutter Cannot Find `ios`
If Flutter says no device matches `ios`, that means it needs a concrete simulator name or device id.

Use:

```bash
make flutter-devices
make dev-ios IOS_DEVICE="iPhone 17 Pro Max"
```

### CMS Starts But Page Looks Stale
Restart the CMS dev server:

```bash
make dev-cms
```

### Flutter Talks To Wrong API Host
The app currently assumes the backend is reachable at:
- `http://localhost:8080`

If that changes, update the dev API base in the learner app before continuing.

## Notes
- Keep the current upload contract stable while iterating on the backend internals.
- Do not reintroduce remote font fetching.
- Use `rtk`-prefixed commands directly only when you are not using the root `Makefile`.
