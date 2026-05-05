package store

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// TestUsersMigration023_FileExistsAndShapesUsersTable validates that the
// V17-A1.1 migration file is present and contains the expected schema. This
// is a static-shape check, not a Postgres apply test — applying the SQL is
// covered by the dedicated UserStore test suite (V17-A1.4) once the store
// landed.
//
// The check intentionally inspects the file by string matching so it does
// not depend on a running Postgres or a SQL parser library.
func TestUsersMigration023_FileExistsAndShapesUsersTable(t *testing.T) {
	path := findMigration(t, "023_users.sql")

	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read migration: %v", err)
	}
	sql := string(raw)

	mustContain(t, sql, "CREATE TABLE IF NOT EXISTS users")

	requiredColumns := []string{
		"id",
		"email",
		"email_normalized",
		"email_verified_at",
		"password_hash",
		"display_name",
		"avatar_asset_id",
		"role",
		"pro_tier",
		"pro_expires_at",
		"onboarding_goal",
		"onboarding_level",
		"daily_reminder_at",
		"push_token",
		"push_token_platform",
		"timezone",
		"grace_attempts_left",
		"created_at",
		"updated_at",
		"deleted_at",
	}
	for _, col := range requiredColumns {
		mustContain(t, sql, col)
	}

	// Partial unique index on email_normalized scoped to active rows.
	mustContain(t, sql, "users_email_normalized_uniq")
	mustContain(t, sql, "WHERE deleted_at IS NULL")

	// Idempotency markers — migration must be safe to re-run.
	mustContain(t, sql, "IF NOT EXISTS")
}

// TestAuthTokensMigration_FileShapesAuthTokensTable validates the V17-A1.2
// extension of 023_users.sql: an auth_tokens table that stores sha256 token
// hashes (never the raw token) and cascades on user deletion. Two partial
// indexes target the active-token lookups (kind + user) and the cleanup
// sweep (expires_at).
func TestAuthTokensMigration_FileShapesAuthTokensTable(t *testing.T) {
	path := findMigration(t, "023_users.sql")

	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read migration: %v", err)
	}
	sql := string(raw)

	mustContain(t, sql, "CREATE TABLE IF NOT EXISTS auth_tokens")

	requiredColumns := []string{
		"token_hash",
		"user_id",
		"kind",
		"expires_at",
		"created_at",
		"revoked_at",
		"last_used_at",
		"user_agent",
		"ip_address",
	}
	for _, col := range requiredColumns {
		mustContain(t, sql, col)
	}

	// Foreign key with cascade so deleting a user removes their tokens.
	mustContain(t, sql, "REFERENCES users(id) ON DELETE CASCADE")

	// Partial indexes for active-only lookups.
	mustContain(t, sql, "auth_tokens_user_kind_idx")
	mustContain(t, sql, "auth_tokens_expires_at_idx")
	// Both indexes scope to active rows.
	if strings.Count(sql, "WHERE revoked_at IS NULL") < 2 {
		t.Errorf("expected at least 2 partial indexes scoped WHERE revoked_at IS NULL")
	}
}

// TestStreakProPurchasesDailyUsageMigration_FileShapesTables validates the
// V17-A1.3 extension of 023_users.sql:
//   - streak_days   — composite PK (user_id, day) for per-day idempotent upserts
//   - pro_purchases — Apple IAP receipts, unique apple_transaction_id
//   - daily_usage   — composite PK (user_id, day) for free-tier rate limit
//
// All three tables CASCADE on user delete.
func TestStreakProPurchasesDailyUsageMigration_FileShapesTables(t *testing.T) {
	path := findMigration(t, "023_users.sql")

	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read migration: %v", err)
	}
	sql := string(raw)

	mustContain(t, sql, "CREATE TABLE IF NOT EXISTS streak_days")
	mustContain(t, sql, "CREATE TABLE IF NOT EXISTS pro_purchases")
	mustContain(t, sql, "CREATE TABLE IF NOT EXISTS daily_usage")

	// streak_days
	for _, col := range []string{"day", "completed", "grace_used"} {
		mustContain(t, sql, col)
	}

	// pro_purchases
	for _, col := range []string{
		"apple_transaction_id",
		"apple_original_transaction_id",
		"product_id",
		"purchased_at",
		"receipt_payload",
		"is_active",
	} {
		mustContain(t, sql, col)
	}
	mustContain(t, sql, "pro_purchases_apple_txn_uniq")
	mustContain(t, sql, "pro_purchases_user_active_idx")

	// daily_usage
	for _, col := range []string{"attempts_count", "interviews_count"} {
		mustContain(t, sql, col)
	}

	// All three new tables cascade on user delete (in addition to
	// auth_tokens that landed in A1.2 -> 4 cascades total).
	if c := strings.Count(sql, "REFERENCES users(id) ON DELETE CASCADE"); c < 4 {
		t.Errorf("expected ≥4 cascade FKs to users(id), got %d", c)
	}
}

func findMigration(t *testing.T, name string) string {
	t.Helper()

	// Walk up from this package directory until we find backend/db/migrations.
	wd, err := os.Getwd()
	if err != nil {
		t.Fatalf("getwd: %v", err)
	}
	dir := wd
	for i := 0; i < 6; i++ {
		candidate := filepath.Join(dir, "db", "migrations", name)
		if _, err := os.Stat(candidate); err == nil {
			return candidate
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	t.Fatalf("could not locate migration %s starting from %s", name, wd)
	return ""
}

func mustContain(t *testing.T, haystack, needle string) {
	t.Helper()
	if !strings.Contains(haystack, needle) {
		t.Errorf("migration missing expected fragment: %q", needle)
	}
}
