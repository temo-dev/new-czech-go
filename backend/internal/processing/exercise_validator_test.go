package processing

import (
	"strings"
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// ── ValidateGeneratedExercise ─────────────────────────────────────────────────

func TestValidate_QuizcardValid(t *testing.T) {
	ex := contracts.GeneratedExercise{
		ExerciseType: "quizcard_basic",
		FrontText:    "chodím",
		BackText:     "đi bộ",
		Explanation:  "chodím là ngôi thứ nhất số ít của chodít.",
	}
	errs := ValidateGeneratedExercise(ex)
	if len(errs) != 0 {
		t.Fatalf("expected no errors, got: %v", errs)
	}
}

func TestValidate_QuizcardMissingFront(t *testing.T) {
	ex := contracts.GeneratedExercise{
		ExerciseType: "quizcard_basic",
		BackText:     "đi bộ",
		Explanation:  "...",
	}
	errs := ValidateGeneratedExercise(ex)
	if len(errs) == 0 {
		t.Fatal("expected error for missing front_text")
	}
	if !strings.Contains(errs[0], "front_text") {
		t.Fatalf("expected front_text error, got: %v", errs)
	}
}

func TestValidate_QuizcardMissingExplanation(t *testing.T) {
	ex := contracts.GeneratedExercise{
		ExerciseType: "quizcard_basic",
		FrontText:    "chodím",
		BackText:     "đi bộ",
	}
	errs := ValidateGeneratedExercise(ex)
	if len(errs) == 0 {
		t.Fatal("expected error for missing explanation")
	}
}

func TestValidate_ChoiceWordValid(t *testing.T) {
	ex := contracts.GeneratedExercise{
		ExerciseType:  "choice_word",
		Prompt:        "Kde ___ Pavel?",
		Options:       []string{"je", "jsou", "jsem", "jste"},
		CorrectAnswer: "je",
		Explanation:   "Pavel → ngôi thứ 3 số ít → je.",
	}
	errs := ValidateGeneratedExercise(ex)
	if len(errs) != 0 {
		t.Fatalf("expected no errors, got: %v", errs)
	}
}

func TestValidate_ChoiceWordCorrectNotInOptions(t *testing.T) {
	ex := contracts.GeneratedExercise{
		ExerciseType:  "choice_word",
		Prompt:        "Kde ___ Pavel?",
		Options:       []string{"je", "jsou", "jsem", "jste"},
		CorrectAnswer: "bude", // not in options
		Explanation:   "...",
	}
	errs := ValidateGeneratedExercise(ex)
	hasError := false
	for _, e := range errs {
		if strings.Contains(e, "correct_answer") && strings.Contains(e, "not in options") {
			hasError = true
		}
	}
	if !hasError {
		t.Fatalf("expected correct_answer-not-in-options error, got: %v", errs)
	}
}

func TestValidate_ChoiceWordDuplicateOptions(t *testing.T) {
	ex := contracts.GeneratedExercise{
		ExerciseType:  "choice_word",
		Prompt:        "Kde?",
		Options:       []string{"je", "je", "jsem", "jste"}, // duplicate
		CorrectAnswer: "je",
		Explanation:   "...",
	}
	errs := ValidateGeneratedExercise(ex)
	found := false
	for _, e := range errs {
		if strings.Contains(e, "duplicate") {
			found = true
		}
	}
	if !found {
		t.Fatalf("expected duplicate options error, got: %v", errs)
	}
}

func TestValidate_ChoiceWordTooFewOptions(t *testing.T) {
	ex := contracts.GeneratedExercise{
		ExerciseType:  "choice_word",
		Prompt:        "Kde?",
		Options:       []string{"je"}, // only 1
		CorrectAnswer: "je",
		Explanation:   "...",
	}
	errs := ValidateGeneratedExercise(ex)
	found := false
	for _, e := range errs {
		if strings.Contains(e, "≥2 options") || strings.Contains(e, "options") {
			found = true
		}
	}
	if !found {
		t.Fatalf("expected too-few-options error, got: %v", errs)
	}
}

func TestValidate_FillBlankValid(t *testing.T) {
	ex := contracts.GeneratedExercise{
		ExerciseType:  "fill_blank",
		Prompt:        "Já ___ do školy.",
		CorrectAnswer: "chodím",
		Explanation:   "Ngôi thứ nhất số ít dùng 'chodím'.",
	}
	errs := ValidateGeneratedExercise(ex)
	if len(errs) != 0 {
		t.Fatalf("expected no errors, got: %v", errs)
	}
}

func TestValidate_FillBlankMissingBlank(t *testing.T) {
	ex := contracts.GeneratedExercise{
		ExerciseType:  "fill_blank",
		Prompt:        "Já chodím do školy.", // no ___
		CorrectAnswer: "chodím",
		Explanation:   "...",
	}
	errs := ValidateGeneratedExercise(ex)
	found := false
	for _, e := range errs {
		if strings.Contains(e, "___") {
			found = true
		}
	}
	if !found {
		t.Fatalf("expected missing-___ error, got: %v", errs)
	}
}

func TestValidate_MatchingValid(t *testing.T) {
	ex := contracts.GeneratedExercise{
		ExerciseType: "matching",
		Pairs: []contracts.MatchingPair{
			{LeftID: "1", Left: "chodím", RightID: "A", Right: "đi bộ"},
			{LeftID: "2", Left: "jedu", RightID: "B", Right: "đi xe"},
			{LeftID: "3", Left: "letím", RightID: "C", Right: "bay"},
			{LeftID: "4", Left: "běžím", RightID: "D", Right: "chạy"},
		},
		Explanation: "Các động từ di chuyển trong tiếng Czech.",
	}
	errs := ValidateGeneratedExercise(ex)
	if len(errs) != 0 {
		t.Fatalf("expected no errors, got: %v", errs)
	}
}

func TestValidate_MatchingTooFewPairs(t *testing.T) {
	ex := contracts.GeneratedExercise{
		ExerciseType: "matching",
		Pairs: []contracts.MatchingPair{
			{LeftID: "1", Left: "chodím", RightID: "A", Right: "đi bộ"},
		},
		Explanation: "...",
	}
	errs := ValidateGeneratedExercise(ex)
	found := false
	for _, e := range errs {
		if strings.Contains(e, "≥2 pairs") || strings.Contains(e, "pairs") {
			found = true
		}
	}
	if !found {
		t.Fatalf("expected too-few-pairs error, got: %v", errs)
	}
}

func TestValidate_UnknownType(t *testing.T) {
	ex := contracts.GeneratedExercise{
		ExerciseType: "unknown_type",
		Explanation:  "...",
	}
	errs := ValidateGeneratedExercise(ex)
	if len(errs) == 0 {
		t.Fatal("expected error for unknown type")
	}
}

// ── BuildExerciseFromGenerated ────────────────────────────────────────────────

func TestBuild_Quizcard(t *testing.T) {
	ex := contracts.GeneratedExercise{
		ExerciseType: "quizcard_basic",
		FrontText:    "chodím",
		BackText:     "đi bộ",
		Explanation:  "first person singular",
	}
	built, err := BuildExerciseFromGenerated(ex)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if built.ExerciseType != "quizcard_basic" {
		t.Errorf("wrong type: %s", built.ExerciseType)
	}
	if built.Pool != "course" {
		t.Errorf("expected pool=course, got %s", built.Pool)
	}
	if built.Status != "published" {
		t.Errorf("expected status=published, got %s", built.Status)
	}
	// correct_answers must be {"1":"known"}
	detail, ok := built.Detail.(contracts.QuizcardBasicDetail)
	if !ok {
		// Try via map (after JSON round-trip)
		t.Logf("detail type: %T", built.Detail)
	} else {
		if detail.CorrectAnswers["1"] != "known" {
			t.Errorf("expected correct_answers[1]=known, got %q", detail.CorrectAnswers["1"])
		}
	}
}

func TestBuild_ChoiceWord(t *testing.T) {
	ex := contracts.GeneratedExercise{
		ExerciseType:  "choice_word",
		Prompt:        "Kde ___ Pavel?",
		Options:       []string{"je", "jsou", "jsem", "jste"},
		CorrectAnswer: "je", // full text, gets mapped to key "A"
		Explanation:   "ngôi thứ 3 số ít",
	}
	built, err := BuildExerciseFromGenerated(ex)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if built.ExerciseType != "choice_word" {
		t.Errorf("wrong type: %s", built.ExerciseType)
	}
	if built.Pool != "course" || built.Status != "published" {
		t.Errorf("pool=%s status=%s", built.Pool, built.Status)
	}
}

func TestBuild_FillBlank(t *testing.T) {
	ex := contracts.GeneratedExercise{
		ExerciseType:  "fill_blank",
		Prompt:        "Já ___ do školy.",
		CorrectAnswer: "chodím",
		Explanation:   "first person",
	}
	built, err := BuildExerciseFromGenerated(ex)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if built.ExerciseType != "fill_blank" {
		t.Errorf("wrong type: %s", built.ExerciseType)
	}
}

func TestBuild_Matching(t *testing.T) {
	ex := contracts.GeneratedExercise{
		ExerciseType: "matching",
		Pairs: []contracts.MatchingPair{
			{Left: "chodím", Right: "đi bộ"},
			{Left: "jedu", Right: "đi xe"},
			{Left: "letím", Right: "bay"},
			{Left: "běžím", Right: "chạy"},
		},
		Explanation: "động từ di chuyển",
	}
	built, err := BuildExerciseFromGenerated(ex)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if built.ExerciseType != "matching" {
		t.Errorf("wrong type: %s", built.ExerciseType)
	}
}

func TestBuild_UnknownType(t *testing.T) {
	ex := contracts.GeneratedExercise{ExerciseType: "bad_type"}
	_, err := BuildExerciseFromGenerated(ex)
	if err == nil {
		t.Fatal("expected error for unknown type")
	}
}
