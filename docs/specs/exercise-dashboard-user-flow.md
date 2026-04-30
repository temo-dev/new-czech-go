# Exercise Dashboard — User Flow

Admin persona: một người duy nhất nhập nội dung Czech A2 cho hệ thống.

---

## Flow Tổng Quan

```
/exercises (page load)
        │
        ▼
  Load parallel:
  - exercises?pool=course&status=published
  - exercises?pool=course&status=draft
  - exercises?pool=exam
  - /modules
  - /courses
        │
        ▼
  ┌─────────────────────────────────┐
  │  Tab: [Khoá học] [Exam Pool]   │
  │                                 │
  │  Default: Tab "Khoá học" active │
  └─────────────────────────────────┘
        │
        ├──────────────────────────────────────────┐
        ▼                                          ▼
  Flow A: Coverage check                  Flow B: Exam Pool
```

---

## Flow A — Khoá Học (tab mặc định)

### A1: Xem coverage tổng thể

```
Admin mở /exercises
        │
        ▼
  Skeleton loading (~300ms)
        │
        ▼
  ┌─────────────────────────────────────────────────────────┐
  │  Coverage Matrix                                        │
  │                                                         │
  │  KHOÁ: "Giao tiếp cơ bản"                              │
  │  Module       │ Nói  │ Nghe │ Viết │ Đọc               │
  │  Chủ đề 1     │ 🟢20 │ 🟡 8 │ 🔴 0 │ 🟡12              │
  │  Chủ đề 2     │ 🟡14 │ 🟢22 │ 🟡 9 │ 🔴 2              │
  │  KHOÁ: "Ôn thi A2"                                      │
  │  Ôn tập nghe  │ 🔴 3 │ 🟢18 │ 🔴 5 │ 🟢21              │
  │  ─────────────────────────────────────────             │
  │  Tổng         │  37  │  48  │  14  │  35               │
  │                                                         │
  │  [+ Tạo exercise]  [Module ▾] [Skill ▾] [Status ▾] [🔍]│
  │                                                         │
  │  ── Exercise list (all, unfiltered) ──────────────────  │
  │  Chủ đề 1 - Nói Úloha 1   │ uloha_1 │ published       │
  │  ...                                                    │
  └─────────────────────────────────────────────────────────┘
        │
        ├── Admin thấy ô đỏ/vàng → đến A2
        ├── Admin muốn tạo mới → đến A3
        └── Admin muốn sửa → đến A4
```

### A2: Drill-down vào gap

```
Admin click ô 🔴 (vd: Chủ đề 1 × Viết, count=0)
        │
        ▼
  State update:
  - moduleFilter = "module-chu-de-1"
  - skillKindFilter = "viet"
  - Ô được highlight (orange border ring)
        │
        ▼
  scroll to #exercise-list (smooth)
        │
        ▼
  ┌─────────────────────────────────────────────────────────┐
  │  Filter bar shows: Module=Chủ đề 1  Skill=Viết  [×]    │
  │                                                         │
  │  ── Exercise list (filtered) ──────────────────────    │
  │  (empty)                                                │
  │  "Chưa có exercise Viết nào trong module này"          │
  │  [+ Tạo exercise Viết cho Chủ đề 1]                    │
  └─────────────────────────────────────────────────────────┘
        │
        ├── Empty state CTA → đến A3 (pre-filled form)
        └── List có items → đến A4 (edit) hoặc tiếp tục xem
```

**Variant: click ô có draft**
```
Admin click ô 🟡 (vd: Chủ đề 1 × Nghe, published=8, draft=3)
        │
        ▼
  Filter active, list shows 11 exercises
        │
        ▼
  Admin thấy 3 items status="draft"
        │
        └── Click exercise → đến A4 (edit + publish)
```

**Variant: click hàng Tổng**
```
Admin click ô Tổng cột Viết (value=14)
        │
        ▼
  State update:
  - moduleFilter = null  ← cleared
  - skillKindFilter = "viet"
        │
        ▼
  List shows ALL viet exercises across all modules
```

**Variant: clear filter**
```
Admin click [×] trên filter bar hoặc click ô đang highlight
        │
        ▼
  moduleFilter = null
  skillKindFilter = null
  highlight cleared
        │
        ▼
  List shows all exercises (unfiltered)
```

### A3: Tạo exercise mới

```
        ┌─────────────────────────────────────────┐
        │  Entry points:                          │
        │  1. [+ Tạo exercise] button (top)       │
        │  2. Empty state CTA (từ A2)             │
        └─────────────────────────────────────────┘
                │                   │
                ▼                   ▼
     (no active filter)    (filter active: module=X, skill=Y)
                │                   │
                ▼                   ▼
        Form opens với       Form opens với
        fields empty         moduleId=X, skillKind=Y
                │                   │
                └─────────┬─────────┘
                          ▼
              ┌───────────────────────┐
              │  Slide-over (80vw)    │
              │                       │
              │  Exercise type: ▾     │
              │  Module: ▾            │
              │  Skill kind: ▾        │
              │  Title: _             │
              │  ... (type fields)    │
              │                       │
              │  [Huỷ]  [Lưu nháp]   │
              │         [Xuất bản]    │
              └───────────────────────┘
                          │
              ┌───────────┼───────────────┐
              ▼           ▼               ▼
          Huỷ        Lưu nháp        Xuất bản
              │           │               │
              ▼           ▼               ▼
        Close form   POST /exercises  POST /exercises
        no change    status=draft     status=published
                          │               │
                          └───────┬───────┘
                                  ▼
                        Reload exercises data
                        Matrix cell count updates
                        Slide-over closes
                        Success toast: "Đã lưu"
```

**Autosave (localStorage, mỗi 10s):**
```
Admin điền form 30s → rời trang vô tình
        │
        ▼
Quay lại /exercises → click [+ Tạo]
        │
        ▼
"Bạn có draft chưa lưu từ lúc 14:32. [Khôi phục] [Bỏ qua]"
```

### A4: Sửa exercise

```
Admin click row trong exercise list
        │
        ▼
GET /exercises/:id
        │
        ▼
Slide-over mở, form pre-filled với dữ liệu exercise
        │
        ▼
Admin sửa → [Lưu] hoặc thay đổi Status
        │
        ▼
PATCH /exercises/:id
        │
        ▼
Slide-over đóng, list row cập nhật
Matrix cell count cập nhật nếu status thay đổi
Success toast: "Đã cập nhật"
```

**Confirm khi có thay đổi chưa lưu:**
```
Admin sửa → click [×] close slide-over
        │
        ▼
"Bạn có thay đổi chưa lưu. [Tiếp tục sửa] [Huỷ bỏ]"
```

### A5: Xoá exercise

```
Admin click [Xoá] trên row
        │
        ▼
Confirm dialog: "Xoá exercise này? Không thể hoàn tác."
        │
        ├── [Huỷ] → không làm gì
        └── [Xoá] → DELETE /exercises/:id
                         │
                         ▼
                  Row biến mất (optimistic)
                  Matrix cell count -1
                  Toast: "Đã xoá"
```

---

## Flow B — Exam Pool (tab thứ hai)

### B1: Xem exam pool

```
Admin click tab [Exam Pool]
        │
        ▼
  ┌─────────────────────────────────────────────────────────┐
  │  Exam Pool — Mini-matrix                               │
  │                                                         │
  │  Exercise type  │ Tổng │ Published │ Có audio          │
  │  uloha_1        │   4  │    4      │  4 (100%)         │
  │  uloha_2        │   3  │    2      │  3 ( 67%)  ← row  │
  │  poslech_1      │   2  │    1      │  1 ( 50%)         │
  │  poslech_2      │   0  │    0      │  0 (  —)  🔴      │
  │  ...                                                    │
  │                                                         │
  │  [+ Tạo exam exercise]                                  │
  │                                                         │
  │  ── Exercise list (pool=exam, unfiltered) ──────────── │
  │  Exam Uloha 1 - Topic A  │ uloha_1 │ published         │
  │  ...                                                    │
  └─────────────────────────────────────────────────────────┘
```

### B2: Filter theo type

```
Admin click row "uloha_2" trong mini-matrix
        │
        ▼
Row highlighted, list filters to exercise_type=uloha_2
        │
        ▼
Admin thấy 3 exercises, 1 còn draft → click để edit
        │
        └── đến A4 (slide-over form)
```

### B3: Tạo exam exercise

```
Admin click [+ Tạo exam exercise]
        │
        ▼
Slide-over mở:
- pool hardcoded = "exam"
- module_id = "" (không chọn)
- Exercise type dropdown: chỉ show exam-compatible types
        │
        └── đến A3 (submit flow)
```

---

## Edge Cases & Error States

### Loading failure

```
API call fails
        │
        ▼
Matrix không render
Error banner: "Không tải được danh sách exercise. [Thử lại]"
```

### Save failure

```
POST/PATCH fails
        │
        ▼
Slide-over vẫn mở (không đóng khi lỗi)
Error message trong form: "Lỗi lưu: [server message]. Thử lại."
[Lưu] button re-enabled
```

### Concurrent edit

```
Admin A và Admin B cùng sửa exercise X
Admin A save trước
Admin B save sau → 409 Conflict (nếu backend có version check)
        │
        ▼
"Exercise này đã được cập nhật bởi người khác. [Reload] [Ghi đè]"
```
*(Hiện tại backend không có version check — chấp nhận last-write-wins)*

---

## Interaction States Summary

| Element | States |
|---------|--------|
| Matrix cell | default / hover (cursor pointer, slight bg) / active (orange ring) / loading (skeleton) |
| Exercise row | default / hover (bg highlight) / selected (bg) |
| Filter bar | no-filter / filter-active (chips với ×) |
| Slide-over | closed / opening (slide-in 300ms) / open / has-changes (× prompts confirm) |
| [+ Tạo] button | default / loading (spinner, disabled) |
| Status badge | draft=grey / published=green / archived=red |

---

## Screen Sizing Notes (CMS = web desktop)

- Matrix: horizontal scroll on viewport < 900px (không collapse columns)
- Slide-over: 80vw, min 480px, max 900px
- Exercise list: full width below matrix, sticky filter bar on scroll
- Tổng row: sticky bottom of matrix viewport (không scroll out)
