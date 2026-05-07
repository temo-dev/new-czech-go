package httpapi

import (
	"bytes"
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

// newPlacementTestServer wires the V21 placement deps onto NewServerForTest
// and seeds an is_placement=true MockTest unless skipSeed is true. Returns
// the placement mock test ID (memory store auto-assigns it; empty string
// when skipSeed is true).
func newPlacementTestServer(t *testing.T, now time.Time, skipSeed bool) (*httptest.Server, *store.MemoryStore, store.UserLevelStore, string) {
	t.Helper()
	unsetMasteryEnv(t)
	unsetLevelEnv(t)
	repo := store.NewMemoryStore()
	masteryStore := store.NewMemorySkillMasteryStore()
	userLevels := store.NewMemoryUserLevelStore()
	promo := store.NewMemoryPromotionAttemptsStore()

	placementID := ""
	if !skipSeed {
		created, err := repo.CreateMockTest(contracts.MockTest{
			Title: "Placement Test V21", Status: "published",
			IsPlacement:              true,
			EstimatedDurationMinutes: 12,
			Sections: []contracts.MockTestSection{
				// MaxPoints explicit so OverallScorePctFromSession has a
				// real denominator (V21 review C2). Set to 100 so
				// SetMockExamOverallScoreForTesting(score) directly
				// expresses score_pct in the placement happy-path test.
				{SequenceNo: 1, SkillKind: "doc", ExerciseID: "ex_doc_1", ExerciseType: "cteni_1", MaxPoints: 100},
			},
		})
		if err != nil {
			t.Fatalf("seed placement mock: %v", err)
		}
		placementID = created.ID
	}

	srv := NewServerForTest(repo, nil)
	srv.SetMasteryDeps(masteryStore, processing.LoadMasteryConfig())
	srv.SetLevelDeps(LevelDeps{
		Service: &processing.LevelService{
			Config:        processing.LoadLevelConfig(),
			Mastery:       masteryStore,
			UserLevels:    userLevels,
			PromoAttempts: promo,
			Now:           func() time.Time { return now },
		},
		UserLevels: userLevels,
	})
	return httptest.NewServer(srv.Handler()), repo, userLevels, placementID
}

func placementPost(t *testing.T, srv *httptest.Server, path, token string, body any) (int, map[string]any) {
	t.Helper()
	var buf bytes.Buffer
	if body != nil {
		if err := json.NewEncoder(&buf).Encode(body); err != nil {
			t.Fatalf("encode body: %v", err)
		}
	}
	req, err := http.NewRequest(http.MethodPost, srv.URL+path, &buf)
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := srv.Client().Do(req)
	if err != nil {
		t.Fatalf("do: %v", err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	if len(raw) == 0 {
		return resp.StatusCode, nil
	}
	var decoded map[string]any
	if err := json.Unmarshal(raw, &decoded); err != nil {
		t.Fatalf("decode: %v; body=%s", err, raw)
	}
	return resp.StatusCode, decoded
}

func TestPlacementHandler_Start_RequiresAuth(t *testing.T) {
	srv, _, _, _ := newPlacementTestServer(t, time.Date(2026, 5, 7, 12, 0, 0, 0, time.UTC), false)
	defer srv.Close()
	status, _ := placementPost(t, srv, "/v1/users/me/placement-test/start", "", nil)
	if status != http.StatusUnauthorized {
		t.Errorf("status = %d, want 401", status)
	}
}

func TestPlacementHandler_Start_FreshUserCreatesSession(t *testing.T) {
	srv, _, _, placementID := newPlacementTestServer(t, time.Date(2026, 5, 7, 12, 0, 0, 0, time.UTC), false)
	defer srv.Close()

	status, body := placementPost(t, srv, "/v1/users/me/placement-test/start", "dev-learner-token", nil)
	if status != http.StatusCreated {
		t.Fatalf("status = %d, want 201; body=%v", status, body)
	}
	data := body["data"].(map[string]any)
	if data["mock_test_id"].(string) != placementID {
		t.Errorf("mock_test_id = %v, want %s", data["mock_test_id"], placementID)
	}
	if data["full_session_id"].(string) == "" {
		t.Error("full_session_id missing")
	}
}

// V21 review I3: a draft placement mock must not be served to learners.
func TestPlacementHandler_Start_DraftPlacementMockNotPicked_404(t *testing.T) {
	srv, repo, _, _ := newPlacementTestServer(t, time.Date(2026, 5, 7, 12, 0, 0, 0, time.UTC), true)
	defer srv.Close()

	if _, err := repo.CreateMockTest(contracts.MockTest{
		Title: "Draft placement", Status: "draft",
		IsPlacement: true,
		Sections: []contracts.MockTestSection{
			{SequenceNo: 1, SkillKind: "doc", ExerciseID: "ex_doc_1", ExerciseType: "cteni_1", MaxPoints: 100},
		},
	}); err != nil {
		t.Fatalf("seed draft placement: %v", err)
	}

	status, body := placementPost(t, srv, "/v1/users/me/placement-test/start",
		"dev-learner-token", nil)
	if status != http.StatusNotFound {
		t.Fatalf("status = %d, want 404 (draft must not be served); body=%v",
			status, body)
	}
	if code := errCode(body); code != "placement_not_configured" {
		t.Errorf("error.code = %q, want placement_not_configured", code)
	}
}

func TestPlacementHandler_Start_NoConfiguredPlacementMock_404(t *testing.T) {
	srv, _, _, _ := newPlacementTestServer(t, time.Date(2026, 5, 7, 12, 0, 0, 0, time.UTC), true)
	defer srv.Close()

	status, body := placementPost(t, srv, "/v1/users/me/placement-test/start", "dev-learner-token", nil)
	if status != http.StatusNotFound {
		t.Fatalf("status = %d, want 404", status)
	}
	if errBody, ok := body["error"].(map[string]any); ok {
		if code := errBody["code"].(string); code != "placement_not_configured" {
			t.Errorf("error.code = %q, want placement_not_configured", code)
		}
	}
}

func TestPlacementHandler_Start_AlreadyTaken_409WithoutForce(t *testing.T) {
	srv, _, userLevels, _ := newPlacementTestServer(t, time.Date(2026, 5, 7, 12, 0, 0, 0, time.UTC), false)
	defer srv.Close()

	if _, err := userLevels.MarkPlacementTaken("user-learner-1", "a1", time.Date(2026, 5, 1, 9, 0, 0, 0, time.UTC)); err != nil {
		t.Fatalf("seed placement_taken_at: %v", err)
	}

	status, body := placementPost(t, srv, "/v1/users/me/placement-test/start", "dev-learner-token", nil)
	if status != http.StatusConflict {
		t.Fatalf("status = %d, want 409; body=%v", status, body)
	}

	// ?force=true bypasses the conflict and creates a new session.
	status2, body2 := placementPost(t, srv, "/v1/users/me/placement-test/start?force=true", "dev-learner-token", nil)
	if status2 != http.StatusCreated {
		t.Fatalf("force status = %d, want 201; body=%v", status2, body2)
	}
}

func TestPlacementHandler_Complete_HappyPath(t *testing.T) {
	srv, repo, userLevels, _ := newPlacementTestServer(t, time.Date(2026, 5, 7, 12, 0, 0, 0, time.UTC), false)
	defer srv.Close()

	startStatus, startBody := placementPost(t, srv, "/v1/users/me/placement-test/start", "dev-learner-token", nil)
	if startStatus != http.StatusCreated {
		t.Fatalf("start status = %d", startStatus)
	}
	sessionID := startBody["data"].(map[string]any)["full_session_id"].(string)

	// Simulate the scoring pipeline finishing — overall_score = 60 maps to a2.
	if !repo.SetMockExamOverallScoreForTesting(sessionID, 60) {
		t.Fatalf("seed overall_score: session not found")
	}

	status, body := placementPost(t, srv, "/v1/users/me/placement-test/complete", "dev-learner-token",
		map[string]string{"full_session_id": sessionID})
	if status != http.StatusOK {
		t.Fatalf("complete status = %d; body=%v", status, body)
	}
	data := body["data"].(map[string]any)
	if data["assigned_level"].(string) != "a2" {
		t.Errorf("assigned_level = %v, want a2 (score 60 → a2 band)", data["assigned_level"])
	}
	if data["current_level"].(string) != "a2" {
		t.Errorf("current_level = %v, want a2", data["current_level"])
	}
	if data["placement_taken_at"] == nil {
		t.Error("placement_taken_at = nil after complete")
	}

	// Persisted on the user level store.
	got, ok := userLevels.GetUserLevel("user-learner-1")
	if !ok {
		t.Fatal("user level row missing after complete")
	}
	if got.PlacementTakenAt == nil {
		t.Error("PlacementTakenAt not persisted")
	}
	if got.CurrentLevel != "a2" {
		t.Errorf("persisted current_level = %q, want a2", got.CurrentLevel)
	}
}

func TestPlacementHandler_Complete_WrongOwner_404(t *testing.T) {
	srv, repo, _, placementID := newPlacementTestServer(t, time.Date(2026, 5, 7, 12, 0, 0, 0, time.UTC), false)
	defer srv.Close()

	// Create a session owned by a *different* user, then try to complete it
	// as user-learner-1. The handler must hide the session entirely (404).
	other, err := repo.CreateMockExam("user-someone-else", placementID)
	if err != nil {
		t.Fatalf("seed other-user session: %v", err)
	}
	repo.SetMockExamOverallScoreForTesting(other.ID, 50)

	status, _ := placementPost(t, srv, "/v1/users/me/placement-test/complete", "dev-learner-token",
		map[string]string{"full_session_id": other.ID})
	if status != http.StatusNotFound {
		t.Errorf("status = %d, want 404", status)
	}
}

// V21 review C1: a session for a non-placement MockTest must NOT be
// accepted by /placement-test/complete. Without this guard a learner
// could submit any of their regular mock_exam_session ids and bypass
// the placement test entirely.
func TestPlacementHandler_Complete_RejectsNonPlacementSession_404(t *testing.T) {
	srv, repo, _, _ := newPlacementTestServer(t, time.Date(2026, 5, 7, 12, 0, 0, 0, time.UTC), false)
	defer srv.Close()

	plain, err := repo.CreateMockTest(contracts.MockTest{
		Title: "Practice Mock", Status: "published",
		Sections: []contracts.MockTestSection{
			{SequenceNo: 1, SkillKind: "doc", ExerciseID: "ex_doc_1", ExerciseType: "cteni_1", MaxPoints: 100},
		},
	})
	if err != nil {
		t.Fatalf("seed plain mock: %v", err)
	}
	session, err := repo.CreateMockExam("user-learner-1", plain.ID)
	if err != nil {
		t.Fatalf("seed practice session: %v", err)
	}
	repo.SetMockExamOverallScoreForTesting(session.ID, 80)

	status, _ := placementPost(t, srv, "/v1/users/me/placement-test/complete",
		"dev-learner-token", map[string]string{"full_session_id": session.ID})
	if status != http.StatusNotFound {
		t.Errorf("status = %d, want 404 (non-placement session must not assign level)", status)
	}
}

// V21 review I2 + I8: /placement-test/start is rate-limited (5/min per
// user) so concurrent calls cannot exhaust mock_exam_session creation
// AND the TOCTOU race between two simultaneous "first placement" calls
// is naturally bounded.
func TestPlacementHandler_Start_RateLimitedAfter5RequestsPerMinute(t *testing.T) {
	srv, _, _, _ := newPlacementTestServer(t, time.Date(2026, 5, 7, 12, 0, 0, 0, time.UTC), false)
	defer srv.Close()

	for i := 0; i < 5; i++ {
		status, _ := placementPost(t, srv, "/v1/users/me/placement-test/start?force=true",
			"dev-learner-token", nil)
		if status != http.StatusCreated {
			t.Fatalf("call #%d status = %d, want 201", i+1, status)
		}
	}
	status, body := placementPost(t, srv, "/v1/users/me/placement-test/start?force=true",
		"dev-learner-token", nil)
	if status != http.StatusTooManyRequests {
		t.Fatalf("6th call status = %d, want 429; body=%v", status, body)
	}
	if code := errCode(body); code != "rate_limited" {
		t.Errorf("error.code = %q, want rate_limited", code)
	}
}

func TestPlacementHandler_Complete_MissingBody_400(t *testing.T) {
	srv, _, _, _ := newPlacementTestServer(t, time.Date(2026, 5, 7, 12, 0, 0, 0, time.UTC), false)
	defer srv.Close()

	status, body := placementPost(t, srv, "/v1/users/me/placement-test/complete", "dev-learner-token",
		map[string]string{})
	if status != http.StatusBadRequest {
		t.Errorf("status = %d, want 400; body=%v", status, body)
	}
}
