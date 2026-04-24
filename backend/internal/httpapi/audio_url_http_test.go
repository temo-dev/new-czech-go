package httpapi

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/processing"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

func TestAttemptAudioURLReturnsSignedLocalStreamURL(t *testing.T) {
	repo, attempt, body, secret := setupLocalAudioAttempt(t)

	server := httptest.NewServer(NewServerWithAudio(repo, nil, nil, NewLocalSignedAudioURLProvider(secret), secret))
	defer server.Close()

	data := getJSON(t, server, "/v1/attempts/"+attempt.ID+"/audio/url")
	payload := data["data"].(map[string]any)
	rawURL, _ := payload["url"].(string)
	if rawURL == "" {
		t.Fatal("expected data.url to be non-empty")
	}
	if payload["mime_type"] != "audio/m4a" {
		t.Fatalf("expected mime_type audio/m4a, got %v", payload["mime_type"])
	}
	if payload["expires_at"] == "" || payload["expires_at"] == nil {
		t.Fatal("expected expires_at to be set")
	}

	parsed, err := url.Parse(rawURL)
	if err != nil {
		t.Fatalf("url parse: %v", err)
	}
	streamURL := server.URL + parsed.Path + "?" + parsed.RawQuery

	response, err := server.Client().Get(streamURL)
	if err != nil {
		t.Fatalf("GET stream failed: %v", err)
	}
	defer response.Body.Close()

	if response.StatusCode != http.StatusOK {
		rb, _ := io.ReadAll(response.Body)
		t.Fatalf("expected 200 from stream, got %d body=%s", response.StatusCode, string(rb))
	}
	got, _ := io.ReadAll(response.Body)
	if string(got) != string(body) {
		t.Fatalf("expected audio bytes to round-trip, got %q", string(got))
	}
}

func TestAttemptAudioStreamRejectsExpiredToken(t *testing.T) {
	repo, attempt, _, secret := setupLocalAudioAttempt(t)

	server := httptest.NewServer(NewServerWithAudio(repo, nil, nil, NewLocalSignedAudioURLProvider(secret), secret))
	defer server.Close()

	expired := time.Now().UTC().Add(-1 * time.Minute).Unix()
	sig := signAudioToken(secret, attempt.ID, ScopeAttemptAudio, expired)
	q := url.Values{}
	q.Set("aid", attempt.ID)
	q.Set("scope", string(ScopeAttemptAudio))
	q.Set("exp", strconv.FormatInt(expired, 10))
	q.Set("sig", sig)

	response, err := server.Client().Get(server.URL + "/v1/attempt-audio/stream?" + q.Encode())
	if err != nil {
		t.Fatalf("GET stream failed: %v", err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusUnauthorized {
		t.Fatalf("expected 401 for expired token, got %d", response.StatusCode)
	}
	var body map[string]any
	_ = json.NewDecoder(response.Body).Decode(&body)
	if err, _ := body["error"].(map[string]any); err == nil || err["code"] != "audio_url_expired" {
		t.Fatalf("expected error.code audio_url_expired, got %#v", body)
	}
}

func TestAttemptAudioStreamRejectsWrongScope(t *testing.T) {
	repo, attempt, _, secret := setupLocalAudioAttempt(t)

	server := httptest.NewServer(NewServerWithAudio(repo, nil, nil, NewLocalSignedAudioURLProvider(secret), secret))
	defer server.Close()

	expiry := time.Now().UTC().Add(5 * time.Minute).Unix()
	// Sign with attempt scope but ask stream to serve review scope.
	sig := signAudioToken(secret, attempt.ID, ScopeAttemptAudio, expiry)
	q := url.Values{}
	q.Set("aid", attempt.ID)
	q.Set("scope", string(ScopeReviewAudio))
	q.Set("exp", strconv.FormatInt(expiry, 10))
	q.Set("sig", sig)

	response, err := server.Client().Get(server.URL + "/v1/attempt-audio/stream?" + q.Encode())
	if err != nil {
		t.Fatalf("GET stream failed: %v", err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusUnauthorized {
		t.Fatalf("expected 401 for wrong-scope token, got %d", response.StatusCode)
	}
}

func TestReviewAudioURLReturnsSignedLocalStreamURL(t *testing.T) {
	repo := store.NewMemoryStore()
	attempt, err := repo.CreateAttempt("user-learner-1", "exercise-uloha1-weather", "ios", "0.1.0", "vi")
	if err != nil {
		t.Fatalf("CreateAttempt: %v", err)
	}

	storageKey := "attempt-review/" + attempt.ID + "/model-answer.wav"
	audio := &contracts.ReviewArtifactAudio{StorageKey: storageKey, MimeType: "audio/wav"}
	if _, ok := repo.UpsertReviewArtifact(attempt.ID, contracts.AttemptReviewArtifact{
		Status:               "ready",
		SourceTranscriptText: "dobry den",
		ModelAnswerText:      "Dobry den.",
		TTSAudio:             audio,
	}); !ok {
		t.Fatal("UpsertReviewArtifact failed")
	}

	filePath := processing.ReviewAudioLocalPath(storageKey)
	if err := os.MkdirAll(filepath.Dir(filePath), 0o755); err != nil {
		t.Fatalf("MkdirAll: %v", err)
	}
	const audioBody = "fake-review-bytes"
	if err := os.WriteFile(filePath, []byte(audioBody), 0o644); err != nil {
		t.Fatalf("WriteFile: %v", err)
	}

	secret := []byte("test-secret-review")
	server := httptest.NewServer(NewServerWithAudio(repo, nil, nil, NewLocalSignedAudioURLProvider(secret), secret))
	defer server.Close()

	data := getJSON(t, server, "/v1/attempts/"+attempt.ID+"/review/audio/url")
	rawURL, _ := data["data"].(map[string]any)["url"].(string)
	if rawURL == "" {
		t.Fatal("expected data.url non-empty")
	}
	parsed, err := url.Parse(rawURL)
	if err != nil {
		t.Fatalf("url parse: %v", err)
	}
	if !strings.Contains(parsed.RawQuery, "scope=review_audio") {
		t.Fatalf("expected scope=review_audio in URL, got %q", parsed.RawQuery)
	}

	response, err := server.Client().Get(server.URL + parsed.Path + "?" + parsed.RawQuery)
	if err != nil {
		t.Fatalf("GET stream: %v", err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		rb, _ := io.ReadAll(response.Body)
		t.Fatalf("expected 200 for review stream, got %d body=%s", response.StatusCode, string(rb))
	}
	got, _ := io.ReadAll(response.Body)
	if string(got) != audioBody {
		t.Fatalf("review audio round-trip mismatch, got %q", string(got))
	}
}

func setupLocalAudioAttempt(t *testing.T) (*store.MemoryStore, *contracts.Attempt, []byte, []byte) {
	t.Helper()
	repo := store.NewMemoryStore()
	attempt, err := repo.CreateAttempt("user-learner-1", "exercise-uloha1-weather", "ios", "0.1.0", "vi")
	if err != nil {
		t.Fatalf("CreateAttempt: %v", err)
	}
	dir := t.TempDir()
	storedPath := filepath.Join(dir, "audio.m4a")
	body := []byte("hello-a2-bytes")
	if err := os.WriteFile(storedPath, body, 0o644); err != nil {
		t.Fatalf("WriteFile: %v", err)
	}
	if _, ok := repo.MarkUploadComplete(attempt.ID, contracts.AttemptAudio{
		StorageKey:     "attempt-audio/" + attempt.ID + "/audio.m4a",
		MimeType:       "audio/m4a",
		StoredFilePath: storedPath,
		DurationMs:     4000,
		FileSizeBytes:  len(body),
	}); !ok {
		t.Fatal("MarkUploadComplete failed")
	}
	return repo, attempt, body, []byte("test-secret-attempt")
}

func getJSON(t *testing.T, server *httptest.Server, path string) map[string]any {
	t.Helper()
	request, err := http.NewRequest(http.MethodGet, server.URL+path, nil)
	if err != nil {
		t.Fatalf("NewRequest: %v", err)
	}
	request.Header.Set("Authorization", "Bearer dev-learner-token")
	response, err := server.Client().Do(request)
	if err != nil {
		t.Fatalf("Do: %v", err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		rb, _ := io.ReadAll(response.Body)
		t.Fatalf("expected 200 from %s, got %d body=%s", path, response.StatusCode, string(rb))
	}
	var decoded map[string]any
	if err := json.NewDecoder(response.Body).Decode(&decoded); err != nil {
		t.Fatalf("Decode: %v", err)
	}
	return decoded
}
