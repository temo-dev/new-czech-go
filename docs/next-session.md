# Next Session

## Resume Prompt
Use this in a new chat:

`Tiếp tục dự án ở /Users/daniel.dev/Desktop/czech-go-system. Đọc AGENTS.md và docs/README.md trước, rồi tiếp tục từ slice gần nhất.`

Or the more specific version:

`Tiếp tục dự án ở /Users/daniel.dev/Desktop/czech-go-system. Đọc AGENTS.md và docs/next-session.md trước. V2 UI hoàn tất. Postgres DB trống (seedDefaults đã xóa) — cần nhập liệu qua CMS theo docs/admin-guide.md trước khi test Flutter end-to-end.`

## Current State
- `Flutter` can record real local audio.
- `Flutter` uploads the recorded binary through the same upload-target contract in both local and future cloud modes.
- Backend can issue either a same-host upload target or an opt-in presigned `S3` upload target when `ATTEMPT_UPLOAD_PROVIDER=s3`.
- Local mode stores uploaded audio in backend temp storage.
- `Attempt` now retains audio metadata.
- Backend now runs a dedicated dev attempt processor for `transcribing -> scoring -> completed/failed`.
- Backend now has a pluggable `Transcriber` layer with a default dev implementation.
- Backend can start an opt-in `Amazon Transcribe` path when `TRANSCRIBER_PROVIDER=amazon_transcribe`, `AWS_REGION`, and `ATTEMPT_AUDIO_S3_BUCKET` are configured.
- Backend now tracks the most recently issued attempt upload target and rejects `upload-complete` payloads whose `storage_key` does not match it.
- Backend can now persist attempts, audio metadata, transcripts, and feedback to `Postgres` when `DATABASE_URL` is set.
- Backend can now persist exercises to `Postgres` when `DATABASE_URL` is set.
- Seed demo exercises are auto-inserted into `Postgres` on first startup so learner and CMS flows still open cleanly.
- Attempt records now store `user_id`, `client_platform`, and `app_version`.
- Result UI shows uploaded audio metadata, transcript, and feedback.
- `CMS` and `Flutter` both use bundled local `Playfair Display`.
- `backend/` now has a production `Dockerfile`.
- `cms/` now has a production `Dockerfile` and a `/api/healthz` route.
- CMS admin list/create requests now go through server-side Next.js API routes instead of exposing the admin token in the browser bundle.
- CMS can now protect the admin desk with optional `HTTP Basic Auth` at the Next.js layer when `CMS_BASIC_AUTH_USER` and `CMS_BASIC_AUTH_PASSWORD` are configured.
- Root `docker-compose.yml` now brings up `backend + cms + postgres` for a local deploy-shaped stack.
- Root `.env.compose.example` documents the compose env shape for local Docker and the future ECS/RDS path.
- Root `docker-compose.ec2.yml` now targets the user's `nginx-proxy` style EC2 deployment with external `RDS`.
- Root `docker-compose.proxy.yml` now bootstraps a minimal `nginx-proxy + acme-companion` stack for a fresh EC2 host.
- Root `.env.ec2.example` and [deploy-ec2-nginx-proxy.md](/Users/daniel.dev/Desktop/czech-go-system/docs/deploy-ec2-nginx-proxy.md) document the host-based production path.
- Root `.env.ec2.example` now defaults to `ECR`-style image repos.
- Root `.env.ec2.example` is now generic and safe again instead of carrying real deployment values.
- `scripts/check-ec2-host.sh` now verifies Docker, Docker Compose, AWS CLI, and proxy readiness on the EC2 host.
- `scripts/check-aws-audio-pipeline.sh` now verifies AWS identity, S3 bucket reachability, and Amazon Transcribe API access from the active EC2 env file.
- `scripts/package-ec2-deploy.sh` now creates a tar.gz deploy bundle so EC2 does not need a git checkout.
- `scripts/ecr-login.sh` now logs Docker into `ECR` from the same env file used for deploys.
- `scripts/build-push-images.sh` now builds and pushes versioned backend/CMS images from one env file.
- `scripts/deploy-ec2.sh` now pulls and refreshes the EC2 app stack from `.env.ec2`.
- `scripts/smoke_test_attempt_flow.py` now provides an API-level production smoke test for `attempt -> upload -> result`.
- the smoke script now auto-detects local versus cloud upload mode, refuses dummy audio for cloud uploads, and stretches the timeout for real `Amazon Transcribe` runs.
- EC2 deploys now use immutable `IMAGE_TAG` values instead of depending on `latest`.
- EC2 deploys now explicitly target `linux/arm64` because the production host is ARM.
- A first real EC2 deploy is now up on `apicz.hadoo.eu` and `cmscz.hadoo.eu`.
- The production `backend` and `cms` containers are healthy.
- `RDS` connectivity from EC2 has been verified at both the TCP layer and the application layer.
- CMS exercise creation has already been confirmed in `RDS`.
- The `czech_user` role and `czech_go_system` database had to be created manually on `RDS` during the first deploy.
- The EC2 host has now passed the AWS audio-pipeline preflight against the real `czech-go-app` bucket and `Amazon Transcribe` API, using one bucket with distinct prefixes for audio and transcript output.
- A cloud-mode redeploy with `ATTEMPT_UPLOAD_PROVIDER=s3`, `TRANSCRIBER_PROVIDER=amazon_transcribe`, and image tag `20260422-002` has already been started on EC2.
- One real-audio cloud smoke attempt did reach `upload_mode=cloud`, but it failed before transcription completed.
- That failed smoke run exposed a MIME alias bug for `.m4a`: the running backend treated Linux-style `audio/mp4a-latm` uploads as unknown, produced `audio.bin` storage keys, and likely let `Amazon Transcribe` miss the media format hint.
- The repo now normalizes common `.m4a` and `.wav` MIME aliases in both the backend and the smoke script, so the next cloud smoke run should use a freshly released backend image.
- Backend processing now logs the concrete transcription error when an attempt ends with `failure_code=transcription_failed`, so the next EC2 smoke run should be debugged from `docker compose ... logs --tail=200 backend` immediately after the failed attempt.
- Real cloud smoke testing revealed one more integration edge case: forcing `sample_rate_hz=44100` in the client or smoke script can make `Amazon Transcribe` reject the file when the encoded sample rate differs. The repo now omits `sample_rate_hz` unless the caller truly knows it.
- The backend now also avoids forwarding client-reported `sample_rate_hz` into `Amazon Transcribe`, so guessed metadata should no longer break transcription jobs.
- The backend now also prefers reading completed transcript artifacts directly from the configured `S3` output bucket/prefix instead of relying on the HTTP `TranscriptFileUri`, because the live EC2 smoke run hit `403` on the HTTP transcript download.
- A real spoken Czech sample has now completed successfully end-to-end on production with `S3 + Amazon Transcribe`.
- An earlier cloud smoke run that mostly contained wind noise failed with `transcription_failed` because the transcript was unusable, which is now treated as an input-quality case instead of an infrastructure blocker.
- Backend now exposes a typed `Uloha 2` exercise detail contract with `scenario_title`, `scenario_prompt`, `required_info_slots`, and `custom_question_hint`.
- Backend now seeds one `Uloha 2` dialogue exercise so the learner shell can exercise the new task type without extra setup.
- CMS can now create both `Uloha 1` and `Uloha 2` exercises from the same task-specific dashboard.
- Flutter now parses and renders the `Uloha 2` scenario card, required info slots, and extra-question hint.
- Backend now exposes a typed `Uloha 3` exercise detail contract with `story_title`, `image_asset_ids`, `narrative_checkpoints`, and `grammar_focus`.
- The seeded `Uloha 3` exercise now carries story detail instead of only common exercise fields.
- CMS can now create `Uloha 3` exercises from the same task-specific dashboard.
- Flutter now parses and renders the `Uloha 3` story title plus narration checkpoints.
- Backend now exposes a typed `Uloha 4` exercise detail contract with `scenario_prompt`, `options`, and `expected_reasoning_axes`.
- The seeded `Uloha 4` exercise now carries choice detail for learner testing.
- CMS can now create `Uloha 4` exercises from the same task-specific dashboard.
- CMS can now edit and delete all four oral task types from the same task-specific dashboard.
- CMS can now upload and preview local prompt images for `Uloha 3` and `Uloha 4`, with asset metadata persisted on each exercise.
- `Uloha 4` authoring now supports optional `image_asset_id` values on each choice option.
- Flutter now parses and renders the `Uloha 4` choice prompt plus the option list.
- Flutter now also renders registered prompt images for `Uloha 3` and optional choice images for `Uloha 4`.
- Flutter can now replay the just-recorded local audio file from the exercise screen.
- Backend now exposes `GET /v1/attempts/:attempt_id/audio/file` so learners can replay the submitted audio of a completed attempt from backend storage.
- Flutter result UI now shows the backend transcript more explicitly and replays the completed-attempt audio through `GET /v1/attempts/:attempt_id/audio/url`.
- Backend now logs each HTTP request plus attempt-audio replay failures, so local debugging of playback issues is much faster.
- iOS remote-attempt playback now streams a short-lived signed URL with `just_audio`; the final audio URL is either a backend HMAC stream or an S3 presigned GET URL, so bearer tokens are not forwarded to cloud storage.
- `GET /v1/attempts` now returns only the authenticated learner's attempts in newest-first order.
- Learner shell now shows a `Lan tap gan day` section with recent readiness, feedback summary, and transcript preview cards.
- Backend feedback summaries and retry advice are now task-aware for `Uloha 1` and `Uloha 2`, so the learner sees guidance tied to topic coverage, supporting detail, question form, required slots, and extra questions.
- Transcript payloads now carry provenance metadata (`provider`, `is_synthetic`) so Flutter can clearly show when local dev is still using the synthetic transcript path.
- Backend now supports `REQUIRE_REAL_TRANSCRIPT=true` as a strict guard: if config would resolve back to the synthetic dev transcriber, startup fails instead of silently returning fake transcript data.
- Compose and EC2 env examples now include `REQUIRE_REAL_TRANSCRIPT`, and the env check script validates that strict real-transcript mode is only used with `amazon_transcribe + s3`.
- Local compose has now reached the real `S3` upload path with container-visible AWS credentials, so `upload-url` and `upload-complete` are no longer the blocker in strict real-transcript mode.
- The current local blocker is IAM on the active AWS identity: the latest local compose run failed at `transcribe:StartTranscriptionJob` with `AccessDeniedException` for the `veggie-team` user.
- In local `s3` mode, replay should use `GET /v1/attempts/:attempt_id/audio/url`; `/audio/file` remains a compatibility path and can still return `404` for cloud-only attempts with no backend `stored_file_path`.
- The next major feature after the current transcript-and-feedback flow has now been documented as `Attempt Repair And Shadowing`.
- The build-ready doc pack for that feature now exists in:
  - [docs/ideas/attempt-repair-and-shadowing.md](/Users/daniel.dev/Desktop/czech-go-system/docs/ideas/attempt-repair-and-shadowing.md)
  - [docs/specs/attempt-repair-and-shadowing.md](/Users/daniel.dev/Desktop/czech-go-system/docs/specs/attempt-repair-and-shadowing.md)
  - [docs/plans/attempt-repair-and-shadowing-plan.md](/Users/daniel.dev/Desktop/czech-go-system/docs/plans/attempt-repair-and-shadowing-plan.md)
- The agreed product direction for that feature is `dual output + task-aware repair + TTS shadowing`, starting with `Uloha 1` and `Uloha 2`.
- `Task 1: Define review artifact contracts` has now landed as a docs-plus-contract slice:
  - `backend/internal/contracts/types.go` now reserves review-artifact structs and a lightweight `review_artifact` summary on `Attempt`
  - `docs/specs/api-contracts.md` now documents the planned nested attempt summary plus the reserved `GET /v1/attempts/:attempt_id/review` contract
  - `docs/specs/content-and-attempt-model.md` now includes `AttemptReviewArtifact` as a planned derived entity
- `Task 2: Add backend persistence for review artifacts` has now landed as a store-layer slice:
  - memory attempt store can now create, update, and read one review artifact per attempt
  - Postgres attempt store now has an `attempt_review_artifacts` table plus join-backed attempt summaries
  - updating a review artifact does not overwrite the existing transcript or feedback on the attempt
- `Task 3: Build text-only repair generation for Uloha 1` has now landed as a backend-processing slice:
  - the processor now creates a `ready` review artifact for completed `Uloha 1` attempts
  - the first cut is intentionally text-only: `corrected_transcript_text` plus `model_answer_text`, no TTS yet
  - if review-artifact persistence fails, the main attempt still remains `completed`
  - the behavior is now covered by backend tests for strong `Uloha 1`, weak `Uloha 1`, and failure-safe persistence
- `Task 4: Add diff generation and speaking focus extraction for Uloha 1` has now landed:
  - `review artifacts` for completed `Uloha 1` attempts now include readable `diff_chunks`
  - the first cut of `speaking_focus_items` is practical and heuristic-based, without claiming deep pronunciation certainty
  - backend tests now cover replacement, insertion-like, and no-change diff cases, plus practical focus-item generation
- `Task 5: Add TTS generation for the model answer` has now landed as a backend-processing slice:
  - `backend/internal/processing/tts.go` now defines a pluggable `TTSProvider`
  - `TTS_PROVIDER=dev` writes a local debug WAV for the review-artifact model answer
  - `TTS_PROVIDER=amazon_polly` can synthesize the model answer through `Amazon Polly`
  - completed `Uloha 1` review artifacts now persist `tts_audio` metadata when TTS generation succeeds
  - TTS failure is non-blocking and does not erase the text review artifact or demote the main attempt from `completed`
- `Task 6: Add review artifact API` has now landed as a backend HTTP slice:
  - `GET /v1/attempts/:attempt_id/review` now returns a lightweight `pending` stub or the full persisted review artifact
  - `GET /v1/attempts/:attempt_id/review/audio/file` now serves local-backed review audio when `tts_audio` metadata exists
  - backend tests now cover `pending`, `ready`, `not_found`, `forbidden`, and review-audio playback/not-found cases
- `Task 7: Render the repair-and-shadowing block in Flutter` has now landed:
  - Flutter now parses `review_artifact` summaries on attempts and the full review artifact payload
  - the result card now shows a dedicated `Repair and shadowing` block for completed attempts
  - that block polls `/v1/attempts/:attempt_id/review` until the artifact is ready or failed
  - learners can now read corrected transcript text, model answer text, diff items, speaking-focus items, and play the model-answer audio from backend review storage
- Review artifact generation now covers all four oral task types:
  - `buildReviewArtifact` switch branches for `uloha_3_story_narration` and `uloha_4_choice_reasoning` (previously fell through to `not_applicable` and rendered the placeholder card)
  - `Uloha 3` rule-based fallback synthesizes a past-tense narrative from `Uloha3Detail.NarrativeCheckpoints` and surfaces checkpoint coverage / past tense / connective use as speaking-focus items
  - `Uloha 4` rule-based fallback uses `Vybírám {Option.Label}, protože {first reasoning axis}` and tracks choice clarity, `protože` clause, axis coverage
  - authored `Exercise.sample_answer_text` now overrides the rule-based model answer for any task type when present
- CMS exercise dashboard now exposes a `Status` select (draft / published / archived) on create and update, and `ExercisesByModule` filters strictly on `status = 'published'` so draft/archived exercises stay hidden from learners.
- Backend `seedDefaults` for the Postgres exercise store is now per-id idempotent, so newly added seed exercises (e.g. `exercise-uloha3-tv`, `exercise-uloha4-flat`) are inserted on next startup even when the table already has rows.
- Postgres exercise schema now adds `sample_answer_text TEXT NOT NULL DEFAULT ''`. `ensureSchema` runs an additive `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` so previously seeded local databases pick the column up automatically; migration `backend/db/migrations/004_exercise_sample_answer_text.sql` is the canonical record.
- Backend startup is now graceful when `LLM_PROVIDER=claude` but `ANTHROPIC_API_KEY` is missing: the API logs a warning and falls back to the rule-based feedback/review path instead of fatal-exiting.
- `docker-compose.yml` now mounts named volumes `backend_assets` (asset blobs) and `backend_attempts` (local attempt audio + TTS cache) so signed audio URLs and uploaded prompt assets survive container rebuilds. `AUDIO_SIGN_SECRET` is wired through both compose files plus `.env.compose.example`; if unset the backend falls back to an ephemeral per-process HMAC key.
- `TRANSCRIBE_TIMEOUT` default is now `3m` (was `2m`) in compose and `.env.compose.example` after a real run hit `transcription timeout: context deadline exceeded`.
- The next implementation slice should start from `Task 8: Add Retry with this model`.
- **Before next EC2 deploy**: set `AUDIO_SIGN_SECRET=$(openssl rand -hex 32)` in `.env.ec2` — backend will fatal-exit at startup if this is missing.
- **Mock exam V2** is now fully implemented:
  - `MockTest` entity: admin-defined templates with per-section `max_points`; CMS `/mock-tests` page for create/edit/publish
  - Learner flow: Home → pick test (list) → intro screen → record all 4 → bulk analyse → scored result (X/40, PASS/FAIL)
  - Scoring: `section_score = round(readiness_fraction × max_points)`, pronunciation bonus `= round(avg_fraction × 3)`, `passed = overall_score >= 24`
  - Result screen: tap any section → `MockExamSectionDetailScreen` shows full `ResultCard` (transcript + feedback + review artifact)
  - Record-all-then-analyse: `ExerciseScreen.onRecordingReady` callback; `MockExamScreen` bulk-uploads and polls after all sections recorded
  - DB migration `006_mock_tests.sql`; backend `ensureSchema` auto-creates tables on startup
  - `mock_test_list_screen` is empty until at least one `MockTest` is published in CMS
- One deploy-bundle bug was found: older bundles needed scripts to be called with `./.env.ec2`; the repo scripts are now patched for future bundles.
- CMS may show stale `Failed to find Server Action ...` errors after redeploy until the browser is hard-refreshed or opened in an incognito tab.
- CMS now expects server-side runtime envs `API_BASE_URL` and `CMS_ADMIN_TOKEN` instead of the old public build-time admin token.
- Production CMS deploys should also set `CMS_BASIC_AUTH_USER` and `CMS_BASIC_AUTH_PASSWORD` so the admin desk is not public-open.
- GitHub Actions now includes a minimal backend/CMS CI workflow and a tag-driven ARM64 image release workflow for `ECR`.
- Pre-ship security audit (2026-04-25) surfaced and fixed three blockers:
  - **Upload size limit**: `handleAttemptAudioUpload` and `handleAdminAssetBlobUpload` now wrap `r.Body` with `http.MaxBytesReader(100 MB)`; exceeding the limit returns `413 payload_too_large` instead of filling disk.
  - **`AUDIO_SIGN_SECRET` required**: backend now calls `log.Fatalf` at startup if `AUDIO_SIGN_SECRET` is unset; the ephemeral per-process fallback was removed from the production startup path. Generate with `openssl rand -hex 32` and add to `.env.ec2` before the next deploy.
  - **`SampleAnswerEnabled` can now be cleared**: `contracts.Exercise` gained `disable_sample_answer bool`; `mergeExerciseUpdate` now respects `DisableSampleAnswer = true` to turn the flag off after it has been enabled.
  - Duplicate `ALTER TABLE exercises ADD COLUMN IF NOT EXISTS sample_answer_text` removed from `ensureSchema`; `CREATE TABLE IF NOT EXISTS` already includes the column, and migration `004` is the canonical record.
- Acknowledged risks (not blocking V1 pilot but should be tracked):
  - CORS policy is `Access-Control-Allow-Origin: *` on all endpoints including authenticated ones; low operational risk for iOS-only V1 but should be locked to specific origins before any browser client is added.
  - No rate limiting on `POST /v1/auth/login`.
  - Admin token default `dev-admin-token` must be overridden in production (already documented in CMS constraints; add startup guard when hardening).
  - `X-Forwarded-Proto` trusted unconditionally in `buildAbsoluteURL`; safe behind ALB/nginx as used in EC2 deploy.
  - HTTP handler test coverage is thin outside audio URL signing; processor tests are thorough.

## Recommended Reading Order
1. [AGENTS.md](/Users/daniel.dev/Desktop/czech-go-system/AGENTS.md)
0. [docs/admin-guide.md](/Users/daniel.dev/Desktop/czech-go-system/docs/admin-guide.md) — nếu cần nhập nội dung
2. [docs/README.md](/Users/daniel.dev/Desktop/czech-go-system/docs/README.md)
3. [api-contracts.md](/Users/daniel.dev/Desktop/czech-go-system/docs/specs/api-contracts.md)
4. [attempt-repair-and-shadowing.md](/Users/daniel.dev/Desktop/czech-go-system/docs/ideas/attempt-repair-and-shadowing.md)
5. [attempt-repair-and-shadowing-plan.md](/Users/daniel.dev/Desktop/czech-go-system/docs/plans/attempt-repair-and-shadowing-plan.md)
6. [flutter-exercise-practice.md](/Users/daniel.dev/Desktop/czech-go-system/docs/screens/flutter-exercise-practice.md)

- **V2 Design System** applied (2026-04-27):
  - CMS `globals.css` rewritten: tokens `--bg #fbf3e7` (warm cream), `--brand #ff6a14` (Babbel orange), `--accent #0f3d3a` (teal), fonts Inter+Fraunces, radius vars, utility classes `.card/.badge/.btn/.stats-grid`
  - CMS `layout.tsx` + `CmsSidebar`: sidebar layout 248px teal fixed, thay thế top navbar cũ
  - Flutter `app_colors.dart`: full color rewrite — orange primary, teal secondary, warm cream surfaces
  - Flutter `app_theme.dart`: Inter font (thay Manrope), warm shadow tones
  - Flutter `app_radius.dart`: radius 10/14/18/24/32 theo design tokens
  - Flutter `result_card.dart`: 3 tabs (Phản hồi / Bản ghi / Bài mẫu) thay vertical scroll
  - Flutter `recording_card.dart`: `AppColors.rec` (#E2530A) cho recording dot/button/label
  - L10n `app_vi.arb` + `app_en.arb`: thêm 6 keys mới (resultTab*, resultNo*)

- **V2 deep analysis** completed (2026-04-27): gap analysis giữa design files và implementation, product spec viết tại `docs/specs/v2-ui-spec.md`
- **Flutter V1 polish** done: AnalysisScreen orbiting ring (V1.1), CourseList status badge (V1.3), ModuleDetail 2-col grid (V1.4), ExerciseList filter pills (V1.5)

- **V2 UI Upgrade hoàn tất** (2026-04-27): tất cả tasks V1–V5 done — xem `tasks/todo.md` để kiểm tra
- **i18n patch** (2026-04-27): Flutter 8 ARB keys thêm, xóa toàn bộ Czech/VI hardcoded strings trên learner surfaces; CMS strings chuẩn hoá sang VI qua `cms/lib/strings.ts`
- **CMS i18n VI/EN** (2026-04-27): `cms/lib/i18n.tsx` React context + localStorage; locale switcher 🇻🇳↔🇬🇧 trong sidebar footer; tất cả dashboards + nav labels reactive; in-app admin guide tại `/guide`
- **Postgres DB reset** (2026-04-27): toàn bộ data đã TRUNCATE, schema giữ nguyên
- **seedDefaults removed**: `postgres_exercises.go` không còn auto-seed exercises khi startup — DB bắt đầu trống, admin nhập liệu thủ công qua CMS
- **Worktrees disabled globally**: `~/.claude/settings.json` có `"deny": ["EnterWorktree"]` — Claude không tạo worktree nữa
- **Admin data entry guide**: xem `docs/admin-guide.md` — luồng nhập Course → Module → Skill → Exercise → MockTest

## Best Next Step

**DB trống — cần nhập nội dung trước khi test Flutter:**

1. Vào CMS tại `http://localhost:3000`
2. Tạo Course → Module → Skill theo `docs/admin-guide.md`
3. Tạo ít nhất 4 exercises (Úloha 1-4, pool=course, status=published)
4. Tạo 1 MockTest với 4 sections (pool=exam)
5. Test Flutter: Home → Course → Module → Skill → Exercise → Record → Result

Sau đó: **V3.2** MockTestListScreen rich cards, **V3.3** MockTestIntroScreen 3-stat grid.

Full roadmap: `tasks/todo.md`.

**Phase 2 (~5h):** Backend: CourseStore + ModuleStore (with course_id) + SkillStore + ExercisesBySkill + new learner/admin APIs.

**Phase 3 (~4h):** CMS dashboards for Course/Module/Skill. Exercise form: skill dropdown replaces module_id.

**Phase 4 (~5h):** Flutter: CourseListScreen → CourseDetailScreen → ModuleDetailScreen (skill cards) → ExerciseListScreen.

Other:
- Seed at least one `MockTest` (pool=exam) in CMS for end-to-end exam testing
- Polish `Uloha 3`/`Uloha 4` messaging + `sample_answer_text`

## Last Verified
- `cms lint` pass (2026-04-26)
- `cms build` pass (2026-04-26)
- `go build ./...` pass (2026-04-26) — GOTOOLCHAIN=go1.24.2
- `go test ./...` pass (2026-04-26) — 5 packages, all pass
- `flutter analyze` pass (2026-04-26)
- `flutter test` pass (2026-04-26) — 6 tests
- Mock exam V2 full flow verified: CMS create → Flutter list → intro → 4-section record-all-then-analyse → scored result → section detail tap

## Important Constraints
- Always prefix shell commands with `rtk`
- Use root [AGENTS.md](/Users/daniel.dev/Desktop/czech-go-system/AGENTS.md)
- Do not reintroduce remote font fetching
- Keep the current upload contract stable while improving internals
- For now, `Postgres` persistence is opt-in via `DATABASE_URL`; memory mode should keep working without extra setup
- The `Amazon Transcribe` code path is opt-in and still assumes learner audio is available in `S3`, not only on local temp storage
- The new `S3` upload target provider and upload-target validation were covered by backend tests, but not by a real AWS smoke run in this workspace
- The production database password used during first deploy should be rotated as soon as possible
