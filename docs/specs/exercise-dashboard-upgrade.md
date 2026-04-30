# Exercise Dashboard Upgrade — Spec

## Objective

Replace the flat exercise list with a **coverage matrix + drill-down** layout so admins can instantly see content gaps and navigate to any exercise in 2 clicks instead of scrolling a 200-item list.

Target user: single admin managing A2 Czech exam content.

---

## Layout Overview

```
[ Khoá học ]  [ Exam Pool ]          ← tabs

─── Tab: Khoá học ───────────────────────────────────

  KHOÁ: "Giao tiếp cơ bản"          ← course header row
  Module          | Nói  | Nghe | Viết | Đọc
  ─────────────────────────────────────────
  Chủ đề 1        |  20🟢|   8🟡|   0🔴|  14🟡
  Chủ đề 2        |  14🟡|  22🟢|   9🟡|   2🔴
  KHOÁ: "Ôn thi A2"
  Ôn tập nghe     |   3🔴|  18🟢|   5🔴|  21🟢
  ─────────────────────────────────────────
  Tổng            |  37  |  48  |  14  |  37

  [+ Tạo exercise]  [Filter: Module ▾] [skill_kind ▾] [Status ▾] [🔍 Tìm]

  ─── Exercise list (filtered) ────────────────────────
  | Title         | Type       | Module   | Status   |
  | ...           | ...        | ...      | ...      |

─── Tab: Exam Pool ──────────────────────────────────

  Exercise type   | Số lượng | % có audio
  ────────────────────────────────────────
  uloha_1         |   4      | 100%
  uloha_2         |   3      |  67%
  poslech_1       |   2      |  50%
  ...

  ─── Exercise list (pool=exam) ───────────────────────
```

---

## Tab 1: Khoá học — Matrix

### Rows

- Grouped by Course with a **non-clickable course header row** (Course title, darker bg).
- Within each course: modules sorted by `sequence_no`.
- Final row: **Tổng** — sum across all modules per skill_kind column.

### Columns

4 fixed columns: `noi` | `nghe` | `viet` | `doc`  
`tu_vung` and `ngu_phap` excluded (managed on /vocabulary and /grammar pages).

### Cell content

```
  20           ← published count (colored)
  (3 draft)    ← draft count sub-label, grey, no color
```

### Color scale (published count vs target 20)

| Published count | Color |
|----------------|-------|
| 0–5 | 🔴 red `#FEE2E2` |
| 6–14 | 🟡 yellow `#FEF9C3` |
| 15–19 | 🟢 light green `#D1FAE5` |
| ≥ 20 | 🟢 dark green `#6EE7B7` bg, `#065F46` text |

Empty cell (module has no exercises of that skill_kind): show `—` in red.

### Cell click interaction

1. Set `moduleFilter = module.id` and `skillKindFilter = skill_kind` in component state.
2. Scroll to exercise list section (`document.getElementById('exercise-list').scrollIntoView`).
3. Highlight the active cell with a border ring (1px `#FF6A14`).
4. "All" row in Tổng: clicking clears `moduleFilter`, sets only `skillKindFilter`.

---

## Tab 2: Exam Pool

### Mini-matrix

Rows = one per `exercise_type` (only types that exist in pool=exam, alphabetical).  
Columns:
- **Số lượng** — total exercises of this type in exam pool
- **Published** — count with status=published
- **Có audio** — count where `exercise_audio` exists (for poslech_* and uloha_*)

Click row → filter exercise list below to that exercise_type.

### Exercise list below

Same list component as Tab 1, hardcoded `pool=exam` filter, no module/skill_kind filter controls (those are irrelevant for exam pool).

---

## Exercise List (shared component)

Visible on both tabs below the matrix/mini-matrix.

**Filter bar controls (Tab 1 only):**
- Module dropdown (populated from loaded modules)
- skill_kind dropdown: Nói / Nghe / Viết / Đọc / Tất cả
- Status: Tất cả / Draft / Published / Archived
- Text search (title + short_instruction, client-side)

**Table columns:**
| Column | Notes |
|--------|-------|
| Title | |
| Type | `exercise_type` badge |
| Module | module title or "—" for exam pool |
| Status | Coloured badge: draft=grey, published=green, archived=red |
| Actions | Edit / Delete |

**Row click or Edit button** → open slide-over form (existing behavior, no change).

---

## API Changes

### Existing (no change needed if supported)

```
GET /v1/exercises?pool=course             → all course exercises
GET /v1/exercises?pool=exam               → all exam exercises
GET /v1/modules                           → module list with course_id
GET /v1/courses                           → course list (for grouping)
```

### New query param (backend)

Add `status` filter to `GET /v1/exercises` if not present:

```go
// backend — exercises handler
if s := r.URL.Query().Get("status"); s != "" {
    query = query.Where("status = $N", s)
}
```

### Data loading strategy (client)

```
On mount (parallel):
  A = GET /v1/exercises?pool=course&status=published   → published counts for matrix
  B = GET /v1/exercises?pool=course&status=draft       → draft counts for cell subtitle
  C = GET /v1/exercises?pool=exam                      → exam pool tab
  D = GET /v1/modules                                  → row labels
  E = GET /v1/courses                                  → course grouping

Client-side group A and B by [module_id][skill_kind].
Merge into MatrixCell { published: number; draft: number }.
```

No N+1 queries. 5 parallel calls, all cached after first load.

---

## File Split (Prerequisite PR)

`cms/components/exercise-dashboard.tsx` (2036 lines) → split before adding matrix:

| File | Est. lines | Contents |
|------|-----------|---------|
| `exercise-utils.ts` | ~400 | All `parse*` and `build*` pure functions |
| `exercise-form/index.tsx` | ~350 | Slide-over shell, autosave, submit logic |
| `exercise-list.tsx` | ~400 | Table + filter bar component |
| `exercise-matrix.tsx` | ~200 | Matrix grid + Exam Pool mini-matrix |
| `exercise-dashboard.tsx` | ~200 | State orchestrator, data fetching, tab state |

Rule: no file over 500 lines. All existing tests must pass unchanged.

---

## Acceptance Criteria

### Matrix

- [ ] Matrix renders correct published count per cell after page load
- [ ] Cell shows draft sub-label when draft count > 0
- [ ] Cell color matches scale (0–5 red, 6–14 yellow, 15–19 light green, ≥20 dark green)
- [ ] Course header rows appear, modules sorted by sequence_no within course
- [ ] Tổng row sums correctly
- [ ] Clicking a cell sets module + skill_kind filter and scrolls to list
- [ ] Active cell has orange ring highlight
- [ ] Clicking Tổng cell sets only skill_kind filter (no module filter)

### Exam Pool tab

- [ ] Mini-matrix shows all exercise_types present in exam pool
- [ ] Published count and audio count correct per type
- [ ] Clicking a row filters list below to that type

### Exercise list

- [ ] Filter bar controls function independently and together
- [ ] Text search filters by title (case-insensitive)
- [ ] Edit opens slide-over with correct exercise data
- [ ] Delete removes from list without page reload

### File split

- [ ] `make cms-build` passes after split
- [ ] `make cms-lint` passes after split
- [ ] No behavior change on existing exercise CRUD

---

## Out of Scope

- Editable target per cell
- Bulk publish/archive
- `tu_vung` / `ngu_phap` in matrix
- Drag-and-drop reorder
- Pagination (client-side filtering sufficient for current content volume)
