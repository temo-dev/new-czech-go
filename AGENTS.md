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
- `noi` (Speaking) — fully implemented: Úloha 1-4, AI scoring, review artifact, MockTest speaking flow
- `viet` (Writing) — V2: `psani_1_formular` + `psani_2_email`, LLM scoring, `WritingExerciseScreen`
- `nghe` (Listening) — V3: `poslech_1-5`, Polly TTS exercise audio, objective scoring, `ListeningExerciseScreen`
- `doc` (Reading) — V4: `cteni_1-5`, objective scoring (substring fill-in), `ReadingExerciseScreen`
- `tu_vung`, `ngu_phap` — data model defined, UI placeholder only

**Exercise types** come from Modelový test A2 (NPI ČR, platný od dubna 2026). See `docs/specs/content-and-attempt-model.md` for full list.

**Exercise pools:**
- `pool=course` — bài luyện trong Course → Skill
- `pool=exam` — bài thi trong MockTest → Section (không dùng chung với course)

Do not expand into:
- free-form AI tutoring
- live teacher marketplace
- advanced analytics platform
- pronunciation-first product positioning

## Source Of Truth
Read these first before making structural changes:
- `SPEC.md` — skills expansion spec (V2 Writing → V5 Full MockTest), all decisions frozen
- `tasks/plan.md` — implementation plan V2→V5 với design decisions per version
- `tasks/todo.md` — task checklist (W1-W4, L1-L4, R1-R4, M1-M4 all ✅)
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
- Flutter i18n (Vietnamese + English) via ARB + generated `AppLocalizations`, with in-app locale selector persisted via `SharedPreferences`; EN=VI=175 keys, zero hardcoded UI strings on learner surfaces (2026-04-27)
- CMS full i18n (VI/EN) via `cms/lib/i18n.tsx` React context + localStorage — locale switcher in sidebar footer; all exercise-dashboard, mock-test/module/skill dashboards, sidebar nav labels reactive; `cms/lib/strings.ts` superseded by `i18n.tsx` (2026-04-27)
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

- **V2 UI Design System** applied (2026-04-27): Babbel orange `#FF6A14` + warm cream `#FBF3E7` + teal `#0F3D3A`; Inter/Fraunces fonts; CMS sidebar layout; Flutter new screens (AnalysisScreen orbiting ring, ResultCard 3 tabs + criteria checklist, ModuleDetail 2-col grid, ExerciseList filter pills, MockList/Intro redesign); CMS new pages (courses 3-col grid, exercise 3-tab editor, learners dashboard, dashboard stats)
- **`criteria_results`** from `task_completion` now parsed in Flutter `AttemptFeedbackView` as `CriterionCheckView` list; displayed as met/unmet checklist in Feedback tab
- **Admin content guide**: `docs/admin-guide.md` — luồng nhập Course → Module → Skill → Exercise → MockTest

- **V2 Writing (psaní) — 2026-04-27:**
  - exercise types: `psani_1_formular` (3 câu hỏi ≥10 từ, 8đ), `psani_2_email` (email theo 5 ảnh ≥35 từ, 12đ)
  - Backend: `POST /v1/attempts/:id/submit-text`, `writing_scorer.go`, LLM feedback (highlight lỗi + corrected text)
  - CMS: forms riêng cho psani_1/2 với image upload
  - Flutter: `WritingExerciseScreen` với word-count gate, `_WritingResultPoller`

- **V3 Listening (poslech) — 2026-04-27:**
  - exercise types: `poslech_1-5` (5 dạng nghe khác nhau, tổng 25đ)
  - Backend: `POST /v1/attempts/:id/submit-answers` (sync scoring), `objective_scorer.go`, `exercise_audio.go`
  - API: `GET /v1/exercises/:id/audio`, `POST /v1/admin/exercises/:id/generate-audio` (Polly TTS)
  - DB: migration `010_exercise_audio.sql`
  - CMS: audio source radio (upload / text→Polly), options, correct_answers
  - Flutter: `ListeningExerciseScreen` với `AudioPlayerWidget` (just_audio + auth headers), `MultipleChoiceWidget`, `FillInWidget`, `ObjectiveResultCard`

- **V4 Reading (čtení) — 2026-04-27:**
  - exercise types: `cteni_1-5` (5 dạng đọc, tổng 25đ)
  - Backend: reuses `objective_scorer.go`; fill-in dùng substring match case-insensitive
  - Flutter: `ReadingExerciseScreen` với `SelectableText` reading passage, reuses widgets từ V3

- **V5 Full MockTest — 2026-04-27 (MVP):**
  - `MockTest.session_type`: `speaking` | `pisemna` | `full`
  - `FullExamSession`: tracks pisemna_score (≥42/70) + ustni_score (≥24/40), computes `overall_passed`
  - API: `POST /v1/full-exams`, `GET /v1/full-exams/:id`, `POST /v1/full-exams/:id/complete`
  - DB: migration `011_full_exam.sql`
  - CMS: `session_type` dropdown trong MockTest form; `DEFAULT_MAX_POINTS` cho tất cả exercise types
  - Flutter: `FullExamIntroScreen` (section list + submit), `FullExamResultScreen` (2-panel PASS/FAIL)

Important current limitations:
- local strict real-transcript mode still depends on valid AWS credentials plus `transcribe:*` IAM on the active local identity
- learner-surface feedback copy and `sample_answer_text` coverage for `Uloha 3` and `Uloha 4` lighter than `Uloha 1` / `Uloha 2`
- **Postgres DB hiện đang trống** — admin cần nhập nội dung qua CMS trước khi test Flutter end-to-end
- Listening exercise audio: `GET /v1/exercises/:id/audio` dùng in-memory store, không persist qua restart (cần Postgres backing)
- `full_exam_sessions` table chỉ in-memory, chưa có Postgres store (migration 011 tồn tại nhưng chưa wired)
- V5 ústní session không auto-link với písemná session sau khi speaking mock exam hoàn tất

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
V2 Writing ✅ V3 Listening ✅ V4 Reading ✅ V5 Full MockTest (MVP) ✅ — tất cả 16 tasks (W1-W4, L1-L4, R1-R4, M1-M4) hoàn thành.

Backlog ưu tiên cao (xem `tasks/todo.md`):

**V5 hardening:**
1. Postgres backing cho `full_exam_sessions` (migration 011 đã có, cần wired vào store)
2. Auto-link ústní session sau khi MockExamSession speaking hoàn tất

**Infrastructure:**
3. Postgres backing cho `exercise_audio` (migration 010 đã có)
4. Polly 2 voices cho `poslech_4` dialogs (hiện 1 voice Option B)

**Content:**
5. Nhập nội dung mẫu qua CMS: ít nhất 1 exercise mỗi loại để test end-to-end

Full plan: `tasks/plan.md` + `tasks/todo.md` + `SPEC.md`.

## Avoid
- adding generic plugin systems
- abstracting for multiple exam types
- building a queue-heavy platform before real load exists
- turning mock APIs into permanent hidden debt without updating the docs
- blurring `learner transcript`, `corrected transcript`, and `model answer`
- calling the next coaching slice a full pronunciation engine before the evidence supports that claim
