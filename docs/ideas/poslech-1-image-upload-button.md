# Poslech 1 — Image Upload Button per option (idea)

**Decided:** 2026-05-10
**Slice:** V29
**Owner:** TBD

## Problem

V27 cho admin paste asset_id thủ công. V28 cho AI generate qua
Replicate. Còn thiếu: upload **ảnh có sẵn** trên máy admin (vd.
ảnh chụp đề thi A2 thật, ảnh từ stock photo). Hiện flow là:
1. Admin upload qua endpoint khác (manual)
2. Lấy asset_id
3. Paste vào input

Không scalable. CteniFields cteni_1 đã có "📁 Tải ảnh lên" button
gọi `POST /api/admin/exercises/:id/assets/upload` với FormData.

→ Gap: chưa wire pattern này vào PoslechFields per option.

## Proposed change

Mỗi option A-D thêm "📁 Tải ảnh lên" button. Click → file picker
(hidden `<input type="file">`) → upload qua FormData →
`asset_id` trả về → patch `imgK`.

Mirror cteni_1 pattern. UI per option giờ có 3 entry points:
1. Paste text input (V27)
2. ✨ AI tạo (V28)
3. 📁 Tải ảnh lên (V29)

## Why now

V27/V28 ship liên tiếp; V29 fill nốt gap upload UX để admin có 3
options đầy đủ. CMS-only slice nhỏ ~50 LOC.

## Why not

Admin có thể upload qua route khác rồi paste asset_id. Acceptable
nhưng UX kém — không match V11 pattern đã có.

## Scope V29

- ✅ Hidden file input + visible "📁 Tải ảnh lên" / "🔄 Đổi ảnh" button
  per option
- ✅ `handleP12ImageUpload(file, itemIndex, optionKey)` async handler
- ✅ Disabled khi `editingId` null
- ✅ Loading state per option (uploading key tracking)
- ✅ Upload error display per option row
- ❌ poslech_2/3/4
- ❌ Backend endpoint changes (đã có `/assets/upload`)
- ❌ Flutter changes
- ❌ Drag-drop UX (defer)
- ❌ Multi-file upload (defer)
- ❌ Image preview thumbnail trước save (defer; admin verify ở Flutter)

## Risks

- 20 file input refs per render (5 items × 4 options) — overhead
  nhẹ; React refs cheap.
- Upload concurrent multiple options đồng thời = race với
  `uploadingKey` single-state → block parallel uploads. Acceptable
  cho V29; admin upload tuần tự OK.
- File size limits backend imposed; CMS không validate. Backend
  trả error → admin retry.

## Open questions (resolved 2026-05-10)

- Q: Image preview trong CMS sau upload? **A:** Defer. Admin verify
  qua Flutter trên thiết bị thật.
- Q: Drag-drop? **A:** Defer.
- Q: Crop / resize CMS-side? **A:** Defer. Backend xử lý nếu cần.

## Next

Spec → `docs/specs/poslech-1-image-upload-button.md`
