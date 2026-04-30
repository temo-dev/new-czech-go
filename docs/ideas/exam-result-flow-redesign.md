# Exam Result Flow Redesign

## Problem Statement

Làm sao redesign toàn bộ flow kết quả exam để mỗi kỹ năng có màn phân tích chi tiết đúng loại, thay vì luôn render widget speaking (ResultCard) cho tất cả sections — gây lỗi hiển thị với nghe/đọc/viết?

## Root Cause

`MockExamSectionDetailScreen` luôn render `ResultCard` (widget của speaking: tabs Phản hồi/Bản ghi/Bài mẫu, readiness hero, audio playback) bất kể `skill_kind` của section là gì. `ObjectiveResultCard` tồn tại nhưng không được dùng trong flow exam.

## Recommended Direction

**`SectionResultCard` wrapper** — widget mới nhận `(AttemptResult, skillKind)`:

```
MockExamResultScreen
  └── tap section
       └── MockExamSectionDetailScreen(attemptId, skillKind)
            └── SectionResultCard(result, skillKind)
                 ├── header: "Section 2 · Nghe · 18/25đ"  ← thống nhất
                 ├── noi  → ResultCard (tabs: Phản hồi/Bản ghi/Bài mẫu)
                 ├── nghe → ObjectiveDetailCard (bảng đúng/sai + text gốc + gợi ý)
                 ├── doc  → ObjectiveDetailCard (bảng đúng/sai + text gốc + gợi ý)
                 └── viet → WritingDetailCard (điểm + diff highlight)
```

**Spinner thay đổi:** Bỏ AnalysisScreen spinner riêng cho speaking khi bulk-analyze. Thay bằng 1 màn loading toàn exam ("Đang chấm điểm bài thi...") sau khi learner nộp tất cả sections. Sau khi tất cả xử lý xong → show màn kết quả tổng.

## Scope thay đổi

### Widgets mới
- `SectionResultCard` — wrapper header + dispatch theo skill
- `ObjectiveDetailCard` — cho nghe/doc: bảng so sánh đáp án learner vs đúng, text gốc bài, hint cải thiện
- `WritingDetailCard` — cho viet: điểm + diff highlight (reuse `_DiffTextBlock` từ WritingExerciseScreen)

### Files thay đổi
- `mock_exam_section_detail_screen.dart` — nhận thêm `skillKind` param, dùng `SectionResultCard`
- `mock_exam_screen.dart` — bỏ per-speaking AnalysisScreen spinner trong `_bulkAnalyze`; thêm màn loading chung
- `mock_exam_result_screen.dart` — truyền `skillKind` khi navigate vào detail screen

### ObjectiveDetailCard cần hiển thị (nghe/doc)
- Điểm: X/Y đúng
- Bảng mỗi câu: câu hỏi + learner đã chọn + đáp án đúng + ✓/✗
- Text gốc bài thi (collapsible — có thể dài)
- Hint cải thiện ngắn (nếu backend trả về feedback)

### WritingDetailCard cần hiển thị (viet)
- Score badge: X/Y điểm
- Bài viết learner với diff highlight lỗi (reuse `_DiffTextBlock`)
- Corrected text (nếu LLM trả về)
- Bài mẫu (nếu có)

## Key Assumptions cần validate
- [ ] `AttemptResult` cho nghe/doc có `answers_given`, `correct_answers`, `score` — kiểm tra `models.dart`
- [ ] `MockExamResultScreen` có `skillKind` của từng section để truyền vào detail screen — kiểm tra `MockExamSessionView`
- [ ] `_DiffTextBlock` widget có thể tách ra/reuse từ WritingExerciseScreen
- [ ] Backend trả về exercise text trong `AttemptResult` hoặc cần gọi thêm `getExercise()`

## Not Doing (và lý do)
- **Accordion inline trên màn tổng** — speaking section có transcript/audio dài, sẽ làm nặng màn tổng
- **Reuse exercise screens với readOnly mode** — cần thêm state vào 4 screens, side effect nhiều
- **PDF export** — ngoài scope V1
- **Debrief walkthrough** — exam Czech A2 cần review tổng hợp, không phải chuỗi flash

## Open Questions
- `MockExamSectionDetailScreen` hiện tải AttemptResult qua `getAttempt(attemptId)` — response có đủ `answers_given` và `questions` để render ObjectiveDetailCard không, hay cần thêm `getExercise()`?
- Spinner thay thế: màn loading toàn exam chờ tất cả speaking attempts xong — cần timeout xử lý ra sao nếu 1 trong số đó fail?
- `skill_kind` của section — lấy từ `MockExamSection.skillKind` hay từ `AttemptResult.exerciseType`?
