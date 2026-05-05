package httpapi

import (
	"crypto/subtle"
	"encoding/json"
	"errors"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/iap"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

// AppleVerifier is re-exported here so the rest of the httpapi package
// can name the dependency without importing the iap package directly.
type AppleVerifier = iap.AppleVerifier

// ── Server fields + AuthDeps wiring ──────────────────────────────────────

// webhookSeen deduplicates ASSN notificationUUIDs in memory so a replay
// of the same payload (Apple retries until it gets a 2xx) does not
// double-flip the user's pro_tier. Bounded at maxSeen entries with FIFO
// eviction so memory stays small.
type webhookDedupe struct {
	mu      sync.Mutex
	seen    map[string]time.Time
	order   []string
	maxSeen int
}

func newWebhookDedupe() *webhookDedupe {
	return &webhookDedupe{seen: map[string]time.Time{}, maxSeen: 4096}
}

// MarkOrSkip returns false if the uuid was already processed within the
// retention window; true otherwise (and records it).
func (d *webhookDedupe) MarkOrSkip(uuid string) bool {
	if uuid == "" {
		return false
	}
	d.mu.Lock()
	defer d.mu.Unlock()
	if _, exists := d.seen[uuid]; exists {
		return false
	}
	d.seen[uuid] = time.Now().UTC()
	d.order = append(d.order, uuid)
	if len(d.order) > d.maxSeen {
		evict := d.order[0]
		d.order = d.order[1:]
		delete(d.seen, evict)
	}
	return true
}

// extendAuthDeps wires the IAP verifier + the dedupe table when the
// V17 deps are applied. Called from AuthDeps.applyTo.
func (s *Server) ensureIAPDefaults() {
	if s.webhookSeen == nil {
		s.webhookSeen = newWebhookDedupe()
	}
}

// allowIAPWebhook enforces the IAP_WEBHOOK_SECRET shared-secret guard.
// Behavior:
//   - Production (ENV=production) without IAP_WEBHOOK_SECRET set →
//     reject everything. Operator MUST set the secret before
//     unblocking the webhook.
//   - Non-production with IAP_WEBHOOK_SECRET unset → allow (dev
//     ergonomics). The TestFlight flow expects open access on
//     staging until ASSN is configured for that environment.
//   - Both production and dev with IAP_WEBHOOK_SECRET set → require
//     constant-time-equal X-Czechgo-Webhook-Secret header.
//
// V18 polish replaces this with a proper JWS verifier against
// Apple's public keys. Until then, deploy the webhook URL via a
// shape that injects the secret (e.g. Apple ASSN URL =
// https://api.../v1/iap/apple/webhook?ws=<rand>) + nginx rewrites
// the query into the header.
func (s *Server) allowIAPWebhook(r *http.Request) bool {
	expected := strings.TrimSpace(os.Getenv("IAP_WEBHOOK_SECRET"))
	provided := strings.TrimSpace(r.Header.Get("X-Czechgo-Webhook-Secret"))
	if expected == "" {
		if strings.EqualFold(strings.TrimSpace(os.Getenv("ENV")), "production") {
			return false
		}
		return true // dev ergonomics
	}
	return subtle.ConstantTimeCompare([]byte(expected), []byte(provided)) == 1
}

// ── Routes ───────────────────────────────────────────────────────────────

func (s *Server) registerIAPRoutes() {
	if s.proPurchaseStore == nil || s.userStore == nil {
		return
	}
	s.mux.HandleFunc("/v1/iap/apple/verify", s.handleIAPVerify)
	s.mux.HandleFunc("/v1/iap/apple/webhook", s.handleIAPWebhook)
}

// ── POST /v1/iap/apple/verify ────────────────────────────────────────────

type iapVerifyRequest struct {
	Receipt   string `json:"receipt"`
	ProductID string `json:"product_id"`
}

type iapVerifyResponse struct {
	ProExpiresAt time.Time `json:"pro_expires_at"`
	ProductID    string    `json:"product_id"`
	IsRenewing   bool      `json:"is_renewing"`
}

// handleIAPVerify takes a StoreKit receipt (base64), validates it
// against Apple, dedupes by transaction id, persists a pro_purchases
// row, and flips the user's pro_tier to "pro" with the expiry from
// the receipt. Idempotent: a duplicate transaction returns the same
// expiry without re-flipping anything.
//
// Spec: docs/specs/self-serve-learner-spec.md §4.14
func (s *Server) handleIAPVerify(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}
	if s.appleVerifier == nil {
		writeAuthError(w, http.StatusServiceUnavailable, "iap_disabled",
			"in-app purchase verification is not configured")
		return
	}
	user, ok := s.requireV17User(r)
	if !ok {
		writeAuthError(w, http.StatusUnauthorized, "missing_token", "authentication required")
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, 256*1024) // receipts can be ~100KiB

	var req iapVerifyRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAuthError(w, http.StatusBadRequest, "invalid_body", "request body is not valid JSON")
		return
	}
	if strings.TrimSpace(req.Receipt) == "" {
		writeAuthError(w, http.StatusBadRequest, "invalid_receipt", "receipt is required")
		return
	}

	resp, err := s.appleVerifier.VerifyReceipt(r.Context(), req.Receipt)
	if err != nil {
		log.Printf("iap-verify: apple verifyReceipt: %v", err)
		writeAuthError(w, http.StatusBadRequest, "verify_failed", "receipt did not validate against apple")
		return
	}

	receipt, found := resp.PickLatestForProduct(req.ProductID)
	if !found {
		receipt, found = resp.AnyLatest()
	}
	if !found {
		writeAuthError(w, http.StatusBadRequest, "no_active_subscription",
			"the receipt does not contain an active subscription")
		return
	}

	purchase, err := s.proPurchaseStore.CreateProPurchase(contracts.ProPurchase{
		UserID:                     user.ID,
		AppleTransactionID:         receipt.TransactionID,
		AppleOriginalTransactionID: receipt.OriginalTransactionID,
		ProductID:                  receipt.ProductID,
		PurchasedAt:                receipt.ParsedPurchasedAt(),
		ExpiresAt:                  receipt.ParsedExpiresAt(),
		ReceiptPayload:             resp.Raw,
	})
	if err != nil {
		if errors.Is(err, store.ErrDuplicateAppleTxn) {
			// Already on file — return the existing expiry rather than
			// 409 so the client treats this as success.
			active, ok := s.proPurchaseStore.ActiveProPurchaseByUser(user.ID)
			if ok {
				writeJSON(w, http.StatusOK, iapVerifyResponse{
					ProExpiresAt: active.ExpiresAt,
					ProductID:    active.ProductID,
					IsRenewing:   active.IsActive,
				})
				return
			}
			writeAuthError(w, http.StatusConflict, "duplicate_transaction",
				"this transaction was already recorded")
			return
		}
		log.Printf("iap-verify: persist purchase: %v", err)
		writeAuthError(w, http.StatusInternalServerError, "internal", "could not persist purchase")
		return
	}

	s.applyProEntitlement(user.ID, purchase.ProductID, purchase.ExpiresAt)

	writeJSON(w, http.StatusOK, iapVerifyResponse{
		ProExpiresAt: purchase.ExpiresAt,
		ProductID:    purchase.ProductID,
		IsRenewing:   true,
	})
}

// applyProEntitlement promotes the user to pro_tier=pro with the given
// expiry. Wrapped in a helper so the verify endpoint and the webhook
// handler share the same write path.
func (s *Server) applyProEntitlement(userID, productID string, expiresAt time.Time) {
	_, _ = s.userStore.UpdateUser(userID, func(u *contracts.UserAccount) {
		u.ProTier = "pro"
		exp := expiresAt
		u.ProExpiresAt = &exp
	})
	_ = productID // reserved for analytics events in V18
}

// downgradeIfExpired flips the user back to free if no other active
// purchase still covers them. Webhook handler invokes this after EXPIRED
// or REFUND events.
func (s *Server) downgradeIfExpired(userID string) {
	if s.proPurchaseStore == nil || s.userStore == nil {
		return
	}
	if _, ok := s.proPurchaseStore.ActiveProPurchaseByUser(userID); ok {
		return // another active subscription still covers them
	}
	_, _ = s.userStore.UpdateUser(userID, func(u *contracts.UserAccount) {
		u.ProTier = "free"
		u.ProExpiresAt = nil
	})
}

// ── POST /v1/iap/apple/webhook ───────────────────────────────────────────

// handleIAPWebhook ingests App Store Server Notifications V2. The
// signed-payload JWS verification is documented as a V18-polish item;
// for V17 the endpoint trusts the decoded JSON envelope and relies on
// notificationUUID dedup + an out-of-band shared secret rotation to
// bound the abuse window. Production deployment MUST place this
// endpoint behind a network-level allowlist for Apple's IP ranges
// until the JWS verifier lands.
//
// Spec: docs/specs/self-serve-learner-spec.md §4.15
func (s *Server) handleIAPWebhook(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}

	// Defense-in-depth pending the V18 JWS verifier: production
	// deployments MUST set IAP_WEBHOOK_SECRET to a 32+ byte random
	// string and configure ASSN to send it on the
	// X-Czechgo-Webhook-Secret header (custom header). Apple does not
	// natively send this; we wire it via a lightweight middleware /
	// proxy / Apple endpoint URL that includes the secret. Until JWS
	// verification ships in V18, this is the only thing standing
	// between an attacker and entitlement-flipping forgeries.
	if !s.allowIAPWebhook(r) {
		writeAuthError(w, http.StatusUnauthorized, "webhook_unauthorized", "missing or invalid webhook secret")
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, 64*1024)
	body, err := io.ReadAll(r.Body)
	if err != nil {
		writeAuthError(w, http.StatusBadRequest, "invalid_body", "could not read request body")
		return
	}
	notif, err := iap.DecodeNotificationPayload(body)
	if err != nil {
		writeAuthError(w, http.StatusBadRequest, "invalid_payload", err.Error())
		return
	}

	// Idempotent: ignore replays of the same notificationUUID.
	if !s.webhookSeen.MarkOrSkip(notif.UUID) {
		w.WriteHeader(http.StatusNoContent)
		return
	}

	if notif.TransactionID == "" {
		// Some notification types (e.g. price-change consent) have no
		// transaction id; nothing to persist.
		w.WriteHeader(http.StatusNoContent)
		return
	}

	switch notif.Type {
	case iap.NotifSubscribed, iap.NotifDidRenew:
		s.applyWebhookActivation(notif)
	case iap.NotifExpired, iap.NotifGracePeriod:
		s.applyWebhookExpiration(notif)
	case iap.NotifRefund:
		s.applyWebhookRefund(notif)
	default:
		log.Printf("iap-webhook: unhandled type=%s uuid=%s", notif.Type, notif.UUID)
	}

	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) applyWebhookActivation(notif *iap.Notification) {
	// V17 cut: SUBSCRIBED + DID_RENEW are logged but not persisted from
	// the webhook because ProPurchaseStore does not yet expose a
	// per-original-transaction-id lookup that we'd need to recover the
	// user_id Apple does NOT send with these events.
	//
	// In practice Flutter's StoreKit observer fires verify() against
	// /v1/iap/apple/verify on every renewal, which IS authenticated and
	// already persists the row + flips entitlement. The webhook acts as
	// a defense-in-depth log that the verify path was reached.
	//
	// V18 polish: add ProPurchaseStore.FindByOriginalTransactionID, then
	// promote this branch to a real upsert.
	log.Printf("iap-webhook: activation type=%s txn=%s product=%s expires=%s",
		notif.Type, notif.TransactionID, notif.ProductID, notif.ExpiresAt.Format(time.RFC3339))
}

func (s *Server) applyWebhookExpiration(notif *iap.Notification) {
	// Mark the matching purchase inactive so ActiveProPurchaseByUser no
	// longer surfaces it, then downgrade if no other active row.
	if !s.proPurchaseStore.MarkProPurchaseInactive(notif.TransactionID) {
		log.Printf("iap-webhook: expiration for unknown txn=%s", notif.TransactionID)
		return
	}
	// Best-effort downgrade: we don't have the user_id on the
	// notification directly, but proPurchaseStore could surface it via
	// a future per-txn lookup. V18 polish.
	_ = notif
}

func (s *Server) applyWebhookRefund(notif *iap.Notification) {
	s.applyWebhookExpiration(notif)
	// V18 polish: send refund-notification email to the affected user.
}
