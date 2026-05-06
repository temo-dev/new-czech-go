package store

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"errors"
	"fmt"
	"sort"
	"sync"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// SkillMasteryStore persists EMA-smoothed mastery rows for the user_skill_mastery
// aggregate (V19). Keyed by (user_id, skill_kind, module_id) with module_id=""
// reserved for exam-pool attempts so the unique index still holds.
//
// Upsert returns the persisted row including the assigned ID; the caller then
// surfaces it through the progress API. The interface is small on purpose —
// recommendation, spaced repetition, and confidence_score are explicitly
// out of scope for V19.
type SkillMasteryStore interface {
	GetForKey(userID, skillKind, moduleID string) (contracts.SkillMasteryRow, bool)
	Upsert(row contracts.SkillMasteryRow) (contracts.SkillMasteryRow, error)
	ListForUser(userID string) []contracts.SkillMasteryRow
}

// ── Memory implementation ────────────────────────────────────────────────

type memorySkillMasteryStore struct {
	mu   sync.RWMutex
	rows map[string]contracts.SkillMasteryRow // keyed by composite key string
}

func newMemorySkillMasteryStore() *memorySkillMasteryStore {
	return &memorySkillMasteryStore{rows: map[string]contracts.SkillMasteryRow{}}
}

// NewMemorySkillMasteryStore returns a fresh in-memory mastery store. Exported
// for dev/test wiring outside this package.
func NewMemorySkillMasteryStore() SkillMasteryStore { return newMemorySkillMasteryStore() }

func masteryKey(userID, skillKind, moduleID string) string {
	return userID + "\x1f" + skillKind + "\x1f" + moduleID
}

func validateMasteryKey(r contracts.SkillMasteryRow) error {
	if r.UserID == "" {
		return errors.New("user_id required")
	}
	if r.SkillKind == "" {
		return errors.New("skill_kind required")
	}
	return nil
}

func (s *memorySkillMasteryStore) Upsert(row contracts.SkillMasteryRow) (contracts.SkillMasteryRow, error) {
	if err := validateMasteryKey(row); err != nil {
		return contracts.SkillMasteryRow{}, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()

	key := masteryKey(row.UserID, row.SkillKind, row.ModuleID)
	existing, ok := s.rows[key]
	if ok {
		row.ID = existing.ID
		// Preserve CreatedAt across updates; callers shouldn't rewrite it.
		row.CreatedAt = existing.CreatedAt
	} else {
		if row.ID == "" {
			row.ID = newSkillMasteryID()
		}
		if row.CreatedAt.IsZero() {
			row.CreatedAt = row.UpdatedAt
		}
	}
	s.rows[key] = row
	return row, nil
}

func (s *memorySkillMasteryStore) GetForKey(userID, skillKind, moduleID string) (contracts.SkillMasteryRow, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	row, ok := s.rows[masteryKey(userID, skillKind, moduleID)]
	return row, ok
}

func (s *memorySkillMasteryStore) ListForUser(userID string) []contracts.SkillMasteryRow {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]contracts.SkillMasteryRow, 0)
	for _, r := range s.rows {
		if r.UserID == userID {
			out = append(out, r)
		}
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].SkillKind != out[j].SkillKind {
			return out[i].SkillKind < out[j].SkillKind
		}
		return out[i].ModuleID < out[j].ModuleID
	})
	return out
}

// newSkillMasteryID returns a 16-byte hex identifier prefixed with "sm_".
// Crypto/rand is used so the in-memory and Postgres backends mint identifiers
// the same way.
func newSkillMasteryID() string {
	var b [16]byte
	if _, err := rand.Read(b[:]); err != nil {
		// Cryptographic randomness is required; this should never fail outside
		// kernel-level breakage. Fall back to a timestamp so a unit test can
		// still proceed deterministically.
		return fmt.Sprintf("sm_%d", time.Now().UnixNano())
	}
	return "sm_" + hex.EncodeToString(b[:])
}

// ── Postgres implementation ──────────────────────────────────────────────

type postgresSkillMasteryStore struct{ db *sql.DB }

// NewPostgresSkillMasteryStoreWithDB wraps an existing *sql.DB and ensures the
// user_skill_mastery schema exists.
func NewPostgresSkillMasteryStoreWithDB(db *sql.DB) (SkillMasteryStore, error) {
	store := &postgresSkillMasteryStore{db: db}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := store.ensureSchema(ctx); err != nil {
		return nil, fmt.Errorf("ensure user_skill_mastery schema: %w", err)
	}
	return store, nil
}

func (s *postgresSkillMasteryStore) ensureSchema(ctx context.Context) error {
	_, err := s.db.ExecContext(ctx, `
CREATE TABLE IF NOT EXISTS user_skill_mastery (
    id              TEXT             PRIMARY KEY,
    user_id         TEXT             NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    skill_kind      TEXT             NOT NULL,
    module_id       TEXT             NOT NULL DEFAULT '',
    mastery_score   DOUBLE PRECISION NOT NULL DEFAULT 0,
    attempts_count  INTEGER          NOT NULL DEFAULT 0,
    last_attempt_id TEXT             NOT NULL DEFAULT '',
    last_attempt_at TIMESTAMPTZ,
    created_at      TIMESTAMPTZ      NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ      NOT NULL DEFAULT now(),
    CONSTRAINT user_skill_mastery_uniq UNIQUE (user_id, skill_kind, module_id)
);
CREATE INDEX IF NOT EXISTS user_skill_mastery_user_updated
    ON user_skill_mastery (user_id, updated_at DESC);
`)
	return err
}

func (s *postgresSkillMasteryStore) Upsert(row contracts.SkillMasteryRow) (contracts.SkillMasteryRow, error) {
	if err := validateMasteryKey(row); err != nil {
		return contracts.SkillMasteryRow{}, err
	}
	if row.ID == "" {
		row.ID = newSkillMasteryID()
	}
	if row.UpdatedAt.IsZero() {
		row.UpdatedAt = time.Now().UTC()
	}
	if row.CreatedAt.IsZero() {
		row.CreatedAt = row.UpdatedAt
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var lastAttemptAt sql.NullTime
	if !row.LastAttemptAt.IsZero() {
		lastAttemptAt = sql.NullTime{Time: row.LastAttemptAt, Valid: true}
	}

	q := `
INSERT INTO user_skill_mastery (
    id, user_id, skill_kind, module_id,
    mastery_score, attempts_count,
    last_attempt_id, last_attempt_at,
    created_at, updated_at
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
ON CONFLICT (user_id, skill_kind, module_id) DO UPDATE SET
    mastery_score   = EXCLUDED.mastery_score,
    attempts_count  = EXCLUDED.attempts_count,
    last_attempt_id = EXCLUDED.last_attempt_id,
    last_attempt_at = EXCLUDED.last_attempt_at,
    updated_at      = EXCLUDED.updated_at
RETURNING id, created_at
`
	var (
		id        string
		createdAt time.Time
	)
	if err := s.db.QueryRowContext(ctx, q,
		row.ID, row.UserID, row.SkillKind, row.ModuleID,
		row.MasteryScore, row.AttemptsCount,
		row.LastAttemptID, lastAttemptAt,
		row.CreatedAt, row.UpdatedAt,
	).Scan(&id, &createdAt); err != nil {
		return contracts.SkillMasteryRow{}, fmt.Errorf("upsert mastery: %w", err)
	}
	row.ID = id
	row.CreatedAt = createdAt
	return row, nil
}

func (s *postgresSkillMasteryStore) GetForKey(userID, skillKind, moduleID string) (contracts.SkillMasteryRow, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	row := s.db.QueryRowContext(ctx, `
SELECT id, user_id, skill_kind, module_id, mastery_score, attempts_count,
       last_attempt_id, last_attempt_at, created_at, updated_at
FROM user_skill_mastery
WHERE user_id = $1 AND skill_kind = $2 AND module_id = $3
`, userID, skillKind, moduleID)
	r, err := scanSkillMasteryRow(row)
	if err != nil {
		return contracts.SkillMasteryRow{}, false
	}
	return r, true
}

func (s *postgresSkillMasteryStore) ListForUser(userID string) []contracts.SkillMasteryRow {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	rows, err := s.db.QueryContext(ctx, `
SELECT id, user_id, skill_kind, module_id, mastery_score, attempts_count,
       last_attempt_id, last_attempt_at, created_at, updated_at
FROM user_skill_mastery
WHERE user_id = $1
ORDER BY skill_kind ASC, module_id ASC
`, userID)
	if err != nil {
		return nil
	}
	defer rows.Close()
	out := make([]contracts.SkillMasteryRow, 0)
	for rows.Next() {
		r, err := scanSkillMasteryRow(rows)
		if err != nil {
			return nil
		}
		out = append(out, r)
	}
	return out
}

// scanSkillMasteryRow accepts both *sql.Row and *sql.Rows via the shared
// Scan signature so single-row and multi-row paths share parsing.
type rowScanner interface {
	Scan(dest ...any) error
}

func scanSkillMasteryRow(r rowScanner) (contracts.SkillMasteryRow, error) {
	var (
		row           contracts.SkillMasteryRow
		lastAttemptAt sql.NullTime
	)
	if err := r.Scan(
		&row.ID, &row.UserID, &row.SkillKind, &row.ModuleID,
		&row.MasteryScore, &row.AttemptsCount,
		&row.LastAttemptID, &lastAttemptAt,
		&row.CreatedAt, &row.UpdatedAt,
	); err != nil {
		return contracts.SkillMasteryRow{}, err
	}
	if lastAttemptAt.Valid {
		row.LastAttemptAt = lastAttemptAt.Time
	}
	return row, nil
}
