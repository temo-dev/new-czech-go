# V25 IAP Wire Real — Todo

**Plan**: [v25-iap-wire-real-plan.md](v25-iap-wire-real-plan.md)
**Spec**: [docs/specs/iap-wire-real.md](../docs/specs/iap-wire-real.md)
**Status**: not started — chờ human approve plan

Backend total target +14 tests (654 → 668). Flutter +16 (309 → 325).

## Phase A — Backend Foundation

- [ ] **A1** Migration 028 `users.apple_sub` + `UserStore.UpsertByAppleSub`
  - Files: `backend/db/migrations/028_v25_user_apple_sub.sql` [NEW], `postgres_migrate.go` [MOD], `postgres_users.go` [MOD], `memory.go` [MOD], `postgres_users_test.go` [MOD]
  - Tests +2: `UpsertByAppleSub_NewUser`, `UpsertByAppleSub_Existing`
  - Verify: `make backend-test ARGS="-run UpsertByAppleSub"` + `make backend-build`
- [ ] **A2** Apple JWKS verifier `iap/apple_jwks.go`
  - Files: `internal/iap/apple_jwks.go` [NEW], `apple_jwks_test.go` [NEW], `go.mod` [MOD] +`lestrrat-go/jwx/v2`
  - Tests +2: `VerifyWithFixture`, `KeyRotation`
  - Verify: `make backend-test ARGS="-run AppleJWKS"`
- [ ] **A3** `ProPurchaseStore.FindByTransactionID`
  - Files: `postgres_pro_purchases.go` [MOD], `memory.go` [MOD], `postgres_pro_purchases_test.go` [MOD], `memory_test.go` [MOD]
  - Tests +2: hit + miss memory + postgres
  - Verify: `make backend-test ARGS="-run FindByTransactionID"`

### Checkpoint A
- [ ] `make backend-build` pass
- [ ] `make backend-test` pass (~660)
- [ ] go.mod chỉ thêm `lestrrat-go/jwx/v2`

## Phase B — Apple Sign-In endpoint

- [ ] **B1** `handleAuthApple` handler
  - Files: `httpapi/auth_handlers_apple.go` [NEW], `auth_handlers_apple_test.go` [NEW], `server.go` [MOD]
  - Tests +6: ValidToken_NewUser, ValidToken_ExistingUser, InvalidJWS, NonceMismatch, ExpiredToken, AudienceMismatch
  - Verify: `make backend-test ARGS="-run HandleAuthApple"`
- [ ] **B2** Route registration + integration smoke
  - Files: `auth_handlers.go` [MOD], `server_test.go` [MOD]
  - Tests +1: `Server_AuthApple_Integration`
  - Verify: `make backend-test ARGS="-run TestServer_AuthApple"` + `curl POST /v1/auth/apple` 400 body

### Checkpoint B
- [ ] `make backend-test` pass (~667)
- [ ] Endpoint reachable

## Phase C — Webhook downgrade stitch

- [ ] **C1** `applyWebhookExpiration` rewrite
  - Files: `httpapi/iap_handlers.go` [MOD], `iap_handlers_test.go` [MOD]
  - Tests +3: DowngradesUser, UnknownTxn_Logs, RefundReusesExpiration
  - Verify: `make backend-test ARGS="-run ApplyWebhook"` + manual mock ASSN POST EXPIRED

### Checkpoint C
- [ ] `make backend-test` pass (~668)
- [ ] Webhook EXPIRED → user downgrade flow tested

## Phase D — Flutter RealIAPService

- [ ] **D1** Pubspec + iOS entitlements
  - Files: `pubspec.yaml` [MOD] +`in_app_purchase: ^3.2.0` +`sign_in_with_apple: ^6.1.0`, `ios/Runner/Runner.entitlements` [MOD]
  - Verify: `flutter pub get && pod install && flutter build ios --debug --no-codesign` + `make flutter-analyze`
- [ ] **D2** `RealIAPService` impl
  - Files: `lib/core/iap/real_iap_service.dart` [NEW], `test/core/iap/real_iap_service_test.dart` [NEW]
  - Tests +5: loadProducts, buy_happy, buy_canceled, restore, error_propagation
  - Verify: `make flutter-test ARGS="--name=real_iap_service"` + `make flutter-analyze`
- [ ] **D3** `main.dart` wire + observer lifecycle
  - Files: `lib/main.dart` [MOD], app shell test [MOD nếu có]
  - Verify: build flag swap không break widget test; iOS simulator paywall không crash

### Checkpoint D
- [ ] `make flutter-analyze` pass
- [ ] `make flutter-test` pass (~314)
- [ ] iOS simulator build pass

## Phase E — Apple Sign-In UI

- [ ] **E1** `AuthService.signInWithApple` + `ApiClient.signInWithAppleV25`
  - Files: `lib/core/api/api_client.dart` [MOD], `lib/core/auth/auth_service.dart` [MOD], 2 test file [MOD]
  - Tests +3: happy, cancel, invalid_token
  - Verify: `make flutter-test ARGS="--name=auth_service|api_client"`
- [ ] **E2** `SignInWithAppleButton` trên 3 screen
  - Files: `welcome_screen.dart`, `login_screen.dart`, `signup_screen.dart` [MOD] + 3 test file [MOD]
  - Tests +3: 1 mỗi screen render + tap dispatch
  - Verify: `make flutter-test ARGS="--name=welcome_screen|login_screen|signup_screen"` + manual iOS simulator render

### Checkpoint E
- [ ] `make flutter-test` pass (~320)
- [ ] 3 screen render Apple button
- [ ] Manual iOS simulator: tap mở Apple sheet

## Phase F — Paywall compliance

- [ ] **F1** Disclosure block + Terms/Privacy buttons
  - Files: `paywall_screen.dart` [MOD], `paywall_screen_test.dart` [MOD], `lib/core/config/legal_urls.dart` [NEW]
  - Tests +2: disclosure_visible_when_loading, terms_tap_dispatch
  - Verify: `make flutter-test ARGS="--name=paywall_screen"` + manual disclosure render + terms tap external link

### Checkpoint F
- [ ] `make flutter-test` pass (~325)
- [ ] Disclosure luôn visible (cả lúc loading/error)
- [ ] EULA/Privacy mở external

## Phase G — Legal docs (parallel)

- [ ] **G1** EULA + Privacy VI/EN draft
  - Files: `docs/reference/legal-eula.md` [NEW], `docs/reference/legal-privacy.md` [NEW]
  - Verify: markdown render OK + operator review trước hosting
  - Cross-check Privacy declared data match V17 + V25 collection (kiểm code)

## Phase H — Sandbox + TestFlight (gate)

- [ ] **H1** StoreKit configuration file + sandbox smoke
  - Files: `flutter_app/ios/Configuration/Storekit.storekit` [NEW], scheme [MOD]
  - Verify: Xcode scheme link config + simulator buy → backend log verify call
- [ ] **H2** App Store Connect operator checklist
  - Operator (không code): tax/banking, products, group, localization, tester, privacy, EULA URL
  - Verify: operator confirm + 1 sandbox tester login → buy
- [ ] **H3** TestFlight build + beta review
  - Files: archive workflow + `CHANGELOG.md` [MOD] + `SPEC.md` [MOD] + `tasks/plan.md` index [MOD] + `tasks/todo.md` index [MOD]
  - Verify: TestFlight downloadable + Apple beta review pass + manual smoke 5 flow + `make verify` pass

### Checkpoint H — Ready to ship
- [ ] Backend test 668+
- [ ] Flutter test 325+
- [ ] CMS 144 (no change)
- [ ] `make verify` pass
- [ ] Sandbox smoke pass: SignIn email + Apple, Buy monthly + yearly, Restore, Expired downgrade
- [ ] TestFlight beta review = "Ready to Test"
- [ ] CHANGELOG entry + SPEC.md digest row updated

## Defer V25.1 (track riêng)

Tạo sau khi V25 ship:

- [ ] V25.1-1 ASSN webhook JWS verifier (Apple public keys JWT verify)
- [ ] V25.1-2 `FindByOriginalTransactionID` + webhook activation upsert
- [ ] V25.1-3 Refund email notification user qua SES
- [ ] V25.1-4 Family Sharing toggle App Store Connect + UI hint
- [ ] V25.1-5 Apple Sign-In account merge — Profile "Liên kết Apple ID" cho user email cũ

## Open questions trước start

- [ ] EULA + Privacy hosting URL — operator chốt trước F1 hoặc dùng placeholder
- [ ] StoreKit config file check-in repo hay gitignore?
- [ ] TestFlight beta tester list — team only hay external?
