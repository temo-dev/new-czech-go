# Exercise Dashboard Upgrade — Todo

Spec: `docs/specs/exercise-dashboard-upgrade.md`
Plan: `tasks/exercise-dashboard-plan.md`
User flow: `docs/specs/exercise-dashboard-user-flow.md`

---

## Phase 1 — File Split (PR-1)

- [ ] **FS-1** Extract all parse*/build*/style helpers → `cms/components/exercise-utils.ts`
- [ ] **FS-2** Extract table + filter bar → `cms/components/exercise-list.tsx` (props: items, filters, callbacks)
- [ ] **FS-3** Extract slide-over form → `cms/components/exercise-form/index.tsx` (props: open, initialForm, onSave, onClose)
- [ ] **FS-4** Slim `exercise-dashboard.tsx` to orchestrator ≤ 250 lines (state + data fetch + tab state)

**Checkpoint:** `make cms-build` + `make cms-lint` + `make smoke-course-flow` all pass

---

## Phase 2 — Coverage Matrix (PR-2)

- [ ] **CM-1** `ExerciseMatrix` component: `buildMatrix()` helper + grid render (course headers, module rows, Tổng row, color coding)
- [ ] **CM-2** Wire cell click → `onCellClick(moduleId, skillKind)` → update filter state + scrollIntoView + orange ring on active cell
- [ ] **CM-3** Tab bar in dashboard: `[Khoá học] [Exam Pool]` — Tab 1 shows matrix + list, Tab 2 placeholder

**Checkpoint:** Coverage matrix visible, cell click filters list, tab switching works

---

## Phase 3 — Exam Pool Tab

- [ ] **EP-1** `ExamPoolMatrix` section: rows per exercise_type with Tổng / Published / Có audio counts, click → filter
- [ ] **EP-2** Exam list in Tab 2: poolMode='exam', hide module/skill filters, show type filter, "+ Tạo exam exercise" pre-fills pool=exam

**Checkpoint:** Both tabs fully functional

---

## Phase 4 — Polish

- [ ] **PO-1** Loading skeletons (matrix + list), API error banner with retry, empty cell empty state with CTA
- [ ] **PO-2** Form pre-fills moduleId + skillKind from active filter when "+ Tạo exercise" clicked
- [ ] **PO-3** Tổng row sticky bottom (position: sticky)

**Final verification:** `make verify` passes
