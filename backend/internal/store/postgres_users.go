package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/lib/pq"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// postgresUserStore is the Postgres-backed UserStore. The schema mirrors
// backend/db/migrations/023_users.sql; the embedded ensureSchema runs the
// same DDL so containers without a manual migration step still come up
// with the right tables (CREATE TABLE IF NOT EXISTS keeps it idempotent).
type postgresUserStore struct{ db *sql.DB }

// NewPostgresUserStore opens a connection (or reuses one) and ensures the
// users table exists. Returns ready-to-use UserStore.
func NewPostgresUserStore(databaseURL string) (UserStore, error) {
	db, err := sql.Open("postgres", databaseURL)
	if err != nil {
		return nil, fmt.Errorf("open postgres: %w", err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := db.PingContext(ctx); err != nil {
		db.Close()
		return nil, fmt.Errorf("ping postgres: %w", err)
	}
	store := &postgresUserStore{db: db}
	if err := store.ensureSchema(ctx); err != nil {
		db.Close()
		return nil, fmt.Errorf("ensure user schema: %w", err)
	}
	return store, nil
}

// NewPostgresUserStoreWithDB wraps an existing *sql.DB. Production
// bootstrap uses [NewPostgresUserStore] (URL-based) so each V17 store
// owns its own pool, matching the legacy NewPostgresXxxStore pattern
// elsewhere in the codebase.
func NewPostgresUserStoreWithDB(db *sql.DB) (UserStore, error) {
	store := &postgresUserStore{db: db}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := store.ensureSchema(ctx); err != nil {
		return nil, fmt.Errorf("ensure user schema: %w", err)
	}
	return store, nil
}

func (s *postgresUserStore) ensureSchema(ctx context.Context) error {
	_, err := s.db.ExecContext(ctx, `
CREATE TABLE IF NOT EXISTS users (
    id                  TEXT        PRIMARY KEY,
    email               TEXT        NOT NULL,
    email_normalized    TEXT        NOT NULL,
    email_verified_at   TIMESTAMPTZ,
    password_hash       TEXT        NOT NULL,
    display_name        TEXT        NOT NULL DEFAULT '',
    avatar_asset_id     TEXT,
    role                TEXT        NOT NULL DEFAULT 'learner',
    pro_tier            TEXT        NOT NULL DEFAULT 'free',
    pro_expires_at      TIMESTAMPTZ,
    onboarding_goal     TEXT,
    onboarding_level    TEXT,
    daily_reminder_at   TEXT,
    push_token          TEXT,
    push_token_platform TEXT,
    timezone            TEXT        NOT NULL DEFAULT 'Asia/Ho_Chi_Minh',
    grace_attempts_left INTEGER     NOT NULL DEFAULT 3,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at          TIMESTAMPTZ
);

CREATE UNIQUE INDEX IF NOT EXISTS users_email_normalized_uniq
    ON users (email_normalized) WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS users_role_idx
    ON users (role) WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS users_pro_expires_at_idx
    ON users (pro_expires_at)
    WHERE pro_tier = 'pro' AND deleted_at IS NULL;
`)
	return err
}

// userColumns is the ordered list returned by every SELECT in this file.
// Centralising it keeps row scans in lockstep with the column order.
const userColumns = `
    id, email, email_normalized, email_verified_at, password_hash,
    display_name, COALESCE(avatar_asset_id, ''), role, pro_tier, pro_expires_at,
    COALESCE(onboarding_goal, ''), COALESCE(onboarding_level, ''),
    COALESCE(daily_reminder_at, ''), COALESCE(push_token, ''),
    COALESCE(push_token_platform, ''), timezone, grace_attempts_left,
    created_at, updated_at, deleted_at
`

func scanUser(row interface {
	Scan(dest ...any) error
}) (contracts.UserAccount, error) {
	var u contracts.UserAccount
	var verifiedAt, proExpiresAt, deletedAt sql.NullTime
	err := row.Scan(
		&u.ID, &u.Email, &u.EmailNormalized, &verifiedAt, &u.PasswordHash,
		&u.DisplayName, &u.AvatarAssetID, &u.Role, &u.ProTier, &proExpiresAt,
		&u.OnboardingGoal, &u.OnboardingLevel,
		&u.DailyReminderAt, &u.PushToken,
		&u.PushTokenPlatform, &u.Timezone, &u.GraceAttemptsLeft,
		&u.CreatedAt, &u.UpdatedAt, &deletedAt,
	)
	if err != nil {
		return contracts.UserAccount{}, err
	}
	if verifiedAt.Valid {
		t := verifiedAt.Time
		u.EmailVerifiedAt = &t
	}
	if proExpiresAt.Valid {
		t := proExpiresAt.Time
		u.ProExpiresAt = &t
	}
	if deletedAt.Valid {
		t := deletedAt.Time
		u.DeletedAt = &t
	}
	return u, nil
}

func (s *postgresUserStore) CreateUser(account contracts.UserAccount) (contracts.UserAccount, error) {
	if strings.TrimSpace(account.Email) == "" {
		return contracts.UserAccount{}, errors.New("email required")
	}
	if account.PasswordHash == "" {
		return contracts.UserAccount{}, errors.New("password_hash required")
	}

	now := time.Now().UTC()
	if account.ID == "" {
		account.ID = newUserID()
	}
	account.EmailNormalized = normalizeEmail(account.Email)
	if account.Role == "" {
		account.Role = "learner"
	}
	if account.ProTier == "" {
		account.ProTier = "free"
	}
	if account.Timezone == "" {
		account.Timezone = "Asia/Ho_Chi_Minh"
	}
	if account.GraceAttemptsLeft == 0 {
		account.GraceAttemptsLeft = 3
	}
	account.CreatedAt = now
	account.UpdatedAt = now

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_, err := s.db.ExecContext(ctx, `
INSERT INTO users (
    id, email, email_normalized, password_hash, display_name, avatar_asset_id,
    role, pro_tier, timezone, grace_attempts_left, created_at, updated_at
) VALUES ($1,$2,$3,$4,$5,NULLIF($6,''),$7,$8,$9,$10,$11,$12)
`,
		account.ID, account.Email, account.EmailNormalized, account.PasswordHash,
		account.DisplayName, account.AvatarAssetID,
		account.Role, account.ProTier, account.Timezone, account.GraceAttemptsLeft,
		account.CreatedAt, account.UpdatedAt,
	)
	if err != nil {
		var pqErr *pq.Error
		if errors.As(err, &pqErr) && pqErr.Code == "23505" {
			return contracts.UserAccount{}, ErrDuplicateEmail
		}
		return contracts.UserAccount{}, fmt.Errorf("insert user: %w", err)
	}
	return account, nil
}

func (s *postgresUserStore) UserAccountByID(id string) (contracts.UserAccount, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	row := s.db.QueryRowContext(ctx,
		`SELECT `+userColumns+` FROM users WHERE id = $1 AND deleted_at IS NULL`, id,
	)
	u, err := scanUser(row)
	if err != nil {
		return contracts.UserAccount{}, false
	}
	return u, true
}

func (s *postgresUserStore) UserAccountByEmail(email string) (contracts.UserAccount, bool) {
	normalized := normalizeEmail(email)
	if normalized == "" {
		return contracts.UserAccount{}, false
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	row := s.db.QueryRowContext(ctx,
		`SELECT `+userColumns+` FROM users WHERE email_normalized = $1 AND deleted_at IS NULL`, normalized,
	)
	u, err := scanUser(row)
	if err != nil {
		return contracts.UserAccount{}, false
	}
	return u, true
}

func (s *postgresUserStore) UpdateUser(id string, mutate func(*contracts.UserAccount)) (contracts.UserAccount, bool) {
	current, ok := s.UserAccountByID(id)
	if !ok {
		return contracts.UserAccount{}, false
	}
	immutableID := current.ID
	immutableCreated := current.CreatedAt
	immutableDeleted := current.DeletedAt

	mutate(&current)

	current.ID = immutableID
	current.CreatedAt = immutableCreated
	current.DeletedAt = immutableDeleted
	current.UpdatedAt = time.Now().UTC()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_, err := s.db.ExecContext(ctx, `
UPDATE users SET
    email = $2,
    email_normalized = $3,
    email_verified_at = $4,
    password_hash = $5,
    display_name = $6,
    avatar_asset_id = NULLIF($7,''),
    role = $8,
    pro_tier = $9,
    pro_expires_at = $10,
    onboarding_goal = NULLIF($11,''),
    onboarding_level = NULLIF($12,''),
    daily_reminder_at = NULLIF($13,''),
    push_token = NULLIF($14,''),
    push_token_platform = NULLIF($15,''),
    timezone = $16,
    grace_attempts_left = $17,
    updated_at = $18
WHERE id = $1 AND deleted_at IS NULL
`,
		current.ID, current.Email, current.EmailNormalized, nullTime(current.EmailVerifiedAt),
		current.PasswordHash, current.DisplayName, current.AvatarAssetID,
		current.Role, current.ProTier, nullTime(current.ProExpiresAt),
		current.OnboardingGoal, current.OnboardingLevel,
		current.DailyReminderAt, current.PushToken, current.PushTokenPlatform,
		current.Timezone, current.GraceAttemptsLeft, current.UpdatedAt,
	)
	if err != nil {
		return contracts.UserAccount{}, false
	}
	return current, true
}

func (s *postgresUserStore) SoftDeleteUser(id string) bool {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	now := time.Now().UTC()
	res, err := s.db.ExecContext(ctx,
		`UPDATE users SET deleted_at = $2, updated_at = $2 WHERE id = $1 AND deleted_at IS NULL`,
		id, now,
	)
	if err != nil {
		return false
	}
	n, _ := res.RowsAffected()
	return n > 0
}

func (s *postgresUserStore) MarkUserEmailVerified(id string) bool {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	now := time.Now().UTC()
	res, err := s.db.ExecContext(ctx, `
UPDATE users SET
    email_verified_at = $2,
    grace_attempts_left = $3,
    updated_at = $2
WHERE id = $1 AND deleted_at IS NULL
`, id, now, graceAfterVerify)
	if err != nil {
		return false
	}
	n, _ := res.RowsAffected()
	return n > 0
}

func (s *postgresUserStore) DecrementUserGrace(id string) (int, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	row := s.db.QueryRowContext(ctx, `
UPDATE users SET
    grace_attempts_left = GREATEST(grace_attempts_left - 1, 0),
    updated_at = now()
WHERE id = $1 AND deleted_at IS NULL
RETURNING grace_attempts_left
`, id)
	var left int
	if err := row.Scan(&left); err != nil {
		return 0, false
	}
	return left, true
}

// nullTime converts an optional time pointer to a sql-compatible value
// suitable for nullable TIMESTAMPTZ columns.
func nullTime(t *time.Time) any {
	if t == nil {
		return nil
	}
	return *t
}
