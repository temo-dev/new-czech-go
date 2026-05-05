package store

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	_ "github.com/lib/pq"
)

// V17 store URL-based constructors. The WithDB variants accept an
// existing *sql.DB; these wrappers open a fresh pool from a Postgres
// URL the same way NewPostgresAttemptStore et al. do, so cmd/api/main.go
// can wire them with the same per-store pool pattern.

func openPostgresPool(databaseURL string, label string) (*sql.DB, error) {
	db, err := sql.Open("postgres", databaseURL)
	if err != nil {
		return nil, fmt.Errorf("open postgres for %s: %w", label, err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := db.PingContext(ctx); err != nil {
		db.Close()
		return nil, fmt.Errorf("ping postgres for %s: %w", label, err)
	}
	return db, nil
}

// NewPostgresAuthTokenStore opens a fresh pool + ensures the schema.
func NewPostgresAuthTokenStore(databaseURL string) (AuthTokenStore, error) {
	db, err := openPostgresPool(databaseURL, "auth_tokens")
	if err != nil {
		return nil, err
	}
	store, err := NewPostgresAuthTokenStoreWithDB(db)
	if err != nil {
		db.Close()
		return nil, err
	}
	return store, nil
}

// NewPostgresStreakStore opens a fresh pool + ensures the schema.
func NewPostgresStreakStore(databaseURL string) (StreakStore, error) {
	db, err := openPostgresPool(databaseURL, "streak_days")
	if err != nil {
		return nil, err
	}
	store, err := NewPostgresStreakStoreWithDB(db)
	if err != nil {
		db.Close()
		return nil, err
	}
	return store, nil
}

// NewPostgresProPurchaseStore opens a fresh pool + ensures the schema.
func NewPostgresProPurchaseStore(databaseURL string) (ProPurchaseStore, error) {
	db, err := openPostgresPool(databaseURL, "pro_purchases")
	if err != nil {
		return nil, err
	}
	store, err := NewPostgresProPurchaseStoreWithDB(db)
	if err != nil {
		db.Close()
		return nil, err
	}
	return store, nil
}

// NewPostgresDailyUsageStore opens a fresh pool + ensures the schema.
func NewPostgresDailyUsageStore(databaseURL string) (DailyUsageStore, error) {
	db, err := openPostgresPool(databaseURL, "daily_usage")
	if err != nil {
		return nil, err
	}
	store, err := NewPostgresDailyUsageStoreWithDB(db)
	if err != nil {
		db.Close()
		return nil, err
	}
	return store, nil
}
