package httpapi

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/email"
	"github.com/danieldev/czech-go-system/backend/internal/iap"
	"github.com/danieldev/czech-go-system/backend/internal/processing"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

// xrayTestEnv wires V17 auth + V19 mastery + V21 level/promotion stores
// onto a single httptest.Server so the admin X-Ray endpoint can be
// exercised end-to-end. Test seeds rows directly through the exposed
// stores so we never depend on internal HTTP flows.
type xrayTestEnv struct {
	srv     *httptest.Server
	repo    *store.MemoryStore
	users   store.UserStore
	mastery store.SkillMasteryStore
	levels  store.UserLevelStore
	promo   store.PromotionAttemptsStore
	usage   store.DailyUsageStore
}

func newXRayTestEnv(t *testing.T) *xrayTestEnv {
	t.Helper()

	repo := store.NewMemoryStore()
	users := newMemoryUserStoreForTest(t)
	tokens := newMemoryAuthTokenStoreForTest(t)
	streaks := store.NewMemoryStreakStore()
	usage := store.NewMemoryDailyUsageStore()
	purchases := store.NewMemoryProPurchaseStore()
	mastery := store.NewMemorySkillMasteryStore()
	levels := store.NewMemoryUserLevelStore()
	promo := store.NewMemoryPromotionAttemptsStore()

	deps := AuthDeps{
		Users:         users,
		AuthTokens:    tokens,
		Streaks:       streaks,
		DailyUsage:    usage,
		ProPurchases:  purchases,
		SkillMastery:  mastery,
		EmailSender:   email.NewRecorderSender(),
		AppleVerifier: &iap.FakeAppleVerifier{},
		BaseURL:       "https://api.example.test",
		VerifyTTL:     24 * time.Hour,
	}
	levelDeps := &LevelDeps{
		Service: &processing.LevelService{
			Config:        processing.LoadLevelConfig(),
			Mastery:       mastery,
			UserLevels:    levels,
			PromoAttempts: promo,
			Now:           func() time.Time { return time.Now().UTC() },
		},
		UserLevels:    levels,
		PromoAttempts: promo,
	}
	handler := NewServerWithAuth(repo, nil, nil, nil, nil, deps, levelDeps)
	srv := httptest.NewServer(handler)
	t.Cleanup(srv.Close)
	return &xrayTestEnv{
		srv:     srv,
		repo:    repo,
		users:   users,
		mastery: mastery,
		levels:  levels,
		promo:   promo,
		usage:   usage,
	}
}

func xrayGet(t *testing.T, env *xrayTestEnv, userID string, token string) (*http.Response, contracts.LearnerStateResponse) {
	t.Helper()
	req, _ := http.NewRequest(http.MethodGet, env.srv.URL+"/v1/admin/users/"+userID+"/state", nil)
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("xray GET: %v", err)
	}
	t.Cleanup(func() { resp.Body.Close() })
	var out contracts.LearnerStateResponse
	if resp.StatusCode == http.StatusOK {
		if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
			t.Fatalf("decode: %v", err)
		}
	}
	return resp, out
}

func TestAdminUserState_RequiresAdmin_LearnerToken_Returns403(t *testing.T) {
	env := newXRayTestEnv(t)
	u, err := env.users.CreateUser(contracts.UserAccount{
		Email: "alice@example.com", PasswordHash: "x", DisplayName: "Alice",
	})
	if err != nil {
		t.Fatalf("seed: %v", err)
	}
	// Use the legacy dev-learner-token (Role="user") through the repo's
	// usersByToken map — exercises the withRole gate.
	resp, _ := xrayGet(t, env, u.ID, "dev-learner-token")
	if resp.StatusCode != http.StatusForbidden {
		t.Errorf("want 403, got %d", resp.StatusCode)
	}
}

func TestAdminUserState_NotFound_Returns404(t *testing.T) {
	env := newXRayTestEnv(t)
	resp, _ := xrayGet(t, env, "user-does-not-exist", devAdminToken)
	if resp.StatusCode != http.StatusNotFound {
		t.Errorf("want 404, got %d", resp.StatusCode)
	}
}

func TestAdminUserState_HappyFull_ReturnsAllSections(t *testing.T) {
	env := newXRayTestEnv(t)
	now := time.Now().UTC()
	u, err := env.users.CreateUser(contracts.UserAccount{
		Email: "alice@example.com", PasswordHash: "x", DisplayName: "Alice",
		Role: "user", ProTier: "free",
	})
	if err != nil {
		t.Fatalf("seed user: %v", err)
	}
	// Mark placement so level state has a placement_taken_at.
	if _, err := env.levels.MarkPlacementTaken(u.ID, "a2", now.Add(-30*24*time.Hour)); err != nil {
		t.Fatalf("placement: %v", err)
	}
	// Seed 1 mastery row.
	if _, err := env.mastery.Upsert(contracts.SkillMasteryRow{
		UserID: u.ID, SkillKind: "noi", ModuleID: "mod-giao-tiep",
		MasteryScore: 0.74, AttemptsCount: 18,
		UpdatedAt: now.Add(-1 * time.Hour),
	}); err != nil {
		t.Fatalf("mastery: %v", err)
	}
	// Seed 1 promotion attempt.
	if _, err := env.promo.Create(contracts.PromotionAttempt{
		UserID: u.ID, TargetLevel: "b1", SourceLevel: "a2",
		MockTestID: "mt-promo-b1",
		Passed:     false, ScorePct: 62,
		CreatedAt: now.Add(-2 * time.Hour),
	}); err != nil {
		t.Fatalf("promo: %v", err)
	}
	// Seed 1 daily usage row.
	if _, err := env.usage.IncrementAttempts(u.ID, now); err != nil {
		t.Fatalf("usage: %v", err)
	}
	// Seed 1 attempt.
	if _, err := env.repo.CreateAttempt(u.ID, "exercise-uloha1-weather", "ios", "0.1.0", "vi"); err != nil {
		t.Fatalf("attempt: %v", err)
	}

	resp, body := xrayGet(t, env, u.ID, devAdminToken)
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("want 200, got %d", resp.StatusCode)
	}

	if body.User.ID != u.ID || body.User.Email != "alice@example.com" {
		t.Errorf("user block wrong: %+v", body.User)
	}
	if body.LevelState.CurrentLevel != "a2" {
		t.Errorf("current_level = %q, want a2", body.LevelState.CurrentLevel)
	}
	if body.LevelState.PlacementTakenAt == nil {
		t.Error("placement_taken_at must be set after MarkPlacementTaken")
	}
	if len(body.Mastery) != 1 {
		t.Errorf("mastery len = %d, want 1", len(body.Mastery))
	} else if body.Mastery[0].SkillKind != "noi" || body.Mastery[0].Score != 0.74 {
		t.Errorf("mastery row wrong: %+v", body.Mastery[0])
	}
	if len(body.PromotionAttempts) != 1 {
		t.Errorf("promotion_attempts len = %d, want 1", len(body.PromotionAttempts))
	} else if body.PromotionAttempts[0].TargetLevel != "b1" || body.PromotionAttempts[0].Passed {
		t.Errorf("promo row wrong: %+v", body.PromotionAttempts[0])
	}
	if body.HasMorePromotion {
		t.Error("has_more_promotion must be false with 1 row")
	}
	if body.DailyUsage.AttemptsCount != 1 {
		t.Errorf("daily_usage.attempts_count = %d, want 1", body.DailyUsage.AttemptsCount)
	}
	if body.DailyUsage.AttemptsCap == 0 {
		t.Error("daily_usage.attempts_cap must be non-zero (free-tier baseline)")
	}
	if len(body.RecentAttempts) != 1 {
		t.Errorf("recent_attempts len = %d, want 1", len(body.RecentAttempts))
	}
}

func TestAdminUserState_NoMastery_ReturnsEmptyArrays(t *testing.T) {
	env := newXRayTestEnv(t)
	u, err := env.users.CreateUser(contracts.UserAccount{
		Email: "fresh@example.com", PasswordHash: "x", DisplayName: "Fresh",
		Role: "user", ProTier: "free",
	})
	if err != nil {
		t.Fatalf("seed: %v", err)
	}

	resp, body := xrayGet(t, env, u.ID, devAdminToken)
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("want 200, got %d", resp.StatusCode)
	}
	// JSON decoded into typed struct: nil and empty slice both deserialize
	// the same way. We just check len==0 — the contract guarantees `[]`,
	// not `null`, on the wire.
	if len(body.Mastery) != 0 {
		t.Errorf("mastery len = %d, want 0", len(body.Mastery))
	}
	if len(body.PromotionAttempts) != 0 {
		t.Errorf("promotion_attempts len = %d, want 0", len(body.PromotionAttempts))
	}
	if len(body.RecentAttempts) != 0 {
		t.Errorf("recent_attempts len = %d, want 0", len(body.RecentAttempts))
	}
	if body.User.ID != u.ID {
		t.Errorf("user block wrong: %+v", body.User)
	}
}

func TestAdminUserState_HasMorePromotion_TrueWhenOver20(t *testing.T) {
	env := newXRayTestEnv(t)
	now := time.Now().UTC()
	u, err := env.users.CreateUser(contracts.UserAccount{
		Email: "over20@example.com", PasswordHash: "x", DisplayName: "Over",
	})
	if err != nil {
		t.Fatalf("seed: %v", err)
	}
	// Seed 21 promotion rows so the 20-row cap returns has_more=true.
	for i := 0; i < 21; i++ {
		if _, err := env.promo.Create(contracts.PromotionAttempt{
			UserID: u.ID, TargetLevel: "b1", MockTestID: "mt-1",
			CreatedAt: now.Add(-time.Duration(i) * time.Minute),
		}); err != nil {
			t.Fatalf("seed promo %d: %v", i, err)
		}
	}

	resp, body := xrayGet(t, env, u.ID, devAdminToken)
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("want 200, got %d", resp.StatusCode)
	}
	if len(body.PromotionAttempts) != 20 {
		t.Errorf("promotion_attempts len = %d, want 20 (cap)", len(body.PromotionAttempts))
	}
	if !body.HasMorePromotion {
		t.Error("has_more_promotion must be true with 21 rows")
	}
}
