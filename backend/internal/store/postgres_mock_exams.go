package store

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	_ "github.com/lib/pq"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

type postgresMockExamStore struct {
	db *sql.DB
}

func NewPostgresMockExamStore(databaseURL string) (MockExamStore, error) {
	db, err := openPostgresPool(databaseURL, "mock_exams")
	if err != nil {
		return nil, err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	s := &postgresMockExamStore{db: db}
	if err := s.ensureSchema(ctx); err != nil {
		db.Close()
		return nil, fmt.Errorf("ensure mock exam schema: %w", err)
	}
	return s, nil
}

func (s *postgresMockExamStore) ensureSchema(ctx context.Context) error {
	_, err := s.db.ExecContext(ctx, `
CREATE TABLE IF NOT EXISTS mock_exam_sessions (
    id                      TEXT        PRIMARY KEY,
    learner_id              TEXT        NOT NULL,
    status                  TEXT        NOT NULL DEFAULT 'in_progress',
    mock_test_id            TEXT        NOT NULL DEFAULT '',
    overall_score           INTEGER     NOT NULL DEFAULT 0,
    passed                  BOOLEAN     NOT NULL DEFAULT false,
    overall_readiness_level TEXT        NOT NULL DEFAULT '',
    overall_summary         TEXT        NOT NULL DEFAULT '',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS mock_exam_sections (
    session_id    TEXT    NOT NULL REFERENCES mock_exam_sessions(id) ON DELETE CASCADE,
    sequence_no   INTEGER NOT NULL,
    exercise_id   TEXT    NOT NULL,
    exercise_type TEXT    NOT NULL,
    max_points    INTEGER NOT NULL DEFAULT 0,
    attempt_id    TEXT    NOT NULL DEFAULT '',
    section_score INTEGER NOT NULL DEFAULT 0,
    status        TEXT    NOT NULL DEFAULT 'pending',
    PRIMARY KEY (session_id, sequence_no)
);

ALTER TABLE mock_exam_sessions
    ADD COLUMN IF NOT EXISTS mock_test_id            TEXT    NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS overall_score           INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS passed                  BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS pass_threshold_percent  INTEGER NOT NULL DEFAULT 60;

ALTER TABLE mock_exam_sections
    ADD COLUMN IF NOT EXISTS max_points    INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS section_score INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS display_order INTEGER NOT NULL DEFAULT 0;

-- V39 timer: pre-V39 rows default to duration_sec=0 so the sweeper ignores
-- them. New sessions get 5400 (90 min) set explicitly in CreateMockExam.
ALTER TABLE mock_exam_sessions
    ADD COLUMN IF NOT EXISTS duration_sec INTEGER NOT NULL DEFAULT 0;

-- V39 backfill: pre-V39 rows have display_order=0; fill with sequence_no
-- so the new ORDER BY display_order ASC reproduces legacy sequence order.
-- Idempotent — only touches rows that haven't been backfilled.
UPDATE mock_exam_sections SET display_order = sequence_no WHERE display_order = 0;
`)
	return err
}

func (s *postgresMockExamStore) CreateMockExam(learnerID, mockTestID string, mockTests MockTestStore) (contracts.MockExamSession, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var sections []contracts.MockExamSessionItem

	threshold := 60
	if mockTestID != "" && mockTests != nil {
		mt, ok := mockTests.MockTestByID(mockTestID)
		if !ok {
			return contracts.MockExamSession{}, fmt.Errorf("mock test not found: %s", mockTestID)
		}
		if mt.PassThresholdPercent > 0 {
			threshold = mt.PassThresholdPercent
		}
		sections = make([]contracts.MockExamSessionItem, 0, len(mt.Sections))
		for _, mts := range mt.Sections {
			sections = append(sections, contracts.MockExamSessionItem{
				SequenceNo:   mts.SequenceNo,
				SkillKind:    mts.SkillKind,
				ExerciseID:   mts.ExerciseID,
				ExerciseType: mts.ExerciseType,
				MaxPoints:    mts.MaxPoints,
				Status:       "pending",
			})
		}
	} else {
		sections = make([]contracts.MockExamSessionItem, 0, len(mockExamTaskTypes))
		for i, kind := range mockExamTaskTypes {
			var exID, exType string
			err := s.db.QueryRowContext(ctx,
				`SELECT id, exercise_type FROM exercises WHERE exercise_type = $1 AND status = 'published' ORDER BY sequence_no LIMIT 1`,
				kind,
			).Scan(&exID, &exType)
			if err == sql.ErrNoRows {
				return contracts.MockExamSession{}, fmt.Errorf("no published exercise for %s", kind)
			}
			if err != nil {
				return contracts.MockExamSession{}, fmt.Errorf("query exercise for %s: %w", kind, err)
			}
			sections = append(sections, contracts.MockExamSessionItem{
				SequenceNo:   i + 1,
				SkillKind:    skillKindForExerciseType(exType),
				ExerciseID:   exID,
				ExerciseType: exType,
				MaxPoints:    defaultMaxPoints[kind],
				Status:       "pending",
			})
		}
	}

	// V39: rank sections by (max_points ASC, sequence_no ASC) and write
	// display_order before INSERT. Mutates the slice in place so the returned
	// session reflects the same order the API will serve on subsequent reads.
	assignDisplayOrder(sections)

	id := newUUIDLikeID()
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return contracts.MockExamSession{}, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback()

	if _, err := tx.ExecContext(ctx,
		`INSERT INTO mock_exam_sessions (id, learner_id, status, mock_test_id, pass_threshold_percent, duration_sec) VALUES ($1, $2, 'in_progress', $3, $4, $5)`,
		id, learnerID, mockTestID, threshold, DefaultMockExamDurationSec,
	); err != nil {
		return contracts.MockExamSession{}, fmt.Errorf("insert mock exam session: %w", err)
	}

	for _, sec := range sections {
		if _, err := tx.ExecContext(ctx,
			`INSERT INTO mock_exam_sections (session_id, sequence_no, exercise_id, exercise_type, max_points, status, display_order) VALUES ($1,$2,$3,$4,$5,'pending',$6)`,
			id, sec.SequenceNo, sec.ExerciseID, sec.ExerciseType, sec.MaxPoints, sec.DisplayOrder,
		); err != nil {
			return contracts.MockExamSession{}, fmt.Errorf("insert mock exam section: %w", err)
		}
	}

	if err := tx.Commit(); err != nil {
		return contracts.MockExamSession{}, fmt.Errorf("commit mock exam: %w", err)
	}

	now := time.Now().UTC()
	return contracts.MockExamSession{
		ID:                   id,
		LearnerID:            learnerID,
		Status:               "in_progress",
		MockTestID:           mockTestID,
		PassThresholdPercent: threshold,
		Sections:             sections,
		StartedAt:            now,
		DurationSec:          DefaultMockExamDurationSec,
		ExpiresAt:            now.Add(time.Duration(DefaultMockExamDurationSec) * time.Second),
	}, nil
}

func (s *postgresMockExamStore) MockExamByID(id string) (contracts.MockExamSession, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var session contracts.MockExamSession
	err := s.db.QueryRowContext(ctx,
		`SELECT id, learner_id, status, mock_test_id, overall_score, passed, pass_threshold_percent, overall_readiness_level, overall_summary, created_at, duration_sec FROM mock_exam_sessions WHERE id = $1`,
		id,
	).Scan(&session.ID, &session.LearnerID, &session.Status, &session.MockTestID, &session.OverallScore, &session.Passed, &session.PassThresholdPercent, &session.OverallReadinessLevel, &session.OverallSummary, &session.StartedAt, &session.DurationSec)
	if err == sql.ErrNoRows {
		return contracts.MockExamSession{}, false
	}
	if err != nil {
		return contracts.MockExamSession{}, false
	}
	if session.DurationSec > 0 {
		session.ExpiresAt = session.StartedAt.Add(time.Duration(session.DurationSec) * time.Second)
	}

	rows, err := s.db.QueryContext(ctx,
		`SELECT sequence_no, exercise_id, exercise_type, max_points, attempt_id, section_score, status, display_order FROM mock_exam_sections WHERE session_id = $1 ORDER BY display_order ASC`,
		id,
	)
	if err != nil {
		return contracts.MockExamSession{}, false
	}
	defer rows.Close()

	for rows.Next() {
		var sec contracts.MockExamSessionItem
		if err := rows.Scan(&sec.SequenceNo, &sec.ExerciseID, &sec.ExerciseType, &sec.MaxPoints, &sec.AttemptID, &sec.SectionScore, &sec.Status, &sec.DisplayOrder); err != nil {
			return contracts.MockExamSession{}, false
		}
		sec.SkillKind = skillKindForExerciseType(sec.ExerciseType)
		session.Sections = append(session.Sections, sec)
	}
	return session, true
}

// SkipSection — V39 postgres impl. Atomic guarded UPDATE that flips the
// section's status to 'skipped' only when it is currently 'pending'. Returns
// ErrSectionNotSkippable when the guard fails, ErrSectionNotFound when the
// (session_id, display_order) pair does not exist.
func (s *postgresMockExamStore) SkipSection(sessionID string, displayOrder int) (contracts.MockExamSession, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var sessionStatus string
	if err := s.db.QueryRowContext(ctx,
		`SELECT status FROM mock_exam_sessions WHERE id = $1`, sessionID,
	).Scan(&sessionStatus); err == sql.ErrNoRows {
		return contracts.MockExamSession{}, ErrSectionNotFound
	} else if err != nil {
		return contracts.MockExamSession{}, fmt.Errorf("query mock exam: %w", err)
	}
	if sessionStatus == "completed" {
		return contracts.MockExamSession{}, ErrSectionNotSkippable
	}

	res, err := s.db.ExecContext(ctx,
		`UPDATE mock_exam_sections SET status='skipped' WHERE session_id=$1 AND display_order=$2 AND status='pending'`,
		sessionID, displayOrder,
	)
	if err != nil {
		return contracts.MockExamSession{}, fmt.Errorf("skip section: %w", err)
	}
	n, err := res.RowsAffected()
	if err != nil {
		return contracts.MockExamSession{}, fmt.Errorf("skip section affected rows: %w", err)
	}
	if n == 0 {
		// Either the row doesn't exist or status != 'pending'. Distinguish
		// so handlers can return 404 vs 409 correctly.
		var existingStatus string
		err := s.db.QueryRowContext(ctx,
			`SELECT status FROM mock_exam_sections WHERE session_id=$1 AND display_order=$2`,
			sessionID, displayOrder,
		).Scan(&existingStatus)
		if err == sql.ErrNoRows {
			return contracts.MockExamSession{}, ErrSectionNotFound
		}
		if err != nil {
			return contracts.MockExamSession{}, fmt.Errorf("lookup section after no-op skip: %w", err)
		}
		return contracts.MockExamSession{}, ErrSectionNotSkippable
	}

	session, ok := s.MockExamByID(sessionID)
	if !ok {
		return contracts.MockExamSession{}, fmt.Errorf("mock exam not found after skip")
	}
	return session, nil
}

// ListExpired — V39 postgres impl.
func (s *postgresMockExamStore) ListExpired(now time.Time) ([]string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	rows, err := s.db.QueryContext(ctx,
		`SELECT id FROM mock_exam_sessions
		 WHERE status = 'in_progress'
		   AND duration_sec > 0
		   AND $1 > created_at + (duration_sec || ' seconds')::interval
		 ORDER BY id`, now.UTC(),
	)
	if err != nil {
		return nil, fmt.Errorf("query expired sessions: %w", err)
	}
	defer rows.Close()
	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, fmt.Errorf("scan expired id: %w", err)
		}
		ids = append(ids, id)
	}
	return ids, nil
}

// ExpireMockExam — V39 postgres impl. Marks pending sections 'skipped' and
// flips the session to 'completed' in a single transaction. No scoring
// rollup; idempotent for already-completed sessions.
func (s *postgresMockExamStore) ExpireMockExam(sessionID string) (contracts.MockExamSession, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return contracts.MockExamSession{}, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback()

	var status string
	if err := tx.QueryRowContext(ctx,
		`SELECT status FROM mock_exam_sessions WHERE id = $1 FOR UPDATE`, sessionID,
	).Scan(&status); err == sql.ErrNoRows {
		return contracts.MockExamSession{}, ErrSectionNotFound
	} else if err != nil {
		return contracts.MockExamSession{}, fmt.Errorf("lock session: %w", err)
	}
	if status == "completed" {
		// Idempotent — return current snapshot.
		_ = tx.Commit()
		session, ok := s.MockExamByID(sessionID)
		if !ok {
			return contracts.MockExamSession{}, fmt.Errorf("mock exam vanished")
		}
		return session, nil
	}

	if _, err := tx.ExecContext(ctx,
		`UPDATE mock_exam_sections SET status='skipped' WHERE session_id=$1 AND status='pending'`,
		sessionID,
	); err != nil {
		return contracts.MockExamSession{}, fmt.Errorf("expire sections: %w", err)
	}
	if _, err := tx.ExecContext(ctx,
		`UPDATE mock_exam_sessions
		 SET status='completed',
		     overall_summary = COALESCE(NULLIF(overall_summary, ''), 'Hết thời gian — bài thi đã tự động nộp.'),
		     updated_at = now()
		 WHERE id = $1`, sessionID,
	); err != nil {
		return contracts.MockExamSession{}, fmt.Errorf("expire session: %w", err)
	}
	if err := tx.Commit(); err != nil {
		return contracts.MockExamSession{}, fmt.Errorf("commit expire: %w", err)
	}
	session, ok := s.MockExamByID(sessionID)
	if !ok {
		return contracts.MockExamSession{}, fmt.Errorf("mock exam not found after expire")
	}
	return session, nil
}

// AdvanceSectionAt — V39 postgres impl. Updates the section at
// (sessionID, displayOrder) with the provided attempt regardless of prior
// status. Useful for sheet jump-back where the learner re-answers a
// section that was previously 'skipped' or 'completed'.
func (s *postgresMockExamStore) AdvanceSectionAt(sessionID, attemptID string, displayOrder int) (contracts.MockExamSession, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var sessionStatus string
	if err := s.db.QueryRowContext(ctx,
		`SELECT status FROM mock_exam_sessions WHERE id = $1`, sessionID,
	).Scan(&sessionStatus); err == sql.ErrNoRows {
		return contracts.MockExamSession{}, ErrSectionNotFound
	} else if err != nil {
		return contracts.MockExamSession{}, fmt.Errorf("query mock exam: %w", err)
	}
	if sessionStatus == "completed" {
		return contracts.MockExamSession{}, fmt.Errorf("mock exam already completed")
	}
	res, err := s.db.ExecContext(ctx,
		`UPDATE mock_exam_sections SET attempt_id = $1, status = 'completed' WHERE session_id = $2 AND display_order = $3`,
		attemptID, sessionID, displayOrder,
	)
	if err != nil {
		return contracts.MockExamSession{}, fmt.Errorf("advance section at: %w", err)
	}
	n, err := res.RowsAffected()
	if err != nil || n == 0 {
		return contracts.MockExamSession{}, ErrSectionNotFound
	}
	session, ok := s.MockExamByID(sessionID)
	if !ok {
		return contracts.MockExamSession{}, fmt.Errorf("mock exam not found after advance-at")
	}
	return session, nil
}

func (s *postgresMockExamStore) AdvanceMockExam(id, attemptID string) (contracts.MockExamSession, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var status string
	if err := s.db.QueryRowContext(ctx,
		`SELECT status FROM mock_exam_sessions WHERE id = $1`, id,
	).Scan(&status); err == sql.ErrNoRows {
		return contracts.MockExamSession{}, fmt.Errorf("mock exam not found")
	} else if err != nil {
		return contracts.MockExamSession{}, fmt.Errorf("query mock exam: %w", err)
	}
	if status == "completed" {
		return contracts.MockExamSession{}, fmt.Errorf("mock exam already completed")
	}

	// Find the pending section whose exercise_id matches the attempt's exercise_id.
	// Using first-pending order would break mixed-skill exams where speaking sections
	// are queued for bulk analysis while objective sections complete out of order.
	var sequenceNo int
	err := s.db.QueryRowContext(ctx, `
		SELECT mes.sequence_no
		FROM mock_exam_sections mes
		JOIN attempts a ON a.exercise_id = mes.exercise_id
		WHERE mes.session_id = $1
		  AND mes.status    = 'pending'
		  AND a.id          = $2
		LIMIT 1
	`, id, attemptID).Scan(&sequenceNo)
	if err == sql.ErrNoRows {
		return contracts.MockExamSession{}, fmt.Errorf("no pending section matches attempt %s", attemptID)
	}
	if err != nil {
		return contracts.MockExamSession{}, fmt.Errorf("query pending section: %w", err)
	}

	if _, err := s.db.ExecContext(ctx,
		`UPDATE mock_exam_sections SET attempt_id = $1, status = 'completed' WHERE session_id = $2 AND sequence_no = $3`,
		attemptID, id, sequenceNo,
	); err != nil {
		return contracts.MockExamSession{}, fmt.Errorf("advance mock exam: %w", err)
	}

	session, ok := s.MockExamByID(id)
	if !ok {
		return contracts.MockExamSession{}, fmt.Errorf("mock exam not found after advance")
	}
	return session, nil
}

func (s *postgresMockExamStore) CompleteMockExam(id string) (contracts.MockExamSession, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// V39: 'skipped' sections are a valid terminal state (no scoring,
	// section_score=0). Only block Complete on rows that are still pending.
	var pendingCount int
	if err := s.db.QueryRowContext(ctx,
		`SELECT COUNT(*) FROM mock_exam_sections WHERE session_id = $1 AND status NOT IN ('completed', 'skipped')`, id,
	).Scan(&pendingCount); err != nil {
		return contracts.MockExamSession{}, fmt.Errorf("check sections: %w", err)
	}
	if pendingCount > 0 {
		return contracts.MockExamSession{}, fmt.Errorf("%d section(s) not yet completed", pendingCount)
	}

	// Load completed (attempt-backed) sections only. Skipped sections are
	// later read back via MockExamByID at section_score=0.
	srows, err := s.db.QueryContext(ctx,
		`SELECT
			ms.sequence_no,
			ms.attempt_id,
			ms.exercise_type,
			ms.max_points,
			a.status,
			a.readiness_level,
			af.payload::text
		FROM mock_exam_sections ms
		LEFT JOIN attempts a ON a.id = ms.attempt_id
		LEFT JOIN attempt_feedback af ON af.attempt_id = ms.attempt_id
		WHERE ms.session_id = $1 AND ms.attempt_id != ''
		ORDER BY ms.sequence_no`, id,
	)
	if err != nil {
		return contracts.MockExamSession{}, fmt.Errorf("query sections: %w", err)
	}
	type sectionMeta struct {
		seqNo         int
		attemptID     string
		exerciseType  string
		maxPoints     int
		attemptStatus string
		readiness     string
		feedback      *contracts.AttemptFeedback
	}
	var sectionMetas []sectionMeta
	for srows.Next() {
		var m sectionMeta
		var readiness sql.NullString
		var attemptStatus sql.NullString
		var feedbackPayload sql.NullString
		if err := srows.Scan(&m.seqNo, &m.attemptID, &m.exerciseType, &m.maxPoints, &attemptStatus, &readiness, &feedbackPayload); err != nil {
			srows.Close()
			return contracts.MockExamSession{}, fmt.Errorf("scan section: %w", err)
		}
		if m.maxPoints == 0 {
			m.maxPoints = defaultMaxPoints[m.exerciseType]
		}
		if readiness.Valid {
			m.readiness = readiness.String
		}
		if attemptStatus.Valid {
			m.attemptStatus = attemptStatus.String
		}
		if feedbackPayload.Valid && feedbackPayload.String != "" {
			var feedback contracts.AttemptFeedback
			if err := json.Unmarshal([]byte(feedbackPayload.String), &feedback); err == nil {
				m.feedback = &feedback
			}
		}
		if m.feedback == nil && m.readiness != "" {
			m.feedback = &contracts.AttemptFeedback{ReadinessLevel: m.readiness}
		}
		if m.attemptStatus != "completed" || m.feedback == nil {
			srows.Close()
			return contracts.MockExamSession{}, fmt.Errorf("attempt %s is not completed", m.attemptID)
		}
		sectionMetas = append(sectionMetas, m)
	}
	srows.Close()

	levels := make([]string, len(sectionMetas))
	inputs := make([]mockExamScoringInput, len(sectionMetas))
	bonusSections := make([]contracts.MockExamSessionItem, len(sectionMetas))
	for i, m := range sectionMetas {
		if m.feedback != nil {
			levels[i] = m.feedback.ReadinessLevel
		} else {
			levels[i] = m.readiness
		}
		inputs[i] = mockExamScoringInputFromFeedback(m.feedback, m.maxPoints)
		bonusSections[i] = contracts.MockExamSessionItem{
			SequenceNo:   m.seqNo,
			ExerciseID:   "",
			ExerciseType: m.exerciseType,
			MaxPoints:    m.maxPoints,
			AttemptID:    m.attemptID,
			Status:       "completed",
		}
	}

	var threshold int
	if err := s.db.QueryRowContext(ctx,
		`SELECT pass_threshold_percent FROM mock_exam_sessions WHERE id = $1`, id,
	).Scan(&threshold); err != nil || threshold <= 0 {
		threshold = 60
	}

	level, summary := rollupReadiness(levels)
	sectionScores, _, overallScore, passed := computeScoring(inputs, threshold, shouldApplyPronunciationBonus(bonusSections))

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return contracts.MockExamSession{}, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback()

	if _, err := tx.ExecContext(ctx,
		`UPDATE mock_exam_sessions SET status='completed', overall_readiness_level=$1, overall_summary=$2, overall_score=$3, passed=$4, updated_at=now() WHERE id=$5`,
		level, summary, overallScore, passed, id,
	); err != nil {
		return contracts.MockExamSession{}, fmt.Errorf("complete mock exam: %w", err)
	}

	for i, m := range sectionMetas {
		sc := 0
		if i < len(sectionScores) {
			sc = sectionScores[i]
		}
		if _, err := tx.ExecContext(ctx,
			`UPDATE mock_exam_sections SET section_score=$1 WHERE session_id=$2 AND sequence_no=$3`,
			sc, id, m.seqNo,
		); err != nil {
			return contracts.MockExamSession{}, fmt.Errorf("update section score: %w", err)
		}
	}

	if err := tx.Commit(); err != nil {
		return contracts.MockExamSession{}, fmt.Errorf("commit complete: %w", err)
	}

	session, ok := s.MockExamByID(id)
	if !ok {
		return contracts.MockExamSession{}, fmt.Errorf("mock exam not found after complete")
	}
	return session, nil
}

func joinStrings(ss []string, sep string) string {
	result := ""
	for i, s := range ss {
		if i > 0 {
			result += sep
		}
		result += s
	}
	return result
}
