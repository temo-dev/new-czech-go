package httpapi

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/store"
)

// newServerWithReplicate creates a test server with replicateAPIKey set via env and
// with the Replicate base URL pointed at mockReplicateURL.
func newServerWithReplicate(t *testing.T, mockReplicateURL string) *httptest.Server {
	t.Helper()
	t.Setenv("REPLICATE_API_KEY", "test-key-123")
	orig := replicateBaseURL
	replicateBaseURL = mockReplicateURL
	t.Cleanup(func() { replicateBaseURL = orig })
	repo := store.NewMemoryStore()
	return httptest.NewServer(NewServer(repo, nil, nil))
}

// mockReplicateServer returns an httptest server that simulates the Replicate API.
// It handles:
//   POST /v1/models/.../predictions → returns predictionID
//   GET  /v1/predictions/{id}       → returns status + output
func mockReplicateServer(t *testing.T, status string, output []string, errMsg string) *httptest.Server {
	t.Helper()
	mux := http.NewServeMux()
	mux.HandleFunc("/v1/models/", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(map[string]any{"id": "pred-test-123", "status": "starting"})
	})
	mux.HandleFunc("/v1/predictions/", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		resp := map[string]any{
			"id":     "pred-test-123",
			"status": status,
		}
		if len(output) > 0 {
			resp["output"] = output
		}
		if errMsg != "" {
			resp["error"] = errMsg
		}
		_ = json.NewEncoder(w).Encode(resp)
	})
	return httptest.NewServer(mux)
}

// mockImageServer returns a simple image file server.
func mockImageServer(t *testing.T) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "image/jpeg")
		// Minimal valid JPEG bytes (2×2 white pixel)
		_, _ = w.Write([]byte("\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00\xff\xd9"))
	}))
}

// ── Tests ─────────────────────────────────────────────────────────────────────

func TestHandleGenerateImage_MissingKey(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()
	// No REPLICATE_API_KEY set → NewServer reads empty string from env.

	status, resp := postJSONAllowErrorWithToken(t, server, "/v1/admin/ai/generate-image", "dev-admin-token",
		map[string]any{"prompt": "a café in Prague"})

	if status != http.StatusServiceUnavailable {
		t.Fatalf("expected 503, got %d", status)
	}
	errMap, _ := resp["error"].(map[string]any)
	if errMap["code"] != "not_configured" {
		t.Fatalf("expected code=not_configured, got %v", errMap["code"])
	}
}

func TestHandleGenerateImage_PromptTooShort(t *testing.T) {
	fakeMock := mockReplicateServer(t, "succeeded", nil, "")
	defer fakeMock.Close()
	server := newServerWithReplicate(t, fakeMock.URL)
	defer server.Close()

	status, resp := postJSONAllowErrorWithToken(t, server, "/v1/admin/ai/generate-image", "dev-admin-token",
		map[string]any{"prompt": "ab"})

	if status != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", status)
	}
	errMap, _ := resp["error"].(map[string]any)
	if errMap["code"] != "validation_error" {
		t.Fatalf("expected validation_error, got %v", errMap["code"])
	}
}

func TestHandleGenerateImage_PromptTooLong(t *testing.T) {
	fakeMock := mockReplicateServer(t, "succeeded", nil, "")
	defer fakeMock.Close()
	server := newServerWithReplicate(t, fakeMock.URL)
	defer server.Close()

	status, _ := postJSONAllowErrorWithToken(t, server, "/v1/admin/ai/generate-image", "dev-admin-token",
		map[string]any{"prompt": strings.Repeat("a", 501)})

	if status != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", status)
	}
}

func TestHandleGenerateImage_RateLimit(t *testing.T) {
	fakeMock := mockReplicateServer(t, "succeeded", nil, "")
	defer fakeMock.Close()
	imgServer := mockImageServer(t)
	defer imgServer.Close()
	// Patch poll to return image URL from our mock image server.
	origPoll := replicateBaseURL
	_ = origPoll

	t.Setenv("REPLICATE_API_KEY", "test-key-123")
	replicateBaseURL = fakeMock.URL

	// Build a mock that returns img server URL as output.
	pollMux := http.NewServeMux()
	pollMux.HandleFunc("/v1/models/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(map[string]any{"id": "pred-rl-1", "status": "starting"})
	})
	pollMux.HandleFunc("/v1/predictions/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]any{
			"id":     "pred-rl-1",
			"status": "succeeded",
			"output": []string{imgServer.URL + "/img.jpg"},
		})
	})
	mockServer := httptest.NewServer(pollMux)
	defer mockServer.Close()
	replicateBaseURL = mockServer.URL
	t.Cleanup(func() { replicateBaseURL = "https://api.replicate.com" })

	repo := store.NewMemoryStore()
	appServer := httptest.NewServer(NewServer(repo, nil, nil))
	defer appServer.Close()

	// Make 5 successful requests (hits the limit).
	for i := 0; i < aiImageRateLimit; i++ {
		status, _ := postJSONAllowErrorWithToken(t, appServer, "/v1/admin/ai/generate-image", "dev-admin-token",
			map[string]any{"prompt": fmt.Sprintf("café in Prague %d", i)})
		if status != http.StatusOK {
			t.Fatalf("request %d: expected 200, got %d", i, status)
		}
	}

	// 6th request must be rate-limited.
	status, resp := postJSONAllowErrorWithToken(t, appServer, "/v1/admin/ai/generate-image", "dev-admin-token",
		map[string]any{"prompt": "should be blocked"})
	if status != http.StatusTooManyRequests {
		t.Fatalf("expected 429 on 6th request, got %d", status)
	}
	errMap, _ := resp["error"].(map[string]any)
	if errMap["code"] != "rate_limited" {
		t.Fatalf("expected code=rate_limited, got %v", errMap["code"])
	}
}

func TestHandleGenerateImage_ReplicateFailed(t *testing.T) {
	fakeMock := mockReplicateServer(t, "failed", nil, "NSFW content detected")
	defer fakeMock.Close()
	server := newServerWithReplicate(t, fakeMock.URL)
	defer server.Close()

	status, resp := postJSONAllowErrorWithToken(t, server, "/v1/admin/ai/generate-image", "dev-admin-token",
		map[string]any{"prompt": "a test prompt for failure"})

	if status != http.StatusServiceUnavailable {
		t.Fatalf("expected 503, got %d", status)
	}
	errMap, _ := resp["error"].(map[string]any)
	if errMap["code"] != "replicate_error" {
		t.Fatalf("expected replicate_error, got %v", errMap["code"])
	}
}

func TestHandleGenerateImage_ReplicateTimeout(t *testing.T) {
	// Mock that never responds to poll.
	hangMux := http.NewServeMux()
	hangMux.HandleFunc("/v1/models/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(map[string]any{"id": "pred-hang", "status": "starting"})
	})
	hangMux.HandleFunc("/v1/predictions/", func(w http.ResponseWriter, r *http.Request) {
		// Never completes — blocks until client cancels.
		select {
		case <-r.Context().Done():
		case <-time.After(60 * time.Second):
		}
		http.Error(w, "context cancelled", http.StatusGatewayTimeout)
	})
	hangServer := httptest.NewServer(hangMux)
	defer hangServer.Close()

	t.Setenv("REPLICATE_API_KEY", "test-key-123")
	orig := replicateBaseURL
	replicateBaseURL = hangServer.URL
	t.Cleanup(func() { replicateBaseURL = orig })

	repo := store.NewMemoryStore()
	appServer := httptest.NewServer(NewServer(repo, nil, nil))
	defer appServer.Close()

	// Use a client with longer timeout so the request can complete after 30s.
	client := &http.Client{Timeout: 45 * time.Second}
	payload := `{"prompt":"a test that will timeout"}`
	req, _ := http.NewRequest(http.MethodPost, appServer.URL+"/v1/admin/ai/generate-image", strings.NewReader(payload))
	req.Header.Set("Authorization", "Bearer dev-admin-token")
	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusGatewayTimeout {
		t.Fatalf("expected 504, got %d", resp.StatusCode)
	}
}

func TestHandleGenerateImage_Success(t *testing.T) {
	imgServer := mockImageServer(t)
	defer imgServer.Close()

	successMux := http.NewServeMux()
	successMux.HandleFunc("/v1/models/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(map[string]any{"id": "pred-success", "status": "starting"})
	})
	successMux.HandleFunc("/v1/predictions/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]any{
			"id":     "pred-success",
			"status": "succeeded",
			"output": []string{imgServer.URL + "/img.jpg"},
		})
	})
	mockServer := httptest.NewServer(successMux)
	defer mockServer.Close()

	t.Setenv("REPLICATE_API_KEY", "test-key-123")
	orig := replicateBaseURL
	replicateBaseURL = mockServer.URL
	t.Cleanup(func() { replicateBaseURL = orig })

	repo := store.NewMemoryStore()
	appServer := httptest.NewServer(NewServer(repo, nil, nil))
	defer appServer.Close()

	status, resp := postJSONAllowErrorWithToken(t, appServer, "/v1/admin/ai/generate-image", "dev-admin-token",
		map[string]any{"prompt": "a beautiful Czech café with warm lighting"})

	if status != http.StatusOK {
		t.Fatalf("expected 200, got %d — resp: %v", status, resp)
	}
	data, _ := resp["data"].(map[string]any)
	if data["asset_id"] == "" {
		t.Fatal("expected non-empty asset_id")
	}
	if data["storage_key"] == "" {
		t.Fatal("expected non-empty storage_key")
	}
	if data["preview_url"] == "" {
		t.Fatal("expected non-empty preview_url")
	}
}

// ── Rate limiter unit tests ───────────────────────────────────────────────────

func TestAiImageRateLimiter_AllowsUpToLimit(t *testing.T) {
	rl := newAiImageRateLimiter()
	for i := 0; i < aiImageRateLimit; i++ {
		if !rl.allow("admin@test.com") {
			t.Fatalf("expected allow on request %d", i+1)
		}
	}
	if rl.allow("admin@test.com") {
		t.Fatal("expected deny on request beyond limit")
	}
}

func TestAiImageRateLimiter_ResetsAfterWindow(t *testing.T) {
	rl := newAiImageRateLimiter()
	// Exhaust the limit.
	for i := 0; i < aiImageRateLimit; i++ {
		rl.allow("admin@test.com")
	}
	if rl.allow("admin@test.com") {
		t.Fatal("should be rate-limited")
	}

	// Manually expire the window.
	rl.mu.Lock()
	w := rl.windows["admin@test.com"]
	w.windowEnd = time.Now().Add(-1 * time.Second)
	rl.windows["admin@test.com"] = w
	rl.mu.Unlock()

	if !rl.allow("admin@test.com") {
		t.Fatal("expected allow after window reset")
	}
}
