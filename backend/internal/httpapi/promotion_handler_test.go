package httpapi

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/processing"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

// newPromotionTestServer wires the V21 promotion deps onto NewServerForTest
// and seeds an is_promotion=true MockTest targeting "b1". Returns the test
// server, the underlying memory store, the wired stores, and the seeded
// promotion mock test ID. Tests use the stores to manipulate gating state
// (mastery, prior failed attempts, user level).
func newPromotionTestServer(t *testing.T, now time.Time) (
	server *httptest.Server,
	repo *store.MemoryStore,
	mastery store.SkillMasteryStore,
	userLevels store.UserLevelStore,
	promo store.PromotionAttemptsStore,
	promoMockID string,
) {
	t.Helper()
	unsetMasteryEnv(t)
	unsetLevelEnv(t)
	repo = store.NewMemoryStore()
	mastery = store.NewMemorySkillMasteryStore()
	userLevels = store.NewMemoryUserLevelStore()
	promo = store.NewMemoryPromotionAttemptsStore()

	created, err := repo.CreateMockTest(contracts.MockTest{
		Title:                    "Promotion to B1",
		Status:                   "published",
		IsPromotion:              true,
		TargetLevel:              "b1",
		EstimatedDurationMinutes: 90,
		Sections: []contracts.MockTestSection{
			{SequenceNo: 1, SkillKind: "doc", ExerciseID: "ex_doc_1", ExerciseType: "cteni_1"},
		},
	})
	if err != nil {
		t.Fatalf("seed promotion mock: %v", err)
	}
	promoMockID = created.ID

	srv := NewServerForTest(repo, nil)
	srv.SetMasteryDeps(mastery, processing.LoadMasteryConfig())
	srv.SetLevelDeps(LevelDeps{
		Service: &processing.LevelService{
			Config:        processing.LoadLevelConfig(),
			Mastery:       mastery,
			UserLevels:    userLevels,
			PromoAttempts: promo,
			Now:           func() time.Time { return now },
		},
		UserLevels:    userLevels,
		PromoAttempts: promo,
	})
	server = httptest.NewServer(srv.Handler())
	return
}

func seedPassingMastery(t *testing.T, mastery store.SkillMasteryStore, userID string, when time.Time) {
	t.Helper()
	for _, k := range []string{"noi", "viet", "nghe", "doc", "tu_vung", "ngu_phap"} {
		if _, err := mastery.Upsert(contracts.SkillMasteryRow{
			UserID: userID, SkillKind: k, ModuleID: "m1",
			MasteryScore: 0.85, AttemptsCount: 4,
			LastAttemptAt: when, UpdatedAt: when,
		}); err != nil {
			t.Fatalf("seed mastery %s: %v", k, err)
		}
	}
}

func errCode(body map[string]any) string {
	errBody, ok := body["error"].(map[string]any)
	if !ok {
		return ""
	}
	c, _ := errBody["code"].(string)
	return c
}

func TestPromotionHandler_RequiresAuth(t *testing.T) {
	srv, _, _, _, _, mockID := newPromotionTestServer(t, time.Date(2026, 5, 7, 12, 0, 0, 0, time.UTC))
	defer srv.Close()
	status, _ := placementPost(t, srv, "/v1/promotion-attempts", "", map[string]string{"mock_test_id": mockID})
	if status != http.StatusUnauthorized {
		t.Errorf("status = %d, want 401", status)
	}
}

func TestPromotionHandler_MockTestNotFound_404(t *testing.T) {
	srv, _, _, _, _, _ := newPromotionTestServer(t, time.Date(2026, 5, 7, 12, 0, 0, 0, time.UTC))
	defer srv.Close()
	status, body := placementPost(t, srv, "/v1/promotion-attempts", "dev-learner-token",
		map[string]string{"mock_test_id": "does_not_exist"})
	if status != http.StatusNotFound {
		t.Fatalf("status = %d, want 404; body=%v", status, body)
	}
	if code := errCode(body); code != "mock_test_not_found" {
		t.Errorf("error.code = %q, want mock_test_not_found", code)
	}
}

func TestPromotionHandler_MockTestNotPromotion_400(t *testing.T) {
	srv, repo, _, _, _, _ := newPromotionTestServer(t, time.Date(2026, 5, 7, 12, 0, 0, 0, time.UTC))
	defer srv.Close()

	plain, err := repo.CreateMockTest(contracts.MockTest{
		Title: "Practice Mock", Status: "published",
		Sections: []contracts.MockTestSection{
			{SequenceNo: 1, SkillKind: "doc", ExerciseID: "ex_doc_1", ExerciseType: "cteni_1"},
		},
	})
	if err != nil {
		t.Fatalf("seed plain mock: %v", err)
	}
	status, body := placementPost(t, srv, "/v1/promotion-attempts", "dev-learner-token",
		map[string]string{"mock_test_id": plain.ID})
	if status != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400; body=%v", status, body)
	}
	if code := errCode(body); code != "mock_test_not_promotion" {
		t.Errorf("error.code = %q, want mock_test_not_promotion", code)
	}
}

func TestPromotionHandler_AlreadyUnlocked_409(t *testing.T) {
	srv, _, _, userLevels, _, mockID := newPromotionTestServer(t, time.Date(2026, 5, 7, 12, 0, 0, 0, time.UTC))
	defer srv.Close()

	if _, err := userLevels.SetUserLevel("user-learner-1", "b1"); err != nil {
		t.Fatalf("seed user level: %v", err)
	}
	status, body := placementPost(t, srv, "/v1/promotion-attempts", "dev-learner-token",
		map[string]string{"mock_test_id": mockID})
	if status != http.StatusConflict {
		t.Fatalf("status = %d, want 409; body=%v", status, body)
	}
	if code := errCode(body); code != "level_already_unlocked" {
		t.Errorf("error.code = %q, want level_already_unlocked", code)
	}
}

func TestPromotionHandler_GatingNotMet_400PromotionLocked(t *testing.T) {
	srv, _, _, userLevels, _, mockID := newPromotionTestServer(t, time.Date(2026, 5, 7, 12, 0, 0, 0, time.UTC))
	defer srv.Close()

	if _, err := userLevels.SetUserLevel("user-learner-1", "a2"); err != nil {
		t.Fatalf("seed user level: %v", err)
	}
	status, body := placementPost(t, srv, "/v1/promotion-attempts", "dev-learner-token",
		map[string]string{"mock_test_id": mockID})
	if status != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400; body=%v", status, body)
	}
	if code := errCode(body); code != "promotion_locked" {
		t.Errorf("error.code = %q, want promotion_locked", code)
	}
}

func TestPromotionHandler_CooldownActive_400(t *testing.T) {
	now := time.Date(2026, 5, 7, 12, 0, 0, 0, time.UTC)
	srv, _, mastery, userLevels, promo, mockID := newPromotionTestServer(t, now)
	defer srv.Close()

	if _, err := userLevels.SetUserLevel("user-learner-1", "a2"); err != nil {
		t.Fatalf("seed user level: %v", err)
	}
	seedPassingMastery(t, mastery, "user-learner-1", now.Add(-2*time.Hour))

	failed, err := promo.Create(contracts.PromotionAttempt{
		UserID:      "user-learner-1",
		MockTestID:  mockID,
		SourceLevel: "a2", TargetLevel: "b1",
		CreatedAt: now.Add(-1 * time.Hour),
	})
	if err != nil {
		t.Fatalf("seed promo: %v", err)
	}
	if _, err := promo.MarkResult(failed.ID, false, 45.0, map[string]float64{"viet": 50}); err != nil {
		t.Fatalf("mark fail: %v", err)
	}

	status, body := placementPost(t, srv, "/v1/promotion-attempts", "dev-learner-token",
		map[string]string{"mock_test_id": mockID})
	if status != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400; body=%v", status, body)
	}
	if code := errCode(body); code != "cooldown_active" {
		t.Errorf("error.code = %q, want cooldown_active", code)
	}
	if errMap, ok := body["error"].(map[string]any); ok {
		if _, hasRetry := errMap["retry_after"]; !hasRetry {
			t.Errorf("error.retry_after missing on cooldown_active; body=%v", body)
		}
	}
}

func TestPromotionHandler_HappyPath_201(t *testing.T) {
	now := time.Date(2026, 5, 7, 12, 0, 0, 0, time.UTC)
	srv, _, mastery, userLevels, _, mockID := newPromotionTestServer(t, now)
	defer srv.Close()

	if _, err := userLevels.SetUserLevel("user-learner-1", "a2"); err != nil {
		t.Fatalf("seed user level: %v", err)
	}
	seedPassingMastery(t, mastery, "user-learner-1", now.Add(-2*time.Hour))

	status, body := placementPost(t, srv, "/v1/promotion-attempts", "dev-learner-token",
		map[string]string{"mock_test_id": mockID})
	if status != http.StatusCreated {
		t.Fatalf("status = %d, want 201; body=%v", status, body)
	}
	data := body["data"].(map[string]any)
	if data["target_level"].(string) != "b1" {
		t.Errorf("target_level = %v, want b1", data["target_level"])
	}
	if data["full_session_id"].(string) == "" {
		t.Error("full_session_id missing")
	}
	if data["promotion_attempt_id"].(string) == "" {
		t.Error("promotion_attempt_id missing")
	}
}
