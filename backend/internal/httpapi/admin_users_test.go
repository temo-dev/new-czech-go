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
