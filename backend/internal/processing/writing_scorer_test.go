package processing

import (
	"strings"
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

func TestCountWords(t *testing.T) {
	cases := []struct {
		input string
		want  int
	}{
		{"", 0},
		{"hello", 1},
		{"hello world", 2},
		{"  hello   world  ", 2},
		{"Jsem z Vietnamu a bydlím v Praze.", 7},
	}
	for _, c := range cases {
		got := countWords(c.input)
		if got != c.want {
			t.Errorf("countWords(%q) = %d, want %d", c.input, got, c.want)
		}
	}
}

func TestValidateWritingSubmission_Psani1(t *testing.T) {
	enough := "Jsem ráda že jsem našla tento e-shop přes kamarádku která nakupuje pravidelně"

	t.Run("ok when all answers have enough words", func(t *testing.T) {
		sub := contracts.WritingSubmission{
			Answers: []string{enough, enough, enough},
		}
		if err := ValidateWritingSubmission("psani_1_formular", sub); err != nil {
			t.Errorf("unexpected error: %v", err)
		}
	})

	t.Run("error when answers field missing", func(t *testing.T) {
		sub := contracts.WritingSubmission{}
		if err := ValidateWritingSubmission("psani_1_formular", sub); err == nil {
			t.Error("expected error for empty answers")
		}
	})

	t.Run("error when wrong answer count", func(t *testing.T) {
		sub := contracts.WritingSubmission{Answers: []string{enough, enough}}
		if err := ValidateWritingSubmission("psani_1_formular", sub); err == nil {
			t.Error("expected error for 2 answers (need 3)")
		}
	})

	t.Run("error when one answer too short", func(t *testing.T) {
		sub := contracts.WritingSubmission{
			Answers: []string{enough, "krátká odpověď", enough},
		}
		if err := ValidateWritingSubmission("psani_1_formular", sub); err == nil {
			t.Error("expected error for short answer")
		}
	})
}

func TestValidateWritingSubmission_Psani2(t *testing.T) {
	longText := "Ahoj Lído tady Eva jsem na dovolené v Itálii s celou rodinou bydlíme v malém hotelu přímo u moře každé ráno chodíme na pláž odpoledne prohlížíme historické památky a večer chodíme jíst do místní restaurace kde vaří výborné italské těstoviny a pizzu"

	t.Run("ok when text long enough", func(t *testing.T) {
		sub := contracts.WritingSubmission{Text: longText}
		if err := ValidateWritingSubmission("psani_2_email", sub); err != nil {
			t.Errorf("unexpected error: %v", err)
		}
	})

	t.Run("error when text too short", func(t *testing.T) {
		sub := contracts.WritingSubmission{Text: "Ahoj jak se máš"}
		if err := ValidateWritingSubmission("psani_2_email", sub); err == nil {
			t.Error("expected error for short text")
		}
	})

	t.Run("error when text field missing", func(t *testing.T) {
		sub := contracts.WritingSubmission{}
		if err := ValidateWritingSubmission("psani_2_email", sub); err == nil {
			t.Error("expected error for empty text")
		}
	})
}

func TestWritingText(t *testing.T) {
	t.Run("psani_1 joins answers with double newline", func(t *testing.T) {
		sub := contracts.WritingSubmission{Answers: []string{"A", "B", "C"}}
		got := writingText("psani_1_formular", sub)
		want := "A\n\nB\n\nC"
		if got != want {
			t.Errorf("writingText = %q, want %q", got, want)
		}
	})

	t.Run("psani_2 returns text directly", func(t *testing.T) {
		sub := contracts.WritingSubmission{Text: "hello world"}
		got := writingText("psani_2_email", sub)
		if got != "hello world" {
			t.Errorf("writingText = %q, want %q", got, "hello world")
		}
	})
}

// --- boundary tests for ValidateWritingSubmission ---

func TestValidateWritingSubmission_Psani1_ExactBoundary(t *testing.T) {
	// Exactly 10 words: must pass.
	exact10 := "jedna dvě tři čtyři pět šest sedm osm devět deset"
	sub := contracts.WritingSubmission{Answers: []string{exact10, exact10, exact10}}
	if err := ValidateWritingSubmission("psani_1_formular", sub); err != nil {
		t.Errorf("expected ok for exactly 10 words per answer, got: %v", err)
	}
}

func TestValidateWritingSubmission_Psani1_NineWords(t *testing.T) {
	// 9 words: must fail.
	nine := "jedna dvě tři čtyři pět šest sedm osm devět"
	enough := "jedna dvě tři čtyři pět šest sedm osm devět deset"
	sub := contracts.WritingSubmission{Answers: []string{enough, nine, enough}}
	if err := ValidateWritingSubmission("psani_1_formular", sub); err == nil {
		t.Error("expected error for answer with 9 words (minimum is 10)")
	}
}

func TestValidateWritingSubmission_Psani2_ExactBoundary(t *testing.T) {
	// Build a 35-word string: must pass.
	words := make([]string, 35)
	for i := range words {
		words[i] = "slovo"
	}
	text35 := strings.Join(words, " ")
	sub := contracts.WritingSubmission{Text: text35}
	if err := ValidateWritingSubmission("psani_2_email", sub); err != nil {
		t.Errorf("expected ok for exactly 35 words, got: %v", err)
	}
}

func TestValidateWritingSubmission_Psani2_ThirtyFourWords(t *testing.T) {
	// 34 words: must fail.
	words := make([]string, 34)
	for i := range words {
		words[i] = "slovo"
	}
	sub := contracts.WritingSubmission{Text: strings.Join(words, " ")}
	if err := ValidateWritingSubmission("psani_2_email", sub); err == nil {
		t.Error("expected error for 34 words (minimum is 35)")
	}
}

func TestValidateWritingSubmission_UnknownType(t *testing.T) {
	sub := contracts.WritingSubmission{Text: "anything"}
	if err := ValidateWritingSubmission("psani_3_unknown", sub); err == nil {
		t.Error("expected error for unsupported exercise type")
	}
}

// --- buildWritingReviewArtifact ---

func TestBuildWritingReviewArtifact_EmptyLearnerText(t *testing.T) {
	fb := contracts.AttemptFeedback{SampleAnswer: "model text"}
	art := buildWritingReviewArtifact("", fb)
	if art.Status != "failed" {
		t.Errorf("expected status=failed for empty learner text, got %q", art.Status)
	}
	if art.FailureCode != "empty_text" {
		t.Errorf("expected failure_code=empty_text, got %q", art.FailureCode)
	}
}

func TestBuildWritingReviewArtifact_WithSampleAnswer(t *testing.T) {
	learner := "Ahoj jak se más"
	model := "Dobrý den, jak se máte?"
	fb := contracts.AttemptFeedback{SampleAnswer: model}
	art := buildWritingReviewArtifact(learner, fb)
	if art.Status != "ready" {
		t.Errorf("expected status=ready, got %q", art.Status)
	}
	if art.SourceTranscriptText != learner {
		t.Errorf("SourceTranscriptText = %q, want %q", art.SourceTranscriptText, learner)
	}
	if art.CorrectedTranscriptText != model {
		t.Errorf("CorrectedTranscriptText = %q, want %q", art.CorrectedTranscriptText, model)
	}
	if art.ModelAnswerText != model {
		t.Errorf("ModelAnswerText = %q, want %q", art.ModelAnswerText, model)
	}
}

func TestBuildWritingReviewArtifact_EmptySampleAnswer(t *testing.T) {
	// When LLM returns no SampleAnswer, CorrectedTranscriptText falls back to learner text.
	learner := "Jsem student z Hanoje."
	fb := contracts.AttemptFeedback{SampleAnswer: ""}
	art := buildWritingReviewArtifact(learner, fb)
	if art.Status != "ready" {
		t.Errorf("expected status=ready, got %q", art.Status)
	}
	if art.CorrectedTranscriptText != learner {
		t.Errorf("CorrectedTranscriptText should fall back to learner text, got %q", art.CorrectedTranscriptText)
	}
	if art.ModelAnswerText != "" {
		t.Errorf("ModelAnswerText should be empty when SampleAnswer is empty, got %q", art.ModelAnswerText)
	}
}

// --- writingFallbackFeedback ---

func TestWritingFallbackFeedback_Fields(t *testing.T) {
	fb := writingFallbackFeedback()
	if fb.ReadinessLevel != "ok" {
		t.Errorf("ReadinessLevel = %q, want ok", fb.ReadinessLevel)
	}
	if fb.OverallSummary == "" {
		t.Error("expected non-empty OverallSummary in fallback feedback")
	}
	if len(fb.Strengths) == 0 {
		t.Error("expected at least one strength in fallback feedback")
	}
	if len(fb.Improvements) == 0 {
		t.Error("expected at least one improvement in fallback feedback")
	}
	if fb.TaskCompletion.ScoreBand != "ok" {
		t.Errorf("TaskCompletion.ScoreBand = %q, want ok", fb.TaskCompletion.ScoreBand)
	}
}
