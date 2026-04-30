# Schema Flatten: Bỏ Skills Table

## Problem Statement

How might we simplify the DB schema bằng cách loại bỏ tầng `skills` redundant, giúp code dễ đọc hơn và query sạch hơn?

## Recommended Direction

Bỏ bảng `skills`. Exercises link trực tiếp vào `modules` qua `module_id`. `skill_kind` không lưu vào DB — computed on-the-fly từ `exercise_type` (hàm `skillKindForExerciseType` đã tồn tại trong backend).

Hierarchy mới: `Course → Module → Exercise`

`skill_kind` vẫn xuất hiện trong API response và Flutter UI nhưng là derived field, không persisted.

## Key Assumptions

- [ ] `skillKindForExerciseType()` cover đủ tất cả exercise types hiện tại — verify bằng cách đọc hàm và so sánh với exercise_type enum
- [ ] Không có business logic nào chỉ sống trong skills table (title, sequence_no) mà không thể derive — confirmed: title = hardcode per kind, sequence_no không dùng
- [ ] Flutter navigation không dùng `skill.id` làm route key bền vững — cần check

## MVP Scope

**Trong scope:**
- Migration SQL: thêm `module_id` vào exercises/vocabulary_sets/grammar_rules/content_generation_jobs, xóa `skill_id`, drop `skills` table
- Backend Go: xóa Skill struct, skills CRUD handlers, skills store; update tất cả SQL queries
- API: endpoint `GET /v1/skills/:id/exercises` → `GET /v1/modules/:id/exercises?skill_kind=X`
- Flutter: xóa Skill model, cập nhật api_client, module_detail_screen
- CMS: xóa skills management, exercise form dùng module_id trực tiếp

**Ngoài scope:**
- Thay đổi business logic của exercises
- Thay đổi mock test flow
- Thay đổi scoring logic

## Not Doing (and Why)

- **Giữ `skill_kind` column trên exercises** — redundant, derive từ exercise_type là đủ
- **Versioning API** — breaking change chấp nhận được, local dev reset
- **Giữ skills CRUD trong CMS** — không còn entity để manage
- **Thêm per-module skill metadata** — không có use case thực tế

## Open Questions

- `content_generation_jobs.skill_id` nullable — sau migration thành `module_id`, có cần `skill_kind` TEXT thêm vào không? (jobs cần biết generate cho kind nào)
- Flutter `_SkillCard` widget hiện nhận `Skill` object — refactor thành nhận `(String moduleId, String skillKind)` hay tạo lightweight struct?
