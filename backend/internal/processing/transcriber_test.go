package processing

import (
	"context"
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

func TestDevTranscriberMarksTranscriptAsSynthetic(t *testing.T) {
	transcript, reliability, usable, err := DevTranscriber{}.Transcribe(
		contracts.Exercise{ExerciseType: "uloha_1_topic_answers"},
		contracts.AttemptAudio{DurationMs: 8000},
	)
	if err != nil {
		t.Fatalf("Transcribe returned error: %v", err)
	}
	if !usable {
		t.Fatal("expected dev transcript to be usable")
	}
	if reliability == reliabilityUnusable {
		t.Fatalf("expected usable reliability, got %s", reliability)
	}
	if transcript.Provider != transcriptProviderDevStub {
		t.Fatalf("expected provider %q, got %q", transcriptProviderDevStub, transcript.Provider)
	}
	if !transcript.IsSynthetic {
		t.Fatal("expected dev transcript to be marked synthetic")
	}
}

func TestNewConfiguredTranscriberFailsWhenRealTranscriptIsRequiredButProviderIsDev(t *testing.T) {
	t.Setenv("TRANSCRIBER_PROVIDER", "dev")
	t.Setenv("REQUIRE_REAL_TRANSCRIPT", "true")

	_, err := NewConfiguredTranscriber(context.Background())
	if err == nil {
		t.Fatal("expected configuration error when real transcript is required in dev mode")
	}
}
