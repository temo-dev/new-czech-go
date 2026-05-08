package httpapi

import (
	"net/http"
	"testing"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// TestApplyWebhookExpiration_DowngradesUser is the V25-C1 acceptance:
// when ASSN delivers EXPIRED for a known transaction, the matching
// user must have pro_tier flipped to "free". V17 only marked the row
// inactive and stopped — the user kept seeing Pro everywhere until
// they reopened the app and Flutter's purchaseStream re-verified.
func TestApplyWebhookExpiration_DowngradesUser(t *testing.T) {
	env := newAuthTestEnv(t)

	// Seed a real user with pro_tier="pro" + active purchase.
	user, err := env.users.CreateUser(contracts.UserAccount{
		Email:        "pro@y.com",
		PasswordHash: "$2a$12$hash",
		ProTier:      "pro",
	})
	if err != nil {
		t.Fatalf("create user: %v", err)
	}
	expires := time.Now().Add(30 * 24 * time.Hour)
	env.users.UpdateUser(user.ID, func(u *contracts.UserAccount) {
		u.ProTier = "pro"
		u.ProExpiresAt = &expires
	})
	if _, err := env.purchases.CreateProPurchase(contracts.ProPurchase{
		UserID:                     user.ID,
		AppleTransactionID:         "txn-v25-exp",
		AppleOriginalTransactionID: "orig-v25",
		ProductID:                  "eu.hadoo.czechgo.pro.monthly",
		PurchasedAt:                time.Now().Add(-29 * 24 * time.Hour),
		ExpiresAt:                  expires,
		ReceiptPayload:             []byte(`{}`),
	}); err != nil {
		t.Fatalf("seed purchase: %v", err)
	}

	payload := []byte(`{
		"notificationUUID":"uuid-V25-EXP",
		"notificationType":"EXPIRED",
		"data":{"transactionInfo":{"transactionId":"txn-v25-exp","originalTransactionId":"orig-v25","productId":"eu.hadoo.czechgo.pro.monthly","expiresDate":` + fmtMS(expires) + `}}
	}`)
	resp := postRaw(t, env.srv.URL+"/v1/iap/apple/webhook", payload)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusNoContent {
		t.Fatalf("expected 204, got %d", resp.StatusCode)
	}

	// Purchase must be inactive…
	if _, ok := env.purchases.ActiveProPurchaseByUser(user.ID); ok {
		t.Error("expected purchase marked inactive after EXPIRED")
	}
	// …AND the user's pro_tier must have flipped back to free without
	// requiring the Flutter client to refresh.
	got, ok := env.users.UserAccountByID(user.ID)
	if !ok {
		t.Fatalf("user not found post-webhook")
	}
	if got.ProTier != "free" {
		t.Errorf("expected pro_tier=free after EXPIRED webhook, got %q", got.ProTier)
	}
	if got.ProExpiresAt != nil {
		t.Errorf("expected pro_expires_at cleared after downgrade, got %v", got.ProExpiresAt)
	}
}

// TestApplyWebhookExpiration_UnknownTxn_Logs covers the graceful path
// when ASSN replays an EXPIRED for a transaction we never recorded.
// The handler must not crash, must return 204, and must not flip any
// user — this is a basic resilience smoke against malformed or
// out-of-order notifications.
func TestApplyWebhookExpiration_UnknownTxn_Logs(t *testing.T) {
	env := newAuthTestEnv(t)

	// Seed a Pro user whose purchase id is NOT the txn the webhook
	// references — guarantees that lookup misses.
	user, _ := env.users.CreateUser(contracts.UserAccount{
		Email:        "innocent@y.com",
		PasswordHash: "$2a$12$hash",
	})
	expires := time.Now().Add(30 * 24 * time.Hour)
	env.users.UpdateUser(user.ID, func(u *contracts.UserAccount) {
		u.ProTier = "pro"
		u.ProExpiresAt = &expires
	})

	payload := []byte(`{
		"notificationUUID":"uuid-V25-UNKNOWN",
		"notificationType":"EXPIRED",
		"data":{"transactionInfo":{"transactionId":"txn-does-not-exist","originalTransactionId":"orig-X","productId":"p","expiresDate":1717488000000}}
	}`)
	resp := postRaw(t, env.srv.URL+"/v1/iap/apple/webhook", payload)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusNoContent {
		t.Fatalf("expected 204 graceful no-op, got %d", resp.StatusCode)
	}

	// The unrelated Pro user must NOT be downgraded.
	got, _ := env.users.UserAccountByID(user.ID)
	if got.ProTier != "pro" {
		t.Errorf("unrelated user should remain pro, got %q", got.ProTier)
	}
}

// TestApplyWebhookRefund_ReusesExpirationPath asserts that REFUND
// flows through the same downgrade path EXPIRED uses. Apple's
// guidance is to treat a refund as an immediate revocation of
// entitlement.
func TestApplyWebhookRefund_ReusesExpirationPath(t *testing.T) {
	env := newAuthTestEnv(t)

	user, _ := env.users.CreateUser(contracts.UserAccount{
		Email:        "refund@y.com",
		PasswordHash: "$2a$12$hash",
	})
	expires := time.Now().Add(30 * 24 * time.Hour)
	env.users.UpdateUser(user.ID, func(u *contracts.UserAccount) {
		u.ProTier = "pro"
		u.ProExpiresAt = &expires
	})
	if _, err := env.purchases.CreateProPurchase(contracts.ProPurchase{
		UserID:                     user.ID,
		AppleTransactionID:         "txn-v25-refund",
		AppleOriginalTransactionID: "orig-v25-refund",
		ProductID:                  "eu.hadoo.czechgo.pro.monthly",
		PurchasedAt:                time.Now().Add(-1 * time.Hour),
		ExpiresAt:                  expires,
		ReceiptPayload:             []byte(`{}`),
	}); err != nil {
		t.Fatalf("seed purchase: %v", err)
	}

	payload := []byte(`{
		"notificationUUID":"uuid-V25-REFUND",
		"notificationType":"REFUND",
		"data":{"transactionInfo":{"transactionId":"txn-v25-refund","originalTransactionId":"orig-v25-refund","productId":"eu.hadoo.czechgo.pro.monthly","expiresDate":` + fmtMS(expires) + `}}
	}`)
	resp := postRaw(t, env.srv.URL+"/v1/iap/apple/webhook", payload)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusNoContent {
		t.Fatalf("expected 204, got %d", resp.StatusCode)
	}

	got, _ := env.users.UserAccountByID(user.ID)
	if got.ProTier != "free" {
		t.Errorf("expected pro_tier=free after REFUND webhook, got %q", got.ProTier)
	}
	if _, ok := env.purchases.ActiveProPurchaseByUser(user.ID); ok {
		t.Error("expected purchase marked inactive after REFUND")
	}
}
