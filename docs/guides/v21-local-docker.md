# V21 — Local Docker Compose Guide

Bring the V21 CEFR level progression slice up locally and exercise the
gating + placement + promotion endpoints end-to-end against Postgres.

This is a **compose-first** guide. For the native (no-docker) workflow
see [dev-workflow.md](dev-workflow.md).

## Prereqs

- Docker Desktop (or Colima / Rancher Desktop) with `docker compose`
- `bash`, `curl`, `jq` for the smoke commands at the bottom
- ~1 GB free disk for the postgres volume + container images

## 1. Compose env file

Compose reads `./.env` automatically. Bootstrap from the template:

```bash
cp .env.compose.example .env
```

Then **fill in the V21-relevant values** — the rest can stay at the
defaults for a local run:

```bash
# Required everywhere (backend hard-fails without it).
AUDIO_SIGN_SECRET=$(openssl rand -hex 32)

# V21 — keep gating thresholds at defaults so the smoke flows
# match what level_flow_test.go asserts.
LEVEL_MASTERY_THRESHOLD_PCT=70.0
LEVEL_COVERAGE_THRESHOLD_PCT=80.0
LEVEL_PROMOTION_PASS_PCT=60.0
LEVEL_PROMOTION_COOLDOWN_HOURS=24
LEVEL_DEMO_EXERCISE_PER_LEVEL=1
LEVEL_PLACEMENT_ALLOW_B1=false   # V21 ships without B1 placement content

# Optional — needed only if you want LLM scoring / OCR / Polly TTS.
ANTHROPIC_API_KEY=
LLM_PROVIDER=dev                  # 'dev' = deterministic fake feedback
TTS_PROVIDER=dev
TRANSCRIBER_PROVIDER=dev
```

> The compose stack defaults `*_PROVIDER` to `dev`, so the backend
> spins up without Anthropic / AWS credentials. LLM feedback,
> transcription, and TTS use deterministic fakes — fine for V21
> gating verification.

## 2. Bring the stack up

```bash
make compose-up      # builds + starts postgres, backend, cms
make compose-logs    # tail backend + cms output
```

Stack:

| Service  | Port | Notes |
|----------|------|-------|
| postgres | 5432 | Named volume `postgres_data` survives `compose-down` |
| backend  | 8080 | Auto-runs migrations (incl. 025 + 026) on startup |
| cms      | 3000 | Wired to the backend container at `http://backend:8080` |

Verify:

```bash
# Backend root liveness.
curl -s http://localhost:8080/v1/me \
  -H "Authorization: Bearer dev-learner-token" | jq .

# CMS UI.
open http://localhost:3000
```

The dev-fixture tokens (`dev-admin-token`, `dev-learner-token`,
`dev-learner-2-token`) are seeded automatically when `ENV != production`.

## 3. Confirm V21 schema migrated

Run inside the postgres container:

```bash
docker compose exec postgres psql -U postgres -d czech_go_system \
  -c "\d users" \
  -c "\d courses" \
  -c "\d mock_tests" \
  -c "\d promotion_attempts"
```

You should see:

- `users.current_level / unlocked_levels / placement_taken_at`
- `courses.level / demo_exercise_id / courses_level_idx`
- `mock_tests.is_promotion / is_placement / target_level`
- `promotion_attempts` table with the descending composite index

If `promotion_attempts` is missing, the schema-helper sequencing has
slipped — re-run `compose-down -v && compose-up` to start with a
fresh volume.

## 4. Seed V21 content via CMS (the human path)

Open `http://localhost:3000` and log in with `dev-admin-token`
(no password — admin path uses the bearer token directly).

### A. A2 course + B1 course

1. **Khóa học → Khóa học mới**.
2. For the A2 course set **Cấp độ CEFR = A2 — Trvalý pobyt**, leave
   demo empty, status `Đã xuất bản`.
3. For the B1 course set **Cấp độ CEFR = B1 — Občanství**, paste any
   exercise id into **Demo exercise ID** so locked-card UI has a
   demo to point at.

### B. Placement mock test

1. **Mock tests → Mock test mới**.
2. Title `Placement V21`, status `Published`.
3. In the **CEFR gating (V21)** panel tick **Bài kiểm tra phân loại**.
   `target_level` stays disabled (placement carries no target).
4. Add at least one section (any published exercise will do).

### C. Promotion mock test (A2 → B1)

1. **Mock tests → Mock test mới**.
2. Title `Promotion to B1`, status `Published`.
3. In the gating panel tick **Đề thi nâng cấp**, then pick **Lên cấp =
   B1 — Občanství**.
4. Add sections — at minimum one per skill the gating service
   measures (`noi`, `viet`, `nghe`, `doc`, `tu_vung`, `ngu_phap`).

After saving, both mocks are live for the dev-learner.

## 5. Exercise the V21 endpoints (the curl path)

```bash
TOKEN=dev-learner-token
BASE=http://localhost:8080

# Fresh user → expect promotion_unlocked = false.
curl -s "$BASE/v1/users/me/level-progress" \
  -H "Authorization: Bearer $TOKEN" | jq .

# Start placement → returns {mock_test_id, full_session_id}.
curl -s -X POST "$BASE/v1/users/me/placement-test/start" \
  -H "Authorization: Bearer $TOKEN" | jq .

# Repeat without ?force=true → 409 placement_already_taken.
curl -s -X POST "$BASE/v1/users/me/placement-test/start" \
  -H "Authorization: Bearer $TOKEN" -w "\n%{http_code}\n"

# After completing the exam in the Flutter app (or by hitting
# /v1/mock-exams/:id/complete with seeded attempts), POST the
# session id back to /placement-test/complete to assign the level:
SESSION_ID=mock-session-1   # from placement-test/start
curl -s -X POST "$BASE/v1/users/me/placement-test/complete" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"full_session_id\":\"$SESSION_ID\"}" | jq .

# Try to create a promotion attempt before the gates pass → 400 promotion_locked.
MOCK_ID=mock-test-2   # promotion mock id from CMS
curl -s -X POST "$BASE/v1/promotion-attempts" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"mock_test_id\":\"$MOCK_ID\"}" | jq .
```

> The placement `/start` endpoint allocates a real mock_exam_session.
> To finish the placement test from the CLI you need to advance the
> session through every section attempt — easier to drive this from
> Flutter. The curl path above is enough to confirm the gating + 409
> + 400 surfaces work.

## 6. Run the V21 smoke directly

The Go integration test exercises the full flow against an in-process
server (no docker required, faster than the compose path):

```bash
make smoke-promotion-flow
# → cd backend && rtk go test -count=1 -run "TestV21LevelFlow_E2E" ./internal/httpapi/
# → 2 tests pass
```

Use this to verify the slice without spinning up the stack — it
seeds passing mastery, drives `HandlePromotionOutcome` directly, and
asserts both the pass and cooldown branches.

## 7. Flutter against the compose backend

In a separate terminal:

```bash
cd flutter_app
flutter run -d <device-id> \
  --dart-define=API_BASE_URL=http://localhost:8080
```

> iOS Simulator: keep `localhost`. Physical device on the same Wi-Fi:
> use the host machine's LAN IP. The iOS local-network entitlement
> in `ios/Runner/Info.plist` is preserved per AGENTS.md.

Open the app with `dev-learner-token` and you should see:

- `LevelBadge` (top-right) showing the current level + ladder dots.
- `LevelProgressRing` with the six skill arcs.
- `PromotionBanner` once the seeded mastery clears the gates.
- Locked B1 course tile with the padlock + delta progress + "Xem
  demo →" CTA.

## 8. Tear down

```bash
make compose-down                   # keeps the postgres_data volume
make compose-down -v                # also drops the volume (full reset)
```

`compose-down` without `-v` keeps every seeded course / mock / user,
so the next `compose-up` resumes the same state. Use `-v` to start
with a fresh database — useful when validating migration 026's
idempotent backfill against a clean schema.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `cms` waits forever on backend | Backend hit a fatal error (most often `AUDIO_SIGN_SECRET` empty). `make compose-logs` shows the cause. |
| `promotion_attempts` missing | Schema helper requires both `users` + `mock_tests` to exist first. Drop volume + re-up. |
| Placement / promotion endpoints return `404 feature_disabled` | `LevelDeps` not wired. The compose backend wires this automatically; if running `cmd/api` directly, check `main.go` initialises `LevelService` + stores. |
| `409 placement_already_taken` blocking iteration | Pass `?force=true` to `/v1/users/me/placement-test/start`, or clear `users.placement_taken_at` in psql for the dev-learner row. |
| `400 cooldown_active` mid-test | Either wait `LEVEL_PROMOTION_COOLDOWN_HOURS`, or `DELETE FROM promotion_attempts WHERE user_id='user-learner-1'` to reset. |
