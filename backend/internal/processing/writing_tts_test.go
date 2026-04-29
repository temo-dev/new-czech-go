package processing

import (
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// TestBuildWritingReviewArtifact_ModelAnswerTextPopulated verifies that
// buildWritingReviewArtifact sets ModelAnswerText when feedback has SampleAnswer.
// ProcessWritingAttempt uses this to trigger TTS generation.
func TestBuildWritingReviewArtifact_ModelAnswerTextPopulated(t *testing.T) {
	feedback := contracts.AttemptFeedback{
		ReadinessLevel: "ok",
		SampleAnswer:   "Já jsem student. Studuji na univerzitě.",
	}

	artifact := buildWritingReviewArtifact("Ja jsem student.", feedback)

	if artifact.Status != "ready" {
		t.Fatalf("expected status=ready, got %s", artifact.Status)
	}
	if artifact.ModelAnswerText != "Já jsem student. Studuji na univerzitě." {
		t.Errorf("ModelAnswerText should match feedback.SampleAnswer, got %q", artifact.ModelAnswerText)
	}
	// TTSAudio is set by ProcessWritingAttempt after building the artifact,
	// not by buildWritingReviewArtifact itself.
	if artifact.TTSAudio != nil {
		t.Error("buildWritingReviewArtifact should not set TTSAudio directly")
	}
}

// TestBuildWritingReviewArtifact_EmptyLearnerText verifies failure path.
func TestBuildWritingReviewArtifact_EmptyLearnerText(t *testing.T) {
	artifact := buildWritingReviewArtifact("", contracts.AttemptFeedback{})
	if artifact.Status != "failed" {
		t.Errorf("expected status=failed for empty text, got %s", artifact.Status)
	}
}
