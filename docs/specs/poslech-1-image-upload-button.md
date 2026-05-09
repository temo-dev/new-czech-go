# Poslech 1 Image Upload Button (V29) — Spec

**Slice:** V29 — manual file upload button per A-D option in PoslechFields
**Status:** Draft — chờ human approve trước khi sang plan
**Owner:** TBD
**Last updated:** 2026-05-10

Liên quan:
- Idea: [`docs/ideas/poslech-1-image-upload-button.md`](../ideas/poslech-1-image-upload-button.md)
- Plan: [`tasks/v29-poslech-1-image-upload-button-plan.md`](../../tasks/v29-poslech-1-image-upload-button-plan.md)
- Todo: [`tasks/v29-poslech-1-image-upload-button-todo.md`](../../tasks/v29-poslech-1-image-upload-button-todo.md)
- Reference: V27 image_asset_id wire, V28 AI generate
- Precedent: `cms/components/exercise-form/CteniFields.tsx:51-72` — handleC1ImageUpload pattern

---

## 1. Objective

Cho admin upload ảnh có sẵn từ máy local cho bất kỳ option A-D nào
của poslech_1. Mirror cteni_1 upload UX.

**Out of scope:** poslech_2/3/4, drag-drop, multi-file, image
preview/crop trong CMS, backend changes.

---

## 2. Quyết định đã chốt

| # | Quyết định | Lý do |
|---|---|---|
| D1 | poslech_1 only | Match V27/V28 scope discipline |
| D2 | Hidden `<input type="file">` + visible label button | Match cteni_1 UX. Native file picker |
| D3 | Endpoint reuse `POST /api/admin/exercises/:id/assets/upload` | Đã có, multipart FormData, returns `{data: {asset: {id}}}` |
| D4 | accept="image/jpeg,image/png,image/webp" | Match cteni_1 |
| D5 | Single uploading-key state ⇒ block parallel uploads | Đơn giản hoá. Admin upload tuần tự acceptable |
| D6 | Upload error message inline per option | Visible at the row that failed |
| D7 | Disabled khi `editingId` null | Match V28 pattern |
| D8 | Button label flip: "📁 Tải ảnh lên" / "🔄 Đổi ảnh" | Match cteni_1 |
| D9 | Manual paste text input vẫn giữ | V27 fallback path; admin có 3 options |
| D10 | Backend không thay đổi | endpoint đã có |

---

## 3. Acceptance Criteria

### A. Upload handler

**A1.** `handleP12ImageUpload(file: File, itemIndex: number, optionKey: OptionKey)` async function trong `PoslechFields`:
1. If `!editingId` → `setUploadError('Lưu bài tập trước rồi upload ảnh.')`, return.
2. Set `uploadingKey = ${itemIndex}-${optionKey}`.
3. FormData `{ file, asset_kind: 'image' }` POST tới `/api/admin/exercises/${editingId}/assets/upload`.
4. Parse response → `data.asset.id`.
5. `setImg(assetId)` qua V28 `makeOptionImagePatcher`.
6. Clear uploadingKey + error trong finally.

### B. UI

**B1.** Per option K render thêm `<label>` chứa "📁 Tải ảnh lên" (hoặc "🔄 Đổi ảnh" khi imgK đã set) + hidden `<input type="file">`. Cùng dòng với AiImageButton.

**B2.** Loading state: button label "⏳ Đang tải..." khi `uploadingKey === ${i}-${k}`.

**B3.** Upload error: text dưới row option khi `uploadError && lastErrorKey === ${i}-${k}`.

**B4.** Other options disabled khi 1 upload đang chạy (parallel block).

### C. Tests

**C1.** Pure helper `parseUploadResponse(json)` extract asset_id từ
`{data: {asset: {id}}}` shape; throws on missing field.

**C2.** Tests V28 patcher tiếp tục pass — wire path không đổi.

### D. Docs

**D1.** Update `docs/reference/content-and-attempt-model.md`.
**D2.** CHANGELOG entry V29.
**D3.** SPEC digest row V29.

---

## 4. Wire shape

V27/V28 wire shape giữ. Chỉ thêm path #3 trong UI để populate
`imgK`. Backend asset_id giống nhau bất kể source (paste / AI /
upload).

---

## 5. Test plan

| Layer | Test |
|---|---|
| CMS unit | parseUploadResponse helper happy + missing field |
| CMS regression | V27 + V28 tests vẫn pass |
| CMS manual | Upload .jpg → button shows "🔄 Đổi ảnh" → save → reload → image_asset_id persisted |
| CMS manual | Upload error backend → inline message |

---

## 6. Risks & mitigations

| Risk | Mitigation |
|---|---|
| File size huge → upload chậm/fail | Backend enforce; CMS show error |
| 20 file inputs ref cost | React refs cheap; verify no leak via cleanup ref nullification |
| User upload non-image | accept attribute restrict picker; backend validate fallback |
| Race với AI generate đồng thời | Single uploading-key; AiImageButton có state machine riêng — UX acceptable |
