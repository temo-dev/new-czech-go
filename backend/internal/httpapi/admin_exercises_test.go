package httpapi

import (
	"bytes"
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

// V21.3 hotfix — POST handler previously omitted Pool from its anon
// decode struct, so every CMS-created exercise silently landed with
// pool="course" (postgres insert default at insertExercise:173-175).
// Regression: POST round-trip must preserve pool="exam" and clear
// module_id when pool is exam (per AGENTS.md "Exercise pools").
func TestAdminExercises_CreatePreservesExamPool(t *testing.T) {
	server, _ := newAdminExercisesEnv(t)

	body := map[string]any{
		"title":         "Mock test item 1",
		"exercise_type": "uloha_1_topic_answers",
		"skill_kind":    "noi",
		"pool":          "exam",
		"module_id":     "",
		"status":        "draft",
		"questions":     []string{"Q1", "Q2"},
	}
	raw, _ := json.Marshal(body)
	req, _ := http.NewRequest(http.MethodPost, server.URL+"/v1/admin/exercises", bytes.NewReader(raw))
	req.Header.Set("Authorization", "Bearer dev-admin-token")
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("POST: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("want 201, got %d", resp.StatusCode)
	}
	var created struct {
		Data contracts.Exercise `json:"data"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&created); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if created.Data.Pool != "exam" {
		t.Errorf("pool not preserved: want exam, got %q", created.Data.Pool)
	}
	if created.Data.ModuleID != "" {
		t.Errorf("exam pool must clear module_id, got %q", created.Data.ModuleID)
	}
}

func TestAdminExercises_CreateDefaultsPoolToCourse(t *testing.T) {
	server, _ := newAdminExercisesEnv(t)

	body := map[string]any{
		"title":         "Course item",
		"exercise_type": "uloha_1_topic_answers",
		"skill_kind":    "noi",
		"module_id":     "mod_1",
		"questions":     []string{"Q1"},
	}
	raw, _ := json.Marshal(body)
	req, _ := http.NewRequest(http.MethodPost, server.URL+"/v1/admin/exercises", bytes.NewReader(raw))
	req.Header.Set("Authorization", "Bearer dev-admin-token")
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("POST: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("want 201, got %d", resp.StatusCode)
	}
	var created struct {
		Data contracts.Exercise `json:"data"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&created); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if created.Data.Pool != "course" {
		t.Errorf("missing pool should default to course, got %q", created.Data.Pool)
	}
	if created.Data.ModuleID != "mod_1" {
		t.Errorf("course pool keeps module_id, got %q", created.Data.ModuleID)
	}
}

func TestAdminExercises_PublishedReadingRequiresCorrectAnswers(t *testing.T) {
	server, _ := newAdminExercisesEnv(t)

	status, body := postJSONAllowErrorWithToken(t, server, "/v1/admin/exercises", "dev-admin-token", map[string]any{
		"title":         "Missing answer keys",
		"exercise_type": "cteni_5",
		"skill_kind":    "doc",
		"pool":          "exam",
		"status":        "published",
		"detail": map[string]any{
			"text": "Hledám podnájemníka do pokoje v Praze 4.",
			"questions": []map[string]any{
				{"question_no": 21, "prompt": "Kdy je pokoj volný?"},
				{"question_no": 22, "prompt": "Co je v ceně?"},
			},
			"correct_answers": map[string]string{"21": "1. června"},
		},
	})

	if status != http.StatusBadRequest {
		t.Fatalf("want 400, got %d: %#v", status, body)
	}
	errPayload := body["error"].(map[string]any)
	if errPayload["code"] != "validation_error" {
		t.Fatalf("error code = %v, want validation_error", errPayload["code"])
	}
	if got := errPayload["message"].(string); got != "cteni_5 question 22 is missing correct answer." {
		t.Fatalf("message = %q", got)
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
