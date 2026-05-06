package store

// dev_fixture_users.go — keeps the in-memory dev login fixtures in sync with
// the Postgres `users` table.
//
// MemoryStore.Login auto-creates three accounts in dev mode (learner@example.com,
// learner2@example.com, admin@example.com — all `demo123`). Several Postgres
// tables that V17/V19 introduced (auth_tokens, streak_days, pro_purchases,
// daily_usage, user_skill_mastery) have a FOREIGN KEY on users(id), so any
// write triggered by those fixture logins fails with a FK violation unless the
// rows also exist in Postgres.
//
// EnsureDevFixtureUsers inserts the three accounts idempotently. Call it once
// at server boot when ENV != "production". Production builds must never call
// this — production users come through the real V17 signup flow.

import (
	"context"
	"fmt"
	"time"
)

// devFixtureUsers mirrors the static map MemoryStore wires up for dev logins.
// Keep this list in lock-step with backend/internal/store/memory.go:devTokens.
var devFixtureUsers = []struct {
	ID          string
	Email       string
	DisplayName string
	Role        string
}{
	{ID: "user-learner-1", Email: "learner@example.com", DisplayName: "Nguyen An", Role: "learner"},
	{ID: "user-learner-2", Email: "learner2@example.com", DisplayName: "Tran Binh", Role: "learner"},
	{ID: "user-admin-1", Email: "admin@example.com", DisplayName: "CMS Admin", Role: "admin"},
}

// EnsureDevFixtureUsers idempotently inserts the dev fixture user rows into
// Postgres. Existing rows (matched by id) are left untouched so a real signup
// that happens to land on the same id never gets clobbered. The placeholder
// password_hash is intentionally non-bcrypt so the V17 login bcrypt path
// always rejects it — credentials still go through MemoryStore.Login.
func EnsureDevFixtureUsers(databaseURL string) error {
	db, err := openPostgresPool(databaseURL, "dev_fixture_users")
	if err != nil {
		return fmt.Errorf("open pool: %w", err)
	}
	defer db.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Insert with email_verified_at = now() so the V17 verify gate doesn't
	// block dev fixtures after 3 attempts. Also bumps grace_attempts_left
	// on existing rows that were inserted before this fix landed; without
	// the UPDATE branch, rows seeded earlier would still hit the gate.
	const q = `
INSERT INTO users (
    id, email, email_normalized, password_hash, display_name, role, pro_tier,
    email_verified_at, grace_attempts_left
) VALUES ($1, $2, $2, 'dev-fixture-no-bcrypt', $3, $4, 'free', now(), 1000000)
ON CONFLICT (id) DO UPDATE SET
    email_verified_at   = COALESCE(users.email_verified_at, now()),
    grace_attempts_left = GREATEST(users.grace_attempts_left, 1000000)
`
	for _, u := range devFixtureUsers {
		if _, err := db.ExecContext(ctx, q, u.ID, u.Email, u.DisplayName, u.Role); err != nil {
			return fmt.Errorf("insert %s: %w", u.ID, err)
		}
	}
	return nil
}
