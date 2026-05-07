# Spec: V22 CMS Catch-Up

## Status
**Implemented 2026-05-07** — code landed + post-review fixes (I-1,
S-3, S-6) applied. `make verify` green (backend 683, CMS 190, Flutter
345). Awaiting commit + manual browser smoke before final ship. Pair
files:

- Idea (pre-spec one-pager): `docs/ideas/v22-cms-catch-up.md`
- Plan: `tasks/v22-cms-catch-up-plan.md`
- Todo: `tasks/v22-cms-catch-up-todo.md`

This spec **freezes on V22-CMS ship**. Future changes (V23+) land in
that slice's spec + relevant `docs/reference/` updates, not here.

## Purpose

Đóng khoảng cách giữa CMS và learner-facing app sau V19 (mastery
aggregate) → V20 (Flutter UI) → V21 (CEFR/promotion) → V21.2 (admin
escape hatch). Đến đầu V22, CMS:

- Không có công cụ debug stuck learner — solo admin phải SQL trực tiếp.
- Mock-test list không phân biệt được promotion exam vs placement vs
  thường (form đã có field, list chưa có badge/filter).
- Không có công cụ phòng ngừa content rot.

V22-CMS giải quyết 3 gap đó trong 1 slice ~5-6 ngày, 3 task theo thứ
tự **B → C → F** (xem § 6). Strict **read-only V22**: chỉ Reset
usage + Reset password (đã có sẵn). Mọi force-action defer V23+.

Đây **không phải**:
- Một CMS rebuild.
- Một dashboard analytics tổng quát.
- Một cron-driven content health system.
- Một bộ admin tools đầy đủ (force unlock, edit mastery, …).

## Current Implementation Snapshot

Recon 2026-05-07. Mục đích: ghim lại state đã có để spec mô tả
đúng delta.

### Backend đã có

| Asset | File | Ghi chú |
|---|---|---|
| `users.current_level`, `placement_taken_at` | V21 migration | có |
| `user_levels` (unlock_state) | `store/user_levels_store.go` | có |
| `promotion_attempts` table | `store/promotion_attempts_store.go` | có |
| `user_skill_mastery` | `store/skill_mastery_store.go` | có (V19) |
| `daily_usage` | V21.2 | có |
| `mock_tests.is_promotion`, `is_placement`, `target_level` | `store/postgres_mock_tests.go` | có (V21) |
| Constraint `mock_tests_promotion_target_required` | DB | có |
| Constraint `mock_tests_promotion_placement_mutex` | DB | có |
| `GET /v1/admin/users` | `httpapi/admin_users.go` | có (kèm `attempts_today`/`attempts_cap`) |
| `GET/DELETE /v1/admin/users/:id` | same | có |
| `POST /v1/admin/users/:id/reset-password` | same | có |
| `POST /v1/admin/users/:id/usage/reset` | same | có (V21.2) |
| Cron infra tổng quát | — | **không** có (chỉ ticker cục bộ trong `transcriber_amazon.go`). |

### Backend còn thiếu (V22 phải build)

- `GET /v1/admin/users/:id/state` — dump tổng hợp X-Ray.
- `GET /v1/admin/content-health` — 6 check rule.
- App-layer validate "1 promotion published per `target_level`" trong
  `PATCH/POST /v1/admin/mock-tests` (DB constraint hiện chỉ enforce
  target_level required + placement-promotion mutex; không enforce
  uniqueness).

### CMS đã có

| Asset | File | Ghi chú |
|---|---|---|
| Users list (kèm "Hôm nay" col) | `cms/components/users-dashboard.tsx` | V21.2 |
| Reset usage / Reset password modals | same | V21.2 |
| Mock test form fields `is_promotion`, `is_placement`, `target_level` | `cms/components/mock-test-dashboard.tsx` line 480-521 | **ĐÃ CÓ section "CEFR gating (V21)"** với checkbox + select + helper. Mutual exclusion via `togglePromotion`/`togglePlacement`. |
| Mock test list status badge + exam_mode badge | same line 305-320 | có |
| Sidebar | `cms/components/cms-sidebar.tsx` | có (chưa có "Sức khỏe nội dung") |
| Custom CSS tokens (`--bg`, `--brand` orange, `--accent` teal) | `cms/app/globals.css` | có (Babbel orange + Deep teal) |

### CMS còn thiếu (V22 phải build)

- Route `/users/[userId]/page.tsx` + component `learner-xray.tsx`.
- Mock test list **promotion/placement badge** + **filter "Loại"** +
  **inline warning** khi conflict promotion-published-per-level.
- Route `/content-health/page.tsx` + component `content-health.tsx`.
- Sidebar mục mới "Sức khỏe nội dung".

### Hệ quả cho scope

| Task | Đã có | V22 cần build |
|---|---|---|
| **B Learner X-Ray** | 0% | full: 1 route + 1 component + 1 backend endpoint |
| **C Promotion authoring** | ~30-40% (form đã xong) | badge list + filter list + app-layer validate (backend + UI inline warning) |
| **F Content Health** | 0% | full: sidebar + route + component + backend endpoint + 6 check rule |

## Out of Scope (V22)

| Bỏ ra | Lý do | Khi quay lại |
|---|---|---|
| Force-unlock level action | Đợi xem dữ liệu X-Ray đủ chưa | V23+ |
| Edit mastery score thủ công | Easy abuse, kỷ luật read-only | V23+ hoặc never |
| Cron schedule cho health report | On-demand đủ cho solo admin V22 | Khi có team content authoring |
| Click-to-fix trong report | V22 chỉ jump tới entity | V23 |
| AI Triage (variation H trong idea) | Bonus, cần X-Ray data làm input | V23 |
| Generic schema-driven CMS (variation D) | Generic UI xấu, không tinh chỉnh được | Never |
| Slice-CMS process change (variation E) | Defer adopt từ V23 nếu V22 ROI rõ | V23 |
| A0/A1 promotion content seed | Chỉ A2/B1 active V22 | V23+ |
| Pagination promotion attempts > 20 | V22 limit 20 default | Khi 1 user có >20 |
| Force-publish/unpublish promotion exam khi conflict | UI chỉ cảnh báo + chặn submit | V23 |
| Health rule thứ 7+ | 6 cố định V22 | Issue + slice mới |

## Schema

**Không thêm/sửa cột.** V22-CMS thuần đọc + 1 endpoint validate phụ
trong handler hiện có.

Cột được đọc trực tiếp:
- `users(current_level, placement_taken_at, ... )`
- `user_levels(user_id, unlock_state, promotion_unlocked, ...)`
- `user_skill_mastery(user_id, skill_kind, module_id, mastery_score, attempts_count, updated_at)`
- `promotion_attempts(id, user_id, target_level, score_pct, passed, created_at, completed_at)`
- `daily_usage(user_id, day, attempts_count)`
- `attempts(id, user_id, exercise_id, ... ) JOIN exercises(id, title, skill_kind, …)`
- `mock_tests(id, title, status, is_promotion, is_placement, target_level, exam_mode, …)`
- `exercises(id, pool, module_id, skill_kind, title, …)`
- `exercise_audio(exercise_id, …)`, `exercise_sentence_audio(exercise_id, …)`
- `mock_test_sections(mock_test_id, …)`
- `modules(id, course_id, title, …)`, `courses(id, title, …)`

## Backend Changes

### B-API. `GET /v1/admin/users/:id/state`

Gate: `withRole("admin")`. Path: `/v1/admin/users/{id}/state`.

Response shape (200):

```json
{
  "user": {
    "id": "u_...",
    "email": "tuananh.ngta@gmail.com",
    "display_name": "Anh Nguyễn",
    "role": "user",
    "pro_tier": "free",
    "grace_attempts_left": 3,
    "current_level": "a2",
    "placement_taken_at": "2026-04-15T10:23:00Z",
    "created_at": "2026-02-03T...",
    "updated_at": "..."
  },
  "daily_usage": {
    "day": "2026-05-07",
    "attempts_count": 12,
    "attempts_cap": 30
  },
  "level_state": {
    "current_level": "a2",
    "unlock_state": { "a2": { "noi": true, "viet": true, "...": "..." }, "b1": { "noi": false } },
    "promotion_unlocked": false
  },
  "mastery": [
    {
      "skill_kind": "noi",
      "module_id": "mod_giao_tiep_co_ban",
      "module_label": "Giao tiếp cơ bản",
      "score": 0.74,
      "attempts_count": 18,
      "updated_at": "..."
    }
  ],
  "promotion_attempts": [
    {
      "id": "pa_...",
      "target_level": "b1",
      "score_pct": 62,
      "passed": false,
      "created_at": "...",
      "completed_at": "..."
    }
  ],
  "recent_attempts": [
    {
      "id": "att_...",
      "exercise_id": "ex_...",
      "exercise_label": "Úloha 2 — quán cà phê",
      "skill_kind": "noi",
      "score": 0.81,
      "started_at": "..."
    }
  ]
}
```

Errors:
- `404` user không tồn tại.
- `403` non-admin.

Limits:
- `mastery`: tất cả rows (thường ≤30 per user).
- `promotion_attempts`: limit 20 mới nhất, kèm `has_more: true` nếu
  còn (V22 không phân trang sâu).
- `recent_attempts`: limit 20 mới nhất.

Implementation: 5 query song song qua `errgroup`, gộp response.

### F-API. `GET /v1/admin/content-health`

Gate: `withRole("admin")`. Path: `/v1/admin/content-health`.

Response shape (200):

```json
{
  "checked_at": "2026-05-07T14:23:00Z",
  "checks": [
    {
      "id": "orphan_exercises",
      "label": "Bài tập mồ côi",
      "description": "pool=course nhưng module_id rỗng",
      "count": 3,
      "items": [
        {
          "entity_type": "exercise",
          "entity_id": "ex_a3f...",
          "label": "Cteni 5 — bãi đỗ xe",
          "extra": "skill=doc"
        }
      ],
      "truncated": false
    }
  ]
}
```

6 check rules cố định:

| id | label | SQL essence |
|---|---|---|
| `orphan_exercises` | Bài tập mồ côi | `exercises WHERE pool='course' AND (module_id='' OR NULL)` |
| `missing_audio_listening` | Bài nghe thiếu audio | `exercises WHERE skill_kind='nghe' AND id NOT IN (SELECT exercise_id FROM exercise_audio)` |
| `untested_skill_in_module` | Module thiếu skill bắt buộc | `modules` không có exercise của ít nhất 1 skill cốt lõi (định nghĩa: noi/viet/nghe/doc/tu_vung/ngu_phap) |
| `mock_test_missing_section` | Mock test thiếu section | `mock_tests LEFT JOIN mock_test_sections ... HAVING COUNT(s.id)=0` |
| `course_missing_module` | Course thiếu module | `courses LEFT JOIN modules ... HAVING COUNT(m.id)=0` |
| `dictation_missing_sentence_audio` | Dictation thiếu sentence audio | `exercises WHERE exercise_type='psani_3_dictation' AND id NOT IN (SELECT exercise_id FROM exercise_sentence_audio)` |

Caps:
- Mỗi check trả tối đa 50 item; nếu còn → `truncated: true`.
- Toàn endpoint p95 < 3s với DB hiện tại (acceptable on-demand).

Errors: `403` non-admin.

### C-API. App-layer validate trong `PATCH/POST /v1/admin/mock-tests`

Sửa file `httpapi/admin_mock_tests.go` (handler hiện có).

Khi request `is_promotion=true && status='published' && target_level=<L>`:

1. Query `SELECT id, title FROM mock_tests WHERE is_promotion=true AND status='published' AND target_level=$1 AND id<>$2` (exclude self khi PATCH).
2. Nếu có row → return `409 Conflict`:
   ```json
   {
     "error": "promotion_exam_already_published",
     "level": "a2",
     "existing_id": "mt_...",
     "existing_title": "Đề pilot A2 → B1",
     "hint": "Hủy Published ở đề đang published trước khi đổi đề khác."
   }
   ```
3. Nếu không có → tiếp tục lưu như bình thường.

Áp dụng cho cả create + update. Không làm với draft.

## CMS Changes

### B-1. New route `cms/app/users/[userId]/page.tsx`

```tsx
import { LearnerXRay } from '../../../components/learner-xray';

export default function UserDetailPage({ params }: { params: { userId: string } }) {
  return <LearnerXRay userId={params.userId} />;
}
```

### B-2. New component `cms/components/learner-xray.tsx`

Section render order (xem wireframe trong idea § 7.2):
1. Header: breadcrumb `Users › <email>` + button "Quay lại".
2. Grid 2 col: `<ProfileCard />` + `<CefrCard />`.
3. `<UnlockStateCollapsible />` (default: tóm tắt; toggle "Xem JSON gốc" → `<pre><code>`).
4. `<MasteryTable />` (sortable, default `updated_at desc`).
5. `<PromotionAttemptsTable />` (mới nhất trước; empty state nếu rỗng).
6. `<RecentAttemptsTable />` (limit 20).
7. Footer: `<AdminActions userId />` reuse từ `users-dashboard.tsx`
   (chỉ Reset usage + Reset password, **không thêm** action mới).

States:
- `loading`: skeleton 6 block grey, ≥300ms.
- `error`: card đỏ + nút "Thử lại".
- `not-found`: card "Không tìm thấy người dùng" + link Users list.

### C-1. Extend `cms/components/mock-test-dashboard.tsx`

#### Badge (list view)
Thêm helper:
```tsx
function gatingBadge(t: MockTestRow): JSX.Element | null {
  if (t.is_promotion) {
    const lvl = (t.target_level ?? '').toUpperCase();
    return <span className="badge-promotion">🎯 → {lvl || '?'}</span>;
  }
  if (t.is_placement) {
    return <span className="badge-placement">📍 Placement</span>;
  }
  return null;
}
```

CSS (inline hoặc thêm vào `globals.css`):
```css
.badge-promotion { background: var(--brand-soft); color: var(--brand-deep); border-radius: 999px; padding: 2px 8px; font-size: 12px; font-weight: 600; }
.badge-placement { background: var(--accent-soft); color: var(--accent); border-radius: 999px; padding: 2px 8px; font-size: 12px; font-weight: 600; }
```

Render cạnh `statusBadge` + `examModeBadge` ở list row.

#### Filter dropdown
Thêm state `kindFilter: 'all' | 'normal' | 'promotion' | 'placement'`.
Render `<select>` ngay cạnh nút "+ Đề mới" trong header. Filter
client-side trên `tests` array trước khi render.

#### Inline warning khi conflict
Trước `handleSubmit`, nếu `flags.is_promotion && status === 'published'`:
1. Fetch `GET /api/admin/mock-tests?is_promotion=true&status=published&target_level=<L>` (proxy CMS sang backend).
2. Loại bỏ chính `editingId` khỏi result.
3. Nếu còn ≥1 → render warning box màu warning trên form:
   "Đã có đề promotion published cho A2: '<title>' (id <id>). Hủy
   Published trước khi đổi sang đề này."
4. Submit vẫn cho phép — backend là gate cuối (409). UI chỉ là pre-check.

(Không proxy mới: dùng `fetch` trực tiếp tới backend admin endpoint
hiện có; nếu cần thêm filter param thì handler hiện đã hỗ trợ
`is_promotion`/`status` query — verify trong plan.)

### F-1. New route `cms/app/content-health/page.tsx`

```tsx
import { ContentHealth } from '../../components/content-health';
export default function ContentHealthPage() { return <ContentHealth />; }
```

### F-2. New component `cms/components/content-health.tsx`

Layout (xem wireframe idea § 7.4):
- Header: "Sức khỏe nội dung" + "Lần chạy gần nhất: <ts>" + button
  "⟳ Chạy kiểm tra".
- Grid 3×2 cards (responsive xuống 2×3 ở < 1024px, 1×6 ở < 640px).
- Mỗi card: title, count, button "Xem chi tiết" (chỉ khi count>0).
- Click "Xem chi tiết" → expand bảng items inline (không modal).
- Click row item → `Link` tới entity gốc (`/exercises/[id]`,
  `/mock-tests/[id]`, `/courses/[id]`, `/modules/[id]`).

States:
- Initial: 6 card "—", button enabled.
- Loading: 6 skeleton, button disabled, label "Đang chạy…".
- Loaded: card có count, "Lần chạy gần nhất" set.
- Error: banner đỏ + nút "Thử lại"; cards giữ trạng thái trước.

V22 không persist DB, không persist localStorage — refresh trang
reset về initial.

### Sidebar update `cms/components/cms-sidebar.tsx`

Thêm 1 mục giữa "Mock tests" và "Users" (hoặc cuối list — quyết định
trong plan):
```
{ href: '/content-health', label: 'Sức khỏe nội dung', icon: '🩺' }
```
(Icon emoji tạm — nếu repo đã import icon library SVG thì dùng
`shield-check` hoặc `activity`. Cần verify trong plan.)

## UI/UX

Wireframe ASCII + design tokens chi tiết: `docs/ideas/v22-cms-catch-up.md`
§ 7. **Spec không lặp lại**. Nếu mâu thuẫn, **spec authoritative**.

Delta cần biết so với idea:
- **Form C đã có sẵn V21**. Không redesign. Idea wireframe § 7.3
  vẽ form 3-radio "Loại đề" — bỏ qua đoạn đó. Form hiện thực dùng
  2-checkbox + select level (xem CMS line 480-521). Spec giữ nguyên.
- Inline warning box khi conflict — UI mới (idea không vẽ chi tiết).
  Style: warning bg `#fff8d6`, text `#7c4a03`, padding 12px, border-left
  4px solid `#facc15`.

Color contrast:
- Badge promotion `#5a2406` on `#ffe5d2` ≈ 8.4:1 ✓.
- Badge placement `#0f3d3a` on `#d9e5e3` ≈ 7.1:1 ✓.
- Warning box `#7c4a03` on `#fff8d6` ≈ 6.2:1 ✓.

## Testing Strategy

### Backend (Go)

| File mới | Cases |
|---|---|
| `httpapi/admin_user_state_test.go` | happy_full / happy_no_mastery / not_found / forbidden_non_admin |
| `httpapi/admin_content_health_test.go` | happy_with_issues / happy_all_clean / forbidden_non_admin / truncated_at_50 |
| `httpapi/admin_mock_tests_test.go` (extend) | promotion_published_conflict_409 / promotion_draft_ok / promotion_unique_self_excluded / non_promotion_unaffected |

Total ≥10 test mới. Run trong `make backend-test`.

### CMS (Vitest + React Testing Library)

| File mới | Cases |
|---|---|
| `cms/__tests__/learner-xray.test.tsx` | renders_full_fixture / loading_state / error_state / not_found_state / empty_promotion_attempts |
| `cms/__tests__/mock-test-dashboard.extend.test.tsx` | promotion_badge_renders / placement_badge_renders / filter_promotion_only / conflict_warning_visible |
| `cms/__tests__/content-health.test.tsx` | initial_six_dashes / run_check_loading / run_check_results / count_zero_muted / click_item_navigates |

Total ≥13 test mới. Run trong `cd cms && npm test`.

### Smoke

- `make smoke-attempt-flow` — không regress.
- Manual browser smoke 3 user flow (idea § 8) trên staging trước
  production deploy.

### CI gate

`make verify` (backend-build + backend-test + cms-lint + cms-build +
flutter-analyze + flutter-test) phải pass trước merge.

## Acceptance Criteria

### B — Learner X-Ray
- [ ] Click row Users list điều hướng tới `/users/:id` < 1s.
- [ ] X-Ray render đầy đủ 5 section với fixture user (≥5 mastery, ≥1 promotion attempt).
- [ ] User không có promotion attempt → empty state "Chưa có lần thi promotion nào".
- [ ] Non-admin GET `/v1/admin/users/:id/state` → 403.
- [ ] User không tồn tại → 404 + UI "Không tìm thấy".
- [ ] Loading skeleton ≥300ms; error có "Thử lại".
- [ ] Backend test 4 cases pass.
- [ ] CMS test 5 cases pass.

### C — Promotion / Placement authoring
- [ ] List hiện badge "🎯 → A2" cho `is_promotion=true && target_level=a2`.
- [ ] List hiện badge "📍 Placement" cho `is_placement=true`.
- [ ] Filter "Loại = Promotion" chỉ hiện promotion mock.
- [ ] Submit `is_promotion=true + published + target_level=a2` khi đã có mock published khác cùng level → backend 409 + UI toast với hint hủy Published.
- [ ] Inline warning hiện ngay khi user toggle published + target_level conflict (pre-submit).
- [ ] Backend test 4 cases pass.
- [ ] CMS test 4 cases pass.

### F — Content Health Report
- [ ] Sidebar có mục "Sức khỏe nội dung".
- [ ] Click "Chạy kiểm tra" → 6 card cập nhật count < 5s.
- [ ] Card `count=0` muted bg + ✓ icon + no CTA.
- [ ] Card `count>0` count đỏ bold + CTA "Xem chi tiết".
- [ ] Click "Xem chi tiết" expand bảng items inline; click row item → jump entity.
- [ ] Refresh trang → cards về "—" (no persist V22).
- [ ] Backend test 3 cases pass.
- [ ] CMS test 5 cases pass.

### Slice-level
- [ ] `make verify` xanh.
- [ ] `make smoke-attempt-flow` không regress.
- [ ] CHANGELOG entry V22 ghi đầy đủ file changed + test count delta.
- [ ] SPEC.md root thêm 1 dòng digest table.

## Boundaries

### Always do
- Mọi route mới: gate `withRole("admin")` backend + check role admin trong CMS proxy nếu có.
- Reuse design token CSS variables (`--brand`, `--accent`, …) từ `globals.css`.
- Reuse dialog pattern `ConfirmResetUsage`/`ConfirmDelete` cho mọi confirm.
- VI inline strings cho form-field components (per AGENTS.md).
- Backend test bắt buộc cho mọi endpoint mới (≥3 cases: happy + invalid + forbidden).
- CMS smoke test cho mọi component mới.

### Ask first
- Bất kỳ DB column / migration mới (V22-CMS không cần — confirm với human nếu phát sinh).
- Mở rộng scope từ 3 task → 4+.
- Đổi cron infra cho F (V22 cố định on-demand).
- Promote bất kỳ defer-list V22 thành active.

### Never do
- Action edit mastery thủ công.
- Action force-unlock level thủ công.
- Click-to-fix trong health report V22.
- Cron schedule V22.
- DB migration mới trong slice này.
- Inline LLM prompt strings hoặc model IDs ngoài `processing/llm_*.go` (project-wide rule).
- Skip backend hoặc CMS test.
- Backfill spec sau khi frozen on ship.
- Tạo file root mới (≠ 5 file đã có).
- Inline slice content vào SPEC.md root (chỉ digest 1 dòng).

## Rollout

| Step | Hành động |
|---|---|
| 1 | Plan + todo file: `tasks/v22-cms-catch-up-plan.md` + `tasks/v22-cms-catch-up-todo.md` (theo lifecycle AGENTS.md). |
| 2 | Backend PR: 2 endpoint mới + extension validator + test. `make backend-test` xanh. |
| 3 | Backend deploy staging. Manual `curl` 3 endpoint với admin token. |
| 4 | CMS PR: 3 component + sidebar + test. `make cms-build` + `npm test` xanh. |
| 5 | CMS deploy staging. Manual smoke 3 user flow (idea § 8). |
| 6 | Production deploy đồng thời (CMS gọi backend mới — không có rollout staggered). |
| 7 | CHANGELOG entry V22 + SPEC.md digest row + spec status → "Shipped". |

**Không cần**: env var mới, feature flag, migration, data backfill.

## Open Questions Resolved (recon 2026-05-07)

| # | Câu hỏi (từ idea § 10) | Resolution |
|---|---|---|
| OQ-1 | `mock_tests` có cột promotion chưa? | **ĐÃ CÓ** `is_promotion` + `is_placement` + `target_level` + 2 constraints (V21). Form CMS cũng đã có. C scope thu hẹp. |
| OQ-2 | Cron infra? | **KHÔNG có scheduler tổng quát**. F = on-demand V22. Cron defer khi cần. |
| OQ-3 | A0/A1 promotion option UI? | A1 hiện disabled trong content (CefrLevelOptions giữ enum). V22 active A2/B1; A0/A1 schema-ready, content defer. |
| OQ-4 | Health rule scope? | **6 cố định V22**. Rule thứ 7+ → issue + slice riêng. |
| OQ-5 | Pagination promotion attempts? | **Limit 20** default V22. Nếu user có >20 → `has_more: true`, UI hiện "Còn N attempt cũ hơn" disabled link. |

## References

- Idea: `docs/ideas/v22-cms-catch-up.md`
- V21 mock test schema: `backend/internal/store/postgres_mock_tests.go`
- V21 promotion store: `backend/internal/store/promotion_attempts_store.go`
- V19 mastery store: `backend/internal/store/skill_mastery_store.go`
- V21.2 admin handlers: `backend/internal/httpapi/admin_users.go`
- CMS users dashboard pattern: `cms/components/users-dashboard.tsx`
- CMS mock test dashboard (form đã có): `cms/components/mock-test-dashboard.tsx` (line 480-521)
- CMS sidebar: `cms/components/cms-sidebar.tsx`
- CMS design tokens: `cms/app/globals.css`
- AGENTS.md § "Documentation Convention" — slice doc lifecycle
- AGENTS.md § "Verification Expectations" — `make verify` gate

## Frozen on Ship

Khi V22-CMS ship:
1. Status section đổi sang **Shipped** + ngày + commit hash.
2. CHANGELOG.md có entry V22.
3. SPEC.md root thêm 1 dòng digest.
4. Spec này không sửa nữa. Mọi thay đổi V23+ land trong slice mới
   + `docs/reference/` nếu là contract chung.
