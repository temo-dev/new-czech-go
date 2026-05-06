# V19 Staging Deploy Runbook

Spec: `docs/specs/skill-mastery-progress.md`. Phase 2 gate 1.

## Pre-flight

- Backend tests green (570/570).
- Flutter tests green (265/265).
- Smoke locally green (`make smoke-all`).
- CHANGELOG entry merged on staging branch.

## Deploy steps

```bash
# 1. Build + push images
make ecr-login
make release-images   # backend + cms tagged with current commit SHA

# 2. SSH to staging EC2
ssh staging.czechgo.hadoo.eu

# 3. Pull + rotate
make compose-ec2-pull EC2_ENV_FILE=.env.ec2.staging
make compose-ec2-up   EC2_ENV_FILE=.env.ec2.staging

# 4. Verify schema migration applied (V19 added user_skill_mastery)
docker compose -f docker-compose.ec2.yml exec postgres \
  psql -U postgres -d czech_go_system -c "\dt user_skill_mastery"

# 5. Health
curl -s https://apicz-staging.hadoo.eu/healthz
# {"status":"ok"}
```

## Smoke from local against staging

```bash
SMOKE_BASE_URL=https://apicz-staging.hadoo.eu make smoke-progress-flow
SMOKE_BASE_URL=https://apicz-staging.hadoo.eu \
  SMOKE_ATTEMPT_ARGS="--audio-file $PWD/example.m4a --mime-type audio/mp4 --duration-ms 30000 --timeout-sec 180" \
  make smoke-attempt-flow
SMOKE_BASE_URL=https://apicz-staging.hadoo.eu \
  SMOKE_PROGRESS_ARGS="--require-rows" make smoke-progress-flow
```

## Latency capture (gate 3)

Capture **before/after** snapshots so the V19 hook overhead is visible.

```bash
# Before V19: roll back to previous tag, run snapshot
SMOKE_BASE_URL=https://apicz-staging.hadoo.eu \
  MASTERY_LATENCY_ARGS="-n 30" make mastery-latency \
  | tee docs/validation/latency-pre-v19.json

# After V19 (current): re-run identical command, save tag
SMOKE_BASE_URL=https://apicz-staging.hadoo.eu \
  MASTERY_LATENCY_ARGS="-n 30 --baseline-p95 $(jq .p95_ms < docs/validation/latency-pre-v19.json)" \
  make mastery-latency \
  | tee docs/validation/latency-post-v19.json
```

Failure threshold: post-V19 p95 > pre-V19 p95 × 1.20.

## Notebook simulation (gate 4)

```bash
make mastery-sim                              # human-readable
make mastery-sim MASTERY_SIM_ARGS=--json      # CI-friendly
```

Failure threshold: any of the 20 sequences violates its invariant.

## Rollback

```bash
make compose-ec2-down EC2_ENV_FILE=.env.ec2.staging
docker compose -f docker-compose.ec2.yml --env-file .env.ec2.staging \
  up -d  # re-pulls previous image tag from EC2_ENV_FILE
```

`user_skill_mastery` table stays — `CREATE TABLE IF NOT EXISTS` makes
re-deploy idempotent. No data backfill on rollout per spec, so rollback
also leaves whatever rows accumulated; truncate only if explicit reset
is needed:

```sql
TRUNCATE user_skill_mastery;
```

## Post-deploy checklist

- [ ] `/healthz` 200
- [ ] `/v1/users/me/progress` returns shape with bands + weights for a
      logged-in learner
- [ ] Backend logs show "V19 skill_mastery aggregate wired"
- [ ] Backend logs show "dev fixture users ensured" (staging treats
      ENV != production; clean up before prod)
- [ ] No `mastery update failed: pq: ... violates foreign key` errors
- [ ] At least 1 mastery row appears after smoke-attempt-flow
- [ ] Latency post/pre p95 ratio ≤ 1.20
- [ ] Notebook simulator 20/20 sane

When all checked, hand off to teacher review template
(`docs/validation/v19-teacher-review-template.md`) and capture the
remaining gates in `tasks/skill-mastery-progress-todo.md § Phase 2`.
