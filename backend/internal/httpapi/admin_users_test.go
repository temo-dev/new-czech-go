package httpapi

import (
	"bytes"
	"encoding/json"
	"net/http"
	"testing"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/auth"
	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

func timeNowPlus(_ *testing.T, days int) time.Time {
	return time.Now().UTC().Add(time.Duration(days) * 24 * time.Hour)
}

const devAdminToken = "dev-admin-token"

func adminGet(t *testing.T, env *authTestEnv, path string) (*http.Response, map[string]any) {
	t.Helper()
	req, _ := http.NewRequest(http.MethodGet, env.srv.URL+path, nil)
	req.Header.Set("Authorization", "Bearer "+devAdminToken)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("admin GET %s: %v", path, err)
	}
	t.Cleanup(func() { resp.Body.Close() })
	var out map[string]any
	_ = json.NewDecoder(resp.Body).Decode(&out)
	return resp, out
}

func adminDelete(t *testing.T, env *authTestEnv, path string) *http.Response {
	t.Helper()
	req, _ := http.NewRequest(http.MethodDelete, env.srv.URL+path, nil)
	req.Header.Set("Authorization", "Bearer "+devAdminToken)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("admin DELETE %s: %v", path, err)
	}
	t.Cleanup(func() { resp.Body.Close() })
	return resp
}

func seedLearner(t *testing.T, env *authTestEnv, email, name string) contracts.UserAccount {
	t.Helper()
	u, err := env.users.CreateUser(contracts.UserAccount{
		Email:        email,
		PasswordHash: "x",
		DisplayName:  name,
	})
	if err != nil {
		t.Fatalf("seed user: %v", err)
	}
	return u
}

func TestAdminListUsers_RequiresAuth(t *testing.T) {
	env := newAuthTestEnv(t)
	resp, err := http.Get(env.srv.URL + "/v1/admin/users")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("want 401, got %d", resp.StatusCode)
	}
}

func TestAdminListUsers_ReturnsActiveUsers(t *testing.T) {
	env := newAuthTestEnv(t)
	seedLearner(t, env, "alice@example.com", "Alice")
	seedLearner(t, env, "bob@example.com", "Bob")

	resp, body := adminGet(t, env, "/v1/admin/users")
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("want 200, got %d body=%v", resp.StatusCode, body)
	}
	data, _ := body["data"].([]any)
	if len(data) != 2 {
		t.Errorf("want 2 users, got %d", len(data))
	}
	meta, _ := body["meta"].(map[string]any)
	if total, _ := meta["total"].(float64); total != 2 {
		t.Errorf("want total=2, got %v", total)
	}
}

func TestAdminListUsers_SearchFiltersByEmail(t *testing.T) {
	env := newAuthTestEnv(t)
	seedLearner(t, env, "alice@example.com", "Alice")
	seedLearner(t, env, "bob@example.com", "Bob")

	resp, body := adminGet(t, env, "/v1/admin/users?search=alice")
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("want 200, got %d", resp.StatusCode)
	}
	data, _ := body["data"].([]any)
	if len(data) != 1 {
		t.Fatalf("want 1 match for 'alice', got %d", len(data))
	}
	row := data[0].(map[string]any)
	if row["email"] != "alice@example.com" {
		t.Errorf("want alice@example.com, got %v", row["email"])
	}
}

func TestAdminDeleteUser_HappyPath_SoftDeletesAndRevokesTokens(t *testing.T) {
	env := newAuthTestEnv(t)
	u := seedLearner(t, env, "victim@example.com", "Victim")

	// Issue a session token so we can verify lookup fails after revoke.
	tokenHash := "h_" + u.ID
	if _, err := env.tokens.CreateAuthToken(contracts.AuthToken{
		TokenHash: tokenHash,
		UserID:    u.ID,
		Kind:      contracts.AuthTokenKindSession,
		ExpiresAt: timeNowPlus(t, 30),
	}); err != nil {
		t.Fatalf("create token: %v", err)
	}
	if _, ok := env.tokens.AuthTokenByHash(tokenHash); !ok {
		t.Fatalf("seeded token should be active before delete")
	}

	resp := adminDelete(t, env, "/v1/admin/users/"+u.ID)
	if resp.StatusCode != http.StatusNoContent {
		t.Fatalf("want 204, got %d", resp.StatusCode)
	}

	if _, ok := env.users.UserAccountByID(u.ID); ok {
		t.Error("user should be soft-deleted (not visible via UserAccountByID)")
	}
	// AuthTokenByHash returns only active tokens, so after revoke it should
	// no longer find the row.
	if _, ok := env.tokens.AuthTokenByHash(tokenHash); ok {
		t.Error("session token should be revoked")
	}
	// Email freed for re-registration.
	if _, ok := env.users.UserAccountByEmail("victim@example.com"); ok {
		t.Error("email should be freed after delete")
	}
}

func TestAdminDeleteUser_NotFound_Returns404(t *testing.T) {
	env := newAuthTestEnv(t)
	resp := adminDelete(t, env, "/v1/admin/users/u_nonexistent")
	if resp.StatusCode != http.StatusNotFound {
		t.Errorf("want 404, got %d", resp.StatusCode)
	}
}

func TestAdminDeleteUser_AdminRole_Forbidden(t *testing.T) {
	env := newAuthTestEnv(t)
	admin, err := env.users.CreateUser(contracts.UserAccount{
		Email:        "admin2@example.com",
		PasswordHash: "x",
		Role:         "admin",
	})
	if err != nil {
		t.Fatalf("seed admin: %v", err)
	}
	resp := adminDelete(t, env, "/v1/admin/users/"+admin.ID)
	if resp.StatusCode != http.StatusForbidden {
		t.Errorf("want 403, got %d", resp.StatusCode)
	}
	if _, ok := env.users.UserAccountByID(admin.ID); !ok {
		t.Error("admin must remain after refused delete")
	}
}

func TestAdminDeleteUser_RequiresAdmin(t *testing.T) {
	env := newAuthTestEnv(t)
	u := seedLearner(t, env, "victim@example.com", "Victim")

	req, _ := http.NewRequest(http.MethodDelete, env.srv.URL+"/v1/admin/users/"+u.ID, nil)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("delete: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("want 401, got %d", resp.StatusCode)
	}
}

func adminPostJSON(t *testing.T, env *authTestEnv, path string, payload any) *http.Response {
	t.Helper()
	buf, _ := json.Marshal(payload)
	req, _ := http.NewRequest(http.MethodPost, env.srv.URL+path, bytes.NewReader(buf))
	req.Header.Set("Authorization", "Bearer "+devAdminToken)
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("admin POST %s: %v", path, err)
	}
	t.Cleanup(func() { resp.Body.Close() })
	return resp
}

func TestAdminResetPassword_HappyPath_UpdatesHashAndRevokesSessions(t *testing.T) {
	env := newAuthTestEnv(t)

	hashed, err := auth.HashPassword("OldP@ssw0rd")
	if err != nil {
		t.Fatalf("hash: %v", err)
	}
	u, err := env.users.CreateUser(contracts.UserAccount{
		Email:        "victim@example.com",
		PasswordHash: hashed,
		DisplayName:  "Victim",
	})
	if err != nil {
		t.Fatalf("seed: %v", err)
	}

	tokenHash := "h_session_" + u.ID
	if _, err := env.tokens.CreateAuthToken(contracts.AuthToken{
		TokenHash: tokenHash,
		UserID:    u.ID,
		Kind:      contracts.AuthTokenKindSession,
		ExpiresAt: timeNowPlus(t, 30),
	}); err != nil {
		t.Fatalf("create token: %v", err)
	}

	resp := adminPostJSON(t, env, "/v1/admin/users/"+u.ID+"/reset-password",
		map[string]string{"new_password": "BrandNew123!"})
	if resp.StatusCode != http.StatusNoContent {
		t.Fatalf("want 204, got %d", resp.StatusCode)
	}

	updated, ok := env.users.UserAccountByID(u.ID)
	if !ok {
		t.Fatal("user gone after reset")
	}
	if updated.PasswordHash == hashed {
		t.Error("hash should change after reset")
	}
	if !auth.VerifyPassword(updated.PasswordHash, "BrandNew123!") {
		t.Error("new password should verify against stored hash")
	}
	if _, ok := env.tokens.AuthTokenByHash(tokenHash); ok {
		t.Error("session token should be revoked")
	}
}

func TestAdminResetPassword_WeakPassword_Returns400(t *testing.T) {
	env := newAuthTestEnv(t)
	u := seedLearner(t, env, "victim@example.com", "Victim")

	resp := adminPostJSON(t, env, "/v1/admin/users/"+u.ID+"/reset-password",
		map[string]string{"new_password": "short"})
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("want 400, got %d", resp.StatusCode)
	}
}

func TestAdminResetPassword_NotFound_Returns404(t *testing.T) {
	env := newAuthTestEnv(t)
	resp := adminPostJSON(t, env, "/v1/admin/users/u_nonexistent/reset-password",
		map[string]string{"new_password": "BrandNew123!"})
	if resp.StatusCode != http.StatusNotFound {
		t.Errorf("want 404, got %d", resp.StatusCode)
	}
}

func TestAdminResetPassword_AdminTarget_Forbidden(t *testing.T) {
	env := newAuthTestEnv(t)
	target, err := env.users.CreateUser(contracts.UserAccount{
		Email:        "other-admin@example.com",
		PasswordHash: "x",
		Role:         "admin",
	})
	if err != nil {
		t.Fatalf("seed: %v", err)
	}
	resp := adminPostJSON(t, env, "/v1/admin/users/"+target.ID+"/reset-password",
		map[string]string{"new_password": "BrandNew123!"})
	if resp.StatusCode != http.StatusForbidden {
		t.Errorf("want 403, got %d", resp.StatusCode)
	}
}

func TestAdminResetPassword_RequiresAdmin(t *testing.T) {
	env := newAuthTestEnv(t)
	u := seedLearner(t, env, "victim@example.com", "Victim")

	buf, _ := json.Marshal(map[string]string{"new_password": "BrandNew123!"})
	resp, err := http.Post(env.srv.URL+"/v1/admin/users/"+u.ID+"/reset-password", "application/json", bytes.NewReader(buf))
	if err != nil {
		t.Fatalf("post: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("want 401, got %d", resp.StatusCode)
	}
}

func TestAdminListUsers_PopulatesAttemptsToday(t *testing.T) {
	env := newAuthTestEnv(t)
	u := seedLearner(t, env, "today@example.com", "Today")
	now := time.Now().UTC()
	for i := 0; i < 4; i++ {
		if _, err := env.usage.IncrementAttempts(u.ID, now); err != nil {
			t.Fatalf("seed: %v", err)
		}
	}
	resp, body := adminGet(t, env, "/v1/admin/users?search=today@example.com")
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("want 200, got %d", resp.StatusCode)
	}
	data, _ := body["data"].([]any)
	if len(data) != 1 {
		t.Fatalf("want 1 user, got %d", len(data))
	}
	row, _ := data[0].(map[string]any)
	if today, _ := row["attempts_today"].(float64); today != 4 {
		t.Errorf("attempts_today want 4, got %v", today)
	}
	if cap, _ := row["attempts_cap"].(float64); cap != 7 {
		t.Errorf("attempts_cap want 7, got %v", cap)
	}
}

func TestAdminListUsers_IncludesLevelState(t *testing.T) {
	env := newAuthTestEnv(t)
	u := seedLearner(t, env, "level@example.com", "Level")
	if _, err := env.levels.SetUserLevel(u.ID, "a1"); err != nil {
		t.Fatalf("seed level: %v", err)
	}

	resp, body := adminGet(t, env, "/v1/admin/users?search=level@example.com")
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("want 200, got %d body=%v", resp.StatusCode, body)
	}
	data, _ := body["data"].([]any)
	if len(data) != 1 {
		t.Fatalf("want 1 user, got %d", len(data))
	}
	row, _ := data[0].(map[string]any)
	if got := row["current_level"]; got != "a1" {
		t.Errorf("current_level = %v, want a1", got)
	}
	unlocked, _ := row["unlocked_levels"].([]any)
	if len(unlocked) != 2 || unlocked[0] != "a0" || unlocked[1] != "a1" {
		t.Errorf("unlocked_levels = %v, want [a0 a1]", unlocked)
	}
}

func TestAdminResetUsage_HappyPath_ZeroesAttemptsKeepsInterviews(t *testing.T) {
	env := newAuthTestEnv(t)
	u := seedLearner(t, env, "capped@example.com", "Capped")

	now := time.Now().UTC()
	for i := 0; i < 7; i++ {
		if _, err := env.usage.IncrementAttempts(u.ID, now); err != nil {
			t.Fatalf("seed attempts: %v", err)
		}
	}
	if _, err := env.usage.IncrementInterviews(u.ID, now); err != nil {
		t.Fatalf("seed interview: %v", err)
	}

	resp := adminPostJSON(t, env, "/v1/admin/users/"+u.ID+"/usage/reset", nil)
	if resp.StatusCode != http.StatusNoContent {
		t.Fatalf("want 204, got %d", resp.StatusCode)
	}
	got, _ := env.usage.DailyUsageByUserDay(u.ID, now)
	if got.AttemptsCount != 0 {
		t.Errorf("attempts should be 0, got %d", got.AttemptsCount)
	}
	if got.InterviewsCount != 1 {
		t.Errorf("interviews should be untouched, got %d", got.InterviewsCount)
	}
}

func TestAdminResetUsage_NotFound_Returns404(t *testing.T) {
	env := newAuthTestEnv(t)
	resp := adminPostJSON(t, env, "/v1/admin/users/u_missing/usage/reset", nil)
	if resp.StatusCode != http.StatusNotFound {
		t.Errorf("want 404, got %d", resp.StatusCode)
	}
}

func TestAdminResetUsage_RequiresAdmin(t *testing.T) {
	env := newAuthTestEnv(t)
	u := seedLearner(t, env, "victim@example.com", "Victim")

	resp, err := http.Post(env.srv.URL+"/v1/admin/users/"+u.ID+"/usage/reset", "application/json", nil)
	if err != nil {
		t.Fatalf("post: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("want 401, got %d", resp.StatusCode)
	}
}

// ── Admin row response helpers ───────────────────────────────────────────────

func decodeAdminUserData(t *testing.T, resp *http.Response) map[string]any {
	t.Helper()
	var body map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	data, ok := body["data"].(map[string]any)
	if !ok {
		t.Fatalf("response missing data object: %v", body)
	}
	return data
}

// ── Manual level upgrade ────────────────────────────────────────────────────

func TestAdminSetUserLevel_PromotesA0ToA1(t *testing.T) {
	env := newAuthTestEnv(t)
	u := seedLearner(t, env, "a0@example.com", "A0")

	resp := adminPostJSON(t, env, "/v1/admin/users/"+u.ID+"/level",
		map[string]string{"current_level": "A1"})
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("want 200, got %d", resp.StatusCode)
	}
	data := decodeAdminUserData(t, resp)
	if data["current_level"] != "a1" {
		t.Errorf("response current_level = %v, want a1", data["current_level"])
	}

	stored, ok := env.levels.GetUserLevel(u.ID)
	if !ok {
		t.Fatal("level row should exist after manual upgrade")
	}
	if stored.CurrentLevel != "a1" {
		t.Errorf("stored CurrentLevel = %q, want a1", stored.CurrentLevel)
	}
	if len(stored.UnlockedLevels) != 2 || stored.UnlockedLevels[0] != "a0" || stored.UnlockedLevels[1] != "a1" {
		t.Errorf("stored UnlockedLevels = %v, want [a0 a1]", stored.UnlockedLevels)
	}
}

func TestAdminSetUserLevel_InvalidLevel_Returns400(t *testing.T) {
	env := newAuthTestEnv(t)
	u := seedLearner(t, env, "bad-level@example.com", "Bad")

	resp := adminPostJSON(t, env, "/v1/admin/users/"+u.ID+"/level",
		map[string]string{"current_level": "c1"})
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("want 400, got %d", resp.StatusCode)
	}
}

func TestAdminSetUserLevel_Downgrade_Returns400(t *testing.T) {
	env := newAuthTestEnv(t)
	u := seedLearner(t, env, "a2@example.com", "A2")
	if _, err := env.levels.SetUserLevel(u.ID, "a2"); err != nil {
		t.Fatalf("seed level: %v", err)
	}

	resp := adminPostJSON(t, env, "/v1/admin/users/"+u.ID+"/level",
		map[string]string{"current_level": "a1"})
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("want 400, got %d", resp.StatusCode)
	}
	stored, _ := env.levels.GetUserLevel(u.ID)
	if stored.CurrentLevel != "a2" {
		t.Errorf("downgrade must not mutate level, got %q", stored.CurrentLevel)
	}
}

func TestAdminSetUserLevel_AdminTarget_Forbidden(t *testing.T) {
	env := newAuthTestEnv(t)
	target, err := env.users.CreateUser(contracts.UserAccount{
		Email:        "other-admin@example.com",
		PasswordHash: "x",
		Role:         "admin",
	})
	if err != nil {
		t.Fatalf("seed admin: %v", err)
	}
	resp := adminPostJSON(t, env, "/v1/admin/users/"+target.ID+"/level",
		map[string]string{"current_level": "a1"})
	if resp.StatusCode != http.StatusForbidden {
		t.Errorf("want 403, got %d", resp.StatusCode)
	}
}

func TestAdminSetUserLevel_RequiresAdmin(t *testing.T) {
	env := newAuthTestEnv(t)
	u := seedLearner(t, env, "level-auth@example.com", "Auth")
	resp, err := http.Post(env.srv.URL+"/v1/admin/users/"+u.ID+"/level", "application/json", nil)
	if err != nil {
		t.Fatalf("post: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("want 401, got %d", resp.StatusCode)
	}
}

// ── Pro grant / downgrade ────────────────────────────────────────────────────

func TestAdminSetUserPro_GrantsProAndSetsExpiry(t *testing.T) {
	env := newAuthTestEnv(t)
	u := seedLearner(t, env, "free@example.com", "Free")

	before := time.Now().UTC()
	resp := adminPostJSON(t, env, "/v1/admin/users/"+u.ID+"/pro",
		map[string]int{"duration_days": 30})
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("want 200, got %d", resp.StatusCode)
	}
	data := decodeAdminUserData(t, resp)
	if data["pro_tier"] != "pro" {
		t.Errorf("want pro_tier=pro, got %v", data["pro_tier"])
	}

	updated, _ := env.users.UserAccountByID(u.ID)
	if updated.ProTier != "pro" {
		t.Errorf("want stored ProTier=pro, got %q", updated.ProTier)
	}
	if updated.ProExpiresAt == nil {
		t.Fatal("ProExpiresAt should be set after grant")
	}
	want := before.Add(30 * 24 * time.Hour)
	delta := updated.ProExpiresAt.Sub(want)
	if delta < -time.Minute || delta > time.Minute {
		t.Errorf("expiry off by %v (want ~%v, got %v)", delta, want, *updated.ProExpiresAt)
	}
}

func TestAdminSetUserPro_ExtendsFromCurrentExpiry(t *testing.T) {
	env := newAuthTestEnv(t)
	u := seedLearner(t, env, "pro@example.com", "Pro")

	currentExpiry := time.Now().UTC().Add(20 * 24 * time.Hour)
	if _, ok := env.users.UpdateUser(u.ID, func(acc *contracts.UserAccount) {
		acc.ProTier = "pro"
		acc.ProExpiresAt = &currentExpiry
	}); !ok {
		t.Fatal("seed pro user")
	}

	resp := adminPostJSON(t, env, "/v1/admin/users/"+u.ID+"/pro",
		map[string]int{"duration_days": 30})
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("want 200, got %d", resp.StatusCode)
	}

	updated, _ := env.users.UserAccountByID(u.ID)
	if updated.ProExpiresAt == nil {
		t.Fatal("expiry nil after extend")
	}
	want := currentExpiry.Add(30 * 24 * time.Hour)
	delta := updated.ProExpiresAt.Sub(want)
	if delta < -time.Second || delta > time.Second {
		t.Errorf("expiry should extend from old expiry; got %v want %v (delta %v)",
			*updated.ProExpiresAt, want, delta)
	}
}

func TestAdminSetUserPro_ExpiredProRebasesFromNow(t *testing.T) {
	env := newAuthTestEnv(t)
	u := seedLearner(t, env, "expired@example.com", "Expired")

	pastExpiry := time.Now().UTC().Add(-5 * 24 * time.Hour)
	if _, ok := env.users.UpdateUser(u.ID, func(acc *contracts.UserAccount) {
		acc.ProTier = "pro"
		acc.ProExpiresAt = &pastExpiry
	}); !ok {
		t.Fatal("seed expired pro user")
	}

	before := time.Now().UTC()
	resp := adminPostJSON(t, env, "/v1/admin/users/"+u.ID+"/pro",
		map[string]int{"duration_days": 7})
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("want 200, got %d", resp.StatusCode)
	}

	updated, _ := env.users.UserAccountByID(u.ID)
	if updated.ProExpiresAt == nil || !updated.ProExpiresAt.After(before.Add(6*24*time.Hour)) {
		t.Errorf("expired Pro should rebase from now; got %v", updated.ProExpiresAt)
	}
}

func TestAdminSetUserPro_ZeroDurationDowngrades(t *testing.T) {
	env := newAuthTestEnv(t)
	u := seedLearner(t, env, "pro@example.com", "Pro")

	exp := time.Now().UTC().Add(30 * 24 * time.Hour)
	if _, ok := env.users.UpdateUser(u.ID, func(acc *contracts.UserAccount) {
		acc.ProTier = "pro"
		acc.ProExpiresAt = &exp
	}); !ok {
		t.Fatal("seed pro user")
	}

	resp := adminPostJSON(t, env, "/v1/admin/users/"+u.ID+"/pro",
		map[string]int{"duration_days": 0})
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("want 200, got %d", resp.StatusCode)
	}
	data := decodeAdminUserData(t, resp)
	if data["pro_tier"] != "free" {
		t.Errorf("want pro_tier=free, got %v", data["pro_tier"])
	}

	updated, _ := env.users.UserAccountByID(u.ID)
	if updated.ProTier != "free" {
		t.Errorf("want stored ProTier=free, got %q", updated.ProTier)
	}
	if updated.ProExpiresAt != nil {
		t.Errorf("expiry should be nil after downgrade, got %v", updated.ProExpiresAt)
	}
}

func TestAdminSetUserPro_NegativeDuration_Returns400(t *testing.T) {
	env := newAuthTestEnv(t)
	u := seedLearner(t, env, "u@example.com", "U")

	resp := adminPostJSON(t, env, "/v1/admin/users/"+u.ID+"/pro",
		map[string]int{"duration_days": -1})
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("want 400, got %d", resp.StatusCode)
	}
}

func TestAdminSetUserPro_HugeDuration_Returns400(t *testing.T) {
	env := newAuthTestEnv(t)
	u := seedLearner(t, env, "u@example.com", "U")

	resp := adminPostJSON(t, env, "/v1/admin/users/"+u.ID+"/pro",
		map[string]int{"duration_days": 9999})
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("want 400, got %d", resp.StatusCode)
	}
}

func TestAdminSetUserPro_AdminTarget_Forbidden(t *testing.T) {
	env := newAuthTestEnv(t)
	target, err := env.users.CreateUser(contracts.UserAccount{
		Email:        "other-admin@example.com",
		PasswordHash: "x",
		Role:         "admin",
	})
	if err != nil {
		t.Fatalf("seed admin: %v", err)
	}
	resp := adminPostJSON(t, env, "/v1/admin/users/"+target.ID+"/pro",
		map[string]int{"duration_days": 30})
	if resp.StatusCode != http.StatusForbidden {
		t.Errorf("want 403, got %d", resp.StatusCode)
	}
}

func TestAdminSetUserPro_NotFound_Returns404(t *testing.T) {
	env := newAuthTestEnv(t)
	resp := adminPostJSON(t, env, "/v1/admin/users/u_nonexistent/pro",
		map[string]int{"duration_days": 30})
	if resp.StatusCode != http.StatusNotFound {
		t.Errorf("want 404, got %d", resp.StatusCode)
	}
}

func TestAdminSetUserPro_RequiresAdmin(t *testing.T) {
	env := newAuthTestEnv(t)
	u := seedLearner(t, env, "u@example.com", "U")
	resp, err := http.Post(env.srv.URL+"/v1/admin/users/"+u.ID+"/pro", "application/json", nil)
	if err != nil {
		t.Fatalf("post: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("want 401, got %d", resp.StatusCode)
	}
}
