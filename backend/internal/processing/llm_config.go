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
	// Claude (Anthropic) — text feedback + content generation
	DefaultFeedbackModel     = "claude-haiku-4-5-20251001" // real-time, per-attempt
	DefaultContentModel      = "claude-haiku-4-5-20251001" // batch, admin-triggered
	DefaultReadingDraftModel = "claude-haiku-4-5-20251001" // V24 reading draft generator
	DefaultOCRModel          = "claude-opus-4-7"           // V18.1 dictation handwriting OCR (vision)

	// Replicate (Flux) — admin AI image generation
	DefaultReplicateImageModel = "black-forest-labs/flux-schnell"

	// ElevenLabs — TTS for review artifacts and dialog audio
	DefaultElevenLabsTTSModel     = "eleven_multilingual_v2"
	DefaultElevenLabsOutputFormat = "mp3_22050_32" // matches Polly default sample rate
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
//	LLM_MODEL                 speaking/writing feedback  (default: DefaultFeedbackModel)
//	LLM_REVIEW_MODEL          review artifact generation (default: LLM_MODEL → DefaultFeedbackModel)
//	LLM_CONTENT_MODEL         vocab/grammar generation   (default: DefaultContentModel)
//	LLM_READING_DRAFT_MODEL   V24 reading draft generator (default: DefaultReadingDraftModel)
//	REPLICATE_IMAGE_MODEL     admin AI image generation  (default: DefaultReplicateImageModel)
//	ELEVENLABS_MODEL_ID       TTS model for ElevenLabs   (default: DefaultElevenLabsTTSModel)
//	ELEVENLABS_OUTPUT_FORMAT  TTS output format          (default: DefaultElevenLabsOutputFormat)
type LLMModels struct {
	Feedback            string // ClaudeLLMFeedbackProvider
	Review              string // ClaudeLLMReviewProvider
	Dictation           string // ClaudeDictationFeedbackProvider (V18)
	OCR                 string // ClaudeVisionOCR (V18.1)
	Content             string // ClaudeContentGenerator
	ReadingDraft        string // ClaudeReadingDraftGenerator (V24)
	ReplicateImage      string // Replicate Flux (admin AI image)
	ElevenLabsTTS       string // ElevenLabsTTSProvider
	ElevenLabsOutputFmt string // ElevenLabs TTS output format
}

// LoadLLMModels resolves model IDs from environment variables with fallback defaults.
// Call once on server startup; the result is passed to each provider constructor.
func LoadLLMModels() LLMModels {
	return LLMModels{
		Feedback:            env("LLM_MODEL", DefaultFeedbackModel),
		Review:              env("LLM_REVIEW_MODEL", env("LLM_MODEL", DefaultFeedbackModel)),
		Dictation:           env("LLM_DICTATION_MODEL", env("LLM_MODEL", DefaultFeedbackModel)),
		OCR:                 env("LLM_OCR_MODEL", DefaultOCRModel),
		Content:             env("LLM_CONTENT_MODEL", DefaultContentModel),
		ReadingDraft:        env("LLM_READING_DRAFT_MODEL", DefaultReadingDraftModel),
		ReplicateImage:      env("REPLICATE_IMAGE_MODEL", DefaultReplicateImageModel),
		ElevenLabsTTS:       env("ELEVENLABS_MODEL_ID", DefaultElevenLabsTTSModel),
		ElevenLabsOutputFmt: env("ELEVENLABS_OUTPUT_FORMAT", DefaultElevenLabsOutputFormat),
	}
}

func env(key, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return fallback
}
