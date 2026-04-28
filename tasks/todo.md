# Todo — Skills Expansion V2→V6

Cập nhật: 2026-04-27. Xem chi tiết + AC trong `tasks/plan.md`.

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

- [ ] **VG-A** Migrations 013-016 (Go-side ID, no DB DEFAULT):
  013: `vocabulary_sets` + `vocabulary_items`;
  014: `grammar_rules`;
  015: `content_generation_jobs` (provider/model/tokens/cost/duration fields);
  016: `exercises` ADD `source_type`/`source_id`/`generation_job_id` NULL.
  Go contracts: `VocabularySet`, `VocabularyItem`, `GrammarRule`, `ContentGenerationJob`,
  `MatchingDetail` (pairs with left_id/right_id, correct_answers option-key), `QuizcardBasicDetail`,
  `FillBlankDetail`, `ChoiceWordDetail`, `GeneratedExercise`, `GeneratedPayload`.
  Store interfaces: `VocabularyStore`, `GrammarStore`, `GenerationJobStore` + memory impls.
  Update `postgres_exercises.go` CreateExercise/UpdateExercise for 3 new columns.
  Flutter `models.dart`: `isVocabGrammar`/`isQuizcard`/`isMatching`/`isFillBlank`/`isChoiceWord` + parsed fields + `MatchingPairView`.

- [ ] **VG-B** Backend API + LLM:
  `content_generator.go`: `ContentGenerator` interface + `ClaudeContentGenerator` (tool_use) + `MockContentGenerator`.
  `exercise_validator.go`: `ValidateExercisePayload()` + `BuildExerciseFromDraft()` — shared by HTTP handler + publish.
  `ensureSkill(moduleID, skillKind)` auto-create.
  Server startup: `repo.MarkAllRunningJobsFailed("Server restarted")`.
  CRUD routes: /admin/vocabulary-sets (+items), /admin/grammar-rules.
  POST /admin/content-generation-jobs: rate limit per-admin-per-module (409), spawn goroutine.
  GET .../jobs/:id (poll), PATCH .../draft, POST .../publish (validate-all atomic), POST .../reject.
  `skillKindForExerciseType` allowlist for 4 new types.
  Quizcard: score=1/1, store known/review in transcript_json.quizcard_result.
  Source fields (source_type/source_id/generation_job_id) set on every exercise created at publish.

- [ ] **VG-C** CMS `/vocabulary` page: VocabularySet list + modal (word list table, paste support) +
  GenerationScopePanel + 2s poll spinner + `DraftReviewPanel` with per-type editors:
  `QuizcardDraftEditor` / `ChoiceWordDraftEditor` / `FillBlankDraftEditor` / `MatchingDraftEditor`
  (each with real-time validation) + [Save Draft] [Publish] [Reject] [New Generation] buttons.

- [ ] **VG-D** CMS `/grammar` page: GrammarRule list + modal (conjugation key-value table, constraints) +
  GenerationScopePanel (fill_blank + choice_word default, matching optional, no quizcard) +
  same DraftReviewPanel + publish flow.

- [ ] **VG-E** Flutter: `VocabGrammarExerciseScreen` router +
  `QuizcardWidget` (200ms flip, Đã biết/Ôn lại, no score display, "Ghi nhận!") +
  `MatchingWidget` (tap-to-connect, color-coded pairs, [Nộp] when all connected) +
  reuse `FillInWidget` + `MultipleChoiceWidget` from V3 +
  `_exerciseMatchesSkillKind` tu_vung/ngu_phap routing + 8 ARB i18n keys.

**[CHECKPOINT VG]** `make backend-build && make backend-test && make cms-build && make flutter-analyze`

---

## Backlog (sau V5)

- [ ] Polly 2 voices cho `poslech_4` dialogs (upgrade từ Option B)
- [ ] Polly đọc `model_answer_text` cho Writing
- [ ] Learner history filter theo skill_kind
- [ ] Admin analytics: pass rate per exercise_type
- [x] V5: FullExamIntroScreen capture real attempt_id (hiện dùng placeholder 'done-N')
- [ ] V5: Auto-link ústní session sau khi mock exam speaking hoàn tất
- [ ] V5: Postgres store cho full_exam_sessions (hiện in-memory)
