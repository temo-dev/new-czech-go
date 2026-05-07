package httpapi

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

// V22 CMS Catch-Up — Phase E2.
// GET /v1/admin/content-health runs the 6 fixed content rot checks
// against the in-memory facade and returns counts + items per check.

type contentHealthResponse struct {
	CheckedAt string                `json:"checked_at"`
	Checks    []contentHealthResult `json:"checks"`
}

type contentHealthResult struct {
	ID          string              `json:"id"`
	Label       string              `json:"label"`
	Description string              `json:"description"`
	Count       int                 `json:"count"`
	Items       []contentHealthItem `json:"items"`
	Truncated   bool                `json:"truncated"`
}

type contentHealthItem struct {
	EntityType string `json:"entity_type"`
	EntityID   string `json:"entity_id"`
	Label      string `json:"label"`
	Extra      string `json:"extra,omitempty"`
}

func newContentHealthEnv(t *testing.T) (*httptest.Server, *store.MemoryStore) {
	t.Helper()
	repo := store.NewMemoryStore()
	srv := NewServerForTest(repo, nil)
	httpsrv := httptest.NewServer(srv.Handler())
	t.Cleanup(httpsrv.Close)
	return httpsrv, repo
}

func contentHealthGet(t *testing.T, server *httptest.Server, token string) (*http.Response, contentHealthResponse) {
	t.Helper()
	req, _ := http.NewRequest(http.MethodGet, server.URL+"/v1/admin/content-health", nil)
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("GET: %v", err)
	}
	t.Cleanup(func() { resp.Body.Close() })
	var out contentHealthResponse
	if resp.StatusCode == http.StatusOK {
		_ = json.NewDecoder(resp.Body).Decode(&out)
	}
	return resp, out
}

func TestAdminContentHealth_RequiresAdmin_LearnerToken_Returns403(t *testing.T) {
	server, _ := newContentHealthEnv(t)
	resp, _ := contentHealthGet(t, server, "dev-learner-token")
	if resp.StatusCode != http.StatusForbidden {
		t.Errorf("want 403, got %d", resp.StatusCode)
	}
}

func TestAdminContentHealth_AllClean_ReturnsSixZeroCounts(t *testing.T) {
	server, _ := newContentHealthEnv(t)

	resp, body := contentHealthGet(t, server, "dev-admin-token")
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("want 200, got %d", resp.StatusCode)
	}
	if len(body.Checks) != 6 {
		t.Fatalf("expected 6 checks, got %d", len(body.Checks))
	}
	for _, c := range body.Checks {
		if c.ID == "" {
			t.Errorf("check missing id: %+v", c)
		}
		if c.Label == "" {
			t.Errorf("check %q missing label", c.ID)
		}
	}
}

func TestAdminContentHealth_OrphanExercise_Detected(t *testing.T) {
	server, repo := newContentHealthEnv(t)

	// Course-pool exercise without module_id → orphan.
	orphan := repo.CreateExercise(contracts.Exercise{
		Pool:         "course",
		ModuleID:     "",
		ExerciseType: "uloha_1_topic_answers",
		SkillKind:    "noi",
		Title:        "Orphan thử nghiệm",
	})
	// Same pool but with module — must NOT be flagged.
	repo.CreateExercise(contracts.Exercise{
		Pool:         "course",
		ModuleID:     "mod-1",
		ExerciseType: "uloha_2_dialogue_questions",
		SkillKind:    "noi",
		Title:        "Có module",
	})

	resp, body := contentHealthGet(t, server, "dev-admin-token")
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("want 200, got %d", resp.StatusCode)
	}
	got := findCheck(t, body.Checks, "orphan_exercises")
	if got.Count != 1 {
		t.Errorf("orphan_exercises count = %d, want 1", got.Count)
	}
	if len(got.Items) != 1 || got.Items[0].EntityID != orphan.ID {
		t.Errorf("orphan items wrong: got %+v, want id %s", got.Items, orphan.ID)
	}
}

func TestAdminContentHealth_MockTestMissingSection_Detected(t *testing.T) {
	server, repo := newContentHealthEnv(t)

	if _, err := repo.CreateMockTest(contracts.MockTest{
		Title:                    "Empty mock", Status: "draft",
		EstimatedDurationMinutes: 10,
		Sections:                 []contracts.MockTestSection{},
	}); err != nil {
		t.Fatalf("seed mock: %v", err)
	}

	resp, body := contentHealthGet(t, server, "dev-admin-token")
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("want 200, got %d", resp.StatusCode)
	}
	got := findCheck(t, body.Checks, "mock_test_missing_section")
	if got.Count != 1 {
		t.Errorf("mock_test_missing_section count = %d, want 1", got.Count)
	}
}

func findCheck(t *testing.T, checks []contentHealthResult, id string) contentHealthResult {
	t.Helper()
	for _, c := range checks {
		if c.ID == id {
			return c
		}
	}
	t.Fatalf("check %q not found in %d checks", id, len(checks))
	return contentHealthResult{}
}

// V23 Phase H1 — per-exercise validation flags helper. 5 rule × 2
// cases (positive / negative) ensures each rule fires on the right
// inputs and stays silent otherwise.

func TestComputeValidationFlags_OrphanPositive(t *testing.T) {
	repo := store.NewMemoryStore()
	flags := computeValidationFlags(repo, contracts.Exercise{
		ID: "ex_1", Pool: "course", ModuleID: "",
	})
	if !flags.Orphan {
		t.Error("Orphan should be true for pool=course with empty module_id")
	}
}

func TestComputeValidationFlags_OrphanNegative(t *testing.T) {
	repo := store.NewMemoryStore()
	flags := computeValidationFlags(repo, contracts.Exercise{
		ID: "ex_1", Pool: "course", ModuleID: "mod_1",
	})
	if flags.Orphan {
		t.Error("Orphan must be false when module_id is set")
	}
}

func TestComputeValidationFlags_MissingAudioPositive(t *testing.T) {
	repo := store.NewMemoryStore()
	flags := computeValidationFlags(repo, contracts.Exercise{
		ID: "ex_nghe_1", SkillKind: "nghe", ModuleID: "mod_1", Pool: "course",
	})
	if !flags.MissingAudio {
		t.Error("MissingAudio should be true for nghe exercise without exercise_audio row")
	}
}

func TestComputeValidationFlags_MissingAudioNegative(t *testing.T) {
	repo := store.NewMemoryStore()
	repo.SetExerciseAudio("ex_nghe_with_audio", contracts.ExerciseAudio{
		ExerciseID: "ex_nghe_with_audio",
		StorageKey: "audio/key.mp3",
	})
	flags := computeValidationFlags(repo, contracts.Exercise{
		ID: "ex_nghe_with_audio", SkillKind: "nghe", ModuleID: "mod_1", Pool: "course",
	})
	if flags.MissingAudio {
		t.Error("MissingAudio must be false when exercise_audio row exists")
	}
}

func TestComputeValidationFlags_MissingSentenceAudioPositive(t *testing.T) {
	repo := store.NewMemoryStore()
	flags := computeValidationFlags(repo, contracts.Exercise{
		ID: "ex_dictation_1", ExerciseType: "psani_3_dictation", SkillKind: "viet", ModuleID: "mod_1",
	})
	if !flags.MissingSentenceAudio {
		t.Error("MissingSentenceAudio should be true for dictation without sentence_audio rows")
	}
}

func TestComputeValidationFlags_MissingSentenceAudioNegative(t *testing.T) {
	repo := store.NewMemoryStore()
	flags := computeValidationFlags(repo, contracts.Exercise{
		ID: "ex_not_dictation", ExerciseType: "psani_2_email", SkillKind: "viet", ModuleID: "mod_1",
	})
	if flags.MissingSentenceAudio {
		t.Error("MissingSentenceAudio must be false for non-dictation exercises")
	}
}

func TestComputeValidationFlags_MissingSamplePositive(t *testing.T) {
	repo := store.NewMemoryStore()
	flags := computeValidationFlags(repo, contracts.Exercise{
		ID: "ex_noi_1", SkillKind: "noi", ModuleID: "mod_1", Pool: "course",
		SampleAnswerEnabled: true, SampleAnswerText: "   ",
	})
	if !flags.MissingSample {
		t.Error("MissingSample should be true when sample_enabled but text is whitespace")
	}
}

func TestComputeValidationFlags_MissingSampleNegative_Disabled(t *testing.T) {
	repo := store.NewMemoryStore()
	flags := computeValidationFlags(repo, contracts.Exercise{
		ID: "ex_noi_disabled", SkillKind: "noi", ModuleID: "mod_1", Pool: "course",
		SampleAnswerEnabled: false, SampleAnswerText: "",
	})
	if flags.MissingSample {
		t.Error("MissingSample must be false when sample_enabled=false")
	}
}

func TestComputeValidationFlags_UnpublishedPositive(t *testing.T) {
	repo := store.NewMemoryStore()
	flags := computeValidationFlags(repo, contracts.Exercise{
		ID: "ex_1", Status: "draft",
	})
	if !flags.Unpublished {
		t.Error("Unpublished should be true for draft status")
	}
}

func TestComputeValidationFlags_UnpublishedNegative(t *testing.T) {
	repo := store.NewMemoryStore()
	flags := computeValidationFlags(repo, contracts.Exercise{
		ID: "ex_1", Status: "published",
	})
	if flags.Unpublished {
		t.Error("Unpublished must be false for published status")
	}
}
