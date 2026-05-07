# Plan — V23 Exercise Authoring Polish

Source spec:    `docs/specs/v23-exercise-authoring-polish.md`
Idea:           `docs/ideas/v23-exercise-authoring-polish.md`
SPEC summary:   `SPEC.md` § V23 (added on ship)

---

## Architecture Decisions

**No DB migration.** V23 thuần đọc + 1 list endpoint extension. Mọi
data đã có từ V21 (exercise/audio/sentence_audio/module schema) +
V22 (content-health logic).

**`validation_flags` inline per row, not separate include.** Single
endpoint, payload tăng nhẹ (~5 bool/row × 50 row ≤ 1 KB). Backend
single source of truth — CMS không recompute.

**Reuse V22 content-health logic, refactor per-rule to per-exercise.**
V22 `admin_content_health.go` có 6 aggregate check; V23 cần per-row
check. Refactor thành helper `computeValidationFlags(repo, ex)` →
V22 aggregate gọi helper này 1 lần per exercise. **DRY**, không
duplicate.

**Strict V23 quick-fix modal scope.** Chỉ publish/unpublish + regen
audio. Edit field khác (gán module, sample text) qua form thường.
Tránh scope creep modal monolith.

**Clone audio: skip hoàn toàn.** Clone không đụng `exercise_audio`.
Admin click "Tạo lại audio" sau qua endpoint generate-audio sẵn có
(server.go:1308).

**Inline form, not separate route.** Spec wireframe ám chỉ
`/exercises/[id]/edit` — thực tế CMS render form inline trong
`exercise-dashboard.tsx` qua `showForm` state. C wrap layout
in-place khi `showForm=true`, **không tạo route `/exercises/[id]/edit`**.

**Top 5 type V23: uloha_1, uloha_2, uloha_3, uloha_4, psani_2_email.**
4 speaking + 1 writing (email). 11 type khác → placeholder. Defer V24+.

**Preview a11y: aria-hidden.** Visual aid only; screen reader skip
preview pane (form là source of truth).

**Drawer 1024-1279 = overlay (không push form).** Đơn giản, không
reflow form.

**Test layer: pure helpers (V22 convention).** CMS infra plain Vitest.
Component render delegate cho manual smoke.

---

## Dependency Graph

```
                     ┌─────────────┐
                     │ A1 audit    │
                     │ A2 scaffold │
                     └──────┬──────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
   [B Vertical 1]     [H Vertical 2]      [C Vertical 3]
   B1 helper          H1 BE per-rule      C1 layout
   B2 row btn         H2 BE list ext      C2 preview pane
   B3 toast           H3 CMS badges       C3 debounce hook
                      H4 list column      C4 uloha renderer
                      H5 filter toggle    C5 psani renderer
                      H6 modal cmpt       C6 placeholder
                      H7 row click        C7 routing test
                      H8 submit hdlrs     C8 wire dashboard
                      H9 reload
        │                   │                   │
        └───────────────────┼───────────────────┘
                            ▼
                       [F Polish]
                       F1..F8 verify + ship
```

B + C độc lập (CMS-only). H đụng backend + CMS. Order user yêu cầu
**B → H → C** giữ nguyên (B nhẹ nhất, C nặng nhất, H giữa).

Tuyến tính cuối: **A → B → H → C → F**.

---

## Phase A — Foundation (~0.5 day)

### A1 — Audit assumptions

**Goal**: confirm spec recon trước khi code.

**Steps**:
- Verify `POST /v1/admin/exercises/:id/generate-audio` response shape
  (sync vs async, success status code)
- Verify `GET /v1/admin/exercises/:id` detail shape khớp với
  source-of-truth Exercise contract
- Confirm `cms/app/page.tsx` root render ExerciseDashboard inline
  form pattern (no separate edit route)
- Spot-check 5 supported preview type prompt JSON shape qua existing
  exercises seed (xem field nào học các renderer cần)

**Deliverable**: comment trong commit message hoặc PR đầu xác nhận
0 sai khác với spec § "Current Implementation Snapshot".

### A2 — Test scaffolding

**Files mới (empty test stubs)**:
- `backend/internal/httpapi/admin_exercises_test.go`
- `cms/__tests__/exercise-clone.test.ts`
- `cms/__tests__/validation-badges.test.ts`
- `cms/__tests__/exercise-quick-fix.test.ts`
- `cms/__tests__/preview-routing.test.ts`

Mỗi file: `it.skip("v23 stub")`.

**Acceptance**: `make backend-test` + `cd cms && npm test` xanh
(skip +5).

**Checkpoint A**: branch `feat/v23-exercise-authoring-polish` tạo.
Spec recon confirmed. Test stubs commit. Skip count tăng.

---

## Phase B — Quick-Clone (~1.5 day, vertical 1, CMS-only)

### B1 — `cloneExercisePayload` helper

**File**: `cms/components/exercise-utils.ts` (extend)

```ts
export function cloneExercisePayload(src: Exercise): CreatePayload {
  return {
    title: `Copy of ${src.title}`,
    status: 'draft',
    module_id: src.module_id,
    skill_kind: src.skill_kind,
    pool: src.pool,
    exercise_type: src.exercise_type,
    short_instruction: src.short_instruction,
    learner_instruction: src.learner_instruction,
    estimated_duration_sec: src.estimated_duration_sec,
    prep_time_sec: src.prep_time_sec,
    recording_time_limit_sec: src.recording_time_limit_sec,
    sample_answer_enabled: src.sample_answer_enabled,
    sample_answer_text: src.sample_answer_text,
    disable_sample_answer: src.disable_sample_answer,
    prompt: src.prompt,
    assets: src.assets,
    detail: src.detail,
  };
}
```

**Test**: `cms/__tests__/exercise-clone.test.ts` — 6 cases:
- title prefix "Copy of "
- status=draft
- preserved fields giữ nguyên
- stripped: id absent
- missing optional (sample) ổn
- assets shared (same reference, no deep copy needed)

CMS test +6 (skipped → real).

### B2 — Row action "Sao chép"

**File**: `cms/components/exercise-list.tsx` (extend)

Cạnh nút [Sửa] [Xóa] thêm [Sao chép]. State `cloningId: string | null`
busy lock. Click handler:
```tsx
async function handleClone(source: Exercise) {
  setCloningId(source.id);
  try {
    const fresh = await fetch(`/api/admin/exercises/${source.id}`).then(r => r.json());
    const payload = cloneExercisePayload(fresh.data);
    const res = await fetch('/api/admin/exercises', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    if (!res.ok) throw new Error((await res.json()).error?.message ?? 'Clone failed');
    const created = (await res.json()).data;
    showToast({ kind: 'success', message: `Đã tạo ${created.id} (draft)`, action: ... });
    await refetchExercises();
  } catch (err) { ... }
  finally { setCloningId(null); }
}
```

**No new test** (covered by B1 helper test + manual smoke).

### B3 — Toast with click-to-edit

**File**: `cms/components/exercise-list.tsx` (extend)

Use existing toast pattern (check users-dashboard for prior art) hoặc
inline simple toast. Click toast → set `editingId = created.id` +
`showForm = true` trong parent ExerciseDashboard.

**Acceptance**:
- Clone source ổn → toast hiện < 800ms
- Click toast → form edit row mới mở, scroll to title
- Source 404 → toast error + retry button

**Checkpoint B**:
- CMS test +6 (clone helper).
- Manual smoke: clone 1 exercise (draft → list refresh → click
  toast → form edit).
- CMS test count: 190 → 196.

---

## Phase H — Validation Inline (~2 day, vertical 2, BE+CMS)

### H1 — Backend per-rule helper

**File**: `backend/internal/httpapi/admin_content_health.go` (extend)

Refactor V22 6 aggregate checks: extract per-exercise rule logic
thành `computeValidationFlags(repo *store.MemoryStore, ex contracts.Exercise) ValidationFlags`.

```go
type ValidationFlags struct {
    MissingAudio          bool `json:"missing_audio"`
    MissingSentenceAudio  bool `json:"missing_sentence_audio"`
    Orphan                bool `json:"orphan"`
    MissingSample         bool `json:"missing_sample"`
    Unpublished           bool `json:"unpublished"`
}

func computeValidationFlags(repo *store.MemoryStore, ex contracts.Exercise) ValidationFlags {
    return ValidationFlags{
        MissingAudio: ex.SkillKind == "nghe" && !hasExerciseAudio(repo, ex.ID),
        MissingSentenceAudio: ex.ExerciseType == "psani_3_dictation" && !hasSentenceAudio(repo, ex.ID),
        Orphan: ex.Pool == "course" && ex.ModuleID == "",
        MissingSample: (ex.SkillKind == "noi" || ex.SkillKind == "viet") &&
                       ex.SampleAnswerEnabled && strings.TrimSpace(ex.SampleAnswerText) == "",
        Unpublished: ex.Status == "draft",
    }
}
```

V22 aggregate (`checkOrphanExercises`, etc.) refactor để gọi
`computeValidationFlags` rồi check field.

**Test**: `httpapi/admin_content_health_test.go` (extend) — 10 cases:
mỗi rule × 2 (positive/negative).

Backend test +10.

### H2 — Backend extend `GET /v1/admin/exercises`

**File**: `backend/internal/httpapi/server.go` (extend handler line 2050)

Trong GET case:
```go
items := s.repo.ListExercises(pool)
type ExerciseWithFlags struct {
    contracts.Exercise
    ValidationFlags ValidationFlags `json:"validation_flags"`
}
out := make([]ExerciseWithFlags, len(items))
for i, ex := range items {
    out[i] = ExerciseWithFlags{
        Exercise: ex,
        ValidationFlags: computeValidationFlags(s.repo, ex),
    }
}
writeJSON(w, http.StatusOK, map[string]any{"data": out, "meta": map[string]any{}})
```

**Test**: `admin_exercises_test.go` (replace stub) — 3 cases:
- happy_with_flags (seed orphan + missing-audio + clean exercises, verify shape)
- forbidden_non_admin
- pool_filter_still_works

Backend test +3.

### H3 — CMS validation-badges helper

**File**: `cms/components/validation-badges.ts` (new)

```ts
export type ValidationFlags = {
  missing_audio: boolean;
  missing_sentence_audio: boolean;
  orphan: boolean;
  missing_sample: boolean;
  unpublished: boolean;
};

export type BadgeSpec = { variant; icon; label; tooltip };

export function flagsToBadges(flags?: ValidationFlags): BadgeSpec[] { ... }
export function hasAnyIssue(flags?: ValidationFlags): boolean { ... }
```

Implementation per spec § H-1.

**Test**: `cms/__tests__/validation-badges.test.ts` — 10 cases:
- 5 individual flag → 1 badge each
- all-false → ✓ ready
- multiple flags combo → multiple badges
- undefined flags → empty array
- hasAnyIssue: positive / negative / unpublished-only-not-counted

CMS test +10.

### H4 — CMS list badge column

**File**: `cms/components/exercise-list.tsx` (extend)

Thêm column "Tình trạng" trước column "Tên". Render `<BadgeCluster
flags={item.validation_flags} />`. Hover badge → tooltip.

`Exercise` type extend với `validation_flags?: ValidationFlags`.

### H5 — Filter "Chỉ hiện vấn đề"

**File**: `exercise-list.tsx` (extend)

Checkbox state `problemOnly: boolean`. Filter logic extend:
```tsx
const filteredItems = useMemo(() => items.filter((item) => {
  if (problemOnly && !hasAnyIssue(item.validation_flags)) return false;
  // existing filters...
}), [...existing, problemOnly, items]);
```

### H6 — Quick fix modal component

**File**: `cms/components/exercise-quick-fix-modal.tsx` (new)

Reuse modal frame `ConfirmResetUsage` style (V21.2). State machine:
- `idle` → display flags + radio + button
- `submitting_status` → disable inputs
- `submitting_audio` → disable + spinner
- `error` → show message + retry
- `done` → close + parent reload

**Test**: `cms/__tests__/exercise-quick-fix.test.ts` — 4 cases:
- audio button enable rule (skill=nghe, dictation, others)
- status submit posts PATCH với new status
- audio retry posts to generate-audio endpoint
- close handler triggers parent reload

CMS test +4.

### H7 — Wire row-click → modal

**File**: `exercise-list.tsx` (extend)

Click row (not row buttons) → open modal. Click button [Sửa]/[Xóa]/
[Sao chép] → `e.stopPropagation()` để không trigger row click.

### H8 — Modal submit handlers

**File**: `exercise-quick-fix-modal.tsx`

```tsx
async function handleStatusSubmit(newStatus) {
  await fetch(`/api/admin/exercises/${id}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ status: newStatus }),
  });
  onClose();
}

async function handleAudioRegen() {
  await fetch(`/api/admin/exercises/${id}/generate-audio`, { method: 'POST' });
  onClose();
}
```

### H9 — Modal close → list reload

**File**: `exercise-list.tsx` (extend)

Modal `onClose` callback gọi `refetchExercises()` để badges cập nhật.

**Checkpoint H**:
- Backend test +13 (10 rule + 3 list shape).
- CMS test +14 (10 badges + 4 modal).
- Manual smoke: orphan exercise → badge ❌ → click → modal → publish
  + audio regen.
- Backend test count: 683 → 696. CMS test count: 196 → 210.

---

## Phase C — Inline Preview (~1.5-2 day, vertical 3, CMS-only)

### C1 — `ExerciseEditLayout` wrap component

**File**: `cms/components/exercise-edit-layout.tsx` (new)

```tsx
export function ExerciseEditLayout({ children, exerciseForm }: Props) {
  const isWide = useMediaQuery('(min-width: 1280px)');
  const [drawerOpen, setDrawerOpen] = useState(false);

  if (isWide) {
    return (
      <div style={{ display: 'grid', gridTemplateColumns: '60% 40%', gap: 16 }}>
        <div>{children}</div>
        <PreviewPane form={exerciseForm} />
      </div>
    );
  }
  return (
    <>
      <div style={{ marginBottom: 12 }}>
        <button onClick={() => setDrawerOpen(true)} className="btn btn-ghost">Xem preview</button>
      </div>
      {children}
      {drawerOpen && (
        <Drawer onClose={() => setDrawerOpen(false)}>
          <PreviewPane form={exerciseForm} />
        </Drawer>
      )}
    </>
  );
}
```

`useMediaQuery` hook (new, ~10 LOC). Drawer = fixed pos right, slide-in.

### C2 — `PreviewPane` + disclaimer band

**File**: `cms/components/exercise-preview/index.tsx` (new)

```tsx
export function PreviewPane({ form }: Props) {
  return (
    <div style={{ background: 'var(--preview-bg)', padding: 16 }} aria-hidden="true">
      <DisclaimerBand />
      <PreviewRouter form={form} />
    </div>
  );
}

function DisclaimerBand() {
  return (
    <div style={{ background: '#fff8d6', borderLeft: '4px solid #facc15', color: '#7c4a03', padding: '8px 12px', marginBottom: 12 }}>
      🔍 Preview low-fidelity. Hãy test trên Flutter trước khi ship.
    </div>
  );
}
```

### C3 — `useDebouncedForm` hook

**File**: `cms/components/exercise-preview/use-debounced-form.ts` (new)

```ts
export function useDebouncedForm<T>(form: T, delayMs: number = 200): T {
  const [debounced, setDebounced] = useState(form);
  useEffect(() => {
    const id = setTimeout(() => setDebounced(form), delayMs);
    return () => clearTimeout(id);
  }, [form, delayMs]);
  return debounced;
}
```

Wire trong PreviewPane: `const debouncedForm = useDebouncedForm(form);`.

### C4 — `UlohaPreview` renderer

**File**: `cms/components/exercise-preview/uloha-preview.tsx` (new)

Render mock card với:
- Title bar "Úloha {variant} — {kind label}"
- Topic / dialogue / story_title (depend on variant)
- Question list (uloha_1) hoặc dialogue prompts (uloha_2) etc.
- Duration label
- Disabled "[🎤 Bắt đầu ghi âm]" button
- Estimated time + prep time

~150 LOC. Reuses existing prompt JSON shape (xem
contracts.Exercise.Prompt + exercise-utils.ts type defs).

### C5 — `PsaniEmailPreview` renderer

**File**: `cms/components/exercise-preview/psani-email-preview.tsx` (new)

Render mock card:
- Email subject / from / to (từ form prompt)
- Email body với scenario
- Disabled textarea "Trả lời email tại đây..."
- Word count guide

~120 LOC.

### C6 — `PreviewPlaceholder` for unsupported types

**File**: `cms/components/exercise-preview/placeholder.tsx` (new)

```tsx
export function PreviewPlaceholder({ type }: { type: string }) {
  return (
    <div style={{ ...emptyState }}>
      <p style={{ fontSize: 24 }}>👁</p>
      <p>Preview cho type <code>{type}</code> chưa hỗ trợ V23.</p>
      <p style={{ fontSize: 12, color: 'var(--ink-3)' }}>
        Top 5 type V23: uloha_1, uloha_2, uloha_3, uloha_4, psani_2_email.
        Test learner-side trên Flutter trước khi ship.
      </p>
    </div>
  );
}
```

### C7 — Preview routing test

**File**: `cms/__tests__/preview-routing.test.ts`

Pure helper `selectPreviewRenderer(type) → ComponentName | 'placeholder'`.

6 cases: 5 supported types → matching renderer; 1 unsupported → placeholder.

CMS test +6.

### C8 — Wire layout vào ExerciseDashboard

**File**: `cms/components/exercise-dashboard.tsx` (extend)

Khi `showForm=true`, wrap form trong `<ExerciseEditLayout
exerciseForm={form}>`. Khi `showForm=false` không wrap (list view
unchanged).

**Checkpoint C**:
- CMS test +6 (preview routing).
- Manual smoke: open form → split layout (≥1280) hoặc drawer
  (<1280) → 5 type render correctly + 11 type placeholder.
- CMS test count: 210 → 216.

---

## Phase F — Polish & Ship (~0.5 day)

### F1 — `make verify`

```bash
make verify
```
Phải xanh. Fix lint nhỏ nếu có.

### F2 — Manual smoke 3 user flow

Theo idea § 7:
- Flow B: clone Úloha 1 → toast → edit → verify draft + new title.
- Flow H: orphan exercise → badge ❌ → click row → modal → publish +
  regen audio → badges cập nhật.
- Flow C: open form → split layout (1440px) → switch type → preview
  cập nhật < 200ms → drawer test (1100px window).

### F3 — `make smoke-attempt-flow` không regress

```bash
make smoke-attempt-flow
make smoke-course-flow
```

(`smoke-exam-flow` pre-existing flake — log không cần fix V23.)

### F4 — CHANGELOG entry V23

Thêm `## V23 — Exercise Authoring Polish — <date>` đầu CHANGELOG (sau
heading), sau V22 entry. Gồm 3 task description + decisions + file
changes + final test counts.

### F5 — SPEC.md root digest row

```
| V23 | <date> | Exercise authoring polish — quick clone, validation badges, inline preview MVP | docs/specs/v23-exercise-authoring-polish.md |
```

### F6 — `tasks/{plan,todo}.md` index update

`tasks/plan.md` row V23 status → "✅ implemented (awaiting commit + manual smoke)".
`tasks/todo.md` link V23 status update.

### F7 — Spec status → Shipped

Sửa `docs/specs/v23-exercise-authoring-polish.md` § Status:
```
**Shipped <date>** (commit `<hash>`).
```

### F8 — `docs/architecture/current-code-shape.md`

Refresh: thêm V23 additions (validation_flags pattern, preview pane
convention, clone helper). 1-2 đoạn.

**Checkpoint F**:
- `make verify` xanh.
- 3 manual smoke pass.
- CHANGELOG + SPEC digest + tasks index + spec status + architecture
  doc landed.
- PR merge → main.

---

## Risk Matrix

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| H2 list response shape break existing CMS callers | LOW | MED | TS types extend `validation_flags?: ...` optional; existing callers ignore extra field |
| C1 `useMediaQuery` SSR mismatch | MED | LOW | Default isWide=true on server; hydrate post-mount; OR client-only via `'use client'` |
| C4-C6 renderer Flutter divergence | HIGH | LOW | Disclaimer band explicit; manual smoke plan stops admin assuming pixel-perfect |
| H1 refactor V22 aggregate breaks existing tests | MED | MED | Run V22 backend tests after H1; keep behavior identical (just extracted helper) |
| B clone race when audio gen not done | LOW | LOW | Clone always skips audio; no race possible |
| H6 modal ariaLive announce too aggressive | LOW | LOW | role="dialog" + aria-modal="true" only |
| C drawer overlay z-index conflict | LOW | LOW | Use existing `--z-modal` token (1000) |
| Top 5 type prompt shape differs from CMS form state | MED | MED | Renderer reads form state directly (not transformed); no API contract change |

---

## Smoke Plan

### Pre-deploy (staging)

| Flow | Steps | Pass criteria |
|---|---|---|
| **Flow B** | Mở /, find exercise → "Sao chép" → toast → click → edit form | Toast < 1s, click navigate, status=draft, title="Copy of …" |
| **Flow H** | Find row có ❌ badge → click row → modal → publish + audio regen | Modal hiện đúng flag list, submit trigger reload, badges cập nhật |
| **Flow C** | Mở form (≥1280) → split layout → switch type top 5 → see render | Preview render < 200ms, disclaimer visible, 11 type placeholder |
| **Flow C-mobile** | Resize <1280 → "Xem preview" button → drawer overlay | Drawer slide-in < 300ms, không reflow form |

### Post-deploy (production)

Repeat 3 flow chính trên production với 1 admin account.

---

## Verification Command Summary

| Phase | Command | Expected delta |
|---|---|---|
| A | `make backend-test` + `cd cms && npm test` | skip +5 |
| B | `cd cms && npm test` | cms +6 (190→196) |
| H | `make backend-test` + `cd cms && npm test` | be +13 (683→696), cms +14 (196→210) |
| C | `cd cms && npm test` | cms +6 (210→216) |
| F | `make verify` + `make smoke-{attempt,course}-flow` | tất cả xanh |

Total V23 test delta: backend +13, CMS +26.

Final state targets:
- Backend: **696** tests
- CMS: **216** tests in **14 files** (was 190 in 10)
- Flutter: 345 (no change)
- New files: 1 backend test + 5 CMS test + ~10 CMS component file
- Modified files: ~8 (server.go, admin_content_health.go, exercise-list.tsx, exercise-dashboard.tsx, exercise-utils.ts, etc.)

---

## Reference

- Spec: `docs/specs/v23-exercise-authoring-polish.md`
- Idea: `docs/ideas/v23-exercise-authoring-polish.md`
- V22 spec (content-health source): `docs/specs/v22-cms-catch-up.md`
- V22 plan (vertical-slice ref): `tasks/v22-cms-catch-up-plan.md`
- AGENTS.md § "Verification Expectations" + § "Documentation Convention"
