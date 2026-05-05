package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"github.com/lib/pq"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// postgresAuthTokenStore is the Postgres-backed AuthTokenStore. The
// schema mirrors the auth_tokens block of
// backend/db/migrations/023_users.sql; ensureSchema runs the same DDL so
// container bootstraps without a manual migration step still work.
//
// CleanupExpiredAuthTokens deletes rows outright (rather than soft-purge)
// because the partial indexes on (user_id, kind) and (expires_at) only
// cover active rows, and keeping rows around indefinitely bloats the
// table without any retention requirement (the audit trail is the
// `auth_tokens.created_at` of the next active token).
type postgresAuthTokenStore struct{ db *sql.DB }

// NewPostgresAuthTokenStoreWithDB wraps an existing *sql.DB.
func NewPostgresAuthTokenStoreWithDB(db *sql.DB) (AuthTokenStore, error) {
	store := &postgresAuthTokenStore{db: db}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := store.ensureSchema(ctx); err != nil {
		return nil, fmt.Errorf("ensure auth_token schema: %w", err)
	}
	return store, nil
}

func (s *postgresAuthTokenStore) ensureSchema(ctx context.Context) error {
	_, err := s.db.ExecContext(ctx, `
CREATE TABLE IF NOT EXISTS auth_tokens (
    token_hash   TEXT        PRIMARY KEY,
    user_id      TEXT        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    kind         TEXT        NOT NULL,
    expires_at   TIMESTAMPTZ NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at   TIMESTAMPTZ,
    last_used_at TIMESTAMPTZ,
    user_agent   TEXT,
    ip_address   TEXT
);

CREATE INDEX IF NOT EXISTS auth_tokens_user_kind_idx
    ON auth_tokens (user_id, kind) WHERE revoked_at IS NULL;

CREATE INDEX IF NOT EXISTS auth_tokens_expires_at_idx
    ON auth_tokens (expires_at) WHERE revoked_at IS NULL;
`)
	return err
}

const authTokenColumns = `
    token_hash, user_id, kind, expires_at, created_at,
    revoked_at, last_used_at,
    COALESCE(user_agent, ''), COALESCE(ip_address, '')
`

func scanAuthToken(row interface {
	Scan(dest ...any) error
}) (contracts.AuthToken, error) {
	var t contracts.AuthToken
	var revokedAt, lastUsedAt sql.NullTime
	err := row.Scan(
		&t.TokenHash, &t.UserID, &t.Kind, &t.ExpiresAt, &t.CreatedAt,
		&revokedAt, &lastUsedAt, &t.UserAgent, &t.IPAddress,
	)
	if err != nil {
		return contracts.AuthToken{}, err
	}
	if revokedAt.Valid {
		v := revokedAt.Time
		t.RevokedAt = &v
	}
	if lastUsedAt.Valid {
		v := lastUsedAt.Time
		t.LastUsedAt = &v
	}
	return t, nil
}

func (s *postgresAuthTokenStore) CreateAuthToken(token contracts.AuthToken) (contracts.AuthToken, error) {
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
	if token.CreatedAt.IsZero() {
		token.CreatedAt = time.Now().UTC()
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_, err := s.db.ExecContext(ctx, `
INSERT INTO auth_tokens (
    token_hash, user_id, kind, expires_at, created_at, user_agent, ip_address
) VALUES ($1,$2,$3,$4,$5,NULLIF($6,''),NULLIF($7,''))
`,
		token.TokenHash, token.UserID, token.Kind, token.ExpiresAt, token.CreatedAt,
		token.UserAgent, token.IPAddress,
	)
	if err != nil {
		var pqErr *pq.Error
		if errors.As(err, &pqErr) && pqErr.Code == "23505" {
			return contracts.AuthToken{}, ErrDuplicateAuthTokenHash
		}
		return contracts.AuthToken{}, fmt.Errorf("insert auth_token: %w", err)
	}
	return token, nil
}

func (s *postgresAuthTokenStore) AuthTokenByHash(hash string) (contracts.AuthToken, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	row := s.db.QueryRowContext(ctx, `
SELECT `+authTokenColumns+`
FROM auth_tokens
WHERE token_hash = $1
  AND revoked_at IS NULL
  AND expires_at > now()
`, hash)
	t, err := scanAuthToken(row)
	if err != nil {
		return contracts.AuthToken{}, false
	}
	return t, true
}

func (s *postgresAuthTokenStore) RevokeAuthToken(hash string) bool {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	res, err := s.db.ExecContext(ctx,
		`UPDATE auth_tokens SET revoked_at = now() WHERE token_hash = $1 AND revoked_at IS NULL`,
		hash,
	)
	if err != nil {
		return false
	}
	n, _ := res.RowsAffected()
	return n > 0
}

func (s *postgresAuthTokenStore) RevokeAllAuthTokensForUser(userID string) int {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	res, err := s.db.ExecContext(ctx,
		`UPDATE auth_tokens SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL`,
		userID,
	)
	if err != nil {
		return 0
	}
	n, _ := res.RowsAffected()
	return int(n)
}

func (s *postgresAuthTokenStore) RevokeAllAuthTokensByKind(userID, kind string) int {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	res, err := s.db.ExecContext(ctx, `
UPDATE auth_tokens
SET revoked_at = now()
WHERE user_id = $1 AND kind = $2 AND revoked_at IS NULL
`, userID, kind)
	if err != nil {
		return 0
	}
	n, _ := res.RowsAffected()
	return int(n)
}

func (s *postgresAuthTokenStore) TouchAuthTokenLastUsed(hash string, when time.Time) bool {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	res, err := s.db.ExecContext(ctx, `
UPDATE auth_tokens
SET last_used_at = $2
WHERE token_hash = $1
  AND revoked_at IS NULL
  AND expires_at > now()
`, hash, when.UTC())
	if err != nil {
		return false
	}
	n, _ := res.RowsAffected()
	return n > 0
}

func (s *postgresAuthTokenStore) CleanupExpiredAuthTokens(before time.Time) int {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	res, err := s.db.ExecContext(ctx,
		`DELETE FROM auth_tokens WHERE expires_at < $1`,
		before.UTC(),
	)
	if err != nil {
		return 0
	}
	n, _ := res.RowsAffected()
	return int(n)
}
