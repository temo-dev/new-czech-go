package store

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

type postgresExerciseAudioStore struct{ db *sql.DB }

func NewPostgresExerciseAudioStore(databaseURL string) (ExerciseAudioStore, error) {
	db, err := sql.Open("postgres", databaseURL)
	if err != nil {
		return nil, fmt.Errorf("open exercise_audio db: %w", err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := db.PingContext(ctx); err != nil {
		db.Close()
		return nil, fmt.Errorf("ping exercise_audio db: %w", err)
	}
	return &postgresExerciseAudioStore{db: db}, nil
}

func (s *postgresExerciseAudioStore) ExerciseAudioByExercise(exerciseID string) (*contracts.ExerciseAudio, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	var a contracts.ExerciseAudio
	err := s.db.QueryRowContext(ctx,
		`SELECT exercise_id, storage_key, mime_type, source_type,
		        to_char(generated_at,'YYYY-MM-DD"T"HH24:MI:SS"Z"')
		 FROM exercise_audio WHERE exercise_id = $1`, exerciseID,
	).Scan(&a.ExerciseID, &a.StorageKey, &a.MimeType, &a.SourceType, &a.GeneratedAt)
	if err != nil {
		if err != sql.ErrNoRows {
			log.Printf("ExerciseAudioByExercise scan error for id=%q: %v", exerciseID, err)
		}
		return nil, false
	}
	return &a, true
}

func (s *postgresExerciseAudioStore) SetExerciseAudio(exerciseID string, audio contracts.ExerciseAudio) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_, err := s.db.ExecContext(ctx,
		`INSERT INTO exercise_audio (exercise_id, storage_key, mime_type, source_type)
		 VALUES ($1,$2,$3,$4)
		 ON CONFLICT (exercise_id) DO UPDATE SET
		     storage_key  = EXCLUDED.storage_key,
		     mime_type    = EXCLUDED.mime_type,
		     source_type  = EXCLUDED.source_type,
		     generated_at = NOW()`,
		exerciseID, audio.StorageKey, audio.MimeType, audio.SourceType,
	)
	if err != nil {
		log.Printf("SetExerciseAudio upsert error for id=%q: %v", exerciseID, err)
	}
}
