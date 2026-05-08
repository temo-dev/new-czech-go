# IAP Wire Real (V25) — Spec

**Slice:** V25 — Production StoreKit + Sign-in with Apple
**Status:** Draft (chưa implement) — chờ human approve trước khi sang plan
**Owner:** TBD
**Last updated:** 2026-05-08

Liên quan:
- Idea: [`docs/ideas/iap-wire-real.md`](../ideas/iap-wire-real.md)
- Plan: [`tasks/v25-iap-wire-real-plan.md`](../../tasks/v25-iap-wire-real-plan.md) (TBD)
- Todo: [`tasks/v25-iap-wire-real-todo.md`](../../tasks/v25-iap-wire-real-todo.md) (TBD)
- Tham chiếu: [`docs/specs/self-serve-learner-spec.md`](self-serve-learner-spec.md) §4.14, §4.15 (V17 IAP foundation)

---

## 1. Objective

Chuyển paywall A2 Mluvení Sprint từ stub `not_implemented` sang StoreKit production thật trên iOS, đóng các V18-polish item backend đủ để webhook xử lý EXPIRED/REFUND end-to-end, và thêm Sign-in with Apple để tuân thủ App Store guideline 4.8.

**Why now**

- V17 đã ship một nửa: backend `/v1/iap/apple/verify` + `/webhook` + `pro_purchases` table chạy tốt. Flutter `StubIAPService` ném `not_implemented` trên Buy → app **không monetize được**.
- LLM/Polly/ElevenLabs cost đã hiện hữu V14 + V15. Quota gate V21.2 + interview gate đã sẵn — chỉ thiếu Pro upgrade path để mở khóa.
- App Store guideline 3.1.2(a) **bắt buộc** subscription disclosure trên paywall — hiện thiếu → 100% reject.
- App Store guideline 4.8: app có email/password signup → bắt buộc Sign-In with Apple equal-prominence.

**Success looks like**

1. Học viên iPhone mở app → quota gate trả 429 → tap upgrade → StoreKit sheet (Face ID) → verify backend → entitlement bật → home unlock không giới hạn.
2. App Store reviewer chấp nhận lần submit đầu — không reject vì 3.1.2(a) hoặc 4.8.
3. ASSN webhook EXPIRED/REFUND tự động flip `users.pro_tier=free` (không phụ thuộc Flutter mở app).
4. Sandbox tester mua được monthly + yearly + restore + cancel + expired flow trong TestFlight.
5. Backend test 668+, Flutter test 325+, all green; `make verify` pass.

**Out of scope (V25)**

- Android Billing — defer V26+.
- Web learner UI / Stripe — khác sản phẩm, defer V27+.
- ASSN JWS verifier (Apple public keys JWT verify) — defer V25.1.
- `FindByOriginalTransactionID` upsert cho webhook activation — defer V25.1.
- Refund email user qua SES — defer V25.1.
- Family Sharing — App Store Connect toggle, không code change, defer V25.1.
- Promotional offers / intro pricing / free trial — defer V26.
- Sign-in with Apple **merge** vào account email cũ — V25 tạo account riêng theo `apple_sub`. Migration manual defer V26.
- Forgotten Apple ID recovery — Apple platform, không phải app.

---

## 2. Quyết định đã chốt

| # | Quyết định | Lý do |
|---|---|---|
| D1 | Boring `in_app_purchase: ^3.x` Flutter package, **không** RevenueCat | Đảo ngược V17 backend đã ship + 12 test. Vendor lock + 1% revenue MTR > $10K. iOS-only đủ V25. |
| D2 | iOS-only, abstract `IAPService` giữ Android-ready | Match V17 spec; widget test giữ `StubIAPService`; V26 wire Android Billing không động backend. |
| D3 | Apple Sign-In tạo **account riêng** theo `apple_sub` | User answer 2026-05-08. Boring nhất. Không merge với email cũ. Migration manual defer V26. |
| D4 | Pricing **99k VND/tháng + 790k VND/năm (-33%)** | Tier 19 + Tier ~159 App Store Connect. < 100k = ngưỡng "thử được" VN, yearly 790k = mạnh hơn 17% cũ, push annual commit. A/B sau khi có 100 conversion baseline. |
| D5 | Defer **all 4** V25.1 polish: JWS verifier, webhook activation upsert, refund email, Family Sharing | User answer "chọn hộ tôi" 2026-05-08. Stopgap đủ cho launch; Flutter `purchaseStream` observer cover 80% renewal flow; SES email không phải critical. |
| D6 | EULA + Privacy draft VI/EN trong V25 | User answer 2026-05-08. Files: `docs/reference/legal-eula.md` + `legal-privacy.md` (cả VI/EN bilingual). Hosting URL operator quyết — viết content trước, host sau. |
| D7 | `purchaseStream` observer = singleton tại `main.dart` post-`runApp` | Tránh race + duplicate subscribe; mỗi PaywallScreen tái dùng instance. |
| D8 | Build flag `kIapEnabled` quyết định `RealIAPService` vs `StubIAPService` | Production iOS = real; widget test + Android = stub. Wire 1 chỗ trong `main.dart`. |
| D9 | Backend `apple_sub` migration = 028, **không** đổi schema `pro_purchases` | Mig 023 đã có `apple_original_transaction_id`. V25 chỉ thêm 1 query method `FindByTransactionID` + 1 column `users.apple_sub`. |
| D10 | Session token sau Apple Sign-In format **giống** V17 email login | Reuse `auth_tokens` table, 90-day expiry, `Authorization: Bearer` header. Không có path code mới cho session lifecycle. |
| D11 | Apple JWKS verify dùng `github.com/lestrrat-go/jwx/v2/jwk` | Cache key auto-rotate qua `jwk.NewCache`; tránh tự viết JWKS fetch + rotate. |
| D12 | Disclosure block + EULA/Privacy text-button **luôn** render — không gate sau loadProducts | Reviewer kiểm cả lúc loading; phải có ngay lập tức. |
| D13 | Restore button text đổi: "Khôi phục giao dịch trước" → giữ nguyên (Apple-OK) | Đã match Apple HIG "Restore Purchases". |
| D14 | Stub vẫn giữ + dùng cho widget test, không xóa | `StubIAPService` test infrastructure; production swap chỉ trong `main.dart`. |

---

## 3. Acceptance Criteria

### A. Buy flow
- [ ] Học viên free tap "Nâng cấp Pro" → `InAppPurchase.queryProductDetails([monthly, yearly])` trả 2 product với giá local hóa từ App Store
- [ ] Tap "Nâng cấp Pro" → `buyNonConsumable()` → StoreKit confirm sheet xuất hiện
- [ ] Sau Face ID confirm, `purchaseStream` emits `PurchaseDetails(status=purchased)` → `POST /v1/iap/apple/verify` với `verificationData.serverVerificationData`
- [ ] Backend trả `200 {pro_expires_at, product_id, is_renewing: true}` → `AuthService.refresh()` → home hiển thị Pro badge
- [ ] `completePurchase()` được gọi → StoreKit transaction queue clear
- [ ] DB row mới trong `pro_purchases` với `is_active=true`, `users.pro_tier='pro'`, `users.pro_expires_at` set

### B. Restore flow
- [ ] Tap "Khôi phục giao dịch trước" → `InAppPurchase.restorePurchases()` → emits restored items
- [ ] Mỗi restored receipt POST verify → backend dedupe theo `apple_transaction_id` → trả 200 (không 409)
- [ ] Không có purchase → toast "Không tìm thấy giao dịch trước đó"
- [ ] Có active purchase → ProSuccessScreen + AuthService refresh

### C. Renewal (background)
- [ ] StoreKit auto-renewal silent → app mở lại → `purchaseStream` emits restored/purchased PurchaseDetails → fire verify → backend tạo row mới với `apple_transaction_id` mới (cùng `apple_original_transaction_id`)
- [ ] Nếu user offline 30 ngày → ASSN webhook EXPIRED → `FindByTransactionID(txn).user_id` → `MarkProPurchaseInactive` + `downgradeIfExpired(userID)` → `users.pro_tier='free'` ngay cả khi user chưa mở app

### D. Sign-in with Apple
- [ ] WelcomeScreen + LoginScreen + SignupScreen render `SignInWithAppleButton` (Apple-spec asset, height 52, equal prominence với email button)
- [ ] Tap → native Apple sheet → `getAppleIDCredential(scopes:[email,fullName], nonce)` → trả `identityToken`, `authorizationCode`, `userIdentifier`
- [ ] `POST /v1/auth/apple {identity_token, authorization_code, nonce, given_name?, family_name?}` → backend verify identityToken JWS qua Apple JWKS → upsert `users` theo `apple_sub` → mint `auth_tokens` row → trả `{token, user}`
- [ ] Apple "Hide my email" relay address chấp nhận làm `users.email` (relay format `*@privaterelay.appleid.com`)
- [ ] App lưu token, navigate home

### E. Paywall compliance
- [ ] PaywallScreen render disclosure block với 3 dòng: auto-renewal, billing-via-Apple-ID, manage-cancellation-path
- [ ] Terms + Privacy text-button row link tới EULA + Privacy URL (deep link or external)
- [ ] Asset `SignInWithAppleButton` dùng package widget chính chủ, không tự render

### F. Webhook downgrade stitch
- [ ] `ProPurchaseStore.FindByTransactionID(txn) (ProPurchase, bool)` trả `user_id` đúng
- [ ] `applyWebhookExpiration` lookup user_id → `MarkProPurchaseInactive(txn)` → `downgradeIfExpired(userID)` → user `pro_tier='free'` nếu không còn active row
- [ ] `applyWebhookRefund` reuse expiration path
- [ ] `notificationUUID` dedupe vẫn work (idempotent replay)

### G. Verification
- [ ] `make backend-test` → 668+ pass (V21.2 baseline 654 + ~14)
- [ ] `make flutter-test` → 325+ pass (baseline 309 + ~16)
- [ ] `make cms-build` + `cd cms && npm test` → giữ 144
- [ ] `make verify` → all green
- [ ] Sandbox StoreKit purchase end-to-end iPhone thật, monthly + yearly + restore + cancel + expired
- [ ] TestFlight beta upload ≥ 1 build, Apple beta review pass

---

## 4. Backend contract

### 4.1 Migration 028 — `users.apple_sub`

```sql
-- backend/db/migrations/028_v25_user_apple_sub.sql
ALTER TABLE users ADD COLUMN IF NOT EXISTS apple_sub TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS users_apple_sub_uniq
    ON users (apple_sub)
    WHERE apple_sub IS NOT NULL;
```

Idempotent. Run via `addColumnIfMissing` trong `postgres_migrate.go` (RDS owner-mismatch safe per V11 caveat).

### 4.2 Endpoint mới — `POST /v1/auth/apple`

**Request**
```json
{
  "identity_token": "eyJ…",
  "authorization_code": "c…",
  "nonce": "abc123",
  "given_name": "Anh",
  "family_name": "Nguyễn"
}
```

**Response 200**
```json
{
  "token": "v17_…",
  "user": {
    "id": "u_…",
    "email": "anh@privaterelay.appleid.com",
    "email_verified": true,
    "nickname": "Anh Nguyễn",
    "pro_tier": "free",
    "current_level": "a2",
    ...
  }
}
```

**Errors**
- `400 invalid_token` — JWS verify fail
- `400 nonce_mismatch` — claim nonce ≠ request nonce
- `400 expired_token` — `exp` < now
- `400 invalid_audience` — `aud` ≠ bundle ID
- `401 issuer_mismatch` — `iss` ≠ `https://appleid.apple.com`

**Verify steps (server)**
1. Fetch JWKS từ `https://appleid.apple.com/auth/keys` (cached 24h via `jwx/v2/jwk.NewCache`)
2. Parse `identity_token` JWT, verify signature theo `kid` từ header
3. Verify claims: `iss=https://appleid.apple.com`, `aud=eu.hadoo.czechgo`, `exp > now`, `nonce_supported=true && nonce=<request>`
4. `apple_sub = claims.sub`
5. Upsert: `SELECT user FROM users WHERE apple_sub=$1`
   - Có → trả user
   - Không → INSERT user mới với `apple_sub`, `email=claims.email`, `email_verified=true`, `current_level='a2'` (V21 default), `pro_tier='free'`, `nickname=given_name + ' ' + family_name` (nếu có)
6. Mint `auth_tokens` row (90-day TTL, format giống email login)
7. Trả `{token, user}`

### 4.3 `ProPurchaseStore` — thêm method

```go
// FindByTransactionID returns the purchase row keyed by Apple's
// transaction id (each renewal has a unique txn id; the original
// transaction id stays constant across renewals).
type ProPurchaseStore interface {
    // ... existing ...
    FindByTransactionID(txn string) (contracts.ProPurchase, bool)
}
```

Postgres impl: `SELECT … FROM pro_purchases WHERE apple_transaction_id=$1 LIMIT 1`. Memory impl: `range d.proPurchases`.

### 4.4 `applyWebhookExpiration` rewrite

```go
func (s *Server) applyWebhookExpiration(notif *iap.Notification) {
    purchase, ok := s.proPurchaseStore.FindByTransactionID(notif.TransactionID)
    if !ok {
        log.Printf("iap-webhook: expiration for unknown txn=%s", notif.TransactionID)
        return
    }
    if !s.proPurchaseStore.MarkProPurchaseInactive(notif.TransactionID) {
        return
    }
    s.downgradeIfExpired(purchase.UserID)
}
```

`applyWebhookRefund` đã reuse path này (chỉ gọi `applyWebhookExpiration`).

### 4.5 LLM config touchpoint

Không. V25 không động prompt / model ID — IAP path không LLM.

### 4.6 Env vars

| Var | Default | Required | Note |
|---|---|---|---|
| `APPLE_BUNDLE_ID` | `eu.hadoo.czechgo` | Y | Audience claim cho identity_token |
| `APPLE_TEAM_ID` | (operator) | N | Optional log/audit |
| `APPLE_JWKS_URL` | `https://appleid.apple.com/auth/keys` | N | Override cho test |
| `IAP_WEBHOOK_SECRET` | (operator) | Y prod | V17 đã có; V25 giữ stopgap |

---

## 5. Flutter contract

### 5.1 Packages

```yaml
# flutter_app/pubspec.yaml
dependencies:
  in_app_purchase: ^3.2.0
  sign_in_with_apple: ^6.1.0
  crypto: ^3.0.3   # đã có; cho nonce SHA256
```

### 5.2 `RealIAPService` (file mới)

```dart
// flutter_app/lib/core/iap/real_iap_service.dart
class RealIAPService implements IAPService {
  RealIAPService(this._authService);

  final AuthService _authService;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  final Map<String, Completer<IAPPurchase>> _pending = {};

  void start() {
    _sub = _iap.purchaseStream.listen(_onPurchaseUpdate);
  }

  void dispose() {
    _sub?.cancel();
  }

  @override
  Future<List<IAPProduct>> loadProducts() async {
    final resp = await _iap.queryProductDetails(IAPProducts.all.toSet());
    return resp.productDetails.map(_toIAPProduct).toList();
  }

  @override
  Future<IAPPurchase> buy(String productId) async {
    final completer = Completer<IAPPurchase>();
    _pending[productId] = completer;
    final resp = await _iap.queryProductDetails({productId});
    if (resp.notFoundIDs.isNotEmpty) {
      throw IAPException(code: 'product_not_found', message: 'Sản phẩm không có sẵn.');
    }
    await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: resp.productDetails.first),
    );
    return completer.future;
  }

  @override
  Future<List<IAPPurchase>> restorePurchases() async {
    await _iap.restorePurchases();
    // observer collects them on stream — return current snapshot
    return _restoredCache;
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> updates) async {
    for (final pd in updates) {
      switch (pd.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verify(pd);
          break;
        case PurchaseStatus.error:
          _failPending(pd.productID, pd.error?.message ?? 'Purchase error');
          break;
        case PurchaseStatus.canceled:
          _failPending(pd.productID, 'Đã hủy');
          break;
        case PurchaseStatus.pending:
          break;
      }
      if (pd.pendingCompletePurchase) {
        await _iap.completePurchase(pd);
      }
    }
  }

  Future<void> _verify(PurchaseDetails pd) async { /* ... POST /v1/iap/apple/verify */ }
}
```

### 5.3 `main.dart` wire

```dart
final iapService = kIapEnabled
    ? RealIAPService(authService)..start()
    : StubIAPService();
```

`kIapEnabled = !kIsWeb && Platform.isIOS && bool.fromEnvironment('IAP_ENABLED', defaultValue: true);`

### 5.4 `PaywallScreen` deltas

1. Disclosure block (mới, dưới ProductPicker, trên FilledButton):
   ```
   Container(padding: 12, decoration: outlineVariant border, radius 12):
     Text('Tự động gia hạn cho đến khi bạn hủy ≥24h trước hết kỳ.')
     Text('Thanh toán qua Apple ID khi xác nhận mua.')
     Text('Quản lý/hủy: Cài đặt → Apple ID → Đăng ký.')
   ```
2. Terms + Privacy row (mới, dưới Restore button):
   ```
   Row(mainAxisAlignment: center):
     TextButton('Điều khoản') → launchUrl(EULA_URL)
     Text(' · ')
     TextButton('Chính sách bảo mật') → launchUrl(PRIVACY_URL)
   ```
3. Không đổi: Header, ComparisonTable, ProductPicker, FilledButton, RestoreButton.

### 5.5 `WelcomeScreen` / `LoginScreen` / `SignupScreen` deltas

Sau cụm CTA email hiện có, thêm:
```dart
const _OrDivider(),
SizedBox(height: 12),
SignInWithAppleButton(
  onPressed: () => _signInWithApple(context),
  style: SignInWithAppleButtonStyle.black,
  height: 52,
  borderRadius: BorderRadius.circular(12),
),
```

`_signInWithApple` flow trong `AuthService.signInWithApple()`:
```dart
final nonce = _sha256(_randomString(32));
final cred = await SignInWithApple.getAppleIDCredential(
  scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
  nonce: nonce,
);
final body = {
  'identity_token': cred.identityToken,
  'authorization_code': cred.authorizationCode,
  'nonce': nonce,
  'given_name': cred.givenName,
  'family_name': cred.familyName,
};
final resp = await _api.post('/v1/auth/apple', body);
await _saveSession(resp.token, resp.user);
```

### 5.6 iOS native config

`ios/Runner/Runner.entitlements`:
```xml
<key>com.apple.developer.applesignin</key>
<array><string>Default</string></array>
<key>com.apple.developer.in-app-payments</key>
<array><string>merchant.eu.hadoo.czechgo</string></array>
```

`ios/Runner/Info.plist` — không đổi (Apple Sign-In + IAP không cần info.plist key extra).

---

## 6. Project Structure (files V25)

```
backend/
  db/migrations/
    028_v25_user_apple_sub.sql                    [NEW]
  internal/
    httpapi/
      auth_handlers_apple.go                      [NEW] POST /v1/auth/apple
      iap_handlers.go                             [MOD] applyWebhookExpiration rewrite
    iap/
      apple_jwks.go                               [NEW] JWKS fetch + verify
    store/
      postgres_pro_purchases.go                   [MOD] +FindByTransactionID
      memory.go                                   [MOD] +FindByTransactionID stub
      postgres_users.go                           [MOD] +UpsertByAppleSub
      postgres_migrate.go                         [MOD] +addColumnIfMissing(users, apple_sub)

flutter_app/
  pubspec.yaml                                    [MOD] +in_app_purchase, +sign_in_with_apple
  ios/Runner/Runner.entitlements                  [MOD] +applesignin
  lib/
    main.dart                                     [MOD] wire RealIAPService
    core/
      auth/auth_service.dart                      [MOD] +signInWithApple
      iap/
        real_iap_service.dart                     [NEW]
      api/api_client.dart                         [MOD] +signInWithAppleV25
    features/
      auth/screens/
        welcome_screen.dart                       [MOD] +SignInWithAppleButton
        login_screen.dart                         [MOD] +SignInWithAppleButton
        signup_screen.dart                        [MOD] +SignInWithAppleButton
      paywall/screens/
        paywall_screen.dart                       [MOD] +disclosure block, +terms/privacy row

docs/
  reference/
    legal-eula.md                                 [NEW] VI/EN bilingual EULA
    legal-privacy.md                              [NEW] VI/EN bilingual Privacy Policy
  specs/
    iap-wire-real.md                              [THIS FILE]
  ideas/
    iap-wire-real.md                              [DONE 2026-05-08]

tasks/
  v25-iap-wire-real-plan.md                       [NEW] Phase A..E breakdown
  v25-iap-wire-real-todo.md                       [NEW] Task checklist
  plan.md                                         [MOD] +V25 entry
  todo.md                                         [MOD] +V25 entry

CHANGELOG.md                                      [MOD] +V25 entry on ship
SPEC.md                                           [MOD] +V25 digest row on ship
```

---

## 7. Commands

| Goal | Command |
|---|---|
| Build backend | `make backend-build` |
| Backend test | `make backend-test` |
| CMS build/lint/test | `make cms-build` + `make cms-lint` + `cd cms && npm test` |
| Flutter analyze/test | `make flutter-analyze` + `make flutter-test` |
| Full verify | `make verify` |
| Pubspec install | `cd flutter_app && flutter pub get` |
| iOS pod install | `cd flutter_app/ios && pod install` |
| Run iOS simulator | `make dev-ios` |
| Sandbox build (StoreKit config) | `flutter build ios --debug --dart-define=IAP_ENABLED=true` |
| TestFlight upload | `cd flutter_app && fastlane beta` (nếu có) hoặc Xcode Archive → Distribute |

---

## 8. Code Style

### Go (backend)

```go
// Package httpapi — auth_handlers_apple.go
//
// POST /v1/auth/apple — verify Apple identity_token, upsert user by
// apple_sub, mint session token. JWS verify uses lestrrat-go/jwx
// with auto-rotated JWKS cache.

func (s *Server) handleAuthApple(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        writeMethodNotAllowed(w)
        return
    }
    r.Body = http.MaxBytesReader(w, r.Body, 32*1024)

    var req appleAuthRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        writeAuthError(w, http.StatusBadRequest, "invalid_body", "request body is not valid JSON")
        return
    }

    claims, err := s.appleJWKS.Verify(r.Context(), req.IdentityToken)
    if err != nil {
        writeAuthError(w, http.StatusBadRequest, "invalid_token", err.Error())
        return
    }
    if claims.Nonce != req.Nonce {
        writeAuthError(w, http.StatusBadRequest, "nonce_mismatch", "nonce does not match")
        return
    }

    user, err := s.userStore.UpsertByAppleSub(claims.Sub, claims.Email,
        strings.TrimSpace(req.GivenName+" "+req.FamilyName))
    if err != nil {
        writeAuthError(w, http.StatusInternalServerError, "internal", "could not upsert user")
        return
    }

    token, err := s.authTokenStore.Mint(user.ID, 90*24*time.Hour)
    if err != nil {
        writeAuthError(w, http.StatusInternalServerError, "internal", "could not mint token")
        return
    }

    writeJSON(w, http.StatusOK, map[string]any{"token": token, "user": user})
}
```

### Dart (Flutter)

```dart
// flutter_app/lib/core/iap/real_iap_service.dart
//
// Production StoreKit binding. Owns purchaseStream observer, fires
// /v1/iap/apple/verify per purchase/restore, completes transactions.
// Singleton: instantiated once in main.dart, disposed in app lifecycle.

class RealIAPService implements IAPService {
  RealIAPService({required this.authService});

  final AuthService authService;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  final Map<String, Completer<IAPPurchase>> _pending = {};
  final List<IAPPurchase> _restoredCache = [];

  void start() {
    _sub = _iap.purchaseStream.listen(_onPurchaseUpdate);
  }

  Future<void> _verify(PurchaseDetails pd) async {
    try {
      await authService.apiClientForScreens.verifyAppleReceiptV17(
        receipt: pd.verificationData.serverVerificationData,
        productId: pd.productID,
      );
      await authService.refresh();
      _completePending(pd.productID, IAPPurchase(
        transactionId: pd.purchaseID ?? '',
        productId: pd.productID,
        receipt: pd.verificationData.serverVerificationData,
      ));
    } catch (e) {
      _failPending(pd.productID, e.toString());
    }
  }
}
```

**Conventions matching project:**

- Backend: tabs, `gofmt`, lowercase package, error wrap với `errors.Is`/`fmt.Errorf("…: %w", err)`, no inline LLM strings (V25 không touch LLM).
- Flutter: 2-space indent, `dart format`, prefer `const`, AppColors / AppSpacing / AppTypography tokens, all learner copy qua ARB → `AppLocalizations`. **PaywallScreen disclosure copy inline VI** (form-field convention per AGENTS.md "form-field components use inline VI").
- Go: server-set fields immutable from client (`pro_tier` flip via IAP only).

---

## 9. Testing Strategy

### Backend (target +14 tests, total 668)

| Test | File | Cover |
|---|---|---|
| `TestHandleAuthApple_ValidToken_NewUser` | `httpapi/auth_handlers_apple_test.go` | Upsert path, mint token |
| `TestHandleAuthApple_ValidToken_ExistingUser` | same | Lookup-by-apple_sub path |
| `TestHandleAuthApple_InvalidJWS` | same | 400 invalid_token |
| `TestHandleAuthApple_NonceMismatch` | same | 400 nonce_mismatch |
| `TestHandleAuthApple_ExpiredToken` | same | 400 expired_token |
| `TestHandleAuthApple_AudienceMismatch` | same | 400 invalid_audience |
| `TestAppleJWKS_VerifyWithFixture` | `iap/apple_jwks_test.go` | Fixed JWKS + fixed token roundtrip |
| `TestAppleJWKS_KeyRotation` | same | Old key still cached, new key fetched |
| `TestProPurchaseStore_FindByTransactionID_Memory` | `store/memory_pro_purchases_test.go` | Lookup hit/miss |
| `TestProPurchaseStore_FindByTransactionID_Postgres` | `store/postgres_pro_purchases_test.go` | Same against pg |
| `TestApplyWebhookExpiration_DowngradesUser` | `httpapi/iap_handlers_test.go` | Full webhook → user_id lookup → downgrade |
| `TestApplyWebhookExpiration_UnknownTxn_Logs` | same | Graceful no-op + log |
| `TestApplyWebhookRefund_ReusesExpirationPath` | same | Refund = expiration semantics |
| `TestUserStore_UpsertByAppleSub_Idempotent` | `store/postgres_users_test.go` | Re-call same `apple_sub` → same user_id |

### Flutter (target +16 tests, total 325)

| Test | File | Cover |
|---|---|---|
| `paywall_screen_test`: disclosure block visible | `test/features/paywall/paywall_screen_test.dart` | Asset compliance |
| `paywall_screen_test`: terms/privacy buttons launch URL | same | Reviewer requirement |
| `paywall_screen_test`: existing flows still pass | same | Regression |
| `welcome_screen_test`: Apple button rendered | `test/features/auth/welcome_screen_test.dart` | 4.8 compliance |
| `login_screen_test`: Apple button rendered | `test/features/auth/login_screen_test.dart` | 4.8 |
| `signup_screen_test`: Apple button rendered | `test/features/auth/signup_screen_test.dart` | 4.8 |
| `auth_service_test`: signInWithApple happy | `test/core/auth/auth_service_test.dart` | Mock `sign_in_with_apple` + http |
| `auth_service_test`: signInWithApple cancel | same | Apple sheet dismissed |
| `auth_service_test`: signInWithApple invalid_token | same | Backend 400 surfaces error |
| `real_iap_service_test`: loadProducts maps StoreKit details | `test/core/iap/real_iap_service_test.dart` | Mock InAppPurchase |
| `real_iap_service_test`: buy → verify → complete | same | Full happy path |
| `real_iap_service_test`: buy canceled → IAPException(canceled) | same | UI feedback |
| `real_iap_service_test`: restore emits cached | same | Restore flow |
| `real_iap_service_test`: error PurchaseDetails surfaces IAPException | same | Error propagation |
| `api_client_test`: signInWithAppleV25 sends correct payload | `test/core/api/api_client_test.dart` | Wire format |
| Widget tests: stub IAPService still drives existing paywall test | regression | Build flag swap doesn't break tests |

### CMS

Không thay đổi — giữ 144.

### Manual / sandbox

- Sandbox tester ≥ 2 (1 VN region, 1 non-VN cross-currency)
- iPhone thật (simulator StoreKit hạn chế) — monthly buy + yearly buy + restore + cancel via Settings + expired flow (StoreKit configuration test mode)
- TestFlight build ≥ 1 — Apple beta review
- Apple Sign-In: test "Hide my email" relay path

### Coverage gate

Không thêm coverage threshold cứng — match V17 baseline (no enforced %).

---

## 10. App Store Connect operator checklist

Operator (không phải Claude) hoàn thành **trước khi** TestFlight beta review:

- [ ] Tax + banking — Paid Apps Agreement signed (lead 1-2 tuần)
- [ ] Subscription products tạo: `eu.hadoo.czechgo.pro.monthly` (Tier 19 = 99k VND), `eu.hadoo.czechgo.pro.yearly` (Tier ~159 = 790k VND)
- [ ] Subscription Group "Czech Go Pro" — cả 2 product cùng group (cho phép upgrade/downgrade)
- [ ] Sandbox tester accounts ≥ 2 (Users and Access → Sandbox Testers)
- [ ] App Store Connect → App Privacy → declare data collection (email, learner content, IAP)
- [ ] App Information → Privacy Policy URL, EULA URL (hoặc chọn "Apple Standard EULA" nếu chưa custom)
- [ ] App Store Connect → Subscription localization (VI title + description, EN title + description)
- [ ] StoreKit Configuration file `flutter_app/ios/Configuration/Storekit.storekit` — local sandbox products mirror

---

## 11. EULA + Privacy draft scope (V25 in-spec)

Claude tạo bilingual VI/EN content, **không** host. Operator host sau (api.../legal/eula.html hoặc czechgo.app/legal/eula).

### `docs/reference/legal-eula.md`

Boilerplate "Standard EULA" khung (Apple cung cấp template) + custom điều khoản:
- Subscription auto-renewal explicit
- Refund policy via Apple
- Acceptable use (không share account, không reverse-engineer)
- Termination conditions
- Liability cap
- Vietnam jurisdiction

### `docs/reference/legal-privacy.md`

GDPR + Vietnam PDPL aware:
- Data collected: email, learner content (transcripts, attempts, audio recordings), device info, IAP receipts
- Third-party processors: Apple (IAP, Sign-In), AWS (storage, SES, Polly), Anthropic (LLM scoring), ElevenLabs (interview voice), Replicate (image gen)
- Retention: account data until deletion request; learner content until account deletion; receipts 7 năm (kế toán)
- User rights: access, deletion (App Store guideline 5.1.1(v) compliant — already wired V17 §10), export
- Contact: support email TBD

Cả 2 file VI primary + EN section dưới. Hosted URL operator confirm.

---

## 12. Defer V25.1 list

Tạo `tasks/v25.1-iap-polish-todo.md` tracking, **không** start trong V25:

1. ASSN webhook JWS verifier — Apple public keys JWT verify, drop `IAP_WEBHOOK_SECRET` stopgap
2. `FindByOriginalTransactionID` + webhook activation upsert (cover offline-renewal path 100%)
3. Refund email notification user qua SES
4. Family Sharing — App Store Connect toggle + UI hint trong PaywallScreen
5. Apple Sign-In account merge — Profile screen "Liên kết Apple ID" cho user email cũ
6. Promotional offers / intro pricing / free trial — A/B framework

Estimate V25.1 ≈ 5-7 ngày sau khi V25 ship + có 100 conversion baseline.

---

## 13. Boundaries

### Always

- Persist mọi receipt/identity_token verification qua DB before flipping `pro_tier` hoặc minting session
- Idempotent verify endpoint — duplicate `apple_transaction_id` → 200 với existing expiry, không 409
- `notificationUUID` dedupe webhook (đã có V17, không regression)
- Dispose `purchaseStream` subscription cleanly trong app lifecycle
- `completePurchase()` mọi PurchaseDetails có `pendingCompletePurchase=true` (StoreKit yêu cầu để clear queue)
- Apple Sign-In nonce: SHA256 random ≥ 32 bytes, gửi raw lên backend, claim verify
- Disclosure block + Terms/Privacy luôn render (kể cả lúc loadProducts loading hoặc fail)
- Equal prominence Sign-in-with-Apple button + email signup CTA (4.8)
- `make verify` xanh trước khi merge

### Ask first

- Đổi pricing 99k/790k sang số khác
- Thêm 3rd party SDK (analytics, crash, A/B)
- Đổi auth_tokens TTL khác 90 ngày
- Đổi `apple_sub` thành PII non-pseudonymous identifier
- Bật ASSN JWS verifier sớm hơn V25.1 (yêu cầu thêm 5 ngày)
- Thêm Android Billing trong V25
- Custom EULA điều khoản nặng (jurisdiction, arbitration, etc.) — luật xem trước
- Tạo migration đụng chạm bảng đã có data prod (`pro_purchases`, `users`) — xác nhận shape trước

### Never

- Trust client `pro_tier` value — server-set only (V17 invariant)
- Skip Apple JWKS signature verify, dù dev mode
- Inline prompt strings / model IDs / fallback strings (V17 invariant — V25 không LLM nhưng giữ rule)
- Commit `IAP_WEBHOOK_SECRET` hoặc Apple `.p8` private key vào repo
- Lưu raw `identity_token` quá 1 request lifetime (verify rồi vứt)
- Render Sign-in-with-Apple button tự custom (Apple HIG cấm)
- Remove subscription disclosure block để paywall đẹp hơn (3.1.2(a) reject)
- Skip `completePurchase()` (StoreKit queue flood)
- Bypass `requireV17User` middleware trên `/v1/iap/apple/verify` (V17 invariant)
- Ship V25 thiếu `make verify` xanh
- Mix V25 với feature work khác (V21 backlog, V18 OCR, etc.) trong cùng PR
- Inline secret literals; tất cả secret qua env

---

## 14. Open risks

| Risk | Mitigation |
|---|---|
| Apple tax/banking xét > 14 ngày → block production launch | Sandbox + TestFlight không block; ship code, defer launch button. Operator submit ngay D0. |
| Sign-in-with-Apple "Hide my email" relay = `*@privaterelay.appleid.com` mất khi token migration → user lose email forever | Backend lưu relay nguyên xi vào `users.email`; document trong Privacy Policy "email có thể là relay từ Apple" |
| Apple JWKS rotate ngoài giờ làm việc → fail verify | `jwx/v2/jwk.NewCache` auto-refetch; thêm log + alert; fallback retry với refresh nếu `kid` không tìm thấy |
| User mua trong khi offline → StoreKit queue verify khi online → race với `purchaseStream` observer chưa start | Observer start trong `main.dart` post-`runApp` đảm bảo subscribe trước queue replay |
| `in_app_purchase: ^3.x` pubspec major bump phá API | Lock minor `^3.2.0`; CI dependency check |
| Reviewer reject vì disclosure copy không đủ rõ | Copy theo Apple template Subscription Information; test với reviewer ngôn ngữ EN + VI |
| Sandbox tester quota Apple Connect (max 100) | Đủ cho team test; promote production tester quota nếu beta scale |
| ASSN không deliver webhook → user pro nhưng không downgrade khi expired | Flutter observer gọi verify mỗi mở app → backend `expires_at` cập nhật → cron downgrade defer V25.1 |
| Apple Sign-In flow gặp Vietnam network MTU issue (như V14 ElevenLabs) | Reuse `dart:io HttpClient` config từ V17.2 avatar upload pattern |

---

## Approval

Spec này cần human ack trước khi sang `/agent-skills:plan` viết `tasks/v25-iap-wire-real-plan.md`. Sai chỗ nào hoặc cần điều chỉnh, comment trực tiếp vào file rồi ping.

Khi đã OK:
1. `/agent-skills:plan` — Phase A..E breakdown
2. `/agent-skills:build` — implement task-by-task
3. Sandbox + TestFlight test
4. CHANGELOG entry + SPEC.md digest row on ship
