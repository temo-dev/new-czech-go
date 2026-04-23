package httpapi

import (
	"context"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	v4 "github.com/aws/aws-sdk-go-v2/aws/signer/v4"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

type AttemptUploadTargetInput struct {
	AttemptID     string
	MimeType      string
	FileSizeBytes int
	DurationMs    int
	BaseURL       string
}

type UploadTargetProvider interface {
	CreateAttemptUploadTarget(ctx context.Context, input AttemptUploadTargetInput) (contracts.UploadTarget, error)
}

type localUploadTargetProvider struct{}

func NewLocalUploadTargetProvider() UploadTargetProvider {
	return localUploadTargetProvider{}
}

func (localUploadTargetProvider) CreateAttemptUploadTarget(_ context.Context, input AttemptUploadTargetInput) (contracts.UploadTarget, error) {
	return contracts.UploadTarget{
		Method: "PUT",
		URL:    strings.TrimRight(input.BaseURL, "/") + fmt.Sprintf("/v1/attempts/%s/audio", input.AttemptID),
		Headers: map[string]string{
			"Content-Type": input.MimeType,
		},
		StorageKey:   attemptAudioStorageKey(input.AttemptID, input.MimeType, ""),
		ExpiresInSec: 900,
	}, nil
}

type s3PresignAPI interface {
	PresignPutObject(ctx context.Context, params *s3.PutObjectInput, optFns ...func(*s3.PresignOptions)) (*v4.PresignedHTTPRequest, error)
}

type s3UploadTargetProvider struct {
	bucket        string
	prefix        string
	expires       time.Duration
	presignClient s3PresignAPI
}

func NewConfiguredUploadTargetProvider(ctx context.Context) (UploadTargetProvider, error) {
	switch strings.ToLower(strings.TrimSpace(os.Getenv("ATTEMPT_UPLOAD_PROVIDER"))) {
	case "", "local":
		return NewLocalUploadTargetProvider(), nil
	case "s3":
		return newS3UploadTargetProviderFromEnv(ctx)
	default:
		return nil, fmt.Errorf("unsupported ATTEMPT_UPLOAD_PROVIDER %q", os.Getenv("ATTEMPT_UPLOAD_PROVIDER"))
	}
}

func newS3UploadTargetProviderFromEnv(ctx context.Context) (UploadTargetProvider, error) {
	region := strings.TrimSpace(os.Getenv("AWS_REGION"))
	if region == "" {
		return nil, fmt.Errorf("AWS_REGION is required when ATTEMPT_UPLOAD_PROVIDER=s3")
	}
	bucket := strings.TrimSpace(os.Getenv("ATTEMPT_AUDIO_S3_BUCKET"))
	if bucket == "" {
		return nil, fmt.Errorf("ATTEMPT_AUDIO_S3_BUCKET is required when ATTEMPT_UPLOAD_PROVIDER=s3")
	}

	cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(region))
	if err != nil {
		return nil, fmt.Errorf("load AWS config: %w", err)
	}

	expires := 15 * time.Minute
	if value := strings.TrimSpace(os.Getenv("ATTEMPT_UPLOAD_URL_TTL")); value != "" {
		parsed, err := time.ParseDuration(value)
		if err == nil {
			expires = parsed
		}
	}

	client := s3.NewFromConfig(cfg)
	return &s3UploadTargetProvider{
		bucket:        bucket,
		prefix:        envOrDefault("ATTEMPT_AUDIO_S3_PREFIX", "attempt-audio"),
		expires:       expires,
		presignClient: s3.NewPresignClient(client),
	}, nil
}

func (p *s3UploadTargetProvider) CreateAttemptUploadTarget(ctx context.Context, input AttemptUploadTargetInput) (contracts.UploadTarget, error) {
	key := attemptAudioStorageKey(input.AttemptID, input.MimeType, p.prefix)
	request, err := p.presignClient.PresignPutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(p.bucket),
		Key:         aws.String(key),
		ContentType: aws.String(input.MimeType),
	}, func(opts *s3.PresignOptions) {
		opts.Expires = p.expires
	})
	if err != nil {
		return contracts.UploadTarget{}, err
	}

	headers := make(map[string]string, len(request.SignedHeader))
	for key, values := range request.SignedHeader {
		if len(values) > 0 {
			headers[key] = values[0]
		}
	}
	if _, ok := headers["Content-Type"]; !ok && input.MimeType != "" {
		headers["Content-Type"] = input.MimeType
	}

	return contracts.UploadTarget{
		Method:       request.Method,
		URL:          request.URL,
		Headers:      headers,
		StorageKey:   key,
		ExpiresInSec: int(p.expires / time.Second),
	}, nil
}

func attemptAudioStorageKey(attemptID, mimeType, prefix string) string {
	if prefix == "" {
		prefix = "attempt-audio"
	}
	return fmt.Sprintf("%s/%s/audio.%s", strings.Trim(prefix, "/"), attemptID, extensionForMime(mimeType))
}

func envOrDefault(key, fallback string) string {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}
	return value
}
