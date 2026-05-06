package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"sort"
	"sync"
	"time"

	"github.com/lib/pq"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// UserLevelStore owns the V21 CEFR gating state attached to each user
// account. The data lives on the existing users table (added by migration
// 025) but the store is intentionally kept separate from UserStore so the
// gating surface can change without dragging the auth contract along.
//
// Auto-default semantics: SetUserLevel and MarkPlacementTaken transparently
// initialise a new row with current_level=a0, unlocked_levels=[a0],
// placement_taken_at=nil if the user has no row yet. GetUserLevel does
// not auto-create — callers see ok=false for users they have not yet
// promoted or placed.
type UserLevelStore interface {
	GetUserLevel(userID string) (contracts.UserLevel, bool)
	SetUserLevel(userID string, target string) (contracts.UserLevel, error)
	MarkPlacementTaken(userID string, assignedLevel string, takenAt time.Time) (contracts.UserLevel, error)
}

// ── Memory implementation ──────────────────────────────────────────────────

type memoryUserLevelStore struct {
	mu   sync.RWMutex
	rows map[string]contracts.UserLevel
}

func newMemoryUserLevelStore() *memoryUserLevelStore {
	return &memoryUserLevelStore{rows: map[string]contracts.UserLevel{}}
}

// NewMemoryUserLevelStore returns a fresh in-memory level store. Exported
// so dev/test wiring outside this package can swap in a memory backend.
func NewMemoryUserLevelStore() UserLevelStore { return newMemoryUserLevelStore() }

func (s *memoryUserLevelStore) GetUserLevel(userID string) (contracts.UserLevel, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	row, ok := s.rows[userID]
	if !ok {
		// Return the same zero defaults the Postgres column defaults
		// produce so callers can ignore ok and still get a sane shape.
		return contracts.UserLevel{
			UserID:         userID,
			CurrentLevel:   "a0",
			UnlockedLevels: []string{"a0"},
		}, false
	}
	return cloneUserLevel(row), true
}

func (s *memoryUserLevelStore) SetUserLevel(userID, target string) (contracts.UserLevel, error) {
	if userID == "" {
		return contracts.UserLevel{}, errors.New("user_id required")
	}
	if target == "" {
		return contracts.UserLevel{}, errors.New("target level required")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	row := s.ensureLocked(userID)
	row.CurrentLevel = target
	row.UnlockedLevels = appendUniqueSorted(row.UnlockedLevels, target)
	s.rows[userID] = row
	return cloneUserLevel(row), nil
}

func (s *memoryUserLevelStore) MarkPlacementTaken(userID, assignedLevel string, takenAt time.Time) (contracts.UserLevel, error) {
	if userID == "" {
		return contracts.UserLevel{}, errors.New("user_id required")
	}
	if assignedLevel == "" {
		return contracts.UserLevel{}, errors.New("assigned level required")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	row := s.ensureLocked(userID)
	row.CurrentLevel = assignedLevel
	row.UnlockedLevels = appendUniqueSorted(row.UnlockedLevels, assignedLevel)
	taken := takenAt
	row.PlacementTakenAt = &taken
	s.rows[userID] = row
	return cloneUserLevel(row), nil
}

// ensureLocked returns the row for userID, creating it with defaults when
// missing. Caller must hold s.mu in write mode.
func (s *memoryUserLevelStore) ensureLocked(userID string) contracts.UserLevel {
	if row, ok := s.rows[userID]; ok {
		return row
	}
	return contracts.UserLevel{
		UserID:         userID,
		CurrentLevel:   "a0",
		UnlockedLevels: []string{"a0"},
	}
}

// appendUniqueSorted returns the union of the existing levels and target,
// sorted ascending. The Postgres backend uses `array_append` with a guard
// so the in-memory and SQL paths agree on shape.
func appendUniqueSorted(existing []string, target string) []string {
	for _, l := range existing {
		if l == target {
			out := append([]string(nil), existing...)
			sort.Strings(out)
			return out
		}
	}
	out := append(append([]string(nil), existing...), target)
	sort.Strings(out)
	return out
}

func cloneUserLevel(in contracts.UserLevel) contracts.UserLevel {
	out := in
	if in.UnlockedLevels != nil {
		out.UnlockedLevels = append([]string(nil), in.UnlockedLevels...)
	}
	if in.PlacementTakenAt != nil {
		t := *in.PlacementTakenAt
		out.PlacementTakenAt = &t
	}
	return out
}

// ── Postgres implementation ────────────────────────────────────────────────

type postgresUserLevelStore struct{ db *sql.DB }

// NewPostgresUserLevelStoreWithDB wraps an existing *sql.DB. The level
// columns live on the users table (created by migration 025) so this
// constructor does not run any schema DDL — callers must ensure
// postgresUserStore.ensureSchema has already run.
func NewPostgresUserLevelStoreWithDB(db *sql.DB) UserLevelStore {
	return &postgresUserLevelStore{db: db}
}

func (s *postgresUserLevelStore) GetUserLevel(userID string) (contracts.UserLevel, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	row := s.db.QueryRowContext(ctx, `
SELECT id, current_level, unlocked_levels, placement_taken_at
FROM users
WHERE id = $1 AND deleted_at IS NULL
`, userID)
	out, err := scanUserLevel(row)
	if err != nil {
		return contracts.UserLevel{
			UserID:         userID,
			CurrentLevel:   "a0",
			UnlockedLevels: []string{"a0"},
		}, false
	}
	return out, true
}

func (s *postgresUserLevelStore) SetUserLevel(userID, target string) (contracts.UserLevel, error) {
	if userID == "" {
		return contracts.UserLevel{}, errors.New("user_id required")
	}
	if target == "" {
		return contracts.UserLevel{}, errors.New("target level required")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	row := s.db.QueryRowContext(ctx, `
UPDATE users
SET current_level   = $2,
    unlocked_levels = CASE
        WHEN $2 = ANY(unlocked_levels) THEN unlocked_levels
        ELSE array_append(unlocked_levels, $2)
    END,
    updated_at      = now()
WHERE id = $1 AND deleted_at IS NULL
RETURNING id, current_level, unlocked_levels, placement_taken_at
`, userID, target)
	out, err := scanUserLevel(row)
	if err != nil {
		return contracts.UserLevel{}, fmt.Errorf("set user level: %w", err)
	}
	return out, nil
}

func (s *postgresUserLevelStore) MarkPlacementTaken(userID, assignedLevel string, takenAt time.Time) (contracts.UserLevel, error) {
	if userID == "" {
		return contracts.UserLevel{}, errors.New("user_id required")
	}
	if assignedLevel == "" {
		return contracts.UserLevel{}, errors.New("assigned level required")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	row := s.db.QueryRowContext(ctx, `
UPDATE users
SET current_level      = $2,
    unlocked_levels    = CASE
        WHEN $2 = ANY(unlocked_levels) THEN unlocked_levels
        ELSE array_append(unlocked_levels, $2)
    END,
    placement_taken_at = $3,
    updated_at         = now()
WHERE id = $1 AND deleted_at IS NULL
RETURNING id, current_level, unlocked_levels, placement_taken_at
`, userID, assignedLevel, takenAt)
	out, err := scanUserLevel(row)
	if err != nil {
		return contracts.UserLevel{}, fmt.Errorf("mark placement taken: %w", err)
	}
	return out, nil
}

func scanUserLevel(row interface {
	Scan(dest ...any) error
}) (contracts.UserLevel, error) {
	var (
		id          string
		current     string
		unlocked    pq.StringArray
		placementAt sql.NullTime
	)
	if err := row.Scan(&id, &current, &unlocked, &placementAt); err != nil {
		return contracts.UserLevel{}, err
	}
	out := contracts.UserLevel{
		UserID:         id,
		CurrentLevel:   current,
		UnlockedLevels: append([]string(nil), unlocked...),
	}
	sort.Strings(out.UnlockedLevels)
	if placementAt.Valid {
		t := placementAt.Time
		out.PlacementTakenAt = &t
	}
	return out, nil
}
