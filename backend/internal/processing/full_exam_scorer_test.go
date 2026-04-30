package processing

import (
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

func TestIsPisemnaPassed(t *testing.T) {
	cases := []struct {
		score int
		want  bool
	}{
		{42, true}, // boundary pass
		{43, true},
		{70, true},  // max
		{41, false}, // boundary fail
		{0, false},
	}
	for _, c := range cases {
		got := IsPisemnaPassed(c.score)
		if got != c.want {
			t.Errorf("IsPisemnaPassed(%d) = %v, want %v", c.score, got, c.want)
		}
	}
}

func TestIsUstniPassed(t *testing.T) {
	cases := []struct {
		score int
		want  bool
	}{
		{24, true},  // boundary pass
		{40, true},  // max
		{23, false}, // boundary fail
		{0, false},
	}
	for _, c := range cases {
		got := IsUstniPassed(c.score)
		if got != c.want {
			t.Errorf("IsUstniPassed(%d) = %v, want %v", c.score, got, c.want)
		}
	}
}

func TestIsFullExamPassed(t *testing.T) {
	if !IsFullExamPassed(true, true) {
		t.Error("expected pass when both passed")
	}
	if IsFullExamPassed(true, false) {
		t.Error("expected fail when ustni failed")
	}
	if IsFullExamPassed(false, true) {
		t.Error("expected fail when pisemna failed")
	}
	if IsFullExamPassed(false, false) {
		t.Error("expected fail when both failed")
	}
}

func TestComputePisemnaScore_FromAttempts(t *testing.T) {
	// Simulate 3 scored attempts (cteni=20, psani=15, poslech=18)
	scores := []int{20, 15, 18}
	got := SumPisemnaScores(scores)
	if got != 53 {
		t.Errorf("SumPisemnaScores = %d, want 53", got)
	}
}

func TestScoreFromAttemptFeedbackScalesObjectiveScoreToSectionMax(t *testing.T) {
	score := ScoreFromAttemptFeedback(&contracts.AttemptFeedback{
		ReadinessLevel: "strong",
		ObjectiveResult: &contracts.ObjectiveResult{
			Score:    3,
			MaxScore: 5,
		},
	}, 25)
	if score != 15 {
		t.Fatalf("objective score = %d, want 15", score)
	}
}

func TestScoreFromAttemptFeedbackHandlesCurrentReadinessLabels(t *testing.T) {
	score := ScoreFromAttemptFeedback(&contracts.AttemptFeedback{
		ReadinessLevel: "ready_for_mock",
	}, 20)
	if score != 20 {
		t.Fatalf("ready_for_mock score = %d, want 20", score)
	}

	score = ScoreFromAttemptFeedback(&contracts.AttemptFeedback{
		ReadinessLevel: "almost_ready",
	}, 20)
	if score != 15 {
		t.Fatalf("almost_ready score = %d, want 15", score)
	}
}

func TestPisemnaMaxPoints(t *testing.T) {
	// cteni=25, psani=20, poslech=25 → 70 total
	if PisemnaMaxPoints != 70 {
		t.Errorf("PisemnaMaxPoints = %d, want 70", PisemnaMaxPoints)
	}
}

func TestUstniMaxPoints(t *testing.T) {
	if UstniMaxPoints != 40 {
		t.Errorf("UstniMaxPoints = %d, want 40", UstniMaxPoints)
	}
}

func TestCreateFullExamSessionRejectsOtherLearnerAttempt(t *testing.T) {
	repo := newFullExamScorerTestRepo()
	repo.attempts["attempt-1"] = &contracts.Attempt{
		ID:       "attempt-1",
		UserID:   "learner-2",
		Status:   "completed",
		Feedback: &contracts.AttemptFeedback{ReadinessLevel: "ready_for_mock"},
	}

	scorer := NewFullExamScorer(repo)
	if _, err := scorer.CreateSession("learner-1", "mock-test-1", []string{"attempt-1"}, []int{20}); err == nil {
		t.Fatal("CreateSession should reject attempts from another learner")
	}
}

func TestCreateFullExamSessionRejectsIncompleteAttempt(t *testing.T) {
	repo := newFullExamScorerTestRepo()
	repo.attempts["attempt-1"] = &contracts.Attempt{
		ID:     "attempt-1",
		UserID: "learner-1",
		Status: "processing",
	}

	scorer := NewFullExamScorer(repo)
	if _, err := scorer.CreateSession("learner-1", "mock-test-1", []string{"attempt-1"}, []int{20}); err == nil {
		t.Fatal("CreateSession should reject attempts that are not completed")
	}
}

func TestCompleteFullExamSessionRejectsOtherLearnerMockExam(t *testing.T) {
	repo := newFullExamScorerTestRepo()
	repo.sessions["full-1"] = contracts.FullExamSession{
		ID:            "full-1",
		LearnerID:     "learner-1",
		PisemnaPassed: true,
		Status:        "pisemna_done",
	}
	repo.mockExams["mock-1"] = contracts.MockExamSession{
		ID:           "mock-1",
		LearnerID:    "learner-2",
		Status:       "completed",
		OverallScore: 40,
	}

	scorer := NewFullExamScorer(repo)
	if _, err := scorer.CompleteSession("full-1", "mock-1"); err == nil {
		t.Fatal("CompleteSession should reject speaking sessions from another learner")
	}
}

func TestCompleteFullExamSessionRejectsIncompleteMockExam(t *testing.T) {
	repo := newFullExamScorerTestRepo()
	repo.sessions["full-1"] = contracts.FullExamSession{
		ID:            "full-1",
		LearnerID:     "learner-1",
		PisemnaPassed: true,
		Status:        "pisemna_done",
	}
	repo.mockExams["mock-1"] = contracts.MockExamSession{
		ID:        "mock-1",
		LearnerID: "learner-1",
		Status:    "in_progress",
	}

	scorer := NewFullExamScorer(repo)
	if _, err := scorer.CompleteSession("full-1", "mock-1"); err == nil {
		t.Fatal("CompleteSession should reject incomplete speaking sessions")
	}
}

type fullExamScorerTestRepo struct {
	attempts  map[string]*contracts.Attempt
	mockExams map[string]contracts.MockExamSession
	sessions  map[string]contracts.FullExamSession
}

func newFullExamScorerTestRepo() *fullExamScorerTestRepo {
	return &fullExamScorerTestRepo{
		attempts:  map[string]*contracts.Attempt{},
		mockExams: map[string]contracts.MockExamSession{},
		sessions:  map[string]contracts.FullExamSession{},
	}
}

func (r *fullExamScorerTestRepo) Attempt(id string) (*contracts.Attempt, bool) {
	attempt, ok := r.attempts[id]
	return attempt, ok
}

func (r *fullExamScorerTestRepo) MockExamByID(id string) (contracts.MockExamSession, bool) {
	session, ok := r.mockExams[id]
	return session, ok
}

func (r *fullExamScorerTestRepo) SetFullExamSession(session contracts.FullExamSession) {
	r.sessions[session.ID] = session
}

func (r *fullExamScorerTestRepo) FullExamSession(id string) (*contracts.FullExamSession, bool) {
	session, ok := r.sessions[id]
	if !ok {
		return nil, false
	}
	return &session, true
}

func (r *fullExamScorerTestRepo) ListFullExamSessions(learnerID string) []contracts.FullExamSession {
	var sessions []contracts.FullExamSession
	for _, session := range r.sessions {
		if session.LearnerID == learnerID {
			sessions = append(sessions, session)
		}
	}
	return sessions
}
