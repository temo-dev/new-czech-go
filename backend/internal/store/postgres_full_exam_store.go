package store

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

type postgresFullExamStore struct{ db *sql.DB }

func NewPostgresFullExamStore(databaseURL string) (FullExamStore, error) {
	db, err := sql.Open("postgres", databaseURL)
	if err != nil {
		return nil, fmt.Errorf("open full_exam db: %w", err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := db.PingContext(ctx); err != nil {
		db.Close()
		return nil, fmt.Errorf("ping full_exam db: %w", err)
	}
	return &postgresFullExamStore{db: db}, nil
}

func (s *postgresFullExamStore) GetFullExamSession(id string) (contracts.FullExamSession, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	var sess contracts.FullExamSession
	var mockTestID, ustniSessionID sql.NullString
	err := s.db.QueryRowContext(ctx,
		`SELECT id, learner_id, COALESCE(mock_test_id,''), pisemna_score, ustni_score,
		        pisemna_passed, ustni_passed, overall_passed, status,
		        COALESCE(ustni_mock_exam_session_id,''),
		        to_char(created_at,'YYYY-MM-DD"T"HH24:MI:SS"Z"')
		 FROM full_exam_sessions WHERE id = $1`, id,
	).Scan(
		&sess.ID, &sess.LearnerID, &mockTestID,
		&sess.PisemnaScore, &sess.UstniScore,
		&sess.PisemnaPassed, &sess.UstniPassed, &sess.OverallPassed,
		&sess.Status, &ustniSessionID, &sess.CreatedAt,
	)
	if err != nil {
		if err != sql.ErrNoRows {
			log.Printf("GetFullExamSession scan error for id=%q: %v", id, err)
		}
		return contracts.FullExamSession{}, false
	}
	sess.MockTestID = mockTestID.String
	sess.UstniMockExamSessionID = ustniSessionID.String
	return sess, true
}

func (s *postgresFullExamStore) SetFullExamSession(session contracts.FullExamSession) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_, err := s.db.ExecContext(ctx,
		`INSERT INTO full_exam_sessions
		    (id, learner_id, mock_test_id, pisemna_score, ustni_score,
		     pisemna_passed, ustni_passed, overall_passed, status,
		     ustni_mock_exam_session_id)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
		 ON CONFLICT (id) DO UPDATE SET
		     pisemna_score = EXCLUDED.pisemna_score,
		     ustni_score   = EXCLUDED.ustni_score,
		     pisemna_passed = EXCLUDED.pisemna_passed,
		     ustni_passed   = EXCLUDED.ustni_passed,
		     overall_passed  = EXCLUDED.overall_passed,
		     status          = EXCLUDED.status,
		     ustni_mock_exam_session_id = EXCLUDED.ustni_mock_exam_session_id`,
		session.ID, session.LearnerID,
		nullStr(session.MockTestID),
		session.PisemnaScore, session.UstniScore,
		session.PisemnaPassed, session.UstniPassed, session.OverallPassed,
		session.Status,
		nullStr(session.UstniMockExamSessionID),
	)
	if err != nil {
		log.Printf("SetFullExamSession upsert error for id=%q: %v", session.ID, err)
	}
}

func (s *postgresFullExamStore) ListFullExamSessions(learnerID string) []contracts.FullExamSession {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	rows, err := s.db.QueryContext(ctx,
		`SELECT id, learner_id, COALESCE(mock_test_id,''), pisemna_score, ustni_score,
		        pisemna_passed, ustni_passed, overall_passed, status,
		        COALESCE(ustni_mock_exam_session_id,''),
		        to_char(created_at,'YYYY-MM-DD"T"HH24:MI:SS"Z"')
		 FROM full_exam_sessions WHERE learner_id = $1 ORDER BY created_at DESC`, learnerID,
	)
	if err != nil {
		log.Printf("ListFullExamSessions error for learner=%q: %v", learnerID, err)
		return nil
	}
	defer rows.Close()
	out := make([]contracts.FullExamSession, 0)
	for rows.Next() {
		var sess contracts.FullExamSession
		var mockTestID, ustniSessionID string
		if err := rows.Scan(
			&sess.ID, &sess.LearnerID, &mockTestID,
			&sess.PisemnaScore, &sess.UstniScore,
			&sess.PisemnaPassed, &sess.UstniPassed, &sess.OverallPassed,
			&sess.Status, &ustniSessionID, &sess.CreatedAt,
		); err != nil {
			log.Printf("ListFullExamSessions scan error: %v", err)
			continue
		}
		sess.MockTestID = mockTestID
		sess.UstniMockExamSessionID = ustniSessionID
		out = append(out, sess)
	}
	return out
}

// nullStr converts an empty string to sql NULL, non-empty to a valid string.
func nullStr(s string) sql.NullString {
	return sql.NullString{String: s, Valid: s != ""}
}
