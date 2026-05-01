package store

import (
	"context"
	"database/sql"
	"fmt"
)

// addColumnIfMissing adds a column to a table only when it doesn't already exist.
// It checks information_schema before attempting ALTER TABLE, so it works even
// when the DB user is not the table owner (e.g. RDS where tables were created by
// a different role during initial goose migrations).
func addColumnIfMissing(ctx context.Context, db *sql.DB, table, column, definition string) error {
	var exists bool
	err := db.QueryRowContext(ctx,
		`SELECT EXISTS (
			SELECT 1 FROM information_schema.columns
			WHERE table_name = $1 AND column_name = $2
		)`, table, column,
	).Scan(&exists)
	if err != nil {
		return fmt.Errorf("check column %s.%s: %w", table, column, err)
	}
	if exists {
		return nil
	}
	if _, err := db.ExecContext(ctx,
		fmt.Sprintf(`ALTER TABLE %s ADD COLUMN %s %s`, table, column, definition),
	); err != nil {
		return fmt.Errorf("alter table %s add %s: %w", table, column, err)
	}
	return nil
}
