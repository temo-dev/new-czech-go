# AGENTS.md

## Purpose
This repository is for `A2 Mluveni Sprint`, a narrow speaking-prep app for Vietnamese learners taking the Czech `trvaly pobyt A2` exam.

The current stack is:
- `Go` backend API
- `Next.js` CMS
- `Flutter` iOS learner app
- docs-first product and architecture specs in `docs/`

## Product Scope

**Content architecture (target):**
```
Course  (nhiều khóa: "Giao tiếp cơ bản", "Đi urad", "Ôn thi A2", ...)
  └── Module  (chủ đề trong khóa)
       └── Skill  (nói | nghe | đọc | viết | từ vựng | ngữ pháp)
            └── Exercise [pool=course]

MockTest (đề thi)
  └── MockTestSection → Exercise [pool=exam]
```

**Implemented skills:**
- `noi` (Speaking) — fully implemented: Úloha 1-4, AI scoring, review artifact
- `nghe`, `doc`, `viet`, `tu_vung`, `ngu_phap` — data model defined, UI placeholder only

**Exercise types** come from Modelový test A2 (NPI ČR, platný od dubna 2026). See `docs/specs/content-and-attempt-model.md` for full list.

**Exercise pools:**
- `pool=course` — bài luyện trong Course → Skill
- `pool=exam` — bài thi trong MockTest → Section (không dùng chung với course)

Do not expand into:
- free-form AI tutoring
- live teacher marketplace
- advanced analytics platform
- pronunciation-first product positioning
- listening/reading/writing UI before data model is stable

## Source Of Truth
Read these first before making structural changes:
- `docs/ideas/a2-mluveni-sprint.md`
- `docs/plans/v1-implementation-plan.md`
- `docs/specs/content-and-attempt-model.md`
- `docs/specs/api-contracts.md`
- `docs/specs/attempt-state-machine.md`
- `docs/specs/infrastructure-baseline.md`
- `docs/specs/scoring-pipeline.md`

When working on the next major learner-coaching slice, also read:
- `docs/ideas/attempt-repair-and-shadowing.md`
- `docs/specs/attempt-repair-and-shadowing.md`
- `docs/plans/attempt-repair-and-shadowing-plan.md`

When working on the i18n slice, also read:
- `docs/ideas/i18n-multi-language-support.md`
- `docs/specs/i18n-spec.md`
- `docs/plans/i18n-implementation-plan.md`

`code-review-graph` is available for this repo and should be used when documenting flows, reviewing structural changes, or checking file/entity relationships.

If code and docs disagree, prefer updating code to match the documented V1 contract unless the human explicitly changes scope.

## Repo Layout
- `backend/` Go API and processing service
- `cms/` Next.js content management app
- `flutter_app/` Flutter learner app
- `docs/` product, planning, and technical specs

## Current Implementation Status
The repo is now beyond the first mock-only slice.

The implemented V1 foundation currently includes:
- Go backend with real attempt upload flow, learner polling, transcript provenance, and task-aware feedback for all four oral task types
- opt-in `Postgres` persistence for exercises, attempts, transcripts, and feedback
- opt-in `S3 + Amazon Transcribe` path that has already been verified end-to-end on production
- opt-in `LLMFeedbackProvider` backed by Claude (`LLM_PROVIDER=claude`, `ANTHROPIC_API_KEY`); falls back to rule-based feedback automatically on error or when unset
- opt-in `LLMReviewProvider` that generates corrected transcript + model answer per exercise + learner response (`LLM_REVIEW_PROVIDER`, falls back to `LLM_PROVIDER` then to rule-based). Missing `ANTHROPIC_API_KEY` while `LLM_PROVIDER=claude` is no longer fatal: backend logs a warning and continues on the rule-based path.
- task-aware review artifacts (corrected transcript + model answer + diff + speaking focus + Polly TTS) for all four oral task types; authored `Exercise.sample_answer_text` overrides the rule-based model answer when present
- opt-in `Amazon Polly` TTS for model-answer audio in review artifacts (`TTS_PROVIDER=amazon_polly`)
- CMS CRUD for all four oral task types, with a `Status` select (draft / published / archived); only `published` exercises surface to learners
- CMS prompt-asset upload and preview for `Uloha 3` and `Uloha 4`
- Compose persistence: named volumes `backend_assets` + `backend_attempts` keep prompt assets and local-mode attempt audio across container rebuilds; `AUDIO_SIGN_SECRET` is wired through both compose files for stable signed audio URLs across restarts; `TRANSCRIBE_TIMEOUT` defaults to `3m`
- Flutter learner flow for all four oral tasks: recording with split Stop/Analyze, dedicated `AnalysisScreen` spinner, result rendering, recent attempts, audio replay, review artifact display with TTS audio playback
- Flutter i18n (Vietnamese + English) via ARB + generated `AppLocalizations`, with in-app locale selector persisted via `SharedPreferences`
- Flutter bottom navigation with separate `Home` and `History` tabs
- Provider-aware audio streaming: `GET /v1/attempts/:id/audio/url` + `.../review/audio/url` return short-lived signed URLs (S3 presigned for cloud, HMAC-signed backend stream for local). Flutter `just_audio` streams directly via `setUrl` instead of downloading.
- **Mock exam V2** — full real-exam format (Modelový test A2, platný od dubna 2026):
  - `MockTest` entity: admin-defined exam templates with title, description, duration, and per-section `max_points`
  - CMS `/mock-tests` page: create/edit/publish mock tests; pick specific exercises per section
  - Learner flow: Home → pick test (list) → intro screen (title, duration, 40 pts total, pass ≥ 24) → record all 4 sections → bulk analyse → scored result
  - Scoring: section scores based on AI readiness level × max_points (Úloha 1=8, 2=12, 3=10, 4=7) + pronunciation bonus (avg readiness × 3); overall_score 0–40, passed = score ≥ 24
  - Result screen: score display (X/40), PASS/FAIL badge, per-section breakdown; tap any section → full `ResultCard` with transcript + feedback + review artifact
  - Backend: `GET /v1/mock-tests` (learner list), `POST/PATCH/DELETE /v1/admin/mock-tests` (admin CRUD); `POST /v1/mock-exams` accepts optional `mock_test_id`; `completeMockExam` computes and stores per-section and overall scores
  - DB: `mock_tests`, `mock_test_sections` tables; `mock_exam_sessions` extended with `mock_test_id`, `overall_score`, `passed`; `mock_exam_sections` extended with `max_points`, `section_score`
  - Record-all-then-analyse flow: `ExerciseScreen.onRecordingReady` callback lets mock exam collect recordings before any upload; `MockExamScreen` bulk-uploads and polls all attempts after all sections recorded

Important current limitations:
- local strict real-transcript mode still depends on valid AWS credentials plus `transcribe:*` IAM on the active local identity
- learner-surface feedback copy and authored `sample_answer_text` coverage for `Uloha 3` and `Uloha 4` are still lighter than `Uloha 1` / `Uloha 2`, even though the review artifact pipeline now covers all four task types
- mock test list is empty until at least one `MockTest` is created and published in the CMS

## Working Rules
- Build in thin vertical slices.
- Keep the repo working after every increment.
- Prefer simple, obvious code over reusable-looking abstractions.
- Treat docs as part of the product, not optional garnish.
- When in doubt, make the learner flow clearer before making the infrastructure fancier.
- Before starting a new major slice, make sure the matching idea/spec/plan docs exist and are current.

## Commands
Use the root `Makefile` when possible:
- `make install`
- `make backend-run`
- `make backend-build`
- `make backend-test`
- `make cms-build`
- `make cms-lint`
- `make flutter-analyze`
- `make flutter-test`
- `make flutter-devices`
- `make dev-backend`
- `make dev-cms`
- `make dev-ios`
- `make dev-check`
- `make dev-stop-backend`
- `make dev-stop-cms`
- `make dev-stop`
- `make compose-up`
- `make compose-down`
- `make compose-logs`
- `make smoke-attempt-flow`
- `make verify`

For daily local startup, prefer [docs/dev-workflow.md](/Users/daniel.dev/Desktop/czech-go-system/docs/dev-workflow.md).

Per the local repo rule in `RTK.md`, shell commands should be prefixed with `rtk`. The `Makefile` already does this.

## Backend Conventions
- Keep the backend monolithic in V1.
- Prefer standard library packages before adding dependencies.
- Keep request and response payloads aligned with `docs/specs/api-contracts.md`.
- Keep learner-facing feedback aligned with `docs/specs/content-and-attempt-model.md`.
- Retry should create a new attempt, not mutate a failed one.

## CMS Conventions
- The CMS is a thin content desk, not a second product.
- Prefer explicit task-specific forms over generic schema builders.
- Prioritize content CRUD and preview over workflow automation.

## Flutter Conventions
- Optimize for the learner flow first.
- Keep UI copy practical and exam-oriented.
- Do not block app progress on perfect audio or pronunciation infrastructure.
- If using local dev API calls on iOS, preserve the local-network allowance in `ios/Runner/Info.plist`.

## Infrastructure Conventions
- Stay within the V1 baseline in `docs/specs/infrastructure-baseline.md`.
- Do not introduce `SQS`, `EventBridge`, microservices, or Kubernetes unless the human explicitly changes scope.
- Prefer a long-running Go service over serverless complexity for V1.

## Verification Expectations
Before closing a meaningful code change, run the relevant checks:
- backend: `make backend-build` and `make backend-test`
- CMS: `make cms-lint` and `make cms-build`
- Flutter: `make flutter-analyze` and `make flutter-test`
- full slice: `make verify`

If a command cannot run because of sandbox or SDK cache restrictions, say so clearly and report what was verified instead.

## Scope Discipline
Do not mix these in one change unless the human asks:
- feature work
- refactoring
- infra expansion
- visual redesign
- docs rewrites outside the touched slice

If you notice adjacent cleanup, note it separately instead of silently expanding scope.

## Good Next Steps
Content architecture V2 (Phases 1-4) done ✅. Design system V0 done ✅. Flutter V1.1/V1.3/V1.4/V1.5 done ✅.

Preferred sequence from current state (see `tasks/todo.md` for full checklist):

**TIER 1 — Unblocked, highest impact:**
1. **V4.1** Backend verify `criteria_results` JSON output — `backend/internal/contracts/types.go`, `backend/internal/httpapi/server.go`
2. **V4.2** Flutter `CriterionCheckView` model + parse — `flutter_app/lib/models/models.dart`
3. **V1.2** ResultCard 4-col criteria grid — `flutter_app/lib/features/exercise/widgets/result_card.dart`
4. **V3.2** MockTestListScreen rich cards — `flutter_app/lib/features/mock_exam/screens/mock_test_list_screen.dart`
5. **V3.3** MockTestIntroScreen 3-stat grid — `flutter_app/lib/features/mock_exam/screens/mock_test_intro_screen.dart`

**TIER 2 — CMS pages:**
6. **V2.2** Exercise editor 5-tab + Rubric scoring grid
7. **V2.1** Courses page 3-col card grid
8. **V3.1** Dashboard stats header

**TIER 3 — New pages:**
9. **V2.3** Learners page (new)
10. **C4** Mock Tests builder

Full spec: `docs/specs/v2-ui-spec.md`. Full plan: `tasks/plan.md` + `tasks/todo.md`.

## Avoid
- adding generic plugin systems
- abstracting for multiple exam types
- building a queue-heavy platform before real load exists
- turning mock APIs into permanent hidden debt without updating the docs
- blurring `learner transcript`, `corrected transcript`, and `model answer`
- calling the next coaching slice a full pronunciation engine before the evidence supports that claim
