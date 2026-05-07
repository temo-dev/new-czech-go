package httpapi

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

// V23 Phase H2 — GET /v1/admin/exercises now returns validation_flags
// per row so the CMS list renders quality badges inline.

func newAdminExercisesEnv(t *testing.T) (*httptest.Server, *store.MemoryStore) {
	t.Helper()
	repo := store.NewMemoryStore()
	srv := NewServerForTest(repo, nil)
	httpsrv := httptest.NewServer(srv.Handler())
	t.Cleanup(httpsrv.Close)
	return httpsrv, repo
}

func adminExercisesGet(t *testing.T, server *httptest.Server, query string, token string) (*http.Response, map[string]any) {
	t.Helper()
	url := server.URL + "/v1/admin/exercises"
	if query != "" {
		url += "?" + query
	}
	req, _ := http.NewRequest(http.MethodGet, url, nil)
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("GET: %v", err)
	}
	t.Cleanup(func() { resp.Body.Close() })
	var body map[string]any
	_ = json.NewDecoder(resp.Body).Decode(&body)
	return resp, body
}

func TestAdminExercises_ResponseIncludesValidationFlags(t *testing.T) {
	server, repo := newAdminExercisesEnv(t)

	// Seed 1 orphan + 1 attached exercise.
	orphan := repo.CreateExercise(contracts.Exercise{
		Pool: "course", ModuleID: "",
		ExerciseType: "uloha_1_topic_answers", SkillKind: "noi",
		Title: "Orphan ex", Status: "draft",
	})
	attached := repo.CreateExercise(contracts.Exercise{
		Pool: "course", ModuleID: "mod_1",
		ExerciseType: "uloha_1_topic_answers", SkillKind: "noi",
		Title: "Attached ex", Status: "published",
	})

	resp, body := adminExercisesGet(t, server, "", "dev-admin-token")
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("want 200, got %d", resp.StatusCode)
	}
	data, _ := body["data"].([]any)
	if len(data) < 2 {
		t.Fatalf("expected ≥2 rows, got %d", len(data))
	}

	byID := map[string]map[string]any{}
	for _, row := range data {
		r, _ := row.(map[string]any)
		id, _ := r["id"].(string)
		byID[id] = r
	}

	orphanRow := byID[orphan.ID]
	if orphanRow == nil {
		t.Fatalf("orphan row missing from response (id=%s)", orphan.ID)
	}
	flags, _ := orphanRow["validation_flags"].(map[string]any)
	if flags == nil {
		t.Fatalf("validation_flags missing on orphan row: %+v", orphanRow)
	}
	if flags["orphan"] != true {
		t.Errorf("orphan flag should be true; got %v", flags["orphan"])
	}
	if flags["unpublished"] != true {
		t.Errorf("unpublished flag should be true for draft; got %v", flags["unpublished"])
	}

	attachedRow := byID[attached.ID]
	attachedFlags, _ := attachedRow["validation_flags"].(map[string]any)
	if attachedFlags["orphan"] != false {
		t.Errorf("attached row orphan should be false; got %v", attachedFlags["orphan"])
	}
}

func TestAdminExercises_ForbiddenWithoutAdminToken(t *testing.T) {
	server, _ := newAdminExercisesEnv(t)
	resp, _ := adminExercisesGet(t, server, "", "dev-learner-token")
	if resp.StatusCode != http.StatusForbidden {
		t.Errorf("want 403, got %d", resp.StatusCode)
	}
}

func TestAdminExercises_PoolFilterStillWorks(t *testing.T) {
	server, repo := newAdminExercisesEnv(t)

	repo.CreateExercise(contracts.Exercise{
		Pool: "course", ModuleID: "mod_1",
		ExerciseType: "uloha_1_topic_answers", SkillKind: "noi", Title: "Course one",
	})
	repo.CreateExercise(contracts.Exercise{
		Pool: "exam", ModuleID: "",
		ExerciseType: "uloha_1_topic_answers", SkillKind: "noi", Title: "Exam one",
	})

	resp, body := adminExercisesGet(t, server, "pool=exam", "dev-admin-token")
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("want 200, got %d", resp.StatusCode)
	}
	data, _ := body["data"].([]any)
	for _, row := range data {
		r, _ := row.(map[string]any)
		pool, _ := r["pool"].(string)
		if pool != "exam" {
			t.Errorf("pool filter leaked non-exam row: %+v", r)
		}
	}
}
