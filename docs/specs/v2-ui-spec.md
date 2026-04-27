# V2 UI Spec — A2 Mluveni Sprint

Source: `docs/design/czech-app-2/` handoff bundle (claude.ai/design, 2026-04-27).

---

## 1. Product Objective

**App:** Luyện nói tiếng Czech A2 cho người Việt chuẩn bị thi trvalý pobyt NPI ČR.  
**Core loop:** Course → Module → Skill → Exercise → Record → AI feedback → Retry.  
**Exam loop:** MockTest → 4 Úloha → Score (0–40, pass ≥ 24).

---

## 2. Navigation Architecture

### Bottom Tabs (chỉ 2 tabs)
| Tab | Screens trong stack |
|---|---|
| `home` | CourseList → ModuleList → ModuleDetail → ExerciseList → Exercise → Result |
| `history` | HistoryScreen → Result |

**Tabs ẩn trên:** `exercise`, `analyzing`, `mock-exam`, `mock-intro`

### Full Route Map
```
course-list
  └── module-list
        └── module-detail
              └── exercise-list
                    └── exercise → analyzing → result

mock-list
  └── mock-intro
        └── mock-exam → analyzing-mock → mock-result

history → result (view past attempt)
```

---

## 3. Design Tokens (đã apply — Phase V0)

| Token | Value | Usage |
|---|---|---|
| `--bg` | `#FBF3E7` | App/page background |
| `--brand` | `#FF6A14` | Primary actions, active states |
| `--accent` | `#0F3D3A` | CMS sidebar, dark surfaces |
| `--ink` | `#14110C` | Primary text |
| `--r3` | `18px` | Standard card radius |
| Font body | Inter | All body/label text |
| Font display | Fraunces / Playfair | Headings, scores |

---

## 4. Flutter Screen Spec

### 4.1 — Screens DONE ✅

| Screen | V0/V1 Task | Status |
|---|---|---|
| CourseListScreen | V1.3 | ✅ status badge, progress bar, lock state |
| ModuleDetailScreen | V1.4 | ✅ 2-col skill grid, mock teaser |
| ExerciseListScreen | V1.5 | ✅ filter pills Úloha 1-4 |
| AnalysisScreen | V1.1 | ✅ orbiting ring, 3 animated steps |
| ResultCard | V0.6 | ✅ 3 tabs (Phản hồi / Bản ghi / Bài mẫu) |
| RecordingCard | V0.7 | ✅ `AppColors.rec` recording state |

---

### 4.2 — ResultCard Score Grid (V1.2 — P0 BLOCKER)

**Design:**
```
4-column grid, gap: 6
┌──────────┬──────────┬──────────┬──────────┐
│ Nội dung │ Ngữ pháp │ Từ vựng  │ Phát âm  │
│   22/25  │   18/25  │   20/25  │   16/25  │
└──────────┴──────────┴──────────┴──────────┘
Each cell: padding 10x8, T.surface bg, 1px border, borderRadius T.r2
Score: fontSize 18, fontWeight 600, tabular-nums
```

**Backend:** `CriteriaResults []CriterionCheck` EXISTS trong `FeedbackResponse`
```go
type CriterionCheck struct {
    CriterionKey string `json:"criterion_key"`
    Label        string `json:"label"`
    Met          bool   `json:"met"`
    Comment      string `json:"comment,omitempty"`
}
```

**Flutter gaps:**
- `AttemptFeedbackView` chưa có `criteriaResults` field
- Cần parse `criteria_results` JSON array
- Cần `CriterionCheckView` model class

**AC:**
- [ ] 4-column grid hiển thị dưới readiness badge, trước tabs
- [ ] Grid hidden khi `criteriaResults == null || criteriaResults.isEmpty`
- [ ] Format: label (10px uppercase) + met indicator (checkmark/x) + comment (optional)
- [ ] `flutter analyze` + `flutter test` pass

---

### 4.3 — MockTestListScreen Rich Cards (D2 — P1)

**Design:**
```
Card layout:
  Row 1: Brand pill "MOCK 01" + "MỚI" pill (if new) + Spacer + chevron-right
  Row 2: Title large (18px, 600wt, display font)
  Row 3: Description (13px, ink2)
  Row 4: Metadata icons row:
    - clock icon + "12 phút"
    - cards icon + "4 phần"
    - flag icon + "Đạt 24/40"
```

**AC:**
- [ ] Metadata row với 3 items + icons
- [ ] "MỚI" pill hiện khi mock test mới (có thể dùng tag field từ API)
- [ ] `flutter analyze` pass

---

### 4.4 — MockTestIntroScreen 3-Stat Grid (D3 — P1)

**Design:**
```
3 stat boxes trong Row, equal flex:
  ┌─────────────┬─────────────┬─────────────┐
  │ 12 phút     │    40 điểm  │    24 điểm  │
  │ Thời gian   │  Điểm tối đa│   Điểm đỗ  │
  └─────────────┴─────────────┴─────────────┘
  padding: 14x12, T.surface, border 1px T.border, borderRadius T.r3

Part breakdown list (4 parts):
  ○ 1  Úloha 1 · Giới thiệu bản thân    8đ
  ○ 2  Úloha 2 · Hội thoại thông tin   12đ
  ○ 3  Úloha 3 · Kể chuyện tranh       10đ
  ○ 4  Úloha 4 · Chọn phương án         7đ
  
Circle badge: 32px, T.brandSoft bg, brand text
```

**AC:**
- [ ] 3 stats trong Row (thời gian, max points, pass score)
- [ ] Part list với circle badge + uloha label + name + max score
- [ ] `flutter analyze` pass

---

### 4.5 — HistoryScreen Polish (P2)

**Design:**
```
Attempt card:
  Leading: 36x36 badge
    - Mock attempt: T.brandSoft bg, trophy icon (T.brand)
    - Exercise: gray bg, mic icon (T.ink3)
  Center: title + "Úloha X · {exercise}" + "N ngày trước"
  Trailing: ReadinessBadge pill (color-coded)
```

**AC:**
- [ ] Icon badge phân biệt mock vs exercise attempt
- [ ] Timestamp display
- [ ] Readiness badge color-coded

---

## 5. CMS Page Spec

### 5.1 — Exercise Editor 5-Tab (C2 — P1)

**Layout:**
```
┌────────────────────────────────────────────────────────┐
│ Header: breadcrumb + title + [Lưu nháp] [Publish]     │
├────────────────────────────────────────────────────────┤
│ Sticky tab bar: Prompt | Bài mẫu | Rubric | AI | Meta │
├─────────────────────────────────┬──────────────────────┤
│ Form area (1fr)                 │ Sidebar (300px)      │
│ Tab 0 — Prompt:                 │ Status: Published    │
│   Tiêu đề VN (required)         │ Loại: Úloha 1        │
│   Tiêu đề Séc                   │ Module: Tuần 3       │
│   Ngữ cảnh (textarea)           │ ─────────────────    │
│   4 ý chính (bullet list)       │ [Nhân bản]           │
│                                 │ [Xem trên app]       │
│ Tab 2 — Rubric:                 │ [Lưu nháp]           │
│   4-col grid:                   │ [Publish ▶]          │
│   Phát âm | Trôi chảy           └──────────────────────┘
│   Ngữ pháp | Nội dung
│   Total: 100%
└─────────────────────────────────┘
```

**AC:**
- [ ] 5 tabs switch content đúng
- [ ] Sticky tab bar khi scroll
- [ ] Rubric tab: 4-col grid với % inputs + total validator
- [ ] Right sidebar: status + actions
- [ ] `cms-lint + cms-build` pass

---

### 5.2 — Courses Page Card Grid (C1 — P1)

**Layout:**
```
3-column grid (repeat(3, 1fr), gap: 16px)

CourseCard:
  ┌──────────────────────────┐
  │  Color header (120px)    │  ← course.color bg
  │  🇨🇿 emoji overlay       │
  ├──────────────────────────┤
  │ Title (16px, 600wt)      │
  │ Subtitle (13px, ink3)    │
  ├──────────────────────────┤
  │ 12 modules  84 bài  1.8k │  ← metrics row
  │ [Đang chạy] badge        │
  └──────────────────────────┘
```

**AC:**
- [ ] 3-col grid, responsive (2-col dưới 1024px)
- [ ] Course card có color header, title, subtitle, metrics, badge
- [ ] Nút "Khóa học mới" → link tới /courses/new
- [ ] `cms-lint + cms-build` pass

---

### 5.3 — Dashboard Stats Header (D1 — P2)

**Layout:**
```
4-column stats grid (dùng .stats-grid class đã có):
  ┌──────────┬──────────┬──────────┬──────────┐
  │ 1.842    │ 14.230   │  68%     │ 91.3%    │
  │ Học viên │ Bài/ngày │ Pass rate│ AI agree │
  │ +9.2%  ↑ │ +3.1%  ↑ │ -2.4%  ↓ │ +1.2%  ↑ │
  └──────────┴──────────┴──────────┴──────────┘
```

Stats fetch từ hardcoded values trước (no new API needed), real API khi có learner analytics.

**AC:**
- [ ] 4 stat cards ở đầu trang `/`
- [ ] Delta indicator với màu (green/red)
- [ ] `cms-lint + cms-build` pass

---

### 5.4 — Learners Page (C3 — P2)

**Layout:**
```
Stats grid (4 cols): bài hoàn thành | phút luyện | điểm TB | câu nộp lại

Filter pills: [Tất cả] [READY] [ALMOST] [NEEDS] [NOT]

Table: 1.6fr 0.9fr 0.7fr 1.3fr 0.8fr 0.9fr 0.9fr 30px
Cols: Tên | Thành phố | Gói | Tiến độ% | Streak | Thi | Gần nhất | ⋮

Learner detail (modal/slide):
  Skill bars: Phát âm | Trôi chảy | Ngữ pháp | Nội dung
  Error list: bullet items
  Actions: [Gửi nudge] [Mở app như learner]
```

Data nguồn: `/api/admin/attempts` (existing) aggregated per user.

**AC:**
- [ ] Table với filter pills
- [ ] Stats từ real attempt data
- [ ] `cms-lint + cms-build` pass

---

### 5.5 — Mock Tests Page (C4 — P3)

**Layout:**
```
List table: gridTemplateColumns: '40px 1fr 130px 140px 110px 130px 30px'
Cols: # | Tiêu đề | Trạng thái | Lượt làm | Pass rate | Cập nhật | ⋮

Builder (2-col):
  Left: 4 sections (Úloha 1-4), mỗi section pick exercise
  Right sidebar (380px):
    Settings: pass%, wait time, max attempts
    Checklist: 5 items với ✓/✗ indicators
    History log
```

**AC:**
- [ ] List table với status badges
- [ ] Builder settings sidebar
- [ ] Publish checklist auto-validates
- [ ] `cms-lint + cms-build` pass

---

## 6. Implementation Order

### TIER 1 — Unblocked (1-2 ngày)
1. `B1` Verify backend `criteria_results` in JSON response
2. `B2` Flutter: `CriterionCheckView` model + parse `criteria_results`
3. `V1.2` ResultCard 4-column criteria grid
4. `D2` MockTestListScreen rich cards
5. `D3` MockTestIntroScreen 3-stat grid

### TIER 2 — CMS polish (3-5 ngày)
6. `C2` Exercise Editor 5-tab layout
7. `C1` Courses page card grid
8. `D1` Dashboard stats header

### TIER 3 — New pages (5-7 ngày)
9. `C3` Learners page
10. `C4` Mock Tests builder

### TIER 4 — Polish (1-2 ngày)
11. HistoryScreen visual polish
12. CourseDetailScreen (module timeline vertical line)

---

## 7. Out of Scope (V2)

- Activity chart component (cần third-party charting lib)
- Drag-drop trong CMS courses hierarchy
- Learner enrollment / real progress tracking
- Non-speaking skills UI (nghe/đọc/viết)
- CMS authentication hardening (next security pass)
- Real learner analytics API (dùng hardcoded cho stats trước)
