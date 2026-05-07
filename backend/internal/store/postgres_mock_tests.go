package store

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	_ "github.com/lib/pq"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

type postgresMockTestStore struct {
	db *sql.DB
}

func NewPostgresMockTestStore(databaseURL string) (MockTestStore, error) {
	db, err := openPostgresPool(databaseURL, "mock_tests")
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	s := &postgresMockTestStore{db: db}
	if err := s.ensureSchema(ctx); err != nil {
		db.Close()
		return nil, fmt.Errorf("ensure mock test schema: %w", err)
	}
	return s, nil
}

func (s *postgresMockTestStore) ensureSchema(ctx context.Context) error {
	_, err := s.db.ExecContext(ctx, `
CREATE TABLE IF NOT EXISTS mock_tests (
    id                          TEXT        PRIMARY KEY,
    title                       TEXT        NOT NULL,
    description                 TEXT        NOT NULL DEFAULT '',
    estimated_duration_minutes  INTEGER     NOT NULL DEFAULT 15,
    status                      TEXT        NOT NULL DEFAULT 'draft',
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE mock_tests
    ADD COLUMN IF NOT EXISTS pass_threshold_percent INTEGER NOT NULL DEFAULT 60;

ALTER TABLE mock_tests
    ADD COLUMN IF NOT EXISTS exam_mode VARCHAR(20) NOT NULL DEFAULT '';

ALTER TABLE mock_tests
    ADD COLUMN IF NOT EXISTS banner_image_id TEXT NOT NULL DEFAULT '';

-- V9: session_type was never persisted to this table (Go struct-only field).
-- All existing rows get exam_mode = '' which the application treats as 'practice'.
-- No data migration needed.

CREATE TABLE IF NOT EXISTS mock_test_sections (
    mock_test_id  TEXT    NOT NULL REFERENCES mock_tests(id) ON DELETE CASCADE,
    sequence_no   INTEGER NOT NULL,
    exercise_id   TEXT    NOT NULL,
    exercise_type TEXT    NOT NULL,
    max_points    INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (mock_test_id, sequence_no)
);

ALTER TABLE mock_test_sections
    ADD COLUMN IF NOT EXISTS skill_kind TEXT NOT NULL DEFAULT '';

-- V9: drop obsolete full exam sessions table (was added in V5, replaced by exam_mode model)
DROP TABLE IF EXISTS full_exam_sessions;

-- Migration 025 (V21): CEFR level promotion + placement flags.
ALTER TABLE mock_tests ADD COLUMN IF NOT EXISTS is_promotion BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE mock_tests ADD COLUMN IF NOT EXISTS is_placement BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE mock_tests ADD COLUMN IF NOT EXISTS target_level TEXT;
`)
	if err != nil {
		return err
	}
	// V21 CHECK constraints — guarded by pg_constraint lookup so re-running
	// this DDL against an already-migrated DB is a no-op.
	for _, ddl := range []string{
		`DO $$ BEGIN
			IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'mock_tests_target_level_check') THEN
				ALTER TABLE mock_tests
					ADD CONSTRAINT mock_tests_target_level_check
					CHECK (target_level IS NULL OR target_level IN ('a0','a1','a2','b1'));
			END IF;
		END$$;`,
		`DO $$ BEGIN
			IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'mock_tests_promotion_target_required') THEN
				ALTER TABLE mock_tests
					ADD CONSTRAINT mock_tests_promotion_target_required
					CHECK (is_promotion = FALSE OR target_level IS NOT NULL);
			END IF;
		END$$;`,
		`DO $$ BEGIN
			IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'mock_tests_promotion_placement_mutex') THEN
				ALTER TABLE mock_tests
					ADD CONSTRAINT mock_tests_promotion_placement_mutex
					CHECK (NOT (is_promotion AND is_placement));
			END IF;
		END$$;`,
	} {
		if _, err := s.db.ExecContext(ctx, ddl); err != nil {
			return fmt.Errorf("apply mock_tests v21 check constraint: %w", err)
		}
	}
	return nil
}

func (s *postgresMockTestStore) CreateMockTest(t contracts.MockTest) (contracts.MockTest, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	id := newUUIDLikeID()
	if t.Status == "" {
		t.Status = "draft"
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return contracts.MockTest{}, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback()

	threshold := t.PassThresholdPercent
	if threshold <= 0 || threshold > 100 {
		threshold = 60
	}
	var targetLevel any
	if t.TargetLevel != "" {
		targetLevel = t.TargetLevel
	}
	if _, err := tx.ExecContext(ctx,
		`INSERT INTO mock_tests (id, title, description, estimated_duration_minutes, status, pass_threshold_percent, exam_mode, is_promotion, is_placement, target_level)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
		id, t.Title, t.Description, t.EstimatedDurationMinutes, t.Status, threshold, t.ExamMode,
		t.IsPromotion, t.IsPlacement, targetLevel,
	); err != nil {
		return contracts.MockTest{}, fmt.Errorf("insert mock test: %w", err)
	}

	for _, sec := range t.Sections {
		if _, err := tx.ExecContext(ctx,
			`INSERT INTO mock_test_sections (mock_test_id, sequence_no, skill_kind, exercise_id, exercise_type, max_points) VALUES ($1,$2,$3,$4,$5,$6)`,
			id, sec.SequenceNo, sec.SkillKind, sec.ExerciseID, sec.ExerciseType, sec.MaxPoints,
		); err != nil {
			return contracts.MockTest{}, fmt.Errorf("insert mock test section: %w", err)
		}
	}

	if err := tx.Commit(); err != nil {
		return contracts.MockTest{}, fmt.Errorf("commit mock test: %w", err)
	}

	t.ID = id
	return t, nil
}

func (s *postgresMockTestStore) MockTestByID(id string) (contracts.MockTest, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var (
		t           contracts.MockTest
		targetLevel sql.NullString
	)
	err := s.db.QueryRowContext(ctx,
		`SELECT id, title, description, estimated_duration_minutes, status, pass_threshold_percent, exam_mode, banner_image_id,
                is_promotion, is_placement, target_level
         FROM mock_tests WHERE id = $1`, id,
	).Scan(&t.ID, &t.Title, &t.Description, &t.EstimatedDurationMinutes, &t.Status, &t.PassThresholdPercent, &t.ExamMode, &t.BannerImageID,
		&t.IsPromotion, &t.IsPlacement, &targetLevel)
	if err == sql.ErrNoRows {
		return contracts.MockTest{}, false
	}
	if err != nil {
		return contracts.MockTest{}, false
	}
	if targetLevel.Valid {
		t.TargetLevel = targetLevel.String
	}

	rows, err := s.db.QueryContext(ctx,
		`SELECT sequence_no, skill_kind, exercise_id, exercise_type, max_points FROM mock_test_sections WHERE mock_test_id = $1 ORDER BY sequence_no`, id,
	)
	if err != nil {
		return contracts.MockTest{}, false
	}
	defer rows.Close()
	for rows.Next() {
		var sec contracts.MockTestSection
		if err := rows.Scan(&sec.SequenceNo, &sec.SkillKind, &sec.ExerciseID, &sec.ExerciseType, &sec.MaxPoints); err != nil {
			return contracts.MockTest{}, false
		}
		t.Sections = append(t.Sections, sec)
	}
	return t, true
}

func (s *postgresMockTestStore) ListMockTests(statusFilter string) []contracts.MockTest {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	query := `SELECT id, title, description, estimated_duration_minutes, status, pass_threshold_percent, exam_mode, banner_image_id,
                     is_promotion, is_placement, target_level
              FROM mock_tests`
	args := []interface{}{}
	if statusFilter != "" {
		query += ` WHERE status = $1`
		args = append(args, statusFilter)
	}
	query += ` ORDER BY created_at DESC`

	rows, err := s.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil
	}
	defer rows.Close()

	var tests []contracts.MockTest
	for rows.Next() {
		var (
			t           contracts.MockTest
			targetLevel sql.NullString
		)
		if err := rows.Scan(&t.ID, &t.Title, &t.Description, &t.EstimatedDurationMinutes, &t.Status, &t.PassThresholdPercent, &t.ExamMode, &t.BannerImageID,
			&t.IsPromotion, &t.IsPlacement, &targetLevel); err != nil {
			continue
		}
		if targetLevel.Valid {
			t.TargetLevel = targetLevel.String
		}
		tests = append(tests, t)
	}

	// Load sections for each test
	for i, t := range tests {
		srows, err := s.db.QueryContext(ctx,
			`SELECT sequence_no, skill_kind, exercise_id, exercise_type, max_points FROM mock_test_sections WHERE mock_test_id = $1 ORDER BY sequence_no`,
			t.ID,
		)
		if err != nil {
			continue
		}
		for srows.Next() {
			var sec contracts.MockTestSection
			if err := srows.Scan(&sec.SequenceNo, &sec.SkillKind, &sec.ExerciseID, &sec.ExerciseType, &sec.MaxPoints); err != nil {
				continue
			}
			tests[i].Sections = append(tests[i].Sections, sec)
		}
		srows.Close()
	}
	return tests
}

func (s *postgresMockTestStore) UpdateMockTest(id string, update contracts.MockTest) (contracts.MockTest, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return contracts.MockTest{}, false
	}
	defer tx.Rollback()

	updateThreshold := update.PassThresholdPercent
	if updateThreshold <= 0 || updateThreshold > 100 {
		updateThreshold = 60
	}
	var updateTarget any
	if update.TargetLevel != "" {
		updateTarget = update.TargetLevel
	}
	res, err := tx.ExecContext(ctx,
		`UPDATE mock_tests SET title=$1, description=$2, estimated_duration_minutes=$3, status=$4, pass_threshold_percent=$5, exam_mode=$6,
		    is_promotion=$7, is_placement=$8, target_level=$9,
		    updated_at=now()
		 WHERE id=$10`,
		update.Title, update.Description, update.EstimatedDurationMinutes, update.Status, updateThreshold, update.ExamMode,
		update.IsPromotion, update.IsPlacement, updateTarget, id,
	)
	if err != nil {
		return contracts.MockTest{}, false
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return contracts.MockTest{}, false
	}

	// Replace sections
	if _, err := tx.ExecContext(ctx, `DELETE FROM mock_test_sections WHERE mock_test_id = $1`, id); err != nil {
		return contracts.MockTest{}, false
	}
	for _, sec := range update.Sections {
		if _, err := tx.ExecContext(ctx,
			`INSERT INTO mock_test_sections (mock_test_id, sequence_no, skill_kind, exercise_id, exercise_type, max_points) VALUES ($1,$2,$3,$4,$5,$6)`,
			id, sec.SequenceNo, sec.SkillKind, sec.ExerciseID, sec.ExerciseType, sec.MaxPoints,
		); err != nil {
			return contracts.MockTest{}, false
		}
	}

	if err := tx.Commit(); err != nil {
		return contracts.MockTest{}, false
	}
	update.ID = id
	return update, true
}

func (s *postgresMockTestStore) DeleteMockTest(id string) bool {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	res, err := s.db.ExecContext(ctx, `DELETE FROM mock_tests WHERE id = $1`, id)
	if err != nil {
		return false
	}
	n, _ := res.RowsAffected()
	return n > 0
}

func (s *postgresMockTestStore) SetMockTestBannerImage(id, storageKey string) bool {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	res, err := s.db.ExecContext(ctx,
		`UPDATE mock_tests SET banner_image_id = $2, updated_at = now() WHERE id = $1`,
		id, storageKey,
	)
	if err != nil {
		return false
	}
	n, _ := res.RowsAffected()
	return n > 0
}

// LatestPromotionMockTest returns the most-recent published promotion
// MockTest for a given target_level. Used by the level-progress
// resolver so the client can deep-link straight to PreExamScreen
// without an extra round trip (V21 review I5).
func (s *postgresMockTestStore) LatestPromotionMockTest(targetLevel string) (contracts.MockTest, bool) {
	if targetLevel == "" {
		return contracts.MockTest{}, false
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var (
		t           contracts.MockTest
		levelOut    sql.NullString
	)
	err := s.db.QueryRowContext(ctx, `
SELECT id, title, description, estimated_duration_minutes, status, pass_threshold_percent, exam_mode, banner_image_id,
       is_promotion, is_placement, target_level
FROM mock_tests
WHERE is_promotion = TRUE AND status = 'published' AND target_level = $1
ORDER BY created_at DESC
LIMIT 1
`, targetLevel).Scan(&t.ID, &t.Title, &t.Description, &t.EstimatedDurationMinutes, &t.Status, &t.PassThresholdPercent, &t.ExamMode, &t.BannerImageID,
		&t.IsPromotion, &t.IsPlacement, &levelOut)
	if err == sql.ErrNoRows {
		return contracts.MockTest{}, false
	}
	if err != nil {
		return contracts.MockTest{}, false
	}
	if levelOut.Valid {
		t.TargetLevel = levelOut.String
	}
	return t, true
}

// LatestPlacementMockTest returns the placement-flagged MockTest with the
// most recent created_at. Drives the V21 placement-test/start endpoint.
func (s *postgresMockTestStore) LatestPlacementMockTest() (contracts.MockTest, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var (
		t           contracts.MockTest
		targetLevel sql.NullString
	)
	err := s.db.QueryRowContext(ctx, `
SELECT id, title, description, estimated_duration_minutes, status, pass_threshold_percent, exam_mode, banner_image_id,
       is_promotion, is_placement, target_level
FROM mock_tests
WHERE is_placement = TRUE AND status = 'published'
ORDER BY created_at DESC
LIMIT 1
`).Scan(&t.ID, &t.Title, &t.Description, &t.EstimatedDurationMinutes, &t.Status, &t.PassThresholdPercent, &t.ExamMode, &t.BannerImageID,
		&t.IsPromotion, &t.IsPlacement, &targetLevel)
	if err == sql.ErrNoRows {
		return contracts.MockTest{}, false
	}
	if err != nil {
		return contracts.MockTest{}, false
	}
	if targetLevel.Valid {
		t.TargetLevel = targetLevel.String
	}
	return t, true
}
