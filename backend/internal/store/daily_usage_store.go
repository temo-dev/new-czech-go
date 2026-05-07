package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"sync"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// DailyUsageStore powers the free-tier rate limit. Increments are atomic
// upserts that return the running counter so the middleware can compare
// against the configured cap in a single round-trip:
//
//	if newCount > limit { return 429 }
//
// The day is normalized to the VN civil date midnight so two requests
// straddling local midnight land on different rows.
type DailyUsageStore interface {
	IncrementAttempts(userID string, day time.Time) (int, error)
	IncrementInterviews(userID string, day time.Time) (int, error)
	DailyUsageByUserDay(userID string, day time.Time) (contracts.DailyUsage, bool)
	// TryIncrementAttempts performs an atomic check-and-increment guarded
	// by cap. When the existing counter is below cap, it bumps and
	// returns (newCount, true, nil). When the counter has reached cap, it
	// leaves the row alone and returns (cap, false, nil) so the gate can
	// emit 429 without inflating the counter on every rejected request.
	// Callers must pass cap > 0; cap == 0 is treated as "always blocked".
	TryIncrementAttempts(userID string, day time.Time, cap int) (int, bool, error)
	// ResetAttempts clears today's attempts_count for an admin-driven
	// reset (QA, support flow). Interview count is left intact.
	ResetAttempts(userID string, day time.Time) error
}

// ── Memory implementation ────────────────────────────────────────────────

type memoryDailyUsageStore struct {
	mu     sync.Mutex
	buckets map[string]map[time.Time]*contracts.DailyUsage // userID -> day -> row
}

func newMemoryDailyUsageStore() DailyUsageStore {
	return &memoryDailyUsageStore{buckets: map[string]map[time.Time]*contracts.DailyUsage{}}
}

// NewMemoryDailyUsageStore returns a fresh in-memory DailyUsageStore.
// Exported for dev/test wiring outside this package.
func NewMemoryDailyUsageStore() DailyUsageStore { return newMemoryDailyUsageStore() }

func (s *memoryDailyUsageStore) row(userID string, day time.Time) *contracts.DailyUsage {
	canonical := vnCivilDay(day)
	bucket, ok := s.buckets[userID]
	if !ok {
		bucket = map[time.Time]*contracts.DailyUsage{}
		s.buckets[userID] = bucket
	}
	r, ok := bucket[canonical]
	if !ok {
		r = &contracts.DailyUsage{UserID: userID, Day: canonical}
		bucket[canonical] = r
	}
	return r
}

func (s *memoryDailyUsageStore) IncrementAttempts(userID string, day time.Time) (int, error) {
	if userID == "" {
		return 0, errors.New("user_id required")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	r := s.row(userID, day)
	r.AttemptsCount++
	return r.AttemptsCount, nil
}

func (s *memoryDailyUsageStore) TryIncrementAttempts(userID string, day time.Time, cap int) (int, bool, error) {
	if userID == "" {
		return 0, false, errors.New("user_id required")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	r := s.row(userID, day)
	if cap <= 0 || r.AttemptsCount >= cap {
		return r.AttemptsCount, false, nil
	}
	r.AttemptsCount++
	return r.AttemptsCount, true, nil
}

func (s *memoryDailyUsageStore) ResetAttempts(userID string, day time.Time) error {
	if userID == "" {
		return errors.New("user_id required")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	canonical := vnCivilDay(day)
	bucket, ok := s.buckets[userID]
	if !ok {
		return nil
	}
	if r, ok := bucket[canonical]; ok {
		r.AttemptsCount = 0
	}
	return nil
}

func (s *memoryDailyUsageStore) IncrementInterviews(userID string, day time.Time) (int, error) {
	if userID == "" {
		return 0, errors.New("user_id required")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	r := s.row(userID, day)
	r.InterviewsCount++
	return r.InterviewsCount, nil
}

func (s *memoryDailyUsageStore) DailyUsageByUserDay(userID string, day time.Time) (contracts.DailyUsage, bool) {
	canonical := vnCivilDay(day)
	s.mu.Lock()
	defer s.mu.Unlock()
	bucket, ok := s.buckets[userID]
	if !ok {
		return contracts.DailyUsage{UserID: userID, Day: canonical}, false
	}
	r, ok := bucket[canonical]
	if !ok {
		return contracts.DailyUsage{UserID: userID, Day: canonical}, false
	}
	return *r, true
}

// ── Postgres implementation ──────────────────────────────────────────────

type postgresDailyUsageStore struct{ db *sql.DB }

// NewPostgresDailyUsageStoreWithDB wraps an existing *sql.DB.
func NewPostgresDailyUsageStoreWithDB(db *sql.DB) (DailyUsageStore, error) {
	store := &postgresDailyUsageStore{db: db}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := store.ensureSchema(ctx); err != nil {
		return nil, fmt.Errorf("ensure daily_usage schema: %w", err)
	}
	return store, nil
}

func (s *postgresDailyUsageStore) ensureSchema(ctx context.Context) error {
	_, err := s.db.ExecContext(ctx, `
CREATE TABLE IF NOT EXISTS daily_usage (
    user_id          TEXT    NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    day              DATE    NOT NULL,
    attempts_count   INTEGER NOT NULL DEFAULT 0,
    interviews_count INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, day)
);
`)
	return err
}

func (s *postgresDailyUsageStore) IncrementAttempts(userID string, day time.Time) (int, error) {
	canonical := vnCivilDay(day)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	row := s.db.QueryRowContext(ctx, `
INSERT INTO daily_usage (user_id, day, attempts_count) VALUES ($1, $2, 1)
ON CONFLICT (user_id, day) DO UPDATE
SET attempts_count = daily_usage.attempts_count + 1
RETURNING attempts_count
`, userID, canonical)
	var count int
	if err := row.Scan(&count); err != nil {
		return 0, fmt.Errorf("increment attempts: %w", err)
	}
	return count, nil
}

// TryIncrementAttempts is the race-safe alternative to IncrementAttempts.
// The CTE bumps the row only when attempts_count < cap and reports back
// whether the bump happened. The fallback SELECT covers the
// already-at-cap case so the caller learns the current value without a
// second round-trip.
func (s *postgresDailyUsageStore) TryIncrementAttempts(userID string, day time.Time, cap int) (int, bool, error) {
	if cap <= 0 {
		current, _ := s.DailyUsageByUserDay(userID, day)
		return current.AttemptsCount, false, nil
	}
	canonical := vnCivilDay(day)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	rows, err := s.db.QueryContext(ctx, `
WITH bump AS (
  INSERT INTO daily_usage (user_id, day, attempts_count) VALUES ($1, $2, 1)
  ON CONFLICT (user_id, day) DO UPDATE
    SET attempts_count = daily_usage.attempts_count + 1
    WHERE daily_usage.attempts_count < $3
  RETURNING attempts_count
)
SELECT attempts_count, true AS granted FROM bump
UNION ALL
SELECT attempts_count, false AS granted FROM daily_usage
  WHERE user_id = $1 AND day = $2 AND NOT EXISTS (SELECT 1 FROM bump)
LIMIT 1
`, userID, canonical, cap)
	if err != nil {
		return 0, false, fmt.Errorf("try increment attempts: %w", err)
	}
	defer rows.Close()
	if !rows.Next() {
		return 0, false, nil
	}
	var count int
	var granted bool
	if err := rows.Scan(&count, &granted); err != nil {
		return 0, false, fmt.Errorf("try increment attempts scan: %w", err)
	}
	return count, granted, nil
}

func (s *postgresDailyUsageStore) ResetAttempts(userID string, day time.Time) error {
	canonical := vnCivilDay(day)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_, err := s.db.ExecContext(ctx, `
UPDATE daily_usage SET attempts_count = 0
WHERE user_id = $1 AND day = $2
`, userID, canonical)
	if err != nil {
		return fmt.Errorf("reset attempts: %w", err)
	}
	return nil
}

func (s *postgresDailyUsageStore) IncrementInterviews(userID string, day time.Time) (int, error) {
	canonical := vnCivilDay(day)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	row := s.db.QueryRowContext(ctx, `
INSERT INTO daily_usage (user_id, day, interviews_count) VALUES ($1, $2, 1)
ON CONFLICT (user_id, day) DO UPDATE
SET interviews_count = daily_usage.interviews_count + 1
RETURNING interviews_count
`, userID, canonical)
	var count int
	if err := row.Scan(&count); err != nil {
		return 0, fmt.Errorf("increment interviews: %w", err)
	}
	return count, nil
}

func (s *postgresDailyUsageStore) DailyUsageByUserDay(userID string, day time.Time) (contracts.DailyUsage, bool) {
	canonical := vnCivilDay(day)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	row := s.db.QueryRowContext(ctx, `
SELECT user_id, day, attempts_count, interviews_count
FROM daily_usage
WHERE user_id = $1 AND day = $2
`, userID, canonical)
	var u contracts.DailyUsage
	if err := row.Scan(&u.UserID, &u.Day, &u.AttemptsCount, &u.InterviewsCount); err != nil {
		return contracts.DailyUsage{UserID: userID, Day: canonical}, false
	}
	return u, true
}
