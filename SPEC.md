# SPEC — A2 Mluvení Sprint: Skills Expansion V2→V9

Source: `tasks/plan.md` (2026-04-30). Kỳ thi: Modelový test A2, NPI ČR (platný od dubna 2026).

---

## 1. Objective

Mở rộng app luyện thi Czech A2 "trvalý pobyt" từ chỉ có **Nói** (đã xong) sang đủ 4 kỹ năng theo thứ tự:

| Version | Kỹ năng | Điểm thi | Phương pháp chấm |
|---|---|---|---|
| V2 | Psaní — Viết | 20đ (pass ≥12) | LLM (highlight lỗi + corrected text + criteria) |
| V3 | Poslech — Nghe | 25đ | Objective (đúng/sai, sync) |
| V4 | Čtení — Đọc | 25đ | Objective (đúng/sai, sync) |
| V5 | Full MockTest | 110đ tổng | 2 session: písemná (V2+V3+V4) + ústní (V1) |

**Target users:** Người Việt đang chuẩn bị thi A2 Czech để xin trạy pobyt.

**Non-goals:**
- Free-form AI tutoring
- Live teacher marketplace
- Pronunciation-first positioning
- Advanced analytics platform

---

## 2. Exercise Types (nguồn chuẩn: PDF Modelový test 2)

### V1 — Mluvení / Nói ✅ ĐÃ XONG
| exercise_type | Mô tả | Điểm |
|---|---|---|
| `uloha_1_topic_answers` | 8 câu / 2 chủ đề | 8 |
| `uloha_2_dialogue_questions` | 2 hội thoại, hỏi 4 thông tin | 12 |
| `uloha_3_story_narration` | Kể chuyện 4 tranh | 10 |
| `uloha_4_choice_reasoning` | Chọn 1/3 phương án + lý do | 7 |
| _(bonus)_ | Phát âm | 3 |

### V2 — Psaní / Viết
| exercise_type | Mô tả | Điểm |
|---|---|---|
| `psani_1_formular` | 3 câu hỏi form, mỗi câu ≥10 từ | 8 |
| `psani_2_email` | Email theo 5 ảnh, ≥35 từ | 12 |

### V3 — Poslech / Nghe
| exercise_type | Mô tả | Điểm |
|---|---|---|
| `poslech_1` | 5 đoạn ngắn → chọn A-D | 5 |
| `poslech_2` | 5 đoạn ngắn → chọn A-D | 5 |
| `poslech_3` | 5 đoạn → match A-G (2 dư) | 5 |
| `poslech_4` | 5 dialog → chọn ảnh A-F (1 dư) | 5 |
| `poslech_5` | Nghe voicemail → điền thông tin (5 ô) | 5 |

### V4 — Čtení / Đọc
| exercise_type | Mô tả | Điểm |
|---|---|---|
| `cteni_1` | Match 5 ảnh/tin nhắn → A-H (3 dư) | 5 |
| `cteni_2` | Đọc text → chọn A-D (5 câu) | 5 |
| `cteni_3` | Match 4 text → nhân vật A-E (1 dư) | 4 |
| `cteni_4` | Chọn A-D (6 câu) | 6 |
| `cteni_5` | Đọc text → điền thông tin (5 ô) | 5 |

---

## 3. Kiến trúc quyết định (frozen)

### Pool separation
```
pool=course  → Course → Module → Skill → Exercise  (luyện tập)
pool=exam    → MockTest → MockTestSection → Exercise (thi thử)
```
Cùng exercise_type nhưng **2 records riêng**. Admin tạo khóa học riêng + bài exam riêng.

### Attempt flows theo skill

**Speaking (V1 — đã có):**
```
POST /v1/attempts → POST /:id/upload-url → upload audio → POST /:id/upload-complete
→ async: Transcribe → LLM feedback → review artifact
→ GET /:id (poll until completed)
```

**Writing (V2):**
```
POST /v1/attempts → POST /:id/submit-text  {answers:[...] | text:"..."}
→ async: LLM writing feedback → review artifact (no Polly TTS)
→ GET /:id (poll until completed)
```

**Listening/Reading (V3/V4):**
```
POST /v1/attempts → POST /:id/submit-answers  {answers:{"1":"B",...}}
→ sync: objective scorer → completed immediately
→ GET /:id (returns completed, no polling needed)
```

### Writing review artifact
Reuse `AttemptReviewArtifact`. Mapping:
- `source_transcript_text` ← learner written text
- `corrected_transcript_text` ← LLM-corrected
- `model_answer_text` ← example answer
- `speaking_focus_items` ← writing error highlights
- `diff_chunks` ← text diff
- `tts_audio` ← **nil** (không dùng Polly cho writing)

### Listening audio source (V3)
Admin chọn 1 trong 2:
- Upload MP3/WAV trực tiếp
- Nhập Czech text → backend gọi Polly → 1 voice (Tomáš Czech neural) → 1 audio file

`poslech_4` dialog: segments `[{speaker:"A", text:...}, {speaker:"B", text:...}]` ghép tuần tự, 1 voice. Upgrade 2 voices là backlog.

### Objective scoring (V3/V4)
```go
// Shared cho cả listening và reading
AnswerSubmission { Answers map[int]string }
ObjectiveResult  { Score, MaxScore, Breakdown []QuestionResult }
QuestionResult   { QuestionNo, LearnerAnswer, CorrectAnswer, IsCorrect }
```
- Multiple choice: exact match (case-insensitive key "A"/"B"/...)
- Fill-in (`cteni_5`, `poslech_5`): **1đ/câu**, substring match (case-insensitive, trim). Partial credit — không all-or-nothing.

### Full exam V5 (superseded by V9)
```
písemná (V4+V2+V3): max 70đ, pass ≥42 (60%)
ústní   (V1):       max 40đ, pass ≥24 (60%)
overall_passed = pisemna_passed AND ustni_passed
```
~~DB: `full_exam_sessions` bảng mới + `session_type` trên `mock_tests`.~~
→ **V9:** `FullExamSession` bị xóa. `session_type` → `exam_mode`. Xem section V9 bên dưới.

### Exam model V9 — ExamTemplate vs PracticeSet

Idea doc: `docs/ideas/exam-template-vs-practice-set.md`

```
exam_mode: "real" | "practice"   (thay session_type trên mock_tests)

"real"     → ExamTemplate: admin chọn exercise per section, scoring 60% cố định
"practice" → PracticeSet:  admin chọn sections tự do, pass_threshold_percent tùy chỉnh
```

**Xóa hoàn toàn:**
- `FullExamSession`, `FullExamCreateRequest`, `FullExamCompleteRequest` khỏi contracts
- `FullExamStore` interface + memory + postgres implementations
- `FullExamScorer`, `FindOpenFullExamForAutoLink` khỏi processing
- Routes `/v1/full-exams`, `/v1/full-exams/:id/complete`
- Auto-link mechanism trong `handleMockExamComplete`
- DB table `full_exam_sessions` (DROP TABLE IF EXISTS trong main.go cleanup)

**Thay đổi:**
- `mock_tests.session_type` → `mock_tests.exam_mode VARCHAR(20) DEFAULT ''`
- `MockTest.SessionType` → `MockTest.ExamMode` trong Go contracts
- Scoring: `exam_mode = "real"` → threshold 60% (≥24/40 ustni, ≥42/70 pisemna); `"practice"` → `pass_threshold_percent`

---

## 4. API Contracts (mới — V2/V3/V4)

### POST /v1/attempts/:id/submit-text
```json
Request: {
  "answers": ["câu trả lời 1", "câu trả lời 2", "câu trả lời 3"],
  "text": "full email text"
}
```
- `answers` dùng cho `psani_1_formular` (3 items)
- `text` dùng cho `psani_2_email`
- Server validate word count, trả 400 nếu thiếu
- Attempt chuyển → `scoring` → async LLM → `completed`

### POST /v1/attempts/:id/submit-answers
```json
Request: { "answers": {"1": "B", "2": "A", "3": "D"} }
Response: attempt object (status=completed, objective_result populated)
```
- Sync scoring, không cần poll
- Keys = question_no (string), values = answer string

### GET /v1/exercises/:id/audio
- Returns signed URL hoặc stream (same pattern as attempt audio)
- Serves pre-generated Polly audio hoặc uploaded file

### POST /v1/admin/exercises/:id/generate-audio
- Gọi Polly với text từ exercise detail
- Lưu audio → `exercise_audio` table
- Returns `{storage_key, mime_type, duration_sec}`

### ~~POST /v1/full-exams (V5)~~ — **XÓA trong V9**
Route này bị xóa. `FullExamSession` không còn tồn tại.

---

## 5. Data Model mới

### DB schema (inline trong Go ensureSchema — không có migration files riêng)
| Table | Trạng thái |
|---|---|
| `exercise_audio` | ✅ tồn tại (V3) |
| `full_exam_sessions` | ~~V5~~ **XÓA trong V9** — `DROP TABLE IF EXISTS` trong main.go |
| `mock_tests.session_type` | ~~V5~~ **XÓA trong V9** — thay bằng `exam_mode` |
| `mock_tests.exam_mode` | **THÊM trong V9** — `VARCHAR(20) NOT NULL DEFAULT ''` |

### New Go structs (contracts/types.go)
- `Psani1Detail`, `Psani2Detail`, `WritingSubmission`
- `Poslech1Detail`, `Poslech2Detail`, `Poslech3Detail`, `Poslech4Detail`, `Poslech5Detail`
- `Cteni1Detail`, `Cteni2Detail`, `Cteni3Detail`, `Cteni4Detail`, `Cteni5Detail`
- `AnswerSubmission`, `ObjectiveResult`, `QuestionResult`
- `ListeningAudioSource`, `AudioSegment`, `MultipleChoiceOption`, `FillQuestion`
- ~~`FullExamSession` (V5)~~ **XÓA trong V9**

### AttemptFeedback extension
Thêm field: `objective_result *ObjectiveResult` (nil cho speaking/writing).

---

## 6. Project Structure

```
backend/
  internal/
    contracts/types.go          -- tất cả types mới ở đây
    processing/
      writing_scorer.go         -- NEW V2
      exercise_audio.go         -- NEW V3 (Polly for exercises)
      objective_scorer.go       -- NEW V3/V4 (shared)
      ~~full_exam_scorer.go~~    -- XÓA trong V9
    httpapi/server.go           -- thêm routes mới; xóa /v1/full-exams* trong V9
    store/
      postgres_mock_tests.go    -- exam_mode column thay session_type (V9)
      ~~full_exam_store.go~~    -- XÓA trong V9
      ~~postgres_full_exam_store.go~~ -- XÓA trong V9

cms/app/exercises/              -- extend exercise forms per type
flutter_app/lib/
  features/exercise/
    screens/
      writing_exercise_screen.dart   -- NEW V2
      listening_exercise_screen.dart -- NEW V3
      reading_exercise_screen.dart   -- NEW V4
    widgets/
      multiple_choice_widget.dart    -- NEW V3 (reused V4)
      match_widget.dart              -- NEW V3 (reused V4)
      fill_in_widget.dart            -- NEW V3 (reused V4)
      audio_player_widget.dart       -- NEW V3
      image_match_widget.dart        -- NEW V4
      match_text_widget.dart         -- NEW V4
      objective_result_card.dart     -- NEW V3 (reused V4)
      writing_result_card.dart       -- NEW V2
  features/mock_exam/
    screens/
      ~~full_exam_intro_screen.dart~~  -- XÓA trong V9
      ~~full_exam_result_screen.dart~~ -- XÓA trong V9
  models/models.dart             -- extend với tất cả types mới
  core/api/api_client.dart       -- add submitText(), submitAnswers(), getExerciseAudio()
```

---

## 7. Code Style

### Backend (Go)
- Monolithic trong V1-V5. Không tách service.
- Prefer standard library. Không thêm dependency mới trừ khi cần thiết.
- Mỗi skill có file scorer riêng (`writing_scorer.go`, `objective_scorer.go`) — không nhét vào `processor.go`.
- Provider pattern: `WritingFeedbackProvider` interface, default impl gọi LLM, fallback rule-based.
- Tất cả new exercise detail types serialize/deserialize qua `json.RawMessage` detail column (existing pattern).
- Error responses: `{"error": {"code": "...", "message": "..."}}`.
- Objective scoring: **không** gọi LLM, không gọi Polly. Pure Go computation.

### CMS (Next.js)
- Thin content desk. Không thêm workflow automation.
- Explicit form per exercise type (không generic schema builder).
- Audio preview trong CMS sau khi generate: `<audio>` element với URL từ backend.
- i18n: mọi string qua `cms/lib/i18n.tsx`.

### Flutter (Dart)
- `skillKind` quyết định routing tới screen nào (không hardcode exercise_type).
- Word count validation hoàn toàn client-side trước khi gọi API.
- `ObjectiveResultCard` reuse cho cả Listening lẫn Reading.
- Không dùng `setState` trong màn hình phức tạp — dùng provider/bloc đang có.
- ARB keys mới: prefix `writing_`, `listening_`, `reading_` cho i18n strings.

---

## 8. Testing Strategy

### Backend
- Unit test `objective_scorer.go`: mỗi exercise type có ít nhất 1 happy path + 1 wrong answer test.
- Unit test fill-in matching: "Bramborový salát" matches "salát", "SALÁT", " salát ".
- Integration test cho mỗi new endpoint (mock Polly, mock LLM).
- `make backend-test` phải pass trước mỗi CHECKPOINT.

### CMS
- `make cms-lint && make cms-build` tại mỗi CHECKPOINT.
- Manual smoke: tạo exercise mỗi loại → save → reload → data intact.

### Flutter
- `make flutter-analyze` phải pass (0 warnings).
- `make flutter-test` cho widget tests của answer widgets.
- Manual end-to-end trên simulator cho mỗi skill mới trước CHECKPOINT.

---

## 9. Boundaries

### ALWAYS DO
- Chạy `make backend-build` sau mỗi thay đổi Go.
- Validate word count client-side (Flutter) TRƯỚC KHI gọi API.
- Objective scoring là sync — không gọi goroutine không cần thiết.
- Mỗi new route trong `server.go` phải có `withAuth` hoặc `withRole("admin")`.
- Fill-in answers dùng substring match (case-insensitive, trim) — không exact string match. 1đ/câu, partial credit.
- `psani_1_formular`: LLM gọi 3 lần (1 per question), điểm = sum. Không gộp 3 câu vào 1 prompt.
- Thêm `skill_kind → exercise_type` mapping vào validation khi thêm exercise type mới.

### ASK FIRST
- Thay đổi `AttemptReviewArtifact` struct fields tên/type (Flutter đang dùng).
- Thêm Polly voice thứ 2 cho dialog (backlog, không làm trong V3).
- Bất kỳ thay đổi nào vào `mock_exam_sessions` table schema (đang được MockTest dùng).
- Thêm LLM call vào objective scoring flow.

### NEVER DO
- Không dùng LLM để chấm objective exercises (listening/reading).
- Không dùng Polly đọc `model_answer` cho Writing exercises (quyết định V2).
- Không merge exercises giữa pool=course và pool=exam.
- Không làm V5 trước khi V4 CHECKPOINT green.
- Không thêm SQS, EventBridge, microservices (infrastructure baseline).
- Không đưa `psani_2_email` images vào base64 trong JSON — dùng S3/asset URLs.

---

## 10. Verification per Version

| Version | Lệnh | Manual check |
|---|---|---|
| W (Writing) | `make backend-build && make backend-test && make cms-build && make flutter-analyze` | psani_1 → nhập 3 câu ≥10 từ → submit → ResultCard có highlight lỗi |
| L (Listening) | same | poslech_5 → nghe voicemail 2 lần → điền thông tin → điểm hiển thị ngay |
| R (Reading) | same | cteni_5 → điền fill-in → fuzzy match hoạt động |
| M (Full exam) | `make verify` | Full exam → písemná (cteni+psani+poslech) → ústní → overall PASS/FAIL |

---

## 11. Scoring Decisions (đã chốt 2026-04-27)

### psani_1_formular — LLM chấm riêng từng câu
LLM nhận 3 câu hỏi + 3 câu trả lời → trả về 3 `readiness_level` riêng biệt.
Điểm tổng = sum(điểm từng câu). Lý do: dễ debug, feedback chi tiết, tránh mơ hồ khi 1 câu tốt / 1 câu kém.

```
psani_1 total_score = score_q1 + score_q2 + score_q3
max = 8đ → mỗi câu max ~2.67đ → dùng readiness map:
  weak   = 0đ
  ok     = 1đ
  strong = 2đ
  (câu thứ 3 bonus nếu cả 3 strong: +2 → tổng 8)
```

Hoặc đơn giản hơn: normalize về [0,1] rồi × max_points:
```
readiness_fraction: weak=0.0, ok=0.5, strong=1.0
score_qi = round(readiness_fraction_i × (max_points / 3))
```

### readiness_level → điểm (universal mapping)
```
weak   = 0     (fraction = 0.0)
ok     = 1     (fraction = 0.5)
strong = 2     (fraction = 1.0)
```
Normalize khi cần thang [0,1]: `fraction = {weak:0, ok:0.5, strong:1.0}[level]`.
Áp dụng cho cả Speaking (existing) lẫn Writing (V2).

### cteni_5 / poslech_5 — fill-in: 1đ/câu đúng
Partial credit. 5 ô → tối đa 5đ. Matching: substring, case-insensitive, trim.
Lý do: công bằng hơn, phản ánh năng lực từng item, dễ thống kê lỗi phổ biến.

```go
func matchFillIn(learner, correct string) bool {
    l := strings.ToLower(strings.TrimSpace(learner))
    c := strings.ToLower(strings.TrimSpace(correct))
    return strings.Contains(l, c) || strings.Contains(c, l)
}
```

### V5 písemná section order: cteni → poslech → psani
Lý do: nhận diện input trước (đọc/nghe), production sau (viết). Hợp flow đánh giá năng lực ngôn ngữ.

```
Section 1: cteni_1 … cteni_5   (40 phút)
Section 2: poslech_1 … poslech_5 (~40 phút)
Section 3: psani_1 + psani_2   (25 phút)
```

---

## V6 — LLM-Assisted Vocab & Grammar (2026-04-28)

Full plan: `tasks/plan-vocab-grammar.md`. Key decisions frozen below.

### Objective

Thêm 2 skill kinds mới (`tu_vung`, `ngu_phap`) với 4 exercise types
(`quizcard_basic`, `matching`, `fill_blank`, `choice_word`) vào course flow.
Admin authoring được hỗ trợ bởi LLM — không phải manual, không phải auto-publish.

Target users: Admin nhập content Czech A2 tiếng Việt. Learner luyện từ vựng/ngữ pháp.

### LLM Usage Boundary (frozen — do not cross)

**ALLOWED (content authoring, admin-only):**
- Vocabulary draft generation (flashcards, matching pairs, example sentences)
- Grammar draft generation (fill_blank, choice_word, explanations, distractors)
- Explanation generation for any exercise type

**NOT ALLOWED:**
- Objective exercise scoring at runtime (remains pure Go, deterministic)
- Learner answer evaluation for fill_blank / choice_word / matching
- Any LLM call in the attempt → submit-answers → result flow

> LLM trong V6 = content authoring assistant. Scoring = Go `ScoreObjectiveAnswers`. Published content must pass admin review before learner sees it.

### New Exercise Types

| Type | Skills | Scoring |
|------|--------|---------|
| `quizcard_basic` | tu_vung only | Self-assessed: always 1/1. known/review stored in transcript_json. |
| `matching` | tu_vung, ngu_phap | Objective: correct pairs / total. Uses `ScoreObjectiveAnswers`. |
| `fill_blank` | tu_vung, ngu_phap | Objective: substring match. Same as cteni_5 pattern. |
| `choice_word` | tu_vung, ngu_phap | Objective: exact option match. Same as poslech pattern. |

Pool = course only. pool=exam rejected at creation.

### Generation Flow (frozen)

```
POST /v1/admin/content-generation-jobs  →  202 { job_id }  (async, goroutine)
GET  /v1/admin/content-generation-jobs/:id  →  poll every 2s
status: pending → running → generated | failed → rejected | published
```

Rate limit: 1 active job per admin. 409 if another running.  
Claude `tool_use` enforces JSON schema — no free text output.

### Skill Auto-Creation (frozen)

When admin creates VocabularySet or GrammarRule, backend calls `ensureSkill(moduleID, skillKind)`.
If no tu_vung/ngu_phap skill exists for that module → auto-create with status=published.
Admin never needs to visit /skills to create vocabulary/grammar skills.

### Publish Behavior (frozen)

`POST /admin/content-generation-jobs/:id/publish`:
1. Validate ALL exercises in edited_payload_json (choice_word: 4 options, correct∈options; fill_blank: `___` in prompt; etc.)
2. If any fail → 400 + `validation_errors[]`. Nothing published.
3. If all pass → create exercises rows (source_type, source_id, generation_job_id set on each). Atomic.

### Draft Editing UI (frozen)

`GeneratedExerciseReviewTable` dispatches per exercise type:
- `QuizcardDraftEditor` — front/back/explanation
- `ChoiceWordDraftEditor` — prompt/4 options/correct selector/explanation
- `FillBlankDraftEditor` — sentence(must have ___)/answer/explanation
- `MatchingDraftEditor` — pair rows (term|definition), add/remove

No per-exercise regenerate. Per-job only: reject + create new job.

### New DB Migrations

- 013: `vocabulary_sets`, `vocabulary_items`
- 014: `grammar_rules`
- 015: `content_generation_jobs` (with provider/model/tokens/cost/duration fields)
- 016: `exercises` ADD `source_type TEXT`, `source_id TEXT`, `generation_job_id TEXT` (nullable)

### New API Endpoints

```
POST/GET/PATCH/DELETE /v1/admin/vocabulary-sets
POST/GET/PATCH/DELETE /v1/admin/vocabulary-sets/:id/items
POST/GET/PATCH/DELETE /v1/admin/grammar-rules
POST   /v1/admin/content-generation-jobs       (async, 409 guard)
GET    /v1/admin/content-generation-jobs/:id   (poll)
PATCH  /v1/admin/content-generation-jobs/:id/draft
POST   /v1/admin/content-generation-jobs/:id/publish
POST   /v1/admin/content-generation-jobs/:id/reject
```

### New CMS Pages

- `/vocabulary` — VocabularySet CRUD + LLM generation + per-type review + publish
- `/grammar` — GrammarRule CRUD (conjugation table) + LLM generation + review + publish

### New Flutter

- `VocabGrammarExerciseScreen` — routes by exerciseType
- `QuizcardWidget` — flip card 200ms, Đã biết/Ôn lại, no ObjectiveResultCard
- `MatchingWidget` — tap-to-pair, color-coded connections, submit when all paired
- Reuse `FillInWidget` + `MultipleChoiceWidget` from V3

### Matching Exercise Contract (frozen)

```json
// Stored in exercises.detail
{
  "pairs": [
    { "left_id": "1", "left": "chodím", "right_id": "A", "right": "đi bộ" },
    { "left_id": "2", "left": "běžím",  "right_id": "B", "right": "chạy"  }
  ],
  "correct_answers": { "1": "A", "2": "B" }
}

// Learner submits (Flutter shuffles right-side display, left stays fixed)
{ "answers": { "1": "C", "2": "A" } }

// Scoring: exact match on right_id key (single char → exact in ScoreObjectiveAnswers)
```

Flutter shuffles `right_id`/`right` display order. `left_id` order is fixed. Server stores deterministic pairs.

### Store Architecture (V6, frozen)

Three new interfaces following existing `SkillStore` pattern:
- `VocabularyStore` — CRUD for vocabulary_sets + vocabulary_items
- `GrammarStore` — CRUD for grammar_rules
- `GenerationJobStore` — job lifecycle + `MarkAllRunningFailed(msg)` called on server start

`ContentGenerator` interface with `ClaudeContentGenerator` (prod) + `MockContentGenerator` (tests).

Shared `ValidateExercisePayload()` + `BuildExerciseFromDraft()` used by both HTTP handler and publish endpoint.

### Rate Limit Scope (frozen)

Per admin per module: `WHERE requested_by='admin' AND module_id=$1 AND status IN ('pending','running')`.
Admin can generate for different modules simultaneously.

### V6 Boundaries

NEVER in V6:
- LLM in scoring/grading flow
- Auto-publish without admin review
- Per-exercise regenerate (per-job only)
- Quizcard mastery dashboard (backlog)
- pool=exam for any new exercise type
- Partial publish (all-or-nothing)
- Full-text matching answers (use option key A/B/C)
- Goroutine left stuck on server restart (must recover on boot)

---

## V9 — Exam Model Cleanup (2026-04-30)

Idea doc: `docs/ideas/exam-template-vs-practice-set.md`
Full plan + task breakdown: `tasks/plan.md` (section V9), `tasks/todo.md` (EX-1 → EX-4).

### Objective

Untangle exam session model. Hai loại rõ ràng thay vì 1 entity với 4-value `session_type` flag:

| Mode | Tên gọi | Scoring | Admin config |
|------|---------|---------|--------------|
| `"real"` | ExamTemplate | 60% cố định (≥24/40 ustni, ≥42/70 pisemna) | Chọn exercise per section |
| `"practice"` | PracticeSet | `pass_threshold_percent` tùy chỉnh | Chọn sections tự do |

`MockTest` entity và `MockExamSession` **giữ nguyên**. Chỉ đổi field + xóa `FullExamSession` layer.

### Kiến trúc quyết định (frozen)

| Quyết định | Lý do |
|---|---|
| Giữ tên DB table `mock_tests` | Không đáng rủi ro rename migration |
| Giữ `MockExamSession` cho cả 2 modes | 1 table đủ, không over-engineer |
| Xóa toàn bộ `FullExamSession` stack | Dead code — không có Flutter UI nào trigger sau V7 |
| `exam_mode = "real"` scoring = 60% flat | Theo spec NPI ČR (≥24/40, ≥42/70) |
| DROP TABLE inline trong main.go | Không có migration files riêng trong codebase — schema quản lý qua ensureSchema() |
| `exam_mode = ""` (empty string) = "practice" | Backward compat — existing records không bị break |

### Deleted (V9)

**Backend files xóa:**
- `backend/internal/processing/full_exam_scorer.go`
- `backend/internal/processing/full_exam_scorer_test.go`
- `backend/internal/processing/full_exam_auto_link_test.go`
- `backend/internal/store/full_exam_store.go`
- `backend/internal/store/full_exam_store_test.go`
- `backend/internal/store/postgres_full_exam_store.go`

**Backend types xóa** (từ `contracts/types.go`):
- `FullExamSession`
- `FullExamCreateRequest`
- `FullExamCompleteRequest`

**Backend routes xóa** (từ `server.go`):
- `POST /v1/full-exams`
- `GET /v1/full-exams`
- `GET /v1/full-exams/:id`
- `POST /v1/full-exams/:id/complete`

**Flutter files xóa:**
- `flutter_app/lib/features/mock_exam/screens/full_exam_intro_screen.dart`
- `flutter_app/lib/features/mock_exam/screens/full_exam_result_screen.dart`

### Changed (V9)

- `mock_tests` DB: ADD `exam_mode VARCHAR(20) NOT NULL DEFAULT ''`, DROP `session_type`
- `contracts.MockTest`: `SessionType string` → `ExamMode string`
- `postgres_mock_tests.go` ensureSchema: migrate column
- `server.go` handleAdminMockTests: đọc/ghi `exam_mode`
- CMS MockTest form: bỏ `session_type` dropdown, thêm `exam_mode` radio (`real` | `practice`)
- Flutter `MockTest` model: `sessionType` → `examMode`
- Flutter `api_client.dart`: xóa FullExam API calls

### V9 Boundaries

NEVER:
- Rebuild `FullExamSession` hay equivalent 2-part exam tracking — thay vào đó dùng 2 `MockExamSession` riêng biệt nếu cần
- Thêm `session_type` lại dưới bất kỳ tên gọi nào — `exam_mode: "real" | "practice"` là source of truth
- Enforce 4-section structure cho `exam_mode = "real"` tại validation layer — convention, không phải constraint

ASK FIRST:
- Bất kỳ thay đổi nào vào `computeScoring()` logic — ảnh hưởng cả real và practice mode
- Thêm `exam_mode` value mới ngoài `"real"` và `"practice"`

### V9 Verification

| Step | Lệnh | Manual check |
|------|------|--------------|
| EX-1 | `make backend-build && make backend-test` | `GET /v1/full-exams` → 404 |
| EX-2 | `make backend-build && make backend-test` | `GET /v1/mock-tests` → trả `exam_mode`, không có `session_type` |
| EX-3 | `make cms-lint && make cms-build` | Tạo MockTest → chọn real/practice → reload → đúng |
| EX-4 | `make flutter-analyze && make flutter-test` | 0 errors, 0 FullExam references |
| CHECKPOINT | `make verify` | Full pass |
