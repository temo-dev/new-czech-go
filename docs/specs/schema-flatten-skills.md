# Spec: Schema Flatten — Bỏ Skills Table

**Status:** Draft  
**Author:** daniel  
**Date:** 2026-04-30

---

## Objective

Loại bỏ bảng `skills` và tầng trung gian `skill_id` khỏi toàn bộ hệ thống. Exercises, vocabulary sets, và grammar rules link trực tiếp vào `modules`. `skill_kind` trở thành derived field từ `exercise_type` — không lưu vào DB.

Hierarchy sau khi hoàn thành:

```
Course → Module → Exercise
                → VocabularySet → VocabularyItem
                → GrammarRule
```

---

## Background & Motivation

- `skills` table chỉ phục vụ classification, không có business logic riêng
- `skill_kind` là deterministic từ `exercise_type` — lưu vào DB là redundant
- Hierarchy 4 tầng (Course→Module→Skill→Exercise) tạo boilerplate JOIN không cần thiết
- Admin phải tạo Skill record trước khi tạo Exercise — UX friction
- `ensureSkill()` trong v6_handlers tự tạo skill rows để workaround friction này

---

## Acceptance Criteria

### Database

- [ ] Migration `016_flatten_skills.sql` chạy thành công trên DB có 10 skills rows hiện tại
- [ ] `exercises.module_id` populated đúng từ JOIN với `skills` trước khi drop
- [ ] `vocabulary_sets.module_id` populated đúng
- [ ] `grammar_rules.module_id` populated đúng
- [ ] `skills` table không còn tồn tại sau migration
- [ ] `skill_id` column không còn trên `exercises`, `vocabulary_sets`, `grammar_rules`, `content_generation_jobs`

### Backend Go

- [ ] `make backend-build` pass
- [ ] `make backend-test` pass
- [ ] `/v1/skills/` → `/v1/modules/:id/exercises?skill_kind=X` (redirect hoặc xóa)
- [ ] `/v1/admin/skills` và `/v1/admin/skills/` không còn tồn tại
- [ ] `GET /v1/modules/:id` response vẫn trả `skills` array dưới dạng computed (group exercises by skill_kind)
- [ ] `skillKindForExerciseType()` cover đủ tất cả 6 skill kinds
- [ ] `ensureSkill()` đã được xóa hoàn toàn
- [ ] `VocabularySet` và `GrammarRule` dùng `module_id + skill_kind` (derived) thay `skill_id`

### Flutter

- [ ] `make flutter-analyze` pass
- [ ] `make flutter-test` pass
- [ ] `class Skill` trong `models.dart` đã xóa hoặc thay thành lightweight struct `(moduleId, skillKind)`
- [ ] `listSkillExercises(skillId)` → `listModuleExercises(moduleId, skillKind)`
- [ ] `ModuleDetailScreen` hiển thị đúng skills grouped từ exercises
- [ ] Navigation vẫn hoạt động: Home → Module → Skill tab → ExerciseList

### CMS

- [ ] `make cms-build` pass
- [ ] `make cms-lint` pass
- [ ] `/skills` route và management page đã xóa
- [ ] Exercise form: chọn `module` trực tiếp, `skill_kind` auto-derive từ `exercise_type`
- [ ] Vocab/Grammar creation: không còn skill dropdown

---

## Technical Design

### Migration SQL (`016_flatten_skills.sql`)

```sql
-- Step 1: Add module_id + skill_kind to exercises (derive from skills)
-- skill_kind must be stored: matching/fill_blank/choice_word shared by tu_vung AND ngu_phap
ALTER TABLE exercises ADD COLUMN module_id TEXT NOT NULL DEFAULT '';
ALTER TABLE exercises ADD COLUMN skill_kind TEXT NOT NULL DEFAULT '';
UPDATE exercises e
SET module_id = s.module_id, skill_kind = s.skill_kind
FROM skills s
WHERE s.id = e.skill_id AND e.skill_id <> '';
DROP INDEX IF EXISTS idx_exercises_skill_id;
ALTER TABLE exercises DROP COLUMN skill_id;
CREATE INDEX idx_exercises_module_id ON exercises(module_id);
CREATE INDEX idx_exercises_module_skill ON exercises(module_id, skill_kind);

-- Step 2: vocabulary_sets — drop skill_id FK, use existing module_id
-- (content_generation_jobs already has module_id NOT NULL)
ALTER TABLE vocabulary_sets DROP CONSTRAINT IF EXISTS vocabulary_sets_skill_id_fkey;
ALTER TABLE vocabulary_sets DROP COLUMN skill_id;

-- Step 3: grammar_rules — same
ALTER TABLE grammar_rules DROP CONSTRAINT IF EXISTS grammar_rules_skill_id_fkey;
DROP INDEX IF EXISTS idx_grammar_rules_skill_id;
ALTER TABLE grammar_rules DROP COLUMN skill_id;

-- Step 4: content_generation_jobs — drop nullable skill_id
ALTER TABLE content_generation_jobs DROP COLUMN IF EXISTS skill_id;

-- Step 5: Drop skills table (no FKs remain)
DROP TABLE IF EXISTS skills;
```

### `skillKindForExerciseType()` — Extended

```go
func skillKindForExerciseType(exerciseType string) string {
    switch {
    case strings.HasPrefix(exerciseType, "uloha_"):
        return "noi"
    case strings.HasPrefix(exerciseType, "psani_"):
        return "viet"
    case strings.HasPrefix(exerciseType, "poslech_"):
        return "nghe"
    case strings.HasPrefix(exerciseType, "cteni_"):
        return "doc"
    case strings.HasPrefix(exerciseType, "vocab_"):
        return "tu_vung"
    case strings.HasPrefix(exerciseType, "grammar_"):
        return "ngu_phap"
    default:
        return ""
    }
}
```

> **Note:** Vocab và grammar exercise types phải dùng prefix `vocab_` và `grammar_`. Cần verify với exercise_type values hiện tại trong DB trước khi merge.

### API Changes

| Old | New |
|-----|-----|
| `GET /v1/skills/:id/exercises` | `GET /v1/modules/:id/exercises?skill_kind=X` |
| `GET /v1/modules/:id/skills` | Xóa — thay bằng computed từ exercises |
| `GET /v1/admin/skills` | Xóa |
| `POST /v1/admin/skills` | Xóa |
| `GET /v1/admin/skills/:id` | Xóa |
| `PUT /v1/admin/skills/:id` | Xóa |
| `DELETE /v1/admin/skills/:id` | Xóa |

`GET /v1/modules/:id` response vẫn trả `skills` field:

```json
{
  "id": "module-xxx",
  "skills": [
    { "skill_kind": "noi",  "title": "Nói (Mluvení)", "exercise_count": 4 },
    { "skill_kind": "nghe", "title": "Nghe (Poslech)", "exercise_count": 5 }
  ]
}
```

Đây là computed field — aggregate từ exercises, không từ skills table.

### Flutter Model Replacement

```dart
// Thay Skill class bằng:
class SkillSummary {
  const SkillSummary({
    required this.moduleId,
    required this.skillKind,
    required this.exerciseCount,
  });

  final String moduleId;
  final String skillKind;
  final int exerciseCount;

  // skill_kind → display title handled by l10n (đã tồn tại)
}
```

### Vocab/Grammar: `skill_kind` Derivation

`VocabularySet` và `GrammarRule` không cần `skill_kind` stored — `source_type` trong `content_generation_jobs` (`vocabulary_set` / `grammar_rule`) xác định kind khi cần.

Trong API response, nếu cần `skill_kind`, derive:
- `vocabulary_set` → `tu_vung`
- `grammar_rule` → `ngu_phap`

---

## Files to Change

### Backend

| File | Action |
|------|--------|
| `db/migrations/016_flatten_skills.sql` | Create |
| `internal/contracts/types.go` | Xóa `Skill` struct, `SkillID` field → `ModuleID` |
| `internal/httpapi/server.go` | Xóa routes skills, `handleSkillExercises`, `handleAdminSkills`, `handleAdminSkillByID`, `handleModuleSkills`, `ensureSkill`; extend `skillKindForExerciseType` |
| `internal/httpapi/v6_handlers.go` | Xóa `ensureSkill()` calls, `skill_id` params → `module_id` |
| `internal/store/postgres_courses_modules_skills.go` | Xóa skills CRUD methods |
| `internal/store/postgres_exercises.go` | Update queries: `module_id` thay JOIN skills |

### Flutter

| File | Action |
|------|--------|
| `lib/models/models.dart` | Xóa `Skill` class → `SkillSummary` |
| `lib/core/api/api_client.dart` | `listSkillExercises` → `listModuleExercises` |
| `lib/features/home/screens/module_detail_screen.dart` | Dùng `SkillSummary` từ exercises |
| `lib/features/home/screens/exercise_list_screen.dart` | Nhận `moduleId + skillKind` thay `Skill` |

### CMS

| File | Action |
|------|--------|
| `cms/app/skills/` hoặc tương đương | Xóa route |
| `cms/components/exercise-dashboard.tsx` | Module picker trực tiếp |
| `cms/components/vocabulary/` | Xóa skill dropdown |
| `cms/components/grammar/` | Xóa skill dropdown |

---

## What We Are NOT Doing

- **Không giữ `skill_kind` column** trên `vocabulary_sets`/`grammar_rules` — derive từ resource type đủ
- **GIỮ `skill_kind` column trên `exercises`** — `matching`/`fill_blank`/`choice_word` dùng chung cho cả `tu_vung` lẫn `ngu_phap`, không thể derive từ `exercise_type` (confirmed qua pre-flight query)
- **Không versioning API** — breaking change accepted (local dev + prod reset)
- **Không giữ skills CRUD** — không còn entity để manage
- **Không thay đổi scoring, mock test, LLM feedback logic** — out of scope
- **Không thay đổi l10n keys** (`skillNoi`, `skillNghe`...) — vẫn dùng cho UI labels

---

## Architecture Notes

### Pool=exam exercises: `module_id = ''` là intentional

Pool=exam exercises hiện có `skill_id = ''`. Sau migration, `module_id = ''` — đây là **đúng**: pool=exam exercises thuộc MockTest sections, không thuộc Module. Query `WHERE module_id <> ''` lọc đúng khi cần list course exercises.

### `GET /v1/modules/:id` — Computed Skills Query

Sau khi xóa `handleModuleSkills`, module detail response tính skills từ:

```sql
SELECT
    CASE
        WHEN exercise_type LIKE 'uloha_%'   THEN 'noi'
        WHEN exercise_type LIKE 'psani_%'   THEN 'viet'
        WHEN exercise_type LIKE 'poslech_%' THEN 'nghe'
        WHEN exercise_type LIKE 'cteni_%'   THEN 'doc'
        WHEN exercise_type LIKE 'vocab_%'   THEN 'tu_vung'
        WHEN exercise_type LIKE 'grammar_%' THEN 'ngu_phap'
    END AS skill_kind,
    COUNT(*) AS exercise_count
FROM exercises
WHERE module_id = $1 AND status = 'published'
GROUP BY skill_kind
HAVING skill_kind IS NOT NULL
ORDER BY skill_kind;
```

Backend dùng `skillKindForExerciseType()` thay raw SQL CASE khi scan rows.

### Flutter `ExerciseListScreen` Refactor

Widget hiện nhận `required this.skill` (Skill object). Dùng `skill.skillKind` ở 10+ chỗ, `skill.id` để gọi API, `skill.title` cho display. Refactor thành:

```dart
const ExerciseListScreen({
  required this.client,
  required this.moduleId,    // thay skill.id trong API call
  required this.skillKind,   // thay skill.skillKind
});
```

`skill.title` thay bằng l10n lookup (đã tồn tại: `l.skillNoi`, `l.skillNghe`...).

### Flutter `_skillKindForExerciseType` Consolidation

`mock_exam_screen.dart:32` có local duplicate. Sau migration, move hàm này thành utility method trong `models.dart` hoặc `utils/skill_utils.dart`. Dùng chung ở cả `ExerciseListScreen` và `MockExamScreen`.

### CMS Files (Xác nhận qua filesystem scan)

Files cần xóa/sửa:

| File | Action |
|------|--------|
| `cms/app/skills/page.tsx` | Xóa |
| `cms/app/api/admin/skills/route.ts` | Xóa |
| `cms/app/api/admin/skills/[skillId]/route.ts` | Xóa |
| `cms/components/skill-dashboard.tsx` | Xóa |
| `cms/components/cms-sidebar.tsx` | Xóa link đến /skills |
| `cms/components/exercise-dashboard.tsx` | Module picker trực tiếp |
| `cms/app/vocabulary/page.tsx` | Xóa skill dropdown |
| `cms/app/grammar/page.tsx` | Xóa skill dropdown |
| `cms/components/exercise-form/validation.ts` | Xóa skill validation |
| `cms/lib/i18n.tsx` | Xóa skills-related strings |

### Pre-Migration Checklist

Trước khi viết migration code:

1. **Verify vocab/grammar exercise_type prefixes**: `SELECT DISTINCT exercise_type FROM exercises WHERE exercise_type NOT LIKE 'uloha_%' AND exercise_type NOT LIKE 'psani_%' AND exercise_type NOT LIKE 'poslech_%' AND exercise_type NOT LIKE 'cteni_%';`
2. **Confirm pool=exam count**: `SELECT count(*) FROM exercises WHERE skill_id = '' OR skill_id IS NULL;`
3. **Confirm all skill_id links valid**: `SELECT count(*) FROM exercises WHERE skill_id <> '' AND skill_id NOT IN (SELECT id FROM skills);`

---

## Risk & Mitigation

| Risk | Mitigation |
|------|-----------|
| Pool=exam exercises `module_id = ''` breaks future queries | Document as invariant; all module queries use `WHERE module_id <> ''` |
| `exercise_type` prefix cho vocab/grammar chưa verify | Run pre-migration checklist query #1 trước |
| Flutter `Skill.id` dùng làm persistent state | Confirmed: chỉ dùng cho API call `listSkillExercises` → sẽ thay bằng `moduleId` |
| `ExerciseListScreen` refactor lớn hơn dự kiến | Widget nhận `(moduleId, skillKind)` strings — không cần struct |

---

## Implementation Order

1. **Pre-migration verification** — run 3 SQL checks trên live DB
2. **Migration SQL** — `016_flatten_skills.sql`, test local
3. **Backend Go** — contracts → store → handlers (build + test sau mỗi bước)
4. **Flutter** — `skill_utils.dart` → models → api_client → screens
5. **CMS** — xóa skills pages + update exercise/vocab/grammar forms
6. **Verify** — `make verify` (build + lint + test tất cả layers)
