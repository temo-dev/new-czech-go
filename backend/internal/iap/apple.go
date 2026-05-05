// Package iap (in-app purchase) wraps the Apple StoreKit verifyReceipt
// + App Store Server Notifications V2 surface the V17 self-serve
// learner flow uses to monetize the Pro tier.
//
// The transport-level details are deliberately small: a single
// AppleVerifier interface + an HTTP implementation that callers swap
// for a fake in tests. The handlers in httpapi/iap_handlers.go own the
// idempotency + persistence concerns.
package iap

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// AppleVerifier abstracts the verifyReceipt endpoint so handlers can be
// tested without hitting Apple. The real HTTP path lives in
// HTTPAppleVerifier; a recording fake suitable for tests lives in
// FakeAppleVerifier.
type AppleVerifier interface {
	VerifyReceipt(ctx context.Context, receipt string) (*VerifyReceiptResponse, error)
}

// VerifyReceiptResponse captures the subset of Apple's response the V17
// flow actually consumes: the most recent in-app entry per
// (originalTransactionId, productId) tuple plus the bundle id used for
// the cross-check. Full payload is JSONB-stored alongside in
// pro_purchases.receipt_payload for audit.
type VerifyReceiptResponse struct {
	Status   int       `json:"status"`
	BundleID string    `json:"bundle_id"`
	Latest   []Receipt `json:"latest_receipt_info"`
	Raw      []byte    `json:"-"`
}

// Receipt is a single in-app transaction line item. Apple sends times
// as millisecond-since-epoch strings; ParsedExpiresAt + ParsedPurchasedAt
// expose them as time.Time for the handlers' convenience.
type Receipt struct {
	TransactionID         string `json:"transaction_id"`
	OriginalTransactionID string `json:"original_transaction_id"`
	ProductID             string `json:"product_id"`
	PurchaseDateMS        string `json:"purchase_date_ms"`
	ExpiresDateMS         string `json:"expires_date_ms"`
}

func (r Receipt) ParsedPurchasedAt() time.Time { return msEpochToTime(r.PurchaseDateMS) }
func (r Receipt) ParsedExpiresAt() time.Time   { return msEpochToTime(r.ExpiresDateMS) }

// PickLatestForProduct returns the receipt entry with the highest
// expires_date for the given product id. Apple may include a long
// renewal history; the V17 store only cares about the freshest entry.
func (v *VerifyReceiptResponse) PickLatestForProduct(productID string) (Receipt, bool) {
	var best Receipt
	var found bool
	for _, r := range v.Latest {
		if r.ProductID != productID {
			continue
		}
		if !found || r.ParsedExpiresAt().After(best.ParsedExpiresAt()) {
			best = r
			found = true
		}
	}
	return best, found
}

// AnyLatest returns the most recent receipt regardless of product id.
// Used as a fallback when the request did not specify a product.
func (v *VerifyReceiptResponse) AnyLatest() (Receipt, bool) {
	var best Receipt
	var found bool
	for _, r := range v.Latest {
		if !found || r.ParsedExpiresAt().After(best.ParsedExpiresAt()) {
			best = r
			found = true
		}
	}
	return best, found
}

// Apple status codes the V17 flow knows how to interpret.
const (
	AppleStatusOK              = 0
	AppleStatusSandboxOnProd   = 21007 // "this receipt is from the sandbox environment"
	AppleStatusProdOnSandbox   = 21008 // "this receipt is from the production environment"
)

// HTTPAppleVerifier is the production AppleVerifier. It hits the
// production endpoint first and falls back to the sandbox endpoint when
// Apple returns status 21007 — that's the flow Apple themselves
// document for apps that want to support both environments without a
// build-time switch.
type HTTPAppleVerifier struct {
	HTTPClient   *http.Client
	SharedSecret string
	BundleID     string
	ProdURL      string
	SandboxURL   string
}

// DefaultHTTPAppleVerifier wires sensible defaults. Provide the shared
// secret + bundle id from env at construction time.
func DefaultHTTPAppleVerifier(sharedSecret, bundleID string) *HTTPAppleVerifier {
	return &HTTPAppleVerifier{
		HTTPClient:   &http.Client{Timeout: 10 * time.Second},
		SharedSecret: sharedSecret,
		BundleID:     bundleID,
		ProdURL:      "https://buy.itunes.apple.com/verifyReceipt",
		SandboxURL:   "https://sandbox.itunes.apple.com/verifyReceipt",
	}
}

// VerifyReceipt submits the receipt to Apple, retrying against sandbox
// when prod responds 21007. On any other non-zero status code it
// returns an error with the Apple status embedded.
func (v *HTTPAppleVerifier) VerifyReceipt(ctx context.Context, receipt string) (*VerifyReceiptResponse, error) {
	resp, err := v.post(ctx, v.ProdURL, receipt)
	if err != nil {
		return nil, err
	}
	if resp.Status == AppleStatusSandboxOnProd {
		return v.post(ctx, v.SandboxURL, receipt)
	}
	if resp.Status != AppleStatusOK {
		return resp, fmt.Errorf("apple verifyReceipt status=%d", resp.Status)
	}
	if v.BundleID != "" && resp.BundleID != "" && resp.BundleID != v.BundleID {
		return resp, fmt.Errorf("bundle id mismatch: got %q want %q", resp.BundleID, v.BundleID)
	}
	return resp, nil
}

func (v *HTTPAppleVerifier) post(ctx context.Context, url, receipt string) (*VerifyReceiptResponse, error) {
	payload := map[string]string{
		"receipt-data": receipt,
		"password":     v.SharedSecret,
	}
	buf, _ := json.Marshal(payload)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(buf))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")

	httpResp, err := v.HTTPClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer httpResp.Body.Close()
	body, err := io.ReadAll(httpResp.Body)
	if err != nil {
		return nil, err
	}
	var parsed VerifyReceiptResponse
	if err := json.Unmarshal(body, &parsed); err != nil {
		return nil, fmt.Errorf("decode apple response: %w", err)
	}
	parsed.Raw = body
	return &parsed, nil
}

// FakeAppleVerifier is the test fixture. Configure Responses to match
// receipt strings the test will submit, or set FixedResponse for any
// receipt input. Any receipt that has neither match returns ErrFakeNoMatch.
type FakeAppleVerifier struct {
	Responses     map[string]*VerifyReceiptResponse
	FixedResponse *VerifyReceiptResponse
	Err           error
}

// ErrFakeNoMatch is returned when FakeAppleVerifier sees a receipt it
// has no canned response for.
var ErrFakeNoMatch = errors.New("fake apple verifier has no match for receipt")

func (f *FakeAppleVerifier) VerifyReceipt(_ context.Context, receipt string) (*VerifyReceiptResponse, error) {
	if f.Err != nil {
		return nil, f.Err
	}
	if r, ok := f.Responses[receipt]; ok {
		return r, nil
	}
	if f.FixedResponse != nil {
		return f.FixedResponse, nil
	}
	return nil, ErrFakeNoMatch
}

// ── App Store Server Notifications V2 ────────────────────────────────────

// NotificationType is the subset of ASSN V2 events the V17 flow handles.
const (
	NotifSubscribed     = "SUBSCRIBED"
	NotifDidRenew       = "DID_RENEW"
	NotifExpired        = "EXPIRED"
	NotifRefund         = "REFUND"
	NotifGracePeriod    = "GRACE_PERIOD_EXPIRED"
)

// Notification is the decoded ASSN V2 payload after JWS verification.
// V17 does NOT verify the JWS in code (see comment in handler) — the
// decoded shape is what callers consume.
type Notification struct {
	UUID                  string
	Type                  string
	OriginalTransactionID string
	TransactionID         string
	ProductID             string
	ExpiresAt             time.Time
}

// DecodeNotificationPayload parses the simplified JSON envelope we
// expose to handlers + tests. Production deployments running behind a
// real ASSN webhook MUST first verify the signedPayload JWS using
// Apple's public keys; until that hook lands (V18 polish), the spec's
// §4.15 entry is documented as "POC contract" and the production
// secret is rotated frequently.
func DecodeNotificationPayload(body []byte) (*Notification, error) {
	var raw struct {
		NotificationUUID string `json:"notificationUUID"`
		NotificationType string `json:"notificationType"`
		Data             struct {
			TransactionInfo struct {
				TransactionID         string `json:"transactionId"`
				OriginalTransactionID string `json:"originalTransactionId"`
				ProductID             string `json:"productId"`
				ExpiresDate           int64  `json:"expiresDate"` // ms epoch
			} `json:"transactionInfo"`
		} `json:"data"`
	}
	if err := json.Unmarshal(body, &raw); err != nil {
		return nil, err
	}
	if strings.TrimSpace(raw.NotificationUUID) == "" {
		return nil, errors.New("missing notificationUUID")
	}
	out := &Notification{
		UUID:                  raw.NotificationUUID,
		Type:                  raw.NotificationType,
		TransactionID:         raw.Data.TransactionInfo.TransactionID,
		OriginalTransactionID: raw.Data.TransactionInfo.OriginalTransactionID,
		ProductID:             raw.Data.TransactionInfo.ProductID,
	}
	if raw.Data.TransactionInfo.ExpiresDate > 0 {
		out.ExpiresAt = time.UnixMilli(raw.Data.TransactionInfo.ExpiresDate).UTC()
	}
	return out, nil
}

// msEpochToTime converts Apple's "1714896000000" string-encoded
// millisecond epoch into a time.Time. Returns the zero value on parse
// errors so handlers can detect missing timestamps without an error
// channel.
func msEpochToTime(s string) time.Time {
	if s == "" {
		return time.Time{}
	}
	var ms int64
	if _, err := fmt.Sscanf(s, "%d", &ms); err != nil {
		return time.Time{}
	}
	return time.UnixMilli(ms).UTC()
}
