# Todo — Skills Expansion V2→V5

Cập nhật: 2026-04-27. Xem chi tiết + AC trong `tasks/plan.md`.

---

## V2 — Psaní (Writing) — Viết

- [ ] **W1** Backend contracts: `Psani1Detail`, `Psani2Detail`, `WritingSubmission` + exercise_type validation
- [ ] **W2** Backend writing attempt flow: `POST /v1/attempts/:id/submit-text` + `writing_scorer.go` + LLM writing feedback
- [ ] **W3** CMS: forms cho `psani_1_formular` và `psani_2_email`
- [ ] **W4** Flutter: `WritingExerciseScreen` + word count validation + `WritingResultCard` (corrected text + diff + criteria)

**[CHECKPOINT W]** `make backend-build && make backend-test && make cms-build && make flutter-analyze`

---

## V3 — Poslech (Listening) — Nghe

- [ ] **L1** Backend contracts: `Poslech1-5Detail` types + exercise audio infra (`GET /v1/exercises/:id/audio` + `POST /v1/admin/exercises/:id/generate-audio` + migration 010)
- [ ] **L2** Backend objective scoring: `POST /v1/attempts/:id/submit-answers` + `objective_scorer.go` (sync, no polling needed)
- [ ] **L3** CMS: forms cho 5 poslech types (audio upload OR text→Polly generate button + audio preview)
- [ ] **L4** Flutter: `ListeningExerciseScreen` + `AudioPlayerWidget` + answer widgets (`MultipleChoiceWidget`, `MatchWidget`, `FillInWidget`) + `ObjectiveResultCard`

**[CHECKPOINT L]** `make backend-build && make backend-test && make cms-build && make flutter-analyze`

---

## V4 — Čtení (Reading) — Đọc

- [ ] **R1** Backend contracts: `Cteni1-5Detail` types + validation
- [ ] **R2** Backend: extend `objective_scorer.go` với Cteni types + fuzzy fill-in matching
- [ ] **R3** CMS: forms cho 5 cteni types (cteni_1 image upload, cteni_2/4 text+options, cteni_3 text+persons, cteni_5 text+fill)
- [ ] **R4** Flutter: `ReadingExerciseScreen` + `ImageMatchWidget` + `MatchTextWidget` + reuse widgets từ V3

**[CHECKPOINT R]** `make backend-build && make backend-test && make cms-build && make flutter-analyze`

---

## V5 — Full MockTest (4 kỹ năng)

- [ ] **M1** Data model: migration 011 (`full_exam_sessions` table + `session_type` trên `mock_tests`) + contracts
- [ ] **M2** Backend: `POST /v1/full-exams` + `GET /v1/full-exams/:id` + `full_exam_scorer.go` (písemná: ≥42/70, ústní: ≥24/40)
- [ ] **M3** CMS: MockTest builder với `session_type` dropdown + písemná section picker (cteni+psani+poslech) + full exam linker
- [ ] **M4** Flutter: `FullExamIntroScreen` + extend `MockExamScreen` cho písemná sections + `FullExamResultScreen` (2-panel pass/fail)

**[CHECKPOINT M]** `make verify`

---

## Backlog (sau V5)

- [ ] Polly 2 voices cho `poslech_4` dialogs (upgrade từ Option B)
- [ ] Polly đọc `model_answer_text` cho Writing
- [ ] Learner history filter theo skill_kind
- [ ] Admin analytics: pass rate per exercise_type
