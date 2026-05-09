# Poslech 1 AI Image Generate per option (V28) — Spec

**Slice:** V28 — Wire AiImageButton into PoslechFields per option for poslech_1
**Status:** Draft — chờ human approve trước khi sang plan
**Owner:** TBD
**Last updated:** 2026-05-10

Liên quan:
- Idea: [`docs/ideas/poslech-1-image-ai-generate.md`](../ideas/poslech-1-image-ai-generate.md)
- Plan: [`tasks/v28-poslech-1-image-ai-generate-plan.md`](../../tasks/v28-poslech-1-image-ai-generate-plan.md)
- Todo: [`tasks/v28-poslech-1-image-ai-generate-todo.md`](../../tasks/v28-poslech-1-image-ai-generate-todo.md)
- Reference: V27 `docs/specs/poslech-1-image-options.md` (image_asset_id wire)
- Precedent: `docs/ideas/ai-image-generation.md` + V11+ `<AiImageButton>` (4 existing wire sites)

---

## 1. Objective

Cho admin generate ảnh AI per A-D option của poslech_1 trực tiếp
trong PoslechFields, không phải upload thủ công ngoài CMS rồi paste
asset_id.

**Out of scope:** poslech_2/3/4/5, backend endpoint changes, Flutter,
bulk generate UX, prompt template auto-fill.

---

## 2. Quyết định đã chốt

| # | Quyết định | Lý do |
|---|---|---|
| D1 | poslech_1 only | Match V27 scope. poslech_2 P12State shared nhưng V27/V28 chỉ enforce poslech_1 publish gate |
| D2 | `<AiImageButton>` inline per option, không modal | Match existing 4 wire sites (exercise-form context, cteni_1 per item) |
| D3 | `existingAssetId={imgK}` để toggle label "Tạo lại bằng AI" vs "Tạo bằng AI" | UX consistency với CteniFields |
| D4 | `onAssetCreated(result)` → patch `state.items[i].img{K} = result.assetId` | Sync state, trigger buildPoslechDetail emit `image_asset_id` |
| D5 | Disabled khi `editingId == null` (chưa save bài) | Match existing pattern, AiImageButton title prop hiện hint |
| D6 | Backend không thay đổi | `/api/admin/ai/generate-image` đã ship |
| D7 | Flutter không thay đổi | image_asset_id wire shape giống V27 |
| D8 | 4 prompt độc lập per option (1 generate call per click) | Bulk feature defer slice sau |
| D9 | Không auto-fill prompt từ optK text | Admin tự viết EN prompt, Flux EN tốt hơn |
| D10 | UI density: 4 idle buttons / item OK vì collapsible | Panel chỉ open khi click |

---

## 3. Acceptance Criteria

### A. CMS PoslechFields wire

**A1.** Trong P12 branch (poslech_1/2), per option key K ∈ {A,B,C,D}
render thêm `<AiImageButton>` ngay sau `<input>` text asset_id.

**A2.** Props:
- `existingAssetId={item[`img${K}`]}` (V27 imgA-D field)
- `disabled={!editingId}` (chưa save bài thì block)
- `onAssetCreated={(result) => patch({ [`img${K}`]: result.assetId })}`

**A3.** `imgK` field cập nhật trigger `update()` → `buildPoslechDetail`
emit `image_asset_id` mới qua `onChange`.

### B. Tests

**B1.** Wire test: simulate `onAssetCreated` callback fired with
fake AiImageResult → verify `state.items[i].imgK` updated; round-trip
detail emits new image_asset_id.

**B2.** State isolation test: generate image cho item 0 option A
không leak sang item 1 option A hoặc item 0 option B.

**B3.** Disabled state test: `editingId=null` → AiImageButton render
disabled.

### C. Docs

**C1.** Update `docs/reference/content-and-attempt-model.md` § listening
ghi chú V28 admin có thể AI-generate per option.

**C2.** CHANGELOG entry V28.

**C3.** SPEC.md digest row V28.

---

## 4. Wire shape

Không đổi từ V27. AiImageButton callback returns
`{ assetId: string, storageKey: string, previewUrl: string }`. PoslechFields
chỉ dùng `assetId` để set `imgK`. Build wire shape:

```json
{
  "options": [
    {"key": "A", "text": "...", "image_asset_id": "ai-generated-asset-key-here"}
  ]
}
```

Không khác V27 — wire shape unchanged, chỉ là source asset_id giờ
đến từ Replicate thay vì admin paste manual upload.

---

## 5. Test plan

| Layer | Test |
|---|---|
| CMS unit | Wire callback updates state.items[i].imgK |
| CMS unit | State isolation: per-item per-option independent |
| CMS unit | Disabled when editingId null |
| CMS manual | Generate flow E2E: prompt → generate → confirm → asset_id populated → save → reload → image_asset_id persisted |

Smoke flow:
1. Create draft poslech_1 với 5 items
2. Save (gets editingId)
3. Reopen edit
4. Câu 1 option A → click "✨ Tạo bằng AI" → prompt "a Czech café in
   the morning, photorealistic" → generate → preview → confirm
5. Verify `imgA` populated, no other img fields touched
6. Repeat 19 times for full exercise
7. Save published — V27 validation gate enforces 4/4 per item
8. Open Flutter → 5 items với 2×2 image grid mỗi câu

---

## 6. Risks & mitigations

| Risk | Mitigation |
|---|---|
| 20 generate calls × $0.003 = $0.06/exercise | Acceptable cho admin authoring scale hiện tại |
| Rate limit 5 req/min hit khi admin generate liên tục | AiImageButton hiện trả error inline, admin tự pace; future improvement defer |
| UI density 4 buttons/item | Collapsible panel mitigate; idle state nhỏ gọn |
| AI-generated ảnh sai context (vd. người Tây thay vì Czech) | Admin tự retry với prompt khác trước confirm |
| Replicate API down → admin block | AiImageButton fallback show error; admin paste asset_id thủ công vẫn hoạt động (V27 path) |
