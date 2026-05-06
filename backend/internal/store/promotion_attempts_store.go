package store

import (
	"context"
	"database/sql"
	"fmt"
)

// ensurePromotionAttemptsSchema creates the V21 promotion_attempts table if
// it does not already exist. The table tracks every promotion attempt a
// learner makes against a level-up MockTest (per docs/specs/cefr-level-progression.md).
//
// Sequencing note: the table has FKs to users(id) and mock_tests(id), so this
// helper is invoked from postgresUserStore.ensureSchema (which runs after
// mock_tests has already been ensured by NewPostgresMockTestStore in the API
// bootstrap). This matches the V17 pattern in 023_users.sql where every
// table that cascades on user delete is co-located with the users schema.
//
// CRUD methods land in V21-B2; this file currently exposes only the schema
// helper so the table is guaranteed to exist by the time those methods are
// added.
func ensurePromotionAttemptsSchema(ctx context.Context, db *sql.DB) error {
	if _, err := db.ExecContext(ctx, `
CREATE TABLE IF NOT EXISTS promotion_attempts (
    id              TEXT        PRIMARY KEY,
    user_id         TEXT        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    mock_test_id    TEXT        NOT NULL REFERENCES mock_tests(id) ON DELETE CASCADE,
    source_level    TEXT        NOT NULL,
    target_level    TEXT        NOT NULL,
    full_session_id TEXT        NOT NULL DEFAULT '',
    passed          BOOLEAN     NOT NULL DEFAULT FALSE,
    score_pct       NUMERIC(5,2) NOT NULL DEFAULT 0,
    per_skill_pct   JSONB       NOT NULL DEFAULT '{}'::jsonb,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS promotion_attempts_user_idx
    ON promotion_attempts (user_id, target_level, created_at DESC);
`); err != nil {
		return fmt.Errorf("ensure promotion_attempts schema: %w", err)
	}
	return nil
}
