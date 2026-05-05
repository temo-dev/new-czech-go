package store

// postgres_pool.go — shared `*sql.DB` pool builder for every Postgres-backed
// store in this package.
//
// Why centralize:
//
// Each store used to call `sql.Open` directly with no `SetMax*` calls. Go's
// `database/sql` defaults `MaxOpenConns` to **unlimited**, so 12 stores on a
// shared RDS could spike to dozens of connections under load and exhaust the
// instance. On 2026-05-06 that surfaced on EC2 as a crash loop:
//
//   pq: remaining connection slots are reserved for roles with privileges of
//   the "pg_use_reserved_connections" role
//
// Every restart re-opened pools, made the situation worse, and never
// stabilised. Capping each pool to a small ceiling fixes the symptom; a
// future refactor can collapse the 12 pools into one shared `*sql.DB`.
//
// Tuning: this app is a low-QPS learner experience (one POST per submit, a
// handful of polls per minute per learner). 2 open connections per store is
// plenty even at peak. With 12 stores that caps the app at 24 connections —
// well under any reasonable RDS instance ceiling, and leaves headroom for
// other tenants on a shared instance (e.g., Odoo on the same RDS).

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	_ "github.com/lib/pq"
)

const (
	// pgMaxOpenConns is the per-store ceiling for in-use + idle connections.
	// Keep this small: every distinct *sql.DB in the process gets its own
	// pool, so the effective connection budget is `pgMaxOpenConns × number
	// of stores`. Bump only after checking RDS `max_connections`.
	pgMaxOpenConns = 2
	// pgMaxIdleConns caps idle warm connections. Keeping one warm avoids
	// the TLS-handshake hit on the next request without holding a slot
	// open across long quiet periods.
	pgMaxIdleConns = 1
	// pgConnMaxLifetime forces a recycle so RDS-side `idle_in_transaction`
	// timeouts and connection-killing maintenance windows don't surface as
	// stale-connection errors mid-request.
	pgConnMaxLifetime = 30 * time.Minute
	// pgConnMaxIdleTime closes idle connections sooner than the lifetime
	// cap so quiet processes free their share back to the instance.
	pgConnMaxIdleTime = 5 * time.Minute
	// pgPingTimeout bounds the at-startup connectivity check.
	pgPingTimeout = 5 * time.Second
)

// openPostgresPool opens a `*sql.DB`, applies the per-store pool ceilings,
// and pings to fail fast on bad credentials / unreachable hosts. Every
// Postgres store in this package should call this instead of `sql.Open`
// directly.
//
// `label` shows up in error messages so callers can tell which pool failed
// when several stores boot in parallel.
func openPostgresPool(databaseURL string, label string) (*sql.DB, error) {
	db, err := sql.Open("postgres", databaseURL)
	if err != nil {
		return nil, fmt.Errorf("open postgres for %s: %w", label, err)
	}
	db.SetMaxOpenConns(pgMaxOpenConns)
	db.SetMaxIdleConns(pgMaxIdleConns)
	db.SetConnMaxLifetime(pgConnMaxLifetime)
	db.SetConnMaxIdleTime(pgConnMaxIdleTime)

	ctx, cancel := context.WithTimeout(context.Background(), pgPingTimeout)
	defer cancel()
	if err := db.PingContext(ctx); err != nil {
		db.Close()
		return nil, fmt.Errorf("ping postgres for %s: %w", label, err)
	}
	return db, nil
}
