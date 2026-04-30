# Spec — Media Enrichment for Exercises (V11)

**Status:** Draft · 2026-04-30  
**Idea doc:** `docs/ideas/media-enrichment.md`  
**UI/UX design:** `docs/designs/media-enrichment.html`  
**Scope:** Direction A (option-level images, core) + Direction B (exercise context images, extension). Video excluded.

---

## 1. Objective

Cho phép admin gắn ảnh vào từng đáp án (option) và từng vocabulary/grammar item — để học viên chọn đáp án bằng ảnh thay vì text, và flashcard có minh họa trực quan. Đây là format thi A2 thực tế (послech_2 chọn 1 trong 4 ảnh).

**Target users:**
- **Admin (CMS):** Upload ảnh từ kho có sẵn cho từng vocab item / grammar item / exercise option.
- **Học viên (Flutter):** Thấy ảnh trong flashcard, luyện nối ảnh↔từ, chọn ảnh đúng trong bài nghe/đọc.

**Non-goals của slice này:**
- Video upload / YouTube embed
- AI-generated images
- Audio per vocabulary item (Polly TTS cho vocab — defer)
- Media library / cross-exercise image reuse
- Generic MediaSlot abstraction

---

## 2. Phân tích hiện trạng (what already exists)

| Component | Đã có | Cần thêm |
|-----------|-------|----------|
| `contracts.PromptAsset` | ✅ `AssetID`, `AssetKind`, `MimeType` | — |
| `contracts.ImageOption` | ✅ `{ Key, AssetID }` | — |
| `contracts.ChoiceOption.ImageAssetID` | ✅ (Uloha3) | — |
| `contracts.ReadingItem.AssetID` | ✅ (cteni_1) | — |
| `POST /admin/exercises/:id/assets/upload` | ✅ | — |
| `GET /v1/exercises/:id/assets/:id/file` | ✅ (route exists) | Verify serving vocab assets |
| `contracts.MultipleChoiceOption` | ❌ no `ImageAssetID` | Add `ImageAssetID string` |
| `contracts.MatchOption` | ❌ no `ImageAssetID` | Add `ImageAssetID string` |
| `contracts.VocabularyItem` | ❌ no `ImageAssetID` | Add `ImageAssetID string` + DB column |
| `contracts.GrammarRule` | ❌ no `ImageAssetID` | Add `ImageAssetID string` + DB column |
| `POST /admin/vocabulary-items/:id/image` | ❌ | New endpoint |
| `POST /admin/grammar-rules/:id/image` | ❌ | New endpoint |
| `DELETE` image from item/option | ❌ | New endpoints |
| Flutter `QuizcardWidget` image | ❌ | Add image slot |
| Flutter `MatchingWidget` image column | ❌ | Add image rendering per option |
| Flutter `MultipleChoiceWidget` image grid | ❌ | 2×2 grid layout khi all options có ảnh |
| CMS vocab item image upload UI | ❌ | Per-item upload button + thumb |
| CMS grammar rule image upload UI | ❌ | Per-rule upload button + thumb |
| CMS exercise option image upload UI | ❌ | Per-option upload button + thumb |

---

## 3. Backend Changes

### 3.1 DB Migrations

**Migration 020 — vocabulary_items.image_asset_id:**
```sql
ALTER TABLE vocabulary_items ADD COLUMN image_asset_id TEXT DEFAULT '';
```

**Migration 021 — grammar_rules.image_asset_id:**
```sql
ALTER TABLE grammar_rules ADD COLUMN image_asset_id TEXT DEFAULT '';
```

Không cần migration cho exercise option images — chúng nằm trong `exercises.detail` (JSONB). Chỉ cần thêm field vào Go struct và parse/serialize.

### 3.2 contracts/types.go

```go
// Thêm vào MultipleChoiceOption
type MultipleChoiceOption struct {
    Key          string `json:"key"`
    Text         string `json:"text"`
    ImageAssetID string `json:"image_asset_id,omitempty"` // NEW
}

// Thêm vào MatchOption
type MatchOption struct {
    Key          string `json:"key"`
    Label        string `json:"label"`
    ImageAssetID string `json:"image_asset_id,omitempty"` // NEW
}

// Thêm vào VocabularyItem
type VocabularyItem struct {
    // ... existing fields ...
    ImageAssetID string `json:"image_asset_id,omitempty"` // NEW
}

// Thêm vào GrammarRule
type GrammarRule struct {
    // ... existing fields ...
    ImageAssetID string `json:"image_asset_id,omitempty"` // NEW
}
```

### 3.3 Asset Upload Endpoints

Reuse pattern từ `POST /admin/exercises/:id/assets/upload`. Assets lưu dùng `backend_assets` volume (local) hoặc S3 (`ASSET_UPLOAD_PROVIDER=s3`).

**Mới:**
```
POST /v1/admin/vocabulary-items/:id/image
  Body: multipart/form-data { file: <image> }
  Response: { "data": { "asset_id": "...", "url": "..." } }
  - Validates: mime jpeg/png/webp, max 5MB
  - Stores: same path as exercise assets (backend_assets volume)
  - Updates: vocabulary_items.image_asset_id = asset_id

DELETE /v1/admin/vocabulary-items/:id/image
  - Sets vocabulary_items.image_asset_id = ''

POST /v1/admin/grammar-rules/:id/image
  Body: multipart/form-data { file: <image> }
  Response: { "data": { "asset_id": "...", "url": "..." } }
  - Same pattern

DELETE /v1/admin/grammar-rules/:id/image
```

**Exercise option images:** Dùng lại endpoint hiện có `POST /admin/exercises/:id/assets/upload` với `asset_kind: "option_image"`. Không cần endpoint mới — option `image_asset_id` được set trong `detail` JSONB khi admin lưu exercise form.

### 3.4 Asset Serving

`GET /v1/exercises/:id/assets/:asset_id/file` đã tồn tại. Vocabulary/grammar assets dùng cùng storage backend → cùng serving path. Không cần endpoint mới nếu asset IDs dùng chung namespace.

**Xác minh:** Asset handler hiện tại không check exercise ownership khi serve — OK cho vocab/grammar reuse.

### 3.5 API Response Changes

`GET /v1/vocabulary-sets/:id/items` — thêm `image_asset_id` trong response per item.

`GET /v1/modules/:id/exercises?skill_kind=tu_vung` — `VocabularyItem.image_asset_id` đã có trong nested response.

`GET /v1/exercises/:id` — `MultipleChoiceOption.image_asset_id`, `MatchOption.image_asset_id` đã tự động có sau khi add field.

---

## 4. CMS Changes

### 4.1 Vocabulary Set Edit — Per-item image upload

File: `cms/components/vocabulary-form.tsx` (hoặc component tương đương)

Thêm vào mỗi vocabulary item row:
- Thumbnail 52×52: hiển thị ảnh nếu `image_asset_id != ''`, placeholder nếu chưa có
- Button `+ Tải ảnh`: trigger file input (jpg/png/webp, max 5MB)
- Upload flow: `POST /v1/admin/vocabulary-items/:id/image` → optimistic thumb update
- Button `Đổi ảnh` / `Xóa ảnh` khi đã có ảnh: `DELETE /v1/admin/vocabulary-items/:id/image`
- Audio gen button (existing) vẫn giữ nguyên vị trí

**UX rules:**
- Save exercise trước rồi mới upload được (item phải có `id`)
- Nếu item chưa save → disable upload button với tooltip "Lưu trước"
- Thumbnail update optimistic (hiện placeholder upload progress) → replace với ảnh thật sau khi xong

### 4.2 Grammar Rule Edit — Per-rule image upload

File: `cms/components/grammar-form.tsx`

Tương tự vocab: thumbnail + `+ Tải ảnh` + `POST /v1/admin/grammar-rules/:id/image`.

### 4.3 Exercise Form — Per-option image upload

File: `cms/components/exercise-form/OptionRow.tsx`

Mở rộng `OptionRow` component:
```tsx
// Thêm props
interface Props {
  optionKey: string;
  label: string;
  imageAssetId?: string;   // NEW
  exerciseId: string;      // NEW (để biết upload vào exercise nào)
  onChange: (value: string) => void;
  onImageUploaded?: (assetId: string) => void; // NEW
  onImageRemoved?: () => void; // NEW
}
```

Thêm vào render:
- Thumbnail 56×44px: hiển thị ảnh nếu `imageAssetId`, placeholder dashed nếu chưa
- Upload button: `POST /admin/exercises/:exerciseId/assets/upload` với `asset_kind: "option_image"`
- Sau upload thành công → `onImageUploaded(assetId)` → parent cập nhật option state

**Warning indicator** (trong exercise form): Nếu 1 < count(options_with_image) < count(total_options) → hiện warning "X/Y options chưa có ảnh — Flutter sẽ dùng text list".

**Note về PoslechFields/CteniFields:** Chỉ apply cho exercise types dùng `MultipleChoiceOption` (послech_1, послech_2, cteni_2, cteni_3, cteni_4). Không apply cho послech_4 (dialog/persons) hay cteni_1 (dùng ImageOption đã có).

---

## 5. Flutter Changes

### 5.1 ExerciseDetail model

`flutter_app/lib/features/exercise/models/exercise_detail.dart` (hoặc tương đương)

Thêm parse `image_asset_id` vào:
- `MultipleChoiceOption.fromJson()`
- `MatchOption.fromJson()`
- `VocabularyItem.fromJson()`

### 5.2 Asset URL Helper

Tạo helper để build signed URL cho bất kỳ asset:
```dart
// Dùng lại pattern của AudioURLProvider
String exerciseAssetUrl(String baseUrl, String exerciseId, String assetId) =>
    '$baseUrl/v1/exercises/$exerciseId/assets/$assetId/file';

// Cho vocab/grammar items — cùng asset namespace
String itemAssetUrl(String baseUrl, String assetId) =>
    '$baseUrl/v1/assets/$assetId/file';
// hoặc dùng lại exercise endpoint nếu cùng storage
```

**Xác minh trước khi implement:** Asset serving endpoint có cần `exerciseId` trong path hay dùng `assetId` standalone?

### 5.3 QuizcardWidget — Image slot

File: `flutter_app/lib/features/exercise/widgets/quizcard_widget.dart`

**Front side changes:**
```
Nếu vocabularyItem.imageAssetId != null:
  └── Image slot (aspect 16:9, borderRadius 12, top of card)
      └── CachedNetworkImage / Image.network với auth headers
      └── Shimmer placeholder trong lúc load
      └── Fallback: empty placeholder (không hiện broken image icon)
Nếu không có ảnh:
  └── Card giống hiện tại (chỉ text)
```

**Back side:** Không thêm ảnh — giữ nguyên (nghĩa + ví dụ).

**Audio button (existing):** Giữ nguyên, không thay đổi vị trí.

### 5.4 MatchingWidget — Image options

File: `flutter_app/lib/features/exercise/widgets/matching_widget.dart`

Khi `MatchOption.imageAssetId != null`:
```
Thay text label trong right column bằng image card:
  ┌──────────────┐
  │  [Image 4:3] │  <- CachedNetworkImage
  │  label text  │  <- vẫn hiện text nhỏ phía dưới
  └──────────────┘
```

Left column (Czech word) giữ nguyên text.

**Fallback:** Nếu image load fail → hiện text label only. Không block matching interaction.

### 5.5 MultipleChoiceWidget — Image grid layout

File: `flutter_app/lib/features/exercise/widgets/multiple_choice_widget.dart`

**Layout switch rule (QUAN TRỌNG):**
```dart
final allOptionsHaveImages = options.every((o) => o.imageAssetId?.isNotEmpty == true);

if (allOptionsHaveImages) {
  // 2×2 GridView layout
  // Mỗi cell: Image (aspect 4:3) + label text phía dưới
  // Selected state: border orange 2.5px + check badge
  // Correct state: border green
  // Wrong state: border red + opacity 0.6
} else {
  // Giữ nguyên text list layout (hiện tại)
}
```

**Grid cell states:**
- Default: border gray-200
- Selected: border `AppColors.primary` (#FF6A14) + check badge ở góc
- Correct (after submit): border green, background tint green-50
- Wrong (after submit): border red, opacity 0.6

**Image loading:** `Image.network` với `fit: BoxFit.cover`, shimmer skeleton trong lúc load. Nếu fail → hiện letter placeholder (A/B/C/D) centered.

### 5.6 Exercise prompt context image (Direction B)

File: `flutter_app/lib/features/exercise/widgets/exercise_prompt.dart` hoặc mỗi ExerciseScreen

`Exercise.Assets []PromptAsset` đã được parse. Hiện tại chỉ speaking dùng.

Thêm rendering cho `asset_kind: "context_image"` trong tất cả exercise types:
```
Nếu exercise.assets.any(a => a.assetKind == 'context_image'):
  └── Render image 16:9 với borderRadius 12 phía trên question text
      └── Không block exercise nếu image load fail
```

CMS: exercise form → tab "Media" hoặc section "Ảnh ngữ cảnh" → upload button → asset_kind = "context_image".

---

## 6. API Contracts

### Vocabulary item with image
```json
GET /v1/vocabulary-sets/:id/items
{
  "data": [
    {
      "id": "vi_001",
      "czech": "kavárna",
      "vietnamese": "quán cà phê",
      "word_type": "podstatné jméno",
      "image_asset_id": "ast_abc123"  // NEW — empty string if none
    }
  ]
}
```

### Exercise option with image
```json
GET /v1/exercises/:id
{
  "detail": {
    "options": [
      { "key": "A", "text": "Kavárna", "image_asset_id": "ast_xyz" },
      { "key": "B", "text": "Lékárna", "image_asset_id": "" }
    ]
  }
}
```

### Upload vocab image
```
POST /v1/admin/vocabulary-items/:id/image
Content-Type: multipart/form-data
Body: file=<binary>

200 OK
{ "data": { "asset_id": "ast_abc123", "url": "/v1/assets/ast_abc123/file" } }

413 Payload Too Large — file > 5MB
415 Unsupported Media Type — not jpeg/png/webp
```

### Asset serving (verify existing)
```
GET /v1/exercises/:id/assets/:asset_id/file
Authorization: Bearer <learner-token>
→ image bytes với Content-Type: image/jpeg
```

---

## 7. Acceptance Criteria

### AC-M1: Vocabulary flashcard với ảnh
- [ ] Admin upload ảnh cho vocabulary item trong CMS → thumbnail hiện ngay (optimistic)
- [ ] `GET /v1/vocabulary-sets/:id/items` trả `image_asset_id` không rỗng
- [ ] Flutter `QuizcardWidget` hiện ảnh phía trên Czech term khi `imageAssetId != null`
- [ ] Khi `imageAssetId == null` → card render y hệt hiện tại (không thay đổi layout)
- [ ] Image load fail → card vẫn dùng được (silent fallback)

### AC-M2: Matching với ảnh
- [ ] `MatchOption.imageAssetId` được parse đúng trong Flutter
- [ ] `MatchingWidget` hiện image card trong right column khi `imageAssetId` có
- [ ] Khi image fail → fallback text label, matching vẫn hoạt động
- [ ] Correct/wrong visual state không bị ảnh hưởng bởi image presence

### AC-M3: Multiple choice image grid
- [ ] `MultipleChoiceOption.imageAssetId` được parse trong Flutter
- [ ] Khi **tất cả** options có `imageAssetId` → render 2×2 grid
- [ ] Khi bất kỳ 1 option thiếu ảnh → render text list (không mixed layout)
- [ ] Selected/correct/wrong states đúng trong cả hai layouts
- [ ] CMS warning khi 0 < n_images < n_options

### AC-M4: Exercise context image (Direction B)
- [ ] CMS: upload ảnh context cho bất kỳ exercise type nào → `asset_kind = "context_image"`
- [ ] Flutter: hiện ảnh 16:9 phía trên question khi `assets.any(context_image)`
- [ ] Tất cả exercise types (noi/viet/nghe/doc/tu_vung/ngu_phap) đều support

### AC-M5: Backend upload endpoints
- [ ] `POST /admin/vocabulary-items/:id/image`: 200 với asset_id khi file hợp lệ
- [ ] `POST /admin/vocabulary-items/:id/image`: 413 khi file > 5MB
- [ ] `POST /admin/vocabulary-items/:id/image`: 415 khi không phải jpeg/png/webp
- [ ] `DELETE /admin/vocabulary-items/:id/image`: xóa asset_id khỏi DB
- [ ] Grammar rule endpoints tương tự

### AC-M6: No regression
- [ ] Tất cả exercise types không có ảnh render y hệt hiện tại
- [ ] MockTest flow không bị ảnh hưởng
- [ ] `make flutter-analyze` pass (no warnings)
- [ ] `make backend-test` pass
- [ ] `make cms-build` pass

---

## 8. Data & Storage

**Asset storage:** Dùng `backend_assets` Docker volume (local) hoặc S3 bucket (production) — cùng infrastructure với exercise prompt assets hiện tại. Không tạo volume mới.

**Asset path scheme:**
```
vocabulary-images/{item_id}/{uuid}.{ext}   — vocab item
grammar-images/{rule_id}/{uuid}.{ext}       — grammar rule
(exercise option images đã dùng exercise assets path)
```

**Image constraints:**
- MIME: `image/jpeg`, `image/png`, `image/webp`
- Max size: 5MB per file
- No server-side resizing (defer — Flutter resize nếu cần)
- No CDN required for V1 (serve qua Go backend như exercise assets)

---

## 9. Testing Strategy

### Backend
- Unit: `TestUploadVocabularyItemImage` — valid/invalid mime, oversized
- Unit: `TestVocabularyItemImageDelete` — removes asset_id
- Integration: `GET /v1/vocabulary-sets/:id/items` — image_asset_id propagates

### CMS
- Extend existing Vitest tests trong `exercise-utils.test.ts`
- Test: `OptionRow` renders upload button when `exerciseId` provided
- Test: warning shows when 0 < n_images < n_options

### Flutter
- Widget test: `QuizcardWidget` với `imageAssetId = null` → unchanged layout
- Widget test: `QuizcardWidget` với `imageAssetId = 'ast_001'` → image slot visible
- Widget test: `MultipleChoiceWidget` với all images → GridView layout
- Widget test: `MultipleChoiceWidget` với mixed images → ListView layout
- Widget test: `MatchingWidget` với image options → image cards in right column

---

## 10. Implementation Order

Thứ tự an toàn (incremental, repo vẫn build sau mỗi bước):

```
M1. Backend contracts + DB migrations
    → Add image_asset_id to MultipleChoiceOption, MatchOption, VocabularyItem, GrammarRule
    → Migration 020 (vocabulary_items) + 021 (grammar_rules)
    → make backend-build pass

M2. Backend upload endpoints
    → POST /admin/vocabulary-items/:id/image
    → DELETE /admin/vocabulary-items/:id/image
    → POST /admin/grammar-rules/:id/image
    → DELETE /admin/grammar-rules/:id/image
    → Tests pass

M3. CMS — Vocabulary item image upload UI
    → OptionRow: thêm imageAssetId prop + upload button
    → Vocabulary form: per-item thumb + upload
    → make cms-build pass

M4. CMS — Grammar rule + exercise option UI
    → Grammar form: per-rule image upload
    → PoslechFields/CteniFields: pass exerciseId to OptionRow
    → Warning indicator khi mixed images

M5. Flutter model + asset URL
    → Parse image_asset_id trong models
    → Asset URL helper

M6. Flutter QuizcardWidget
    → Image slot phía trên term
    → Shimmer + fallback

M7. Flutter MatchingWidget
    → Image card trong right column

M8. Flutter MultipleChoiceWidget
    → 2×2 grid layout khi all images
    → Selected/correct/wrong states

M9. Flutter context image (Direction B)
    → Render asset_kind=context_image trong exercise prompt area
    → Apply cho all exercise screens

M10. Tests + verify
    → make verify
```

---

## 11. Boundaries

**Always do:**
- Fallback gracefully khi ảnh không load (không crash, không block interaction)
- Validate MIME + size trước khi lưu
- Reuse `backend_assets` volume — không tạo storage layer mới
- `image_asset_id` là optional trên tất cả entities — không breaking change

**Ask first:**
- Nếu asset serving cần auth header từ Flutter (cần kiểm tra existing asset handler)
- Nếu CMS upload cần progress bar UX (hay optimistic thumbnail đủ rồi)

**Never do:**
- Video upload hay YouTube embed trong slice này
- AI image generation
- Server-side image resize/thumbnail generation
- Breaking change cho existing exercise JSON shape (chỉ thêm field optional)
- Tạo bảng DB mới cho assets — dùng filesystem/S3 path trong existing columns
