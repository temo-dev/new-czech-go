# IAP Wire Real (V25) — Idea Refine

**Status:** Refined → ready for `/agent-skills:spec`
**Date:** 2026-05-08
**Spec:** `docs/specs/iap-wire-real.md` (TBD)
**Plan:** `tasks/v25-iap-wire-real-plan.md` (TBD)

---

## Problem Statement (How Might We)

**Làm sao để chuyển paywall A2 Mluvení từ stub sang StoreKit thật, đóng các V18-polish item backend đủ để webhook không còn no-op, và không bị App Store reject — trong 9-11 ngày làm việc, song song với 1-2 tuần Apple xét tax/banking?**

V17 đã ship nửa hệ thống: backend `/v1/iap/apple/verify` + `/webhook` + `pro_purchases` table chạy đầy đủ; Flutter chỉ có `StubIAPService` ném `not_implemented` trên Buy. PaywallScreen UI hoàn chỉnh nhưng thiếu 3 disclosure bắt buộc cho App Store guideline 3.1.2(a).

---

## Recommended Direction — V25 = V2 + V5

**V2 (Boring + downgrade stitch)** + **V5 (Sign-in with Apple)**.

**Thứ tự thi công:**
1. **V2 core** (5-7 ngày) — Flutter `RealIAPService` qua `in_app_purchase: ^3.x`, `purchaseStream` observer fire `/v1/iap/apple/verify`, backend bổ sung `ProPurchaseStore.FindByTransactionID(txn) -> user_id` để `applyWebhookExpiration` gọi `downgradeIfExpired(userID)` thật.
2. **V5 Sign-in with Apple** (3-4 ngày) — `sign_in_with_apple` Flutter package; `POST /v1/auth/apple` backend handler verify identity_token JWS qua Apple JWKS, upsert user theo Apple `sub`, mint session token. Bắt buộc theo App Store guideline 4.8.
3. **Sandbox + TestFlight polish** (2-3 ngày) — `StoreKit.configuration` cho test, sandbox tester flow, paywall disclosure block + EULA/Privacy links, Apple HIG asset compliance, TestFlight beta review.

**Defer V18 polish:** ASSN JWS verifier (giữ `IAP_WEBHOOK_SECRET` + IP allowlist stopgap), `FindByOriginalTransactionID` cho webhook activation upsert (Flutter observer đã cover renewal path 80% case). → V25.1.

**Defer Android:** Match V17 spec; iOS-only V25. Kiến trúc `IAPService` abstract đã sẵn, V26 wire `purchases_flutter` hoặc native Google Billing không động backend.

---

## Key Assumptions to Validate

- [ ] **Apple tax/banking xét xong < 14 ngày** — Test: submit ngày D0, theo dõi App Store Connect. Nếu > 14 ngày → ship code, defer launch ngày, không block Sandbox/TestFlight.
- [ ] **`in_app_purchase: ^3.x` Flutter package đủ stable cho VND auto-renewable subscription** — Test: chạy sandbox tester với product `eu.hadoo.czechgo.pro.monthly` trong tuần 1 trên iPhone thật.
- [ ] **Backend `/v1/iap/apple/verify` đã wire đúng StoreKit 2 receipt format** — Test: 1 sandbox purchase end-to-end, kiểm `pro_purchases` row + `users.pro_tier='pro'` trong DB.
- [ ] **`sign_in_with_apple` package + Apple JWKS verify path không ăn dependency lớn** — Test: verify identity_token với `golang-jwt` + Apple `auth.apple.com/keys` JWKS endpoint, ít nhất 1 unit test với fixed JWKS fixture.
- [ ] **PaywallScreen disclosure block đủ cho reviewer** — Test: nội dung chuẩn theo Apple guideline 3.1.2(a) (auto-renewal text, billing point, manage cancellation hint), EULA + privacy_url accessible, render trên iPhone SE width 375.

---

## MVP Scope

**In V25:**

Backend
- `ProPurchaseStore.FindByTransactionID(string) (ProPurchase, bool)` + Postgres + memory impl + 2 tests
- `applyWebhookExpiration` upgrade: lookup user_id rồi `downgradeIfExpired`
- `applyWebhookRefund` reuse expiration path (đã có)
- New: `POST /v1/auth/apple` handler — verify Apple identity_token JWS via JWKS, upsert `users` by Apple `sub`, mint session token, set `email_verified=true` (Apple đã verify)
- Migration 027: thêm `users.apple_sub` unique nullable column
- 6-8 backend tests

Flutter
- `pubspec.yaml`: add `in_app_purchase: ^3.2.0` + `sign_in_with_apple: ^6.x`
- `lib/core/iap/real_iap_service.dart`: production impl 3 method, owns `purchaseStream` observer, calls verify endpoint, completes transactions
- `main.dart` wire: `RealIAPService` thay `StubIAPService` trên iOS production builds (build flag giữ stub cho widget tests)
- `PaywallScreen` deltas: disclosure block (auto-renewal text), Terms + Privacy text-button row, asset compliance check
- `WelcomeScreen` + `LoginScreen` + `SignupScreen`: chèn `SignInWithAppleButton` (Apple-style asset, equal prominence) + `AuthService.signInWithApple(...)` flow
- `ApiClient.signInWithAppleV25(identityToken, authCode, nonce)` method
- 8-10 widget/unit tests

App Store Connect (operator, không code)
- Tax + banking submit (parallel, không block code)
- 2 sandbox tester accounts
- EULA URL + Privacy Policy URL trong app metadata
- StoreKit configuration file cho local test

**Out V25 (defer V25.1+):**
- ASSN JWS verifier (Apple public keys JWT verify)
- `FindByOriginalTransactionID` + webhook activation upsert
- Android Billing
- Promotional offers / intro pricing / Family Sharing
- Refund email notification user

---

## Not Doing (and Why)

- **RevenueCat** — Đảo ngược V17 backend đã ship + 12 backend test. Vendor lock + 1% revenue MTR > $10K. Boring StoreKit đủ cho launch iOS-only.
- **JWS verify ASSN webhook trong V25** — Flutter `purchaseStream` observer cover 80% renewal flow. Shared-secret + IP allowlist là stopgap Apple chấp nhận. Defer V25.1 5 ngày.
- **Android Billing** — Match V17 scope. Abstract `IAPService` đã sẵn. Tránh slice phình.
- **Web learner UI / Stripe** — Khác sản phẩm hoàn toàn. Defer V27+.
- **Promotional offers, intro pricing, free trial** — Test 2 tier giá thuần trước, A/B sau khi có baseline conversion.
- **Refund email** — Defer V25.1 cùng webhook polish.
- **Migration tới StoreKit 2 native API thay vì receipt-based** — `in_app_purchase` package đã wrap StoreKit 2 transparent; trực tiếp StoreKit 2 đòi platform channel custom. Boring path đủ.

---

## Open Questions

- **EULA + Privacy URL** — Đã có sẵn URL chưa? Nếu chưa, ai viết? (Marketing? Legal?) Bắt buộc trước TestFlight submit.
- **Pricing 99k/990k chốt cuối cùng?** — App Store Connect product hiện đặt giá nào? Có cần điều chỉnh tier (Apple Pricing Tier 19 ≈ 99k VND)?
- **`pro_purchases.expires_at` xử lý gia hạn như nào trong DB?** — Tạo row mới mỗi renewal hay update row cũ? Code hiện tạo mới (migration 023 — confirm).
- **Sign-in with Apple — học viên cũ đã đăng ký bằng email có cần migration path?** — Flow link Apple ID vào account email cũ qua Profile screen? Hay Apple Sign-In tạo account riêng (rủi ro duplicate)?
- **Sandbox tester gia đình hoặc tài khoản dùng chung được không?** — Cần ≥1 tester với region VN để test giá VND label, ≥1 tester region khác để cross-currency check.
- **Khi tax/banking Apple xét > 14 ngày, có ship TestFlight không?** — TestFlight không cần Paid Apps Agreement; có thể bê toàn flow vào sandbox + TestFlight beta tester miễn phí, chỉ chờ tax/banking để bật launch button.
