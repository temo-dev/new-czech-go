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
	mockExams    map[string]*contracts.MockExamSession
	nextMockExam int
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
		modules:      seedDailyPlanModules(),
		exercises:    exercises,
		attempts:     attempts,
		mockExams:    map[string]*contracts.MockExamSession{},
		nextMockExam: 1,
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

var mockExamTaskTypes = []string{
	"uloha_1_topic_answers",
	"uloha_2_dialogue_questions",
	"uloha_3_story_narration",
	"uloha_4_choice_reasoning",
}

func (s *MemoryStore) CreateMockExam() (contracts.MockExamSession, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	all := s.exercises.ListExercises()
	sections := make([]contracts.MockExamSessionItem, 0, len(mockExamTaskTypes))
	for i, kind := range mockExamTaskTypes {
		ex := firstPublishedExerciseByType(all, kind)
		if ex.ID == "" {
			return contracts.MockExamSession{}, fmt.Errorf("no published exercise for %s", kind)
		}
		sections = append(sections, contracts.MockExamSessionItem{
			SequenceNo:   i + 1,
			ExerciseID:   ex.ID,
			ExerciseType: ex.ExerciseType,
			Status:       "pending",
		})
	}

	id := fmt.Sprintf("mock-session-%d", s.nextMockExam)
	s.nextMockExam++
	session := &contracts.MockExamSession{
		ID:       id,
		Status:   "in_progress",
		Sections: sections,
	}
	s.mockExams[id] = session
	return *session, nil
}

func (s *MemoryStore) MockExamByID(id string) (contracts.MockExamSession, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	session, ok := s.mockExams[id]
	if !ok {
		return contracts.MockExamSession{}, false
	}
	return *session, true
}

func (s *MemoryStore) AdvanceMockExam(id, attemptID string) (contracts.MockExamSession, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	session, ok := s.mockExams[id]
	if !ok {
		return contracts.MockExamSession{}, fmt.Errorf("mock exam not found")
	}
	if session.Status == "completed" {
		return contracts.MockExamSession{}, fmt.Errorf("mock exam already completed")
	}
	for i := range session.Sections {
		if session.Sections[i].Status == "pending" {
			session.Sections[i].AttemptID = attemptID
			session.Sections[i].Status = "completed"
			return *session, nil
		}
	}
	return contracts.MockExamSession{}, fmt.Errorf("no pending section")
}

func (s *MemoryStore) CompleteMockExam(id string) (contracts.MockExamSession, error) {
	s.mu.Lock()
	session, ok := s.mockExams[id]
	if !ok {
		s.mu.Unlock()
		return contracts.MockExamSession{}, fmt.Errorf("mock exam not found")
	}
	attemptIDs := make([]string, 0, len(session.Sections))
	for _, sec := range session.Sections {
		if sec.Status != "completed" || sec.AttemptID == "" {
			s.mu.Unlock()
			return contracts.MockExamSession{}, fmt.Errorf("section %d not completed", sec.SequenceNo)
		}
		attemptIDs = append(attemptIDs, sec.AttemptID)
	}
	s.mu.Unlock()

	level, summary := s.aggregateMockExam(attemptIDs)

	s.mu.Lock()
	defer s.mu.Unlock()
	session = s.mockExams[id]
	session.Status = "completed"
	session.OverallReadinessLevel = level
	session.OverallSummary = summary
	return *session, nil
}

func (s *MemoryStore) aggregateMockExam(attemptIDs []string) (string, string) {
	levels := make([]string, 0, len(attemptIDs))
	for _, aid := range attemptIDs {
		attempt, ok := s.attempts.Attempt(aid)
		if !ok || attempt.Feedback == nil {
			continue
		}
		levels = append(levels, attempt.Feedback.ReadinessLevel)
	}
	return rollupReadiness(levels)
}

func rollupReadiness(levels []string) (string, string) {
	if len(levels) == 0 {
		return "not_ready", "Chua co du feedback de danh gia."
	}
	score := map[string]int{
		"ready":       3,
		"almost":      2,
		"needs_work":  1,
		"not_ready":   0,
	}
	total := 0
	counts := map[string]int{}
	for _, lv := range levels {
		total += score[lv]
		counts[lv]++
	}
	avg := float64(total) / float64(len(levels))
	var overall string
	switch {
	case avg >= 2.5:
		overall = "ready"
	case avg >= 1.5:
		overall = "almost"
	case avg >= 0.75:
		overall = "needs_work"
	default:
		overall = "not_ready"
	}
	summary := fmt.Sprintf("ready:%d almost:%d needs_work:%d not_ready:%d",
		counts["ready"], counts["almost"], counts["needs_work"], counts["not_ready"])
	return overall, summary
}

func firstPublishedExerciseByType(items []contracts.Exercise, kind string) contracts.Exercise {
	for _, ex := range items {
		if ex.ExerciseType == kind && ex.Status == "published" {
			return ex
		}
	}
	return contracts.Exercise{}
}

func seedDailyPlanModules() []contracts.Module {
	days := []struct {
		title       string
		description string
	}{
		{"Day 1 · Uloha 1", "Chu de: Gia dinh. Tap tra loi cau hoi ngan."},
		{"Day 2 · Uloha 1", "Chu de: Cong viec. Luyen cau tra loi ro y."},
		{"Day 3 · Uloha 1", "Chu de: Thoi gian ranh. Tap noi tu tin hon."},
		{"Day 4 · Uloha 1", "Chu de: An uong. On lai cau truc co ban."},
		{"Day 5 · Uloha 2", "Scenario: Tren buu dien. Hoi du thong tin."},
		{"Day 6 · Uloha 2", "Scenario: O phong mach bac si. Dat cau hoi ro rang."},
		{"Day 7 · Uloha 2", "Scenario: Thue can ho. Luyen cau hoi da dang."},
		{"Day 8 · Uloha 3", "Story: Cuoi tuan trong cong vien. Ke theo tranh."},
		{"Day 9 · Uloha 3", "Story: Di cho. Dung nejdriv/pak/nakonec."},
		{"Day 10 · Uloha 3", "Story: Mot ngay o truong. Chu y thi qua khu."},
		{"Day 11 · Uloha 4", "Scenario: Chon diem du lich. Giai thich ly do."},
		{"Day 12 · Uloha 4", "Scenario: Chon mon an. Dung 'protoze'."},
		{"Day 13 · On tap", "Quay lai bai yeu nhat. Ghi am 1 lan cho moi Uloha."},
		{"Day 14 · Ready check", "Luyen toc do va su ro rang truoc mock exam."},
	}
	mods := make([]contracts.Module, 0, len(days)+1)
	for i, d := range days {
		seq := i + 1
		mods = append(mods, contracts.Module{
			ID:          fmt.Sprintf("module-day-%d", seq),
			Slug:        fmt.Sprintf("day-%d", seq),
			Title:       d.title,
			ModuleKind:  "daily_plan",
			SequenceNo:  seq,
			Description: d.description,
		})
	}
	mods = append(mods, contracts.Module{
		ID:          "module-mock",
		Slug:        "mock-1",
		Title:       "Mock Oral Exam",
		ModuleKind:  "mock_exam",
		SequenceNo:  len(days) + 1,
		Description: "Bai thi noi tong hop sau 14 ngay.",
	})
	return mods
}

