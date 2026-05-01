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
