package processing

import (
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
