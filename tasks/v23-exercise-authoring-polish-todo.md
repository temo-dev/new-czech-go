# Todo — V23 Exercise Authoring Polish

Plan:  `tasks/v23-exercise-authoring-polish-plan.md`
Spec:  `docs/specs/v23-exercise-authoring-polish.md`
Idea:  `docs/ideas/v23-exercise-authoring-polish.md`

Phase order: **A → B → H → C → F**. Mỗi phase end bằng checkpoint;
không bắt đầu phase tiếp khi checkpoint chưa pass.

Test count baseline (đầu V23, sau V22 ship): backend 683, CMS 190
(10 file), Flutter 345.

---

## Phase A — Foundation (~0.5 day)

- [x] **A1** Audit verify spec § "Current Implementation Snapshot":
  (a) `POST /v1/admin/exercises/:id/generate-audio` response shape
  (sync? status code?), (b) `GET /v1/admin/exercises/:id` detail
  shape, (c) `cms/app/page.tsx` dùng `ExerciseDashboard` inline form
  pattern (no separate edit route), (d) prompt JSON shape của 5
  supported preview type (uloha_1-4 + psani_2_email). Ghi kết quả vào
  PR comment hoặc commit message đầu.
- [x] **A2** Test scaffolding — tạo 5 stub file:
  `backend/internal/httpapi/admin_exercises_test.go`,
  `cms/__tests__/exercise-clone.test.ts`,
  `cms/__tests__/validation-badges.test.ts`,
  `cms/__tests__/exercise-quick-fix.test.ts`,
  `cms/__tests__/preview-routing.test.ts`. Mỗi file 1 `it.skip("v23 stub")`.

**Checkpoint A**: `make backend-test` + `cd cms && npm test` xanh
(skip +5). Branch `feat/v23-exercise-authoring-polish` tạo. Spec
recon confirmed hoặc updated.

---

## Phase B — Quick-Clone (~1.5 day, vertical 1, CMS-only)

- [x] **B1** `cms/components/exercise-utils.ts` extend —
  `cloneExercisePayload(src: Exercise): CreatePayload` helper. Title
  prefix "Copy of ", status='draft', preserve module/skill/type/prompt/
  assets/sample, strip id + audio. Test: 6 cases (title prefix /
  status draft / preserved fields / stripped id / missing optional /
  share assets). CMS test +6 (190 → 196).
- [x] **B2** `cms/components/exercise-list.tsx` extend — thêm row
  button "Sao chép" cạnh [Sửa] [Xóa]. State `cloningId`. Click
  handler async fetch source + POST clone. Loading state disable
  button. Error → toast retry.
- [x] **B3** Toast on success với click-to-edit. Click → set
  `editingId = created.id` + `showForm = true` trong parent
  ExerciseDashboard. Reuse existing toast pattern hoặc inline simple.

**Checkpoint B**: CMS test +6 xanh. Manual smoke clone flow:
clone Úloha 1 → toast hiện < 1s → click toast → form edit row mới
mở. Backend 683, CMS 196.

---

## Phase H — Validation Inline (~2 day, vertical 2, BE+CMS)

- [x] **H1** `backend/internal/httpapi/admin_content_health.go` extend
  — `computeValidationFlags(repo, ex) ValidationFlags` helper. 5 rule
  per spec § H-API. Refactor V22 aggregate functions để gọi helper
  này (DRY). Test: 10 cases (5 rule × 2 positive/negative). Backend
  test +10 (683 → 693).
- [x] **H2** `backend/internal/httpapi/server.go` extend
  `handleAdminExercises` GET case — wrap mỗi item trong
  `ExerciseWithFlags` struct kèm flags. Test:
  `admin_exercises_test.go` (replace stub) — 3 cases
  (happy_with_flags / forbidden_non_admin / pool_filter_still_works).
  Backend test +3 (693 → 696).
- [x] **H3** `cms/components/validation-badges.ts` (new) —
  `flagsToBadges(flags) BadgeSpec[]` + `hasAnyIssue(flags) bool`.
  Test: `validation-badges.test.ts` (replace stub) — 10 cases
  (5 individual / all-clean / multiple combo / undefined / hasAnyIssue
  3 cases). CMS test +10 (196 → 206).
- [x] **H4** `cms/components/exercise-list.tsx` extend — thêm column
  "Tình trạng" trước "Tên". Render `<BadgeCluster flags={item.validation_flags} />`.
  Hover badge → tooltip. Type extend với `validation_flags?: ValidationFlags`.
- [x] **H5** `exercise-list.tsx` extend — checkbox "Chỉ hiện vấn đề"
  cạnh filter dropdowns. State `problemOnly`. Filter logic
  `problemOnly && !hasAnyIssue(item.validation_flags)` skip.
- [x] **H6** `cms/components/exercise-quick-fix-modal.tsx` (new) —
  modal frame reuse `ConfirmResetUsage` style. State machine: idle /
  submitting_status / submitting_audio / error / done. Render badge
  list readonly + radio Draft/Published + button "Tạo lại audio"
  (enable rule per spec § H-2). Test:
  `exercise-quick-fix.test.ts` (replace stub) — 4 cases (audio button
  enable / status submit / audio retry / close handler). CMS test +4
  (206 → 210).
- [x] **H7** `exercise-list.tsx` extend — click row (not row buttons)
  → open quick-fix modal. Click [Sửa]/[Xóa]/[Sao chép] →
  `e.stopPropagation()`.
- [x] **H8** `exercise-quick-fix-modal.tsx` — submit handlers:
  `handleStatusSubmit` → PATCH `/api/admin/exercises/:id` với
  `{status}`; `handleAudioRegen` → POST
  `/api/admin/exercises/:id/generate-audio`.
- [x] **H9** `exercise-list.tsx` extend — modal `onClose` callback
  trigger `refetchExercises()` để badges cập nhật.

**Checkpoint H**: backend test +13 (10 H1 + 3 H2) xanh. CMS test
+14 (10 H3 + 4 H6) xanh. Manual smoke: orphan exercise → badge ❌
→ click row → modal hiện flag list → publish + audio regen → reload
→ badges cập nhật. Backend 696, CMS 210.

---

## Phase C — Inline Preview (~1.5-2 day, vertical 3, CMS-only)

- [x] **C1** `cms/components/exercise-edit-layout.tsx` (new) —
  wrap form. Hook `useMediaQuery('(min-width: 1280px)')` (~10 LOC
  helper). Width ≥ 1280 → grid 60/40 form + preview. Width < 1280 →
  form full + button "Xem preview" + drawer overlay slide-in.
- [x] **C2** `cms/components/exercise-preview/index.tsx` (new) —
  `<PreviewPane form>`. Bg `var(--preview-bg)` (new token, add to
  globals.css). `<DisclaimerBand>` always visible (text "🔍 Preview
  low-fidelity. Hãy test trên Flutter trước khi ship."). Container
  `aria-hidden="true"`.
- [x] **C3** `cms/components/exercise-preview/use-debounced-form.ts`
  (new) — `useDebouncedForm<T>(form, 200): T` hook. Wire trong
  PreviewPane: `const debouncedForm = useDebouncedForm(form);` để
  preview rerender debounced.
- [x] **C4** `cms/components/exercise-preview/uloha-preview.tsx`
  (new) — render mock card cho `uloha_1_topic_answers`,
  `uloha_2_dialogue_questions`, `uloha_3_story_narration`,
  `uloha_4_choice_reasoning`. Variant prop. Title bar + topic/dialogue/
  story + question list + duration + disabled record button. ~150 LOC.
- [x] **C5** `cms/components/exercise-preview/psani-email-preview.tsx`
  (new) — render mock email card cho `psani_2_email`. Subject/from/to
  + body + disabled textarea. ~120 LOC.
- [x] **C6** `cms/components/exercise-preview/placeholder.tsx` (new) —
  fallback cho 11 type không hỗ trợ V23. Hiện list top 5 + lời mời
  test trên Flutter.
- [x] **C7** `cms/components/exercise-preview/router.ts` (new) —
  pure helper `selectPreviewRenderer(type) → ComponentName | 'placeholder'`.
  Test: `preview-routing.test.ts` (replace stub) — 6 cases (5
  supported + 1 placeholder). CMS test +6 (210 → 216).
- [→] **C8** _(deferred V24)_ Wire `<ExerciseEditLayout>` vào
  ExerciseSlideOver. V23 ship preview pane + layout standalone
  (built + tested). Live-wire vào slide-over đụng form monolith
  refactor — vi phạm boundary V23 "no form refactor". V24
  form-refactor slice plug-in.

**Checkpoint C**: CMS test +6 xanh. Manual smoke: open form (1440px)
→ split layout → switch type top 5 → preview render < 200ms.
Resize 1100px → "Xem preview" button → drawer overlay. 11 type
khác → placeholder. Backend 696, CMS 216.

---

## Phase F — Polish & Ship (~0.5 day)

- [x] **F1** `make verify` xanh. Fix lint nhỏ nếu có.
- [ ] **F2** Manual smoke 3 user flow trên staging (idea § 7):
  Flow B (clone) + Flow H (badge + fix modal) + Flow C (preview
  layout + drawer). _Defer to user — needs running dev server +
  browser._
- [x] **F3** `make smoke-attempt-flow` + `make smoke-course-flow`
  không regress. (`make smoke-exam-flow` pre-existing 401 — không
  cần fix V23.)
- [x] **F4** `CHANGELOG.md` thêm entry V23 đầu file: 3 task
  description + decisions + file changes + test count delta
  (backend 683 → 696 = +13, CMS 190 → 216 = +26).
- [x] **F5** `SPEC.md` root thêm 1 dòng digest:
  `| V23 | <date> | Exercise authoring polish — clone + validation
  badges + inline preview MVP | docs/specs/v23-exercise-authoring-polish.md |`.
- [x] **F6** `tasks/plan.md` + `tasks/todo.md` index update status
  V23 → "✅ implemented (awaiting commit + manual smoke)".
- [ ] **F7** `docs/specs/v23-exercise-authoring-polish.md` § Status
  → "Shipped <date> (commit <hash>)" — _Awaiting actual commit;
  spec currently marks "Implemented 2026-05-08 — awaiting commit
  + manual smoke + C8 V24 follow-up"._
- [x] **F8** `docs/architecture/current-code-shape.md` thêm 1-2 đoạn
  ghi nhận V23 additions (validation_flags pattern,
  exercise-preview pane convention, clone helper).

**Checkpoint F**: `make verify` xanh. 3 manual smoke pass.
CHANGELOG + SPEC digest + tasks index + spec status + architecture
doc landed. PR merge → main.

---

## Final state targets

- Backend tests: **696** (was 683, +13).
- CMS tests: **216** in **14 files** (was 190 in 10).
- Flutter tests: **345** (no change — V23 không đụng Flutter).
- New files: 1 backend (admin_exercises_test.go) + 9 CMS
  (validation-badges.ts, exercise-quick-fix-modal.tsx,
  exercise-edit-layout.tsx, exercise-preview/{index,use-debounced-form,
  uloha-preview,psani-email-preview,placeholder,router}.tsx).
- Modified files: ~8 (server.go, admin_content_health.go,
  exercise-list.tsx, exercise-dashboard.tsx, exercise-utils.ts,
  globals.css, exercise-utils types, etc.).
