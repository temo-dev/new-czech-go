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
       └── Exercise [pool=course, module_id + skill_kind = canonical link]

MockTest (đề thi)
  └── MockTestSection → Exercise [pool=exam]
```

**DB linkage (V8 — migration 017):** `exercises.module_id` + `exercises.skill_kind` là liên kết trực tiếp lên Module. Bảng `skills` đã bị xóa. `skill_kind` được lưu trực tiếp trên exercise vì `matching`/`fill_blank`/`choice_word` dùng chung cho cả `tu_vung` lẫn `ngu_phap`.

**API derived:** `GET /v1/modules/:id/skills` trả danh sách `SkillSummary` (skill_kind + exercise_count) computed từ exercises, không có bảng skills.

**Implemented skills:**
- `noi` (Speaking) — fully implemented: Úloha 1-4, AI scoring, review artifact, MockTest speaking flow
- `viet` (Writing) — V2: `psani_1_formular` + `psani_2_email`, LLM scoring, `WritingExerciseScreen`, Polly TTS for model_answer_text
- `nghe` (Listening) — V3: `poslech_1-5`, Polly TTS exercise audio (2 voices for poslech_4 dialogs), objective scoring, `ListeningExerciseScreen`; **V13**: `poslech_6` Ano/Ne (TTS passage + 1–5 true/false statements)
- `doc` (Reading) — V4: `cteni_1-5`, objective scoring (substring fill-in), `ReadingExerciseScreen`; **V13**: `cteni_6` Ano/Ne (passage card + 1–5 true/false statements)
- `tu_vung` — V6: fully implemented. CMS `/vocabulary` với VocabularySet CRUD + AI generation (Claude tool_use async job) + inline review/publish. Flutter: `VocabGrammarExerciseScreen` với `QuizcardWidget`, `MatchingWidget`, filter pills.
- `ngu_phap` — V6: fully implemented. CMS `/grammar` với GrammarRule CRUD (conjugation table, constraints) + same AI flow. Exercises: matching + fill_blank + choice_word.

**Exercise types** come from Modelový test A2 (NPI ČR, platný od dubna 2026). See `docs/specs/content-and-attempt-model.md` for full list.

**Exercise pools:**
- `pool=course` — bài luyện trong Course → Module (module_id bắt buộc)
- `pool=exam` — bài thi trong MockTest → Section (module_id = '', không thuộc module)

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
- opt-in `ContentGenerator` backed by Claude for V6 vocab/grammar exercise generation (async job, admin-triggered). Model and prompts are centralized in `processing/llm_config.go` and `processing/llm_prompts.go`.
- task-aware review artifacts (corrected transcript + model answer + diff + speaking focus + Polly TTS) for all four oral task types; authored `Exercise.sample_answer_text` overrides the rule-based model answer when present
- opt-in `Amazon Polly` TTS for model-answer audio in review artifacts (`TTS_PROVIDER=amazon_polly`)
- CMS CRUD for all four oral task types, with a `Status` select (draft / published / archived); only `published` exercises surface to learners
- CMS prompt-asset upload and preview for `Uloha 3` and `Uloha 4`
- Compose persistence: named volumes `backend_assets` + `backend_attempts` keep prompt assets and local-mode attempt audio across container rebuilds; `AUDIO_SIGN_SECRET` is wired through both compose files for stable signed audio URLs across restarts; `TRANSCRIBE_TIMEOUT` defaults to `3m`; `LOCAL_ASSETS_DIR` set to volume path in both compose files so Polly-generated exercise audio survives restarts
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

- **V2 Writing (psaní) — 2026-04-27, bug fixes 2026-04-29:**
  - exercise types: `psani_1_formular` (3 câu hỏi ≥10 từ, 8đ), `psani_2_email` (email theo 5 ảnh ≥35 từ, 12đ)
  - Backend: `POST /v1/attempts/:id/submit-text`, `writing_scorer.go`, LLM feedback (highlight lỗi + corrected text)
  - CMS: forms riêng cho psani_1/2 với image upload; `WritingFields.tsx` hint dùng template literal
  - Flutter: `WritingExerciseScreen` với word-count gate, `_WritingResultPoller`
  - **Bug fixes (2026-04-29):**
    - `ExerciseDetail.fromJson` crash khi mở psani_1: `poslechQuestions` + `cteniQuestions` dùng `.whereType<Map<String,dynamic>>()` — `detail['questions']` là `[]string` với psani_1 nhưng `[]Map` với poslech/cteni
    - `writingMinWords` default fix: psani_1 = 10, psani_2 = 35 (trước đó cả hai fallback về 10)
    - `_WritingResultPoller` timeout 2 phút (60 retries × 2s) + i18n key `scoringTimeout`; trước đó poll vô hạn nếu backend stuck
    - `WritingExerciseScreen` dùng `LocaleScope.of(context).code` thay `'vi'` hardcode để đồng nhất với speaking
    - `ProcessWritingAttempt` goroutine: thêm `defer recover()` để FailAttempt nếu panic; bỏ duplicate `ValidateWritingSubmission` call trong goroutine
    - `handleSubmitText`: thêm `http.MaxBytesReader(64KB)` + max 500 words trong `ValidateWritingSubmission` ngăn OOM và LLM credit abuse
    - **Diff highlight trong repair tab**: `_DiffTextBlock` widget dùng `RichText`/`TextSpan` — `deleted`+`replaced` → đỏ, `inserted`+`replaced` → xanh, `unchanged` → plain; fallback về plain text khi `diff_chunks` rỗng
    - **Czech character encoding fix (2026-05-03)**: `api_client.dart` `_request()` đổi từ `utf8.encode` + `request.add(bytes)` sang `request.write(jsonEncode(body))` — Dart `_IOSinkImpl` init với `latin1` encoding; `write()` đọc `charset=utf-8` từ Content-Type header và dùng UTF-8 thay vì latin1, tránh `ArgumentError` khi submit Czech text có ký tự > U+00FF (č, ž, ě, ř, …)

- **V3 Listening (poslech) — 2026-04-27, bug fix 2026-04-29:**
  - exercise types: `poslech_1-5` (5 dạng nghe khác nhau, tổng 25đ)
  - Backend: `POST /v1/attempts/:id/submit-answers` (sync scoring), `objective_scorer.go`, `exercise_audio.go`
  - API: `GET /v1/exercises/:id/audio`, `POST /v1/admin/exercises/:id/generate-audio` (Polly TTS)
  - DB: migration `010_exercise_audio.sql`
  - CMS: audio source radio (upload / text→Polly), options, correct_answers
  - Flutter: `ListeningExerciseScreen` với `AudioPlayerWidget` (just_audio + auth headers), `MultipleChoiceWidget`, `FillInWidget`, `ObjectiveResultCard`
  - **Bug fix (2026-04-29):** `poslechQuestions` parser trong `ExerciseDetail.fromJson` dùng `.whereType<Map>()` — cùng fix với psani_1 ở trên (shared `detail['questions']` key, khác kiểu item)

- **V4 Reading (čtení) — 2026-04-27:**
  - exercise types: `cteni_1-5` (5 dạng đọc, tổng 25đ)
  - Backend: reuses `objective_scorer.go`; fill-in dùng substring match case-insensitive
  - Flutter: `ReadingExerciseScreen` với `SelectableText` reading passage, reuses widgets từ V3

- **V5 Full MockTest — 2026-04-27 (MVP):**
  - `MockTest.session_type`: `speaking` | `pisemna` | `full`
  - `FullExamSession`: tracks pisemna_score (≥42/70) + ustni_score (≥24/40), computes `overall_passed`
  - API: `POST /v1/full-exams`, `GET /v1/full-exams/:id`, `POST /v1/full-exams/:id/complete`
  - DB: migration `011_full_exam.sql` — **now Postgres-persisted** via `FullExamStore` interface
  - CMS: `session_type` dropdown trong MockTest form; `DEFAULT_MAX_POINTS` cho tất cả exercise types
  - Flutter: `FullExamIntroScreen` (section list + submit), `FullExamResultScreen` (2-panel PASS/FAIL)
  - **Auto-link**: `handleMockExamComplete` tự động link speaking session vào open `FullExamSession` của cùng learner (`FindOpenFullExamForAutoLink`)

- **V6 LLM-Assisted Vocab & Grammar — 2026-04-28:**
  - Async LLM job (Claude tool_use) → Admin review/edit → Publish atomic
  - Postgres backing: `vocabulary_sets`, `vocabulary_items`, `grammar_rules`, `content_generation_jobs` tables
  - CMS `/vocabulary`: VocabularySet list + edit/delete + Generate → inline editors → Lưu nháp / Draft resume / Publish
  - CMS `/grammar`: GrammarRule (conjugation table + constraints) + same flow, full parity với vocabulary
  - Flutter: `VocabGrammarExerciseScreen` + `QuizcardWidget` (flip) + `MatchingWidget` + filter pills
  - Rate limit: 1 active generation job per admin per module

- **Admin login (CMS auth) — 2026-04-28:**
  - CMS `/login` page với email/password form. Cookie `admin_token` (HTTP-only, 24h) thay cho Basic Auth.
  - Backend: `ADMIN_EMAIL`/`ADMIN_PASSWORD` env vars; `crypto/rand` token; 24h TTL
  - Middleware: redirect `/login` nếu không có cookie; `dev-admin-token` hợp lệ chỉ khi `ENV != production`
  - `lib/auth.ts` `getAdminToken(request)` threads cookie qua 21 admin proxy routes

- **Exercise form upgrade — 2026-04-28:**
  - Slide-over panel (80vw, full height) thay cramped modal; `localStorage` autosave 10s; dismiss confirm
  - Structured inputs per exercise type: `ItemRepeater`, `OptionRow`, `AnswerSelect` shared components
  - `PoslechFields`/`CteniFields` (Option C pattern — own typed state + `onChange(payload)`); `SpeakingFields`/`WritingFields`
  - Inline validation: `validateExercise()` per type; submit disabled khi invalid

- **Infrastructure hardening — 2026-04-29:**
  - `ExerciseAudioStore` interface + `postgresExerciseAudioStore`: exercise audio metadata persists qua restart; `LOCAL_ASSETS_DIR` must point to a named volume for the MP3 file to also persist (fixed 2026-05-01)
  - `FullExamStore` interface + `postgresFullExamStore`: full exam sessions persist
  - Polly 2 voices for poslech_4: `DialogExerciseAudioGenerator` + `GenerateDialogAudio()` alternating voices + MP3 concat
  - Polly TTS for writing `model_answer_text`: `ProcessWritingAttempt` generates TTS audio (same pattern as speaking)
  - `POLLY_VOICE_ID_2` env var for second Czech voice (default: Tomáš)

- **CMS analytics & UX — 2026-04-29:**
  - Analytics tab trong learners dashboard: pass rate per exercise_type (table + color bar)
  - Flutter history: skill_kind filter pills trên `HistoryScreen` (Nói/Viết/Nghe/Đọc/Từ vựng/Ngữ pháp)
  - CMS guide page updated: login, slide-over panel, vocab edit/delete/draft, analytics

- **Security hardening — 2026-04-29:**
  - Dev tokens (`dev-admin-token`, `dev-learner-token`, `dev-learner-2-token`) chỉ seed khi `ENV != production`; `ENV=production` bắt buộc set trước khi deploy
  - `ADMIN_PASSWORD` startup guard: fatal exit nếu empty hoặc `"demo123"` trong production
  - Admin password hỗ trợ bcrypt (`$2a$`/`$2b$` prefix) via `golang.org/x/crypto/bcrypt`; dev vẫn dùng plaintext
  - `handleSubmitText`: `http.MaxBytesReader(64KB)` ngăn OOM payload; max 500 từ trong `ValidateWritingSubmission`
  - CORS: `withCORS` đọc `CORS_ALLOWED_ORIGINS` env var (comma-separated); production không có var → no ACAO header; dev không có var → wildcard `*`
  - Audio upload ownership: `handleRecordingStarted`, `handleUploadURL`, `handleAttemptAudioUpload`, `handleUploadComplete` thêm `user` param + `authorizedAttemptForUser` check — ngăn learner A ghi đè audio learner B
  - CMS `admin_token` cookie: thêm `secure: true` khi `NODE_ENV=production`
  - `CORS_ALLOWED_ORIGINS` cần set trong `.env.ec2` production (vd: `https://cmscz.hadoo.eu`)

Important current limitations:
- local strict real-transcript mode still depends on valid AWS credentials plus `transcribe:*` IAM on the active local identity
- learner-surface feedback copy and `sample_answer_text` coverage for `Uloha 3` và `Uloha 4` lighter than `Uloha 1` / `Uloha 2`
- Exercise form file split ✅ hoàn thành trong V9 CMS Dashboard Upgrade
- `_DiffTextBlock` chỉ highlight khi LLM trả về `diff_chunks` khác nhau; nếu learner text và corrected giống nhau hoàn toàn → all `unchanged` → không có highlight (đúng behavior)
- `poslech_6` passage text sent to Polly as-is; admin phải nhập prose (không dùng bảng cột) — Polly TTS không xử lý tốt markdown/ASCII tables
- `matchObjectiveAnswer` dùng exact-match cho ANO/NE keys (via `isAnoNeKey()`); fill-in vẫn dùng bidirectional substring match như trước

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
- `make smoke-course-flow`
- `make smoke-exam-flow`
- `make smoke-all`
- `make verify`

For daily local startup, prefer [docs/dev-workflow.md](/Users/daniel.dev/Desktop/czech-go-system/docs/dev-workflow.md).

For smoke test usage, troubleshooting, and API notes: [docs/smoke-test-guide.md](/Users/daniel.dev/Desktop/czech-go-system/docs/smoke-test-guide.md).

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
- CMS: `make cms-lint` and `make cms-build` and `cd cms && npm test`
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
V2 ✅ V3 ✅ V4 ✅ V5 ✅ V6 ✅ V7 ✅ V8 ✅ V9 ✅ V10 ✅ V11 ✅ V12 ✅ V13 ✅ V14 ✅ V15 ✅ V16 ✅ — tất cả planned slices hoàn thành.
Xem `tasks/todo.md` để theo dõi backlog chi tiết.

**V16 Interview First-Turn Fix + Push-to-Talk + UX Polish — 2026-05-04:**
- **Audio gate fix**: gate routing chunks Simli theo `onVideoReady` (first frame) thay `isConnected` (WS START); buffer pending chunks, flush khi ready, fallback timer (`audio_buffer_timeout_ms`, default 1500ms, range 500–5000) → `PcmAudioPlayer` local
- **Display prompt** derive server-side từ `system_prompt` (strip "You are…", extract ÚKOL/TASK block, drop `{selected_option}` placeholder); contract trên `InterviewConversationDetail` + `InterviewChoiceExplainDetail` thêm 2 field optional `display_prompt` + `audio_buffer_timeout_ms`; helper `processing.DerivePromptForLearner` + `processing.EnrichInterviewDetail`
- **Admin preview endpoint**: `POST /v1/admin/interview/preview-prompt` (rate limit 30/phút/admin); CMS `PromptPreview` component debounce 400ms render real-time
- **Prompt card**: `InterviewPromptCard` widget bottom panel, expanded mặc định 8s → mini pill, pulse 1.5s khi `agent_response_complete` (skip lần đầu); choice variant hiện `selectedOption.id — label`
- **Preparing overlay**: 4 step checklist (Khởi tạo → Avatar → Examiner → Sẵn sàng) thay black screen, fade-out khi step 4
- **iOS AEC**: `AVAudioSessionMode.videoChat` (echo cancel + noise suppress) thay `spokenAudio` — eliminates loa-vọng-mic gây empty learner turn
- **Push-to-talk mic**: tap toggle thay always-on VAD; `_PttMicButton` widget (idle gray / orange enabled / red pulse + send icon recording); state authoritative từ Simli SPEAK/SILENT WS messages — mic disable khi avatar còn phát audio; 8s `_agentWaitTimer` sau user turn; 550ms preroll buffer + 1600 byte minimum trước khi flush sang ElevenLabs; `canStartInterviewMic` + `shouldReleaseInterviewMicPreroll` pure helpers cho test
- **Empty turn filter**: `_isMeaningfulTranscript` regex `\p{L}|\p{N}` Unicode-aware drop "..." / whitespace turn rỗng từ ElevenLabs VAD false positive
- **Defensive state**: `_startConversation` flip `_state` speaking→ready để mic enable kể cả safety timer fire không qua `agent_response_complete`; metadata + 3s no audio fallback enable mic cho learner nói trước (firstMessage rejected scenario)
- **Result screen**: sticky CTA "Hoàn thành" / "Finish" → `Navigator.popUntil(home)`
- **Layout unified**: bottom panel single Column (transcript bubble L/R-aligned + prompt card + timer + mic + hint + end link) — không còn Positioned magic offsets chồng chéo; avatar full-bleed cap 78%/640px Cover fit
- **Audio diagnostics**: per-turn counter log `Interview turn=N audio chunks: simli=X local=Y buffered=Z useSimliAudio=A videoReady=B`; `PcmAudioPlayer.flushAndPlay` log sample rate + bytes + duration
- I18n VI+EN: 6 keys mới (`interviewPromptLabel`, `interviewTapToView`, `interviewVocabHints`, `interviewPttIdleHint`, `interviewPttSendHint`, `interviewFinishBtn`)
- **ElevenLabs agent settings required**: bật "Allow client override system_prompt", "first_message", "TTS voice" trong Security; nếu thiếu first_message override → 3s fallback enable mic
- Specs: `docs/specs/interview-first-turn-fix.md`, idea: `docs/ideas/interview-first-turn-fix.md`, plan: `docs/plans/interview-first-turn-fix-plan.md`, design: `docs/designs/interview-first-turn-fix.html`
- Tests: 297 backend (Go), 137 Flutter, 92 CMS Vitest

**V8 Schema Flatten — 2026-04-30:**
- Bảng `skills` đã xóa (migration 017–019)
- `exercises.module_id` + `exercises.skill_kind` thay cho `exercises.skill_id → skills`
- `vocabulary_sets.module_id`, `grammar_rules.module_id` thay cho `skill_id`
- `GET /v1/modules/:id/skills` trả `SkillSummary[]` computed từ exercises
- `GET /v1/modules/:id/exercises?skill_kind=X` filter server-side
- CMS: bỏ `/skills` page, exercise form chọn module trực tiếp
- Flutter: `SkillSummary` thay `Skill`, `ExerciseSummary.skillKind` từ API
- Specs: `docs/specs/schema-flatten-skills.md`, idea: `docs/ideas/schema-flatten-skills.md`

**V7 Flexible Sprint MockTest — 2026-04-29:**
- `pass_threshold_percent` per MockTest (default 80 sprint / 60 full exam chuẩn)
- Admin tự chọn bất kỳ exercise types nào cho từng section (không bị lock theo session_type)
- Flutter `MockExamScreen` route section đến đúng screen (speaking/listening/reading/writing)
- `computeScoring` dùng threshold động thay vì hardcode ≥24
- CMS: bỏ `session_type` select, thêm `pass_threshold_percent` input
- Intro screen passScore tính động từ threshold; result hiển thị % ngưỡng đạt

**V9 CMS Exercise Dashboard Upgrade — 2026-04-30:**
- `exercise-dashboard.tsx` 2036 dòng → 5 file tách biệt: `exercise-utils.ts` (types + parse/build helpers), `exercise-list.tsx` (filter bar + table), `exercise-form/index.tsx` (slide-over wizard + autosave), `exercise-matrix.tsx` (coverage matrix + exam pool mini-matrix), `exercise-dashboard.tsx` (thin orchestrator 211 dòng)
- Coverage Matrix: Module rows × 4 cột (Nói/Nghe/Viết/Đọc), màu theo published count vs target 20, nhóm theo Course, sort theo sequence_no
- Cell click → set module+skill_kind filter + smooth scroll đến list; toggle cell → clear filter
- Tab "Exam Pool": mini-matrix per exercise_type (Tổng / Published / Có ảnh) + flat list; click row → filter
- Form prefill: mở "+ Tạo exercise" khi có active matrix cell tự điền moduleId + skillKind + advance wizard đến step 2
- Loading skeleton (shimmer) + API error banner với retry
- `ExerciseListFilters` state lifted để matrix cell click có thể control list filters
- Vitest 49 unit tests: `buildMatrix`, parse/build utilities, formStateFromExercise, payload builders
- Specs: `docs/specs/exercise-dashboard-upgrade.md`, user flow: `docs/specs/exercise-dashboard-user-flow.md`

**V10 Exam Result Flow Redesign — 2026-04-30:**
- `MockExamSectionDetailScreen` nhận `skillKind` + `maxPoints`, dispatch `SectionResultCard` thay vì luôn `ResultCard`
- `SectionResultCard` mới: header thống nhất (skill icon + label + score + progress bar) + body theo skill (noi/viet → `ResultCard`, nghe/doc → `ObjectiveResultCard`)
- `ObjectiveResultCard`: card-per-question (green/red bg), 2-line wrong answer layout, passage collapsible cho doc (`_PassageSection` async fetch `cteniText`)
- `_buildAnalyzingView` upgrade: LinearProgressIndicator + step list per speaking section (✓/⏳/○)
- 4 i18n keys mới: `objectiveYourAnswer`, `objectiveCorrectAnswer`, `viewPassage`, `hidePassage`
- **Bug fix**: `AdvanceMockExam` query từ "first pending" → JOIN attempts ON exercise_id — fix 400 khi mixed-skill exam (speaking sections chưa analyzed khi objective sections complete)
- **Feature**: `QuestionResult.question_text` — backend extract question prompt từ `items[].question` và `questions[].prompt`
- **Feature**: `QuestionResult.learner_answer_text` + `correct_answer_text` — backend extract option text từ per-question `options[]` và global `options[]`/`persons[]`; Flutter `_AnswerDisplay` widget hiện "A — Nová kavárna" thay chỉ "A"
- **Bug fix**: overall score invisible trong result hero — `RichText` root `TextSpan` không kế thừa `DefaultTextStyle`, thêm `color: AppColors.onSurface`
- Specs: `docs/specs/exam-result-flow-redesign.md`, `docs/specs/exam-result-flow-implementation.md`, idea: `docs/ideas/exam-result-flow-redesign.md`
- Tests: 16 widget tests trong `flutter_app/test/section_result_card_test.dart` (53 total Flutter tests)

**V11 Media Enrichment — 2026-05-01:**
- `image_asset_id` trên `VocabularyItem`, `GrammarRule`, `MultipleChoiceOption`, `MatchOption` (contracts + migrations 020/021)
- `QuizcardBasicDetail.ImageAssetID` inject tại publish time từ vocab item; `ApiClient.mediaUri(key)` → `GET /v1/media/file?key=`
- `QuizcardWidget` image slot (16:9, priority: context_image asset > flashcardImageAssetId)
- `MultipleChoiceWidget` tự switch 2×2 image grid khi tất cả options có `imageAssetId`
- `MatchingWidget` right column hiện image card khi `imageAssetId` có
- `ExerciseContextImage` widget trên tất cả 4 exercise screens (listening/reading/writing/vocab-grammar) + `DeckSessionScreen` (`_FillBlankDeckCard` và `_ChoiceWordDeckCard`)
- Exercise form: "🖼 Ảnh minh họa" collapsible section cho mọi exercise type; `DELETE /admin/exercises/:id/assets/:assetId`
- cteni_1 per-item image upload trong CMS (CteniFields mode image/text toggle); Flutter `_buildCteni1Layout` redesign
- `Course.BannerImageID` + `MockTest.BannerImageID`: `POST/DELETE /admin/{courses,mock-tests}/:id/banner`; CMS card header hiện banner + upload UI; Flutter CourseCard/MockTestCard banner image
- Security fix: `isSafeAssetKey()` dùng `filepath.Clean + HasPrefix` thay `strings.Contains("..")`
- DB fix: inline `ALTER TABLE ADD COLUMN IF NOT EXISTS` tại startup cho tất cả stores — không cần chạy goose migrations thủ công. **RDS caveat**: `ALTER TABLE` yêu cầu table owner; nếu goose chạy bằng user khác (e.g. `odoo`) thì app user (`czech_user`) không thể ALTER. Fix: (1) chạy `DO $$ ... ALTER TABLE ... OWNER TO czech_user $$` một lần sau initial migration (xem `deploy-first-release-checklist.md`); (2) code dùng `addColumnIfMissing()` helper (`store/postgres_migrate.go`) check `information_schema` trước — không gọi `ALTER TABLE` nếu column đã tồn tại
- Specs: `docs/specs/media-enrichment.md`, idea: `docs/ideas/media-enrichment.md`, UI/UX: `docs/designs/media-enrichment.html`

**V12 Deck Session Mode — 2026-05-01:**
- `TypeGroupScreen`: tu_vung/ngu_phap → group exercises by exerciseType, 2-col grid với count badge
- `DeckSessionScreen`: queue (`ListQueue`), progress bar, 4 card types (quizcard_basic, choice_word, fill_blank, matching)
- Local scoring: choice_word/fill_blank substring check on-device — không gọi backend
- `_CompletionView`: Đã biết / Ôn lại counts
- 11 widget tests trong `deck_session_test.dart`

**V13 Ano/Ne Exercise Type — 2026-05-02:**
- Hai exercise types mới: `cteni_6` (đọc passage → Ano/Ne) + `poslech_6` (nghe TTS passage → Ano/Ne), 1–5 statements mỗi bài
- Backend: `AnoNeDetail`/`AnoNeStatement` contracts; `extractQuestionTexts` nhánh `statements[].statement`; `BuildExerciseAudioText` case `poslech_6`; `isAnoNeKey()` exact-match guard ngăn substring collision ("NEANO" ≠ "ANO")
- CMS: `AnoNeFields.tsx` (passage textarea + statement repeater + ANO/NE toggle + max_points + Polly button); wired trước `startsWith` checks trong `exercise-form/index.tsx`; 4 Vitest tests
- Flutter: `AnoNeWidget` + `_AnoNeRow` (44pt tap target, animated states); `_buildCteni6Layout` + poslech_6 branch; `_hasAllAnswers` empty-guard; `AnoNeStatementView` model; 5 i18n keys VI+EN; 5 widget tests
- Scoring: reuse `objective_scorer.go` — no LLM, no new DB migrations, no new endpoints
- Specs: `SPEC.md` § V13, `docs/specs/ano-ne-exercise-type.md`, `docs/designs/ano-ne-exercise-type.html`
- Tests: 243 backend, 53 CMS Vitest, 69 Flutter

**V14 Interview Skill — 2026-05-02:**
- `skill_kind = "interview"`, 2 exercise types: `interview_conversation` + `interview_choice_explain`
- Backend: `POST /v1/interview-sessions/token` (ephemeral ElevenLabs signed URL, inject `{selected_option}`); `POST /v1/attempts/:id/submit-interview`; `interview_scorer.go` (LLM post-session)
- CMS: `InterviewConversationFields.tsx` + `InterviewChoiceExplainFields.tsx` với `system_prompt`, `max_turns`, `show_transcript` toggle
- Flutter: `ElevenLabsWsClient` (custom Dart WS, PCM16 streaming); `SimliSessionManager` (wraps `simli_client`); `InterviewListScreen` → `InterviewIntroScreen` → `InterviewSessionScreen` → `InterviewResultScreen`
- Audio: PCM16 buffer → WAV → `just_audio` playback (Sprint 1); pipe to `simliClient.sendAudioData()` for avatar lip-sync (Sprint 2)
- Security: API key server-side only, Flutter nhận ephemeral signed URL từ backend
- iOS: deployment target 13.0 (flutter_webrtc requirement); camera + mic permissions
- `SIMLI_API_KEY` + `SIMLI_FACE_ID` qua `--dart-define`; avatar disabled khi key trống
- `ELEVENLABS_VOICE_ID_C` env var: khi set, backend trả `voice_id` trong `InterviewTokenResponse`; Flutter inject vào `conversation_config_override.tts.voice_id` — **yêu cầu** bật "Allow client to override TTS voice" trong ElevenLabs agent Security settings, nếu không WS bị reject và learner thấy lỗi kết nối
- Specs: `SPEC.md` § V14, `docs/ideas/interview-skill.md`, `docs/designs/interview-skill.html`
- Tests: 263 backend, 61 CMS Vitest, 102 Flutter

**V15 AI Image Generation in CMS — 2026-05-03:**
- Nút "✨ Tạo bằng AI" kế nút upload ảnh ở 4 vị trí: exercise context_image, cteni_1 per-item, Course banner, MockTest banner
- Backend: `POST /v1/admin/ai/generate-image` (Replicate Flux.1-schnell, poll + download + lưu local) + `POST /v1/admin/ai/set-banner`; rate limit 5 req/phút per admin; `REPLICATE_API_KEY` env var
- CMS: `AiImageButton.tsx` (6-state machine: idle→open→generating→preview→uploading→done/error); `ai-image-utils.ts` (validation + state logic); proxy routes `/api/admin/ai/generate-image` + `/api/admin/ai/set-banner`
- Confirm flow: generate → preview (Replicate CDN URL) → "Dùng ảnh này" → `POST /assets` register → `onSaved()` reload
- Image format: JPEG 512×512; output_format `"jpg"` (không phải `"jpeg"`); `docker-compose.yml` + `docker-compose.ec2.yml` đã thêm `REPLICATE_API_KEY`; DNS fix (`8.8.8.8`) cho Docker container
- Specs: `SPEC.md` § V15, `docs/ideas/ai-image-generation.md`, `docs/designs/ai-image-generation.html`
- Tests: backend +10 (rate limiter + mock Replicate), CMS +17 Vitest (ai-image-utils)

**Remaining backlog (low priority):**
1. Nhập nội dung mẫu qua CMS: ít nhất 1 exercise mỗi loại để test Flutter end-to-end (interview bao gồm)
2. Vocab item audio per-item (Polly TTS deferred từ V11)
3. Sprint 0 spike IV-0: manual verify ElevenLabs Czech quality + simli_client v1.0.1 trên iPhone

**Next coaching slice (if expanding):**
Đọc `docs/ideas/attempt-repair-and-shadowing.md` + spec/plan files trước khi bắt đầu.

Full plan: `tasks/plan.md` + `tasks/todo.md` + `SPEC.md`.

## Avoid
- adding generic plugin systems
- abstracting for multiple exam types
- building a queue-heavy platform before real load exists
- turning mock APIs into permanent hidden debt without updating the docs
- blurring `learner transcript`, `corrected transcript`, and `model answer`
- calling the next coaching slice a full pronunciation engine before the evidence supports that claim
