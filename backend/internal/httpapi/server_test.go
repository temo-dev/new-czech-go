package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/processing"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

func TestUploadURLUsesLocalUploadProviderByDefault(t *testing.T) {
	repo := store.NewMemoryStore()
	attempt, err := repo.CreateAttempt("user-learner-1", "exercise-uloha1-weather", "ios", "0.1.0", "vi")
	if err != nil {
		t.Fatalf("CreateAttempt returned error: %v", err)
	}

	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	response := postJSON(t, server, "/v1/attempts/"+attempt.ID+"/upload-url", map[string]any{
		"mime_type":       "audio/m4a",
		"file_size_bytes": 182044,
		"duration_ms":     18000,
	})

	upload := response["data"].(map[string]any)["upload"].(map[string]any)
	if upload["method"] != "PUT" {
		t.Fatalf("expected PUT upload method, got %v", upload["method"])
	}
	if !strings.HasPrefix(upload["url"].(string), server.URL+"/v1/attempts/"+attempt.ID+"/audio") {
		t.Fatalf("expected local upload URL, got %q", upload["url"])
	}
	headers := upload["headers"].(map[string]any)
	if headers["Content-Type"] != "audio/m4a" {
		t.Fatalf("expected Content-Type audio/m4a, got %v", headers["Content-Type"])
	}
	if upload["storage_key"] != "attempt-audio/"+attempt.ID+"/audio.m4a" {
		t.Fatalf("unexpected storage key %q", upload["storage_key"])
	}
}

func TestUploadURLUsesInjectedProviderContract(t *testing.T) {
	repo := store.NewMemoryStore()
	attempt, err := repo.CreateAttempt("user-learner-1", "exercise-uloha1-weather", "ios", "0.1.0", "vi")
	if err != nil {
		t.Fatalf("CreateAttempt returned error: %v", err)
	}

	provider := fakeUploadTargetProvider{
		target: contracts.UploadTarget{
			Method: "PUT",
			URL:    "https://s3.example.invalid/presigned-put",
			Headers: map[string]string{
				"Content-Type": "audio/m4a",
				"x-amz-meta":   "attempt-audio",
			},
			StorageKey:   "attempt-audio/" + attempt.ID + "/audio.m4a",
			ExpiresInSec: 900,
		},
	}
	server := httptest.NewServer(NewServer(repo, nil, provider))
	defer server.Close()

	response := postJSON(t, server, "/v1/attempts/"+attempt.ID+"/upload-url", map[string]any{
		"mime_type":       "audio/m4a",
		"file_size_bytes": 182044,
		"duration_ms":     18000,
	})

	upload := response["data"].(map[string]any)["upload"].(map[string]any)
	if upload["url"] != "https://s3.example.invalid/presigned-put" {
		t.Fatalf("expected injected upload URL, got %q", upload["url"])
	}
	headers := upload["headers"].(map[string]any)
	if headers["x-amz-meta"] != "attempt-audio" {
		t.Fatalf("expected injected headers to survive, got %v", headers)
	}
}

func TestUploadCompleteRejectsWithoutIssuedTarget(t *testing.T) {
	repo := store.NewMemoryStore()
	attempt, err := repo.CreateAttempt("user-learner-1", "exercise-uloha1-weather", "ios", "0.1.0", "vi")
	if err != nil {
		t.Fatalf("CreateAttempt returned error: %v", err)
	}

	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	status, response := postJSONAllowError(t, server, "/v1/attempts/"+attempt.ID+"/upload-complete", map[string]any{
		"storage_key":     "attempt-audio/" + attempt.ID + "/audio.m4a",
		"mime_type":       "audio/m4a",
		"duration_ms":     18000,
		"file_size_bytes": 182044,
	})

	if status != http.StatusConflict {
		t.Fatalf("expected 409 conflict, got %d", status)
	}
	errorPayload := response["error"].(map[string]any)
	if errorPayload["code"] != "conflict" {
		t.Fatalf("expected conflict error code, got %v", errorPayload["code"])
	}
}

func TestUploadCompleteRejectsMismatchedStorageKey(t *testing.T) {
	repo := store.NewMemoryStore()
	attempt, err := repo.CreateAttempt("user-learner-1", "exercise-uloha1-weather", "ios", "0.1.0", "vi")
	if err != nil {
		t.Fatalf("CreateAttempt returned error: %v", err)
	}

	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	postJSON(t, server, "/v1/attempts/"+attempt.ID+"/upload-url", map[string]any{
		"mime_type":       "audio/m4a",
		"file_size_bytes": 182044,
		"duration_ms":     18000,
	})

	status, response := postJSONAllowError(t, server, "/v1/attempts/"+attempt.ID+"/upload-complete", map[string]any{
		"storage_key":     "attempt-audio/other-attempt/audio.m4a",
		"mime_type":       "audio/m4a",
		"duration_ms":     18000,
		"file_size_bytes": 182044,
	})

	if status != http.StatusConflict {
		t.Fatalf("expected 409 conflict, got %d", status)
	}
	errorPayload := response["error"].(map[string]any)
	if errorPayload["code"] != "conflict" {
		t.Fatalf("expected conflict error code, got %v", errorPayload["code"])
	}
}

func TestUploadCompleteUsesIssuedStorageKeyWhenBodyOmitsIt(t *testing.T) {
	repo := store.NewMemoryStore()
	attempt, err := repo.CreateAttempt("user-learner-1", "exercise-uloha1-weather", "ios", "0.1.0", "vi")
	if err != nil {
		t.Fatalf("CreateAttempt returned error: %v", err)
	}

	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	response := postJSON(t, server, "/v1/attempts/"+attempt.ID+"/upload-url", map[string]any{
		"mime_type":       "audio/m4a",
		"file_size_bytes": 182044,
		"duration_ms":     18000,
	})
	expectedStorageKey := response["data"].(map[string]any)["upload"].(map[string]any)["storage_key"]

	postJSON(t, server, "/v1/attempts/"+attempt.ID+"/upload-complete", map[string]any{
		"mime_type":       "audio/m4a",
		"duration_ms":     18000,
		"file_size_bytes": 182044,
	})

	storedAttempt, ok := repo.Attempt(attempt.ID)
	if !ok {
		t.Fatalf("expected attempt %s after upload completion", attempt.ID)
	}
	if storedAttempt.Audio == nil || storedAttempt.Audio.StorageKey != expectedStorageKey {
		t.Fatalf("expected stored audio key %q, got %+v", expectedStorageKey, storedAttempt.Audio)
	}
}

func TestLocalBinaryUploadUsesExpectedFileExtensionForAudioMP4(t *testing.T) {
	repo := store.NewMemoryStore()
	attempt, err := repo.CreateAttempt("user-learner-1", "exercise-uloha1-weather", "ios", "0.1.0", "vi")
	if err != nil {
		t.Fatalf("CreateAttempt returned error: %v", err)
	}

	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	request, err := http.NewRequest(http.MethodPut, server.URL+"/v1/attempts/"+attempt.ID+"/audio", strings.NewReader("fake-audio"))
	if err != nil {
		t.Fatalf("NewRequest failed: %v", err)
	}
	request.Header.Set("Authorization", "Bearer dev-learner-token")
	request.Header.Set("Content-Type", "audio/mp4")

	response, err := server.Client().Do(request)
	if err != nil {
		t.Fatalf("Do failed: %v", err)
	}
	defer response.Body.Close()

	if response.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(response.Body)
		t.Fatalf("expected 200, got %d with body %s", response.StatusCode, string(body))
	}

	var decoded map[string]any
	if err := json.NewDecoder(response.Body).Decode(&decoded); err != nil {
		t.Fatalf("Decode failed: %v", err)
	}

	data := decoded["data"].(map[string]any)
	if !strings.HasSuffix(data["stored_file_path"].(string), ".mp4") {
		t.Fatalf("expected stored file path to end with .mp4, got %q", data["stored_file_path"])
	}
}

func TestLearnerCanFetchCompletedAttemptAudioFile(t *testing.T) {
	repo := store.NewMemoryStore()
	attempt, err := repo.CreateAttempt("user-learner-1", "exercise-uloha1-weather", "ios", "0.1.0", "vi")
	if err != nil {
		t.Fatalf("CreateAttempt returned error: %v", err)
	}

	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	uploadURLResponse := postJSON(t, server, "/v1/attempts/"+attempt.ID+"/upload-url", map[string]any{
		"mime_type":       "audio/m4a",
		"file_size_bytes": 9,
		"duration_ms":     8000,
	})
	uploadURL := uploadURLResponse["data"].(map[string]any)["upload"].(map[string]any)["url"].(string)

	request, err := http.NewRequest(http.MethodPut, uploadURL, bytes.NewReader([]byte("hello-a2")))
	if err != nil {
		t.Fatalf("NewRequest failed: %v", err)
	}
	request.Header.Set("Authorization", "Bearer dev-learner-token")
	request.Header.Set("Content-Type", "audio/m4a")

	response, err := server.Client().Do(request)
	if err != nil {
		t.Fatalf("Do failed: %v", err)
	}
	defer response.Body.Close()

	if response.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(response.Body)
		t.Fatalf("expected 200 from audio upload, got %d with body %s", response.StatusCode, string(body))
	}

	var uploadResult map[string]any
	if err := json.NewDecoder(response.Body).Decode(&uploadResult); err != nil {
		t.Fatalf("Decode failed: %v", err)
	}
	uploadedAudio := uploadResult["data"].(map[string]any)

	postJSON(t, server, "/v1/attempts/"+attempt.ID+"/upload-complete", map[string]any{
		"storage_key":      uploadedAudio["storage_key"],
		"mime_type":        "audio/m4a",
		"duration_ms":      8000,
		"file_size_bytes":  9,
		"stored_file_path": uploadedAudio["stored_file_path"],
	})

	fileRequest, err := http.NewRequest(http.MethodGet, server.URL+"/v1/attempts/"+attempt.ID+"/audio/file", nil)
	if err != nil {
		t.Fatalf("NewRequest failed: %v", err)
	}
	fileRequest.Header.Set("Authorization", "Bearer dev-learner-token")

	fileResponse, err := server.Client().Do(fileRequest)
	if err != nil {
		t.Fatalf("Do failed: %v", err)
	}
	defer fileResponse.Body.Close()

	if fileResponse.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(fileResponse.Body)
		t.Fatalf("expected 200 from learner attempt audio file, got %d with body %s", fileResponse.StatusCode, string(body))
	}
	if fileResponse.Header.Get("Content-Type") != "audio/m4a" {
		t.Fatalf("expected audio/m4a content type, got %q", fileResponse.Header.Get("Content-Type"))
	}

	body, err := io.ReadAll(fileResponse.Body)
	if err != nil {
		t.Fatalf("ReadAll failed: %v", err)
	}
	if string(body) != "hello-a2" {
		t.Fatalf("expected stored audio bytes to round-trip, got %q", string(body))
	}
}

func TestLearnerCanFetchPendingAttemptReviewArtifact(t *testing.T) {
	repo := store.NewMemoryStore()
	attempt, err := repo.CreateAttempt("user-learner-1", "exercise-uloha1-weather", "ios", "0.1.0", "vi")
	if err != nil {
		t.Fatalf("CreateAttempt returned error: %v", err)
	}

	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	request, err := http.NewRequest(http.MethodGet, server.URL+"/v1/attempts/"+attempt.ID+"/review", nil)
	if err != nil {
		t.Fatalf("NewRequest failed: %v", err)
	}
	request.Header.Set("Authorization", "Bearer dev-learner-token")

	response, err := server.Client().Do(request)
	if err != nil {
		t.Fatalf("Do failed: %v", err)
	}
	defer response.Body.Close()

	if response.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(response.Body)
		t.Fatalf("expected 200, got %d with body %s", response.StatusCode, string(body))
	}

	var decoded map[string]any
	if err := json.NewDecoder(response.Body).Decode(&decoded); err != nil {
		t.Fatalf("Decode failed: %v", err)
	}

	data := decoded["data"].(map[string]any)
	if data["attempt_id"] != attempt.ID {
		t.Fatalf("expected attempt id %q, got %v", attempt.ID, data["attempt_id"])
	}
	if data["status"] != "pending" {
		t.Fatalf("expected pending review artifact, got %v", data["status"])
	}
}

func TestLearnerCanFetchReadyAttemptReviewArtifact(t *testing.T) {
	repo := store.NewMemoryStore()
	attempt, err := repo.CreateAttempt("user-learner-1", "exercise-uloha1-weather", "ios", "0.1.0", "vi")
	if err != nil {
		t.Fatalf("CreateAttempt returned error: %v", err)
	}
	if _, ok := repo.UpsertReviewArtifact(attempt.ID, contracts.AttemptReviewArtifact{
		Status:                  "ready",
		SourceTranscriptText:    "dobry den ja mam rad pocasi",
		CorrectedTranscriptText: "Dobry den, mam rad pocasi.",
		ModelAnswerText:         "Mam rad teple pocasi, protoze muzu byt venku.",
		RepairProvider:          "task_aware_repair_v1",
		GeneratedAt:             "2026-04-23T10:00:00Z",
		TTSAudio: &contracts.ReviewArtifactAudio{
			StorageKey: "attempt-review/" + attempt.ID + "/model-answer.wav",
			MimeType:   "audio/wav",
		},
	}); !ok {
		t.Fatalf("expected review artifact to persist")
	}

	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	request, err := http.NewRequest(http.MethodGet, server.URL+"/v1/attempts/"+attempt.ID+"/review", nil)
	if err != nil {
		t.Fatalf("NewRequest failed: %v", err)
	}
	request.Header.Set("Authorization", "Bearer dev-learner-token")

	response, err := server.Client().Do(request)
	if err != nil {
		t.Fatalf("Do failed: %v", err)
	}
	defer response.Body.Close()

	if response.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(response.Body)
		t.Fatalf("expected 200, got %d with body %s", response.StatusCode, string(body))
	}

	var decoded map[string]any
	if err := json.NewDecoder(response.Body).Decode(&decoded); err != nil {
		t.Fatalf("Decode failed: %v", err)
	}

	data := decoded["data"].(map[string]any)
	if data["status"] != "ready" {
		t.Fatalf("expected ready review artifact, got %v", data["status"])
	}
	if data["model_answer_text"] != "Mam rad teple pocasi, protoze muzu byt venku." {
		t.Fatalf("unexpected model answer %v", data["model_answer_text"])
	}
	ttsAudio := data["tts_audio"].(map[string]any)
	if ttsAudio["mime_type"] != "audio/wav" {
		t.Fatalf("expected audio/wav TTS mime type, got %v", ttsAudio["mime_type"])
	}
}

func TestAttemptReviewRequiresOwnership(t *testing.T) {
	repo := store.NewMemoryStore()
	attempt, err := repo.CreateAttempt("user-learner-1", "exercise-uloha1-weather", "ios", "0.1.0", "vi")
	if err != nil {
		t.Fatalf("CreateAttempt returned error: %v", err)
	}

	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	request, err := http.NewRequest(http.MethodGet, server.URL+"/v1/attempts/"+attempt.ID+"/review", nil)
	if err != nil {
		t.Fatalf("NewRequest failed: %v", err)
	}
	request.Header.Set("Authorization", "Bearer dev-learner-2-token")

	response, err := server.Client().Do(request)
	if err != nil {
		t.Fatalf("Do failed: %v", err)
	}
	defer response.Body.Close()

	if response.StatusCode != http.StatusForbidden {
		body, _ := io.ReadAll(response.Body)
		t.Fatalf("expected 403, got %d with body %s", response.StatusCode, string(body))
	}
}

func TestAttemptReviewNotFoundForMissingAttempt(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	request, err := http.NewRequest(http.MethodGet, server.URL+"/v1/attempts/attempt-missing/review", nil)
	if err != nil {
		t.Fatalf("NewRequest failed: %v", err)
	}
	request.Header.Set("Authorization", "Bearer dev-learner-token")

	response, err := server.Client().Do(request)
	if err != nil {
		t.Fatalf("Do failed: %v", err)
	}
	defer response.Body.Close()

	if response.StatusCode != http.StatusNotFound {
		body, _ := io.ReadAll(response.Body)
		t.Fatalf("expected 404, got %d with body %s", response.StatusCode, string(body))
	}
}

func TestLearnerCanFetchAttemptReviewAudioFile(t *testing.T) {
	repo := store.NewMemoryStore()
	attempt, err := repo.CreateAttempt("user-learner-1", "exercise-uloha1-weather", "ios", "0.1.0", "vi")
	if err != nil {
		t.Fatalf("CreateAttempt returned error: %v", err)
	}

	audio := &contracts.ReviewArtifactAudio{
		StorageKey: "attempt-review/" + attempt.ID + "/model-answer.wav",
		MimeType:   "audio/wav",
	}
	if _, ok := repo.UpsertReviewArtifact(attempt.ID, contracts.AttemptReviewArtifact{
		Status:               "ready",
		SourceTranscriptText: "dobry den",
		ModelAnswerText:      "Dobry den.",
		TTSAudio:             audio,
	}); !ok {
		t.Fatalf("expected review artifact to persist")
	}

	filePath := processing.ReviewAudioLocalPath(audio.StorageKey)
	if err := os.MkdirAll(filepath.Dir(filePath), 0o755); err != nil {
		t.Fatalf("MkdirAll failed: %v", err)
	}
	if err := os.WriteFile(filePath, []byte("fake-review-audio"), 0o644); err != nil {
		t.Fatalf("WriteFile failed: %v", err)
	}

	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	request, err := http.NewRequest(http.MethodGet, server.URL+"/v1/attempts/"+attempt.ID+"/review/audio/file", nil)
	if err != nil {
		t.Fatalf("NewRequest failed: %v", err)
	}
	request.Header.Set("Authorization", "Bearer dev-learner-token")

	response, err := server.Client().Do(request)
	if err != nil {
		t.Fatalf("Do failed: %v", err)
	}
	defer response.Body.Close()

	if response.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(response.Body)
		t.Fatalf("expected 200, got %d with body %s", response.StatusCode, string(body))
	}
	if response.Header.Get("Content-Type") != "audio/wav" {
		t.Fatalf("expected audio/wav content type, got %q", response.Header.Get("Content-Type"))
	}
	body, err := io.ReadAll(response.Body)
	if err != nil {
		t.Fatalf("ReadAll failed: %v", err)
	}
	if string(body) != "fake-review-audio" {
		t.Fatalf("expected stored review audio bytes to round-trip, got %q", string(body))
	}
}

func TestAttemptReviewAudioReturnsNotFoundWithoutTTSAudio(t *testing.T) {
	repo := store.NewMemoryStore()
	attempt, err := repo.CreateAttempt("user-learner-1", "exercise-uloha1-weather", "ios", "0.1.0", "vi")
	if err != nil {
		t.Fatalf("CreateAttempt returned error: %v", err)
	}

	if _, ok := repo.UpsertReviewArtifact(attempt.ID, contracts.AttemptReviewArtifact{
		Status:               "ready",
		SourceTranscriptText: "dobry den",
		ModelAnswerText:      "Dobry den.",
	}); !ok {
		t.Fatalf("expected review artifact to persist")
	}

	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	request, err := http.NewRequest(http.MethodGet, server.URL+"/v1/attempts/"+attempt.ID+"/review/audio/file", nil)
	if err != nil {
		t.Fatalf("NewRequest failed: %v", err)
	}
	request.Header.Set("Authorization", "Bearer dev-learner-token")

	response, err := server.Client().Do(request)
	if err != nil {
		t.Fatalf("Do failed: %v", err)
	}
	defer response.Body.Close()

	if response.StatusCode != http.StatusNotFound {
		body, _ := io.ReadAll(response.Body)
		t.Fatalf("expected 404, got %d with body %s", response.StatusCode, string(body))
	}
}

func TestListAttemptsReturnsOnlyCurrentLearnerAndNewestFirst(t *testing.T) {
	repo := store.NewMemoryStore()

	first, err := repo.CreateAttempt("user-learner-1", "exercise-uloha1-weather", "ios", "0.1.0", "vi")
	if err != nil {
		t.Fatalf("CreateAttempt returned error: %v", err)
	}
	time.Sleep(10 * time.Millisecond)
	second, err := repo.CreateAttempt("user-learner-1", "exercise-uloha2-cinema", "ios", "0.1.0", "vi")
	if err != nil {
		t.Fatalf("CreateAttempt returned error: %v", err)
	}
	if _, err := repo.CreateAttempt("user-learner-2", "exercise-uloha1-weather", "ios", "0.1.0", "vi"); err != nil {
		t.Fatalf("CreateAttempt returned error: %v", err)
	}

	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	request, err := http.NewRequest(http.MethodGet, server.URL+"/v1/attempts", nil)
	if err != nil {
		t.Fatalf("NewRequest failed: %v", err)
	}
	request.Header.Set("Authorization", "Bearer dev-learner-token")

	response, err := server.Client().Do(request)
	if err != nil {
		t.Fatalf("Do failed: %v", err)
	}
	defer response.Body.Close()

	if response.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(response.Body)
		t.Fatalf("expected 200, got %d with body %s", response.StatusCode, string(body))
	}

	var decoded map[string]any
	if err := json.NewDecoder(response.Body).Decode(&decoded); err != nil {
		t.Fatalf("Decode failed: %v", err)
	}

	items := decoded["data"].([]any)
	if len(items) != 2 {
		t.Fatalf("expected 2 visible attempts, got %d", len(items))
	}

	firstItem := items[0].(map[string]any)
	secondItem := items[1].(map[string]any)
	if firstItem["id"] != second.ID {
		t.Fatalf("expected newest attempt %q first, got %v", second.ID, firstItem["id"])
	}
	if secondItem["id"] != first.ID {
		t.Fatalf("expected older attempt %q second, got %v", first.ID, secondItem["id"])
	}
	if firstItem["user_id"] != "user-learner-1" || secondItem["user_id"] != "user-learner-1" {
		t.Fatalf("expected only learner-owned attempts, got %+v", items)
	}
}

func TestExtensionForMimeSupportsCommonRecorderAliases(t *testing.T) {
	cases := map[string]string{
		"audio/mp4a-latm": "m4a",
		"audio/x-m4a":     "m4a",
		"audio/x-wav":     "wav",
		"audio/wave":      "wav",
	}

	for mimeType, expected := range cases {
		if actual := extensionForMime(mimeType); actual != expected {
			t.Fatalf("expected extension %q for %q, got %q", expected, mimeType, actual)
		}
	}
}

func TestAdminCreateExerciseSupportsUloha2Detail(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	response := postJSONWithToken(t, server, "/v1/admin/exercises", "dev-admin-token", map[string]any{
		"module_id":                "module-day-1",
		"exercise_type":            "uloha_2_dialogue_questions",
		"title":                    "Boty v obchode",
		"short_instruction":        "Zeptejte se na chybejici informace o botach.",
		"learner_instruction":      "Ban can hoi thong tin con thieu khi mua boty.",
		"estimated_duration_sec":   90,
		"prep_time_sec":            10,
		"recording_time_limit_sec": 45,
		"sample_answer_enabled":    true,
		"detail": map[string]any{
			"scenario_title":  "Nakup bot",
			"scenario_prompt": "Jste v obchode a chcete zjistit velikost, cenu a material bot.",
			"required_info_slots": []map[string]any{
				{"slot_key": "size", "label": "Velikost", "sample_question": "Mate velikost 39?"},
				{"slot_key": "price", "label": "Cena", "sample_question": "Kolik ty boty stoji?"},
				{"slot_key": "material", "label": "Material", "sample_question": "Z jakeho materialu jsou?"},
			},
			"custom_question_hint": "Zeptejte se jeste na slevu.",
		},
	})

	data := response["data"].(map[string]any)
	if data["exercise_type"] != "uloha_2_dialogue_questions" {
		t.Fatalf("expected uloha 2 exercise type, got %v", data["exercise_type"])
	}

	detail := data["detail"].(map[string]any)
	if detail["scenario_title"] != "Nakup bot" {
		t.Fatalf("expected scenario title to round-trip, got %v", detail["scenario_title"])
	}
	requiredSlots := detail["required_info_slots"].([]any)
	if len(requiredSlots) != 3 {
		t.Fatalf("expected 3 required info slots, got %d", len(requiredSlots))
	}
}

func TestAdminCreateExerciseSupportsUloha3Detail(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	response := postJSONWithToken(t, server, "/v1/admin/exercises", "dev-admin-token", map[string]any{
		"module_id":                "module-day-2",
		"exercise_type":            "uloha_3_story_narration",
		"title":                    "Cesta vlakem",
		"short_instruction":        "Vypravejte pribeh podle 4 obrazku.",
		"learner_instruction":      "Ban ke lai trinh tu cau chuyen bang qua khu.",
		"estimated_duration_sec":   120,
		"prep_time_sec":            15,
		"recording_time_limit_sec": 60,
		"sample_answer_enabled":    true,
		"detail": map[string]any{
			"story_title": "Cesta vlakem",
			"image_asset_ids": []string{
				"asset-train-1",
				"asset-train-2",
				"asset-train-3",
				"asset-train-4",
			},
			"narrative_checkpoints": []string{
				"Prisli na nadrazi.",
				"Koupili si listky.",
				"Nastoupili do vlaku.",
				"Dojeli do mesta.",
			},
			"grammar_focus": []string{"past_tense"},
		},
	})

	data := response["data"].(map[string]any)
	if data["exercise_type"] != "uloha_3_story_narration" {
		t.Fatalf("expected uloha 3 exercise type, got %v", data["exercise_type"])
	}

	detail := data["detail"].(map[string]any)
	if detail["story_title"] != "Cesta vlakem" {
		t.Fatalf("expected story title to round-trip, got %v", detail["story_title"])
	}
	checkpoints := detail["narrative_checkpoints"].([]any)
	if len(checkpoints) != 4 {
		t.Fatalf("expected 4 narrative checkpoints, got %d", len(checkpoints))
	}
}

func TestAdminCreateExerciseSupportsUloha4Detail(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	response := postJSONWithToken(t, server, "/v1/admin/exercises", "dev-admin-token", map[string]any{
		"module_id":                "module-day-2",
		"exercise_type":            "uloha_4_choice_reasoning",
		"title":                    "Doprava do prace",
		"short_instruction":        "Vyberte jednu moznost a vysvetlete proc.",
		"learner_instruction":      "Ban can chon mot phuong an roi giai thich.",
		"estimated_duration_sec":   90,
		"prep_time_sec":            10,
		"recording_time_limit_sec": 45,
		"sample_answer_enabled":    true,
		"detail": map[string]any{
			"scenario_prompt": "Jak pojedete do prace?",
			"options": []map[string]any{
				{"option_key": "bus", "label": "Autobus", "description": "Levny a pomaly."},
				{"option_key": "metro", "label": "Metro", "description": "Rychle a pohodlne."},
				{"option_key": "bike", "label": "Kolo", "description": "Zdrave, ale narocne."},
			},
			"expected_reasoning_axes": []string{"price", "speed"},
		},
	})

	data := response["data"].(map[string]any)
	if data["exercise_type"] != "uloha_4_choice_reasoning" {
		t.Fatalf("expected uloha 4 exercise type, got %v", data["exercise_type"])
	}

	detail := data["detail"].(map[string]any)
	options := detail["options"].([]any)
	if len(options) != 3 {
		t.Fatalf("expected 3 options, got %d", len(options))
	}
}

func TestAdminDeleteExerciseRemovesItem(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	created := postJSONWithToken(t, server, "/v1/admin/exercises", "dev-admin-token", map[string]any{
		"module_id":              "module-day-1",
		"exercise_type":          "uloha_1_topic_answers",
		"title":                  "Delete me",
		"short_instruction":      "Delete me",
		"learner_instruction":    "Delete me",
		"estimated_duration_sec": 90,
		"sample_answer_enabled":  true,
		"questions":              []string{"Kde bydlite?"},
	})

	id := created["data"].(map[string]any)["id"].(string)

	request, err := http.NewRequest(http.MethodDelete, server.URL+"/v1/admin/exercises/"+id, nil)
	if err != nil {
		t.Fatalf("NewRequest failed: %v", err)
	}
	request.Header.Set("Authorization", "Bearer dev-admin-token")

	response, err := server.Client().Do(request)
	if err != nil {
		t.Fatalf("Do failed: %v", err)
	}
	defer response.Body.Close()

	if response.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(response.Body)
		t.Fatalf("expected 200, got %d with body %s", response.StatusCode, string(body))
	}

	if _, ok := repo.Exercise(id); ok {
		t.Fatalf("expected exercise %s to be removed", id)
	}
}

func TestAdminPatchExerciseUpdatesTypedDetail(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	body, err := json.Marshal(map[string]any{
		"title":                    "Kino rano",
		"short_instruction":        "Zeptejte se na nove informace.",
		"learner_instruction":      "Ban can hoi thong tin moi ve navsteve kina.",
		"module_id":                "module-day-1",
		"exercise_type":            "uloha_2_dialogue_questions",
		"estimated_duration_sec":   90,
		"prep_time_sec":            10,
		"recording_time_limit_sec": 45,
		"sample_answer_enabled":    true,
		"detail": map[string]any{
			"scenario_title":  "Ranni kino",
			"scenario_prompt": "Chcete jit rano do kina a potrebujete zjistit cas, cenu a slevu.",
			"required_info_slots": []map[string]any{
				{"slot_key": "start_time", "label": "Cas zacatku", "sample_question": "V kolik hodin film zacina?"},
				{"slot_key": "price", "label": "Cena", "sample_question": "Kolik stoji listek?"},
				{"slot_key": "discount", "label": "Sleva", "sample_question": "Mate studentskou slevu?"},
			},
			"custom_question_hint": "Zeptejte se take na sal.",
		},
	})
	if err != nil {
		t.Fatalf("Marshal failed: %v", err)
	}

	request, err := http.NewRequest(http.MethodPatch, server.URL+"/v1/admin/exercises/exercise-uloha2-cinema", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("NewRequest failed: %v", err)
	}
	request.Header.Set("Authorization", "Bearer dev-admin-token")
	request.Header.Set("Content-Type", "application/json")

	response, err := server.Client().Do(request)
	if err != nil {
		t.Fatalf("Do failed: %v", err)
	}
	defer response.Body.Close()

	if response.StatusCode != http.StatusOK {
		payload, _ := io.ReadAll(response.Body)
		t.Fatalf("expected 200, got %d with body %s", response.StatusCode, string(payload))
	}

	updated, ok := repo.Exercise("exercise-uloha2-cinema")
	if !ok {
		t.Fatal("expected updated exercise to exist")
	}

	if updated.Title != "Kino rano" {
		t.Fatalf("expected updated title, got %q", updated.Title)
	}

	detail, ok := updated.Detail.(map[string]any)
	if !ok {
		t.Fatalf("expected detail to decode into map[string]any via PATCH JSON, got %T", updated.Detail)
	}

	if detail["scenario_title"] != "Ranni kino" {
		t.Fatalf("expected updated scenario title, got %v", detail["scenario_title"])
	}

	requiredInfoSlots, ok := detail["required_info_slots"].([]any)
	if !ok {
		t.Fatalf("expected required_info_slots array, got %T", detail["required_info_slots"])
	}
	if len(requiredInfoSlots) != 3 {
		t.Fatalf("expected 3 required info slots, got %d", len(requiredInfoSlots))
	}
}

func TestAdminAssetUploadRegisterAndPreview(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	uploadTarget := postJSONWithToken(t, server, "/v1/admin/exercises/exercise-uloha3-tv/assets/upload-url", "dev-admin-token", map[string]any{
		"asset_kind": "image",
		"mime_type":  "image/png",
	})

	uploadData := uploadTarget["data"].(map[string]any)
	assetMeta := uploadData["asset"].(map[string]any)
	upload := uploadData["upload"].(map[string]any)
	assetID := assetMeta["id"].(string)
	storageKey := upload["storage_key"].(string)

	request, err := http.NewRequest(http.MethodPut, upload["url"].(string), bytes.NewReader([]byte("fake-image-bytes")))
	if err != nil {
		t.Fatalf("NewRequest failed: %v", err)
	}
	request.Header.Set("Authorization", "Bearer dev-admin-token")
	request.Header.Set("Content-Type", "image/png")

	response, err := server.Client().Do(request)
	if err != nil {
		t.Fatalf("Do failed: %v", err)
	}
	defer response.Body.Close()

	if response.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(response.Body)
		t.Fatalf("expected 200 from blob upload, got %d with body %s", response.StatusCode, string(body))
	}

	registered := postJSONWithToken(t, server, "/v1/admin/exercises/exercise-uloha3-tv/assets", "dev-admin-token", map[string]any{
		"id":          assetID,
		"asset_kind":  "image",
		"storage_key": storageKey,
		"mime_type":   "image/png",
		"sequence_no": 3,
	})

	asset := registered["data"].(map[string]any)["asset"].(map[string]any)
	if asset["id"] != assetID {
		t.Fatalf("expected asset id %q, got %v", assetID, asset["id"])
	}

	exercise, ok := repo.Exercise("exercise-uloha3-tv")
	if !ok {
		t.Fatal("expected exercise to exist")
	}
	if len(exercise.Assets) != 1 {
		t.Fatalf("expected 1 registered asset, got %d", len(exercise.Assets))
	}

	fileRequest, err := http.NewRequest(http.MethodGet, server.URL+"/v1/admin/exercises/exercise-uloha3-tv/assets/"+assetID+"/file", nil)
	if err != nil {
		t.Fatalf("NewRequest failed: %v", err)
	}
	fileRequest.Header.Set("Authorization", "Bearer dev-admin-token")

	fileResponse, err := server.Client().Do(fileRequest)
	if err != nil {
		t.Fatalf("Do failed: %v", err)
	}
	defer fileResponse.Body.Close()

	if fileResponse.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(fileResponse.Body)
		t.Fatalf("expected 200 from asset file, got %d with body %s", fileResponse.StatusCode, string(body))
	}
	if fileResponse.Header.Get("Content-Type") != "image/png" {
		t.Fatalf("expected image/png content type, got %q", fileResponse.Header.Get("Content-Type"))
	}

	body, err := io.ReadAll(fileResponse.Body)
	if err != nil {
		t.Fatalf("ReadAll failed: %v", err)
	}
	if string(body) != "fake-image-bytes" {
		t.Fatalf("expected stored asset bytes to round-trip, got %q", string(body))
	}

	learnerFileRequest, err := http.NewRequest(http.MethodGet, server.URL+"/v1/exercises/exercise-uloha3-tv/assets/"+assetID+"/file", nil)
	if err != nil {
		t.Fatalf("NewRequest failed: %v", err)
	}
	learnerFileRequest.Header.Set("Authorization", "Bearer dev-learner-token")

	learnerFileResponse, err := server.Client().Do(learnerFileRequest)
	if err != nil {
		t.Fatalf("Do failed: %v", err)
	}
	defer learnerFileResponse.Body.Close()

	if learnerFileResponse.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(learnerFileResponse.Body)
		t.Fatalf("expected 200 from learner asset file, got %d with body %s", learnerFileResponse.StatusCode, string(body))
	}
}

func postJSON(t *testing.T, server *httptest.Server, path string, body map[string]any) map[string]any {
	t.Helper()
	status, decoded := postJSONAllowError(t, server, path, body)
	if status >= 400 {
		t.Fatalf("unexpected status %d", status)
	}
	return decoded
}

func postJSONWithToken(t *testing.T, server *httptest.Server, path, token string, body map[string]any) map[string]any {
	t.Helper()
	status, decoded := postJSONAllowErrorWithToken(t, server, path, token, body)
	if status >= 400 {
		t.Fatalf("unexpected status %d", status)
	}
	return decoded
}

func postJSONAllowError(t *testing.T, server *httptest.Server, path string, body map[string]any) (int, map[string]any) {
	t.Helper()
	return postJSONAllowErrorWithToken(t, server, path, "dev-learner-token", body)
}

func postJSONAllowErrorWithToken(t *testing.T, server *httptest.Server, path, token string, body map[string]any) (int, map[string]any) {
	t.Helper()

	payload, err := json.Marshal(body)
	if err != nil {
		t.Fatalf("json.Marshal failed: %v", err)
	}

	request, err := http.NewRequest(http.MethodPost, server.URL+path, bytes.NewReader(payload))
	if err != nil {
		t.Fatalf("NewRequest failed: %v", err)
	}
	request.Header.Set("Authorization", "Bearer "+token)
	request.Header.Set("Content-Type", "application/json")

	response, err := server.Client().Do(request)
	if err != nil {
		t.Fatalf("Do failed: %v", err)
	}
	defer response.Body.Close()

	var decoded map[string]any
	if err := json.NewDecoder(response.Body).Decode(&decoded); err != nil {
		t.Fatalf("Decode failed: %v", err)
	}
	return response.StatusCode, decoded
}

type fakeUploadTargetProvider struct {
	target contracts.UploadTarget
	err    error
}

func (f fakeUploadTargetProvider) CreateAttemptUploadTarget(_ context.Context, _ AttemptUploadTargetInput) (contracts.UploadTarget, error) {
	return f.target, f.err
}
