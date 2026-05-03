# Plan: Skills Expansion V2→V14

Source: Modelový test A2, NPI ČR (platný od dubna 2026). OCR'd 2026-04-27.

---

## Đã xong

- ✅ Nói (Speaking) — Úloha 1-4, LLM scoring, review artifact, MockTest (speaking-only)
- ✅ Content architecture — Course → Module → Skill → Exercise hierarchy
- ✅ pool=course / pool=exam separation
- ✅ Design system V0 (Babbel theme)
- ✅ Flutter i18n (VI/EN)
- ✅ V2 Writing, V3 Listening, V4 Reading, V5 MockTest full, V6 Vocab+Grammar, V7 Flexible Sprint
- ✅ V8 Voice Selection (4 slices VS1-VS4)
- ✅ V9 Exam Model Cleanup, V10 Exam Result Redesign, V11 Media Enrichment, V12 Deck Session, V13 Ano/Ne

---

## Quyết định kiến trúc (không thay đổi)

| Quyết định | Lý do |
|---|---|
| pool=course và pool=exam là 2 records riêng | Admin tạo khóa học riêng + bài exam riêng, không reuse |
| V2 Writing: LLM chấm, KHÔNG dùng Polly đọc model_answer | Đủ cho V1, Polly là tùy chọn sau |
| V3 Listening audio: upload file OR text→Polly (1 voice, ghép segments) | Đơn giản, upgrade 2 voices sau |
| V4 Reading: objective scoring (đúng/sai), không cần LLM | All answers deterministic |
| V5 MockTest full: chỉ làm sau V4 xong | 2 session riêng: písemná (doc+viet+poslech) + ústní (noi) |

---

## Exercise types đầy đủ

### Viết (viet) — 20đ
| exercise_type | Mô tả | Pool | Điểm thi |
|---|---|---|---|
| `psani_1_formular` | 3 câu hỏi form, mỗi câu ≥10 từ | cả 2 | 8 |
| `psani_2_email` | Viết email theo 5 ảnh, ≥35 từ | cả 2 | 12 |

### Nghe (nghe) — 25đ
| exercise_type | Mô tả | Pool | Điểm thi |
|---|---|---|---|
| `poslech_1` | 5 đoạn ngắn → chọn A-D | cả 2 | 5 |
| `poslech_2` | 5 đoạn ngắn → chọn A-D | cả 2 | 5 |
| `poslech_3` | 5 đoạn → match A-G (2 dư) | cả 2 | 5 |
| `poslech_4` | 5 dialog → chọn ảnh A-F (1 dư) | cả 2 | 5 |
| `poslech_5` | Nghe voicemail → điền thông tin (5 ô) | cả 2 | 5 |

### Đọc (doc) — 25đ
| exercise_type | Mô tả | Pool | Điểm thi |
|---|---|---|---|
| `cteni_1` | Match 5 ảnh/tin nhắn → A-H (3 dư) | cả 2 | 5 |
| `cteni_2` | Đọc text → chọn A-D (5 câu) | cả 2 | 5 |
| `cteni_3` | Match 4 text → nhân vật A-E (1 dư) | cả 2 | 4 |
| `cteni_4` | Chọn A-D (6 câu) | cả 2 | 6 |
| `cteni_5` | Đọc text → điền thông tin (5 ô) | cả 2 | 5 |

---

## Dependency graph

```
W1 (contracts) ──→ W2 (backend flow) ──→ W3 (CMS) ──→ W4 (Flutter)
                                                             ↓
[CHECKPOINT W] ←─────────────────────────────────────────────

L1 (contracts+audio) ──→ L2 (backend flow) ──→ L3 (CMS) ──→ L4 (Flutter)
                                                                  ↓
[CHECKPOINT L] ←──────────────────────────────────────────────────

R1 (contracts) ──→ R2 (backend flow, reuse L2) ──→ R3 (CMS) ──→ R4 (Flutter, reuse L4 widgets)
                                                                       ↓
[CHECKPOINT R] ←───────────────────────────────────────────────────────

M1 (data model) ──→ M2 (backend) ──→ M3 (CMS) ──→ M4 (Flutter)
                                                         ↓
[CHECKPOINT M] ←──────────────────────────────────────────
```

---

## V2 — Psaní (Writing)

### Design: Writing attempt flow

```
Flutter: display questions/images
  → POST /v1/attempts          (create, attempt_type="writing")
  → POST /v1/attempts/:id/submit-text   (NEW)
     body: { "answers": ["Q1 text", "Q2 text", "Q3 text"] }  -- psani_1
        OR { "text": "full email text" }                      -- psani_2
  → poll GET /v1/attempts/:id
  → show result (corrected_text + diff + criteria)
```

### Design: Writing review artifact

Reuses existing `AttemptReviewArtifact` struct. Mapping:
- `source_transcript_text` ← learner's written text (or joined answers)
- `corrected_transcript_text` ← LLM-corrected version
- `model_answer_text` ← example answer
- `speaking_focus_items` ← writing errors (grammar, vocabulary, coherence)
- `diff_chunks` ← text diff
- `tts_audio` ← **nil** (không dùng Polly)

LLM prompt differs from speaking: no transcript noise, no readiness_level từ confidence. Scoring: `weak` (<60% criteria met) / `ok` (60-80%) / `strong` (>80%).

Word count validated **client-side** trước khi submit:
- psani_1: mỗi answer ≥10 từ
- psani_2: tổng text ≥35 từ

### Slice W1 — Contracts + exercise types (Backend)

**Files:** `backend/internal/contracts/types.go`

Thêm:
```go
type Psani1Detail struct {
    ExerciseID string   `json:"exercise_id"`
    Questions  []string `json:"questions"`   // 3 câu hỏi
    MinWords   int      `json:"min_words"`   // default 10
}

type Psani2Detail struct {
    ExerciseID    string   `json:"exercise_id"`
    Prompt        string   `json:"prompt"`         // "Jste na dovolené..."
    ImageAssetIDs []string `json:"image_asset_ids"` // 5 ảnh
    Topics        []string `json:"topics"`          // ["KDE JSTE?", ...]
    MinWords      int      `json:"min_words"`        // default 35
}

type WritingSubmission struct {
    Answers []string `json:"answers,omitempty"` // psani_1: 3 answers
    Text    string   `json:"text,omitempty"`    // psani_2: full text
}
```

Thêm vào `ExerciseType` validation: `psani_1_formular`, `psani_2_email`.
Thêm vào `SkillKind → ExerciseType` mapping: `viet → psani_*`.

**AC:** `make backend-build` passes.

### Slice W2 — Backend writing attempt flow

**Files:**
- `backend/internal/httpapi/server.go` — thêm route `POST /v1/attempts/:id/submit-text`
- `backend/internal/processing/writing_scorer.go` — NEW
- `backend/internal/processing/llm_feedback.go` — extend cho writing

`writing_scorer.go`:
1. Load exercise detail (Psani1Detail hoặc Psani2Detail)
2. Validate word count (trả lỗi nếu thiếu)
3. Call `LLMWritingFeedbackProvider.Score(exerciseType, submission, detail)`
4. Build `AttemptFeedback` + `AttemptReviewArtifact`
5. Persist + mark attempt `completed`

LLM prompt cho writing khác speaking:
- Input: learner text + exercise questions/images description
- Output: corrected_text, error_highlights, model_answer, criteria_results, readiness_level

`POST /v1/attempts/:id/submit-text`:
- Validate attempt exists + status=`created`
- Parse `WritingSubmission`
- Client-side word count validation (return 400 nếu thiếu)
- Transition attempt → `scoring`
- Trigger `writing_scorer` async (same pattern as audio processing)

**AC:** `make backend-test` passes. Integration test: create psani_1 attempt → submit text → poll → completed with feedback.

### Slice W3 — CMS writing exercise forms

**Files:** `cms/app/exercises/` — extend exercise dashboard

Thêm 2 form types:
- `psani_1_formular`: 3 question text fields + min_words number input
- `psani_2_email`: prompt text + 5 image upload slots + 5 topic label fields

CMS exercise list filter: hiện `Viết` exercises khi skill_kind=`viet`.

**AC:** `make cms-build` passes. Admin có thể tạo/edit psani_1 và psani_2 exercises.

### Slice W4 — Flutter writing screen

**Files:**
- `flutter_app/lib/features/exercise/screens/writing_exercise_screen.dart` — NEW
- `flutter_app/lib/features/exercise/widgets/writing_result_card.dart` — NEW (hoặc extend result_card.dart)
- `flutter_app/lib/models/models.dart` — add WritingSubmission, Psani1Detail, Psani2Detail
- `flutter_app/lib/core/api/api_client.dart` — add `submitText()`

`WritingExerciseScreen`:
- psani_1: show 3 câu hỏi, 3 TextField, word count badge mỗi field
- psani_2: show 5 ảnh + topics, 1 TextField lớn, word count badge
- Submit button: disabled nếu chưa đủ từ
- On submit → create attempt → submitText → AnalysisScreen (spinner) → ResultCard

`WritingResultCard`:
- Tab 1 "Bài làm": show learner text với highlight lỗi
- Tab 2 "Gợi ý": corrected text (diff view) + writing_focus_items
- Tab 3 "Tiêu chí": criteria_results checklist (reuse CriterionCheckView)

ExerciseScreen routing: detect `exercise.skillKind == "viet"` → navigate to `WritingExerciseScreen`.

**AC:** `make flutter-analyze` passes. End-to-end: chọn psani_1 exercise → nhập text → submit → xem kết quả có highlight lỗi.

### [CHECKPOINT W]

```
make backend-build && make backend-test
make cms-build
make flutter-analyze && make flutter-test
```

Manual: Simulator: psani_1 → nhập 3 câu trả lời → submit → result card hiển thị corrected text.

---

## V3 — Poslech (Listening)

### Design: Exercise audio

Admin chọn một trong hai:
- **Upload**: upload file MP3/WAV trực tiếp (dùng asset upload flow đã có)
- **Text→Polly**: nhập Czech text → CMS gọi `POST /v1/admin/exercises/:id/generate-audio` → backend gọi Polly → lưu audio file → link vào exercise

`poslech_4` (dialog 2 người): text chia thành segments với speaker prefix:
```json
{"segments": [
  {"speaker": "A", "text": "Paní prodavačko..."},
  {"speaker": "B", "text": "Počkejte, podívám se."}
]}
```
Polly đọc tuần tự, ghép thành 1 audio file. V3 dùng 1 voice duy nhất (Tomáš - Czech neural). Upgrade 2 voices sau.

### Design: Objective scoring

Listening và Reading dùng chung `objective_scorer.go`:
```go
type AnswerSubmission struct {
    Answers map[int]string `json:"answers"` // question_no → answer (e.g. "B", "Restaurace Klášterní")
}

type ObjectiveResult struct {
    Score      int                  `json:"score"`
    MaxScore   int                  `json:"max_score"`
    Breakdown  []QuestionResult     `json:"breakdown"`
}

type QuestionResult struct {
    QuestionNo     int    `json:"question_no"`
    LearnerAnswer  string `json:"learner_answer"`
    CorrectAnswer  string `json:"correct_answer"`
    IsCorrect      bool   `json:"is_correct"`
}
```

Stored trong `AttemptFeedback.objective_result` (new field).

### Design: Listening attempt flow

```
Flutter: show exercise + audio player
  → play audio (GET /v1/exercises/:id/audio)
  → learner answers
  → POST /v1/attempts          (create, attempt_type="listening")
  → POST /v1/attempts/:id/submit-answers   (NEW, reused cho Reading)
     body: { "answers": {"1": "B", "2": "C", ...} }
  → GET /v1/attempts/:id (poll — but sync scoring, returns immediately)
  → show result (correct/wrong per question)
```

Objective scoring là sync (no async pipeline) — kết quả ngay lập tức.

### Slice L1 — Contracts + exercise audio infrastructure

**Files:**
- `backend/internal/contracts/types.go` — thêm Poslech1-5Detail types
- `backend/internal/httpapi/server.go` — thêm `GET /v1/exercises/:id/audio` + `POST /v1/admin/exercises/:id/generate-audio`
- `backend/internal/processing/exercise_audio.go` — NEW: Polly call cho exercise audio
- `backend/db/migrations/010_exercise_audio.sql` — NEW: `exercise_audio` table

```go
// Exercise audio types
type MultipleChoiceOption struct {
    Key  string `json:"key"`  // "A", "B", ...
    Text string `json:"text"`
}

type AudioSegment struct {
    Speaker string `json:"speaker"` // "A" hoặc "B" (cho dialog)
    Text    string `json:"text"`
}

type Poslech1Detail struct {
    ExerciseID    string                 `json:"exercise_id"`
    Items         []ListeningItem        `json:"items"`  // 5 items
    CorrectAnswers map[int]string        `json:"correct_answers"` // {1:"B", 2:"A",...}
}

type ListeningItem struct {
    QuestionNo  int                    `json:"question_no"`
    AudioSource ListeningAudioSource   `json:"audio_source"` // file or text
    Options     []MultipleChoiceOption `json:"options"`
}

type ListeningAudioSource struct {
    AssetID  string         `json:"asset_id,omitempty"`  // uploaded file
    Segments []AudioSegment `json:"segments,omitempty"`  // text→Polly
}
// Poslech2Detail same as Poslech1Detail

type Poslech3Detail struct { // match A-G (2 extra)
    ExerciseID    string            `json:"exercise_id"`
    Items         []ListeningItem   `json:"items"`  // 5 items
    Options       []MatchOption     `json:"options"` // A-G (7 total)
    CorrectAnswers map[int]string   `json:"correct_answers"`
}

type Poslech4Detail struct { // dialog → choose image
    ExerciseID    string            `json:"exercise_id"`
    Items         []DialogItem      `json:"items"`  // 5 dialogs
    Options       []ImageOption     `json:"options"` // A-F (6 images, 1 extra)
    CorrectAnswers map[int]string   `json:"correct_answers"`
}

type Poslech5Detail struct { // voicemail → fill
    ExerciseID    string            `json:"exercise_id"`
    AudioSource   ListeningAudioSource `json:"audio_source"`
    Questions     []FillQuestion    `json:"questions"` // 5 questions
    CorrectAnswers map[int]string   `json:"correct_answers"`
}

type FillQuestion struct {
    QuestionNo int    `json:"question_no"`
    Prompt     string `json:"prompt"` // "KDO dal Evě lístky?"
}
```

`exercise_audio` table: `(exercise_id, storage_key, mime_type, source_type, generated_at)`.

**AC:** `make backend-build` passes. `POST /v1/admin/exercises/:id/generate-audio` gọi Polly thành công (integration test with mock Polly).

### Slice L2 — Backend objective scoring + submit-answers endpoint

**Files:**
- `backend/internal/httpapi/server.go` — `POST /v1/attempts/:id/submit-answers`
- `backend/internal/processing/objective_scorer.go` — NEW

`objective_scorer.go`:
1. Load exercise detail (detect type by exercise_type)
2. Compare `submission.answers` với `detail.correct_answers`
3. Calculate score (1 point per correct answer, or as configured)
4. Build `ObjectiveResult`
5. Persist trong `AttemptFeedback.objective_result`
6. Mark attempt `completed` (sync, không async)

`POST /v1/attempts/:id/submit-answers`:
- Validate attempt + status
- Parse `AnswerSubmission`
- Score sync → return completed attempt immediately (no polling needed, but same GET endpoint works)

**AC:** `make backend-test`. Unit test: poslech_1 answers → correct score calculated. Integration test: submit answers → attempt completed immediately.

### Slice L3 — CMS listening exercise forms

**Files:** `cms/app/exercises/` — extend forms

Forms cho 5 poslech types:
- Audio source: radio (Upload file / Generate from text)
- If "Generate": text area + "Generate audio" button → calls backend → shows audio preview
- Options (A-D / A-G / A-F): text fields hoặc image upload (poslech_4)
- Correct answers: dropdown / input per question
- AC: `make cms-build`. Admin tạo được poslech_5 với text → Polly generated audio.

### Slice L4 — Flutter listening UI

**Files:**
- `flutter_app/lib/features/exercise/screens/listening_exercise_screen.dart` — NEW
- `flutter_app/lib/features/exercise/widgets/audio_player_widget.dart` — NEW
- `flutter_app/lib/features/exercise/widgets/multiple_choice_widget.dart` — NEW (reusable)
- `flutter_app/lib/features/exercise/widgets/match_widget.dart` — NEW
- `flutter_app/lib/features/exercise/widgets/fill_in_widget.dart` — NEW
- `flutter_app/lib/features/exercise/widgets/objective_result_card.dart` — NEW

`ListeningExerciseScreen`:
- AudioPlayerWidget: play/pause, progress bar, replay button
- Answer widgets swap theo exercise_type
- Submit button → create attempt + submit answers (sync) → ObjectiveResultCard

`ObjectiveResultCard`:
- Per-question: ✅ correct / ❌ wrong + correct answer shown
- Score: X/5 display
- Retry button

ExerciseScreen routing: detect `skillKind == "nghe"` → `ListeningExerciseScreen`.

**AC:** `make flutter-analyze`. End-to-end: chọn poslech_1 → nghe audio → chọn đáp án → submit → thấy kết quả ngay.

### [CHECKPOINT L]

```
make backend-build && make backend-test
make cms-build
make flutter-analyze && make flutter-test
```

Manual: poslech_5 voicemail → nghe 2 lần → điền thông tin → xem điểm.

---

## V4 — Čtení (Reading)

### Design

Reuse toàn bộ objective scoring từ V3. Chỉ cần:
- New exercise detail types (Cteni1-5)
- CMS forms cho reading
- Flutter UI (reuse widgets từ L4, thêm text display)

`cteni_1` cần images — reuse asset upload flow đã có.
`cteni_3` (match text → person) cần text display cho mỗi item.

Không có audio. Không cần Polly.

### Slice R1 — Contracts + reading exercise types

**Files:** `backend/internal/contracts/types.go`

```go
type Cteni1Detail struct { // match image/message → A-H (3 extra)
    ExerciseID    string          `json:"exercise_id"`
    Items         []ReadingItem   `json:"items"`   // 5 items (ảnh)
    Options       []TextOption    `json:"options"` // A-H (8 options)
    CorrectAnswers map[int]string `json:"correct_answers"`
}

type Cteni2Detail struct { // đọc text → A-D (5 câu)
    ExerciseID    string                 `json:"exercise_id"`
    Text          string                 `json:"text"`
    Questions     []ReadingQuestion      `json:"questions"` // 5 questions
    CorrectAnswers map[int]string        `json:"correct_answers"`
}

type ReadingQuestion struct {
    QuestionNo int                    `json:"question_no"`
    Prompt     string                 `json:"prompt"`
    Options    []MultipleChoiceOption `json:"options"`
}

type Cteni3Detail struct { // match text → person A-E (1 extra)
    ExerciseID    string        `json:"exercise_id"`
    Texts         []TextItem    `json:"texts"`   // 4 texts
    Persons       []PersonOption `json:"persons"` // A-E (5 persons)
    CorrectAnswers map[int]string `json:"correct_answers"`
}

type Cteni4Detail struct { // A-D (6 câu)
    ExerciseID    string            `json:"exercise_id"`
    Context       string            `json:"context,omitempty"` // optional passage
    Questions     []ReadingQuestion `json:"questions"` // 6 questions
    CorrectAnswers map[int]string   `json:"correct_answers"`
}

type Cteni5Detail struct { // điền thông tin từ text
    ExerciseID    string         `json:"exercise_id"`
    Text          string         `json:"text"`
    Questions     []FillQuestion `json:"questions"` // 5 questions
    CorrectAnswers map[int]string `json:"correct_answers"`
    // fill-in: accept substring match (case-insensitive)
}
```

Thêm vào `SkillKind → ExerciseType` mapping: `doc → cteni_*`.

**AC:** `make backend-build`.

### Slice R2 — Backend reading scoring (reuse L2)

`objective_scorer.go` đã handle reading types sau khi thêm Cteni1-5.

Đặc biệt: `cteni_5` và `poslech_5` là fill-in — cần fuzzy match (substring, case-insensitive, trim whitespace).

**Files:** `backend/internal/processing/objective_scorer.go` — extend với fill-in matching logic.

**AC:** `make backend-test`. Unit test cteni_5: "bramborový salát" matches "Bramborový/chutný/jednoduchý salát".

### Slice R3 — CMS reading exercise forms

**Files:** `cms/app/exercises/` — extend forms

- `cteni_1`: 5 image upload slots + 8 option text fields + correct answers
- `cteni_2`: textarea (text) + 5 question blocks (prompt + 4 options) + correct answers
- `cteni_3`: 4 text blocks + 5 person descriptions + correct answers
- `cteni_4`: optional context textarea + 6 question blocks + correct answers
- `cteni_5`: textarea (text) + 5 prompt fields + correct answers (with note: fuzzy match)

**AC:** `make cms-build`.

### Slice R4 — Flutter reading UI

**Files:**
- `flutter_app/lib/features/exercise/screens/reading_exercise_screen.dart` — NEW
- Reuse: `multiple_choice_widget.dart`, `fill_in_widget.dart`, `objective_result_card.dart` từ V3
- NEW: `match_text_widget.dart` cho cteni_3 (tap text → tap person)
- NEW: `image_match_widget.dart` cho cteni_1

`ReadingExerciseScreen`:
- Text display (scrollable, selectable)
- Answer widgets theo exercise_type
- Submit → create attempt + submit answers → ObjectiveResultCard

ExerciseScreen routing: `skillKind == "doc"` → `ReadingExerciseScreen`.

**AC:** `make flutter-analyze`. End-to-end: cteni_2 → đọc text → chọn đáp án → xem điểm.

### [CHECKPOINT R]

```
make backend-build && make backend-test
make cms-build
make flutter-analyze && make flutter-test
```

Manual: cteni_5 fill-in → nhập thông tin → xem điểm (fuzzy match hoạt động).

---

## V5 — Full MockTest (4 kỹ năng)

### Design: 2-session exam structure

Kỳ thi thật có 2 phần riêng biệt:
- **Písemná část**: Čtení (40') + Psaní (25') + Poslech (~40') → max 70đ, pass ≥42
- **Ústní část**: Mluvení (15') → max 40đ, pass ≥24

Cả 2 phải pass. Fail 1 → phải thi lại cả 2.

App V5 model:
```
FullExamSession
  ├── pisemna_session_id → MockExamSession (type=pisemna, skills: doc+viet+poslech)
  └── ustni_session_id   → MockExamSession (type=ustni,   skills: noi) ← existing
```

Hoặc: mở rộng `MockExamSession` với `session_type: "pisemna" | "ustni" | "speaking"`.

MockTest V5 template sẽ có `session_type` field để chỉ định đây là písemná hay ústní.

### Slice M1 — Data model + migrations

**Files:**
- `backend/db/migrations/011_full_exam.sql` — NEW
- `backend/internal/contracts/types.go` — extend MockTest, MockExamSession

```sql
-- Extend mock_tests với session_type
ALTER TABLE mock_tests ADD COLUMN session_type TEXT NOT NULL DEFAULT 'speaking';
-- 'speaking' | 'pisemna' | 'full'

-- full_exam_sessions: link 2 sessions
CREATE TABLE full_exam_sessions (
    id TEXT PRIMARY KEY,
    learner_id TEXT NOT NULL,
    mock_test_id TEXT NOT NULL,
    pisemna_session_id TEXT,
    ustni_session_id TEXT,
    pisemna_score INT,
    ustni_score INT,
    pisemna_passed BOOL,
    ustni_passed BOOL,
    overall_passed BOOL,
    status TEXT NOT NULL DEFAULT 'in_progress',
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**AC:** `make backend-build`. Migration runs.

### Slice M2 — Backend full exam flow

**Files:**
- `backend/internal/httpapi/server.go` — new routes: `POST /v1/full-exams`, `GET /v1/full-exams/:id`
- `backend/internal/store/` — full_exam CRUD
- `backend/internal/processing/full_exam_scorer.go` — NEW

Písemná scoring:
```
pisemna_score = cteni_score + viet_score + poslech_score
pisemna_passed = pisemna_score >= 42
```

Ústní scoring: existing speaking mock exam (score 0-40, pass ≥24).

`POST /v1/full-exams`: tạo FullExamSession + MockExamSession cho písemná.
Khi písemná complete → link ustni session.

**AC:** `make backend-test`. Integration test: full exam session created → both parts scored → overall_passed computed.

### Slice M3 — CMS full exam builder

**Files:** `cms/app/mock-tests/` — extend

MockTest form thêm `session_type` dropdown: Speaking / Písemná / Full (4 skills).

Písemná builder: pick exercises cho từng section (cteni_1-5, psani_1-2, poslech_1-5).
Full builder: link 1 Písemná MockTest + 1 Ústní MockTest.

**AC:** `make cms-build`. Admin tạo được Full exam template.

### Slice M4 — Flutter full exam flow

**Files:**
- `flutter_app/lib/features/mock_exam/screens/full_exam_intro_screen.dart` — NEW
- `flutter_app/lib/features/mock_exam/screens/full_exam_result_screen.dart` — NEW
- Extend MockExamScreen để handle písemná sections (text/listening/writing)

Full exam flow:
1. Intro screen: duration, 110đ total, pass conditions (42/70 písemná + 24/40 ústní)
2. Písemná session: Čtení sections → Psaní sections → Poslech sections
3. Submit písemná → result intermediate
4. Ústní session: Mluvení (existing flow)
5. Final result: 2-panel (písemná + ústní), PASS/FAIL overall

**AC:** `make flutter-analyze`. End-to-end: chọn full exam → hoàn thành cả 2 phần → xem kết quả tổng.

### [CHECKPOINT M]

```
make backend-build && make backend-test
make cms-build && make cms-lint
make flutter-analyze && make flutter-test
make verify
```

Manual: Full exam → Písemná (cteni_2 + psani_1 + poslech_1) → Ústní (uloha_1) → Overall result.

---

## Thứ tự ưu tiên tuyệt đối

```
W1 → W2 → W3 → W4 → [CHECKPOINT W]
→ L1 → L2 → L3 → L4 → [CHECKPOINT L]
→ R1 → R2 → R3 → R4 → [CHECKPOINT R]
→ M1 → M2 → M3 → M4 → [CHECKPOINT M]
```

Không nhảy cóc giữa versions. Mỗi CHECKPOINT phải green trước khi bắt đầu version tiếp theo.

---

## V8 — Voice Selection (Chọn giọng đọc)

Spec: `docs/ideas/voice-selection.md`

**Mục tiêu:** Learner chọn 1 trong 4 giọng Czech trên màn Profile. Preference lưu trong `SharedPreferences`, gửi theo request khi generate review artifact TTS (speaking review + writing review). Poslech pre-generated audio **không bị ảnh hưởng**.

**4 voices:**
| Slug | Tên hiển thị | Giới tính | Provider | Env var |
|---|---|---|---|---|
| `jitka` | Jitka | Nữ | AWS Polly | `POLLY_VOICE_ID` (hiện có) |
| `tomas` | Tomáš | Nam | ElevenLabs | `ELEVENLABS_VOICE_ID` (hiện có) |
| `el_female_2` | (env `VOICE_C_NAME`, default `"Jana"`) | Nữ | ElevenLabs | `ELEVENLABS_VOICE_ID_C` (mới) |
| `el_male_2` | (env `VOICE_D_NAME`, default `"Marek"`) | Nam | ElevenLabs | `ELEVENLABS_VOICE_ID_D` (mới) |

**Design decisions:**
- Voice slug `""` → fallback về `p.ttsProvider` (backward compat, không break hiện tại)
- `VoiceRegistry.For("")` và `.For("unknown")` đều trả default provider
- Preview: `GET /v1/voices/:id/preview` tạo 1 câu mẫu, cache local/S3, trả signed URL
- Speaking: `preferred_voice_id` gửi trong body của `POST /v1/attempts/:id/upload-complete`
- Writing: `preferred_voice_id` thêm vào `WritingSubmission` (omitempty, backward compat)
- Nếu EL voice C/D chưa có env → không xuất hiện trong `GET /v1/voices` list

---

### Slice VS1 — Backend: VoiceRegistry + GET /v1/voices

**Files:**
- Tạo `backend/internal/processing/voice_registry.go`
- Sửa `backend/internal/processing/processor.go` — thêm field `voiceRegistry`
- Sửa `backend/internal/httpapi/server.go` — wire registry + route `GET /v1/voices`

**API:**
```
GET /v1/voices   (no auth required)
→ { "data": [{ "id":"jitka","name":"Jitka","gender":"female","provider":"aws_polly" }, ...] }
```

**Env vars mới:**
- `ELEVENLABS_VOICE_ID_C`, `ELEVENLABS_VOICE_ID_D` — voice IDs cho 2 giọng Eleven mới
- `VOICE_C_NAME` (default `"Jana"`), `VOICE_D_NAME` (default `"Marek"`) — display names

**AC:**
- Dev mode: trả `[{id:"jitka",...}]` (ít nhất 1)
- Prod với đủ env: trả 4 entries
- EL voice thiếu env → bị bỏ qua, không crash

**Verify:** `make backend-build && make backend-test`

---

### Slice VS2 — Backend: Thread voice vào TTS + preview endpoint

**Files:**
- Sửa `backend/internal/contracts/contracts.go` — `WritingSubmission.PreferredVoiceID string` (`json:"preferred_voice_id,omitempty"`)
- Sửa `backend/internal/processing/processor.go` — `ProcessAttempt(attemptID, locale, preferredVoiceID string)`, dùng `p.voiceRegistry.For(preferredVoiceID).Generate(...)`
- Sửa `backend/internal/processing/writing_scorer.go` — dùng `p.voiceRegistry.For(sub.PreferredVoiceID).Generate(...)`
- Sửa `backend/internal/httpapi/server.go`:
  - `handleUploadComplete`: parse optional `{"preferred_voice_id":"..."}` từ body, pass vào goroutine
  - Thêm `GET /v1/voices/:id/preview` (no auth) → generate + cache 1 câu TTS, trả signed URL

**Preview cache key:** `voice-preview/<slug>.mp3` (local tmp / S3)
**Preview phrase:** `"Dobrý den, jsem připraven pomoci vám s učením češtiny."`

**AC:**
- Speaking review: `preferred_voice_id=tomas` → Tomáš voice trong artifact TTS
- Writing review: `preferred_voice_id=jitka` → Jitka voice trong TTS
- `preferred_voice_id=""` → default provider (không break existing calls)
- Preview endpoint: trả audio URL; gọi lần 2 → cache hit (không gọi lại TTS API)
- Backward compat: upload-complete không có body vẫn hoạt động

**Verify:** `make backend-build && make backend-test`

---

**[CHECKPOINT VS-A]** `make backend-build && make backend-test`
Manual: `curl /v1/voices` → list; `curl /v1/voices/jitka/preview` → audio URL.

---

### Slice VS3 — Flutter: VoicePreferenceService + api_client

**Files:**
- Tạo `flutter_app/lib/core/voice/voice_option.dart`
- Tạo `flutter_app/lib/core/voice/voice_preference_service.dart`
- Sửa `flutter_app/lib/core/api/api_client.dart`

**VoicePreferenceService:**
```dart
class VoicePreferenceService {
  static const _key = 'pref_voice_id';
  String get current => _prefs.getString(_key) ?? '';
  Future<void> save(String voiceId) async { ... }
  static Future<VoicePreferenceService> create() async { ... }
}
```

**api_client thêm:**
- `Future<List<VoiceOption>> getVoices()` — `GET /v1/voices`
- `Future<String?> getVoicePreviewUrl(String voiceId)` — `GET /v1/voices/:id/preview` → trả `data.url`
- `submitText(..., {String? preferredVoiceId})` — thêm vào body nếu not null/empty
- Speaking upload-complete: tìm call site, thêm `preferred_voice_id` vào body

**AC:**
- `submitText(id, text:'...', preferredVoiceId:'tomas')` → body chứa `"preferred_voice_id":"tomas"`
- `submitText(id, text:'...')` → body không có `preferred_voice_id` (backward compat)
- `flutter analyze` pass

**Verify:** `make flutter-analyze`

---

### Slice VS4 — Flutter: Profile screen voice picker UI

**Files:**
- Sửa `flutter_app/lib/features/profile/screens/profile_screen.dart`
- Sửa `flutter_app/lib/l10n/app_en.arb` + `flutter_app/lib/l10n/app_vi.arb`

**Layout (thêm section trước _AboutCard):**
```
┌──────────────────────────────────────────┐
│ Giọng đọc mẫu                            │
│ ┌──────────────────────┐                 │
│ │ ✓ Jitka  Nữ  Polly  [Nghe thử]       │ ← selected: orange border
│ │   Tomáš  Nam  EL    [Nghe thử]       │
│ │   Jana   Nữ   EL    [Nghe thử]       │ hidden nếu chưa config
│ │   Marek  Nam  EL    [Nghe thử]       │ hidden nếu chưa config
│ └──────────────────────┘                 │
└──────────────────────────────────────────┘
```

**`_VoicePickerSection` (StatefulWidget):**
- `initState`: `getVoices()` + load `VoicePreferenceService.current` → setState
- Tap card → `save(voice.id)` + setState (optimistic)
- "Nghe thử": `getVoicePreviewUrl(voice.id)` → `just_audio` play URL
- Loading: `CircularProgressIndicator` nhỏ trong section
- Error / empty list: ẩn section (not critical)

**i18n keys (thêm vào cả VI + EN):**
- `profileVoiceSection` — "Giọng đọc mẫu" / "Model answer voice"
- `profileVoicePreview` — "Nghe thử" / "Preview"
- `profileVoiceFemale` — "Nữ" / "Female"
- `profileVoiceMale` — "Nam" / "Male"
- `profileVoiceProviderPolly` — "AWS Polly"
- `profileVoiceProviderElevenLabs` — "ElevenLabs"

**AC:**
- Tap Tomas → check xuất hiện, preference saved → app restart vẫn giữ
- Nhấn Nghe thử → audio phát 1 câu Czech
- Chỉ 2 voices config → 2 card, không crash
- Gọi API lỗi → section ẩn, không crash
- `flutter analyze` + `flutter test` pass

**Verify:** `make flutter-analyze && make flutter-test`

---

**[CHECKPOINT VS-B]** `make verify`
Manual: Profile → chọn Tomáš → làm bài psani_1 → xem review → TTS audio bằng giọng Tomáš.

---

## Thứ tự V8

```
VS1 → VS2 → [CHECKPOINT VS-A] → VS3 → VS4 → [CHECKPOINT VS-B]
```

Dependency: VS1 là foundation (registry). VS2 dùng registry. VS3 dùng VS2 endpoints. VS4 dùng VS3 service.

---

## V9 — Exam Model Cleanup: ExamTemplate vs PracticeSet

Idea doc: `docs/ideas/exam-template-vs-practice-set.md`

### Vấn đề

`MockTest.session_type` (`speaking | pisemna | full | ""`) là 4-value field cố gắng phân loại cả exam thật lẫn luyện thi. `FullExamSession` là entity thứ 3 không có Flutter UI nào kết nối vào, tồn tại như dead code kể từ V7 sprint model thay thế.

Kết quả: 3 scoring path (`CompleteMockExam` / `FullExamScorer` / `computeScoring`), 2 session store, 1 auto-link hack, và admin không rõ phải tạo MockTest loại gì.

### Model mới

```
exam_mode: "real" | "practice"   ← thay session_type

"real"     → ExamTemplate: admin chọn exercise per section, scoring 60% cố định
"practice" → PracticeSet:  admin chọn sections tự do, pass_threshold_percent tùy chỉnh
```

`MockTest` entity và `MockExamSession` giữ nguyên — chỉ đổi field + xóa `FullExamSession` layer.

### Quyết định kiến trúc

| Quyết định | Lý do |
|---|---|
| Giữ tên DB table `mock_tests` | Không đáng rủi ro rename migration |
| Giữ `MockExamSession` cho cả 2 modes | 1 table đủ, không over-engineer |
| Xóa toàn bộ `FullExamSession` stack | Dead code — không có Flutter UI nào trigger |
| `exam_mode = "real"` scoring = 60% flat | Theo spec NPI ČR (≥24/40 ustni, ≥42/70 pisemna) |
| DROP TABLE `full_exam_sessions` inline trong main.go cleanup | Không có migration files riêng trong codebase |

### Slices

#### EX-1 — Backend: Xóa FullExam stack

**Files xóa:**
- `backend/internal/processing/full_exam_scorer.go`
- `backend/internal/processing/full_exam_scorer_test.go`
- `backend/internal/processing/full_exam_auto_link_test.go`
- `backend/internal/store/full_exam_store.go`
- `backend/internal/store/full_exam_store_test.go`
- `backend/internal/store/postgres_full_exam_store.go`

**Files sửa:**
- `backend/internal/contracts/types.go` — xóa `FullExamSession`, `FullExamCreateRequest`, `FullExamCompleteRequest`
- `backend/internal/store/memory.go` — xóa FullExamStore field + Repo methods (`FullExamSession`, `SetFullExamSession`, `ListFullExamSessions`)
- `backend/internal/httpapi/server.go` — xóa `fullExamScorer` field, handlers `handleFullExams`/`handleFullExamByID`, routes `/v1/full-exams*`, auto-link call trong `handleMockExamComplete`
- `backend/cmd/api/main.go` — xóa fullExamScorer wiring, thêm `DROP TABLE IF EXISTS full_exam_sessions`

**AC:**
- `make backend-build` passes
- `make backend-test` passes
- `curl /v1/full-exams` → 404

#### EX-2 — Backend: session_type → exam_mode

**Files sửa:**
- `backend/internal/contracts/types.go` — `MockTest.SessionType` → `MockTest.ExamMode`
- `backend/internal/store/postgres_mock_tests.go` — ensureSchema: `ADD COLUMN IF NOT EXISTS exam_mode VARCHAR(20) NOT NULL DEFAULT ''`; drop `session_type` col; update INSERT/SELECT/UPDATE queries
- `backend/internal/store/mock_test_store.go` (nếu có memory impl) — cập nhật field
- `backend/internal/httpapi/server.go` — handler `handleAdminMockTests` đọc/ghi `exam_mode`

**AC:**
- `make backend-build && make backend-test`
- `GET /v1/mock-tests` trả về `exam_mode` thay `session_type`

#### EX-3 — CMS: bỏ session_type, thêm exam_mode radio

**Files sửa:**
- MockTest form trong CMS — xóa `session_type` dropdown, thêm `exam_mode` radio (`real` | `practice`)
- Hiển thị danh sách MockTest — show exam_mode badge thay session_type

**AC:**
- `make cms-lint && make cms-build`
- Tạo MockTest mới → chọn real/practice → lưu → reload → đúng giá trị

#### EX-4 — Flutter: xóa FullExam screens, update models

**Files xóa:**
- `flutter_app/lib/features/mock_exam/screens/full_exam_intro_screen.dart`
- `flutter_app/lib/features/mock_exam/screens/full_exam_result_screen.dart`

**Files sửa:**
- `flutter_app/lib/models/models.dart` — xóa `FullExamSession` model; `MockTest.sessionType` → `examMode`
- `flutter_app/lib/core/api/api_client.dart` — xóa FullExam API calls
- `flutter_app/lib/main.dart` — xóa FullExam imports/routes
- `flutter_app/lib/features/mock_exam/screens/mock_test_list_screen.dart` — xóa navigation đến FullExamIntroScreen
- `flutter_app/lib/features/mock_exam/screens/mock_test_intro_screen.dart` — xóa FullExam branching nếu có

**AC:**
- `make flutter-analyze` passes (0 errors)
- `make flutter-test` passes

**[CHECKPOINT EX]** `make verify`

### Dependency graph

```
EX-1 (xóa FullExam stack)
  └── EX-2 (session_type → exam_mode)
        ├── EX-3 (CMS)
        └── EX-4 (Flutter)
              ↓
[CHECKPOINT EX] make verify
```

EX-1 trước: xóa references trước khi rename field để tránh compile error cascade.
EX-2 sau EX-1: rename field an toàn khi FullExam types đã xóa.
EX-3 và EX-4 song song sau EX-2.

---

## V10 — Exam Result Flow Redesign

Spec: `docs/specs/exam-result-flow-implementation.md`
UI design: `docs/specs/exam-result-flow-redesign.md`
Idea: `docs/ideas/exam-result-flow-redesign.md`

### Problem

`MockExamSectionDetailScreen` luôn render `ResultCard` (speaking widget) cho mọi skill.
Nghe/đọc → màn rỗng/sai. Fix: truyền `skillKind` + `maxPoints`, dispatch đúng widget.

### Key findings từ codebase

- `_QuestionRow` đã có `learnerAnswer`/`correctAnswer` — chỉ cần visual card upgrade
- `viet` dùng `ResultCard` là đúng — `transcript` = text nộp, tab "Bài mẫu" có diff
- `ObjectiveResultCard` cần: card bg per câu + passage collapsible (doc only)
- `MockExamSection.skillKind` đã có — chỉ cần truyền qua detail screen

### Slices

#### ER-1 — ObjectiveResultCard: visual upgrade + passage

**Files:** `flutter_app/lib/features/exercise/widgets/objective_result_card.dart`, `flutter_app/lib/l10n/intl_vi.arb`, `flutter_app/lib/l10n/intl_en.arb`

**Changes:**

1. Upgrade `_QuestionRow` → card container per câu:
   - Đúng: green bg `AppColors.success.withValues(alpha:0.08)`, border green 0.2, icon ✓, correctAnswer riêng dòng
   - Sai: red bg `AppColors.error.withValues(alpha:0.08)`, border red 0.2, icon ✗, learnerAnswer (đỏ) + correctAnswer (xanh) riêng 2 dòng

2. Thêm params backward-compatible (all optional, default=false/''):
   - `showPassage` — chỉ `doc` truyền `true`
   - `exerciseId` — để fetch passage
   - `client` — `ApiClient?` để fetch `getExercise()`

3. Thêm `_PassageSection` StatefulWidget:
   - `initState`: nếu `showPassage && exerciseId.isNotEmpty && client != null` → fetch `getExercise(exerciseId)`
   - Loading: `LinearProgressIndicator` compact
   - Loaded: `ExpansionTile` (`l.viewPassage` / `l.hidePassage`) + `SelectableText(passage)`
   - Error: ẩn hoàn toàn, không block result

4. 2 i18n keys VI+EN: `viewPassage` ("Xem bài đọc"), `hidePassage` ("Ẩn bài đọc")

**AC:**
- `flutter-analyze` clean
- Câu đúng: green card, icon ✓, 1 dòng đáp án
- Câu sai: red card, icon ✗, 2 dòng (learner đỏ + đúng xanh)
- `showPassage=true` + valid exerciseId + client → passage fetch + collapsible
- `showPassage=false` (default) → passage section không render
- Existing callers (`ListeningExerciseScreen`, `ReadingExerciseScreen`) — không bị break

#### ER-2 — SectionResultCard: wrapper mới (phụ thuộc ER-1)

**File mới:** `flutter_app/lib/features/mock_exam/widgets/section_result_card.dart`

**Structure:**
```dart
class SectionResultCard extends StatelessWidget {
  // client, result, skillKind, maxPoints, onRetry
  // _resolvedKind: skillKind → fallback by exerciseType prefix
  // _body(): switch _resolvedKind → ObjectiveResultCard | ResultCard
}

class _SectionHeader extends StatelessWidget {
  // skill icon + label + score "X/Y" + LinearProgressIndicator h=6dp
  // color: ≥75% success, ≥50% info, <50% error
}
```

**Skill icons:**
- `noi` → `Icons.mic_outlined`
- `nghe` → `Icons.headphones_outlined`
- `doc` → `Icons.menu_book_outlined`
- `viet` → `Icons.edit_outlined`

**Dispatch:**
```
'nghe'|'doc' → ObjectiveResultCard(showPassage: kind=='doc', exerciseId, client)
_            → ResultCard(noi + viet)
```

**AC:**
- `noi` + `viet` → `ResultCard`
- `nghe` → `ObjectiveResultCard(showPassage: false)`
- `doc` → `ObjectiveResultCard(showPassage: true, exerciseId: result.exerciseId, client)`
- Empty `skillKind` + `exerciseType='poslech_1'` → fallback nghe → `ObjectiveResultCard`
- Header hiện score badge và progress bar đúng màu

#### ER-3 — Plumbing: truyền skillKind qua screens (phụ thuộc ER-2)

**Files:**
- `flutter_app/lib/features/mock_exam/screens/mock_exam_section_detail_screen.dart`
- `flutter_app/lib/features/mock_exam/screens/mock_exam_screen.dart`

**`mock_exam_section_detail_screen.dart`:**
- Thêm `required this.skillKind` + `required this.maxPoints` vào constructor
- Thay `ResultCard(...)` → `SectionResultCard(result, skillKind: widget.skillKind, maxPoints: widget.maxPoints, client: widget.client, onRetry: ...)`

**`mock_exam_screen.dart` — `_MockExamResultView` (~dòng 706):**
- Thêm `skillKind: _sectionSkillKind(section)` + `maxPoints: section.maxPoints` vào `MockExamSectionDetailScreen(...)` call

**AC:**
- Tap nói → `ResultCard` với tabs Phản hồi/Bản ghi/Bài mẫu
- Tap nghe → `ObjectiveResultCard` extended (card per câu)
- Tap đọc → `ObjectiveResultCard` extended + passage collapsible
- Tap viết → `ResultCard` với tabs (transcript = text nộp)
- `flutter-analyze` clean, không có unused import

#### ER-4 — Loading view upgrade (độc lập)

**File:** `flutter_app/lib/features/mock_exam/screens/mock_exam_screen.dart`

**`_buildAnalyzingView` upgrade:** thay `CircularProgressIndicator` đơn lẻ bằng:
```
- Text "Đang phân tích bài nói..."      ← bodyMedium
- LinearProgressIndicator (_analyzeProgress / total)
- SizedBox(h=AppSpacing.x4)
- Column per _pendingAnalyses[i]:
    i < _analyzeProgress    → Icon.check_circle (success) + "Section N · xong"
    i == _analyzeProgress-1 → SizedBox(16) CircularProgressIndicator small + "Section N · đang xử lý..."
    i >= _analyzeProgress   → Icon.radio_button_unchecked (muted) + "Section N"
```

**AC:**
- 0/2 pending: progress 0%, 2 icons muted
- 1/2 done: Section 1 ✓, Section 2 spinning
- 2/2 done: tự navigate (logic `_finalize` hiện tại giữ nguyên)
- Nếu `_pendingAnalyses` empty → màn này không xuất hiện (guard hiện tại giữ nguyên)

### Dependency graph

```
ER-1 (ObjectiveResultCard upgrade)
  └── ER-2 (SectionResultCard mới, dùng ObjectiveResultCard với params mới)
        └── ER-3 (Plumbing: MockExamSectionDetailScreen + MockExamScreen)
                    ↓
              [CHECKPOINT ER]

ER-4 (Loading view) — độc lập, làm sau ER-3
```

ER-1 trước: `SectionResultCard` cần `ObjectiveResultCard` đã có params mới.
ER-3 cuối: cần cả ER-1 + ER-2 compile trước.


---

## V10 — Exam Result Flow Redesign

Spec: `docs/specs/exam-result-flow-implementation.md`
UI design: `docs/specs/exam-result-flow-redesign.md`
Idea: `docs/ideas/exam-result-flow-redesign.md`

### Problem

`MockExamSectionDetailScreen` luôn render `ResultCard` (speaking widget) cho mọi skill. Nghe/đọc → màn rỗng/sai. Fix: truyền `skillKind` + `maxPoints` qua và dispatch đúng widget.

### Key findings từ codebase

- `_QuestionRow` đã hiện `learnerAnswer` → correctAnswer (sai) inline — chỉ cần visual upgrade card
- `viet` dùng `ResultCard` là đúng — `transcript` = text nộp, "Bài mẫu" tab có diff
- `ObjectiveResultCard` cần: card bg per câu + passage collapsible (doc only)
- `MockExamSection.skillKind` đã có — chỉ cần truyền qua detail screen

### Slices

#### ER-1 — ObjectiveResultCard: visual upgrade + passage (standalone)

**Files:** `flutter_app/lib/features/exercise/widgets/objective_result_card.dart`, `flutter_app/lib/l10n/intl_vi.arb`, `flutter_app/lib/l10n/intl_en.arb`

**Changes:**
1. Upgrade `_QuestionRow` → card container per câu:
   - Đúng: green bg `AppColors.success.withValues(alpha:0.08)`, border green 0.2, icon ✓ + correctAnswer trên dòng riêng
   - Sai: red bg `AppColors.error.withValues(alpha:0.08)`, border red 0.2, icon ✗ + learnerAnswer (đỏ) + correctAnswer (xanh) trên 2 dòng riêng
2. Thêm params backward-compatible:
   ```dart
   class ObjectiveResultCard extends StatelessWidget {
     const ObjectiveResultCard({
       super.key,
       required this.result,
       required this.onRetry,
       this.showPassage = false,
       this.exerciseId = '',
       this.client,
     });
     final bool showPassage;
     final String exerciseId;
     final ApiClient? client;
   }
   ```
3. Thêm `_PassageSection` StatefulWidget (doc only):
   - `initState`: nếu `showPassage && exerciseId.isNotEmpty && client != null` → fetch `getExercise(exerciseId)`
   - Loading: `LinearProgressIndicator` + "Đang tải bài đọc..." text
   - Loaded: `ExpansionTile` title `l.viewPassage` / `l.hidePassage` + `SelectableText(passage)`
   - Error: ẩn hoàn toàn (không block result)
4. Thêm 2 i18n keys VI+EN: `viewPassage` / `hidePassage`

**AC:**
- `flutter-analyze` clean
- Câu đúng: green card, 1 dòng (câu số + đáp án)
- Câu sai: red card, 2 dòng (learner đỏ + đúng xanh)
- `showPassage=true` + valid exerciseId → fetch + collapsible passage
- `showPassage=false` → passage section ẩn hoàn toàn
- Existing callers `ListeningExerciseScreen`, `ReadingExerciseScreen` → không bị break

#### ER-2 — SectionResultCard: wrapper mới (phụ thuộc ER-1)

**File mới:** `flutter_app/lib/features/mock_exam/widgets/section_result_card.dart`

**Widget:**
```dart
class SectionResultCard extends StatelessWidget {
  // header + dispatch body
  // nghe/doc → ObjectiveResultCard(showPassage: skillKind=='doc')
  // _ → ResultCard (noi + viet)
}

class _SectionHeader extends StatelessWidget {
  // skill icon (Icons.mic/headphones/menu_book/edit outlined)
  // skill label (dùng _skillLabel helper)
  // score "sectionScore/maxPoints"
  // LinearProgressIndicator height 6dp, màu theo pct
}
```

**Score color:** ≥75
---

## V11 — Media Enrichment (Ảnh cho Exercise & Vocabulary)

Spec: `docs/specs/media-enrichment.md`
UI/UX: `docs/designs/media-enrichment.html`
Idea: `docs/ideas/media-enrichment.md`

### Problem

Tất cả exercise types hiện chỉ dùng text cho options và vocabulary items. Bài thi A2 thực tế (послech_2) yêu cầu chọn đúng ảnh trong 4 ảnh. Flashcard từ vựng không có hình minh họa.

### Hiện trạng

`ImageOption`, `ChoiceOption.ImageAssetID`, `ReadingItem.AssetID` đã tồn tại (speaking/cteni_1). Asset upload endpoint `/admin/exercises/:id/assets/upload` đã có. Cần extend sang `VocabularyItem`, `GrammarRule`, `MultipleChoiceOption`, `MatchOption`.

### Design decisions

- `MultipleChoiceWidget` switch sang 2×2 image grid **chỉ khi tất cả** options có `image_asset_id` — không mixed layout
- Fallback silent khi image load fail — không block interaction
- Video excluded. Audio per vocab item deferred.
- Exercise option images: reuse endpoint `/admin/exercises/:id/assets/upload` với `asset_kind="option_image"`, ghi `image_asset_id` vào option object trong detail JSONB — không cần migration mới
- Vocab/grammar images: cần 2 migration nhỏ + 4 new endpoints (upload/delete per entity)

---

### ME-1 — Backend: contracts + vocab/grammar image endpoints

**Files:**
- `backend/internal/contracts/types.go`
- `backend/db/migrations/020_vocabulary_item_image.sql`
- `backend/db/migrations/021_grammar_rule_image.sql`
- `backend/internal/httpapi/server.go` (route wiring)
- `backend/internal/httpapi/media_assets.go` (new file — upload/delete handlers)
- `backend/internal/store/` (update vocab + grammar stores)

**Changes:**
1. `contracts/types.go` — thêm `ImageAssetID string \`json:"image_asset_id,omitempty"\`` vào:
   - `MultipleChoiceOption`
   - `MatchOption`
   - `VocabularyItem`
   - `GrammarRule`
2. Migration 020: `ALTER TABLE vocabulary_items ADD COLUMN image_asset_id TEXT NOT NULL DEFAULT '';`
3. Migration 021: `ALTER TABLE grammar_rules ADD COLUMN image_asset_id TEXT NOT NULL DEFAULT '';`
4. `media_assets.go` — 4 handlers:
   - `handleVocabItemImageUpload` — `POST /v1/admin/vocabulary-items/:id/image`
   - `handleVocabItemImageDelete` — `DELETE /v1/admin/vocabulary-items/:id/image`
   - `handleGrammarRuleImageUpload` — `POST /v1/admin/grammar-rules/:id/image`
   - `handleGrammarRuleImageDelete` — `DELETE /v1/admin/grammar-rules/:id/image`
   - Validate: MIME ∈ {jpeg, png, webp}, size ≤ 5MB
   - Reuse `backend_assets` volume / S3 pattern từ exercise asset handler
5. Store: `UpdateVocabularyItemImageAssetID(id, assetID string)`, `UpdateGrammarRuleImageAssetID(id, assetID string)`
6. `GET /v1/vocabulary-sets/:id/items` — trả `image_asset_id` trong response

**AC:**
- `make backend-build` + `make backend-test` pass
- `POST /admin/vocabulary-items/:id/image` với jpeg hợp lệ → 200, body có `asset_id`
- `POST /admin/vocabulary-items/:id/image` với file > 5MB → 413
- `POST /admin/vocabulary-items/:id/image` với video/mp4 → 415
- `DELETE /admin/vocabulary-items/:id/image` → `image_asset_id` xóa trong DB
- `GET /v1/vocabulary-sets/:id/items` → `image_asset_id` có trong response
- `MultipleChoiceOption`, `MatchOption` JSON serialization có `image_asset_id` (omitempty)

---

### ME-2 — E2E: Vocabulary flashcard với ảnh (CMS + Flutter)

**Phụ thuộc:** ME-1

**Files:**
- `cms/components/vocabulary-form.tsx` (hoặc tương đương vocab edit page)
- `flutter_app/lib/features/exercise/models/exercise_detail.dart` (hoặc vocab model)
- `flutter_app/lib/features/exercise/widgets/quizcard_widget.dart`

**CMS changes:**
1. Mỗi vocabulary item row: thêm thumbnail 52×52 (hiện ảnh nếu `image_asset_id`, placeholder dashed nếu không)
2. Button `+ Tải ảnh lên` / `✓ Đã có ảnh — Đổi` / `Xóa ảnh` per item
3. Upload flow: file input → `POST /v1/admin/vocabulary-items/:id/image` → optimistic thumbnail update
4. Error: toast nếu upload fail (size/type)
5. Item chưa save → disable upload với tooltip "Lưu item trước"

**Flutter changes:**
1. `VocabularyItem.fromJson()` parse `image_asset_id`
2. Build asset URL helper (reuse auth headers pattern từ audio player):
   ```dart
   // Dùng exercise asset endpoint với exerciseId từ context
   // hoặc standalone: /v1/exercises/{exId}/assets/{assetId}/file
   ```
3. `QuizcardWidget` front side:
   - Nếu `imageAssetId != null && imageAssetId.isNotEmpty`:
     - `Image.network(url, headers: authHeaders)` ở top of card, aspect 16:9, `BorderRadius` 12, `BoxFit.cover`
     - Shimmer placeholder khi loading (giống `_PassageSection` pattern)
     - Fail → silent placeholder (grey background, không hiện broken icon)
   - Nếu không có ảnh: card layout unchanged
4. Back side: unchanged

**AC:**
- Admin upload ảnh cho vocab item trong CMS → thumbnail hiện ngay
- `GET /v1/vocabulary-sets/:id/items` trả `image_asset_id` khác rỗng
- Flutter `QuizcardWidget` hiện ảnh phía trên term khi `imageAssetId != null`
- Khi không có ảnh: card render y hệt hiện tại
- Image fail → card vẫn tương tác được
- `make flutter-analyze` + `make cms-build` pass

**[CHECKPOINT ME-A]** `make backend-test` + `make flutter-analyze` + `make cms-build`.
Manual: CMS upload ảnh cho "kavárna" → Flutter flashcard hiện ảnh.

---

### ME-3 — Multiple choice image grid (CMS option upload + Flutter grid)

**Phụ thuộc:** ME-1

**Files:**
- `cms/components/exercise-form/OptionRow.tsx`
- `cms/components/exercise-form/PoslechFields.tsx`
- `cms/components/exercise-form/CteniFields.tsx`
- `cms/components/exercise-form/index.tsx` (warning indicator)
- `flutter_app/lib/features/exercise/models/exercise_detail.dart`
- `flutter_app/lib/features/exercise/widgets/multiple_choice_widget.dart`

**CMS changes:**
1. `OptionRow.tsx` — thêm props: `imageAssetId?: string`, `exerciseId: string`, `onImageUploaded?: (assetId: string) => void`, `onImageRemoved?: () => void`
2. Trong `OptionRow` render: thumbnail 56×44 + upload button (reuse `/admin/exercises/:exerciseId/assets/upload` với `asset_kind: "option_image"`)
3. `PoslechFields.tsx` + `CteniFields.tsx`: truyền `exerciseId` xuống `OptionRow`, handle `onImageUploaded` → cập nhật option state với `image_asset_id`
4. `index.tsx`: warning banner khi `0 < countOptionsWithImage < totalOptions` — "X/Y options chưa có ảnh — Flutter dùng text list"
5. Chỉ apply cho exercise types dùng `MultipleChoiceOption`: `послech_1`, `послech_2`, `cteni_2`, `cteni_3`, `cteni_4`

**Flutter changes:**
1. `MultipleChoiceOption.fromJson()` parse `image_asset_id`
2. `MultipleChoiceWidget`:
   ```dart
   final allHaveImages = options.every((o) => o.imageAssetId?.isNotEmpty == true);
   ```
   - `allHaveImages = true` → `GridView.count(crossAxisCount: 2)` với image cells
   - `allHaveImages = false` → giữ ListView layout hiện tại
3. Image cell: `Image.network` aspect 4:3, label text phía dưới, border 2.5px:
   - Default: `AppColors.border` (gray-200)
   - Selected: `AppColors.primary` (#FF6A14) + check badge góc trên phải
   - Correct: `AppColors.success` (green)
   - Wrong: `AppColors.error` (red) + opacity 0.6
4. Image fail trong cell → letter placeholder (A/B/C/D) centered, interaction unblocked

**AC:**
- CMS: `OptionRow` hiện thumbnail + upload button khi `exerciseId` truyền vào
- CMS: warning hiện khi mixed images, ẩn khi 0 hoặc tất cả có ảnh
- Flutter: tất cả options có `image_asset_id` → 2×2 grid render
- Flutter: 1 option thiếu ảnh → text list (không mixed)
- Selected/correct/wrong states đúng trong grid layout
- Existing `MultipleChoiceWidget` callers không bị break
- `make flutter-analyze` + `make cms-build` pass

---

### ME-4 — Matching với ảnh (Flutter MatchingWidget)

**Phụ thuộc:** ME-1, ME-3 (CMS option upload pattern reusable cho matching options)

**Files:**
- `flutter_app/lib/features/exercise/models/exercise_detail.dart`
- `flutter_app/lib/features/exercise/widgets/matching_widget.dart`

**Flutter changes:**
1. `MatchOption.fromJson()` parse `image_asset_id`
2. `MatchingWidget` — right column rendering:
   ```dart
   // Nếu matchOption.imageAssetId?.isNotEmpty == true:
   //   Render image card: Image.network (aspect 4:3) + label text nhỏ phía dưới
   // Else:
   //   Render text tile (unchanged)
   ```
3. Image card border state: unmatched → gray, matched → green border + text "✓"
4. Image fail → fallback text-only tile, matching vẫn hoạt động
5. Left column (Czech words) unchanged

**Note:** CMS upload cho `MatchOption.image_asset_id` dùng lại `OptionRow` đã có từ ME-3, chỉ cần wire vào matching form nếu có.

**AC:**
- `MatchOption` với `image_asset_id` → image card hiện trong right column
- `MatchOption` không có ảnh → text tile (unchanged)
- Mixed options (có + không ảnh) trong cùng exercise → mix render (image card + text tile)
- Correct pair highlight đúng trên cả hai loại
- `make flutter-analyze` pass

**[CHECKPOINT ME-B]** `make flutter-analyze` + `make backend-test`.
Manual: послech_2 exercise với 4 options đều có ảnh → grid. послech_1 không ảnh → text list.

---

### ME-5 — Grammar rule image (backend + CMS)

**Phụ thuộc:** ME-1

**Files:**
- `cms/components/grammar-form.tsx` (hoặc tương đương)
- (Flutter đã handle image rendering từ ME-2/ME-3)

**Backend:** Đã hoàn thành trong ME-1 (migration 021 + endpoints).

**CMS changes:**
1. Grammar rule form: thêm ảnh context upload (thumbnail 52×52 + `+ Tải ảnh`)
2. Upload flow: `POST /v1/admin/grammar-rules/:id/image`
3. Pattern y hệt vocab item từ ME-2

**Flutter:** `GrammarRule.fromJson()` parse `image_asset_id`. Nếu grammar exercise dùng `QuizcardWidget` hoặc `MatchingWidget` → đã tự có image rendering từ ME-2/ME-4.

**AC:**
- CMS grammar form upload ảnh → `image_asset_id` lưu trong DB
- `GET /v1/grammar-rules/:id` trả `image_asset_id`
- `make cms-build` pass

---

### ME-6 — Exercise context image / Direction B (CMS + Flutter)

**Phụ thuộc:** ME-1

**Files:**
- `cms/components/exercise-form/index.tsx` hoặc `SpeakingFields.tsx` (thêm tab/section)
- `flutter_app/lib/features/exercise/widgets/` — exercise prompt area trong mỗi screen

**Context:** `Exercise.Assets []PromptAsset` đã có + đã parse. Đang dùng cho speaking Uloha3/4. Cần enable cho tất cả exercise types.

**CMS changes:**
1. Exercise form: thêm section "Ảnh ngữ cảnh (tùy chọn)" trong tất cả exercise type forms (không chỉ speaking)
2. Upload → `POST /admin/exercises/:id/assets/upload` với `asset_kind: "context_image"`
3. Preview thumbnail trong form
4. Xóa: `DELETE /admin/exercises/:id/assets/:asset_id`

**Flutter changes:**
1. Trong mỗi exercise screen (Listening/Reading/Writing/VocabGrammar): kiểm tra `exercise.assets.where((a) => a.assetKind == 'context_image')`
2. Nếu có → render image 16:9 với `borderRadius: 12` phía trên question text/audio player
3. Fail → ẩn hoàn toàn, không hiện placeholder, không block exercise
4. Speaking screens đã có `uloha_prompt.dart` — verify không duplicate

**AC:**
- CMS: upload ảnh context cho exercise type bất kỳ (nghe/đọc/viết/từ vựng/ngữ pháp)
- Flutter: context image hiện phía trên question trên tất cả exercise screens
- Không có ảnh → layout unchanged
- Speaking screens không bị duplicate (check `uloha_prompt.dart` không bị override)
- `make flutter-analyze` + `make cms-build` pass

**[CHECKPOINT ME-C]** `make verify` (backend-build + backend-test + cms-lint + cms-build + flutter-analyze + flutter-test).
Manual end-to-end: (1) Upload ảnh vocab → flashcard có hình. (2) послech_2 với 4 ảnh option → grid. (3) Exercise bất kỳ với context image → hiện phía trên.

---

## V12 — Deck Session Mode (Từ vựng & Ngữ pháp)

**Spec:** `docs/specs/deck-session-vocab-grammar.md`  
**Design:** `docs/designs/deck-session-vocab-grammar.html`  
**Idea:** `docs/ideas/deck-session-vocab-grammar.md`  
**Scope:** Flutter iOS only. No backend. No CMS.

### Dependency graph

```
DS-1 (entry point change)
  └─ DS-2 (TypeGroupScreen)
       └─ DS-3 (VocabTypeListScreen + _openExercise)
            └─ DS-4 (DeckSessionScreen — quizcard core)
                 ├─ DS-5 (DeckSessionScreen — choice_word + fill_blank)
                 ├─ DS-6 (DeckSessionScreen — matching)
                 └─ DS-7 (widget tests)
```

### DS-1 — Entry point: module_detail_screen.dart

**File:** `flutter_app/lib/features/home/screens/module_detail_screen.dart`

**Change** (line ~123): wrap existing `Navigator.push(ExerciseListScreen(...))` trong condition:
```dart
onTap: sk.isImplemented ? () {
  if (sk.skillKind == 'tu_vung' || sk.skillKind == 'ngu_phap') {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TypeGroupScreen(
        client: widget.client,
        moduleId: widget.module.id,
        skillKind: sk.skillKind,
        moduleTitle: widget.module.title,
      ),
    ));
  } else {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ExerciseListScreen(
        client: widget.client,
        moduleId: widget.module.id,
        skillKind: sk.skillKind,
      ),
    ));
  }
} : null,
```

Import `TypeGroupScreen` từ `type_group_screen.dart`.

**AC:** Tap "Từ vựng" hoặc "Ngữ pháp" → TypeGroupScreen. Các skill khác (noi/nghe/doc/viet) → ExerciseListScreen unchanged.

---

### DS-2 — TypeGroupScreen

**File:** `flutter_app/lib/features/exercise/screens/type_group_screen.dart`

**Data loading:**
```dart
final raw = await widget.client.listModuleExercises(widget.moduleId, skillKind: widget.skillKind);
final exercises = raw.map((e) => ExerciseSummary.fromJson(e)).toList();
// group: Map<String, List<ExerciseSummary>>
final grouped = <String, List<ExerciseSummary>>{};
for (final ex in exercises) { grouped.putIfAbsent(ex.exerciseType, () => []).add(ex); }
```

**Type config (const list, order matters):**
```dart
static const _types = [
  _TypeConfig(type: 'quizcard_basic', label: 'Flashcard',  icon: '📚'),
  _TypeConfig(type: 'matching',       label: 'Ghép đôi',   icon: '↔'),
  _TypeConfig(type: 'fill_blank',     label: 'Điền từ',    icon: '✏'),
  _TypeConfig(type: 'choice_word',    label: 'Chọn từ',    icon: '✓'),
];
```

**UI:**
- AppBar: skill label ("Từ vựng" / "Ngữ pháp") với back button
- Subtitle: `widget.moduleTitle`
- Body: 2-col `GridView` (hoặc `Wrap`) với `_TypeCard` widgets
- Chỉ render card nếu `grouped[type] != null && grouped[type]!.isNotEmpty`
- Loading: `CircularProgressIndicator` centered
- Error: retry button

**_TypeCard tap** → `Navigator.push(VocabTypeListScreen(exercises: grouped[type]!, ...))`

**AC:** TypeGroupScreen load đúng count, chỉ hiện types có bài, tap card navigate đúng.

---

### DS-3 — VocabTypeListScreen

**File:** `flutter_app/lib/features/exercise/screens/vocab_type_list_screen.dart`

**Constructor:**
```dart
const VocabTypeListScreen({
  required this.client,
  required this.moduleId,
  required this.exerciseType,
  required this.typeLabel,
  required this.exercises,   // pre-loaded, filtered by exerciseType
});
```

**Không fetch API** — nhận `exercises` từ parent.

**UI:**
```
AppBar(title: typeLabel, actions: [count badge])
Column(
  ElevatedButton("▶ Bắt đầu học tất cả (N)")  → DeckSessionScreen
  SizedBox(height: 8)
  Text("Hoặc học từng bài", style: labelSmall)
  Expanded(ListView(exercises.map(_ExerciseListTile)))
)
```

**`_openExercise`** — copy pattern từ `ExerciseListScreen._openExercise`:
- `await client.getExercise(exercise.id)` → parse `ExerciseDetail`
- Push `VocabGrammarExerciseScreen(client, detail, onOpenNext: null)`
- Error → SnackBar

**"Bắt đầu học tất cả"** → `Navigator.push(DeckSessionScreen(client, moduleId, exerciseType, typeLabel, exercises))`

**AC:** Button visible với count đúng; individual exercise tap mở VocabGrammarExerciseScreen; deck button mở DeckSessionScreen.

---

### DS-4 — DeckSessionScreen: core + quizcard_basic

**File:** `flutter_app/lib/features/exercise/screens/deck_session_screen.dart`

**State:**
```dart
late ListQueue<ExerciseSummary> _queue;
final Set<String> _knownIds = {};
int _totalCount = 0;
ExerciseDetail? _currentDetail;
bool _loadingDetail = false;
bool _sessionComplete = false;
```

**initState:**
```dart
_totalCount = widget.exercises.length;
_queue = ListQueue.from(widget.exercises);
_loadCurrentDetail();
```

**`_loadCurrentDetail()`:**
```dart
Future<void> _loadCurrentDetail() async {
  if (_queue.isEmpty) return;
  setState(() { _loadingDetail = true; _currentDetail = null; });
  try {
    final raw = await widget.client.getExercise(_queue.first.id);
    if (mounted) setState(() { _currentDetail = ExerciseDetail.fromJson(raw); _loadingDetail = false; });
  } catch (_) {
    if (mounted) setState(() => _loadingDetail = false);
  }
}
```

**AppBar:**
- Back → `showDialog` confirm nếu `!_sessionComplete && _queue.isNotEmpty`
- Title: `widget.typeLabel`

**Progress header:**
```dart
// "3 / 8 đã biết"
Text('${_knownIds.length} / $_totalCount đã biết')
LinearProgressIndicator(value: _knownIds.length / _totalCount)
```

**Body switch:**
- `_sessionComplete` → `_CompletionView`
- `_loadingDetail || _currentDetail == null` → loading spinner
- `_currentDetail!.isQuizcard` → `_QuizcardDeckCard`
- else → `_OtherTypeDeckCard` (DS-5/DS-6)

**`_QuizcardDeckCard`:**
- Wrap `QuizcardWidget(front, back, example, submitting: false, onChoice: _handleQuizcardChoice)`
- `QuizcardWidget` đã có flip animation + Đã biết/Ôn lại buttons

**`_handleQuizcardChoice(String choice)`:**
```dart
void _handleQuizcardChoice(String choice) {
  final current = _queue.removeFirst();
  if (choice == 'known') {
    _knownIds.add(current.id);
  } else {
    _queue.addLast(current);
  }
  if (_queue.isEmpty) {
    setState(() => _sessionComplete = true);
  } else {
    _loadCurrentDetail();
  }
}
```

**`_CompletionView` (private widget):**
```dart
// params: knownCount, totalCount, onRetry (replay với exercises chưa known), onDone
// UI: icon + title + stat + primary/secondary buttons
```

**AC:**
- Quizcard deck: flip → unlock buttons → Đã biết removes card, progress tăng
- Ôn lại: card xuất hiện lại cuối queue
- Queue rỗng → CompletionView inline
- Back button mid-session: dialog confirm
- Không có network call đến `/v1/attempts`

---

### DS-5 — DeckSessionScreen: choice_word + fill_blank

**Thêm vào `deck_session_screen.dart`:**

**Choice word card `_ChoiceWordDeckCard`:**
```dart
// state: String? _selectedKey, bool _revealed
// UI: stem text + 4 option buttons
// tap option:
//   if !_revealed: _selectedKey = key; _revealed = true;
//   highlight: correct=green, selected wrong=red
//   show "Tiếp theo →" FilledButton

// Local check:
bool _isCorrect(ExerciseDetail d, String key) =>
    key.toLowerCase() == (d.correctAnswers['1'] ?? '').toLowerCase();
```

**Advance (choice/fill):** `_advanceKnown()`:
```dart
void _advanceKnown() {
  _knownIds.add(_queue.removeFirst().id);
  if (_queue.isEmpty) setState(() => _sessionComplete = true);
  else _loadCurrentDetail();
}
```

**Fill blank card `_FillBlankDeckCard`:**
```dart
// state: TextEditingController _ctrl, bool _submitted, bool _isCorrect
// UI: sentence với ___ highlighted + TextField + Submit button
// Submit:
//   _isCorrect = answer.trim().toLowerCase().contains(correct.toLowerCase())
//   _submitted = true
//   show result feedback + "Tiếp theo →"

// Fill blank local check:
bool _checkFill(ExerciseDetail d, String answer) =>
    answer.trim().toLowerCase().contains(
      (d.correctAnswers['1'] ?? '').toLowerCase()
    );
```

**AC:**
- Choice word: tap option → highlight đúng/sai → "Tiếp theo →" → advance
- Fill blank: type → submit → feedback → "Tiếp theo →" → advance
- Tất cả advance → treated as known (queue.removeFirst + knownIds.add)

---

### DS-6 — DeckSessionScreen: matching

**Matching card `_MatchingDeckCard`:**
```dart
// state: Map<String,String> _answers = {}
// UI: MatchingWidget(pairs: d.matchPairs, answers: _answers, onChanged: (a) => setState(() => _answers = a))
// "Tiếp theo →" enabled when _answers.length == d.matchPairs.length
// tap → _advanceKnown()
```

**Note:** `MatchingWidget` đã có đầy đủ interaction logic (select/pair/un-pair). Deck chỉ cần wrap và detect completion.

**AC:** Matching deck: pair all items → "Tiếp theo →" active → advance.

---

### DS-7 — Widget tests

**File:** `flutter_app/test/deck_session_test.dart`

**Tests:**
1. `TypeGroupScreen` renders 4 type cards khi có exercises đủ các loại
2. `TypeGroupScreen` ẩn type card khi không có exercise cho loại đó
3. `VocabTypeListScreen` hiện "Bắt đầu học tất cả (N)" với đúng count
4. `DeckSessionScreen` quizcard: `onChoice('known')` → progress tăng + card advance
5. `DeckSessionScreen` quizcard: `onChoice('review')` → card push back, không tăng known
6. `DeckSessionScreen`: queue empty sau known → CompletionView renders
7. `_CompletionView`: hiện đúng knownCount/totalCount

**Verification:** `make flutter-test` pass, `make flutter-analyze` pass.

---

### [CHECKPOINT DS-A] — sau DS-4

`make flutter-analyze && make flutter-test`  
Manual: Tap Từ vựng → TypeGroupScreen → Flashcard list → "Bắt đầu học tất cả" → deck với quizcard → completion.

### [CHECKPOINT DS-FINAL]

`make flutter-analyze && make flutter-test`  
Manual: deck qua đủ 4 types. Verify no network call đến `/v1/attempts` trong deck mode.

---

## V13 — Ano/Ne Exercise Type

Spec: `SPEC.md` § V13 · `docs/specs/ano-ne-exercise-type.md`  
Design: `docs/designs/ano-ne-exercise-type.html`  
Idea: `docs/ideas/ano-ne-exercise-type.md`

### Dependency graph

```
AN-1 (Backend foundation)
  ├── AN-2 (Backend tests)        — requires AN-1
  └── AN-3 (Docs update)         — requires AN-1
  
[CHECKPOINT AN-A]                — requires AN-1, AN-2, AN-3

AN-4 (CMS utils + AnoNeFields)   — độc lập, chạy song song với Flutter
AN-5 (CMS wire + tests)         — requires AN-4

[CHECKPOINT AN-B]               — requires AN-4, AN-5

AN-6 (Flutter widget + model)    — độc lập, chạy song song với CMS
AN-7 (Flutter screens + i18n)   — requires AN-6
AN-8 (Flutter tests)            — requires AN-6, AN-7

[CHECKPOINT AN-FINAL]           — requires tất cả
```

### Slice AN-1 — Backend foundation

**Files:**
- `backend/internal/contracts/types.go` — thêm `AnoNeDetail`, `AnoNeStatement`
- `backend/internal/processing/objective_scorer.go` — thêm nhánh `statements[].statement` trong `extractQuestionTexts`
- `backend/internal/processing/exercise_audio.go` — thêm `case "poslech_6": return buildAnoNeAudioText(exercise.Detail)`
- `backend/internal/server.go` (hoặc exercise handler) — accept `"cteni_6"`, `"poslech_6"` trong valid exercise type list

**Changes chi tiết:**

```go
// contracts/types.go
type AnoNeDetail struct {
    Passage        string            `json:"passage"`
    Statements     []AnoNeStatement  `json:"statements"`
    CorrectAnswers map[string]string `json:"correct_answers"` // "1"→"ANO"
    MaxPoints      int               `json:"max_points,omitempty"`
}
type AnoNeStatement struct {
    QuestionNo int    `json:"question_no"`
    Statement  string `json:"statement"`
}

// objective_scorer.go — extractQuestionTexts, sau nhánh "questions"
var withStatements struct {
    Statements []struct {
        QuestionNo int    `json:"question_no"`
        Statement  string `json:"statement"`
    } `json:"statements"`
}
if json.Unmarshal(b, &withStatements) == nil {
    for _, s := range withStatements.Statements {
        if s.Statement != "" {
            texts[fmt.Sprintf("%d", s.QuestionNo)] = s.Statement
        }
    }
}

// exercise_audio.go — BuildExerciseAudioText switch
case "poslech_6":
    return buildAnoNeAudioText(exercise.Detail)
```

**AC:**
- `make backend-build` pass, 0 compiler errors
- `POST /v1/admin/exercises` với `exercise_type: "cteni_6"` không trả 400 "invalid type"

---

### Slice AN-2 — Backend tests

**File:** `backend/internal/processing/objective_scorer_test.go`

Test cases cần thêm:
```go
TestScoreObjectiveAnswers_AnoNe_AllCorrect       // {"1":"ANO","2":"NE"} vs same → score=2
TestScoreObjectiveAnswers_AnoNe_SomeWrong         // {"1":"ANO","2":"ANO"} vs {"1":"ANO","2":"NE"} → score=1
TestScoreObjectiveAnswers_AnoNe_CaseInsensitive   // {"1":"ano"} vs {"1":"ANO"} → correct
TestExtractQuestionTexts_Statements               // statements[].statement → map["1"]="Na úřadu..."
TestBuildExerciseAudioText_Poslech6               // exercise.Detail = AnoNeDetail{passage:"..."} → "..."
```

**AC:** `make backend-test` pass, 5 test cases mới đều green.

---

### Slice AN-3 — Docs update

**Files:**
- `docs/specs/content-and-attempt-model.md` — thêm `cteni_6` và `poslech_6` vào `ExerciseType` enum
- `docs/specs/api-contracts.md` — ghi chú `cteni_6`/`poslech_6` hợp lệ với `submit-answers`

**AC:** Docs updated, không cần build check.

---

### [CHECKPOINT AN-A]

```
make backend-build && make backend-test
```

Manual: `POST /v1/admin/exercises` body `{"exercise_type":"cteni_6","title":"Test","module_id":"...","skill_kind":"doc","pool":"course","status":"draft","detail":{"passage":"Vlašim...","statements":[{"question_no":1,"statement":"Je zavřeno v pátek?"}],"correct_answers":{"1":"ANO"},"max_points":1}}` → 200.

---

### Slice AN-4 — CMS utils + AnoNeFields

**Files:**
- `cms/lib/exercise-utils.ts` — thêm `ANO_NE_TYPES`, `AnoNeFormState`, `buildAnoNePayload()`, `formStateFromAnoNe()`
- `cms/components/exercise-form/AnoNeFields.tsx` — NEW component

**AnoNeFields layout:**
1. Passage textarea (required, label "Văn bản / Script", helper text cho poslech_6)
2. Max points input (number, min 1, default 3)
3. Statement repeater (1–5 rows):
   - Row: index badge (A/B/C/D/E) + statement input + ANO/NE toggle buttons + delete icon
   - "+ Thêm câu" button (disabled khi = 5 rows)
4. Validation inline: passage non-empty, ≥1 statement, mỗi statement non-empty

**AC:** `make cms-build` pass. Component render đúng trong storybook/dev với 3 statements.

---

### Slice AN-5 — CMS wire + tests

**File:** `cms/components/exercise-form/index.tsx`

Thêm trước `startsWith('poslech_')` và `startsWith('cteni_')` checks:

```tsx
// IMPORTANT: cteni_6 và poslech_6 phải check TRƯỚC startsWith vì chúng cần AnoNeFields, không phải CteniFields/PoslechFields
{(form.exerciseType === 'cteni_6' || form.exerciseType === 'poslech_6') && (
  <AnoNeFields
    value={formState as AnoNeFormState}
    onChange={setFormState}
    exerciseType={form.exerciseType as 'cteni_6' | 'poslech_6'}
  />
)}
{form.exerciseType.startsWith('poslech_') && form.exerciseType !== 'poslech_6' && (
  <PoslechFields ... />
)}
{form.exerciseType.startsWith('cteni_') && form.exerciseType !== 'cteni_6' && (
  <CteniFields ... />
)}
```

**File:** `cms/lib/exercise-utils.test.ts` — thêm test cases:
```ts
describe('buildAnoNePayload', () => {
  it('builds valid 3-statement payload')
  it('rejects >5 statements')
  it('uppercase ANO/NE in correct_answers')
})
describe('formStateFromAnoNe', () => {
  it('roundtrip: buildAnoNePayload → formStateFromAnoNe')
})
```

**AC:** `make cms-lint && make cms-build && cd cms && npm test` pass.

---

### [CHECKPOINT AN-B]

```
make cms-lint && make cms-build && cd cms && npm test
```

Manual CMS: Tạo exercise type `cteni_6` → AnoNeFields render → thêm 3 statements → toggle ANO/NE → Lưu → reload → data đúng.

---

### Slice AN-6 — Flutter widget + model extension

**Files:**

1. `flutter_app/lib/features/exercise/widgets/ano_ne_widget.dart` — NEW

```dart
class AnoNeWidget extends StatefulWidget {
  const AnoNeWidget({
    super.key,
    required this.statements,          // List<AnoNeStatement>
    required this.onAnswersChanged,    // void Function(Map<String,String>)
    this.result,                       // ObjectiveResult? — null trước submit
    this.enabled = true,
  });
}

class _AnoNeRow extends StatelessWidget {
  // statement text + ANO button + NE button
  // selected: ANO = green filled, NE = red filled
  // post-submit: disabled, correct = filled, wrong = strikethrough + correct highlighted
  // min tap target: 44×44
}
```

2. `flutter_app/lib/models/models.dart` — thêm `AnoNeStatement` model + getters vào `ExerciseDetail`:

```dart
class AnoNeStatement {
  final int questionNo;
  final String statement;
  const AnoNeStatement({required this.questionNo, required this.statement});
  factory AnoNeStatement.fromJson(Map<String, dynamic> j) =>
      AnoNeStatement(questionNo: j['question_no'] as int, statement: j['statement'] as String? ?? '');
}

// Trong ExerciseDetail:
List<AnoNeStatement> get anoNeStatements =>
    (detail['statements'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(AnoNeStatement.fromJson)
        .toList();

String get passage => detail['passage'] as String? ?? '';
```

3. `flutter_app/lib/l10n/intl_vi.arb` + `intl_en.arb` — thêm 5 keys:
   - `anoButton`: `ANO` / `YES`
   - `neButton`: `NE` / `NO`
   - `anoNeInstruction`: `Đúng hay sai?` / `True or false?`
   - `anoNeCorrectHint`: `Đúng ✓` / `Correct ✓`
   - `anoNeWrongHint`: `Sai — đáp án: {answer}` / `Wrong — correct: {answer}`

4. Regenerate: `flutter gen-l10n` (hoặc `make flutter-analyze` tự trigger)

**AC:** `make flutter-analyze` pass, 0 errors.

---

### Slice AN-7 — Flutter screens + i18n wiring

**File 1:** `flutter_app/lib/features/exercise/screens/reading_exercise_screen.dart`

Thêm branch TRƯỚC `if (d.exerciseType == 'cteni_1')`:

```dart
// cteni_6: passage card + AnoNe widget
if (d.exerciseType == 'cteni_6') ...[
  ..._buildCteni6Layout(d),
] else if (d.exerciseType == 'cteni_1') ...[
  ..._buildCteni1Layout(d),
] else ...[
  // existing cteni_2/3/4/5 layout
]
```

```dart
List<Widget> _buildCteni6Layout(ExerciseDetail d) {
  return [
    // Passage card (white card, tên địa điểm, passage text)
    Card(child: Padding(padding: ..., child: SelectableText(d.passage))),
    const SizedBox(height: 12),
    AnoNeWidget(
      statements: d.anoNeStatements,
      onAnswersChanged: (a) => setState(() => _answers = a),
      result: _result?.objectiveResult,
      enabled: _result == null,
    ),
  ];
}
```

**File 2:** `flutter_app/lib/features/exercise/screens/listening_exercise_screen.dart`

Thêm branch cho `poslech_6`:

```dart
// Trong body build, thêm sau AudioPlayerWidget:
if (d.exerciseType == 'poslech_6') ...[
  AnoNeWidget(
    statements: d.anoNeStatements,
    onAnswersChanged: (a) => setState(() => _answers = a),
    result: _result?.objectiveResult,
    enabled: _result == null,
  ),
] else ...[
  // existing _buildItemAnswers(d)
]
```

**Submit gate** (cả 2 screens): submit button enabled khi `_answers.length == d.anoNeStatements.length`.

**AC:** `make flutter-analyze` pass, 0 errors.

---

### Slice AN-8 — Flutter tests

**File:** `flutter_app/test/ano_ne_widget_test.dart` — NEW

```dart
// 5 test cases:
testWidgets('renders all statements', ...)
testWidgets('ANO selects → NE deselects for same row', ...)
testWidgets('selecting different rows independent', ...)
testWidgets('onAnswersChanged called with correct map', ...)
testWidgets('post-result: correct row green, wrong row red, buttons disabled', ...)
```

**AC:** `make flutter-test` pass. Test count tăng từ 64 → 69+.

---

### [CHECKPOINT AN-FINAL]

```
make backend-build && make backend-test
make cms-lint && make cms-build && cd cms && npm test
make flutter-analyze && make flutter-test
```

Manual E2E (iOS Simulator):
1. CMS: tạo `cteni_6` với 3 statements → publish
2. Flutter: Module → exercise list → mở cteni_6 → đọc passage → chọn ANO/NE cho 3 câu → submit → ObjectiveResultCard hiện score + per-statement ✓/✗
3. CMS: tạo `poslech_6` → generate audio → publish
4. Flutter: mở poslech_6 → play audio → chọn ANO/NE → submit → kết quả đúng

---

## V14 — Interview Skill: ElevenLabs Conversational AI + Simli Avatar

Spec: `SPEC.md` § V14  
Idea: `docs/ideas/interview-skill.md`  
Design: `docs/designs/interview-skill.html`

Hai exercise types: `interview_conversation` (hội thoại chủ đề) + `interview_choice_explain` (chọn phương án + giải thích).  
Platform: Flutter iOS only. Entry: `ModuleDetail` như các skill_kind khác.

---

### Dependency graph

```
IV-0 (spike — BLOCKER) ── PHẢI PASS TRƯỚC KHI VIẾT BẤT KỲ CODE PRODUCTION NÀO
           │
           ▼
IV-1 (Backend: contracts + env + exercise type validation)
    │
    ├──→ IV-2 (Backend: token endpoint + submit endpoint + interview_scorer.go)
    │         └──→ IV-3 (Backend tests: scorer + token injection)
    │
    ├──→ IV-4 (CMS: 2 exercise type forms + wire)
    │
    └──→ IV-5 (Flutter: models + api_client + i18n + ModuleDetail entry)
              │
              ├──→ IV-6 (Flutter: custom ElevenLabs Dart WS client)
              │         └──→ IV-7 (Flutter: IntroScreens + SessionScreen audio-only)
              │                   └──→ IV-8 (Flutter: ResultScreen)
              │
[CHECKPOINT IV-A: Sprint 1 — full conversation, no avatar, lên simulator]
              │
              └──→ IV-9 (Flutter: Simli integration — pubspec + simli_session_manager)
                        └──→ IV-10 (Flutter: avatar RTCVideoView trong SessionScreen)
                                  └──→ IV-11 (Flutter: all widget tests)

[CHECKPOINT IV-FINAL]
```

---

### IV-0 — Sprint 0 Spike (BLOCKER)

**Không commit vào main. Standalone test apps.**

**Files tạm (xóa sau):**
- `spike/elevenlabs_czech_test.md` — notes từ ElevenLabs dashboard test
- `spike/simli_flutter_poc/` — standalone Flutter project

**Checklist bắt buộc trước khi tiếp tục:**
```
[ ] A. ElevenLabs dashboard: tạo Conversational AI agent với Czech system prompt
       → Nói tiếng Czech, nghe được, trả lời A2-appropriate
       → Ngôn ngữ: Czech (không bị fallback sang English)
       → Latency response ≤ 2s từ khi learner ngừng nói

[ ] B. simli_client standalone Flutter app trên iPhone thật:
       → `simli_client: ^1.0.1` build thành công iOS
       → RTCVideoView render (dù chỉ là placeholder)
       → `sendAudioData(Uint8List.fromList([0,0,...]))` không crash
       → Kết nối Simli WebSocket thành công với SIMLI_API_KEY + SIMLI_FACE_ID

[ ] C. PCM16 format compatibility:
       → ElevenLabs ConvAI output: PCM16, 16kHz, mono (verify từ docs/event messages)
       → Simli input: PCM16 `Uint8List` (verify từ simli_client README)
       → Hai format khớp → không cần conversion layer

[ ] D. Latency end-to-end acceptable (đo trên iPhone, không simulator):
       → Thời gian từ learner ngừng nói → avatar bắt đầu cử động < 1.5s
```

**AC:** Tất cả 4 mục checked. Ghi lại kết quả trong `docs/ideas/interview-skill.md` phần assumptions.

---

### IV-1 — Backend: Contracts + Env + Validation

**Files:**
- `backend/internal/contracts/types.go` — thêm 8 types mới
- `backend/internal/httpapi/server.go` — thêm 2 routes + exercise type validation
- `.env.example` (hoặc README) — document 3 env vars mới

**New types:**
```go
type InterviewConversationDetail struct {
    Topic          string   `json:"topic"`
    Tips           []string `json:"tips,omitempty"`
    SystemPrompt   string   `json:"system_prompt"`
    MaxTurns       int      `json:"max_turns"`
    ShowTranscript bool     `json:"show_transcript"`
}

type InterviewChoiceExplainDetail struct {
    Question       string            `json:"question"`
    Options        []InterviewOption `json:"options"`
    SystemPrompt   string            `json:"system_prompt"`
    MaxTurns       int               `json:"max_turns"`
    ShowTranscript bool              `json:"show_transcript"`
}

type InterviewOption struct {
    ID           string `json:"id"`
    Label        string `json:"label"`
    ImageAssetID string `json:"image_asset_id,omitempty"`
}

type InterviewTokenRequest struct {
    ExerciseID     string `json:"exercise_id"`
    AttemptID      string `json:"attempt_id"`
    SelectedOption string `json:"selected_option,omitempty"`
}

type InterviewTokenResponse struct {
    SignedURL  string `json:"signed_url"`
    ExpiresIn int    `json:"expires_in"`
}

type InterviewTranscriptTurn struct {
    Speaker string `json:"speaker"` // "examiner" | "learner"
    Text    string `json:"text"`
    AtSec   int    `json:"at_sec"`
}

type InterviewSubmitRequest struct {
    Transcript  []InterviewTranscriptTurn `json:"transcript"`
    DurationSec int                       `json:"duration_sec"`
}
```

**Validation trong `handleCreateExercise`/`handleUpdateExercise`:**
- Accept `interview_conversation` và `interview_choice_explain` như valid exercise types
- `interview_choice_explain`: validate `options` length 3–4
- `interview_conversation`/`_choice_explain`: validate `system_prompt` không rỗng
- `skill_kind = "interview"` → valid skill kind list

**Env vars mới (đọc trong main.go, truyền vào Server struct):**
```go
ELEVENLABS_API_KEY   // required if interview exercises exist
```
Không fatal nếu thiếu — log warning, endpoint trả 503 nếu thiếu key.

**AC:** `make backend-build` passes. `handleCreateExercise` với `interview_conversation` không trả 400 validation error.

---

### IV-2 — Backend: Token Endpoint + Submit Endpoint + Scorer

**Files:**
- `backend/internal/httpapi/server.go` — thêm handlers
- `backend/internal/processing/interview_scorer.go` — NEW
- `backend/internal/httpapi/interview_handler.go` — NEW (hoặc inline trong server.go)

**`POST /v1/interview-sessions/token` handler:**
```go
// 1. Parse InterviewTokenRequest
// 2. Load exercise by exercise_id, check skill_kind == "interview"
// 3. Verify attempt exists + belongs to authenticated learner
// 4. Load detail (InterviewConversationDetail hoặc InterviewChoiceExplainDetail)
// 5. Build system_prompt: inject selected_option nếu có
//    prompt = strings.ReplaceAll(detail.SystemPrompt, "{selected_option}", req.SelectedOption)
// 6. Call ElevenLabs: POST https://api.elevenlabs.io/v1/convai/conversation/get_signed_url
//    Headers: xi-api-key: ELEVENLABS_API_KEY
//    Body: { "agent_id": ..., "conversation_config_override": { "agent": { "prompt": { "prompt": injectedPrompt } } } }
// 7. Return InterviewTokenResponse { signed_url, expires_in }
```

**`POST /v1/attempts/:id/submit-interview` handler:**
```go
// 1. Parse InterviewSubmitRequest
// 2. Validate attempt belongs to learner, status != completed
// 3. Save transcript turns to attempt.transcript_json
// 4. Update attempt status = "scoring"
// 5. Launch goroutine: defer recover() → processInterviewAttempt(attemptID)
// 6. Return attempt (status=scoring) immediately
```

**`interview_scorer.go`:**
```go
func (p *Processor) processInterviewAttempt(attemptID string) {
    // 1. Load attempt + exercise + transcript turns
    // 2. Build Claude prompt:
    //    - exercise type + topic/question
    //    - full transcript (labeled "Examiner:" / "Learner:")
    //    - duration_sec
    //    - rubric: vocab_score, grammar_score, fluency_score (0-10 each)
    //    - overall readiness_level (weak/ok/strong)
    //    - feedback_items (max 4, Czech-A2 specific)
    //    - model_answer_sample (optional)
    // 3. Call LLM via tool_use schema
    // 4. Build AttemptFeedback from response
    // 5. FailAttempt on panic/error
}
```

Reuse `LLMFeedbackProvider` interface pattern. Fallback to rule-based nếu LLM unavailable.

**AC:** `make backend-build` passes. Manual test: `POST /v1/interview-sessions/token` với valid exercise_id → nhận `signed_url`. `POST /v1/attempts/:id/submit-interview` → status=scoring.

---

### IV-3 — Backend Tests

**Files:**
- `backend/internal/processing/interview_scorer_test.go` — NEW

```go
TestProcessInterviewAttempt_StrongConversation
    // Full transcript 6 turns, fluent answers → readiness_level=strong
TestProcessInterviewAttempt_WeakConversation
    // Monosyllabic replies (Ano. / Ne.) → readiness_level=weak
TestProcessInterviewAttempt_ChoiceExplain_Strong
    // Good explanation with reasoning → readiness_level=strong
TestInjectSelectedOption_ReplacesPlaceholder
    // system_prompt với {selected_option} + req.SelectedOption="Praha" → Prague in prompt
TestInjectSelectedOption_NoPlaceholder_Unchanged
    // system_prompt tanpa {selected_option} → prompt không đổi
TestInjectSelectedOption_EmptyOption_Unchanged
    // interview_conversation (no selected_option) → prompt không đổi
```

**AC:** `make backend-test` passes. 6+ test cases mới pass.

---

### IV-4 — CMS: Interview Exercise Forms

**Files:**
- `cms/app/exercises/exercise-utils.ts` — thêm `InterviewConversationFormState`, `InterviewChoiceExplainFormState`, `buildInterviewConversationPayload`, `buildInterviewChoiceExplainPayload`, `formStateFromInterviewConversation`, `formStateFromInterviewChoiceExplain`
- `cms/app/exercises/components/exercise-form/InterviewConversationFields.tsx` — NEW
- `cms/app/exercises/components/exercise-form/InterviewChoiceExplainFields.tsx` — NEW
- `cms/app/exercises/components/exercise-form/index.tsx` — wire 2 types mới TRƯỚC startsWith checks

**InterviewConversationFields fields:**
- Tiêu đề `*` (shared — đã có trong parent form)
- Topic (string, `*`) + hint "Hiển thị trong Intro screen cho learner"
- Tips repeater (optional, max 5 items, mỗi item = 1 string)
- System Prompt (textarea `*`, min-height 120px) + hint "Agent dùng prompt này — viết tiếng Czech role instructions"
- Max turns (number, range 4–12, default 8)
- Show transcript toggle (default ON)

**InterviewChoiceExplainFields fields:**
- Câu hỏi chính (string, `*`) + hint "Hiển thị dưới tiêu đề trong Intro screen"
- Options repeater (3–4 items bắt buộc):
  - Mỗi option: Label `*` + image upload (optional, reuse existing media upload pattern)
- System Prompt (textarea `*`) + hint "Dùng `{selected_option}` để inject lựa chọn của learner"
- Warning (non-blocking) nếu system_prompt không chứa `{selected_option}`
- Max turns (number, range 4–10, default 6)
- Show transcript toggle (default OFF)

**Validation (inline, không block submit với warning):**
- `interview_choice_explain`: options.length < 3 → error "Cần ít nhất 3 phương án"
- `interview_choice_explain`: options.length > 4 → error "Tối đa 4 phương án"
- system_prompt rỗng → error
- `{selected_option}` warning (non-blocking) cho choice type

**CMS tests (Vitest — `exercise-utils.test.ts`):**
```ts
buildInterviewConversationPayload_valid
buildInterviewConversationPayload_emptySystemPrompt_throws
buildInterviewChoiceExplainPayload_3options_valid
buildInterviewChoiceExplainPayload_2options_throws
buildInterviewChoiceExplainPayload_5options_throws
formStateFromInterviewConversation_roundtrip
formStateFromInterviewChoiceExplain_roundtrip
```

**AC:** `make cms-lint && make cms-build && cd cms && npm test` passes. Tạo `interview_conversation` trong CMS → save → reload → data intact.

---

### IV-5 — Flutter: Models + API Client + i18n + ModuleDetail Entry Point

**Files:**
- `flutter_app/lib/models/models.dart` — thêm Interview* types
- `flutter_app/lib/core/api/api_client.dart` — thêm `getInterviewToken()`, `submitInterview()`
- `flutter_app/lib/l10n/intl_vi.arb` + `intl_en.arb` — thêm `interview_*` keys
- `flutter_app/lib/features/home/screens/module_detail_screen.dart` — thêm interview skill card

**New Dart types:**
```dart
class InterviewOption {
  final String id, label, imageAssetId;
}

class InterviewTranscriptTurn {
  final String speaker; // "examiner" | "learner"
  final String text;
  final int atSec;
}

class InterviewTokenResponse {
  final String signedUrl;
  final int expiresIn;
}

// ExerciseDetail extension
// interviewConversationDetail, interviewChoiceExplainDetail getters
// isInterviewConversation, isInterviewChoiceExplain getters
// interviewTopic, interviewTips, interviewQuestion, interviewOptions,
// interviewSystemPrompt, interviewMaxTurns, interviewShowTranscript
```

**api_client.dart thêm:**
```dart
Future<InterviewTokenResponse> getInterviewToken({
  required String exerciseId,
  required String attemptId,
  String? selectedOption,
})

Future<Attempt> submitInterview({
  required String attemptId,
  required List<InterviewTranscriptTurn> transcript,
  required int durationSec,
})
```

**ModuleDetail entry point:**  
Interview skill card: teal gradient, full width, "MỚI" badge, route → `InterviewListScreen`.  
Điều kiện hiện: `skill.skillKind == 'interview'`.

**i18n:** 22 keys theo spec (prefix `interview_`), cả VI lẫn EN.

**AC:** `make flutter-analyze` passes (0 warnings). `make flutter-test` passes.

---

### IV-6 — Flutter: ElevenLabs Dart WebSocket Client

**Files:**
- `flutter_app/lib/features/interview/services/elevenlabs_ws_client.dart` — NEW

**Interface:**
```dart
class ElevenLabsWsClient {
  // Callbacks
  VoidCallback? onReady;
  void Function(Uint8List pcm16)? onAudioChunk;  // agent speech → Simli
  void Function(String speaker, String text)? onTranscript;
  VoidCallback? onDisconnected;
  void Function(String error)? onError;

  Future<void> connect(String signedUrl);

  // Send learner mic audio to ElevenLabs
  void sendAudio(Uint8List pcm16Chunk);

  Future<void> disconnect();
}
```

**WebSocket message protocol:**
```dart
// Send mic audio
ws.send(jsonEncode({
  "user_audio_chunk": base64Encode(pcm16Chunk),
}))

// Receive and dispatch:
// type="conversation_initiation_metadata" → onReady()
// type="audio" → decode base64 → onAudioChunk(pcm16)
// type="transcript", message.role="agent" → onTranscript("examiner", text)
// type="transcript", message.role="user" → onTranscript("learner", text)
// type="interruption" → (ignore, Simli handles visual)
// WS onDone → onDisconnected()
// WS onError → onError(msg); auto-reconnect max 3 times
```

**Reconnect logic:** Max 3 attempts, exponential backoff 1s/2s/4s. Sau 3 lần fail → `onError("connection_failed")`.

**Mic capture:** Dùng `record` package (đã có trong pubspec). `RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1)`. Stream chunks trong timer loop mỗi 100ms.

**AC:** Unit test (mock WebSocket): `TestElevenLabsWsClient_DispatchesAudio`, `TestElevenLabsWsClient_AccumulatesTranscript`. `make flutter-analyze` passes.

---

### IV-7 — Flutter: InterviewListScreen + InterviewIntroScreen

**Files:**
- `flutter_app/lib/features/interview/screens/interview_list_screen.dart` — NEW
- `flutter_app/lib/features/interview/screens/interview_intro_screen.dart` — NEW

**InterviewListScreen:**
- Load exercises by `module_id + skill_kind="interview"` (reuse `getExercises` API)
- Group theo `exerciseType`: header "Hội thoại theo chủ đề" / "Chọn phương án + giải thích"
- Mỗi item: icon + title + sub (turn count + duration estimate) + type badge
- Empty state nếu không có bài

**InterviewIntroScreen (shared cho 2 types, dispatch theo exerciseType):**

Luồng A (`interview_conversation`):
- Teal hero: avatar placeholder (👩‍💼 icon) + topic label + title + duration badge
- Tips card (hiển thị `tips` từ detail nếu có)
- Exam tips card (amber bg, generic tips)
- Primary button "Bắt đầu phỏng vấn →"
- On tap: `POST /v1/attempts` → navigate `InterviewSessionScreen`

Luồng B (`interview_choice_explain`):
- Teal hero (compact): question text + instruction "Chọn 1 và giải thích lý do"
- 2×2 grid options (text hoặc ảnh nếu có `image_asset_id`)
- Selected state: orange border + bg + checkmark
- "Đã chọn: X" label sau khi chọn
- Primary button "Bắt đầu với lựa chọn này →" (disabled cho đến khi có selection)
- Secondary "Chọn lại" button reset selection
- On tap start: `POST /v1/attempts` → navigate `InterviewSessionScreen(selectedOption: ...)`

**AC:**
- `flutter-analyze` 0 warnings
- Widget tests: intro_conv: button enabled ngay; intro_choice: button disabled → chọn option → enabled; chọn lại → disabled

---

### IV-8 — Flutter: InterviewSessionScreen (audio-only) + InterviewResultScreen

**Files:**
- `flutter_app/lib/features/interview/screens/interview_session_screen.dart` — NEW
- `flutter_app/lib/features/interview/screens/interview_result_screen.dart` — NEW
- `flutter_app/lib/features/interview/widgets/session_status_pill.dart` — NEW
- `flutter_app/lib/features/interview/widgets/mic_waveform_widget.dart` — NEW

**InterviewSessionScreen:**

State machine:
```
connecting → ready → speaking (examiner) ↔ listening (learner) → ended
```

Session lifecycle:
```dart
initState():
  1. POST /v1/attempts (nếu chưa có attempt_id)
  2. POST /v1/interview-sessions/token {exercise_id, attempt_id, selected_option}
  3. ElevenLabsWsClient.connect(signedUrl)
  4. ElevenLabsWsClient.onReady = () => state = ready
  5. ElevenLabsWsClient.onAudioChunk = (chunk) => playAudio(chunk)  // Sprint 1: just_audio
  6. ElevenLabsWsClient.onTranscript = (speaker, text) => accumulateTranscript(...)
  7. Start mic recording: sendAudio loop

dispose(): disconnect WS, stop mic, stop audio
```

**Layout (dark #0A1628 background):**
- `SessionStatusPill` (top center): 4 states với màu dot + text
- Sprint 1 (no avatar): centered icon 👩‍💼 với ring pulse khi speaking, dims khi listening
- Transcript overlay (nếu `showTranscript = true`): phía dưới, max 2 dòng, auto-clear 4s
- Selected choice chip (góc phải, nếu choice type): "Praha ✓"
- Mic waveform widget (trung tâm controls)
- Timer display
- "Kết thúc" button (đỏ, bottom center, safe area aware)
- On "Kết thúc": confirmation dialog → `POST /v1/attempts/:id/submit-interview` → navigate `InterviewResultScreen`

**Error handling:**
- Token fail → SnackBar "Không kết nối được" + retry button
- WS disconnect mid-session → auto-reconnect 3 lần → snackbar nếu fail
- Mic permission denied → dialog với link Settings

**InterviewResultScreen:**
- Hero (teal bg): score circle (0–100) + exercise title + level badge
- 2 tabs: "Nhận xét" (feedback cards) + "Hội thoại" (transcript turns)
- Nhận xét tab: `AttemptFeedback` → 3 score bars (vocab/grammar/fluency) + comments
- Hội thoại tab: turn-by-turn list, speaker labels, alternating bg
- "Luyện lại" button → pop back to InterviewListScreen

**AC:**
- Session screen renders khi không có Simli
- Transcript accumulates correctly
- "Kết thúc" → confirm → submit → result screen shows
- Error states: token fail shows retry, WS disconnect shows snackbar
- `flutter-analyze` 0 warnings

---

### [CHECKPOINT IV-A — Sprint 1 Complete]

```
make backend-build && make backend-test   → pass (≥6 new interview tests)
make cms-lint && make cms-build && cd cms && npm test → pass (≥7 new tests)
make flutter-analyze && make flutter-test → 0 warnings, all tests pass

Manual E2E trên iPhone (Luồng A):
  ModuleDetail → "Phỏng vấn AI" → InterviewListScreen
  → bài "Gia đình" → IntroScreen → "Bắt đầu phỏng vấn"
  → SessionScreen: icon avatar, nói tiếng Czech, agent trả lời qua audio
  → "Kết thúc" → confirm → InterviewResultScreen: score + transcript

Manual E2E trên iPhone (Luồng B):
  → bài "Địa điểm du lịch" → IntroScreen → chọn Praha
  → "Bắt đầu với lựa chọn này" → session ("Praha ✓" chip hiện)
  → agent hỏi về Praha → kết thúc → result screen

Không cần Simli avatar trong checkpoint này.
```

---

### IV-9 — Flutter: Simli Integration

**Files:**
- `flutter_app/pubspec.yaml` — thêm `simli_client: ^1.0.1`, `flutter_webrtc: ^0.9.x`
- `flutter_app/lib/features/interview/services/simli_session_manager.dart` — NEW
- `flutter_app/ios/Runner/Info.plist` — thêm camera permission description (RTCVideoView yêu cầu)

**simli_session_manager.dart:**
```dart
class SimliSessionManager {
  late SimliClient _client;
  RTCVideoRenderer? get videoRenderer => _client.videoRenderer;
  ValueNotifier<bool> get isSpeaking => _client.isSpeakingNotifier;

  Future<void> start() async {
    _client = SimliClient(
      clientConfig: SimliClientConfig(
        apiKey: AppConfig.simliApiKey,
        faceId: AppConfig.simliFaceId,
        syncAudio: true,
        handleSilence: true,
        maxSessionLength: 900,
        maxIdleTime: 300,
      ),
      log: Logger(),
    );
    _client.onConnection = () => _connected.value = true;
    _client.onFailed = (e) => _onError?.call(e.message);
    _client.onDisconnected = () => _connected.value = false;
    await _client.start();
  }

  void sendAudio(Uint8List pcm16) => _client.sendAudioData(pcm16);

  Future<void> dispose() async { /* cleanup */ }
}
```

**AppConfig:** Build-time constants `simliApiKey`, `simliFaceId` từ `--dart-define` hoặc `.env.dart` (gitignored).

**Wire trong ElevenLabsWsClient:**
```dart
// onAudioChunk callback lúc này:
onAudioChunk = (chunk) {
  simliManager.sendAudio(chunk);  // → avatar lip-sync
  _audioPlayer.feed(chunk);       // → learner hears examiner
}
```

**Note:** Nếu `simli_client` v1.0.1 không tương thích Simli API hiện tại (phát hiện trong Sprint 0), escalate trước khi tiếp tục slice này.

**AC:** `make flutter-analyze` passes. App build thành công với `simli_client` dependency. `SimliSessionManager.start()` không throw trên iOS.

---

### IV-10 — Flutter: Avatar RTCVideoView trong SessionScreen

**Files:**
- `flutter_app/lib/features/interview/widgets/avatar_video_container.dart` — NEW
- `flutter_app/lib/features/interview/screens/interview_session_screen.dart` — MODIFY

**AvatarVideoContainer widget:**
```dart
// Wraps RTCVideoView với:
// - Fallback placeholder (👩‍💼) khi chưa connected
// - Ring pulse animation khi isSpeaking = true
// - Smooth opacity transition connected/disconnected
// - Safe: không crash khi videoRenderer = null

RTCVideoView(
  simliManager.videoRenderer!,
  mirror: false,
  placeholderBuilder: (_) => AvatarPlaceholder(),
)
```

**SessionScreen modifications:**
- Khởi tạo `SimliSessionManager` trong `initState()` trước `ElevenLabsWsClient.connect()`
- Wait for `SimliSessionManager` connected state trước khi show `ready` status
- Wire `ElevenLabsWsClient.onAudioChunk` → `simliManager.sendAudio(chunk)` + audio playback
- Replace placeholder icon bằng `AvatarVideoContainer` trong layout
- Ring pulse animation: `ValueListenableBuilder(simliManager.isSpeaking, ...)`

**Transcript overlay (show_transcript = true):**
- Position absolute bottom avatar area + padding `session_transcript`
- Blur background overlay
- 2 dòng max, auto-clear sau 4s
- Examiner = white text, Learner = orange text

**AC:** Avatar renders trên iPhone, lip-syncs khi examiner nói, ring pulses. Learner mic → ElevenLabs → audio → Simli avatar animated. `flutter-analyze` 0 warnings.

---

### IV-11 — Flutter: Widget Tests

**Files:**
- `flutter_app/test/interview_list_screen_test.dart` — NEW
- `flutter_app/test/interview_intro_screen_test.dart` — NEW
- `flutter_app/test/interview_session_widgets_test.dart` — NEW

```dart
// interview_list_screen_test.dart
renders_empty_state_when_no_exercises
renders_conversation_group_header
renders_choice_explain_group_header
exercise_item_tap_navigates_to_intro

// interview_intro_screen_test.dart (conversation type)
conv_shows_topic_title
conv_start_button_enabled_immediately
conv_shows_tips_when_provided

// interview_intro_screen_test.dart (choice type)
choice_start_button_disabled_initially
choice_tap_option_enables_start_button
choice_tap_different_option_changes_selection
choice_reset_button_clears_selection

// interview_session_widgets_test.dart
status_pill_renders_connecting_state
status_pill_renders_speaking_state_with_orange_dot
status_pill_renders_listening_state_with_green_dot
mic_waveform_animates_when_active
choice_chip_shows_selected_option
```

Minimum 13 test cases. Mock `ElevenLabsWsClient` và `SimliSessionManager` trong tests.

**AC:** `make flutter-test` passes. Tổng flutter test count ≥ 82 (69 hiện tại + 13 mới).

---

### [CHECKPOINT IV-FINAL]

```
make backend-build && make backend-test   → pass, ≥249 tests (243 + 6 mới)
make cms-lint && make cms-build && cd cms && npm test → pass, ≥60 tests (53 + 7 mới)
make flutter-analyze                      → 0 warnings
make flutter-test                         → ≥ 82 tests pass

Manual E2E full avatar (iPhone thật):
1. Luồng A: ModuleDetail → Phỏng vấn → hội thoại → Simli avatar lip-syncs
2. Luồng B: Chọn phương án Praha → avatar hỏi về Praha → transcript tích lũy
3. show_transcript=true: phụ đề hiện realtime dưới avatar
4. show_transcript=false: không có overlay
5. WS disconnect: auto-reconnect → session tiếp tục
6. Kết thúc → InterviewResultScreen: 3 score bars + tab Hội thoại

make verify
```
