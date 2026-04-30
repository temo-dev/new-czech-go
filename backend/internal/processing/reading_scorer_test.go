package processing

import (
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// Verify extractCorrectAnswers works for all cteni types via JSON round-trip.

func TestExtractCorrectAnswers_Cteni2(t *testing.T) {
	ex := contracts.Exercise{
		ExerciseType: "cteni_2",
		Detail: contracts.Cteni2Detail{
			Text: "Vážení spoluobčané...",
			Questions: []contracts.ReadingQuestion{
				{QuestionNo: 6, Prompt: "Kdy se koná otevření?", Options: []contracts.MultipleChoiceOption{
					{Key: "A", Text: "25. 6."}, {Key: "B", Text: "26. 6."},
				}},
			},
			CorrectAnswers: map[string]string{"6": "A", "7": "B", "8": "A", "9": "C", "10": "D"},
		},
	}
	correct, err := extractCorrectAnswers(ex)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if correct["6"] != "A" || correct["7"] != "B" {
		t.Errorf("wrong correct answers: %v", correct)
	}
}

func TestExtractCorrectAnswers_Cteni5_FillIn(t *testing.T) {
	ex := contracts.Exercise{
		ExerciseType: "cteni_5",
		Detail: contracts.Cteni5Detail{
			Text: "Bramborový salát z Pohořelic...",
			Questions: []contracts.FillQuestion{
				{QuestionNo: 21, Prompt: "Podle receptu můžeme připravit..."},
				{QuestionNo: 22, Prompt: "Na salát potřebujeme jednu..."},
			},
			CorrectAnswers: map[string]string{
				"21": "bramborový salát",
				"22": "velkou cibuli",
			},
		},
	}
	correct, err := extractCorrectAnswers(ex)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Verify fill-in matching works for cteni_5 answers
	learner := map[string]string{
		"21": "salát",         // substring → correct
		"22": "cibuli",        // substring → correct
	}
	result := ScoreObjectiveAnswers(learner, correct, nil, nil)
	if result.Score != 2 {
		t.Errorf("Score = %d, want 2 (both substring matches)", result.Score)
	}
}

func TestExtractCorrectAnswers_Cteni1_Match(t *testing.T) {
	ex := contracts.Exercise{
		ExerciseType: "cteni_1",
		Detail: contracts.Cteni1Detail{
			Items: []contracts.ReadingItem{
				{ItemNo: 1}, {ItemNo: 2}, {ItemNo: 3}, {ItemNo: 4}, {ItemNo: 5},
			},
			Options: []contracts.TextOption{
				{Key: "A", Text: "Celodenní parkování zdarma."},
			},
			CorrectAnswers: map[string]string{"1": "H", "2": "A", "3": "C", "4": "D", "5": "F"},
		},
	}
	correct, err := extractCorrectAnswers(ex)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(correct) != 5 {
		t.Errorf("expected 5 correct answers, got %d", len(correct))
	}
}

func TestExtractCorrectAnswers_Cteni4_MultiQuestion(t *testing.T) {
	ex := contracts.Exercise{
		ExerciseType: "cteni_4",
		Detail: contracts.Cteni4Detail{
			Questions: []contracts.ReadingQuestion{
				{QuestionNo: 15}, {QuestionNo: 16}, {QuestionNo: 17},
				{QuestionNo: 18}, {QuestionNo: 19}, {QuestionNo: 20},
			},
			CorrectAnswers: map[string]string{
				"15": "D", "16": "A", "17": "B", "18": "B", "19": "D", "20": "B",
			},
		},
	}
	correct, err := extractCorrectAnswers(ex)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(correct) != 6 {
		t.Errorf("expected 6 correct answers, got %d", len(correct))
	}
	result := ScoreObjectiveAnswers(correct, correct, nil, nil) // all correct
	if result.Score != 6 {
		t.Errorf("Score = %d, want 6", result.Score)
	}
}
