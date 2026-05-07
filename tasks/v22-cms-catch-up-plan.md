# Plan — V22 CMS Catch-Up

Source spec:    `docs/specs/v22-cms-catch-up.md`
Idea:           `docs/ideas/v22-cms-catch-up.md`
SPEC summary:   `SPEC.md` § V22 (added on ship)

---

## Architecture Decisions

**No new DB migration.** V22-CMS thuần đọc + 1 app-layer validate.
Mọi cột cần đã sẵn từ V19 (`user_skill_mastery`), V21 (`user_levels`,
`promotion_attempts`, `mock_tests.is_promotion/is_placement/target_level`),
V21.2 (`daily_usage`). Nếu phát sinh nhu cầu cột mới → block + hỏi
human.

**1 endpoint per task, không gộp mega endpoint.** Tách `GET /v1/admin/users/:id/state`
(B), `GET /v1/admin/content-health` (E), và extension `PATCH/POST /v1/admin/mock-tests`
(D). Lý do: error budget tách bạch, test phân vùng rõ, CMS load
song song không cần.

**X-Ray endpoint dùng `errgroup` 5 query song song.** User row +
unlock_state row + mastery list + promotion_attempts list +
recent_attempts list. Tổng p95 < 500ms cho user ≤1k attempts.
Không tạo materialized view — dữ liệu admin debug, không phải hot path.

**Read-only V22 strict.** Không thêm action edit/force trên X-Ray.
Chỉ Reuse 2 modal `ConfirmResetUsage` + `ResetPassword` đã có. Edit
defer V23+.

**C — reuse V21 form.** Form CMS line 480-521 trong `mock-test-dashboard.tsx`
đã có 3 field (`is_promotion`/`is_placement`/`target_level`). V22
chỉ thêm: badge list + filter list + inline warning + backend 409.
Không refactor form.

**F — on-demand only V22, không cron.** Backend không có scheduler
tổng quát; chỉ `transcriber_amazon` ticker cục bộ. Cron defer khi
nào team content scale.

**App-layer uniqueness "1 promotion published per level".** DB
constraint hiện chỉ enforce target_level required + placement-promotion
mutex. Uniqueness không nên đặt UNIQUE constraint vì draft + multiple
target_level cần coexist. App-layer kiểm tra `WHERE is_promotion=true
AND status='published' AND target_level=$1 AND id<>$2`.

**CMS không proxy mới — gọi backend trực tiếp.** Pattern hiện có
(xem `users-dashboard.tsx`): CMS server-side proxy chỉ khi cần auth
token rewrite. Endpoint X-Ray + content-health đi qua existing
`/api/admin/...` proxy pattern, không thêm proxy file mới.

**6 health check rules cố định.** Không plugin system, không config-driven.
Rule thứ 7+ → issue + slice mới.

**Test-first for backend, render-test for CMS.** Backend handler test
viết trước handler (TDD). CMS chỉ render test (mock fetch) — không
e2e Playwright V22.

---

## Dependency Graph

```
                    ┌─────────────┐
                    │ A1 audit    │
                    │ A2 scaffold │
                    └──────┬──────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼
   [B Backend]        [D Backend]        [E Backend]
   B1 store           D1 store           E1 store (6 queries)
   B2 handler         D2 handler ext     E2 handler
   B3 contracts                          
        │                  │                  │
        ▼                  ▼                  ▼
   [B CMS 4-12]       [D CMS 3-5]        [E CMS 3-8]
   route + page       inline warning     route + cards + sidebar
   sub-components     toast 409          
        │                  │                  │
        └──────────┬───────┴──────────┬───────┘
                   │                  │
                   ▼                  ▼
            [C Independent]    ─►  [F Polish]
            C1 badge               F1 verify
            C2 filter              F2 smoke 3 flow
            C3 tests               F3 CHANGELOG + SPEC digest
                                   F4 spec freeze
```

C độc lập (no backend dep). Có thể chạy song song với B, hoặc dùng
làm warm-up phase. Plan đặt C sau B vì user yêu cầu order **B → C → F**
trong idea — nhưng D + E chêm giữa C và F vì là code path khác.

Order tuyến tính cuối: **A → B → C → D → E → F**.

---

## Phase A — Foundation (~0.5 day)

### A1 — Audit assumptions

**Goal**: Confirm spec recon trước khi code.

**Steps**:
- Verify `mock_tests.is_promotion`, `is_placement`, `target_level`
  tồn tại đúng tên trong DB live (không chỉ trong code).
  ```bash
  cd backend && go test ./internal/store -run TestMockTestSchema -v
  ```
- Verify CMS form đang gửi 3 field qua API call hiện có:
  ```bash
  grep -nE "is_promotion|is_placement|target_level" cms/components/exercise-utils.ts cms/lib
  ```
- Verify endpoint `GET /v1/admin/users/:id` hiện trả gì (so sánh với
  X-Ray response shape mới).

**Deliverable**: Comment ngắn trong todo phase A xác nhận assumption.
Nếu phát hiện sai khác → cập nhật spec + revisit.

**Acceptance**: 0 sai khác giữa spec § "Current Implementation Snapshot"
và code thực tế.

### A2 — Test scaffolding

**Goal**: Empty test files để không phải vừa code vừa tạo file.

**Files mới (empty test bodies)**:
- `backend/internal/httpapi/admin_user_state_test.go`
- `backend/internal/httpapi/admin_content_health_test.go`
- `cms/__tests__/learner-xray.test.tsx`
- `cms/__tests__/mock-test-dashboard.extend.test.tsx`
- `cms/__tests__/content-health.test.tsx`

Mỗi file chỉ có:
```go
package httpapi
import "testing"
func TestPlaceholder(t *testing.T) { t.Skip("v22 stub — see plan") }
```

**Acceptance**: `make backend-test` + `cd cms && npm test` xanh
(skip count tăng).

**Checkpoint A**: branch `feat/v22-cms-catch-up` tạo. Spec recon
verify. Test stubs commit. Test count: backend 654 (skip+1) → 654,
CMS 144 (skip+1) → 144.

---

## Phase B — Learner X-Ray (~2 days, vertical 1)

Vertical: 1 user click → 1 trang đầy đủ → 1 endpoint backend.

### B1 — Backend store helper

**File**: `backend/internal/store/admin_user_state_store.go` (new)

**Functions**:
```go
type LearnerState struct {
    User              UserRow
    DailyUsage        DailyUsageRow
    UnlockState       UserLevelsRow
    Mastery           []SkillMasteryRow
    PromotionAttempts []PromotionAttemptRow
    RecentAttempts    []AttemptWithExercise
}

func (s *PostgresStore) GetLearnerState(ctx context.Context, userID string) (*LearnerState, error) {
    g, gctx := errgroup.WithContext(ctx)
    var state LearnerState
    g.Go(func() error { /* user + daily_usage join */ })
    g.Go(func() error { /* user_levels */ })
    g.Go(func() error { /* user_skill_mastery JOIN modules for label */ })
    g.Go(func() error { /* promotion_attempts ORDER BY created_at DESC LIMIT 21 */ })
    g.Go(func() error { /* attempts JOIN exercises ORDER BY started_at DESC LIMIT 20 */ })
    return &state, g.Wait()
}
```

**Note**: Limit 21 cho promotion_attempts để detect `has_more`
(20 trả về + 1 sentinel).

**Test**: `backend/internal/store/admin_user_state_store_test.go` —
4 cases: full / no_mastery / no_promotion / has_more_promotion.

**Acceptance**: store function compile + test pass.

### B2 — Backend handler

**File**: `backend/internal/httpapi/admin_user_state.go` (new)

```go
func (s *Server) handleAdminUserState(w http.ResponseWriter, r *http.Request) {
    userID := strings.TrimPrefix(r.URL.Path, "/v1/admin/users/")
    userID = strings.TrimSuffix(userID, "/state")
    if userID == "" { http.Error(w, "user_id required", 400); return }

    state, err := s.adminUserStateStore.GetLearnerState(r.Context(), userID)
    if errors.Is(err, store.ErrNotFound) { http.Error(w, "not_found", 404); return }
    if err != nil { http.Error(w, "internal", 500); return }

    writeJSON(w, 200, marshalLearnerStateResponse(state))
}
```

Wire trong `server.go`:
```go
s.mux.HandleFunc("/v1/admin/users/", s.withRole("admin", s.handleAdminUserByIDOrSubresource))
```
Cập nhật `handleAdminUserByID` để route `:id/state` → `handleAdminUserState`.
Pattern đã có cho `:id/reset-password` và `:id/usage/reset`.

**Test**: `admin_user_state_test.go` — 4 cases: happy_full / happy_no_mastery /
not_found_404 / forbidden_non_admin_403.

**Acceptance**: 4 test pass, handler return JSON đúng spec § B-API shape.

### B3 — Contracts type

**File**: `backend/internal/contracts/types.go` (extend)

```go
type LearnerStateResponse struct {
    User              UserStateProfile      `json:"user"`
    DailyUsage        DailyUsageState       `json:"daily_usage"`
    LevelState        LevelStateBlock       `json:"level_state"`
    Mastery           []MasteryRow          `json:"mastery"`
    PromotionAttempts []PromotionAttemptRow `json:"promotion_attempts"`
    HasMorePromotion  bool                  `json:"has_more_promotion"`
    RecentAttempts    []RecentAttemptRow    `json:"recent_attempts"`
}
// + sub-types
```

**Acceptance**: `make backend-build` xanh.

### B4 — CMS route stub

**File**: `cms/app/users/[userId]/page.tsx` (new)

```tsx
import { LearnerXRay } from '../../../components/learner-xray';
export default function UserDetailPage({ params }: { params: { userId: string } }) {
  return <LearnerXRay userId={params.userId} />;
}
```

### B5 — Component skeleton + data fetch

**File**: `cms/components/learner-xray.tsx` (new)

State machine: `loading | error | not-found | ready`. Fetch on mount
qua `/api/admin/users/[userId]/state` proxy (cần thêm proxy nếu chưa
có — kiểm trong A1).

```tsx
'use client';
type State = { kind: 'loading' } | { kind: 'error'; message: string } | { kind: 'not-found' } | { kind: 'ready'; data: LearnerStateResponse };
```

Layout:
```tsx
<div className="xray-container">
  <XRayHeader breadcrumb={['Users', user.email]} />
  {state.kind === 'loading' && <Skeleton />}
  {state.kind === 'error' && <ErrorBlock onRetry={refetch} />}
  {state.kind === 'not-found' && <NotFoundBlock />}
  {state.kind === 'ready' && <XRayBody data={state.data} />}
</div>
```

### B6 — ProfileCard + CefrCard

Grid 2 col:
- ProfileCard: email, display_name, role, pro_tier, grace_attempts, created_at
- CefrCard: current_level (badge), placement_taken_at, promotion_unlocked, attempts_today/cap (kèm reset link reuse)

### B7 — UnlockStateCollapsible

Default tóm tắt: `A2 · noi ✓ · viet ✓ · ...`. Toggle "Xem JSON gốc" →
`<pre><code>{JSON.stringify(unlock_state, null, 2)}</code></pre>`.

### B8 — MasteryTable

Sortable columns: skill_kind / module_label / score (bar viz) /
attempts_count / updated_at. Default sort: updated_at desc.

### B9 — PromotionAttemptsTable

Cols: target_level / score_pct (xx%) / passed (✓/❌) / created_at /
completed_at. Empty state: "Chưa có lần thi promotion nào".
`has_more_promotion=true` → hiện "Còn N attempt cũ hơn" disabled link.

### B10 — RecentAttemptsTable

Cols: exercise_label / skill_kind / score / started_at. Limit 20.

### B11 — AdminActions footer

Reuse `ConfirmResetUsage` + `ResetPassword` modal từ `users-dashboard.tsx`.
Import dạng named export hoặc copy ra helper file nếu cần.

### B12 — Wire link from users list

Sửa `users-dashboard.tsx`: row hiện đang có `<button>` actions.
Thêm `<Link href={\`/users/\${user.id}\`}>` bao quanh email cell hoặc
thêm 1 nút mới "Xem chi tiết".

### B13 — CMS test

**File**: `cms/__tests__/learner-xray.test.tsx`

5 cases:
- renders_full_fixture (mock fetch trả LearnerStateResponse)
- loading_state (fetch never resolves)
- error_state (fetch reject)
- not_found_state (404)
- empty_promotion_attempts (empty array)

**Checkpoint B**:
- `make backend-test` xanh, +4 test (654 → 658).
- `cd cms && npm test` xanh, +5 test (144 → 149).
- Manual: login admin, click 1 user trong Users list → mở X-Ray <1s,
  thấy 5 section.

---

## Phase C — Mock test list polish (~0.5 day, vertical 2)

Vertical: list view nhận 3 thứ mới. Không backend.

### C1 — Badge helper + CSS

**File**: `cms/components/mock-test-dashboard.tsx` (extend)

Thêm helper `gatingBadge(test)` (xem spec § C-1). CSS class
`.badge-promotion` + `.badge-placement` thêm vào `cms/app/globals.css`.

### C2 — Filter dropdown

State `kindFilter`. Dropdown render bên cạnh nút "+ Đề mới" trong
header. Filter `tests` array client-side trước render.

### C3 — Test

**File**: `cms/__tests__/mock-test-dashboard.extend.test.tsx`

4 cases: promotion_badge_renders / placement_badge_renders /
filter_promotion_only_shows_promotion / filter_all_shows_everything.

**Checkpoint C**:
- CMS test +4 (149 → 153).
- Manual: mở Mock tests, thấy badge orange/teal + filter dropdown
  hoạt động.

---

## Phase D — Promotion uniqueness validate (~0.5 day, vertical 3)

Vertical: backend 409 + CMS pre-check warning + toast on submit.

### D1 — Backend store query

**File**: `backend/internal/store/postgres_mock_tests.go` (extend)

```go
func (s *PostgresStore) FindPublishedPromotionByLevel(ctx context.Context, level string, excludeID string) (*MockTestRow, error) {
    // SELECT id, title FROM mock_tests
    // WHERE is_promotion=true AND status='published' AND target_level=$1 AND id<>$2
    // LIMIT 1
}
```

**Test**: thêm vào `postgres_mock_tests_test.go` 3 cases:
match_one / no_match / exclude_self.

### D2 — Backend handler extension

**File**: `backend/internal/httpapi/admin_mock_tests.go` (extend)

Trong `handleCreateMockTest` + `handleUpdateMockTest`, sau khi parse
body, trước khi store call:
```go
if req.IsPromotion && req.Status == "published" {
    existing, err := s.mockTestStore.FindPublishedPromotionByLevel(ctx, req.TargetLevel, req.ID)
    if err != nil { /* 500 */ }
    if existing != nil {
        writeJSON(w, 409, map[string]any{
            "error": "promotion_exam_already_published",
            "level": req.TargetLevel,
            "existing_id": existing.ID,
            "existing_title": existing.Title,
            "hint": "Hủy Published ở đề đang published trước khi đổi đề khác.",
        })
        return
    }
}
```

**Test**: `admin_mock_tests_test.go` (extend) — 4 cases:
promotion_published_conflict_409 / promotion_draft_no_check_passes /
promotion_unique_self_excluded_passes / non_promotion_unaffected.

### D3 — CMS inline warning fetch

**File**: `cms/components/mock-test-dashboard.tsx` (extend)

`useEffect` listen `[form.flags.is_promotion, form.flags.target_level, form.status]`.
Khi cả 3 thoả `is_promotion && published && target_level`:
```tsx
fetch(`/api/admin/mock-tests?is_promotion=true&status=published&target_level=${lvl}`)
  .then(r => r.json())
  .then(data => {
    const conflict = data.items.find(t => t.id !== editingId);
    setConflictWarning(conflict ?? null);
  });
```

(Verify `GET /api/admin/mock-tests` đã hỗ trợ filter `is_promotion`
+ `status` + `target_level` trong A1; nếu chưa → thêm filter trong
handler list, tách microtask D1.5.)

### D4 — Inline warning render + toast on 409

Render warning box trong form (xem spec § C-1 inline warning style).

`handleSubmit` catch 409:
```tsx
if (res.status === 409) {
  const body = await res.json();
  showToast({ kind: 'error', message: `Đã có promotion exam published cho ${body.level.toUpperCase()}: "${body.existing_title}". ${body.hint}` });
  return;
}
```

### D5 — CMS test

Thêm 4 case vào `mock-test-dashboard.extend.test.tsx`:
conflict_warning_visible / conflict_warning_hidden_for_draft /
toast_on_409 / no_warning_when_self_only.

**Checkpoint D**:
- Backend test +4 (658 → 662).
- CMS test +4 (153 → 157).
- Manual: tạo 2 mock tests cùng `target_level=a2 + published` → mock
  thứ 2 bị reject với toast hint.

---

## Phase E — Content Health Report (~1.5 days, vertical 4)

Vertical: 1 endpoint + 1 page + 1 sidebar entry.

### E1 — Backend store 6 queries

**File**: `backend/internal/store/content_health_store.go` (new)

```go
type CheckResult struct {
    ID          string
    Label       string
    Description string
    Count       int
    Items       []CheckItem
    Truncated   bool
}

type CheckItem struct {
    EntityType string
    EntityID   string
    Label      string
    Extra      string
}

func (s *PostgresStore) RunContentHealth(ctx context.Context) ([]CheckResult, error) {
    g, gctx := errgroup.WithContext(ctx)
    var results [6]CheckResult
    g.Go(func() error { results[0], err = s.checkOrphanExercises(gctx); ... })
    // ... 5 more checks
    return results[:], g.Wait()
}
```

6 queries:
1. `checkOrphanExercises`: `SELECT id, title, skill_kind FROM exercises WHERE pool='course' AND (module_id='' OR module_id IS NULL) LIMIT 51`
2. `checkMissingListeningAudio`: `SELECT e.id, e.title FROM exercises e LEFT JOIN exercise_audio a ON a.exercise_id=e.id WHERE e.skill_kind='nghe' AND a.exercise_id IS NULL LIMIT 51`
3. `checkUntestedSkillInModule`: more complex — module mismatch
4. `checkMockTestMissingSection`: `SELECT m.id, m.title FROM mock_tests m LEFT JOIN mock_test_sections s ON s.mock_test_id=m.id GROUP BY m.id, m.title HAVING COUNT(s.id)=0 LIMIT 51`
5. `checkCourseMissingModule`: similar
6. `checkDictationMissingSentenceAudio`: `SELECT e.id, e.title FROM exercises e LEFT JOIN exercise_sentence_audio sa ON sa.exercise_id=e.id WHERE e.exercise_type='psani_3_dictation' AND sa.exercise_id IS NULL GROUP BY e.id, e.title LIMIT 51`

Limit 51 → nếu trả 51 row → `Truncated=true`, slice xuống 50.

**Test**: `content_health_store_test.go` — 6 happy + 6 empty cases.

### E2 — Backend handler

**File**: `backend/internal/httpapi/admin_content_health.go` (new)

```go
func (s *Server) handleAdminContentHealth(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodGet { http.Error(w, "method not allowed", 405); return }
    results, err := s.contentHealthStore.RunContentHealth(r.Context())
    if err != nil { http.Error(w, "internal", 500); return }
    writeJSON(w, 200, map[string]any{
        "checked_at": time.Now().UTC().Format(time.RFC3339),
        "checks": results,
    })
}
```

Wire trong `server.go`:
```go
s.mux.HandleFunc("/v1/admin/content-health", s.withRole("admin", s.handleAdminContentHealth))
```

**Test**: `admin_content_health_test.go` — 3 cases:
happy_with_issues / happy_all_clean / forbidden_non_admin.

### E3 — CMS route stub

**File**: `cms/app/content-health/page.tsx` (new)

```tsx
import { ContentHealth } from '../../components/content-health';
export default function ContentHealthPage() { return <ContentHealth />; }
```

### E4 — Component grid + count display

**File**: `cms/components/content-health.tsx` (new)

State machine: `initial | running | loaded | error`. 6 card grid 3×2.

```tsx
const [state, setState] = useState<State>({ kind: 'initial' });
async function runCheck() {
  setState({ kind: 'running' });
  try {
    const res = await fetch('/api/admin/content-health');
    const data = await res.json();
    setState({ kind: 'loaded', data });
  } catch (e) {
    setState({ kind: 'error', message: String(e) });
  }
}
```

Card: title, count (đỏ bold nếu >0, ✓ nếu =0), CTA "Xem chi tiết" (chỉ khi >0).

### E5 — Expand inline + entity links

Click "Xem chi tiết" toggle `expandedCheckId`. Bảng items render
inline dưới grid:

```tsx
{expandedCheckId && (
  <ExpandedItemsTable
    items={checks.find(c => c.id === expandedCheckId)?.items ?? []}
    onItemClick={(item) => router.push(entityLink(item))}
  />
)}
```

`entityLink` map:
- `exercise` → `/exercises/${id}` (verify route tồn tại)
- `mock_test` → `/mock-tests/${id}`
- `course` → `/courses/${id}`
- `module` → `/modules/${id}`

### E6 — States polish

- Initial: 6 card "—", button enabled.
- Running: 6 skeleton, button disabled label "Đang chạy…".
- Loaded: card có count, "Lần chạy gần nhất: <ts>" header.
- Error: banner đỏ + nút "Thử lại"; cards giữ trạng thái trước.

### E7 — CMS test

**File**: `cms/__tests__/content-health.test.tsx`

5 cases: initial_six_dashes / run_check_loading_skeleton /
run_check_results_render / count_zero_muted_no_cta /
click_item_navigates.

### E8 — Sidebar entry

**File**: `cms/components/cms-sidebar.tsx` (extend)

Thêm 1 mục:
```tsx
{ href: '/content-health', label: 'Sức khỏe nội dung', icon: '🩺' }
```

Vị trí: sau "Mock tests", trước "Users".

**Checkpoint E**:
- Backend test +9 (662 → 671) — bao gồm 6 store + 3 handler.
- CMS test +5 (157 → 162).
- Manual: sidebar có mục mới, click "Chạy kiểm tra" → 6 card load,
  click "Xem chi tiết" trên card có count → bảng expand, click item
  → jump entity.

---

## Phase F — Polish & ship (~0.5 day)

### F1 — Full verify

```bash
make verify
```
Phải xanh. Nếu CMS lint đỏ → fix style nhỏ. Nếu Flutter analyze
đỏ → bug ngoài scope V22-CMS, hỏi human.

### F2 — Manual smoke 3 user flow

Theo idea § 8:
- Flow B: Users list → click 1 user (chọn user có promotion attempt) → X-Ray load → 5 section đầy đủ. Click "Reset usage" → confirm → toast.
- Flow C: Mock tests → tạo mới `is_promotion=true, target_level=a2, status=published` lần 1 → save OK. Lần 2 (mock khác cùng level) → inline warning + toast 409.
- Flow F: Sidebar "Sức khỏe nội dung" → "Chạy kiểm tra" → 6 card load. Click 1 card có count → bảng expand → click item → jump entity.

### F3 — `make smoke-attempt-flow` không regress

```bash
make smoke-attempt-flow
make smoke-course-flow
make smoke-exam-flow
```

Nếu fail không liên quan V22-CMS → log + tiếp tục. Nếu liên quan → fix.

### F4 — CHANGELOG entry V22

Thêm vào `CHANGELOG.md` đầu file (sau heading):
```markdown
## V22 — CMS Catch-Up (2026-XX-XX)

3-task slice đóng khoảng cách CMS với V19/V20/V21 features.
Strict read-only.

- **B Learner X-Ray** (`/users/[userId]`): admin click 1 user → trang
  debug đầy đủ ...
- **C Mock test list polish**: badge promotion/placement + filter
  + app-layer "1-published-per-level" validate ...
- **F Content Health Report** (`/content-health`): on-demand 6
  check ...

Backend 671 tests (was 654 → +17). CMS 162 tests in 10 files (was 144).
`make verify` xanh.
```

### F5 — SPEC.md root digest row

Thêm vào bảng digest:
```
| V22 | CMS Catch-Up | docs/specs/v22-cms-catch-up.md | 2026-XX-XX |
```

### F6 — tasks/plan.md + todo.md index

Thêm dòng trong `tasks/plan.md`:
```
| V22 CMS Catch-Up | [v22-cms-catch-up-plan.md](v22-cms-catch-up-plan.md) | [v22-cms-catch-up-todo.md](v22-cms-catch-up-todo.md) | [docs/specs/v22-cms-catch-up.md](../docs/specs/v22-cms-catch-up.md) | ✅ shipped |
```

Thêm dòng trong `tasks/todo.md`:
```
- [v22-cms-catch-up-todo.md](v22-cms-catch-up-todo.md) — V22 (shipped)
```

### F7 — Spec status → Shipped

Sửa `docs/specs/v22-cms-catch-up.md` § Status:
```markdown
**Shipped 2026-XX-XX** (commit `<hash>`).
```

### F8 — Fold contracts (nếu phát sinh)

Nếu V22 đụng contract chung (api shape, attempt lifecycle, etc) → cập
nhật `docs/reference/api-contracts.md`. Hiện spec V22 không thay đổi
contract chung — chỉ thêm 2 admin endpoint nội bộ → **skip F8**.

### F9 — `docs/architecture/current-code-shape.md`

Refresh nếu kiến trúc thay đổi đáng kể. V22-CMS thêm 3 component +
2 endpoint, không thay đổi cấu trúc lớn → 1-2 dòng mention là đủ.

**Checkpoint F**:
- `make verify` xanh.
- 3 manual smoke pass.
- CHANGELOG + SPEC digest + tasks index landed.
- Spec status = Shipped.

---

## Risk Matrix

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `GET /api/admin/mock-tests` chưa hỗ trợ filter `is_promotion`/`target_level` | MED | LOW | A1 verify; nếu thiếu → thêm filter trong handler list (microtask D1.5, ~30 phút) |
| Errgroup 5 query slow trên user lớn | LOW | MED | Limit `mastery` rows (chuẩn ≤30/user), `recent_attempts` 20, `promotion_attempts` 21. Nếu p95 > 500ms → index check trong DB |
| CMS proxy `/api/admin/users/:id/state` chưa có | HIGH | LOW | A1 check; thêm proxy file `cms/app/api/admin/users/[userId]/state/route.ts` (vài dòng forward) |
| Health check #3 (untested skill in module) query phức tạp | MED | MED | Viết test trước. Nếu quá chậm → tách per-skill thành 6 sub-query |
| Sidebar emoji không match style | LOW | LOW | Defer SVG icon library V23 nếu chưa có |
| Reset usage modal regress khi reuse | LOW | HIGH | E2E manual smoke flow B step "Reset usage" |
| Promotion conflict warning fetch race | LOW | LOW | Debounce 250ms hoặc abort previous fetch |

---

## Smoke Plan

### Pre-deploy (staging)

| Flow | Steps | Pass criteria |
|---|---|---|
| **Flow B** | Login admin → Users list → click user có promotion attempt → X-Ray load | 5 section render đầy đủ < 1s, badge level đúng, action footer có 2 button |
| **Flow C** | Mock tests → tạo mới `is_promotion=true, target_level=a2, status=published` × 2 lần | Lần 2 bị reject với toast 409 + warning inline trước submit |
| **Flow F** | Sidebar → "Sức khỏe nội dung" → "Chạy kiểm tra" → click 1 card → click 1 item | 6 card load, expand, item click jump tới entity, refresh trang reset card |

### Post-deploy (production)

Repeat 3 flow trên production với 1 admin account thật. Log thời gian
load X-Ray + content-health vào CHANGELOG nếu khác staging notable.

---

## Verification Command Summary

| Phase | Command | Expected delta |
|---|---|---|
| A | `make backend-test` + `cd cms && npm test` | skip +1, +0 |
| B | `make backend-test` + `cd cms && npm test` | backend +4 (654→658), cms +5 (144→149) |
| C | `cd cms && npm test` | cms +4 (149→153) |
| D | `make backend-test` + `cd cms && npm test` | backend +4 (658→662), cms +4 (153→157) |
| E | `make backend-test` + `cd cms && npm test` | backend +9 (662→671), cms +5 (157→162) |
| F | `make verify` + `make smoke-all` | tất cả xanh |

Total V22-CMS test delta: backend +17, CMS +18.

---

## Reference

- Spec: `docs/specs/v22-cms-catch-up.md`
- Idea: `docs/ideas/v22-cms-catch-up.md`
- Pattern: `tasks/cefr-ui-wireup-plan.md` (V21.3, vertical-slice ref)
- Pattern: `tasks/skill-mastery-progress-plan.md` (V19, backend store +
  handler ref)
- AGENTS.md § "Verification Expectations" + § "Documentation Convention"
