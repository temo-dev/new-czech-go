package processing

// dictation_ocr.go — V18.1 OCR provider for psani_3_dictation handwriting submissions.
//
// Reads a single handwritten Czech sentence photo via Claude Vision (multimodal
// Anthropic Messages API) and returns the recognized text. Failure is fail-soft:
// any HTTP/parse/decode error returns ("", nil) so the learner sees an empty
// TextField and can either retake the photo or type the text manually. This
// guarantees the calling endpoint never returns 5xx because of OCR issues.

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
)

// OCRProvider reads a single image and returns the text contained in it.
// Implementations MUST not panic and MUST be safe for concurrent use.
// On unrecoverable error implementations SHOULD return ("", nil) so the
// HTTP caller can fall back to an empty preview rather than 5xx-ing the
// learner.
type OCRProvider interface {
	OCRImage(ctx context.Context, mime string, body []byte) (string, error)
}

// NoopOCR returns empty string for any input. Used in dev/local environments
// where ANTHROPIC_API_KEY is not configured. The learner sees an empty
// TextField and types manually.
type NoopOCR struct{}

func (NoopOCR) OCRImage(_ context.Context, _ string, _ []byte) (string, error) {
	return "", nil
}

// NewConfiguredOCRProvider picks an OCR provider based on LLM_OCR_PROVIDER
// (falling back to LLM_PROVIDER):
//   - empty / "dev"     → NoopOCR (safe default; empty text returned)
//   - "claude"          → ClaudeVisionOCR (requires ANTHROPIC_API_KEY)
//   - anything else     → error
func NewConfiguredOCRProvider() (OCRProvider, error) {
	provider := strings.ToLower(strings.TrimSpace(os.Getenv("LLM_OCR_PROVIDER")))
	if provider == "" {
		provider = strings.ToLower(strings.TrimSpace(os.Getenv("LLM_PROVIDER")))
	}
	switch provider {
	case "", "dev":
		return NoopOCR{}, nil
	case "claude":
		return NewClaudeVisionOCRFromEnv()
	default:
		return nil, fmt.Errorf("unsupported LLM_OCR_PROVIDER %q", provider)
	}
}

// ClaudeVisionOCR calls the Anthropic Messages API with an image content
// block. `endpoint` is exposed for testing; production code uses claudeAPIEndpoint.
type ClaudeVisionOCR struct {
	apiKey   string
	model    string
	client   *http.Client
	endpoint string
}

func NewClaudeVisionOCRFromEnv() (*ClaudeVisionOCR, error) {
	apiKey := strings.TrimSpace(os.Getenv("ANTHROPIC_API_KEY"))
	if apiKey == "" {
		return nil, fmt.Errorf("ANTHROPIC_API_KEY is required when LLM_OCR_PROVIDER=claude")
	}
	return &ClaudeVisionOCR{
		apiKey:   apiKey,
		model:    LoadLLMModels().OCR,
		client:   &http.Client{Timeout: llmRequestTimeout},
		endpoint: claudeAPIEndpoint,
	}, nil
}

// claudeVisionContentBlock is the request-side content shape for Anthropic
// vision: text blocks and image blocks. Unlike claudeMessage's plain string
// Content (text-only), vision requires structured content.
type claudeVisionContentBlock struct {
	Type   string                  `json:"type"`
	Text   string                  `json:"text,omitempty"`
	Source *claudeVisionImageBlock `json:"source,omitempty"`
}

type claudeVisionImageBlock struct {
	Type      string `json:"type"`       // "base64"
	MediaType string `json:"media_type"` // "image/jpeg" | "image/png" | "image/heic"
	Data      string `json:"data"`       // base64-encoded body
}

type claudeVisionMessage struct {
	Role    string                     `json:"role"`
	Content []claudeVisionContentBlock `json:"content"`
}

type claudeVisionRequest struct {
	Model     string                `json:"model"`
	MaxTokens int                   `json:"max_tokens"`
	System    string                `json:"system"`
	Messages  []claudeVisionMessage `json:"messages"`
}

type claudeVisionTextResponse struct {
	Text string `json:"text"`
}

// OCRImage sends the image to Claude Vision and returns the recognized text.
// Any error path (HTTP failure, malformed JSON, missing text field) is logged
// and converted to ("", nil) so the caller can render an empty preview.
func (c *ClaudeVisionOCR) OCRImage(ctx context.Context, mime string, body []byte) (string, error) {
	if len(body) == 0 {
		return "", nil
	}
	if mime == "" {
		mime = "image/jpeg"
	}

	encoded := base64.StdEncoding.EncodeToString(body)
	reqBody := claudeVisionRequest{
		Model:     c.model,
		MaxTokens: 512,
		System:    DictationOCRSystemPrompt(),
		Messages: []claudeVisionMessage{{
			Role: "user",
			Content: []claudeVisionContentBlock{
				{
					Type: "image",
					Source: &claudeVisionImageBlock{
						Type:      "base64",
						MediaType: mime,
						Data:      encoded,
					},
				},
				{Type: "text", Text: buildDictationOCRUserPrompt()},
			},
		}},
	}
	payload, err := json.Marshal(reqBody)
	if err != nil {
		log.Printf("[v18.1] ocr marshal failed: %v", err)
		return "", nil
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.endpoint, bytes.NewReader(payload))
	if err != nil {
		log.Printf("[v18.1] ocr build request failed: %v", err)
		return "", nil
	}
	req.Header.Set("content-type", "application/json")
	req.Header.Set("x-api-key", c.apiKey)
	req.Header.Set("anthropic-version", claudeAPIVersion)

	resp, err := c.client.Do(req)
	if err != nil {
		log.Printf("[v18.1] ocr api call failed: %v", err)
		return "", nil
	}
	defer resp.Body.Close()
	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		log.Printf("[v18.1] ocr read response failed: %v", err)
		return "", nil
	}
	if resp.StatusCode >= 400 {
		log.Printf("[v18.1] ocr api status %d: %s", resp.StatusCode, truncate(string(respBody), 200))
		return "", nil
	}

	var parsed dictationClaudeResponse
	if err := json.Unmarshal(respBody, &parsed); err != nil {
		log.Printf("[v18.1] ocr unmarshal envelope failed: %v", err)
		return "", nil
	}
	if parsed.Error != nil {
		log.Printf("[v18.1] ocr api error %s: %s", parsed.Error.Type, parsed.Error.Message)
		return "", nil
	}
	if len(parsed.Content) == 0 || strings.TrimSpace(parsed.Content[0].Text) == "" {
		return "", nil
	}

	raw := extractJSONObjectBlock(parsed.Content[0].Text)
	var out claudeVisionTextResponse
	if err := json.Unmarshal([]byte(raw), &out); err != nil {
		log.Printf("[v18.1] ocr parse text payload failed: %v; body=%s", err, truncate(raw, 200))
		return "", nil
	}
	return strings.TrimSpace(out.Text), nil
}

// extractJSONObjectBlock isolates the outermost JSON object from a model
// response, stripping markdown fences. Mirrors extractJSONArrayBlock for objects.
func extractJSONObjectBlock(text string) string {
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

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "…"
}
