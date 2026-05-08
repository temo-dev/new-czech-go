# Exercise Draft Generator — UX

**Pair with**: [exercise-draft-generator.md](exercise-draft-generator.md)
**Decided**: 2026-05-08
**Surface**: CMS admin desk (Next.js)
**MVP skill**: `doc` only (cteni 1-6)

## Decisions (locked)

| Question | Decision |
|---|---|
| Surface | Inline panel at top of `exercise-form/ReadingFields.tsx` |
| Grammar input | Free text + autocomplete from `grammar_rules` table |
| Preview | None — direct fill into form fields |
| Retry | Edit-prompt + Regenerate (no diff, no variant picker) |

## User Flow

```
[Admin opens "New Reading Exercise" page in CMS]
              │
              ▼
[Picks exercise_type: cteni_1 / cteni_2 / ... / cteni_6]
              │
              ▼
[AI Draft Panel appears collapsed at top of form]
              │
        ┌─────┴─────┐
        │           │
   Skip AI       Use AI
   (manual)       │
        │         ▼
        │   [Expand panel]
        │         │
        │         ▼
        │   [Fill: topic, grammar (autocomplete), level (A2/B1)]
        │         │
        │         ▼
        │   [Click "Generate draft"]
        │         │
        │         ▼
        │   [Loading state ~5-10s — skeleton on form fields below]
        │         │
        │    ┌────┴────┐
        │    │         │
        │  Success    Fail
        │    │         │
        │    │         ▼
        │    │   [Inline error banner + Retry]
        │    │         │
        │    ▼         │
        │  [Form fields auto-filled]
        │  [Panel collapses, shows green chip "AI-drafted · regenerate"]
        │         │
        │         ├─── Admin satisfied → edit + Save ──┐
        │         │                                     │
        │         └─── Not satisfied → expand panel    │
        │                  │                            │
        │                  ▼                            │
        │            [Edit topic/grammar/level]         │
        │            [+ optional refinement note]       │
        │                  │                            │
        │                  ▼                            │
        │            [Regenerate → overwrites fields]  │
        │                                               │
        ▼                                               │
   [Manual fill all fields]                            │
        │                                               │
        └────────────────┬──────────────────────────────┘
                         ▼
                  [Click Save]
                         │
                         ▼
              [POST /v1/admin/exercises]
              [exercises.created_by_llm=true if AI used]
```

## Inline Panel Design

### Collapsed (default for AI users) / Initial state

```
┌─────────────────────────────────────────────────────────────┐
│  ✨ Tạo nháp bằng AI                              [Mở rộng ▾]│
│  Nhập chủ đề + ngữ pháp, AI sinh đoạn văn + câu hỏi cho bạn.│
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  Nội dung bài đọc                                            │
│  ┌──────────────────────────────────────────────────────┐    │
│  │ (đoạn văn — empty)                                    │    │
│  └──────────────────────────────────────────────────────┘    │
│  ...
```

### Expanded — input mode

```
┌─────────────────────────────────────────────────────────────┐
│  ✨ Tạo nháp bằng AI                              [Thu gọn ▴]│
│                                                              │
│  Chủ đề *                                                    │
│  ┌──────────────────────────────────────────────────────┐    │
│  │ ví dụ: đi khám bác sĩ, mua hàng ở chợ, du lịch Praha │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                              │
│  Điểm ngữ pháp *  (1-3)                                      │
│  ┌──────────────────────────────────────────────────────┐    │
│  │ minulý čas ✕  pády (akuzativ) ✕                       │    │
│  └──────────────────────────────────────────────────────┘    │
│  ↳ Gợi ý: minulý čas dokonavých sloves · 7 pádů · ...       │
│                                                              │
│  Cấp độ *                                                    │
│  ( ) A0   ( ) A1   (●) A2   ( ) B1                          │
│                                                              │
│  Hướng dẫn thêm (tùy chọn)                                   │
│  ┌──────────────────────────────────────────────────────┐    │
│  │ ví dụ: dùng giọng văn thân mật, có 2 nhân vật...      │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                              │
│                                  [Hủy]  [✨ Sinh nháp]       │
└─────────────────────────────────────────────────────────────┘
```

### Loading state

```
┌─────────────────────────────────────────────────────────────┐
│  ✨ AI đang sinh nội dung... (~10 giây)                      │
│  ▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  35%    │
│  [Hủy]                                                       │
└─────────────────────────────────────────────────────────────┘

[Form fields below show skeleton shimmer]
┌─────────────────────────────────────────────────────────────┐
│  Nội dung bài đọc                                            │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓   │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓   │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓                            │
└─────────────────────────────────────────────────────────────┘
```

### Filled state (after success)

```
┌─────────────────────────────────────────────────────────────┐
│  ✨ Nháp AI · "đi khám bác sĩ" · A2  [Tạo lại]  [Mở rộng ▾] │
└─────────────────────────────────────────────────────────────┘

[Form fields filled with AI content, fully editable]
┌─────────────────────────────────────────────────────────────┐
│  Nội dung bài đọc                                            │
│  ┌──────────────────────────────────────────────────────┐    │
│  │ Pavel byl nemocný a šel k lékaři. Lékař se ho zeptal,│    │
│  │ co ho bolí. Pavel řekl, že ho bolí hlava a v krku... │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                              │
│  Câu hỏi 1                                                   │
│  ┌──────────────────────────────────────────────────────┐    │
│  │ Kam šel Pavel?                                        │    │
│  └──────────────────────────────────────────────────────┘    │
│  ...
```

### Error state

```
┌─────────────────────────────────────────────────────────────┐
│  ⚠️ Sinh nháp thất bại                                       │
│  Schema không khớp loại bài cteni_3. Thử lại hoặc đổi đề.   │
│                                          [Thu gọn]  [Thử lại]│
└─────────────────────────────────────────────────────────────┘
```

### Regenerate confirmation (when fields already have content)

```
┌─────────────────────────────────────────────────────────────┐
│  Ghi đè nội dung hiện tại?                                   │
│  Đoạn văn và 4 câu hỏi đã có sẽ bị thay thế. Không thể hoàn │
│  tác.                                                        │
│                                  [Hủy]  [Ghi đè & Tạo lại]   │
└─────────────────────────────────────────────────────────────┘
```

## Components Needed

| Component | Path | New? | Notes |
|---|---|---|---|
| `AiDraftPanel` | `cms/components/ai-draft/AiDraftPanel.tsx` | ✅ New | Top-level container; collapsible |
| `GrammarPointPicker` | `cms/components/ai-draft/GrammarPointPicker.tsx` | ✅ New | Free text + autocomplete from `/v1/admin/grammar-rules` |
| `LevelRadio` | `cms/components/ai-draft/LevelRadio.tsx` | ✅ New | A0/A1/A2/B1 radio group |
| `useGenerateDraft` hook | `cms/hooks/useGenerateDraft.ts` | ✅ New | POST `/v1/admin/exercises/generate-draft`, returns `{data, isLoading, error, regenerate}` |
| `ReadingFields` | `cms/components/exercise-form/ReadingFields.tsx` | 🔧 Modify | Add `<AiDraftPanel onApply={fillForm} />` at top |
| `Skeleton` | shadcn or existing | Reuse | Form field skeletons during loading |
| Toast | existing | Reuse | Success "Đã tạo nháp" / Error |

## States (state machine)

```
idle ──[click Generate]──▶ loading
loading ──[200 OK]──▶ filled
loading ──[error]──▶ error
loading ──[click Cancel]──▶ idle
filled ──[click Regenerate, fields empty]──▶ loading
filled ──[click Regenerate, fields dirty]──▶ confirm-overwrite
confirm-overwrite ──[Confirm]──▶ loading
confirm-overwrite ──[Cancel]──▶ filled
error ──[click Retry]──▶ loading
```

## Validation Rules (client-side)

- `topic`: required, 3-200 chars
- `grammar_points`: required, 1-3 items
- `level`: required, enum
- `extra_instructions`: optional, max 500 chars
- Disable "Sinh nháp" button until topic + ≥1 grammar + level all set

## Loading & Performance

- LLM call ~5-10s. Show indeterminate progress with elapsed-seconds counter ("đang sinh... 7s").
- Cancel button on AbortController — fetch supports cancellation.
- Skeleton matches actual form field layout (avoid CLS).
- After fill: smooth scroll to first filled field, focus it for immediate edit.

## Accessibility

- Panel = `<section aria-label="Tạo nháp bằng AI">`.
- Grammar combobox = WAI-ARIA combobox pattern with `aria-expanded`, `aria-activedescendant`.
- Loading = `aria-live="polite"` announcing "AI đang sinh nội dung".
- Error = `role="alert"`.
- "Sinh nháp" button announces loading state via `aria-busy`.
- Tab order: topic → grammar → level → extra → Generate.
- Confirm dialog returns focus to "Tạo lại" button on dismiss.

## Empty / Edge Cases

| Case | UX |
|---|---|
| `grammar_rules` table empty | Combobox falls back to free text. Show inline hint "Chưa có grammar trong DB — nhập tự do". |
| Network timeout (>30s) | Auto-cancel, show retry banner. |
| 422 schema mismatch | Error banner: "AI trả output sai cho cteni_X. Thử lại hoặc liên hệ tech." |
| 429 rate limit | Disable Generate for 60s with countdown chip. |
| Admin clicks Save while loading | Disable Save button while `isLoading=true`. |
| Admin closes form during generation | Cancel request via AbortController. No DB write. |
| Field already manually edited before AI | First Generate → confirm-overwrite dialog (same as Regenerate). |

## Visual Style (CMS conventions)

- Reuse existing CMS Tailwind tokens. No new design language.
- Panel background: `bg-violet-50` (light) / `bg-violet-950/30` (dark) — distinguish from regular form.
- AI accent icon: `Sparkles` from lucide-react (already in CMS deps — verify before adding).
- Primary CTA "Sinh nháp": `bg-violet-600 hover:bg-violet-700` — visually distinct from form's neutral Save button.
- Filled chip: `bg-emerald-100 text-emerald-900` with `Sparkles` icon.

## Anti-patterns (don't do)

- ❌ Modal overlay (rejected by user — inline preferred)
- ❌ Side-by-side preview pane (no preview decided)
- ❌ Variant picker (3 drafts × cost, marginal value)
- ❌ Auto-save AI draft as separate exercise (clutters DB; admin must Save)
- ❌ Hide AI panel after first use (re-discoverable, regenerate is common)
- ❌ Block manual editing while AI panel expanded (admin should be able to mix)
- ❌ Emoji as state icons in production (use lucide `Sparkles`, `AlertCircle`, `Loader2`)
- ❌ Show raw JSON to admin on schema error (translate to friendly message)

## Out of scope (V1 UX)

- Bulk module generator UI (separate slice)
- AI generator for `viet`/`nghe`/`noi` (separate slices, may reuse `AiDraftPanel` shell)
- Variant comparison view
- Audit log of all AI generations (analytics on `created_by_llm` column only)
- Inline grammar/level second-pass quality check (offline test only per idea note)

## Open UX questions

- Should "extra instructions" persist across regenerate, or clear each time? (Probably persist within session, clear on form unmount.)
- Where to surface `created_by_llm=true` in CMS list view? (Filter chip + small ✨ icon next to title.)
- Mobile/tablet support for CMS? (Out of scope — CMS is desktop-first per current design.)
