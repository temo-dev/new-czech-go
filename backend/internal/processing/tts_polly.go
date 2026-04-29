package processing

import (
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/polly"
	pollytypes "github.com/aws/aws-sdk-go-v2/service/polly/types"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

type amazonPollyAPI interface {
	SynthesizeSpeech(ctx context.Context, params *polly.SynthesizeSpeechInput, optFns ...func(*polly.Options)) (*polly.SynthesizeSpeechOutput, error)
}

type AmazonPollyTTSProvider struct {
	client     amazonPollyAPI
	voiceID    string
	engine     pollytypes.Engine
	outputFmt  pollytypes.OutputFormat
	sampleRate string
}

func NewAmazonPollyTTSProviderFromEnv() (TTSProvider, error) {
	region := strings.TrimSpace(os.Getenv("AWS_REGION"))
	if region == "" {
		return nil, fmt.Errorf("AWS_REGION is required when TTS_PROVIDER=amazon_polly")
	}
	cfg, err := config.LoadDefaultConfig(context.Background(), config.WithRegion(region))
	if err != nil {
		return nil, fmt.Errorf("load AWS config for polly: %w", err)
	}
	return &AmazonPollyTTSProvider{
		client:     polly.NewFromConfig(cfg),
		voiceID:    envOrDefault("POLLY_VOICE_ID", "Jitka"),
		engine:     pollytypes.EngineNeural,
		outputFmt:  pollytypes.OutputFormatMp3,
		sampleRate: envOrDefault("POLLY_SAMPLE_RATE", "22050"),
	}, nil
}

// NewAmazonPollyTTSProviderWithVoice creates a Polly provider with an explicit voiceID.
// Used for the second voice in dialog generation.
// POLLY_VOICE_ID_2 env var overrides the voiceID parameter.
// Returns nil when AWS_REGION is unset.
// Uses Standard engine because Tomáš (Czech male) does not support Neural.
func NewAmazonPollyTTSProviderWithVoice(voiceID string) TTSProvider {
	override := strings.TrimSpace(os.Getenv("POLLY_VOICE_ID_2"))
	if override != "" {
		voiceID = override
	}
	if voiceID == "" {
		return nil
	}
	region := strings.TrimSpace(os.Getenv("AWS_REGION"))
	if region == "" {
		return nil
	}
	cfg, err := config.LoadDefaultConfig(context.Background(), config.WithRegion(region))
	if err != nil {
		return nil
	}
	return &AmazonPollyTTSProvider{
		client:    polly.NewFromConfig(cfg),
		voiceID:   voiceID,
		engine:    pollytypes.EngineStandard, // Tomáš (cs-CZ male) only supports Standard
		outputFmt: pollytypes.OutputFormatMp3,
		// Standard engine requires 8000 or 16000 Hz; use 16000 for better quality.
		sampleRate: envOrDefault("POLLY_SAMPLE_RATE_2", "16000"),
	}
}

func (p *AmazonPollyTTSProvider) Generate(attemptID, text string) (*contracts.ReviewArtifactAudio, error) {
	normalized := strings.TrimSpace(text)
	if normalized == "" {
		return nil, fmt.Errorf("tts text is required")
	}

	output, err := p.client.SynthesizeSpeech(context.Background(), &polly.SynthesizeSpeechInput{
		Engine:       p.engine,
		OutputFormat: p.outputFmt,
		SampleRate:   aws.String(p.sampleRate),
		Text:         aws.String(normalized),
		TextType:     pollytypes.TextTypeText,
		VoiceId:      pollytypes.VoiceId(p.voiceID),
	})
	if err != nil {
		return nil, fmt.Errorf("synthesize speech: %w", err)
	}
	defer output.AudioStream.Close()

	audioBytes, err := io.ReadAll(output.AudioStream)
	if err != nil {
		return nil, fmt.Errorf("read polly audio stream: %w", err)
	}

	storageKey := fmt.Sprintf("attempt-review/%s/model-answer.mp3", attemptID)
	filePath := localReviewAudioPath(storageKey)
	if err := os.MkdirAll(filepath.Dir(filePath), 0o755); err != nil {
		return nil, fmt.Errorf("prepare local polly storage: %w", err)
	}
	if err := os.WriteFile(filePath, audioBytes, 0o644); err != nil {
		return nil, fmt.Errorf("write polly audio: %w", err)
	}

	return &contracts.ReviewArtifactAudio{
		StorageKey: storageKey,
		MimeType:   "audio/mpeg",
	}, nil
}
