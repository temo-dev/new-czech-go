package processing

import (
	"fmt"
	"strconv"
	"strings"
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// ── cteni_2 fixtures ──────────────────────────────────────────────────────────

func validCteni2Detail() contracts.Cteni2Detail {
	return contracts.Cteni2Detail{
		Text: "Pavel byl nemocný a šel k lékaři. Lékař se ho zeptal, co ho bolí. Pavel řekl, že ho bolí hlava a v krku.",
		Questions: []contracts.ReadingQuestion{
			cteni2Q(1, "Kam šel Pavel?"),
			cteni2Q(2, "Co se zeptal lékař?"),
			cteni2Q(3, "Co bolí Pavla?"),
			cteni2Q(4, "Kdo je Pavel?"),
			cteni2Q(5, "Co dostal Pavel?"),
		},
		CorrectAnswers: map[string]string{"1": "A", "2": "B", "3": "C", "4": "D", "5": "A"},
	}
}

func cteni2Q(no int, prompt string) contracts.ReadingQuestion {
	return contracts.ReadingQuestion{
		QuestionNo: no,
		Prompt:     prompt,
		Options: []contracts.MultipleChoiceOption{
			{Key: "A", Text: "option A"},
			{Key: "B", Text: "option B"},
			{Key: "C", Text: "option C"},
			{Key: "D", Text: "option D"},
		},
	}
}

func TestValidateReadingDraft_Cteni2_AcceptsValid(t *testing.T) {
	draft := &contracts.ReadingDraft{
		ExerciseType: "cteni_2",
		Detail:       validCteni2Detail(),
	}
	if err := ValidateReadingDraft(draft); err != nil {
		t.Fatalf("expected valid draft to pass, got %v", err)
	}
}

func TestValidateReadingDraft_Cteni2_RejectsMalformed(t *testing.T) {
	cases := []struct {
		name    string
		mutate  func(d *contracts.Cteni2Detail)
		wantSub string
	}{
		{
			name:    "wrong question count",
			mutate:  func(d *contracts.Cteni2Detail) { d.Questions = d.Questions[:4] },
			wantSub: "5 questions",
		},
		{
			name:    "options not exactly 4",
			mutate:  func(d *contracts.Cteni2Detail) { d.Questions[0].Options = d.Questions[0].Options[:3] },
			wantSub: "4 options",
		},
		{
			name: "correct_answer key out of A-D",
			mutate: func(d *contracts.Cteni2Detail) {
				d.CorrectAnswers["1"] = "E"
			},
			wantSub: "A-D",
		},
		{
			name:    "missing correct_answer for question 3",
			mutate:  func(d *contracts.Cteni2Detail) { delete(d.CorrectAnswers, "3") },
			wantSub: "missing correct_answer",
		},
		{
			name:    "empty text",
			mutate:  func(d *contracts.Cteni2Detail) { d.Text = "" },
			wantSub: "text",
		},
		{
			name: "empty option text",
			mutate: func(d *contracts.Cteni2Detail) {
				d.Questions[2].Options[1].Text = ""
			},
			wantSub: "option text",
		},
		{
			name: "duplicate option keys",
			mutate: func(d *contracts.Cteni2Detail) {
				d.Questions[0].Options[1].Key = "A"
			},
			wantSub: "duplicate",
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			detail := validCteni2Detail()
			tc.mutate(&detail)
			draft := &contracts.ReadingDraft{ExerciseType: "cteni_2", Detail: detail}
			err := ValidateReadingDraft(draft)
			if err == nil {
				t.Fatalf("expected validation error containing %q, got nil", tc.wantSub)
			}
			if !strings.Contains(err.Error(), tc.wantSub) {
				t.Fatalf("expected error containing %q, got %q", tc.wantSub, err.Error())
			}
		})
	}
}

func TestValidateReadingDraft_RejectsUnknownType(t *testing.T) {
	draft := &contracts.ReadingDraft{ExerciseType: "uloha_1", Detail: nil}
	if err := ValidateReadingDraft(draft); err == nil {
		t.Fatal("expected error for unknown exercise_type")
	}
}

func TestValidateReadingDraft_Cteni2_RejectsWrongDetailType(t *testing.T) {
	draft := &contracts.ReadingDraft{ExerciseType: "cteni_2", Detail: contracts.Cteni4Detail{}}
	if err := ValidateReadingDraft(draft); err == nil {
		t.Fatal("expected error when Detail type mismatches exercise_type")
	}
}

// ── cteni_4 fixtures ──────────────────────────────────────────────────────────

func validCteni4Detail() contracts.Cteni4Detail {
	return contracts.Cteni4Detail{
		Context: "Pavel byl nemocný a šel k lékaři.",
		Questions: []contracts.ReadingQuestion{
			cteni2Q(1, "Q1?"),
			cteni2Q(2, "Q2?"),
			cteni2Q(3, "Q3?"),
			cteni2Q(4, "Q4?"),
			cteni2Q(5, "Q5?"),
			cteni2Q(6, "Q6?"),
		},
		CorrectAnswers: map[string]string{"1": "A", "2": "B", "3": "C", "4": "D", "5": "A", "6": "B"},
	}
}

func TestValidateReadingDraft_Cteni4_AcceptsValid(t *testing.T) {
	draft := &contracts.ReadingDraft{ExerciseType: "cteni_4", Detail: validCteni4Detail()}
	if err := ValidateReadingDraft(draft); err != nil {
		t.Fatalf("expected valid draft to pass, got %v", err)
	}
}

func TestValidateReadingDraft_Cteni4_AcceptsValidWithoutContext(t *testing.T) {
	d := validCteni4Detail()
	d.Context = ""
	draft := &contracts.ReadingDraft{ExerciseType: "cteni_4", Detail: d}
	if err := ValidateReadingDraft(draft); err != nil {
		t.Fatalf("expected empty context to pass (optional), got %v", err)
	}
}

// ── cteni_5 fixtures ──────────────────────────────────────────────────────────

func validCteni5Detail() contracts.Cteni5Detail {
	return contracts.Cteni5Detail{
		Text: "Pavel byl nemocný a šel k lékaři ve čtvrtek.",
		Questions: []contracts.FillQuestion{
			{QuestionNo: 1, Prompt: "Jméno autora:"},
			{QuestionNo: 2, Prompt: "Kam šel:"},
			{QuestionNo: 3, Prompt: "Den:"},
			{QuestionNo: 4, Prompt: "Co bolelo:"},
			{QuestionNo: 5, Prompt: "Stav:"},
		},
		CorrectAnswers: map[string]string{"1": "Pavel", "2": "lékař", "3": "čtvrtek", "4": "hlava", "5": "nemocný"},
	}
}

func TestValidateReadingDraft_Cteni5_AcceptsValid(t *testing.T) {
	draft := &contracts.ReadingDraft{ExerciseType: "cteni_5", Detail: validCteni5Detail()}
	if err := ValidateReadingDraft(draft); err != nil {
		t.Fatalf("expected valid draft to pass, got %v", err)
	}
}

func TestValidateReadingDraft_Cteni5_RejectsMalformed(t *testing.T) {
	cases := []struct {
		name    string
		mutate  func(d *contracts.Cteni5Detail)
		wantSub string
	}{
		{
			name:    "empty text",
			mutate:  func(d *contracts.Cteni5Detail) { d.Text = "" },
			wantSub: "text",
		},
		{
			name:    "wrong question count",
			mutate:  func(d *contracts.Cteni5Detail) { d.Questions = d.Questions[:4] },
			wantSub: "5 questions",
		},
		{
			name:    "empty prompt",
			mutate:  func(d *contracts.Cteni5Detail) { d.Questions[2].Prompt = "" },
			wantSub: "prompt",
		},
		{
			name:    "missing correct_answer for question 4",
			mutate:  func(d *contracts.Cteni5Detail) { delete(d.CorrectAnswers, "4") },
			wantSub: "missing correct_answer",
		},
		{
			name:    "empty correct_answer value",
			mutate:  func(d *contracts.Cteni5Detail) { d.CorrectAnswers["1"] = "" },
			wantSub: "empty",
		},
		{
			name:    "correct_answer value too long",
			mutate:  func(d *contracts.Cteni5Detail) { d.CorrectAnswers["3"] = strings.Repeat("a", 31) },
			wantSub: "30 characters",
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			detail := validCteni5Detail()
			tc.mutate(&detail)
			draft := &contracts.ReadingDraft{ExerciseType: "cteni_5", Detail: detail}
			err := ValidateReadingDraft(draft)
			if err == nil {
				t.Fatalf("expected validation error containing %q, got nil", tc.wantSub)
			}
			if !strings.Contains(err.Error(), tc.wantSub) {
				t.Fatalf("expected error containing %q, got %q", tc.wantSub, err.Error())
			}
		})
	}
}

// ── cteni_6 fixtures ──────────────────────────────────────────────────────────

func validCteni6Detail() contracts.AnoNeDetail {
	return contracts.AnoNeDetail{
		Passage: "Pavel byl nemocný a šel k lékaři ve čtvrtek.",
		Statements: []contracts.AnoNeStatement{
			{QuestionNo: 1, Statement: "Pavel je doktor."},
			{QuestionNo: 2, Statement: "Pavel byl nemocný."},
			{QuestionNo: 3, Statement: "Pavel šel v pondělí."},
		},
		CorrectAnswers: map[string]string{"1": "NE", "2": "ANO", "3": "NE"},
		MaxPoints:      3,
	}
}

func TestValidateReadingDraft_Cteni6_AcceptsValid(t *testing.T) {
	draft := &contracts.ReadingDraft{ExerciseType: "cteni_6", Detail: validCteni6Detail()}
	if err := ValidateReadingDraft(draft); err != nil {
		t.Fatalf("expected valid draft to pass, got %v", err)
	}
}

func TestValidateReadingDraft_Cteni6_AcceptsBoundary(t *testing.T) {
	for _, n := range []int{1, 5} {
		t.Run(fmt.Sprintf("statements=%d", n), func(t *testing.T) {
			d := contracts.AnoNeDetail{Passage: "x"}
			d.CorrectAnswers = map[string]string{}
			for i := 1; i <= n; i++ {
				d.Statements = append(d.Statements, contracts.AnoNeStatement{QuestionNo: i, Statement: "s"})
				d.CorrectAnswers[strconv.Itoa(i)] = "ANO"
			}
			d.MaxPoints = n
			draft := &contracts.ReadingDraft{ExerciseType: "cteni_6", Detail: d}
			if err := ValidateReadingDraft(draft); err != nil {
				t.Fatalf("expected boundary count to pass, got %v", err)
			}
		})
	}
}

func TestValidateReadingDraft_Cteni6_RejectsMalformed(t *testing.T) {
	cases := []struct {
		name    string
		mutate  func(d *contracts.AnoNeDetail)
		wantSub string
	}{
		{
			name:    "empty passage",
			mutate:  func(d *contracts.AnoNeDetail) { d.Passage = "" },
			wantSub: "passage",
		},
		{
			name:    "zero statements",
			mutate:  func(d *contracts.AnoNeDetail) { d.Statements = nil; d.CorrectAnswers = map[string]string{}; d.MaxPoints = 0 },
			wantSub: "1-5",
		},
		{
			name: "six statements",
			mutate: func(d *contracts.AnoNeDetail) {
				d.Statements = append(d.Statements,
					contracts.AnoNeStatement{QuestionNo: 4, Statement: "s4"},
					contracts.AnoNeStatement{QuestionNo: 5, Statement: "s5"},
					contracts.AnoNeStatement{QuestionNo: 6, Statement: "s6"})
				d.CorrectAnswers["4"] = "ANO"
				d.CorrectAnswers["5"] = "NE"
				d.CorrectAnswers["6"] = "ANO"
				d.MaxPoints = 6
			},
			wantSub: "1-5",
		},
		{
			name:    "lowercase ano",
			mutate:  func(d *contracts.AnoNeDetail) { d.CorrectAnswers["1"] = "ano" },
			wantSub: "ANO",
		},
		{
			name:    "value not ANO/NE",
			mutate:  func(d *contracts.AnoNeDetail) { d.CorrectAnswers["1"] = "YES" },
			wantSub: "ANO",
		},
		{
			name:    "max_points mismatch",
			mutate:  func(d *contracts.AnoNeDetail) { d.MaxPoints = 99 },
			wantSub: "max_points",
		},
		{
			name:    "missing correct_answer",
			mutate:  func(d *contracts.AnoNeDetail) { delete(d.CorrectAnswers, "2") },
			wantSub: "missing correct_answer",
		},
		{
			name:    "empty statement text",
			mutate:  func(d *contracts.AnoNeDetail) { d.Statements[0].Statement = "" },
			wantSub: "statement",
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			detail := validCteni6Detail()
			tc.mutate(&detail)
			draft := &contracts.ReadingDraft{ExerciseType: "cteni_6", Detail: detail}
			err := ValidateReadingDraft(draft)
			if err == nil {
				t.Fatalf("expected validation error containing %q, got nil", tc.wantSub)
			}
			if !strings.Contains(err.Error(), tc.wantSub) {
				t.Fatalf("expected error containing %q, got %q", tc.wantSub, err.Error())
			}
		})
	}
}

func TestValidateReadingDraft_Cteni4_RejectsMalformed(t *testing.T) {
	cases := []struct {
		name    string
		mutate  func(d *contracts.Cteni4Detail)
		wantSub string
	}{
		{
			name:    "wrong question count",
			mutate:  func(d *contracts.Cteni4Detail) { d.Questions = d.Questions[:5] },
			wantSub: "6 questions",
		},
		{
			name:    "options not exactly 4",
			mutate:  func(d *contracts.Cteni4Detail) { d.Questions[2].Options = d.Questions[2].Options[:3] },
			wantSub: "4 options",
		},
		{
			name:    "correct_answer key out of A-D",
			mutate:  func(d *contracts.Cteni4Detail) { d.CorrectAnswers["1"] = "Z" },
			wantSub: "A-D",
		},
		{
			name:    "missing correct_answer for question 6",
			mutate:  func(d *contracts.Cteni4Detail) { delete(d.CorrectAnswers, "6") },
			wantSub: "missing correct_answer",
		},
		{
			name:    "duplicate option keys",
			mutate:  func(d *contracts.Cteni4Detail) { d.Questions[0].Options[1].Key = "A" },
			wantSub: "duplicate",
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			detail := validCteni4Detail()
			tc.mutate(&detail)
			draft := &contracts.ReadingDraft{ExerciseType: "cteni_4", Detail: detail}
			err := ValidateReadingDraft(draft)
			if err == nil {
				t.Fatalf("expected validation error containing %q, got nil", tc.wantSub)
			}
			if !strings.Contains(err.Error(), tc.wantSub) {
				t.Fatalf("expected error containing %q, got %q", tc.wantSub, err.Error())
			}
		})
	}
}
