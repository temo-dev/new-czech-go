package store

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// postgresExerciseSentenceAudioStore persists V18 dictation per-sentence
// audio. The table exercise_sentence_audio is created idempotently on first
// connect so deployments that haven't yet run goose migration 024 still come
// up cleanly.
type postgresExerciseSentenceAudioStore struct{ db *sql.DB }

const createExerciseSentenceAudioTableSQL = `
CREATE TABLE IF NOT EXISTS exercise_sentence_audio (
    exercise_id  TEXT        NOT NULL,
    sentence_idx INT         NOT NULL,
    storage_key  TEXT        NOT NULL,
    mime_type    TEXT        NOT NULL DEFAULT 'audio/mpeg',
    source_type  TEXT        NOT NULL DEFAULT 'polly',
    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (exercise_id, sentence_idx)
)`

const createExerciseSentenceAudioIndexSQL = `
CREATE INDEX IF NOT EXISTS idx_exercise_sentence_audio_exercise
    ON exercise_sentence_audio (exercise_id)`

func NewPostgresExerciseSentenceAudioStore(databaseURL string) (ExerciseSentenceAudioStore, error) {
	db, err := openPostgresPool(databaseURL, "exercise_sentence_audio")
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if _, err := db.ExecContext(ctx, createExerciseSentenceAudioTableSQL); err != nil {
		db.Close()
		return nil, fmt.Errorf("create exercise_sentence_audio: %w", err)
	}
	if _, err := db.ExecContext(ctx, createExerciseSentenceAudioIndexSQL); err != nil {
		log.Printf("create exercise_sentence_audio index (non-fatal): %v", err)
	}
	return &postgresExerciseSentenceAudioStore{db: db}, nil
}

func (s *postgresExerciseSentenceAudioStore) SentenceAudio(exerciseID string, sentenceIdx int) (*contracts.ExerciseSentenceAudio, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	var a contracts.ExerciseSentenceAudio
	err := s.db.QueryRowContext(ctx,
		`SELECT exercise_id, sentence_idx, storage_key, mime_type, source_type,
		        to_char(generated_at,'YYYY-MM-DD"T"HH24:MI:SS"Z"')
		 FROM exercise_sentence_audio WHERE exercise_id = $1 AND sentence_idx = $2`,
		exerciseID, sentenceIdx,
	).Scan(&a.ExerciseID, &a.SentenceIdx, &a.StorageKey, &a.MimeType, &a.SourceType, &a.GeneratedAt)
	if err != nil {
		if err != sql.ErrNoRows {
			log.Printf("SentenceAudio scan error for ex=%q idx=%d: %v", exerciseID, sentenceIdx, err)
		}
		return nil, false
	}
	return &a, true
}

func (s *postgresExerciseSentenceAudioStore) SentenceAudiosByExercise(exerciseID string) []contracts.ExerciseSentenceAudio {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	rows, err := s.db.QueryContext(ctx,
		`SELECT exercise_id, sentence_idx, storage_key, mime_type, source_type,
		        to_char(generated_at,'YYYY-MM-DD"T"HH24:MI:SS"Z"')
		 FROM exercise_sentence_audio
		 WHERE exercise_id = $1
		 ORDER BY sentence_idx ASC`, exerciseID,
	)
	if err != nil {
		log.Printf("SentenceAudiosByExercise query error for ex=%q: %v", exerciseID, err)
		return nil
	}
	defer rows.Close()
	var out []contracts.ExerciseSentenceAudio
	for rows.Next() {
		var a contracts.ExerciseSentenceAudio
		if err := rows.Scan(&a.ExerciseID, &a.SentenceIdx, &a.StorageKey, &a.MimeType, &a.SourceType, &a.GeneratedAt); err != nil {
			log.Printf("SentenceAudiosByExercise scan error: %v", err)
			continue
		}
		out = append(out, a)
	}
	return out
}

func (s *postgresExerciseSentenceAudioStore) SetSentenceAudio(exerciseID string, sentenceIdx int, audio contracts.ExerciseAudio) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_, err := s.db.ExecContext(ctx,
		`INSERT INTO exercise_sentence_audio (exercise_id, sentence_idx, storage_key, mime_type, source_type)
		 VALUES ($1,$2,$3,$4,$5)
		 ON CONFLICT (exercise_id, sentence_idx) DO UPDATE SET
		     storage_key  = EXCLUDED.storage_key,
		     mime_type    = EXCLUDED.mime_type,
		     source_type  = EXCLUDED.source_type,
		     generated_at = NOW()`,
		exerciseID, sentenceIdx, audio.StorageKey, audio.MimeType, audio.SourceType,
	)
	if err != nil {
		log.Printf("SetSentenceAudio upsert error for ex=%q idx=%d: %v", exerciseID, sentenceIdx, err)
	}
}

func (s *postgresExerciseSentenceAudioStore) DeleteSentenceAudio(exerciseID string, sentenceIdx int) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if _, err := s.db.ExecContext(ctx,
		`DELETE FROM exercise_sentence_audio WHERE exercise_id = $1 AND sentence_idx = $2`,
		exerciseID, sentenceIdx,
	); err != nil {
		return fmt.Errorf("delete sentence audio: %w", err)
	}
	return nil
}
