package httpapi

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/processing"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

func unsetMasteryEnv(t *testing.T) {
	t.Helper()
	for _, k := range []string{
		"MASTERY_BAND_LEARNING", "MASTERY_BAND_SOLID", "MASTERY_BAND_READY",
		"MASTERY_OVERALL_NOI", "MASTERY_OVERALL_VIET", "MASTERY_OVERALL_NGHE",
		"MASTERY_OVERALL_DOC", "MASTERY_OVERALL_NGU_PHAP", "MASTERY_OVERALL_TU_VUNG",
		"MASTERY_OVERALL_INTERVIEW",
	} {
		t.Setenv(k, "")
	}
}

func newProgressTestServer(t *testing.T) (*httptest.Server, store.SkillMasteryStore) {
	t.Helper()
	unsetMasteryEnv(t)
	repo := store.NewMemoryStore()
	masteryStore := store.NewMemorySkillMasteryStore()
	srv := NewServerForTest(repo, nil)
	srv.SetMasteryDeps(masteryStore, processing.LoadMasteryConfig())
	return httptest.NewServer(srv.Handler()), masteryStore
}

func progressGet(t *testing.T, server *httptest.Server, token string) (int, map[string]any) {
	t.Helper()
	req, err := http.NewRequest(http.MethodGet, server.URL+"/v1/users/me/progress", nil)
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	resp, err := server.Client().Do(req)
	if err != nil {
		t.Fatalf("do: %v", err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	if len(body) == 0 {
		return resp.StatusCode, nil
	}
	var decoded map[string]any
	if err := json.Unmarshal(body, &decoded); err != nil {
		t.Fatalf("decode: %v; body=%s", err, body)
	}
	return resp.StatusCode, decoded
}

func TestProgressHandler_RequiresAuth(t *testing.T) {
	srv, _ := newProgressTestServer(t)
	defer srv.Close()
	status, _ := progressGet(t, srv, "")
	if status != http.StatusUnauthorized {
		t.Errorf("status = %d, want 401", status)
	}
}

func TestProgressHandler_EmptyUserReturnsZero(t *testing.T) {
	srv, _ := newProgressTestServer(t)
	defer srv.Close()
	status, body := progressGet(t, srv, "dev-learner-token")
	if status != http.StatusOK {
		t.Fatalf("status = %d, want 200", status)
	}
	data := body["data"].(map[string]any)
	if data["overall_progress"].(float64) != 0 {
		t.Errorf("overall_progress = %v, want 0", data["overall_progress"])
	}
	if data["overall_band"].(string) != "needs_work" {
		t.Errorf("overall_band = %v, want needs_work", data["overall_band"])
	}
	skills, _ := data["skills"].([]any)
	if len(skills) != 0 {
		t.Errorf("skills should be empty; got %d", len(skills))
	}
	if _, ok := data["bands"]; !ok {
		t.Error("response must surface bands map for the client")
	}
	if _, ok := data["weights"]; !ok {
		t.Error("response must surface weights map for the client")
	}
}

func TestProgressHandler_PopulatedWeightedOverall(t *testing.T) {
	srv, mastery := newProgressTestServer(t)
	defer srv.Close()

	// dev-learner-token resolves to user "user-learner-1" via the legacy
	// dev-fixture path; that's the user_id we must seed against.
	now := time.Date(2026, 5, 6, 12, 0, 0, 0, time.UTC)
	rows := []contracts.SkillMasteryRow{
		{UserID: "user-learner-1", SkillKind: "noi", ModuleID: "m_a", MasteryScore: 0.80, AttemptsCount: 4, LastAttemptAt: now, UpdatedAt: now},
		{UserID: "user-learner-1", SkillKind: "noi", ModuleID: "m_b", MasteryScore: 0.40, AttemptsCount: 2, LastAttemptAt: now, UpdatedAt: now},
		{UserID: "user-learner-1", SkillKind: "nghe", ModuleID: "m_a", MasteryScore: 0.90, AttemptsCount: 3, LastAttemptAt: now, UpdatedAt: now},
		// Exam-pool aggregate row keyed by empty module_id.
		{UserID: "user-learner-1", SkillKind: "doc", ModuleID: "", MasteryScore: 0.50, AttemptsCount: 1, LastAttemptAt: now, UpdatedAt: now},
	}
	for _, r := range rows {
		if _, err := mastery.Upsert(r); err != nil {
			t.Fatalf("seed: %v", err)
		}
	}

	status, body := progressGet(t, srv, "dev-learner-token")
	if status != http.StatusOK {
		t.Fatalf("status = %d, want 200", status)
	}
	data := body["data"].(map[string]any)

	skills := data["skills"].([]any)
	if len(skills) != 3 {
		t.Fatalf("expected 3 skill groups (noi, nghe, doc); got %d", len(skills))
	}
	bySkill := map[string]map[string]any{}
	for _, s := range skills {
		m := s.(map[string]any)
		bySkill[m["skill_kind"].(string)] = m
	}
	noi := bySkill["noi"]
	// noi mastery = mean(0.80, 0.40) = 0.60.
	if got := noi["mastery"].(float64); got < 0.59 || got > 0.61 {
		t.Errorf("noi mastery = %v, want ~0.60", got)
	}
	if got := noi["attempts_count"].(float64); got != 6 {
		t.Errorf("noi attempts_count = %v, want 6", got)
	}
	if mods, _ := noi["modules"].([]any); len(mods) != 2 {
		t.Errorf("noi modules = %d, want 2", len(mods))
	}

	nghe := bySkill["nghe"]
	if got := nghe["mastery"].(float64); got < 0.89 || got > 0.91 {
		t.Errorf("nghe mastery = %v, want ~0.90", got)
	}
	if got := nghe["band"].(string); got != "ready" {
		t.Errorf("nghe band = %q, want ready", got)
	}

	// Weighted overall (defaults: noi 25, nghe 20, doc 20, others 0):
	//   (0.60*25 + 0.90*20 + 0.50*20) / (25+20+20) = (15 + 18 + 10) / 65 ≈ 0.6615
	overall := data["overall_progress"].(float64)
	if overall < 0.65 || overall > 0.68 {
		t.Errorf("overall = %v, want ~0.66", overall)
	}
	if data["overall_band"].(string) != "needs_work" && data["overall_band"].(string) != "learning" {
		// 0.66 sits in "learning" with default thresholds.
		t.Errorf("overall_band = %v, want learning", data["overall_band"])
	}
}

func TestProgressHandler_RespectsEnvWeightOverride(t *testing.T) {
	unsetMasteryEnv(t)
	t.Setenv("MASTERY_OVERALL_NOI", "100")
	t.Setenv("MASTERY_OVERALL_NGHE", "0")
	t.Setenv("MASTERY_OVERALL_VIET", "0")
	t.Setenv("MASTERY_OVERALL_DOC", "0")
	t.Setenv("MASTERY_OVERALL_NGU_PHAP", "0")
	t.Setenv("MASTERY_OVERALL_TU_VUNG", "0")
	t.Setenv("MASTERY_OVERALL_INTERVIEW", "0")

	repo := store.NewMemoryStore()
	masteryStore := store.NewMemorySkillMasteryStore()
	srv := NewServerForTest(repo, nil)
	srv.SetMasteryDeps(masteryStore, processing.LoadMasteryConfig())
	httpSrv := httptest.NewServer(srv.Handler())
	defer httpSrv.Close()

	now := time.Date(2026, 5, 6, 12, 0, 0, 0, time.UTC)
	_, _ = masteryStore.Upsert(contracts.SkillMasteryRow{
		UserID: "user-learner-1", SkillKind: "noi", ModuleID: "m_a",
		MasteryScore: 0.40, AttemptsCount: 1, LastAttemptAt: now, UpdatedAt: now,
	})
	_, _ = masteryStore.Upsert(contracts.SkillMasteryRow{
		UserID: "user-learner-1", SkillKind: "nghe", ModuleID: "m_a",
		MasteryScore: 0.95, AttemptsCount: 1, LastAttemptAt: now, UpdatedAt: now,
	})

	_, body := progressGet(t, httpSrv, "dev-learner-token")
	data := body["data"].(map[string]any)
	overall := data["overall_progress"].(float64)
	// nghe weight = 0 → ignored. Overall = noi only = 0.40.
	if overall < 0.39 || overall > 0.41 {
		t.Errorf("overall = %v, want ~0.40 (noi only)", overall)
	}
}
