# Exam Template vs Practice Set

## Problem Statement
How might we untangle the exam session model so that real exam simulation and flexible skill practice don't share confusing state, routing logic, or scoring paths?

## Recommended Direction

Two distinct exam modes replacing the current `session_type: speaking | pisemna | full | ""` mess:

```
exam_mode: "real" | "practice"

ExamTemplate (exam_mode = "real")
  ├── Fixed A2 structure: 4 sections (speaking + listening + reading + writing)
  ├── Scoring: 60% threshold cố định (≥24/40 ustni, ≥42/70 pisemna)
  └── Admin chỉ chọn exercise per section, không thay đổi structure

PracticeSet (exam_mode = "practice")
  ├── Admin tự chọn sections (bất kỳ skill nào, bất kỳ số lượng)
  ├── pass_threshold_percent tùy chỉnh
  └── Time estimate linh hoạt
```

`MockTest` entity và `MockExamSession` được giữ nguyên — chỉ đổi field `session_type` → `exam_mode` và xóa toàn bộ `FullExamSession` layer.

## Key Assumptions to Validate
- [ ] `FullExamSession` chưa có real user data trong production (safe to drop tables)
- [ ] Flutter không có live user nào đang ở `FullExamIntroScreen` flow
- [ ] Scoring real exam = 60% flat threshold cho cả 2 parts (không có edge case phức tạp hơn theo spec NPI)

## MVP Scope
- Thêm `exam_mode` column vào `mock_tests` DB table
- Xóa `session_type` column
- Xóa toàn bộ `FullExamSession` stack: entity, store, scorer, API, Flutter screens, auto-link
- `CompleteMockExam` scoring: real mode → 60% fixed, practice mode → `pass_threshold_percent`
- CMS: bỏ `session_type` dropdown, thêm `exam_mode` radio (real | practice)
- Flutter: xóa `FullExamIntroScreen` + `FullExamResultScreen`, update MockExamScreen routing

## Not Doing (and Why)
- Rename DB table `mock_tests` → `exam_templates` — không đáng rủi ro migration
- Tách `MockExamSession` thành 2 tables — over-engineering, 1 table đủ cho cả 2 modes
- Thêm UI differentiation phức tạp giữa real/practice — learner flow giữ nguyên
- Hardcode real exam sections (force 4 skills) — admin vẫn có thể tạo real exam với ít section hơn để test

## Open Questions
- Khi `exam_mode = "real"`, có nên enforce admin phải chọn đủ 4 sections không, hay chỉ là convention?
- `pass_threshold_percent = 0` (default 60) có conflict với real mode logic không? Cần decide 1 source of truth.
