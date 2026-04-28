package store

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

type postgresGenerationJobStore struct{ db *sql.DB }

func NewPostgresGenerationJobStore(databaseURL string) (GenerationJobStore, error) {
	db, err := sql.Open("postgres", databaseURL)
	if err != nil {
		return nil, fmt.Errorf("open generation_job db: %w", err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := db.PingContext(ctx); err != nil {
		db.Close()
		return nil, fmt.Errorf("ping generation_job db: %w", err)
	}
	return &postgresGenerationJobStore{db: db}, nil
}

func (s *postgresGenerationJobStore) CreateJob(job contracts.ContentGenerationJob) contracts.ContentGenerationJob {
	if job.ID == "" {
		job.ID = "genjob-" + newUUIDLikeID()
	}
	if job.Status == "" {
		job.Status = "pending"
	}
	if job.Provider == "" {
		job.Provider = "claude"
	}
	if len(job.InputPayload) == 0 {
		job.InputPayload = []byte("{}")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_, insertErr := s.db.ExecContext(ctx,
		`INSERT INTO content_generation_jobs
		    (id, module_id, skill_id, source_type, source_id, requested_by,
		     input_payload_json, status, provider, model)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
		job.ID, job.ModuleID, job.SkillID, job.SourceType, job.SourceID,
		job.RequestedBy, job.InputPayload, job.Status, job.Provider, job.Model,
	)
	if insertErr != nil {
		log.Printf("CreateJob INSERT failed for %s: %v", job.ID, insertErr)
	}
	// Return the job directly — do NOT re-fetch via GetJob.
	// GetJob can fail on scan type mismatches, returning an empty ID that
	// causes the goroutine to call UpdateJob with "" and silently no-op.
	return job
}

func (s *postgresGenerationJobStore) GetJob(id string) (contracts.ContentGenerationJob, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	var j contracts.ContentGenerationJob
	var skillID sql.NullString
	var genPayload, editPayload sql.RawBytes
	var inputTokens, outputTokens sql.NullInt64
	var costUSD sql.NullFloat64
	var durationMs sql.NullInt64
	var errMsg sql.NullString
	var publishedAt sql.NullString
	err := s.db.QueryRowContext(ctx,
		`SELECT id, module_id, COALESCE(skill_id,''), source_type, source_id, requested_by,
		        input_payload_json, COALESCE(generated_payload_json,'{}'), COALESCE(edited_payload_json,'{}'),
		        status, provider, model,
		        input_tokens, output_tokens, estimated_cost_usd, duration_ms, error_message,
		        to_char(created_at,'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
		        to_char(updated_at,'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
		        to_char(published_at,'YYYY-MM-DD"T"HH24:MI:SS"Z"')
		 FROM content_generation_jobs WHERE id = $1`, id,
	).Scan(
		&j.ID, &j.ModuleID, &skillID, &j.SourceType, &j.SourceID, &j.RequestedBy,
		&j.InputPayload, &genPayload, &editPayload,
		&j.Status, &j.Provider, &j.Model,
		&inputTokens, &outputTokens, &costUSD, &durationMs, &errMsg,
		&j.CreatedAt, &j.UpdatedAt, &publishedAt,
	)
	if err != nil {
		return contracts.ContentGenerationJob{}, false
	}
	j.SkillID = skillID.String
	if len(genPayload) > 0 && string(genPayload) != "{}" {
		j.GeneratedPayload = []byte(genPayload)
	}
	if len(editPayload) > 0 && string(editPayload) != "{}" {
		j.EditedPayload = []byte(editPayload)
	}
	if inputTokens.Valid {
		j.InputTokens = int(inputTokens.Int64)
	}
	if outputTokens.Valid {
		j.OutputTokens = int(outputTokens.Int64)
	}
	if costUSD.Valid {
		j.EstimatedCostUSD = costUSD.Float64
	}
	if durationMs.Valid {
		j.DurationMs = int(durationMs.Int64)
	}
	if errMsg.Valid {
		j.ErrorMessage = errMsg.String
	}
	if publishedAt.Valid {
		j.PublishedAt = publishedAt.String
	}
	return j, true
}

func (s *postgresGenerationJobStore) UpdateJobRunning(id string) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	s.db.ExecContext(ctx,
		`UPDATE content_generation_jobs SET status='running', updated_at=now() WHERE id=$1`, id)
}

func (s *postgresGenerationJobStore) UpdateJobGenerated(id string, payload []byte, inputTokens, outputTokens int, costUSD float64, durationMs int) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	s.db.ExecContext(ctx,
		`UPDATE content_generation_jobs SET
		    status='generated',
		    generated_payload_json=$2,
		    edited_payload_json=$2,
		    input_tokens=$3, output_tokens=$4,
		    estimated_cost_usd=$5, duration_ms=$6,
		    updated_at=now()
		 WHERE id=$1`,
		id, payload, inputTokens, outputTokens, costUSD, durationMs,
	)
}

func (s *postgresGenerationJobStore) UpdateJobFailed(id string, errMsg string) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	s.db.ExecContext(ctx,
		`UPDATE content_generation_jobs SET status='failed', error_message=$2, updated_at=now() WHERE id=$1`,
		id, errMsg)
}

func (s *postgresGenerationJobStore) UpdateJobDraft(id string, editedPayload []byte) bool {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	res, err := s.db.ExecContext(ctx,
		`UPDATE content_generation_jobs SET edited_payload_json=$2, updated_at=now() WHERE id=$1`,
		id, editedPayload)
	if err != nil {
		return false
	}
	n, _ := res.RowsAffected()
	return n > 0
}

func (s *postgresGenerationJobStore) UpdateJobPublished(id string) bool {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	res, err := s.db.ExecContext(ctx,
		`UPDATE content_generation_jobs SET status='published', published_at=now(), updated_at=now() WHERE id=$1`, id)
	if err != nil {
		return false
	}
	n, _ := res.RowsAffected()
	return n > 0
}

func (s *postgresGenerationJobStore) UpdateJobRejected(id string) bool {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	res, err := s.db.ExecContext(ctx,
		`UPDATE content_generation_jobs SET status='rejected', updated_at=now() WHERE id=$1`, id)
	if err != nil {
		return false
	}
	n, _ := res.RowsAffected()
	return n > 0
}

func (s *postgresGenerationJobStore) FindActiveJob(requestedBy, moduleID string) (contracts.ContentGenerationJob, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	var id string
	err := s.db.QueryRowContext(ctx,
		`SELECT id FROM content_generation_jobs
		 WHERE requested_by=$1 AND module_id=$2 AND status IN ('pending','running')
		 LIMIT 1`,
		requestedBy, moduleID,
	).Scan(&id)
	if err != nil {
		return contracts.ContentGenerationJob{}, false
	}
	return s.GetJob(id)
}

func (s *postgresGenerationJobStore) MarkAllRunningFailed(errMsg string) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	s.db.ExecContext(ctx,
		`UPDATE content_generation_jobs SET status='failed', error_message=$1, updated_at=now()
		 WHERE status='running'`, errMsg)
}
