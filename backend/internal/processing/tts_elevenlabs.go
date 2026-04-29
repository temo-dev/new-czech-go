package processing

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

const elevenLabsBaseURL = "https://api.elevenlabs.io/v1"

type ElevenLabsTTSProvider struct {
	apiKey  string
	voiceID string
	modelID string
	client  *http.Client
}

// NewElevenLabsTTSProviderFromEnv creates a provider from ELEVENLABS_API_KEY + ELEVENLABS_VOICE_ID.
func NewElevenLabsTTSProviderFromEnv() (TTSProvider, error) {
	apiKey := strings.TrimSpace(os.Getenv("ELEVENLABS_API_KEY"))
	if apiKey == "" {
		return nil, fmt.Errorf("ELEVENLABS_API_KEY required for TTS_PROVIDER=elevenlabs")
	}
	voiceID := strings.TrimSpace(os.Getenv("ELEVENLABS_VOICE_ID"))
	if voiceID == "" {
		return nil, fmt.Errorf("ELEVENLABS_VOICE_ID required for TTS_PROVIDER=elevenlabs")
	}
	return newElevenLabsProvider(apiKey, voiceID), nil
}

// NewElevenLabsVoiceBProvider creates a provider for the second dialog voice using
// ELEVENLABS_API_KEY + ELEVENLABS_VOICE_ID_B. Returns nil when either is unset.
func NewElevenLabsVoiceBProvider() TTSProvider {
	apiKey := strings.TrimSpace(os.Getenv("ELEVENLABS_API_KEY"))
	voiceID := strings.TrimSpace(os.Getenv("ELEVENLABS_VOICE_ID_B"))
	if apiKey == "" || voiceID == "" {
		return nil
	}
	return newElevenLabsProvider(apiKey, voiceID)
}

func newElevenLabsProvider(apiKey, voiceID string) *ElevenLabsTTSProvider {
	modelID := strings.TrimSpace(os.Getenv("ELEVENLABS_MODEL_ID"))
	if modelID == "" {
		modelID = "eleven_multilingual_v2"
	}
	return &ElevenLabsTTSProvider{
		apiKey:  apiKey,
		voiceID: voiceID,
		modelID: modelID,
		client:  &http.Client{},
	}
}

func (p *ElevenLabsTTSProvider) Generate(attemptID, text string) (*contracts.ReviewArtifactAudio, error) {
	normalized := strings.TrimSpace(text)
	if normalized == "" {
		return nil, fmt.Errorf("tts text is required")
	}

	reqBody, err := json.Marshal(map[string]any{
		"text":     normalized,
		"model_id": p.modelID,
	})
	if err != nil {
		return nil, fmt.Errorf("elevenlabs marshal: %w", err)
	}

	// output_format=mp3_22050_32 matches Amazon Polly's default 22050 Hz sample rate
	// so concatenated dialog audio plays correctly without sample-rate mismatch.
	outputFmt := strings.TrimSpace(os.Getenv("ELEVENLABS_OUTPUT_FORMAT"))
	if outputFmt == "" {
		outputFmt = "mp3_22050_32"
	}
	url := fmt.Sprintf("%s/text-to-speech/%s?output_format=%s", elevenLabsBaseURL, p.voiceID, outputFmt)
	req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(reqBody))
	if err != nil {
		return nil, fmt.Errorf("elevenlabs new request: %w", err)
	}
	req.Header.Set("xi-api-key", p.apiKey)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "audio/mpeg")

	resp, err := p.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("elevenlabs request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		errBody, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
		return nil, fmt.Errorf("elevenlabs status %d: %s", resp.StatusCode, errBody)
	}

	audioBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("elevenlabs read audio: %w", err)
	}

	storageKey := fmt.Sprintf("attempt-review/%s/model-answer.mp3", attemptID)
	filePath := localReviewAudioPath(storageKey)
	if err := os.MkdirAll(filepath.Dir(filePath), 0o755); err != nil {
		return nil, fmt.Errorf("prepare elevenlabs storage: %w", err)
	}
	if err := os.WriteFile(filePath, audioBytes, 0o644); err != nil {
		return nil, fmt.Errorf("write elevenlabs audio: %w", err)
	}

	return &contracts.ReviewArtifactAudio{
		StorageKey: storageKey,
		MimeType:   "audio/mpeg",
	}, nil
}
