package store

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"sort"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

type postgresExerciseStore struct {
	db *sql.DB
}

func NewPostgresExerciseStore(databaseURL string) (ExerciseStore, error) {
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

	store := &postgresExerciseStore{db: db}
	if err := store.ensureSchema(ctx); err != nil {
		db.Close()
		return nil, fmt.Errorf("ensure exercise schema: %w", err)
	}
	if err := store.seedDefaults(ctx); err != nil {
		db.Close()
		return nil, fmt.Errorf("seed exercise defaults: %w", err)
	}

	return store, nil
}

func (s *postgresExerciseStore) ensureSchema(ctx context.Context) error {
	_, err := s.db.ExecContext(ctx, `
CREATE TABLE IF NOT EXISTS exercises (
	id TEXT PRIMARY KEY,
	module_id TEXT NOT NULL,
	exercise_type TEXT NOT NULL,
	title TEXT NOT NULL,
	short_instruction TEXT NOT NULL,
	learner_instruction TEXT NOT NULL,
	estimated_duration_sec INTEGER NOT NULL,
	prep_time_sec INTEGER,
	recording_time_limit_sec INTEGER,
	sample_answer_enabled BOOLEAN NOT NULL,
	status TEXT NOT NULL,
	sequence_no INTEGER,
	prompt_json JSONB,
	assets_json JSONB,
	detail_json JSONB,
	scoring_template_preview_json JSONB
);
`)
	return err
}

func (s *postgresExerciseStore) seedDefaults(ctx context.Context) error {
	var count int
	if err := s.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM exercises`).Scan(&count); err != nil {
		return err
	}
	if count > 0 {
		return nil
	}
	for _, exercise := range seedExercises() {
		if err := s.insertExercise(ctx, exercise); err != nil {
			return err
		}
	}
	return nil
}

func (s *postgresExerciseStore) ExercisesByModule(moduleID string) []contracts.Exercise {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	rows, err := s.db.QueryContext(ctx, exerciseSelectQuery+` WHERE module_id = $1 AND status != 'archived'`, moduleID)
	if err != nil {
		return nil
	}
	defer rows.Close()

	items := scanExercises(rows)
	sort.Slice(items, func(i, j int) bool {
		if items[i].SequenceNo == items[j].SequenceNo {
			return items[i].Title < items[j].Title
		}
		return items[i].SequenceNo < items[j].SequenceNo
	})
	return items
}

func (s *postgresExerciseStore) ListExercises() []contracts.Exercise {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	rows, err := s.db.QueryContext(ctx, exerciseSelectQuery+` ORDER BY module_id, sequence_no, title`)
	if err != nil {
		return nil
	}
	defer rows.Close()

	return scanExercises(rows)
}

func (s *postgresExerciseStore) Exercise(id string) (contracts.Exercise, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	row := s.db.QueryRowContext(ctx, exerciseSelectQuery+` WHERE id = $1`, id)
	exercise, err := scanExercise(row.Scan)
	if err == sql.ErrNoRows {
		return contracts.Exercise{}, false
	}
	if err != nil {
		return contracts.Exercise{}, false
	}
	return exercise, true
}

func (s *postgresExerciseStore) CreateExercise(exercise contracts.Exercise) contracts.Exercise {
	if exercise.ID == "" {
		exercise.ID = "exercise-" + newUUIDLikeID()
	}
	if exercise.Status == "" {
		exercise.Status = "draft"
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := s.insertExercise(ctx, exercise); err != nil {
		return contracts.Exercise{}
	}

	created, ok := s.Exercise(exercise.ID)
	if !ok {
		return contracts.Exercise{}
	}
	return created
}

func (s *postgresExerciseStore) UpdateExercise(id string, update contracts.Exercise) (contracts.Exercise, bool) {
	current, ok := s.Exercise(id)
	if !ok {
		return contracts.Exercise{}, false
	}
	merged := mergeExerciseUpdate(current, update)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := s.upsertExercise(ctx, merged); err != nil {
		return contracts.Exercise{}, false
	}
	updated, ok := s.Exercise(id)
	return updated, ok
}

func (s *postgresExerciseStore) DeleteExercise(id string) bool {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	result, err := s.db.ExecContext(ctx, `DELETE FROM exercises WHERE id = $1`, id)
	if err != nil {
		return false
	}
	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return false
	}
	return rowsAffected > 0
}

func (s *postgresExerciseStore) insertExercise(ctx context.Context, exercise contracts.Exercise) error {
	_, err := s.db.ExecContext(
		ctx,
		`INSERT INTO exercises (
			id, module_id, exercise_type, title, short_instruction, learner_instruction,
			estimated_duration_sec, prep_time_sec, recording_time_limit_sec, sample_answer_enabled,
			status, sequence_no, prompt_json, assets_json, detail_json, scoring_template_preview_json
		) VALUES (
			$1, $2, $3, $4, $5, $6,
			$7, $8, $9, $10,
			$11, $12, $13, $14, $15, $16
		)`,
		exercise.ID,
		exercise.ModuleID,
		exercise.ExerciseType,
		exercise.Title,
		exercise.ShortInstruction,
		exercise.LearnerInstruction,
		exercise.EstimatedDurationSec,
		nullIfZero(exercise.PrepTimeSec),
		nullIfZero(exercise.RecordingTimeLimitSec),
		exercise.SampleAnswerEnabled,
		exercise.Status,
		nullIfZero(exercise.SequenceNo),
		jsonValue(exercise.Prompt),
		jsonValue(exercise.Assets),
		jsonValue(exercise.Detail),
		jsonValue(exercise.ScoringTemplatePreview),
	)
	return err
}

func (s *postgresExerciseStore) upsertExercise(ctx context.Context, exercise contracts.Exercise) error {
	_, err := s.db.ExecContext(
		ctx,
		`INSERT INTO exercises (
			id, module_id, exercise_type, title, short_instruction, learner_instruction,
			estimated_duration_sec, prep_time_sec, recording_time_limit_sec, sample_answer_enabled,
			status, sequence_no, prompt_json, assets_json, detail_json, scoring_template_preview_json
		) VALUES (
			$1, $2, $3, $4, $5, $6,
			$7, $8, $9, $10,
			$11, $12, $13, $14, $15, $16
		)
		ON CONFLICT (id) DO UPDATE SET
			module_id = EXCLUDED.module_id,
			exercise_type = EXCLUDED.exercise_type,
			title = EXCLUDED.title,
			short_instruction = EXCLUDED.short_instruction,
			learner_instruction = EXCLUDED.learner_instruction,
			estimated_duration_sec = EXCLUDED.estimated_duration_sec,
			prep_time_sec = EXCLUDED.prep_time_sec,
			recording_time_limit_sec = EXCLUDED.recording_time_limit_sec,
			sample_answer_enabled = EXCLUDED.sample_answer_enabled,
			status = EXCLUDED.status,
			sequence_no = EXCLUDED.sequence_no,
			prompt_json = EXCLUDED.prompt_json,
			assets_json = EXCLUDED.assets_json,
			detail_json = EXCLUDED.detail_json,
			scoring_template_preview_json = EXCLUDED.scoring_template_preview_json`,
		exercise.ID,
		exercise.ModuleID,
		exercise.ExerciseType,
		exercise.Title,
		exercise.ShortInstruction,
		exercise.LearnerInstruction,
		exercise.EstimatedDurationSec,
		nullIfZero(exercise.PrepTimeSec),
		nullIfZero(exercise.RecordingTimeLimitSec),
		exercise.SampleAnswerEnabled,
		exercise.Status,
		nullIfZero(exercise.SequenceNo),
		jsonValue(exercise.Prompt),
		jsonValue(exercise.Assets),
		jsonValue(exercise.Detail),
		jsonValue(exercise.ScoringTemplatePreview),
	)
	return err
}

const exerciseSelectQuery = `
SELECT
	id,
	module_id,
	exercise_type,
	title,
	short_instruction,
	learner_instruction,
	estimated_duration_sec,
	prep_time_sec,
	recording_time_limit_sec,
	sample_answer_enabled,
	status,
	sequence_no,
	prompt_json,
	assets_json,
	detail_json,
	scoring_template_preview_json
FROM exercises
`

func scanExercises(rows *sql.Rows) []contracts.Exercise {
	var items []contracts.Exercise
	for rows.Next() {
		exercise, err := scanExercise(rows.Scan)
		if err != nil {
			continue
		}
		items = append(items, exercise)
	}
	return items
}

func scanExercise(scan scanFunc) (contracts.Exercise, error) {
	var (
		exercise                   contracts.Exercise
		prepTimeSec                sql.NullInt64
		recordingTimeLimitSec      sql.NullInt64
		sequenceNo                 sql.NullInt64
		promptJSON                 []byte
		assetsJSON                 []byte
		detailJSON                 []byte
		scoringTemplatePreviewJSON []byte
	)

	err := scan(
		&exercise.ID,
		&exercise.ModuleID,
		&exercise.ExerciseType,
		&exercise.Title,
		&exercise.ShortInstruction,
		&exercise.LearnerInstruction,
		&exercise.EstimatedDurationSec,
		&prepTimeSec,
		&recordingTimeLimitSec,
		&exercise.SampleAnswerEnabled,
		&exercise.Status,
		&sequenceNo,
		&promptJSON,
		&assetsJSON,
		&detailJSON,
		&scoringTemplatePreviewJSON,
	)
	if err != nil {
		return contracts.Exercise{}, err
	}

	exercise.PrepTimeSec = int(prepTimeSec.Int64)
	exercise.RecordingTimeLimitSec = int(recordingTimeLimitSec.Int64)
	exercise.SequenceNo = int(sequenceNo.Int64)

	if len(promptJSON) > 0 {
		exercise.Prompt = decodePrompt(exercise.ExerciseType, promptJSON)
	}
	if len(detailJSON) > 0 {
		exercise.Detail = decodeAnyJSON(detailJSON)
	}
	if len(assetsJSON) > 0 {
		var assets []contracts.PromptAsset
		if err := json.Unmarshal(assetsJSON, &assets); err == nil {
			exercise.Assets = assets
		}
	}
	if len(scoringTemplatePreviewJSON) > 0 {
		var preview contracts.ScoringPreview
		if err := json.Unmarshal(scoringTemplatePreviewJSON, &preview); err == nil {
			exercise.ScoringTemplatePreview = &preview
		}
	}

	return cloneExercise(exercise), nil
}

func decodePrompt(exerciseType string, payload []byte) any {
	switch exerciseType {
	case "uloha_1_topic_answers":
		var prompt contracts.Uloha1Prompt
		if err := json.Unmarshal(payload, &prompt); err == nil {
			return prompt
		}
	}
	return decodeAnyJSON(payload)
}

func decodeAnyJSON(payload []byte) any {
	var value any
	if err := json.Unmarshal(payload, &value); err != nil {
		return nil
	}
	return value
}

func jsonValue(value any) any {
	if value == nil {
		return nil
	}
	payload, err := json.Marshal(value)
	if err != nil {
		return nil
	}
	return payload
}
