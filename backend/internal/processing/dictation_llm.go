package processing

// dictation_llm.go — V18 LLM annotator for psani_3_dictation attempts.
//
// The deterministic Levenshtein scorer (dictation_scorer.go) computes the
// score on its own. This provider runs in parallel and only adds friendly
// per-sentence annotations (error_tags, feedback_vi/en, diff_chunks).
// LLM failure is fail-soft: callers fall back to dictationFallbackFeedback.

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
)

// claudeContentBlock mirrors the JSON shape of one item inside the
// Anthropic Messages API response `content` array. Defined locally for the
// dictation provider so test code can construct mock responses cleanly
// without depending on anonymous-struct shapes elsewhere.
type claudeContentBlock struct {
	Type string `json:"type"`
	Text string `json:"text"`
}

// dictationClaudeResponse is a local response decoder for the dictation
// provider. It matches the Anthropic shape but uses the named
// claudeContentBlock so tests can build fixtures without copying the
// anonymous-struct definition from llm_feedback.go.
type dictationClaudeResponse struct {
	Content []claudeContentBlock `json:"content"`
	Error   *struct {
		Type    string `json:"type"`
		Message string `json:"message"`
	} `json:"error,omitempty"`
}

// DictationFeedbackProvider returns per-sentence LLM annotations.
// Implementations MUST not panic; they should return (nil, err) on failure
// so the caller can fall back to the deterministic-only path.
type DictationFeedbackProvider interface {
	Annotate(inputs []DictationLLMInput) ([]DictationLLMAnnotation, error)
}

// DevDictationFeedbackProvider returns no annotations and no error. Used in
// dev/local environments where the LLM is not configured. The result screen
// renders deterministic-only diffs instead.
type DevDictationFeedbackProvider struct{}

func (DevDictationFeedbackProvider) Annotate(_ []DictationLLMInput) ([]DictationLLMAnnotation, error) {
	return nil, nil
}

// NewConfiguredDictationFeedbackProvider picks a provider based on
// LLM_DICTATION_PROVIDER (falling back to LLM_PROVIDER):
//   - empty / "dev"     → DevDictationFeedbackProvider
//   - "claude"          → ClaudeDictationFeedbackProvider (requires ANTHROPIC_API_KEY)
//   - anything else     → error
func NewConfiguredDictationFeedbackProvider() (DictationFeedbackProvider, error) {
	provider := strings.ToLower(strings.TrimSpace(os.Getenv("LLM_DICTATION_PROVIDER")))
	if provider == "" {
		provider = strings.ToLower(strings.TrimSpace(os.Getenv("LLM_PROVIDER")))
	}
	switch provider {
	case "", "dev":
		return DevDictationFeedbackProvider{}, nil
	case "claude":
		return NewClaudeDictationFeedbackProviderFromEnv()
	default:
		return nil, fmt.Errorf("unsupported LLM_DICTATION_PROVIDER %q", provider)
	}
}

// ClaudeDictationFeedbackProvider calls the Anthropic Messages API.
// `endpoint` is exposed for testing; production code uses claudeAPIEndpoint.
type ClaudeDictationFeedbackProvider struct {
	apiKey   string
	model    string
	client   *http.Client
	endpoint string
}

func NewClaudeDictationFeedbackProviderFromEnv() (*ClaudeDictationFeedbackProvider, error) {
	apiKey := strings.TrimSpace(os.Getenv("ANTHROPIC_API_KEY"))
	if apiKey == "" {
		return nil, fmt.Errorf("ANTHROPIC_API_KEY is required when LLM_DICTATION_PROVIDER=claude")
	}
	return &ClaudeDictationFeedbackProvider{
		apiKey:   apiKey,
		model:    LoadLLMModels().Dictation,
		client:   &http.Client{Timeout: llmRequestTimeout},
		endpoint: claudeAPIEndpoint,
	}, nil
}

func (c *ClaudeDictationFeedbackProvider) Annotate(inputs []DictationLLMInput) ([]DictationLLMAnnotation, error) {
	if len(inputs) == 0 {
		return nil, nil
	}

	systemPrompt := DictationSystemPrompt()
	userPrompt := buildDictationUserPrompt(inputs)

	reqBody := claudeMessageRequest{
		Model:     c.model,
		MaxTokens: 1024,
		System:    systemPrompt,
		Messages: []claudeMessage{
			{Role: "user", Content: userPrompt},
		},
	}
	payload, err := json.Marshal(reqBody)
	if err != nil {
		return nil, fmt.Errorf("marshal dictation request: %w", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), llmRequestTimeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.endpoint, bytes.NewReader(payload))
	if err != nil {
		return nil, fmt.Errorf("build dictation request: %w", err)
	}
	req.Header.Set("content-type", "application/json")
	req.Header.Set("x-api-key", c.apiKey)
	req.Header.Set("anthropic-version", claudeAPIVersion)

	resp, err := c.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("call dictation api: %w", err)
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read dictation response: %w", err)
	}
	if resp.StatusCode >= 400 {
		return nil, fmt.Errorf("dictation api status %d: %s", resp.StatusCode, string(body))
	}

	var parsed dictationClaudeResponse
	if err := json.Unmarshal(body, &parsed); err != nil {
		return nil, fmt.Errorf("unmarshal dictation response: %w", err)
	}
	if parsed.Error != nil {
		return nil, fmt.Errorf("dictation api error %s: %s", parsed.Error.Type, parsed.Error.Message)
	}
	if len(parsed.Content) == 0 || parsed.Content[0].Text == "" {
		return nil, fmt.Errorf("dictation response empty")
	}

	raw := extractJSONArrayBlock(parsed.Content[0].Text)
	var annotations []DictationLLMAnnotation
	if err := json.Unmarshal([]byte(raw), &annotations); err != nil {
		return nil, fmt.Errorf("parse dictation annotations: %w; body=%s", err, raw)
	}
	return annotations, nil
}

// extractJSONArrayBlock strips markdown fences and isolates the outermost
// JSON array. Returns the input trimmed if no array brackets are found.
func extractJSONArrayBlock(text string) string {
	trimmed := strings.TrimSpace(text)
	trimmed = strings.TrimPrefix(trimmed, "```json")
	trimmed = strings.TrimPrefix(trimmed, "```")
	trimmed = strings.TrimSuffix(trimmed, "```")
	trimmed = strings.TrimSpace(trimmed)
	start := strings.Index(trimmed, "[")
	end := strings.LastIndex(trimmed, "]")
	if start >= 0 && end > start {
		return trimmed[start : end+1]
	}
	return trimmed
}
