package processing

import (
	"testing"
)

// IV-3: injectSelectedOption tests

func TestInjectSelectedOption_ReplacesPlaceholder(t *testing.T) {
	prompt := "You are Jana. The learner chose {selected_option}. Ask why."
	result := injectSelectedOption(prompt, "Praha")
	want := "You are Jana. The learner chose Praha. Ask why."
	if result != want {
		t.Fatalf("got %q, want %q", result, want)
	}
}

func TestInjectSelectedOption_NoPlaceholder_Unchanged(t *testing.T) {
	prompt := "You are Jana, a Czech examiner. Ask about family."
	result := injectSelectedOption(prompt, "Praha")
	if result != prompt {
		t.Fatalf("expected prompt unchanged, got %q", result)
	}
}

func TestInjectSelectedOption_EmptyOption_Unchanged(t *testing.T) {
	prompt := "You are Jana. The learner chose {selected_option}."
	result := injectSelectedOption(prompt, "")
	// Empty selectedOption: placeholder stays — caller should not inject empty option
	if result != prompt {
		t.Fatalf("expected prompt unchanged for empty option, got %q", result)
	}
}

func TestInjectSelectedOption_MultiplePlaceholders(t *testing.T) {
	prompt := "The learner chose {selected_option}. Why {selected_option}?"
	result := injectSelectedOption(prompt, "Brno")
	want := "The learner chose Brno. Why Brno?"
	if result != want {
		t.Fatalf("got %q, want %q", result, want)
	}
}

func TestBuildInterviewTranscriptText_Formats(t *testing.T) {
	turns := []interviewTurn{
		{Speaker: "examiner", Text: "Jak se jmenujete?"},
		{Speaker: "learner", Text: "Jmenuji se Anna."},
		{Speaker: "examiner", Text: "Odkud jste?"},
		{Speaker: "learner", Text: "Jsem z Brna."},
	}
	text := buildInterviewTranscriptText(turns)
	if text == "" {
		t.Fatal("expected non-empty transcript text")
	}
	// Should contain speaker labels and text
	for _, turn := range turns {
		if !interviewContains(text, turn.Text) {
			t.Fatalf("expected transcript to contain %q", turn.Text)
		}
	}
}

func TestBuildInterviewTranscriptText_EmptyTurns(t *testing.T) {
	text := buildInterviewTranscriptText(nil)
	if text != "" {
		t.Fatalf("expected empty text for nil turns, got %q", text)
	}
}

func interviewContains(s, sub string) bool {
	if len(s) < len(sub) {
		return false
	}
	for i := 0; i <= len(s)-len(sub); i++ {
		if s[i:i+len(sub)] == sub {
			return true
		}
	}
	return false
}
