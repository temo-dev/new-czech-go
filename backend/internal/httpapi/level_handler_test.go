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

func unsetLevelEnv(t *testing.T) {
	t.Helper()
	for _, k := range []string{
		"LEVEL_MASTERY_THRESHOLD_PCT",
		"LEVEL_COVERAGE_THRESHOLD_PCT",
		"LEVEL_PROMOTION_PASS_PCT",
		"LEVEL_PROMOTION_COOLDOWN_HOURS",
		"LEVEL_DEMO_EXERCISE_PER_LEVEL",
		"LEVEL_PLACEMENT_ALLOW_B1",
		"LEVEL_PLACEMENT_BANDS_JSON",
	} {
		t.Setenv(k, "")
	}
}

// newLevelTestServer wires the V21 level deps onto a NewServerForTest
// instance using memory-backed stores. Returns the test server plus the
// stores so individual tests can seed mastery / user level / promotion
// rows directly.
func newLevelTestServer(t *testing.T, now time.Time) (*httptest.Server, store.SkillMasteryStore, store.UserLevelStore, store.PromotionAttemptsStore) {
	t.Helper()
	unsetMasteryEnv(t)
	unsetLevelEnv(t)
	repo := store.NewMemoryStore()
	masteryStore := store.NewMemorySkillMasteryStore()
	userLevels := store.NewMemoryUserLevelStore()
	promo := store.NewMemoryPromotionAttemptsStore()

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
	})
	return httptest.NewServer(srv.Handler()), masteryStore, userLevels, promo
}

func levelProgressGet(t *testing.T, server *httptest.Server, token string) (int, http.Header, map[string]any) {
	t.Helper()
	req, err := http.NewRequest(http.MethodGet, server.URL+"/v1/users/me/level-progress", nil)
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
		return resp.StatusCode, resp.Header, nil
	}
	var decoded map[string]any
	if err := json.Unmarshal(body, &decoded); err != nil {
		t.Fatalf("decode: %v; body=%s", err, body)
	}
	return resp.StatusCode, resp.Header, decoded
}

func TestLevelProgressHandler_RequiresAuth(t *testing.T) {
	srv, _, _, _ := newLevelTestServer(t, time.Date(2026, 5, 7, 12, 0, 0, 0, time.UTC))
	defer srv.Close()
	status, _, _ := levelProgressGet(t, srv, "")
	if status != http.StatusUnauthorized {
		t.Errorf("status = %d, want 401", status)
	}
}

func TestLevelProgressHandler_FreshUserReturnsZeroPayload(t *testing.T) {
	srv, _, _, _ := newLevelTestServer(t, time.Date(2026, 5, 7, 12, 0, 0, 0, time.UTC))
	defer srv.Close()

	status, hdr, body := levelProgressGet(t, srv, "dev-learner-token")
	if status != http.StatusOK {
		t.Fatalf("status = %d, want 200", status)
	}
	if got := hdr.Get("Cache-Control"); got != "no-store" {
		t.Errorf("Cache-Control = %q, want no-store", got)
	}
	data := body["data"].(map[string]any)
	if data["current_level"].(string) != "a0" {
		t.Errorf("current_level = %v, want a0", data["current_level"])
	}
	if data["next_level"].(string) != "a1" {
		t.Errorf("next_level = %v, want a1", data["next_level"])
	}
	if data["promotion_unlocked"].(bool) {
		t.Errorf("promotion_unlocked = true, want false")
	}
	if data["all_skills_pass"].(bool) {
		t.Errorf("all_skills_pass = true, want false")
	}
	skillMap := data["skill_mastery"].(map[string]any)
	if len(skillMap) == 0 {
		t.Error("skill_mastery should expose all six expected skills")
	}
}

func TestLevelProgressHandler_ReadyToPromote_Unlocked(t *testing.T) {
	now := time.Date(2026, 5, 7, 12, 0, 0, 0, time.UTC)
	srv, mastery, userLevels, _ := newLevelTestServer(t, now)
	defer srv.Close()

	if _, err := userLevels.SetUserLevel("user-learner-1", "a2"); err != nil {
		t.Fatalf("seed user level: %v", err)
	}
	for _, k := range []string{"noi", "viet", "nghe", "doc", "tu_vung", "ngu_phap"} {
		_, err := mastery.Upsert(contracts.SkillMasteryRow{
			UserID: "user-learner-1", SkillKind: k, ModuleID: "m1",
			MasteryScore: 0.85, AttemptsCount: 4,
			LastAttemptAt: now.Add(-time.Hour), UpdatedAt: now.Add(-time.Hour),
		})
		if err != nil {
			t.Fatalf("seed mastery %s: %v", k, err)
		}
	}

	status, _, body := levelProgressGet(t, srv, "dev-learner-token")
	if status != http.StatusOK {
		t.Fatalf("status = %d, want 200", status)
	}
	data := body["data"].(map[string]any)

	if !data["all_skills_pass"].(bool) {
		t.Errorf("all_skills_pass = false, want true")
	}
	if !data["promotion_unlocked"].(bool) {
		t.Errorf("promotion_unlocked = false, want true (all gates met)")
	}
	if data["next_level"].(string) != "b1" {
		t.Errorf("next_level = %v, want b1", data["next_level"])
	}
}

// V21 review I5: SetLevelDeps installs a default PromotionTestForLevel
// resolver so /level-progress can advertise the promotion mock id without
// the client doing a follow-up listMockTests round trip.
func TestLevelProgressHandler_PromotionTestIDPopulatedWhenMockExists(t *testing.T) {
	now := time.Date(2026, 5, 7, 12, 0, 0, 0, time.UTC)
	srv, mastery, userLevels, _ := newLevelTestServer(t, now)
	defer srv.Close()

	// We need access to the underlying repo to seed a promotion mock.
	// newLevelTestServer doesn't return it, so reuse newPromotionTestServer
	// which seeds a B1 promotion mock by default.
	// (Done in a separate test below — guard against double work.)
	_ = mastery
	_ = userLevels

	srv2, _, mastery2, userLevels2, _, mockID := newPromotionTestServer(t, now)
	defer srv2.Close()

	if _, err := userLevels2.SetUserLevel("user-learner-1", "a2"); err != nil {
		t.Fatalf("seed user level: %v", err)
	}
	seedPassingMastery(t, mastery2, "user-learner-1", now.Add(-2*time.Hour))

	status, _, body := levelProgressGet(t, srv2, "dev-learner-token")
	if status != http.StatusOK {
		t.Fatalf("status = %d, want 200", status)
	}
	data := body["data"].(map[string]any)
	if got := data["promotion_test_id"].(string); got != mockID {
		t.Errorf("promotion_test_id = %q, want %q (resolver should pick up the seeded B1 promotion mock)",
			got, mockID)
	}
}

func TestLevelProgressHandler_CooldownActive_LocksWithUntilTimestamp(t *testing.T) {
	now := time.Date(2026, 5, 7, 12, 0, 0, 0, time.UTC)
	srv, mastery, userLevels, promo := newLevelTestServer(t, now)
	defer srv.Close()

	_, _ = userLevels.SetUserLevel("user-learner-1", "a2")
	for _, k := range []string{"noi", "viet", "nghe", "doc", "tu_vung", "ngu_phap"} {
		_, _ = mastery.Upsert(contracts.SkillMasteryRow{
			UserID: "user-learner-1", SkillKind: k, ModuleID: "m1",
			MasteryScore: 0.85, AttemptsCount: 4,
			LastAttemptAt: now.Add(-time.Hour), UpdatedAt: now.Add(-time.Hour),
		})
	}
	failed, err := promo.Create(contracts.PromotionAttempt{
		UserID: "user-learner-1", MockTestID: "mt_b1",
		SourceLevel: "a2", TargetLevel: "b1",
		CreatedAt: now.Add(-1 * time.Hour),
	})
	if err != nil {
		t.Fatalf("seed promo: %v", err)
	}
	if _, err := promo.MarkResult(failed.ID, false, 45.0, map[string]float64{"viet": 50}); err != nil {
		t.Fatalf("mark fail: %v", err)
	}

	status, _, body := levelProgressGet(t, srv, "dev-learner-token")
	if status != http.StatusOK {
		t.Fatalf("status = %d, want 200", status)
	}
	data := body["data"].(map[string]any)
	if data["promotion_unlocked"].(bool) {
		t.Errorf("promotion_unlocked = true, want false (cooldown active)")
	}
	if _, ok := data["promotion_cooldown_until"]; !ok {
		t.Error("promotion_cooldown_until must be present when cooldown is active")
	}
}
