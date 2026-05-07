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

// TestV21LevelFlow_E2E_PromotionPassUnlocksTargetLevel exercises the
// V21 happy path end-to-end against the in-process HTTP server:
//
//	signup (dev fixture) → skip placement → seed passing mastery
//	→ GET /v1/users/me/level-progress (promotion_unlocked=true)
//	→ POST /v1/promotion-attempts → simulate scoring pass
//	→ HandlePromotionOutcome hook → user level == b1.
//
// The standalone *_test.go file is the V21-E1 smoke; `make
// smoke-promotion-flow` shells out to `go test -run TestV21LevelFlow_E2E`.
// Stability-wise this is preferred over a Python script + running
// server: zero network deps, zero docker bring-up, no flake from port
// races.
func TestV21LevelFlow_E2E_PromotionPassUnlocksTargetLevel(t *testing.T) {
	now := time.Date(2026, 5, 7, 12, 0, 0, 0, time.UTC)
	srv, repo, mastery, userLevels, promo, mockID := newPromotionTestServer(t, now)
	defer srv.Close()

	// 1. Skip placement → user lands on a2 (the migration-day default).
	if _, err := userLevels.SetUserLevel("user-learner-1", "a2"); err != nil {
		t.Fatalf("seed user level: %v", err)
	}
	seedPassingMastery(t, mastery, "user-learner-1", now.Add(-2*time.Hour))

	// 2. Confirm gates are met server-side.
	progress := mustFetchLevelProgress(t, srv, "dev-learner-token")
	if !progress.AllSkillsPass {
		t.Fatal("all_skills_pass = false; expected true with seeded mastery")
	}
	if !progress.PromotionUnlocked {
		t.Fatal("promotion_unlocked = false; expected true after mastery + coverage gates")
	}

	// 3. Create promotion attempt — server allocates a session + a row.
	attemptStatus, attemptBody := v21FlowPostJSON(t, srv,
		"/v1/promotion-attempts", "dev-learner-token",
		map[string]string{"mock_test_id": mockID})
	if attemptStatus != http.StatusCreated {
		t.Fatalf("promotion attempt status = %d; body=%v", attemptStatus, attemptBody)
	}
	data := attemptBody["data"].(map[string]any)
	sessionID := data["full_session_id"].(string)
	promoAttemptID := data["promotion_attempt_id"].(string)
	if sessionID == "" || promoAttemptID == "" {
		t.Fatalf("promotion attempt response missing ids: %v", data)
	}

	// 4. Simulate scoring: server normally writes overall_score via
	//    CompleteMockExam after every section attempt finishes. The hook
	//    in handleMockExamComplete then fires HandlePromotionOutcome.
	//    For the smoke we drive both directly so the test stays sealed
	//    against the per-attempt scoring pipeline.
	if !repo.SetMockExamOverallScoreForTesting(sessionID, 78) {
		t.Fatalf("seed session overall score: session not found")
	}
	session, _ := repo.MockExamByID(sessionID)
	session.Passed = true
	session.Sections = []contracts.MockExamSessionItem{
		{SkillKind: "doc", MaxPoints: 10, SectionScore: 9, Status: "completed"},
		{SkillKind: "viet", MaxPoints: 10, SectionScore: 8, Status: "completed"},
	}
	processed, err := processing.HandlePromotionOutcome(processing.PromotionHookDeps{
		PromoAttempts: promo,
		UserLevels:    userLevels,
	}, session)
	if err != nil {
		t.Fatalf("HandlePromotionOutcome: %v", err)
	}
	if !processed {
		t.Fatal("HandlePromotionOutcome returned false; expected processed")
	}

	// 5. User level now b1 — verify both via the store and via the
	//    public level-progress endpoint (server is the source of truth).
	updated, _ := userLevels.GetUserLevel("user-learner-1")
	if updated.CurrentLevel != "b1" {
		t.Errorf("CurrentLevel = %q, want b1", updated.CurrentLevel)
	}
	foundB1 := false
	for _, lvl := range updated.UnlockedLevels {
		if lvl == "b1" {
			foundB1 = true
		}
	}
	if !foundB1 {
		t.Errorf("UnlockedLevels = %v, want to contain b1", updated.UnlockedLevels)
	}
	after := mustFetchLevelProgress(t, srv, "dev-learner-token")
	if after.CurrentLevel != "b1" {
		t.Errorf("level-progress current_level = %q, want b1 after promotion",
			after.CurrentLevel)
	}

	// 6. Promotion ledger row carries the outcome.
	pa, ok := promo.GetByFullSessionID(sessionID)
	if !ok {
		t.Fatal("promotion attempt missing after hook")
	}
	if pa.ID != promoAttemptID {
		t.Errorf("ledger id mismatch: got %s want %s", pa.ID, promoAttemptID)
	}
	if !pa.Passed || pa.ScorePct != 78 {
		t.Errorf("ledger row not marked pass: %+v", pa)
	}
}

// TestV21LevelFlow_E2E_FailureLocksRetryWithCooldown covers the
// cooldown re-entry path: a failed promotion does not promote the user
// and a second attempt within the cooldown window is rejected with
// `400 cooldown_active`.
func TestV21LevelFlow_E2E_FailureLocksRetryWithCooldown(t *testing.T) {
	now := time.Date(2026, 5, 7, 12, 0, 0, 0, time.UTC)
	srv, repo, mastery, userLevels, promo, mockID := newPromotionTestServer(t, now)
	defer srv.Close()

	if _, err := userLevels.SetUserLevel("user-learner-1", "a2"); err != nil {
		t.Fatalf("seed user level: %v", err)
	}
	seedPassingMastery(t, mastery, "user-learner-1", now.Add(-2*time.Hour))

	// First attempt — gates pass, fail the exam.
	createStatus, createBody := v21FlowPostJSON(t, srv,
		"/v1/promotion-attempts", "dev-learner-token",
		map[string]string{"mock_test_id": mockID})
	if createStatus != http.StatusCreated {
		t.Fatalf("first promotion attempt status = %d; body=%v",
			createStatus, createBody)
	}
	sessionID := createBody["data"].(map[string]any)["full_session_id"].(string)
	repo.SetMockExamOverallScoreForTesting(sessionID, 45)
	session, _ := repo.MockExamByID(sessionID)
	session.Passed = false
	session.Sections = []contracts.MockExamSessionItem{
		{SkillKind: "viet", MaxPoints: 10, SectionScore: 4, Status: "completed"},
	}
	if _, err := processing.HandlePromotionOutcome(processing.PromotionHookDeps{
		PromoAttempts: promo,
		UserLevels:    userLevels,
	}, session); err != nil {
		t.Fatalf("HandlePromotionOutcome (fail): %v", err)
	}

	// User level untouched after a fail.
	updated, _ := userLevels.GetUserLevel("user-learner-1")
	if updated.CurrentLevel != "a2" {
		t.Errorf("CurrentLevel = %q, want a2 after fail (no promotion)",
			updated.CurrentLevel)
	}

	// Second attempt within the cooldown — server should refuse with
	// `cooldown_active` AND return the retry_after timestamp so the
	// PromotionResultScreen fail card can render the live timer.
	retryStatus, retryBody := v21FlowPostJSON(t, srv,
		"/v1/promotion-attempts", "dev-learner-token",
		map[string]string{"mock_test_id": mockID})
	if retryStatus != http.StatusBadRequest {
		t.Fatalf("retry status = %d, want 400; body=%v",
			retryStatus, retryBody)
	}
	if code := errCode(retryBody); code != "cooldown_active" {
		t.Errorf("retry error.code = %q, want cooldown_active", code)
	}
	if errMap, ok := retryBody["error"].(map[string]any); ok {
		if _, has := errMap["retry_after"]; !has {
			t.Errorf("retry response missing retry_after; body=%v", retryBody)
		}
	}
}

// ── shared helpers ─────────────────────────────────────────────────────────

func mustFetchLevelProgress(t *testing.T, srv *httptest.Server, token string) lpData {
	t.Helper()
	req, err := http.NewRequest(http.MethodGet, srv.URL+"/v1/users/me/level-progress", nil)
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err := srv.Client().Do(req)
	if err != nil {
		t.Fatalf("do: %v", err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("level-progress status = %d; body=%s", resp.StatusCode, body)
	}
	var decoded struct {
		Data lpData `json:"data"`
	}
	if err := json.Unmarshal(body, &decoded); err != nil {
		t.Fatalf("decode: %v", err)
	}
	return decoded.Data
}

type lpData struct {
	CurrentLevel      string `json:"current_level"`
	AllSkillsPass     bool   `json:"all_skills_pass"`
	PromotionUnlocked bool   `json:"promotion_unlocked"`
}

func v21FlowPostJSON(t *testing.T, srv *httptest.Server, path, token string, body any) (int, map[string]any) {
	t.Helper()
	var buf bytes.Buffer
	if body != nil {
		if err := json.NewEncoder(&buf).Encode(body); err != nil {
			t.Fatalf("encode: %v", err)
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

// stop the linter from flagging store as unused if signatures change.
var _ store.UserLevelStore = (store.UserLevelStore)(nil)
