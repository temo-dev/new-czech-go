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
    ADD COLUMN IF NOT EXISTS section_score INTEGER NOT NULL DEFAULT 0;
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

	id := newUUIDLikeID()
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return contracts.MockExamSession{}, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback()

	if _, err := tx.ExecContext(ctx,
		`INSERT INTO mock_exam_sessions (id, learner_id, status, mock_test_id, pass_threshold_percent) VALUES ($1, $2, 'in_progress', $3, $4)`,
		id, learnerID, mockTestID, threshold,
	); err != nil {
		return contracts.MockExamSession{}, fmt.Errorf("insert mock exam session: %w", err)
	}

	for _, sec := range sections {
		if _, err := tx.ExecContext(ctx,
			`INSERT INTO mock_exam_sections (session_id, sequence_no, exercise_id, exercise_type, max_points, status) VALUES ($1,$2,$3,$4,$5,'pending')`,
			id, sec.SequenceNo, sec.ExerciseID, sec.ExerciseType, sec.MaxPoints,
		); err != nil {
			return contracts.MockExamSession{}, fmt.Errorf("insert mock exam section: %w", err)
		}
	}

	if err := tx.Commit(); err != nil {
		return contracts.MockExamSession{}, fmt.Errorf("commit mock exam: %w", err)
	}

	return contracts.MockExamSession{
		ID:                   id,
		LearnerID:            learnerID,
		Status:               "in_progress",
		MockTestID:           mockTestID,
		PassThresholdPercent: threshold,
		Sections:             sections,
	}, nil
}

func (s *postgresMockExamStore) MockExamByID(id string) (contracts.MockExamSession, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var session contracts.MockExamSession
	err := s.db.QueryRowContext(ctx,
		`SELECT id, learner_id, status, mock_test_id, overall_score, passed, pass_threshold_percent, overall_readiness_level, overall_summary FROM mock_exam_sessions WHERE id = $1`,
		id,
	).Scan(&session.ID, &session.LearnerID, &session.Status, &session.MockTestID, &session.OverallScore, &session.Passed, &session.PassThresholdPercent, &session.OverallReadinessLevel, &session.OverallSummary)
	if err == sql.ErrNoRows {
		return contracts.MockExamSession{}, false
	}
	if err != nil {
		return contracts.MockExamSession{}, false
	}

	rows, err := s.db.QueryContext(ctx,
		`SELECT sequence_no, exercise_id, exercise_type, max_points, attempt_id, section_score, status FROM mock_exam_sections WHERE session_id = $1 ORDER BY sequence_no`,
		id,
	)
	if err != nil {
		return contracts.MockExamSession{}, false
	}
	defer rows.Close()

	for rows.Next() {
		var sec contracts.MockExamSessionItem
		if err := rows.Scan(&sec.SequenceNo, &sec.ExerciseID, &sec.ExerciseType, &sec.MaxPoints, &sec.AttemptID, &sec.SectionScore, &sec.Status); err != nil {
			return contracts.MockExamSession{}, false
		}
		sec.SkillKind = skillKindForExerciseType(sec.ExerciseType)
		session.Sections = append(session.Sections, sec)
	}
	return session, true
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

	var sequenceNo int
	var sectionExerciseID string
	err := s.db.QueryRowContext(ctx,
		`SELECT sequence_no, exercise_id FROM mock_exam_sections WHERE session_id = $1 AND status = 'pending' ORDER BY sequence_no LIMIT 1`,
		id,
	).Scan(&sequenceNo, &sectionExerciseID)
	if err == sql.ErrNoRows {
		return contracts.MockExamSession{}, fmt.Errorf("no pending section")
	}
	if err != nil {
		return contracts.MockExamSession{}, fmt.Errorf("query pending section: %w", err)
	}

	var attemptExerciseID string
	if err := s.db.QueryRowContext(ctx, `SELECT exercise_id FROM attempts WHERE id = $1`, attemptID).Scan(&attemptExerciseID); err == sql.ErrNoRows {
		return contracts.MockExamSession{}, fmt.Errorf("attempt not found")
	} else if err != nil {
		return contracts.MockExamSession{}, fmt.Errorf("query attempt: %w", err)
	}
	if attemptExerciseID != sectionExerciseID {
		return contracts.MockExamSession{}, fmt.Errorf("attempt exercise does not match section %d", sequenceNo)
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

	var pendingCount int
	if err := s.db.QueryRowContext(ctx,
		`SELECT COUNT(*) FROM mock_exam_sections WHERE session_id = $1 AND status != 'completed'`, id,
	).Scan(&pendingCount); err != nil {
		return contracts.MockExamSession{}, fmt.Errorf("check sections: %w", err)
	}
	if pendingCount > 0 {
		return contracts.MockExamSession{}, fmt.Errorf("%d section(s) not yet completed", pendingCount)
	}

	// Load sections with attempt IDs, max_points, and feedback payloads.
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
