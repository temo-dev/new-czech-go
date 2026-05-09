package httpapi

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/processing"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

// failingItemAudioGen is a test-only ItemAudioGenerator that succeeds for items
// up to (but not including) failAt and then returns an error. Used to exercise
// the rollback path in handleAdminGenerateAudio for poslech_1.
type failingItemAudioGen struct {
	failAt int
}

func (g failingItemAudioGen) GenerateAudio(_, _ string) (*contracts.ExerciseAudio, error) {
	return nil, fmt.Errorf("not used in per-item tests")
}

func (g failingItemAudioGen) GenerateItemAudio(exerciseID string, itemNo int, _ string) (*contracts.ExerciseAudio, error) {
	if itemNo >= g.failAt {
		return nil, fmt.Errorf("simulated polly fail at item %d", itemNo)
	}
	// Reuse Dev WAV writer so files actually appear at the expected path —
	// the rollback test then verifies they are deleted.
	return processing.DevExerciseAudioGenerator{}.GenerateItemAudio(exerciseID, itemNo, "")
}

func newPoslech1Exercise() contracts.Exercise {
	return contracts.Exercise{
		ExerciseType: "poslech_1",
		SkillKind:    "nghe",
		ModuleID:     "mod-nghe",
		Pool:         "course",
		Status:       "draft",
		Detail: contracts.Poslech1Detail{
			Items: []contracts.ListeningItem{
				{QuestionNo: 1, AudioSource: contracts.ListeningAudioSource{Segments: []contracts.AudioSegment{{Text: "Kde je nádraží?"}}}},
				{QuestionNo: 2, AudioSource: contracts.ListeningAudioSource{Segments: []contracts.AudioSegment{{Text: "Jak se jmenujete?"}}}},
				{QuestionNo: 3, AudioSource: contracts.ListeningAudioSource{Segments: []contracts.AudioSegment{{Text: "Kolik je hodin?"}}}},
				{QuestionNo: 4, AudioSource: contracts.ListeningAudioSource{Segments: []contracts.AudioSegment{{Text: "Odkud jste?"}}}},
				{QuestionNo: 5, AudioSource: contracts.ListeningAudioSource{Segments: []contracts.AudioSegment{{Text: "Co děláte?"}}}},
			},
			CorrectAnswers: map[string]string{"1": "B", "2": "A", "3": "C", "4": "D", "5": "B"},
		},
	}
}

func mustDecodePoslech1Detail(t *testing.T, raw any) contracts.Poslech1Detail {
	t.Helper()
	b, err := json.Marshal(raw)
	if err != nil {
		t.Fatalf("marshal detail: %v", err)
	}
	var d contracts.Poslech1Detail
	if err := json.Unmarshal(b, &d); err != nil {
		t.Fatalf("unmarshal detail: %v", err)
	}
	return d
}

func postGenerateAudio(t *testing.T, srv *httptest.Server, exerciseID string) *http.Response {
	t.Helper()
	url := fmt.Sprintf("%s/v1/admin/exercises/%s/generate-audio", srv.URL, exerciseID)
	req, _ := http.NewRequest(http.MethodPost, url, nil)
	req.Header.Set("Authorization", "Bearer dev-admin-token")
	resp, err := srv.Client().Do(req)
	if err != nil {
		t.Fatalf("post generate-audio: %v", err)
	}
	return resp
}

func TestAdminGenerateAudio_Poslech1_PerItem_Happy(t *testing.T) {
	t.Setenv("LOCAL_ASSETS_DIR", t.TempDir())
	repo := store.NewMemoryStore()
	created := repo.CreateExercise(newPoslech1Exercise())

	s := NewServerForTest(repo, nil)
	srv := httptest.NewServer(s.Handler())
	defer srv.Close()

	resp := postGenerateAudio(t, srv, created.ID)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want 200", resp.StatusCode)
	}

	var body map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	data, _ := body["data"].(map[string]any)
	if storageKey, _ := data["storage_key"].(string); storageKey == "" {
		t.Errorf("storage_key empty: %+v", data)
	}
	meta, _ := body["meta"].(map[string]any)
	if got, _ := meta["item_count"].(float64); int(got) != 5 {
		t.Errorf("meta.item_count = %v, want 5", meta["item_count"])
	}

	// All 5 items should now carry asset_id pointing at item-N audio.
	updated, ok := repo.Exercise(created.ID)
	if !ok {
		t.Fatal("exercise missing after generate")
	}
	detail := mustDecodePoslech1Detail(t, updated.Detail)
	if len(detail.Items) != 5 {
		t.Fatalf("got %d items, want 5", len(detail.Items))
	}
	for i, item := range detail.Items {
		wantSuffix := fmt.Sprintf("/item-%d.", item.QuestionNo)
		if item.AudioSource.AssetID == "" {
			t.Errorf("item %d AssetID empty", i)
			continue
		}
		if !contains(item.AudioSource.AssetID, wantSuffix) {
			t.Errorf("item %d AssetID = %q, want substring %q",
				i, item.AudioSource.AssetID, wantSuffix)
		}
		// File should physically exist at the asset path.
		if _, err := os.Stat(localExerciseAudioPath(item.AudioSource.AssetID)); err != nil {
			t.Errorf("item %d file missing: %v", i, err)
		}
	}
}

func TestAdminGenerateAudio_Poslech1_PerItem_RollbackOnFailure(t *testing.T) {
	t.Setenv("LOCAL_ASSETS_DIR", t.TempDir())
	repo := store.NewMemoryStore()
	created := repo.CreateExercise(newPoslech1Exercise())

	s := NewServerForTest(repo, nil)
	s.audioGenerator = failingItemAudioGen{failAt: 3}
	srv := httptest.NewServer(s.Handler())
	defer srv.Close()

	resp := postGenerateAudio(t, srv, created.ID)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusInternalServerError {
		t.Fatalf("status = %d, want 500", resp.StatusCode)
	}

	// Detail should be unchanged — no asset_id should leak from the
	// successful items 1 and 2 if the third failed.
	updated, _ := repo.Exercise(created.ID)
	detail := mustDecodePoslech1Detail(t, updated.Detail)
	for i, item := range detail.Items {
		if item.AudioSource.AssetID != "" {
			t.Errorf("item %d AssetID = %q, want empty (rollback)", i, item.AudioSource.AssetID)
		}
	}

	// Files written for items 1 and 2 should be cleaned up.
	for n := 1; n <= 2; n++ {
		key := fmt.Sprintf("exercise-audio/%s/item-%d.wav", created.ID, n)
		if _, err := os.Stat(localExerciseAudioPath(key)); err == nil {
			t.Errorf("item-%d file still on disk after rollback: %s", n, key)
		}
	}
}

func TestAdminGenerateAudio_Poslech1_LegacyFallback_NoItems(t *testing.T) {
	// poslech_1 with all items uploaded (AssetID set) — no per-item TTS to do.
	// Endpoint should fall through to single-audio path (returns 400 here
	// because BuildExerciseAudioText returns "" when every item is uploaded).
	t.Setenv("LOCAL_ASSETS_DIR", t.TempDir())
	repo := store.NewMemoryStore()
	created := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "poslech_1",
		SkillKind:    "nghe",
		ModuleID:     "mod-nghe",
		Pool:         "course",
		Status:       "draft",
		Detail: contracts.Poslech1Detail{
			Items: []contracts.ListeningItem{
				{QuestionNo: 1, AudioSource: contracts.ListeningAudioSource{AssetID: "uploaded-1"}},
				{QuestionNo: 2, AudioSource: contracts.ListeningAudioSource{AssetID: "uploaded-2"}},
			},
		},
	})

	s := NewServerForTest(repo, nil)
	srv := httptest.NewServer(s.Handler())
	defer srv.Close()

	resp := postGenerateAudio(t, srv, created.ID)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400 (no synthesizable items)", resp.StatusCode)
	}
}

func contains(s, sub string) bool {
	return len(sub) <= len(s) && (s == sub || stringIndex(s, sub) >= 0)
}

func stringIndex(s, sub string) int {
	for i := 0; i+len(sub) <= len(s); i++ {
		if s[i:i+len(sub)] == sub {
			return i
		}
	}
	return -1
}
