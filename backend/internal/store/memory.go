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
	exercises    map[string]contracts.Exercise
	attempts     map[string]*contracts.Attempt
	attemptOrder map[string]int
	mockExam     contracts.MockExamSession
	nextExercise int
	nextAttempt  int
}

func NewMemoryStore() *MemoryStore {
	exercise1 := contracts.Exercise{
		ID:                    "exercise-uloha1-weather",
		ModuleID:              "module-day-1",
		ExerciseType:          "uloha_1_topic_answers",
		Title:                 "Pocasi 1",
		ShortInstruction:      "Tra loi ngan gon theo chu de thoi tiet.",
		LearnerInstruction:    "Ban se tra loi 4 cau hoi ngan ve chu de thoi tiet.",
		EstimatedDurationSec:  90,
		PrepTimeSec:           10,
		RecordingTimeLimitSec: 45,
		SampleAnswerEnabled:   true,
		Status:                "published",
		SequenceNo:            1,
		Prompt: contracts.Uloha1Prompt{
			TopicLabel: "Pocasi",
			QuestionPrompts: []string{
				"Ve kterem mesici v Cesku casto snezi a mrzne?",
				"Jake pocasi mate rad/a a proc?",
				"Kdy naposledy prselo?",
				"Jake pocasi bude zitra?",
			},
		},
		ScoringTemplatePreview: &contracts.ScoringPreview{
			RubricVersion: "v1",
			FeedbackStyle: "supportive_direct_vi",
		},
	}
	exercise2 := contracts.Exercise{
		ID:                    "exercise-uloha3-tv",
		ModuleID:              "module-day-2",
		ExerciseType:          "uloha_3_story_narration",
		Title:                 "Nakup televize",
		ShortInstruction:      "Ke lai pribeh theo 4 tranh.",
		LearnerInstruction:    "Ban hay noi lai cau chuyen theo 4 tranh va dung qua khu.",
		EstimatedDurationSec:  120,
		PrepTimeSec:           15,
		RecordingTimeLimitSec: 60,
		SampleAnswerEnabled:   true,
		Status:                "published",
		SequenceNo:            1,
	}

	return &MemoryStore{
		usersByToken: map[string]contracts.User{
			"dev-learner-token": {
				ID:                "user-learner-1",
				Role:              "learner",
				Email:             "learner@example.com",
				DisplayName:       "Nguyen An",
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
		exercises: map[string]contracts.Exercise{
			exercise1.ID: exercise1,
			exercise2.ID: exercise2,
		},
		attempts:     map[string]*contracts.Attempt{},
		attemptOrder: map[string]int{},
		mockExam: contracts.MockExamSession{
			ID:     "mock-session-demo",
			Status: "created",
			Sections: []contracts.MockExamSessionItem{
				{SequenceNo: 1, ExerciseID: exercise1.ID, ExerciseType: exercise1.ExerciseType, Status: "pending"},
				{SequenceNo: 2, ExerciseID: exercise2.ID, ExerciseType: exercise2.ExerciseType, Status: "pending"},
			},
		},
		nextExercise: 3,
		nextAttempt:  1,
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
	s.mu.RLock()
	defer s.mu.RUnlock()
	var items []contracts.Exercise
	for _, exercise := range s.exercises {
		if exercise.ModuleID == moduleID && exercise.Status != "archived" {
			items = append(items, exercise)
		}
	}
	return items
}

func (s *MemoryStore) ListExercises() []contracts.Exercise {
	s.mu.RLock()
	defer s.mu.RUnlock()
	var items []contracts.Exercise
	for _, exercise := range s.exercises {
		items = append(items, exercise)
	}
	return items
}

func (s *MemoryStore) Exercise(id string) (contracts.Exercise, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	exercise, ok := s.exercises[id]
	return exercise, ok
}

func (s *MemoryStore) CreateExercise(exercise contracts.Exercise) contracts.Exercise {
	s.mu.Lock()
	defer s.mu.Unlock()
	exercise.ID = fmt.Sprintf("exercise-%d", s.nextExercise)
	s.nextExercise++
	if exercise.Status == "" {
		exercise.Status = "draft"
	}
	s.exercises[exercise.ID] = exercise
	return exercise
}

func (s *MemoryStore) UpdateExercise(id string, update contracts.Exercise) (contracts.Exercise, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	current, ok := s.exercises[id]
	if !ok {
		return contracts.Exercise{}, false
	}
	if update.Title != "" {
		current.Title = update.Title
	}
	if update.ShortInstruction != "" {
		current.ShortInstruction = update.ShortInstruction
	}
	if update.LearnerInstruction != "" {
		current.LearnerInstruction = update.LearnerInstruction
	}
	if update.ExerciseType != "" {
		current.ExerciseType = update.ExerciseType
	}
	if update.ModuleID != "" {
		current.ModuleID = update.ModuleID
	}
	if update.Status != "" {
		current.Status = update.Status
	}
	if update.Detail != nil {
		current.Detail = update.Detail
	}
	if update.Prompt != nil {
		current.Prompt = update.Prompt
	}
	s.exercises[id] = current
	return current, true
}

func (s *MemoryStore) CreateAttempt(exerciseID string) (*contracts.Attempt, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	exercise, ok := s.exercises[exerciseID]
	if !ok {
		return nil, fmt.Errorf("exercise not found")
	}
	s.attemptOrder[exerciseID]++
	id := fmt.Sprintf("attempt-%d", s.nextAttempt)
	s.nextAttempt++
	attempt := &contracts.Attempt{
		ID:           id,
		ExerciseID:   exerciseID,
		ExerciseType: exercise.ExerciseType,
		Status:       "created",
		AttemptNo:    s.attemptOrder[exerciseID],
		StartedAt:    time.Now().UTC().Format(time.RFC3339),
	}
	s.attempts[id] = attempt
	return cloneAttempt(attempt), nil
}

func (s *MemoryStore) UpdateAttemptRecordingStarted(id string, timestamp string) (*contracts.Attempt, bool) {
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

func (s *MemoryStore) MarkUploadComplete(id string, audio contracts.AttemptAudio) (*contracts.Attempt, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	attempt, ok := s.attempts[id]
	if !ok {
		return nil, false
	}
	attempt.Status = "recording_uploaded"
	attempt.RecordingUploadedAt = time.Now().UTC().Format(time.RFC3339)
	attempt.Audio = &audio
	return cloneAttempt(attempt), true
}

func (s *MemoryStore) SetAttemptStatus(id, status string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if attempt, ok := s.attempts[id]; ok {
		attempt.Status = status
	}
}

func (s *MemoryStore) CompleteAttempt(id string, transcript contracts.Transcript, feedback contracts.AttemptFeedback) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if attempt, ok := s.attempts[id]; ok {
		attempt.Status = "completed"
		attempt.CompletedAt = time.Now().UTC().Format(time.RFC3339)
		attempt.ReadinessLevel = feedback.ReadinessLevel
		attempt.Transcript = &transcript
		attempt.Feedback = &feedback
	}
}

func (s *MemoryStore) Attempt(id string) (*contracts.Attempt, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	attempt, ok := s.attempts[id]
	if !ok {
		return nil, false
	}
	return cloneAttempt(attempt), true
}

func (s *MemoryStore) ListAttempts() []contracts.Attempt {
	s.mu.RLock()
	defer s.mu.RUnlock()
	items := make([]contracts.Attempt, 0, len(s.attempts))
	for _, attempt := range s.attempts {
		items = append(items, *cloneAttempt(attempt))
	}
	return items
}

func (s *MemoryStore) MockExam() contracts.MockExamSession {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.mockExam
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
	return &clone
}
