package processing

import (
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

func TestScoreObjectiveAnswers_MultipleChoice(t *testing.T) {
	correct := map[string]string{"1": "B", "2": "A", "3": "D", "4": "C", "5": "B"}
	learner := map[string]string{"1": "B", "2": "A", "3": "C", "4": "C", "5": "B"}

	result := ScoreObjectiveAnswers(learner, correct)

	if result.Score != 4 {
		t.Errorf("Score = %d, want 4", result.Score)
	}
	if result.MaxScore != 5 {
		t.Errorf("MaxScore = %d, want 5", result.MaxScore)
	}
	if len(result.Breakdown) != 5 {
		t.Errorf("Breakdown len = %d, want 5", len(result.Breakdown))
	}
	// Q3 should be wrong
	for _, q := range result.Breakdown {
		if q.QuestionNo == 3 {
			if q.IsCorrect {
				t.Error("Q3 expected wrong")
			}
			if q.LearnerAnswer != "C" {
				t.Errorf("Q3 learner answer = %q, want C", q.LearnerAnswer)
			}
			if q.CorrectAnswer != "D" {
				t.Errorf("Q3 correct answer = %q, want D", q.CorrectAnswer)
			}
		}
	}
}

func TestScoreObjectiveAnswers_FillIn_CaseInsensitive(t *testing.T) {
	correct := map[string]string{"1": "bramborový salát"}
	learner := map[string]string{"1": "salát"}

	result := ScoreObjectiveAnswers(learner, correct)
	if result.Score != 1 {
		t.Errorf("Score = %d, want 1 (substring match)", result.Score)
	}
}

func TestScoreObjectiveAnswers_FillIn_CaseVariant(t *testing.T) {
	correct := map[string]string{"1": "Restaurace Klášterní"}
	learner := map[string]string{"1": "klášterní"}

	result := ScoreObjectiveAnswers(learner, correct)
	if result.Score != 1 {
		t.Errorf("Score = %d, want 1 (case-insensitive substring)", result.Score)
	}
}

func TestScoreObjectiveAnswers_FillIn_Wrong(t *testing.T) {
	correct := map[string]string{"1": "Eva"}
	learner := map[string]string{"1": "Ivana"}

	result := ScoreObjectiveAnswers(learner, correct)
	if result.Score != 0 {
		t.Errorf("Score = %d, want 0", result.Score)
	}
}

func TestScoreObjectiveAnswers_AllCorrect(t *testing.T) {
	correct := map[string]string{"1": "A", "2": "B", "3": "C"}
	result := ScoreObjectiveAnswers(correct, correct)
	if result.Score != 3 || result.MaxScore != 3 {
		t.Errorf("expected 3/3 got %d/%d", result.Score, result.MaxScore)
	}
}

func TestReadinessLevelFromObjective(t *testing.T) {
	cases := []struct {
		score    int
		maxScore int
		want     string
	}{
		{5, 5, "strong"},
		{4, 5, "strong"},  // ≥80%
		{3, 5, "ok"},   // 60% ≥ 0.5
		{2, 5, "weak"}, // 40% < 0.5
		{1, 5, "weak"},
		{0, 5, "weak"},
	}
	for _, c := range cases {
		got := ReadinessFromObjective(c.score, c.maxScore)
		if got != c.want {
			t.Errorf("ReadinessFromObjective(%d,%d) = %q, want %q", c.score, c.maxScore, got, c.want)
		}
	}
}

func TestBuildObjectiveFeedback_Basic(t *testing.T) {
	result := contracts.ObjectiveResult{Score: 3, MaxScore: 5}
	fb := BuildObjectiveFeedback(result)
	if fb.ReadinessLevel == "" {
		t.Error("expected non-empty readiness level")
	}
	if fb.ObjectiveResult == nil {
		t.Error("expected ObjectiveResult to be set")
	}
	if fb.ObjectiveResult.Score != 3 {
		t.Errorf("ObjectiveResult.Score = %d, want 3", fb.ObjectiveResult.Score)
	}
}
