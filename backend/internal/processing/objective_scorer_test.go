package processing

import (
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

func TestScoreObjectiveAnswers_MultipleChoice(t *testing.T) {
	correct := map[string]string{"1": "B", "2": "A", "3": "D", "4": "C", "5": "B"}
	learner := map[string]string{"1": "B", "2": "A", "3": "C", "4": "C", "5": "B"}

	result := ScoreObjectiveAnswers(learner, correct, nil, nil)

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

	result := ScoreObjectiveAnswers(learner, correct, nil, nil)
	if result.Score != 1 {
		t.Errorf("Score = %d, want 1 (substring match)", result.Score)
	}
}

func TestScoreObjectiveAnswers_FillIn_CaseVariant(t *testing.T) {
	correct := map[string]string{"1": "Restaurace Klášterní"}
	learner := map[string]string{"1": "klášterní"}

	result := ScoreObjectiveAnswers(learner, correct, nil, nil)
	if result.Score != 1 {
		t.Errorf("Score = %d, want 1 (case-insensitive substring)", result.Score)
	}
}

func TestScoreObjectiveAnswers_FillIn_Wrong(t *testing.T) {
	correct := map[string]string{"1": "Eva"}
	learner := map[string]string{"1": "Ivana"}

	result := ScoreObjectiveAnswers(learner, correct, nil, nil)
	if result.Score != 0 {
		t.Errorf("Score = %d, want 0", result.Score)
	}
}

func TestScoreObjectiveAnswers_AllCorrect(t *testing.T) {
	correct := map[string]string{"1": "A", "2": "B", "3": "C"}
	result := ScoreObjectiveAnswers(correct, correct, nil, nil)
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

func TestMatchObjectiveAnswer_ShortFillIn_UsesSubstring(t *testing.T) {
	// Short Czech name like "Eva" should use substring, not exact match.
	// Learner writes full name; correct answer is first name only.
	correct := map[string]string{"1": "Eva"}
	learner := map[string]string{"1": "Eva Nováková"}
	result := ScoreObjectiveAnswers(learner, correct, nil, nil)
	if result.Score != 1 {
		t.Errorf("Score = %d, want 1 (substring: %q contains %q)", result.Score, "Eva Nováková", "Eva")
	}
}

func TestMatchObjectiveAnswer_ChoiceKey_ExactOnly(t *testing.T) {
	// A-H single-letter keys use exact match.
	cases := []struct {
		learner, correct string
		want             bool
	}{
		{"B", "B", true},
		{"b", "B", true},   // case-insensitive
		{"B", "A", false},
		{"AB", "A", false}, // not exact
		{"G", "G", true},
		{"H", "H", true},   // cteni_2 uses A-H
		{"AI", "I", true},  // I not in A-H → substring: "ai" contains "i"
		{"X", "I", false},  // I not in A-H → substring: "x" doesn't contain "i"
	}
	for _, c := range cases {
		correct := map[string]string{"1": c.correct}
		learner := map[string]string{"1": c.learner}
		got := ScoreObjectiveAnswers(learner, correct, nil, nil).Score == 1
		if got != c.want {
			t.Errorf("learner=%q correct=%q: got %v, want %v", c.learner, c.correct, got, c.want)
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

// --- V13: Ano/Ne tests ---

func TestScoreObjectiveAnswers_AnoNe_AllCorrect(t *testing.T) {
	correct := map[string]string{"1": "ANO", "2": "NE", "3": "ANO"}
	learner := map[string]string{"1": "ANO", "2": "NE", "3": "ANO"}

	result := ScoreObjectiveAnswers(learner, correct, nil, nil)

	if result.Score != 3 {
		t.Errorf("Score = %d, want 3", result.Score)
	}
	if result.MaxScore != 3 {
		t.Errorf("MaxScore = %d, want 3", result.MaxScore)
	}
}

func TestScoreObjectiveAnswers_AnoNe_SomeWrong(t *testing.T) {
	correct := map[string]string{"1": "ANO", "2": "NE", "3": "ANO"}
	learner := map[string]string{"1": "ANO", "2": "ANO", "3": "NE"}

	result := ScoreObjectiveAnswers(learner, correct, nil, nil)

	if result.Score != 1 {
		t.Errorf("Score = %d, want 1", result.Score)
	}
	for _, q := range result.Breakdown {
		if q.QuestionNo == 2 && q.IsCorrect {
			t.Error("Q2 expected wrong (ANO vs NE)")
		}
		if q.QuestionNo == 3 && q.IsCorrect {
			t.Error("Q3 expected wrong (NE vs ANO)")
		}
	}
}

func TestScoreObjectiveAnswers_AnoNe_CaseInsensitive(t *testing.T) {
	correct := map[string]string{"1": "ANO", "2": "NE"}
	learner := map[string]string{"1": "ano", "2": "ne"}

	result := ScoreObjectiveAnswers(learner, correct, nil, nil)

	if result.Score != 2 {
		t.Errorf("Score = %d, want 2 (case-insensitive match)", result.Score)
	}
}

func TestExtractQuestionTexts_Statements(t *testing.T) {
	exercise := contracts.Exercise{
		ExerciseType: "cteni_6",
		Detail: contracts.AnoNeDetail{
			Passage: "Vlašim\nMěstský úřad",
			Statements: []contracts.AnoNeStatement{
				{QuestionNo: 1, Statement: "Na úřadu města je zavřeno ve středu."},
				{QuestionNo: 2, Statement: "Ve čtvrtek je polední přestávka do jedné hodiny."},
				{QuestionNo: 3, Statement: "V úterý úřední hodiny končí ve dvě hodiny odpoledne."},
			},
			CorrectAnswers: map[string]string{"1": "NE", "2": "NE", "3": "ANO"},
		},
	}

	texts := extractQuestionTexts(exercise)

	if texts["1"] != "Na úřadu města je zavřeno ve středu." {
		t.Errorf("texts[1] = %q, want Na úřadu...", texts["1"])
	}
	if texts["2"] != "Ve čtvrtek je polední přestávka do jedné hodiny." {
		t.Errorf("texts[2] = %q", texts["2"])
	}
	if texts["3"] != "V úterý úřední hodiny končí ve dvě hodiny odpoledne." {
		t.Errorf("texts[3] = %q", texts["3"])
	}
	if len(texts) != 3 {
		t.Errorf("len(texts) = %d, want 3", len(texts))
	}
}

func TestScoreObjectiveAnswers_AnoNe_SubstringCollision(t *testing.T) {
	// "NEANO" contains "ANO" as a substring — must NOT score as correct.
	correct := map[string]string{"1": "ANO"}
	learner := map[string]string{"1": "NEANO"}
	result := ScoreObjectiveAnswers(learner, correct, nil, nil)
	if result.Score != 0 {
		t.Errorf("Score = %d, want 0 (NEANO must not match ANO via substring)", result.Score)
	}
}

func TestScoreObjectiveAnswers_AnoNe_NeInsideAno_NotMatch(t *testing.T) {
	// "NEano" must NOT match correct="ANO".
	correct := map[string]string{"1": "ANO"}
	learner := map[string]string{"1": "neano"}
	result := ScoreObjectiveAnswers(learner, correct, nil, nil)
	if result.Score != 0 {
		t.Errorf("Score = %d, want 0", result.Score)
	}
}
