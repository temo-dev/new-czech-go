package store

import (
	"fmt"
	"math"
	"strings"
	"sync"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// MockTestStore manages mock test templates (admin-defined exam blueprints).
type MockTestStore interface {
	CreateMockTest(t contracts.MockTest) (contracts.MockTest, error)
	MockTestByID(id string) (contracts.MockTest, bool)
	ListMockTests(statusFilter string) []contracts.MockTest
	UpdateMockTest(id string, update contracts.MockTest) (contracts.MockTest, bool)
	DeleteMockTest(id string) bool
}

// defaultMaxPoints maps exercise_type → max speaking score per real A2 exam rubric.
var defaultMaxPoints = map[string]int{
	"uloha_1_topic_answers":      8,
	"uloha_2_dialogue_questions": 12,
	"uloha_3_story_narration":    10,
	"uloha_4_choice_reasoning":   7,
}

type mockExamScoringInput struct {
	SectionScore      int
	MaxPoints         int
	ReadinessFraction float64
}

// readinessToFraction converts a readiness label to a 0–1 score fraction.
func readinessToFraction(level string) float64 {
	switch strings.ToLower(strings.TrimSpace(level)) {
	case "ready", "ready_for_mock", "exam_ready", "strong":
		return 1.0
	case "almost", "almost_ready":
		return 0.75
	case "needs_work", "ok":
		return 0.5
	case "not_ready":
		return 0.25
	case "weak":
		return 0.0
	default:
		return 0.0
	}
}

func mockExamScoringInputFromFeedback(feedback *contracts.AttemptFeedback, maxPoints int) mockExamScoringInput {
	if maxPoints < 0 {
		maxPoints = 0
	}
	if feedback == nil {
		return mockExamScoringInput{MaxPoints: maxPoints}
	}
	if feedback.ObjectiveResult != nil && feedback.ObjectiveResult.MaxScore > 0 {
		fraction := clampFraction(float64(feedback.ObjectiveResult.Score) / float64(feedback.ObjectiveResult.MaxScore))
		return mockExamScoringInput{
			SectionScore:      int(math.Round(fraction * float64(maxPoints))),
			MaxPoints:         maxPoints,
			ReadinessFraction: fraction,
		}
	}
	fraction := readinessToFraction(feedback.ReadinessLevel)
	return mockExamScoringInput{
		SectionScore:      int(math.Round(fraction * float64(maxPoints))),
		MaxPoints:         maxPoints,
		ReadinessFraction: fraction,
	}
}

func clampFraction(v float64) float64 {
	switch {
	case v < 0:
		return 0
	case v > 1:
		return 1
	default:
		return v
	}
}

func shouldApplyPronunciationBonus(sections []contracts.MockExamSessionItem) bool {
	if len(sections) != 4 {
		return false
	}
	totalMax := 0
	for _, sec := range sections {
		if skillKindForExerciseType(sec.ExerciseType) != "noi" {
			return false
		}
		maxPoints := sec.MaxPoints
		if maxPoints == 0 {
			maxPoints = defaultMaxPoints[sec.ExerciseType]
		}
		totalMax += maxPoints
	}
	return totalMax == 37
}

// computeScoring calculates overall_score and passed for a completed session.
// thresholdPercent: pass if overallScore >= scoringMax*thresholdPercent/100.
// scoringMax is sum(maxPoints), plus the 3-point speaking bonus when enabled.
// Returns (sectionScores, pronunciationBonus, overallScore, passed).
func computeScoring(inputs []mockExamScoringInput, thresholdPercent int, includePronunciationBonus bool) ([]int, int, int, bool) {
	n := len(inputs)
	if n == 0 {
		return nil, 0, 0, false
	}
	if thresholdPercent <= 0 {
		thresholdPercent = 60
	}
	sectionScores := make([]int, n)
	totalFrac := 0.0
	total := 0
	totalMax := 0
	for i, input := range inputs {
		score := input.SectionScore
		if score < 0 {
			score = 0
		}
		if input.MaxPoints > 0 && score > input.MaxPoints {
			score = input.MaxPoints
		}
		sectionScores[i] = score
		total += score
		totalMax += input.MaxPoints
		totalFrac += clampFraction(input.ReadinessFraction)
	}
	avgFrac := totalFrac / float64(n)
	pronunciationBonus := 0
	passMax := totalMax
	if includePronunciationBonus {
		pronunciationBonus = int(math.Round(avgFrac * 3.0))
		passMax += 3
	}
	overallScore := total + pronunciationBonus
	var passed bool
	if passMax > 0 {
		passed = overallScore*100 >= passMax*thresholdPercent
	}
	return sectionScores, pronunciationBonus, overallScore, passed
}

// memoryMockTestStore is the default in-memory implementation.
type memoryMockTestStore struct {
	mu     sync.RWMutex
	tests  map[string]*contracts.MockTest
	nextID int
}

func newMemoryMockTestStore() MockTestStore {
	return &memoryMockTestStore{
		tests:  map[string]*contracts.MockTest{},
		nextID: 1,
	}
}

func (s *memoryMockTestStore) CreateMockTest(t contracts.MockTest) (contracts.MockTest, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	t.ID = fmt.Sprintf("mock-test-%d", s.nextID)
	s.nextID++
	if t.Status == "" {
		t.Status = "draft"
	}
	if t.PassThresholdPercent <= 0 || t.PassThresholdPercent > 100 {
		t.PassThresholdPercent = 60
	}
	cp := t
	s.tests[t.ID] = &cp
	return cp, nil
}

func (s *memoryMockTestStore) MockTestByID(id string) (contracts.MockTest, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	t, ok := s.tests[id]
	if !ok {
		return contracts.MockTest{}, false
	}
	return *t, true
}

func (s *memoryMockTestStore) ListMockTests(statusFilter string) []contracts.MockTest {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]contracts.MockTest, 0, len(s.tests))
	for _, t := range s.tests {
		if statusFilter == "" || t.Status == statusFilter {
			out = append(out, *t)
		}
	}
	return out
}

func (s *memoryMockTestStore) UpdateMockTest(id string, update contracts.MockTest) (contracts.MockTest, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	existing, ok := s.tests[id]
	if !ok {
		return contracts.MockTest{}, false
	}
	update.ID = existing.ID
	s.tests[id] = &update
	return update, true
}

func (s *memoryMockTestStore) DeleteMockTest(id string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, ok := s.tests[id]
	if !ok {
		return false
	}
	delete(s.tests, id)
	return true
}
