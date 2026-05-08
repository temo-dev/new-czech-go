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

func TestClaudeReadingDraftGenerator_NotImplementedForAllCteniTypes(t *testing.T) {
	gen := NewClaudeReadingDraftGenerator("dummy-key", DefaultReadingDraftModel)

	for _, exType := range []string{"cteni_1", "cteni_2", "cteni_3", "cteni_4", "cteni_5", "cteni_6"} {
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
