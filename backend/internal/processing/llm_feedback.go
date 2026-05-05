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
	llmProviderDev    = "dev"
	llmProviderClaude = "claude"
	// API/timeout constants and model defaults are in llm_config.go.
	// Prompt templates are in llm_prompts.go.
)

type LLMFeedbackProvider interface {
	GenerateFeedback(exercise contracts.Exercise, transcript contracts.Transcript, reliability transcriptReliability, locale string) (contracts.AttemptFeedback, error)
	GenerateInterviewFeedback(turns []contracts.InterviewTranscriptTurn, exerciseType, topic string, durationSec int, locale string) (contracts.AttemptFeedback, error)
}

type DevLLMFeedbackProvider struct{}

func (DevLLMFeedbackProvider) GenerateFeedback(_ contracts.Exercise, _ contracts.Transcript, _ transcriptReliability, _ string) (contracts.AttemptFeedback, error) {
	return contracts.AttemptFeedback{}, fmt.Errorf("llm feedback disabled: dev provider")
}

func (DevLLMFeedbackProvider) GenerateInterviewFeedback(_ []contracts.InterviewTranscriptTurn, _, _ string, _ int, _ string) (contracts.AttemptFeedback, error) {
	return contracts.AttemptFeedback{}, fmt.Errorf("llm feedback disabled: dev provider")
}

func ConfiguredLLMFeedbackProvider() string {
	provider := strings.ToLower(strings.TrimSpace(os.Getenv("LLM_PROVIDER")))
	if provider == "" {
		return llmProviderDev
	}
	return provider
}

func NewConfiguredLLMFeedbackProvider() (LLMFeedbackProvider, error) {
	switch ConfiguredLLMFeedbackProvider() {
	case "", llmProviderDev:
		return DevLLMFeedbackProvider{}, nil
	case llmProviderClaude:
		return NewClaudeLLMFeedbackProviderFromEnv()
	default:
		return nil, fmt.Errorf("unsupported LLM_PROVIDER %q", os.Getenv("LLM_PROVIDER"))
	}
}

type ClaudeLLMFeedbackProvider struct {
	apiKey string
	model  string
	client *http.Client
}

func NewClaudeLLMFeedbackProviderFromEnv() (*ClaudeLLMFeedbackProvider, error) {
	apiKey := strings.TrimSpace(os.Getenv("ANTHROPIC_API_KEY"))
	if apiKey == "" {
		return nil, fmt.Errorf("ANTHROPIC_API_KEY is required when LLM_PROVIDER=claude")
	}
	return &ClaudeLLMFeedbackProvider{
		apiKey: apiKey,
		model:  LoadLLMModels().Feedback,
		client: &http.Client{Timeout: llmRequestTimeout},
	}, nil
}

type claudeMessageRequest struct {
	Model     string          `json:"model"`
	MaxTokens int             `json:"max_tokens"`
	System    string          `json:"system"`
	Messages  []claudeMessage `json:"messages"`
}

type claudeMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type claudeMessageResponse struct {
	Content []struct {
		Type string `json:"type"`
		Text string `json:"text"`
	} `json:"content"`
	Error *struct {
		Type    string `json:"type"`
		Message string `json:"message"`
	} `json:"error,omitempty"`
}

type llmFeedbackJSON struct {
	ReadinessLevel string   `json:"readiness_level"`
	OverallSummary string   `json:"overall_summary"`
	Strengths      []string `json:"strengths"`
	Improvements   []string `json:"improvements"`
	RetryAdvice    []string `json:"retry_advice"`
	SampleAnswer   string   `json:"sample_answer"`
}

// callClaude sends a system+user prompt to Claude and parses the JSON feedback response.
func (c *ClaudeLLMFeedbackProvider) callClaude(systemPrompt, userPrompt string) (llmFeedbackJSON, error) {
	reqBody := claudeMessageRequest{
		Model:     c.model,
		MaxTokens: 2048,
		System:    systemPrompt,
		Messages:  []claudeMessage{{Role: "user", Content: userPrompt}},
	}
	payload, err := json.Marshal(reqBody)
	if err != nil {
		return llmFeedbackJSON{}, fmt.Errorf("marshal claude request: %w", err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), llmRequestTimeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, claudeAPIEndpoint, bytes.NewReader(payload))
	if err != nil {
		return llmFeedbackJSON{}, fmt.Errorf("build claude request: %w", err)
	}
	req.Header.Set("content-type", "application/json")
	req.Header.Set("x-api-key", c.apiKey)
	req.Header.Set("anthropic-version", claudeAPIVersion)
	resp, err := c.client.Do(req)
	if err != nil {
		return llmFeedbackJSON{}, fmt.Errorf("call claude: %w", err)
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return llmFeedbackJSON{}, fmt.Errorf("read claude response: %w", err)
	}
	if resp.StatusCode >= 400 {
		return llmFeedbackJSON{}, fmt.Errorf("claude api status %d: %s", resp.StatusCode, string(body))
	}
	var parsed claudeMessageResponse
	if err := json.Unmarshal(body, &parsed); err != nil {
		return llmFeedbackJSON{}, fmt.Errorf("unmarshal claude response: %w", err)
	}
	if parsed.Error != nil {
		return llmFeedbackJSON{}, fmt.Errorf("claude api error %s: %s", parsed.Error.Type, parsed.Error.Message)
	}
	if len(parsed.Content) == 0 || parsed.Content[0].Text == "" {
		return llmFeedbackJSON{}, fmt.Errorf("claude response empty")
	}
	raw := extractJSONBlock(parsed.Content[0].Text)
	var fb llmFeedbackJSON
	if err := json.Unmarshal([]byte(raw), &fb); err != nil {
		return llmFeedbackJSON{}, fmt.Errorf("parse feedback json: %w; body=%s", err, raw)
	}
	return fb, nil
}

func (c *ClaudeLLMFeedbackProvider) GenerateFeedback(exercise contracts.Exercise, transcript contracts.Transcript, reliability transcriptReliability, locale string) (contracts.AttemptFeedback, error) {
	fb, err := c.callClaude(FeedbackSystemPrompt(locale), buildLLMUserPrompt(exercise, transcript, reliability, locale))
	if err != nil {
		return contracts.AttemptFeedback{}, err
	}
	return contracts.AttemptFeedback{
		ReadinessLevel: normalizeReadinessLevel(fb.ReadinessLevel),
		OverallSummary: strings.TrimSpace(fb.OverallSummary),
		Strengths:      sanitizeStringList(fb.Strengths),
		Improvements:   sanitizeStringList(fb.Improvements),
		RetryAdvice:    sanitizeStringList(fb.RetryAdvice),
		SampleAnswer:   strings.TrimSpace(fb.SampleAnswer),
	}, nil
}

func (c *ClaudeLLMFeedbackProvider) GenerateInterviewFeedback(turns []contracts.InterviewTranscriptTurn, exerciseType, topic string, durationSec int, locale string) (contracts.AttemptFeedback, error) {
	internal := make([]interviewTurn, len(turns))
	for i, t := range turns {
		internal[i] = interviewTurn{Speaker: t.Speaker, Text: t.Text, AtSec: t.AtSec}
	}
	fb, err := c.callClaude(InterviewSystemPrompt(locale), buildInterviewUserPrompt(exerciseType, topic, internal, durationSec))
	if err != nil {
		return contracts.AttemptFeedback{}, err
	}
	return contracts.AttemptFeedback{
		ReadinessLevel: normalizeReadinessLevel(fb.ReadinessLevel),
		OverallSummary: strings.TrimSpace(fb.OverallSummary),
		Strengths:      sanitizeStringList(fb.Strengths),
		Improvements:   sanitizeStringList(fb.Improvements),
		RetryAdvice:    sanitizeStringList(fb.RetryAdvice),
		SampleAnswer:   strings.TrimSpace(fb.SampleAnswer),
	}, nil
}


func normalizeReadinessLevel(raw string) string {
	v := strings.ToLower(strings.TrimSpace(raw))
	switch v {
	case "not_ready", "almost_ready", "ready_for_mock", "exam_ready":
		return v
	default:
		return "almost_ready"
	}
}

func sanitizeStringList(in []string) []string {
	out := make([]string, 0, len(in))
	for _, s := range in {
		s = strings.TrimSpace(s)
		if s == "" {
			continue
		}
		out = append(out, s)
	}
	return out
}

func extractJSONBlock(text string) string {
	trimmed := strings.TrimSpace(text)
	trimmed = strings.TrimPrefix(trimmed, "```json")
	trimmed = strings.TrimPrefix(trimmed, "```")
	trimmed = strings.TrimSuffix(trimmed, "```")
	trimmed = strings.TrimSpace(trimmed)
	start := strings.Index(trimmed, "{")
	end := strings.LastIndex(trimmed, "}")
	if start >= 0 && end > start {
		return trimmed[start : end+1]
	}
	return trimmed
}
