# V25 IAP Wire Real — Todo

**Plan**: [v25-iap-wire-real-plan.md](v25-iap-wire-real-plan.md)
**Spec**: [docs/specs/iap-wire-real.md](../docs/specs/iap-wire-real.md)
**Status**: ✅ implemented Phase A-G + H1 (2026-05-08); H2 + H3
operator-side remain.

Backend final: **+23 tests** (822 → 845, exceeded +14 target).
Flutter final: **+22 V25 tests** (309 → 366 cumulative incl earlier
slices, exceeded +16 target).

## Phase A — Backend Foundation

- [x] **A1** Migration 028 `users.apple_sub` + `UserStore.UpsertByAppleSub`
  - Files: `backend/db/migrations/028_v25_user_apple_sub.sql` [NEW], `postgres_users.go` [MOD], `user_store.go` [MOD], `user_store_test.go` [MOD], `contracts/user_account.go` [MOD]
  - Tests +3: `UpsertByAppleSub_NewUser`, `UpsertByAppleSub_Idempotent`, `UpsertByAppleSub_EmptySubRejected`
- [x] **A2** Apple JWKS verifier `iap/apple_jwks.go`
  - Files: `internal/iap/apple_jwks.go` [NEW], `apple_jwks_test.go` [NEW], `go.mod` + `go.sum` [MOD] +`lestrrat-go/jwx/v2 v2.1.6` + transitive
  - Tests +4: `VerifyWithFixture`, `VerifyRejectsWrongAudience`, `VerifyRejectsExpiredToken`, `KeyRotation`
- [x] **A3** `ProPurchaseStore.FindByTransactionID`
  - Files: `pro_purchase_store.go` [MOD], `pro_purchase_store_test.go` [MOD]
  - Tests +2: `FindByTransactionID_Hit` (incl mark-inactive replay), `FindByTransactionID_Miss`

### Checkpoint A
- [x] `make backend-build` pass
- [x] `make backend-test` pass (831 after A)
- [x] go.mod thêm `lestrrat-go/jwx/v2` + transitive (blackmagic, httprc, iter, secp256k1, goccy/go-json, segmentio/asm)

## Phase B — Apple Sign-In endpoint

- [x] **B1** `handleAuthApple` handler
  - Files: `httpapi/auth_handlers_apple.go` [NEW], `auth_handlers_apple_test.go` [NEW], `server.go` [MOD], `iap_handlers.go` [MOD] (`AppleIdentityVerifier` alias)
  - Tests +10: ValidToken_NewUser, ValidToken_ExistingUser, InvalidJWS, NonceMismatch, ExpiredToken, AudienceMismatch, MissingFields (2 subtests), DisabledWhenNoVerifier
- [x] **B2** Route registration + integration smoke
  - Files: `auth_handlers.go` [MOD] (AuthDeps `+AppleJWKS` + applyTo + `registerAppleAuthRoute`)
  - Tests +1: `Server_AuthApple_Integration` (session token round-trip via /v1/users/me)

### Checkpoint B
- [x] `make backend-test` pass (842 after B)
- [x] Endpoint reachable; 404 when `appleJWKS=nil`

## Phase C — Webhook downgrade stitch

- [x] **C1** `applyWebhookExpiration` rewrite
  - Files: `iap_handlers.go` [MOD], `iap_webhook_v25_test.go` [NEW]
  - Tests +3: `DowngradesUser`, `UnknownTxn_Logs`, `RefundReusesExpirationPath`

### Checkpoint C
- [x] `make backend-test` pass (845)
- [x] Webhook EXPIRED → user downgrade flow tested end-to-end

## Phase D — Flutter RealIAPService

- [x] **D1** Pubspec + iOS entitlements
  - Files: `pubspec.yaml` [MOD] +`in_app_purchase: ^3.2.0` +`sign_in_with_apple: ^6.1.0` +`url_launcher: ^6.3.0` +`crypto: ^3.0.3`, `ios/Runner/Runner.entitlements` [NEW] (`com.apple.developer.applesignin = [Default]`), `ios/Runner.xcodeproj/project.pbxproj` [MOD] (`CODE_SIGN_ENTITLEMENTS` × 3 configs)
  - Verify: `flutter pub get` + `pod install` + `flutter build ios --debug --no-codesign` (11.8s) + `flutter analyze` clean
- [x] **D2** `RealIAPService` impl
  - Files: `lib/core/iap/real_iap_service.dart` [NEW], `test/real_iap_service_test.dart` [NEW]
  - Tests +7: loadProducts mapping, buy happy, buy canceled, buy error, restore cache, verify-throws still clears queue, start idempotent
- [x] **D3** `main.dart` wire + observer lifecycle
  - Files: `lib/main.dart` [MOD] (StatefulWidget, `kIapEnabled`, `_buildIAPService`), `lib/core/iap/iap_service_provider.dart` [NEW], `test/widget_test.dart` [MOD]
  - Tests +1: `default app wires IAPServiceProvider with StubIAPService`

### Checkpoint D
- [x] `make flutter-analyze` pass
- [x] `make flutter-test` pass (353 after D)
- [x] iOS simulator build pass; paywall không crash

## Phase E — Apple Sign-In UI

- [x] **E1** `AuthService.signInWithApple` + `ApiClient.signInWithAppleV25`
  - Files: `lib/core/api/api_client.dart` [MOD], `lib/core/auth/auth_service.dart` [MOD] (`AppleCredentialFn` typedef + nonce SHA256), `test/auth_service_test.dart` [MOD]
  - Tests +4: happy, cancel → `sign_in_canceled`, invalid_token surfaces backend code, missing identity_token → `invalid_credential`
- [x] **E2** `AppleSignInButton` trên 3 screen
  - Files: `lib/features/auth/widgets/apple_sign_in_button.dart` [NEW] (incl `OrDivider`), 3 screens [MOD], `test/auth_screens_test.dart` [MOD] (+5: render Welcome/Login/Signup, error inline, cancel silent)

### Checkpoint E
- [x] `make flutter-test` pass (362 after E)
- [x] 3 screen render Apple button (key `sign_in_with_apple_button`)
- [ ] Manual iOS simulator: tap mở Apple sheet (defer H1 smoke)

## Phase F — Paywall compliance + entry points

- [x] **F1** Disclosure block + Terms/Privacy buttons
  - Files: `paywall_screen.dart` [MOD] (`_SubscriptionDisclosure`, `_LegalLinksRow`, `PaywallUrlLauncher` typedef, `SingleChildScrollView`), `lib/core/config/legal_urls.dart` [NEW], `test/paywall_test.dart` [MOD]
  - Tests +2: disclosure visible while loading, Terms+Privacy dispatch external URLs
- [x] **F2** Wire upgrade entry points
  - Files: `profile_screen.dart` [MOD] (`_ProUpgradeTile`), `exercise_screen.dart` [MOD] (429 → `showForAttemptQuota`), `interview_session_screen.dart` [MOD] (429 → `showForInterviewQuota`), `course_list_screen.dart` [MOD] (`QuotaIndicator` mount + `_loadUsage`)
  - Tests +2: free user upgrade tile pushes paywall, pro user manage-subscription tile rendered

### Checkpoint F
- [x] `make flutter-test` pass (366 after F)
- [x] Disclosure luôn visible (cả lúc loading)
- [x] EULA/Privacy mở external (Terms + Privacy buttons keyed)
- [x] 4 upgrade entry points (Profile + Exercise 429 + Interview 429 + Home QuotaIndicator)

## Phase G — Legal docs (parallel)

- [x] **G1** EULA + Privacy VI/EN draft
  - Files: `docs/reference/legal-eula.md` [NEW] (245 lines, 14 sections), `docs/reference/legal-privacy.md` [NEW] (313 lines, 13 sections)
  - Cross-checked: declared data §3 matches `users.{email, password_hash, apple_sub, …}`, `pro_purchases.{transaction_id, …, receipt_payload}`, `attempts`/`feedback`, `auth_tokens.{user_agent, ip_address}`, `daily_usage`. Sub-processors: Apple, Anthropic (US), AWS Polly+Transcribe+S3+SES (Singapore/Frankfurt), ElevenLabs (US), Replicate (US — no user data).
  - Operator TBD: legal owner name + DPO email + EULA/Privacy hosting URL.

## Phase H — Sandbox + TestFlight (gate)

- [x] **H1** StoreKit configuration file + sandbox smoke playbook
  - Files: `flutter_app/ios/Configuration/CzechGoPro.storekit` [NEW] (monthly 99k + yearly 790k VND in Subscription Group "Czech Go Pro" id `21565432`), `Runner.xcscheme` [MOD] (`<StoreKitConfigurationFileReference>`), `docs/guides/v25-iap-sandbox-smoke.md` [NEW] (7-step playbook)
- [ ] **H2** App Store Connect operator checklist
  - Operator (không code): tax/banking + Paid Apps Agreement, products `eu.hadoo.czechgo.pro.{monthly, yearly}`, Subscription Group "Czech Go Pro", VI + EN localization, sandbox tester ≥ 2 (1 VN + 1 cross-currency), App Privacy declarations match `legal-privacy.md` §3, EULA + Privacy hosting URL set
- [ ] **H3** TestFlight build + beta review
  - Files: archive workflow (Xcode Distribute → App Store Connect), confirm `LegalUrls` const points to operator-confirmed hosting before submit
  - Verify: TestFlight build downloadable + Apple beta review pass + manual smoke 5 flow on iPhone thật (sign-in email + Apple, buy monthly + yearly, restore, cancel via Settings + accelerate expire, ASSN webhook downgrade)

### Checkpoint H — Ready to ship
- [x] Backend test 845 (target ≥668)
- [x] Flutter test 366 (target ≥325)
- [x] CMS 144 (no change)
- [x] `make verify` xanh (backend + flutter; iOS build 11.8s)
- [ ] Sandbox smoke pass: 5 flows (gate H1 H2 manual)
- [ ] TestFlight beta review = "Ready to Test" (gate H3)
- [x] CHANGELOG entry + SPEC.md digest row + tasks/{plan, todo}.md updated (2026-05-08)

## Defer V25.1 (track riêng)

Tạo sau khi V25 ship + có 100 conversion baseline:

- [ ] V25.1-1 ASSN webhook JWS verifier (Apple public keys JWT verify)
- [ ] V25.1-2 `FindByOriginalTransactionID` + webhook activation upsert
- [ ] V25.1-3 Refund email notification user qua SES
- [ ] V25.1-4 Family Sharing toggle App Store Connect + UI hint
- [ ] V25.1-5 Apple Sign-In account merge — Profile "Liên kết Apple ID" cho user email cũ

## Open questions resolved during implementation

- ~~EULA + Privacy hosting URL~~ → placeholder `czechgo.hadoo.eu/legal/{eula,privacy}` trong `LegalUrls` const; operator chốt before TestFlight submit (H2 / H3)
- ~~StoreKit config file check-in~~ → committed (sandbox local dev); chứa product IDs công khai + price tiers, không sensitive
- ~~TestFlight beta tester list~~ → defer H3 — operator chọn team-only vs external (Apple beta review duyệt nhanh team, external 1-2 ngày)
