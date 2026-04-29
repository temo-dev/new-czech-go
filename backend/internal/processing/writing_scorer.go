package processing

import (
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// countWords splits s on whitespace and counts non-empty tokens.
func countWords(s string) int {
	return len(strings.Fields(s))
}

// writingText extracts a single learner text string from a WritingSubmission.
// psani_1_formular: joins all answers with a blank line separator.
// psani_2_email: returns Text directly.
func writingText(exerciseType string, sub contracts.WritingSubmission) string {
	if exerciseType == "psani_1_formular" {
		return strings.Join(sub.Answers, "\n\n")
	}
	return sub.Text
}

// validateWritingSubmission checks word-count rules per SPEC:
// psani_1_formular: must have exactly 3 answers, each ≥10 words.
// psani_2_email: Text must be ≥35 words.
func ValidateWritingSubmission(exerciseType string, sub contracts.WritingSubmission) error {
	switch exerciseType {
	case "psani_1_formular":
		if len(sub.Answers) != 3 {
			return fmt.Errorf("psani_1_formular requires exactly 3 answers, got %d", len(sub.Answers))
		}
		for i, a := range sub.Answers {
			if countWords(a) < 10 {
				return fmt.Errorf("answer %d has %d words, minimum is 10", i+1, countWords(a))
			}
		}
	case "psani_2_email":
		if sub.Text == "" {
			return fmt.Errorf("psani_2_email requires a non-empty text field")
		}
		if countWords(sub.Text) < 35 {
			return fmt.Errorf("psani_2_email text has %d words, minimum is 35", countWords(sub.Text))
		}
	default:
		return fmt.Errorf("unsupported writing exercise type: %s", exerciseType)
	}
	return nil
}

// ProcessWritingAttempt scores a writing attempt using the LLM feedback provider.
// The learner's written text is treated as a "transcript" so the existing feedback
// pipeline (LLM prompt → AttemptFeedback → review artifact) can be reused directly.
func (p *Processor) ProcessWritingAttempt(attemptID string, sub contracts.WritingSubmission) {
	attempt, ok := p.repo.Attempt(attemptID)
	if !ok {
		log.Printf("writing attempt %s not found", attemptID)
		return
	}

	exercise, ok := p.repo.Exercise(attempt.ExerciseID)
	if !ok {
		log.Printf("writing attempt %s: exercise %s not found", attemptID, attempt.ExerciseID)
		p.repo.FailAttempt(attemptID, "scoring_failed")
		return
	}

	if err := ValidateWritingSubmission(exercise.ExerciseType, sub); err != nil {
		log.Printf("writing attempt %s validation failed: %v", attemptID, err)
		p.repo.FailAttempt(attemptID, "scoring_failed")
		return
	}

	text := writingText(exercise.ExerciseType, sub)
	locale := attempt.Locale
	if locale == "" {
		locale = "vi"
	}

	// Represent the written text as a transcript so the LLM provider can score it.
	// IsSynthetic=true prevents transcript-noise heuristics from penalising the text.
	transcript := contracts.Transcript{
		FullText:    text,
		Locale:      "cs",
		Confidence:  1.0,
		Provider:    "learner_text",
		IsSynthetic: true,
	}

	// Written text has no STT noise — treat as fully usable.
	reliability := reliabilityUsable

	feedback, ok := p.buildFeedbackWithLLM(attemptID, exercise, transcript, reliability, locale)
	if !ok {
		log.Printf("writing attempt %s: LLM feedback failed, using rule-based fallback", attemptID)
		feedback = writingFallbackFeedback()
	}

	p.repo.CompleteAttempt(attemptID, transcript, feedback)

	artifact := buildWritingReviewArtifact(text, feedback)
	if artifact.Status == "ready" {
		// Generate Polly TTS for the model answer so learners can hear it
		// (same pattern as speaking review artifacts in processor.go).
		if artifact.ModelAnswerText != "" {
			if audio, err := p.ttsProvider.Generate(attemptID, artifact.ModelAnswerText); err != nil {
				log.Printf("writing attempt %s: model answer TTS failed: %v", attemptID, err)
			} else {
				artifact.TTSAudio = audio
			}
		}
		p.repo.UpsertReviewArtifact(attemptID, artifact)
	}

	log.Printf("writing attempt %s completed (readiness=%s)", attemptID, feedback.ReadinessLevel)
}

// buildWritingReviewArtifact constructs the review artifact for a writing attempt.
// Reuses AttemptReviewArtifact — SourceTranscriptText carries the learner text,
// CorrectedTranscriptText carries the LLM correction. TTSAudio is set by the caller.
func buildWritingReviewArtifact(learnerText string, feedback contracts.AttemptFeedback) contracts.AttemptReviewArtifact {
	if learnerText == "" {
		return contracts.AttemptReviewArtifact{Status: "failed", FailureCode: "empty_text"}
	}

	corrected := feedback.SampleAnswer
	if corrected == "" {
		corrected = learnerText
	}

	diffChunks := buildReadableDiffChunks(learnerText, corrected)

	return contracts.AttemptReviewArtifact{
		Status:                  "ready",
		SourceTranscriptText:    learnerText,
		CorrectedTranscriptText: corrected,
		ModelAnswerText:         feedback.SampleAnswer,
		DiffChunks:              diffChunks,
		RepairProvider:          "writing_scorer_v1",
		GeneratedAt:             time.Now().UTC().Format(time.RFC3339),
	}
}

// writingFallbackFeedback returns a minimal rule-based feedback when LLM is unavailable.
func writingFallbackFeedback() contracts.AttemptFeedback {
	return contracts.AttemptFeedback{
		ReadinessLevel: "ok",
		OverallSummary: "Bài viết đã được ghi nhận. Phản hồi chi tiết sẽ có khi AI sẵn sàng.",
		Strengths:      []string{"Bạn đã hoàn thành bài viết"},
		Improvements:   []string{"Hãy kiểm tra lại ngữ pháp và từ vựng"},
		TaskCompletion: contracts.TaskCompletion{ScoreBand: "ok"},
		GrammarFeedback: contracts.GrammarFeedback{ScoreBand: "ok"},
		RetryAdvice:    []string{"Thử lại với câu văn đầy đủ và rõ ràng hơn"},
	}
}
