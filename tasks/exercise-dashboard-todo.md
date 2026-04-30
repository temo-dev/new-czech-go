# Exercise Dashboard Upgrade — Todo ✅ HOÀN THÀNH

Spec: `docs/specs/exercise-dashboard-upgrade.md`
Plan: `tasks/exercise-dashboard-plan.md`
User flow: `docs/specs/exercise-dashboard-user-flow.md`

Commits: b93c85d → 412ff4e → cddcd54 → be77afd → 1fbf2c5 → 3bb44a6

---

## Phase 1 — File Split (PR-1) ✅

- [x] **FS-1** Extract all parse*/build*/style helpers → `cms/components/exercise-utils.ts`
- [x] **FS-2** Extract table + filter bar → `cms/components/exercise-list.tsx` (props: items, filters, callbacks)
- [x] **FS-3** Extract slide-over form → `cms/components/exercise-form/index.tsx` (props: open, initialForm, onSave, onClose)
- [x] **FS-4** Slim `exercise-dashboard.tsx` to orchestrator ≤ 250 lines (211 lines final)

**Checkpoint:** `make cms-build` + `make cms-lint` + `make smoke-course-flow` all pass ✅

---

## Phase 2 — Coverage Matrix (PR-2) ✅

- [x] **CM-1** `ExerciseMatrix` component: `buildMatrix()` helper + grid render (course headers, module rows, Tổng row, color coding)
- [x] **CM-2** Wire cell click → `onCellClick(moduleId, skillKind)` → update filter state + scrollIntoView + orange ring on active cell
- [x] **CM-3** Tab bar in dashboard: `[Khoá học] [Exam Pool]` — Tab 1 shows matrix + list, Tab 2 placeholder

**Checkpoint:** Coverage matrix visible, cell click filters list, tab switching works ✅

---

## Phase 3 — Exam Pool Tab ✅

- [x] **EP-1** `ExamPoolMatrix` section: rows per exercise_type with Tổng / Published / Có ảnh counts, click → filter
- [x] **EP-2** Exam list in Tab 2: poolMode='exam', hide module/skill filters, show type filter, "+ Tạo exam exercise" pre-fills pool=exam

**Checkpoint:** Both tabs fully functional ✅

---

## Phase 4 — Polish ✅

- [x] **PO-1** Loading skeletons (matrix + list), API error banner with retry, empty cell empty state with CTA
- [x] **PO-2** Form pre-fills moduleId + skillKind from active filter when "+ Tạo exercise" clicked; wizard advances to step 2
- [x] **PO-3** Tổng row sticky bottom (position: sticky)

**Final verification:** `npm test` (49 tests pass) + `make cms-build` + `make cms-lint` ✅

---

## Post-review Bug Fixes ✅

- [x] Form reset on asset upload — use `editingItem?.id` not `editingItem` object in useEffect deps
- [x] "Có audio" misleading — renamed to "Có ảnh", counts uploaded image assets
- [x] `buildMatrix` sort O(M²logM) → O(MlogM) with pre-computed moduleSeqMap
- [x] `MatrixSkeleton` inside component → moved to module level (prevents animation reset)
- [x] Double `localStorage.removeItem` in save path — removed redundant call
- [x] `hasAudio` counted image assets as audio — fixed
