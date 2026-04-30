package store

import (
	"fmt"
	"sync"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// MockExamStore manages mock exam sessions. The learnerID parameter is stored
// for persistence but not used for access control (HTTP layer enforces that).
// mockTestID is optional — empty string falls back to hardcoded exercise types.
type MockExamStore interface {
	CreateMockExam(learnerID, mockTestID string, mockTests MockTestStore) (contracts.MockExamSession, error)
	MockExamByID(id string) (contracts.MockExamSession, bool)
	AdvanceMockExam(id, attemptID string) (contracts.MockExamSession, error)
	CompleteMockExam(id string) (contracts.MockExamSession, error)
}

var mockExamTaskTypes = []string{
	"uloha_1_topic_answers",
	"uloha_2_dialogue_questions",
	"uloha_3_story_narration",
	"uloha_4_choice_reasoning",
}

// memoryMockExamStore is the default in-memory implementation.
type memoryMockExamStore struct {
	mu          sync.RWMutex
	sessions    map[string]*contracts.MockExamSession
	nextSession int
	exercises   ExerciseStore
	attempts    AttemptStore
}

func newMemoryMockExamStore(exercises ExerciseStore, attempts AttemptStore) MockExamStore {
	return &memoryMockExamStore{
		sessions:    map[string]*contracts.MockExamSession{},
		nextSession: 1,
		exercises:   exercises,
		attempts:    attempts,
	}
}

func (s *memoryMockExamStore) CreateMockExam(learnerID, mockTestID string, mockTests MockTestStore) (contracts.MockExamSession, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	var sections []contracts.MockExamSessionItem

	threshold := 60
	if mockTestID != "" && mockTests != nil {
		mt, ok := mockTests.MockTestByID(mockTestID)
		if !ok {
			return contracts.MockExamSession{}, fmt.Errorf("mock test not found: %s", mockTestID)
		}
		if mt.PassThresholdPercent > 0 {
			threshold = mt.PassThresholdPercent
		}
		sections = make([]contracts.MockExamSessionItem, 0, len(mt.Sections))
		for _, mts := range mt.Sections {
			sections = append(sections, contracts.MockExamSessionItem{
				SequenceNo:   mts.SequenceNo,
				SkillKind:    mts.SkillKind,
				ExerciseID:   mts.ExerciseID,
				ExerciseType: mts.ExerciseType,
				MaxPoints:    mts.MaxPoints,
				Status:       "pending",
			})
		}
	} else {
		all := s.exercises.ListExercises("")
		sections = make([]contracts.MockExamSessionItem, 0, len(mockExamTaskTypes))
		for i, kind := range mockExamTaskTypes {
			ex := firstPublishedExerciseByType(all, kind)
			if ex.ID == "" {
				return contracts.MockExamSession{}, fmt.Errorf("no published exercise for %s", kind)
			}
			sections = append(sections, contracts.MockExamSessionItem{
				SequenceNo:   i + 1,
				SkillKind:    skillKindForExerciseType(ex.ExerciseType),
				ExerciseID:   ex.ID,
				ExerciseType: ex.ExerciseType,
				MaxPoints:    defaultMaxPoints[kind],
				Status:       "pending",
			})
		}
	}

	id := fmt.Sprintf("mock-session-%d", s.nextSession)
	s.nextSession++
	session := &contracts.MockExamSession{
		ID:                   id,
		LearnerID:            learnerID,
		Status:               "in_progress",
		MockTestID:           mockTestID,
		PassThresholdPercent: threshold,
		Sections:             sections,
	}
	s.sessions[id] = session
	return *session, nil
}

func skillKindForExerciseType(exerciseType string) string {
	switch {
	case len(exerciseType) >= 6 && exerciseType[:6] == "uloha_":
		return "noi"
	case len(exerciseType) >= 8 && exerciseType[:8] == "poslech_":
		return "nghe"
	case len(exerciseType) >= 6 && exerciseType[:6] == "cteni_":
		return "doc"
	case len(exerciseType) >= 6 && exerciseType[:6] == "psani_":
		return "viet"
	default:
		return "noi"
	}
}

func (s *memoryMockExamStore) MockExamByID(id string) (contracts.MockExamSession, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	session, ok := s.sessions[id]
	if !ok {
		return contracts.MockExamSession{}, false
	}
	return *session, true
}

func (s *memoryMockExamStore) AdvanceMockExam(id, attemptID string) (contracts.MockExamSession, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	session, ok := s.sessions[id]
	if !ok {
		return contracts.MockExamSession{}, fmt.Errorf("mock exam not found")
	}
	if session.Status == "completed" {
		return contracts.MockExamSession{}, fmt.Errorf("mock exam already completed")
	}
	attempt, ok := s.attempts.Attempt(attemptID)
	if !ok {
		return contracts.MockExamSession{}, fmt.Errorf("attempt not found")
	}
	for i := range session.Sections {
		if session.Sections[i].Status == "pending" {
			if attempt.ExerciseID != session.Sections[i].ExerciseID {
				return contracts.MockExamSession{}, fmt.Errorf("attempt exercise does not match section %d", session.Sections[i].SequenceNo)
			}
			session.Sections[i].AttemptID = attemptID
			session.Sections[i].Status = "completed"
			return *session, nil
		}
	}
	return contracts.MockExamSession{}, fmt.Errorf("no pending section")
}

func (s *memoryMockExamStore) CompleteMockExam(id string) (contracts.MockExamSession, error) {
	s.mu.Lock()
	session, ok := s.sessions[id]
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
	maxPoints := make([]int, len(session.Sections))
	for i, sec := range session.Sections {
		mp := sec.MaxPoints
		if mp == 0 {
			mp = defaultMaxPoints[sec.ExerciseType]
		}
		maxPoints[i] = mp
	}
	s.mu.Unlock()

	levels := make([]string, 0, len(attemptIDs))
	inputs := make([]mockExamScoringInput, 0, len(attemptIDs))
	for i, aid := range attemptIDs {
		attempt, ok := s.attempts.Attempt(aid)
		if !ok {
			return contracts.MockExamSession{}, fmt.Errorf("attempt %s not found", aid)
		}
		if attempt.Status != "completed" || attempt.Feedback == nil {
			return contracts.MockExamSession{}, fmt.Errorf("attempt %s is not completed", aid)
		}
		levels = append(levels, attempt.Feedback.ReadinessLevel)
		inputs = append(inputs, mockExamScoringInputFromFeedback(attempt.Feedback, maxPoints[i]))
	}
	level, summary := rollupReadiness(levels)
	sectionScores, _, overallScore, passed := computeScoring(inputs, session.PassThresholdPercent, shouldApplyPronunciationBonus(session.Sections))

	s.mu.Lock()
	defer s.mu.Unlock()
	session = s.sessions[id]
	session.Status = "completed"
	session.OverallReadinessLevel = level
	session.OverallSummary = summary
	session.OverallScore = overallScore
	session.Passed = passed
	for i := range session.Sections {
		if i < len(sectionScores) {
			session.Sections[i].SectionScore = sectionScores[i]
		}
	}
	return *session, nil
}
