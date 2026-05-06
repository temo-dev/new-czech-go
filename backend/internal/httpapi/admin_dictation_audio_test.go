package httpapi

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

func newDictationAudioTestServer(t *testing.T) (*httptest.Server, *store.MemoryStore, string) {
	t.Helper()
	t.Setenv("LOCAL_ASSETS_DIR", t.TempDir())
	repo := store.NewMemoryStore()
	// CreateExercise auto-assigns the ID — capture and use the returned value.
	created := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "psani_3_dictation",
		SkillKind:    "viet",
		ModuleID:     "mod-viet",
		Status:       "draft",
	})
	srv := httptest.NewServer(NewServer(repo, nil, nil))
	t.Cleanup(srv.Close)
	return srv, repo, created.ID
}

func postDictationSentenceAudio(t *testing.T, srv *httptest.Server, exerciseID string, idx int, body string, token string) *http.Response {
	t.Helper()
	url := fmt.Sprintf("%s/v1/admin/exercises/%s/dictation/sentences/%d/audio", srv.URL, exerciseID, idx)
	req, _ := http.NewRequest(http.MethodPost, url, strings.NewReader(body))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	resp, err := srv.Client().Do(req)
	if err != nil {
		t.Fatalf("post sentence audio: %v", err)
	}
	return resp
}

func TestAdminDictationSentenceAudio_PostHappy(t *testing.T) {
	srv, repo, exID := newDictationAudioTestServer(t)
	resp := postDictationSentenceAudio(t, srv, exID, 0, `{"text":"Pavel jde do kavárny."}`, "dev-admin-token")
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status: %d", resp.StatusCode)
	}
	var body map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	data, _ := body["data"].(map[string]any)
	if data["storage_key"] == "" {
		t.Errorf("storage_key empty: %+v", data)
	}
	if got, _ := data["sentence_idx"].(float64); int(got) != 0 {
		t.Errorf("sentence_idx: %v", data["sentence_idx"])
	}
	// Repository row should be persisted.
	rec, ok := repo.SentenceAudio(exID, 0)
	if !ok {
		t.Fatalf("expected SentenceAudio row to be persisted")
	}
	if rec.StorageKey == "" || rec.SentenceIdx != 0 {
		t.Errorf("row content: %+v", rec)
	}
}

func TestAdminDictationSentenceAudio_PostMultipleIdx(t *testing.T) {
	srv, repo, exID := newDictationAudioTestServer(t)
	for idx := 0; idx < 3; idx++ {
		resp := postDictationSentenceAudio(t, srv, exID, idx, fmt.Sprintf(`{"text":"Câu %d."}`, idx), "dev-admin-token")
		resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("idx=%d status: %d", idx, resp.StatusCode)
		}
	}
	rows := repo.SentenceAudiosByExercise(exID)
	if len(rows) != 3 {
		t.Fatalf("rows: %d", len(rows))
	}
	if rows[0].SentenceIdx != 0 || rows[2].SentenceIdx != 2 {
		t.Errorf("rows not sorted by idx: %+v", rows)
	}
}

func TestLearnerDictationDetailHydratesTypedSentenceAudio(t *testing.T) {
	t.Setenv("LOCAL_ASSETS_DIR", t.TempDir())
	repo := store.NewMemoryStore()
	created := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "psani_3_dictation",
		SkillKind:    "viet",
		ModuleID:     "mod-viet",
		Status:       "published",
		Detail: contracts.DictationDetail{
			Topic: "Cafe",
			Sentences: []contracts.DictationSentence{
				{Idx: 0, Text: "Pavel jde do kavárny."},
				{Idx: 1, Text: "Děkuji."},
				{Idx: 2, Text: "Na shledanou."},
			},
			MaxReplaysPerSentence: 3,
		},
	})
	for idx := 0; idx < 3; idx++ {
		repo.SetSentenceAudio(created.ID, idx, contracts.ExerciseAudio{
			StorageKey: fmt.Sprintf("exercise-audio/%s/sentence-%d.mp3", created.ID, idx),
			MimeType:   "audio/mpeg",
		})
	}
	srv := httptest.NewServer(NewServer(repo, nil, nil))
	t.Cleanup(srv.Close)

	req, _ := http.NewRequest(http.MethodGet, srv.URL+"/v1/exercises/"+created.ID, nil)
	req.Header.Set("Authorization", "Bearer dev-learner-token")
	resp, err := srv.Client().Do(req)
	if err != nil {
		t.Fatalf("get exercise: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status: %d", resp.StatusCode)
	}
	var body map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	data, _ := body["data"].(map[string]any)
	detail, _ := data["detail"].(map[string]any)
	sentences, _ := detail["sentences"].([]any)
	if len(sentences) != 3 {
		t.Fatalf("sentences: %+v", detail["sentences"])
	}
	got, _ := sentences[0].(map[string]any)["audio_asset_id"].(string)
	want := "exercise-audio/" + created.ID + "/sentence-0.mp3"
	if got != want {
		t.Fatalf("audio_asset_id not hydrated: got %q want %q", got, want)
	}
}

func TestAdminCreateDictationPublishedRequiresSentenceAudio(t *testing.T) {
	t.Setenv("LOCAL_ASSETS_DIR", t.TempDir())
	repo := store.NewMemoryStore()
	srv := httptest.NewServer(NewServer(repo, nil, nil))
	t.Cleanup(srv.Close)

	body := `{
		"module_id":"mod-viet",
		"skill_kind":"viet",
		"exercise_type":"psani_3_dictation",
		"title":"Viết chính tả",
		"short_instruction":"Nghe và viết lại.",
		"learner_instruction":"Nghe từng câu rồi viết lại.",
		"estimated_duration_sec":600,
		"sample_answer_enabled":false,
		"status":"published",
		"detail":{
			"topic":"Cafe",
			"sentences":[
				{"idx":0,"text":"Pavel jde do kavárny.","audio_asset_id":""},
				{"idx":1,"text":"Děkuji.","audio_asset_id":"exercise-audio/ex/sentence-1.mp3"},
				{"idx":2,"text":"Na shledanou.","audio_asset_id":"exercise-audio/ex/sentence-2.mp3"}
			],
			"max_replays_per_sentence":3
		}
	}`
	req, _ := http.NewRequest(http.MethodPost, srv.URL+"/v1/admin/exercises", strings.NewReader(body))
	req.Header.Set("Authorization", "Bearer dev-admin-token")
	req.Header.Set("Content-Type", "application/json")
	resp, err := srv.Client().Do(req)
	if err != nil {
		t.Fatalf("create exercise: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", resp.StatusCode)
	}
	var payload map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode: %v", err)
	}
	errObj, _ := payload["error"].(map[string]any)
	if errObj["code"] != "validation_error" {
		t.Fatalf("expected validation_error, got %+v", errObj)
	}
	if !strings.Contains(fmt.Sprint(errObj["message"]), "audio") {
		t.Fatalf("expected audio validation message, got %+v", errObj)
	}
}

func TestAdminPatchDictationPublishedRequiresSentenceAudio(t *testing.T) {
	t.Setenv("LOCAL_ASSETS_DIR", t.TempDir())
	repo := store.NewMemoryStore()
	created := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "psani_3_dictation",
		SkillKind:    "viet",
		ModuleID:     "mod-viet",
		Status:       "draft",
		Detail: contracts.DictationDetail{
			Topic: "Cafe",
			Sentences: []contracts.DictationSentence{
				{Idx: 0, Text: "Pavel jde do kavárny."},
				{Idx: 1, Text: "Děkuji."},
				{Idx: 2, Text: "Na shledanou."},
			},
			MaxReplaysPerSentence: 3,
		},
	})
	srv := httptest.NewServer(NewServer(repo, nil, nil))
	t.Cleanup(srv.Close)

	req, _ := http.NewRequest(http.MethodPatch, srv.URL+"/v1/admin/exercises/"+created.ID, strings.NewReader(`{"status":"published"}`))
	req.Header.Set("Authorization", "Bearer dev-admin-token")
	req.Header.Set("Content-Type", "application/json")
	resp, err := srv.Client().Do(req)
	if err != nil {
		t.Fatalf("patch exercise: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", resp.StatusCode)
	}
}

func TestAdminPatchDictationPublishedAllowsSentenceAudioRows(t *testing.T) {
	t.Setenv("LOCAL_ASSETS_DIR", t.TempDir())
	repo := store.NewMemoryStore()
	created := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "psani_3_dictation",
		SkillKind:    "viet",
		ModuleID:     "mod-viet",
		Status:       "draft",
		Detail: contracts.DictationDetail{
			Topic: "Cafe",
			Sentences: []contracts.DictationSentence{
				{Idx: 0, Text: "Pavel jde do kavárny."},
				{Idx: 1, Text: "Děkuji."},
				{Idx: 2, Text: "Na shledanou."},
			},
			MaxReplaysPerSentence: 3,
		},
	})
	for idx := 0; idx < 3; idx++ {
		repo.SetSentenceAudio(created.ID, idx, contracts.ExerciseAudio{
			StorageKey: fmt.Sprintf("exercise-audio/%s/sentence-%d.mp3", created.ID, idx),
			MimeType:   "audio/mpeg",
		})
	}
	srv := httptest.NewServer(NewServer(repo, nil, nil))
	t.Cleanup(srv.Close)

	req, _ := http.NewRequest(http.MethodPatch, srv.URL+"/v1/admin/exercises/"+created.ID, strings.NewReader(`{"status":"published"}`))
	req.Header.Set("Authorization", "Bearer dev-admin-token")
	req.Header.Set("Content-Type", "application/json")
	resp, err := srv.Client().Do(req)
	if err != nil {
		t.Fatalf("patch exercise: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}
}

func TestLocalExerciseAudioAndMediaAssetDefaultDirsMatch(t *testing.T) {
	t.Setenv("LOCAL_ASSETS_DIR", "")
	key := "exercise-audio/ex-1/sentence-0.mp3"
	if localExerciseAudioPath(key) != localExerciseAssetPath(key) {
		t.Fatalf("default storage dirs differ: audio=%q media=%q", localExerciseAudioPath(key), localExerciseAssetPath(key))
	}
	if filepath.Join(localAssetsDir(), key) != localExerciseAssetPath(key) {
		t.Fatalf("dictation delete dir differs: delete=%q media=%q", filepath.Join(localAssetsDir(), key), localExerciseAssetPath(key))
	}
}

func TestAdminDictationSentenceAudio_PostExerciseNotFound(t *testing.T) {
	srv, _, _ := newDictationAudioTestServer(t)
	resp := postDictationSentenceAudio(t, srv, "ex-missing", 0, `{"text":"x"}`, "dev-admin-token")
	resp.Body.Close()
	if resp.StatusCode != http.StatusNotFound {
		t.Errorf("status: %d", resp.StatusCode)
	}
}

func TestAdminDictationSentenceAudio_PostEmptyText(t *testing.T) {
	srv, _, exID := newDictationAudioTestServer(t)
	resp := postDictationSentenceAudio(t, srv, exID, 0, `{"text":"   "}`, "dev-admin-token")
	resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("status: %d", resp.StatusCode)
	}
}

func TestAdminDictationSentenceAudio_PostTooLong(t *testing.T) {
	srv, _, exID := newDictationAudioTestServer(t)
	long := strings.Repeat("á", 251)
	resp := postDictationSentenceAudio(t, srv, exID, 0, fmt.Sprintf(`{"text":%q}`, long), "dev-admin-token")
	resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("status: %d", resp.StatusCode)
	}
}

func TestAdminDictationSentenceAudio_PostNonAdmin(t *testing.T) {
	srv, _, exID := newDictationAudioTestServer(t)
	resp := postDictationSentenceAudio(t, srv, exID, 0, `{"text":"Ahoj."}`, "dev-learner-token")
	resp.Body.Close()
	if resp.StatusCode != http.StatusForbidden && resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("expected 401/403 for learner, got %d", resp.StatusCode)
	}
}

func TestAdminDictationSentenceAudio_DeleteHappy(t *testing.T) {
	srv, repo, exID := newDictationAudioTestServer(t)
	// Seed a row first.
	postResp := postDictationSentenceAudio(t, srv, exID, 0, `{"text":"Ahoj."}`, "dev-admin-token")
	postResp.Body.Close()

	url := fmt.Sprintf("%s/v1/admin/exercises/%s/dictation/sentences/0/audio", srv.URL, exID)
	req, _ := http.NewRequest(http.MethodDelete, url, nil)
	req.Header.Set("Authorization", "Bearer dev-admin-token")
	resp, err := srv.Client().Do(req)
	if err != nil {
		t.Fatalf("delete: %v", err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusNoContent {
		t.Errorf("status: %d", resp.StatusCode)
	}
	if _, ok := repo.SentenceAudio(exID, 0); ok {
		t.Errorf("row should be gone")
	}
}

func TestAdminDictationSentenceAudio_DeleteMissingIsNoOp(t *testing.T) {
	srv, _, exID := newDictationAudioTestServer(t)
	url := fmt.Sprintf("%s/v1/admin/exercises/%s/dictation/sentences/9/audio", srv.URL, exID)
	req, _ := http.NewRequest(http.MethodDelete, url, nil)
	req.Header.Set("Authorization", "Bearer dev-admin-token")
	resp, err := srv.Client().Do(req)
	if err != nil {
		t.Fatalf("delete: %v", err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusNoContent {
		t.Errorf("status: %d", resp.StatusCode)
	}
}

func TestAdminDictationSentenceAudio_BadIdx(t *testing.T) {
	srv, _, exID := newDictationAudioTestServer(t)
	url := fmt.Sprintf("%s/v1/admin/exercises/%s/dictation/sentences/abc/audio", srv.URL, exID)
	req, _ := http.NewRequest(http.MethodPost, url, strings.NewReader(`{"text":"x"}`))
	req.Header.Set("Authorization", "Bearer dev-admin-token")
	req.Header.Set("Content-Type", "application/json")
	resp, err := srv.Client().Do(req)
	if err != nil {
		t.Fatalf("post: %v", err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusNotFound {
		t.Errorf("expected 404 for non-numeric idx, got %d", resp.StatusCode)
	}
}

func TestParseDictationSentencePath(t *testing.T) {
	cases := []struct {
		in      string
		wantEx  string
		wantIdx int
		wantOK  bool
	}{
		{"ex-1/dictation/sentences/0/audio", "ex-1", 0, true},
		{"ex-1/dictation/sentences/12/audio", "ex-1", 12, true},
		{"ex-1/dictation/sentences/abc/audio", "", 0, false},
		{"ex-1/dictation/sentences//audio", "", 0, false},
		{"ex-1/dictation/sentences/0/audio/extra", "", 0, false},
		{"/dictation/sentences/0/audio", "", 0, false}, // leading slash before dictation = empty exerciseID
	}
	for _, c := range cases {
		ex, idx, ok := parseDictationSentencePath(c.in)
		if ok != c.wantOK || ex != c.wantEx || idx != c.wantIdx {
			t.Errorf("parse(%q) = (%q, %d, %v); want (%q, %d, %v)", c.in, ex, idx, ok, c.wantEx, c.wantIdx, c.wantOK)
		}
	}
}
