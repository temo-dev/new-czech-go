# Poslech 1 Image Options A-D (V27) — Spec

**Slice:** V27 — poslech_1 image_asset_id per option in CMS authoring
**Status:** Draft — chờ human approve trước khi sang plan
**Owner:** TBD
**Last updated:** 2026-05-09

Liên quan:
- Idea: [`docs/ideas/poslech-1-image-options.md`](../ideas/poslech-1-image-options.md)
- Plan: [`tasks/v27-poslech-1-image-options-plan.md`](../../tasks/v27-poslech-1-image-options-plan.md)
- Todo: [`tasks/v27-poslech-1-image-options-todo.md`](../../tasks/v27-poslech-1-image-options-todo.md)
- Reference: [`docs/reference/content-and-attempt-model.md`](../reference/content-and-attempt-model.md) § Listening
- Precedent: V11 media enrichment (`MultipleChoiceOption.ImageAssetID`); V26 per-item audio (`docs/specs/poslech-per-item-audio.md`)

---

## 1. Objective

Cho admin authoring poslech_1 với 4 image_asset_id per option qua
CMS. Backend + Flutter zero change — chỉ wire CMS field + validation.

**Out of scope:** poslech_2/3/4, file upload UX, seed image data,
backend, Flutter widget.

---

## 2. Quyết định đã chốt

| # | Quyết định | Lý do |
|---|---|---|
| D1 | poslech_1 only, không mở sang poslech_2 | Matches V26 scope discipline. poslech_2 cùng schema có thể clone sau |
| D2 | Text input cho `image_asset_id`, không file upload | Match V11 vocab `choice_word` pattern (`VocabGrammarFields.tsx:71`). File upload UX = slice riêng |
| D3 | Drafts allow partial state (1-3 ảnh OK) | Admin có thể save WIP. Publish gate validates |
| D4 | All-or-none rule per item: 4 ảnh hoặc 0 ảnh khi published | Mixed state khiến Flutter silent-fallback về text — UX broken. Validation gate publish-time |
| D5 | Backend không thay đổi | `MultipleChoiceOption.ImageAssetID` đã có V11 với `omitempty` — backward compat tự nhiên |
| D6 | Flutter không thay đổi | `MultipleChoiceWidget._allHaveImages` đã switch image grid khi đủ 4 |
| D7 | Empty `text` cho phép khi có image | Image-only options hợp lệ. Match real A2 exam 4 ảnh không text |
| D8 | Asset_id orphan fail-soft | `_LetterPlaceholder` errorBuilder đã có sẵn. Admin tự fix qua CMS |
| D9 | Validation message tiếng Việt | Match existing validation.ts conventions |
| D10 | No CHANGELOG-required test count regression | CMS test suite mở rộng từ 144 → ~146 |

---

## 3. Acceptance Criteria

### A. CMS PoslechFields shape

**A1.** `P12Item` type extends:
```ts
type P12Item = {
  question: string;
  text: string;
  optA: string; optB: string; optC: string; optD: string;
  imgA: string; imgB: string; imgC: string; imgD: string;  // NEW
  answer: string;
};
```

**A2.** `initState` reads `options[*].image_asset_id` from existing
exercise.detail; defaults empty if absent.

**A3.** `buildDetail` output emits options:
```json
[
  {"key": "A", "text": "...", "image_asset_id": "..."},
  ...
]
```
`image_asset_id` field omitted when string is empty (back-compat).

### B. CMS UI

**B1.** Per item, 4 input pairs render: 1 text input + 1
image_asset_id input per option key. Image input placeholder:
`"Asset ID ảnh A"` etc.

**B2.** Use `OptionRow` for text + sibling input for image_asset_id;
or extract small `OptionRowWithImage` component if cleaner.

### C. Validation

**C1.** `validation.ts` poslech_1 branch: per item, count options
with non-empty `image_asset_id`. If count ∈ {1, 2, 3} → error: "Câu
{N}: hoặc tất cả 4 đáp án có ảnh, hoặc không đáp án nào có ảnh
(không cho mixed)."

**C2.** Drafts skip rule. Published exercise enforces.

**C3.** All-empty (count=0) and all-set (count=4) both pass.

### D. Tests

**D1.** Round-trip: load detail with image_asset_ids → state has
imgA-D populated → buildDetail outputs same shape.

**D2.** Validation: count=2 returns error; count=0 OK; count=4 OK.

**D3.** Cross-pollution: poslech_2 (out of scope) state ignores
image_asset_id field.

### E. Docs

**E1.** Update `docs/reference/content-and-attempt-model.md` §
listening: poslech_1 entry mention image_asset_id per option since V27.

**E2.** CHANGELOG entry V27.

---

## 4. Wire shape changes

### Before (V26)

```json
{
  "exercise_type": "poslech_1",
  "detail": {
    "items": [
      {
        "question_no": 1,
        "options": [
          {"key": "A", "text": "V praci"},
          {"key": "B", "text": "Doma"},
          {"key": "C", "text": "V obchode"},
          {"key": "D", "text": "U lekare"}
        ]
      }
    ]
  }
}
```

### After (V27)

```json
{
  "exercise_type": "poslech_1",
  "detail": {
    "items": [
      {
        "question_no": 1,
        "options": [
          {"key": "A", "text": "V praci",   "image_asset_id": "media/items/q1-a.jpg"},
          {"key": "B", "text": "Doma",      "image_asset_id": "media/items/q1-b.jpg"},
          {"key": "C", "text": "V obchode", "image_asset_id": "media/items/q1-c.jpg"},
          {"key": "D", "text": "U lekare",  "image_asset_id": "media/items/q1-d.jpg"}
        ]
      }
    ]
  }
}
```

`image_asset_id` field optional + `omitempty` — exercise không có
ảnh wire shape giống V26.

---

## 5. Test plan

| Layer | Test |
|---|---|
| CMS unit | initState reads image_asset_id per option |
| CMS unit | buildDetail emits image_asset_id when set |
| CMS unit | buildDetail omits image_asset_id when empty |
| CMS unit | Round-trip: load → state → save → identical |
| CMS unit | Validation: 4 set → pass |
| CMS unit | Validation: 0 set → pass |
| CMS unit | Validation: 2/4 → error message |
| CMS unit | Validation: drafts skip rule |
| CMS unit | poslech_2 ignores image_asset_id (cross-pollution) |

---

## 6. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Admin paste sai asset_id → 404 | Flutter `_LetterPlaceholder` fail-soft đã có |
| Mixed state seep through draft → publish | Validation gate publish-time |
| poslech_1 với 4 image nhưng text trống không render | OK — `_LetterPlaceholder` shows letter; image grid still works |
| Existing seeds break | Backend `omitempty` + JSON-extra-fields tolerant. Empty image_asset_id = old behavior |
