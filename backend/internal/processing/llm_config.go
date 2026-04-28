package processing

import (
	"os"
	"strings"
	"time"
)

// ── Anthropic API ─────────────────────────────────────────────────────────────

const (
	claudeAPIEndpoint = "https://api.anthropic.com/v1/messages"
	claudeAPIVersion  = "2023-06-01"
)

// ── Default models ─────────────────────────────────────────────────────────────
//
// Override at runtime via environment variables (see LoadLLMModels).
//
// Feedback/Review use a fast, cheap model since they run per-attempt in real time.
// Content generation uses a more capable model since it runs in batch (admin-triggered).
const (
	DefaultFeedbackModel = "claude-haiku-4-5-20251001" // real-time, per-attempt
	DefaultContentModel  = "claude-haiku-4-5-20251001" // batch, admin-triggered
)

// ── Request timeouts ──────────────────────────────────────────────────────────

const (
	// llmRequestTimeout covers real-time feedback + review calls.
	// Keep short — learner is waiting for results.
	llmRequestTimeout = 30 * time.Second

	// contentGenerationTimeout covers batch exercise generation (20–40 items).
	// Must exceed the HTTP client timeout in ClaudeContentGenerator.
	contentGenerationTimeout = 180 * time.Second
)

// ── LLMModels holds resolved model IDs ────────────────────────────────────────
//
// Environment variables (all optional — defaults apply if unset):
//
//	LLM_MODEL          speaking/writing feedback  (default: DefaultFeedbackModel)
//	LLM_REVIEW_MODEL   review artifact generation (default: LLM_MODEL → DefaultFeedbackModel)
//	LLM_CONTENT_MODEL  vocab/grammar generation   (default: DefaultContentModel)
type LLMModels struct {
	Feedback string // ClaudeLLMFeedbackProvider
	Review   string // ClaudeLLMReviewProvider
	Content  string // ClaudeContentGenerator
}

// LoadLLMModels resolves model IDs from environment variables with fallback defaults.
// Call once on server startup; the result is passed to each provider constructor.
func LoadLLMModels() LLMModels {
	feedbackModel := env("LLM_MODEL", DefaultFeedbackModel)
	reviewModel := env("LLM_REVIEW_MODEL", env("LLM_MODEL", DefaultFeedbackModel))
	contentModel := env("LLM_CONTENT_MODEL", DefaultContentModel)
	return LLMModels{
		Feedback: feedbackModel,
		Review:   reviewModel,
		Content:  contentModel,
	}
}

func env(key, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return fallback
}
