# Poslech 1 — Image options A-D (idea)

**Decided:** 2026-05-09
**Slice:** V27
**Owner:** TBD

## Problem

Poslech 1 hiện chỉ cho admin nhập text cho 4 đáp án A-D. Real exam
A2 có nhiều câu poslech_1 dùng **ảnh** thay text (vd. 4 ảnh mô tả
hoạt động → "Eva làm gì cuối tuần?"). Backend đã chừa trường
`MultipleChoiceOption.ImageAssetID` từ V11 (vocab); Flutter
`MultipleChoiceWidget` đã có 2×2 image grid khi cả 4 option có
`imageAssetId`. Nhưng:

- CMS form `PoslechFields.tsx` chỉ track `{optA..D}` text — không
  có chỗ nhập `image_asset_id` per option.
- Output line 80: emit chỉ `{key, text}`, không emit `image_asset_id`.
- Validation không check image consistency.
- Seed không có image data.

→ Gap CMS-only. Backend + Flutter có sẵn capability, chưa wire qua
authoring tool.

## Proposed change

CMS `PoslechFields.tsx` extend per item:
- 4 image_asset_id input cạnh 4 text input.
- Wire output options[i] = `{key, text, image_asset_id}`.
- Validation: all-or-none per item (4 ảnh hoặc 0 ảnh, không mixed).
- Round-trip test fixture với image_asset_ids.

## Why now

- V26 đã ship per-item audio (foundation cho poslech_1 polish).
- Seed expand 5 items mới ship → admin có ngữ cảnh để test full A2 flow.
- Backend + Flutter zero change → slice nhỏ ~150 LOC CMS.

## Why not (do nothing)

Admin không thể authoring poslech_1 ảnh A-D qua CMS. Nếu cần phải
sửa JSON tay trong DB hoặc seed code. Không scalable.

## Scope V27

- ✅ poslech_1 — extend P12Item state với imgA-D
- ✅ Wire JSON output emit image_asset_id per option
- ✅ Validation all-or-none rule per item
- ✅ Round-trip test
- ❌ poslech_2 (cùng schema, defer slice sau)
- ❌ poslech_3/4 image options (Poslech4 đã có image qua MatchOption,
  Poslech3 không có image trong design)
- ❌ Backend changes (V11 schema đủ)
- ❌ Flutter changes (MultipleChoiceWidget đã hỗ trợ)
- ❌ Image upload UX trong CMS (admin paste asset_id từ uploader hiện
  có; UX integration defer)
- ❌ Seed image data (admin tự tạo qua CMS)
- ❌ V22 content health rule cho mixed state (defer)

## Risks

- Mixed state: admin nhập 3/4 image → fallback text-only silently.
  Validation rule mitigate publish-time. Drafts vẫn allow partial.
- Asset_id orphan: admin paste sai asset_id → image 404. Flutter
  `_buildImageOption` đã có `errorBuilder: (_, __, ___) =>
  _LetterPlaceholder(letter: option.key)` nên fail-soft.

## Open questions (resolved 2026-05-09)

- Q: poslech_1 only hay mở rộng? **A:** poslech_1 only. poslech_2
  cùng schema nhưng defer (matches V26 scope discipline).
- Q: File upload UI hay text input asset_id? **A:** Text input
  (matches V11 vocab choice_word pattern). Upload UX defer.
- Q: Drafts allow partial state? **A:** Yes. Validation gate at
  publish only.

## Next

Spec → `docs/specs/poslech-1-image-options.md`
