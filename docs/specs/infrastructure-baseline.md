# Infrastructure Baseline

## Purpose
This document defines the V1 infrastructure baseline for `A2 Mluveni Sprint`.

The keyword is `baseline`, not `target architecture for all future scale`. This is the smallest deployable setup that supports:
- one `Go` backend service
- one `Next.js` CMS
- one `Flutter` learner app
- audio upload and storage
- Czech speech-to-text
- async scoring
- a small pilot release

## Constraints
- team size: `1 person + Codex`
- implementation window: `2 weeks`
- target budget for prototype and early pilot: `under 50 USD`
- user platform focus: `iOS` for learners, `web` for CMS
- reliability goal: good enough for a small pilot, not high-scale enterprise

## Baseline Principles
- Prefer fewer moving parts over textbook cloud architecture.
- Pick services with direct product value before adding infrastructure helpers.
- Keep the backend monolithic in V1.
- Use managed services where they remove real operational burden.
- Defer queues, event buses, and multi-service orchestration until a concrete pain appears.

## Chosen Baseline

### Application Components
- `Flutter iOS app`
- `Next.js CMS web app`
- `Go backend API and processing service`
- `Postgres` for relational data
- `S3` for audio and exercise assets
- `Amazon Transcribe` for Czech STT
- `Amazon Polly` for prompt or sample-answer TTS

### Deployment Shape
- deploy `Go backend` as one service
- deploy `Next.js CMS` as one separate web app
- use direct object storage uploads from clients via presigned URLs
- process attempts asynchronously inside the same backend service or via one lightweight worker mode of the same codebase
- ship the backend and CMS as Docker images so local compose, ECS tasks, and small-host deployments reuse the same runtime artifact

This means V1 does **not** require:
- microservices
- `SQS`
- `EventBridge`
- `API Gateway` plus `ALB` together
- `ECS/Fargate` if a simpler host is available
- Kubernetes

## Recommended Environment Layout

### Environments
- `local`
- `staging`
- `production`

V1 can keep `staging` and `production` extremely small. If necessary, `staging` may share some low-risk infrastructure patterns with production but must not share databases or storage buckets.

### AWS Account Usage
Preferred:
- one AWS account for the project in V1
- separate resource names per environment

This keeps setup lighter while still allowing environment isolation.

## Compute Baseline

## Backend
Recommended baseline:
- one containerized `Go` service
- one deploy target per environment

Acceptable hosting options, in order of pragmatism:
1. simple VM or app platform that can run one container reliably
2. one lightweight ECS service if team already wants AWS-native deployment
3. one small EC2 instance if that is faster operationally

V1 recommendation:
- choose the option you can deploy in hours, not days
- if no existing preference exists, a small VM or a single small EC2 instance is the safest baseline
- if using one EC2 host with multiple apps, a shared reverse proxy such as `nginx-proxy` plus Docker networking is still within baseline as long as the backend stays one long-running service

Why:
- constant background processing for transcription polling and scoring is easier in a long-running service than in a serverless design
- operational debugging is simpler with one persistent service

Packaging note:
- keep one production `Dockerfile` in `backend/`
- local `docker compose` may run `Postgres` beside it, but production should point `DATABASE_URL` at `RDS`

## CMS
Recommended baseline:
- deploy `Next.js` separately on the fastest reliable platform available

Acceptable options:
- Vercel
- a small Node-capable app platform
- the same VM family if co-hosting is operationally simpler

V1 recommendation:
- if using Vercel keeps the CMS out of the backend path, that is a good trade
- do not force the CMS into the same deploy unit if that slows iteration

Packaging note:
- keep one production `Dockerfile` in `cms/`
- pass `API_BASE_URL` and `CMS_ADMIN_TOKEN` to the container at runtime
- if the CMS is public on the internet, also set `CMS_BASIC_AUTH_USER` and `CMS_BASIC_AUTH_PASSWORD` so the admin desk is not public-open

## Data Baseline

## Relational Data
Primary store:
- `Postgres`

Stores:
- users
- courses/modules/exercises
- scoring templates
- attempts
- transcripts
- feedback
- mock exam sessions

Acceptable V1 options:
1. managed Postgres with low-cost tier
2. Postgres on the same VM if budget or speed demands it

Recommendation:
- if budget allows, prefer managed Postgres for backup and operational simplicity
- if budget is too tight, colocated Postgres is acceptable for a short pilot

## Object Storage
Primary store:
- `S3`

Stores:
- learner audio uploads
- exercise images
- prompt audio
- sample answer audio

Bucket strategy:
- separate buckets or prefixes per environment
- distinct prefixes for `attempt-audio` and `exercise-assets`

Suggested prefix layout:
```text
staging/attempt-audio/<attempt-id>/audio.m4a
staging/exercise-assets/<exercise-id>/image-1.jpg
production/prompt-audio/<exercise-id>/prompt.mp3
```

## Speech Services Baseline

## Speech-to-Text
Primary choice:
- `Amazon Transcribe`

Why:
- supports Czech
- integrates well with the chosen object storage and backend stack
- can be used in upload-first mode without building realtime infrastructure first

V1 mode:
- batch or upload-triggered async processing from stored audio

Not in baseline:
- realtime transcription as a hard dependency

## Text-to-Speech
Primary choice:
- `Amazon Polly`

Use cases:
- prompt audio
- sample answer audio
- optional learner playback content

Guideline:
- pre-generate prompt or sample audio where possible instead of synthesizing on every request

## Async Processing Baseline

### Chosen Pattern
Use one of these two patterns:

1. same-service background processing
- upload completion writes attempt state
- backend launches or schedules transcription/scoring work in the same service process model

2. same-codebase worker mode
- one process serves HTTP
- one process runs lightweight polling and scoring jobs

V1 recommendation:
- start with same-service background processing if deployment platform supports persistent processes well
- move to worker mode only if request latency or crash isolation becomes a problem

### Not in Baseline
- `SQS`
- `EventBridge`
- dedicated workflow engine
- distributed job orchestration

Reason:
- they add setup and failure modes before the product has enough volume to justify them

## Networking Baseline

### Client Upload Pattern
- learner app requests a presigned upload URL from backend
- learner app uploads audio directly to `S3`
- learner app notifies backend with upload metadata
- backend begins transcription and scoring

Why:
- avoids routing large audio files through the backend
- reduces backend bandwidth and memory pressure
- keeps the API service focused on coordination

### API Exposure
V1 needs:
- HTTPS for backend API
- HTTPS for CMS

Recommended:
- one stable domain for API, for example `api.<project-domain>`
- one stable domain for CMS, for example `cms.<project-domain>`

Pragmatic alternative when the host already runs `nginxproxy/nginx-proxy`:
- publish backend and CMS on separate hostnames
- route by `VIRTUAL_HOST` instead of introducing `ALB`
- let the app containers join the shared proxy Docker network

## Security Baseline

### Secrets
Store these outside source control:
- JWT or session signing secrets
- database credentials
- AWS credentials or IAM workload identity configuration
- LLM provider secrets if used for scoring

### IAM Guidance
- backend service should have least-privilege access to:
  - read and write relevant `S3` prefixes
  - invoke `Transcribe`
  - invoke `Polly`
- CMS should not have direct broad storage access beyond what backend mediates

### Upload Validation
Backend must validate:
- expected content type
- max file size
- duration bounds
- upload target ownership

## Observability Baseline

V1 minimum:
- structured application logs
- request IDs
- attempt IDs in logs
- error logs for failed transcription or scoring

Nice to have, but not required:
- centralized log search
- uptime monitor for backend and CMS
- one alert on repeated failed attempts or crash loops

Do not block launch on:
- full tracing stack
- metrics dashboards with dozens of charts

## Backup and Recovery Baseline

### Database
- daily automated backup if managed
- if self-hosted, automated dump at least daily

### S3
- rely on object durability for V1
- do not overbuild archival lifecycle policies before real usage patterns are known

### Recovery Goals
- acceptable to restore within hours for V1 pilot
- unacceptable to lose all attempt metadata silently

## Cost Guardrails

### Budget Priorities
Spend on:
1. storage for audio/assets
2. database
3. speech-to-text for real learner attempts
4. minimal hosting

Avoid spending early on:
- redundant compute
- complex staging duplicates
- heavy observability tools
- realtime speech infrastructure

### Practical Guardrails
- cap max recording duration per attempt
- pre-generate repeated prompt audio instead of synthesizing every time
- limit pilot users if speech-service usage spikes unexpectedly
- keep staging usage low and synthetic

## Scaling Triggers
Only add more infrastructure when one of these becomes true:
- attempt processing delays are common at pilot volume
- same-process background jobs interfere with API responsiveness
- deployment safety becomes a recurring problem
- multiple concurrent users make single-instance processing too slow

Then add, in this order:
1. separate worker process using same codebase
2. managed Postgres if still self-hosted
3. lightweight queue
4. richer observability

Not first:
- microservices
- Kubernetes
- multi-region setup

## Local Development Baseline

Recommended local stack:
- `Go` backend runs locally
- `Next.js` CMS runs locally
- local `Flutter` simulator or device testing
- local Postgres via container or local install
- `S3` may be mocked locally or pointed to a low-risk dev bucket

Local developer needs:
- seed data for exercises
- one sample learner account
- one sample CMS admin account
- one sample audio file for scoring pipeline testing

## Environment Variables

Illustrative categories:
- app config
- auth secrets
- database DSN
- AWS region and bucket names
- Transcribe config
- Polly config
- scoring provider config

Do not hard-code:
- bucket names
- provider credentials
- environment URLs

## Non-Goals for V1 Infrastructure
- zero-downtime deployments
- autoscaling based on complex metrics
- active-active redundancy
- fine-grained internal event-driven architecture
- separate infra stacks for every small experiment

## Recommended V1 Baseline Summary

If choosing today, the most practical baseline is:
- `Flutter` iOS app
- `Next.js` CMS on Vercel or equivalent
- one small long-running `Go` backend service
- one small `Postgres` instance
- `S3` for uploads and assets
- `Amazon Transcribe` for Czech STT
- `Amazon Polly` for TTS
- presigned upload flow
- async processing inside the monolith

This is production-minded enough for a pilot and simple enough to actually ship in two weeks.

## Open Questions
- Do you already have a preferred host for the `Go` service, or should we optimize for the fastest path to first deploy?
- Is managed Postgres worth the extra cost for peace of mind, or do we want to keep V1 even leaner?
- Do we want a tiny worker process from day one, or is in-process async good enough until the first real load test?
