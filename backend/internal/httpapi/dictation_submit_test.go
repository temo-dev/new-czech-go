package httpapi

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/processing"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

// newDictationSubmitTestServer seeds an exercise with the canonical dictation
// detail used by all submit-text tests below, returns the test server, the
// exercise ID, and the learner token.
func newDictationSubmitTestServer(t *testing.T) (*httptest.Server, string, string) {
	t.Helper()
	t.Setenv("LOCAL_ASSETS_DIR", t.TempDir())
	repo := store.NewMemoryStore()
	created := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "psani_3_dictation",
		SkillKind:    "viet",
		ModuleID:     "mod-viet",
		Status:       "published",
		Detail: contracts.DictationDetail{
			Topic: "Trong quán cafe",
			Sentences: []contracts.DictationSentence{
				{Idx: 0, Text: "Pavel jde do kavárny."},
				{Idx: 1, Text: "Chce si dát čaj."},
				{Idx: 2, Text: "Děkuji."},
			},
			MaxReplaysPerSentence: 3,
			VoiceID:               "Tomas",
			MaxPoints:             10,
			PassThresholdPercent:  60,
		},
	})
	processor := processing.NewProcessor(repo, nil, nil, nil, nil)
	srv := httptest.NewServer(NewServer(repo, processor, nil))
	t.Cleanup(srv.Close)
	return srv, created.ID, "dev-learner-token"
}

func createDictationAttempt(t *testing.T, srv *httptest.Server, exerciseID, token string) string {
	t.Helper()
	body := fmt.Sprintf(`{"exercise_id":%q,"locale":"vi","client_platform":"test"}`, exerciseID)
	req, _ := http.NewRequest(http.MethodPost, srv.URL+"/v1/attempts", strings.NewReader(body))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	resp, err := srv.Client().Do(req)
	if err != nil {
		t.Fatalf("create attempt: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("create attempt status: %d", resp.StatusCode)
	}
	var payload map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode: %v", err)
	}
	data, _ := payload["data"].(map[string]any)
	attempt, _ := data["attempt"].(map[string]any)
	id, _ := attempt["id"].(string)
	if id == "" {
		t.Fatalf("attempt id missing in response: %+v", payload)
	}
	return id
}

func submitDictation(t *testing.T, srv *httptest.Server, attemptID, token, body string) *http.Response {
	t.Helper()
	req, _ := http.NewRequest(http.MethodPost, srv.URL+"/v1/attempts/"+attemptID+"/submit-text", strings.NewReader(body))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	resp, err := srv.Client().Do(req)
	if err != nil {
		t.Fatalf("submit-text: %v", err)
	}
	return resp
}

// pollAttemptUntilCompleted blocks until status != "scoring", capped at ~3s.
func pollAttemptUntilCompleted(t *testing.T, srv *httptest.Server, attemptID, token string) map[string]any {
	t.Helper()
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) {
		req, _ := http.NewRequest(http.MethodGet, srv.URL+"/v1/attempts/"+attemptID, nil)
		req.Header.Set("Authorization", "Bearer "+token)
		resp, err := srv.Client().Do(req)
		if err != nil {
			t.Fatalf("poll attempt: %v", err)
		}
		var payload map[string]any
		_ = json.NewDecoder(resp.Body).Decode(&payload)
		resp.Body.Close()
		data, _ := payload["data"].(map[string]any)
		status, _ := data["status"].(string)
		if status != "scoring" && status != "" {
			return data
		}
		time.Sleep(50 * time.Millisecond)
	}
	t.Fatalf("attempt %s did not complete within 3s", attemptID)
	return nil
}

func TestSubmitDictation_HappyPerfectScore(t *testing.T) {
	srv, exerciseID, token := newDictationSubmitTestServer(t)
	attemptID := createDictationAttempt(t, srv, exerciseID, token)
	body := `{"sentences":[
		{"idx":0,"text":"Pavel jde do kavárny.","replay_count":1},
		{"idx":1,"text":"Chce si dát čaj.","replay_count":0},
		{"idx":2,"text":"Děkuji.","replay_count":2}
	]}`
	resp := submitDictation(t, srv, attemptID, token, body)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusAccepted {
		t.Fatalf("submit status: %d", resp.StatusCode)
	}

	data := pollAttemptUntilCompleted(t, srv, attemptID, token)
	feedback, _ := data["feedback"].(map[string]any)
	if feedback == nil {
		t.Fatalf("feedback missing: %+v", data)
	}
	dict, _ := feedback["dictation_result"].(map[string]any)
	if dict == nil {
		t.Fatalf("dictation_result missing: %+v", feedback)
	}
	score, _ := dict["overall_score"].(float64)
	if int(score) != 10 {
		t.Errorf("overall_score: %v", score)
	}
	passed, _ := dict["passed"].(bool)
	if !passed {
		t.Errorf("expected passed=true")
	}
	sentences, _ := dict["sentences"].([]any)
	if len(sentences) != 3 {
		t.Fatalf("sentences: %d", len(sentences))
	}
}

func TestSubmitDictation_AllDiacriticsMissingPassesAtFiftyPct(t *testing.T) {
	srv, exerciseID, token := newDictationSubmitTestServer(t)
	attemptID := createDictationAttempt(t, srv, exerciseID, token)
	// Strip every diacritic.
	body := `{"sentences":[
		{"idx":0,"text":"Pavel jde do kavarny.","replay_count":0},
		{"idx":1,"text":"Chce si dat caj.","replay_count":0},
		{"idx":2,"text":"Dekuji.","replay_count":0}
	]}`
	resp := submitDictation(t, srv, attemptID, token, body)
	resp.Body.Close()

	data := pollAttemptUntilCompleted(t, srv, attemptID, token)
	feedback, _ := data["feedback"].(map[string]any)
	dict, _ := feedback["dictation_result"].(map[string]any)
	score, _ := dict["overall_score"].(float64)
	if int(score) < 5 || int(score) > 9 {
		t.Errorf("expected 5..9 with all-diacritics-stripped, got %v", score)
	}
}

func TestSubmitDictation_WrongSentenceCount(t *testing.T) {
	srv, exerciseID, token := newDictationSubmitTestServer(t)
	attemptID := createDictationAttempt(t, srv, exerciseID, token)
	body := `{"sentences":[{"idx":0,"text":"x"}]}` // exercise has 3 sentences
	resp := submitDictation(t, srv, attemptID, token, body)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("status: %d", resp.StatusCode)
	}
	var body2 map[string]any
	_ = json.NewDecoder(resp.Body).Decode(&body2)
	errPayload, _ := body2["error"].(map[string]any)
	code, _ := errPayload["code"].(string)
	if code != "invalid_sentence_count" {
		t.Errorf("error code: %s — expected invalid_sentence_count", code)
	}
}

func TestSubmitDictation_SentenceTooLong(t *testing.T) {
	srv, exerciseID, token := newDictationSubmitTestServer(t)
	attemptID := createDictationAttempt(t, srv, exerciseID, token)
	long := strings.Repeat("á", 201)
	body := fmt.Sprintf(`{"sentences":[
		{"idx":0,"text":%q},
		{"idx":1,"text":"x"},
		{"idx":2,"text":"y"}
	]}`, long)
	resp := submitDictation(t, srv, attemptID, token, body)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("status: %d", resp.StatusCode)
	}
	var body2 map[string]any
	_ = json.NewDecoder(resp.Body).Decode(&body2)
	errPayload, _ := body2["error"].(map[string]any)
	code, _ := errPayload["code"].(string)
	if code != "sentence_too_long" {
		t.Errorf("error code: %s — expected sentence_too_long", code)
	}
}

func TestSubmitDictation_BodyTooLarge(t *testing.T) {
	srv, exerciseID, token := newDictationSubmitTestServer(t)
	attemptID := createDictationAttempt(t, srv, exerciseID, token)
	huge := strings.Repeat("x", 17*1024)
	body := fmt.Sprintf(`{"sentences":[{"idx":0,"text":%q}]}`, huge)
	resp := submitDictation(t, srv, attemptID, token, body)
	resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest && resp.StatusCode != http.StatusRequestEntityTooLarge {
		t.Errorf("expected 400/413 for oversized body, got %d", resp.StatusCode)
	}
}

func TestSubmitDictation_DevProviderFallsBackToFallbackFeedback(t *testing.T) {
	// Dev dictation provider returns nil annotations; ProcessDictationAttempt
	// must still complete and fill feedback_vi from dictationFallbackFeedback.
	srv, exerciseID, token := newDictationSubmitTestServer(t)
	attemptID := createDictationAttempt(t, srv, exerciseID, token)
	body := `{"sentences":[
		{"idx":0,"text":"Pavel jde do kavarny.","replay_count":0},
		{"idx":1,"text":"Chce si dat caj."},
		{"idx":2,"text":"Dekuji."}
	]}`
	resp := submitDictation(t, srv, attemptID, token, body)
	resp.Body.Close()

	data := pollAttemptUntilCompleted(t, srv, attemptID, token)
	feedback, _ := data["feedback"].(map[string]any)
	dict, _ := feedback["dictation_result"].(map[string]any)
	sentences, _ := dict["sentences"].([]any)
	if len(sentences) == 0 {
		t.Fatalf("sentences empty")
	}
	first, _ := sentences[0].(map[string]any)
	if first["feedback_vi"] == nil || first["feedback_vi"] == "" {
		t.Errorf("expected feedback_vi populated by fallback, got: %+v", first)
	}
}

func TestSubmitDictation_AlreadyScoringRejected(t *testing.T) {
	srv, exerciseID, token := newDictationSubmitTestServer(t)
	attemptID := createDictationAttempt(t, srv, exerciseID, token)
	body := `{"sentences":[
		{"idx":0,"text":"Pavel jde do kavárny."},
		{"idx":1,"text":"Chce si dát čaj."},
		{"idx":2,"text":"Děkuji."}
	]}`
	first := submitDictation(t, srv, attemptID, token, body)
	first.Body.Close()
	if first.StatusCode != http.StatusAccepted {
		t.Fatalf("first submit status: %d", first.StatusCode)
	}
	// Second submit on the same attempt must be rejected (status != "created").
	second := submitDictation(t, srv, attemptID, token, body)
	defer second.Body.Close()
	if second.StatusCode != http.StatusConflict {
		t.Errorf("second submit status: %d (expected 409)", second.StatusCode)
	}
}
