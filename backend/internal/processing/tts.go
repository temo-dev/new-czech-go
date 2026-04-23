package processing

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"strings"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

const (
	ttsProviderDev         = "dev"
	ttsProviderAmazonPolly = "amazon_polly"
)

type TTSProvider interface {
	Generate(attemptID, text string) (*contracts.ReviewArtifactAudio, error)
}

type DevTTSProvider struct{}

func ConfiguredTTSProvider() string {
	provider := strings.ToLower(strings.TrimSpace(os.Getenv("TTS_PROVIDER")))
	if provider == "" {
		return ttsProviderDev
	}
	return provider
}

func NewConfiguredTTSProvider() (TTSProvider, error) {
	switch ConfiguredTTSProvider() {
	case "", ttsProviderDev:
		return DevTTSProvider{}, nil
	case ttsProviderAmazonPolly:
		return NewAmazonPollyTTSProviderFromEnv()
	default:
		return nil, fmt.Errorf("unsupported TTS_PROVIDER %q", os.Getenv("TTS_PROVIDER"))
	}
}

func (DevTTSProvider) Generate(attemptID, text string) (*contracts.ReviewArtifactAudio, error) {
	normalized := strings.TrimSpace(text)
	if normalized == "" {
		return nil, fmt.Errorf("tts text is required")
	}

	storageKey := fmt.Sprintf("attempt-review/%s/model-answer.wav", attemptID)
	filePath := localReviewAudioPath(storageKey)
	if err := os.MkdirAll(filepath.Dir(filePath), 0o755); err != nil {
		return nil, fmt.Errorf("prepare local tts storage: %w", err)
	}

	audioBytes := synthesizeDebugWAV(normalized)
	if err := os.WriteFile(filePath, audioBytes, 0o644); err != nil {
		return nil, fmt.Errorf("write local tts audio: %w", err)
	}

	return &contracts.ReviewArtifactAudio{
		StorageKey: storageKey,
		MimeType:   "audio/wav",
	}, nil
}

func localReviewAudioPath(storageKey string) string {
	trimmed := strings.TrimPrefix(strings.TrimSpace(storageKey), "/")
	return filepath.Join(os.TempDir(), "czech-go-system", trimmed)
}

func ReviewAudioLocalPath(storageKey string) string {
	return localReviewAudioPath(storageKey)
}

func synthesizeDebugWAV(text string) []byte {
	const (
		sampleRate    = 16000
		amplitude     = 12000
		baseFreq      = 440.0
		wordDuration  = 0.16
		pauseDuration = 0.04
	)

	wordCount := len(strings.Fields(text))
	if wordCount == 0 {
		wordCount = 1
	}
	totalSamples := int(float64(sampleRate) * (float64(wordCount)*wordDuration + float64(wordCount-1)*pauseDuration))
	if totalSamples < sampleRate/4 {
		totalSamples = sampleRate / 4
	}

	data := make([]int16, 0, totalSamples)
	words := strings.Fields(text)
	for i := range words {
		freq := baseFreq + float64((i%5)*45)
		toneSamples := int(wordDuration * sampleRate)
		for n := 0; n < toneSamples; n++ {
			sample := int16(amplitude * math.Sin(2*math.Pi*freq*float64(n)/sampleRate))
			data = append(data, sample)
		}
		if i < len(words)-1 {
			pauseSamples := int(pauseDuration * sampleRate)
			for n := 0; n < pauseSamples; n++ {
				data = append(data, 0)
			}
		}
	}

	var body bytes.Buffer
	for _, sample := range data {
		_ = binary.Write(&body, binary.LittleEndian, sample)
	}

	byteRate := sampleRate * 2
	blockAlign := 2
	subchunk2Size := body.Len()
	chunkSize := 36 + subchunk2Size

	var wav bytes.Buffer
	wav.WriteString("RIFF")
	_ = binary.Write(&wav, binary.LittleEndian, uint32(chunkSize))
	wav.WriteString("WAVE")
	wav.WriteString("fmt ")
	_ = binary.Write(&wav, binary.LittleEndian, uint32(16))
	_ = binary.Write(&wav, binary.LittleEndian, uint16(1))
	_ = binary.Write(&wav, binary.LittleEndian, uint16(1))
	_ = binary.Write(&wav, binary.LittleEndian, uint32(sampleRate))
	_ = binary.Write(&wav, binary.LittleEndian, uint32(byteRate))
	_ = binary.Write(&wav, binary.LittleEndian, uint16(blockAlign))
	_ = binary.Write(&wav, binary.LittleEndian, uint16(16))
	wav.WriteString("data")
	_ = binary.Write(&wav, binary.LittleEndian, uint32(subchunk2Size))
	wav.Write(body.Bytes())

	return wav.Bytes()
}
