# V25 IAP Wire Real — Plan

**Spec**: [docs/specs/iap-wire-real.md](../docs/specs/iap-wire-real.md)
**Idea**: [docs/ideas/iap-wire-real.md](../docs/ideas/iap-wire-real.md)
**Todo**: [v25-iap-wire-real-todo.md](v25-iap-wire-real-todo.md)

## Approach

Vertical slicing trên 8 phase. Backend foundation (A) trước, sau đó hai
nhánh độc lập:

- **Backend nhánh** B (Apple Sign-In endpoint) + C (webhook downgrade
  stitch) — chỉ Go, không phụ thuộc Flutter.
- **Flutter nhánh** D (RealIAPService) + E (Apple Sign-In UI) + F
  (paywall compliance) — chỉ Dart, dùng V17 verify endpoint hiện có cho
  D, dùng B endpoint cho E.

G (legal docs) song song mọi nhánh, ưu tiên hoàn thành trước H. H
(sandbox + TestFlight) là gate cuối — chỉ start khi all of A–G xanh.

**Critical invariant** giữ trong suốt slice:
- Server sole authority cho `pro_tier`. Client không tự set.
- `apple_transaction_id` UNIQUE đảm bảo idempotent verify.
- `notificationUUID` dedupe webhook giữ V17 behaviour.
- Mọi prompt / model ID / fallback string giữ V17 location (V25 không
  LLM).

**Critical kill switch**: nếu Phase B JWS verify không pass theo Apple
JWKS rotate test (B1 acceptance), Phase E không start — Sign-in-with-
Apple flow phụ thuộc B end-to-end. Backend nhánh C + Flutter nhánh D
+ F + G vẫn tiếp tục.

## Dependency Graph

```
A1 ─┬─▶ A2 ─▶ B1 ─▶ B2 ─▶ E1 ─▶ E2 ─┐
    ├─▶ A3 ─▶ C1 ─────────────────────┤
    └─▶ D1 ─▶ D2 ─▶ D3 ────────────────├─▶ Checkpoint Backend+Flutter ─▶ H1 ─▶ H2 ─▶ H3
                  F1 ──────────────────┤
G1 (parallel) ────────────────────────┘
```

A1 (mig 028 + apple_sub) blocks B (apple_sub upsert), không block D
(Flutter IAP).
A2 (JWKS lib) blocks chỉ B.
A3 (FindByTransactionID) blocks chỉ C.
D có thể chạy parallel A2/A3/B/C — chỉ phụ thuộc V17 verify endpoint
đã có.
F độc lập — UI-only paywall.
G độc lập — markdown only.
E1 phụ thuộc B endpoint xong. E2 phụ thuộc E1 + screen sẵn có.
H phụ thuộc tất cả.

Estimate tổng: **9-11 ngày**, có thể nén còn **7-8 ngày** nếu parallel
2 dev (1 backend B+C+G, 1 Flutter D+E+F).

## Phase A — Backend Foundation (1 ngày)

### A1. Migration 028 + UserStore upsert

**Files**:
- `backend/db/migrations/028_v25_user_apple_sub.sql` [NEW]
- `backend/internal/store/postgres_migrate.go` [MOD]
- `backend/internal/store/postgres_users.go` [MOD]
- `backend/internal/store/memory.go` [MOD]
- `backend/internal/store/postgres_users_test.go` [MOD]

**Acceptance**:
- `users.apple_sub TEXT` column tạo qua `addColumnIfMissing` (RDS owner-mismatch safe)
- Partial unique index `users_apple_sub_uniq WHERE apple_sub IS NOT NULL` tạo
- `UserStore.UpsertByAppleSub(sub, email, displayName) (UserAccount, error)` thêm cả Postgres + memory impl
- 2 test: `TestUserStore_UpsertByAppleSub_NewUser` + `TestUserStore_UpsertByAppleSub_Existing` (idempotent re-call)

**Verify**:
- `make backend-test ARGS="-run UpsertByAppleSub"` pass
- `make backend-build` pass
- Manual: chạy migration 2 lần liên tiếp — idempotent, không error

**Size**: S (5 files)

### A2. Apple JWKS verifier

**Files**:
- `backend/internal/iap/apple_jwks.go` [NEW]
- `backend/internal/iap/apple_jwks_test.go` [NEW]
- `backend/go.mod` [MOD] — add `github.com/lestrrat-go/jwx/v2`

**Acceptance**:
- `AppleJWKSVerifier` struct với `Verify(ctx, idToken) (AppleClaims, error)`
- `AppleClaims` chứa `Sub`, `Email`, `EmailVerified`, `Nonce`, `NonceSupported`, `Aud`, `Iss`, `Exp`
- JWKS cache via `jwk.NewCache` — refresh 24h
- Verify steps: signature theo `kid`, `iss=https://appleid.apple.com`, `aud=eu.hadoo.czechgo` (config), `exp > now`
- 2 test: `TestAppleJWKS_VerifyWithFixture` (fixed JWK + signed token RSA roundtrip), `TestAppleJWKS_KeyRotation` (cache miss → refetch)

**Verify**:
- `make backend-test ARGS="-run AppleJWKS"` pass (cả 2)
- `make backend-build` pass

**Size**: M (3 files, lib lần đầu)

### A3. ProPurchaseStore.FindByTransactionID

**Files**:
- `backend/internal/store/postgres_pro_purchases.go` [MOD]
- `backend/internal/store/memory.go` [MOD]
- `backend/internal/store/postgres_pro_purchases_test.go` [MOD]
- `backend/internal/store/memory_test.go` [MOD]

**Acceptance**:
- Interface thêm `FindByTransactionID(txn string) (contracts.ProPurchase, bool)`
- Postgres: `SELECT … WHERE apple_transaction_id=$1 LIMIT 1`
- Memory: linear scan
- 2 test: hit + miss case (memory + postgres)

**Verify**:
- `make backend-test ARGS="-run FindByTransactionID"` pass

**Size**: S (4 files)

### Checkpoint A — Backend foundation
- [ ] `make backend-build` pass
- [ ] `make backend-test` pass (~648 + 6 = 654)
- [ ] Migration 028 run 2 lần idempotent
- [ ] go.mod chỉ thêm `lestrrat-go/jwx/v2` — không pull deps lạ

## Phase B — Apple Sign-In endpoint (1.5 ngày)

### B1. handleAuthApple handler

**Files**:
- `backend/internal/httpapi/auth_handlers_apple.go` [NEW]
- `backend/internal/httpapi/auth_handlers_apple_test.go` [NEW]
- `backend/internal/httpapi/server.go` [MOD] — wire `appleJWKS` field + register route

**Acceptance**:
- `POST /v1/auth/apple` accepts `{identity_token, authorization_code, nonce, given_name?, family_name?}`
- Verify identity_token qua `s.appleJWKS.Verify`
- Nonce match: `claims.Nonce == req.Nonce` (Apple SHA256 client-side, raw nonce server-side comparable)
- Upsert qua `UserStore.UpsertByAppleSub(claims.Sub, claims.Email, displayName)`
- Mint `auth_tokens` row 90-day TTL
- Trả `200 {token, user}`
- Errors: 400 invalid_token, 400 nonce_mismatch, 400 expired_token, 400 invalid_audience, 401 issuer_mismatch
- New user: `email_verified=true`, `current_level='a2'` (V21 default), `pro_tier='free'`
- 6 test cover happy path (new + existing user) + 4 error path

**Verify**:
- `make backend-test ARGS="-run HandleAuthApple"` pass (cả 6)
- `make backend-build` pass

**Size**: M (3 files)

### B2. Route registration + smoke

**Files**:
- `backend/internal/httpapi/auth_handlers.go` [MOD] — `registerV17Routes` thêm `/v1/auth/apple`
- `backend/internal/httpapi/server_test.go` [MOD] — full integration test

**Acceptance**:
- Route `/v1/auth/apple` reachable trên server boot
- Integration test: HTTP POST → verify (mock JWKS verifier qua interface override) → upsert → token mint → 200
- Existing email signup/login routes regression — không thay đổi behaviour

**Verify**:
- `make backend-test ARGS="-run TestServer_AuthApple_Integration"` pass
- `curl -X POST localhost:8080/v1/auth/apple -d '{}'` trả 400 invalid_body (handler reachable)

**Size**: S (2 files)

### Checkpoint B — Apple auth backend
- [ ] `make backend-test` pass (~660)
- [ ] Endpoint reachable, 400 trên empty body
- [ ] Mock JWKS verifier path tested

## Phase C — Webhook downgrade stitch (0.5 ngày)

### C1. applyWebhookExpiration rewrite

**Files**:
- `backend/internal/httpapi/iap_handlers.go` [MOD]
- `backend/internal/httpapi/iap_handlers_test.go` [MOD]

**Acceptance**:
- `applyWebhookExpiration(notif)` lookup `FindByTransactionID(notif.TransactionID)` → user_id
- `MarkProPurchaseInactive(notif.TransactionID)` → `downgradeIfExpired(user_id)`
- `applyWebhookRefund` reuse path (chỉ gọi `applyWebhookExpiration`)
- Unknown txn → log + no-op (không crash)
- 3 test: `TestApplyWebhookExpiration_DowngradesUser`, `TestApplyWebhookExpiration_UnknownTxn_Logs`, `TestApplyWebhookRefund_ReusesExpirationPath`
- `notificationUUID` dedupe regression test giữ nguyên

**Verify**:
- `make backend-test ARGS="-run ApplyWebhook"` pass (3)
- Manual: POST mock ASSN EXPIRED payload với secret → user `pro_tier` flip free trong DB

**Size**: S (2 files)

### Checkpoint C — Webhook stitch
- [ ] `make backend-test` pass (~663)
- [ ] Webhook EXPIRED → user downgrade end-to-end (mock or sandbox)

## Phase D — Flutter RealIAPService (2 ngày)

### D1. Pubspec + iOS entitlements

**Files**:
- `flutter_app/pubspec.yaml` [MOD] — `in_app_purchase: ^3.2.0`, `sign_in_with_apple: ^6.1.0`
- `flutter_app/ios/Runner/Runner.entitlements` [MOD] — `com.apple.developer.applesignin` Default + `com.apple.developer.in-app-payments` merchant
- `flutter_app/ios/Podfile.lock` [MOD] (auto)

**Acceptance**:
- `flutter pub get` xong, `pod install` thành công
- `flutter build ios --debug --no-codesign` pass
- Entitlements file render đúng XML
- `flutter analyze` không cảnh báo mới

**Verify**:
- `cd flutter_app && flutter pub get && cd ios && pod install && cd .. && flutter build ios --debug --no-codesign`
- `make flutter-analyze` pass

**Size**: S (3 files)

### D2. RealIAPService implementation

**Files**:
- `flutter_app/lib/core/iap/real_iap_service.dart` [NEW]
- `flutter_app/test/core/iap/real_iap_service_test.dart` [NEW]

**Acceptance**:
- `RealIAPService` implements `IAPService` 3 method
- `start()` mở `purchaseStream` listener; `dispose()` cancel
- `loadProducts()` qua `InAppPurchase.queryProductDetails(IAPProducts.all.toSet())`, map sang `IAPProduct`
- `buy()` mở `Completer`, gọi `buyNonConsumable`, observer fulfil
- `restorePurchases()` gọi `InAppPurchase.restorePurchases()`, trả cached restored list
- Observer: `purchased`/`restored` → POST `/v1/iap/apple/verify` qua `apiClient.verifyAppleReceiptV17` → `authService.refresh()` → fulfil completer; `error`/`canceled` → fail completer; `pendingCompletePurchase` → `completePurchase()`
- 5 test: loadProducts, buy happy, buy canceled, restore, error propagation (mock `InAppPurchase` qua `IInAppPurchase` interface)

**Verify**:
- `make flutter-test ARGS="--name=real_iap_service"` pass (5)
- `make flutter-analyze` pass

**Size**: M (2 files)

### D3. main.dart wire + observer lifecycle

**Files**:
- `flutter_app/lib/main.dart` [MOD]
- `flutter_app/test/main_test.dart` hoặc app shell test [MOD nếu có]

**Acceptance**:
- `kIapEnabled = !kIsWeb && Platform.isIOS && bool.fromEnvironment('IAP_ENABLED', defaultValue: true)`
- Production iOS: `iapService = RealIAPService(authService)..start()`
- Khác: giữ `StubIAPService`
- Singleton — 1 instance, dispose trên app close
- Existing widget tests dùng stub không bị regression

**Verify**:
- `make flutter-test` pass (~316)
- Build + run iOS simulator (no codesign): paywall mở, `loadProducts()` gọi StoreKit → simulator trả empty (sandbox config chưa wire) — không crash

**Size**: S (2 files)

### Checkpoint D — Flutter IAP service
- [ ] `make flutter-analyze` pass
- [ ] `make flutter-test` pass (~316)
- [ ] iOS simulator build pass, paywall không crash khi loadProducts

## Phase E — Apple Sign-In UI (1 ngày)

### E1. AuthService.signInWithApple + ApiClient

**Files**:
- `flutter_app/lib/core/api/api_client.dart` [MOD] — `signInWithAppleV25(payload)`
- `flutter_app/lib/core/auth/auth_service.dart` [MOD] — `signInWithApple()`
- `flutter_app/test/core/auth/auth_service_test.dart` [MOD]
- `flutter_app/test/core/api/api_client_test.dart` [MOD]

**Acceptance**:
- `AuthService.signInWithApple()`: tạo nonce SHA256(random 32 bytes), gọi `SignInWithApple.getAppleIDCredential(scopes:[email,fullName], nonce: rawNonce)`, build payload, POST `/v1/auth/apple`, save token, navigate caller-defined
- `ApiClient.signInWithAppleV25` POST `/v1/auth/apple` với headers JSON, body chuẩn spec §4.2
- Cancel: `SignInWithAppleAuthorizationException` → propagate user-friendly message
- Error path: 400 invalid_token surfaces qua existing `ApiException`
- 3 test: happy, cancel, invalid_token

**Verify**:
- `make flutter-test ARGS="--name=auth_service"` pass (cả 3)
- `make flutter-test ARGS="--name=api_client"` pass

**Size**: M (4 files)

### E2. SignInWithAppleButton trên 3 screens

**Files**:
- `flutter_app/lib/features/auth/screens/welcome_screen.dart` [MOD]
- `flutter_app/lib/features/auth/screens/login_screen.dart` [MOD]
- `flutter_app/lib/features/auth/screens/signup_screen.dart` [MOD]
- `flutter_app/test/features/auth/welcome_screen_test.dart` [MOD]
- `flutter_app/test/features/auth/login_screen_test.dart` [MOD]
- `flutter_app/test/features/auth/signup_screen_test.dart` [MOD]

**Acceptance**:
- Mỗi screen render `SignInWithAppleButton` (style `.black`, height 52, radius 12, equal prominence với email CTA)
- Đặt sau `_OrDivider` widget mới (chia tay email/Apple flow)
- Tap → `authService.signInWithApple()` → success navigate home, error inline error
- 3 test (1 mỗi screen): button render + tap dispatch correct method
- Apple HIG asset compliance — dùng package widget chính chủ, không tự render logo

**Verify**:
- `make flutter-test ARGS="--name=welcome_screen|login_screen|signup_screen"` pass (3)
- `make flutter-analyze` pass
- Manual iOS simulator: 3 screen render Apple button, tap mở native sheet (TestFlight cần real device để test full flow)

**Size**: M (6 files)

### Checkpoint E — Sign-in-with-Apple UI
- [ ] `make flutter-test` pass (~325)
- [ ] 3 screen render Apple button, manual tap mở Apple sheet
- [ ] Apple HIG asset không tự custom

## Phase F — Paywall compliance (0.5 ngày)

### F1. PaywallScreen disclosure + Terms/Privacy

**Files**:
- `flutter_app/lib/features/paywall/screens/paywall_screen.dart` [MOD]
- `flutter_app/test/features/paywall/paywall_screen_test.dart` [MOD]
- `flutter_app/lib/core/config/legal_urls.dart` [NEW] — placeholder URLs (TBD operator)

**Acceptance**:
- Disclosure block render giữa ProductPicker + FilledButton "Nâng cấp Pro": 3 dòng
  1. "Tự động gia hạn cho đến khi bạn hủy ≥24h trước hết kỳ."
  2. "Thanh toán qua Apple ID khi xác nhận mua."
  3. "Quản lý/hủy: Cài đặt → Apple ID → Đăng ký."
- Terms + Privacy text-button row dưới Restore button: tap launch URL via `url_launcher` package (nếu chưa có thì add)
- Disclosure render kể cả lúc loading (`_products == null`) hoặc error
- `legal_urls.dart` chứa `eulaUrl` + `privacyUrl` constant (TBD URL từ G1 hoặc operator)
- 2 test: disclosure visible khi loading, terms tap dispatch URL

**Verify**:
- `make flutter-test ARGS="--name=paywall_screen"` pass
- Manual iOS simulator: paywall render disclosure + button row, tap "Điều khoản" mở external link

**Size**: S (3 files)

### Checkpoint F — Paywall compliance
- [ ] `make flutter-test` pass
- [ ] Disclosure block luôn visible
- [ ] EULA/Privacy button work (mở external)

## Phase G — Legal docs (1 ngày, parallel)

### G1. EULA + Privacy VI/EN draft

**Files**:
- `docs/reference/legal-eula.md` [NEW]
- `docs/reference/legal-privacy.md` [NEW]

**Acceptance**:
- EULA bilingual VI primary, EN section dưới: subscription auto-renewal, refund via Apple, acceptable use, termination, liability cap, Vietnam jurisdiction
- Privacy bilingual: data collected (email, learner content, device, IAP receipts), 3rd-party processors (Apple, AWS, Anthropic, ElevenLabs, Replicate), retention (account ∞, content until delete, receipts 7y), user rights (access/delete/export — V17 §10 wired), contact email TBD
- Match V25 spec §11
- Format: H1 title, H2 mỗi điều khoản, EN section dùng "## English version" anchor

**Verify**:
- Markdown render OK
- Operator review trước hosting
- Privacy declared data match thực tế V17 + V25 collection (kiểm cross với code)

**Size**: M (2 files, ~600 dòng tổng)

## Phase H — Sandbox + TestFlight (2 ngày, gate cuối)

### H1. StoreKit configuration + sandbox smoke

**Files**:
- `flutter_app/ios/Configuration/Storekit.storekit` [NEW]
- `flutter_app/ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` [MOD] — link StoreKit config

**Acceptance**:
- StoreKit config file mirror App Store Connect products: monthly + yearly với giá VND
- Subscription Group "Czech Go Pro"
- Sandbox build qua Xcode (không codesign cho dev) → simulator có thể test buy local mà không cần sandbox tester
- Smoke test manual: buy monthly → verify endpoint local backend → DB pro_purchases row + user pro_tier='pro'

**Verify**:
- Xcode → Run → Product → Scheme → StoreKit Configuration set
- iPhone simulator buy flow → StoreKit sheet → Face ID skip → purchaseStream emits → backend log show verify call

**Size**: S (2 files, Xcode UI work)

### H2. App Store Connect operator checklist

**Files**: không (operator task)

**Acceptance** (operator hoàn thành, Claude check by reading App Store Connect screenshots hoặc verbal confirm):
- [ ] Tax + banking signed
- [ ] Subscription products created (`eu.hadoo.czechgo.pro.monthly`, `.yearly`) với giá final D4 (99k/790k)
- [ ] Subscription Group "Czech Go Pro" — cả 2 product
- [ ] Localization VI + EN cho subscription title + description
- [ ] Sandbox tester ≥ 2 (1 VN region, 1 cross-currency)
- [ ] App Privacy declarations match `legal-privacy.md`
- [ ] EULA URL + Privacy URL set (hoặc Apple Standard EULA)

**Verify**:
- Operator confirm checklist xong
- Sandbox tester login simulator → buy thực tế

**Size**: XS (operator, không code)

### H3. TestFlight build + beta review

**Files**:
- `flutter_app/ios/fastlane/` [NEW nếu có] hoặc Xcode Archive workflow
- `CHANGELOG.md` [MOD] — V25 entry on ship
- `SPEC.md` [MOD] — V25 digest row on ship

**Acceptance**:
- Flutter release build: `flutter build ios --release --dart-define=IAP_ENABLED=true`
- Xcode Archive + Distribute → App Store Connect TestFlight
- Beta review submit
- ≥ 1 beta tester (operator) cài qua TestFlight, test full flow:
  - Sign-in-with-Apple
  - Sign-in email (regression)
  - Buy monthly → verify → Pro
  - Restore (uninstall reinstall)
  - Cancel via Settings → Apple ID → Subscriptions → simulate expire (Sandbox accelerated) → ASSN webhook EXPIRED → user downgrade
- Beta review pass (Apple ack)
- CHANGELOG entry + SPEC.md digest row updated

**Verify**:
- TestFlight build downloadable
- Apple beta review status = "Ready to Test"
- Manual smoke pass cả 5 flow trên iPhone thật
- `make verify` pass cuối cùng

**Size**: M (3 files, manual ops)

### Checkpoint H — Ready to ship
- [ ] All 14 backend test pass (target ~668)
- [ ] All 16 Flutter test pass (target ~325)
- [ ] CMS giữ 144
- [ ] `make verify` pass
- [ ] Sandbox smoke pass cả 5 flow
- [ ] TestFlight beta review pass
- [ ] CHANGELOG + SPEC.md cập nhật
- [ ] Ready for prod App Store submit (chờ tax/banking nếu chưa)

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Apple tax/banking xét > 14 ngày | High (block launch, không block code) | Operator submit ngay D0; code sandbox/TestFlight không phụ thuộc; defer launch button |
| `lestrrat-go/jwx/v2` pull deps lạ vào go.mod | Med | Lock `^2.x`; `go mod tidy` audit; nếu dirty fallback `golang-jwt/jwt/v5` + tự fetch JWKS |
| `in_app_purchase: ^3.2.0` API breaking change | Med | Lock minor; nếu break check changelog; đã review API stable từ Flutter team |
| Sign-in-with-Apple "Hide my email" relay | Low | Backend lưu raw, Privacy Policy mention rõ; user OK Apple relay là email |
| Sandbox Apple sheet không hiện (entitlement missing) | Med | Entitlement D1 + provisioning profile có "Sign In with Apple" capability; test sớm trên D3 build |
| Apple beta review reject 3.1.2(a) | High | F1 disclosure + G1 EULA/Privacy đầy đủ; review copy Apple template trước submit |
| Apple beta review reject 4.8 | High | E2 button equal prominence; test render trên iPhone SE 375px |
| Backend test count regression do mock JWKS | Low | Interface override pattern V17, đã proven; mock không touch real network |
| Flutter widget test fail vì stub vẫn dùng | Low | D3 build flag chỉ swap production; widget test giữ stub |
| Operator chưa setup App Store Connect (H2) khi code xong | High | H2 độc lập song song mọi phase; ping operator D0; H3 không block bởi H2 nếu sandbox via local StoreKit config (H1) |

## Open Questions

- Hosting EULA + Privacy URL — operator chọn (api.../legal hoặc czechgo.app/legal hoặc CMS page)? G1 viết content, không host. Cần URL trước F1 finalize hoặc dùng placeholder rồi swap.
- StoreKit configuration file checked-in repo hay gitignore? V25 plan check-in (sandbox local dev). Nếu sensitive (chứa product price draft) → gitignore.
- TestFlight beta tester list — chỉ team hay external testers? Apple beta review duyệt nhanh team, external 1-2 ngày.

## Parallelization

**2 dev**:
- Dev A: Backend A → B → C → G1
- Dev B: Flutter D → E → F (block bởi B endpoint cho E1)

**1 dev**:
- A → C → B → G1 → D → F → E → H (interleave)

## Test Counts Target

| Layer | Baseline | V25 add | Target |
|---|---|---|---|
| Backend | 654 (V21.2) | +14 | 668 |
| Flutter | 309 (V21.2) | +16 | 325 |
| CMS | 144 | 0 | 144 |
