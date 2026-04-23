package processing

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

const (
	llmReviewProviderDev    = "dev"
	llmReviewProviderClaude = "claude"
)

type LLMReviewProvider interface {
	GenerateReview(exercise contracts.Exercise, transcript contracts.Transcript, feedback contracts.AttemptFeedback, locale string) (LLMReviewResult, error)
}

type LLMReviewResult struct {
	CorrectedTranscript string
	ModelAnswer         string
}

type DevLLMReviewProvider struct{}

func (DevLLMReviewProvider) GenerateReview(_ contracts.Exercise, _ contracts.Transcript, _ contracts.AttemptFeedback, _ string) (LLMReviewResult, error) {
	return LLMReviewResult{}, fmt.Errorf("llm review disabled: dev provider")
}

func NewConfiguredLLMReviewProvider() (LLMReviewProvider, error) {
	provider := strings.ToLower(strings.TrimSpace(os.Getenv("LLM_REVIEW_PROVIDER")))
	if provider == "" {
		provider = strings.ToLower(strings.TrimSpace(os.Getenv("LLM_PROVIDER")))
	}
	switch provider {
	case "", llmReviewProviderDev:
		return DevLLMReviewProvider{}, nil
	case llmReviewProviderClaude:
		return NewClaudeLLMReviewProviderFromEnv()
	default:
		return nil, fmt.Errorf("unsupported LLM_REVIEW_PROVIDER %q", provider)
	}
}

type ClaudeLLMReviewProvider struct {
	apiKey string
	model  string
	client *http.Client
}

func NewClaudeLLMReviewProviderFromEnv() (*ClaudeLLMReviewProvider, error) {
	apiKey := strings.TrimSpace(os.Getenv("ANTHROPIC_API_KEY"))
	if apiKey == "" {
		return nil, fmt.Errorf("ANTHROPIC_API_KEY is required when LLM_REVIEW_PROVIDER=claude")
	}
	model := strings.TrimSpace(os.Getenv("LLM_REVIEW_MODEL"))
	if model == "" {
		model = strings.TrimSpace(os.Getenv("LLM_MODEL"))
	}
	if model == "" {
		model = defaultClaudeModel
	}
	return &ClaudeLLMReviewProvider{
		apiKey: apiKey,
		model:  model,
		client: &http.Client{Timeout: llmRequestTimeout},
	}, nil
}

type llmReviewJSON struct {
	CorrectedTranscript string `json:"corrected_transcript"`
	ModelAnswer         string `json:"model_answer"`
}

func (c *ClaudeLLMReviewProvider) GenerateReview(exercise contracts.Exercise, transcript contracts.Transcript, feedback contracts.AttemptFeedback, locale string) (LLMReviewResult, error) {
	systemPrompt := buildLLMReviewSystemPrompt()
	userPrompt := buildLLMReviewUserPrompt(exercise, transcript, feedback, locale)

	reqBody := claudeMessageRequest{
		Model:     c.model,
		MaxTokens: 768,
		System:    systemPrompt,
		Messages: []claudeMessage{
			{Role: "user", Content: userPrompt},
		},
	}
	payload, err := json.Marshal(reqBody)
	if err != nil {
		return LLMReviewResult{}, fmt.Errorf("marshal claude review request: %w", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), llmRequestTimeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, claudeAPIEndpoint, bytes.NewReader(payload))
	if err != nil {
		return LLMReviewResult{}, fmt.Errorf("build claude review request: %w", err)
	}
	req.Header.Set("content-type", "application/json")
	req.Header.Set("x-api-key", c.apiKey)
	req.Header.Set("anthropic-version", claudeAPIVersion)

	resp, err := c.client.Do(req)
	if err != nil {
		return LLMReviewResult{}, fmt.Errorf("call claude review: %w", err)
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return LLMReviewResult{}, fmt.Errorf("read claude review response: %w", err)
	}
	if resp.StatusCode >= 400 {
		return LLMReviewResult{}, fmt.Errorf("claude review api status %d: %s", resp.StatusCode, string(body))
	}

	var parsed claudeMessageResponse
	if err := json.Unmarshal(body, &parsed); err != nil {
		return LLMReviewResult{}, fmt.Errorf("unmarshal claude review response: %w", err)
	}
	if parsed.Error != nil {
		return LLMReviewResult{}, fmt.Errorf("claude review api error %s: %s", parsed.Error.Type, parsed.Error.Message)
	}
	if len(parsed.Content) == 0 || parsed.Content[0].Text == "" {
		return LLMReviewResult{}, fmt.Errorf("claude review response empty")
	}

	raw := extractJSONBlock(parsed.Content[0].Text)
	var rv llmReviewJSON
	if err := json.Unmarshal([]byte(raw), &rv); err != nil {
		return LLMReviewResult{}, fmt.Errorf("parse review json: %w; body=%s", err, raw)
	}

	corrected := strings.TrimSpace(rv.CorrectedTranscript)
	model := strings.TrimSpace(rv.ModelAnswer)
	if corrected == "" || model == "" {
		return LLMReviewResult{}, fmt.Errorf("review fields empty; body=%s", raw)
	}
	return LLMReviewResult{CorrectedTranscript: corrected, ModelAnswer: model}, nil
}

func buildLLMReviewSystemPrompt() string {
	return strings.Join([]string{
		"You are an expert Czech language coach for the \"trvaly pobyt A2\" oral exam.",
		"You produce TWO Czech texts for review of a learner's spoken answer:",
		"1. corrected_transcript: the learner's SAME content and intent, but grammatically correct A2 Czech. Keep the learner's chosen facts, names, places, and opinions. Fix case endings, verb conjugation, reflexive se/si, prepositions, word order, agreement, diacritics. Remove filler syllables the transcript picked up. Keep it at A2 level — do NOT upgrade to B1.",
		"2. model_answer: an exam-appropriate natural A2 Czech answer that DIRECTLY addresses the exercise prompt/topic/scenario. It may be longer and more complete than the learner's attempt. It should include concrete details a Vietnamese A2 learner could realistically say (short simple sentences, connectors like 'protože', 'ale', 'a', 'pak').",
		"The two texts MUST differ: corrected_transcript is a faithful repair of what the learner said; model_answer is a fresh exemplar for the same task.",
		"Both texts in natural Czech with proper diacritics. No English. No Vietnamese. No markdown. Return ONLY valid JSON.",
		"Output schema: {\"corrected_transcript\":\"...\",\"model_answer\":\"...\"}",
	}, "\n")
}

func buildLLMReviewUserPrompt(exercise contracts.Exercise, transcript contracts.Transcript, feedback contracts.AttemptFeedback, locale string) string {
	_ = locale
	var b strings.Builder
	fmt.Fprintf(&b, "Exercise type: %s\n", exercise.ExerciseType)
	if exercise.Title != "" {
		fmt.Fprintf(&b, "Exercise title: %s\n", exercise.Title)
	}
	if exercise.LearnerInstruction != "" {
		fmt.Fprintf(&b, "Learner instruction: %s\n", exercise.LearnerInstruction)
	}
	b.WriteString(describeExercisePrompt(exercise))
	b.WriteString("\n")
	fmt.Fprintf(&b, "Learner transcript (Czech, may contain errors): %q\n", strings.TrimSpace(transcript.FullText))
	if transcript.Confidence > 0 {
		fmt.Fprintf(&b, "Transcript confidence: %.2f\n", transcript.Confidence)
	}
	if transcript.IsSynthetic {
		b.WriteString("Note: transcript was synthesized for testing.\n")
	}
	if feedback.OverallSummary != "" {
		fmt.Fprintf(&b, "Coach summary of attempt: %s\n", feedback.OverallSummary)
	}
	if len(feedback.Improvements) > 0 {
		b.WriteString("Issues already identified:\n")
		for _, s := range feedback.Improvements {
			fmt.Fprintf(&b, "- %s\n", s)
		}
	}
	b.WriteString("\nReturn the JSON only. Both fields must be non-empty A2 Czech.")
	return b.String()
}
