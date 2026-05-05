package contracts

import "time"

// ProPurchase records a single Apple In-App Purchase transaction. Each
// receipt verifyReceipt response yields exactly one row; renewals create
// new rows (with a fresh AppleTransactionID but the same
// AppleOriginalTransactionID) so the store retains the full ledger.
//
// IsActive flips to false when Apple's webhook reports EXPIRED or REFUND
// for the matching transaction; the active-by-user lookup returns the row
// with the latest ExpiresAt among the still-active ones.
type ProPurchase struct {
	ID                         string    `json:"id"`
	UserID                     string    `json:"user_id"`
	AppleTransactionID         string    `json:"apple_transaction_id"`
	AppleOriginalTransactionID string    `json:"apple_original_transaction_id"`
	ProductID                  string    `json:"product_id"`
	PurchasedAt                time.Time `json:"purchased_at"`
	ExpiresAt                  time.Time `json:"expires_at"`
	ReceiptPayload             []byte    `json:"-"` // raw verifyReceipt JSON, not exposed
	IsActive                   bool      `json:"is_active"`
	CreatedAt                  time.Time `json:"created_at"`
}

// IsCurrent reports whether the purchase is still the source of an active
// Pro entitlement at `now`: not flagged inactive AND not past expiry.
func (p ProPurchase) IsCurrent(now time.Time) bool {
	return p.IsActive && p.ExpiresAt.After(now)
}
