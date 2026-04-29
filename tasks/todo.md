# Todo — Skills Expansion V2→V6

Cập nhật: 2026-04-29. Xem chi tiết + AC trong `tasks/plan.md`.
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

- [ ] **SP-1** Backend: `pass_threshold_percent` field trên `MockTest` + `MockExamSession`;
      ALTER TABLE + update INSERT/SELECT/UPDATE; `computeScoring` nhận threshold param;
      `CompleteMockExam` đọc threshold từ session row
- [ ] **SP-2a** CMS: bỏ `session_type` field khỏi form; thêm `pass_threshold_percent` input
      (default=80); update payload + display danh sách
- [ ] **SP-2b** Flutter: di chuyển `onAttemptCompleted?.call(attemptId)` trong
      `WritingExerciseScreen._submit()` xuống SAU `await Navigator.push(AnalysisScreen)`
      (1-line move — Listening + Reading đã OK, callbacks đã tồn tại đúng chỗ)
- [ ] **SP-3** Flutter: `MockExamScreen._runSection()` route theo `exercise_type` prefix
      (`uloha_`→speaking, `poslech_`→listening, `cteni_`→reading, `psani_`→writing);
      non-speaking sections advance mock exam ngay; `_bulkAnalyze` chỉ cho speaking;
      result view hiển thị pass threshold

**[CHECKPOINT SP]** `make verify` + manual: tạo sprint 2 sections (1 nói + 1 nghe),
  làm bài, kết quả tính 80% threshold đúng

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
