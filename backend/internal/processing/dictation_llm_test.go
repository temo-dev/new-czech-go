package processing

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

func TestDictationSystemPrompt_HasRequiredFields(t *testing.T) {
	prompt := DictationSystemPrompt()
	for _, want := range []string{
		"error_tags",
		"feedback_vi",
		"feedback_en",
		"diff_chunks",
		"missing_diacritic",
	} {
		if !strings.Contains(prompt, want) {
			t.Errorf("system prompt missing %q; got: %s", want, prompt)
		}
	}
	if strings.Contains(strings.ToLower(prompt), "score") && !strings.Contains(strings.ToLower(prompt), "do not") && !strings.Contains(strings.ToLower(prompt), "don't") {
		// LLM must not score; deterministic scoring is already computed.
		t.Errorf("system prompt should explicitly forbid scoring: %s", prompt)
	}
}

func TestBuildDictationUserPrompt_IncludesSentencePairs(t *testing.T) {
	inputs := []DictationLLMInput{
		{Idx: 0, Reference: "Pavel jde do kavárny.", Learner: "Pavel jde do kavarny.", DistanceWeighted: 0.5},
		{Idx: 1, Reference: "Děkuji.", Learner: "Dekuji.", DistanceWeighted: 0.5},
	}
	got := buildDictationUserPrompt(inputs)
	for _, want := range []string{
		"Pavel jde do kavárny.",
		"Pavel jde do kavarny.",
		"Děkuji.",
	} {
		if !strings.Contains(got, want) {
			t.Errorf("user prompt missing %q; got: %s", want, got)
		}
	}
}

func TestDictationFallbackFeedback_HasNonEmptyVI(t *testing.T) {
	got := dictationFallbackFeedback(0, 0.5)
	if strings.TrimSpace(got) == "" {
		t.Errorf("fallback feedback empty")
	}
}

func TestNewConfiguredDictationFeedbackProvider_DefaultsToDev(t *testing.T) {
	t.Setenv("LLM_PROVIDER", "")
	t.Setenv("LLM_DICTATION_PROVIDER", "")
	p, err := NewConfiguredDictationFeedbackProvider()
	if err != nil {
		t.Fatalf("err: %v", err)
	}
	annots, err := p.Annotate(nil)
	if err != nil {
		t.Fatalf("dev provider should not error, got: %v", err)
	}
	if len(annots) != 0 {
		t.Errorf("dev provider should return zero annotations for nil input, got %d", len(annots))
	}
}

func TestNewConfiguredDictationFeedbackProvider_ClaudeNeedsAPIKey(t *testing.T) {
	t.Setenv("LLM_DICTATION_PROVIDER", "claude")
	t.Setenv("ANTHROPIC_API_KEY", "")
	if _, err := NewConfiguredDictationFeedbackProvider(); err == nil {
		t.Errorf("expected error when claude provider selected without API key")
	}
}

func TestClaudeDictationFeedbackProvider_AnnotatesViaHTTPMock(t *testing.T) {
	mock := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if got := r.Header.Get("x-api-key"); got != "test-key" {
			t.Errorf("missing api key, got %q", got)
		}
		body := dictationClaudeResponse{
			Content: []claudeContentBlock{{
				Text: `[
  {"idx": 0, "error_tags": ["missing_diacritic"], "feedback_vi": "Bạn quên dấu", "feedback_en": "Missing diacritic", "diff_chunks": [{"kind":"replaced","source_text":"kavárny","target_text":"kavarny"}]}
]`,
			}},
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(body)
	}))
	defer mock.Close()

	p := &ClaudeDictationFeedbackProvider{
		apiKey:   "test-key",
		model:    "claude-test",
		client:   mock.Client(),
		endpoint: mock.URL,
	}

	inputs := []DictationLLMInput{{
		Idx: 0, Reference: "Pavel jde do kavárny.", Learner: "Pavel jde do kavarny.", DistanceWeighted: 0.5,
	}}

	annots, err := p.Annotate(inputs)
	if err != nil {
		t.Fatalf("annotate: %v", err)
	}
	if len(annots) != 1 {
		t.Fatalf("annotation count: %d", len(annots))
	}
	got := annots[0]
	if got.Idx != 0 {
		t.Errorf("idx: %d", got.Idx)
	}
	if len(got.ErrorTags) != 1 || got.ErrorTags[0] != "missing_diacritic" {
		t.Errorf("error_tags: %+v", got.ErrorTags)
	}
	if got.FeedbackVI == "" || got.FeedbackEN == "" {
		t.Errorf("feedback fields empty: %+v", got)
	}
	if len(got.DiffChunks) != 1 || got.DiffChunks[0].Kind != "replaced" {
		t.Errorf("diff_chunks: %+v", got.DiffChunks)
	}
}

func TestClaudeDictationFeedbackProvider_HandlesAPIErrorCleanly(t *testing.T) {
	mock := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
		_, _ = w.Write([]byte(`{"error":{"type":"server_error","message":"down"}}`))
	}))
	defer mock.Close()

	p := &ClaudeDictationFeedbackProvider{
		apiKey:   "test-key",
		model:    "claude-test",
		client:   mock.Client(),
		endpoint: mock.URL,
	}
	if _, err := p.Annotate([]DictationLLMInput{{Idx: 0, Reference: "x", Learner: "y"}}); err == nil {
		t.Errorf("expected error on 500")
	}
}

// Compile-time assert: provider satisfies interface and produces shape compatible
// with contracts.DictationSentenceScore annotations.
var _ DictationFeedbackProvider = (*ClaudeDictationFeedbackProvider)(nil)
var _ DictationFeedbackProvider = DevDictationFeedbackProvider{}
var _ = contracts.DictationSentenceScore{}
