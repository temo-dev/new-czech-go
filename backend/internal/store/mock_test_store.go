package store

import (
	"fmt"
	"math"
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

// readinessToFraction converts a readiness label to a 0–1 score fraction.
func readinessToFraction(level string) float64 {
	switch level {
	case "ready":
		return 1.0
	case "almost":
		return 0.75
	case "needs_work":
		return 0.5
	case "not_ready":
		return 0.25
	default:
		return 0.0
	}
}

// computeScoring calculates overall_score and passed for a completed session.
// levels and maxPoints must be the same length and same order as sections.
// thresholdPercent: pass if overallScore >= sum(maxPoints)*thresholdPercent/100.
// Returns (sectionScores, pronunciationBonus, overallScore, passed).
func computeScoring(levels []string, maxPoints []int, thresholdPercent int) ([]int, int, int, bool) {
	n := len(levels)
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
	for i, lv := range levels {
		f := readinessToFraction(lv)
		totalFrac += f
		pts := int(math.Round(f * float64(maxPoints[i])))
		sectionScores[i] = pts
		total += pts
		totalMax += maxPoints[i]
	}
	avgFrac := totalFrac / float64(n)
	pronunciationBonus := int(math.Round(avgFrac * 3.0))
	overallScore := total + pronunciationBonus
	var passed bool
	if totalMax > 0 {
		passed = overallScore*100 >= totalMax*thresholdPercent
	}
	return sectionScores, pronunciationBonus, overallScore, passed
}

// memoryMockTestStore is the default in-memory implementation.
type memoryMockTestStore struct {
	mu       sync.RWMutex
	tests    map[string]*contracts.MockTest
	nextID   int
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
