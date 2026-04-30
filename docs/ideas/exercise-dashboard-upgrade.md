# Exercise Dashboard Upgrade

## Problem Statement

How might we help admins understand and fill content gaps across 20+ exercise types without drowning in a 2000-line flat list?

## Decisions Locked

| Question | Decision |
|----------|----------|
| pool=exam exercises | Separate "Exam Pool" tab — excluded from main matrix |
| Color target | `published` exercises only (draft shown as sub-label, not colored) |
| Skill kinds in matrix | 4 columns: `noi` / `nghe` / `viet` / `doc` |
| `tu_vung` / `ngu_phap` | Excluded — already managed on /vocabulary and /grammar pages |
| Target per cell | 20 published for all 4 skill kinds |

## Recommended Direction

**Coverage Matrix + Drill-down — 2 tabs**

```
[ Course Matrix ]  [ Exam Pool ]

Module         | nói  | nghe  | viết  | đọc
─────────────────────────────────────────────
Chủ đề 1       |  🟢20 |  🟡 8 |  🔴 0 | 🟡12
Chủ đề 2       |  🟡14 |  🟢22 |  🟡 9 | 🔴 2
─────────────────────────────────────────────
Tổng           |  34  |  30   |   9  |  14

Cell format: published count (draft: N)
Color: 0–5=red, 6–14=yellow, 15–19=light green, ≥20=dark green
```

Click ô → filters exercise list bên dưới (same list + slide-over form — no rewrite).

**Tab "Exam Pool"** = flat list, filter by exercise_type only, no matrix.

**Data fetching strategy:**  
`GET /v1/exercises` with `?status=published` → group by `module_id + skill_kind` client-side for matrix. One call, no N+1 per module. Separate call for draft count (tooltip). If `?status=` filter not on exercises API yet → add 1 query param to backend (trivial).

**File split is prerequisite** (separate PR): `exercise-dashboard.tsx` 2036 lines →
- `exercise-matrix.tsx` — matrix component + cell logic
- `exercise-list.tsx` — table + filter bar
- `exercise-form/index.tsx` — slide-over form shell (form field components already split)
- `exercise-utils.ts` — all parse*/build* helpers (~400 lines of pure functions)
- `exercise-dashboard.tsx` — thin orchestrator, state only (~200 lines)

## Key Assumptions to Validate

- [ ] `GET /v1/exercises` API supports `?status=published` filter (likely yes, easy to add if not)
- [ ] Module count stays < 50 (no virtualization needed); if not, add Course-level row grouping
- [ ] Exam pool exercises always have `module_id = ""` — confirm backend sets this consistently

## MVP Scope

**In:**
- Tab 1 — Course Matrix: Module rows × 4 skill_kind columns, color by published count vs target 20, draft count in cell subtitle, click → filter list
- Tab 2 — Exam Pool: flat list filtered by pool=exam, same slide-over form
- "Tổng" summary row at bottom of matrix
- Filter bar on list: module + skill_kind + status + pool + text search
- File split prerequisite PR

**Out:**
- Editable target per cell (hardcode 20)
- Drag-and-drop reorder
- Bulk publish/archive
- tu_vung / ngu_phap in matrix (use /vocabulary and /grammar pages)

## Not Doing (and Why)

- **Module-first tree navigation** — matrix already gives hierarchy without extra nav steps
- **Kanban status board** — wrong primary use; admin checks coverage, not pipelines
- **AI gap-fill button** — generation quality not yet validated for auto-suggest
- **10x health scoring** — raw counts at this scale are enough

## Open Questions

- Modules grouped by Course in matrix rows (with course header rows), or flat sorted by sequence_no?
- Cell click: replace filter bar values and scroll to list, or open a modal? (Recommend: update filter state + scroll — fewer layers)
- Does "Exam Pool" tab need its own matrix (exercise_type × count), or just a plain list?
