# Plan: Exercise Dashboard Upgrade (Coverage Matrix)

Source: `docs/specs/exercise-dashboard-upgrade.md` + `docs/specs/exercise-dashboard-user-flow.md`

---

## Architecture Decision

Current `loadExercises()` loads ALL exercises in one call — no pagination, all filters client-side.
This means coverage matrix counts can be derived entirely from the existing `items` array:
```ts
const publishedCount = items.filter(i =>
  i.module_id === moduleId && i.skill_kind === sk && i.status === 'published'
).length;
```
**No backend changes required.** Matrix is pure client-side computation.

---

## Dependency Graph

```
exercise-utils.ts (pure functions)
    └─ ExerciseForm/index.tsx (slide-over shell)
    └─ ExerciseList.tsx (table + filter bar)
    └─ ExerciseMatrix.tsx (matrix grid)
         └─ ExerciseDashboard.tsx (thin orchestrator + tab state)
```

File split must land before any matrix work. Each file can be extracted independently.

---

## Phase 1 — File Split (Prerequisite)

### FS-1: Extract pure utility functions

**Files changed:** new `exercise-utils.ts`, `exercise-dashboard.tsx`

**What to move:** all top-level functions that are pure (no hooks, no JSX):
- `createInitialFormState()`
- `parseRequiredInfoSlots()`, `parseLineList()`, `parseChoiceOptions()`
- `formStateFromExercise()`
- `parsePoslechOptions()`, `parsePoslechCorrectAnswers()`, `parsePoslechItems()`
- `buildPoslechPayload()`, `buildPoslechBase()`
- `parseCteniCorrectAnswers()`, `buildCteniPayload()`, `buildCteniBase()`
- `buildCreatePayload()`, `buildUpdatePayload()`
- `appendLineIfMissing()`, `assetPreviewSrc()`
- All inline style `const`s (fieldStyle, badgeStyle, etc.)

**Acceptance criteria:**
- [ ] `exercise-utils.ts` contains all parse/build/style helpers
- [ ] No React imports in `exercise-utils.ts`
- [ ] `exercise-dashboard.tsx` imports from `./exercise-utils`
- [ ] `make cms-build` passes
- [ ] `make cms-lint` passes
- [ ] Exercise CRUD still works end-to-end in browser

---

### FS-2: Extract ExerciseList component

**Files changed:** new `exercise-list.tsx`, `exercise-dashboard.tsx`

**What to extract:** the table + filter bar rendering block (currently ~lines 1140–1650 approx)

Props interface:
```ts
interface ExerciseListProps {
  items: Exercise[];
  modules: CmsModule[];
  courses: CmsCourse[];
  mockTests: CmsMockTest[];
  onEdit: (id: string) => void;
  onDelete: (id: string) => void;
  // active filter state (controlled from parent for matrix cell click sync)
  moduleFilter: string;
  skillKindFilter: string;
  statusFilter: string;
  textFilter: string;
  onFilterChange: (patch: Partial<FilterState>) => void;
  poolMode: 'course' | 'exam'; // hides module/skill filters when 'exam'
}
```

**Acceptance criteria:**
- [ ] `exercise-list.tsx` ≤ 500 lines
- [ ] Filter bar + table renders identically to current
- [ ] `make cms-build` + `make cms-lint` pass
- [ ] Filter interactions work (select module, select skill, text search, clear)

---

### FS-3: Extract ExerciseForm component

**Files changed:** new `exercise-form/index.tsx`, `exercise-dashboard.tsx`

**What to extract:** slide-over shell + all form rendering (currently ~lines 1200–1920 approx)

Props interface:
```ts
interface ExerciseFormProps {
  open: boolean;
  editingId: string | null;
  initialForm: ExerciseFormState;
  modules: CmsModule[];
  courses: CmsCourse[];
  assets: PromptAsset[];
  onSave: (form: ExerciseFormState) => Promise<void>;
  onDelete?: (id: string) => Promise<void>;
  onClose: () => void;
  onUploadAsset: (file: File) => Promise<void>;
  saving: boolean;
  error: string;
}
```

**Acceptance criteria:**
- [ ] `exercise-form/index.tsx` ≤ 500 lines
- [ ] Slide-over opens/closes correctly
- [ ] All 20 exercise types render their fields correctly
- [ ] Autosave (localStorage) still works
- [ ] `make cms-build` + `make cms-lint` pass

---

### FS-4: Slim down ExerciseDashboard orchestrator

**Files changed:** `exercise-dashboard.tsx` (orchestrator only)

After FS-1–3, `exercise-dashboard.tsx` should only contain:
- State declarations (items, modules, courses, mockTests, filterState, editingId, showForm, etc.)
- `loadExercises()`, `loadModules()`, `loadCourses()`, `loadMockTests()` data fetchers
- `handleSave()`, `handleDelete()` mutation handlers
- Tab state (`activeTab: 'course' | 'exam'`)
- Return JSX: tab bar + `<ExerciseMatrix>` or exam pool section + `<ExerciseList>` + `<ExerciseForm>`

**Acceptance criteria:**
- [ ] `exercise-dashboard.tsx` ≤ 250 lines
- [ ] All 5 files pass `make cms-build` + `make cms-lint`
- [ ] Full exercise CRUD smoke test passes (`make smoke-course-flow`)

**Checkpoint: Phase 1 complete** — no behavior change, 5 files under 500 lines each.

---

## Phase 2 — Coverage Matrix (Tab: Khoá học)

### CM-1: ExerciseMatrix component — data + skeleton

**Files changed:** new `exercise-matrix.tsx`

Implement static structure first (no cell interactions):

```ts
type MatrixCell = { published: number; draft: number };
type MatrixRow = {
  moduleId: string;
  moduleTitle: string;
  courseId: string;
  courseTitle: string;
  cells: Record<string, MatrixCell>; // skill_kind → counts
};
```

Helper `buildMatrix(items, modules, courses) → MatrixRow[]`:
- Group items by `[module_id][skill_kind]` and count by `status`
- Filter `skill_kind` to `['noi', 'nghe', 'viet', 'doc']` only
- Sort rows: by course sequence_no, then module sequence_no within course
- Skip items with no `module_id` (they belong to exam pool)

Color helper:
```ts
function cellColor(published: number): string {
  if (published >= 20) return '#6EE7B7';   // dark green
  if (published >= 15) return '#D1FAE5';   // light green
  if (published >= 6)  return '#FEF9C3';   // yellow
  return '#FEE2E2';                         // red
}
```

Render: course header rows (non-clickable) + module rows + Tổng row.
Cell format: `{published}` in bold, `({draft} draft)` in grey below if draft > 0.

**Acceptance criteria:**
- [ ] Matrix renders with correct published/draft counts
- [ ] Color coding matches scale
- [ ] Course header rows render (darker bg, no cells)
- [ ] Tổng row shows column sums
- [ ] Component ≤ 250 lines (no interactions yet)
- [ ] `make cms-build` passes

---

### CM-2: Cell click → filter + scroll

**Files changed:** `exercise-matrix.tsx`, `exercise-dashboard.tsx`

Wire cell click to parent filter state:

```ts
// ExerciseMatrix props addition
onCellClick: (moduleId: string | null, skillKind: string) => void;
activeCell: { moduleId: string | null; skillKind: string } | null;
```

In `ExerciseDashboard`:
```ts
function handleCellClick(moduleId: string | null, skillKind: string) {
  setModuleFilter(moduleId ?? '');
  setSkillKindFilter(skillKind);
  document.getElementById('exercise-list')?.scrollIntoView({ behavior: 'smooth' });
}
```

Active cell: orange border ring `2px solid #FF6A14`.  
Clicking active cell again → clears both filters.  
Clicking Tổng cell → clears `moduleFilter`, sets `skillKindFilter` only.

**Acceptance criteria:**
- [ ] Click cell → filter bar updates (module + skill_kind dropdowns reflect new values)
- [ ] List scrolls into view after click
- [ ] Active cell has orange ring
- [ ] Click active cell → clears filters, ring removed
- [ ] Click Tổng row → only skill_kind filter set

---

### CM-3: Tab system + "Khoá học" tab wiring

**Files changed:** `exercise-dashboard.tsx`

Add tab bar at top:
```tsx
<div style={{ display: 'flex', gap: 0, borderBottom: '2px solid var(--border)' }}>
  <TabButton active={activeTab === 'course'} onClick={() => setActiveTab('course')}>
    Khoá học
  </TabButton>
  <TabButton active={activeTab === 'exam'} onClick={() => setActiveTab('exam')}>
    Exam Pool
  </TabButton>
</div>
```

Tab "Khoá học" = `<ExerciseMatrix>` + `<ExerciseList poolMode="course">`.
Tab "Exam Pool" = exam mini-matrix + `<ExerciseList poolMode="exam">` (Phase 3).

**Acceptance criteria:**
- [ ] Tab bar renders
- [ ] "Khoá học" tab shows matrix + filtered list
- [ ] Switching tabs does not lose matrix filter state
- [ ] `<ExerciseList poolMode="exam">` on Exam Pool tab shows only pool=exam exercises (stub — full mini-matrix in Phase 3)

**Checkpoint: Phase 2 complete** — Coverage matrix functional. Filter + scroll working.

---

## Phase 3 — Exam Pool Tab

### EP-1: Exam Pool mini-matrix

**Files changed:** `exercise-matrix.tsx` (new `ExamPoolMatrix` export or section)

Mini-matrix for pool=exam items:
- Row per `exercise_type` (from items where `pool === 'exam'`, sorted alphabetically)
- Columns: **Tổng** (all count) | **Published** (status=published) | **Có audio** (has `assets` with audio mime type OR `detail` has audio fields)
- Click row → set `examTypeFilter` state → filter exam list below
- Row with 0 total: show `—` in red

**Acceptance criteria:**
- [ ] Mini-matrix shows all exercise types found in pool=exam items
- [ ] Counts are correct (Tổng = all, Published = status match, Có audio = assets present)
- [ ] Rows with 0 items show `—` in red
- [ ] Click row → list filters to that exercise_type

---

### EP-2: Exam Pool list + form integration

**Files changed:** `exercise-dashboard.tsx`, `exercise-list.tsx`

When `poolMode === 'exam'`:
- ExerciseList hides module/skill_kind filter dropdowns
- Shows exercise_type filter dropdown instead (from mini-matrix active row or standalone)
- `[+ Tạo exam exercise]` button opens form with `pool` pre-set to `'exam'`

**Acceptance criteria:**
- [ ] Exam Pool list shows only pool=exam exercises
- [ ] Module/skill_kind filters hidden in exam mode
- [ ] "+ Tạo exam exercise" opens form with pool=exam pre-filled
- [ ] Edit/delete work same as Tab 1

**Checkpoint: Phase 3 complete** — Both tabs fully functional.

---

## Phase 4 — Polish

### PO-1: Empty states + loading skeletons

- Matrix loading: skeleton rows (grey animated bars)
- Empty cell click → list shows empty state: "Chưa có exercise {skill_kind} nào trong module này" + "+ Tạo" CTA
- API error: error banner with "Thử lại" button
- Exam pool empty: "Chưa có exercise trong exam pool"

### PO-2: Pre-fill form from active filter

When `[+ Tạo exercise]` clicked with active `moduleFilter` + `skillKindFilter`:
- Form opens with `moduleId` + `skillKind` pre-filled

### PO-3: Tổng row sticky

Tổng row sticks to bottom of matrix viewport (does not scroll away).
```css
position: sticky; bottom: 0; z-index: 1; background: var(--surface-alt);
```

**Acceptance criteria (Phase 4):**
- [ ] Skeleton visible during initial load
- [ ] Empty state renders with correct skill_kind/module name
- [ ] Error state renders with retry
- [ ] New exercise form pre-fills module/skill_kind from active filter
- [ ] Tổng row stays visible when scrolling through many modules
- [ ] `make verify` passes

---

## Task Summary

| ID | Task | Phase | Est. |
|----|------|-------|------|
| FS-1 | Extract utils | 1 | 45m |
| FS-2 | Extract ExerciseList | 1 | 60m |
| FS-3 | Extract ExerciseForm | 1 | 60m |
| FS-4 | Slim orchestrator | 1 | 30m |
| CM-1 | Matrix data + render | 2 | 90m |
| CM-2 | Cell click + scroll | 2 | 45m |
| CM-3 | Tab system | 2 | 30m |
| EP-1 | Exam mini-matrix | 3 | 60m |
| EP-2 | Exam list + form | 3 | 30m |
| PO-1 | Empty + loading | 4 | 45m |
| PO-2 | Form pre-fill | 4 | 20m |
| PO-3 | Tổng sticky | 4 | 15m |

Total: ~9 giờ. Có thể làm Phase 1 riêng (PR-1) và Phase 2–4 riêng (PR-2).

---

## Out of Scope (confirmed)

- Backend `?status=` filter param (not needed — client-side counts from full load)
- tu_vung / ngu_phap in matrix
- Editable target per cell
- Bulk operations
- Pagination
