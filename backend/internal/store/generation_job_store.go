package store

import (
	"encoding/json"
	"fmt"
	"sync"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

type GenerationJobStore interface {
	CreateJob(job contracts.ContentGenerationJob) contracts.ContentGenerationJob
	GetJob(id string) (contracts.ContentGenerationJob, bool)
	UpdateJobRunning(id string)
	UpdateJobGenerated(id string, payload []byte, inputTokens, outputTokens int, costUSD float64, durationMs int)
	UpdateJobFailed(id string, errMsg string)
	UpdateJobDraft(id string, editedPayload []byte) bool
	UpdateJobPublished(id string) bool
	UpdateJobRejected(id string) bool
	FindActiveJob(requestedBy, moduleID string) (contracts.ContentGenerationJob, bool)
	MarkAllRunningFailed(errMsg string)
}

type memoryGenerationJobStore struct {
	mu   sync.RWMutex
	jobs map[string]*contracts.ContentGenerationJob
	next int
}

func newMemoryGenerationJobStore() GenerationJobStore {
	return &memoryGenerationJobStore{
		jobs: make(map[string]*contracts.ContentGenerationJob),
		next: 1,
	}
}

func (s *memoryGenerationJobStore) CreateJob(job contracts.ContentGenerationJob) contracts.ContentGenerationJob {
	s.mu.Lock()
	defer s.mu.Unlock()
	job.ID = fmt.Sprintf("genjob-%d", s.next)
	s.next++
	job.Status = "pending"
	now := time.Now().UTC().Format(time.RFC3339)
	job.CreatedAt = now
	job.UpdatedAt = now
	cp := job
	s.jobs[job.ID] = &cp
	return cp
}

func (s *memoryGenerationJobStore) GetJob(id string) (contracts.ContentGenerationJob, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	j, ok := s.jobs[id]
	if !ok {
		return contracts.ContentGenerationJob{}, false
	}
	return *j, true
}

func (s *memoryGenerationJobStore) UpdateJobRunning(id string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if j, ok := s.jobs[id]; ok {
		j.Status = "running"
		j.UpdatedAt = time.Now().UTC().Format(time.RFC3339)
	}
}

func (s *memoryGenerationJobStore) UpdateJobGenerated(id string, payload []byte, inputTokens, outputTokens int, costUSD float64, durationMs int) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if j, ok := s.jobs[id]; ok {
		j.Status = "generated"
		j.GeneratedPayload = payload
		j.EditedPayload = payload // start with generated as edited
		j.InputTokens = inputTokens
		j.OutputTokens = outputTokens
		j.EstimatedCostUSD = costUSD
		j.DurationMs = durationMs
		j.UpdatedAt = time.Now().UTC().Format(time.RFC3339)
	}
}

func (s *memoryGenerationJobStore) UpdateJobFailed(id string, errMsg string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if j, ok := s.jobs[id]; ok {
		j.Status = "failed"
		j.ErrorMessage = errMsg
		j.UpdatedAt = time.Now().UTC().Format(time.RFC3339)
	}
}

func (s *memoryGenerationJobStore) UpdateJobDraft(id string, editedPayload []byte) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	j, ok := s.jobs[id]
	if !ok {
		return false
	}
	j.EditedPayload = editedPayload
	j.UpdatedAt = time.Now().UTC().Format(time.RFC3339)
	return true
}

func (s *memoryGenerationJobStore) UpdateJobPublished(id string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	j, ok := s.jobs[id]
	if !ok {
		return false
	}
	j.Status = "published"
	now := time.Now().UTC().Format(time.RFC3339)
	j.UpdatedAt = now
	j.PublishedAt = now
	return true
}

func (s *memoryGenerationJobStore) UpdateJobRejected(id string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	j, ok := s.jobs[id]
	if !ok {
		return false
	}
	j.Status = "rejected"
	j.UpdatedAt = time.Now().UTC().Format(time.RFC3339)
	return true
}

func (s *memoryGenerationJobStore) FindActiveJob(requestedBy, moduleID string) (contracts.ContentGenerationJob, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	for _, j := range s.jobs {
		if j.RequestedBy == requestedBy && j.ModuleID == moduleID &&
			(j.Status == "pending" || j.Status == "running") {
			return *j, true
		}
	}
	return contracts.ContentGenerationJob{}, false
}

func (s *memoryGenerationJobStore) MarkAllRunningFailed(errMsg string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	now := time.Now().UTC().Format(time.RFC3339)
	for _, j := range s.jobs {
		if j.Status == "running" {
			j.Status = "failed"
			j.ErrorMessage = errMsg
			j.UpdatedAt = now
		}
	}
}

// JobViewFromDB converts raw JSON fields to a JSON-serializable view for API responses.
func JobViewFromDB(job contracts.ContentGenerationJob) map[string]any {
	view := map[string]any{
		"id":          job.ID,
		"module_id":   job.ModuleID,
		"source_type": job.SourceType,
		"source_id":    job.SourceID,
		"status":       job.Status,
		"provider":     job.Provider,
		"model":        job.Model,
		"created_at":   job.CreatedAt,
		"updated_at":   job.UpdatedAt,
	}
	if job.InputTokens > 0 {
		view["input_tokens"] = job.InputTokens
		view["output_tokens"] = job.OutputTokens
	}
	if job.EstimatedCostUSD > 0 {
		view["estimated_cost_usd"] = job.EstimatedCostUSD
	}
	if job.ErrorMessage != "" {
		view["error_message"] = job.ErrorMessage
	}
	if job.PublishedAt != "" {
		view["published_at"] = job.PublishedAt
	}
	if len(job.GeneratedPayload) > 0 {
		var gp any
		if err := json.Unmarshal(job.GeneratedPayload, &gp); err == nil {
			view["generated_payload"] = gp
		}
	}
	if len(job.EditedPayload) > 0 {
		var ep any
		if err := json.Unmarshal(job.EditedPayload, &ep); err == nil {
			view["edited_payload"] = ep
		}
	}
	return view
}
