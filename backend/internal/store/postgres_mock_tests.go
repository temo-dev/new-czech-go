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
	db, err := sql.Open("postgres", databaseURL)
	if err != nil {
		return nil, fmt.Errorf("open postgres connection: %w", err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := db.PingContext(ctx); err != nil {
		db.Close()
		return nil, fmt.Errorf("ping postgres: %w", err)
	}
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

CREATE TABLE IF NOT EXISTS mock_test_sections (
    mock_test_id  TEXT    NOT NULL REFERENCES mock_tests(id) ON DELETE CASCADE,
    sequence_no   INTEGER NOT NULL,
    exercise_id   TEXT    NOT NULL,
    exercise_type TEXT    NOT NULL,
    max_points    INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (mock_test_id, sequence_no)
);
`)
	return err
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
	if _, err := tx.ExecContext(ctx,
		`INSERT INTO mock_tests (id, title, description, estimated_duration_minutes, status, pass_threshold_percent) VALUES ($1,$2,$3,$4,$5,$6)`,
		id, t.Title, t.Description, t.EstimatedDurationMinutes, t.Status, threshold,
	); err != nil {
		return contracts.MockTest{}, fmt.Errorf("insert mock test: %w", err)
	}

	for _, sec := range t.Sections {
		if _, err := tx.ExecContext(ctx,
			`INSERT INTO mock_test_sections (mock_test_id, sequence_no, exercise_id, exercise_type, max_points) VALUES ($1,$2,$3,$4,$5)`,
			id, sec.SequenceNo, sec.ExerciseID, sec.ExerciseType, sec.MaxPoints,
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

	var t contracts.MockTest
	err := s.db.QueryRowContext(ctx,
		`SELECT id, title, description, estimated_duration_minutes, status, pass_threshold_percent FROM mock_tests WHERE id = $1`, id,
	).Scan(&t.ID, &t.Title, &t.Description, &t.EstimatedDurationMinutes, &t.Status, &t.PassThresholdPercent)
	if err == sql.ErrNoRows {
		return contracts.MockTest{}, false
	}
	if err != nil {
		return contracts.MockTest{}, false
	}

	rows, err := s.db.QueryContext(ctx,
		`SELECT sequence_no, exercise_id, exercise_type, max_points FROM mock_test_sections WHERE mock_test_id = $1 ORDER BY sequence_no`, id,
	)
	if err != nil {
		return contracts.MockTest{}, false
	}
	defer rows.Close()
	for rows.Next() {
		var sec contracts.MockTestSection
		if err := rows.Scan(&sec.SequenceNo, &sec.ExerciseID, &sec.ExerciseType, &sec.MaxPoints); err != nil {
			return contracts.MockTest{}, false
		}
		t.Sections = append(t.Sections, sec)
	}
	return t, true
}

func (s *postgresMockTestStore) ListMockTests(statusFilter string) []contracts.MockTest {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	query := `SELECT id, title, description, estimated_duration_minutes, status, pass_threshold_percent FROM mock_tests`
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
		var t contracts.MockTest
		if err := rows.Scan(&t.ID, &t.Title, &t.Description, &t.EstimatedDurationMinutes, &t.Status, &t.PassThresholdPercent); err != nil {
			continue
		}
		tests = append(tests, t)
	}

	// Load sections for each test
	for i, t := range tests {
		srows, err := s.db.QueryContext(ctx,
			`SELECT sequence_no, exercise_id, exercise_type, max_points FROM mock_test_sections WHERE mock_test_id = $1 ORDER BY sequence_no`,
			t.ID,
		)
		if err != nil {
			continue
		}
		for srows.Next() {
			var sec contracts.MockTestSection
			if err := srows.Scan(&sec.SequenceNo, &sec.ExerciseID, &sec.ExerciseType, &sec.MaxPoints); err != nil {
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
	res, err := tx.ExecContext(ctx,
		`UPDATE mock_tests SET title=$1, description=$2, estimated_duration_minutes=$3, status=$4, pass_threshold_percent=$5, updated_at=now() WHERE id=$6`,
		update.Title, update.Description, update.EstimatedDurationMinutes, update.Status, updateThreshold, id,
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
			`INSERT INTO mock_test_sections (mock_test_id, sequence_no, exercise_id, exercise_type, max_points) VALUES ($1,$2,$3,$4,$5)`,
			id, sec.SequenceNo, sec.ExerciseID, sec.ExerciseType, sec.MaxPoints,
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
