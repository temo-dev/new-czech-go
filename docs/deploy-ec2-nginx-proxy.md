# EC2 Deploy With `nginx-proxy`

## Purpose
This doc explains the deployment shape that matches an EC2 host already using:
- `nginxproxy/nginx-proxy`
- `nginxproxy/acme-companion`
- host-based virtual routing such as `app.example.com`

This is the recommended path when you do **not** want `ALB` and already operate a shared Docker-based reverse proxy on the instance.

## Shape
- shared EC2 host
- shared `nginx-proxy` + `acme-companion`
- one `backend` container for the API
- one `cms` container for the Next.js admin app
- `RDS Postgres` outside Docker
- `ECR` stores versioned backend and CMS images
- optional AWS services for `S3` and `Amazon Transcribe`

## Files
- [bootstrap-ec2-arm-host.md](/Users/daniel.dev/Desktop/czech-go-system/docs/bootstrap-ec2-arm-host.md)
- [docker-compose.proxy.yml](/Users/daniel.dev/Desktop/czech-go-system/docker-compose.proxy.yml)
- [docker-compose.ec2.yml](/Users/daniel.dev/Desktop/czech-go-system/docker-compose.ec2.yml)
- [.env.ec2.example](/Users/daniel.dev/Desktop/czech-go-system/.env.ec2.example)
- [backend/Dockerfile](/Users/daniel.dev/Desktop/czech-go-system/backend/Dockerfile)
- [cms/Dockerfile](/Users/daniel.dev/Desktop/czech-go-system/cms/Dockerfile)
- [scripts/check-ec2-host.sh](/Users/daniel.dev/Desktop/czech-go-system/scripts/check-ec2-host.sh)
- [scripts/package-ec2-deploy.sh](/Users/daniel.dev/Desktop/czech-go-system/scripts/package-ec2-deploy.sh)
- [scripts/ecr-login.sh](/Users/daniel.dev/Desktop/czech-go-system/scripts/ecr-login.sh)
- [scripts/check-ec2-env.sh](/Users/daniel.dev/Desktop/czech-go-system/scripts/check-ec2-env.sh)
- [scripts/build-push-images.sh](/Users/daniel.dev/Desktop/czech-go-system/scripts/build-push-images.sh)
- [scripts/deploy-ec2.sh](/Users/daniel.dev/Desktop/czech-go-system/scripts/deploy-ec2.sh)
- [scripts/smoke_test_attempt_flow.py](/Users/daniel.dev/Desktop/czech-go-system/scripts/smoke_test_attempt_flow.py)
- [deploy-first-release-checklist.md](/Users/daniel.dev/Desktop/czech-go-system/docs/deploy-first-release-checklist.md)
- [production-attempt-smoke-test.md](/Users/daniel.dev/Desktop/czech-go-system/docs/production-attempt-smoke-test.md)

## Key Assumptions
- your EC2 host already has a proxy network shared with `nginx-proxy`
- the proxy containers keep handling `80/443` and Let's Encrypt
- this app stack only joins that network and exposes internal ports
- `backend` is published on a dedicated hostname such as `api.example.com`
- `cms` is published on a dedicated hostname such as `cms.example.com`

This doc assumes host-based routing because that is the natural fit for `nginx-proxy`.

If the EC2 host is still fresh and has no Docker tooling yet, start with:
- [bootstrap-ec2-arm-host.md](/Users/daniel.dev/Desktop/czech-go-system/docs/bootstrap-ec2-arm-host.md)

## Why Two Hostnames
That means the cleanest production shape is:
- `https://api.example.com` for backend
- `https://cms.example.com` for CMS

The CMS now talks to the backend through same-origin Next.js API routes and uses a server-side `API_BASE_URL` such as `http://backend:8080` inside the container network.

If you want one domain with path routing such as `/v1`, that is still possible, but it requires custom `nginx` vhost rules beyond the default `VIRTUAL_HOST` pattern.

## Release Strategy
Use immutable tags for each deploy instead of reusing `latest`.

Recommended shape:
- one tag per release, for example `20260422-001`
- backend image: `<repo>:<tag>`
- CMS image: `<repo>:<tag>`
- target platform: `linux/arm64` for the current EC2 host
- `.env.ec2` points at the release tag currently deployed

Why:
- rollback is just changing `IMAGE_TAG` back to the previous value
- the EC2 host always pulls an exact artifact
- debugging is easier because logs map to one concrete image build

## Prepare The Proxy Network
If your EC2 host is fresh, bring up the bundled proxy stack first:

```bash
docker compose --env-file .env.ec2 -f docker-compose.proxy.yml up -d
```

If your existing proxy stack already uses a named Docker network, reuse it.

If not, create one and attach the proxy stack to it:

```bash
docker network create proxy
```

Then ensure the proxy containers and this app stack both join that same network.

## Prepare Environment
On your workstation:

```bash
cp .env.ec2.example .env.ec2
```

Fill in:
- `PROXY_NETWORK`
- `AWS_REGION`
- `AWS_ACCOUNT_ID`
- `ECR_REGISTRY`
- `LE_EMAIL`
- `BACKEND_HOST`
- `CMS_HOST`
- `BACKEND_IMAGE_REPO`
- `CMS_IMAGE_REPO`
- `IMAGE_TAG`
- `IMAGE_PLATFORM`
- `API_BASE_URL`
- `CMS_ADMIN_TOKEN`
- `CMS_BASIC_AUTH_USER`
- `CMS_BASIC_AUTH_PASSWORD`
- `DATABASE_URL`
- `AUDIO_SIGN_SECRET` — **required**; backend fatal-exits if missing. Generate: `openssl rand -hex 32`

Use `sslmode=require` in `DATABASE_URL` for `RDS`.

Then package the deploy bundle:

```bash
make package-ec2-deploy EC2_ENV_FILE=.env.ec2
```

Copy it to EC2:

```bash
scp dist/czech-go-system-ec2-deploy.tar.gz ec2-user@<ec2-host>:~/
```

## Create ECR Repositories
Create the two repositories once:

```bash
aws ecr create-repository --region eu-central-1 --repository-name czech-go-system-backend
aws ecr create-repository --region eu-central-1 --repository-name czech-go-system-cms
```

If they already exist, AWS will return an error and you can ignore that.

## Login To ECR
Before pushing images from your workstation or CI:

```bash
make check-ec2-env EC2_ENV_FILE=.env.ec2
make ecr-login EC2_ENV_FILE=.env.ec2
```

This uses `AWS_REGION` and `ECR_REGISTRY` from `.env.ec2`.

## Build And Push Images
From your workstation or CI:

```bash
cp .env.ec2.example .env.ec2
make check-ec2-env EC2_ENV_FILE=.env.ec2
make ecr-login EC2_ENV_FILE=.env.ec2
make release-images EC2_ENV_FILE=.env.ec2
```

This uses:
- `BACKEND_IMAGE_REPO`
- `CMS_IMAGE_REPO`
- `IMAGE_TAG`
- `IMAGE_PLATFORM`

If you prefer the raw script:

```bash
sh scripts/ecr-login.sh .env.ec2
ENV_FILE=.env.ec2 sh scripts/build-push-images.sh
```

## Deploy
On the EC2 host, verify host readiness and render config first:

```bash
mkdir -p ~/czech-go-system
cd ~/czech-go-system
tar -xzf ~/czech-go-system-ec2-deploy.tar.gz --strip-components=1
sh scripts/check-ec2-host.sh .env.ec2
docker compose --env-file .env.ec2 -f docker-compose.ec2.yml config
```

Then deploy:

```bash
sh scripts/ecr-login.sh .env.ec2
sh scripts/deploy-ec2.sh .env.ec2
```

This validates config, pulls the exact tagged images, and restarts the stack.

If you prefer the raw script:

```bash
sh scripts/deploy-ec2.sh .env.ec2
```

## Verify
Check containers:

```bash
docker compose --env-file .env.ec2 -f docker-compose.ec2.yml ps
docker compose --env-file .env.ec2 -f docker-compose.ec2.yml logs --tail=100
```

Expected public endpoints:
- `https://api.example.com/healthz`
- `https://cms.example.com/api/healthz`

## Current Known Good State
The current production-shaped deploy on EC2 has already reached this state once:
- `proxy` and `acme` are running on the ARM host
- `backend` and `cms` both pull successfully from `ECR`
- `https://apicz.hadoo.eu/healthz` returns `200`
- `https://cmscz.hadoo.eu/api/healthz` returns `200`
- `RDS` is reachable from EC2 on `5432`
- `Postgres` persistence is active and the CMS has already written exercise rows into `RDS`
- the EC2 host can now reach AWS identity, the shared `czech-go-app` audio bucket prefixes, and the `Amazon Transcribe` API through `sh scripts/check-aws-audio-pipeline.sh .env.ec2`
- the real cloud learner flow has now completed successfully once on production with:
  - `ATTEMPT_UPLOAD_PROVIDER=s3`
  - `TRANSCRIBER_PROVIDER=amazon_transcribe`
  - `TRANSCRIBE_OUTPUT_BUCKET` and `TRANSCRIBE_OUTPUT_PREFIX` set

One real-world issue from the first deploy:
- the backend stayed in a restart loop until the `czech_user` role and `czech_go_system` database were created in `RDS`
- after that fix, backend health became healthy and logs showed `attempt and exercise persistence enabled with Postgres`

Another real-world issue from the CMS after redeploy:
- `Failed to find Server Action ... older or newer deployment`
- this came from a browser session holding stale Next.js action ids from an older build
- hard refresh or an incognito tab cleared it

Current hardening note:
- the CMS can now challenge browsers with `HTTP Basic Auth` when `CMS_BASIC_AUTH_USER` and `CMS_BASIC_AUTH_PASSWORD` are set
- keep `/api/healthz` outside that challenge so Docker health checks still pass

The next operational check after infrastructure health should be:
- [production-attempt-smoke-test.md](/Users/daniel.dev/Desktop/czech-go-system/docs/production-attempt-smoke-test.md)

One practical lesson from the live smoke runs:
- an audio file that is mostly wind noise may still exercise the whole cloud pipeline correctly, but it can end in `transcription_failed` because the transcript is unusable for scoring
- a short spoken Czech sample has already completed successfully end-to-end on production

## Enable Real `S3` + `Amazon Transcribe`
Once the first local-mode production deploy is stable, switch the backend to the real cloud speech path by setting:
- `ATTEMPT_UPLOAD_PROVIDER=s3`
- `TRANSCRIBER_PROVIDER=amazon_transcribe`
- `ATTEMPT_AUDIO_S3_BUCKET`
- `ATTEMPT_AUDIO_S3_PREFIX`
- `TRANSCRIBE_LANGUAGE_CODE`
- optionally `TRANSCRIBE_OUTPUT_BUCKET`
- optionally `TRANSCRIBE_OUTPUT_PREFIX`

The EC2 host or task role then needs AWS permissions to:
- presign `S3` uploads into the configured audio bucket prefix
- read learner audio objects from that prefix
- start and read `Amazon Transcribe` jobs
- optionally write transcript output into `TRANSCRIBE_OUTPUT_BUCKET`

After changing those env vars:
1. refresh the deploy bundle
2. redeploy the backend
3. run `sh scripts/check-aws-audio-pipeline.sh .env.ec2` on the EC2 host
4. run [production-attempt-smoke-test.md](/Users/daniel.dev/Desktop/czech-go-system/docs/production-attempt-smoke-test.md) with a real audio file

Using one bucket for both audio and transcripts is supported. In that case:
- set `ATTEMPT_AUDIO_S3_BUCKET` and `TRANSCRIBE_OUTPUT_BUCKET` to the same bucket name
- keep `ATTEMPT_AUDIO_S3_PREFIX` and `TRANSCRIBE_OUTPUT_PREFIX` different

This matches the AWS API shape where `OutputBucketName` is only the bucket name, and `OutputKey` provides the sub-folder path.

Example:
- `ATTEMPT_AUDIO_S3_BUCKET=czech-go-app`
- `ATTEMPT_AUDIO_S3_PREFIX=attempt-audio`
- `TRANSCRIBE_OUTPUT_BUCKET=czech-go-app`
- `TRANSCRIBE_OUTPUT_PREFIX=transcribe-output`

Current live status:
- this shared-bucket pattern has already been validated at the IAM and bucket-prefix level on the EC2 host
- a cloud-mode redeploy with `ATTEMPT_UPLOAD_PROVIDER=s3` is now in progress on EC2 with image tag `20260422-002`
- do not call the cloud path done until the backend returns healthy again and a real-audio smoke test completes

## Update
For a new release:
1. build and push a new immutable tag
2. update `IMAGE_TAG` in `.env.ec2`
3. rerun `make package-ec2-deploy EC2_ENV_FILE=.env.ec2`
4. copy the new bundle to EC2
5. redeploy with `sh scripts/deploy-ec2.sh .env.ec2`

## Rollback
Rollback is intentionally simple:
1. change `IMAGE_TAG` in `.env.ec2` back to the previous release
2. rerun `make package-ec2-deploy EC2_ENV_FILE=.env.ec2`
3. copy the bundle to EC2
4. rerun `sh scripts/deploy-ec2.sh .env.ec2`

Because the compose file uses `<repo>:<tag>`, rollback does not require editing service definitions.

## AWS Notes
For the first deployment keep this simple:
- use `ECR` as the image registry
- use `RDS` for `DATABASE_URL`
- build images for `linux/arm64` because the target EC2 host is ARM
- keep `TRANSCRIBER_PROVIDER=dev` and `ATTEMPT_UPLOAD_PROVIDER=local` until the app is stable
- set `CMS_BASIC_AUTH_USER` and `CMS_BASIC_AUTH_PASSWORD` on production deploys so the CMS web surface is not public-open
- turn on `S3` plus `Amazon Transcribe` later by setting the AWS env vars and giving the host or workload valid AWS credentials

## Operational Notes
- `backend` and `cms` do not bind host ports in this EC2 compose file; `nginx-proxy` reaches them over Docker networking
- `docker-compose.proxy.yml` is intentionally minimal and should only be used when the host does not already have a shared proxy stack
- the deploy bundle lets the EC2 host run without a git checkout; it only needs Docker, AWS CLI, the tarball, and `.env.ec2`
- the EC2 host does not need `make`; every operational step can be run through the bundled shell scripts directly
- if you are using an older deploy bundle, run the scripts with `./.env.ec2` instead of `.env.ec2`; newer bundles normalize this path correctly
- `docker compose` may warn about orphan containers `acme` and `proxy` when the app stack is deployed separately from the shared proxy stack; that warning is expected in the current host layout
- if you rebuild the CMS with a new API hostname, redeploy the CMS container with the new image tag
- if your proxy stack lives in one large compose file already, you can also copy only the `backend` and `cms` service definitions into that existing file instead of running a second compose project
- the helper scripts are intentionally thin wrappers around `docker build`, `docker push`, and `docker compose`; if they ever get in the way, the raw commands above remain the source of truth
