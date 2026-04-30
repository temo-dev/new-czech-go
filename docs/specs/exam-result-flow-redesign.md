# Exam Result Flow — UI/UX Design Spec

> Companion to `docs/ideas/exam-result-flow-redesign.md`
> Stack: Flutter iOS · Design system: V2 (Orange `#FF6A14` / Cream `#FBF3E7` / Teal `#0F3D3A` / Inter + Fraunces)

---

## Requirement Clarification

### Problem (confirmed)

`MockExamSectionDetailScreen` luôn render `ResultCard` (speaking widget: tabs Phản hồi/Bản ghi/Bài mẫu, readiness hero, audio replay) cho **mọi** skill. Với nghe/đọc/viết → widget render sai, hiển thị rỗng/lỗi.

### Data available (từ codebase)

| Field | Source | Notes |
|-------|--------|-------|
| `skillKind` | `MockExamSection.skillKind` | Đã có, cần truyền qua detail screen |
| `sectionScore` / `maxPoints` | `MockExamSection` | Đã có trên màn tổng |
| `feedback.objectiveResult` | `AttemptResult.feedback` | Score + câu đúng/sai — `ObjectiveResultCard` đã dùng |
| `feedback.readinessLevel` | `AttemptResult.feedback` | Speaking only |
| `transcript` | `AttemptResult.transcript` | Speaking only |
| `feedback.diffChunks` / `correctedText` | `AttemptResult.feedback` | Writing diff |

### Gap duy nhất cần giải quyết

`MockExamSectionDetailScreen` hiện nhận `attemptId` + `sequenceNo` — **không có `skillKind`**. Cần thêm param này để dispatch đúng widget.

---

## User Flow (Before vs After)

### Before (broken)

```
MockExamScreen
  ├── noi   → ExerciseScreen (ghi âm) → AnalysisScreen spinner → back
  ├── nghe  → ListeningExerciseScreen → scored inline → back
  ├── doc   → ReadingExerciseScreen  → scored inline → back
  └── viet  → WritingExerciseScreen  → scored inline → back
        ↓
  _bulkAnalyze() speaking sections (hiện: per-section AnalysisScreen đã bị bỏ trong bulk)
        ↓
  _MockExamResultView (summary score + sections list)
        ↓
  tap section → MockExamSectionDetailScreen
                  └── ResultCard (LUÔN speaking widget) ← BUG
```

### After (redesigned)

```
MockExamScreen
  ├── noi   → ExerciseScreen (ghi âm, onRecordingReady callback)
  ├── nghe  → ListeningExerciseScreen (score inline)
  ├── doc   → ReadingExerciseScreen (score inline)
  └── viet  → WritingExerciseScreen (score inline)
        ↓
  [Tất cả sections xong]
        ↓
  ExamLoadingScreen ─── NEW ───
  "Đang chấm điểm bài thi..." · X/N phân tích xong
  (orbiting ring, reuse _ProgressView logic)
        ↓
  MockExamResultScreen (redesigned layout)
        ↓
  tap section → MockExamSectionDetailScreen(attemptId, skillKind, sequenceNo, maxPoints)
                  └── SectionResultCard(result, skillKind, maxPoints) ─── NEW ───
                       ├── header thống nhất (icon + label + score badge)
                       ├── noi  → ResultCard (existing, unchanged)
                       ├── nghe → ObjectiveDetailCard (new, extended ObjectiveResultCard)
                       ├── doc  → ObjectiveDetailCard (same, passage collapsible)
                       └── viet → WritingDetailCard (new)
```

---

## Screen Designs

### Screen 1 — ExamLoadingScreen (mới)

Thay thế per-speaking `AnalysisScreen` spinner trong `_bulkAnalyze()`.

```
┌─────────────────────────────────────────┐
│  ← Bài kiểm tra                   [--] │  ← AppBar teal
│─────────────────────────────────────────│
│                                         │
│                                         │
│              ╔═══════╗                  │
│           ╔══╣  orb  ╠══╗               │
│           ║  ╚═══════╝  ║               │  ← Orbiting ring (reuse _ProgressView)
│           ╚═════════════╝               │    animated dots chạy quanh
│                                         │
│        Đang chấm điểm bài thi           │  ← bodyMedium, teal
│                                         │
│    ████████████████░░░░░░░░░░  2/3      │  ← LinearProgressIndicator orange
│                                         │
│  ┌─────────────────────────────────┐    │
│  │ ✓  Section 1 · Nói    · xong   │    │  ← step list, icon+label+status
│  │ ✓  Section 2 · Nghe   · xong   │    │    ✓ = green, ⏳ = orange spin
│  │ ⏳  Section 3 · Nói    · đang...│    │
│  └─────────────────────────────────┘    │
│                                         │
│                                         │
└─────────────────────────────────────────┘
```

**Behavior:**
- Chỉ xuất hiện khi có `_pendingAnalyses.length > 0` (speaking sections cần upload/process)
- Nếu exam toàn nghe/đọc/viết → skip màn này, vào result ngay
- Progress bar: `_analyzeProgress / total`
- Auto-advance khi tất cả `completed`
- Timeout 3 phút: nếu section nào fail → hiện error card + "Xem kết quả" button (partial result)

**Colors:** Background cream `#FBF3E7`, orb ring orange `#FF6A14`, text teal `#0F3D3A`

---

### Screen 2 — MockExamResultScreen (redesign layout)

```
┌─────────────────────────────────────────┐
│  ← Kết quả bài kiểm tra           [--] │  ← AppBar teal
│─────────────────────────────────────────│
│                                         │
│  ┌─────────────────────────────────┐    │
│  │                                 │    │
│  │         34 / 40 điểm            │    │  ← Fraunces 48sp, teal
│  │                                 │    │
│  │  ╔══════════════════════════╗   │    │
│  │  ║      ✓  ĐẠT YÊU CẦU     ║   │    │  ← badge: green nếu passed
│  │  ╚══════════════════════════╝   │    │       red "CHƯA ĐẠT" nếu fail
│  │                                 │    │
│  │  "Bạn đạt 85% — vượt ngưỡng"   │    │  ← overallSummary, bodySmall
│  └─────────────────────────────────┘    │
│                                         │
│  ─── Chi tiết từng phần ─────────────── │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │  🎙  Nói · Section 1    28/37  →│    │  ← section card
│  │      ████████████████░░  76%    │    │    mini progress bar
│  └─────────────────────────────────┘    │
│  ┌─────────────────────────────────┐    │
│  │  🎧  Nghe · Section 2   18/25  →│    │
│  │      █████████████░░░░░  72%    │    │
│  └─────────────────────────────────┘    │
│  ┌─────────────────────────────────┐    │
│  │  📖  Đọc · Section 3    20/25  →│    │
│  │      ████████████████░░  80%    │    │
│  └─────────────────────────────────┘    │
│  ┌─────────────────────────────────┐    │
│  │  ✏️  Viết · Section 4   10/12  →│    │
│  │      █████████████████░  83%    │    │
│  └─────────────────────────────────┘    │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │      Về trang chủ               │    │  ← primary button orange
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

**Section card spec:**
- Padding: 16dp vertical, 20dp horizontal
- Background: white, border-radius 16
- Left icon: skill icon (24dp, teal stroke) — mic/headphones/book/pen
- Score text: `sectionScore/maxPoints`, Inter Bold 16sp
- Score color: ≥80% → success green, ≥60% → orange, <60% → error red
- Mini progress bar: height 4dp, orange fill on cream track, border-radius full
- Chevron: 16dp, muted teal — nếu `attemptId` empty (section bị skip) → chevron ẩn, opacity 0.4
- Card tap: navigate `MockExamSectionDetailScreen(attemptId, skillKind, sequenceNo, maxPoints)`

---

### Screen 3 — MockExamSectionDetailScreen + SectionResultCard

#### Header thống nhất (tất cả skill kinds)

```
┌─────────────────────────────────────────┐
│  ← Section 2                      [--] │  ← AppBar, sequenceNo
│─────────────────────────────────────────│
│                                         │
│  ┌─────────────────────────────────┐    │
│  │  🎧  Nghe                       │    │  ← skill icon + label
│  │                                 │    │
│  │       18 / 25 điểm              │    │  ← score, Fraunces 32sp
│  │  ╔══════════════════╗           │    │
│  │  ║  ██████████░░  72%  ║        │    │  ← progress bar + %
│  │  ╚══════════════════╝           │    │
│  └─────────────────────────────────┘    │
│                                         │
│  ─── [skill-specific body below] ─────  │
```

#### Body A — noi (speaking) → ResultCard (unchanged)

```
│  ┌─ Tab bar ──────────────────────┐    │
│  │  Phản hồi  │  Bản ghi  │  Bài mẫu  │    │
│  └────────────────────────────────┘    │
│                                         │
│  [Existing ResultCard tab content]      │
│  - readiness hero badge                 │
│  - strengths / improvements chips       │
│  - criteria checklist                   │
│  - audio replay                         │
│  - transcript with diff highlight       │
```

#### Body B — nghe / doc → ObjectiveDetailCard (mới/mở rộng)

```
│  ─── Kết quả chi tiết ──────────────── │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │  Câu 1                          │    │  ← question row
│  │  Bạn chọn:  [B] Ano             │    │  ← learner answer
│  │  Đúng:      [B] Ano      ✓      │    │  ← correct if same → ✓ green
│  └─────────────────────────────────┘    │
│  ┌─────────────────────────────────┐    │
│  │  Câu 2                          │    │
│  │  Bạn chọn:  [A] Ne       ✗      │    │  ← wrong → red, show correct
│  │  Đúng:      [C] Nevím           │    │
│  └─────────────────────────────────┘    │
│  ...                                    │
│                                         │
│  ┌──── Lời khuyên ─────────────────┐    │  ← if feedback present
│  │  Cần luyện nghe thêm các từ...  │    │
│  └─────────────────────────────────┘    │
│                                         │
│  ┌──── Bài gốc ─── [▼ Xem] ───────┐    │  ← collapsible (doc có passage dài)
│  │  (collapsed by default)         │    │
│  └─────────────────────────────────┘    │
```

**Question row spec:**
- Correct: background `#E8F5E9`, icon ✓ green, border green 0.3 opacity
- Wrong: background `#FFEBEE`, icon ✗ red, show correct answer below in green text
- Question text: Inter Regular 14sp, teal
- Answer text: Inter Medium 14sp
- No tabs — single scroll view

#### Body C — viet (writing) → WritingDetailCard (mới)

```
│  ─── Bài viết của bạn ──────────────── │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │  "Tôi muốn [xin] một vé..."     │    │  ← diff text
│  │   ~~xin~~ → [mua]               │    │    deleted=red strikethrough
│  │  "...cảm ơn bạn [rất] nhiều"    │    │    inserted=green underline
│  └─────────────────────────────────┘    │
│                                         │
│  ─── Bản sửa ───────────────────────── │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │  Tôi muốn mua một vé...         │    │  ← corrected text (plain)
│  └─────────────────────────────────┘    │
│                                         │
│  ┌──── Bài mẫu ─── [▼ Xem] ──────┐    │  ← collapsible
│  │  (collapsed by default)        │    │
│  └────────────────────────────────┘    │
│                                         │
│  ┌──── Nhận xét ──────────────────┐    │  ← LLM feedback if present
│  │  Bài viết đủ từ. Cần chú ý... │    │
│  └────────────────────────────────┘    │
```

---

## Component Spec

### SectionResultCard

```dart
// Nhận từ MockExamSectionDetailScreen:
SectionResultCard({
  required AttemptResult result,
  required String skillKind,   // 'noi' | 'nghe' | 'doc' | 'viet'
  required int maxPoints,
  required VoidCallback onBack,
})
```

**Dispatch logic:**
```dart
Widget _body() => switch (skillKind) {
  'noi'  => ResultCard(result, onRetry: onBack),
  'nghe' || 'doc' => ObjectiveDetailCard(result, onBack: onBack),
  'viet' => WritingDetailCard(result, onBack: onBack),
  _      => ObjectiveDetailCard(result, onBack: onBack), // safe fallback
};
```

### MockExamSectionDetailScreen — thay đổi

```dart
// Thêm params:
class MockExamSectionDetailScreen extends StatefulWidget {
  const MockExamSectionDetailScreen({
    required this.client,
    required this.attemptId,
    required this.sequenceNo,
    required this.skillKind,   // NEW
    required this.maxPoints,   // NEW
  });
}

// Render: replace ResultCard → SectionResultCard
SectionResultCard(
  result: result,
  skillKind: widget.skillKind,
  maxPoints: widget.maxPoints,
  onBack: () => Navigator.of(context).pop(),
)
```

### _MockExamResultView — thay đổi

```dart
// Tại chỗ navigate sang detail:
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => MockExamSectionDetailScreen(
      client: widget.client,
      attemptId: section.attemptId,
      sequenceNo: section.sequenceNo,
      skillKind: section.skillKind,   // NEW — đã có trong MockExamSection
      maxPoints: section.maxPoints,   // NEW
    ),
  ),
);
```

---

## ExamLoadingScreen — thay đổi _bulkAnalyze

### Trước (hiện tại)

`_bulkAnalyze()` chạy inline trong `MockExamScreen`, update `_analyzeProgress`, render `_LoadingView` inline.

### Sau

Giữ nguyên logic `_bulkAnalyze()`. Thay đổi: khi `_analyzing == true` render `ExamLoadingScreen` widget (thay `_LoadingView`) với:
- Reuse orbiting ring từ `analysis_screen.dart` `_ProgressView`
- Step list per-section với trạng thái
- Không navigate ra màn riêng — vẫn là widget trong MockExamScreen state machine

---

## Design Tokens (V2, giữ nguyên)

| Token | Value | Dùng cho |
|-------|-------|---------|
| Primary orange | `#FF6A14` | Buttons, progress fill, badges |
| Deep teal | `#0F3D3A` | AppBar, text chính, icons |
| Warm cream | `#FBF3E7` | Background |
| Success green | `AppColors.success` | Score ≥80%, ✓ icon, Đúng row |
| Warning orange | `#FF6A14` / `AppColors.info` | Score 60–79% |
| Error red | `AppColors.error` | Score <60%, ✗ icon, Sai row |
| Card BG | white | Section cards, result cards |
| Card radius | 16dp | Tất cả cards |
| Body font | Inter | Content text |
| Heading font | Fraunces | Score numbers, section titles |

---

## Accessibility

- [ ] `skillKind` != empty trước khi navigate (guard trong `_runSection`)
- [ ] Score badge: không chỉ dùng màu — thêm text "Đạt" / "Chưa đạt"
- [ ] Question rows: ✓/✗ icon + color, không chỉ màu
- [ ] Collapsible sections: semanticsLabel "Xem bài gốc / Ẩn bài gốc"
- [ ] Touch targets ≥ 44pt cho tất cả interactive elements
- [ ] Loading screen: timeout 3 phút + "Xem kết quả hiện tại" fallback

---

## Files cần thay đổi / tạo mới

| File | Action | Ghi chú |
|------|--------|---------|
| `features/mock_exam/screens/mock_exam_section_detail_screen.dart` | Edit | Thêm `skillKind`, `maxPoints` params; dùng `SectionResultCard` |
| `features/mock_exam/screens/mock_exam_screen.dart` | Edit | Truyền `skillKind`/`maxPoints` khi navigate; upgrade loading UI |
| `features/mock_exam/widgets/section_result_card.dart` | **New** | Wrapper header + dispatch |
| `features/mock_exam/widgets/objective_detail_card.dart` | **New** | nghe/doc: answer table + collapsible passage |
| `features/mock_exam/widgets/writing_detail_card.dart` | **New** | viet: score + diff + model answer |

> `ResultCard` và `ObjectiveResultCard` hiện tại: **không thay đổi**.

---

## Open Questions (cần verify trước khi build)

1. **`AttemptResult` cho nghe/doc** có `feedback.objectiveResult.questions[]` với `question_text`, `learner_answer`, `correct_answer`? → Xem `ObjectiveResult` model + backend `scoring_pipeline.go`
2. **`AttemptResult` cho viet** — `feedback` có `diff_chunks`, `corrected_text`? → Xem `AttemptFeedbackView` model + `writing_scorer.go` response
3. **`skillKind` từ `MockExamSection`** — nếu empty string (section cũ) → `_skillKindForExerciseType(section.exerciseType)` fallback đã có trong `mock_exam_screen.dart`, cần áp dụng tương tự khi navigate.
