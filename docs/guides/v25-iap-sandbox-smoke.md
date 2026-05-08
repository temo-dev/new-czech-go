# V25 IAP — Sandbox smoke test guide

Audience: operator + dev preparing the V25 ship gate.
Spec: [`docs/specs/iap-wire-real.md`](../specs/iap-wire-real.md).
Plan reference: V25 task **H1**.

This is the sandbox-only path. App Store Connect / TestFlight steps
are tracked separately in V25 tasks H2 / H3.

---

## What this guide covers

Local sandbox testing using the **StoreKit Configuration file** at
`flutter_app/ios/Configuration/CzechGoPro.storekit`. The config
mirrors App Store Connect products (`eu.hadoo.czechgo.pro.monthly`
+ `.yearly`) so the simulator can drive a Buy flow without a sandbox
tester or signed Paid Apps Agreement.

## Prerequisites

- Xcode 15+ (StoreKit configuration files).
- iPhone simulator running iOS 16+.
- Backend reachable from the simulator. Default for dev is
  `make dev-backend` on `127.0.0.1:8080`. The simulator can reach
  the host via `127.0.0.1` directly — unlike a physical device, no
  bridge IP needed.
- `kIapEnabled` left at default (`true`) and `kUseV17Auth` enabled.
  Run flag:
  ```
  --dart-define=USE_V17_AUTH=true --dart-define=IAP_ENABLED=true
  ```

## Step 0 — Verify the scheme references the StoreKit config

Open the project in Xcode:
```bash
open flutter_app/ios/Runner.xcworkspace
```

Edit Scheme → **Run** → **Options** → **StoreKit Configuration**.
The dropdown should show `CzechGoPro.storekit`. If it says **None**,
the H1 scheme edit did not stick — re-apply or pick the file
manually from `ios/Configuration/CzechGoPro.storekit`.

> If the file appears with a red name in the Navigator, drag-add it
> to the project (uncheck "Copy items if needed"). The scheme
> reference works without it but the Navigator preview is more
> friendly when the file is registered.

## Step 1 — Run the app from Xcode against the simulator

```bash
cd flutter_app
flutter run -d <iphone-simulator-id> \
  --dart-define=USE_V17_AUTH=true \
  --dart-define=IAP_ENABLED=true
```

Watch the log for:
```
RealIAPService: started observer
```

(If you see `StubIAPService` instead, `kIapEnabled` is false or
`Platform.isIOS` is false — confirm the build flag.)

## Step 2 — Sign in

Sign in via email or Apple Sign-In. Apple Sign-In on the simulator
requires the simulator to be signed in to an Apple ID — easier to
test the email path first.

## Step 3 — Trigger the paywall

Either:
- Burn the free quota: hit `/v1/attempts/start` 7 times → free-tier
  gate raises `attempts_quota_exceeded` → upgrade prompt.
- Or hit Profile → Pro upsell directly.

The PaywallScreen mounts and calls `loadProducts()`.

**Expected:** the two product tiles render with **99.000 ₫ / tháng**
and **790.000 ₫ / năm**. If you see a spinner forever, StoreKit did
not pick up the config — recheck Step 0.

## Step 4 — Buy monthly

Tap **Pro hàng tháng** → tap **Nâng cấp Pro**.

The simulator shows the StoreKit confirmation sheet. Approve with
the simulator's "Confirm" (no Face ID needed).

The `purchaseStream` observer in `RealIAPService` fires with
`PurchaseStatus.purchased`. The service:
1. POSTs `/v1/iap/apple/verify` with the receipt.
2. Backend Apple-verifies → records `pro_purchases` row → flips
   `users.pro_tier='pro'`.
3. `AuthService.refresh()` reloads `/v1/users/me` → home/profile
   re-renders with Pro badge.
4. `completePurchase()` clears the StoreKit transaction queue.

**Verify backend log:**
```
iap-verify: persist purchase: ...
applyProEntitlement: user_id=u_... product=eu.hadoo.czechgo.pro.monthly
```

**Verify DB:**
```sql
SELECT user_id, apple_transaction_id, product_id, expires_at, is_active
  FROM pro_purchases ORDER BY created_at DESC LIMIT 1;
SELECT id, email, pro_tier, pro_expires_at FROM users WHERE pro_tier='pro';
```
Both rows should be present and `is_active=true`.

## Step 5 — Restore flow

Background the app → kill it → reopen → navigate back to PaywallScreen.

Tap **Khôi phục giao dịch trước**. The observer re-receives the
purchase as `PurchaseStatus.restored`, fires verify again
(idempotent — the duplicate `apple_transaction_id` returns 200 with
the existing entitlement), and routes to `ProSuccessScreen`.

## Step 6 — Cancel via Settings → simulate expire

In the simulator: **Settings → App Store → Sandbox Account →
Manage Subscriptions → Czech Go Pro → Cancel**.

Then accelerate time: **Xcode → Debug → StoreKit → Time Rate**.
Subscriptions in the .storekit config use renewal periods; use the
**Process Pending Transactions** option to push an EXPIRED event.

The ASSN webhook is NOT delivered locally (it would come from Apple
in production). To smoke the V25-C1 downgrade stitch, post a hand
crafted ASSN payload directly:

```bash
curl -X POST http://127.0.0.1:8080/v1/iap/apple/webhook \
  -H 'Content-Type: application/json' \
  -H 'X-Czechgo-Webhook-Secret: $IAP_WEBHOOK_SECRET' \
  -d '{
    "notificationUUID":"smoke-EXP-1",
    "notificationType":"EXPIRED",
    "data":{"transactionInfo":{
      "transactionId":"<txn from step 4>",
      "originalTransactionId":"...",
      "productId":"eu.hadoo.czechgo.pro.monthly",
      "expiresDate": <epoch ms>
    }}
  }'
```

Backend logs `applyWebhookExpiration` → `downgradeIfExpired(user_id)`.
Re-query `users.pro_tier` — should now be `'free'`.

## Step 7 — Buy yearly + product switch

Tap **Pro hàng năm** → confirm. The Subscription Group "Czech Go
Pro" allows upgrade/downgrade between products. Verify a second row
in `pro_purchases` with `apple_original_transaction_id` matching the
monthly transaction (they share the same Apple group).

## Smoke pass criteria

- [ ] `RealIAPService.started` log on app launch (iOS only)
- [ ] `loadProducts()` returns 2 products with VND prices
- [ ] Buy monthly → `pro_purchases` row + `users.pro_tier='pro'`
      + `ProSuccessScreen` rendered
- [ ] Restore → no duplicate row, same entitlement returned
- [ ] Cancel via Settings + handcrafted EXPIRED → `users.pro_tier='free'`
      auto via webhook stitch (V25-C1)
- [ ] Buy yearly within same group → second row + Pro extended

## Pitfalls

| Symptom | Likely cause |
|---|---|
| Loader hangs in PaywallScreen | StoreKit config not selected in Run scheme. Re-pick in Edit Scheme. |
| `RealIAPService` fails verify with 401 | Session token missing — sign-in flow did not run. |
| Webhook returns 401 | `IAP_WEBHOOK_SECRET` env mismatch between server + curl. |
| `apple_disabled` 503 | Backend `appleVerifier` is nil. Confirm `iap.HTTPAppleVerifier` wired in dev bootstrap. |
| Simulator buy succeeds but verify fails | The simulator-side StoreKit config receipt is a development one. Backend must run in dev mode (`ENV != production`) so the verify endpoint accepts non-prod receipts. |

## See also

- V25 spec: [`docs/specs/iap-wire-real.md`](../specs/iap-wire-real.md)
- V25 plan: [`tasks/v25-iap-wire-real-plan.md`](../../tasks/v25-iap-wire-real-plan.md)
- Existing smoke playbook: [`smoke-test-guide.md`](smoke-test-guide.md)
