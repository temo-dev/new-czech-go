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
	"log"
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
	// pgPingRetries is the number of ping attempts before giving up. With
	// pgPingBackoff the worst case is 1+2+4+8+16 = 31s of waiting before
	// the process exits and Docker restarts it. This breaks the crash-loop
	// pattern where Postgres briefly returns "remaining connection slots"
	// during instance maintenance or while another tenant frees its
	// connections.
	pgPingRetries = 5
	pgPingBackoff = 1 * time.Second
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

	if err := pingWithBackoff(db, label); err != nil {
		db.Close()
		return nil, err
	}
	return db, nil
}

// pingWithBackoff retries Postgres pings with exponential backoff so a
// transient "remaining connection slots are reserved" response (RDS
// maintenance, another tenant draining its pool) doesn't immediately crash
// the process. Each retry doubles the wait. After pgPingRetries attempts
// the function returns the last error and lets the caller surface it.
func pingWithBackoff(db *sql.DB, label string) error {
	wait := pgPingBackoff
	var lastErr error
	for attempt := 1; attempt <= pgPingRetries; attempt++ {
		ctx, cancel := context.WithTimeout(context.Background(), pgPingTimeout)
		err := db.PingContext(ctx)
		cancel()
		if err == nil {
			if attempt > 1 {
				log.Printf("postgres pool %s: ping ok after %d attempts", label, attempt)
			}
			return nil
		}
		lastErr = err
		if attempt < pgPingRetries {
			log.Printf("postgres pool %s: ping attempt %d/%d failed: %v; retrying in %s",
				label, attempt, pgPingRetries, err, wait)
			time.Sleep(wait)
			wait *= 2
		}
	}
	return fmt.Errorf("ping postgres for %s after %d attempts: %w", label, pgPingRetries, lastErr)
}
