# Spec: V23 Exercise Authoring Polish (CMS)

## Status
**Implemented 2026-05-08.** B + H + most of C complete. C8 live-wire
into the existing slide-over form deferred to V24 form-refactor
slice (boundary "no form monolith refactor" V23). `make verify`
green (backend 696, CMS 217, Flutter 345). Awaiting commit + manual
browser smoke before final ship. Pair files:

- Idea (pre-spec one-pager): `docs/ideas/v23-exercise-authoring-polish.md`
- Plan (TBD): `tasks/v23-exercise-authoring-polish-plan.md`
- Todo (TBD): `tasks/v23-exercise-authoring-polish-todo.md`

This spec **freezes on V23 ship**. Future changes (V24+) land in
that slice's spec + relevant `docs/reference/` updates, not here.

## Purpose

V22 đóng debug + content-health gap, nhưng exercise authoring vẫn
chậm. Form 1361 LOC + audio gen per-button + zero learner-side preview
= chu kỳ tạo bài tập tốn nhiều click + publish-rồi-test. Volume <50
hiện tại tăng nhanh khi seed → cần tools trước khi pain leo thang.

V23 ship 3 vertical:

- **B Quick-Clone** — row action "Sao chép" tăng tốc seed bài tương tự (4 Úloha 1 chủ đề khác, 5 cteni đoạn văn).
- **H Validation Inline Badges** — list response gắn `validation_flags`; CMS hiện ✓/⚠/❌ inline; mini fix modal cho publish + regen audio (strict scope V23).
- **C Inline Preview Pane MVP** — side-pane render mock learner UI cho top 5 type (uloha_1-4 + psani_2_email). Static HTML, low-fidelity, disclaimer rõ.

Đây **không phải**:
- Form monolith refactor (variation A defer V24+).
- 3 list view consolidation (variation D defer V24+).
- Bulk action bar (variation E defer khi >150 exercises).
- Authoring wizard (variation G — parallel path = nợ kỹ thuật).
- Versioning / draft history (defer V25+).
- Full Flutter preview / pixel-perfect render.

Volume baseline khi spec frozen: **<50 exercises**. Pareto pain ở
authoring speed + quality safeguard, không phải scale.

## Current Implementation Snapshot

Recon 2026-05-07. Mục đích: ghim state đã có.

### Backend đã có

| Asset | File | Ghi chú |
|---|---|---|
| `GET /v1/admin/exercises` list | `httpapi/server.go:2050` | trả `s.repo.ListExercises(pool)`, không có flags |
| `POST /v1/admin/exercises` create | same line 2055 | flat field list — accept clone payload |
| `GET /v1/admin/exercises/:id` detail | `httpapi/server.go:2122` | có |
| `PATCH /v1/admin/exercises/:id` update | same | có |
| `POST /v1/admin/exercises/:id/generate-audio` | `httpapi/server.go:1308` | **đã có** — H reuse |
| Module + Course store helpers | `store/memory.go` | `ModuleByID`, `ListModules` |
| V22 content-health checks | `httpapi/admin_content_health.go` | shared logic source — H DRY |
| Exercise audio store | `store/exercise_audio_store.go` | `ExerciseAudioByExercise(id)` |
| Sentence audio store | `store/exercise_sentence_audio_store.go` | `SentenceAudiosByExercise(id)` |

### Backend còn thiếu (V23 phải build)

- Extend `GET /v1/admin/exercises` response: thêm `validation_flags` per row (5 rule).
- Helper extract content-health logic per-exercise (từ V22 aggregate xuống per-row check) cho code reuse.

### CMS đã có

| Asset | File | Ghi chú |
|---|---|---|
| Exercise list view | `cms/components/exercise-list.tsx` (506 LOC) | filter + row actions [Sửa] [Xóa] |
| Exercise dashboard | `exercise-dashboard.tsx` (381 LOC) | duplicate UI, defer V24 |
| Exercise matrix | `exercise-matrix.tsx` (455 LOC) | duplicate UI, defer V24 |
| Exercise form monolith | `exercise-form/index.tsx` (1361 LOC) | edit/create form |
| Exercise utils | `exercise-utils.ts` (1229 LOC) | shared types + helpers |
| Per-skill sub-fields | `exercise-form/{Speaking,Writing,...}Fields.tsx` | wired vào index.tsx |
| List filter | exercise-list.tsx line 200-257 | course/module/skill/mock/text filters |

### CMS còn thiếu (V23 phải build)

- B: row action "Sao chép" + helper `cloneExercisePayload(source)`.
- H: badge cluster column + click-row → quick fix modal + filter "Chỉ hiện vấn đề".
- C: split layout + 5 type renderer + side-pane drawer < 1280px.

### Hệ quả cho scope

| Task | Đã có | V23 cần build |
|---|---|---|
| **B Quick-Clone** | 0% | helper + button + toast |
| **H Validation Inline** | 50% (V22 logic reusable + generate-audio endpoint) | extend list response + UI badge + modal |
| **C Inline Preview** | 0% | layout + 5 renderer + drawer responsive |

## Out of Scope (V23)

| Bỏ ra | Lý do | Khi quay lại |
|---|---|---|
| Form monolith split (variation A) | Code health, không user-facing | V24 form-refactor slice |
| 3 list view consolidation (D) | Code health, không user-facing | V24 |
| Bulk action bar (E) | Premature ở <50 exercises | Khi >150 |
| Smart filter chips (F) | List filter hiện đủ với <50 | Khi >150 |
| Authoring wizard (G) | Parallel path = nợ kỹ thuật | Never trừ khi A done |
| Audio regen status pill (I) | Fold vào H modal | V24 nếu cần |
| 11 type render khác trong preview | Top 5 cover ≥80% authoring | V24 +5 type, V25 hết |
| Versioning / draft history | Out-of-scope V23 | V25+ |
| Edit field khác trong fix modal (module, sample, etc.) | Strict V23 — full edit qua form thường | V24+ |
| Auto async audio gen khi clone | Skip → admin click regen sau (đơn giản hơn) | Khi authoring volume tăng |
| Copy audio metadata khi clone | Risk prompt-audio mismatch | Never |
| Pixel-perfect Flutter render | Defer | V25+ nếu cần |

## Schema

**Không thêm/sửa cột.** V23 thuần đọc + 1 endpoint extension. Validation flags compute on-the-fly từ join của `exercises × exercise_audio × exercise_sentence_audio × modules`.

Cột đọc:
- `exercises(id, pool, module_id, skill_kind, exercise_type, title, sample_answer_enabled, sample_answer_text, status, ...)`
- `exercise_audio(exercise_id, ...)` — has-row check
- `exercise_sentence_audio(exercise_id, ...)` — has-row check
- `modules(id, course_id, title, ...)`

## Backend Changes

### B-API. Không thay đổi
B thuần client-side: CMS fetch source + transform + POST. Không cần endpoint mới.

### H-API. Extend `GET /v1/admin/exercises`

Mỗi row trong response thêm field `validation_flags`:

```json
{
  "data": [
    {
      "id": "ex_...",
      "title": "...",
      "skill_kind": "nghe",
      "pool": "course",
      "module_id": "mod_...",
      "exercise_type": "poslech_1",
      "status": "draft",
      "...": "...",
      "validation_flags": {
        "missing_audio": false,
        "missing_sentence_audio": false,
        "orphan": false,
        "missing_sample": false,
        "unpublished": true
      }
    }
  ],
  "meta": {}
}
```

5 flag rule (compute server-side):

| Flag | Rule |
|---|---|
| `missing_audio` | `skill_kind=nghe && !ExerciseAudioByExercise(id)` |
| `missing_sentence_audio` | `exercise_type='psani_3_dictation' && len(SentenceAudiosByExercise(id))==0` |
| `orphan` | `pool='course' && (module_id=='' \|\| module_id is null)` |
| `missing_sample` | `skill_kind ∈ {noi, viet} && sample_answer_enabled && trim(sample_answer_text)==''` |
| `unpublished` | `status=='draft'` |

Implementation:
- Helper `computeValidationFlags(s.repo, ex contracts.Exercise) ValidationFlags` trong `httpapi/admin_content_health.go` (DRY với V22 aggregate logic).
- Handler `handleAdminExercises` GET case lặp `s.repo.ListExercises(pool)`, kèm flag mỗi row trước writeJSON.

Performance: 5 lookup × N exercises. Với N=50 = 250 lookup memory backend → < 50ms. Postgres N=1000 → ~5000 lookup → vượt p95 500ms NFR. **V23 chấp nhận**: scale hiện <50 nên OK; defer N+1 fix sang V24 nếu volume tăng.

### Reuse `POST /v1/admin/exercises/:id/generate-audio`
H quick fix modal "Tạo lại audio" call endpoint sẵn có line 1308. Không thay đổi.

### Backward compat
Existing CMS callers chưa biết `validation_flags` → bỏ qua field thừa (JSON serializer của TypeScript ignore unknown). Không break.

## CMS Changes

### B-1. Helper `cloneExercisePayload(source: Exercise): CreatePayload`
**File**: `cms/components/exercise-utils.ts` (extend)

Pure function:
```ts
export function cloneExercisePayload(src: Exercise): CreatePayload {
  return {
    // Identity-stripped fields
    title: `Copy of ${src.title}`,
    status: 'draft',
    // Preserved fields
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
    assets: src.assets,  // share asset_id
    detail: src.detail,
    // Skipped: id, exercise_audio (regen separately), sequence_no (backend assigns)
  };
}
```

Test coverage: title prefix, status='draft', preserved + stripped fields, missing optional fields.

### B-2. Row action "Sao chép"
**File**: `cms/components/exercise-list.tsx` (extend)

Cạnh nút [Sửa] [Xóa] thêm [Sao chép]. Click → fetch + POST → toast.

```tsx
async function handleClone(source: Exercise) {
  setCloning(source.id);
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
    showToast({
      kind: 'success',
      message: `Đã tạo ${created.id} (draft). Click để sửa.`,
      onClick: () => router.push(`/exercises/${created.id}/edit`),
    });
    await fetchList();
  } catch (err) {
    showToast({ kind: 'error', message: err.message, retry: () => handleClone(source) });
  } finally {
    setCloning(null);
  }
}
```

### H-1. Badge cluster column
**File**: `exercise-list.tsx` (extend) + new helper `cms/components/validation-badges.ts`

Helper:
```ts
export type ValidationFlags = {
  missing_audio: boolean;
  missing_sentence_audio: boolean;
  orphan: boolean;
  missing_sample: boolean;
  unpublished: boolean;
};

export type BadgeSpec = {
  variant: 'error' | 'warning' | 'neutral' | 'ready';
  icon: '❌' | '⚠' | '📝' | '✓';
  label: string;
  tooltip: string;
};

export function flagsToBadges(flags: ValidationFlags | undefined): BadgeSpec[] {
  if (!flags) return [];
  const out: BadgeSpec[] = [];
  if (flags.orphan) out.push({ variant: 'error', icon: '❌', label: 'Mồ côi', tooltip: 'pool=course nhưng chưa gán module' });
  if (flags.missing_audio) out.push({ variant: 'error', icon: '❌', label: 'Thiếu audio', tooltip: 'skill=nghe nhưng chưa có exercise_audio' });
  if (flags.missing_sentence_audio) out.push({ variant: 'error', icon: '❌', label: 'Thiếu sentence audio', tooltip: 'dictation chưa có per-sentence audio' });
  if (flags.missing_sample) out.push({ variant: 'warning', icon: '⚠', label: 'Thiếu sample', tooltip: 'sample_answer_enabled nhưng text rỗng' });
  if (flags.unpublished) out.push({ variant: 'neutral', icon: '📝', label: 'Draft', tooltip: 'chưa publish' });
  if (out.length === 0) out.push({ variant: 'ready', icon: '✓', label: 'Sẵn sàng', tooltip: 'Tất cả check pass' });
  return out;
}

export function hasAnyIssue(flags: ValidationFlags | undefined): boolean {
  if (!flags) return false;
  return flags.orphan || flags.missing_audio || flags.missing_sentence_audio
    || flags.missing_sample;
  // unpublished không tính là "vấn đề" — chỉ là trạng thái
}
```

List render thêm column "Tình trạng" với cluster up to 4 badge inline.

### H-2. Filter "Chỉ hiện vấn đề"
**File**: `exercise-list.tsx` (extend)

Checkbox cạnh filter dropdowns. State `problemOnly: boolean`. Filter `items` bằng `hasAnyIssue(item.validation_flags)` khi true.

### H-3. Quick fix modal
**File**: `cms/components/exercise-quick-fix-modal.tsx` (new)

Open by clicking row (not buttons trong row). Reuse modal frame `ConfirmResetUsage` style.

Strict V23 scope:
- Tình trạng: list badge readonly từ flags
- Trạng thái radio: Draft / Published — submit gọi `PATCH /api/admin/exercises/:id` với `{status}`
- "Tạo lại audio" button: chỉ enable khi `skill_kind ∈ {nghe}` hoặc `exercise_type === 'psani_3_dictation'`. Submit gọi `POST /api/admin/exercises/:id/generate-audio`.
- Link "→ Mở form đầy đủ" navigate `/exercises/[id]/edit`.

**KHÔNG có** field gán module, sample text, edit khác. Strict.

### C-1. Split layout component
**File**: `cms/components/exercise-edit-layout.tsx` (new) — wrap form route.

```tsx
export function ExerciseEditLayout({ children, exercise }: Props) {
  const isWide = useMediaQuery('(min-width: 1280px)');
  const [drawerOpen, setDrawerOpen] = useState(false);
  if (isWide) {
    return (
      <div className="grid-60-40">
        <div>{children}</div>
        <PreviewPane exercise={exercise} />
      </div>
    );
  }
  return (
    <>
      <button onClick={() => setDrawerOpen(true)}>Xem preview</button>
      <div>{children}</div>
      {drawerOpen && <PreviewDrawer onClose={() => setDrawerOpen(false)} exercise={exercise} />}
    </>
  );
}
```

### C-2. Preview renderers
**File**: `cms/components/exercise-preview/{UlohaPreview,PsaniEmailPreview,Placeholder,index}.tsx`

Top 5 V23: `uloha_1_topic_answers`, `uloha_2_dialogue_questions`, `uloha_3_story_narration`, `uloha_4_choice_reasoning`, `psani_2_email`.

`<PreviewPane>` switch trên `exercise_type`:
```tsx
switch (type) {
  case 'uloha_1_topic_answers': return <UlohaPreview variant="1" form={form} />;
  case 'uloha_2_dialogue_questions': return <UlohaPreview variant="2" form={form} />;
  case 'uloha_3_story_narration': return <UlohaPreview variant="3" form={form} />;
  case 'uloha_4_choice_reasoning': return <UlohaPreview variant="4" form={form} />;
  case 'psani_2_email': return <PsaniEmailPreview form={form} />;
  default: return <PreviewPlaceholder type={type} />;
}
```

Mỗi renderer ~120-150 LOC. Render mock card với prompt + duration + asset preview. **Không interactive** — không play audio, không tap, button disabled.

### C-3. Disclaimer band
Always-visible top bar trên preview pane:
```
🔍 Preview low-fidelity. Hãy test trên Flutter trước khi ship.
```
Style: `var(--preview-disclaimer)` — text `#7c4a03` on `#fff8d6`, border-left 4px solid `#facc15`.

### C-4. Debounce form change
Hook `useDebouncedForm(form, 200)` → preview render từ debounced state. Tránh re-render mỗi keystroke.

## UI/UX

Wireframe + design tokens chi tiết: `docs/ideas/v23-exercise-authoring-polish.md` § 6. Spec không lặp lại. Nếu mâu thuẫn, **spec authoritative**.

Delta so với idea:
- Top 5 type confirmed: **uloha_1, uloha_2, uloha_3, uloha_4, psani_2_email** (idea ban đầu cteni_1 → đổi thành psani_2_email per user pick).
- Quick fix modal scope strict (không gán module inline).
- Drawer 1024-1279 = overlay (không push form).
- Preview a11y: `aria-hidden="true"` trên preview pane (visual aid only).

Color contrast verify:
- `--preview-disclaimer` text `#7c4a03` on `#fff8d6` ≈ 6.2:1 ✓ (WCAG AA Large + Small)
- Badge cluster icons có cả symbol + label, không color-only.

## Testing Strategy

### Backend (Go)

| File mới/extend | Cases | Total |
|---|---|---|
| `httpapi/admin_content_health.go` extend (`computeValidationFlags`) | 5 rule × 2 case (positive/negative) = 10 | 10 |
| `httpapi/admin_exercises_test.go` (new) | list response shape with flags / no flags when not admin / pool filter still works | 3 |

Total backend +13.

### CMS (Vitest pure helpers)

| File mới | Cases |
|---|---|
| `__tests__/exercise-clone.test.ts` | cloneExercisePayload — 6 cases (title prefix / status draft / preserved fields / stripped id / missing sample / share assets) |
| `__tests__/validation-badges.test.ts` | flagsToBadges — 7 cases (each flag, all-clean, multiple combo) + hasAnyIssue 3 cases |
| `__tests__/exercise-quick-fix.test.ts` | modal state machine — 4 cases (open/close, audio button enable rule, status submit, audio retry) |
| `__tests__/preview-routing.test.ts` | type switch — 6 cases (5 supported + 1 placeholder) |

Total CMS +26.

### Smoke
- `make smoke-attempt-flow` không regress.
- Manual smoke browser: clone 1 exercise + fix modal + open preview pane.

### CI gate
`make verify` xanh trước merge.

## Acceptance Criteria

### B — Quick-Clone
- [ ] Click "Sao chép" tạo new draft trong < 1s.
- [ ] Title = `"Copy of " + source.title`.
- [ ] Status = "draft", new ID.
- [ ] Module/skill/type/prompt/assets giữ nguyên.
- [ ] `exercise_audio` row không clone.
- [ ] Toast click navigate edit form bài mới.
- [ ] Source 404 → toast error + retry option.
- [ ] Backend test 0 (B thuần CMS-side).
- [ ] CMS test 6 cases pass.

### H — Validation Inline
- [ ] List response mỗi row có `validation_flags`.
- [ ] 5 rule compute đúng (10 backend test).
- [ ] Badge cluster render đúng combo (test all 32 combinations qua hasAnyIssue + flagsToBadges).
- [ ] Filter "Chỉ hiện vấn đề" lọc đúng (skip unpublished-only rows).
- [ ] Quick fix modal: publish/unpublish hoạt động.
- [ ] "Tạo lại audio" button enable đúng (skill=nghe || exercise_type=psani_3_dictation).
- [ ] Modal close → list reload, badges cập nhật.
- [ ] Backend test 13 + CMS test 10 pass.

### C — Inline Preview
- [ ] Width ≥ 1280 → split 60/40 default.
- [ ] Width < 1280 → form full + button "Xem preview" → drawer overlay.
- [ ] Top 5 type render mock card đúng prompt + duration + asset.
- [ ] 11 type khác → placeholder "chưa hỗ trợ V23".
- [ ] Disclaimer band always visible.
- [ ] Debounce 200ms khi form change.
- [ ] Empty state khi form trắng.
- [ ] CMS test 10 pass.

### Slice-level
- [ ] `make verify` xanh.
- [ ] V22 content-health logic reused (no duplicate per-rule code).
- [ ] CHANGELOG entry V23.
- [ ] SPEC.md root + 1 dòng digest.
- [ ] No backend regression in existing tests.

## Boundaries

### Always do
- Mọi route mới: gate `withRole("admin")` backend (V23 không thêm route, chỉ extend).
- Reuse design token CSS variables + V22 modal pattern (`ConfirmResetUsage`).
- VI inline strings cho form-field components (per AGENTS.md).
- Backend test bắt buộc cho mọi check rule mới (≥2 cases per rule).
- Test pure helper trên CMS (không component render — match V22 pattern).
- DRY: H reuse V22 content-health helpers.

### Ask first
- Bất kỳ DB column / migration mới (V23 không cần).
- Mở rộng scope từ 3 task → 4+.
- Thêm renderer cho exercise type ngoài top 5.
- Thêm action ngoài publish + audio trong fix modal.
- Đổi clone audio policy.

### Never do
- Edit field khác trong fix modal V23 (gán module, sample text, etc.).
- Pixel-perfect Flutter render trong preview.
- Bulk action (clone/publish/delete N) V23.
- DB migration mới trong slice này.
- Inline LLM prompt strings hoặc model IDs ngoài `processing/llm_*.go`.
- Skip backend test cho validation_flags rule.
- Backfill spec sau khi frozen on ship.
- Tạo file root mới (≠ 5 file đã có).
- Inline slice content vào SPEC.md root.

## Rollout

| Step | Hành động |
|---|---|
| 1 | Plan + todo: `tasks/v23-exercise-authoring-polish-{plan,todo}.md`. |
| 2 | Backend PR: extend list response + 13 test. `make backend-test` xanh. |
| 3 | Backend deploy staging. Manual `curl` verify list response shape. |
| 4 | CMS PR: 3 task vertical (B → H → C) + 26 test. `make cms-{lint,build}` + `npm test` xanh. |
| 5 | CMS deploy staging. Manual smoke 3 user flow (idea § 7). |
| 6 | Production deploy đồng thời. |
| 7 | CHANGELOG entry V23 + SPEC.md digest row + spec status → "Shipped". |

**Không cần**: env var mới, feature flag, migration, data backfill.

## Open Questions Resolved (recon 2026-05-07 + user picks)

| # | Câu hỏi (idea § 9) | Resolution |
|---|---|---|
| OQ-1 | Backend list shape inline vs separate? | **Inline** — thêm `validation_flags` mỗi row (recommended). Payload tăng nhẹ, BE single endpoint. |
| OQ-2 | Clone audio policy? | **Skip hoàn toàn** (user pick). Admin click "Tạo lại audio" qua endpoint sẵn có. |
| OQ-3 | Top 5 type cho preview? | **uloha_1, uloha_2, uloha_3, uloha_4, psani_2_email** (user pick — cover speaking 100% + writing). |
| OQ-4 | Quick fix modal scope? | **Strict V23**: chỉ publish/unpublish + regen audio (user pick). Edit field khác qua form thường. |
| OQ-5 | Preview accessibility? | `aria-hidden="true"` trên preview pane (visual aid only). |
| OQ-6 | Drawer 1024-1279? | **Overlay** — đơn giản hơn push, không reflow form. |

## References

- Idea: `docs/ideas/v23-exercise-authoring-polish.md`
- V22 spec (content-health logic source): `docs/specs/v22-cms-catch-up.md`
- V22 idea: `docs/ideas/v22-cms-catch-up.md` (variation B/C/H/E/F/G origin)
- Backend exercise handler: `backend/internal/httpapi/server.go:2050`
- Existing audio gen: `backend/internal/httpapi/server.go:1308`
- V22 health rules: `backend/internal/httpapi/admin_content_health.go`
- CMS exercise list: `cms/components/exercise-list.tsx`
- CMS exercise utils: `cms/components/exercise-utils.ts`
- AGENTS.md § "Documentation Convention" — slice doc lifecycle
- AGENTS.md § "Verification Expectations" — `make verify` gate

## Frozen on Ship

Khi V23 ship:
1. Status section → **Shipped <date> (commit <hash>)**.
2. CHANGELOG.md có entry V23.
3. SPEC.md root +1 dòng digest.
4. Spec không sửa nữa. Mọi thay đổi V24+ land trong slice mới
   + `docs/reference/` nếu là contract chung.
