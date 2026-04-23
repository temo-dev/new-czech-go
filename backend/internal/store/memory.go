package store

import (
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

type MemoryStore struct {
	mu           sync.RWMutex
	usersByToken map[string]contracts.User
	course       contracts.Course
	plan         contracts.LearningPlan
	modules      []contracts.Module
	exercises    ExerciseStore
	attempts     AttemptStore
	mockExam     contracts.MockExamSession
}

func NewMemoryStore() *MemoryStore {
	return NewMemoryStoreWithStores(newMemoryAttemptStore(), newMemoryExerciseStore(seedExercises()))
}

func NewMemoryStoreWithAttemptStore(attempts AttemptStore) *MemoryStore {
	return NewMemoryStoreWithStores(attempts, newMemoryExerciseStore(seedExercises()))
}

func NewMemoryStoreWithStores(attempts AttemptStore, exercises ExerciseStore) *MemoryStore {
	if attempts == nil {
		attempts = newMemoryAttemptStore()
	}
	if exercises == nil {
		exercises = newMemoryExerciseStore(seedExercises())
	}

	initialExercises := exercises.ListExercises()
	exercise1 := firstExerciseByID(initialExercises, "exercise-uloha1-weather")
	exercise2 := firstExerciseByID(initialExercises, "exercise-uloha3-tv")

	return &MemoryStore{
		usersByToken: map[string]contracts.User{
			"dev-learner-token": {
				ID:                "user-learner-1",
				Role:              "learner",
				Email:             "learner@example.com",
				DisplayName:       "Nguyen An",
				PreferredLanguage: "vi",
			},
			"dev-learner-2-token": {
				ID:                "user-learner-2",
				Role:              "learner",
				Email:             "learner2@example.com",
				DisplayName:       "Tran Binh",
				PreferredLanguage: "vi",
			},
			"dev-admin-token": {
				ID:                "user-admin-1",
				Role:              "admin",
				Email:             "admin@example.com",
				DisplayName:       "CMS Admin",
				PreferredLanguage: "vi",
			},
		},
		course: contracts.Course{
			ID:    "course-a2-mluveni",
			Slug:  "a2-mluveni-sprint",
			Title: "A2 Mluveni Sprint",
		},
		plan: contracts.LearningPlan{
			StartDate:  time.Now().Format("2006-01-02"),
			CurrentDay: 1,
			Status:     "active",
		},
		modules: []contracts.Module{
			{ID: "module-day-1", Slug: "day-1", Title: "Day 1", ModuleKind: "daily_plan", SequenceNo: 1, Description: "Lam quen voi cau hoi theo chu de."},
			{ID: "module-day-2", Slug: "day-2", Title: "Day 2", ModuleKind: "daily_plan", SequenceNo: 2, Description: "Ke chuyen theo tranh."},
			{ID: "module-mock", Slug: "mock-1", Title: "Mock Oral Exam", ModuleKind: "mock_exam", SequenceNo: 3, Description: "Bai thi noi tong hop."},
		},
		exercises: exercises,
		attempts:  attempts,
		mockExam: contracts.MockExamSession{
			ID:     "mock-session-demo",
			Status: "created",
			Sections: []contracts.MockExamSessionItem{
				{SequenceNo: 1, ExerciseID: exercise1.ID, ExerciseType: exercise1.ExerciseType, Status: "pending"},
				{SequenceNo: 2, ExerciseID: exercise2.ID, ExerciseType: exercise2.ExerciseType, Status: "pending"},
			},
		},
	}
}

func (s *MemoryStore) Login(email, password string) (string, contracts.User, bool) {
	if password != "demo123" {
		return "", contracts.User{}, false
	}
	switch strings.ToLower(strings.TrimSpace(email)) {
	case "learner@example.com":
		return "dev-learner-token", s.usersByToken["dev-learner-token"], true
	case "admin@example.com":
		return "dev-admin-token", s.usersByToken["dev-admin-token"], true
	default:
		return "", contracts.User{}, false
	}
}

func (s *MemoryStore) UserByToken(token string) (contracts.User, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	user, ok := s.usersByToken[token]
	return user, ok
}

func (s *MemoryStore) Course() contracts.Course {
	return s.course
}

func (s *MemoryStore) Plan() contracts.LearningPlan {
	return s.plan
}

func (s *MemoryStore) Modules(kind string) []contracts.Module {
	if kind == "" {
		return append([]contracts.Module(nil), s.modules...)
	}
	var filtered []contracts.Module
	for _, module := range s.modules {
		if module.ModuleKind == kind {
			filtered = append(filtered, module)
		}
	}
	return filtered
}

func (s *MemoryStore) ExercisesByModule(moduleID string) []contracts.Exercise {
	return s.exercises.ExercisesByModule(moduleID)
}

func (s *MemoryStore) ListExercises() []contracts.Exercise {
	return s.exercises.ListExercises()
}

func (s *MemoryStore) Exercise(id string) (contracts.Exercise, bool) {
	return s.exercises.Exercise(id)
}

func (s *MemoryStore) CreateExercise(exercise contracts.Exercise) contracts.Exercise {
	return s.exercises.CreateExercise(exercise)
}

func (s *MemoryStore) UpdateExercise(id string, update contracts.Exercise) (contracts.Exercise, bool) {
	return s.exercises.UpdateExercise(id, update)
}

func (s *MemoryStore) DeleteExercise(id string) bool {
	return s.exercises.DeleteExercise(id)
}

func (s *MemoryStore) CreateAttempt(userID, exerciseID, clientPlatform, appVersion, locale string) (*contracts.Attempt, error) {
	s.mu.RLock()
	exercise, ok := s.exercises.Exercise(exerciseID)
	s.mu.RUnlock()
	if !ok {
		return nil, fmt.Errorf("exercise not found")
	}
	if locale == "" {
		locale = contracts.DefaultLocale
	}
	return s.attempts.CreateAttempt(userID, exerciseID, exercise.ExerciseType, clientPlatform, appVersion, locale)
}

func (s *MemoryStore) UpdateAttemptRecordingStarted(id string, timestamp string) (*contracts.Attempt, bool) {
	return s.attempts.UpdateAttemptRecordingStarted(id, timestamp)
}

func (s *MemoryStore) RecordUploadTargetIssued(id, storageKey string) (*contracts.Attempt, bool) {
	return s.attempts.RecordUploadTargetIssued(id, storageKey)
}

func (s *MemoryStore) MarkUploadComplete(id string, audio contracts.AttemptAudio) (*contracts.Attempt, bool) {
	return s.attempts.MarkUploadComplete(id, audio)
}

func (s *MemoryStore) SetAttemptStatus(id, status string) {
	s.attempts.SetAttemptStatus(id, status)
}

func (s *MemoryStore) CompleteAttempt(id string, transcript contracts.Transcript, feedback contracts.AttemptFeedback) {
	s.attempts.CompleteAttempt(id, transcript, feedback)
}

func (s *MemoryStore) UpsertReviewArtifact(id string, artifact contracts.AttemptReviewArtifact) (*contracts.AttemptReviewArtifact, bool) {
	return s.attempts.UpsertReviewArtifact(id, artifact)
}

func (s *MemoryStore) ReviewArtifact(id string) (*contracts.AttemptReviewArtifact, bool) {
	return s.attempts.ReviewArtifact(id)
}

func (s *MemoryStore) FailAttempt(id, failureCode string) {
	s.attempts.FailAttempt(id, failureCode)
}

func (s *MemoryStore) Attempt(id string) (*contracts.Attempt, bool) {
	return s.attempts.Attempt(id)
}

func (s *MemoryStore) ListAttempts() []contracts.Attempt {
	return s.attempts.ListAttempts()
}

func (s *MemoryStore) MockExam() contracts.MockExamSession {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.mockExam
}

func firstExerciseByID(items []contracts.Exercise, id string) contracts.Exercise {
	for _, exercise := range items {
		if exercise.ID == id {
			return exercise
		}
	}
	return contracts.Exercise{ID: id}
}
