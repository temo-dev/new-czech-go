package httpapi

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
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

// V31 — admin tries to generate per-item audio when only a subset of items
// have transcripts. Pre-V31 the handler would silently generate just for the
// items with text, leaving the others without asset_id and Flutter falling
// back to legacy single-audio. V31 must reject loudly with question numbers.
func TestAdminGenerateAudio_Poslech1_PartialTranscripts_Rejected(t *testing.T) {
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
				{QuestionNo: 1},
				{QuestionNo: 2},
				{QuestionNo: 3},
				{QuestionNo: 4},
				{QuestionNo: 5, AudioSource: contracts.ListeningAudioSource{Segments: []contracts.AudioSegment{{Text: "only this one"}}}},
			},
		},
	})

	s := NewServerForTest(repo, nil)
	srv := httptest.NewServer(s.Handler())
	defer srv.Close()

	resp := postGenerateAudio(t, srv, created.ID)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400", resp.StatusCode)
	}

	var body map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	errObj, _ := body["error"].(map[string]any)
	msg, _ := errObj["message"].(string)
	for _, q := range []string{"1", "2", "3", "4"} {
		if !strings.Contains(msg, q) {
			t.Errorf("error message should name missing item %s; got %q", q, msg)
		}
	}

	// Detail must remain untouched — no leaked asset_id from the partial state.
	updated, _ := repo.Exercise(created.ID)
	detail := mustDecodePoslech1Detail(t, updated.Detail)
	for i, item := range detail.Items {
		if item.AudioSource.AssetID != "" {
			t.Errorf("item %d AssetID = %q, want empty (rejected before persist)",
				i, item.AudioSource.AssetID)
		}
	}
}

// ── V39: per-item dialog (poslech_1 multi-speaker) ────────────────────────────

// recordingItemDialogGen records every call so tests can verify which items
// took the flat path vs the dialog path. Both methods write a real stub file
// (Dev impl) so the rollback/state assertions still work end-to-end.
type recordingItemDialogGen struct {
	flatCalls   []int
	dialogCalls []dialogCall
}

type dialogCall struct {
	itemNo   int
	segments []contracts.AudioSegment
}

func (g *recordingItemDialogGen) GenerateAudio(_, _ string) (*contracts.ExerciseAudio, error) {
	return nil, fmt.Errorf("not used in per-item tests")
}

func (g *recordingItemDialogGen) GenerateItemAudio(exerciseID string, itemNo int, _ string) (*contracts.ExerciseAudio, error) {
	g.flatCalls = append(g.flatCalls, itemNo)
	return processing.DevExerciseAudioGenerator{}.GenerateItemAudio(exerciseID, itemNo, "")
}

func (g *recordingItemDialogGen) GenerateItemDialogAudio(exerciseID string, itemNo int, segs []contracts.AudioSegment) (*contracts.ExerciseAudio, error) {
	g.dialogCalls = append(g.dialogCalls, dialogCall{itemNo: itemNo, segments: segs})
	return processing.DevExerciseAudioGenerator{}.GenerateItemAudio(exerciseID, itemNo, "")
}

// V39 — poslech_1 with a multi-speaker item must take the dialog path so the
// generator can route [Žena]/[Muž] to distinct voices. Pre-V39 the per-item
// route fed the joined transcript into a single Polly voice (always Žena).
func TestAdminGenerateAudio_Poslech1_PerItem_MultiSpeaker_RoutesToDialog(t *testing.T) {
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
				{QuestionNo: 1, AudioSource: contracts.ListeningAudioSource{Segments: []contracts.AudioSegment{
					{Speaker: "Žena", Text: "Dobrý den, tady jazyková škola."},
					{Speaker: "Muž", Text: "Dobrý den, ano, to jsem já."},
				}}},
				{QuestionNo: 2, AudioSource: contracts.ListeningAudioSource{Segments: []contracts.AudioSegment{
					{Text: "Jak se jmenujete?"},
				}}},
			},
		},
	})

	s := NewServerForTest(repo, nil)
	rec := &recordingItemDialogGen{}
	s.audioGenerator = rec
	srv := httptest.NewServer(s.Handler())
	defer srv.Close()

	resp := postGenerateAudio(t, srv, created.ID)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want 200", resp.StatusCode)
	}

	if len(rec.dialogCalls) != 1 || rec.dialogCalls[0].itemNo != 1 {
		t.Errorf("dialog calls = %+v, want exactly item 1", rec.dialogCalls)
	}
	if len(rec.flatCalls) != 1 || rec.flatCalls[0] != 2 {
		t.Errorf("flat calls = %+v, want exactly item 2", rec.flatCalls)
	}
	if len(rec.dialogCalls) >= 1 {
		got := rec.dialogCalls[0].segments
		if len(got) != 2 || got[0].Speaker != "Žena" || got[1].Speaker != "Muž" {
			t.Errorf("dialog segments = %+v, want [Žena, Muž]", got)
		}
	}
}

// V39 — a poslech_1 with no multi-speaker items must keep the flat per-item
// path so the dialog generator is not exercised when it's not needed.
func TestAdminGenerateAudio_Poslech1_PerItem_AllSingleVoice_NoDialog(t *testing.T) {
	t.Setenv("LOCAL_ASSETS_DIR", t.TempDir())
	repo := store.NewMemoryStore()
	created := repo.CreateExercise(newPoslech1Exercise())

	s := NewServerForTest(repo, nil)
	rec := &recordingItemDialogGen{}
	s.audioGenerator = rec
	srv := httptest.NewServer(s.Handler())
	defer srv.Close()

	resp := postGenerateAudio(t, srv, created.ID)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want 200", resp.StatusCode)
	}

	if len(rec.dialogCalls) != 0 {
		t.Errorf("dialog calls = %+v, want none (no multi-speaker items)", rec.dialogCalls)
	}
	if len(rec.flatCalls) != 5 {
		t.Errorf("flat calls = %+v, want 5", rec.flatCalls)
	}
}

// ── V39: P4 + P6 multi-speaker via dialog generator ──────────────────────────

// recordingDialogGen records every dialog/single TTS call so tests can verify
// which path was taken for non-P1 exercise types. Uses the dev stub audio
// writer so the response body is still well-formed.
type recordingDialogGen struct {
	dialogCalls [][]contracts.AudioSegment
	singleCalls []string
}

func (g *recordingDialogGen) GenerateAudio(exerciseID, text string) (*contracts.ExerciseAudio, error) {
	g.singleCalls = append(g.singleCalls, text)
	return processing.DevExerciseAudioGenerator{}.GenerateAudio(exerciseID, text)
}

func (g *recordingDialogGen) GenerateDialogAudio(exerciseID string, segments []contracts.AudioSegment) (*contracts.ExerciseAudio, error) {
	cp := make([]contracts.AudioSegment, len(segments))
	copy(cp, segments)
	g.dialogCalls = append(g.dialogCalls, cp)
	return processing.DevExerciseAudioGenerator{}.GenerateDialogAudio(exerciseID, segments)
}

func TestAdminGenerateAudio_Poslech4_MultiSpeaker_RoutesToDialogSegments(t *testing.T) {
	t.Setenv("LOCAL_ASSETS_DIR", t.TempDir())
	repo := store.NewMemoryStore()
	created := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "poslech_4",
		SkillKind:    "nghe",
		ModuleID:     "mod-nghe",
		Pool:         "course",
		Status:       "draft",
		Detail: contracts.Poslech4Detail{
			Items: []contracts.DialogItem{
				{QuestionNo: 1, AudioSource: contracts.ListeningAudioSource{Segments: []contracts.AudioSegment{
					{Speaker: "Žena", Text: "Co byste si přál?"},
					{Speaker: "Muž", Text: "Kávu prosím."},
				}}},
				{QuestionNo: 2, AudioSource: contracts.ListeningAudioSource{Segments: []contracts.AudioSegment{
					{Speaker: "Muž", Text: "Kde je nádraží?"},
					{Speaker: "Žena", Text: "Přímo za rohem."},
				}}},
			},
			Options:        []contracts.ImageOption{{Key: "A"}, {Key: "B"}, {Key: "C"}, {Key: "D"}, {Key: "E"}, {Key: "F"}},
			CorrectAnswers: map[string]string{"1": "A", "2": "B"},
		},
	})

	s := NewServerForTest(repo, nil)
	rec := &recordingDialogGen{}
	s.audioGenerator = rec
	srv := httptest.NewServer(s.Handler())
	defer srv.Close()

	resp := postGenerateAudio(t, srv, created.ID)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want 200", resp.StatusCode)
	}

	if len(rec.dialogCalls) != 1 {
		t.Fatalf("dialog calls = %d, want 1 (merged audio with speakers)", len(rec.dialogCalls))
	}
	if len(rec.singleCalls) != 0 {
		t.Errorf("single-voice calls = %d, want 0", len(rec.singleCalls))
	}
	segs := rec.dialogCalls[0]
	if len(segs) != 4 {
		t.Fatalf("segments = %d, want 4 (2 turns × 2 items)", len(segs))
	}
	wantSpeakers := []string{"Žena", "Muž", "Muž", "Žena"}
	for i, want := range wantSpeakers {
		if segs[i].Speaker != want {
			t.Errorf("segment %d speaker = %q, want %q", i, segs[i].Speaker, want)
		}
	}
}

func TestAdminGenerateAudio_Poslech4_LegacySingleVoice_KeepsIndexAlternation(t *testing.T) {
	t.Setenv("LOCAL_ASSETS_DIR", t.TempDir())
	repo := store.NewMemoryStore()
	created := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "poslech_4",
		SkillKind:    "nghe",
		ModuleID:     "mod-nghe",
		Pool:         "course",
		Status:       "draft",
		Detail: contracts.Poslech4Detail{
			Items: []contracts.DialogItem{
				{QuestionNo: 1, AudioSource: contracts.ListeningAudioSource{Segments: []contracts.AudioSegment{{Text: "Ahoj."}}}},
				{QuestionNo: 2, AudioSource: contracts.ListeningAudioSource{Segments: []contracts.AudioSegment{{Text: "Nazdar."}}}},
			},
			Options:        []contracts.ImageOption{{Key: "A"}, {Key: "B"}, {Key: "C"}, {Key: "D"}, {Key: "E"}, {Key: "F"}},
			CorrectAnswers: map[string]string{"1": "A", "2": "B"},
		},
	})

	s := NewServerForTest(repo, nil)
	rec := &recordingDialogGen{}
	s.audioGenerator = rec
	srv := httptest.NewServer(s.Handler())
	defer srv.Close()

	resp := postGenerateAudio(t, srv, created.ID)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want 200", resp.StatusCode)
	}

	if len(rec.dialogCalls) != 1 {
		t.Fatalf("dialog calls = %d, want 1 (per-item index alternation)", len(rec.dialogCalls))
	}
	segs := rec.dialogCalls[0]
	if len(segs) != 2 {
		t.Fatalf("segments = %d, want 2 (one per item)", len(segs))
	}
	for i, seg := range segs {
		if seg.Speaker != "" {
			t.Errorf("segment %d speaker = %q, want empty (legacy index-alternation)", i, seg.Speaker)
		}
	}
}

func TestAdminGenerateAudio_Poslech6_MultiSpeaker_RoutesToDialog(t *testing.T) {
	t.Setenv("LOCAL_ASSETS_DIR", t.TempDir())
	repo := store.NewMemoryStore()
	created := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "poslech_6",
		SkillKind:    "nghe",
		ModuleID:     "mod-nghe",
		Pool:         "course",
		Status:       "draft",
		Detail: contracts.AnoNeDetail{
			Passage: "[Žena]: Dobrý den, tady úřad.\n[Muž]: Děkuji, na shledanou.",
			Statements: []contracts.AnoNeStatement{
				{QuestionNo: 1, Statement: "Úřad je otevřen."},
			},
			CorrectAnswers: map[string]string{"1": "ANO"},
		},
	})

	s := NewServerForTest(repo, nil)
	rec := &recordingDialogGen{}
	s.audioGenerator = rec
	srv := httptest.NewServer(s.Handler())
	defer srv.Close()

	resp := postGenerateAudio(t, srv, created.ID)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want 200", resp.StatusCode)
	}

	if len(rec.dialogCalls) != 1 {
		t.Fatalf("dialog calls = %d, want 1", len(rec.dialogCalls))
	}
	segs := rec.dialogCalls[0]
	if len(segs) != 2 || segs[0].Speaker != "Žena" || segs[1].Speaker != "Muž" {
		t.Errorf("dialog segments = %+v", segs)
	}
	if segs[0].Text != "Dobrý den, tady úřad." {
		t.Errorf("seg 0 text = %q", segs[0].Text)
	}
}

func TestAdminGenerateAudio_Poslech6_PlainPassage_SingleVoice(t *testing.T) {
	t.Setenv("LOCAL_ASSETS_DIR", t.TempDir())
	repo := store.NewMemoryStore()
	created := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "poslech_6",
		SkillKind:    "nghe",
		ModuleID:     "mod-nghe",
		Pool:         "course",
		Status:       "draft",
		Detail: contracts.AnoNeDetail{
			Passage: "Vlašim. Městský úřad je otevřen v pondělí.",
			Statements: []contracts.AnoNeStatement{
				{QuestionNo: 1, Statement: "Úřad je otevřen v pondělí."},
			},
			CorrectAnswers: map[string]string{"1": "ANO"},
		},
	})

	s := NewServerForTest(repo, nil)
	rec := &recordingDialogGen{}
	s.audioGenerator = rec
	srv := httptest.NewServer(s.Handler())
	defer srv.Close()

	resp := postGenerateAudio(t, srv, created.ID)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want 200", resp.StatusCode)
	}

	if len(rec.dialogCalls) != 0 {
		t.Errorf("dialog calls = %d, want 0 (plain passage)", len(rec.dialogCalls))
	}
	if len(rec.singleCalls) != 1 || rec.singleCalls[0] == "" {
		t.Errorf("single-voice calls = %+v, want 1 non-empty", rec.singleCalls)
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
