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
