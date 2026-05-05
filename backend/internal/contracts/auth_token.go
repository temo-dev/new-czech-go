package contracts

import "time"

// AuthToken kinds. Each kind has its own TTL, single-use semantics, and
// revocation policy — the store does not enforce these; callers do. The
// store only persists the values verbatim and offers bulk-revoke helpers.
const (
	AuthTokenKindSession       = "session"        // 30 day rolling, multi-device
	AuthTokenKindEmailVerify   = "email_verify"   // 24 hour, one-shot
	AuthTokenKindPasswordReset = "password_reset" // 1 hour, one-shot
)

// AuthToken is a database-backed bearer token. The raw token string is
// never persisted; only its sha256 hash lives in TokenHash. Callers MUST
// hash the raw token before passing it to the store, and MUST do the same
// hashing when looking a token up.
type AuthToken struct {
	TokenHash  string     `json:"token_hash"`
	UserID     string     `json:"user_id"`
	Kind       string     `json:"kind"`
	ExpiresAt  time.Time  `json:"expires_at"`
	CreatedAt  time.Time  `json:"created_at"`
	RevokedAt  *time.Time `json:"revoked_at,omitempty"`
	LastUsedAt *time.Time `json:"last_used_at,omitempty"`
	UserAgent  string     `json:"user_agent,omitempty"`
	IPAddress  string     `json:"ip_address,omitempty"`
}

// IsActive reports whether the token can still be used: not revoked and
// not past its expiry. Equivalent to the partial-index predicate used by
// the Postgres lookup query.
func (t AuthToken) IsActive(now time.Time) bool {
	if t.RevokedAt != nil {
		return false
	}
	return t.ExpiresAt.After(now)
}
