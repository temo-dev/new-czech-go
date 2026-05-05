package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"sort"
	"sync"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// vnLocation is the authoritative timezone for streak day boundaries.
// Loaded once and reused; if the host lacks tzdata the constructor that
// uses it should fail loudly so the bug surfaces in dev rather than
// silently shifting day boundaries to UTC.
var vnLocation = mustLoadVN()

func mustLoadVN() *time.Location {
	loc, err := time.LoadLocation("Asia/Ho_Chi_Minh")
	if err != nil {
		// Fallback to a fixed +07:00 offset so local-only dev hosts
		// without IANA tzdata still get a usable streak day boundary.
		return time.FixedZone("VN", 7*60*60)
	}
	return loc
}

// vnCivilDay normalizes any timestamp into the VN civil date midnight.
// Two attempts on the same VN calendar day collapse to a single key.
func vnCivilDay(t time.Time) time.Time {
	local := t.In(vnLocation)
	return time.Date(local.Year(), local.Month(), local.Day(), 0, 0, 0, 0, vnLocation)
}

// StreakStore tracks per-day completion + grace-pass usage for streak
// computation. Writes are idempotent; reads are scoped to a date range
// because the Home ring and the history calendar both want a window.
type StreakStore interface {
	MarkDayCompleted(userID string, day time.Time) error
	ApplyGracePass(userID string, day time.Time) error
	StreakDaysByUserBetween(userID string, from, to time.Time) ([]contracts.StreakDay, error)
	StreakSummary(userID string, asOfDay time.Time) (contracts.StreakSummary, error)
}

// ── Memory implementation ────────────────────────────────────────────────

type memoryStreakStore struct {
	mu   sync.RWMutex
	days map[string]map[time.Time]*contracts.StreakDay // userID -> day -> row
}

func newMemoryStreakStore() StreakStore {
	return &memoryStreakStore{days: map[string]map[time.Time]*contracts.StreakDay{}}
}

func (s *memoryStreakStore) upsert(userID string, day time.Time, mutate func(*contracts.StreakDay)) {
	canonical := vnCivilDay(day)
	s.mu.Lock()
	defer s.mu.Unlock()
	bucket, ok := s.days[userID]
	if !ok {
		bucket = map[time.Time]*contracts.StreakDay{}
		s.days[userID] = bucket
	}
	row, ok := bucket[canonical]
	if !ok {
		row = &contracts.StreakDay{
			UserID:    userID,
			Day:       canonical,
			CreatedAt: time.Now().UTC(),
		}
		bucket[canonical] = row
	}
	mutate(row)
}

func (s *memoryStreakStore) MarkDayCompleted(userID string, day time.Time) error {
	if userID == "" {
		return errors.New("user_id required")
	}
	s.upsert(userID, day, func(d *contracts.StreakDay) { d.Completed = true })
	return nil
}

func (s *memoryStreakStore) ApplyGracePass(userID string, day time.Time) error {
	if userID == "" {
		return errors.New("user_id required")
	}
	s.upsert(userID, day, func(d *contracts.StreakDay) { d.GraceUsed = true })
	return nil
}

func (s *memoryStreakStore) StreakDaysByUserBetween(userID string, from, to time.Time) ([]contracts.StreakDay, error) {
	fromDay := vnCivilDay(from)
	toDay := vnCivilDay(to)

	s.mu.RLock()
	defer s.mu.RUnlock()
	bucket, ok := s.days[userID]
	if !ok {
		return nil, nil
	}
	var out []contracts.StreakDay
	for _, row := range bucket {
		if row.Day.Before(fromDay) || row.Day.After(toDay) {
			continue
		}
		out = append(out, *row)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Day.Before(out[j].Day) })
	return out, nil
}

func (s *memoryStreakStore) StreakSummary(userID string, asOfDay time.Time) (contracts.StreakSummary, error) {
	asOf := vnCivilDay(asOfDay)

	s.mu.RLock()
	defer s.mu.RUnlock()

	bucket, ok := s.days[userID]
	if !ok || len(bucket) == 0 {
		return contracts.StreakSummary{}, nil
	}
	rows := make([]contracts.StreakDay, 0, len(bucket))
	for _, r := range bucket {
		rows = append(rows, *r)
	}
	return computeStreakSummary(rows, asOf), nil
}

// computeStreakSummary is the pure function the memory store and (later)
// the Postgres adapter both call. Splitting it out makes timezone +
// edge-case behavior testable without a database.
func computeStreakSummary(rows []contracts.StreakDay, asOf time.Time) contracts.StreakSummary {
	if len(rows) == 0 {
		return contracts.StreakSummary{}
	}

	sort.Slice(rows, func(i, j int) bool { return rows[i].Day.Before(rows[j].Day) })

	// Index rows by canonical day for O(1) walk.
	byDay := make(map[time.Time]contracts.StreakDay, len(rows))
	for _, r := range rows {
		byDay[r.Day] = r
	}

	// Longest run = max consecutive days where Completed OR GraceUsed.
	var longest, run int
	var lastDay time.Time
	for _, r := range rows {
		active := r.Completed || r.GraceUsed
		if !active {
			run = 0
			continue
		}
		if !lastDay.IsZero() && r.Day.Sub(lastDay) == 24*time.Hour {
			run++
		} else {
			run = 1
		}
		if run > longest {
			longest = run
		}
		lastDay = r.Day
	}

	// Current run = consecutive active days ending at asOf, walking back.
	current := 0
	for d := asOf; ; d = d.AddDate(0, 0, -1) {
		row, ok := byDay[d]
		if !ok || (!row.Completed && !row.GraceUsed) {
			break
		}
		current++
	}

	// Find the most recent Completed day (not just GraceUsed) for the
	// summary's last_completed_day field. Walks rows in reverse.
	var lastCompleted time.Time
	for i := len(rows) - 1; i >= 0; i-- {
		if rows[i].Completed {
			lastCompleted = rows[i].Day
			break
		}
	}

	// ISO week of asOf (Monday-anchored) bounds the grace-pass counter.
	weekStart, weekEnd := isoWeekBounds(asOf)
	var gracePasses int
	for _, r := range rows {
		if r.GraceUsed && !r.Day.Before(weekStart) && !r.Day.After(weekEnd) {
			gracePasses++
		}
	}

	return contracts.StreakSummary{
		Current:                 current,
		Longest:                 longest,
		LastCompletedDay:        lastCompleted,
		GracePassesUsedThisWeek: gracePasses,
	}
}

// isoWeekBounds returns Monday and Sunday (inclusive) of the ISO week
// containing day. Day is assumed to be a VN civil date midnight.
func isoWeekBounds(day time.Time) (time.Time, time.Time) {
	weekday := int(day.Weekday()) // Sunday=0..Saturday=6
	if weekday == 0 {
		weekday = 7 // Monday=1..Sunday=7
	}
	monday := day.AddDate(0, 0, -(weekday - 1))
	sunday := monday.AddDate(0, 0, 6)
	return monday, sunday
}

// ── Postgres implementation ──────────────────────────────────────────────

type postgresStreakStore struct{ db *sql.DB }

// NewPostgresStreakStoreWithDB wraps an existing *sql.DB.
func NewPostgresStreakStoreWithDB(db *sql.DB) (StreakStore, error) {
	store := &postgresStreakStore{db: db}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := store.ensureSchema(ctx); err != nil {
		return nil, fmt.Errorf("ensure streak schema: %w", err)
	}
	return store, nil
}

func (s *postgresStreakStore) ensureSchema(ctx context.Context) error {
	_, err := s.db.ExecContext(ctx, `
CREATE TABLE IF NOT EXISTS streak_days (
    user_id    TEXT        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    day        DATE        NOT NULL,
    completed  BOOLEAN     NOT NULL DEFAULT FALSE,
    grace_used BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, day)
);

CREATE INDEX IF NOT EXISTS streak_days_user_day_idx
    ON streak_days (user_id, day DESC);
`)
	return err
}

func (s *postgresStreakStore) MarkDayCompleted(userID string, day time.Time) error {
	canonical := vnCivilDay(day)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_, err := s.db.ExecContext(ctx, `
INSERT INTO streak_days (user_id, day, completed) VALUES ($1, $2, TRUE)
ON CONFLICT (user_id, day) DO UPDATE SET completed = TRUE
`, userID, canonical)
	return err
}

func (s *postgresStreakStore) ApplyGracePass(userID string, day time.Time) error {
	canonical := vnCivilDay(day)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_, err := s.db.ExecContext(ctx, `
INSERT INTO streak_days (user_id, day, grace_used) VALUES ($1, $2, TRUE)
ON CONFLICT (user_id, day) DO UPDATE SET grace_used = TRUE
`, userID, canonical)
	return err
}

func (s *postgresStreakStore) StreakDaysByUserBetween(userID string, from, to time.Time) ([]contracts.StreakDay, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	rows, err := s.db.QueryContext(ctx, `
SELECT user_id, day, completed, grace_used, created_at
FROM streak_days
WHERE user_id = $1 AND day BETWEEN $2 AND $3
ORDER BY day
`, userID, vnCivilDay(from), vnCivilDay(to))
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []contracts.StreakDay
	for rows.Next() {
		var d contracts.StreakDay
		if err := rows.Scan(&d.UserID, &d.Day, &d.Completed, &d.GraceUsed, &d.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, d)
	}
	return out, rows.Err()
}

func (s *postgresStreakStore) StreakSummary(userID string, asOfDay time.Time) (contracts.StreakSummary, error) {
	// Pull the trailing 13 weeks (~91 days) of activity — enough for the
	// longest plausible streak the UI shows on the calendar heatmap. The
	// pure summary function then walks the rows.
	asOf := vnCivilDay(asOfDay)
	from := asOf.AddDate(0, 0, -13*7)
	rows, err := s.StreakDaysByUserBetween(userID, from, asOf)
	if err != nil {
		return contracts.StreakSummary{}, err
	}
	return computeStreakSummary(rows, asOf), nil
}
