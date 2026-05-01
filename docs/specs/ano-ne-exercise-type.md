# Ano/Ne Exercise Type — Technical Spec (V12)

> Source of truth: `SPEC.md` § V12. File này mở rộng chi tiết kỹ thuật.

## Exercise Types

| Type | Skill | Pool |
|---|---|---|
| `cteni_6` | `doc` | `course` hoặc `exam` |
| `poslech_6` | `nghe` | `course` hoặc `exam` |

## Detail Payload Contract (frozen)

```json
{
  "passage": "Vlašim\nMěstský úřad – úřední hodiny\n...",
  "statements": [
    { "question_no": 1, "statement": "Na úřadu města je zavřeno ve středu." },
    { "question_no": 2, "statement": "Ve čtvrtek je polední přestávka do jedné hodiny." },
    { "question_no": 3, "statement": "V úterý úřední hodiny končí ve dvě hodiny odpoledne." }
  ],
  "correct_answers": { "1": "ANO", "2": "NE", "3": "ANO" },
  "max_points": 3
}
```

### Constraints

| Field | Rule |
|---|---|
| `passage` | required, non-empty string |
| `statements` | 1–5 items, `question_no` = 1-indexed, unique |
| `correct_answers` | keys = stringified `question_no`; values = `"ANO"` \| `"NE"` (uppercase) |
| `max_points` | integer ≥ 1; stored in exercise detail (not a separate DB column) |

### poslech_6 passage note

`passage` cho poslech_6 phải là **prose** (không dùng bảng cột với tab/space alignment). Polly TTS đọc prose tự nhiên hơn. CMS nên có helper text nhắc admin viết dạng: *"V pondělí je úřad otevřen od osmi do jedenácti hodin třicet."*

## Backend Changes

### 1. `contracts/types.go`

```go
type AnoNeDetail struct {
    Passage        string            `json:"passage"`
    Statements     []AnoNeStatement  `json:"statements"`
    CorrectAnswers map[string]string `json:"correct_answers"`
    MaxPoints      int               `json:"max_points,omitempty"`
}

type AnoNeStatement struct {
    QuestionNo int    `json:"question_no"`
    Statement  string `json:"statement"`
}
```

### 2. `processing/objective_scorer.go` — `extractQuestionTexts`

Thêm nhánh sau cùng (sau các nhánh `items` và `questions`):

```go
// statements[].statement (cteni_6, poslech_6 — AnoNeStatement)
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
```

### 3. `processing/exercise_audio.go` — `BuildExerciseAudioText`

```go
case "poslech_6":
    return buildAnoNeAudioText(exercise.Detail)
```

```go
func buildAnoNeAudioText(detail json.RawMessage) string {
    var d struct {
        Passage string `json:"passage"`
    }
    if err := json.Unmarshal(detail, &d); err != nil {
        return ""
    }
    return d.Passage
}
```

### 4. Exercise type validation

Thêm `"cteni_6"` và `"poslech_6"` vào bất kỳ allowlist nào đang guard `exercise_type`. Kiểm tra:
- `server.go` hoặc `exercise_handler.go` — nơi validate exercise_type khi create/update
- `skill_utils.go` hoặc equivalent — nếu có map `exerciseType → skillKind`

### 5. Scoring note

`matchObjectiveAnswer("ANO", "ANO")` → true (substring match, case-insensitive).
`matchObjectiveAnswer("ANO", "NE")` → false (`"ano"` không contain `"ne"` và ngược lại).
Không cần thay đổi logic scorer.

## CMS Changes

### `exercise-utils.ts`

```ts
// Thêm vào type list
export const ANO_NE_TYPES = ['cteni_6', 'poslech_6'] as const;

export interface AnoNeStatement {
  question_no: number;
  statement: string;
}

export interface AnoNeFormState {
  passage: string;
  statements: Array<{ statement: string; correct: 'ANO' | 'NE' }>;
  max_points: number;
}

// Build payload cho API
export function buildAnoNePayload(form: AnoNeFormState): object {
  const correct_answers: Record<string, string> = {};
  form.statements.forEach((s, i) => {
    correct_answers[String(i + 1)] = s.correct;
  });
  return {
    passage: form.passage,
    statements: form.statements.map((s, i) => ({
      question_no: i + 1,
      statement: s.statement,
    })),
    correct_answers,
    max_points: form.max_points,
  };
}

// Khởi tạo form từ existing exercise (edit mode)
export function formStateFromAnoNe(detail: any): AnoNeFormState {
  return {
    passage: detail?.passage ?? '',
    statements: (detail?.statements ?? []).map((s: any) => ({
      statement: s.statement ?? '',
      correct: (detail?.correct_answers?.[String(s.question_no)] ?? 'ANO') as 'ANO' | 'NE',
    })),
    max_points: detail?.max_points ?? 3,
  };
}
```

### `components/exercise-form/AnoNeFields.tsx`

Fields cần render:

1. **Passage textarea** — label "Văn bản / Script", required. Helper text cho poslech_6: "Nhập dạng văn xuôi để Polly đọc tự nhiên."
2. **Max points input** — number, min 1.
3. **Statement repeater** — tối đa 5 rows. Mỗi row:
   - Index badge (A/B/C/D/E)
   - Statement text input (required)
   - ANO/NE toggle buttons (giống design trong `ano-ne-exercise-type.html`)
   - Delete button (khi > 1 row)
4. **"+ Thêm câu"** button — disabled khi đã đủ 5 rows.

Validation inline:
- `passage` không được rỗng
- Ít nhất 1 statement, tối đa 5
- Mỗi statement text không được rỗng

### `exercise-form/index.tsx`

```tsx
case 'cteni_6':
case 'poslech_6':
  return <AnoNeFields value={formState} onChange={setFormState} exerciseType={exerciseType} />;
```

## Flutter Changes

### `lib/features/exercise/widgets/ano_ne_widget.dart`

```dart
class AnoNeWidget extends StatefulWidget {
  const AnoNeWidget({
    super.key,
    required this.statements,    // List<AnoNeStatement>
    required this.onAnswersChanged, // void Function(Map<String,String>)
    this.result,                 // ObjectiveResult? — null khi chưa submit
    this.enabled = true,
  });
}
```

**`_AnoNeRow` internal widget:**
- Statement text (wrap, không truncate)
- 2 buttons: ANO (xanh khi selected) / NE (đỏ khi selected)
- Min tap target 44×44pt (`constraints: BoxConstraints(minWidth: 44, minHeight: 44)`)
- Post-submit: disabled, đổi border/bg theo đúng/sai

**Answers format truyền lên:**
```dart
Map<String, String> answers;  // {"1": "ANO", "2": "NE", "3": "ANO"}
```

**Submit gate:** Submit button kích hoạt khi `answers.length == statements.length`.

### `lib/features/exercise/screens/reading_exercise_screen.dart`

```dart
Widget _buildCteni6Layout(ExerciseDetail detail) {
  return Column(children: [
    _PassageCard(passage: detail.passage),
    const SizedBox(height: 12),
    AnoNeWidget(
      statements: detail.anoNeStatements,
      onAnswersChanged: _setAnswers,
      result: _result?.objectiveResult,
      enabled: _result == null,
    ),
  ]);
}
```

### `lib/features/exercise/screens/listening_exercise_screen.dart`

```dart
Widget _buildPoslech6Layout(ExerciseDetail detail) {
  return Column(children: [
    AudioPlayerWidget(exerciseId: widget.exercise.id, client: widget.client),
    const SizedBox(height: 12),
    AnoNeWidget(
      statements: detail.anoNeStatements,
      onAnswersChanged: _setAnswers,
      result: _result?.objectiveResult,
      enabled: _result == null,
    ),
  ]);
}
```

### `ExerciseDetail` model extension

```dart
// Thêm vào ExerciseDetail.fromJson:
List<AnoNeStatement> get anoNeStatements =>
    (detail['statements'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(AnoNeStatement.fromJson)
        .toList();

String get passage => detail['passage'] as String? ?? '';
```

### i18n keys (4 keys mới)

| Key | VI | EN |
|---|---|---|
| `anoButton` | `ANO` | `YES` |
| `neButton` | `NE` | `NO` |
| `anoNeInstruction` | `Đúng hay sai?` | `True or false?` |
| `anoNeCorrectHint` | `Đúng ✓` | `Correct ✓` |
| `anoNeWrongHint` | `Sai — đáp án đúng: {answer}` | `Wrong — correct: {answer}` |

## Acceptance Criteria

- [ ] `cteni_6` exercise tạo được từ CMS với passage + 3 statements; publish thành công
- [ ] `poslech_6` exercise tạo được từ CMS; click "Generate audio" → Polly đọc passage
- [ ] Flutter `ReadingExerciseScreen` hiển thị PassageCard + AnoNeWidget cho cteni_6
- [ ] Flutter `ListeningExerciseScreen` hiển thị AudioPlayerWidget + AnoNeWidget cho poslech_6
- [ ] Submit button chỉ enable khi tất cả statements đã chọn
- [ ] Submit → `POST /v1/attempts/:id/submit-answers` → `completed` với `objective_result`
- [ ] `ObjectiveResultCard` hiển thị: score X/Y, per-statement ✓/✗, correct answer "ANO"/"NE" khi sai
- [ ] `make backend-test` pass (3 test cases mới)
- [ ] `make flutter-test` pass (AnoNeWidget tests)
- [ ] `make cms-build && cd cms && npm test` pass

## Open Questions

1. **Passage reveal trong result card?** Hiện tại `ObjectiveResultCard` có `showPassage=true` flag cho cteni exercises. Có nên bật cho cteni_6 không?
   - Đề xuất: **bật** — learner có thể xem lại passage sau khi submit để học
2. **poslech_6 passage trong CMS:** Hiển thị read-only dưới audio player để admin preview không? Hiện không show với poslech_1–5.
   - Đề xuất: **show** dưới "Script" collapsible trong CMS preview only

## Related Files

- `SPEC.md` § V12 — decisions frozen
- `docs/ideas/ano-ne-exercise-type.md` — idea refinement
- `docs/designs/ano-ne-exercise-type.html` — UI/UX mockups
