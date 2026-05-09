# Changelog

Detailed history of completed slices. Newest first. AGENTS.md keeps the
operational guide; this file keeps the receipts.

For each slice the entry lists: scope, key file changes, decisions
worth remembering, and final test counts. When a slice introduces a new
contract or convention, the canonical home is its own spec under
`docs/specs/` — the entry here points there rather than inlining.

---

## V29 — Poslech 1 Image Upload Button — 2026-05-10

V28 ship cùng ngày, smoke test xong tìm thấy gap thứ 3: admin có
ảnh có sẵn trên máy local (vd. ảnh chụp đề thi A2 thật, stock
photo) không có UX upload trực tiếp trong PoslechFields — phải đi
qua route khác rồi paste asset_id. Cteni_1 đã có "📁 Tải ảnh lên"
button gọi `/api/admin/exercises/:id/assets/upload` (FormData).
V29 wire pattern này vào PoslechFields per A-D option.

Spec: `docs/specs/poslech-1-image-upload-button.md`. Plan + todo:
`tasks/v29-poslech-1-image-upload-button-{plan,todo}.md`. Idea:
`docs/ideas/poslech-1-image-upload-button.md`.

CMS-only slice. Backend (upload endpoint đã có V11+) + Flutter
unchanged.

### CMS (Phase A)

- **`poslech-model.ts`**:
  - `parseUploadResponse(json)`: extract `data.asset.id` từ upload
    response; throw on missing field tránh "ok response → asset_id
    rỗng" silent failure.
  - `uploadingKeyFor(itemIndex, optionKey)`: encode active cell vào
    string `${i}-${k}`. Single-state guard concurrent upload.
- **`PoslechFields.tsx`**:
  - `handleP12ImageUpload(file, itemIndex, optionKey, setImg)` async
    handler: FormData POST → parseUploadResponse → setImg via V28
    `makeOptionImagePatcher`. Try/catch error caught into
    `uploadError` state với cellKey + message.
  - Hidden `<input type="file">` + visible `<label>` button per
    option. Label: "📁 Tải ảnh lên" / "🔄 Đổi ảnh" / "⏳ Đang tải...".
  - `accept="image/jpeg,image/png,image/webp"` match cteni_1.
  - File picker disabled khi (a) `editingId` null hoặc (b) other cell
    uploading hoặc (c) this cell uploading.
  - AiImageButton (V28) cũng disabled khi other cell upload — tránh
    state race.
  - Inline error message dưới row option khi cellKey match.

Per option giờ có 3 entry points cho asset_id:
1. Paste text (V27)
2. ✨ AI tạo (V28)
3. 📁 Upload local (V29)

### Backend + Flutter

Không đổi. Endpoint `/api/admin/exercises/:id/assets/upload` đã ship
multipart support qua V11+; Flutter consume `image_asset_id` không
đổi semantics.

### Docs

- `docs/ideas/poslech-1-image-upload-button.md` — idea.
- `docs/specs/poslech-1-image-upload-button.md` — Status: Draft → Shipped.
- `tasks/v29-poslech-1-image-upload-button-{plan,todo}.md`.
- `docs/reference/content-and-attempt-model.md` § listening: thêm
  ghi chú V29.
- `SPEC.md` digest: row V29.

### Tests

CMS: 290 tests pass (was 285 → +5 V29). Phase A added 5 tests
(parseUploadResponse happy + missing data + missing/empty
asset.id + null/undefined input + uploadingKeyFor encoding).
Lint + build clean. Backend (859) + Flutter (373) unchanged.

### Out of scope

- ❌ poslech_2/3/4
- ❌ Backend endpoint changes
- ❌ Flutter changes
- ❌ Drag-drop / multi-file
- ❌ CMS-side image preview / crop
- ❌ Concurrent upload (single-flight by design)

---

## V28 — Poslech 1 AI Image Generate — 2026-05-10

V27 ship 1 ngày, smoke test phát hiện UX gap: admin phải tự upload
4 ảnh × 5 câu = 20 lần upload thủ công ngoài CMS rồi paste asset_id
vào PoslechFields. Không scalable. `<AiImageButton>` đã tồn tại +
tích hợp 4 nơi khác trong CMS (exercise-form context image,
CteniFields per item cteni_1, course/mock-test banner). V28 wire
component thứ 5: per A-D option của poslech_1.

Spec: `docs/specs/poslech-1-image-ai-generate.md`. Plan + todo:
`tasks/v28-poslech-1-image-ai-generate-{plan,todo}.md`. Idea:
`docs/ideas/poslech-1-image-ai-generate.md`.

CMS-only slice. Backend (`/api/admin/ai/generate-image` Replicate
Flux Schnell endpoint) + Flutter unchanged.

### CMS (Phase A)

- **`poslech-model.ts`**: thêm `OptionKey` type alias +
  `makeOptionImagePatcher(onPatch, optionKey)` factory. Returns
  setter `(assetId) => onPatch({ [imgK]: assetId })`. Extracted để
  test wire không cần React Testing Library.
- **`PoslechFields.tsx`** (P12 branch): per option K ∈ {A,B,C,D}
  render thêm `<AiImageButton>` cạnh OptionRow + img text input.
  Callback flow:
  1. `onAssetCreated(result)` fired (AiImageButton state machine
     `idle → open → generating → preview → confirm`)
  2. Register asset: `POST /api/admin/exercises/{editingId}/assets`
     với `{id, asset_kind: 'image', storage_key, mime_type}` —
     mirror CteniFields cteni_1 pattern.
  3. `setImg(result.assetId)` qua `makeOptionImagePatcher` →
     state.items[i].imgK update → buildPoslechDetail re-emit
     `image_asset_id` qua V27 wire shape.
- Disabled khi `editingId == null` (chưa save bài). Title prop
  hiện hint "Lưu bài tập trước để tạo ảnh AI".
- `existingAssetId={imgK || undefined}` flip label "Tạo lại bằng AI"
  thay vì "Tạo bằng AI" khi option đã có ảnh — UX consistency với
  4 wire site khác.
- Manual paste vẫn hoạt động (V27 path) — admin có thể paste
  asset_id thủ công nếu muốn dùng ảnh upload bằng đường khác.

### Backend + Flutter

Không đổi. `/api/admin/ai/generate-image` đã ship qua
`ai-image-generation` slice (V11+); rate limit 5 req/min/admin,
Replicate Flux Schnell, timeout 30s. Wire shape `image_asset_id`
giữ V27 spec. `MultipleChoiceWidget` switch image grid như cũ.

### Docs

- `docs/ideas/poslech-1-image-ai-generate.md` — idea.
- `docs/specs/poslech-1-image-ai-generate.md` — Status: Draft → Shipped.
- `tasks/v28-poslech-1-image-ai-generate-{plan,todo}.md`.
- `docs/reference/content-and-attempt-model.md` § listening: thêm
  ghi chú V28 AI generate.
- `SPEC.md` digest: row V28.

### Tests

CMS: 285 tests pass (was 282 → +3 V28). Phase A added 3 tests
(makeOptionImagePatcher targets correct imgK; A/B/C/D isolated;
end-to-end through buildPoslechDetail emits image_asset_id on
patched option only). Lint + build clean. Backend (859) + Flutter
(373) unchanged.

### Out of scope

- ❌ poslech_2/3/4 AI generate
- ❌ Backend endpoint changes
- ❌ Flutter changes
- ❌ Bulk generate (1 prompt → 4 variations)
- ❌ Prompt template auto-fill from option text
- ❌ Rate limit improvements

---

## V27 — Poslech 1 Image Options A-D — 2026-05-09

V26 ship được 1 ngày, dispatch review tìm thấy poslech_1 thiếu khả
năng authoring image_asset_id per A-D option mặc dù backend (V11
`MultipleChoiceOption.ImageAssetID` + `omitempty`) và Flutter
(`MultipleChoiceWidget._allHaveImages` đã switch 2×2 image grid khi
đủ 4 image) đã sẵn sàng. CMS form `PoslechFields.tsx` chỉ track
`{optA..D}` text, không emit `image_asset_id`. V27 wire CMS field +
validation, không đụng backend hay Flutter.

Spec: `docs/specs/poslech-1-image-options.md`. Plan + todo:
`tasks/v27-poslech-1-image-options-{plan,todo}.md`. Idea:
`docs/ideas/poslech-1-image-options.md`.

Scope là poslech_1 only. poslech_2 (cùng schema) defer slice sau.

### CMS (Phase A + B)

- **`cms/components/exercise-form/poslech-model.ts`** mới: extract
  pure types + `initPoslechState` + `buildPoslechDetail` +
  `countItemImages` từ `PoslechFields.tsx` (mirrors `cteni-model.ts`
  pattern). Tests có thể drive helpers trực tiếp không cần React
  Testing Library. `PoslechFields.tsx` import từ module mới, không
  còn inline duplicate.
- **`P12Item` mở rộng**: thêm `imgA, imgB, imgC, imgD: string` cho
  poslech_1/2. Empty string = không ảnh.
- **`initPoslechState` (poslech_1/2)**: hydrate `imgK` từ
  `detail.items[i].options[k].image_asset_id`, default empty.
- **`buildPoslechDetail` (poslech_1/2)**: emit
  `options[k] = {key, text}` khi `imgK` empty (V26-compatible),
  hoặc `{key, text, image_asset_id}` khi set. Round-trip clean.
- **PoslechFields UI**: cho poslech_1/2 branch, dưới mỗi `OptionRow`
  text input thêm 1 `<input>` cho `image_asset_id` per option.
  Placeholder: "Asset ID ảnh K (tùy chọn — bỏ trống nếu chỉ dùng
  text)". Admin paste asset_id từ existing uploader; UI integration
  upload defer.
- **`validation.ts` poslech_1 all-or-none rule**: published poslech_1
  per item phải có 0/4 hoặc 4/4 image_asset_id. 1-3/4 fail với
  message "Câu N: hoặc tất cả 4 đáp án có ảnh, hoặc không đáp án nào
  có ảnh (hiện có X/4 ảnh)." Drafts skip (status='draft').
  poslech_2 không gate (dù P12State shared, V27 chỉ enforce
  poslech_1).

### Backend + Flutter

Không đổi. `MultipleChoiceOption.ImageAssetID` đã có V11 với
`omitempty` — wire shape backward-compat tự nhiên.
`MultipleChoiceWidget._allHaveImages` đã switch image grid khi
`mediaUri != null && options.every(imageAssetId != "")`. Per-item
audio (V26) + image options (V27) độc lập cùng tồn tại.

### Docs

- `docs/ideas/poslech-1-image-options.md` — one-pager idea.
- `docs/specs/poslech-1-image-options.md` — Status: Draft → Shipped.
- `tasks/v27-poslech-1-image-options-plan.md` — 3 phase A-C.
- `tasks/v27-poslech-1-image-options-todo.md` — RED/GREEN checklist.
- `docs/reference/content-and-attempt-model.md` § Listening: thêm
  ghi chú V27 image options + all-or-none rule.
- `SPEC.md` digest: row V27.

### Tests

CMS: 282 tests pass (was 277 → +15 V27). Phase A added 10 (state
hydration, buildDetail emit/omit, round-trip, countItemImages
truth-table, poslech_2 cross-pollution). Phase B added 5 (mixed
rejected, 0/4 pass, 4/4 pass, drafts skip, multi-offender). Lint
clean. Build clean.

### Out of scope

- ❌ poslech_2/3/4 image options (poslech_4 đã có image qua MatchOption
  asset_id, khác design)
- ❌ Backend changes (V11 đủ)
- ❌ Flutter changes (MultipleChoiceWidget đủ)
- ❌ File upload UX trong CMS — admin paste asset_id qua existing
  `/api/admin/exercises/:id/assets/upload` flow, không integrate inline
- ❌ Seed image data — admin tự authoring qua CMS
- ❌ V22 content health rule mixed state
- ❌ Migration regenerate seed cũ

---

## V26 — Poslech 1 Per-item Audio — 2026-05-09

V21.2 ship được 30 ngày, learner feedback từ MobAI test cho thấy
poslech_1 phát 1 file MP3 gộp 5 câu liên tiếp khiến học viên không
tua được riêng từng câu — phải scrub timeline thủ công, lệch UX so
với đề thi A2 thật vốn phát từng đoạn riêng có khoảng nghỉ. V26 bỏ
mô hình "1 audio = cả exercise" cho poslech_1 và chuyển sang
"1 audio = 1 ListeningItem"; mỗi câu có mini-player riêng trên
Flutter, pause-others coordinator đảm bảo chỉ 1 câu chạy cùng lúc.
Backward compat: seed cũ vẫn play single audio cho đến khi admin
click Generate audio để upgrade.

Spec: `docs/specs/poslech-per-item-audio.md`. Plan + todo:
`tasks/v26-poslech-per-item-audio-{plan,todo}.md`. Idea:
`docs/ideas/poslech-per-item-audio.md`.

Scope là poslech_1 only. poslech_2/3/4 (cùng schema gia đình) giữ
single-audio path; mở rộng sang slice sau nếu cần.

### Backend (Phase A + B)

- **`processing.BuildExerciseItemTexts(exercise) []ItemText`**
  (`exercise_audio.go`): trả slice per-item text cho poslech_1,
  skip items đã upload (`AssetID != ""`) và items không có text.
  `nil` cho non-poslech_1 — scope guard tránh poslech_2 vô tình
  lọt qua đường mới.
- **`PollyExerciseAudioGenerator.GenerateItemAudio(eid, n, text)`**:
  mirror `GenerateSentenceAudio` (V18 dictation pattern). Storage
  key `exercise-audio/<eid>/item-<n>.mp3`. Empty text → error.
- **`DevExerciseAudioGenerator.GenerateItemAudio`**: writes silent
  WAV stub cho dev/test. Cùng namespace
  `exercise-audio/<eid>/item-<n>.wav`.
- **`ItemAudioGenerator` interface**: extends
  `ExerciseAudioGenerator`, both Dev + Polly satisfy. Admin endpoint
  type-asserts để fork branch.
- **`handleAdminGenerateAudio` poslech_1 fast-path**
  (`server.go:1322` + `generatePoslech1ItemAudio` helper): khi
  `audioGenerator` thoả `ItemAudioGenerator` và
  `BuildExerciseItemTexts` non-empty, loop sequential generate, mutate
  `Detail.Items[i].AudioSource.AssetID = result.StorageKey`, gọi
  `repo.UpdateExercise({Detail: ...})` để persist. Last item's
  audio cũng được `SetExerciseAudio` để legacy `/v1/exercises/:id/audio`
  vẫn answer hợp lý cho client cũ chưa nâng cấp.
- **Rollback**: collect `written` storage keys từng vòng; nếu item
  thứ N fail, `os.Remove` tất cả file đã write trước đó (best-effort,
  IsNotExist không log fatal) + skip `UpdateExercise` → exercise
  unchanged. Admin retry không tạo orphan asset_id.
- **Response shape**: giữ `data.{storage_key, mime_type, source_type,
  generated_at}` cho compat (= last item's audio); thêm
  `meta.item_count` (= số file đã generate).
- **Fallback paths**: poslech_2/3/4/5/6, exercise legacy không có
  text segments, hoặc audioGenerator chỉ là single-audio interface
  → vẫn dùng nhánh dialog/single-voice gốc.

### Flutter (Phase C)

- **`PoslechItemView.audioAssetId`**: hydrate từ
  `audio_source.asset_id` JSON khi parse `ExerciseDetail`.
- **`itemsHavePerItemAudio(detail)` helper** (exported via
  `@visibleForTesting`): true iff exercise_type là poslech_1, có
  items, và mỗi item có `audioAssetId.isNotEmpty`. Dùng cho cả
  screen logic lẫn unit test để có 1 quy tắc duy nhất.
- **`ListeningExerciseScreen` refactor**: top-level
  `_LegacyAudioPlayerBar` chỉ render khi `itemsHavePerItemAudio`
  false; per-item branch render `_ItemAudioPlayerBar` inline phía
  trên question label của mỗi item.
- **`_ItemAudioPlayerBar`**: lazy `setAudioSource` (chỉ khi user tap
  play đầu tiên) → mở screen không bùng 5 network call. Lifecycle
  cleanup `_player.dispose()` + cancel stream subscription.
- **`_PlaybackCoordinator`** (`ChangeNotifier`): each player owns
  `playerId = item.questionNo`. `claim`/`release` đẩy sự kiện;
  player khác listen và pause khi active != my id. Đảm bảo "chỉ 1
  câu chạy cùng lúc".
- **`_AudioBarShell`**: shared visual (headphones icon + status
  text + play/retry button) cho cả 2 bar variants — single style
  source.

### Docs

- `docs/ideas/poslech-per-item-audio.md` — one-pager idea.
- `docs/specs/poslech-per-item-audio.md` — Status: Draft → Shipped.
- `tasks/v26-poslech-per-item-audio-plan.md` — 4 phase A-D với
  dependency graph.
- `tasks/v26-poslech-per-item-audio-todo.md` — RED/GREEN checklist
  từng task.
- `docs/reference/content-and-attempt-model.md` § Listening: ghi
  rõ poslech_1 V26 audio model + fallback semantics.
- `SPEC.md` digest: row V26.

### Tests

Backend: 859 tests pass. Phase A added 9 (per-item text extraction
× 5, item audio gen × 3, interface satisfaction × 1). Phase B added
3 (happy 5-asset, rollback at item 3, all-uploaded fallback to 400).
Flutter: 373 tests pass. Phase C added 7 (PoslechItemView hydration
× 3, itemsHavePerItemAudio truth-table × 4 covering scope guard,
all-have, mixed, empty).

### Out of scope

- ❌ poslech_2/3/4 per-item audio
- ❌ Vocab V11 per-item TTS
- ❌ Image A-D per choice (slice riêng đã review tách biệt)
- ❌ CMS UI thay đổi — admin click "Generate audio" như cũ, backend
  tự loop 5 lần
- ❌ Migration regenerate seed cũ — admin tự click khi muốn upgrade

---

## V25 — IAP Wire Real — 2026-05-08

V17 shipped backend `/v1/iap/apple/verify` + `/webhook` + `pro_purchases`
table but Flutter held a `StubIAPService` that threw `not_implemented`
on every Buy. V25 wires production StoreKit, adds Sign-in with Apple
(App Store guideline 4.8), closes V18-polish webhook gaps that mattered
for downgrade, and ships the 3.1.2(a) disclosure copy + 4 upgrade entry
points so a free learner has a one-tap path to Pro.

Spec: `docs/specs/iap-wire-real.md`. Plan + todo:
`tasks/v25-iap-wire-real-{plan,todo}.md`. Idea:
`docs/ideas/iap-wire-real.md`. Pricing decision (D4): 99k VND/month +
790k VND/year (-33% saving) — Apple Pricing Tier 19 + ~159, threshold
< 100k for "thử được" + < 800k undercutting Mondly equivalents.

### Backend (Phase A-C)

- **Migration 028** (`backend/db/migrations/028_v25_user_apple_sub.sql`)
  + ensureSchema mirror in `postgres_users.go`: `users.apple_sub TEXT`
  + partial unique index `WHERE apple_sub IS NOT NULL AND deleted_at IS
  NULL`. Idempotent.
- **`UserStore.UpsertByAppleSub(sub, email, displayName)`**: Apple-
  verified email auto-flagged (`email_verified_at = now`,
  `grace_attempts_left = graceAfterVerify`). Placeholder
  `password_hash = "apple_oauth:<sub>"` so the legacy `password_hash
  required` guard accepts the row but bcrypt-compare against any
  password always fails. Idempotent: replay returns existing user
  untouched (Apple only emits email/name on the first sign-in).
- **`iap.AppleJWKSVerifier`** (`backend/internal/iap/apple_jwks.go`):
  wraps `lestrrat-go/jwx/v2/jwk.Cache` (24h refresh, auto rotation).
  `Verify(ctx, idToken)` enforces `iss=https://appleid.apple.com`,
  `aud=<bundle_id>`, `exp > now`, claim signature against cached
  JWKS. Two constructors: production cache-backed
  (`NewAppleJWKSVerifier`) + offline static-set
  (`NewAppleJWKSVerifierWithSet`) for tests.
- **`POST /v1/auth/apple`** (`auth_handlers_apple.go`): body
  `{identity_token, authorization_code, nonce, given_name?,
  family_name?}` → JWS verify → nonce match (SHA256-hashed both
  sides) → `UpsertByAppleSub(claims.Sub, claims.Email, given+family)`
  → mint 90-day session token. Errors collapse to `invalid_token` /
  `nonce_mismatch` / `expired_token` / `invalid_audience` /
  `issuer_mismatch` / `invalid_credential`. Unregistered when
  `appleJWKS = nil` (legacy + dev fixture builds).
- **`ProPurchaseStore.FindByTransactionID(txn)`**: returns the row
  even after `MarkProPurchaseInactive` so REFUND-after-EXPIRED
  replays still resolve `user_id`.
- **Webhook downgrade stitch** (`applyWebhookExpiration` rewrite +
  `applyWebhookRefund` reuse): `FindByTransactionID(notif.txn).user_id`
  → `MarkProPurchaseInactive` → `downgradeIfExpired(user_id)`. Apple
  ASSN no longer needs the Flutter `purchaseStream` observer to fire
  for a free-tier flip — EXPIRED auto-flips `pro_tier=free` even
  when the user is offline.

### Flutter (Phase D-F + H1)

- **Pubspec**: `+in_app_purchase: ^3.2.0` `+sign_in_with_apple: ^6.1.0`
  `+url_launcher: ^6.3.0` `+crypto: ^3.0.3`. iOS `Runner.entitlements`
  adds `com.apple.developer.applesignin` (Default scope). pbxproj
  threads `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements`
  through Profile/Debug/Release.
- **`RealIAPService`** (`lib/core/iap/real_iap_service.dart`): owns
  the singleton `purchaseStream` observer; `start()` is idempotent,
  `dispose()` cancels. `loadProducts()` uses
  `InAppPurchase.queryProductDetails(IAPProducts.all.toSet())`.
  `buy()` parks a `Completer` keyed by productId; the observer
  resolves on `purchased`/`restored` (after firing the verifyReceipt
  callback) and rejects on `error`/`canceled`. Every event with
  `pendingCompletePurchase=true` triggers `completePurchase()` so
  StoreKit's transaction queue does not flood. `InAppPurchaseClient`
  seam lets unit tests drive the flow without a real plugin.
- **`VerifyReceiptFn` typedef** plus `IAPServiceProvider`
  InheritedWidget: production wires `RealIAPService(verifyReceipt:
  (r,p) => apiClient.verifyAppleReceiptV17 + authService.refresh)`
  via `_buildIAPService` in `main.dart`, guarded by `kIapEnabled =
  bool.fromEnvironment('IAP_ENABLED', defaultValue: true) && !kIsWeb
  && Platform.isIOS`. Web, Android, legacy fixture builds + widget
  tests fall back to `StubIAPService`. `MluveniSprintApp` flipped to
  `StatefulWidget` so the Real service is disposed on tear-down (no
  zombie StoreKit listeners across hot-restart).
- **`AuthService.signInWithApple()`** (`lib/core/auth/auth_service.dart`):
  generates 32-char URL-safe nonce, SHA256-hashes once, passes the
  hash to both `SignInWithApple.getAppleIDCredential(nonce: hashed)`
  and the backend payload. `AppleCredentialFn` typedef injected into
  the constructor for unit tests. `SignInWithAppleAuthorizationException`
  → `AuthException(code: sign_in_canceled | apple_sign_in_failed)`;
  missing identity_token → `invalid_credential`. Backend errors
  surface verbatim via `AuthException` from `_v17Request`.
- **`ApiClient.signInWithAppleV25(...)`**: thin wrapper around
  `_v17Request` POST `/v1/auth/apple` that parses `AuthSession` and
  attaches the session token to the client.
- **`AppleSignInButton` + `OrDivider`** (`lib/features/auth/widgets/`):
  shared widgets so Welcome / Login / Signup don't reinvent the
  busy + error band. `SignInWithAppleButton` package widget at
  `style: .black`, `height: 52`, `borderRadius: 12` — equal
  prominence with the email FilledButton (App Store 4.8). Cancel
  silently dismisses (no error band); `invalid_token`/`nonce_mismatch`
  surface localized "Phiên đăng nhập Apple không hợp lệ" copy.
- **PaywallScreen disclosure compliance** (App Store 3.1.2(a)):
  `_SubscriptionDisclosure` block (auto-renewal text, billing-via-
  Apple-ID, manage-cancellation path) renders unconditionally —
  including while `loadProducts()` is in flight, so reviewers see it
  on every paywall state. `_LegalLinksRow` Wrap with Terms +
  Privacy `paywall_terms_button` / `paywall_privacy_button` keys
  dispatch through `PaywallUrlLauncher` typedef (default
  `launchUrl(externalApplication)`). `LegalUrls` const is the
  swap-in-one-place when ops moves the marketing host. Body
  rewrapped in `SingleChildScrollView` (replace `Spacer` →
  `SizedBox(24)`) so 320pt iPhone SE no longer overflows.
- **Upgrade entry points (F2)**: 4 surfaces wire toward the paywall
  so a free learner can always reach it.
  - **Profile**: `_ProUpgradeTile` between v17 account section and
    progress entry. Free user sees a CTA card → push
    `PaywallScreen`. Pro user sees "Quản lý đăng ký Pro" → external
    deep link to `apps.apple.com/account/subscriptions`.
  - **Exercise screen 429**: `_maybeShowUpgradePrompt` fires
    `UpgradePromptDialog.showForAttemptQuota` on top of the existing
    `recordErrorRateLimit` toast — modal CTA in addition to text.
  - **Interview start 429**: `getInterviewToken` catch detects
    `ApiException(429)` → `UpgradePromptDialog.showForInterviewQuota`
    above the connect-error snackbar.
  - **Home (`course_list_screen`)**: `_loadUsage` calls
    `fetchStreakAndUsageV17`; `QuotaIndicator` banner renders below
    the level header, hidden for Pro via `proHide`. `onTapWhenFull`
    pushes paywall.

### iOS sandbox (Phase H1)

- `flutter_app/ios/Configuration/CzechGoPro.storekit` mirrors App
  Store Connect: monthly 99.000 ₫ + yearly 790.000 ₫ in Subscription
  Group "Czech Go Pro" (`P1M` + `P1Y`, storefront VNM, VI + EN
  localizations). Run scheme `<StoreKitConfigurationFileReference>`
  points 3 levels up to the .storekit so simulator buys don't need
  a sandbox tester or signed Paid Apps Agreement.
- `docs/guides/v25-iap-sandbox-smoke.md`: 7-step playbook (verify
  scheme → run with `--dart-define=USE_V17_AUTH=true
  --dart-define=IAP_ENABLED=true` → buy monthly → restore → cancel
  via Settings + handcraft EXPIRED to /webhook → buy yearly), with
  pitfall table (loader hangs, 401, webhook secret mismatch,
  apple_disabled 503, simulator-vs-prod receipt).

### Legal docs (Phase G)

- `docs/reference/legal-eula.md` (245 lines, VI primary + EN
  section): subscription auto-renewal, refund-via-Apple, intellectual
  property, Apple Standard EULA-required clauses (Apple as
  third-party beneficiary, no maintenance liability), Czech Republic
  / Vietnam jurisdiction. Operator TBD on owner name + support email
  + EULA hosting URL.
- `docs/reference/legal-privacy.md` (313 lines, GDPR + Vietnam
  Decree 13/2023 aligned): declared data cross-checked with V17/V25
  actual collection — `users.{email, password_hash, apple_sub,
  display_name, avatar_asset_id, push_token, timezone}`,
  `pro_purchases.{apple_transaction_id, …, receipt_payload}`,
  `attempts`/`feedback`/`streak_days`/`daily_usage`,
  `auth_tokens.{user_agent, ip_address}`. Sub-processor table:
  Apple, Anthropic (US), AWS Polly+Transcribe+S3+SES (Singapore /
  Frankfurt), ElevenLabs (US), Replicate (US — no user data sent).
  Retention windows: account ∞, recordings 90d, OCR 24h, receipts
  7y, audit 12m. Account deletion exposed in-app via
  `Profile → Delete Account` (V17 §10 / App Store 5.1.1(v) compliant).

### Defer V25.1

JWS verify ASSN webhook (Apple public-key JWT verify) — currently
guarded by `IAP_WEBHOOK_SECRET` shared-secret stopgap + IP allowlist;
`FindByOriginalTransactionID` for webhook activation upsert (covers
the offline-renewal edge); refund email via SES; Family Sharing toggle;
Apple Sign-In account merge for existing email users.

### Decisions worth remembering

- **D3 Apple Sign-In creates a separate account per `apple_sub`** —
  no auto-merge with existing email accounts, even on email
  collision. Boring path; Apple's "Hide my email" relay (`*@privaterelay.appleid.com`)
  stored verbatim. Manual link-via-Profile deferred V26.
- **D4 pricing 99k/790k VND** (saving badge "Tiết kiệm 33%") chosen
  over 17% (V17 default) to push annual commit; A/B sweep deferred
  until 100 conversions baseline.
- **D5 defer ALL 4 V25.1 polish items** (JWS verifier, webhook
  activation upsert, refund email, Family Sharing) — Flutter
  observer covers ~80% renewal flow; refund email is low priority.
- **Apple new user → `current_level='a0'`** (DB default), goes through
  V21 onboarding/placement same as email signup. Spec §4.2 wording
  ('a2' default) was imprecise — only the V21 backfill (mig 026)
  promoted *existing pre-V21 users* to a2; new V21+ users start a0.
- **Spec `com.apple.developer.in-app-payments` entitlement struck**:
  that's Apple Pay merchant, NOT StoreKit IAP. StoreKit needs no
  entitlement file; only Sign-in-with-Apple does.
- **`PaywallUrlLauncher` typedef** + injectable `urlLauncher` ctor
  param — same testability pattern as `AppleCredentialFn`.

### File changes

Backend (17 files): migration 028, contracts/user_account.go,
httpapi/{auth_handlers, auth_handlers_apple[+test], iap_handlers,
iap_webhook_v25_test, server}, iap/{apple_jwks[+test]},
store/{postgres_users, pro_purchase_store[+test], user_store[+test]},
go.mod / go.sum (`+lestrrat-go/jwx/v2 v2.1.6` + transitive).

Flutter (29 files): pubspec.yaml/lock, ios/Runner/Runner.entitlements,
ios/Runner.xcodeproj/{project.pbxproj, xcshareddata/xcschemes/Runner.xcscheme},
ios/Configuration/CzechGoPro.storekit, ios/Podfile.lock,
android GeneratedPluginRegistrant (auto), lib/core/{api/api_client,
auth/auth_service, config/legal_urls, iap/{iap_service_provider,
real_iap_service}}, lib/features/auth/{screens/{login, signup,
welcome}_screen, widgets/apple_sign_in_button}, lib/features/{exercise,
home, interview, paywall, profile}/screens/* (5 entry-point edits),
lib/main.dart, 6 test files.

Docs (5 + 4 task index): `docs/{ideas, specs}/iap-wire-real.md`,
`docs/reference/legal-{eula, privacy}.md`,
`docs/guides/v25-iap-sandbox-smoke.md`, `tasks/v25-iap-wire-real-{plan,
todo}.md`, `tasks/{plan, todo}.md` index updates.

### Test counts

- Backend: 822 → **845** (+23) — 3 UpsertByAppleSub, 4 AppleJWKS, 2
  FindByTransactionID, 8 handleAuthApple (incl 2 happy + 4 error
  shape + missing-fields + disabled-when-nil), 1 server integration
  smoke, 3 webhook downgrade.
- Flutter: 309 → **366** (+57; V25 contributes ~22) — 7
  RealIAPService observer flows, 4 AuthService.signInWithApple, 5
  Apple button render+dispatch (3 screens + error inline + cancel
  silent), 2 paywall disclosure + Terms launcher, 2 ProUpgradeTile
  free/pro variants, 1 IAPServiceProvider smoke.
- CMS: 144 (no change).
- `make verify` green; iOS `flutter build ios --debug --no-codesign`
  passes 11.8s.

### Out of scope (operator gate, V25-H2/H3)

- App Store Connect tax/banking submission (Paid Apps Agreement) —
  1-2 week Apple lead time, blocks production launch but not
  sandbox/TestFlight.
- Subscription products created with the V25 tier numbers + VI/EN
  localization, sandbox testers ≥ 2.
- App Privacy declarations (must mirror `legal-privacy.md` §3).
- TestFlight beta build upload + Apple beta review.
- Manual smoke pass on iPhone 17 Pro Max simulator: 5 flows
  (sign-in email + Apple, buy monthly + yearly, restore, cancel +
  expire).

---

## V24 — Reading-Exercise AI Draft Generator — 2026-05-08

V23 polished authoring ergonomics, but the structural cost of writing a
new cteni passage (100-200 words of natural Czech + 5 questions × 4
options + correct answers) was still 20-40 min/exercise. V24 cuts that
to ~5 min by letting Claude draft the payload from a `(topic, grammar,
level)` triple. Admin reviews + edits the populated form fields and
saves manually — no auto-publish.

Spec: `docs/specs/v24-doc-draft-generator.md`. Plan + todo:
`tasks/v24-doc-draft-generator-{plan,todo}.md`. UX one-pager:
`docs/ideas/exercise-draft-generator-ux.md`.

### Key changes

- **Backend endpoint** `POST /v1/admin/exercises/generate-draft`. Body:
  `{exercise_type, topic, grammar_point_ids, level, extra_instructions}`.
  Resolves grammar IDs against the existing `grammar_rules` store,
  rate-limits at 5 calls/min/admin (separate window from the AI image
  endpoint), calls `processing.ReadingDraftGenerator.Generate` with a
  30s context timeout, validates the AI output via
  `processing.ValidateReadingDraft`, returns `{data: ReadingDraft}` on
  200. 8 distinct error codes covered by tests: 400 invalid_request, 404
  grammar_point_not_found, 405 method_not_allowed, 422 schema_mismatch,
  429 rate_limited, 502 llm_error, 503 not_configured, 504 timeout.

- **Per-cteni-type tool_use schemas** (one per task B1..B6). Each cteni
  type has its own JSON schema, prompt branch, validator, and parser:
  cteni_2 (text + 5×4MC A-D), cteni_4 (optional context + 6×4MC),
  cteni_5 (text + 5 fill-info ≤30 chars), cteni_6 (passage + 1-5 ANO/NE
  with strict UPPERCASE), cteni_3 (4 texts → 5 persons A-E with unique
  match), cteni_1 (5 text-only items + 8 options A-H, no asset_id —
  admin uploads images post-fill, schema sets
  `additionalProperties:false` to prevent leakage). All schemas use
  Anthropic `tool_use` enforcement so malformed output is rejected by
  Claude before it leaves the API.

- **`ReadingDraftSystemPrompt`** in `llm_prompts.go` covers cross-cutting
  rules: CEFR-appropriate vocabulary, distractor plausibility, no
  English/Vietnamese leakage in Czech text, ANO/NE casing, no asset_id.

- **Per-type structural requirements** in `BuildReadingDraftUserPrompt`
  (`llm_user_prompts.go`) — passage length, question count, option
  enforcement, distractor rules per cteni type.

- **`Exercise.CreatedByLLM bool`** field (migration: inline `ALTER TABLE
  exercises ADD COLUMN IF NOT EXISTS created_by_llm BOOLEAN NOT NULL
  DEFAULT FALSE` in `postgres_exercises.go ensureSchema`). **Sticky on
  upsert** — `created_by_llm = exercises.created_by_llm OR
  EXCLUDED.created_by_llm` so admin edits cannot strip the flag.
  `POST /v1/admin/exercises` accepts the flag in the request body.

- **CMS `AiDraftPanel`** mounted at the top of `CteniFields.tsx` for
  cteni_1..5. State machine (`reduceDraftState`): idle → loading →
  success / error / confirm-overwrite. AbortController cancels in-flight
  fetch on Hủy. Server error codes mapped to inline VI messages via
  `mapServerError`. Direct-fill goes through the existing `initState`
  decoder — same path as exercise edit, no new mapping logic to keep
  in sync.

- **Off-switch**: `ANTHROPIC_API_KEY` unset → handler returns 503
  `not_configured`. (Earlier draft considered an explicit
  `LLM_READING_DRAFT_MODEL=""` flag, but the shared `env()` helper
  short-circuits empty values to default; the API-key gate is simpler
  and consistent with other AI endpoints.)

### File changes

Backend (new):
- `internal/processing/reading_draft_generator.go` (Claude impl + tool
  schemas + parser + dispatch)
- `internal/processing/reading_draft_validator.go` (per-type validators
  + shared helpers)
- `internal/processing/reading_draft_generator_test.go`,
  `reading_draft_validator_test.go`, `llm_config_test.go`
- `internal/httpapi/admin_draft_handler.go` + `_test.go`
- `internal/httpapi/draft_flow_test.go` (E2E smoke)

Backend (modified):
- `internal/contracts/types.go` — Exercise.CreatedByLLM, ReadingDraft*,
  ReadingDraftMeta, ReadingDraftInput
- `internal/processing/llm_prompts.go` — ReadingDraftSystemPrompt
- `internal/processing/llm_user_prompts.go` — BuildReadingDraftUserPrompt
  + readingDraftStructuralRequirements per type
- `internal/processing/llm_config.go` — LLM_READING_DRAFT_MODEL env +
  default
- `internal/store/postgres_exercises.go` — ALTER TABLE + INSERT/UPSERT/
  SELECT/scan threading the flag through with sticky-on-upsert semantics
- `internal/store/memory_test.go` — TestCreateExercisePreservesCreatedByLLM
- `internal/httpapi/server.go` — readingDraftGenerator field + DI in
  assembleServer + route + created_by_llm in admin create body

CMS (new):
- `cms/app/api/admin/exercises/generate-draft/route.ts` (Next.js POST
  proxy)
- `cms/lib/ai-draft-utils.ts` (pure helpers: validation, error map,
  reducer, payload mapper)
- `cms/components/ai-draft/AiDraftPanel.tsx`
- `cms/components/ai-draft/GrammarPointPicker.tsx`
- `cms/components/ai-draft/LevelRadio.tsx`
- `cms/__tests__/ai-draft-utils.test.ts`,
  `cms/__tests__/cteni-dirty.test.ts`

CMS (modified):
- `cms/components/exercise-form/CteniFields.tsx` — mount AiDraftPanel +
  export isCteniDirty for the overwrite check + handleAiApply re-runs
  initState

Docs:
- `docs/ideas/exercise-draft-generator.md` (idea)
- `docs/ideas/exercise-draft-generator-ux.md` (UX)
- `docs/specs/v24-doc-draft-generator.md` (spec)
- `docs/reference/api-contracts.md` (endpoint + created_by_llm note)
- `docs/reference/infrastructure-baseline.md` (LLM env table row)
- `tasks/v24-doc-draft-generator-{plan,todo}.md`
- `Makefile` (`make smoke-draft-flow` target wired into `smoke-all`)
- `SPEC.md` (digest row), `tasks/{plan,todo}.md` (indexes)

### Decisions

- **Sync endpoint, not async via `content_generation_jobs`** —
  generating a single 1-exercise draft in <10s doesn't benefit from
  async + polling. Keeps UX direct-fill (per UX spec).
- **No preview pane / variant picker** — admin edits inline; 3× token
  cost on variants doesn't justify the marginal value.
- **cteni_1 text-only**, image upload deferred — Replicate Flux for
  per-item images would 5× the cost + add a flaky dependency. Admin
  uploads images after fill, same as today.
- **cteni_6 backend ships, CMS panel deferred** — `AnoNeFields` host
  was out of scope for the V24 surgical-precision target. Backend
  endpoint accepts cteni_6 today; UI in V25.
- **Exercise.CreatedByLLM sticky on upsert** so manual edits can never
  silently re-classify an AI-drafted exercise as human-authored.
- **Off-switch via ANTHROPIC_API_KEY presence**, not a separate flag.
- **Skip `LLM_READING_DRAFT_MODEL=""` honoring** — `env()` helper
  semantics make that approach unimplementable without an extra
  sentinel; not worth the complexity.

### C4 Czech-quality gate (NOT YET RUN)

Plan §C4 calls for a manual review of 30 drafts (5 × 6 cteni types)
by a Czech native or qualified A2/B1 teacher before promoting V24 on
production. PASS = ≥21/30 usable as-is or with minor edits. Until
that gate runs, leave `ANTHROPIC_API_KEY` unset on prod — the handler
returns 503 and the panel shows "Tính năng AI chưa được cấu hình".

If <21/30 with Haiku 4.5: retest with `LLM_READING_DRAFT_MODEL=claude-sonnet-4-6`.
If still <21/30: revert V24 (the panel is opt-in via the API key gate
so no learner-facing impact remains).

Result placeholder in `tasks/v24-doc-draft-generator-todo.md` §C4.

### Test counts

- Backend: ~+78 tests across A1..C2 (memory store + llm_config +
  reading_draft_validator + reading_draft_generator + admin_draft_handler
  + draft_flow E2E). Full `make backend-test` green.
- CMS: +37 tests (29 ai-draft-utils + 8 cteni-dirty regression). Total
  256 pass via `cd cms && npm test`. Lint clean. Production build green;
  `/api/admin/exercises/generate-draft` route registered.
- Smoke: `make smoke-draft-flow` runs `TestV24DraftFlow_E2E` in-process
  end-to-end; folded into `make smoke-all`.

### Out of scope (deferred)

- `viet`/`nghe`/`noi` generators → V25+
- Bulk module generator (one topic → all 7 skills) → future
- ExerciseListView ✨ badge + AI-drafted filter chip → V25 (flag already
  round-trips, no backend change needed)
- AnoNeFields cteni_6 panel host → V25
- Variant picker, preview pane, image generation for cteni_1 → out of
  V24 scope per spec §14
- Auto grammar/level second-pass quality verification → out

---

## V23 — Exercise Authoring Polish — 2026-05-08

V22 closed the admin debug + content-health gap, but exercise
authoring stayed slow: a 1361 LOC form, audio gen one button at a
time, and zero learner-side preview meant every new bài tập went
through publish → test on Flutter → fix loops. V23 ships three
verticals to compress that loop while volume is still <50 (so the
tools land before scale pain hits).

Spec: `docs/specs/v23-exercise-authoring-polish.md`. Plan + todo:
`tasks/v23-exercise-authoring-polish-{plan,todo}.md`.

### Key changes

- **B Quick-Clone** (row action on `/`): admin clicks "Sao chép" on
  any exercise list row → backend GET source detail → CMS transforms
  via `cloneExercisePayload` (preserve module/skill/type/prompt/
  assets/sample, strip id, force status=draft, **skip exercise_audio
  link** so each clone regenerates audio against its own edited
  prompt) → POST as new draft → admin lands directly in the edit
  form on the new row. 5× faster seeding for similar bài tập (4
  Úloha 1 chủ đề khác, 5 cteni đoạn văn) without any "audio mismatch
  with prompt" risk.

- **H Validation Inline Badges** (list view): `GET /v1/admin/exercises`
  responses now carry `validation_flags` per row — five rules
  computed server-side using the same logic V22 powered the aggregate
  Content Health page with: `missing_audio` (skill=nghe with no
  exercise_audio), `missing_sentence_audio` (psani_3_dictation with
  no per-sentence audio), `orphan` (pool=course with empty
  module_id), `missing_sample` (noi/viet with sample_enabled but
  empty text), `unpublished` (draft). Admin sees ❌/⚠/📝/✓ badges
  inline next to status, plus a "Chỉ hiện vấn đề" filter checkbox to
  scope the list to rows with quality issues (drafts that are
  otherwise clean stay hidden so the admin can focus on rot, not
  workflow). Click any row → quick-fix modal: publish/unpublish radio
  + a "Tạo lại audio" button (enabled only for nghe / dictation),
  routing anything else through the full edit form. Strict V23
  scope — no module reassign, no inline sample edit.

- **C Inline Preview MVP**: split-pane layout component
  (`ExerciseEditLayout`) + preview pane with always-visible
  disclaimer band ("🔍 Preview low-fidelity. Hãy test trên Flutter
  trước khi ship."), driven by a `selectPreviewRenderer(type)`
  router. Top 5 V23 types render dedicated low-fidelity mock cards:
  uloha_1/2/3/4 (Speaking) via `UlohaPreview` (4 variants in one
  component) and `psani_2_email` (Writing) via `PsaniEmailPreview`.
  The other 11 types fall through to a placeholder explaining the
  V23 boundary. State debounced via `useDebouncedForm(form, 200)`
  hook to keep typing responsive; layout swaps to a slide-in drawer
  via `useMediaQuery('(min-width: 1280px)')` below 1280 px.

### Decisions worth remembering

- **No DB migration.** Validation flags compute on-the-fly from
  joins of existing tables; no schema change V23.
- **DRY via per-row helper.** V22's `admin_content_health.go`
  shipped six aggregate checks; V23 extracts a per-Exercise
  `computeValidationFlags(repo, ex) ValidationFlags` helper there,
  reused by both the V22 dashboard counters and the V23 list-row
  badges. Single source of truth for rule definitions.
- **Clone audio policy: skip.** Cloned exercises do not copy the
  source `exercise_audio` row. Admin runs the existing
  `POST /v1/admin/exercises/:id/generate-audio` endpoint after
  editing. Avoids prompt/audio mismatch when admin tweaks the
  source's question list in the new draft.
- **Strict quick-fix scope.** Modal only does publish/unpublish +
  audio regen. Module reassignment, sample text edits, and other
  field changes route through the full slide-over form. Keeps the
  modal predictable; no scope creep.
- **`unpublished` flag does not count as an "issue".** Draft is a
  workflow state, not content rot. The "Chỉ hiện vấn đề" filter
  hides clean drafts so the admin can triage real problems.
- **Preview is `aria-hidden`.** Preview is a visual aid; the form
  is the source of truth for screen readers. Avoids double-reading.
- **C8 live-wire deferred.** The preview pane + layout component
  + 3 renderers + helpers all ship and are unit-tested, but wiring
  them inside the existing 1361 LOC `ExerciseSlideOver` would
  require restructuring that conflicts with the V23 boundary "no
  form monolith refactor". The integration adapter ships in the
  V24 form-refactor slice. Result: V23 lands the building blocks;
  V24 plugs them in without further design work.

### File changes

**Backend (3 files)**:
- `internal/httpapi/admin_content_health.go` — `+ValidationFlags`
  type, `+computeValidationFlags(repo, ex)` helper,
  `+exerciseWithFlags` wire shape; `+strings`, `+store` imports.
- `internal/httpapi/server.go` — `handleAdminExercises` GET case
  now wraps each row with its computed flags before writeJSON.
- `internal/httpapi/admin_exercises_test.go` (new) — 3 list-shape
  tests (response includes flags / forbidden non-admin / pool
  filter still works).
- `internal/httpapi/admin_content_health_test.go` — +10
  per-rule tests on `computeValidationFlags`.

**CMS (10 files modified / created)**:
- `components/exercise-utils.ts` — `+cloneExercisePayload` helper +
  `Exercise.validation_flags?` field.
- `components/exercise-list.tsx` — `+onClone` + `+onRowClick`
  props, "Sao chép" row button, "Chỉ hiện vấn đề" filter
  checkbox, badge cluster column inline next to status pill,
  row-click → modal handler, button stop-propagation.
- `components/exercise-dashboard.tsx` — `+handleClone` (fetch +
  POST), `+quickFixId` state, mounted `<ExerciseQuickFixModal>`,
  threaded new props.
- `components/validation-badges.ts` (new) — `flagsToBadges` +
  `hasAnyIssue` pure helpers.
- `components/exercise-quick-fix-modal.tsx` (new) — modal +
  `audioRegenSupported` exported helper.
- `components/exercise-edit-layout.tsx` (new) — split-pane layout
  + drawer for narrow widths.
- `components/exercise-preview/router.ts` (new) —
  `selectPreviewRenderer`.
- `components/exercise-preview/index.tsx` (new) — `<PreviewPane>` +
  `<DisclaimerBand>`.
- `components/exercise-preview/use-debounced-form.ts` (new).
- `components/exercise-preview/use-media-query.ts` (new).
- `components/exercise-preview/uloha-preview.tsx` (new) — 4-variant
  Speaking renderer.
- `components/exercise-preview/psani-email-preview.tsx` (new).
- `components/exercise-preview/placeholder.tsx` (new).
- `__tests__/exercise-clone.test.ts` (new) — 6 cases.
- `__tests__/validation-badges.test.ts` (new) — 11 cases.
- `__tests__/exercise-quick-fix.test.ts` (new) — 4 cases on
  `audioRegenSupported`.
- `__tests__/preview-routing.test.ts` (new) — 6 cases.

### Post-review fixes

- **C-1 row layout overflow** (`exercise-list.tsx`): grid columns
  widened from `2fr 1fr 100px 96px` to `2fr 1fr 200px 240px` so the
  new validation badges (e.g. "❌ Thiếu sentence audio") fit in the
  status column and the third actions button ("Sao chép") fits
  alongside [Sửa] and [Xóa] without overflowing into the next
  column. Status cell wrapper gets `min-width: 0` + `overflow:
  hidden` and the badge cluster gets `flex-wrap: wrap` so a long
  label wraps within its column instead of pushing the layout.
- **I-1 IIFE refactor** (`exercise-list.tsx`,
  `exercise-dashboard.tsx`, `exercise-quick-fix-modal.tsx`): the
  inline-IIFE pattern (same anti-pattern V22 already fixed) is now
  replaced by a shared `<ValidationBadgeCluster flags variant>`
  component (`row` vs `modal` variants) and a `<QuickFixSlot>`
  wrapper for the modal mount. New `badgeStyle(variant)` helper
  centralises the variant → CSS variable lookup.

### Final test counts

- Backend: **696** tests (was 683 at V22 ship → +13: 10
  per-rule + 3 list-shape).
- CMS: **217** tests in **14 files** (was 190 in 10 → +27: 6
  clone + 11 badges + 4 quick-fix + 6 preview-routing).
- Flutter: **345** tests (no change — V23 does not touch Flutter).
- `make verify` (backend-build + cms-lint + cms-build +
  flutter-analyze + flutter-test): green.
- `make smoke-attempt-flow` + `make smoke-course-flow`: pass.
  `smoke-exam-flow` 401 flake remains pre-V22 baseline; not a
  V23 regression.

---

## V22 — CMS Catch-Up — 2026-05-07

CMS desk had drifted 2-3 slices behind learner-facing app: V19 mastery
aggregate, V20 Flutter UI, V21 CEFR + promotion + placement, V21.2 admin
escape hatch all shipped without a CMS counterpart for debug or content
authoring of the new constructs. V22 closes that gap with three vertical
features under a strict read-only V22 boundary.

Spec: `docs/specs/v22-cms-catch-up.md`. Plan + todo:
`tasks/v22-cms-catch-up-{plan,todo}.md`.

### Key changes

- **B Learner X-Ray** (`/users/[userId]`): admin clicks a row in the
  Users list to land on a 5-section debug screen — Profile, CEFR state
  (`current_level` / `unlocked_levels` / `placement_taken_at`),
  Mastery (per-skill × module × score × attempts × updated_at), the
  Promotion attempts ledger (capped at 20 newest with `has_more` hint),
  and Recent attempts (last 20). Backed by a new
  `GET /v1/admin/users/:id/state` aggregator that pulls from the V17
  user store, V21 user_levels, V19 user_skill_mastery, V21
  promotion_attempts, V21.2 daily_usage, and the attempts ledger.
  Read-only V22 footer offers Reset usage hôm nay (reuses V21.2
  endpoint) and a back link to the bulk Users dashboard for password
  reset / delete.

- **C Mock test list polish** (`/mock-tests`): the V21 form already had
  `is_promotion` / `is_placement` / `target_level` fields wired, but
  the list view did not surface them. Added `🎯 → A2` orange pill +
  `📍 Placement` teal pill alongside status / exam_mode badges, plus a
  "Loại" filter dropdown (Tất cả / Thường / Promotion / Placement)
  that scopes client-side. Added an app-layer "1 published promotion
  exam per `target_level`" guard: `POST` and `PATCH /v1/admin/mock-tests`
  return `409 promotion_exam_already_published` with `{level,
  existing_id, existing_title, hint}`. CMS form runs the same check
  client-side (against the in-memory `tests` array) so a yellow inline
  warning appears before submit; the backend remains the gate of last
  resort.

- **F Content Health Report** (`/content-health`): on-demand 6-rule
  scanner that surfaces content rot before it leaks to learners.
  Rules: orphan exercises (`pool=course && module_id=''`), nghe
  exercises missing `exercise_audio`, modules with zero exercises,
  mock_tests with zero sections, courses with zero modules, dictation
  exercises (`psani_3_dictation`) missing `exercise_sentence_audio`.
  Each rule caps at 50 items with a `truncated` flag. Backed by
  `GET /v1/admin/content-health` — handler-level aggregator over the
  existing `MemoryStore` facade (no new store file). UI is a 6-card
  grid with click-to-expand item tables that link to the offending
  entity. New sidebar entry "Sức khỏe nội dung".

### Decisions worth remembering

- **No DB migration.** V22-CMS reads the V21 schema as-is; the
  promotion uniqueness guard is app-layer (DB constraint enforces
  target_level required + placement-promotion mutex but not
  uniqueness, since draft + multiple target_level need to coexist).
- **`module_empty` rule, not `untested_skill_in_module`.** Spec
  originally proposed a per-skill check on each module; V22 simplifies
  to "module has zero exercises" until the per-skill rubric is needed.
- **CMS test layer = pure helpers.** CMS infra is plain Vitest with
  no `@testing-library/react` or `jsdom`. Component render coverage
  is delegated to manual smoke; instead, every non-trivial UI helper
  (formatters, badge spec builders, conflict detector, state machine
  predicates) is extracted to a `*-utils.ts` companion file and unit
  tested. 44 new helper tests across 3 files.
- **B11 Action footer = Reset usage only.** Spec said reuse the
  existing `ConfirmResetUsage` + `ResetPassword` modals from
  `users-dashboard.tsx`. Those are not exported and pulling them out
  was scope creep; instead the footer uses `window.confirm()` for
  Reset usage and links back to `/users` for password reset / delete
  (where the existing modals already live).
- **F is on-demand only.** Backend has no general scheduler; cron
  defers to whenever content authoring scales beyond the solo admin.
- **D0 microtask dropped.** Spec hinted at adding query-string
  filtering to `GET /v1/admin/mock-tests`. The CMS already has the
  full `tests` array in memory; D3's pre-submit warning reads that
  state directly.

### File changes

**Backend (8 files modified / created)**:
- `internal/contracts/learner_state.go` (new) — `LearnerStateResponse`
  + 5 sub-types
- `internal/store/promotion_attempts_store.go` — `ListForUser` on
  interface + memory + postgres
- `internal/store/attempt_store.go` — `ListAttemptsForUser` on
  interface + memory; `+sort` import
- `internal/store/postgres_attempts.go` — postgres
  `ListAttemptsForUser` reusing `attemptSelectQuery`
- `internal/store/mock_test_store.go` — `FindPublishedPromotionByLevel`
  on interface + memory
- `internal/store/postgres_mock_tests.go` — postgres
  `FindPublishedPromotionByLevel`
- `internal/store/memory.go` — `ListAttemptsForUser` +
  `FindPublishedPromotionByLevel` facade forwarders
- `internal/httpapi/admin_user_state.go` (new) — handler
  `GET /v1/admin/users/:id/state`
- `internal/httpapi/admin_content_health.go` (new) — handler
  `GET /v1/admin/content-health` + 6 check functions
- `internal/httpapi/admin_users.go` — sub-resource case `state`
- `internal/httpapi/server.go` — `checkPromotionUniqueness` helper +
  wired into POST / PATCH handlers; new
  `/v1/admin/content-health` route

**CMS (12 files modified / created)**:
- `app/api/admin/users/[userId]/state/route.ts` (new) — proxy
- `app/api/admin/content-health/route.ts` (new) — proxy
- `app/users/[userId]/page.tsx` (new) — page route
- `app/content-health/page.tsx` (new) — page route
- `components/learner-xray.tsx` (new, ~360 LOC) — X-Ray component
- `components/learner-xray-utils.ts` (new) — formatter helpers
- `components/content-health.tsx` (new, ~250 LOC) — health report
- `components/content-health-utils.ts` (new) — entityLink + state
  helpers
- `components/mock-test-dashboard-utils.ts` (new) — gatingBadge /
  kindFilter / findPromotionConflict
- `components/mock-test-dashboard.tsx` — wired badge + filter +
  inline conflict warning + 409 toast
- `components/users-dashboard.tsx` — wrap email cell in `<Link>` to
  X-Ray
- `components/cms-sidebar.tsx` — new "Sức khỏe nội dung" entry
- `app/globals.css` — `.badge-promotion` / `.badge-placement`
- `lib/i18n.tsx` — `nav.contentHealth` (VI + EN)

**Tests**:
- Backend: 21 new tests across 5 files
  (`promotion_attempts_store_test.go` +3 list-for-user, +4
  find-published-promotion; `memory_test.go` +1 list-attempts-for-user;
  `admin_user_state_test.go` 5 X-Ray cases; `admin_mock_tests_test.go`
  4 promotion conflict cases; `admin_content_health_test.go` 4
  content-health cases).
- CMS: 44 new helper tests across 3 files
  (`learner-xray-helpers.test.ts` 17, `mock-test-dashboard-conflict.test.ts`
  19, `content-health-helpers.test.ts` 10).

### Post-review fixes

- **I-1 backend enum validation** (`server.go:validateMockTestPromotion`):
  promotion mocks must carry `target_level` ∈ {a0, a1, a2, b1}. Stray
  values (incl. empty) → `400 invalid_target_level`. Wired into POST +
  PATCH paths. 3 new tests.
- **S-3 module label N+1** (`admin_user_state.go`): pre-fetch the full
  module list once into a `map[id]title`, replace per-row
  `ModuleByID` lookups. Single facade call vs 30 — material on
  postgres.
- **S-6 IIFE refactor** (`mock-test-dashboard.tsx`): lift the
  `findPromotionConflict` call out of the inline IIFE inside JSX into
  a `promotionConflict` const at the top of the component; render the
  warning via standard `{conflict && <div>}`.

### Final test counts

- Backend: **683** tests (was 659 at V21.3 ship → +24, including I-1
  validation fix).
- CMS: **190** tests in **10 files** (was 144 in 7 → +46).
- Flutter: **345** tests (no change — V22-CMS does not touch Flutter).
- `make verify` (backend-build + cms-lint + cms-build + flutter-analyze
  + flutter-test): green.
- `make smoke-attempt-flow` + `make smoke-course-flow`: pass.
  `make smoke-exam-flow` fails 401 on `/v1/attempts/:id/audio` —
  reproduced on `main` before this slice; pre-existing flake unrelated
  to V22-CMS.

---

## V21.3 — CEFR UI Wire-up — 2026-05-07

All V21 CEFR backend features existed since V21..V21.2 but no widget was
wired into the Flutter router. This slice mounts every V21 widget end-to-end
so the learner can see their level, do placement, confirm existing level,
use locked-course UI, and run the promotion exam.

### Key changes

- **Backend** — `POST /v1/users/me/placement-test/skip` added: parks a fresh
  learner at A0 with `placement_taken_at = now` without running a 12-min
  session. Idempotent (409 on replay). 5 handler tests.

- **Flutter — fresh-signup onboarding** — `CefrAuthGate` sits between
  `AuthState.authenticated` and `LearnerShell`. Fetches level-progress and
  routes: loading → spinner; fresh-A0 (no placement) → `WelcomeScreen` →
  `PlacementTestScreen`; already-onboarded → shell. `_CefrOnboarding` in
  `main.dart` wires the gate with `LevelApi` from the auth service's client.
  `PlacementTestScreen` calls `startPlacement` + `getMockExam`, wraps
  `MockExamScreen(onCompleted)`, then calls `completePlacement` → pushes
  `PlacementResultScreen`.

- **Flutter — existing-A2 confirm dialog** — `ExistingLevelConfirmDialog`
  (`PopScope(canPop: false)`, 4 ARB keys) is shown exactly once by the gate
  when `currentLevel != a0 && placementTakenAt == null && !promptShown`.
  Confirm: `skipPlacement()` + `markExistingPromptShown()` + refresh.
  Retest: `markExistingPromptShown()` + push `PlacementTestScreen(force)`.

- **Flutter — home level header** — `CourseListScreen` accepts optional
  `LevelApi?`. When provided, `HomeLevelHeader` (badge + ring + banner) renders
  above the course list. `LearnerShell` passes the api from `_client`.

- **Flutter — locked courses** — `CourseListScreen` switches to
  `LockedCourseTile` for any course with `unlockState == locked`. Tap opens
  `LockedCourseSheet`. Demo CTA routes to `CourseDetailScreen`.

- **Flutter — promotion exam** — Banner tap (`HomeLevelHeader.onTapPromotion`)
  routes to `PromotionExamFlow`: `PreExamScreen` → `createPromotionAttempt` →
  `MockExamScreen(onCompleted)` → `PromotionResultScreen`. `onFinished` pops
  and refreshes the level header.

- **`MockExamScreen`** — Added optional `onCompleted(sessionId)` hook. When
  set, suppresses `_MockExamResultView` and calls the hook via
  `postFrameCallback`; caller owns the result screen.

- **`CefrPrefs`** — New `SharedPreferences` helper for two CEFR pref keys
  (`cefr_existing_prompt_shown`, `promo_banner_dismissed_for_<level>`).

### File changes

```
flutter_app/
  lib/core/api/level_api.dart             +skipPlacement() method
  lib/core/storage/cefr_prefs.dart        NEW — CefrPrefs helper
  lib/features/mock_exam/screens/
    mock_exam_screen.dart                 +onCompleted hook
  lib/features/onboarding/
    cefr_auth_gate.dart                   NEW — routing gate
    placement_test_screen.dart            NEW — placement wrapper
    existing_level_confirm_dialog.dart    NEW — one-time dialog
    welcome_screen.dart                   (existing, now wired)
    placement_result_screen.dart          (existing, now reachable)
  lib/features/home/screens/
    course_list_screen.dart               +levelApi, HomeLevelHeader, locked tiles
  lib/features/promotion/
    promotion_exam_flow.dart              NEW — pre-exam → exam → result
    pre_exam_screen.dart                  (existing, now reachable)
    promotion_result_screen.dart          (existing, now reachable)
  lib/main.dart                           _CefrOnboarding + LevelApi wire-up
  lib/l10n/app_vi.arb + app_en.arb        +4 keys each (v213Existing*)

backend/
  internal/httpapi/placement_handler.go  +handlePlacementTestSkip
  internal/httpapi/placement_handler_test.go  +5 tests
  internal/httpapi/server.go             +/placement-test/skip route

test/
  cefr_prefs_test.dart                   5 unit tests
  level_api_test.dart                    +2 (skipPlacement)
  screens/cefr_auth_gate_test.dart       6 widget tests
  screens/placement_test_screen_test.dart 4 widget tests
  screens/existing_level_prompt_test.dart 8 widget tests
  screens/course_list_level_test.dart    6 widget tests
  screens/promotion_exam_flow_test.dart  5 widget tests
```

### Test counts

| Layer | Before | After |
|---|---|---|
| Flutter | 309 | 345 |
| Backend | 654 | 659 |
| CMS | 144 | 144 |

All verified: `make flutter-analyze` + `make flutter-test` + `make backend-test`
+ `make cms-lint` + `make cms-build` green.

MobAI walkthrough: pending (requires live device session — all 10 acceptance
criteria have automated coverage).

---

## V21.2 — Exam-flow runtime hotfixes (MobAI test) — 2026-05-07

Driver: full mock-test flow run via MobAI on iPhone 17 Pro Max simulator
surfaced 3 user-visible bugs across the speaking + writing surfaces and
1 latent counter-leak in the free-tier gate. Fixed inline + added admin
escape hatch the CMS Users desk can call from now on.

### Bugs fixed

- **Critical — free-tier gate counter leak.** `checkAndIncrAttemptQuota`
  used to increment `daily_usage.attempts_count` THEN compare to cap. Each
  rejected request burned a slot, so the counter grew past cap (8, 9, 10…)
  and any future cap raise (Pro grant, env tweak) would honour the
  inflated value. New `DailyUsageStore.TryIncrementAttempts(userID, day, cap)`
  performs an atomic guarded UPSERT (`ON CONFLICT DO UPDATE WHERE
  attempts_count < $cap`) — counter now pins at cap regardless of how many
  rejected calls land. Memory + Postgres impl. Test asserts attempts 8..11
  all return 429 with `attempts_count == 7`.
  ([backend/internal/store/daily_usage_store.go](backend/internal/store/daily_usage_store.go),
  [backend/internal/httpapi/auth_gates.go](backend/internal/httpapi/auth_gates.go))

- **Important — speaking screen rendered raw `HttpException`.** Tap-mic
  on a 429 surfaced `HttpException: daily free-tier limit of 7 attempts
  reached` verbatim in the recording card with no retry path. Added
  `ApiException extends HttpException` carrying `statusCode` + `errorCode`
  + headers (case-insensitive `headerValue()` accessor) so the speaking
  screen can detect 429 and render a friendly localized message
  `recordErrorRateLimit{resetTime}` parsed from `X-Limit-Reset`. Existing
  `catch (HttpException)` sites keep working.
  ([flutter_app/lib/core/api/api_client.dart](flutter_app/lib/core/api/api_client.dart),
  [flutter_app/lib/features/exercise/screens/exercise_screen.dart](flutter_app/lib/features/exercise/screens/exercise_screen.dart))

- **Important — Psaní form keyboard focus leak.** On iOS the soft keyboard
  occluded fields 2/3 of `psani_1_formular`; tapping them did not transfer
  focus and any subsequent `type` action leaked back into field 1. Added
  bottom padding `MediaQuery.viewInsetsOf(context).bottom` + `keyboardDismissBehavior: onDrag`
  on the ListView. Same fix landed on `dictation_exercise_screen.dart`.
  ([flutter_app/lib/features/exercise/screens/writing_exercise_screen.dart](flutter_app/lib/features/exercise/screens/writing_exercise_screen.dart),
  [flutter_app/lib/features/exercise/screens/dictation_exercise_screen.dart](flutter_app/lib/features/exercise/screens/dictation_exercise_screen.dart))

### Admin reset endpoint

User feedback during the test: "CMS chưa có UI quản lý/reset daily_usage."

- **Backend** — `POST /v1/admin/users/:id/usage/reset` (admin-only). Clears
  `attempts_count` for today (VN civil day); interview counter untouched.
  503 when store missing, 404 when user missing, 401 when not admin.
  `GET /v1/admin/users` response gains `attempts_today` + `attempts_cap`
  fields populated per row (PK lookup against `daily_usage`).
  ([backend/internal/httpapi/admin_users.go](backend/internal/httpapi/admin_users.go))

- **CMS** — Users desk gains a "Hôm nay" column (`X/cap`, red bold at cap;
  `∞` for Pro) and a "Reset usage" action that pops a confirm dialog and
  POSTs the proxy route. Hidden when `attempts_today == 0` to avoid
  cluttering rows that don't need it.
  ([cms/components/users-dashboard.tsx](cms/components/users-dashboard.tsx),
  [cms/app/api/admin/users/[userId]/usage/reset/route.ts](cms/app/api/admin/users/[userId]/usage/reset/route.ts))

### Decisions worth remembering

- **Race window 1-2 over cap is acceptable** for free-tier UX. The atomic
  guarded UPSERT eliminates the counter leak but two concurrent requests
  hitting the gate at `count == cap-1` may both pass through. Trade vs
  full SERIALIZABLE transaction overhead — the previous "atomic always-bump"
  was strictly worse because it inflated the counter on every 429.
- **`IncrementAttempts` legacy method retained** for the interview gate
  path (which already check-then-increments correctly). Callers must use
  `TryIncrementAttempts` for any new gate logic.
- **`attempts_cap` returned even for Pro** (numeric, not omitted) so the
  CMS can render `∞` based on `pro_tier`, not based on field absence.

### Stable contract updates

- [docs/reference/api-contracts.md](docs/reference/api-contracts.md):
  GET `/v1/admin/users` response gains `attempts_today` + `attempts_cap`.
  New section `POST /v1/admin/users/:id/usage/reset`. New section
  documenting the V21.2 free-tier attempts gate semantics (counter
  pinned at cap, race trade-off explicit).

### Tests

- Backend: 654 passed in 8 packages (was 647 → +7: `TryIncrementAttempts`
  honors-cap + cap-zero-blocks, `ResetAttempts` keeps-interviews,
  `attempts_today` populated, `usage/reset` happy/404/auth, gate counter
  pinned at cap regression).
- Flutter: 309 passed (no new tests; bug fixes are UI-layer + caught by
  manual MobAI run).
- CMS: 144 passed in 7 files. `cms-lint` + `cms-build` clean — new route
  `/api/admin/users/[userId]/usage/reset` registered.

---

## V21.1 — V21 review hotfixes — 2026-05-07

Five-axis review on the V21 slice surfaced 2 Critical + 5 Important
findings. V21.1 lands the lot in two atomic batches.

### V21.1 Batch 1 — Critical + first 2 Important (commit `fix(v21):`)

- **C1 placement non-placement-session**: `placement-test/complete`
  now validates `session.MockTestID` belongs to a `is_placement=true`
  MockTest. Without this guard a learner could submit any of their
  regular `mock_exam_session` ids and have its score map to a level —
  silently skipping placement.
- **C2 score scale**: `OverallScore` is raw points (sum of
  `section_score + pronunciation bonus` per `mock_test_store.computeScoring`),
  not a percentage. Both the promotion hook and the placement complete
  handler now route through `processing.OverallScorePctFromSession`,
  which divides by `sum(MaxPoints)`. Tests updated to use realistic
  raw inputs.
- **I1 N+1 in course list**: `handleCourses` reads `userLevelStore.GetUserLevel`
  once per request, then resolves unlock per course via the new pure
  helper `processing.ResolveCourseUnlockWith(unlockedLevels, ...)`.
- **I3 published-only placement mock**: `LatestPlacementMockTest`
  filters by `status='published'` (memory + Postgres). Drafts no
  longer leak to learners.

### V21.1 Batch 2 — remaining Important + I6 doc (commit `fix(v21.1):`)

- **I4 FK on full_session_id**: migration 027 drops the `NOT NULL DEFAULT ''`
  on `promotion_attempts.full_session_id`, normalises sentinel empty
  rows to NULL, and adds a foreign key to `mock_exam_sessions(id)`
  with `ON DELETE SET NULL`. Ledger row survives session pruning
  (audit trail) but never points to a stale id again.
- **I5 PromotionTestForLevel resolver wired**: `SetLevelDeps` installs
  a default resolver that calls `MockTestStore.LatestPromotionMockTest(targetLevel)`
  so `GET /v1/users/me/level-progress` surfaces `promotion_test_id` —
  the home banner can now deep-link to PreExam without a follow-up
  `listMockTests` round trip.
- **I2 + I8 placement rate limit**: new `placementRateLimiter` (5
  RPM per user) installed by `SetLevelDeps`. Cap closes the TOCTOU
  race between two concurrent first-placement calls AND throttles
  malicious / buggy clients hammering `?force=true`. Returns
  `429 rate_limited` once the window is exhausted.
- **I6 V19/V21 mastery aggregation policy documented**: V21 takes
  *max* across modules per skill (gating threshold favours the
  learner's strongest module so they're not blocked by weak ones);
  V19 progress takes *mean* (honest signal of typical performance).
  Different metrics, different purposes — comment in
  `processing/level_service.go.computeSkillMastery` cross-references
  this CHANGELOG entry so the divergence stays intentional.

### V21.1 deferred to future slices

- I7 hook short-circuit before `GetByFullSessionID` — accepted as-is;
  the lookup is O(1) and the cost is acceptable for V21 traffic.
- S1–S8 — suggestion-tier polish; no behaviour change.

### V21.1 final test counts

- Backend: **647** (V21 baseline 636 → +11 from V21.1: C1+C2 added 7,
  V21.1 batch 2 added 4: migration shape, LatestPromotionMockTest,
  promotion_test_id resolver, placement rate limit).
- Flutter: 309 (no Flutter changes — all V21.1 work is server-side).
- CMS: 144 (no CMS changes).
- `make verify` + `make smoke-promotion-flow` both green.

---

## V21 — CEFR Level Progression (A0 → B1) — 2026-05-07

Pivot from "A2-only sprint" to a level-gated CEFR ladder. Each
learner has a `users.current_level`; content above their level is
locked behind a 2-gate promotion (mastery threshold unlocks a
promotion exam, passing the exam promotes the learner). MVP ships
A2 + B1 only — A0/A1 schema-ready, content deferred. Existing users
backfill to A2 with `{a0,a1,a2}` unlocked.

Per-slice docs: idea `docs/ideas/cefr-level-progression.md`,
spec `docs/specs/cefr-level-progression.md`, UX
`docs/specs/cefr-level-progression-ux.md`, plan
`tasks/cefr-level-progression-plan.md`.

### V21 schema (migrations 025 + 026)

- `courses` `+level enum(a0,a1,a2,b1) DEFAULT 'a2'`,
  `+demo_exercise_id`, `courses_level_idx`. Existing courses backfill
  to `a2`.
- `users` `+current_level`, `+unlocked_levels TEXT[] DEFAULT {a0}`,
  `+placement_taken_at`. Migration 026 backfills pre-V21 users to
  `current_level='a2'` + `{a0,a1,a2}` (idempotent — guarded by
  `current_level='a0' AND placement_taken_at IS NULL` so re-runs and
  greenfield deploys are no-ops).
- `mock_tests` `+is_promotion`, `+is_placement`, `+target_level` with
  three CHECK constraints (target enum, promotion-target-required,
  promotion/placement mutex).
- `promotion_attempts` (new): per-attempt ledger with FKs to
  `users(id)` + `mock_tests(id)`, descending composite index
  `(user_id, target_level, created_at DESC)`.

### V21 endpoints

- `GET /v1/users/me/level-progress` — server-authoritative gating
  state for the home screen. Returns per-skill mastery vs threshold,
  coverage pct, `promotion_unlocked` flag, optional cooldown
  timestamp. `Cache-Control: no-store`.
- `POST /v1/users/me/placement-test/start` — picks the latest
  `is_placement=true` MockTest, creates a session, returns
  `{mock_test_id, full_session_id}`. `409 placement_already_taken`
  unless `?force=true`.
- `POST /v1/users/me/placement-test/complete` — reads session
  `OverallScore`, maps via `LevelService.MapPlacementScoreToLevel`,
  persists `current_level + placement_taken_at`. `404` hides
  wrong-owner / missing-session identically.
- `POST /v1/promotion-attempts` — error precedence: `404
  mock_test_not_found` → `400 mock_test_not_promotion` → `409
  level_already_unlocked` → `400 promotion_locked` → `400
  cooldown_active` (with `retry_after`). On pass creates
  `mock_exam_session` + `promotion_attempts` row.
- `GET /v1/courses(/:id)` — adds `?level=` filter, per-item
  `level / unlock_state / demo_exercise_id`. `unlock_state` ∈
  `{unlocked, demo, locked}` — server is sole authority.
- `GET /v1/exercises/:id` — `403 level_locked` unless caller's level
  unlocks the parent course OR exercise == course's `demo_exercise_id`.

### V21 backend layout

Code lands across the existing package split (no new
`internal/level/` package — matches V19 mastery layout):

- `processing/level_service.go` — gating math (`ComputeLevelProgress`,
  `ResolveCourseUnlock`).
- `processing/level_promotion.go` — `HandlePromotionOutcome` post-
  scoring hook; idempotent on replay.
- `processing/level_config.go` — env loader (sole owner of `LEVEL_*`
  reads).
- `processing/mastery_updater.go` — extended with `WithDemoCheck` so
  demo attempts skip mastery aggregate writes.
- `store/user_level_store.go` — interface + memory + Postgres impls.
- `store/promotion_attempts_store.go` — interface + memory + Postgres
  impls + schema helper.
- `contracts/level.go`, `contracts/user_level.go`,
  `contracts/promotion_attempt.go` — DTOs.
- `httpapi/level_handler.go`, `placement_handler.go`,
  `promotion_handler.go` — wire the four endpoints + `LevelDeps`.
- `httpapi/level_flow_test.go` — E2E smoke (V21-E1).
- Hook fired from `httpapi/server.go.handleMockExamComplete` after
  `repo.CompleteMockExam` returns the finalised session.

### V21 CMS

- Course form: `<select>` over CEFR levels (`cms/lib/level.ts` shared
  helpers) + optional `demo_exercise_id` text input (hidden at
  lowest level). `coursePayload` carries both fields.
- MockTest form: mutex `is_promotion`/`is_placement` checkboxes via
  `cms/lib/mockTestFlags.ts` helpers (`togglePromotion`,
  `togglePlacement`, `setTargetLevel`, `validateMockTestFlags`,
  `mockTestFlagsPayload`); target_level select reveals only when
  promotion is on; `validateMockTestFlags` blocks submit when
  promotion lacks target.

### V21 Flutter

- `core/level_utils.dart` — `CefrLevel` enum + parsers + ladder
  helpers + `CourseUnlockState`.
- `core/api/level_api.dart` — typed client; `LevelApiException`
  collapses both backend envelope shapes (`{error: {code, ...}}` and
  flat `{error: "code"}`).
- `models/models.dart` extended — `LevelProgressResponse`,
  `SkillMasteryInfo`, `Course.level/unlockState/demoExerciseId`.
- `features/home/widgets/level_badge.dart`,
  `level_progress_ring.dart`, `promotion_banner.dart`,
  `home_level_header.dart` — home composer.
- `features/courses/widgets/locked_course_tile.dart`,
  `locked_course_sheet.dart` — locked-state UI.
- `features/onboarding/welcome_screen.dart`,
  `placement_result_screen.dart` — first-launch flow.
- `features/promotion/pre_exam_screen.dart`,
  `promotion_result_screen.dart` — pre-exam confirm + pass/fail
  result with diagnostic table + live cooldown timer.
- ARB additions (matched VI = EN counts): six `v21*` keys for badge
  / banner / locked / promotion copy.

### V21 boundaries

- Server is sole authority for `unlock_state` and `promotion_unlocked`.
  Client never recomputes gates.
- Promotion fail does **not** decrement mastery — only writes the
  ledger row + 24h cooldown.
- Demo attempts (`exercise == course.demo_exercise_id`) skip mastery
  aggregate via `WithDemoCheck` callback so taste-test runs leave no
  trace.
- Reuse `MockTest` via flags. No new `PromotionTest` entity.

### V21 deferred (per scope discipline)

- A0 / A1 module + exercise authoring (content question, not
  engineering).
- `home_screen.dart` integration of `HomeLevelHeader`.
- Onboarding router gate (first-launch routing through Welcome →
  placement → result → home).
- Per-screen ARB-routed copy across the V21 widgets (queued for
  deploy-time wiring pass).

### V21 final test counts

- Backend: **636** (baseline 570, +66 net — A1+A2: +7, B1: +6, B2:
  +4, B3: +10, B4: +4, B5: +7, B6: +7, B7: +5, B8: +5, E1: +2 —
  exceeds plan budget +45).
- CMS Vitest: **144** (baseline ~123, +21 — C1: +6, C2: +15;
  exceeds plan budget +6).
- Flutter: **309** (baseline 266, +43 — D1: +11, D2: +6, D3: +4,
  D4: +4, D5: +3, D6: +3, D7: +4, D8: +5, D9: +3; exceeds plan
  budget +32).
- `make verify` exits 0; `make smoke-promotion-flow` exits 0.

---

## V20.1 — Hotfixes from learner-flow simulation — 2026-05-06

End-to-end MobAI simulation through the demo course surfaced 7 bugs in
the V20 learner flow. All fixed in this slice. No new product scope.

- **B5+B6 (P0): `cteni_4` answers never persist.** `_buildAnswerWidgets`
  in `features/exercise/screens/reading_exercise_screen.dart` was
  pulling options from the global `cteniOptions` (empty for cteni_4
  where each question carries its own option set) and keying answers by
  1-based loop index. Backend `extractCorrectAnswers` keys
  `correct_answers` by `question_no` (15..20 for cteni_4), so every
  submission scored 0/N. Fix: extend `FillQuestionView`
  (`models/models.dart`) with `options: List<PoslechOptionView>`; rewrite
  `_buildAnswerWidgets` + `_hasAllAnswers` to use per-question options
  and `q.questionNo` as the answer-map key. Per-question prompts now
  render via the caller; `MultipleChoiceWidget` skips its own number
  prefix when `questionNo == 0`.
- **Cast crash (P0): `String?['message']` on flat error.** Backend
  returns two error envelopes — `{"error":{"code","message"}}` (most
  endpoints) and `{"error":"<code>","message":"..."}` (auth gates like
  `email_verify_required`, `attempts_quota_exceeded`). `api_client.dart`
  assumed Map and crashed `type 'String' is not a subtype of type 'int'
  of 'index'` when `payload['error']` was a String. Now checks shape and
  falls back to top-level `message` field.
- **B7 (P1): `HomeProgressCard` stale after attempts.** Cache only
  refreshed on app launch / pull on detail screen. Fix: promote
  `_HomeProgressCardState` → `HomeProgressCardState` and expose
  `refresh()`; `CourseListScreen` holds a
  `GlobalKey<HomeProgressCardState>` and awaits the course-detail push
  before calling `refresh()` so mastery accrued inside an attempt is
  visible on return.
- **B8 (P1): Vocab flashcard never logged an attempt** → `tu_vung`
  mastery stayed at zero. `deck_session_screen.dart` now fires a
  background `createAttempt` + `submitAnswers({'1': choice})` per
  flashcard mark for `quizcard_basic` only. The backend's existing
  `QuizcardBasicDetail.correct_answers = {"1": "known"}` makes "known"
  score 1/1 and "again" 0/1 through the standard objective scorer →
  V19 EMA pipeline. Errors are swallowed (logged) so the local Anki UX
  does not stall.
- **B4 (P3): Course-detail stat row lied.** "KỸ NĂNG" was
  `modules.length * 4` and "PHÚT" was `modules.length * 45` — both
  arbitrary multipliers. `CourseDetailScreen` now fans out
  `listModuleSkills` per module in parallel and shows real totals
  (KỸ NĂNG = sum of returned skill summaries; PHÚT replaced with
  BÀI TẬP = sum of `exercise_count`).
- **B3 (P2): "Bắt đầu tất cả" did not actually queue.** Reading +
  listening result screens only had "Làm lại" — pressing the sprint CTA
  opened the first exercise then dropped the learner back to the list.
  `ObjectiveResultCard` gains an optional `onNext` (renders primary
  "Bài tiếp theo →" + outlined retry); `ReadingExerciseScreen` and
  `ListeningExerciseScreen` accept `onOpenNext`; `_openExercise` in
  `exercise_list_screen.dart` computes the next item and routes via
  `pushReplacement` so the navigation stack stays flat (matches the
  pre-existing vocab/uloha pattern).
- **B1 (P2): Wrong subtitle for non-speaking skills.**
  `exerciseListSubtitle` ARB key was hard-coded to a speaking-specific
  string ("Tập trung vào sự trôi chảy và phát âm…") and shown on every
  skill detail. Replaced with the skill-neutral
  "Chọn bài tập để bắt đầu luyện ngay." in both VI and EN ARBs.

Tests: Flutter 265 → 266 (+1: `HomeProgressCard.refresh()` re-fetches
with `forceRefresh=true`, plus +2 inside `section_result_card_test.dart`
covering ObjectiveResultCard sprint queue render/hide). Backend test
suite unchanged (no contract changes).

Files touched:
- `flutter_app/lib/core/api/api_client.dart` — error envelope handling.
- `flutter_app/lib/models/models.dart` — `FillQuestionView.options`.
- `flutter_app/lib/features/exercise/screens/reading_exercise_screen.dart`
  — per-question options + question_no keys + onOpenNext.
- `flutter_app/lib/features/exercise/screens/listening_exercise_screen.dart`
  — onOpenNext.
- `flutter_app/lib/features/exercise/screens/deck_session_screen.dart`
  — flashcard attempt logging.
- `flutter_app/lib/features/exercise/widgets/multiple_choice_widget.dart`
  — skip "0." when caller renders prompt.
- `flutter_app/lib/features/exercise/widgets/objective_result_card.dart`
  — onNext CTA.
- `flutter_app/lib/features/mock_exam/widgets/section_result_card.dart`
  — thread onNext.
- `flutter_app/lib/features/home/screens/exercise_list_screen.dart`
  — sprint queue routing for cteni/poslech.
- `flutter_app/lib/features/home/screens/course_list_screen.dart`
  — GlobalKey + refresh on push return.
- `flutter_app/lib/features/home/screens/course_detail_screen.dart`
  — real skill / exercise totals.
- `flutter_app/lib/features/progress/widgets/home_progress_card.dart`
  — public state + `refresh()`.
- `flutter_app/lib/l10n/app_{vi,en}.arb` — `exerciseListSubtitle`
  rewrite.
- `flutter_app/test/widgets/home_progress_card_test.dart`,
  `flutter_app/test/section_result_card_test.dart` — coverage for the
  new APIs.

Out of scope (open):
- B9 — `cteni_5` exercise listed twice in seed; `cteni_6` exercise has
  empty `module_id` in the API response. Both are seed-data issues, not
  app code; CMS reseed needed.

---

## V20 — Flutter Skill Mastery UI — 2026-05-06

- Renders the V19 progress aggregate as a home-screen card + drill-down
  detail screen, plus a profile entry tile. Strings flow through ARB
  (24 new keys, VI=EN parity at 376=376) so the UI stays free of
  hardcoded VI copy outside the call sites.
- Wire layer: `core/api/progress_models.dart` (typed `UserProgress`,
  `SkillProgress`, `ModuleProgress`, `ProgressBands` with permissive
  `fromApiJson` that accepts `Map<dynamic,dynamic>` const fixtures);
  `core/api/progress_api.dart` (typed wrapper + 24 h cache via
  in-memory `_Cached` + `SharedPreferences`; on network error returns
  the prior cache with `isStale=true`); `ApiClient.getProgress()` raw
  fetch.
- Widgets under `features/progress/widgets/`:
  - `MasteryBar` — 8 dp track + animated fill via `TweenAnimationBuilder`,
    band → colour from `AppColors.score{Poor|Fair|Good|Excellent}`,
    collapses tween to zero duration when
    `MediaQuery.disableAnimations` so reduced-motion paints final value
    immediately. Optional `Semantics(label, value)`.
  - `SkillMasteryRow` — 56 dp min-height row, label + bar +
    tabular-figure percent. `MergeSemantics` + `Semantics(button: true,
    onTap)` + `InkWell(excludeFromSemantics: true)` so screen readers
    announce one node, not three.
  - `ProgressEmptyState` / `ProgressErrorState` — icon + title +
    optional message + optional FilledButton/OutlinedButton CTA.
- Screens under `features/progress/screens/`:
  - `HomeProgressCard` (mounted above the course grid in
    `course_list_screen.dart`) — loading → populated / empty / error
    states; offline chip when stale; optional onSkillTap pushes the
    drilldown filtered to that `skill_kind`.
  - `ProgressDetailScreen` (`skillKind` nullable) — `RefreshIndicator`
    pull-to-refresh re-runs the fetcher with `forceRefresh: true`;
    AppBar offline chip mirrors `HomeProgressCard`.
- Profile: new "Tiến độ học tập" tile on `ProfileScreen` pushes
  `ProgressDetailScreen(skillKind: null)` (all-skills view) by lazy-
  building `ProgressApi` from `SharedPreferences` on tap.
- Shared util: `features/progress/skill_labels.dart#skillKindLabel(l, kind)`
  resolves the 7 skill_kind tokens to their localised display name —
  consumed by both the home card and detail screen.
- ARB: 24 new keys per spec — `homeProgressCardTitle`,
  `progressOverallTitle`, `progressOverallPercent({percent})`,
  `progressSkill{Noi,Viet,Nghe,Doc,TuVung,NguPhap,Interview}`,
  `progressBand{NeedsWork,Learning,Solid,Ready}`,
  `progressEmpty{Title,Cta}`, `progressError{Title,Retry}`,
  `progressOfflineChip`, `progressDetailTitle`,
  `progressDetailAttemptsLabel({count})`,
  `progressDetailLastAttemptLabel`,
  `progressLastAttemptRelativeFormat({when})`, `profileProgressEntry`.
- Spec: `docs/specs/skill-mastery-progress.md` (covers V19 + V20)
  · plan: `tasks/skill-mastery-progress-plan.md`
  · todo: `tasks/skill-mastery-progress-todo.md`.
- Tests: Flutter +43 widget/unit (222 → 265): `test/api/progress_api_test.dart`
  (10 — parse, round-trip, empty, network hit, memory cache, force
  refresh, prefs cold start, 24 h expiry, stale fallback, offline
  rethrow); `test/widgets/mastery_bar_test.dart` (12 — 4 band colours
  + unknown fallback + clamp + semantics + reduced-motion + row
  layout + tap + merged semantics + tabular figures);
  `test/widgets/progress_states_test.dart` (6 — render + tap +
  null-callback hide); `test/widgets/home_progress_card_test.dart`
  (5 — loading→populated, empty + CTA, error + retry refetch, offline
  chip, tap-row); `test/screens/progress_detail_screen_test.dart`
  (6 — all-skills, single-skill filter, empty, error + retry,
  pull-to-refresh forceRefresh, offline chip). `flutter analyze`
  clean.
- Manual UI verify (Checkpoint 3) outstanding: iPhone SE 375 +
  iPhone 14 Pro × light/dark × reduced-motion + largest Dynamic Type.

---

## V19 — Skill Mastery Aggregate + Progress Endpoint — 2026-05-06

- Turns the per-attempt `AttemptFeedback.readiness_level` stream into a
  durable per-skill / per-module mastery signal keyed by
  `(user_id, skill_kind, module_id)`. Updated synchronously after each
  feedback persists; failures log at error level, never roll back the
  attempt.
- Schema (Postgres, idempotent via `CREATE TABLE IF NOT EXISTS`):
  `user_skill_mastery (id, user_id, skill_kind, module_id,
  mastery_score, attempts_count, last_attempt_id, last_attempt_at,
  created_at, updated_at)` with `UNIQUE (user_id, skill_kind,
  module_id)` and `INDEX (user_id, updated_at DESC)`. `module_id=""`
  reserved for exam-pool attempts so the unique index still holds.
- Vocabulary unify (Phase 0, separate commit `f20fbee` shipped
  alongside): the 4-band scale `not_ready / needs_work /
  almost_ready / ready_for_mock` is now used by both the LLM scorer
  (`exam_ready` collapsed into `ready_for_mock`, explicit
  `needs_work` token added to the prompt) and the objective scorer
  (`frac` thresholds 0.85 / 0.60 / 0.30). `normalizeReadinessLevel`
  preserves backwards compat for legacy persisted feedback
  (`weak → needs_work`, `ok → almost_ready`, `strong → ready_for_mock`,
  `exam_ready → ready_for_mock`). New `ReadinessToScore` returns the
  numeric mastery contribution: 0.20 / 0.45 / 0.70 / 0.90.
- EMA update rule (`processing/mastery_updater.go`):
  - First attempt sets `mastery = score` directly.
  - `attempts_count ≤ EarlyAttemptCap (3)` → `0.5*old + 0.5*score`.
  - Otherwise → `0.7*old + 0.3*score`.
  - Idempotent on `last_attempt_id`: if the same attempt is replayed
    (e.g. retried persist), the upsert is skipped.
- Config (`processing/processing_config.go`, sibling to `llm_config.go`
  per AGENTS.md SoT rule): `MasteryConfig{BandLearning, BandSolid,
  BandReady, EarlyAttemptCap, EarlyAlpha, SteadyAlpha, weights}`.
  Env-overridable via `MASTERY_BAND_{LEARNING,SOLID,READY}` and
  `MASTERY_OVERALL_{NOI,VIET,NGHE,DOC,NGU_PHAP,TU_VUNG,INTERVIEW}`.
  `LoadMasteryConfig` clamps band floors to [0, 1], weights to [0,
  100], swaps non-monotonic floors, and warns on env parse errors so
  operator typos (e.g. comma-decimal) are visible in logs.
- Endpoint: `GET /v1/users/me/progress` (auth required via
  `withAuth`, 401 without bearer, 200 always for authenticated users
  even with zero rows). Returns
  `{overall_progress, overall_band, skills[], bands{needs_work,
  solid, ready}, weights{...}}`. Per-skill mastery is the unweighted
  mean across the skill's modules; `overall_progress` is the
  weighted mean across non-zero-weight skills with fallback to
  equal-weight when every weight is zero.
- Wiring: `Processor.completeAttempt` (processor.go) is the single
  funnel — all 5 `CompleteAttempt` call sites (speaking, writing,
  interview, objective, dictation) route through it so adding a new
  attempt path can't accidentally skip the mastery hook.
  `httpapi.MasteryDeps{Store, Config}` + `NewServerWithMastery`
  decouples mastery wiring from the V17 self-serve auth bundle so the
  dev fixture build path also records progress.
- Dev fixtures: `EnsureDevFixtureUsers(databaseURL)` runs at server
  boot when `ENV != "production"`, idempotently INSERTs the 3
  fixture user IDs (`user-learner-1`, `user-learner-2`,
  `user-admin-1`) into Postgres `users` with `email_verified_at =
  now()` and a high `grace_attempts_left` so the V17 verify gate
  doesn't fire after 3 attempts. Without this, mastery (and every
  other V17 store FK on `users(id)`) silently rolled back every
  insert from the dev fixture path.
- Smoke: `scripts/smoke_progress_flow.py` + `make smoke-progress-flow`
  cover auth gate (401), wire shape, monotonic bands, band
  classification mirroring backend, weights non-negative,
  per-skill + per-module ranges, idempotent re-read, optional
  `--require-rows` assertion. Folded into `make smoke-all`.
  `smoke_test_attempt_flow.py` + `smoke_course_flow.py` migrated to
  the V8 `/v1/modules/{id}/exercises?skill_kind=...` path so they
  no longer reference the dropped `skills` table.
- Spec: `docs/specs/skill-mastery-progress.md`
  · idea: `docs/ideas/skill-mastery-progress.md`.
- Tests: backend +27 (532 → 570 inc. processing config clamp/swap +
  smoke add): `processing_config_test.go` (8 — defaults, env override,
  band classification, unknown skill, clamp band, clamp weight,
  monotonic swap, parse fallback); `mastery_updater_test.go` (7 —
  first attempt, EMA convergence, decay, idempotency,
  exam-pool empty `module_id`, missing user-skill-feedback no-op,
  `last_attempt_at` from `CompletedAt`); `skill_mastery_store_test.go`
  (7 — insert, composite-key update, get, list ordering, empty user,
  exam-pool empty `module_id`, missing user-skill rejection);
  `progress_handler_test.go` (4 — 401, empty user, populated weighted
  overall, env-overridden weights). All tests green; smoke E2E PASS.
- Validation gates (post-ship, blocks V21): 30-attempt teacher
  agreement ≥ 70 %, 5-learner pilot interview, 20-sequence notebook
  curve check, p95 attempt-persist latency within current SLO.
  Recorded in `tasks/skill-mastery-progress-todo.md § Phase 4`.

---

## V18.1 — Dictation OCR Submission — 2026-05-05

- Extends `psani_3_dictation` with handwriting-photo input via
  Claude Vision OCR (zero new vendor — reuses `ANTHROPIC_API_KEY`).
- `DictationDetail.submission_mode: "type" | "ocr" | "both"`, default
  `"type"` for V18 backward-compat. `Mode()` getter normalises.
- Backend: `processing/dictation_ocr.go` (`OCRProvider` interface +
  `ClaudeVisionOCR` + `NoopOCR` fallback); `LLM_OCR_MODEL` env (default
  `claude-opus-4-7`). Prompts in SoT files. Fail-soft: OCR error returns
  `("", nil)` so the endpoint never 5xx because of OCR.
- Endpoints (multipart):
  - `POST /v1/attempts/:id/dictation-ocr-preview` — single image,
    5 MB cap, MIME jpeg/png/webp, idx 0..7, per-user RL 30/min.
    Returns `{idx, text, asset_id}`. OCR fail → 200 with empty text.
  - `POST /v1/attempts/:id/submit-dictation-ocr` — `sentences` JSON form
    field, 64 KB cap. Reuses `ProcessDictationAttempt` so scoring is
    identical to V18 type-mode (AC: score parity).
- Storage: file-based under `dictation-ocr/<attempt_id>/img-<nanos>.<ext>`
  via `LOCAL_ASSETS_DIR`. No new DB table — storage key serves as
  `asset_id`.
- Compose: `LLM_OCR_PROVIDER` + `LLM_OCR_MODEL` threaded through
  `docker-compose.yml` + `docker-compose.ec2.yml`. Without the host
  shell setting these, backend defaults to `NoopOCR` (silent empty
  preview).
- Server hooks: `Server.ocrProvider` field + `dictationOCRRL`
  rate limiter; new `NewServerForTest` + `Handler()` + `SetOCRProvider`
  for fake-OCR injection in widget tests.
- CMS: `DictationFields.tsx` adds "Chế độ nộp bài" select + per-mode
  hint paragraph. `DictationFormState.submissionMode` parsed safely
  (`"type"` default for unknown/missing). `validateDictation` rejects
  invalid enum values.
- Flutter: `ExerciseDetail.dictationSubmissionMode` + `isOCRMode` /
  `isTypeMode` / `isBothMode` getters. `DictationOCRPreviewCard` widget
  (thumbnail + editable TextField + Retake/Confirm + isUploading
  spinner + optional failedBanner). `DictationExerciseScreen` branches
  on submission mode: "type" keeps V18 flow, "ocr" replaces TextField
  with camera CTA, "both" adds per-sentence ChoiceChip toggle. Lazy-
  creates the attempt at first OCR preview (preview endpoint needs
  attemptId). Submit dispatches OCR endpoint when any sentence used the
  photo path.
- Camera: `image_picker: ^1.1.2` (already in pubspec from V17.2),
  `pickImage(source: camera, maxWidth: 1024, imageQuality: 85)`.
  Injectable via `DictationImagePicker` typedef so widget tests stub
  the platform channel.
- API client: `dictationOCRPreview()` + `submitDictationOCR()` use the
  same dart:io HttpClient multipart helper as V17.2 avatar upload.
  Reuses existing `AuthException`.
- i18n: 8 new ARB keys VI + EN (mode labels, preview titles/hints,
  buttons, banners). 4 admin-side hint strings inline in
  `DictationFields.tsx` (matches existing exercise-form-fields
  convention; `cms/lib/i18n.tsx` scope is sidebar/dashboards only).
- Spec: `docs/specs/dictation-ocr.md` · idea: `docs/ideas/dictation-ocr.md`
  · plan: `tasks/plan.md § V18.1` · summary: `SPEC.md § V18.1`.
- Tests: backend +22 (510 → 532), Flutter +11 (211 → 222), CMS +5
  (116 → 121); analyze + lint + build clean across all three.
- E2E + pilot remain manual: TestFlight smoke MAN-1..MAN-8 + 20×6 photo
  gold set across 5 learners measuring CER ≤10% before promoting OCR
  to default mode in V18.2.

---

## V18 — Dictation Exercise (`psani_3_dictation`) — 2026-05-05

- New exercise type under `viet`: 3–8 Czech sentences, per-sentence
  Polly TTS, learner stepper UI (auto-play once + manual repeats with
  client-side cap), keyboard-typing input + Czech diacritic chip row.
- Backend: `processing/dictation_scorer.go` weighted Levenshtein
  (diacritic substitution weight 0.5, NFC-normalized) →
  `DictationFeedback`; `processing/dictation_processor.go` orchestrator;
  `processing/dictation_llm.go` async Claude annotator (fail-soft to
  deterministic-only diff). `POST /v1/attempts/:id/submit-text`
  branches on exercise_type to dispatch the dictation goroutine.
- Storage: `exercise_audios.sentence_idx` nullable column added via
  `addColumnIfMissing`; `ExerciseSentenceAudioStore` interface; admin
  per-sentence audio endpoint `POST/DELETE /v1/admin/exercises/:id/dictation/sentences/:idx/audio`.
- CMS: `DictationFields.tsx` (transcript paste → auto-split with Czech
  abbreviation handling: Mgr./Dr./Bc./Ph.D./pan./ing.; per-row Polly
  button + preview; replay-cap + max_points + threshold + voice inputs;
  inline validation banner). `validateExercise` blocks publish when a
  sentence lacks audio.
- Flutter: `DictationExerciseScreen` stepper + `DictationAudioCard` +
  `CzechKeyboardChips` + `DictationResultCard` 3-tab (Score / Sửa bài
  diff / Phản hồi). `submitDictation` API client.
- Spec: `docs/specs/dictation-exercise.md` · summary: `SPEC.md § V18`.
- Tests: backend 510, Flutter 211, CMS 116; smoke pass; verify green.
- Hot fixes: Postgres `ExerciseSentenceAudioStore` wired in main.go;
  audio_asset_id hydrated from sentence_audio store at exercise read;
  edit dialog rehydrates the transcript textarea.

---

## V17.2 — Learner Profile Identity (Avatar + Nickname) — 2026-05-05

- `POST /v1/users/me/avatar` (multipart, 5 MB cap, jpg/png/webp) +
  `DELETE /v1/users/me/avatar`. `patchMeRequest.avatar_asset_id`
  optional pointer; `display_name` 60-rune cap via
  `utf8.RuneCountInString` (Vietnamese-safe).
- Backend reuses V11 `uploadItemImage` helper with
  `storagePrefix=avatars`. Storage key
  `avatars/<user_id>/img-<nanos>.<ext>`; old file removed on rewrite or
  delete.
- Flutter: `image_picker: ^1.1.2`, `ApiClient.uploadAvatarV17(File)`
  via `dart:io HttpClient` multipart, `mediaUri(asset_id)` reused for
  serve. ProfileScreen redesign: V17AccountSection promotes to top as
  centered hero (avatar 96pt + name 22pt + edit pencil + email + chip
  pills + email-verify warning).
- `_AvatarTile` `Stack(fit: StackFit.expand)` + `Image.network(width,
  height, fit: BoxFit.cover)` to fix avatar circle clipping. Action
  sheet: capture / pick from library / delete / cancel; client-side
  resize via `pickImage(maxWidth: 1024, maxHeight: 1024, imageQuality:
  85)`.
- Bug fix `AuthService._adoptUser`: always `notifyListeners()` when
  `_user` mutates so `AnimatedBuilder` rebuilds.
- iOS Info.plist: `NSPhotoLibraryUsageDescription` (camera permission
  was already added in V14).
- Initials fallback derived from `display_name` (first 2 chars) or
  email local-part when avatar is absent.
- Specs: `docs/reference/learner-profile-identity.md` · idea:
  `docs/ideas/learner-profile-identity.md`.
- Tests: 452 backend (+5), 201 Flutter, 95 CMS Vitest.

---

## V17.1 — Admin User Management — 2026-05-05

- `GET /v1/admin/users` (paginate + search + role filter), `DELETE
  /v1/admin/users/:id` (soft-delete + revoke tokens; frees email for
  re-register), `POST /v1/admin/users/:id/reset-password` (admin sets
  password directly; validates strength via `auth.ValidatePassword`;
  revokes sessions; resets login RL).
- `UserStore.ListUsers(opts)` added to interface + memory + postgres
  impls (LIKE search on email + display_name + COUNT total).
- Sub-route dispatch in `handleAdminUserByID` on path suffix after
  `:id` (`/reset-password`).
- Security guards: refuse self-delete (`caller.ID == target.ID`),
  refuse admin-role target (delete + reset-password both 403), 4 KiB
  body cap.
- CMS `/users` page: search input + paginate footer + Reset/Delete row
  actions. Admin row shows `—`. Reset modal: 2 password inputs +
  confirm + inline strength hint; success state nudges admin to share
  via secure channel (chat/sms, not email).
- Soft-delete keeps `attempts.user_id` for audit; partial unique index
  `WHERE deleted_at IS NULL` allows re-register.
- Specs: `docs/specs/admin-user-management.md`.
- Tests: 447 backend (+12), 95 CMS Vitest.

---

## V17 — Self-serve Learner Auth — earlier 2026-05

- Signup/login/IAP/quota gates (see `docs/specs/self-serve-learner-spec.md`).

---

## V16 — Interview First-Turn Fix + Push-to-Talk + UX Polish — 2026-05-04

- Audio gate routes Simli chunks on `onVideoReady` (first frame), not
  WS START. Buffer pending chunks, flush on ready, fallback timer
  `audio_buffer_timeout_ms` (default 1500ms; 500..5000 clamp) →
  `PcmAudioPlayer` local.
- Simli opt-in via Profile (`InterviewPreferenceService.avatarEnabled`,
  default false). Disabled mode uses sound wave + local PCM player and
  removes the 11–15s SPEAK delay we saw in production logs.
- Local examiner volume slider 100–180% (`localAudioVolume`, default
  135%). PCM16 gain with safe clipping.
- Server-derived `display_prompt` from `system_prompt` (strip "You
  are…", extract `ÚKOL`/`TASK` block, drop `{selected_option}`
  placeholder). Helper `processing.DerivePromptForLearner` +
  `processing.EnrichInterviewDetail`.
- Admin preview endpoint: `POST /v1/admin/interview/preview-prompt`
  (RL 30/min/admin); CMS `PromptPreview` debounced 400ms.
- `InterviewPromptCard` bottom panel widget; pulse 1.5s on
  `agent_response_complete` (skip first); "Hoàn thành" / "Finish"
  sticky CTA → `popUntil(home)`.
- Push-to-talk mic (`_PttMicButton`): tap toggle replaces always-on
  VAD. State authoritative from Simli SPEAK/SILENT WS messages. 12s
  agent-wait timer after user turn. 550ms preroll buffer + 1600 byte
  minimum before flushing to ElevenLabs. Sound-wave mode applies fixed
  outbound PCM gain `2.4×` with safe clipping for VAD sensitivity.
  `canStartInterviewMic` + `shouldReleaseInterviewMicPreroll` pure
  helpers for tests.
- Empty-turn filter (`_isMeaningfulTranscript`): `\p{L}|\p{N}` regex
  drops "..." / whitespace turns from VAD false positives.
- Defensive state in `_startConversation`: flip `_state`
  speaking→ready so mic enables even when the safety timer fires
  outside `agent_response_complete`. 3s no-audio fallback enables mic
  for learner-speaks-first scenarios.
- iOS audio session switching: Simli duplex uses `playAndRecord +
  videoChat`; sound-wave PTT uses `playAndRecord + measurement` to
  avoid AEC/noise gate suppressing ElevenLabs detection. Sound-wave
  examiner playback returns to `AudioSessionConfiguration.speech()`
  before each turn to dodge iOS ducking attenuation.
- Local playback turn gate: sound-wave mode waits for
  `PcmAudioPlayer.flushAndPlay()` before re-enabling mic; chunks
  auto-flush to reduce latency, mic only re-opens on
  `agent_response_complete` or silence timeout. `flushAndPlay` defers
  while mic active to avoid iOS `AVAudioSession` `!pri`.
- Responsive layout: bottom panel scroll lane for transcript + prompt
  card, separate fixed control lane for timer/mic/end. Compact-height
  uses prompt max-height; widget tests at 360×640 catch overflow.
- Audio diagnostics: per-turn counter logs
  `Interview turn=N audio chunks: simli=X local=Y buffered=Z
  useSimliAudio=A videoReady=B`; mic `rawPeak`/`sentPeak`/`micGain`;
  ElevenLabs `vad_score` max log; `flushAndPlay` logs sample rate +
  gain + bytes + duration.
- ElevenLabs agent settings required (in Security): "Allow client
  override system_prompt", "first_message", "TTS voice". Without
  first_message override, the 3s fallback enables mic.
- Specs: `docs/specs/interview-first-turn-fix.md` · plan:
  `docs/plans/interview-first-turn-fix-plan.md`.
- Tests: 298 backend, 159 Flutter, 95 CMS Vitest.

---

## V15 — AI Image Generation in CMS — 2026-05-03

- "✨ Tạo bằng AI" button next to upload at exercise context_image,
  cteni_1 per-item, Course banner, MockTest banner (4 sites).
- Backend: `POST /v1/admin/ai/generate-image` (Replicate Flux.1-schnell,
  poll + download + local save) + `POST /v1/admin/ai/set-banner`. RL
  5/min/admin. `REPLICATE_API_KEY` env.
- CMS `AiImageButton.tsx`: 6-state machine
  (idle→open→generating→preview→uploading→done/error). Confirm flow:
  generate → preview Replicate CDN → "Dùng ảnh này" → POST `/assets`
  register → reload.
- Image format JPEG 512×512; output_format `"jpg"` (not `"jpeg"`).
  Compose adds `REPLICATE_API_KEY`. DNS fix (8.8.8.8) for Docker.
- Specs: `docs/ideas/ai-image-generation.md`.
- Tests: backend +10 (rate limiter + mock Replicate), CMS +17 Vitest.

---

## V14 — Interview Skill — 2026-05-02

- `skill_kind = "interview"` with 2 exercise types:
  `interview_conversation` + `interview_choice_explain`.
- Backend: `POST /v1/interview-sessions/token` (ephemeral ElevenLabs
  signed URL, injects `{selected_option}`); `POST
  /v1/attempts/:id/submit-interview`; `interview_scorer.go` post-
  session LLM scoring.
- CMS: `InterviewConversationFields.tsx` +
  `InterviewChoiceExplainFields.tsx` with `system_prompt`, `max_turns`,
  `show_transcript` toggle. `interview_choice_explain.options[].tips`
  for per-option learner hints.
- Flutter: `ElevenLabsWsClient` (custom Dart WS, PCM16 streaming) +
  `SimliSessionManager` (wraps `simli_client`); InterviewList →
  InterviewIntro → InterviewSession → InterviewResult screens.
- Audio pipeline: PCM16 buffer → WAV → `just_audio` (Sprint 1); pipe
  to `simliClient.sendAudioData()` for avatar lip-sync (Sprint 2).
- Security: API key server-side only; Flutter receives ephemeral
  signed URL.
- iOS deployment target 13.0 (flutter_webrtc requirement); camera +
  mic permissions added.
- `SIMLI_API_KEY` + `SIMLI_FACE_ID` via `--dart-define`; avatar
  disabled when key empty.
- `ELEVENLABS_VOICE_ID_C` env: when set, backend returns `voice_id` in
  `InterviewTokenResponse`; Flutter injects into
  `conversation_config_override.tts.voice_id`. **Requires** "Allow
  client to override TTS voice" in ElevenLabs agent Security settings —
  WS reject otherwise.
- Specs: `docs/ideas/interview-skill.md` · `docs/design/mockups/interview-skill.html`.
- Tests: 263 backend, 61 CMS Vitest, 102 Flutter.

---

## V13 — Ano/Ne Exercise Type — 2026-05-02

- Two new exercise types: `cteni_6` (read passage → Ano/Ne) +
  `poslech_6` (TTS passage → Ano/Ne). 1–5 statements each.
- Backend: `AnoNeDetail`/`AnoNeStatement` contracts;
  `extractQuestionTexts` branch on `statements[].statement`;
  `BuildExerciseAudioText` case `poslech_6`; `isAnoNeKey()` exact-match
  guard prevents substring collision ("NEANO" ≠ "ANO").
- CMS: `AnoNeFields.tsx` (passage textarea + statement repeater +
  ANO/NE toggle + max_points + Polly button); wired before
  `startsWith` checks in `exercise-form/index.tsx`. 4 Vitest tests.
- Flutter: `AnoNeWidget` + `_AnoNeRow` (44pt tap target, animated
  states); `_buildCteni6Layout` + poslech_6 branch; `_hasAllAnswers`
  empty-guard; `AnoNeStatementView` model. 5 i18n keys VI+EN. 5 widget
  tests.
- Scoring reuses `objective_scorer.go` — no LLM, no migrations, no new
  endpoints.
- Specs: `docs/specs/ano-ne-exercise-type.md`.
- Tests: 243 backend, 53 CMS Vitest, 69 Flutter.

---

## V12 — Deck Session Mode — 2026-05-01

- `TypeGroupScreen`: tu_vung/ngu_phap groups exercises by exerciseType
  in 2-col grid with count badge.
- `DeckSessionScreen`: queue (`ListQueue`), progress bar, 4 card types
  (quizcard_basic, choice_word, fill_blank, matching).
- Local scoring on choice_word / fill_blank (substring check) — no
  backend round-trip.
- `_CompletionView` shows Đã biết / Ôn lại counts.
- 11 widget tests in `deck_session_test.dart`.

---

## V11 — Media Enrichment — 2026-05-01

- `image_asset_id` added to `VocabularyItem`, `GrammarRule`,
  `MultipleChoiceOption`, `MatchOption` (contracts + migrations
  020/021).
- `QuizcardBasicDetail.ImageAssetID` injected at publish time from the
  vocab item; `ApiClient.mediaUri(key)` → `GET /v1/media/file?key=`.
- `QuizcardWidget` 16:9 image slot (priority: context_image asset >
  flashcardImageAssetId).
- `MultipleChoiceWidget` switches to 2×2 image grid when all options
  carry `imageAssetId`. `MatchingWidget` right column shows image card.
- `ExerciseContextImage` widget on all 4 exercise screens
  (listening/reading/writing/vocab-grammar) + `DeckSessionScreen`.
- Exercise form: "🖼 Ảnh minh họa" collapsible section for every
  exercise type; `DELETE /admin/exercises/:id/assets/:assetId`.
- cteni_1 per-item image upload in CMS (CteniFields image/text
  toggle); Flutter `_buildCteni1Layout` redesign.
- `Course.BannerImageID` + `MockTest.BannerImageID` with
  `POST/DELETE /admin/{courses,mock-tests}/:id/banner`. CMS card
  header + Flutter Course/MockTest cards show banner.
- Security fix: `isSafeAssetKey()` uses `filepath.Clean + HasPrefix`
  instead of `strings.Contains("..")`.
- DB: inline `ALTER TABLE ADD COLUMN IF NOT EXISTS` at startup for all
  stores — no manual goose run. **RDS caveat**: `ALTER TABLE` requires
  table owner; if goose ran as a different user, app user can't ALTER.
  Fix: (1) one-time `ALTER TABLE ... OWNER TO <app_user>` after
  initial migration (see `deploy-first-release-checklist.md`); (2)
  `addColumnIfMissing()` checks `information_schema` first.
- Specs: `docs/specs/media-enrichment.md`.

---

## V10 — Exam Result Flow Redesign — 2026-04-30

- `MockExamSectionDetailScreen` accepts `skillKind` + `maxPoints`,
  dispatches `SectionResultCard` instead of always `ResultCard`.
- `SectionResultCard`: unified header (skill icon + label + score +
  progress bar) + body per skill (noi/viet → `ResultCard`, nghe/doc →
  `ObjectiveResultCard`).
- `ObjectiveResultCard`: card-per-question (green/red bg), 2-line
  wrong-answer layout, passage collapsible for doc.
- `_buildAnalyzingView`: LinearProgressIndicator + step list per
  speaking section (✓/⏳/○).
- 4 i18n keys: `objectiveYourAnswer`, `objectiveCorrectAnswer`,
  `viewPassage`, `hidePassage`.
- Bug fix `AdvanceMockExam`: query went from "first pending" to JOIN
  attempts ON exercise_id — fixes 400 on mixed-skill exams.
- Feature: `QuestionResult.question_text`,
  `QuestionResult.learner_answer_text` + `correct_answer_text` —
  backend extracts option text so Flutter renders "A — Nová kavárna".
- Bug fix: overall score invisible in result hero — `RichText` root
  `TextSpan` did not inherit `DefaultTextStyle`; explicit `color:
  AppColors.onSurface` added.
- Specs: `docs/specs/exam-result-flow-redesign.md` +
  `exam-result-flow-implementation.md`.
- Tests: 16 widget tests in `section_result_card_test.dart`.

---

## V9 — CMS Exercise Dashboard Upgrade — 2026-04-30

- `exercise-dashboard.tsx` 2036 lines → 5 files: `exercise-utils.ts`,
  `exercise-list.tsx`, `exercise-form/index.tsx`, `exercise-matrix.tsx`,
  `exercise-dashboard.tsx` (thin orchestrator, 211 lines).
- Coverage Matrix: Module rows × 4 cols (Nói/Nghe/Viết/Đọc), color by
  published count vs target 20, grouped by Course, sorted by
  sequence_no.
- Cell click → set module+skill_kind filter + smooth scroll; toggle
  cell → clear filter.
- Tab "Exam Pool": mini-matrix per exercise_type (Tổng / Published /
  Có ảnh) + flat list; click row → filter.
- Form prefill: matrix-cell-active tap on "+ Tạo exercise" auto-fills
  moduleId + skillKind and advances wizard to step 2.
- Loading skeleton + API error banner with retry.
- Vitest 49 unit tests on `buildMatrix`, parse/build, payload builders.
- Specs: `docs/specs/exercise-dashboard-upgrade.md`.

---

## V8 — Schema Flatten — 2026-04-30

- `skills` table dropped (migrations 017–019).
- `exercises.module_id` + `exercises.skill_kind` replaces
  `exercises.skill_id → skills`.
- `vocabulary_sets.module_id`, `grammar_rules.module_id` replace
  `skill_id`.
- `GET /v1/modules/:id/skills` returns computed `SkillSummary[]`.
- `GET /v1/modules/:id/exercises?skill_kind=X` filters server-side.
- CMS removed `/skills` page; exercise form picks module directly.
- Flutter: `SkillSummary` replaces `Skill`.
- Specs: `docs/specs/schema-flatten-skills.md`.

---

## V7 — Flexible Sprint MockTest — 2026-04-29

- Per-MockTest `pass_threshold_percent` (default 80 sprint / 60 full).
- Admin picks any exercise types per section (not locked to
  session_type).
- Flutter `MockExamScreen` routes section to correct screen
  (speaking/listening/reading/writing).
- `computeScoring` uses dynamic threshold (no hardcoded 24).
- CMS removes `session_type`; adds `pass_threshold_percent` input.
- Intro screen passScore from threshold; result shows % threshold met.

---

## V6 — LLM-Assisted Vocab & Grammar — 2026-04-28

- Async LLM job (Claude tool_use) → admin review/edit → publish atomic.
- Postgres tables: `vocabulary_sets`, `vocabulary_items`,
  `grammar_rules`, `content_generation_jobs`.
- CMS `/vocabulary`: VocabularySet list + edit/delete + Generate →
  inline editors → Save draft / resume / Publish. CMS `/grammar`: full
  parity.
- Flutter: `VocabGrammarExerciseScreen` + `QuizcardWidget` (flip) +
  `MatchingWidget` + filter pills.
- Rate limit: 1 active generation job per admin per module.

---

## Earlier slices (V2–V5) — late 2026-04

- **V2 Writing** (`psani_1_formular`, `psani_2_email`): submit-text
  endpoint, writing scorer, LLM feedback with diff highlight,
  `WritingExerciseScreen` with word-count gate. Bug fixes: parser
  type-coercion for `detail['questions']`, `writingMinWords` defaults
  per type, `_WritingResultPoller` 2-min timeout, `LocaleScope.code`
  used everywhere, `defer recover()` on async scoring goroutine,
  `MaxBytesReader(64KB)` + 500-word cap, Czech UTF-8 fix in
  `api_client.dart` (`_IOSinkImpl` was latin1).
- **V3 Listening** (`poslech_1-5`): submit-answers sync, Polly TTS
  per exercise (2 voices for poslech_4), audio store +
  `GET/POST /v1/exercises/:id/audio`, MultipleChoice/FillIn widgets,
  ObjectiveResultCard.
- **V4 Reading** (`cteni_1-5`): reuses objective scorer with
  case-insensitive substring match for fill-in; SelectableText passage
  in Flutter.
- **V5 Full MockTest**: `session_type` (speaking/pisemna/full) +
  `FullExamSession` (pisemna_score ≥42/70 + ustni_score ≥24/40);
  `POST /v1/full-exams`, `GET /v1/full-exams/:id`, `complete`. Auto-link
  speaking session into open FullExamSession.

---

## V1 baseline (mock + AWS path verified)

- Go backend with attempt upload, learner polling, transcript
  provenance, task-aware feedback for all four oral task types.
- Postgres persistence (opt-in) for exercises, attempts, transcripts,
  feedback.
- S3 + Amazon Transcribe path (verified end-to-end on production).
- LLMFeedbackProvider + LLMReviewProvider (Claude), fail-soft to
  rule-based on error or when unset.
- Amazon Polly TTS for model-answer audio in review artifacts.
- CMS CRUD for all four oral task types with status select; only
  `published` exercises surface to learners.
- CMS prompt-asset upload + preview for `Uloha 3` and `Uloha 4`.
- Compose: named volumes for `backend_assets` + `backend_attempts`;
  `AUDIO_SIGN_SECRET` threaded; `TRANSCRIBE_TIMEOUT` default 3m;
  `LOCAL_ASSETS_DIR` set to volume path.
- Flutter learner flow for all four oral tasks: split Stop/Analyze,
  AnalysisScreen, ResultCard, recent attempts, audio replay, review
  artifact.
- i18n VI + EN via ARB / `cms/lib/i18n.tsx`.
- Provider-aware audio streaming with short-lived signed URLs.
- Mock exam V2: per-section max_points, intro screen, scored result.
- V2 UI design system (Babbel orange `#FF6A14` + warm cream `#FBF3E7` +
  teal `#0F3D3A`; Inter / Fraunces; CMS sidebar; Flutter screen
  redesigns).
- `criteria_results` parsed in Flutter `AttemptFeedbackView` as
  `CriterionCheckView`.
- Admin content guide: `docs/guides/admin-guide.md`.

---

## Cross-cutting hardening rounds

### Infrastructure (2026-04-29 + 2026-05-01)

- `ExerciseAudioStore` + `postgresExerciseAudioStore`: audio metadata
  persists across restart. `LOCAL_ASSETS_DIR` must point to a named
  volume so the MP3 also persists.
- `FullExamStore` + `postgresFullExamStore`: full exam sessions
  persist.
- Polly 2-voice dialog generator for `poslech_4`:
  `DialogExerciseAudioGenerator` + `GenerateDialogAudio()` alternating
  voices + MP3 concat. `POLLY_VOICE_ID_2` env.
- Polly TTS for writing `model_answer_text` in `ProcessWritingAttempt`.

### Security (2026-04-29)

- Dev tokens (`dev-admin-token`, `dev-learner-token`,
  `dev-learner-2-token`) only seed when `ENV != production`. Production
  must set `ENV=production` before deploy.
- `ADMIN_PASSWORD` startup guard: fatal exit if empty or `"demo123"`
  in production. Bcrypt support (`$2a$`/`$2b$` prefix) via
  `golang.org/x/crypto/bcrypt`; dev still plaintext.
- `handleSubmitText`: `MaxBytesReader(64KB)` + 500-word cap.
- CORS: `withCORS` reads `CORS_ALLOWED_ORIGINS` (comma-separated).
  Production without var → no ACAO header. Dev without var → wildcard.
- Audio upload ownership: `handleRecordingStarted`, `handleUploadURL`,
  `handleAttemptAudioUpload`, `handleUploadComplete` all run
  `authorizedAttemptForUser`.
- CMS `admin_token` cookie: `secure: true` when `NODE_ENV=production`.
- `CORS_ALLOWED_ORIGINS` required in `.env.ec2` production.
