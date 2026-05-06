package store

import (
	"os"
	"strings"
	"testing"
)

// TestV21LevelsMigration_FileShapesAllSchema validates that the V21 migration
// file (025_v21_cefr_levels.sql) is present and contains the expected DDL for
// every schema change called out in the V21 spec:
//
//   - courses.level enum + courses_level_idx
//   - users.current_level + users.unlocked_levels + users.placement_taken_at
//   - mock_tests.is_promotion + is_placement + target_level + CHECK constraint
//   - promotion_attempts table with FKs and per-user index
//
// This is a static-shape check matching the existing repo convention (see
// users_migration_test.go for the same pattern). It does not apply the SQL —
// runtime application is exercised by the postgres store ensureSchema methods
// at startup.
func TestV21LevelsMigration_FileShapesAllSchema(t *testing.T) {
	path := findMigration(t, "025_v21_cefr_levels.sql")

	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read migration: %v", err)
	}
	sql := string(raw)

	t.Run("courses level + index", func(t *testing.T) {
		mustContain(t, sql, "ALTER TABLE courses")
		mustContain(t, sql, "ADD COLUMN IF NOT EXISTS level")
		// Default a2 keeps existing courses inside the current product scope.
		mustContain(t, sql, "DEFAULT 'a2'")
		mustContain(t, sql, "courses_level_idx")
	})

	t.Run("users level columns", func(t *testing.T) {
		mustContain(t, sql, "ALTER TABLE users")
		mustContain(t, sql, "ADD COLUMN IF NOT EXISTS current_level")
		mustContain(t, sql, "ADD COLUMN IF NOT EXISTS unlocked_levels")
		mustContain(t, sql, "ADD COLUMN IF NOT EXISTS placement_taken_at")
		// Array literal default for unlocked_levels — at least 'a0' so legacy
		// users always have a sane default before backfill in V21-B1.
		mustContain(t, sql, "ARRAY['a0']")
	})

	t.Run("mock_tests promotion flags + check", func(t *testing.T) {
		mustContain(t, sql, "ALTER TABLE mock_tests")
		mustContain(t, sql, "ADD COLUMN IF NOT EXISTS is_promotion")
		mustContain(t, sql, "ADD COLUMN IF NOT EXISTS is_placement")
		mustContain(t, sql, "ADD COLUMN IF NOT EXISTS target_level")
		// Promotion mocks must declare a target level.
		mustContain(t, sql, "mock_tests_promotion_target_required")
	})

	t.Run("promotion_attempts table", func(t *testing.T) {
		mustContain(t, sql, "CREATE TABLE IF NOT EXISTS promotion_attempts")
		// Required columns per V21 spec.
		for _, col := range []string{
			"user_id",
			"mock_test_id",
			"source_level",
			"target_level",
			"full_session_id",
			"passed",
			"score_pct",
			"per_skill_pct",
			"created_at",
		} {
			mustContain(t, sql, col)
		}
		// Cascade on user delete — matches 023_users.sql convention for all
		// tables that reference users(id).
		mustContain(t, sql, "REFERENCES users(id) ON DELETE CASCADE")
		mustContain(t, sql, "REFERENCES mock_tests(id)")
		// Per-user descending index used by cooldown lookup in V21-B2.
		mustContain(t, sql, "promotion_attempts_user_idx")
	})
}

// TestV21LevelsMigration_IsIdempotent validates that the V21 migration file
// uses idempotent markers everywhere so re-running against an already-migrated
// DB is safe (the existing postgres_migrate.addColumnIfMissing helper inspects
// information_schema, but the .sql file must also be safe to re-apply via
// goose).
func TestV21LevelsMigration_IsIdempotent(t *testing.T) {
	path := findMigration(t, "025_v21_cefr_levels.sql")

	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read migration: %v", err)
	}
	sql := string(raw)

	mustContain(t, sql, "IF NOT EXISTS")
	// Every ALTER TABLE ADD COLUMN must use IF NOT EXISTS — count must match
	// the column-add count to make sure none were forgotten.
	addCount := strings.Count(sql, "ADD COLUMN ")
	idempotentAdds := strings.Count(sql, "ADD COLUMN IF NOT EXISTS")
	if addCount != idempotentAdds {
		t.Errorf("non-idempotent ADD COLUMN found: %d total, %d idempotent",
			addCount, idempotentAdds)
	}

	// CREATE INDEX statements should also be idempotent.
	createIdx := strings.Count(sql, "CREATE INDEX ")
	idempotentIdx := strings.Count(sql, "CREATE INDEX IF NOT EXISTS")
	if createIdx != idempotentIdx {
		t.Errorf("non-idempotent CREATE INDEX found: %d total, %d idempotent",
			createIdx, idempotentIdx)
	}
}
