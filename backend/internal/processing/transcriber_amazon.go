package processing

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path"
	"strconv"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/transcribe"
	transcribetypes "github.com/aws/aws-sdk-go-v2/service/transcribe/types"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

type amazonTranscribeAPI interface {
	StartTranscriptionJob(ctx context.Context, params *transcribe.StartTranscriptionJobInput, optFns ...func(*transcribe.Options)) (*transcribe.StartTranscriptionJobOutput, error)
	GetTranscriptionJob(ctx context.Context, params *transcribe.GetTranscriptionJobInput, optFns ...func(*transcribe.Options)) (*transcribe.GetTranscriptionJobOutput, error)
}

type s3GetObjectAPI interface {
	GetObject(ctx context.Context, params *s3.GetObjectInput, optFns ...func(*s3.Options)) (*s3.GetObjectOutput, error)
}

type AmazonTranscriber struct {
	client       amazonTranscribeAPI
	s3Client     s3GetObjectAPI
	httpClient   *http.Client
	audioBucket  string
	outputBucket string
	outputPrefix string
	languageCode string
	pollInterval time.Duration
	timeout      time.Duration
}

func NewConfiguredTranscriber(ctx context.Context) (Transcriber, error) {
	provider := ConfiguredTranscriberProvider()
	if provider == "dev" && realTranscriptRequired() {
		return nil, fmt.Errorf("REQUIRE_REAL_TRANSCRIPT=true but TRANSCRIBER_PROVIDER resolved to dev")
	}

	switch provider {
	case "", "dev":
		return DevTranscriber{}, nil
	case "amazon_transcribe":
		return NewAmazonTranscriberFromEnv(ctx)
	default:
		return nil, fmt.Errorf("unsupported TRANSCRIBER_PROVIDER %q", os.Getenv("TRANSCRIBER_PROVIDER"))
	}
}

func ConfiguredTranscriberProvider() string {
	provider := strings.ToLower(strings.TrimSpace(os.Getenv("TRANSCRIBER_PROVIDER")))
	if provider == "" {
		return "dev"
	}
	return provider
}

func realTranscriptRequired() bool {
	value := strings.ToLower(strings.TrimSpace(os.Getenv("REQUIRE_REAL_TRANSCRIPT")))
	return value == "1" || value == "true" || value == "yes"
}

func NewAmazonTranscriberFromEnv(ctx context.Context) (Transcriber, error) {
	region := strings.TrimSpace(os.Getenv("AWS_REGION"))
	if region == "" {
		return nil, fmt.Errorf("AWS_REGION is required when TRANSCRIBER_PROVIDER=amazon_transcribe")
	}

	audioBucket := strings.TrimSpace(os.Getenv("ATTEMPT_AUDIO_S3_BUCKET"))
	if audioBucket == "" {
		return nil, fmt.Errorf("ATTEMPT_AUDIO_S3_BUCKET is required when TRANSCRIBER_PROVIDER=amazon_transcribe")
	}

	cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(region))
	if err != nil {
		return nil, fmt.Errorf("load AWS config: %w", err)
	}

	return &AmazonTranscriber{
		client:       transcribe.NewFromConfig(cfg),
		s3Client:     s3.NewFromConfig(cfg),
		httpClient:   &http.Client{Timeout: 30 * time.Second},
		audioBucket:  audioBucket,
		outputBucket: strings.TrimSpace(os.Getenv("TRANSCRIBE_OUTPUT_BUCKET")),
		outputPrefix: strings.TrimSpace(os.Getenv("TRANSCRIBE_OUTPUT_PREFIX")),
		languageCode: envOrDefault("TRANSCRIBE_LANGUAGE_CODE", "cs-CZ"),
		pollInterval: envDuration("TRANSCRIBE_POLL_INTERVAL", 2*time.Second),
		timeout:      envDuration("TRANSCRIBE_TIMEOUT", 90*time.Second),
	}, nil
}

func (t *AmazonTranscriber) Transcribe(_ contracts.Exercise, audio contracts.AttemptAudio) (contracts.Transcript, transcriptReliability, bool, error) {
	mediaURI, err := t.mediaURI(audio)
	if err != nil {
		return contracts.Transcript{}, reliabilityUnusable, false, err
	}

	ctx, cancel := context.WithTimeout(context.Background(), t.timeout)
	defer cancel()

	jobName := "attempt-" + randomSuffix()
	input := t.buildStartTranscriptionJobInput(jobName, mediaURI, audio)

	if _, err := t.client.StartTranscriptionJob(ctx, input); err != nil {
		return contracts.Transcript{}, reliabilityUnusable, false, fmt.Errorf("start transcription job: %w", err)
	}

	jobName = aws.ToString(input.TranscriptionJobName)
	ticker := time.NewTicker(t.pollInterval)
	defer ticker.Stop()

	for {
		jobOutput, err := t.client.GetTranscriptionJob(ctx, &transcribe.GetTranscriptionJobInput{
			TranscriptionJobName: aws.String(jobName),
		})
		if err != nil {
			return contracts.Transcript{}, reliabilityUnusable, false, fmt.Errorf("get transcription job: %w", err)
		}

		status := jobOutput.TranscriptionJob.TranscriptionJobStatus
		switch status {
		case transcribetypes.TranscriptionJobStatusCompleted:
			uri := t.transcriptResultURI(jobName, aws.ToString(jobOutput.TranscriptionJob.Transcript.TranscriptFileUri))
			return t.fetchTranscript(ctx, uri, audio)
		case transcribetypes.TranscriptionJobStatusFailed:
			reason := aws.ToString(jobOutput.TranscriptionJob.FailureReason)
			return contracts.Transcript{}, reliabilityUnusable, false, fmt.Errorf("transcription job failed: %s", reason)
		}

		select {
		case <-ctx.Done():
			return contracts.Transcript{}, reliabilityUnusable, false, fmt.Errorf("transcription timeout: %w", ctx.Err())
		case <-ticker.C:
		}
	}
}

func (t *AmazonTranscriber) mediaURI(audio contracts.AttemptAudio) (string, error) {
	key := strings.TrimSpace(audio.StorageKey)
	if key == "" {
		return "", fmt.Errorf("audio storage key is required")
	}
	if strings.HasPrefix(key, "s3://") {
		return key, nil
	}
	return fmt.Sprintf("s3://%s/%s", t.audioBucket, strings.TrimPrefix(key, "/")), nil
}

func (t *AmazonTranscriber) fetchTranscript(ctx context.Context, uri string, audio contracts.AttemptAudio) (contracts.Transcript, transcriptReliability, bool, error) {
	if uri == "" {
		return contracts.Transcript{}, reliabilityUnusable, false, fmt.Errorf("empty transcript URI")
	}

	if strings.HasPrefix(uri, "s3://") {
		return t.fetchTranscriptFromS3(ctx, uri, audio)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, uri, nil)
	if err != nil {
		return contracts.Transcript{}, reliabilityUnusable, false, fmt.Errorf("build transcript request: %w", err)
	}

	response, err := t.httpClient.Do(req)
	if err != nil {
		return contracts.Transcript{}, reliabilityUnusable, false, fmt.Errorf("download transcript: %w", err)
	}
	defer response.Body.Close()

	if response.StatusCode >= 400 {
		return contracts.Transcript{}, reliabilityUnusable, false, fmt.Errorf("download transcript failed with status %d", response.StatusCode)
	}

	body, err := io.ReadAll(response.Body)
	if err != nil {
		return contracts.Transcript{}, reliabilityUnusable, false, fmt.Errorf("read transcript body: %w", err)
	}

	return t.parseTranscriptPayload(body, audio)
}

func (t *AmazonTranscriber) buildStartTranscriptionJobInput(jobName, mediaURI string, audio contracts.AttemptAudio) *transcribe.StartTranscriptionJobInput {
	input := &transcribe.StartTranscriptionJobInput{
		LanguageCode:         transcribetypes.LanguageCode(t.languageCode),
		Media:                &transcribetypes.Media{MediaFileUri: aws.String(mediaURI)},
		TranscriptionJobName: aws.String(jobName),
	}
	if mediaFormat := mediaFormatForMime(audio.MimeType); mediaFormat != "" {
		input.MediaFormat = transcribetypes.MediaFormat(mediaFormat)
	}
	if t.outputBucket != "" {
		input.OutputBucketName = aws.String(t.outputBucket)
		if outputKey := transcriptOutputKey(t.outputPrefix, jobName); outputKey != "" {
			input.OutputKey = aws.String(outputKey)
		}
	}
	return input
}

func (t *AmazonTranscriber) transcriptResultURI(jobName, transcriptURI string) string {
	if bucket := strings.TrimSpace(t.outputBucket); bucket != "" {
		if outputKey := transcriptOutputKey(t.outputPrefix, jobName); outputKey != "" {
			return fmt.Sprintf("s3://%s/%s", bucket, outputKey)
		}
	}
	return strings.TrimSpace(transcriptURI)
}

func (t *AmazonTranscriber) fetchTranscriptFromS3(ctx context.Context, uri string, audio contracts.AttemptAudio) (contracts.Transcript, transcriptReliability, bool, error) {
	if t.s3Client == nil {
		return contracts.Transcript{}, reliabilityUnusable, false, fmt.Errorf("s3 client is not configured")
	}

	bucket, key, err := parseS3URI(uri)
	if err != nil {
		return contracts.Transcript{}, reliabilityUnusable, false, err
	}

	response, err := t.s3Client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		return contracts.Transcript{}, reliabilityUnusable, false, fmt.Errorf("download transcript from s3: %w", err)
	}
	defer response.Body.Close()

	body, err := io.ReadAll(response.Body)
	if err != nil {
		return contracts.Transcript{}, reliabilityUnusable, false, fmt.Errorf("read transcript body: %w", err)
	}

	return t.parseTranscriptPayload(body, audio)
}

func (t *AmazonTranscriber) parseTranscriptPayload(body []byte, audio contracts.AttemptAudio) (contracts.Transcript, transcriptReliability, bool, error) {
	var payload struct {
		Results struct {
			Transcripts []struct {
				Transcript string `json:"transcript"`
			} `json:"transcripts"`
			Items []struct {
				Type         string `json:"type"`
				Alternatives []struct {
					Confidence string `json:"confidence"`
				} `json:"alternatives"`
			} `json:"items"`
		} `json:"results"`
	}
	if err := json.Unmarshal(body, &payload); err != nil {
		return contracts.Transcript{}, reliabilityUnusable, false, fmt.Errorf("parse transcript body: %w", err)
	}

	text := ""
	if len(payload.Results.Transcripts) > 0 {
		text = normalizeTranscript(payload.Results.Transcripts[0].Transcript)
	}

	confidence := averageConfidence(payload.Results.Items)
	reliability := reliabilityFromTranscript(text, confidence, audio.DurationMs)
	if text == "" || reliability == reliabilityUnusable {
		return contracts.Transcript{}, reliability, false, nil
	}

	return contracts.Transcript{
		FullText:    text,
		Locale:      t.languageCode,
		Confidence:  confidence,
		Provider:    transcriptProviderAmazonTranscribe,
		IsSynthetic: false,
	}, reliability, true, nil
}

func averageConfidence(items []struct {
	Type         string `json:"type"`
	Alternatives []struct {
		Confidence string `json:"confidence"`
	} `json:"alternatives"`
}) float64 {
	var total float64
	var count int

	for _, item := range items {
		if item.Type != "pronunciation" || len(item.Alternatives) == 0 {
			continue
		}
		confidence, err := strconv.ParseFloat(item.Alternatives[0].Confidence, 64)
		if err != nil {
			continue
		}
		total += confidence
		count++
	}

	if count == 0 {
		return 0
	}
	return total / float64(count)
}

func reliabilityFromTranscript(text string, confidence float64, durationMs int) transcriptReliability {
	if normalizeTranscript(text) == "" || wordCount(text) < 2 {
		return reliabilityUnusable
	}
	if confidence > 0 && confidence < 0.7 {
		return reliabilityUsableWithWarnings
	}
	if durationMs >= 8000 && wordCount(text) < 4 {
		return reliabilityUsableWithWarnings
	}
	return reliabilityUsable
}

func mediaFormatForMime(mimeType string) string {
	switch strings.TrimSpace(strings.ToLower(mimeType)) {
	case "audio/m4a", "audio/mp4a-latm", "audio/x-m4a":
		return "m4a"
	case "audio/mpeg":
		return "mp3"
	case "audio/mp4":
		return "mp4"
	case "audio/wav", "audio/x-wav", "audio/wave", "audio/vnd.wave":
		return "wav"
	case "audio/flac":
		return "flac"
	case "audio/webm":
		return "webm"
	default:
		return ""
	}
}

func envOrDefault(key, fallback string) string {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}
	return value
}

func envDuration(key string, fallback time.Duration) time.Duration {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}
	parsed, err := time.ParseDuration(value)
	if err != nil {
		return fallback
	}
	return parsed
}

func randomSuffix() string {
	var bytes [8]byte
	if _, err := rand.Read(bytes[:]); err != nil {
		return strconv.FormatInt(time.Now().UTC().UnixNano(), 10)
	}
	return fmt.Sprintf("%x", bytes[:])
}

func transcriptOutputKey(prefix, jobName string) string {
	jobName = strings.TrimSpace(jobName)
	if jobName == "" {
		return ""
	}
	prefix = strings.Trim(strings.TrimSpace(prefix), "/")
	if prefix == "" {
		return jobName + ".json"
	}
	return path.Join(prefix, jobName+".json")
}

func parseS3URI(uri string) (string, string, error) {
	trimmed := strings.TrimSpace(strings.TrimPrefix(uri, "s3://"))
	parts := strings.SplitN(trimmed, "/", 2)
	if len(parts) != 2 || parts[0] == "" || parts[1] == "" {
		return "", "", fmt.Errorf("invalid s3 uri %q", uri)
	}
	return parts[0], parts[1], nil
}
