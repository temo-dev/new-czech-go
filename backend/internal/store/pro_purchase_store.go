package store

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"errors"
	"fmt"
	"sync"
	"time"

	"github.com/lib/pq"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// ProPurchaseStore persists Apple IAP receipts. Every transaction is
// written exactly once; renewals add new rows and the active-lookup picks
// the row with the latest expiry. The webhook handler flips IsActive to
// false on EXPIRED and REFUND events.
type ProPurchaseStore interface {
	CreateProPurchase(p contracts.ProPurchase) (contracts.ProPurchase, error)
	ActiveProPurchaseByUser(userID string) (contracts.ProPurchase, bool)
	MarkProPurchaseInactive(appleTransactionID string) bool

	// FindByTransactionID returns the row keyed by Apple's transaction id
	// regardless of is_active. The webhook downgrade path needs the
	// owning user_id even when the same transaction has already been
	// marked inactive (e.g. a REFUND following an EXPIRED for the same
	// txn). Returns (zero, false) when no row matches.
	FindByTransactionID(appleTransactionID string) (contracts.ProPurchase, bool)
}

// ErrDuplicateAppleTxn is returned when CreateProPurchase is called with a
// transaction id that already exists. Apple's webhook may replay events,
// so callers translate this error into a no-op rather than a hard failure.
var ErrDuplicateAppleTxn = errors.New("apple transaction id already recorded")

// ── Memory implementation ────────────────────────────────────────────────

type memoryProPurchaseStore struct {
	mu        sync.RWMutex
	purchases map[string]*contracts.ProPurchase // keyed by apple_transaction_id
}

func newMemoryProPurchaseStore() ProPurchaseStore {
	return &memoryProPurchaseStore{purchases: map[string]*contracts.ProPurchase{}}
}

// NewMemoryProPurchaseStore returns a fresh in-memory store. Exported for
// dev/test wiring outside this package.
func NewMemoryProPurchaseStore() ProPurchaseStore { return newMemoryProPurchaseStore() }

func (s *memoryProPurchaseStore) CreateProPurchase(p contracts.ProPurchase) (contracts.ProPurchase, error) {
	if p.UserID == "" {
		return contracts.ProPurchase{}, errors.New("user_id required")
	}
	if p.AppleTransactionID == "" {
		return contracts.ProPurchase{}, errors.New("apple_transaction_id required")
	}
	if p.ProductID == "" {
		return contracts.ProPurchase{}, errors.New("product_id required")
	}
	if p.ExpiresAt.IsZero() {
		return contracts.ProPurchase{}, errors.New("expires_at required")
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	if _, exists := s.purchases[p.AppleTransactionID]; exists {
		return contracts.ProPurchase{}, ErrDuplicateAppleTxn
	}

	if p.ID == "" {
		p.ID = newProPurchaseID()
	}
	if p.CreatedAt.IsZero() {
		p.CreatedAt = time.Now().UTC()
	}
	// Default to active unless caller passed an inactive row explicitly
	// (e.g. recording a known-refunded transaction).
	if !p.IsActive {
		p.IsActive = true
	}

	cp := p
	s.purchases[p.AppleTransactionID] = &cp
	return p, nil
}

func (s *memoryProPurchaseStore) ActiveProPurchaseByUser(userID string) (contracts.ProPurchase, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	now := time.Now().UTC()
	var best *contracts.ProPurchase
	for _, p := range s.purchases {
		if p.UserID != userID || !p.IsActive || !p.ExpiresAt.After(now) {
			continue
		}
		if best == nil || p.ExpiresAt.After(best.ExpiresAt) {
			best = p
		}
	}
	if best == nil {
		return contracts.ProPurchase{}, false
	}
	return *best, true
}

func (s *memoryProPurchaseStore) FindByTransactionID(appleTransactionID string) (contracts.ProPurchase, bool) {
	if appleTransactionID == "" {
		return contracts.ProPurchase{}, false
	}
	s.mu.RLock()
	defer s.mu.RUnlock()
	p, ok := s.purchases[appleTransactionID]
	if !ok {
		return contracts.ProPurchase{}, false
	}
	return *p, true
}

func (s *memoryProPurchaseStore) MarkProPurchaseInactive(appleTransactionID string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, ok := s.purchases[appleTransactionID]
	if !ok || !p.IsActive {
		return false
	}
	p.IsActive = false
	return true
}

// newProPurchaseID returns a 16-hex-char identifier prefixed with "pp_".
func newProPurchaseID() string {
	b := make([]byte, 8)
	if _, err := rand.Read(b); err != nil {
		return fmt.Sprintf("pp_%d", time.Now().UnixNano())
	}
	return "pp_" + hex.EncodeToString(b)
}

// ── Postgres implementation ──────────────────────────────────────────────

type postgresProPurchaseStore struct{ db *sql.DB }

// NewPostgresProPurchaseStoreWithDB wraps an existing *sql.DB.
func NewPostgresProPurchaseStoreWithDB(db *sql.DB) (ProPurchaseStore, error) {
	store := &postgresProPurchaseStore{db: db}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := store.ensureSchema(ctx); err != nil {
		return nil, fmt.Errorf("ensure pro_purchase schema: %w", err)
	}
	return store, nil
}

func (s *postgresProPurchaseStore) ensureSchema(ctx context.Context) error {
	_, err := s.db.ExecContext(ctx, `
CREATE TABLE IF NOT EXISTS pro_purchases (
    id                            TEXT        PRIMARY KEY,
    user_id                       TEXT        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    apple_transaction_id          TEXT        NOT NULL,
    apple_original_transaction_id TEXT        NOT NULL,
    product_id                    TEXT        NOT NULL,
    purchased_at                  TIMESTAMPTZ NOT NULL,
    expires_at                    TIMESTAMPTZ NOT NULL,
    receipt_payload               JSONB       NOT NULL,
    is_active                     BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at                    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS pro_purchases_apple_txn_uniq
    ON pro_purchases (apple_transaction_id);

CREATE INDEX IF NOT EXISTS pro_purchases_user_active_idx
    ON pro_purchases (user_id) WHERE is_active = TRUE;
`)
	return err
}

func (s *postgresProPurchaseStore) CreateProPurchase(p contracts.ProPurchase) (contracts.ProPurchase, error) {
	if p.UserID == "" {
		return contracts.ProPurchase{}, errors.New("user_id required")
	}
	if p.AppleTransactionID == "" {
		return contracts.ProPurchase{}, errors.New("apple_transaction_id required")
	}
	if p.ProductID == "" {
		return contracts.ProPurchase{}, errors.New("product_id required")
	}
	if p.ExpiresAt.IsZero() {
		return contracts.ProPurchase{}, errors.New("expires_at required")
	}

	if p.ID == "" {
		p.ID = newProPurchaseID()
	}
	if p.CreatedAt.IsZero() {
		p.CreatedAt = time.Now().UTC()
	}
	p.IsActive = true

	payload := p.ReceiptPayload
	if len(payload) == 0 {
		payload = []byte(`{}`)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_, err := s.db.ExecContext(ctx, `
INSERT INTO pro_purchases (
    id, user_id, apple_transaction_id, apple_original_transaction_id,
    product_id, purchased_at, expires_at, receipt_payload, is_active, created_at
) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
`,
		p.ID, p.UserID, p.AppleTransactionID, p.AppleOriginalTransactionID,
		p.ProductID, p.PurchasedAt, p.ExpiresAt, payload, p.IsActive, p.CreatedAt,
	)
	if err != nil {
		var pqErr *pq.Error
		if errors.As(err, &pqErr) && pqErr.Code == "23505" {
			return contracts.ProPurchase{}, ErrDuplicateAppleTxn
		}
		return contracts.ProPurchase{}, fmt.Errorf("insert pro_purchase: %w", err)
	}
	return p, nil
}

func (s *postgresProPurchaseStore) ActiveProPurchaseByUser(userID string) (contracts.ProPurchase, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	row := s.db.QueryRowContext(ctx, `
SELECT id, user_id, apple_transaction_id, apple_original_transaction_id,
       product_id, purchased_at, expires_at, receipt_payload, is_active, created_at
FROM pro_purchases
WHERE user_id = $1 AND is_active = TRUE AND expires_at > now()
ORDER BY expires_at DESC
LIMIT 1
`, userID)
	var p contracts.ProPurchase
	if err := row.Scan(
		&p.ID, &p.UserID, &p.AppleTransactionID, &p.AppleOriginalTransactionID,
		&p.ProductID, &p.PurchasedAt, &p.ExpiresAt, &p.ReceiptPayload, &p.IsActive, &p.CreatedAt,
	); err != nil {
		return contracts.ProPurchase{}, false
	}
	return p, true
}

func (s *postgresProPurchaseStore) FindByTransactionID(appleTransactionID string) (contracts.ProPurchase, bool) {
	if appleTransactionID == "" {
		return contracts.ProPurchase{}, false
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	row := s.db.QueryRowContext(ctx, `
SELECT id, user_id, apple_transaction_id, apple_original_transaction_id,
       product_id, purchased_at, expires_at, receipt_payload, is_active, created_at
FROM pro_purchases
WHERE apple_transaction_id = $1
LIMIT 1
`, appleTransactionID)
	var p contracts.ProPurchase
	if err := row.Scan(
		&p.ID, &p.UserID, &p.AppleTransactionID, &p.AppleOriginalTransactionID,
		&p.ProductID, &p.PurchasedAt, &p.ExpiresAt, &p.ReceiptPayload, &p.IsActive, &p.CreatedAt,
	); err != nil {
		return contracts.ProPurchase{}, false
	}
	return p, true
}

func (s *postgresProPurchaseStore) MarkProPurchaseInactive(appleTransactionID string) bool {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	res, err := s.db.ExecContext(ctx,
		`UPDATE pro_purchases SET is_active = FALSE WHERE apple_transaction_id = $1 AND is_active = TRUE`,
		appleTransactionID,
	)
	if err != nil {
		return false
	}
	n, _ := res.RowsAffected()
	return n > 0
}
