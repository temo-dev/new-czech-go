# Spec: Exam Result Flow — Implementation

> Sau khi phân tích kỹ codebase. Companion của `docs/ideas/exam-result-flow-redesign.md` và `docs/specs/exam-result-flow-redesign.md`.

---

## Objective

Fix lỗi `MockExamSectionDetailScreen` luôn render `ResultCard` (speaking widget) cho mọi skill. Với nghe/đọc → widget trống/sai; viết → hoạt động nhưng thiếu header context.

Đồng thời nâng cấp UX tổng thể: header thống nhất per-section, loading screen rõ ràng hơn.

**Target users:** Học viên Vietnamese làm bài thi A2 Czech trên iOS.

---

## Data Model — Đã xác nhận

| Skill | Result data | Widget hiện tại | Verdict |
|-------|------------|-----------------|---------|
| `noi` | `feedback.readinessLevel`, `transcript`, `audio`, `reviewArtifact.diffChunks` | `ResultCard` | ✅ Đúng |
| `viet` | `transcript` = bài nộp, `feedback.overallSummary`, `reviewArtifact.diffChunks` | `ResultCard` | ✅ Đúng — tab "Bài mẫu" có diff, tab "Bản ghi" có text nộp |
| `nghe` | `feedback.objectiveResult.{score,maxScore,breakdown[]}` | `ResultCard` | ❌ SAI — ResultCard render rỗng |
| `doc` | `feedback.objectiveResult.{score,maxScore,breakdown[]}` + passage text từ exercise | `ResultCard` | ❌ SAI |

`QuestionResult` fields: `questionNo`, `learnerAnswer`, `correctAnswer`, `isCorrect`.

`_DiffTextBlock` là **private class** bên trong `result_card.dart` — không thể reuse trực tiếp.

---

## Solution Architecture

### Thay đổi tối thiểu (surgical)

```
1. MockExamSectionDetailScreen  — thêm skillKind, maxPoints params
2. MockExamScreen               — truyền skillKind/maxPoints khi navigate; nâng cấp loading view
3. section_result_card.dart     — NEW: wrapper header + dispatch
4. objective_result_card.dart   — EXTEND: thêm learnerAnswer/correctAnswer, passage collapsible cho doc
```

**KHÔNG thêm `WritingDetailCard` mới** — `ResultCard` đã handle viet đúng.

---

## Acceptance Criteria

### AC-1: skillKind routing đúng

- Tap section nói → `ResultCard` với tabs Phản hồi/Bản ghi/Bài mẫu
- Tap section nghe → `ObjectiveResultCard` (extended) với bảng câu đúng/sai
- Tap section đọc → `ObjectiveResultCard` (extended) với bảng câu đúng/sai + passage collapsible
- Tap section viết → `ResultCard` với tabs Phản hồi/Bản ghi/Bài mẫu (giữ nguyên)
- `skillKind` empty → fallback `_skillKindForExerciseType(exerciseType)` (pattern đã có)

### AC-2: Header thống nhất

Tất cả sections hiện header: skill icon + skill label + `sectionScore/maxPoints` + progress bar.

### AC-3: ObjectiveResultCard extended

- Hiện `learnerAnswer` và `correctAnswer` per câu
- ✓ icon (green) / ✗ icon (red) per câu — không chỉ dùng màu
- Câu sai: hiện cả learner answer (đỏ) lẫn đáp án đúng (xanh)
- Câu đúng: chỉ hiện đáp án (xanh ✓)
- `overallSummary` từ feedback nếu có

### AC-4: Passage collapsible cho doc

- Section `doc`: nút "Xem bài đọc" / "Ẩn bài đọc" — load `ExerciseDetail` async sau khi result load
- Loading indicator nhỏ (skeleton 2 dòng) khi đang fetch
- Nếu fetch fail → ẩn nút, không block hiển thị kết quả
- Section `nghe`: không cần passage

### AC-5: Loading view upgrade

- Khi `_analyzing == true`: render `_ExamAnalyzingView` cải tiến — step list per-section với trạng thái (✓ xong / ⏳ đang chờ / ✗ lỗi)
- Progress text: "Đang phân tích X/N bài nói..."
- Timeout hiện tại đã xử lý ở `_pollUntilDone` — không đổi logic

### AC-6: MockExamResultScreen section cards

- Score color: ≥75% → success green, ≥50% → warning/info, <50% → error red (giữ threshold hiện tại)
- Section card hiện skill label (Nói/Nghe/Đọc/Viết) bên cạnh "Section N"
- Tap disabled (opacity 0.4) nếu `attemptId.isEmpty`

---

## Files thay đổi

### 1. `mock_exam_section_detail_screen.dart` — Edit

**Thêm params:**
```dart
class MockExamSectionDetailScreen extends StatefulWidget {
  const MockExamSectionDetailScreen({
    super.key,
    required this.client,
    required this.attemptId,
    required this.sequenceNo,
    required this.skillKind,   // NEW
    required this.maxPoints,   // NEW
  });

  final String skillKind;
  final int maxPoints;
}
```

**Thay render:**
```dart
// Cũ:
ResultCard(client: widget.client, result: result, onRetry: ...)

// Mới:
SectionResultCard(
  client: widget.client,
  result: result,
  skillKind: widget.skillKind,
  maxPoints: widget.maxPoints,
  onRetry: () => Navigator.of(context).pop(),
)
```

---

### 2. `mock_exam_screen.dart` — Edit

**Tại `_MockExamResultView`, chỗ navigate (hiện dòng ~706):**
```dart
// Cũ:
MockExamSectionDetailScreen(
  client: _client(context),
  attemptId: section.attemptId,
  sequenceNo: section.sequenceNo,
)

// Mới:
MockExamSectionDetailScreen(
  client: _client(context),
  attemptId: section.attemptId,
  sequenceNo: section.sequenceNo,
  skillKind: _sectionSkillKind(section),   // dùng helper đã có
  maxPoints: section.maxPoints,
)
```

**Section card: thêm skill label:**
```dart
// Thêm vào Row bên cạnh "Section N":
Text(
  _skillLabel(l, _sectionSkillKind(section)),
  style: AppTypography.bodySmall.copyWith(color: AppColors.secondary),
),
```

**Loading view `_buildAnalyzingView`:**
- Giữ logic, nâng cấp UI: thêm step list (section number + status icon per section)
- Sections đã xong (index < `_analyzeProgress`) → icon ✓ green
- Section đang xử lý (index == `_analyzeProgress - 1`) → spinning indicator
- Sections chưa đến → màu muted

---

### 3. `features/mock_exam/widgets/section_result_card.dart` — NEW

```dart
/// Unified wrapper: header (skill + score) + dispatch body by skillKind.
class SectionResultCard extends StatelessWidget {
  const SectionResultCard({
    super.key,
    required this.client,
    required this.result,
    required this.skillKind,
    required this.maxPoints,
    required this.onRetry,
  });

  final ApiClient client;
  final AttemptResult result;
  final String skillKind;
  final int maxPoints;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(result: result, skillKind: skillKind, maxPoints: maxPoints),
        const SizedBox(height: AppSpacing.x4),
        _body(context),
      ],
    );
  }

  Widget _body(BuildContext context) => switch (skillKind) {
    'nghe' || 'doc' => ObjectiveResultCard(
        result: result,
        onRetry: onRetry,
        showPassage: skillKind == 'doc',
        exerciseId: result.exerciseId,
        client: client,
      ),
    _ => ResultCard(client: client, result: result, onRetry: onRetry),
  };
}

/// Header: skill icon · label · score/maxPoints · progress bar
class _SectionHeader extends StatelessWidget { ... }
```

**`_SectionHeader` spec:**
- Row: skill icon (24dp teal) + label text + spacer + score "X/Y"
- Progress bar bên dưới: height 6dp, border-radius 3, màu theo pct (≥75 green, ≥50 orange, <50 red)
- Background card: white, radius 16, padding 16dp, border outline-variant

**Skill icons:** dùng `Icons` hoặc custom SVG nếu có:
- `noi` → `Icons.mic_outlined`
- `nghe` → `Icons.headphones_outlined`
- `doc` → `Icons.menu_book_outlined`
- `viet` → `Icons.edit_outlined`

---

### 4. `features/exercise/widgets/objective_result_card.dart` — EXTEND

**Thêm params:**
```dart
class ObjectiveResultCard extends StatelessWidget {
  const ObjectiveResultCard({
    super.key,
    required this.result,
    required this.onRetry,
    this.showPassage = false,    // NEW — chỉ true cho doc
    this.exerciseId = '',        // NEW — để fetch passage
    this.client,                 // NEW — ApiClient để fetch ExerciseDetail
  });

  final bool showPassage;
  final String exerciseId;
  final ApiClient? client;
}
```

**Nâng cấp `_QuestionRow`:**

```dart
// Cũ: chỉ hiện questionNo + isCorrect icon
// Mới: hiện learnerAnswer vs correctAnswer

class _QuestionRow extends StatelessWidget {
  // Câu đúng: green bg, ✓ icon, chỉ hiện correctAnswer
  // Câu sai: red bg, ✗ icon, hiện learnerAnswer (đỏ strikethrough) + correctAnswer (xanh)
}
```

**Layout per câu (sai):**
```
┌─────────────────────────────────────┐
│  Câu 3                         ✗   │  ← questionNo + ✗ red
│  Bạn trả lời: Ne                   │  ← learnerAnswer, màu error
│  Đáp án đúng: Ano                  │  ← correctAnswer, màu success
└─────────────────────────────────────┘
```

**Layout per câu (đúng):**
```
┌─────────────────────────────────────┐
│  Câu 1                         ✓   │  ← questionNo + ✓ green
│  Ano                               │  ← correctAnswer, màu success
└─────────────────────────────────────┘
```

**Passage collapsible (doc only):**
```dart
// Stateful widget mới _PassageSection:
// - initState: nếu showPassage && exerciseId.isNotEmpty → fetch ExerciseDetail
// - loading: skeleton 2 dòng
// - loaded: ExpansionTile "Xem bài đọc" / "Ẩn bài đọc" với SelectableText passage
// - error: ẩn hoàn toàn (không block result)
```

---

## Logic: skillKind fallback

`MockExamSectionDetailScreen` nhận `skillKind` từ caller. Nếu caller truyền empty:

```dart
// Trong SectionResultCard:
String get _resolvedSkillKind {
  if (skillKind.isNotEmpty) return skillKind;
  // fallback theo exerciseType
  final t = result.exerciseType;
  if (t.startsWith('uloha_')) return 'noi';
  if (t.startsWith('poslech_')) return 'nghe';
  if (t.startsWith('cteni_')) return 'doc';
  if (t.startsWith('psani_')) return 'viet';
  return 'noi'; // safe default
}
```

---

## Testing Expectations

### Unit tests (không cần mới)

`_skillKindForExerciseType()` đã được test implicitly qua exercise routing.

### Widget tests cần thêm

```dart
// section_result_card_test.dart
// AC-1: test dispatch đúng widget theo skillKind
// AC-2: test header hiện score/maxPoints đúng
// AC-3: test _QuestionRow render đúng cho isCorrect=true và isCorrect=false

group('SectionResultCard', () {
  test('noi → renders ResultCard');
  test('viet → renders ResultCard');
  test('nghe → renders ObjectiveResultCard');
  test('doc → renders ObjectiveResultCard with showPassage=true');
  test('empty skillKind → fallback via exerciseType');
});

group('ObjectiveResultCard _QuestionRow', () {
  test('correct question shows only correctAnswer + green check');
  test('wrong question shows both learnerAnswer + correctAnswer');
  test('icon: correct=check, wrong=close');
});
```

### Manual smoke test

1. Tạo MockTest với 4 sections: nói + nghe + đọc + viết
2. Hoàn thành exam
3. Tap từng section trên màn kết quả
4. Verify:
   - Nói: tabs Phản hồi/Bản ghi/Bài mẫu
   - Nghe: bảng câu đúng/sai với learner answer
   - Đọc: bảng câu đúng/sai + nút "Xem bài đọc"
   - Viết: tabs Phản hồi/Bản ghi/Bài mẫu (text nộp + diff)

---

## Boundaries

### Always do
- Truyền `skillKind` đầy đủ từ `MockExamSection` — không suy luận lại trong detail screen nếu không cần
- `ObjectiveResultCard` backward-compatible: tất cả params mới có default value, existing callers không bị break
- `showPassage=false` là default — không fetch exercise trừ khi `doc`

### Ask first
- Nếu backend không trả về `breakdown` (empty list) cho nghe/đọc — cần quyết định: hiện "Không có dữ liệu chi tiết" hay fallback về ObjectiveResultCard cũ (chỉ score header)
- Nếu `exerciseId` empty trên AttemptResult — passage fetch không khả thi

### Never do
- Đừng thay đổi `ResultCard` — widget này dùng cho nhiều nơi
- Đừng thay đổi `ObjectiveResultCard` constructor thành `required` cho params mới — sẽ break `ListeningExerciseScreen`, `ReadingExerciseScreen`
- Đừng fetch ExerciseDetail trong `SectionResultCard` — chỉ `ObjectiveResultCard` mới fetch (khi `showPassage=true`)
- Đừng extract `_DiffTextBlock` ra public — không cần, viet đã dùng ResultCard

---

## File Structure sau khi xong

```
flutter_app/lib/features/
├── exercise/
│   └── widgets/
│       ├── result_card.dart              (unchanged)
│       └── objective_result_card.dart    (extended: learnerAnswer/correctAnswer + passage)
├── mock_exam/
│   ├── screens/
│   │   ├── mock_exam_screen.dart         (truyền skillKind/maxPoints + loading UI upgrade)
│   │   └── mock_exam_section_detail_screen.dart  (thêm skillKind/maxPoints params)
│   └── widgets/
│       └── section_result_card.dart      (NEW: header + dispatch)
```

---

## Verification Checklist

- [ ] `make flutter-analyze` — zero errors
- [ ] `make flutter-test` — all pass
- [ ] Smoke: exam với 4 skill kinds, tap tất cả sections → đúng widget
- [ ] Smoke: exam chỉ nói (4 sections) → vẫn hoạt động như cũ
- [ ] Smoke: exam với skillKind empty (section cũ) → fallback đúng
- [ ] Accessibility: score badge có text "Đạt"/"Chưa đạt" không chỉ màu
- [ ] No regression: practice flow (ListeningExerciseScreen, ReadingExerciseScreen) không bị ảnh hưởng
