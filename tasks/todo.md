# Master Todo — Content Architecture V2

## Phase 1 — Exercise pool separation

- [x] **T1.1** — `contracts.Exercise` thêm `Pool string` + migration `007_exercise_pool.sql`
- [x] **T1.2** — Backend `GET /v1/admin/exercises?pool=` filter
- [x] **T1.3** — CMS exercise form: Pool dropdown (course / exam)
- [x] **T1.4** — CMS mock-test-dashboard: `fetchExercises()` → `?pool=exam`

**[CHECKPOINT 1]** backend-build + backend-test + cms-build + flutter-analyze

---

## Phase 2 — Backend hierarchy

- [x] **T2.1** — `CourseStore` + seed 2 courses ("A2 Mluveni Sprint" + "Giao tiếp cơ bản")
- [x] **T2.2** — Module thêm `course_id`+`status` + `ModuleStore` + seed (14 modules → course-a2-mluveni)
- [x] **T2.3** — `Skill` entity + `SkillStore` + seed 1 "Nói" per daily_plan module
- [x] **T2.4** — `Exercise.SkillID` + `ExercisesBySkill` + backward compat
- [x] **T2.5** — Learner APIs: `/v1/courses`, `/v1/courses/:id`, `/v1/courses/:id/modules`, `/v1/modules/:id/skills`, `/v1/skills/:id/exercises`
- [x] **T2.6** — Admin APIs: `/v1/admin/courses`, `/v1/admin/modules`, `/v1/admin/skills` (full CRUD)

**[CHECKPOINT 2]** backend-build + backend-test

---

## Phase 3 — CMS

- [x] **T3.1** — CMS API routes proxy (courses + modules + skills — 6 route files)
- [x] **T3.2** — CMS CourseDashboard + page `/courses`
- [x] **T3.3** — CMS ModuleDashboard + page `/modules` (course dropdown filter)
- [x] **T3.4** — CMS SkillDashboard + page `/skills` (module picker, skill_kind dropdown)
- [x] **T3.5** — CMS exercise form: skill dropdown + module dropdown trong Metadata tab (đã có trong exercise-dashboard.tsx)
- [x] **T3.6** — CMS nav: Exercises | Courses | Modules | Skills | Mock Tests

**[CHECKPOINT 3]** cms-lint + cms-build

---

## Phase 4 — Flutter

- [x] **T4.1** — i18n strings (skill kinds, screen titles) + gen-l10n
- [x] **T4.2** — Models (Course, Skill, updated ModuleSummary) + ApiClient (listCourses, listCourseModules, listModuleSkills, listSkillExercises)
- [x] **T4.3** — `CourseListScreen`
- [x] **T4.4** — `CourseDetailScreen` (module list)
- [x] **T4.5** — `ModuleDetailScreen` (skill cards — Nói tappable, others "Sắp ra mắt")
- [x] **T4.6** — `ExerciseListScreen` per skill (self-contained navigation)
- [x] **T4.7** — Navigation: Home → CourseListScreen. Xoá PlanStrip, modules/plan loading.

**[CHECKPOINT 4]** flutter-analyze + flutter-test
**[CHECKPOINT 5]** Simulator: Course → Module → Skill → Exercise → Record → Result

---

## V2 UI Upgrade — Design System (Babbel theme)

### Phase 0 — Design tokens & theme (DONE)

- [x] **V0.1** — CMS `globals.css`: tokens `--bg #fbf3e7`, `--brand #ff6a14`, `--accent #0f3d3a`, fonts Inter+Fraunces, radius, utility classes
- [x] **V0.2** — CMS `layout.tsx` + `CmsSidebar` component (sidebar 248px, teal bg)
- [x] **V0.3** — Flutter `app_colors.dart`: orange primary, teal secondary, warm cream surface/bg
- [x] **V0.4** — Flutter `app_theme.dart`: Inter (thay Manrope), warm shadows
- [x] **V0.5** — Flutter `app_radius.dart`: 10/14/18/24/32 px
- [x] **V0.6** — Flutter `result_card.dart`: 3 tabs (Phản hồi / Bản ghi / Bài mẫu)
- [x] **V0.7** — Flutter `recording_card.dart`: `AppColors.rec` cho recording state
- [x] **V0.8** — L10n: tab keys + no-content fallback keys

**[CHECKPOINT V0]** flutter-analyze + cms-lint + cms-build ✅

---

### Phase 1 — Flutter UX Polish

- [x] **V1.1** — `analysis_screen.dart`: orbiting-ring + 3 animated steps
- [x] **V1.2** — `result_card.dart`: criteria checklist (met/unmet circle badge) + `models.dart`: CriterionCheckView
- [x] **V1.3** — `course_list_screen.dart`: status badge (published/draft), lock icon, progress bar
- [x] **V1.4** — `module_detail_screen.dart`: 2-column skill grid + mock teaser card
- [x] **V1.5** — `exercise_list_screen.dart`: filter pills (Tất cả | Úloha 1-4), active state

**[CHECKPOINT V1]** flutter-analyze + flutter-test — partial (V1.2 pending)

---

### Phase 2 — CMS Pages v2

- [x] **V2.1** — `cms/components/course-dashboard.tsx`: 3-col card grid, color header (96px), status badge, design-system classes
- [x] **V2.2** — `cms/components/exercise-dashboard.tsx`: 3-tab bar (Đề bài|Bài mẫu|Metadata) + conditional field rendering
- [x] **V2.3** — `cms/app/learners/page.tsx` + `learners-dashboard.tsx` (NEW): stats grid, filter pills (Tất cả/READY/ALMOST/NEEDS/NOT READY), submissions table 5-col + sidebar nav link

**[CHECKPOINT V2]** cms-lint + cms-build ✅ (V2.3 pending)

---

### Phase 3 — Stats + Mock UX

- [x] **V3.1** — CMS `/` dashboard: `DashboardStatsBar` component với 4 stat cards (hardcoded)
- [x] **V3.2** — `mock_test_list_screen.dart`: brand pill "MOCK 01", metadata row (clock/cards/flag), index-based numbering
- [x] **V3.3** — `mock_test_intro_screen.dart`: 3-stat Row boxes (Thời gian/Điểm tối đa/Điểm đỗ) + part list với circle badge (32px brandSoft)

**[CHECKPOINT V3]** flutter-analyze + cms-build

---

### Phase 4 — Backend criteria_results (unblocks V1.2)

- [x] **V4.1** — Backend: `criteria_results` EXISTS trong `task_completion` JSON (verified)
- [x] **V4.2** — Flutter `models.dart`: `CriterionCheckView` class + parse `criteria_results` từ `task_completion`
- [x] **V1.2** — `result_card.dart`: criteria checklist display trong Feedback tab (met/unmet với circle badge)

**[CHECKPOINT V4]** backend-build + backend-test + flutter-analyze + flutter-test

---

### Phase 5 — Polish (sau khi Tier 1-4 done)

- [x] **V5.1** — `history_screen.dart`: circle icon badge (38px), new color tokens, tiêu đề tiếng Việt
- [x] **V5.2** — `course_detail_screen.dart`: all modules tappable (status-based), gradient orange→teal, circle badges primaryContainer
- [x] **V5.3** — CMS `/learners`: view toggle (Lượt nộp / Học viên), per-user readiness bars, expandable detail với attempt history + criteria failure analysis

**[CHECKPOINT V5]** full e2e: flutter-analyze + cms-build + simulator smoke test

---

**Spec:** `docs/specs/v2-ui-spec.md`

---

## i18n Patch

### Slice F — Flutter: fix post-i18n hardcoded strings

> 8 chuỗi hardcoded (6 tiếng Séc) được thêm vào trong UI polish V5.x sau khi i18n slice đóng.

- [x] **F-I1** — Thêm 8 ARB keys vào `app_en.arb` + `app_vi.arb`, chạy `flutter gen-l10n`
  - Keys: `historyLabel`, `historyTitle`, `historySubtitle`, `historyStatTotal`, `historyStatSuccess`, `resultCoachTipLabel`, `resultCriteriaLabel`, `recordingCoachTip`
- [x] **F-I2** — `history_screen.dart`: thay 5 hardcoded strings (2 Czech + 3 Vietnamese) bằng `l.*`
- [x] **F-I3** — `result_card.dart` + `recording_card.dart`: thay 3 hardcoded Czech strings bằng `l.*`

**[CHECKPOINT F]** `make flutter-analyze && make flutter-test` ✅ 11/11 tests pass

---

### Slice C — CMS: chuẩn hoá strings

> CMS strings hiện tại là mixed VI/EN. Approach: constants file, không dùng library.

- [x] **C-I1** — Tạo `cms/lib/strings.ts` với tất cả CMS UI strings chuẩn hoá sang tiếng Việt
- [x] **C-I2** — Migrate 4 CMS components dùng `S`: `exercise-dashboard`, `mock-test-dashboard`, `module-dashboard`, `skill-dashboard`
  - Note: `cms-sidebar` labels already Vietnamese; `course-dashboard`, `learners-dashboard` labels already Vietnamese

**[CHECKPOINT C]** `make cms-lint && make cms-build` ✅
