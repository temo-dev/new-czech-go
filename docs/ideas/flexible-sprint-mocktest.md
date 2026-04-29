# Flexible Sprint MockTest

## Problem Statement
Học viên bận không đủ thời gian làm đề thi đầy đủ. Admin cần tạo
đề luyện ngắn với bất kỳ tổ hợp exercise types nào, ngưỡng pass
cao hơn để tín hiệu "mastery" rõ ràng hơn thi thật.

## Recommended Direction
Bỏ ràng buộc `session_type`. Admin tự chọn exercises cho từng section.
Flutter route mỗi section đến đúng screen theo `exercise_type` prefix.
`MockTest` có thêm field `pass_threshold_percent` (default=60, admin
set 80 cho sprint). Scoring = `sum(section_score) / sum(max_points)`.
`FullExamSession` giữ nguyên cho full A2 chuẩn — không thay đổi.

## Key Assumptions to Validate
- [ ] Flutter route mixed-type sections OK — test sprint có 1 speaking + 1 listening
- [ ] 80% threshold không demoralize người mới —
      vì AI scoring thô (ok=50%), 2 sections ok+ok = 50% < 80% → fail
      → xem xét label "Đề nâng cao" để set kỳ vọng đúng
- [ ] Admin tự set max_points hợp lý — không cần validation phức tạp

## MVP Scope

**IN:**
- `pass_threshold_percent` field trên `MockTest` (CMS input, default 60)
- Bỏ `session_type` khỏi CMS form (hoặc make optional/hidden)
- Flutter `_runSection()` route theo `exercise_type` prefix
- CMS cho phép thêm bất kỳ exercise type vào 1 MockTest
- Kết quả dùng `MockExamSession.overall_score` + `passed` (đã có)

**OUT:**
- `FullExamSession` (pisemna/ustni split) — không đụng vào
- DB schema `MockTestSection` — không thay đổi
- Auto-select exercises theo thời gian — admin tự chọn

## Not Doing (and Why)
- **Per-section threshold khác nhau** — quá phức tạp, 1 threshold toàn exam đủ
- **Gamification (streak, badge)** — ngoài scope sprint
- **Time-based scoring** — thêm complexity không cần thiết

## Open Questions
- Mixed exam flow: speaking record-all-then-analyze + listening submit-immediately
  trong cùng 1 session → cần quyết định: từng section submit ngay, hay bulk ở cuối?
  (Đây là câu hỏi lớn nhất về Flutter UX)
- UI label: "Đề luyện rút gọn" hay "Sprint" để learner không nhầm với đề thi thật?
