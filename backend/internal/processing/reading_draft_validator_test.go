package processing

import (
	"fmt"
	"strconv"
	"strings"
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

func sampleCzechWords(n int) string {
	words := []string{"Pavel", "šel", "ráno", "na", "úřad", "protože", "potřeboval", "nový", "formulář", "a", "mluvil", "pomalu"}
	out := make([]string, n)
	for i := range out {
		out[i] = words[i%len(words)]
	}
	return strings.Join(out, " ")
}

// ── cteni_2 fixtures ──────────────────────────────────────────────────────────

func validCteni2Detail() contracts.Cteni2Detail {
	return contracts.Cteni2Detail{
		Text: sampleCzechWords(120),
		Questions: []contracts.ReadingQuestion{
			cteni2Q(6, "Kam šel Pavel?"),
			cteni2Q(7, "Co se zeptal lékař?"),
			cteni2Q(8, "Co bolí Pavla?"),
			cteni2Q(9, "Kdo je Pavel?"),
			cteni2Q(10, "Co dostal Pavel?"),
		},
		CorrectAnswers: map[string]string{"6": "A", "7": "B", "8": "C", "9": "D", "10": "A"},
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
				d.CorrectAnswers["6"] = "E"
			},
			wantSub: "A-D",
		},
		{
			name:    "missing correct_answer for question 8",
			mutate:  func(d *contracts.Cteni2Detail) { delete(d.CorrectAnswers, "8") },
			wantSub: "missing correct_answer",
		},
		{
			name:    "empty text",
			mutate:  func(d *contracts.Cteni2Detail) { d.Text = "" },
			wantSub: "text",
		},
		{
			name:    "text too short",
			mutate:  func(d *contracts.Cteni2Detail) { d.Text = sampleCzechWords(cteni2MinWords - 1) },
			wantSub: "100-200 words",
		},
		{
			name:    "text too long",
			mutate:  func(d *contracts.Cteni2Detail) { d.Text = sampleCzechWords(cteni2MaxWords + 1) },
			wantSub: "100-200 words",
		},
		{
			name:    "wrong question_no sequence",
			mutate:  func(d *contracts.Cteni2Detail) { d.Questions[0].QuestionNo = 1 },
			wantSub: "question_no",
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

// ── cteni_1 fixtures ──────────────────────────────────────────────────────────

func validCteni1Detail() contracts.Cteni1Detail {
	return contracts.Cteni1Detail{
		Items: []contracts.ReadingItem{
			{ItemNo: 1, Text: "Setkáme se v 18:00."},
			{ItemNo: 2, Text: "Zítra je svátek."},
			{ItemNo: 3, Text: "Mám nový telefon."},
			{ItemNo: 4, Text: "Vlak odjíždí v 9:30."},
			{ItemNo: 5, Text: "Kupte si chleba."},
		},
		Options: []contracts.TextOption{
			{Key: "A", Text: "info o schůzce"},
			{Key: "B", Text: "cestovní info"},
			{Key: "C", Text: "info o nákupu"},
			{Key: "D", Text: "info o svátku"},
			{Key: "E", Text: "info o telefonu"},
			{Key: "F", Text: "info o jídle"},
			{Key: "G", Text: "info o počasí"},
			{Key: "H", Text: "info o sportu"},
		},
		CorrectAnswers: map[string]string{"1": "A", "2": "D", "3": "E", "4": "B", "5": "C"},
	}
}

func TestValidateReadingDraft_Cteni1_AcceptsValid(t *testing.T) {
	draft := &contracts.ReadingDraft{ExerciseType: "cteni_1", Detail: validCteni1Detail()}
	if err := ValidateReadingDraft(draft); err != nil {
		t.Fatalf("expected valid draft to pass, got %v", err)
	}
}

func TestValidateReadingDraft_Cteni1_RejectsMalformed(t *testing.T) {
	cases := []struct {
		name    string
		mutate  func(d *contracts.Cteni1Detail)
		wantSub string
	}{
		{
			name:    "wrong item count",
			mutate:  func(d *contracts.Cteni1Detail) { d.Items = d.Items[:4] },
			wantSub: "5 items",
		},
		{
			name:    "wrong option count",
			mutate:  func(d *contracts.Cteni1Detail) { d.Options = d.Options[:7] },
			wantSub: "8 options",
		},
		{
			name:    "option key out of A-H",
			mutate:  func(d *contracts.Cteni1Detail) { d.Options[0].Key = "Z" },
			wantSub: "A-H",
		},
		{
			name:    "duplicate option keys",
			mutate:  func(d *contracts.Cteni1Detail) { d.Options[1].Key = "A" },
			wantSub: "duplicate",
		},
		{
			name:    "asset_id present (forbidden in V24)",
			mutate:  func(d *contracts.Cteni1Detail) { d.Items[0].AssetID = "img-123" },
			wantSub: "asset_id",
		},
		{
			name:    "empty item text",
			mutate:  func(d *contracts.Cteni1Detail) { d.Items[2].Text = "" },
			wantSub: "text",
		},
		{
			name:    "wrong item_no sequence",
			mutate:  func(d *contracts.Cteni1Detail) { d.Items[1].ItemNo = 9 },
			wantSub: "item_no",
		},
		{
			name:    "correct_answer value out of A-H",
			mutate:  func(d *contracts.Cteni1Detail) { d.CorrectAnswers["1"] = "Z" },
			wantSub: "A-H",
		},
		{
			name:    "missing correct_answer",
			mutate:  func(d *contracts.Cteni1Detail) { delete(d.CorrectAnswers, "5") },
			wantSub: "missing correct_answer",
		},
		{
			name:    "duplicate correct_answer values",
			mutate:  func(d *contracts.Cteni1Detail) { d.CorrectAnswers["2"] = "A" },
			wantSub: "duplicate",
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			detail := validCteni1Detail()
			tc.mutate(&detail)
			draft := &contracts.ReadingDraft{ExerciseType: "cteni_1", Detail: detail}
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

// ── cteni_3 fixtures ──────────────────────────────────────────────────────────

func validCteni3Detail() contracts.Cteni3Detail {
	return contracts.Cteni3Detail{
		Texts: []contracts.TextItem{
			{ItemNo: 1, Text: "Mám rád kávu a knihy."},
			{ItemNo: 2, Text: "Hraju fotbal každý víkend."},
			{ItemNo: 3, Text: "Pracuju jako učitelka."},
			{ItemNo: 4, Text: "Cestuji rád po Evropě."},
		},
		Persons: []contracts.PersonOption{
			{Key: "A", Name: "Pavel", Description: "sportovec"},
			{Key: "B", Name: "Marie", Description: "učitelka"},
			{Key: "C", Name: "Jan", Description: "intelektuál"},
			{Key: "D", Name: "Eva", Description: "cestovatelka"},
			{Key: "E", Name: "Tomáš", Description: "kuchař"},
		},
		CorrectAnswers: map[string]string{"1": "C", "2": "A", "3": "B", "4": "D"},
	}
}

func TestValidateReadingDraft_Cteni3_AcceptsValid(t *testing.T) {
	draft := &contracts.ReadingDraft{ExerciseType: "cteni_3", Detail: validCteni3Detail()}
	if err := ValidateReadingDraft(draft); err != nil {
		t.Fatalf("expected valid draft to pass, got %v", err)
	}
}

func TestValidateReadingDraft_Cteni3_RejectsMalformed(t *testing.T) {
	cases := []struct {
		name    string
		mutate  func(d *contracts.Cteni3Detail)
		wantSub string
	}{
		{
			name:    "wrong text count",
			mutate:  func(d *contracts.Cteni3Detail) { d.Texts = d.Texts[:3] },
			wantSub: "4 texts",
		},
		{
			name:    "wrong person count",
			mutate:  func(d *contracts.Cteni3Detail) { d.Persons = d.Persons[:4] },
			wantSub: "5 persons",
		},
		{
			name:    "person key out of A-E",
			mutate:  func(d *contracts.Cteni3Detail) { d.Persons[2].Key = "Z" },
			wantSub: "A-E",
		},
		{
			name:    "duplicate person keys",
			mutate:  func(d *contracts.Cteni3Detail) { d.Persons[1].Key = "A" },
			wantSub: "duplicate",
		},
		{
			name:    "empty person name",
			mutate:  func(d *contracts.Cteni3Detail) { d.Persons[3].Name = "" },
			wantSub: "name",
		},
		{
			name:    "correct_answer value out of A-E",
			mutate:  func(d *contracts.Cteni3Detail) { d.CorrectAnswers["1"] = "Z" },
			wantSub: "A-E",
		},
		{
			name:    "missing correct_answer",
			mutate:  func(d *contracts.Cteni3Detail) { delete(d.CorrectAnswers, "3") },
			wantSub: "missing correct_answer",
		},
		{
			name:    "duplicate correct_answer values",
			mutate:  func(d *contracts.Cteni3Detail) { d.CorrectAnswers["2"] = "C" },
			wantSub: "duplicate",
		},
		{
			name:    "empty text item",
			mutate:  func(d *contracts.Cteni3Detail) { d.Texts[0].Text = "" },
			wantSub: "text",
		},
		{
			name:    "wrong item_no sequence",
			mutate:  func(d *contracts.Cteni3Detail) { d.Texts[2].ItemNo = 8 },
			wantSub: "item_no",
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			detail := validCteni3Detail()
			tc.mutate(&detail)
			draft := &contracts.ReadingDraft{ExerciseType: "cteni_3", Detail: detail}
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

// ── cteni_4 fixtures ──────────────────────────────────────────────────────────

func validCteni4Detail() contracts.Cteni4Detail {
	return contracts.Cteni4Detail{
		Context: "Pavel byl nemocný a šel k lékaři.",
		Questions: []contracts.ReadingQuestion{
			cteni2Q(15, "Q1?"),
			cteni2Q(16, "Q2?"),
			cteni2Q(17, "Q3?"),
			cteni2Q(18, "Q4?"),
			cteni2Q(19, "Q5?"),
			cteni2Q(20, "Q6?"),
		},
		CorrectAnswers: map[string]string{"15": "A", "16": "B", "17": "C", "18": "D", "19": "A", "20": "B"},
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
		Text: sampleCzechWords(90),
		Questions: []contracts.FillQuestion{
			{QuestionNo: 21, Prompt: "Jméno autora:"},
			{QuestionNo: 22, Prompt: "Kam šel:"},
			{QuestionNo: 23, Prompt: "Den:"},
			{QuestionNo: 24, Prompt: "Co bolelo:"},
			{QuestionNo: 25, Prompt: "Stav:"},
		},
		CorrectAnswers: map[string]string{"21": "Pavel", "22": "lékař", "23": "čtvrtek", "24": "hlava", "25": "nemocný"},
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
			name:    "text too short",
			mutate:  func(d *contracts.Cteni5Detail) { d.Text = sampleCzechWords(cteni5MinWords - 1) },
			wantSub: "80-150 words",
		},
		{
			name:    "wrong question_no sequence",
			mutate:  func(d *contracts.Cteni5Detail) { d.Questions[1].QuestionNo = 99 },
			wantSub: "question_no",
		},
		{
			name:    "empty prompt",
			mutate:  func(d *contracts.Cteni5Detail) { d.Questions[2].Prompt = "" },
			wantSub: "prompt",
		},
		{
			name:    "missing correct_answer for question 24",
			mutate:  func(d *contracts.Cteni5Detail) { delete(d.CorrectAnswers, "24") },
			wantSub: "missing correct_answer",
		},
		{
			name:    "empty correct_answer value",
			mutate:  func(d *contracts.Cteni5Detail) { d.CorrectAnswers["21"] = "" },
			wantSub: "empty",
		},
		{
			name:    "correct_answer value too long",
			mutate:  func(d *contracts.Cteni5Detail) { d.CorrectAnswers["23"] = strings.Repeat("a", 31) },
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
		Passage: sampleCzechWords(90),
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
			d := contracts.AnoNeDetail{Passage: sampleCzechWords(cteni6MinWords)}
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
			name: "zero statements",
			mutate: func(d *contracts.AnoNeDetail) {
				d.Statements = nil
				d.CorrectAnswers = map[string]string{}
				d.MaxPoints = 0
			},
			wantSub: "1-5",
		},
		{
			name:    "passage too short",
			mutate:  func(d *contracts.AnoNeDetail) { d.Passage = sampleCzechWords(cteni6MinWords - 1) },
			wantSub: "80-150 words",
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
			name:    "wrong question_no sequence",
			mutate:  func(d *contracts.AnoNeDetail) { d.Statements[1].QuestionNo = 9 },
			wantSub: "question_no",
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
			mutate:  func(d *contracts.Cteni4Detail) { d.CorrectAnswers["15"] = "Z" },
			wantSub: "A-D",
		},
		{
			name:    "missing correct_answer for question 20",
			mutate:  func(d *contracts.Cteni4Detail) { delete(d.CorrectAnswers, "20") },
			wantSub: "missing correct_answer",
		},
		{
			name:    "duplicate option keys",
			mutate:  func(d *contracts.Cteni4Detail) { d.Questions[0].Options[1].Key = "A" },
			wantSub: "duplicate",
		},
		{
			name:    "wrong question_no sequence",
			mutate:  func(d *contracts.Cteni4Detail) { d.Questions[3].QuestionNo = 99 },
			wantSub: "question_no",
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
