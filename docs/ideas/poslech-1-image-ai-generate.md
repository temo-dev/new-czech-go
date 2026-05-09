# Poslech 1 — AI Image Generate per option (idea)

**Decided:** 2026-05-10
**Slice:** V28
**Owner:** TBD

## Problem

V27 cho admin nhập `image_asset_id` per A-D option của poslech_1
qua text input — admin phải tự upload ảnh ngoài CMS rồi paste
asset_id vào. UX kém: 4 lần upload thủ công per câu × 5 câu = 20
lần upload cho 1 exercise. Tốn thời gian, không scalable.

`<AiImageButton>` đã tồn tại + tích hợp ở 4 nơi khác trong CMS
(`exercise-form/index.tsx` context image, `CteniFields.tsx` per item
cteni_1, course-dashboard banner, mock-test-dashboard banner). Backend
endpoint `POST /api/admin/ai/generate-image` đã ship (Replicate Flux
Schnell, ~3-5s/ảnh).

→ Gap: chưa wire AiImageButton vào PoslechFields per option của
poslech_1.

## Proposed change

Mỗi option A-D trong PoslechFields P12 branch render thêm
`<AiImageButton>` cạnh text input asset_id. Click → prompt input
inline → generate ảnh → preview → confirm → callback patch
`state.items[i].img{K}` với asset_id mới.

## Why now

- V27 vừa ship per-option image_asset_id. Test smoke phát hiện UX
  thiếu tự AI-generate.
- Infra đã sẵn (V11+ ai-image-generation slice). Wire 1 component
  thay vì build mới.
- Không đụng backend (Replicate endpoint hoạt động) hoặc Flutter
  (chỉ thêm asset_id vào wire).

## Why not (do nothing)

Admin paste asset_id thủ công sau khi upload ngoài. Ổn cho 1-2 ảnh
nhưng không scale cho 20 ảnh per exercise. Block production
content authoring.

## Scope V28

- ✅ Render `<AiImageButton>` per option K trong P12 branch
- ✅ Wire `onAssetCreated` callback → patch `imgK`
- ✅ `existingAssetId` prop từ `imgK` để show "Tạo lại bằng AI" label
- ✅ Test wire (mock callback)
- ❌ poslech_2 — same schema nhưng V27 chỉ enforce poslech_1, V28 cũng vậy
- ❌ poslech_3/4/5
- ❌ Backend changes (endpoint đã có)
- ❌ Flutter changes
- ❌ Bulk generate UX (1 prompt → 4 ảnh A-D variations) — defer slice
  sau nếu thực tế cần
- ❌ Prompt template auto-fill từ option text — admin tự viết prompt

## Risks

- 4 buttons per item × 5 items = 20 buttons trên 1 màn hình. UI
  density cao.
  Mitigation: AiImageButton đã có `display: 'contents'` + collapsible
  panel nên idle state chỉ là 1 nút nhỏ.
- Replicate API cost: 4 ảnh × 5 câu × $0.003 = $0.06/exercise. Reasonable.
- Rate limit hiện tại 5 req/min/admin. Bulk authoring có thể hit.
  Defer cải thiện.

## Open questions (resolved 2026-05-10)

- Q: Generate 4 ảnh từ 1 prompt hay 4 prompt độc lập? **A:** 4 prompt
  độc lập (mỗi option khác nhau về nội dung). Bulk feature defer.
- Q: Auto-fill prompt từ optK text? **A:** Không V28. Admin tự viết
  prompt tiếng Anh — Flux EN tốt hơn VI.

## Next

Spec → `docs/specs/poslech-1-image-ai-generate.md`
