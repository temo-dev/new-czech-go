package processing

import (
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

func TestEvaluateStoryNarrationUsesCheckpointCoverage(t *testing.T) {
	exercise := contracts.Exercise{
		ExerciseType: "uloha_3_story_narration",
		Detail: contracts.Uloha3Detail{
			NarrativeCheckpoints: []string{
				"Rodina prijela autem na chatu",
				"Deti hraly na zahrade",
				"Vecer opekali parky",
				"Vratili se domu",
			},
		},
	}

	transcript := "nejdriv rodina prijela na chatu pak deti hraly na zahrade potom opekali parky nakonec se vratili domu"
	criteria, band := evaluateStoryNarration(exercise, transcript)
	if !criterionMet(criteria, "covered_story_events") {
		t.Fatal("expected covered_story_events to pass when most checkpoints present")
	}
	if !criterionMet(criteria, "narrative_sequence_present") {
		t.Fatal("expected sequence to pass")
	}
	if band == "weak" {
		t.Fatal("expected band better than weak for full coverage")
	}
}

func TestEvaluateStoryNarrationFlagsMissingCheckpoints(t *testing.T) {
	exercise := contracts.Exercise{
		ExerciseType: "uloha_3_story_narration",
		Detail: contracts.Uloha3Detail{
			NarrativeCheckpoints: []string{
				"Rodina prijela autem na chatu",
				"Deti hraly na zahrade",
				"Vecer opekali parky",
				"Vratili se domu",
			},
		},
	}

	transcript := "nejdriv rodina prijela autem"
	criteria, _ := evaluateStoryNarration(exercise, transcript)
	if criterionMet(criteria, "covered_story_events") {
		t.Fatal("expected covered_story_events to fail for low coverage")
	}
	for _, c := range criteria {
		if c.CriterionKey == "covered_story_events" && c.Comment == "" {
			t.Fatal("expected missing-checkpoints hint in comment")
		}
	}
}

func TestEvaluateStoryNarrationFallbackWithoutCheckpoints(t *testing.T) {
	exercise := contracts.Exercise{ExerciseType: "uloha_3_story_narration"}
	transcript := "nejdriv sli ven pak koupili parky nakonec se vratili domu"
	criteria, _ := evaluateStoryNarration(exercise, transcript)
	if !criterionMet(criteria, "narrative_sequence_present") {
		t.Fatal("expected fallback sequence detection without checkpoints")
	}
}

func TestEvaluateChoiceReasoningIdentifiesOption(t *testing.T) {
	exercise := contracts.Exercise{
		ExerciseType: "uloha_4_choice_reasoning",
		Detail: contracts.Uloha4Detail{
			Options: []contracts.ChoiceOption{
				{OptionKey: "a", Label: "Horska chata"},
				{OptionKey: "b", Label: "Hotel u more"},
				{OptionKey: "c", Label: "Mesto Praha"},
			},
			ExpectedReasoningAxes: []string{"priroda a klid", "cena", "deti"},
		},
	}

	transcript := "vybiram horska chata protoze je to dobra priroda a klid pro deti"
	criteria, band := evaluateChoiceReasoning(exercise, transcript)
	if !criterionMet(criteria, "made_clear_choice") {
		t.Fatal("expected made_clear_choice to pass when option label mentioned")
	}
	if !criterionMet(criteria, "gave_reason") {
		t.Fatal("expected gave_reason to pass with protoze + axis hit")
	}
	if !criterionMet(criteria, "reason_matches_choice") {
		t.Fatal("expected reason_matches_choice to pass when label and axis co-occur")
	}
	if band == "weak" {
		t.Fatal("expected band better than weak for full reasoning")
	}
}

func TestEvaluateChoiceReasoningHintsMissingChoice(t *testing.T) {
	exercise := contracts.Exercise{
		ExerciseType: "uloha_4_choice_reasoning",
		Detail: contracts.Uloha4Detail{
			Options: []contracts.ChoiceOption{
				{OptionKey: "a", Label: "Horska chata"},
				{OptionKey: "b", Label: "Hotel u more"},
			},
		},
	}

	transcript := "je to tezke rozhodnuti nevim"
	criteria, _ := evaluateChoiceReasoning(exercise, transcript)
	if criterionMet(criteria, "made_clear_choice") {
		t.Fatal("expected made_clear_choice to fail when no option mentioned")
	}
	for _, c := range criteria {
		if c.CriterionKey == "made_clear_choice" && c.Comment == "" {
			t.Fatal("expected hint referencing option labels")
		}
	}
}

func TestContentTokensFiltersStopwords(t *testing.T) {
	tokens := contentTokens("Rodina je v parku")
	for _, tok := range tokens {
		if tok == "je" || tok == "v" || tok == "a" {
			t.Fatalf("expected stopwords filtered, got %v", tokens)
		}
	}
	if len(tokens) == 0 {
		t.Fatal("expected at least one content token")
	}
}
