# Media Enrichment for Exercises

## Problem Statement
Làm thế nào để mọi loại exercise đều có thể kèm media (ảnh, audio) ở cả cấp độ câu hỏi lẫn từng đáp án — để học viên hiểu ngữ cảnh và bài trở nên sống động hơn?

## Recommended Direction
**Direction A (Core) + Direction B (Extension)**

**Direction A — Option-level images:** Thêm `asset_id` vào từng option object trong exercise detail JSONB. Học viên chọn đáp án bằng ảnh thay vì text — đúng format thi A2 thực tế (послech_2 là chọn đúng ảnh trong 4 ảnh). VocabularyItem thêm `image_asset_id` cho flashcard. Grammar matching với ảnh tình huống.

**Direction B (Extension) — Exercise-level context:** Bất kỳ exercise type nào đều có thể kèm ảnh context ở cấp question (extend PromptAsset đã có). VocabularyItem thêm audio (Polly TTS hoặc upload). Noi/viet đã có PromptAsset, chỉ cần enable cho nghe/đọc/từ vựng/ngữ pháp.

Tại sao A+B là sweet spot: A giải quyết đúng vấn đề thi thật (image option selection), B thêm vocab richness với effort thấp. Cả hai reuse infrastructure `PromptAsset` + upload endpoint đã có.

## Key Assumptions to Validate
- [ ] Admin có kho ảnh chất lượng tốt sẵn sàng upload — xác nhận trước khi build CMS upload UI
- [ ] PromptAsset serving endpoint (`GET /v1/exercises/:id/assets/:asset_id`) đủ nhanh cho image-heavy screens — test với 4 ảnh option đồng thời
- [ ] Flutter `CachedNetworkImage` (hoặc Image.network) xử lý 4 ảnh option 300×200px mà không lag trên older devices

## MVP Scope

**Backend:**
- VocabularyItem thêm `image_asset_id` column + upload endpoint `POST /v1/admin/vocabulary-items/:id/image`
- GrammarRule thêm `image_asset_id` column + upload endpoint
- Exercise option objects trong detail JSONB: thêm `asset_id` field (optional) — zero migration nếu detail là JSONB
- Extend asset serving endpoint để serve vocabulary/grammar images (hoặc reuse `/assets/:id`)

**CMS:**
- VocabularyItem row: image upload button + thumbnail preview (32×32)
- GrammarRule row: image context upload + preview
- Exercise form → Options section: per-option image upload button + small preview

**Flutter:**
- `QuizcardWidget`: hiển thị ảnh phía trên term khi `imageUrl != null` (aspect ratio 4:3)
- `MatchingWidget`: option có ảnh → show image + label stacked
- `MultipleChoiceWidget`: khi tất cả options có ảnh → switch layout từ list → 2×2 grid
- Exercise header area (dùng chung): optional context image bên dưới title khi exercise có PromptAsset dạng image

**Not in MVP:**
- Audio per VocabularyItem (Polly TTS pipeline cần thêm endpoint, defer sang sau)
- Image per GrammarConjugation table cell
- Exercise-level video

## Not Doing (and Why)
- **Video** — Storage + bandwidth cost không tương xứng với exam prep use case. Học viên dùng offline.
- **AI-generated images** — Bài thi A2 dùng ảnh thực tế (tiệm cà phê Czech, formulář). AI không match.
- **Generic MediaSlot system** — Over-engineering. PromptAsset đã đủ flexible với `asset_kind` string.
- **Media library/inheritance** — Premature. Chưa có evidence admin cần reuse ảnh cross-exercise.
- **YouTube embed** — App dùng offline, YouTube URL rot, phụ thuộc external.

## Open Questions
- VocabularyItem images: upload per item hay per set (set-level image cho chủ đề)? → Khả năng per item linh hoạt hơn
- Khi option có ảnh nhưng server trả lỗi: fallback về text label hay hiển thị broken image? → Fallback về text, đừng block
- Polly TTS cho VocabularyItem: trigger khi publish VocabularySet hay lazy on-demand? → On-demand an toàn hơn
