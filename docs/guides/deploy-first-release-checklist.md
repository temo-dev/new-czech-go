# First Release Checklist

## Purpose
This is the shortest safe checklist for the first real EC2 release of `A2 Mluveni Sprint` using:
- `nginxproxy/nginx-proxy`
- `nginxproxy/acme-companion`
- `ECR`
- `RDS`
- host-based domains

It is written for the current configured hostnames:
- `https://apicz.hadoo.eu`
- `https://cmscz.hadoo.eu`

If the EC2 machine is still empty, do the host bootstrap first:
- [bootstrap-ec2-arm-host.md](/Users/daniel.dev/Desktop/czech-go-system/docs/bootstrap-ec2-arm-host.md)

## Preflight
1. Confirm the EC2 host has Docker, Docker Compose plugin, and AWS CLI installed.
2. Confirm the shared proxy network exists on the EC2 host.
   Current expected value: `proxy`
3. Confirm these DNS records point to the EC2 host:
   - `apicz.hadoo.eu`
   - `cmscz.hadoo.eu`
4. Confirm `RDS` is reachable from the EC2 host on `5432`.
5. Confirm `.env.ec2` is filled and local-only placeholders are gone where needed.
   Current expected platform: `linux/arm64`
6. Package the Docker deploy bundle on your workstation:

```bash
rtk make package-ec2-deploy EC2_ENV_FILE=.env.ec2
```

7. Copy the bundle to EC2:

```bash
scp dist/czech-go-system-ec2-deploy.tar.gz ec2-user@<ec2-host>:~/
```

## RDS Table Ownership (run once after initial goose migrations)

If goose ran as a different Postgres user than the app user (e.g. `odoo` vs `czech_user`),
the app cannot run `ALTER TABLE` at startup. Fix: transfer ownership to the app user once.

Connect to RDS as the master user (`odoo`):

```sql
\c czech_go_system
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' LOOP
    EXECUTE 'ALTER TABLE public.' || quote_ident(r.tablename) || ' OWNER TO czech_user';
  END LOOP;
END $$;
```

Replace `czech_user` with the value from `DATABASE_URL` in `.env.ec2`.
This only needs to run once per RDS instance. Future inline column additions use
`addColumnIfMissing()` which checks `information_schema` and skips `ALTER TABLE`
when the column already exists.

## Create ECR Repositories
Run once:

```bash
aws ecr create-repository --region eu-central-1 --repository-name czech-go-system-backend
aws ecr create-repository --region eu-central-1 --repository-name czech-go-system-cms
```

## Build And Push
From your workstation:

```bash
make ecr-login EC2_ENV_FILE=.env.ec2
make release-images EC2_ENV_FILE=.env.ec2
```

Expected result:
- backend image pushed to `055279698723.dkr.ecr.eu-central-1.amazonaws.com/czech-go-system-backend:<IMAGE_TAG>`
- CMS image pushed to `055279698723.dkr.ecr.eu-central-1.amazonaws.com/czech-go-system-cms:<IMAGE_TAG>`
- both images are built for `linux/arm64`

## Deploy On EC2
On the EC2 host:

```bash
mkdir -p ~/czech-go-system
cd ~/czech-go-system
tar -xzf ~/czech-go-system-ec2-deploy.tar.gz --strip-components=1
sh scripts/check-ec2-host.sh .env.ec2
docker compose --env-file .env.ec2 -f docker-compose.proxy.yml up -d
sh scripts/check-ec2-env.sh .env.ec2
sh scripts/ecr-login.sh .env.ec2
sh scripts/deploy-ec2.sh .env.ec2
```

Then inspect:

```bash
docker compose --env-file .env.ec2 -f docker-compose.ec2.yml ps
docker compose --env-file .env.ec2 -f docker-compose.ec2.yml logs --tail=100
```

## Public Health Checks
Verify:

```bash
curl -I https://apicz.hadoo.eu/healthz
curl -I https://cmscz.hadoo.eu/api/healthz
```

Expected:
- backend returns `200`
- CMS returns `200`
- certificates are issued and valid

Current real status from the first EC2 deploy:
- `https://apicz.hadoo.eu/healthz` returned `200`
- `https://cmscz.hadoo.eu/api/healthz` returned `200`
- both `backend` and `cms` reached healthy container status
- `RDS` accepted TLS connections from the EC2 host

## App Smoke Test
1. Open `https://cmscz.hadoo.eu`
2. Confirm the CMS loads and can reach the backend at `https://apicz.hadoo.eu`
3. Create one exercise
4. Confirm the new exercise shows in the CMS list and also appears in `RDS`
5. Run the API-level smoke script or use Flutter to create one attempt and verify:
   - attempt is created
   - upload works in current local mode
   - result reaches `completed`
6. Confirm the attempt row is present in `RDS`

Fastest script-based check:

```bash
python3 scripts/smoke_test_attempt_flow.py --base-url https://apicz.hadoo.eu
```

Current real status from the first EC2 deploy:
- exercise creation from CMS has already been confirmed in `RDS`
- learner attempt flow has already been smoke-tested on production
- the real cloud path has now completed successfully once with `ATTEMPT_UPLOAD_PROVIDER=s3` and `TRANSCRIBER_PROVIDER=amazon_transcribe`
- one earlier cloud run with mostly wind noise failed with `transcription_failed`, which is now treated as an input-quality case instead of an infrastructure blocker
- the real cloud path has now also been smoke-tested successfully once with `S3 + Amazon Transcribe`
- one earlier cloud run using mostly wind noise failed with `transcription_failed`, which is now understood as an input-quality problem rather than an infrastructure failure

## Known Current Limitations
- `CMS_ADMIN_TOKEN` is still only a backend-facing shared token
- the CMS web surface still needs `CMS_BASIC_AUTH_USER` and `CMS_BASIC_AUTH_PASSWORD` set if you want the admin desk protected at the browser layer
- the production learner smoke path still depends on the dev learner login and password
- learner-facing failure messages for bad audio quality are still generic and should be improved

That means the first release goal should be:
- app up
- CMS up
- database wired
- end-to-end learner attempt works

Not yet:
- stronger CMS auth than `HTTP Basic Auth`
- provider-aware failure messaging for unusable audio and transcription edge cases

## Rollback
If the release is bad:
1. change `IMAGE_TAG` in `.env.ec2` back to the previous known-good tag
2. redeploy:

```bash
make package-ec2-deploy EC2_ENV_FILE=.env.ec2
scp dist/czech-go-system-ec2-deploy.tar.gz ec2-user@<ec2-host>:~/
ssh ec2-user@<ec2-host> 'cd ~/czech-go-system && tar -xzf ~/czech-go-system-ec2-deploy.tar.gz --strip-components=1 && sh scripts/deploy-ec2.sh .env.ec2'
```

## After First Success
Recommended next order:
1. rotate the current `RDS` password if it has been shared in local files or chat
2. set `CMS_BASIC_AUTH_USER` and `CMS_BASIC_AUTH_PASSWORD` in `.env.ec2`
3. enable `S3` upload
4. enable `Amazon Transcribe`

Recommended immediate cleanup from the first deploy:
- upload a fresh deploy bundle because older bundles required `./.env.ec2` as a workaround
- hard refresh the CMS or use an incognito tab if you still see stale Next.js Server Action errors
