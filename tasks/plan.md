# Master Plan — Content Architecture V2

Source format: Modelový test A2, NPI ČR (platný od dubna 2026).

---

## Kiến trúc

```
Exam (MockTest)  [pool=exam, riêng biệt]
  └── Section (MockTestSection → Exercise)

Course  [pool=course, riêng biệt]
  └── Module  ("Ở bưu điện", "Tuần 1: Gia đình", ...)
       └── Skill  (nói | nghe | đọc | viết | từ vựng | ngữ pháp)
            └── Exercise
```

---

## Exercise types từ A2 PDF (nguồn chuẩn)

### Speaking (noi) — ĐÃ IMPLEMENT
| exercise_type | Mô tả | Max pts thi |
|---|---|---|
| `uloha_1_topic_answers` | 8 câu / 2 chủ đề | 8 |
| `uloha_2_dialogue_questions` | 2 hội thoại, hỏi 4 thông tin | 12 |
| `uloha_3_story_narration` | Kể chuyện 4 tranh, thì quá khứ | 10 |
| `uloha_4_choice_reasoning` | Chọn 1/3 phương án + lý do | 7 |

### Listening (nghe) — chưa implement
| exercise_type | Mô tả | Max pts thi |
|---|---|---|
| `listening_dialogue_picture` | 5 hội thoại → chọn ảnh A-D | 5 |
| `listening_announcement_choice` | 5 bản tin → trắc nghiệm A-D | 5 |
| `listening_monologue_match` | 5 monologue → ghép danh mục A-G | 5 |
| `listening_dialogue_image` | 5 hội thoại → chọn ảnh A-F | 5 |
| `listening_voicemail_fill` | Tin nhắn thoại → điền thông tin | 5 |

### Reading (doc) — chưa implement
| exercise_type | Mô tả | Max pts thi |
|---|---|---|
| `reading_picture_message_match` | 5 tranh → ghép tin A-H | 5 |
| `reading_article_choice` | Đọc bài → trắc nghiệm A-D | 5 |
| `reading_text_person_match` | Ghép đoạn văn với người A-E | 4 |
| `reading_gap_fill_word` | Điền từ vào chỗ trống (chọn A-D) | 6 |
| `reading_text_completion` | Đọc → hoàn chỉnh câu | 5 |

### Writing (viet) — chưa implement
| exercise_type | Mô tả | Max pts thi |
|---|---|---|
| `writing_form_answers` | Điền khảo sát, ≥10 từ/câu | 8 |
| `writing_email_pictures` | Viết email theo 5 tranh, ≥35 từ | 12 |

### Vocabulary + Grammar — course only, không có trong đề thi
| exercise_type | Mô tả |
|---|---|
| `vocabulary_match` | Ghép từ Czech → nghĩa |
| `vocabulary_fill` | Điền từ vào câu |
| `grammar_choice` | Chọn dạng ngữ pháp đúng |
| `grammar_fill` | Điền dạng đúng |

---

## Skill → valid exercise_types mapping

```
noi        → uloha_1, uloha_2, uloha_3, uloha_4
nghe       → listening_*
doc        → reading_*
viet       → writing_*
tu_vung    → vocabulary_*
ngu_phap   → grammar_*
```

---

## Đã xong (session này)
- ✅ Mock exam record-all-then-analyze flow
- ✅ MockTest entity + CMS + scoring 0-40 điểm + PASS/FAIL
- ✅ Section detail tap → full ResultCard
- ✅ Back-to-home fix

---

## Phần chưa làm — chia theo phase

### Phase 1 — Exercise pool separation (prerequisite, làm trước)
Tách exercise pool để CMS exam chỉ thấy pool=exam, course chỉ thấy pool=course.

- T1.1: `contracts.Exercise` thêm `Pool string` (course|exam) + migration `007_exercise_pool.sql`
- T1.2: Backend `GET /v1/admin/exercises?pool=` filter
- T1.3: CMS exercise form: pool dropdown
- T1.4: CMS mock-test-dashboard: fetch `?pool=exam`

**[CHECKPOINT 1]** backend-build + cms-build

---

### Phase 2 — Backend: Course/Module/Skill/Exercise hierarchy

- T2.1: `CourseStore` + Postgres + seed 2 courses: "A2 Mluveni Sprint" + "Giao tiếp cơ bản"
- T2.2: `Module` thêm `course_id`+`status` + `ModuleStore` + Postgres + seed
- T2.3: `Skill` entity + `SkillStore` + Postgres + seed (1 "Nói"/module)
- T2.4: `Exercise` thêm `skill_id` + `ExercisesBySkill` + backward compat
- T2.5: Learner APIs: `GET /v1/courses`, `GET /v1/courses/:id/modules`, `GET /v1/modules/:id/skills`, `GET /v1/skills/:id/exercises`
- T2.6: Admin APIs: `/v1/admin/courses`, `/v1/admin/modules`, `/v1/admin/skills`

**Quan trọng:** `Skill` store validate `exercise_type` thuộc đúng `skill_kind` khi CMS assign exercise vào skill.

**[CHECKPOINT 2]** backend-build + backend-test

---

### Phase 3 — CMS

- T3.1: API routes proxy (courses + modules + skills)
- T3.2: CourseDashboard + page `/courses`
- T3.3: ModuleDashboard + page `/modules` (course_id dropdown)
- T3.4: SkillDashboard per module (skill_kind dropdown, hiện valid exercise_types)
- T3.5: Exercise form: skill dropdown (thay module_id), pool selector
- T3.6: Nav: Courses | Modules | Skills | Exercises | Mock Tests

**[CHECKPOINT 3]** cms-lint + cms-build

---

### Phase 4 — Flutter (Speaking only, others placeholder)

- T4.1: i18n strings (skill kinds + screen titles)
- T4.2: Models (Course, updated Module, Skill, updated ExerciseSummary) + ApiClient
- T4.3: `CourseListScreen`
- T4.4: `CourseDetailScreen` (module list)
- T4.5: `ModuleDetailScreen` (skill cards: "Nói" tappable, others "Sắp ra mắt")
- T4.6: `ExerciseListScreen` per skill
- T4.7: Navigation: Home → CourseListScreen. Bỏ hoàn toàn PlanStrip + 14-day plan UI.

**[CHECKPOINT 4]** flutter-analyze + flutter-test
**[CHECKPOINT 5]** Simulator: Course → Module → Skill "Nói" → Exercises → Record → Result

---

## Scope KHÔNG làm trong slices này

- Listening/Reading/Writing/Vocabulary/Grammar exercise UIs → placeholder only
- Learner enrollment / progress tracking per course
- Plan progression (current_day tự động)
- Multi-language course (chỉ Tiếng Việt)
- Pronunciation scoring nâng cao

---

# V2 UI Upgrade Plan — Babbel Design System

Source: `docs/design/czech-app-2/` — handoff bundle từ claude.ai/design.

## Đã hoàn thành (Phase 0)

- ✅ CMS `globals.css` — design tokens: `--bg #fbf3e7`, `--brand #ff6a14`, `--accent #0f3d3a`, fonts Inter+Fraunces, radius vars, utility classes (`.card`, `.badge`, `.btn`, `.stats-grid`)
- ✅ CMS `layout.tsx` — sidebar layout 248px (thay top navbar), `CmsSidebar` component với teal bg + nav items
- ✅ Flutter `app_colors.dart` — orange primary `#FF6A14`, teal secondary `#0F3D3A`, warm cream surface `#FBF3E7`
- ✅ Flutter `app_theme.dart` — Inter font (thay Manrope), warm shadows
- ✅ Flutter `app_radius.dart` — radius 10/14/18/24/32 theo design tokens
- ✅ Flutter `result_card.dart` — tabs: Phản hồi / Bản ghi / Bài mẫu
- ✅ Flutter `recording_card.dart` — màu `AppColors.rec` (#E2530A) cho recording state
- ✅ L10n — thêm `resultTabFeedback`, `resultTabTranscript`, `resultTabSample`, `resultNoFeedback`, `resultNoTranscript`, `resultNoSample`

## Phase 1 — Flutter UX Polish (pending)

**F1 — AnalysisScreen animated progress**
- File: `flutter_app/lib/features/exercise/screens/analysis_screen.dart`
- Replace spinner với orbiting-ring widget + 3 animated steps (Uploading → Processing → Analysing)
- AC: 3 steps animate đúng state từ API poll

**F2 — ResultCard score dimension grid**
- Files: `flutter_app/lib/features/exercise/widgets/result_card.dart`, `flutter_app/lib/models/models.dart`
- Parse `criteria_results` từ API → 4-column grid: Nội dung | Ngữ pháp | Từ vựng | Phát âm
- AC: grid hiển thị khi có data, hidden khi không có

**F3 — CourseListScreen visual update**
- File: `flutter_app/lib/features/home/screens/course_list_screen.dart`
- Progress bar (height 6, pill), learner count, status badge
- AC: flutter-analyze pass

**F4 — ModuleDetailScreen 2-column skill grid**
- File: `flutter_app/lib/features/home/screens/module_detail_screen.dart`
- GridView 2 cột, mock teaser card dashed border ở cuối
- AC: flutter-analyze pass

**F5 — ExerciseListScreen filter pills**
- File: `flutter_app/lib/features/home/screens/exercise_list_screen.dart`
- Horizontal scroll filter (Tất cả | Úloha 1-4), readiness badge per card
- AC: filter hoạt động đúng

## Phase 2 — CMS Pages v2 (pending)

**C1 — Courses page 3-column card grid**
- File: `cms/app/courses/page.tsx`
- 3-col grid dùng `.stats-grid` style, course color header, metrics row
- AC: cms-lint + cms-build pass

**C2 — Exercise editor 5-tab layout**
- File: `cms/components/exercise-dashboard.tsx`
- Tabs: Prompt | Bài mẫu | Rubric | AI | Metadata; sticky tab bar; right sidebar 300px với preview + actions
- AC: cms-lint + cms-build pass

**C3 — Learners page (new)**
- Files: `cms/app/admin/learners/page.tsx`, `cms/app/api/admin/attempts/route.ts`
- Stats grid + filter pills + submissions table (Ngày | Bài | Trạng thái | Score)
- AC: cms-lint + cms-build pass

## Phase 3 — Stats + Mock UX (pending)

**D1 — CMS dashboard stats header**
- File: `cms/components/exercise-dashboard.tsx`
- 4-column `.stats-grid` trên đầu trang: exercises published, attempts, pass rate, avg score
- AC: build pass

**D2 — MockTestListScreen rich cards**
- File: `flutter_app/lib/features/mock_exam/screens/mock_test_list_screen.dart`
- Metadata row: duration + "4 phần" + "Đạt 24/40", "MỚI" pill
- AC: analyze pass

**D3 — MockTestIntroScreen 3-stat grid + part breakdown**
- File: `flutter_app/lib/features/mock_exam/screens/mock_test_intro_screen.dart`
- 3-stat grid (Thời gian | Điểm tối đa | Điểm đỗ), part list với circle badge
- AC: analyze pass

## Phase 4 — Backend criteria_results (pending)

**B1 — Expose criteria_results in API**
- Files: `backend/internal/contracts/types.go`, `backend/internal/httpapi/server.go`
- Verify/add `CriteriaResults map[string]float64` trong feedback response JSON
- AC: backend-build + backend-test pass

**B2 — Flutter parse criteria_results**
- Files: `flutter_app/lib/models/models.dart`
- Parse map → wire vào F2 score grid
- AC: flutter-analyze pass, grid hiện với real data

## Verification

- Phase 1: `flutter analyze && flutter test`
- Phase 2: `npm run lint && npm run build` trong `cms/`
- Phase 3: simulator end-to-end
- Phase 4: `make backend-test`, curl check `criteria_results` trong response

## Out of scope v2

- Listening/Reading/Writing exercise UIs
- Activity chart (cần charting lib)
- Dashboard pipeline sidebar (cần learner analytics API)
- Mock exam settings CRUD

---

# i18n Patch Plan

## Bối cảnh

Flutter i18n Slice 1+2 đã ship (2026-04-25). Tuy nhiên, UI polish V5.x (history_screen redesign, result_card criteria checklist, recording_card coach tip) thêm vào 8 chuỗi hardcoded — trong đó **6 chuỗi tiếng Séc** — sau khi i18n slice đóng. CMS chưa có i18n; chuỗi UI phân tán giữa tiếng Việt và tiếng Anh.

## Assumptions

1. CMS là tool nội bộ (admin là người Việt) → không cần locale switching, chỉ cần chuẩn hoá sang tiếng Việt qua constants file.
2. Flutter ARB parity đang tốt (EN = VI = 167 keys, diff = 0); chỉ cần thêm 8 keys mới.
3. Chuỗi `'• '` trong feedback_card là typographic separator — không dịch, giữ nguyên.
4. `locale_selector.dart` không dùng AppLocalizations — đúng (tự tham chiếu, hardcode language names là đúng).

## Dependency graph

```
F-I1 (ARB keys) → F-I2 (history_screen) 
F-I1 (ARB keys) → F-I3 (result_card + recording_card)
F-I1, F-I2, F-I3 → [CHECKPOINT F]

C-I1 (strings.ts) → C-I2 (migrate components)
C-I2 → [CHECKPOINT C]
```

---

## Slice F — Flutter: fix post-i18n hardcoded strings

### F-I1: Thêm 8 ARB keys (en + vi)

**Files:** `flutter_app/lib/l10n/app_en.arb`, `flutter_app/lib/l10n/app_vi.arb`

**Keys cần thêm:**

| Key | EN | VI |
|---|---|---|
| `historyLabel` | `HISTORY` | `LỊCH SỬ` |
| `historyTitle` | `Practice History` | `Lịch sử luyện tập` |
| `historySubtitle` | `Track your progress and submission results.` | `Theo dõi tiến độ và kết quả các bài đã nộp.` |
| `historyStatTotal` | `Total attempts` | `Tổng số bài` |
| `historyStatSuccess` | `Success rate` | `Tỷ lệ thành công` |
| `resultCoachTipLabel` | `COACH TIP` | `NHẬN XÉT HUẤN LUYỆN VIÊN` |
| `resultCriteriaLabel` | `EVALUATION CRITERIA` | `TIÊU CHÍ ĐÁNH GIÁ` |
| `recordingCoachTip` | `Coach tip` | `Nhận xét huấn luyện viên` |

Run `flutter gen-l10n` sau khi thêm.

**AC:**
- [ ] Cả 2 ARB files có đủ 8 keys mới
- [ ] EN + VI key sets vẫn bằng nhau (diff = 0)
- [ ] `flutter gen-l10n` thành công

### F-I2: Migrate history_screen.dart

**File:** `flutter_app/lib/features/history/screens/history_screen.dart`

Thay 5 hardcoded strings:
- `'LỊCH SỬ'` → `l.historyLabel`
- `'Lịch sử luyện tập'` → `l.historyTitle`
- `'Theo dõi tiến độ và kết quả các bài đã nộp.'` → `l.historySubtitle`
- `'Celkem lekcí'` → `l.historyStatTotal`
- `'Průměrná úspěšnost'` → `l.historyStatSuccess`

**AC:**
- [ ] Không còn chuỗi Czech/Vietnamese hardcoded trong file
- [ ] Widget dùng `l = AppLocalizations.of(context)` ở đầu build

### F-I3: Migrate result_card.dart + recording_card.dart

**Files:**
- `flutter_app/lib/features/exercise/widgets/result_card.dart`
- `flutter_app/lib/features/exercise/widgets/recording_card.dart`

Thay 3 hardcoded strings:
- `result_card.dart`: `'TIP OD KOUČE'` → `l.resultCoachTipLabel`
- `result_card.dart`: `'TIÊU CHÍ ĐÁNH GIÁ'` → `l.resultCriteriaLabel`
- `recording_card.dart`: `'Tip od kouče'` → `l.recordingCoachTip`

**AC:**
- [ ] Không còn chuỗi Czech hardcoded trong 2 file
- [ ] `recording_card.dart` nhận `BuildContext` để gọi `AppLocalizations.of(context)` (check xem widget đã có context chưa)

### [CHECKPOINT F]

```
make flutter-analyze && make flutter-test
```

Chuyển tiếp device sang EN → kiểm tra history + result + recording hiển thị đúng tiếng Anh.

---

## Slice C — CMS: chuẩn hoá strings

### C-I1: Tạo cms/lib/strings.ts

**File:** `cms/lib/strings.ts` (mới)

Constants file tập trung tất cả CMS UI strings, chuẩn hoá sang tiếng Việt. Không dùng library.

**Nội dung cần cover:**
- Nav labels (sidebar): Bài tập, Khóa học, Mock Test, Học viên, Module, Kỹ năng
- Button labels: Tạo mới, Lưu, Xoá, Chỉnh sửa, Huỷ
- Status labels: Bản nháp, Đã xuất bản
- Form tabs (exercise-dashboard): Đề bài, Bài mẫu, Siêu dữ liệu
- Mock test UI: Thêm bài thi mới, Chỉnh sửa bài thi, Thêm phần thi
- Stats labels (dashboard-stats): đã là tiếng Việt, giữ nguyên hoặc nhất quán hoá
- Error messages tiếng Anh → tiếng Việt

**AC:**
- [ ] File export `CMS_STRINGS` const object với đủ keys
- [ ] TypeScript type-safe (no `any`)
- [ ] `cms-lint` pass

### C-I2: Migrate CMS components

**Files:**
- `cms/components/cms-sidebar.tsx` — NAV labels từ constants
- `cms/components/exercise-dashboard.tsx` — tab labels, button labels
- `cms/components/mock-test-dashboard.tsx` — button labels, status options
- `cms/components/learners-dashboard.tsx` — button/filter labels
- `cms/components/module-dashboard.tsx` — button labels
- `cms/components/skill-dashboard.tsx` — button labels
- `cms/components/course-dashboard.tsx` — button labels

Import `CMS_STRINGS` và thay literal strings. Sidebar NAV array: thay inline labels → `CMS_STRINGS.nav.*`.

**AC:**
- [ ] Không còn English button labels ('Edit', 'Delete', 'New mock test') trong JSX
- [ ] Tất cả components import từ `cms/lib/strings.ts`
- [ ] `cms-lint` + `cms-build` pass

### [CHECKPOINT C]

```
make cms-lint && make cms-build
```

Spot check: mở `/`, `/mock-tests`, `/exercises` → kiểm tra labels tiếng Việt nhất quán.
