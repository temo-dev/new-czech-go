# AI Image Generation trong CMS

## Problem Statement
How might we help CMS admin tạo ảnh minh họa cho exercises nhanh hơn bằng AI thay vì phải tự tìm/chụp/upload ảnh thủ công?

## Recommended Direction

Thêm nút "✨ AI" ngay cạnh nút upload ảnh hiện tại ở mọi nơi CMS dùng ảnh. Khi nhấn, một prompt input nhỏ xuất hiện inline (không modal). Admin điền mô tả → backend gọi Flux (Replicate) → trả ảnh preview → admin xác nhận để upload vào asset store.

**Tại sao hướng này:**
- Không thay đổi flow hiện tại — chỉ bổ sung path song song với upload thủ công
- Preview-before-commit tránh lãng phí storage và giữ kiểm soát ở tay admin
- Component dùng chung `<AiImageButton>` tái sử dụng ở 4 nơi mà không duplicate code
- Flux.1-schnell qua Replicate: ~3s/ảnh, ~$0.003, phù hợp workload admin nhỏ

## Key Assumptions to Validate
- [ ] Replicate Flux cho ra ảnh phù hợp ngữ cảnh Czech A2 exam (quán café, văn phòng, trường học) — test 5–10 prompt thực tế trước khi build
- [ ] Admin sẵn sàng viết prompt tiếng Anh (Flux hiểu EN tốt hơn VI) — hoặc cần prompt helper tiếng Việt
- [ ] `REPLICATE_API_KEY` có thể thêm vào `.env` production không conflict với budget
- [ ] Backend download + lưu ảnh từ Replicate URL không bị firewall/timeout trên EC2

## MVP Scope

**Backend:**
- Env var: `REPLICATE_API_KEY`
- Endpoint: `POST /api/admin/ai/generate-image`
  - Body: `{ prompt: string }`
  - Logic: POST Replicate API (flux-schnell model) → poll until done → download image bytes → lưu vào asset store (local file hoặc S3 tùy `STORAGE_PROVIDER`) → trả `{ asset_id: string, preview_url: string }`
  - Rate limit: max 5 req/min per admin (tránh accident spam)
  - Timeout: 30s

**Frontend (CMS):**
- Component `<AiImageButton onAssetCreated={(assetId) => void} disabled={!exerciseId} />`
- State: `idle → prompt-open → generating → preview → done/error`
- UI: nút nhỏ "✨ AI" kế nút upload → click → input box xuất hiện bên dưới → "Generate" button → spinner → thumbnail 120×80 preview → "Dùng ảnh này" / "Thử lại" / "Hủy"
- Sau khi confirm: gọi callback `onAssetCreated(assetId)` → parent dùng asset_id như bình thường

**Tích hợp 4 nơi:**
1. `exercise-form/index.tsx` — section "🖼 Ảnh minh họa" (context_image) ~line 978
2. `exercise-form/index.tsx` — section upload assets cho uloha_3 ~line 783
3. `OptionRow.tsx` — imageAssetId per option (vocab/grammar matching)
4. `CteniFields.tsx` — per-item image cteni_1
5. Course/MockTest banner upload (cms/app/courses, cms/app/mock-tests pages)

## Not Doing (và lý do)

- **Auto-generate prompt từ nội dung bài** — thêm LLM call, tăng latency và cost; admin viết prompt nhanh hơn
- **Batch generate nhiều ảnh** — admin cần xem 1 ảnh trước, nếu tệ mới retry; 4 ảnh cùng lúc gây confusion
- **DALL-E / Imagen** — Replicate đủ tốt, tránh thêm key mới
- **Tự động gắn ảnh không cần confirm** — admin phải thấy ảnh trước khi commit vào bài
- **Lưu generation history / gallery** — over-engineering cho V1; admin có thể retry nếu cần
- **Prompt templates picker** — nice to have, có thể thêm sau nếu admin thấy cần

## Open Questions
- Flux.1-schnell vs Flux.1-dev: schnell nhanh hơn nhưng dev chất lượng cao hơn — test so sánh trước
- Ảnh format trả về: JPEG 512×512 đủ cho exercise context? Hay cần 1024×1024?
- Nếu admin hủy sau khi ảnh đã được lưu vào asset store, asset đó có bị orphan không? → có thể cleanup khi exercise save, hoặc chấp nhận orphan (kích thước nhỏ)
- Rate limit: lưu counter per admin session hay per IP?
