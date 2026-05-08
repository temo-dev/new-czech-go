package processing

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

func TestMockReadingDraftGenerator_ReturnsCanned(t *testing.T) {
	canned := &contracts.ReadingDraft{
		ExerciseType: "cteni_2",
		Detail:       contracts.Cteni2Detail{Text: "x"},
		Metadata:     contracts.ReadingDraftMeta{Model: "mock", DurationMs: 1},
	}
	gen := &MockReadingDraftGenerator{Draft: canned}

	got, err := gen.Generate(context.Background(), contracts.ReadingDraftInput{ExerciseType: "cteni_2"})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got != canned {
		t.Fatalf("expected canned draft, got %+v", got)
	}
}

func TestMockReadingDraftGenerator_PropagatesError(t *testing.T) {
	want := errors.New("boom")
	gen := &MockReadingDraftGenerator{Err: want}

	_, err := gen.Generate(context.Background(), contracts.ReadingDraftInput{ExerciseType: "cteni_2"})
	if !errors.Is(err, want) {
		t.Fatalf("expected wrapped error, got %v", err)
	}
}

func TestClaudeReadingDraftGenerator_NotImplementedForUnshippedTypes(t *testing.T) {
	gen := NewClaudeReadingDraftGenerator("dummy-key", DefaultReadingDraftModel)

	// cteni_2 (B1), cteni_4 (B2), cteni_5 (B3), cteni_6 (B4), cteni_3 (B5) shipped; cteni_1 still skeleton.
	for _, exType := range []string{"cteni_1"} {
		t.Run(exType, func(t *testing.T) {
			_, err := gen.Generate(context.Background(), contracts.ReadingDraftInput{ExerciseType: exType})
			if !errors.Is(err, ErrReadingDraftNotImplemented) {
				t.Fatalf("expected ErrReadingDraftNotImplemented, got %v", err)
			}
		})
	}
}

func TestClaudeReadingDraftGenerator_RejectsUnknownType(t *testing.T) {
	gen := NewClaudeReadingDraftGenerator("dummy-key", DefaultReadingDraftModel)

	_, err := gen.Generate(context.Background(), contracts.ReadingDraftInput{ExerciseType: "uloha_1_topic_answers"})
	if err == nil {
		t.Fatal("expected error for non-cteni exercise type")
	}
	if errors.Is(err, ErrReadingDraftNotImplemented) {
		t.Fatalf("unsupported type should not return ErrReadingDraftNotImplemented, got %v", err)
	}
}

func TestReadingDraftSystemPrompt_AnchorsOnExpectedRules(t *testing.T) {
	mustContain(t, ReadingDraftSystemPrompt, "ANO")
	mustContain(t, ReadingDraftSystemPrompt, "NE")
	mustContain(t, ReadingDraftSystemPrompt, "Vietnamese")
	mustContain(t, ReadingDraftSystemPrompt, "Czech")
	mustContain(t, ReadingDraftSystemPrompt, "Distractors")
	mustContain(t, ReadingDraftSystemPrompt, "asset_id")
	mustContain(t, ReadingDraftSystemPrompt, "A2")
	mustContain(t, ReadingDraftSystemPrompt, "B1")
}

func mustContain(t *testing.T, haystack, needle string) {
	t.Helper()
	if !strings.Contains(haystack, needle) {
		t.Errorf("system prompt missing required substring %q", needle)
	}
}

func TestBuildReadingDraftUserPrompt_Cteni2_EchoesInput(t *testing.T) {
	in := contracts.ReadingDraftInput{
		ExerciseType: "cteni_2",
		Topic:        "đi khám bác sĩ",
		Level:        "A2",
		GrammarPoints: []contracts.GrammarRule{
			{Title: "minulý čas", ExplanationVI: "thì quá khứ", RuleTable: map[string]string{"já": "byl jsem"}},
		},
		ExtraInstructions: "tone neutral",
	}
	got := BuildReadingDraftUserPrompt(in)

	for _, sub := range []string{
		"cteni_2",
		"đi khám bác sĩ",
		"A2",
		"minulý čas",
		"thì quá khứ",
		"já→byl jsem",
		"tone neutral",
		"5 questions",
		"4 options",
		"A, B, C, D",
	} {
		if !strings.Contains(got, sub) {
			t.Errorf("user prompt missing %q\nfull:\n%s", sub, got)
		}
	}
}

func TestBuildReadingDraftToolSchema_Cteni2_HasExpectedShape(t *testing.T) {
	schema := buildReadingDraftToolSchema("cteni_2")
	if schema == nil {
		t.Fatal("expected schema for cteni_2")
	}
	props, ok := schema["properties"].(map[string]any)
	if !ok {
		t.Fatal("schema missing properties")
	}
	for _, key := range []string{"text", "questions", "correct_answers"} {
		if _, ok := props[key]; !ok {
			t.Errorf("schema missing top-level property %q", key)
		}
	}
	required, _ := schema["required"].([]string)
	if len(required) != 3 {
		t.Errorf("schema required len = %d, want 3", len(required))
	}
	questions, _ := props["questions"].(map[string]any)
	if questions["minItems"] != 5 || questions["maxItems"] != 5 {
		t.Errorf("questions array bounds = [%v, %v], want [5, 5]", questions["minItems"], questions["maxItems"])
	}
}

func TestBuildReadingDraftToolSchema_UnknownTypeReturnsNil(t *testing.T) {
	if schema := buildReadingDraftToolSchema("cteni_99"); schema != nil {
		t.Fatalf("expected nil schema for unknown type, got %v", schema)
	}
}

func TestBuildReadingDraftUserPrompt_Cteni4_HasSixQuestionRequirement(t *testing.T) {
	in := contracts.ReadingDraftInput{
		ExerciseType:  "cteni_4",
		Topic:         "u doktora",
		Level:         "B1",
		GrammarPoints: []contracts.GrammarRule{{Title: "akuzativ"}},
	}
	got := BuildReadingDraftUserPrompt(in)
	for _, sub := range []string{"cteni_4", "u doktora", "B1", "akuzativ", "6 questions", "A, B, C, D"} {
		if !strings.Contains(got, sub) {
			t.Errorf("user prompt missing %q\nfull:\n%s", sub, got)
		}
	}
}

func TestBuildReadingDraftToolSchema_Cteni4_HasContextOptionalAndSixQuestions(t *testing.T) {
	schema := buildReadingDraftToolSchema("cteni_4")
	if schema == nil {
		t.Fatal("expected schema for cteni_4")
	}
	required, _ := schema["required"].([]string)
	for _, r := range required {
		if r == "context" {
			t.Error("context must NOT be required for cteni_4")
		}
	}
	props, _ := schema["properties"].(map[string]any)
	questions, _ := props["questions"].(map[string]any)
	if questions["minItems"] != 6 || questions["maxItems"] != 6 {
		t.Errorf("questions array bounds = [%v, %v], want [6, 6]", questions["minItems"], questions["maxItems"])
	}
}

func TestParseReadingDraftDetail_Cteni4_RoundTrips(t *testing.T) {
	raw := []byte(`{
		"context": "Pavel byl nemocný.",
		"questions": [
			{"question_no": 1, "prompt": "Q1?", "options": [
				{"key": "A", "text": "a"}, {"key": "B", "text": "b"},
				{"key": "C", "text": "c"}, {"key": "D", "text": "d"}
			]}
		],
		"correct_answers": {"1": "A"}
	}`)
	detail, err := parseReadingDraftDetail("cteni_4", raw)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	d, ok := detail.(contracts.Cteni4Detail)
	if !ok {
		t.Fatalf("expected Cteni4Detail, got %T", detail)
	}
	if d.Context != "Pavel byl nemocný." {
		t.Fatalf("context mismatch: %q", d.Context)
	}
}

func TestBuildReadingDraftUserPrompt_Cteni5_HasFillRequirements(t *testing.T) {
	in := contracts.ReadingDraftInput{
		ExerciseType:  "cteni_5",
		Topic:         "u doktora",
		Level:         "A2",
		GrammarPoints: []contracts.GrammarRule{{Title: "minulý čas"}},
	}
	got := BuildReadingDraftUserPrompt(in)
	for _, sub := range []string{"cteni_5", "5 fill-information", "≤30 characters", "verbatim"} {
		if !strings.Contains(got, sub) {
			t.Errorf("user prompt missing %q\nfull:\n%s", sub, got)
		}
	}
}

func TestBuildReadingDraftToolSchema_Cteni5_EnforcesShortAnswers(t *testing.T) {
	schema := buildReadingDraftToolSchema("cteni_5")
	if schema == nil {
		t.Fatal("expected schema for cteni_5")
	}
	props, _ := schema["properties"].(map[string]any)
	answers, _ := props["correct_answers"].(map[string]any)
	addProps, _ := answers["additionalProperties"].(map[string]any)
	if addProps["maxLength"] != cteni5MaxAnswerLen {
		t.Errorf("correct_answers maxLength = %v, want %d", addProps["maxLength"], cteni5MaxAnswerLen)
	}
	if addProps["minLength"] != 1 {
		t.Errorf("correct_answers minLength = %v, want 1", addProps["minLength"])
	}
}

func TestParseReadingDraftDetail_Cteni5_RoundTrips(t *testing.T) {
	raw := []byte(`{
		"text": "Pavel byl nemocný.",
		"questions": [
			{"question_no": 1, "prompt": "Jméno:"}
		],
		"correct_answers": {"1": "Pavel"}
	}`)
	detail, err := parseReadingDraftDetail("cteni_5", raw)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	d, ok := detail.(contracts.Cteni5Detail)
	if !ok {
		t.Fatalf("expected Cteni5Detail, got %T", detail)
	}
	if d.Questions[0].Prompt != "Jméno:" {
		t.Fatalf("prompt mismatch: %q", d.Questions[0].Prompt)
	}
	if d.CorrectAnswers["1"] != "Pavel" {
		t.Fatalf("answer mismatch: %v", d.CorrectAnswers)
	}
}

func TestBuildReadingDraftUserPrompt_Cteni6_RequiresAnoNeUppercase(t *testing.T) {
	in := contracts.ReadingDraftInput{ExerciseType: "cteni_6", Topic: "x", Level: "A2"}
	got := BuildReadingDraftUserPrompt(in)
	for _, sub := range []string{"cteni_6", "1 and 5", "UPPERCASE", "ANO", "NE", "max_points"} {
		if !strings.Contains(got, sub) {
			t.Errorf("user prompt missing %q\nfull:\n%s", sub, got)
		}
	}
}

func TestBuildReadingDraftToolSchema_Cteni6_EnforcesAnoNeEnum(t *testing.T) {
	schema := buildReadingDraftToolSchema("cteni_6")
	if schema == nil {
		t.Fatal("expected schema for cteni_6")
	}
	props, _ := schema["properties"].(map[string]any)
	answers, _ := props["correct_answers"].(map[string]any)
	addProps, _ := answers["additionalProperties"].(map[string]any)
	enum, _ := addProps["enum"].([]string)
	if len(enum) != 2 || enum[0] != "ANO" || enum[1] != "NE" {
		t.Errorf("expected enum [ANO NE], got %v", enum)
	}
	statements, _ := props["statements"].(map[string]any)
	if statements["minItems"] != 1 || statements["maxItems"] != 5 {
		t.Errorf("statements bounds = [%v, %v], want [1, 5]", statements["minItems"], statements["maxItems"])
	}
}

func TestParseReadingDraftDetail_Cteni6_RoundTrips(t *testing.T) {
	raw := []byte(`{
		"passage": "Pavel byl nemocný.",
		"statements": [{"question_no": 1, "statement": "Pavel je doktor."}],
		"correct_answers": {"1": "NE"},
		"max_points": 1
	}`)
	detail, err := parseReadingDraftDetail("cteni_6", raw)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	d, ok := detail.(contracts.AnoNeDetail)
	if !ok {
		t.Fatalf("expected AnoNeDetail, got %T", detail)
	}
	if d.MaxPoints != 1 || d.CorrectAnswers["1"] != "NE" {
		t.Fatalf("decode mismatch: %+v", d)
	}
}

func TestBuildReadingDraftToolSchema_Cteni3_HasFiveDistinctPersons(t *testing.T) {
	schema := buildReadingDraftToolSchema("cteni_3")
	if schema == nil {
		t.Fatal("expected schema for cteni_3")
	}
	props, _ := schema["properties"].(map[string]any)
	persons, _ := props["persons"].(map[string]any)
	if persons["minItems"] != 5 || persons["maxItems"] != 5 {
		t.Errorf("persons bounds = [%v, %v], want [5, 5]", persons["minItems"], persons["maxItems"])
	}
	answers, _ := props["correct_answers"].(map[string]any)
	addProps, _ := answers["additionalProperties"].(map[string]any)
	enum, _ := addProps["enum"].([]string)
	if len(enum) != 5 {
		t.Errorf("expected enum A-E (5 keys), got %v", enum)
	}
}

func TestParseReadingDraftDetail_Cteni3_RoundTrips(t *testing.T) {
	raw := []byte(`{
		"texts": [{"item_no": 1, "text": "A"}],
		"persons": [{"key": "A", "name": "Pavel"}],
		"correct_answers": {"1": "A"}
	}`)
	detail, err := parseReadingDraftDetail("cteni_3", raw)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	d, ok := detail.(contracts.Cteni3Detail)
	if !ok {
		t.Fatalf("expected Cteni3Detail, got %T", detail)
	}
	if d.Persons[0].Name != "Pavel" {
		t.Fatalf("name mismatch: %q", d.Persons[0].Name)
	}
}

func TestParseReadingDraftDetail_Cteni2_RoundTrips(t *testing.T) {
	raw := []byte(`{
		"text": "Pavel byl nemocný.",
		"questions": [
			{"question_no": 1, "prompt": "?", "options": [
				{"key": "A", "text": "a"}, {"key": "B", "text": "b"},
				{"key": "C", "text": "c"}, {"key": "D", "text": "d"}
			]}
		],
		"correct_answers": {"1": "A"}
	}`)
	detail, err := parseReadingDraftDetail("cteni_2", raw)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	d, ok := detail.(contracts.Cteni2Detail)
	if !ok {
		t.Fatalf("expected Cteni2Detail, got %T", detail)
	}
	if d.Text != "Pavel byl nemocný." {
		t.Fatalf("text mismatch: %q", d.Text)
	}
	if len(d.Questions) != 1 || d.Questions[0].Options[0].Key != "A" {
		t.Fatalf("questions decoded incorrectly: %+v", d.Questions)
	}
	if d.CorrectAnswers["1"] != "A" {
		t.Fatalf("correct_answers mismatch: %v", d.CorrectAnswers)
	}
}
