package httpapi

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

// V37 — admin generate-audio for a single vocab item. Reuses the existing
// PollyExerciseAudioGenerator under the hood; the handler asks for a Polly
// MP3 of `item.Term` and persists the resulting storage_key on the
// vocabulary_items row.

func newVocabAudioServer(t *testing.T) (*httptest.Server, *store.MemoryStore, string) {
	t.Helper()
	repo := store.NewMemoryStore()
	srv := httptest.NewServer(NewServer(repo, nil, nil))
	t.Cleanup(srv.Close)
	set, err := repo.CreateVocabularySet(contracts.VocabularySet{
		ModuleID: "module-1",
		Title:    "Pocasi",
		Level:    "A2",
		Status:   "published",
	})
	if err != nil {
		t.Fatalf("CreateVocabularySet: %v", err)
	}
	item := repo.CreateVocabularyItem(contracts.VocabularyItem{
		SetID: set.ID,
		Term:  "počasí",
	})
	return srv, repo, item.ID
}

func postVocabGenerateAudio(t *testing.T, srv *httptest.Server, itemID string) (int, map[string]any) {
	t.Helper()
	req, err := http.NewRequest(http.MethodPost,
		srv.URL+"/v1/admin/vocabulary-items/"+itemID+"/generate-audio",
		strings.NewReader(`{}`))
	if err != nil {
		t.Fatalf("NewRequest: %v", err)
	}
	req.Header.Set("Authorization", "Bearer dev-admin-token")
	req.Header.Set("Content-Type", "application/json")
	resp, err := srv.Client().Do(req)
	if err != nil {
		t.Fatalf("Do: %v", err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	var body map[string]any
	if len(raw) > 0 {
		_ = json.Unmarshal(raw, &body)
	}
	return resp.StatusCode, body
}

func TestVocabItemGenerateAudio_HappyPath(t *testing.T) {
	srv, repo, itemID := newVocabAudioServer(t)
	status, body := postVocabGenerateAudio(t, srv, itemID)
	if status != http.StatusOK {
		t.Fatalf("status = %d, want 200; body=%v", status, body)
	}
	data, ok := body["data"].(map[string]any)
	if !ok {
		t.Fatalf("expected data object; got %v", body)
	}
	storageKey, _ := data["audio_storage_key"].(string)
	if storageKey == "" {
		t.Fatalf("audio_storage_key empty in response; data=%v", data)
	}
	got, ok := repo.GetVocabularyItem(itemID)
	if !ok {
		t.Fatalf("item missing after generate")
	}
	if got.AudioStorageKey == "" {
		t.Errorf("AudioStorageKey not persisted on item")
	}
	if got.AudioStorageKey != storageKey {
		t.Errorf("response storage_key %q != persisted %q", storageKey, got.AudioStorageKey)
	}
}

func TestVocabItemGenerateAudio_NotFound(t *testing.T) {
	srv, _, _ := newVocabAudioServer(t)
	status, body := postVocabGenerateAudio(t, srv, "nope")
	if status != http.StatusNotFound {
		t.Fatalf("status = %d, want 404; body=%v", status, body)
	}
}

func TestVocabItemGenerateAudio_EmptyTermRejected(t *testing.T) {
	srv, repo, _ := newVocabAudioServer(t)
	set, _ := repo.CreateVocabularySet(contracts.VocabularySet{ModuleID: "m2", Title: "Empty", Level: "A2"})
	blank := repo.CreateVocabularyItem(contracts.VocabularyItem{SetID: set.ID, Term: "  "})
	status, body := postVocabGenerateAudio(t, srv, blank.ID)
	if status != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400; body=%v", status, body)
	}
}
