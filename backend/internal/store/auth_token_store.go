package store

import (
	"errors"
	"sync"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// AuthTokenStore persists sha256-hashed bearer tokens. The store treats
// the hash as opaque: callers compute it, callers verify it. Lookups
// exclude revoked and expired rows so a single read is sufficient to
// authenticate a request.
type AuthTokenStore interface {
	// CreateAuthToken inserts a new token. The TokenHash must be unique;
	// reuse returns ErrDuplicateAuthTokenHash because a sha256 collision
	// is a security incident, not a normal-path retry.
	CreateAuthToken(token contracts.AuthToken) (contracts.AuthToken, error)

	// AuthTokenByHash returns the token only when it is active (not
	// revoked, not expired).
	AuthTokenByHash(hash string) (contracts.AuthToken, bool)

	// RevokeAuthToken marks a single token revoked. Returns false if the
	// token does not exist or was already revoked.
	RevokeAuthToken(hash string) bool

	// RevokeAllAuthTokensForUser revokes every active token belonging to
	// a user (e.g. after password reset). Returns the number revoked.
	RevokeAllAuthTokensForUser(userID string) int

	// RevokeAllAuthTokensByKind revokes every active token of a specific
	// kind for a user (e.g. invalidate prior verify links when a new
	// resend lands). Returns the number revoked.
	RevokeAllAuthTokensByKind(userID, kind string) int

	// TouchAuthTokenLastUsed updates the last-used timestamp on the
	// active token. Returns false if the token is not active. Used by
	// the auth middleware to power session sliding expiry in V18.
	TouchAuthTokenLastUsed(hash string, when time.Time) bool

	// CleanupExpiredAuthTokens deletes (or otherwise purges) tokens whose
	// ExpiresAt is before `before`. Returns the number purged. Idempotent.
	CleanupExpiredAuthTokens(before time.Time) int
}

// ErrDuplicateAuthTokenHash signals that a sha256 collision (or, much
// more likely, a programming bug) caused two distinct issuances to land
// on the same hash.
var ErrDuplicateAuthTokenHash = errors.New("auth token hash already exists")

// ── Memory implementation ────────────────────────────────────────────────

type memoryAuthTokenStore struct {
	mu     sync.RWMutex
	tokens map[string]*contracts.AuthToken // keyed by token_hash
}

func newMemoryAuthTokenStore() AuthTokenStore {
	return &memoryAuthTokenStore{tokens: map[string]*contracts.AuthToken{}}
}

func (s *memoryAuthTokenStore) CreateAuthToken(token contracts.AuthToken) (contracts.AuthToken, error) {
	if token.TokenHash == "" {
		return contracts.AuthToken{}, errors.New("token_hash required")
	}
	if token.UserID == "" {
		return contracts.AuthToken{}, errors.New("user_id required")
	}
	if token.Kind == "" {
		return contracts.AuthToken{}, errors.New("kind required")
	}
	if token.ExpiresAt.IsZero() {
		return contracts.AuthToken{}, errors.New("expires_at required")
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	if _, exists := s.tokens[token.TokenHash]; exists {
		return contracts.AuthToken{}, ErrDuplicateAuthTokenHash
	}

	if token.CreatedAt.IsZero() {
		token.CreatedAt = time.Now().UTC()
	}
	cp := token
	s.tokens[token.TokenHash] = &cp
	return token, nil
}

func (s *memoryAuthTokenStore) AuthTokenByHash(hash string) (contracts.AuthToken, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	t, ok := s.tokens[hash]
	if !ok {
		return contracts.AuthToken{}, false
	}
	if !t.IsActive(time.Now().UTC()) {
		return contracts.AuthToken{}, false
	}
	return *t, true
}

func (s *memoryAuthTokenStore) RevokeAuthToken(hash string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	t, ok := s.tokens[hash]
	if !ok || t.RevokedAt != nil {
		return false
	}
	now := time.Now().UTC()
	t.RevokedAt = &now
	return true
}

func (s *memoryAuthTokenStore) RevokeAllAuthTokensForUser(userID string) int {
	s.mu.Lock()
	defer s.mu.Unlock()
	now := time.Now().UTC()
	count := 0
	for _, t := range s.tokens {
		if t.UserID != userID || t.RevokedAt != nil {
			continue
		}
		t.RevokedAt = &now
		count++
	}
	return count
}

func (s *memoryAuthTokenStore) RevokeAllAuthTokensByKind(userID, kind string) int {
	s.mu.Lock()
	defer s.mu.Unlock()
	now := time.Now().UTC()
	count := 0
	for _, t := range s.tokens {
		if t.UserID != userID || t.Kind != kind || t.RevokedAt != nil {
			continue
		}
		t.RevokedAt = &now
		count++
	}
	return count
}

func (s *memoryAuthTokenStore) TouchAuthTokenLastUsed(hash string, when time.Time) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	t, ok := s.tokens[hash]
	if !ok || !t.IsActive(time.Now().UTC()) {
		return false
	}
	w := when.UTC()
	t.LastUsedAt = &w
	return true
}

func (s *memoryAuthTokenStore) CleanupExpiredAuthTokens(before time.Time) int {
	s.mu.Lock()
	defer s.mu.Unlock()
	count := 0
	for h, t := range s.tokens {
		if t.ExpiresAt.Before(before) {
			delete(s.tokens, h)
			count++
		}
	}
	return count
}
