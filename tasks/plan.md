# Plan: Skills Expansion V2→V9

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