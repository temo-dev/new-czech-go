package httpapi

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/store"
)

func postPreviewPrompt(t *testing.T, server *httptest.Server, token, body string) (int, map[string]any) {
	t.Helper()
	req, err := http.NewRequest(http.MethodPost,
		server.URL+"/v1/admin/interview/preview-prompt",
		bytes.NewReader([]byte(body)))
	if err != nil {
		t.Fatalf("NewRequest failed: %v", err)
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := server.Client().Do(req)
	if err != nil {
		t.Fatalf("Do failed: %v", err)
	}
	defer resp.Body.Close()
	var decoded map[string]any
	_ = json.NewDecoder(resp.Body).Decode(&decoded)
	return resp.StatusCode, decoded
}

func TestInterviewPreviewPrompt_RequiresAdmin(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	status, _ := postPreviewPrompt(t, server, "", `{"system_prompt":"x"}`)
	if status != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", status)
	}

	status, _ = postPreviewPrompt(t, server, "dev-learner-token", `{"system_prompt":"x"}`)
	if status != http.StatusForbidden {
		t.Fatalf("learner expected 403, got %d", status)
	}
}

func TestInterviewPreviewPrompt_DerivesPrompt(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	body := `{"system_prompt":"You are an examiner.\n\nÚKOL:\nMô tả công việc.\n\nEnd."}`
	status, decoded := postPreviewPrompt(t, server, "dev-admin-token", body)
	if status != http.StatusOK {
		t.Fatalf("expected 200, got %d", status)
	}
	data := decoded["data"].(map[string]any)
	if got := data["display_prompt"].(string); got != "Mô tả công việc." {
		t.Fatalf("display_prompt = %q", got)
	}
}

func TestInterviewPreviewPrompt_EmptyPrompt(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	status, decoded := postPreviewPrompt(t, server, "dev-admin-token", `{"system_prompt":""}`)
	if status != http.StatusOK {
		t.Fatalf("expected 200, got %d", status)
	}
	data := decoded["data"].(map[string]any)
	if got := data["display_prompt"].(string); got != "" {
		t.Fatalf("display_prompt should be empty, got %q", got)
	}
}

func TestInterviewPreviewPrompt_InvalidJSON(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	status, _ := postPreviewPrompt(t, server, "dev-admin-token", `not json`)
	if status != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", status)
	}
}

func TestInterviewPreviewPrompt_RateLimit(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	body := `{"system_prompt":"You are. Test."}`
	for i := 0; i < interviewPreviewRateLimit; i++ {
		status, _ := postPreviewPrompt(t, server, "dev-admin-token", body)
		if status != http.StatusOK {
			t.Fatalf("req %d expected 200, got %d", i, status)
		}
	}
	status, _ := postPreviewPrompt(t, server, "dev-admin-token", body)
	if status != http.StatusTooManyRequests {
		t.Fatalf("expected 429 after limit, got %d", status)
	}
}
