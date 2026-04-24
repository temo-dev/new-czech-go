package httpapi

import (
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	v4 "github.com/aws/aws-sdk-go-v2/aws/signer/v4"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

// AudioURLScope names the asset the signed URL may open.
type AudioURLScope string

const (
	ScopeAttemptAudio AudioURLScope = "attempt_audio"
	ScopeReviewAudio  AudioURLScope = "review_audio"
)

// SignedAudioURL carries the playable URL plus its lifecycle metadata.
type SignedAudioURL struct {
	URL       string
	MimeType  string
	ExpiresAt time.Time
}

// AudioURLProvider mints short-lived playable URLs for stored audio.
// Implementations either presign against cloud storage or mint an
// HMAC-signed URL back to the backend's own streaming endpoint.
type AudioURLProvider interface {
	SignedAudioURL(ctx context.Context, input AudioURLInput) (SignedAudioURL, error)
}

// AudioURLInput is the request payload for minting a signed URL.
type AudioURLInput struct {
	AttemptID  string
	Scope      AudioURLScope
	StorageKey string
	MimeType   string
	BaseURL    string
	ExpiresIn  time.Duration
}

var (
	errAudioURLExpired    = errors.New("audio url expired")
	errAudioURLInvalidSig = errors.New("audio url invalid signature")
	errAudioURLBadScope   = errors.New("audio url wrong scope")
	errAudioURLBadPayload = errors.New("audio url payload invalid")
)

// localSignedAudioURLProvider mints URLs that point back to the backend's
// own streaming endpoint, authenticated by an HMAC over (attempt, scope, exp).
type localSignedAudioURLProvider struct {
	secret []byte
}

// NewLocalSignedAudioURLProvider returns the default local-file signer.
func NewLocalSignedAudioURLProvider(secret []byte) AudioURLProvider {
	return &localSignedAudioURLProvider{secret: secret}
}

func (p *localSignedAudioURLProvider) SignedAudioURL(_ context.Context, input AudioURLInput) (SignedAudioURL, error) {
	if input.AttemptID == "" {
		return SignedAudioURL{}, fmt.Errorf("attempt id required")
	}
	if input.Scope == "" {
		return SignedAudioURL{}, fmt.Errorf("scope required")
	}
	if input.ExpiresIn <= 0 {
		input.ExpiresIn = 10 * time.Minute
	}
	if input.BaseURL == "" {
		return SignedAudioURL{}, fmt.Errorf("base url required")
	}

	expiresAt := time.Now().UTC().Add(input.ExpiresIn).Truncate(time.Second)
	sig := signAudioToken(p.secret, input.AttemptID, input.Scope, expiresAt.Unix())

	q := url.Values{}
	q.Set("aid", input.AttemptID)
	q.Set("scope", string(input.Scope))
	q.Set("exp", strconv.FormatInt(expiresAt.Unix(), 10))
	q.Set("sig", sig)

	u := strings.TrimRight(input.BaseURL, "/") + "/v1/attempt-audio/stream?" + q.Encode()
	return SignedAudioURL{URL: u, MimeType: input.MimeType, ExpiresAt: expiresAt}, nil
}

// s3PresignedAudioURLProvider returns direct S3 presigned GET URLs.
type s3PresignedAudioURLProvider struct {
	bucket        string
	presignClient interface {
		PresignGetObject(ctx context.Context, params *s3.GetObjectInput, optFns ...func(*s3.PresignOptions)) (*v4.PresignedHTTPRequest, error)
	}
	fallback AudioURLProvider
}

// NewS3PresignedAudioURLProvider loads credentials from env and returns an S3-backed
// provider. It falls back to the local signer for storage keys that do not look like
// S3 object keys (e.g. cloud-copied learner attempts stored under an http URL).
func NewS3PresignedAudioURLProvider(ctx context.Context, bucket string, fallback AudioURLProvider) (AudioURLProvider, error) {
	region := strings.TrimSpace(os.Getenv("AWS_REGION"))
	if region == "" {
		return nil, fmt.Errorf("AWS_REGION is required when audio url provider is s3")
	}
	cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(region))
	if err != nil {
		return nil, fmt.Errorf("load AWS config: %w", err)
	}
	client := s3.NewFromConfig(cfg)
	return &s3PresignedAudioURLProvider{
		bucket:        bucket,
		presignClient: s3.NewPresignClient(client),
		fallback:      fallback,
	}, nil
}

func (p *s3PresignedAudioURLProvider) SignedAudioURL(ctx context.Context, input AudioURLInput) (SignedAudioURL, error) {
	key := strings.TrimSpace(input.StorageKey)
	if key == "" {
		return SignedAudioURL{}, fmt.Errorf("storage key required")
	}
	// Already-absolute URLs (rare) round-trip as-is.
	if strings.HasPrefix(key, "http://") || strings.HasPrefix(key, "https://") {
		return SignedAudioURL{
			URL:       key,
			MimeType:  input.MimeType,
			ExpiresAt: time.Now().UTC().Add(input.ExpiresIn).Truncate(time.Second),
		}, nil
	}
	// If the storage key doesn't look like an S3 object path, fall back to local signing.
	if strings.ContainsAny(key, " \t") || !strings.Contains(key, "/") {
		if p.fallback != nil {
			return p.fallback.SignedAudioURL(ctx, input)
		}
	}

	if input.ExpiresIn <= 0 {
		input.ExpiresIn = 10 * time.Minute
	}

	req, err := p.presignClient.PresignGetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(p.bucket),
		Key:    aws.String(key),
	}, func(opts *s3.PresignOptions) {
		opts.Expires = input.ExpiresIn
	})
	if err != nil {
		return SignedAudioURL{}, err
	}

	return SignedAudioURL{
		URL:       req.URL,
		MimeType:  input.MimeType,
		ExpiresAt: time.Now().UTC().Add(input.ExpiresIn).Truncate(time.Second),
	}, nil
}

// NewConfiguredAudioURLProvider picks an implementation based on env.
// ATTEMPT_AUDIO_URL_PROVIDER=s3 plus ATTEMPT_AUDIO_S3_BUCKET selects S3.
// Otherwise the local HMAC signer is returned.
func NewConfiguredAudioURLProvider(ctx context.Context, secret []byte) (AudioURLProvider, error) {
	local := NewLocalSignedAudioURLProvider(secret)
	kind := strings.ToLower(strings.TrimSpace(os.Getenv("ATTEMPT_AUDIO_URL_PROVIDER")))
	switch kind {
	case "", "local":
		return local, nil
	case "s3":
		bucket := strings.TrimSpace(os.Getenv("ATTEMPT_AUDIO_S3_BUCKET"))
		if bucket == "" {
			return nil, fmt.Errorf("ATTEMPT_AUDIO_S3_BUCKET is required when ATTEMPT_AUDIO_URL_PROVIDER=s3")
		}
		return NewS3PresignedAudioURLProvider(ctx, bucket, local)
	default:
		return nil, fmt.Errorf("unsupported ATTEMPT_AUDIO_URL_PROVIDER %q", kind)
	}
}

// signAudioToken returns a base64url(no-pad) HMAC-SHA256 of the canonical payload.
func signAudioToken(secret []byte, attemptID string, scope AudioURLScope, expiry int64) string {
	mac := hmac.New(sha256.New, secret)
	fmt.Fprintf(mac, "%s|%d|%s", attemptID, expiry, scope)
	return base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
}

// verifyAudioToken validates a URL-bound token against the scope and attempt it was minted for.
func verifyAudioToken(secret []byte, attemptID string, scope AudioURLScope, expiry int64, sig string) error {
	if attemptID == "" || scope == "" || sig == "" {
		return errAudioURLBadPayload
	}
	if time.Now().UTC().Unix() > expiry {
		return errAudioURLExpired
	}
	expected := signAudioToken(secret, attemptID, scope, expiry)
	if !hmac.Equal([]byte(expected), []byte(sig)) {
		return errAudioURLInvalidSig
	}
	return nil
}

// AudioSigningSecretFromEnv reads AUDIO_SIGN_SECRET. If empty, generates a random 32-byte
// secret and logs a warning — dev-only. Production must set the env var.
func AudioSigningSecretFromEnv(warn func(string, ...any)) []byte {
	if raw := strings.TrimSpace(os.Getenv("AUDIO_SIGN_SECRET")); raw != "" {
		if decoded, err := hex.DecodeString(raw); err == nil && len(decoded) >= 16 {
			return decoded
		}
		return []byte(raw)
	}
	buf := make([]byte, 32)
	_, _ = rand.Read(buf)
	if warn != nil {
		warn("AUDIO_SIGN_SECRET is unset; generated ephemeral key for this process. Playback URLs will not verify across restarts.")
	}
	return buf
}
