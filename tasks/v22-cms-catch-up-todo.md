# Todo — V22 CMS Catch-Up

Plan:  `tasks/v22-cms-catch-up-plan.md`
Spec:  `docs/specs/v22-cms-catch-up.md`
Idea:  `docs/ideas/v22-cms-catch-up.md`

Phase order: **A → B → C → D → E → F**. Mỗi phase end bằng checkpoint;
không bắt đầu phase tiếp khi checkpoint chưa pass.

Test count baseline (đầu V22): backend 654, CMS 144 (7 file), Flutter 309.

---

## Phase A — Foundation (~0.5 day)

- [x] **A1** Audit + verify spec § "Current Implementation Snapshot"
  vs code thực tế. Verify: (a) `mock_tests.is_promotion/is_placement/target_level`
  tồn tại; (b) form CMS line 480-521 đang gửi đủ 3 field; (c) endpoint
  `GET /v1/admin/users/:id` shape; (d) liệu `GET /api/admin/mock-tests`
  có hỗ trợ filter `is_promotion` + `status` + `target_level`; (e)
  proxy CMS pattern cho route mới (cần thêm file mới hay không). Ghi
  kết quả vào commit message hoặc comment đầu PR.
- [x] **A2** Test scaffolding — tạo 5 file empty test:
  `backend/internal/httpapi/admin_user_state_test.go`,
  `backend/internal/httpapi/admin_content_health_test.go`,
  `cms/__tests__/learner-xray.test.tsx`,
  `cms/__tests__/mock-test-dashboard.extend.test.tsx`,
  `cms/__tests__/content-health.test.tsx`. Mỗi file 1 `t.Skip("v22 stub")`.

**Checkpoint A**: `make backend-test` + `cd cms && npm test` xanh
(skip +5). Branch `feat/v22-cms-catch-up` tạo. Spec recon confirmed
hoặc updated.

---

## Phase B — Learner X-Ray (~2 days, vertical 1)

- [x] **B1** `backend/internal/store/admin_user_state_store.go` (new)
  — `GetLearnerState(ctx, userID)` dùng `errgroup` 5 query song song.
  Limit promotion_attempts 21 (cho `has_more`), recent_attempts 20.
  Test: `admin_user_state_store_test.go` — 4 cases.
- [x] **B2** `backend/internal/httpapi/admin_user_state.go` (new)
  — handler `GET /v1/admin/users/:id/state`. Wire qua
  `handleAdminUserByID` sub-resource pattern (giống `:id/usage/reset`).
  Test: 4 cases (happy_full / happy_no_mastery / not_found_404 /
  forbidden_non_admin_403). Backend test +4 (654 → 658).
- [x] **B3** `backend/internal/contracts/types.go` extend —
  `LearnerStateResponse` + sub-types khớp § B-API spec shape.
- [x] **B4** `cms/app/users/[userId]/page.tsx` (new) — stub import
  `<LearnerXRay userId={params.userId} />`. Nếu cần proxy thêm
  `cms/app/api/admin/users/[userId]/state/route.ts`.
- [x] **B5** `cms/components/learner-xray.tsx` (new) — state machine
  `loading | error | not-found | ready` + fetch effect + breadcrumb header.
- [x] **B6** Sub-component `<ProfileCard />` + `<CefrCard />` (cùng file
  hoặc tách `learner-xray-cards.tsx`). Grid 2 col. CSS dùng existing
  `--surface`/`--ink`/`--brand` tokens.
- [x] **B7** `<UnlockStateCollapsible />` — default tóm tắt level row,
  toggle "Xem JSON gốc" → `<pre><code>` JSON.stringify pretty.
- [x] **B8** `<MasteryTable />` — sortable cols (skill_kind /
  module_label / score / attempts_count / updated_at). Default sort
  `updated_at desc`. Score render bar viz inline.
- [x] **B9** `<PromotionAttemptsTable />` — cols target_level / score_pct
  / passed / created_at / completed_at. Empty state. `has_more` link.
- [x] **B10** `<RecentAttemptsTable />` — cols exercise_label /
  skill_kind / score / started_at. Limit 20.
- [x] **B11** `<AdminActionsFooter />` — reuse `ConfirmResetUsage` +
  `ResetPassword` từ `users-dashboard.tsx`. Có thể tách helper file
  `cms/components/user-admin-actions.tsx` để share.
- [x] **B12** Sửa `cms/components/users-dashboard.tsx` — wrap email
  cell trong `<Link href={'/users/' + user.id}>` hoặc thêm 1 nút
  "Xem chi tiết". Style giữ kín pattern existing.
- [x] **B13** `cms/__tests__/learner-xray.test.tsx` — 5 cases
  (renders_full_fixture / loading_state / error_state / not_found_state
  / empty_promotion_attempts). CMS test +5 (144 → 149).

**Checkpoint B**: `make backend-test` (+4) + `cd cms && npm test` (+5)
xanh. Manual: login admin → click 1 user trong Users list → mở X-Ray
< 1s, thấy đủ 5 section. Backend 658, CMS 149.

---

## Phase C — Mock test list polish (~0.5 day, vertical 2)

- [x] **C1** `cms/components/mock-test-dashboard.tsx` extend —
  helper `gatingBadge(test)` + render cạnh `statusBadge` +
  `examModeBadge` trong list row. CSS class `.badge-promotion` +
  `.badge-placement` thêm vào `cms/app/globals.css`.
- [x] **C2** Filter dropdown — state `kindFilter: 'all' | 'normal'
  | 'promotion' | 'placement'`. Render `<select>` cạnh nút
  "+ Đề mới" trong header. Filter `tests` array client-side trước
  render.
- [x] **C3** `cms/__tests__/mock-test-dashboard.extend.test.tsx` —
  4 cases (promotion_badge_renders / placement_badge_renders /
  filter_promotion_only_shows_promotion / filter_all_shows_everything).
  CMS test +4 (149 → 153).

**Checkpoint C**: `cd cms && npm test` (+4) xanh. Manual: mở Mock
tests, thấy 2 badge orange/teal, filter dropdown lọc đúng. CMS 153.

---

## Phase D — Promotion uniqueness validate (~0.5 day, vertical 3)

- [→] **D0** _(dropped)_ Nếu A1 phát hiện `GET /api/admin/mock-tests`
  chưa filter `is_promotion`/`status`/`target_level` → thêm filter.
  Phát hiện trong A1: D3 dùng in-memory `tests[]` đã load sẵn → không
  cần fetch riêng → microtask này không cần.
- [x] **D1** `backend/internal/store/postgres_mock_tests.go` extend —
  `FindPublishedPromotionByLevel(ctx, level, excludeID)`. Test:
  3 cases trong `postgres_mock_tests_test.go` (match_one / no_match
  / exclude_self).
- [x] **D2** `backend/internal/httpapi/admin_mock_tests.go` extend —
  thêm validate trong `handleCreate` + `handleUpdate`. Return 409
  với JSON `{error, level, existing_id, existing_title, hint}`.
  Test: 4 cases (promotion_published_conflict_409 /
  promotion_draft_no_check_passes / promotion_unique_self_excluded_passes
  / non_promotion_unaffected). Backend test +4 (658 → 662; +1 từ D1
  store test count vào `662` tổng).
- [x] **D3** `cms/components/mock-test-dashboard.tsx` extend —
  `useEffect` listen `[is_promotion, target_level, status]`. Khi cả
  3 thoả `is_promotion + published + target_level !== ''` → fetch
  `GET /api/admin/mock-tests?is_promotion=true&status=published&target_level=<L>`
  → set `conflictWarning` (loại trừ `editingId`). Debounce 250ms.
- [x] **D4** Render warning box trong form (dưới CEFR gating section)
  + toast on 409 trong `handleSubmit`. Style: bg `#fff8d6`, text
  `#7c4a03`, border-left 4px solid `#facc15`.
- [x] **D5** `cms/__tests__/mock-test-dashboard.extend.test.tsx`
  thêm 4 case (conflict_warning_visible / conflict_warning_hidden_for_draft
  / toast_on_409 / no_warning_when_self_only). CMS test +4 (153 → 157).

**Checkpoint D**: backend test (+4) + cms test (+4) xanh. Manual:
tạo 2 mock tests cùng `target_level=a2 + published` → mock thứ 2
inline warning hiện trước submit + toast 409 sau submit. Backend
662, CMS 157.

---

## Phase E — Content Health Report (~1.5 days, vertical 4)

- [x] **E1** `backend/internal/store/content_health_store.go` (new)
  — `RunContentHealth(ctx)` với 6 check function. Mỗi check limit 51
  (detect truncation). Test: `content_health_store_test.go` —
  6 happy + 6 empty cases (12 cases tổng).
- [x] **E2** `backend/internal/httpapi/admin_content_health.go` (new)
  — handler `GET /v1/admin/content-health`. Wire trong `server.go`.
  Test: 3 cases (happy_with_issues / happy_all_clean /
  forbidden_non_admin). Backend test +9 (662 → 671 cumulative).
- [x] **E3** `cms/app/content-health/page.tsx` (new) — stub
  `<ContentHealth />`. Proxy `cms/app/api/admin/content-health/route.ts`
  nếu cần.
- [x] **E4** `cms/components/content-health.tsx` (new) — state machine
  `initial | running | loaded | error`. 6 card grid 3×2. Card
  component: title, count (đỏ bold nếu >0, ✓ nếu =0), CTA "Xem chi
  tiết" chỉ khi >0.
- [x] **E5** Expand inline `<ExpandedItemsTable />` — bảng items dưới
  grid khi click "Xem chi tiết". `entityLink` map per `entity_type`
  → route. Verify route đích tồn tại (`/exercises/[id]`,
  `/mock-tests/[id]`, `/courses/[id]`, `/modules/[id]`).
- [x] **E6** States polish — initial 6 dash, running skeleton + button
  disabled, loaded với "Lần chạy gần nhất: <ts>", error banner đỏ
  + "Thử lại".
- [x] **E7** `cms/__tests__/content-health.test.tsx` — 5 cases
  (initial_six_dashes / run_check_loading_skeleton / run_check_results_render
  / count_zero_muted_no_cta / click_item_navigates). CMS test +5
  (157 → 162).
- [x] **E8** `cms/components/cms-sidebar.tsx` extend — thêm mục
  `{ href: '/content-health', label: 'Sức khỏe nội dung', icon: '🩺' }`
  giữa "Mock tests" và "Users".

**Checkpoint E**: backend test (+9) + cms test (+5) xanh. Manual:
sidebar có mục mới, click "Chạy kiểm tra" → 6 card load, click "Xem
chi tiết" trên card có count → bảng expand, click item → jump entity.
Backend 671, CMS 162.

---

## Phase F — Polish & ship (~0.5 day)

- [x] **F1** `make verify` xanh. Fix lint nhỏ nếu có.
- [ ] **F2** Manual smoke 3 user flow trên staging (idea § 8):
  Flow B (X-Ray) + Flow C (promotion conflict) + Flow F (health).
  _Defer to user — needs running dev server + browser._
- [x] **F3** `make smoke-attempt-flow` + `make smoke-course-flow` +
  `make smoke-exam-flow` không regress.
- [x] **F4** `CHANGELOG.md` thêm entry V22 với file changes + test
  count delta (backend 654 → 671 = +17, CMS 144 → 162 = +18).
- [x] **F5** `SPEC.md` root thêm 1 dòng digest `| V22 | CMS Catch-Up
  | docs/specs/v22-cms-catch-up.md | <ship date> |`.
- [x] **F6** `tasks/plan.md` + `tasks/todo.md` index thêm dòng pointer
  V22.
- [ ] **F7** `docs/specs/v22-cms-catch-up.md` § Status đổi thành
  "Shipped <date> (commit <hash>)". _Awaiting actual commit; spec
  currently marked "Implemented 2026-05-07 — awaiting commit + manual smoke"._
- [x] **F8** _(skip)_ `docs/reference/` fold — V22 không thay đổi
  contract chung, chỉ thêm 2 admin endpoint nội bộ. Skip.
- [x] **F9** `docs/architecture/current-code-shape.md` thêm 1-2 dòng
  ghi nhận 3 component CMS mới + 2 endpoint admin mới.

**Checkpoint F**: `make verify` xanh. 3 manual smoke pass. CHANGELOG
+ SPEC digest + tasks index + spec status landed. PR merge → main.

---

## Final state targets

- Backend tests: **671** (was 654, +17).
- CMS tests: **162** in **10 files** (was 144 in 7).
- Flutter tests: **309** (no change).
- New files: 3 backend (store + handler × 2 + 1 store helper) +
  6 CMS (3 components + 3 routes + sidebar update).
- Modified files: ~5 (sidebar, users-dashboard, mock-test-dashboard,
  contracts, server.go).
