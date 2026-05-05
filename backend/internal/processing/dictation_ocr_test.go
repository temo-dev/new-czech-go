package processing

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestDictationOCRSystemPrompt_HasJSONShapeRule(t *testing.T) {
	p := DictationOCRSystemPrompt()
	for _, want := range []string{"Czech", "JSON", "text", "empty"} {
		if !strings.Contains(p, want) {
			t.Errorf("system prompt missing %q; got: %s", want, p)
		}
	}
}

func TestBuildDictationOCRUserPrompt_ContainsInstructions(t *testing.T) {
	got := buildDictationOCRUserPrompt()
	if strings.TrimSpace(got) == "" {
		t.Errorf("user prompt empty")
	}
	if !strings.Contains(strings.ToLower(got), "image") && !strings.Contains(strings.ToLower(got), "photo") {
		t.Errorf("user prompt should reference the image: %s", got)
	}
}

func TestNoopOCR_ReturnsEmpty(t *testing.T) {
	var p OCRProvider = NoopOCR{}
	got, err := p.OCRImage(context.Background(), "image/jpeg", []byte{0xff, 0xd8, 0xff})
	if err != nil {
		t.Fatalf("noop should never error: %v", err)
	}
	if got != "" {
		t.Errorf("noop should return empty string, got %q", got)
	}
}

func TestClaudeVisionOCR_HappyPath(t *testing.T) {
	mock := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if got := r.Header.Get("x-api-key"); got != "test-key" {
			t.Errorf("missing api key, got %q", got)
		}
		// Verify image content block was sent (base64 of test bytes "OK!").
		raw, _ := readAll(r.Body)
		if !strings.Contains(string(raw), `"type":"image"`) {
			t.Errorf("request missing image content block: %s", string(raw))
		}
		if !strings.Contains(string(raw), "image/jpeg") {
			t.Errorf("request missing media_type=image/jpeg: %s", string(raw))
		}
		body := dictationClaudeResponse{
			Content: []claudeContentBlock{{
				Text: `{"text": "Včera jsem byl v kavárně."}`,
			}},
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(body)
	}))
	defer mock.Close()

	p := &ClaudeVisionOCR{
		apiKey:   "test-key",
		model:    "claude-test",
		client:   mock.Client(),
		endpoint: mock.URL,
	}
	got, err := p.OCRImage(context.Background(), "image/jpeg", []byte("OK!"))
	if err != nil {
		t.Fatalf("OCRImage: %v", err)
	}
	if got != "Včera jsem byl v kavárně." {
		t.Errorf("text: %q", got)
	}
}

func TestClaudeVisionOCR_FailSoftOn4xx(t *testing.T) {
	mock := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte(`{"error":{"type":"invalid_request","message":"bad image"}}`))
	}))
	defer mock.Close()

	p := &ClaudeVisionOCR{
		apiKey:   "test-key",
		model:    "claude-test",
		client:   mock.Client(),
		endpoint: mock.URL,
	}
	got, err := p.OCRImage(context.Background(), "image/jpeg", []byte("x"))
	if err != nil {
		t.Errorf("OCR must fail-soft (return empty + nil error), got err=%v", err)
	}
	if got != "" {
		t.Errorf("OCR fail must return empty text, got %q", got)
	}
}

func TestClaudeVisionOCR_FailSoftOnMalformedJSON(t *testing.T) {
	mock := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		body := dictationClaudeResponse{
			Content: []claudeContentBlock{{Text: "not-json-at-all"}},
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(body)
	}))
	defer mock.Close()

	p := &ClaudeVisionOCR{
		apiKey:   "test-key",
		model:    "claude-test",
		client:   mock.Client(),
		endpoint: mock.URL,
	}
	got, err := p.OCRImage(context.Background(), "image/jpeg", []byte("x"))
	if err != nil {
		t.Errorf("malformed body must fail-soft, got err=%v", err)
	}
	if got != "" {
		t.Errorf("expected empty text on malformed JSON, got %q", got)
	}
}

func TestLLMModels_LoadsOCRModel(t *testing.T) {
	t.Setenv("LLM_OCR_MODEL", "")
	models := LoadLLMModels()
	if models.OCR == "" {
		t.Errorf("OCR model default missing")
	}
	t.Setenv("LLM_OCR_MODEL", "custom-vision-model")
	if got := LoadLLMModels().OCR; got != "custom-vision-model" {
		t.Errorf("env override ignored: got %q", got)
	}
}

func TestNewConfiguredOCRProvider_DefaultsToNoop(t *testing.T) {
	t.Setenv("LLM_PROVIDER", "")
	t.Setenv("LLM_OCR_PROVIDER", "")
	p, err := NewConfiguredOCRProvider()
	if err != nil {
		t.Fatalf("err: %v", err)
	}
	got, err := p.OCRImage(context.Background(), "image/jpeg", []byte("x"))
	if err != nil || got != "" {
		t.Errorf("default provider must be Noop: got=%q err=%v", got, err)
	}
}

func TestNewConfiguredOCRProvider_ClaudeNeedsAPIKey(t *testing.T) {
	t.Setenv("LLM_OCR_PROVIDER", "claude")
	t.Setenv("ANTHROPIC_API_KEY", "")
	if _, err := NewConfiguredOCRProvider(); err == nil {
		t.Errorf("expected error when claude OCR provider selected without API key")
	}
}

// readAll mirrors io.ReadAll without importing "io" twice in tests.
func readAll(r interface {
	Read(p []byte) (int, error)
}) ([]byte, error) {
	buf := make([]byte, 0, 512)
	tmp := make([]byte, 512)
	for {
		n, err := r.Read(tmp)
		if n > 0 {
			buf = append(buf, tmp[:n]...)
		}
		if err != nil {
			if err.Error() == "EOF" {
				return buf, nil
			}
			return buf, err
		}
	}
}

var _ OCRProvider = (*ClaudeVisionOCR)(nil)
var _ OCRProvider = NoopOCR{}
