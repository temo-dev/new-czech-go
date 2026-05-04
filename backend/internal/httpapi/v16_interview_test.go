package httpapi

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/store"
)

// V16: GET /v1/exercises/:id enriches interview detail with display_prompt
// (derived) and clamps audio_buffer_timeout_ms.

func getInterviewDetail(t *testing.T, server *httptest.Server, exerciseID string) map[string]any {
	t.Helper()
	req, err := http.NewRequest(http.MethodGet, server.URL+"/v1/exercises/"+exerciseID, nil)
	if err != nil {
		t.Fatalf("NewRequest failed: %v", err)
	}
	req.Header.Set("Authorization", "Bearer dev-learner-token")
	resp, err := server.Client().Do(req)
	if err != nil {
		t.Fatalf("GET failed: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("unexpected status %d", resp.StatusCode)
	}
	var decoded map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&decoded); err != nil {
		t.Fatalf("decode failed: %v", err)
	}
	data := decoded["data"].(map[string]any)
	detail, _ := data["detail"].(map[string]any)
	return detail
}

func createInterviewExercise(t *testing.T, server *httptest.Server, timeoutMs any) string {
	t.Helper()
	detail := map[string]any{
		"topic": "Công việc",
		"system_prompt": `You are an examiner.

ÚKOL:
Mô tả công việc bạn muốn làm ở Cộng hòa Séc.

End.`,
		"max_turns":       6,
		"show_transcript": true,
	}
	if timeoutMs != nil {
		detail["audio_buffer_timeout_ms"] = timeoutMs
	}
	resp := postJSONWithToken(t, server, "/v1/admin/exercises", "dev-admin-token", map[string]any{
		"module_id":     "module-interview-1",
		"exercise_type": "interview_conversation",
		"title":         "Phỏng vấn công việc",
		"detail":        detail,
	})
	return resp["data"].(map[string]any)["id"].(string)
}

func TestExerciseGet_DerivesDisplayPromptForInterview(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	id := createInterviewExercise(t, server, nil)
	detail := getInterviewDetail(t, server, id)

	got, _ := detail["display_prompt"].(string)
	want := "Mô tả công việc bạn muốn làm ở Cộng hòa Séc."
	if got != want {
		t.Fatalf("display_prompt = %q, want %q", got, want)
	}
}

func TestExerciseGet_DefaultAudioBufferTimeout(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	id := createInterviewExercise(t, server, nil)
	detail := getInterviewDetail(t, server, id)

	got := detail["audio_buffer_timeout_ms"]
	if v, _ := got.(float64); int(v) != 1500 {
		t.Fatalf("audio_buffer_timeout_ms = %v, want 1500", got)
	}
}

func TestExerciseGet_ClampsLowAudioBufferTimeout(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	id := createInterviewExercise(t, server, 100)
	detail := getInterviewDetail(t, server, id)

	got := detail["audio_buffer_timeout_ms"]
	if v, _ := got.(float64); int(v) != 500 {
		t.Fatalf("audio_buffer_timeout_ms = %v, want 500 (clamped low)", got)
	}
}

func TestExerciseGet_ClampsHighAudioBufferTimeout(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	id := createInterviewExercise(t, server, 9999)
	detail := getInterviewDetail(t, server, id)

	got := detail["audio_buffer_timeout_ms"]
	if v, _ := got.(float64); int(v) != 5000 {
		t.Fatalf("audio_buffer_timeout_ms = %v, want 5000 (clamped high)", got)
	}
}

func TestExerciseGet_NonInterviewSkillUntouched(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	resp := postJSONWithToken(t, server, "/v1/admin/exercises", "dev-admin-token", map[string]any{
		"module_id":     "module-noi-1",
		"exercise_type": "uloha_1_topic_answers",
		"title":         "Bản thân",
		"questions":     []string{"Jak se jmenujete?", "Kde bydlíte?"},
	})
	id := resp["data"].(map[string]any)["id"].(string)

	req, err := http.NewRequest(http.MethodGet, server.URL+"/v1/exercises/"+id, nil)
	if err != nil {
		t.Fatalf("NewRequest failed: %v", err)
	}
	req.Header.Set("Authorization", "Bearer dev-learner-token")
	getResp, err := server.Client().Do(req)
	if err != nil {
		t.Fatalf("GET failed: %v", err)
	}
	defer getResp.Body.Close()

	var decoded map[string]any
	if err := json.NewDecoder(getResp.Body).Decode(&decoded); err != nil {
		t.Fatalf("decode failed: %v", err)
	}
	data := decoded["data"].(map[string]any)
	detail, _ := data["detail"].(map[string]any)
	if _, present := detail["display_prompt"]; present {
		t.Fatalf("non-interview skill must not have display_prompt; got %v", detail["display_prompt"])
	}
	if _, present := detail["audio_buffer_timeout_ms"]; present {
		t.Fatalf("non-interview skill must not have audio_buffer_timeout_ms; got %v", detail["audio_buffer_timeout_ms"])
	}
}
