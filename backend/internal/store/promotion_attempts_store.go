package store

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"sort"
	"sync"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// PromotionAttemptsStore tracks every level-up exam attempt a learner makes.
// The store is **append-only on Create** and the only post-Create mutation
// is MarkResult, which lands once the scoring pipeline finishes (V21-B8
// promotion hook). The cooldown lookup in V21-B6 reads the most recent
// failed row by (user_id, target_level) — backed by the descending
// composite index defined in ensurePromotionAttemptsSchema.
type PromotionAttemptsStore interface {
	Create(in contracts.PromotionAttempt) (contracts.PromotionAttempt, error)
	GetLatestFailedAttempt(userID, targetLevel string) (contracts.PromotionAttempt, bool)
	GetByFullSessionID(sessionID string) (contracts.PromotionAttempt, bool)
	MarkResult(id string, passed bool, scorePct float64, perSkillPct map[string]float64) (contracts.PromotionAttempt, error)
}

// ── Memory implementation ──────────────────────────────────────────────────

type memoryPromotionAttemptsStore struct {
	mu   sync.RWMutex
	rows map[string]contracts.PromotionAttempt
}

func newMemoryPromotionAttemptsStore() *memoryPromotionAttemptsStore {
	return &memoryPromotionAttemptsStore{rows: map[string]contracts.PromotionAttempt{}}
}

// NewMemoryPromotionAttemptsStore returns a fresh in-memory store. Useful for
// the dev/test wiring outside this package.
func NewMemoryPromotionAttemptsStore() PromotionAttemptsStore {
	return newMemoryPromotionAttemptsStore()
}

func (s *memoryPromotionAttemptsStore) Create(in contracts.PromotionAttempt) (contracts.PromotionAttempt, error) {
	if in.UserID == "" {
		return contracts.PromotionAttempt{}, errors.New("user_id required")
	}
	if in.TargetLevel == "" {
		return contracts.PromotionAttempt{}, errors.New("target_level required")
	}
	if in.MockTestID == "" {
		return contracts.PromotionAttempt{}, errors.New("mock_test_id required")
	}
	if in.ID == "" {
		in.ID = newPromotionAttemptID()
	}
	if in.CreatedAt.IsZero() {
		in.CreatedAt = time.Now().UTC()
	}
	if in.PerSkillPct == nil {
		in.PerSkillPct = map[string]float64{}
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	s.rows[in.ID] = in
	return clonePromotionAttempt(in), nil
}

func (s *memoryPromotionAttemptsStore) GetLatestFailedAttempt(userID, targetLevel string) (contracts.PromotionAttempt, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	matching := make([]contracts.PromotionAttempt, 0)
	for _, r := range s.rows {
		if r.UserID == userID && r.TargetLevel == targetLevel && !r.Passed {
			matching = append(matching, r)
		}
	}
	if len(matching) == 0 {
		return contracts.PromotionAttempt{}, false
	}
	// Newest first.
	sort.Slice(matching, func(i, j int) bool {
		return matching[i].CreatedAt.After(matching[j].CreatedAt)
	})
	return clonePromotionAttempt(matching[0]), true
}

func (s *memoryPromotionAttemptsStore) GetByFullSessionID(sessionID string) (contracts.PromotionAttempt, bool) {
	if sessionID == "" {
		return contracts.PromotionAttempt{}, false
	}
	s.mu.RLock()
	defer s.mu.RUnlock()
	for _, r := range s.rows {
		if r.FullSessionID == sessionID {
			return clonePromotionAttempt(r), true
		}
	}
	return contracts.PromotionAttempt{}, false
}

func (s *memoryPromotionAttemptsStore) MarkResult(id string, passed bool, scorePct float64, perSkillPct map[string]float64) (contracts.PromotionAttempt, error) {
	if id == "" {
		return contracts.PromotionAttempt{}, errors.New("id required")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	row, ok := s.rows[id]
	if !ok {
		return contracts.PromotionAttempt{}, fmt.Errorf("promotion attempt %q not found", id)
	}
	row.Passed = passed
	row.ScorePct = scorePct
	if perSkillPct != nil {
		row.PerSkillPct = clonePerSkill(perSkillPct)
	}
	s.rows[id] = row
	return clonePromotionAttempt(row), nil
}

func clonePromotionAttempt(in contracts.PromotionAttempt) contracts.PromotionAttempt {
	out := in
	out.PerSkillPct = clonePerSkill(in.PerSkillPct)
	return out
}

func clonePerSkill(in map[string]float64) map[string]float64 {
	if in == nil {
		return nil
	}
	out := make(map[string]float64, len(in))
	for k, v := range in {
		out[k] = v
	}
	return out
}

// newPromotionAttemptID returns a 16-byte hex identifier prefixed with "pa_".
// Cryptographic randomness keeps memory and Postgres backends generating
// the same shape of id.
func newPromotionAttemptID() string {
	var b [16]byte
	if _, err := rand.Read(b[:]); err != nil {
		return fmt.Sprintf("pa_%d", time.Now().UnixNano())
	}
	return "pa_" + hex.EncodeToString(b[:])
}

// ── Postgres implementation ────────────────────────────────────────────────

type postgresPromotionAttemptsStore struct{ db *sql.DB }

// NewPostgresPromotionAttemptsStoreWithDB wraps an existing *sql.DB. The
// schema (table + index) is created by ensurePromotionAttemptsSchema during
// the postgresUserStore bootstrap, so this constructor does no DDL of its
// own — matching the V19 SkillMasteryStore pattern.
func NewPostgresPromotionAttemptsStoreWithDB(db *sql.DB) PromotionAttemptsStore {
	return &postgresPromotionAttemptsStore{db: db}
}

func (s *postgresPromotionAttemptsStore) Create(in contracts.PromotionAttempt) (contracts.PromotionAttempt, error) {
	if in.UserID == "" {
		return contracts.PromotionAttempt{}, errors.New("user_id required")
	}
	if in.TargetLevel == "" {
		return contracts.PromotionAttempt{}, errors.New("target_level required")
	}
	if in.MockTestID == "" {
		return contracts.PromotionAttempt{}, errors.New("mock_test_id required")
	}
	if in.ID == "" {
		in.ID = newPromotionAttemptID()
	}
	if in.CreatedAt.IsZero() {
		in.CreatedAt = time.Now().UTC()
	}
	if in.PerSkillPct == nil {
		in.PerSkillPct = map[string]float64{}
	}
	perSkillJSON, err := json.Marshal(in.PerSkillPct)
	if err != nil {
		return contracts.PromotionAttempt{}, fmt.Errorf("marshal per_skill_pct: %w", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_, err = s.db.ExecContext(ctx, `
INSERT INTO promotion_attempts (
    id, user_id, mock_test_id, source_level, target_level,
    full_session_id, passed, score_pct, per_skill_pct, created_at
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::jsonb, $10)
`,
		in.ID, in.UserID, in.MockTestID, in.SourceLevel, in.TargetLevel,
		in.FullSessionID, in.Passed, in.ScorePct, string(perSkillJSON), in.CreatedAt,
	)
	if err != nil {
		return contracts.PromotionAttempt{}, fmt.Errorf("create promotion_attempt: %w", err)
	}
	return clonePromotionAttempt(in), nil
}

func (s *postgresPromotionAttemptsStore) GetLatestFailedAttempt(userID, targetLevel string) (contracts.PromotionAttempt, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	row := s.db.QueryRowContext(ctx, `
SELECT id, user_id, mock_test_id, source_level, target_level,
       full_session_id, passed, score_pct, per_skill_pct, created_at
FROM promotion_attempts
WHERE user_id = $1 AND target_level = $2 AND passed = FALSE
ORDER BY created_at DESC
LIMIT 1
`, userID, targetLevel)
	out, err := scanPromotionAttempt(row)
	if err != nil {
		return contracts.PromotionAttempt{}, false
	}
	return out, true
}

func (s *postgresPromotionAttemptsStore) GetByFullSessionID(sessionID string) (contracts.PromotionAttempt, bool) {
	if sessionID == "" {
		return contracts.PromotionAttempt{}, false
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	row := s.db.QueryRowContext(ctx, `
SELECT id, user_id, mock_test_id, source_level, target_level,
       full_session_id, passed, score_pct, per_skill_pct, created_at
FROM promotion_attempts
WHERE full_session_id = $1
ORDER BY created_at DESC
LIMIT 1
`, sessionID)
	out, err := scanPromotionAttempt(row)
	if err != nil {
		return contracts.PromotionAttempt{}, false
	}
	return out, true
}

func (s *postgresPromotionAttemptsStore) MarkResult(id string, passed bool, scorePct float64, perSkillPct map[string]float64) (contracts.PromotionAttempt, error) {
	if id == "" {
		return contracts.PromotionAttempt{}, errors.New("id required")
	}
	if perSkillPct == nil {
		perSkillPct = map[string]float64{}
	}
	perSkillJSON, err := json.Marshal(perSkillPct)
	if err != nil {
		return contracts.PromotionAttempt{}, fmt.Errorf("marshal per_skill_pct: %w", err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	row := s.db.QueryRowContext(ctx, `
UPDATE promotion_attempts
SET passed        = $2,
    score_pct     = $3,
    per_skill_pct = $4::jsonb
WHERE id = $1
RETURNING id, user_id, mock_test_id, source_level, target_level,
          full_session_id, passed, score_pct, per_skill_pct, created_at
`, id, passed, scorePct, string(perSkillJSON))
	out, err := scanPromotionAttempt(row)
	if err != nil {
		return contracts.PromotionAttempt{}, fmt.Errorf("mark promotion result: %w", err)
	}
	return out, nil
}

func scanPromotionAttempt(row interface {
	Scan(dest ...any) error
}) (contracts.PromotionAttempt, error) {
	var (
		out          contracts.PromotionAttempt
		perSkillJSON []byte
	)
	if err := row.Scan(
		&out.ID, &out.UserID, &out.MockTestID, &out.SourceLevel, &out.TargetLevel,
		&out.FullSessionID, &out.Passed, &out.ScorePct, &perSkillJSON, &out.CreatedAt,
	); err != nil {
		return contracts.PromotionAttempt{}, err
	}
	if len(perSkillJSON) > 0 {
		if err := json.Unmarshal(perSkillJSON, &out.PerSkillPct); err != nil {
			return contracts.PromotionAttempt{}, fmt.Errorf("unmarshal per_skill_pct: %w", err)
		}
	}
	if out.PerSkillPct == nil {
		out.PerSkillPct = map[string]float64{}
	}
	return out, nil
}

// ensurePromotionAttemptsSchema creates the V21 promotion_attempts table if
// it does not already exist. The table tracks every promotion attempt a
// learner makes against a level-up MockTest (per docs/specs/cefr-level-progression.md).
//
// Sequencing note: the table has FKs to users(id) and mock_tests(id), so this
// helper is invoked from postgresUserStore.ensureSchema (which runs after
// mock_tests has already been ensured by NewPostgresMockTestStore in the API
// bootstrap). This matches the V17 pattern in 023_users.sql where every
// table that cascades on user delete is co-located with the users schema.
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
