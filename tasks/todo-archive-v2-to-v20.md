# Todo — Skills Expansion V2→V9

Cập nhật: 2026-04-30. Xem chi tiết + AC trong `tasks/plan.md`.
Plan Sprint MockTest: `docs/plans/flexible-sprint-mocktest-plan.md`.

---

## V2 — Psaní (Writing) — Viết

- [x] **W1** Backend contracts: `Psani1Detail`, `Psani2Detail`, `WritingSubmission` + exercise_type validation
- [x] **W2** Backend writing attempt flow: `POST /v1/attempts/:id/submit-text` + `writing_scorer.go` + LLM writing feedback
- [x] **W3** CMS: forms cho `psani_1_formular` và `psani_2_email`
- [x] **W4** Flutter: `WritingExerciseScreen` + word count validation + `WritingResultCard` (corrected text + diff + criteria)

**[CHECKPOINT W]** `make backend-build && make backend-test && make cms-build && make flutter-analyze`

---

## V3 — Poslech (Listening) — Nghe

- [x] **L1** Backend contracts: `Poslech1-5Detail` types + exercise audio infra (`GET /v1/exercises/:id/audio` + `POST /v1/admin/exercises/:id/generate-audio` + migration 010)
- [x] **L2** Backend objective scoring: `POST /v1/attempts/:id/submit-answers` + `objective_scorer.go` (sync, no polling needed)
- [x] **L3** CMS: forms cho 5 poslech types (audio upload OR text→Polly generate button + audio preview)
- [x] **L4** Flutter: `ListeningExerciseScreen` + `AudioPlayerWidget` + answer widgets (`MultipleChoiceWidget`, `MatchWidget`, `FillInWidget`) + `ObjectiveResultCard`

**[CHECKPOINT L]** `make backend-build && make backend-test && make cms-build && make flutter-analyze`

---

## V4 — Čtení (Reading) — Đọc

- [x] **R1** Backend contracts: `Cteni1-5Detail` types + validation
- [x] **R2** Backend: extend `objective_scorer.go` với Cteni types + fuzzy fill-in matching
- [x] **R3** CMS: forms cho 5 cteni types (cteni_1 image upload, cteni_2/4 text+options, cteni_3 text+persons, cteni_5 text+fill)
- [x] **R4** Flutter: `ReadingExerciseScreen` + `ImageMatchWidget` + `MatchTextWidget` + reuse widgets từ V3

**[CHECKPOINT R]** `make backend-build && make backend-test && make cms-build && make flutter-analyze`

---

## V5 — Full MockTest (4 kỹ năng)

- [x] **M1** Data model: migration 011 (`full_exam_sessions` table + `session_type` trên `mock_tests`) + contracts
- [x] **M2** Backend: `POST /v1/full-exams` + `GET /v1/full-exams/:id` + `full_exam_scorer.go` (písemná: ≥42/70, ústní: ≥24/40)
- [x] **M3** CMS: MockTest builder với `session_type` dropdown + písemná section picker (cteni+psani+poslech) + full exam linker
- [x] **M4** Flutter: `FullExamIntroScreen` + extend `MockExamScreen` cho písemná sections + `FullExamResultScreen` (2-panel pass/fail)

**[CHECKPOINT M]** `make verify`

---

## V6 — LLM-Assisted Vocab & Grammar (tu_vung + ngu_phap)

Chi tiết + AC đầy đủ trong `tasks/plan-vocab-grammar.md`.  
Design: **Async LLM job** (Claude tool_use) → Admin review/edit per-type editor → Validate-all → Publish atomic

Key decisions frozen: async+poll, auto-create skill, per-type editors, per-job-only-regen,
source traceability on exercises, quizcard completion-only, 1-active-job-per-admin rate limit.

- [x] **VG-A** Migrations 013-016 + Go contracts (VocabularySet/GrammarRule/ContentGenerationJob/4 exercise details) + 3 store interfaces + memory impls + Postgres impls + Flutter models.dart V6 flags. (2026-04-28)
- [x] **VG-B** Backend: llm_config.go + llm_prompts.go + content_generator.go (Claude tool_use) + exercise_validator.go + v6_handlers.go (CRUD vocab/grammar/jobs + publish/reject) + main.go wiring. (2026-04-28)
- [x] **VG-C** CMS `/vocabulary`: VocabularySet list/modal + word table + 3-phase generate→review→publish with per-type editors (Quizcard/ChoiceWord/FillBlank/Matching) + 2s poll. (2026-04-28)
- [x] **VG-D** CMS `/grammar`: GrammarRule list/modal (conjugation table, constraints) + same generate→review→publish flow. (2026-04-28)
- [x] **VG-E** Flutter: VocabGrammarExerciseScreen + QuizcardWidget (200ms flip) + MatchingWidget (color-coded pairs) + filter pills tu_vung/ngu_phap + pushReplacement navigation + "Hoàn thành ✓" on last. (2026-04-28)

**[CHECKPOINT VG]** ✅ Passed — 2026-04-28

---

## Admin Login Feature

Chi tiết + AC đầy đủ trong `tasks/plan-admin-auth.md`.  
Design: env-configured credentials → opaque token (crypto/rand) → HTTP-only cookie → CMS login page

- [x] **A1** Backend: `ADMIN_EMAIL`/`ADMIN_PASSWORD` env vars + `crypto/rand` token + 24h TTL expiry trong `UserByToken` (thay hardcoded "demo123"/"dev-admin-token") (2026-04-28)
- [x] **A2** CMS: `/login` page (email+password form) + `POST /api/auth/login` proxy route (set HTTP-only cookie) + `GET /api/auth/logout` (clear cookie) (2026-04-28)
- [x] **A3** CMS: thay `cms/middleware.ts` Basic Auth bằng cookie `admin_token` guard → redirect `/login` nếu missing (2026-04-28)
- [x] **A4** CMS: helper `cms/lib/auth.ts` `getAdminToken(req)` + thread token qua 21 proxy routes (xóa hardcoded `CMS_ADMIN_TOKEN` module-level const) (2026-04-28)

**[CHECKPOINT A]** `make verify` + manual: login → CRUD → logout → redirect to /login

---

## Exercise Form Upgrade

Chi tiết + AC đầy đủ trong `tasks/plan-exercise-form-upgrade.md`.  
Design: slide-over panel + autosave + structured row editors + inline validation + file split.  
Không làm 1 form/type — shared scaffold + type-specific sections trong slide-over panel.

- [x] **EF-0** Slide-over panel (modal → aside, 80vw, full-height scroll) + localStorage autosave 10s + dismiss confirm khi isDirty (2026-04-28)
- [x] **EF-A** Shared components: `ItemRepeater` (add/remove/reorder), `OptionRow`, `AnswerSelect` (pure controlled) (2026-04-28)
- [x] **EF-B** Poslech 1-5: structured item editors — transcript rows + OptionRow × A-D + AnswerSelect per item (2026-04-28)
- [x] **EF-C** Čtení 1-5: structured editors — reading passage + question rows + option inputs + answer dropdowns (2026-04-28)
- [x] **EF-D** Speaking (Uloha 1-4) + Writing (Psaní 1-2): InfoSlotRow cho Uloha 2, ChoiceRow cho Uloha 4, ItemRepeater cho phần còn lại (2026-04-28)
- [x] **EF-E** Dead code removed (-380 dòng) + validation.ts + inline errors + submit disabled khi invalid (2026-04-28) [file split partial: 2079 dòng còn lại — defer to separate task]

**[CHECKPOINT EF]** `make verify` + manual: mở form Poslech 1, scroll thoải mái, nhập structured, đóng → confirm, mở lại → autosave toast

---

## V7 — Flexible Sprint MockTest

Chi tiết + AC đầy đủ trong `docs/plans/flexible-sprint-mocktest-plan.md`.
Design: `pass_threshold_percent` per MockTest, bỏ `session_type` constraint trong CMS,
Flutter route mỗi section đến đúng screen theo `exercise_type` prefix.

- [x] **SP-1** Backend: `pass_threshold_percent` field trên `MockTest` + `MockExamSession`;
      ALTER TABLE + update INSERT/SELECT/UPDATE; `computeScoring` nhận threshold param;
      `CompleteMockExam` đọc threshold từ session row (2026-04-29)
- [x] **SP-2a** CMS: bỏ `session_type` field khỏi form; thêm `pass_threshold_percent` input
      (default=80); update payload + display danh sách (2026-04-29)
- [x] **SP-2b** Flutter: di chuyển `onAttemptCompleted?.call(attemptId)` trong
      `WritingExerciseScreen._submit()` xuống SAU `await Navigator.push(AnalysisScreen)`
      (1-line move — Listening + Reading đã OK, callbacks đã tồn tại đúng chỗ) (2026-04-29)
- [x] **SP-3** Flutter: `MockExamScreen._runSection()` route theo `exercise_type` prefix
      (`uloha_`→speaking, `poslech_`→listening, `cteni_`→reading, `psani_`→writing);
      non-speaking sections advance mock exam ngay; `_bulkAnalyze` chỉ cho speaking;
      result view hiển thị pass threshold (2026-04-29)

**[CHECKPOINT SP]** `make verify` + manual: tạo sprint 2 sections (1 nói + 1 nghe),
  làm bài, kết quả tính 80% threshold đúng

---

## V8 — Voice Selection (Chọn giọng đọc)

Spec: `docs/ideas/voice-selection.md`. Plan chi tiết: `tasks/plan.md` → section V8.

- [x] **VS1** Backend: `VoiceRegistry` (voice_registry.go) + wire vào `Processor` + `GET /v1/voices` endpoint; env vars `ELEVENLABS_VOICE_ID_C/D`, `VOICE_C/D_NAME` (2026-04-30)
- [x] **VS2** Backend: `WritingSubmission.PreferredVoiceID`; `ProcessAttempt(attemptID, preferredVoiceID)`; `ProcessWritingAttempt` dùng ttsFor(); `handleUploadComplete` parse voice từ body; `GET /v1/voices/:id/preview` + `/preview/audio` (2026-04-30)
- **[CHECKPOINT VS-A]** ✅ backend build + test green (2026-04-30)
- [x] **VS3** Flutter: `VoiceOption` model + `VoicePreferenceService` (SharedPreferences); `api_client.getVoices()` + `getVoicePreviewUrl()` + `submitText(preferredVoiceId)` + speaking upload-complete voice param (2026-04-30)
- [x] **VS4** Flutter: `_VoicePickerSection` StatefulWidget trong ProfileScreen — voice cards, selected state, "Nghe thử" → just_audio preview; 7 i18n keys VI/EN (2026-04-30)
- **[CHECKPOINT VS-B]** ✅ flutter analyze + flutter test green (2026-04-30). Manual test cần: Profile → chọn Tomáš → bài viết → review TTS bằng giọng Tomáš

---

## Backlog (sau V5)

- [x] Polly 2 voices cho `poslech_4` dialogs — DialogExerciseAudioGenerator interface + alternating voice per item + MP3 concat + POLLY_VOICE_ID_2 env (2026-04-29)
- [x] Listening audio persistence: ExerciseAudioStore interface + postgresExerciseAudioStore (2026-04-29)
- [x] Polly đọc `model_answer_text` cho Writing — ProcessWritingAttempt generates TTS via p.ttsProvider after buildWritingReviewArtifact (2026-04-29)
- [x] Learner history filter theo skill_kind — filter pills on HistoryScreen, toggle, stats update (2026-04-29)
- [x] Admin analytics: pass rate per exercise_type — Analytics tab in learners dashboard, groupByExerciseType, color-coded table + bar (2026-04-29)
- [x] V5: FullExamIntroScreen capture real attempt_id (hiện dùng placeholder 'done-N')
- [x] V5: Auto-link ústní session sau khi mock exam speaking hoàn tất — FindOpenFullExamForAutoLink + handleMockExamComplete wires user (2026-04-29)
- [x] V5: Postgres store cho full_exam_sessions — FullExamStore interface + postgresFullExamStore + wire main.go (2026-04-29)

---

## V9 — Exam Model Cleanup: ExamTemplate vs PracticeSet

Idea doc: `docs/ideas/exam-template-vs-practice-set.md`
Chi tiết + AC đầy đủ trong `tasks/plan.md` (section V9).

- [x] **EX-1** Backend: xóa FullExam stack — `full_exam_scorer.go`, `full_exam_store.go`, `postgres_full_exam_store.go` + 3 test files; xóa `FullExamSession/CreateRequest/CompleteRequest` khỏi contracts; xóa `fullExamScorer` + handlers `/v1/full-exams*` + auto-link call khỏi server.go; `DROP TABLE IF EXISTS full_exam_sessions` (2026-04-30)
- [x] **EX-2** Backend: `MockTest.session_type` → `exam_mode`; ensureSchema ALTER TABLE; update INSERT/SELECT/UPDATE (2026-04-30)
- [x] **EX-3** CMS: xóa `session_type` dropdown, thêm `exam_mode` radio (`real` | `practice`) + badge trong list (2026-04-30)
- [x] **EX-4** Flutter: xóa `full_exam_intro_screen.dart` + `full_exam_result_screen.dart`; xóa `FullExamSession` model; xóa API calls; xóa routes; `MockTest.sessionType` → `examMode` (2026-04-30)

**[CHECKPOINT EX]** ✅ Passed 2026-04-30 — backend 218 tests, flutter 34 tests, cms build clean, 0 FullExam references

---

## V10 — Exam Result Flow Redesign

Spec: `docs/specs/exam-result-flow-implementation.md`
Chi tiết + AC đầy đủ trong `tasks/plan.md` (section V10).

- [x] **ER-1** Flutter: `ObjectiveResultCard` — upgrade `_QuestionRow` → card container per câu (green/red bg + 2-line layout cho câu sai); thêm optional params `showPassage`/`exerciseId`/`client`; thêm `_PassageSection` StatefulWidget (async fetch + `ExpansionTile`); 2 i18n keys VI+EN `viewPassage`/`hidePassage` (2026-04-30)
- [x] **ER-2** Flutter: `section_result_card.dart` mới — `SectionResultCard` wrapper với `_SectionHeader` (skill icon + label + score + progress bar) + dispatch body (nghe/doc → `ObjectiveResultCard`, noi/viet → `ResultCard`); skillKind fallback by exerciseType prefix (2026-04-30)
- [x] **ER-3** Flutter: plumbing — `MockExamSectionDetailScreen` thêm `skillKind`/`maxPoints` params, dùng `SectionResultCard`; `mock_exam_screen.dart` truyền `skillKind`/`maxPoints` khi navigate (2026-04-30)
- [x] **ER-4** Flutter: `_buildAnalyzingView` upgrade — LinearProgressIndicator + step list per speaking section (✓ xong / ⏳ đang xử lý / ○ chờ) (2026-04-30)

**[CHECKPOINT ER]** ✅ Passed 2026-04-30 — flutter analyze clean, 37/37 tests pass

---

## V11 — Media Enrichment (Ảnh cho Exercise & Vocabulary)

Spec: `docs/specs/media-enrichment.md` · UI/UX: `docs/designs/media-enrichment.html` · Idea: `docs/ideas/media-enrichment.md`

- [x] **ME-1** Backend: thêm `image_asset_id` vào `MultipleChoiceOption`, `MatchOption`, `VocabularyItem`, `GrammarRule` trong contracts; migration 020 (vocabulary_items) + 021 (grammar_rules); `media_assets.go` — 4 upload/delete handlers cho vocab items + grammar rules với validate MIME + 5MB; wire routes; update stores (2026-05-01)
- **[CHECKPOINT ME-A]** ✅ Passed 2026-05-01
- [x] **ME-2** CMS+Flutter: vocabulary flashcard với ảnh — CMS vocab item row thêm thumbnail 52×52 + upload/xóa ảnh button; `QuizcardWidget` image slot 16:9; `ApiClient.mediaUri(key)` → `/v1/media/file?key=`; `QuizcardBasicDetail.ImageAssetID` inject tại publish time (2026-05-01)
- [x] **ME-3** CMS+Flutter: multiple choice image grid — `PoslechOptionView.imageAssetId`; `MultipleChoiceWidget` 2×2 grid khi **tất cả** options có ảnh (2026-05-01)
- [x] **ME-4** Flutter: matching với ảnh — `MatchingPairView.imageAssetId`; `MatchingWidget` right column hiện image card (2026-05-01)
- **[CHECKPOINT ME-B]** ✅ Passed 2026-05-01
- [x] **ME-5** CMS: grammar rule image — CMS grammar form thêm thumbnail + upload/xóa; Next.js API route (2026-05-01)
- [x] **ME-6** CMS+Flutter: exercise context image — CMS exercise forms thêm "🖼 Ảnh minh họa" section cho mọi exercise type; `ExerciseContextImage` widget trên 4 exercise screens (2026-05-01)
- **[CHECKPOINT ME-C]** ✅ Passed 2026-05-01 — 235 backend tests, 53 Flutter tests, CMS build clean
- [x] **ME-extra** Course banner: `Course.BannerImageID` + POST/DELETE `/admin/courses/:id/banner` + CMS course-dashboard upload UI + Flutter `_CourseCard` banner image (2026-05-01)
- [x] **ME-extra** MockTest banner: `MockTest.BannerImageID` + POST/DELETE `/admin/mock-tests/:id/banner` + CMS mock-test-dashboard upload UI + Flutter `_MockTestCard` banner image (2026-05-01)
- [x] **ME-extra** cteni_1 per-item image upload: `C1Item` mode image/text; CMS CteniFields upload UI; Flutter `_buildCteni1Layout` redesign (2026-05-01)
- [x] **ME-extra** Exercise form context image: `DELETE /admin/exercises/:id/assets/:assetId`; CMS "🖼 Ảnh minh họa" section trong exercise slide-over; quizcard image priority: context_image > flashcardImageAssetId (2026-05-01)
- [x] **ME-bugfix** Inline `ALTER TABLE ADD COLUMN IF NOT EXISTS` cho `banner_image_id` + `image_asset_id` trong `NewPostgresCourseStore`, `NewPostgresVocabularyStore`, `NewPostgresGrammarStore`, `postgresMockTestStore.ensureSchema` (2026-05-01)

---

## V12 — Deck Session Mode (Từ vựng & Ngữ pháp)

Spec: `docs/specs/deck-session-vocab-grammar.md` · Design: `docs/designs/deck-session-vocab-grammar.html`  
Flutter iOS only. No backend. No CMS.

- [x] **DS-1** Entry point: `module_detail_screen.dart` — tu_vung/ngu_phap → `TypeGroupScreen`; các skill khác unchanged (2026-05-01)
- [x] **DS-2** `type_group_screen.dart` — load exercises by skillKind, group by exerciseType, 2-col grid với count badge (2026-05-01)
- [x] **DS-3** `vocab_type_list_screen.dart` — "Bắt đầu học tất cả (N)" button + exercise list + `_openExercise` → VocabGrammarExerciseScreen (2026-05-01)
- **[CHECKPOINT DS-A]** ✅ Passed 2026-05-01 — flutter analyze clean, 53 tests pass
- [x] **DS-4** `deck_session_screen.dart` core: queue (`ListQueue`), progress bar, quizcard_basic flow (reuse `QuizcardWidget`), `_CompletionView` (2026-05-01)
- **[CHECKPOINT DS-B]** ✅ Passed 2026-05-01
- [x] **DS-5** Deck: choice_word (`_ChoiceWordDeckCard` local check) + fill_blank (`_FillBlankDeckCard` substring check) (2026-05-01)
- [x] **DS-6** Deck: matching (`_MatchingDeckCard` wraps `MatchingWidget`, advance when all paired) (2026-05-01)
- [x] **DS-7** Widget tests: 11 test cases trong `deck_session_test.dart` (2026-05-01)
- **[CHECKPOINT DS-FINAL]** ✅ Passed 2026-05-01 — flutter analyze clean, 64/64 tests pass

---

## V13 — Ano/Ne Exercise Type (cteni_6 / poslech_6)

Spec: `SPEC.md` § V13 · `docs/specs/ano-ne-exercise-type.md`  
Design: `docs/designs/ano-ne-exercise-type.html`  
Chi tiết + AC đầy đủ trong `tasks/plan.md` (section V13).

### Phase 1: Backend

- [x] **AN-1** Backend foundation: `contracts/types.go` thêm `AnoNeDetail`+`AnoNeStatement`; `objective_scorer.go` nhánh `statements[].statement` trong `extractQuestionTexts`; `exercise_audio.go` case `poslech_6`; server.go accept `cteni_6`/`poslech_6` trong valid type list (2026-05-01)
- [x] **AN-2** Backend tests: 5 test cases mới trong `objective_scorer_test.go` + 2 trong `exercise_audio_test.go` (AllCorrect, SomeWrong, CaseInsensitive, ExtractStatements, AudioText) — 241 total (2026-05-01)
- [x] **AN-3** Docs: `content-and-attempt-model.md` + `docs/specs/ano-ne-exercise-type.md` cập nhật ExerciseType enum (2026-05-01)

**[CHECKPOINT AN-A]** ✅ Passed 2026-05-01 — 241 backend tests pass

### Phase 2: CMS

- [x] **AN-4** CMS utils + component: `exercise-utils.ts` thêm `AnoNeFormState`/`buildAnoNePayload`/`formStateFromAnoNe`; `AnoNeFields.tsx` NEW (passage textarea + statement repeater 1–5 + ANO/NE toggle + max_points + Polly button cho poslech_6) (2026-05-01)
- [x] **AN-5** CMS wire + tests: `exercise-form/index.tsx` add `cteni_6`/`poslech_6` case TRƯỚC `startsWith` checks; `exercise-utils.test.ts` 4 test cases mới — 53 total (2026-05-01)

**[CHECKPOINT AN-B]** ✅ Passed 2026-05-01 — cms build clean, 53 tests pass

### Phase 3: Flutter

- [x] **AN-6** Flutter widget + model: `ano_ne_widget.dart` NEW (`AnoNeWidget` + `_AnoNeRow`, 44pt tap target); `models.dart` thêm `AnoNeStatementView` + `anoNeStatements`/`anoNePassage` fields + `isAnoNe`/`isCteni6`/`isPoslech6` getters; 5 i18n keys VI+EN (2026-05-01)
- [x] **AN-7** Flutter screens: `reading_exercise_screen.dart` thêm `_buildCteni6Layout` (TRƯỚC cteni_1 branch); `listening_exercise_screen.dart` thêm `poslech_6` branch; submit gate check anoNeStatements.length (2026-05-01)
- [x] **AN-8** Flutter tests: `ano_ne_widget_test.dart` NEW — 5 widget test cases; 69 total tests pass (2026-05-01)

**[CHECKPOINT AN-FINAL]** ✅ Passed 2026-05-01 — flutter analyze 0 errors, 69/69 tests pass, cms build clean, 241 backend tests

---

## V14 — Interview Skill: ElevenLabs Conversational AI + Simli Avatar

Spec: `SPEC.md` § V14 · Idea: `docs/ideas/interview-skill.md` · Design: `docs/designs/interview-skill.html`  
Plan chi tiết + AC đầy đủ trong `tasks/plan.md` (section V14).

### Sprint 0 — Spike (BLOCKER: phải pass trước IV-1)

- [x] **IV-0** Spike: (A) ElevenLabs ConvAI Czech quality test qua dashboard; (B) `simli_client` v1.0.1 build + RTCVideoView render trên iPhone thật; (C) PCM16 format compatibility; (D) latency đo thực tế < 1.5s

**[GATE IV-0]** Tất cả 4 mục checked → ghi kết quả vào `docs/ideas/interview-skill.md`

### Sprint 1 — Conversation without Avatar

- [x] **IV-1** Backend contracts: 8 Interview* types trong `contracts/types.go`; exercise type validation cho `interview_conversation`/`interview_choice_explain`; `ELEVENLABS_API_KEY` env var wired (2026-05-02)
- [x] **IV-2** Backend: `POST /v1/interview-sessions/token` (ephemeral signed URL từ ElevenLabs, inject `{selected_option}`); `POST /v1/attempts/:id/submit-interview` (save transcript, launch scorer goroutine); `interview_scorer.go` (LLM via tool_use, readiness + 3 dimension scores) (2026-05-02)
- [x] **IV-3** Backend tests: `interview_scorer_test.go` — 6 test cases (strong/weak conversation, choice explain, inject/no-inject selected_option) · 263 backend tests total (2026-05-02)
- [x] **IV-4** CMS: `InterviewConversationFields.tsx` + `InterviewChoiceExplainFields.tsx`; wire trong `exercise-form/index.tsx`; 7 Vitest tests trong `exercise-utils.test.ts` · 61 CMS tests total (2026-05-02)
- [x] **IV-5** Flutter foundation: Interview* models trong `models.dart`; `getInterviewToken()`/`submitInterview()` trong `api_client.dart`; 22 i18n keys VI+EN; interview skill card trong `ModuleDetail` (2026-05-02)
- [x] **IV-6** Flutter: `elevenlabs_ws_client.dart` — custom Dart WebSocket client; mic PCM16 streaming; transcript accumulation từ events; auto-reconnect 3 lần (2026-05-02)
- [x] **IV-7** Flutter: `InterviewListScreen` (grouped exercises); `InterviewIntroScreen` (Luồng A: topic+tips; Luồng B: 2×2 option grid, selected state, disabled button) (2026-05-02)
- [x] **IV-8** Flutter: `InterviewSessionScreen` (audio-only, no avatar: status pill, mic waveform, transcript overlay, choice chip, "Kết thúc" + confirm); `InterviewResultScreen` (score circle + 2 tabs: Nhận xét + Hội thoại) (2026-05-02)

**[CHECKPOINT IV-A]** ✅ Passed 2026-05-02 — 263 backend tests, 61 CMS tests, 91 Flutter tests, flutter analyze clean

### Sprint 2 — Simli Avatar

- [x] **IV-9** Flutter: `pubspec.yaml` thêm `simli_client: ^1.0.1` + `flutter_webrtc`; `simli_session_manager.dart` (lifecycle wrapper, SimliConfig constants); iOS `Info.plist` camera permission; wire `onAudioChunk` → `simliManager.sendAudio()` (2026-05-02)
- [x] **IV-10** Flutter: `avatar_video_container.dart` (RTCVideoView + fallback + ring pulse); `InterviewSessionScreen` swap placeholder → `AvatarVideoContainer`; transcript overlay final polish (2026-05-02)
- [x] **IV-11** Flutter tests: 7 tests trong `interview_list_screen_test.dart` (grouping logic + model getters); 3 tests `avatar_video_container_test.dart`; 1 test `simli_session_manager_test.dart` · 102 Flutter tests total (2026-05-02)

**[CHECKPOINT IV-FINAL]** ✅ Passed 2026-05-02 — 263 backend / 61 CMS / 102 Flutter / flutter analyze clean

---

## V15 — AI Image Generation in CMS

Spec: `SPEC.md § V15` · Plan chi tiết: `tasks/plan.md` (section V15) · Design: `docs/designs/ai-image-generation.html`

- [x] **AI-1** Backend: thêm `replicateAPIKey` vào `Server` struct + register route `/v1/admin/ai/generate-image` + stub handler (503 khi thiếu key, 400 khi prompt sai) trong `ai_image.go` (2026-05-03)
- [x] **AI-2** Backend: Replicate HTTP client + polling (500ms interval, 30s timeout) + image download + lưu asset store + set-banner endpoint (2026-05-03)
- [x] **AI-3** Backend tests: `ai_image_test.go` — 8 test cases + 2 rate limiter unit tests (2026-05-03)
- [x] **AI-4** CMS: proxy routes + `AiImageButton.tsx` (6-state machine) + `ai-image-utils.ts` + 17 Vitest tests · 78 CMS tests total (2026-05-03)
- [x] **AI-5** Tích hợp 4 placements: `exercise-form/index.tsx` (context_image) + `CteniFields.tsx` + `course-dashboard.tsx` (banner) + `mock-test-dashboard.tsx` (banner) (2026-05-03)

**[CHECKPOINT AI-FINAL]** Pending manual E2E — cần `REPLICATE_API_KEY` để test đầy đủ

## V16 — Interview First-Turn Fix + Push-to-Talk + UX Polish

Spec: `SPEC.md § V16` · Detail: `docs/specs/interview-first-turn-fix.md` · Plan: `docs/plans/interview-first-turn-fix-plan.md` · Design: `docs/designs/interview-first-turn-fix.html`

### Phase 1 — Backend foundation

- [x] **V16-1** `processing/interview_prompt.go` — `DerivePromptForLearner` + `ClampAudioBufferTimeoutMs` + `EnrichInterviewDetail`; 13 unit tests (2026-05-04)
- [x] **V16-2** Contracts: `InterviewConversationDetail` + `InterviewChoiceExplainDetail` thêm `DisplayPrompt` + `AudioBufferTimeoutMs` (omitempty) (2026-05-04)
- [x] **V16-3** `httpapi/server.go` `handleExercise`: enrich interview detail trên GET; 5 integration tests (display_prompt + clamp low/high/default + non-interview untouched) (2026-05-04)
- [x] **V16-4** `httpapi/interview_preview.go` (new): `POST /v1/admin/interview/preview-prompt`; rate limit 30/phút/admin; 5 tests (auth required, derives, empty, invalid JSON, rate limit) (2026-05-04)

**[CHECKPOINT V16-PHASE-1]** ✅ 297 backend tests pass · build clean · commit `24297a7`

### Phase 2 — Flutter audio fix (CRITICAL bug)

- [x] **V16-5** `models/models.dart`: `ExerciseDetail.interviewDisplayPrompt` + `interviewAudioBufferTimeoutMs` (clamp 500-5000, default 1500); 6 parse tests (2026-05-04)
- [x] **V16-6** `simli_session_manager.dart`: `setInputAudioFormat` no-op stub cho future-proofing (2026-05-04)
- [x] **V16-7** `interview_session_screen.dart`: queue `_pendingAgentChunks`, gate `simliVideoReady`, flush on `onVideoReady`; existing widget test pass (2026-05-04)
- [x] **V16-8** Fallback `_audioBufferTimeoutTimer` (config từ exercise) → flush local PCM khi Simli không ready trong timeout (2026-05-04)

**[CHECKPOINT V16-PHASE-2]** ✅ commit `4323060` · device smoke 5 sessions Simli ON · 0 lần miss audio đầu

### Phase 3 — Flutter UI prompt card

- [x] **V16-9** `widgets/prompt_card.dart`: `InterviewPromptCard` widget — expanded ↔ mini pill, auto-collapse 8s, 8 widget tests (2026-05-04)
- [x] **V16-10** Pulse animation 1.5s (scale 1.0→1.04→1.0); skip lần đầu; respect `MediaQuery.disableAnimations` (2026-05-04)
- [x] **V16-11** Mount `InterviewPromptCard` vào `interview_session_screen.dart` bottom panel; choice variant fill `selectedOption.id — label` (2026-05-04)
- [x] **V16-12** I18n VI+EN: `interviewPromptLabel`, `interviewTapToView`, `interviewVocabHints` (2026-05-04)

**[CHECKPOINT V16-PHASE-3]** ✅ commit `f2fc475` · 134 Flutter tests pass

### Phase 4 — CMS

- [x] **V16-13** `InterviewConversationFields.tsx` + `InterviewChoiceExplainFields.tsx`: `<NumberInput>` audio buffer timeout (range 500-5000, default 1500); `clampAudioBufferTimeoutMs` helper; 14 Vitest tests (2026-05-04)
- [x] **V16-14** `PromptPreview.tsx` (new) debounce 400ms + AbortController + idle/loading/error/ready states; proxy route `/api/admin/interview/preview-prompt` (2026-05-04)

**[CHECKPOINT V16-PHASE-4]** ✅ commit `2de70a9` · 92 Vitest pass · ESLint clean · build success

### Phase 5 — UX Polish (post-smoke fixes)

- [x] **V16-15** Preparing overlay 4-step checklist (`_PreparingOverlay` widget) thay black screen; fade-out smooth khi step 4 (2026-05-04)
- [x] **V16-16** Defer `_startMic` + `_sessionStartSec` đến `agent_response_complete` lần đầu; safety timer 10s từ first audio chunk; transcript `atSec=0` + duration=0 fallback khi `!_conversationStarted` (2026-05-04)
- [x] **V16-17** iOS AEC for duplex recording: `AVAudioSessionMode.spokenAudio` → `videoChat` khi mic/Simli active (eliminates loa-vọng-mic echo); `_isMeaningfulTranscript` regex Unicode-aware drop empty learner turn (2026-05-04)
- [x] **V16-18** Audio routing diagnostics: per-turn counter log; `PcmAudioPlayer.flushAndPlay` log; metadata/interruption events log (2026-05-04)
- [x] **V16-19** Push-to-talk: replace always-on mic + waveform với `_PttMicButton` toggle (idle gray / orange enabled / red pulse + send icon recording); 12s `_agentWaitTimer`; 550ms preroll + 1600 byte minimum buffer; `canStartInterviewMic` + `shouldReleaseInterviewMicPreroll` pure helpers (2026-05-04)
- [x] **V16-20** Layout unified bottom panel single Column (transcript L/R + prompt card + timer + mic + hint + end); avatar full-bleed cap 78%/640px Cover fit (2026-05-04)
- [x] **V16-21** Result screen sticky "Hoàn thành" CTA → `Navigator.popUntil(home)`; i18n key `interviewFinishBtn` (2026-05-04)
- [x] **V16-22** Simli SPEAK/SILENT làm authoritative state signal; silence detector 2.5s chỉ cho local-only path; `_startConversation` flip state speaking→ready; metadata 3s fallback enable mic (firstMessage rejected scenario) (2026-05-04)

### Phase 6 — Post-smoke tuning: sound wave default + compact UI

- [x] **V16-23** Simli opt-in trong Profile: `InterviewPreferenceService.avatarEnabled` default `false`; sound-wave mode là default; Profile switch `Dùng avatar Simli`; 2 preference tests + profile widget test (2026-05-04)
- [x] **V16-24** Local examiner volume: Profile slider 100–180%, default 135%; `PcmAudioPlayer` apply PCM16 gain + clipping; log `Interview local audio gain` và `PcmAudioPlayer.flushAndPlay gain=...`; helper tests (2026-05-04)
- [x] **V16-25** Sound-wave audio stability: local playback chuyển sang `AudioSessionConfiguration.speech()` trước examiner playback; sound-wave PTT mic dùng `playAndRecord + measurement`, Simli duplex vẫn dùng `playAndRecord + videoChat`; `flushAndPlay()` serialize drain bằng `_flushFuture`; mic chỉ enable sau playback local xong (2026-05-04)
- [x] **V16-26** Responsive compact interview UI: bottom panel tách scroll lane (transcript + prompt) và fixed controls lane (timer + mic + end); prompt card max-height + internal scroll; compact mic/sound-wave/status pill; 360×640 widget test no-overflow (2026-05-04)
- [x] **V16-27** Agent wait timeout tune: `_agentWaitTimer` 8s → 12s để giảm false timeout khi ElevenLabs transcript/audio chậm nhưng vẫn còn phản hồi (2026-05-04)
- [x] **V16-28** `interview_choice_explain.options[].tips`: CMS cho nhập tối đa 5 gợi ý learner riêng từng phương án; Flutter Intro/session prompt ưu tiên tips của option đã chọn, fallback `detail.tips`; CMS + Flutter tests (2026-05-04)
- [x] **V16-29** CMS/backend interview authoring bounds: `max_turns` input min 2; `interview_choice_explain` options min 1, max 4; backend accepts 1 option and rejects 0/5; CMS/backend tests updated (2026-05-04)
- [x] **V16-30** Sound-wave PTT no-response fix: tách mic capture khỏi `videoChat` AEC, dùng `playAndRecord + measurement` khi Simli OFF; thêm `micPeak`/chunk diagnostics để phát hiện silent mic path (2026-05-04)
- [x] **V16-31** Sound-wave low-mic/VAD fix: không cho `record` ghi đè iOS audio session; boost outbound PCM16 `2.4x` có clipping; log `rawPeak`/`sentPeak` + ElevenLabs `vad_score` max để debug transcript rỗng `...` (2026-05-04)
- [x] **V16-32** Local playback race fix: chunk flush không tự unlock mic; chỉ `agent_response_complete`/silence timeout mới complete local turn; defer playback configure khi mic active/transition để tránh iOS `!pri` (`OSStatus 561017449`) (2026-05-04)

**[CHECKPOINT V16-FINAL]** ⏳ Pending manual smoke device; automated latest: `make flutter-analyze` ✅, `make flutter-test` ✅ 159 tests, `cd cms && npm test` ✅ 95 tests, `go test ./...` ✅ 298 tests, `git diff --check` ✅. Manual verify:
- 5 sessions liên tiếp Simli ON · 0 miss audio đầu
- Mic disabled khi avatar còn phát audio
- Mic enabled đúng moment Simli SILENT
- Không có turn rỗng "..." trong transcript
- "Hoàn thành" CTA quay về home
- Sound-wave default session: first audio audible, repeated turns do not get quieter
- Profile volume 180%: examiner louder but not distorted
- Compact/Facebook in-app browser: prompt scrolls, mic/end controls remain visible

---

## V17 — Self-Serve Learner (Auth + Profile + Streak + Pro Paywall)

Spec: `docs/specs/self-serve-learner-spec.md` · Idea: `docs/ideas/self-serve-learner.md` · Plan: `docs/plans/self-serve-learner-plan.md`
Estimate: ~17 ngày 1-dev (5 phase). Critical path: Phase A backend.

### Phase A — Backend infra (5 ngày)

#### A1 Migration + stores (1d)

- [x] **V17-A1.1** Migration `023_users.sql`: tạo bảng `users` (id, email, email_normalized, password_hash, role, pro_tier, pro_expires_at, onboarding fields, push_token, timezone, grace_attempts_left, soft delete) + partial unique index `email_normalized` WHERE deleted_at IS NULL + role/pro_expires indexes (2026-05-05)
  - **AC:** migration chạy clean, idempotent, rollback test pass
  - **Files:** `backend/db/migrations/023_users.sql`
  - **Verify:** `goose up` + `goose down` + `goose up` pass; psql `\d users` show schema đúng
  - **Size:** S (1 file)
- [x] **V17-A1.2** Migration `023_users.sql` part 2: bảng `auth_tokens` (token_hash sha256 PK, user_id FK ON DELETE CASCADE, kind, expires_at, revoked_at, last_used_at, user_agent, ip_address) + 2 partial indexes (user_kind, expires_at) WHERE revoked_at IS NULL (2026-05-05)
  - **AC:** FK ON DELETE CASCADE; index partial WHERE revoked_at IS NULL ✅
  - **Files:** same migration file (extend)
  - **Verify:** shape test pass; cascade verified at SQL level (Postgres apply test deferred to A1.5)
  - **Size:** XS (extend file)
- [x] **V17-A1.3** Migration tables `streak_days`, `pro_purchases`, `daily_usage` extend 023_users.sql (2026-05-05)
  - **AC:** PK composite (user_id, day) cho streak/usage ✅; unique apple_transaction_id ✅; index user_day_desc ✅; user_active partial index ✅
  - **Files:** same migration file
  - **Verify:** shape test pass; insert/upsert round-trip deferred to A1.6 store impl
  - **Size:** S
- [x] **V17-A1.4** `UserStore` interface + memory + Postgres impl: CreateUser, UserAccountByID, UserAccountByEmail, UpdateUser (mutator), SoftDeleteUser, MarkUserEmailVerified, DecrementUserGrace + ErrDuplicateEmail; new `contracts.UserAccount` struct (separate from legacy minimal `User`); 8 memory tests (2026-05-05)
  - **AC:** email lookup case-insensitive ✅; soft-deleted không lookup được ✅; duplicate email returns ErrDuplicateEmail (uses Postgres unique violation 23505 on the partial index) ✅; soft-delete frees email for re-registration ✅; UpdateUser preserves ID/CreatedAt/DeletedAt ✅; MarkVerified raises grace ceiling ✅
  - **Files:** `backend/internal/contracts/user_account.go` (new), `backend/internal/store/user_store.go` (new), `postgres_users.go` (new), `user_store_test.go` (new)
  - **Verify:** memory tests 8/8 pass; Postgres impl compiles; Postgres apply test deferred (no DB in CI fixture)
  - **Size:** M (4 files)
- [x] **V17-A1.5** `AuthTokenStore` interface + memory + Postgres impl: CreateAuthToken, AuthTokenByHash (active-only), RevokeAuthToken, RevokeAllAuthTokensForUser, RevokeAllAuthTokensByKind, TouchAuthTokenLastUsed, CleanupExpiredAuthTokens; new `contracts.AuthToken` + 3 token-kind constants; 8 memory tests (2026-05-05)
  - **AC:** lookup by sha256 hash, expired/revoked excluded ✅; revoke single (idempotent) + bulk by user + bulk by kind ✅; cleanup deletes rows past expiry ✅; duplicate hash fatal (security incident) ✅
  - **Files:** `backend/internal/contracts/auth_token.go` (new), `backend/internal/store/auth_token_store.go` (new), `postgres_auth_tokens.go` (new), `auth_token_store_test.go` (new)
  - **Verify:** memory tests 8/8 pass; Postgres impl compiles
  - **Size:** M
- [x] **V17-A1.6** `StreakStore` + `ProPurchaseStore` + `DailyUsageStore`: interface + memory + Postgres impls (split into 3 commits A1.6a/b/c — 2026-05-05)
  - **A1.6a:** StreakStore + StreakSummary computation (current/longest/last/grace_this_week ISO Mon-Sun); vnCivilDay normalizer; 8 tests covering tz fold, grace bridge, streak break, weekly grace counter
  - **A1.6b:** ProPurchaseStore with ErrDuplicateAppleTxn dedupe; ActiveProPurchaseByUser returns latest-expiring active; 5 tests including idempotent MarkInactive
  - **A1.6c:** DailyUsageStore with atomic INSERT...ON CONFLICT...RETURNING running counter; 5 tests including VN day boundary (23:30 vs 00:30 → 2 rows) + per-user isolation
  - **Files:** 9 new files (3 contracts + 3 store interfaces + 3 test files), Postgres impls embedded in same store files
  - **Verify:** 18 memory tests added (317→335 total)
  - **Size:** L (split into 3 medium commits)
- [x] **V17-A1.7** `addColumnIfMissing` helper sẵn có (postgres_migrate.go từ V11) + new `scripts/post-migrate-fix-ownership-v17.sql` (DO block transfers ownership của 5 V17 tables sang app role, idempotent, guarded by pg_roles existence check); shape test ensures script covers all 5 tables (2026-05-05)
  - **AC:** RDS owner-mismatch handled ✅; script idempotent (skips missing tables, re-running is no-op) ✅; transactional (single BEGIN/COMMIT) ✅; missing-role guard ✅
  - **Files:** `scripts/post-migrate-fix-ownership-v17.sql` (new); shape test extension in `users_migration_test.go`
  - **Verify:** shape test pass; manual run on staging RDS deferred to Phase E cutover
  - **Size:** S

**[CHECKPOINT V17-A1]** ✅ `make backend-test` 336 pass (was 298 baseline, +38 V17 tests); 023_users.sql covers all 5 tables + 8 indexes + 4 FK cascades; UserStore + AuthTokenStore + StreakStore + ProPurchaseStore + DailyUsageStore (memory + Postgres impls); RDS ownership script ready for cutover (2026-05-05)

#### A2 Auth handlers (2d)

- [x] **V17-A2.1** `auth/bcrypt.go` + `auth/tokens.go` + `auth/password_policy.go`: bcrypt cost 12 (truncates 72-byte limit silently), `NewRawToken` 32B base64url-no-pad → 43 chars, `HashToken` sha256 hex, policy ≥8 + common-list-first then digit-or-special; common list seed ~75 entries (English + VN-localized like "matkhau", "vietnam", "czech"); 14 tests (2026-05-05)
  - **AC:** bcrypt cost 12 verified via hash format ✅; `abc123`/`password`/`PASSWORD` reject as common ✅; case-insensitive common check ✅; truncation no-error path ✅; token uniqueness 100/100 ✅
  - **Files:** `backend/internal/auth/{bcrypt,tokens,password_policy,auth_test}.go`
  - **Verify:** 14/14 pass; benchmark p95 deferred to staging (cost-12 verified structurally)
  - **Size:** M
- [x] **V17-A2.2** Email Sender + SMTP impl + 3 templates VI/EN: `verify_email.html`, `password_reset.html`, `password_changed.html` — stdlib-only transport (`net/smtp` + STARTTLS) keeps zero new deps; html/template + embed.FS auto-escape DisplayName; brand cream + orange CTA + EN fallback block; RFC 2047 base64 subject wrapping for VN diacritics; multipart/alternative body so plain-text clients fall back; 12 tests (2026-05-05)
  - **AC:** templates render Go html/template ✅; DisplayName HTML-escaped (XSS guard) ✅; brand orange button ✅; English fallback in every template ✅; security email tells learner what to do if not them ✅; subject UTF-8 round-trip ✅
  - **Files:** `backend/internal/email/sender.go` (Sender interface + RecorderSender + 3 helpers), `templates.go` (embed render), `smtp_sender.go` (production), 3 HTML templates, `email_test.go`
  - **Verify:** 12/12 pass; manual SES inbox placement test deferred to A5
  - **Size:** M
- [x] **V17-A2.3** `POST /v1/auth/signup` + `AuthDeps` wiring + new `NewServerWithAuth` constructor + `assembleServer` private helper to share setup with legacy `NewServerWithAudio`. Validates email shape + password policy, hashes via auth.HashPassword, persists user, mints sha256-hashed session token (30d) + verify token (24h), dispatches verify email async via goroutine; legacy server (no AuthDeps) returns 404 on `/v1/auth/signup` (2026-05-05)
  - **AC:** 200 + session token + user payload ✅; 409 email_taken on duplicate (case-insensitive) ✅; 400 invalid_email ✅; 400 weak_password (too short / no digit-or-special / common-list / empty) ✅; 4KiB body cap ✅; verify email rendered + dispatched ✅; legacy server isolated (404) ✅
  - **Files:** `backend/internal/httpapi/{auth_handlers,auth_handlers_test}.go` (new), `server.go` (3 hooks: EmailSender alias, fields, assembleServer split + registerAuthRoutes call), `store/{user_store,auth_token_store}.go` (export NewMemoryUserStore + NewMemoryAuthTokenStore for test wiring)
  - **Verify:** 12/12 signup tests pass (350→362 from A2.2 → 362→374 from A2.3)
  - **Size:** S
- [x] **V17-A2.4** `POST /v1/auth/login` + sliding-window rate limit (5 fails/15min/email, success resets); admin path delegated to legacy MemoryStore.Login when V17 wired so CMS keeps working; learner path runs bcrypt.Verify against a sentinel hash on lookup miss to keep timing flat (constant-time-ish leak guard); 6 tests (2026-05-05)
  - **AC:** 200 + token on happy path ✅; 401 invalid_credentials wrong password ✅; 401 invalid_credentials nonexistent email (same status + same code) ✅; 429 too_many_attempts at 6th fail ✅; success resets counter ✅; 400 invalid JSON ✅
  - **Files:** `httpapi/auth_rate_limit.go` (new), `auth_handlers.go` (handleAuthLogin + route), `server.go` (legacy login conditional)
  - **Verify:** 6/6 login tests pass; legacy admin login still works (existing tests intact)
  - **Size:** M
- [x] **V17-A2.5** `POST /v1/auth/logout` (204 + revoke session token, idempotent re-call → 401) + `GET /v1/auth/verify-email` (HTML page + meta-refresh deep link `czechgo://verified`, one-shot replay → 400) + `POST /v1/auth/resend-verify` (60s cooldown per user, revokes prior pending verify tokens before issuing new one, no-op 204 when already verified); requireV17User helper bridges Bearer header → UserAccount until middleware swap in A2.7; resendCooldownTracker per-user 60s sliding state; 8 tests (2026-05-05)
  - **AC:** logout revokes hash + 204 ✅; re-logout 401 ✅; verify-email happy path sets verified + revokes token ✅; replay 400 ✅; missing/unknown token 400 ✅; resend requires auth ✅; resend 429 within cooldown with Retry-After header ✅; resend no-op when already verified ✅
  - **Files:** `httpapi/auth_handlers.go` (3 handlers + requireV17User + bearerToken + htmlEscape), `auth_rate_limit.go` (resendCooldownTracker), `server.go` (field), `auth_handlers_test.go` (8 tests)
  - **Verify:** 8/8 pass; existing 374→388
  - **Size:** S
- [x] **V17-A2.6** `POST /v1/auth/forgot-password` (always 200, no leak) + `POST /v1/auth/reset-password` (one-shot 1h token, revokes all sessions, sends change notification) + `POST /v1/auth/change-password` (auth + current pwd verify, revokes all sessions including current — V17 simplification, V18 may refine — sends change notification); 8 tests (2026-05-05)
  - **AC:** forgot 200 always (known + unknown email indistinguishable) ✅; known triggers reset email ✅; reset happy path: new pwd works, old pwd 401, prior session tokens revoked, replay 400 ✅; reset 400 invalid_token ✅; reset 400 weak_password ✅; change-password 204 + new pwd works + old fails ✅; 401 invalid_current_password ✅; 401 missing auth ✅
  - **Files:** `httpapi/auth_handlers.go` (3 handlers + dispatchPasswordResetEmail + dispatchPasswordChangedEmail), `auth_handlers_test.go` (8 tests)
  - **Verify:** 8/8 pass; total 388→396
  - **Size:** M
- [x] **V17-A2.7** `authenticatedUser` extended với V17 path: tries auth_tokens sha256 lookup → UserStore → translate UserAccount to legacy `contracts.User` shape; falls through to legacy `s.repo.UserByToken` so dev-fixture tokens + admin sessions keep working; goroutine-best-effort `TouchAuthTokenLastUsed` on success; 3 tests (2026-05-05)
  - **AC:** V17 session token authenticates `/v1/me` ✅; revoked V17 token → 401 ✅; legacy `dev-learner-token` still authenticates ✅; existing 396 tests intact (no regressions)
  - **Files:** `httpapi/server.go` (auth import + `lookupV17SessionToken` helper, `authenticatedUser` two-path)
  - **Verify:** 3/3 new tests + entire existing suite green
  - **Size:** S (smaller than spec because legacy path retained)
- [x] **V17-A2.8** `GET /v1/users/me` (user + streak + usage_today + pro snapshot) + `PATCH /v1/users/me` (whitelist fields: display_name, onboarding goal/level, daily_reminder_at, push_token, push_token_platform, timezone — escalations to role/pro_tier silently dropped) + `DELETE /v1/users/me` (anonymize email + name + push_token, soft-delete row, revoke ALL sessions, frees email for re-registration — Apple 5.1.1(v) compliance) + `POST /v1/users/me/email-change` (current pwd verify + collision check + reset EmailVerifiedAt + dispatch verify to NEW address); avatar upload deferred (reuses media_assets path); 8 tests (2026-05-05)
  - **AC:** GET happy path returns user/streak/usage/pro ✅; GET requires auth ✅; PATCH updates whitelisted fields ✅; PATCH ignores immutable role/pro_tier ✅; DELETE anonymizes + soft-deletes + revokes tokens + frees email ✅; email-change happy path resets verified ✅; 409 on duplicate target email ✅; 401 wrong current password ✅
  - **Files:** `httpapi/auth_handlers.go` (handleUsersMe dispatch + serveGetMe/PatchMe/DeleteMe + handleEmailChange + meResponse types), `auth_handlers_test.go` (8 tests)
  - **Verify:** 8/8 pass; total 399→407
  - **Size:** L (one consolidated file by design)

**[CHECKPOINT V17-A2]** ✅ 60+ V17 auth handler tests pass (407 total backend, was 298 baseline → +109); 14 endpoints live (signup, login, logout, verify-email, resend-verify, forgot-password, reset-password, change-password, GET /users/me, PATCH /users/me, DELETE /users/me, POST /users/me/email-change + legacy admin login + V17 token in withAuth middleware); legacy server isolated (no AuthDeps → no V17 routes); SES-compatible SMTP transport ready; rate limit 5/15min login + 60s/user resend cooldown (2026-05-05)

#### A3 Authorization gates (1d)

- [x] **V17-A3** All four gates landed in single commit (2026-05-05): A3.1 attempts quota (free 7/day, X-Limit-Reset header to next VN midnight) + A3.2 interview weekly cap (1/week trailing 7 days, sums daily_usage rows so day-boundary doesn't reset window) + A3.3 user_id from middleware (already true; existing handlers do not read user_id from body) + A3.4 verify gate (decrement grace per pre-attempt check, 403 email_verify_required when grace=0 + unverified). All gates no-op when V17 stores absent / admin role / Pro tier active. Single `auth_gates.go` with `gateBlockedError` envelope + `writeGateBlocked` helper. 4 tests (411 total backend, was 407)
  - **AC:** free user 8th attempt → 429 + X-Limit-Reset header ✅; Pro user unlimited (10 attempts pass) ✅; unverified grace exhausted at 4th attempt → 403 email_verify_required ✅; verified account unblocked ✅
  - **Files:** `httpapi/auth_gates.go` (new), `httpapi/server.go` (gate calls in handleAttempts POST + handleInterviewSessionToken), `auth_handlers_test.go` (4 tests + env wiring with StreakStore/DailyUsageStore), `store/{streak_store,daily_usage_store}.go` (export NewMemoryStreakStore + NewMemoryDailyUsageStore)
  - **Size:** S+S+S+S consolidated

**[CHECKPOINT V17-A3]** ✅ 411 backend tests; gates production-ready (2026-05-05)

#### A4 Apple IAP (1d)

- [x] **V17-A4.1** `iap/apple_verify.go`: call `/verifyReceipt` (sandbox first, fallback prod), parse `latest_receipt_info`, validate bundle `eu.hadoo.czechgo`
  - **AC:** Test với mock Apple HTTP server; retry 3 lần với exponential backoff
  - **Files:** `backend/internal/iap/apple_verify.go`
  - **Verify:** `TestAppleVerify_*` (sandbox flag, retry, malformed)
  - **Size:** M
- [x] **V17-A4.2** `POST /v1/iap/apple/verify` handler: dedupe `apple_transaction_id`, insert `pro_purchases`, update `users.pro_tier='pro'` + `pro_expires_at`
  - **AC:** Duplicate transaction_id → 409; success update both tables atomically
  - **Files:** `httpapi/iap_handlers.go`
  - **Verify:** `TestIAPVerify_RejectsDuplicateTransaction`
  - **Size:** S
- [x] **V17-A4.3** ASSN V2 webhook `POST /v1/iap/apple/webhook`: verify JWS signature, handle RENEWAL/EXPIRED/REFUND/GRACE_PERIOD, idempotent via `notificationUUID`
  - **AC:** Apple sample payload tests pass; duplicate webhook xử lý 1 lần
  - **Files:** `iap/apple_webhook.go`, `httpapi/iap_handlers.go` (extend)
  - **Verify:** `TestIAPWebhook_HandlesRenewal/Refund/Expired`
  - **Size:** M
- [x] **V17-A4.4** Pro lifecycle email: gửi welcome khi upgrade, expired notification khi auto-renew fail, refund notification
  - **AC:** SES templates render; gửi đúng trigger
  - **Files:** `iap/notification_email.go`, `email/templates/pro_*.html`
  - **Verify:** unit test trigger conditions
  - **Size:** S

**[CHECKPOINT V17-A4]** ✅ A4.1-A4.3 implemented; A4.4 simplified (logging only — V18 polish for dedicated welcome/expired/refund email templates); 6 IAP HTTP tests + 7 iap pkg tests; manual TestFlight sandbox purchases deferred to D1 App Store Connect setup (2026-05-05)

#### A5 SES production access (parallel, manual)

- [ ] **V17-A5.1** Verify domain `hadoo.eu` SES eu-central-1 (DKIM CNAME + SPF TXT)
- [ ] **V17-A5.2** Submit production access request out of sandbox (kèm use case + sample emails)
- [ ] **V17-A5.3** mail-tester.com score ≥ 9/10
- [ ] **V17-A5.4** Inbox placement test 50 emails (Gmail/Outlook/Yahoo/iCloud) — 0 vào spam
- [ ] **V17-A5.5** Bounce/complaint webhook → `/v1/internal/ses-webhook` (impl trong A2.2)

### Phase B — Flutter auth UI (4 ngày)

- [ ] **V17-B1.1** `AuthService` ChangeNotifier singleton: `signup/login/logout/refresh/me`, AuthState enum
  - **Files:** `flutter_app/lib/core/auth/auth_service.dart`, `auth_models.dart`, `auth_state.dart`
  - **AC:** 401 → auto logout; emit state changes
  - **Verify:** `auth_service_test.dart` pass
  - **Size:** M
- [ ] **V17-B1.2** `AuthStorage` wrapper `flutter_secure_storage` (KeyChain iOS) + bootstrap trong `main()`
  - **Files:** `core/auth/auth_storage.dart`, `main.dart` (edit)
  - **AC:** Token persist qua app restart; bootstrap chạy trước `runApp`
  - **Verify:** manual restart test
  - **Size:** S
- [ ] **V17-B1.3** Inject `Authorization: Bearer` header trong `ApiClient` + handle 401 trigger logout
  - **Files:** `core/api/api_client.dart` (edit)
  - **AC:** Token tự động attach; 401 emit AuthService.logout
  - **Verify:** integration test với mock 401 response
  - **Size:** S
- [ ] **V17-B2.1** `WelcomeScreen` + `SignupScreen`: form 3 field + ToS checkbox, validate on blur
  - **Files:** `features/auth/screens/welcome_screen.dart`, `signup_screen.dart`, `widgets/auth_text_field.dart`, `password_strength_meter.dart`, `password_visibility_toggle.dart`
  - **AC:** submit disabled khi invalid; first invalid field auto-focus on error; iOS keyboard `emailAddress`/`newPassword`
  - **Verify:** widget tests
  - **Size:** L (5 files)
- [ ] **V17-B2.2** `LoginScreen`: email + password + forgot link
  - **Files:** `features/auth/screens/login_screen.dart`
  - **AC:** show/hide password; error inline; forgot link navigate
  - **Verify:** widget test
  - **Size:** S
- [ ] **V17-B3.1** `VerifyPendingScreen` với 60s cooldown resend + change email link
  - **Files:** `features/auth/screens/verify_pending_screen.dart`, `widgets/cooldown_button.dart`
  - **AC:** countdown chính xác; tap resend → call API + reset cooldown
  - **Verify:** widget test cooldown timer
  - **Size:** S
- [ ] **V17-B3.2** `ForgotPasswordScreen` + `ResetPasswordScreen` (deep link entry)
  - **Files:** `features/auth/screens/forgot_password_screen.dart`, `reset_password_screen.dart`
  - **AC:** forgot 200 + toast; reset → redirect login
  - **Verify:** widget test
  - **Size:** M
- [ ] **V17-B3.3** Deep link handler: parse `czechgo://verified` + `czechgo://reset?token=...` + `Info.plist` URL scheme registration
  - **Files:** `core/deep_links/deep_link_handler.dart`, `ios/Runner/Info.plist` (edit)
  - **AC:** Test bằng `xcrun simctl openurl booted czechgo://verified`
  - **Verify:** manual device test
  - **Size:** S
- [ ] **V17-B4.1** `AppShell` routing swap dựa trên AuthService state
  - **Files:** `features/shell/app_shell.dart` (rewrite), `core/auth/auth_state_router.dart`
  - **AC:** loading→splash; unauth→Welcome; auth→HomeShell; needsVerify+grace=0→block banner
  - **Verify:** widget test all 4 states
  - **Size:** M

**[CHECKPOINT V17-B]** `make flutter-analyze` + `make flutter-test` pass; manual signup→verify→login trên device

### Phase C — Profile + Streak (3 ngày)

- [ ] **V17-C1.1** `ProfileScreen` augment: thêm sections Account / Học tập / Pro / Đăng xuất; giữ existing locale + interview prefs
  - **Files:** `features/profile/screens/profile_screen.dart` (edit), `widgets/profile_section.dart`
  - **AC:** không break existing prefs; logout confirm dialog
  - **Verify:** widget test sections render đủ
  - **Size:** M
- [ ] **V17-C1.2** `ChangePasswordScreen` + `EmailChangeScreen`
  - **Files:** `features/profile/screens/change_password_screen.dart`, `email_change_screen.dart`
  - **AC:** current password validation; success → toast + back
  - **Verify:** widget test
  - **Size:** S
- [ ] **V17-C1.3** `AvatarPicker` widget: `image_picker` + crop + upload `/v1/users/me/avatar`
  - **Files:** `features/profile/widgets/avatar_picker.dart`, `pubspec.yaml` (add deps)
  - **AC:** preview; upload progress; error retry
  - **Verify:** manual device
  - **Size:** S
- [ ] **V17-C1.4** Account deletion flow với double-confirm dialog (App Store 5.1.1v requirement)
  - **Files:** `features/profile/widgets/delete_account_dialog.dart`
  - **AC:** 2-step confirm; nhập "XÓA" để confirm
  - **Verify:** widget test confirm flow
  - **Size:** S
- [ ] **V17-C2.1** `OnboardingScreen` 3 step (goal/level/reminder) + skip button
  - **Files:** `features/auth/screens/onboarding_screen.dart`, `widgets/onboarding_step.dart`, `progress_dots.dart`, `time_picker_field.dart`
  - **AC:** skip→Home với defaults; submit→PATCH /me + Home
  - **Verify:** widget tests
  - **Size:** M
- [ ] **V17-C3.1** `StreakRingWidget` (Home top): 12 con số + 7 dots last week + spring animation
  - **Files:** `features/home/widgets/streak_ring_widget.dart`
  - **AC:** spring 280ms; reduced-motion → static; tap→history; a11y label "12 ngày liên tục"
  - **Verify:** widget test + golden test
  - **Size:** S
- [ ] **V17-C3.2** `StreakHistoryScreen` calendar heatmap 12 tuần
  - **Files:** `features/home/screens/streak_history_screen.dart`, `widgets/calendar_heatmap.dart`
  - **AC:** show grace pass left; color intensity by completion
  - **Verify:** widget test
  - **Size:** M
- [ ] **V17-C3.3** Home augment: StreakRing top + Pro banner nếu free + verify banner nếu chưa verify
  - **Files:** `features/home/screens/home_screen.dart` (edit)
  - **AC:** banners conditional render đúng state
  - **Verify:** widget test mỗi state
  - **Size:** S

**[CHECKPOINT V17-C]** Manual: profile edit → onboarding → streak tick (làm 1 attempt → streak +1)

### Phase D — Paywall + IAP (4 ngày)

- [ ] **V17-D1.1** App Store Connect: tạo bundle `eu.hadoo.czechgo`, subscription group `pro`, 2 product IDs (placeholder pricing)
  - **Manual task** — không code
  - **AC:** Sandbox tester account ready; ASSN V2 endpoint configured
- [ ] **V17-D2.1** Add `in_app_purchase: ^3.x` + `IAPService` wrapper
  - **Files:** `pubspec.yaml`, `features/paywall/services/iap_service.dart`
  - **AC:** load products từ StoreKit; buy/restore stream listener
  - **Verify:** unit test mock StoreKit
  - **Size:** M
- [ ] **V17-D2.2** `PaywallScreen` + comparison table + monthly/yearly toggle + restore button
  - **Files:** `features/paywall/screens/paywall_screen.dart`, `widgets/pro_comparison_table.dart`, `restore_purchase_button.dart`, `monthly_yearly_toggle.dart`
  - **AC:** giá hiển thị từ StoreKit (không hardcode); restore button visible (Apple HIG)
  - **Verify:** widget test
  - **Size:** L (4 files)
- [ ] **V17-D2.3** `ProSuccessScreen`: confetti animation (skip nếu reduced-motion) + "Bắt đầu" CTA
  - **Files:** `features/paywall/screens/pro_success_screen.dart`, `widgets/confetti_overlay.dart`
  - **AC:** reduced-motion → static checkmark
  - **Verify:** widget test
  - **Size:** S
- [ ] **V17-D2.4** Buy flow: paywall→StoreKit sheet→backend verify→success/error
  - **Files:** `features/paywall/services/iap_service.dart` (extend)
  - **AC:** pending transaction cleanup; error retry
  - **Verify:** sandbox manual 5 mua thành công
  - **Size:** M
- [ ] **V17-D3.1** Backend: hardening verifyReceipt (retry + timeout + structured logging)
  - **Files:** `iap/apple_verify.go` (edit)
  - **AC:** 3 retry expo backoff; timeout 10s; log JSON structured
  - **Verify:** unit test retry logic
  - **Size:** S
- [ ] **V17-D3.2** Backend: webhook idempotency table `iap_webhook_events` (notificationUUID PK, processed_at)
  - **Files:** migration `025_iap_webhook_events.sql`, `iap/apple_webhook.go` (edit)
  - **AC:** Duplicate UUID xử lý 1 lần
  - **Verify:** test gửi duplicate webhook
  - **Size:** S
- [ ] **V17-D4.1** Quota indicator widget Home: "3/7 attempts hôm nay" (hide cho Pro)
  - **Files:** `features/home/widgets/usage_quota_indicator.dart`, `home_screen.dart` (edit)
  - **AC:** update sau mỗi attempt; Pro user không thấy
  - **Verify:** widget test
  - **Size:** S
- [ ] **V17-D4.2** `UpgradePromptDialog` khi nhận 429 từ backend
  - **Files:** `features/exercise/widgets/upgrade_prompt_dialog.dart`
  - **AC:** modal với CTA → Paywall
  - **Verify:** widget test trigger trên 429
  - **Size:** S

**[CHECKPOINT V17-D]** Sandbox 5 mua thành công; webhook test pass; TestFlight beta deploy

### Phase E — Cutover (1 ngày)

- [ ] **V17-E1.1** Pre-cutover checklist: SES production access ✅, Apple agreement signed, App Privacy form filled, Privacy + ToS URLs live, account deletion + data export tested manual, backup snapshot ready, rollback image tag `pre-v17` ready, CMS deploy new `/learners`, TestFlight ổn định 48h
- [ ] **V17-E2.1** Cutover sequence:
  1. Backup Postgres `pg_dump` → S3
  2. Maintenance mode 503 (5 phút)
  3. Run scrub: `TRUNCATE attempts, mock_exam_sessions, mock_exam_sections, full_exam_sessions, attempt_feedbacks, attempt_review_artifacts CASCADE`
  4. Run migration `023_users.sql`
  5. Deploy backend `v17.0.0`
  6. Disable maintenance mode
  7. Smoke test: signup → verify → login → attempt → success
  8. Submit Flutter v17.0.0 production
  - **Files:** `scripts/cutover-v17.sh`, `scripts/scrub-attempts.sql`
  - **AC:** smoke pass; zero error trong 5 phút post-cutover
  - **Size:** S
- [ ] **V17-E2.2** 24h monitoring: SES bounce rate, signup vs verified ratio, login p95 latency, attempt 429 rate, IAP success rate
  - **AC:** không hit rollback trigger condition
  - **Manual task**

**[CHECKPOINT V17-FINAL]**
- [ ] `make backend-test` pass (target: 320+ tests)
- [ ] `make flutter-test` pass (target: 200+ tests)
- [ ] `cd cms && npm test` pass
- [ ] `make smoke-all` xanh
- [ ] Manual TestFlight 48h ổn định
- [ ] Cutover smoke test pass
- [ ] 24h post-cutover metrics OK
- [ ] Rollback plan tested staging

---

## V18 — Dictation Exercise (`psani_3_dictation`)

Spec: `docs/specs/dictation-exercise.md` · Plan: `tasks/plan.md § V18` · SPEC.md: § V18

### Phase A — Backend foundation (1.5 ngày)

- [x] **V18-A1.1** Contracts: `DictationDetail`, `DictationSentence`, `DictationSubmission`, `DictationSentenceAnswer`, `DictationFeedback`, `DictationSentenceScore` + `ExerciseDetail.DictationDetail()` getter
  - **Files:** `backend/internal/contracts/types.go`
  - **AC:** `make backend-build` pass; JSON tags exact match spec § 4.1
  - **Verify:** unit test parse + nil-on-wrong-type
  - **Size:** S
- [x] **V18-A2.1** Levenshtein scorer + diacritic pair table + normalize
  - **Files:** `backend/internal/processing/dictation_scorer.go` (new), `dictation_scorer_test.go` (new)
  - **AC:** 15 diacritic pairs cost 0.5; normalize NFC + lowercase + collapse; empty/identical edge cases
  - **Verify:** 10+ test cases incl. perfect, all-diacritics-stripped (≥ 50%), totally-different (= 0), empty
  - **Size:** M
- [x] **V18-A3.1** LLM config + prompt + provider + fallback
  - **Files:** `processing/llm_config.go` (edit), `llm_prompts.go` (edit — `DictationSystemPrompt`), `llm_user_prompts.go` (edit — `buildDictationUserPrompt`), `llm_fallbacks.go` (edit), `processing/dictation_llm.go` (new — interface + Claude impl + nil fallback)
  - **AC:** All prompt strings stay in SoT files (per AGENTS.md); env var `LLM_DICTATION_MODEL` loads
  - **Verify:** mock provider returns correct annotation shape
  - **Size:** M
- [x] **V18-A4.1** DB migration: `exercise_audios.sentence_idx` nullable + composite index
  - **Files:** `backend/internal/store/postgres_exercise_audio.go` (edit), `backend/internal/store/exercise_audio.go` (interface edit)
  - **AC:** `addColumnIfMissing` adds column; index created; existing audio rows untouched
  - **Verify:** start backend twice — second run no-op; existing poslech audio still readable
  - **Size:** S
- [x] **V18-A5.1** Admin per-sentence audio endpoint + Polly client wrap
  - **Files:** `backend/internal/httpapi/admin_dictation_audio.go` (new), `processing/exercise_audio.go` (edit — `GenerateSentenceAudio`), `httpapi/server.go` (edit — register routes)
  - **AC:** POST creates MP3 + DB row; DELETE removes both; non-admin → 403; text > 250 → 400
  - **Verify:** integration test in `httpapi/admin_dictation_audio_test.go`
  - **Size:** M

**[CHECKPOINT V18-A]** `make backend-build && make backend-test` pass with +10 tests

### Phase B — Backend integration (0.5 ngày)

- [x] **V18-B1.1** Dispatch `submit-text` on exercise_type → dictation goroutine
  - **Files:** `backend/internal/httpapi/attempts.go` (edit)
  - **AC:** body cap 16 KB; sentence count mismatch → 400 `invalid_sentence_count`; sentence > 200 chars → 400 `sentence_too_long`; goroutine has `defer recover()` → FailAttempt; `replay_counts` saved to `attempts.details_json`
  - **Verify:** unit test handler branching
  - **Size:** M
- [x] **V18-B2.1** Integration test
  - **Files:** `backend/internal/httpapi/dictation_test.go` (new)
  - **AC:** 7 tests — happy, diacritic-only ≥ 50%, wrong count, too-long, body-too-large, LLM fail fallback, audio gen
  - **Verify:** `go test ./internal/httpapi -run TestSubmitDictation` pass
  - **Size:** M

**[CHECKPOINT V18-B]** Backend test count ≥ +10; smoke `curl` POST submit-text với dictation payload returns valid result

### Phase C — CMS authoring (1 ngày)

- [x] **V18-C1.1** `DictationFields` component
  - **Files:** `cms/components/exercise-form/DictationFields.tsx` (new)
  - **AC:** topic + image + transcript + sentence repeater (Polly per row + preview + delete) + voice/replay/points/threshold inputs; inline validation banner
  - **Verify:** Storybook-style render với 6-sentence mock
  - **Size:** L
- [x] **V18-C2.1** Utils: split, validate, payload, formState
  - **Files:** `cms/components/exercise-form/exercise-utils.ts` (edit)
  - **AC:** `splitTranscriptIntoSentences` handles `Mgr.`/`Dr.`/`Bc.`/`Ph.D.`/`pan.`/`ing.` abbreviations; `validateDictation` enforces 3..8 sentences, 1..200 char each, audio_asset_id required, replay 0..10
  - **Verify:** Vitest in C4
  - **Size:** M
- [x] **V18-C3.1** Proxy routes for sentence audio
  - **Files:** `cms/app/api/admin/exercises/[exerciseId]/dictation/sentences/[idx]/audio/route.ts` (new)
  - **AC:** POST + DELETE thread `admin_token` cookie; forward to backend
  - **Verify:** route response shape match backend
  - **Size:** S
- [x] **V18-C4.1** i18n + Vitest
  - **Files:** `cms/lib/i18n.tsx` (edit), `cms/components/__tests__/dictation-fields.test.ts` (new)
  - **AC:** 8 VI+EN keys; +5 Vitest minimum (split basic, split keeps abbreviations, split trims empty, validate min/max, validate missing audio, payload shape)
  - **Verify:** `cd cms && npm test` pass
  - **Size:** M
- [x] **V18-C5.1** Wire vào slide-over + skill_kind + pool filter
  - **Files:** `cms/components/exercise-form/index.tsx` (edit)
  - **AC:** dropdown shows `Chính tả (psani_3_dictation)` only khi skill=`viet` && pool=`course`; submit gated by `validateDictation`
  - **Verify:** manual click-through CMS
  - **Size:** S

**[CHECKPOINT V18-C]** `make cms-lint && cd cms && npm test && make cms-build` pass; admin authors test exercise end-to-end với 6 câu Polly

### Phase D — Flutter (2 ngày)

- [x] **V18-D1.1** Models parser
  - **Files:** `flutter_app/lib/models/models.dart` (edit), `flutter_app/test/dictation_models_test.dart` (new)
  - **AC:** parse `DictationDetail`/`DictationSentence`/`DictationSentenceScore` from JSON; `ExerciseDetail.dictationDetail` getter returns null cho non-dictation
  - **Verify:** +3 tests
  - **Size:** S
- [x] **V18-D2.1** `DictationAudioCard` widget
  - **Files:** `flutter_app/lib/features/exercise/widgets/dictation_audio_card.dart` (new), test
  - **AC:** auto-play once on mount (no count); manual repeat increments counter; disable at cap; `maxReplays=0` unlimited
  - **Verify:** +3 widget tests
  - **Size:** M
- [x] **V18-D3.1** `CzechKeyboardChips` widget
  - **Files:** `flutter_app/lib/features/exercise/widgets/czech_keyboard_chips.dart` (new), test
  - **AC:** 13 chip glyphs; tap inserts at cursor; 44pt min target; semantics labels
  - **Verify:** +2 widget tests
  - **Size:** S
- [x] **V18-D4.1** `DictationExerciseScreen` stepper
  - **Files:** `flutter_app/lib/features/exercise/screens/dictation_exercise_screen.dart` (new), test
  - **AC:** initial idx=0; Next disabled empty; last → Submit; Prev preserves text; `AutomaticKeepAliveClientMixin`; back-confirm dialog when dirty
  - **Verify:** +6 widget tests (initial state, Next gate, Prev preserve, Submit triggers API, last-sentence label, replay-cap doesn't block submit)
  - **Size:** L
- [x] **V18-D5.1** `DictationResultCard` 3-tab + diff highlight
  - **Files:** `flutter_app/lib/features/exercise/widgets/dictation_result_card.dart` (new), test
  - **AC:** 3 tabs render; accuracy bar color (green ≥ 80%, orange < 80%); LLM-empty fallback banner; reuse `_DiffTextBlock`
  - **Verify:** +4 widget tests
  - **Size:** M
- [x] **V18-D6.1** `submitDictation` API client
  - **Files:** `flutter_app/lib/core/api/api_client.dart` (edit)
  - **AC:** Czech UTF-8 chars > U+00FF round-trip OK (V2 fix verified); payload shape match backend
  - **Verify:** unit test
  - **Size:** S
- [x] **V18-D7.1** i18n ARB keys VI+EN
  - **Files:** `flutter_app/lib/l10n/app_vi.arb`, `app_en.arb` (edit)
  - **AC:** 10 keys (xem SPEC.md § V18); VI=EN count
  - **Verify:** `make flutter-analyze` no missing-l10n warning
  - **Size:** S
- [x] **V18-D8.1** Router dispatch psani_3_dictation
  - **Files:** dispatcher equivalent (next to where `WritingExerciseScreen` is pushed today)
  - **AC:** dictation exercises route đúng screen; reading/listening/writing routes intact
  - **Verify:** manual smoke + 1 navigation test
  - **Size:** S

**[CHECKPOINT V18-D]** `make flutter-analyze && make flutter-test` pass with +10 tests; manual: TestFlight build dictation flow end-to-end

### Phase E — End-to-end (0.5 ngày)

- [x] **V18-E1.1** Manual acceptance MAN-1..MAN-8 (xem SPEC.md § V18 Verification)
  - Admin author 6 câu → Polly per row → publish
  - Learner perfect text → 10/10 PASS
  - Learner ref minus diacritics → 50–70%
  - Repeat 3× câu 2 → button disable
  - Submit fail (mạng off) → text not lost
  - Background app → state preserved
  - Tab Sửa bài → diff highlight green/red
  - LLM mock fail → deterministic-only diff renders
  - **Manual task** — không code
- [x] **V18-E2.1** Smoke extension
  - **Files:** `scripts/smoke_attempt_flow.py` (or equivalent — extend với dictation case)
  - **AC:** `make smoke-attempt-flow` pass với dictation submit
  - **Size:** S
- [x] **V18-E3.1** `make verify` final
  - **AC:** all CI green; backend tests ≥ +10; Flutter ≥ +10; CMS ≥ +5

**[CHECKPOINT V18-FINAL]**
- [x] `make backend-test` pass (target: 462+ tests)
- [x] `make flutter-test` pass (target: 211+ tests)
- [x] `cd cms && npm test` pass (target: 100+ tests)
- [x] `make smoke-all` xanh
- [x] Manual MAN-1..MAN-8 pass
- [ ] CMS guide page updated với dictation section *(deferred — V18.2 docs slice)*
- [x] No regression: existing `psani_1_formular` + `psani_2_email` submissions still work end-to-end

---

## V18.1 — Dictation OCR Submission

Spec: `docs/specs/dictation-ocr.md` · Idea: `docs/ideas/dictation-ocr.md` · Plan: `tasks/plan.md § V18.1` · SPEC.md: § V18.1
Estimated: ~4 ngày dev

### Phase A — Backend foundation (1 ngày)

- [x] **V18.1-A1** Contracts + SubmissionMode field
  - **Files:** `backend/internal/contracts/types.go`
  - **AC:** `SubmissionMode` JSON field on `DictationDetail` + `Mode()` getter (default `"type"`); `DictationOCRPreviewResponse` + `DictationOCRSentenceSubmission` structs; backward-compat with V18 deserialize
  - **Verify:** unit test parse + Mode() default
  - **Size:** S
- [x] **V18.1-A2** Claude Vision OCR provider
  - **Files:** `processing/dictation_ocr.go` (new), `dictation_ocr_test.go` (new), `processing/llm_config.go` (edit), `llm_prompts.go` (edit), `llm_user_prompts.go` (edit)
  - **AC:** `OCRProvider` interface + `ClaudeVisionOCR` impl (Anthropic messages API + image content block); `NoopOCR` fallback; env `LLM_OCR_MODEL` (default `claude-opus-4-7`); prompts in SoT files; fail-soft empty string on HTTP error
  - **Verify:** test happy / 4xx / malformed JSON
  - **Size:** M
- [x] **V18.1-A3** Storage helper for attempt-scoped images *(folded into A4 — repo uses file-based storage; no DB table for media_assets exists; storage key serves as asset_id; storagePrefix `dictation-ocr/<attempt_id>/`)*
- [x] **V18.1-A4** Preview endpoint
  - **Files:** `backend/internal/httpapi/attempt_dictation_ocr.go` (new), `httpapi/server.go` (edit)
  - **AC:** `POST /v1/attempts/:id/dictation-ocr-preview` multipart; ownership; MaxBytesReader 5MB; MIME whitelist jpeg/png/heic; idx 0..7; persist via media_assets with attempt_id; return `{idx, text, asset_id}`; per-user RL 30/min; OCR fail → 200 empty text
  - **Verify:** integration test 6 cases (size, mime, idx, owner, non-dictation, ocr fail)
  - **Size:** M

**[CHECKPOINT V18.1-A]** `make backend-build && make backend-test` pass +5 tests; manual `curl` preview returns OCR text

### Phase B — Backend integration (0.5 ngày)

- [x] **V18.1-B1** Submit endpoint + processor branch
  - **Files:** `httpapi/attempt_dictation_ocr.go` (edit), `processing/dictation_processor.go` (edit)
  - **AC:** `POST /v1/attempts/:id/submit-dictation-ocr` multipart `sentences` JSON; lazy-OCR for empty-text+image rows; reuse `ProcessDictationAttempt`; `submission_mode: "ocr"` in feedback_json; count mismatch → 400; payload >40MB → 413; goroutine recover()
  - **Verify:** unit test handler branching
  - **Size:** M
- [x] **V18.1-B2** Integration tests
  - **Files:** `httpapi/attempt_dictation_ocr_test.go`
  - **AC:** 4 tests — preview happy, submit happy, submit lazy-OCR, score parity (typed vs OCR identical OverallScore)
  - **Verify:** `go test -run TestDictationOCR` pass
  - **Size:** M

**[CHECKPOINT V18.1-B]** Backend test count ≥+8

### Phase C — CMS authoring (0.5 ngày)

- [x] **V18.1-C1** CMS submission_mode dropdown
  - **Files:** `cms/components/exercise-form/DictationFields.tsx`
  - **AC:** `<select>` Type/OCR/Both với i18n labels + inline hint per choice; saves into payload
  - **Size:** S
- [x] **V18.1-C2** Validation + payload utils
  - **Files:** `cms/components/exercise-form/exercise-utils.ts`
  - **AC:** `validateDictation` enum check; `formStateFromExercise` reads existing; `dictationPayload` includes field; default `"type"` when missing
  - **Size:** S
- [x] **V18.1-C3** i18n + Vitest *(inline VI in DictationFields per existing form-fields convention; i18n.tsx scope is sidebar/dashboards only — no diff needed there)*
  - **Files:** `cms/lib/i18n.tsx`, `cms/components/__tests__/dictation-fields.test.ts`
  - **AC:** 4 admin i18n keys; +4 Vitest cases
  - **Verify:** `cd cms && npm test` pass
  - **Size:** S

**[CHECKPOINT V18.1-C]** `make cms-lint && cd cms && npm test && make cms-build` pass

### Phase D — Flutter (1.5 ngày)

- [x] **V18.1-D1** Models parser submissionMode
  - **Files:** `flutter_app/lib/models/models.dart`, `test/dictation_models_test.dart`
  - **AC:** Parses 3 modes; defaults `"type"` when key absent; +1 test
  - **Size:** S
- [x] **V18.1-D2** `DictationOCRPreviewCard` widget
  - **Files:** `flutter_app/lib/features/exercise/widgets/dictation_ocr_preview_card.dart` (new), `test/dictation_ocr_preview_card_test.dart` (new)
  - **AC:** Thumbnail 16:9 + editable TextField + Retake/Confirm buttons; `isUploading` swap to spinner; callbacks
  - **Verify:** +3 widget tests
  - **Size:** M
- [x] **V18.1-D3** Mode-toggle pill (for "both")
  - **Files:** Inline trong `dictation_exercise_screen.dart`
  - **AC:** Per-sentence segmented pill (Type/Camera) khi `submissionMode=="both"`; persists across Prev/Next
  - **Verify:** +1 widget test
  - **Size:** S
- [x] **V18.1-D4** `DictationExerciseScreen` branch
  - **Files:** `flutter_app/lib/features/exercise/screens/dictation_exercise_screen.dart`
  - **AC:** Branch on submissionMode; OCR path: hide TextField → camera button → image_picker(camera, maxWidth 1024, q 85) → upload preview → render PreviewCard → confirm locks → Next; Both: per-sentence toggle; Submit dispatches OCR endpoint if any OCR sentence else V18 endpoint
  - **Verify:** +4 widget tests
  - **Size:** L
- [x] **V18.1-D5** API client methods
  - **Files:** `flutter_app/lib/core/api/api_client.dart`
  - **AC:** `dictationOCRPreview(attemptId, idx, file)` + `submitDictationOCR(attemptId, sentences, files)` multipart; UTF-8 round-trip
  - **Verify:** +1 unit test
  - **Size:** M
- [x] **V18.1-D6** Flutter i18n ARB
  - **Files:** `flutter_app/lib/l10n/app_vi.arb`, `app_en.arb`
  - **AC:** 8 keys per spec § 5; VI=EN count
  - **Verify:** `make flutter-analyze` no missing-l10n
  - **Size:** S

**[CHECKPOINT V18.1-D]** `make flutter-analyze && make flutter-test` pass +6 widget tests; manual TestFlight OCR end-to-end

### Phase E — End-to-end + pilot (0.5 ngày)

- [ ] **V18.1-E1** Manual acceptance MAN-1..MAN-8
  - Per SPEC.md § V18.1 Verification — manual, không code
- [ ] **V18.1-E2** Pilot gold set
  - **Files:** `scripts/dictation_ocr_pilot.py` (new) hoặc spreadsheet
  - **AC:** 20 photos × 6 sentences × 5 learners; CER ≤10% averaged → gates default-mode promotion in V18.2; result saved `docs/pilot/dictation-ocr-results.md`
- [ ] **V18.1-E3** `make verify` final
  - **AC:** Backend +8, Flutter +6, CMS +4; `make verify` xanh

**[CHECKPOINT V18.1-FINAL]**
- [ ] Backend test target ≥ 470
- [ ] Flutter test target ≥ 207
- [ ] CMS test target ≥ 99
- [ ] Manual MAN-1..MAN-8 pass on TestFlight
- [ ] Pilot CER ≤10% verdict documented
- [ ] No regression: V18 type-mode dictation submissions still work
- [ ] Backward-compat: pre-V18.1 dictation exercises (no `submission_mode`) default to `"type"`

---

## V21 — CEFR Level Progression (A0 → B1)

Detail in `tasks/cefr-level-progression-todo.md`. Plan
`tasks/cefr-level-progression-plan.md`. Spec
`docs/specs/cefr-level-progression.md`.

Phases A (schema + config) → B (gating service + 4 endpoints + course
mods + atomic promotion hook) → C (CMS form fields) → D (Flutter
onboarding + home + lock states + promotion flow) → E (smoke + manual
+ verify). Targets: backend +45, Flutter +32, CMS +6.
