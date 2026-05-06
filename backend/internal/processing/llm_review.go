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
	return &ClaudeLLMReviewProvider{
		apiKey: apiKey,
		model:  LoadLLMModels().Review,
		client: &http.Client{Timeout: llmRequestTimeout},
	}, nil
}

type llmReviewJSON struct {
	CorrectedTranscript string `json:"corrected_transcript"`
	ModelAnswer         string `json:"model_answer"`
}

func (c *ClaudeLLMReviewProvider) GenerateReview(exercise contracts.Exercise, transcript contracts.Transcript, feedback contracts.AttemptFeedback, locale string) (LLMReviewResult, error) {
	systemPrompt := ReviewSystemPrompt()
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

// ReviewSystemPrompt + buildLLMReviewUserPrompt live in llm_prompts.go and
// llm_user_prompts.go respectively.
