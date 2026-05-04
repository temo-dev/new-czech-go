package processing

import (
	"encoding/json"
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)


// interviewTurn is an internal type mirroring InterviewTranscriptTurn for scoring.
type interviewTurn struct {
	Speaker string
	Text    string
	AtSec   int
}

// injectSelectedOption replaces all occurrences of {selected_option} in prompt
// with the given value. If value is empty, the prompt is returned unchanged.
func injectSelectedOption(prompt, selectedOption string) string {
	if selectedOption == "" {
		return prompt
	}
	return strings.ReplaceAll(prompt, "{selected_option}", selectedOption)
}

// buildInterviewTranscriptText formats interview turns into a plain-text
// transcript suitable for the LLM scoring prompt.
func buildInterviewTranscriptText(turns []interviewTurn) string {
	if len(turns) == 0 {
		return ""
	}
	var sb strings.Builder
	for _, t := range turns {
		label := "Examiner"
		if t.Speaker == "learner" {
			label = "Learner"
		}
		sb.WriteString(fmt.Sprintf("%s: %s\n", label, t.Text))
	}
	return strings.TrimRight(sb.String(), "\n")
}

// interviewSystemPrompt returns the system prompt for interview scoring.
// readiness_level values match normalizeReadinessLevel: not_ready/almost_ready/ready_for_mock/exam_ready.
func interviewSystemPrompt(locale string) string {
	lang := "Vietnamese"
	if locale == contracts.LocaleEN {
		lang = "English"
	}
	return fmt.Sprintf(
		"You are an expert Czech A2 language coach evaluating a practice interview session for the Czech \"trvaly pobyt A2\" oral exam. "+
			"You will receive a multi-turn conversation transcript between a Czech examiner and a learner. "+
			"Evaluate the LEARNER's responses ONLY — ignore examiner turns. "+
			"Assess: vocabulary range (A2-appropriate words), grammar accuracy (case endings, verb conjugation, tense), conversational fluency (natural responses, cohesion). "+
			"CRITICAL LANGUAGE RULE: overall_summary, strengths, improvements, retry_advice MUST be written entirely in %s. "+
			"Only sample_answer may contain Czech. "+
			"Address the learner directly (you/your / bạn/của bạn). "+
			"readiness_level MUST be one of: not_ready, almost_ready, ready_for_mock, exam_ready. "+
			"strengths, improvements, retry_advice: arrays of 1-3 concise %s strings (one idea per string, under 200 characters each). "+
			"overall_summary: one concise paragraph under 400 characters. "+
			"sample_answer: one or two natural Czech sentences demonstrating a better version of a key learner response. "+
			`Return ONLY valid JSON. Output schema: {"readiness_level":"...","overall_summary":"...","strengths":["..."],"improvements":["..."],"retry_advice":["..."],"sample_answer":"..."}`,
		lang, lang,
	)
}

// buildInterviewUserPrompt constructs the user prompt for interview scoring.
func buildInterviewUserPrompt(exerciseType, topic string, turns []interviewTurn, durationSec int) string {
	transcriptText := buildInterviewTranscriptText(turns)
	topicLine := ""
	if topic != "" {
		topicLine = fmt.Sprintf("Topic: %s\n", topic)
	}
	return fmt.Sprintf(
		"Exercise type: %s\n%sDuration: %d seconds\n\nTranscript:\n%s",
		exerciseType, topicLine, durationSec, transcriptText,
	)
}

// interviewFallbackFeedback returns minimal rule-based feedback when LLM is unavailable.
func interviewFallbackFeedback() contracts.AttemptFeedback {
	return contracts.AttemptFeedback{
		ReadinessLevel: "ok",
		OverallSummary: "Phiên phỏng vấn đã được ghi nhận. Phản hồi chi tiết sẽ có khi AI sẵn sàng.",
		Strengths:      []string{"Bạn đã hoàn thành buổi luyện tập"},
		Improvements:   []string{"Hãy luyện thêm câu trả lời đầy đủ và chi tiết"},
		RetryAdvice:    []string{"Thử lại với câu văn hoàn chỉnh hơn"},
		TaskCompletion: contracts.TaskCompletion{ScoreBand: "ok"},
		GrammarFeedback: contracts.GrammarFeedback{ScoreBand: "ok"},
	}
}

// ProcessInterviewAttempt scores a completed interview session using LLM feedback.
// turns is passed directly from the submit handler (not read from store) so no
// extra storage field is needed on Attempt.
func (p *Processor) ProcessInterviewAttempt(attemptID string, turns []contracts.InterviewTranscriptTurn, durationSec int) {
	defer func() {
		if r := recover(); r != nil {
			log.Printf("interview attempt %s: panic recovered: %v", attemptID, r)
			p.repo.FailAttempt(attemptID, "scoring_failed")
		}
	}()

	attempt, ok := p.repo.Attempt(attemptID)
	if !ok {
		log.Printf("interview attempt %s not found", attemptID)
		return
	}
	exercise, ok := p.repo.Exercise(attempt.ExerciseID)
	if !ok {
		log.Printf("interview attempt %s: exercise %s not found", attemptID, attempt.ExerciseID)
		p.repo.FailAttempt(attemptID, "scoring_failed")
		return
	}

	locale := attempt.Locale
	if locale == "" {
		locale = "vi"
	}

	internal := make([]interviewTurn, len(turns))
	for i, t := range turns {
		internal[i] = interviewTurn{Speaker: t.Speaker, Text: t.Text, AtSec: t.AtSec}
	}

	transcriptText := buildInterviewTranscriptText(internal)
	if transcriptText == "" {
		transcriptText = "(no transcript recorded)"
	}

	transcript := contracts.Transcript{
		FullText:    transcriptText,
		Locale:      "cs",
		Confidence:  1.0,
		Provider:    "interview_session",
		IsSynthetic: true,
	}

	topic := interviewTopicFromExercise(exercise)
	var feedback contracts.AttemptFeedback
	if p.llmProvider != nil && len(turns) > 0 {
		fb, err := p.llmProvider.GenerateInterviewFeedback(turns, exercise.ExerciseType, topic, durationSec, locale)
		if err != nil {
			log.Printf("interview attempt %s: LLM feedback failed, using fallback: %v", attemptID, err)
			feedback = interviewFallbackFeedback()
		} else {
			feedback = fb
		}
	} else {
		feedback = interviewFallbackFeedback()
	}

	p.repo.CompleteAttempt(attemptID, transcript, feedback)
	log.Printf("interview attempt %s completed (readiness=%s, turns=%d)", attemptID, feedback.ReadinessLevel, len(turns))
}

// interviewTopicFromExercise extracts the topic/question from exercise detail for scoring context.
func interviewTopicFromExercise(exercise contracts.Exercise) string {
	if exercise.Detail == nil {
		return ""
	}
	raw, err := json.Marshal(exercise.Detail)
	if err != nil {
		return ""
	}
	var d struct {
		Topic    string `json:"topic"`
		Question string `json:"question"`
	}
	if err := json.Unmarshal(raw, &d); err != nil {
		return ""
	}
	if d.Topic != "" {
		return d.Topic
	}
	return d.Question
}

// BuildInterviewLLMPrompt constructs the user message for the LLM scoring prompt.
// Exported for testing and potential override from llm_prompts.go.
func BuildInterviewLLMPrompt(exerciseType, topic string, turns []interviewTurn, durationSec int) string {
	return buildInterviewUserPrompt(exerciseType, topic, turns, durationSec)
}

// InterviewTokenSystemPromptInjected returns the system_prompt with {selected_option}
// replaced server-side. This is the string sent to ElevenLabs when creating a session.
// Exported so the handler can use it directly without importing internal helpers.
func InterviewTokenSystemPromptInjected(systemPrompt, selectedOption string) string {
	return injectSelectedOption(systemPrompt, selectedOption)
}

// FormatInterviewTranscriptForStorage converts contracts.InterviewTranscriptTurn
// slice to JSON bytes suitable for storage in attempt.TranscriptJSON.
func FormatInterviewTranscriptForStorage(turns []contracts.InterviewTranscriptTurn) (string, error) {
	internal := make([]interviewTurn, len(turns))
	for i, t := range turns {
		internal[i] = interviewTurn{Speaker: t.Speaker, Text: t.Text, AtSec: t.AtSec}
	}
	b, err := json.Marshal(internal)
	if err != nil {
		return "", fmt.Errorf("marshal interview transcript: %w", err)
	}
	return string(b), nil
}

// interviewReviewArtifact builds a minimal review artifact for an interview session.
// Unlike speaking/writing, there is no corrected_transcript — just the raw conversation.
func buildInterviewReviewArtifact(turns []interviewTurn) contracts.AttemptReviewArtifact {
	text := buildInterviewTranscriptText(turns)
	if text == "" {
		return contracts.AttemptReviewArtifact{Status: "failed", FailureCode: "no_transcript"}
	}
	return contracts.AttemptReviewArtifact{
		Status:               "ready",
		SourceTranscriptText: text,
		RepairProvider:       "interview_scorer_v1",
		GeneratedAt:          time.Now().UTC().Format(time.RFC3339),
	}
}
