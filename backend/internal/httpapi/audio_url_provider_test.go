package httpapi

import (
	"context"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"testing"
	"time"

	v4 "github.com/aws/aws-sdk-go-v2/aws/signer/v4"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

func TestLocalSignedAudioURLRoundTripVerifies(t *testing.T) {
	secret := []byte("test-secret-key")
	provider := NewLocalSignedAudioURLProvider(secret)

	signed, err := provider.SignedAudioURL(context.Background(), AudioURLInput{
		AttemptID:  "attempt-42",
		Scope:      ScopeAttemptAudio,
		StorageKey: "attempt-audio/attempt-42/audio.m4a",
		MimeType:   "audio/m4a",
		BaseURL:    "http://api.example.com",
		ExpiresIn:  5 * time.Minute,
	})
	if err != nil {
		t.Fatalf("SignedAudioURL returned error: %v", err)
	}

	if !strings.HasPrefix(signed.URL, "http://api.example.com/v1/attempt-audio/stream?") {
		t.Fatalf("unexpected URL prefix: %q", signed.URL)
	}

	parsed, err := url.Parse(signed.URL)
	if err != nil {
		t.Fatalf("url.Parse failed: %v", err)
	}
	q := parsed.Query()
	expiry, err := strconv.ParseInt(q.Get("exp"), 10, 64)
	if err != nil {
		t.Fatalf("bad exp: %v", err)
	}
	if q.Get("aid") != "attempt-42" {
		t.Fatalf("unexpected aid: %q", q.Get("aid"))
	}
	if q.Get("scope") != string(ScopeAttemptAudio) {
		t.Fatalf("unexpected scope: %q", q.Get("scope"))
	}
	if err := verifyAudioToken(secret, "attempt-42", ScopeAttemptAudio, expiry, q.Get("sig")); err != nil {
		t.Fatalf("expected signature to verify, got %v", err)
	}
}

func TestLocalSignedAudioURLRejectsExpiredToken(t *testing.T) {
	secret := []byte("secret")
	expired := time.Now().UTC().Add(-1 * time.Minute).Unix()
	sig := signAudioToken(secret, "attempt-42", ScopeAttemptAudio, expired)

	if err := verifyAudioToken(secret, "attempt-42", ScopeAttemptAudio, expired, sig); err != errAudioURLExpired {
		t.Fatalf("expected errAudioURLExpired, got %v", err)
	}
}

func TestLocalSignedAudioURLRejectsWrongScope(t *testing.T) {
	secret := []byte("secret")
	expiry := time.Now().UTC().Add(5 * time.Minute).Unix()
	sig := signAudioToken(secret, "attempt-42", ScopeAttemptAudio, expiry)

	// Token minted for attempt scope must not verify for review scope.
	if err := verifyAudioToken(secret, "attempt-42", ScopeReviewAudio, expiry, sig); err == nil {
		t.Fatal("expected cross-scope token to fail verification")
	}
}

func TestLocalSignedAudioURLRejectsTamperedAttempt(t *testing.T) {
	secret := []byte("secret")
	expiry := time.Now().UTC().Add(5 * time.Minute).Unix()
	sig := signAudioToken(secret, "attempt-42", ScopeAttemptAudio, expiry)

	if err := verifyAudioToken(secret, "attempt-other", ScopeAttemptAudio, expiry, sig); err != errAudioURLInvalidSig {
		t.Fatalf("expected errAudioURLInvalidSig, got %v", err)
	}
}

func TestConfiguredAudioURLProviderDefaultsToS3WhenUploadsUseS3(t *testing.T) {
	t.Setenv("ATTEMPT_AUDIO_URL_PROVIDER", "")
	t.Setenv("ATTEMPT_UPLOAD_PROVIDER", "s3")

	if got := configuredAudioURLProviderKind(); got != "s3" {
		t.Fatalf("provider kind = %q, want s3", got)
	}
}

func TestConfiguredAudioURLProviderExplicitLocalOverridesS3Uploads(t *testing.T) {
	t.Setenv("ATTEMPT_AUDIO_URL_PROVIDER", "local")
	t.Setenv("ATTEMPT_UPLOAD_PROVIDER", "s3")

	if got := configuredAudioURLProviderKind(); got != "local" {
		t.Fatalf("provider kind = %q, want local", got)
	}
}

func TestS3AudioURLProviderFallsBackForReviewAudio(t *testing.T) {
	provider := &s3PresignedAudioURLProvider{
		bucket:        "bucket",
		presignClient: fakeGetObjectPresigner{url: "https://s3.example.invalid/presigned-get"},
		fallback:      NewLocalSignedAudioURLProvider([]byte("review-secret")),
	}

	signed, err := provider.SignedAudioURL(context.Background(), AudioURLInput{
		AttemptID:  "attempt-42",
		Scope:      ScopeReviewAudio,
		StorageKey: "attempt-review/attempt-42/model-answer.mp3",
		MimeType:   "audio/mpeg",
		BaseURL:    "http://api.example.com",
		ExpiresIn:  5 * time.Minute,
	})
	if err != nil {
		t.Fatalf("SignedAudioURL returned error: %v", err)
	}
	if strings.HasPrefix(signed.URL, "https://s3.example.invalid/") {
		t.Fatalf("review audio should use local fallback, got %q", signed.URL)
	}
	if !strings.HasPrefix(signed.URL, "http://api.example.com/v1/attempt-audio/stream?") {
		t.Fatalf("unexpected fallback URL: %q", signed.URL)
	}
	if !strings.Contains(signed.URL, "scope=review_audio") {
		t.Fatalf("expected review scope in fallback URL, got %q", signed.URL)
	}
}

type fakeGetObjectPresigner struct {
	url string
}

func (f fakeGetObjectPresigner) PresignGetObject(context.Context, *s3.GetObjectInput, ...func(*s3.PresignOptions)) (*v4.PresignedHTTPRequest, error) {
	return &v4.PresignedHTTPRequest{
		URL:          f.url,
		Method:       http.MethodGet,
		SignedHeader: http.Header{},
	}, nil
}
