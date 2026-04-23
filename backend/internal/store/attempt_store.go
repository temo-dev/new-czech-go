package store

import (
	"fmt"
	"sync"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

type AttemptStore interface {
	CreateAttempt(userID, exerciseID, exerciseType, clientPlatform, appVersion string) (*contracts.Attempt, error)
	UpdateAttemptRecordingStarted(id string, timestamp string) (*contracts.Attempt, bool)
	RecordUploadTargetIssued(id, storageKey string) (*contracts.Attempt, bool)
	MarkUploadComplete(id string, audio contracts.AttemptAudio) (*contracts.Attempt, bool)
	SetAttemptStatus(id, status string)
	CompleteAttempt(id string, transcript contracts.Transcript, feedback contracts.AttemptFeedback)
	UpsertReviewArtifact(id string, artifact contracts.AttemptReviewArtifact) (*contracts.AttemptReviewArtifact, bool)
	ReviewArtifact(id string) (*contracts.AttemptReviewArtifact, bool)
	FailAttempt(id, failureCode string)
	Attempt(id string) (*contracts.Attempt, bool)
	ListAttempts() []contracts.Attempt
}

type memoryAttemptStore struct {
	mu           sync.RWMutex
	attempts     map[string]*contracts.Attempt
	reviews      map[string]*contracts.AttemptReviewArtifact
	attemptOrder map[string]int
	nextAttempt  int
}

func newMemoryAttemptStore() *memoryAttemptStore {
	return &memoryAttemptStore{
		attempts:     map[string]*contracts.Attempt{},
		reviews:      map[string]*contracts.AttemptReviewArtifact{},
		attemptOrder: map[string]int{},
		nextAttempt:  1,
	}
}

func (s *memoryAttemptStore) CreateAttempt(userID, exerciseID, exerciseType, clientPlatform, appVersion string) (*contracts.Attempt, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	key := attemptCounterKey(userID, exerciseID)
	s.attemptOrder[key]++

	id := fmt.Sprintf("attempt-%d", s.nextAttempt)
	s.nextAttempt++

	attempt := &contracts.Attempt{
		ID:             id,
		UserID:         userID,
		ExerciseID:     exerciseID,
		ExerciseType:   exerciseType,
		Status:         "created",
		AttemptNo:      s.attemptOrder[key],
		StartedAt:      time.Now().UTC().Format(time.RFC3339),
		ClientPlatform: clientPlatform,
		AppVersion:     appVersion,
	}
	s.attempts[id] = attempt
	return cloneAttempt(attempt), nil
}

func (s *memoryAttemptStore) UpdateAttemptRecordingStarted(id string, timestamp string) (*contracts.Attempt, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()

	attempt, ok := s.attempts[id]
	if !ok {
		return nil, false
	}
	attempt.Status = "recording_started"
	attempt.RecordingStartedAt = timestamp
	return cloneAttempt(attempt), true
}

func (s *memoryAttemptStore) RecordUploadTargetIssued(id, storageKey string) (*contracts.Attempt, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()

	attempt, ok := s.attempts[id]
	if !ok {
		return nil, false
	}
	attempt.PendingUploadStorageKey = storageKey
	attempt.UploadTargetIssuedAt = time.Now().UTC().Format(time.RFC3339)
	return cloneAttempt(attempt), true
}

func (s *memoryAttemptStore) MarkUploadComplete(id string, audio contracts.AttemptAudio) (*contracts.Attempt, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()

	attempt, ok := s.attempts[id]
	if !ok {
		return nil, false
	}
	attempt.Status = "recording_uploaded"
	attempt.RecordingUploadedAt = time.Now().UTC().Format(time.RFC3339)
	attempt.PendingUploadStorageKey = ""
	attempt.UploadTargetIssuedAt = ""
	attempt.Audio = &audio
	return cloneAttempt(attempt), true
}

func (s *memoryAttemptStore) SetAttemptStatus(id, status string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if attempt, ok := s.attempts[id]; ok {
		attempt.Status = status
	}
}

func (s *memoryAttemptStore) CompleteAttempt(id string, transcript contracts.Transcript, feedback contracts.AttemptFeedback) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if attempt, ok := s.attempts[id]; ok {
		attempt.Status = "completed"
		attempt.CompletedAt = time.Now().UTC().Format(time.RFC3339)
		attempt.FailedAt = ""
		attempt.FailureCode = ""
		attempt.ReadinessLevel = feedback.ReadinessLevel
		attempt.Transcript = &transcript
		attempt.Feedback = &feedback
	}
}

func (s *memoryAttemptStore) UpsertReviewArtifact(id string, artifact contracts.AttemptReviewArtifact) (*contracts.AttemptReviewArtifact, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()

	attempt, ok := s.attempts[id]
	if !ok {
		return nil, false
	}

	artifact.AttemptID = id
	cloned := cloneReviewArtifact(&artifact)
	s.reviews[id] = cloned
	attempt.ReviewArtifact = buildReviewArtifactSummary(cloned)
	return cloneReviewArtifact(cloned), true
}

func (s *memoryAttemptStore) ReviewArtifact(id string) (*contracts.AttemptReviewArtifact, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	artifact, ok := s.reviews[id]
	if !ok {
		return nil, false
	}
	return cloneReviewArtifact(artifact), true
}

func (s *memoryAttemptStore) FailAttempt(id, failureCode string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if attempt, ok := s.attempts[id]; ok {
		attempt.Status = "failed"
		attempt.FailedAt = time.Now().UTC().Format(time.RFC3339)
		attempt.FailureCode = failureCode
	}
}

func (s *memoryAttemptStore) Attempt(id string) (*contracts.Attempt, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	attempt, ok := s.attempts[id]
	if !ok {
		return nil, false
	}
	return cloneAttempt(attempt), true
}

func (s *memoryAttemptStore) ListAttempts() []contracts.Attempt {
	s.mu.RLock()
	defer s.mu.RUnlock()

	items := make([]contracts.Attempt, 0, len(s.attempts))
	for _, attempt := range s.attempts {
		items = append(items, *cloneAttempt(attempt))
	}
	return items
}

func attemptCounterKey(userID, exerciseID string) string {
	return userID + "|" + exerciseID
}

func cloneAttempt(src *contracts.Attempt) *contracts.Attempt {
	if src == nil {
		return nil
	}
	clone := *src
	if src.Transcript != nil {
		t := *src.Transcript
		clone.Transcript = &t
	}
	if src.Audio != nil {
		audio := *src.Audio
		clone.Audio = &audio
	}
	if src.Feedback != nil {
		f := *src.Feedback
		f.Strengths = append([]string(nil), src.Feedback.Strengths...)
		f.Improvements = append([]string(nil), src.Feedback.Improvements...)
		f.RetryAdvice = append([]string(nil), src.Feedback.RetryAdvice...)
		f.TaskCompletion.CriteriaResults = append([]contracts.CriterionCheck(nil), src.Feedback.TaskCompletion.CriteriaResults...)
		f.GrammarFeedback.Issues = append([]contracts.GrammarIssue(nil), src.Feedback.GrammarFeedback.Issues...)
		clone.Feedback = &f
	}
	if src.ReviewArtifact != nil {
		clone.ReviewArtifact = cloneReviewArtifactSummary(src.ReviewArtifact)
	}
	return &clone
}

func buildReviewArtifactSummary(src *contracts.AttemptReviewArtifact) *contracts.AttemptReviewArtifactSummary {
	if src == nil {
		return nil
	}
	return &contracts.AttemptReviewArtifactSummary{
		Status:         src.Status,
		FailureCode:    src.FailureCode,
		GeneratedAt:    src.GeneratedAt,
		RepairProvider: src.RepairProvider,
	}
}

func cloneReviewArtifactSummary(src *contracts.AttemptReviewArtifactSummary) *contracts.AttemptReviewArtifactSummary {
	if src == nil {
		return nil
	}
	clone := *src
	return &clone
}

func cloneReviewArtifact(src *contracts.AttemptReviewArtifact) *contracts.AttemptReviewArtifact {
	if src == nil {
		return nil
	}
	clone := *src
	if src.SpeakingFocusItems != nil {
		clone.SpeakingFocusItems = append([]contracts.SpeakingFocusItem(nil), src.SpeakingFocusItems...)
	}
	if src.DiffChunks != nil {
		clone.DiffChunks = append([]contracts.DiffChunk(nil), src.DiffChunks...)
	}
	if src.TTSAudio != nil {
		audio := *src.TTSAudio
		clone.TTSAudio = &audio
	}
	return &clone
}
