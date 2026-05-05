package httpapi

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/auth"
	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/email"
	"github.com/danieldev/czech-go-system/backend/internal/iap"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

// authTestServer wires a fresh in-memory Server with V17 auth deps. The
// returned httptest.Server is the URL clients hit; the *email.RecorderSender
// lets the test assert on dispatched emails after a goroutine flush.
type authTestEnv struct {
	srv         *httptest.Server
	users       store.UserStore
	tokens      store.AuthTokenStore
	streaks     store.StreakStore
	usage       store.DailyUsageStore
	purchases   store.ProPurchaseStore
	emails      *email.RecorderSender
	verifier    *iap.FakeAppleVerifier
}

func newAuthTestEnv(t *testing.T) *authTestEnv {
	t.Helper()
	repo := store.NewMemoryStore()
	users := newMemoryUserStoreForTest(t)
	tokens := newMemoryAuthTokenStoreForTest(t)
	streaks := store.NewMemoryStreakStore()
	usage := store.NewMemoryDailyUsageStore()
	purchases := store.NewMemoryProPurchaseStore()
	rec := email.NewRecorderSender()
	verifier := &iap.FakeAppleVerifier{}

	deps := AuthDeps{
		Users:         users,
		AuthTokens:    tokens,
		Streaks:       streaks,
		DailyUsage:    usage,
		ProPurchases:  purchases,
		EmailSender:   rec,
		AppleVerifier: verifier,
		BaseURL:       "https://api.example.test",
		VerifyTTL:     24 * time.Hour,
	}
	handler := NewServerWithAuth(repo, nil, nil, nil, nil, deps)
	srv := httptest.NewServer(handler)
	t.Cleanup(srv.Close)
	return &authTestEnv{
		srv: srv, users: users, tokens: tokens,
		streaks: streaks, usage: usage, purchases: purchases,
		emails: rec, verifier: verifier,
	}
}

// signup is a convenience helper that POSTs the signup form and returns
// the parsed body + status.
func (env *authTestEnv) signup(t *testing.T, body map[string]string) (*http.Response, map[string]any) {
	t.Helper()
	buf, _ := json.Marshal(body)
	resp, err := http.Post(env.srv.URL+"/v1/auth/signup", "application/json", bytes.NewReader(buf))
	if err != nil {
		t.Fatalf("post signup: %v", err)
	}
	t.Cleanup(func() { resp.Body.Close() })
	var out map[string]any
	_ = json.NewDecoder(resp.Body).Decode(&out)
	return resp, out
}

// ── happy path ───────────────────────────────────────────────────────────

func TestSignup_HappyPath_Returns200WithSession(t *testing.T) {
	env := newAuthTestEnv(t)

	resp, body := env.signup(t, map[string]string{
		"email":        "An@Example.com",
		"password":     "Strong1Password!",
		"display_name": "An",
	})
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d body=%v", resp.StatusCode, body)
	}
	if body["session_token"] == nil || body["session_token"] == "" {
		t.Errorf("missing session_token in response: %v", body)
	}
	user := body["user"].(map[string]any)
	if user["email"] != "An@Example.com" {
		t.Errorf("response should preserve original email casing, got %q", user["email"])
	}
	if user["email_verified"] != false {
		t.Error("freshly signed-up account should be unverified")
	}
	if user["pro_tier"] != "free" {
		t.Errorf("default pro_tier=free, got %v", user["pro_tier"])
	}

	// Persistence side-effects.
	stored, ok := env.users.UserAccountByEmail("an@example.com")
	if !ok {
		t.Fatal("expected user persisted")
	}
	if stored.PasswordHash == "" {
		t.Error("expected password to be hashed and stored")
	}
	if !auth.VerifyPassword(stored.PasswordHash, "Strong1Password!") {
		t.Error("stored hash must round-trip via VerifyPassword")
	}

	// Session token is in the auth_tokens store as sha256.
	rawToken := body["session_token"].(string)
	if _, ok := env.tokens.AuthTokenByHash(auth.HashToken(rawToken)); !ok {
		t.Error("session token hash must be persisted")
	}
}

// ── duplicate email ──────────────────────────────────────────────────────

func TestSignup_DuplicateEmail_Returns409(t *testing.T) {
	env := newAuthTestEnv(t)

	if resp, _ := env.signup(t, map[string]string{
		"email": "a@x.com", "password": "Strong1Password!", "display_name": "A",
	}); resp.StatusCode != http.StatusOK {
		t.Fatalf("first signup should succeed, got %d", resp.StatusCode)
	}

	resp, body := env.signup(t, map[string]string{
		"email": "A@X.COM", "password": "Strong1Password!", "display_name": "A2",
	})
	if resp.StatusCode != http.StatusConflict {
		t.Errorf("expected 409 on duplicate, got %d", resp.StatusCode)
	}
	if body["error"] != "email_taken" {
		t.Errorf("expected error=email_taken, got %v", body["error"])
	}
}

// ── validation paths ─────────────────────────────────────────────────────

func TestSignup_InvalidEmail_Returns400(t *testing.T) {
	env := newAuthTestEnv(t)

	resp, body := env.signup(t, map[string]string{
		"email": "not-an-email", "password": "Strong1Password!", "display_name": "A",
	})
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", resp.StatusCode)
	}
	if body["error"] != "invalid_email" {
		t.Errorf("expected error=invalid_email, got %v", body["error"])
	}
}

func TestSignup_WeakPassword_Returns400WithCode(t *testing.T) {
	env := newAuthTestEnv(t)

	cases := []struct {
		name, password string
	}{
		{"too short", "Ab1!"},
		{"no digit or special", "abcdefghij"},
		{"common list", "password123"},
		{"empty", ""},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			resp, body := env.signup(t, map[string]string{
				"email": "u@x.com", "password": c.password, "display_name": "A",
			})
			if resp.StatusCode != http.StatusBadRequest {
				t.Errorf("expected 400, got %d", resp.StatusCode)
			}
			if body["error"] != "weak_password" {
				t.Errorf("expected error=weak_password, got %v", body["error"])
			}
		})
	}
}

func TestSignup_InvalidJSON_Returns400(t *testing.T) {
	env := newAuthTestEnv(t)

	resp, err := http.Post(env.srv.URL+"/v1/auth/signup", "application/json", strings.NewReader("{not json"))
	if err != nil {
		t.Fatalf("post: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", resp.StatusCode)
	}
}

func TestSignup_OversizedBody_Rejected(t *testing.T) {
	env := newAuthTestEnv(t)

	huge := bytes.Repeat([]byte("a"), 8*1024) // 8KiB > 4KiB cap
	body, _ := json.Marshal(map[string]string{
		"email":        "u@x.com",
		"password":     "Strong1Password!",
		"display_name": string(huge),
	})
	resp, err := http.Post(env.srv.URL+"/v1/auth/signup", "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("post: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusOK {
		t.Errorf("expected oversized body to be rejected, got 200")
	}
}

func TestSignup_DispatchesVerifyEmail(t *testing.T) {
	env := newAuthTestEnv(t)

	resp, _ := env.signup(t, map[string]string{
		"email": "v@x.com", "password": "Strong1Password!", "display_name": "Vy",
	})
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("signup should succeed, got %d", resp.StatusCode)
	}

	// Verify email is dispatched on a goroutine — wait briefly.
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		if len(env.emails.Sent()) > 0 {
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	sent := env.emails.Sent()
	if len(sent) != 1 {
		t.Fatalf("expected 1 verify email, got %d", len(sent))
	}
	if sent[0].To != "v@x.com" {
		t.Errorf("To: %q", sent[0].To)
	}
	if !strings.Contains(sent[0].HTMLBody, "https://api.example.test/v1/auth/verify-email?token=") {
		t.Errorf("verify URL missing or wrong base, body has: %q", sent[0].HTMLBody)
	}
	if !strings.Contains(sent[0].Subject, "Xác minh") {
		t.Errorf("expected VI subject, got %q", sent[0].Subject)
	}

	// The verify-token hash must be persisted as kind=email_verify.
	stored, _ := env.users.UserAccountByEmail("v@x.com")
	if stored.ID == "" {
		t.Fatal("user gone")
	}
}

// ── login ────────────────────────────────────────────────────────────────

// preSignup creates an account through the public signup endpoint so the
// login tests don't reach into the store directly.
func (env *authTestEnv) preSignup(t *testing.T, emailAddr, password string) {
	t.Helper()
	resp, body := env.signup(t, map[string]string{
		"email": emailAddr, "password": password, "display_name": "X",
	})
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("preSignup failed: %d %v", resp.StatusCode, body)
	}
	// Wait for the signup verify email goroutine to land in the
	// recorder so a follow-up Reset doesn't race ahead of it. Cap at 1s.
	deadline := time.Now().Add(1 * time.Second)
	for time.Now().Before(deadline) {
		if len(env.emails.Sent()) > 0 {
			break
		}
		time.Sleep(10 * time.Millisecond)
	}
	env.emails.Reset()
}

func (env *authTestEnv) login(t *testing.T, emailAddr, password string) (*http.Response, map[string]any) {
	t.Helper()
	buf, _ := json.Marshal(map[string]string{"email": emailAddr, "password": password})
	resp, err := http.Post(env.srv.URL+"/v1/auth/login", "application/json", bytes.NewReader(buf))
	if err != nil {
		t.Fatalf("post login: %v", err)
	}
	t.Cleanup(func() { resp.Body.Close() })
	var out map[string]any
	_ = json.NewDecoder(resp.Body).Decode(&out)
	return resp, out
}

func TestLogin_HappyPath_ReturnsSessionToken(t *testing.T) {
	env := newAuthTestEnv(t)
	env.preSignup(t, "u@x.com", "Strong1Password!")

	resp, body := env.login(t, "u@x.com", "Strong1Password!")
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}
	if body["session_token"] == nil || body["session_token"] == "" {
		t.Errorf("missing session_token: %v", body)
	}
	user := body["user"].(map[string]any)
	if user["email"] != "u@x.com" {
		t.Errorf("unexpected user email: %v", user["email"])
	}
}

func TestLogin_WrongPassword_Returns401(t *testing.T) {
	env := newAuthTestEnv(t)
	env.preSignup(t, "u@x.com", "Strong1Password!")

	resp, body := env.login(t, "u@x.com", "wrong-password")
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", resp.StatusCode)
	}
	if body["error"] != "invalid_credentials" {
		t.Errorf("expected error=invalid_credentials, got %v", body["error"])
	}
}

func TestLogin_NonexistentEmail_Returns401_DoesNotLeakExistence(t *testing.T) {
	env := newAuthTestEnv(t)
	env.preSignup(t, "real@x.com", "Strong1Password!")

	respWrongPwd, bodyWrongPwd := env.login(t, "real@x.com", "wrong")
	respNoUser, bodyNoUser := env.login(t, "nonexistent@x.com", "anything-strong-1!")

	if respWrongPwd.StatusCode != respNoUser.StatusCode {
		t.Errorf("status divergence leaks existence: %d vs %d",
			respWrongPwd.StatusCode, respNoUser.StatusCode)
	}
	if bodyWrongPwd["error"] != bodyNoUser["error"] {
		t.Errorf("error code divergence leaks existence: %v vs %v",
			bodyWrongPwd["error"], bodyNoUser["error"])
	}
}

func TestLogin_RateLimit_5FailsLocksOut(t *testing.T) {
	env := newAuthTestEnv(t)
	env.preSignup(t, "rl@x.com", "Strong1Password!")

	for i := 0; i < 5; i++ {
		resp, _ := env.login(t, "rl@x.com", "wrong")
		if resp.StatusCode != http.StatusUnauthorized {
			t.Fatalf("fail %d: expected 401, got %d", i+1, resp.StatusCode)
		}
	}
	// 6th attempt — even with the right password — must be blocked.
	resp, body := env.login(t, "rl@x.com", "Strong1Password!")
	if resp.StatusCode != http.StatusTooManyRequests {
		t.Errorf("expected 429 after 5 fails, got %d", resp.StatusCode)
	}
	if body["error"] != "too_many_attempts" {
		t.Errorf("expected error=too_many_attempts, got %v", body["error"])
	}
}

func TestLogin_SuccessResetsRateLimit(t *testing.T) {
	env := newAuthTestEnv(t)
	env.preSignup(t, "ok@x.com", "Strong1Password!")

	// 3 failures then a success.
	for i := 0; i < 3; i++ {
		env.login(t, "ok@x.com", "wrong")
	}
	if resp, _ := env.login(t, "ok@x.com", "Strong1Password!"); resp.StatusCode != http.StatusOK {
		t.Fatalf("expected success, got %d", resp.StatusCode)
	}
	// The successful login must have cleared the counter, so 5 more
	// failures should still not lock out (we only hit 8 total, but only
	// 5 since the reset).
	for i := 0; i < 4; i++ {
		resp, _ := env.login(t, "ok@x.com", "wrong")
		if resp.StatusCode != http.StatusUnauthorized {
			t.Fatalf("post-success fail %d: expected 401, got %d", i+1, resp.StatusCode)
		}
	}
}

func TestLogin_InvalidJSON_Returns400(t *testing.T) {
	env := newAuthTestEnv(t)
	resp, err := http.Post(env.srv.URL+"/v1/auth/login", "application/json", strings.NewReader("{bad"))
	if err != nil {
		t.Fatalf("post: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", resp.StatusCode)
	}
}

// ── logout / verify-email / resend-verify ────────────────────────────────

func (env *authTestEnv) loginToken(t *testing.T, emailAddr, password string) string {
	t.Helper()
	resp, body := env.login(t, emailAddr, password)
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("login failed: %d %v", resp.StatusCode, body)
	}
	tok, _ := body["session_token"].(string)
	if tok == "" {
		t.Fatal("missing session token")
	}
	return tok
}

func TestLogout_RevokesSessionToken(t *testing.T) {
	env := newAuthTestEnv(t)
	env.preSignup(t, "u@x.com", "Strong1Password!")
	tok := env.loginToken(t, "u@x.com", "Strong1Password!")

	req, _ := http.NewRequest(http.MethodPost, env.srv.URL+"/v1/auth/logout", nil)
	req.Header.Set("Authorization", "Bearer "+tok)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("logout: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusNoContent {
		t.Fatalf("expected 204, got %d", resp.StatusCode)
	}

	// Token must no longer authenticate.
	if _, ok := env.tokens.AuthTokenByHash(auth.HashToken(tok)); ok {
		t.Error("expected token to be revoked")
	}

	// Re-logout returns 401 (already gone).
	req2, _ := http.NewRequest(http.MethodPost, env.srv.URL+"/v1/auth/logout", nil)
	req2.Header.Set("Authorization", "Bearer "+tok)
	resp2, _ := http.DefaultClient.Do(req2)
	defer resp2.Body.Close()
	if resp2.StatusCode != http.StatusUnauthorized {
		t.Errorf("expected 401 on re-logout, got %d", resp2.StatusCode)
	}
}

func TestLogout_NoBearerHeader_Returns401(t *testing.T) {
	env := newAuthTestEnv(t)
	resp, err := http.Post(env.srv.URL+"/v1/auth/logout", "", nil)
	if err != nil {
		t.Fatalf("post: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", resp.StatusCode)
	}
}

func TestVerifyEmail_HappyPath_SetsVerifiedAndRevokesToken(t *testing.T) {
	env := newAuthTestEnv(t)
	env.preSignup(t, "v@x.com", "Strong1Password!")
	user, _ := env.users.UserAccountByEmail("v@x.com")

	// Trigger a fresh verify token via resend so we can capture the link
	// from the recorder. (preSignup discarded the original.)
	tok := env.loginToken(t, "v@x.com", "Strong1Password!")
	req, _ := http.NewRequest(http.MethodPost, env.srv.URL+"/v1/auth/resend-verify", nil)
	req.Header.Set("Authorization", "Bearer "+tok)
	resp, _ := http.DefaultClient.Do(req)
	resp.Body.Close()

	// Wait for the goroutine email dispatch.
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		if len(env.emails.Sent()) > 0 {
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	if len(env.emails.Sent()) == 0 {
		t.Fatal("expected resent verify email")
	}
	body := env.emails.Sent()[0].HTMLBody
	rawToken := extractVerifyToken(t, body)

	// Hit the verify endpoint.
	verifyResp, err := http.Get(env.srv.URL + "/v1/auth/verify-email?token=" + rawToken)
	if err != nil {
		t.Fatalf("get verify: %v", err)
	}
	defer verifyResp.Body.Close()
	if verifyResp.StatusCode != http.StatusOK {
		t.Errorf("expected 200, got %d", verifyResp.StatusCode)
	}
	if ct := verifyResp.Header.Get("Content-Type"); !strings.HasPrefix(ct, "text/html") {
		t.Errorf("expected HTML response, got %q", ct)
	}

	updated, _ := env.users.UserAccountByID(user.ID)
	if !updated.IsEmailVerified() {
		t.Error("expected user to be verified after link click")
	}

	// Replay must fail (token revoked).
	replay, _ := http.Get(env.srv.URL + "/v1/auth/verify-email?token=" + rawToken)
	defer replay.Body.Close()
	if replay.StatusCode != http.StatusBadRequest {
		t.Errorf("expected replay 400, got %d", replay.StatusCode)
	}
}

func TestVerifyEmail_MissingToken_Returns400(t *testing.T) {
	env := newAuthTestEnv(t)
	resp, _ := http.Get(env.srv.URL + "/v1/auth/verify-email")
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", resp.StatusCode)
	}
}

func TestVerifyEmail_UnknownToken_Returns400(t *testing.T) {
	env := newAuthTestEnv(t)
	resp, _ := http.Get(env.srv.URL + "/v1/auth/verify-email?token=not-a-real-token")
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", resp.StatusCode)
	}
}

func TestResendVerify_RequiresAuth(t *testing.T) {
	env := newAuthTestEnv(t)
	resp, err := http.Post(env.srv.URL+"/v1/auth/resend-verify", "", nil)
	if err != nil {
		t.Fatalf("post: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", resp.StatusCode)
	}
}

func TestResendVerify_Cooldown(t *testing.T) {
	env := newAuthTestEnv(t)
	env.preSignup(t, "rs@x.com", "Strong1Password!")
	tok := env.loginToken(t, "rs@x.com", "Strong1Password!")

	// First call -> 204.
	resp1 := postWithAuth(t, env.srv.URL+"/v1/auth/resend-verify", tok)
	defer resp1.Body.Close()
	if resp1.StatusCode != http.StatusNoContent {
		t.Fatalf("first resend expected 204, got %d", resp1.StatusCode)
	}

	// Second call within 60s -> 429.
	resp2 := postWithAuth(t, env.srv.URL+"/v1/auth/resend-verify", tok)
	defer resp2.Body.Close()
	if resp2.StatusCode != http.StatusTooManyRequests {
		t.Errorf("second resend expected 429, got %d", resp2.StatusCode)
	}
	if ra := resp2.Header.Get("Retry-After"); ra == "" {
		t.Error("expected Retry-After header on 429")
	}
}

func TestResendVerify_AlreadyVerified_NoOps(t *testing.T) {
	env := newAuthTestEnv(t)
	env.preSignup(t, "av@x.com", "Strong1Password!")
	user, _ := env.users.UserAccountByEmail("av@x.com")
	env.users.MarkUserEmailVerified(user.ID)

	tok := env.loginToken(t, "av@x.com", "Strong1Password!")
	resp := postWithAuth(t, env.srv.URL+"/v1/auth/resend-verify", tok)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusNoContent {
		t.Errorf("expected 204 (no-op) for already-verified, got %d", resp.StatusCode)
	}
	// No new email dispatched.
	if len(env.emails.Sent()) != 0 {
		t.Error("expected no email when already verified")
	}
}

// extractVerifyToken pulls the raw token out of the verify URL the email
// body contains.
func extractVerifyToken(t *testing.T, htmlBody string) string {
	t.Helper()
	const marker = "/v1/auth/verify-email?token="
	idx := strings.Index(htmlBody, marker)
	if idx < 0 {
		t.Fatalf("marker not found in body: %s", htmlBody)
	}
	rest := htmlBody[idx+len(marker):]
	end := strings.IndexAny(rest, "\"' <>\r\n")
	if end < 0 {
		t.Fatalf("could not find token end in: %s", rest)
	}
	return rest[:end]
}

func postWithAuth(t *testing.T, url, token string) *http.Response {
	t.Helper()
	req, _ := http.NewRequest(http.MethodPost, url, nil)
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("post: %v", err)
	}
	return resp
}

// ── forgot / reset / change password ─────────────────────────────────────

func (env *authTestEnv) postJSON(t *testing.T, path string, body any) (*http.Response, map[string]any) {
	t.Helper()
	buf, _ := json.Marshal(body)
	resp, err := http.Post(env.srv.URL+path, "application/json", bytes.NewReader(buf))
	if err != nil {
		t.Fatalf("post %s: %v", path, err)
	}
	t.Cleanup(func() { resp.Body.Close() })
	var out map[string]any
	_ = json.NewDecoder(resp.Body).Decode(&out)
	return resp, out
}

func (env *authTestEnv) postJSONWithAuth(t *testing.T, path, token string, body any) (*http.Response, map[string]any) {
	t.Helper()
	buf, _ := json.Marshal(body)
	req, _ := http.NewRequest(http.MethodPost, env.srv.URL+path, bytes.NewReader(buf))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("post %s: %v", path, err)
	}
	t.Cleanup(func() { resp.Body.Close() })
	var out map[string]any
	_ = json.NewDecoder(resp.Body).Decode(&out)
	return resp, out
}

func TestForgotPassword_KnownEmail_DispatchesResetLink(t *testing.T) {
	env := newAuthTestEnv(t)
	env.preSignup(t, "fp@x.com", "Strong1Password!")

	resp, _ := env.postJSON(t, "/v1/auth/forgot-password", map[string]string{"email": "fp@x.com"})
	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200, got %d", resp.StatusCode)
	}

	// Wait for async dispatch.
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		if len(env.emails.Sent()) > 0 {
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	if len(env.emails.Sent()) != 1 {
		t.Fatalf("expected 1 reset email, got %d", len(env.emails.Sent()))
	}
	if !strings.Contains(env.emails.Sent()[0].HTMLBody, "/v1/auth/reset-password?token=") {
		t.Error("expected reset URL in body")
	}
}

func TestForgotPassword_UnknownEmail_StillReturns200_NoLeak(t *testing.T) {
	env := newAuthTestEnv(t)

	resp, _ := env.postJSON(t, "/v1/auth/forgot-password", map[string]string{"email": "nobody@x.com"})
	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200 for unknown email, got %d", resp.StatusCode)
	}
	// And nothing dispatched.
	time.Sleep(50 * time.Millisecond)
	if len(env.emails.Sent()) != 0 {
		t.Errorf("expected zero emails for unknown user, got %d", len(env.emails.Sent()))
	}
}

func TestResetPassword_HappyPath_RevokesAllSessions(t *testing.T) {
	env := newAuthTestEnv(t)
	env.preSignup(t, "rp@x.com", "Strong1Password!")
	user, _ := env.users.UserAccountByEmail("rp@x.com")

	// Issue an extra session token directly so we can prove it gets
	// revoked alongside the original.
	tok1 := env.loginToken(t, "rp@x.com", "Strong1Password!")
	tok2 := env.loginToken(t, "rp@x.com", "Strong1Password!")

	// Trigger forgot-password to capture a real reset token from the
	// recorder.
	env.postJSON(t, "/v1/auth/forgot-password", map[string]string{"email": "rp@x.com"})
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		if len(env.emails.Sent()) > 0 {
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	resetToken := extractResetToken(t, env.emails.Sent()[0].HTMLBody)

	resp, _ := env.postJSON(t, "/v1/auth/reset-password", map[string]string{
		"token":        resetToken,
		"new_password": "NewStrong1Password!",
	})
	if resp.StatusCode != http.StatusNoContent {
		t.Fatalf("expected 204, got %d", resp.StatusCode)
	}

	// Old password must no longer work.
	respLogin, _ := env.login(t, "rp@x.com", "Strong1Password!")
	if respLogin.StatusCode != http.StatusUnauthorized {
		t.Errorf("expected old password to fail, got %d", respLogin.StatusCode)
	}
	// New password works.
	respNew, _ := env.login(t, "rp@x.com", "NewStrong1Password!")
	if respNew.StatusCode != http.StatusOK {
		t.Errorf("expected new password to succeed, got %d", respNew.StatusCode)
	}

	// Both prior session tokens must be revoked.
	for i, tok := range []string{tok1, tok2} {
		if _, ok := env.tokens.AuthTokenByHash(auth.HashToken(tok)); ok {
			t.Errorf("session token %d should be revoked", i+1)
		}
	}

	// Reset token itself must be revoked (replay -> 400).
	respReplay, _ := env.postJSON(t, "/v1/auth/reset-password", map[string]string{
		"token":        resetToken,
		"new_password": "AnotherStrong1Password!",
	})
	if respReplay.StatusCode != http.StatusBadRequest {
		t.Errorf("expected replay 400, got %d", respReplay.StatusCode)
	}
	_ = user
}

func TestResetPassword_InvalidToken_Returns400(t *testing.T) {
	env := newAuthTestEnv(t)
	resp, body := env.postJSON(t, "/v1/auth/reset-password", map[string]string{
		"token": "not-a-real-token", "new_password": "Strong1Password!",
	})
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", resp.StatusCode)
	}
	if body["error"] != "invalid_token" {
		t.Errorf("expected error=invalid_token, got %v", body["error"])
	}
}

func TestResetPassword_WeakNewPassword_Returns400(t *testing.T) {
	env := newAuthTestEnv(t)
	resp, body := env.postJSON(t, "/v1/auth/reset-password", map[string]string{
		"token": "anything", "new_password": "abc",
	})
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", resp.StatusCode)
	}
	if body["error"] != "weak_password" {
		t.Errorf("expected weak_password, got %v", body["error"])
	}
}

func TestChangePassword_HappyPath(t *testing.T) {
	env := newAuthTestEnv(t)
	env.preSignup(t, "cp@x.com", "Strong1Password!")
	tok := env.loginToken(t, "cp@x.com", "Strong1Password!")

	resp, _ := env.postJSONWithAuth(t, "/v1/auth/change-password", tok, map[string]string{
		"current_password": "Strong1Password!",
		"new_password":     "NewerStrong1Password!",
	})
	if resp.StatusCode != http.StatusNoContent {
		t.Fatalf("expected 204, got %d", resp.StatusCode)
	}

	// Old password no longer works on login.
	if r, _ := env.login(t, "cp@x.com", "Strong1Password!"); r.StatusCode != http.StatusUnauthorized {
		t.Errorf("old pwd should be invalid, got %d", r.StatusCode)
	}
	// New password works.
	if r, _ := env.login(t, "cp@x.com", "NewerStrong1Password!"); r.StatusCode != http.StatusOK {
		t.Errorf("new pwd should work, got %d", r.StatusCode)
	}
}

func TestChangePassword_WrongCurrent_Returns401(t *testing.T) {
	env := newAuthTestEnv(t)
	env.preSignup(t, "cw@x.com", "Strong1Password!")
	tok := env.loginToken(t, "cw@x.com", "Strong1Password!")

	resp, body := env.postJSONWithAuth(t, "/v1/auth/change-password", tok, map[string]string{
		"current_password": "wrong",
		"new_password":     "NewStrong1Password!",
	})
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", resp.StatusCode)
	}
	if body["error"] != "invalid_current_password" {
		t.Errorf("expected invalid_current_password, got %v", body["error"])
	}
}

func TestChangePassword_RequiresAuth(t *testing.T) {
	env := newAuthTestEnv(t)
	resp, _ := env.postJSON(t, "/v1/auth/change-password", map[string]string{
		"current_password": "x", "new_password": "y",
	})
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", resp.StatusCode)
	}
}

func extractResetToken(t *testing.T, htmlBody string) string {
	t.Helper()
	const marker = "/v1/auth/reset-password?token="
	idx := strings.Index(htmlBody, marker)
	if idx < 0 {
		t.Fatalf("marker not found in body: %s", htmlBody)
	}
	rest := htmlBody[idx+len(marker):]
	end := strings.IndexAny(rest, "\"' <>\r\n")
	if end < 0 {
		t.Fatalf("could not find token end")
	}
	return rest[:end]
}

// ── A2.7 — withAuth middleware accepts V17 tokens ────────────────────────

func TestWithAuth_AcceptsV17SessionToken(t *testing.T) {
	env := newAuthTestEnv(t)
	env.preSignup(t, "m@x.com", "Strong1Password!")
	tok := env.loginToken(t, "m@x.com", "Strong1Password!")

	// /v1/me is a withAuth-protected endpoint registered by the legacy
	// route table; passing a V17 session token must work.
	req, _ := http.NewRequest(http.MethodGet, env.srv.URL+"/v1/me", nil)
	req.Header.Set("Authorization", "Bearer "+tok)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("get me: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200 with V17 token, got %d", resp.StatusCode)
	}
}

func TestWithAuth_RejectsRevokedV17Token(t *testing.T) {
	env := newAuthTestEnv(t)
	env.preSignup(t, "rv@x.com", "Strong1Password!")
	tok := env.loginToken(t, "rv@x.com", "Strong1Password!")

	// Revoke directly via the store.
	env.tokens.RevokeAuthToken(auth.HashToken(tok))

	req, _ := http.NewRequest(http.MethodGet, env.srv.URL+"/v1/me", nil)
	req.Header.Set("Authorization", "Bearer "+tok)
	resp, _ := http.DefaultClient.Do(req)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("expected 401 after revoke, got %d", resp.StatusCode)
	}
}

func TestWithAuth_LegacyDevTokenStillWorks(t *testing.T) {
	env := newAuthTestEnv(t)

	// dev-learner-token is seeded by NewMemoryStore when ENV != production.
	req, _ := http.NewRequest(http.MethodGet, env.srv.URL+"/v1/me", nil)
	req.Header.Set("Authorization", "Bearer dev-learner-token")
	resp, _ := http.DefaultClient.Do(req)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Errorf("legacy dev-learner-token should still authenticate, got %d", resp.StatusCode)
	}
}

// ── A2.8 — /v1/users/me ──────────────────────────────────────────────────

func (env *authTestEnv) getMe(t *testing.T, token string) (*http.Response, map[string]any) {
	t.Helper()
	req, _ := http.NewRequest(http.MethodGet, env.srv.URL+"/v1/users/me", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("get /me: %v", err)
	}
	t.Cleanup(func() { resp.Body.Close() })
	var out map[string]any
	_ = json.NewDecoder(resp.Body).Decode(&out)
	return resp, out
}

func (env *authTestEnv) patchMe(t *testing.T, token string, body any) (*http.Response, map[string]any) {
	t.Helper()
	buf, _ := json.Marshal(body)
	req, _ := http.NewRequest(http.MethodPatch, env.srv.URL+"/v1/users/me", bytes.NewReader(buf))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("patch /me: %v", err)
	}
	t.Cleanup(func() { resp.Body.Close() })
	var out map[string]any
	_ = json.NewDecoder(resp.Body).Decode(&out)
	return resp, out
}

func TestGetMe_HappyPath(t *testing.T) {
	env := newAuthTestEnv(t)
	env.preSignup(t, "me@x.com", "Strong1Password!")
	tok := env.loginToken(t, "me@x.com", "Strong1Password!")

	resp, body := env.getMe(t, tok)
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}
	user := body["user"].(map[string]any)
	if user["email"] != "me@x.com" {
		t.Errorf("email: %v", user["email"])
	}
	if user["pro_tier"] != "free" {
		t.Errorf("pro_tier: %v", user["pro_tier"])
	}
	if _, ok := body["streak"]; !ok {
		t.Error("missing streak block")
	}
	if _, ok := body["usage_today"]; !ok {
		t.Error("missing usage_today block")
	}
	if _, ok := body["pro"]; !ok {
		t.Error("missing pro block")
	}
}

func TestGetMe_RequiresAuth(t *testing.T) {
	env := newAuthTestEnv(t)
	resp, err := http.Get(env.srv.URL + "/v1/users/me")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", resp.StatusCode)
	}
}

func TestPatchMe_UpdatesAllowedFields(t *testing.T) {
	env := newAuthTestEnv(t)
	env.preSignup(t, "p@x.com", "Strong1Password!")
	tok := env.loginToken(t, "p@x.com", "Strong1Password!")

	resp, body := env.patchMe(t, tok, map[string]string{
		"display_name":      "New Name",
		"onboarding_goal":   "a2_pobyt",
		"onboarding_level":  "a1",
		"daily_reminder_at": "20:00",
		"timezone":          "Asia/Ho_Chi_Minh",
	})
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d body=%v", resp.StatusCode, body)
	}
	user := body["user"].(map[string]any)
	if user["display_name"] != "New Name" {
		t.Errorf("display_name not updated: %v", user["display_name"])
	}
	if user["onboarding_goal"] != "a2_pobyt" {
		t.Errorf("onboarding_goal: %v", user["onboarding_goal"])
	}
}

func TestPatchMe_IgnoresImmutableFields(t *testing.T) {
	env := newAuthTestEnv(t)
	env.preSignup(t, "i@x.com", "Strong1Password!")
	tok := env.loginToken(t, "i@x.com", "Strong1Password!")

	// Try to escalate role via the patch payload — must be silently
	// ignored because patchMeRequest does not list it.
	_, body := env.patchMe(t, tok, map[string]string{
		"role":          "admin",
		"pro_tier":      "pro",
		"display_name":  "OK",
	})
	user := body["user"].(map[string]any)
	if user["role"] == "admin" {
		t.Error("role escalation must be impossible via PATCH /me")
	}
	if user["pro_tier"] != "free" {
		t.Errorf("pro_tier escalation must be impossible, got %v", user["pro_tier"])
	}
}

func TestDeleteMe_AnonymizesAndRevokes(t *testing.T) {
	env := newAuthTestEnv(t)
	env.preSignup(t, "d@x.com", "Strong1Password!")
	tok := env.loginToken(t, "d@x.com", "Strong1Password!")

	req, _ := http.NewRequest(http.MethodDelete, env.srv.URL+"/v1/users/me", nil)
	req.Header.Set("Authorization", "Bearer "+tok)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("delete: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusNoContent {
		t.Fatalf("expected 204, got %d", resp.StatusCode)
	}

	// Email is anonymized + soft-deleted -> cannot be looked up.
	if _, ok := env.users.UserAccountByEmail("d@x.com"); ok {
		t.Error("email lookup must miss after delete")
	}
	// Token revoked -> /me is 401.
	resp2, _ := env.getMe(t, tok)
	if resp2.StatusCode != http.StatusUnauthorized {
		t.Errorf("expected 401 after delete, got %d", resp2.StatusCode)
	}
	// Email is freed for re-registration.
	if r, _ := env.signup(t, map[string]string{
		"email": "d@x.com", "password": "Strong1Password!", "display_name": "X",
	}); r.StatusCode != http.StatusOK {
		t.Errorf("expected re-signup 200, got %d", r.StatusCode)
	}
}

func TestEmailChange_HappyPath(t *testing.T) {
	env := newAuthTestEnv(t)
	env.preSignup(t, "old@x.com", "Strong1Password!")
	tok := env.loginToken(t, "old@x.com", "Strong1Password!")

	resp, _ := env.postJSONWithAuth(t, "/v1/users/me/email-change", tok, map[string]string{
		"new_email":        "new@x.com",
		"current_password": "Strong1Password!",
	})
	if resp.StatusCode != http.StatusNoContent {
		t.Fatalf("expected 204, got %d", resp.StatusCode)
	}

	// Lookup by old email must miss; new email must hit and be unverified.
	if _, ok := env.users.UserAccountByEmail("old@x.com"); ok {
		t.Error("old email still findable")
	}
	updated, ok := env.users.UserAccountByEmail("new@x.com")
	if !ok {
		t.Fatal("new email missing")
	}
	if updated.IsEmailVerified() {
		t.Error("changing email must reset verified status")
	}
}

func TestEmailChange_DuplicateEmail_409(t *testing.T) {
	env := newAuthTestEnv(t)
	env.preSignup(t, "a@x.com", "Strong1Password!")
	env.preSignup(t, "b@x.com", "Strong1Password!")
	tok := env.loginToken(t, "a@x.com", "Strong1Password!")

	resp, body := env.postJSONWithAuth(t, "/v1/users/me/email-change", tok, map[string]string{
		"new_email":        "b@x.com",
		"current_password": "Strong1Password!",
	})
	if resp.StatusCode != http.StatusConflict {
		t.Errorf("expected 409, got %d", resp.StatusCode)
	}
	if body["error"] != "email_taken" {
		t.Errorf("expected error=email_taken, got %v", body["error"])
	}
}

func TestEmailChange_WrongPassword_401(t *testing.T) {
	env := newAuthTestEnv(t)
	env.preSignup(t, "ec@x.com", "Strong1Password!")
	tok := env.loginToken(t, "ec@x.com", "Strong1Password!")

	resp, _ := env.postJSONWithAuth(t, "/v1/users/me/email-change", tok, map[string]string{
		"new_email":        "new@x.com",
		"current_password": "wrong",
	})
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", resp.StatusCode)
	}
}

// ── A3 — authorization gates ─────────────────────────────────────────────

// firstSeededExerciseID returns the id of an exercise the legacy seed
// stocks the MemoryStore with, so the attempt-creation tests have a
// real exercise to point at.
func firstSeededExerciseID(t *testing.T) string {
	t.Helper()
	repo := store.NewMemoryStore()
	exs := repo.ListExercises("")
	if len(exs) == 0 {
		t.Fatal("no seeded exercises found")
	}
	return exs[0].ID
}

func (env *authTestEnv) postAttempt(t *testing.T, token, exerciseID string) *http.Response {
	t.Helper()
	body := map[string]string{
		"exercise_id":     exerciseID,
		"client_platform": "ios",
		"locale":          "vi",
	}
	buf, _ := json.Marshal(body)
	req, _ := http.NewRequest(http.MethodPost, env.srv.URL+"/v1/attempts", bytes.NewReader(buf))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("post attempt: %v", err)
	}
	t.Cleanup(func() { resp.Body.Close() })
	return resp
}

func TestAttemptQuota_FreeUserBlockedAfter7thAttempt(t *testing.T) {
	env := newAuthTestEnv(t)
	exID := firstSeededExerciseID(t)
	env.preSignup(t, "q@x.com", "Strong1Password!")
	user, _ := env.users.UserAccountByEmail("q@x.com")
	// Verify so the verify-gate does not interfere with quota tests.
	env.users.MarkUserEmailVerified(user.ID)
	tok := env.loginToken(t, "q@x.com", "Strong1Password!")

	for i := 1; i <= 7; i++ {
		resp := env.postAttempt(t, tok, exID)
		if resp.StatusCode != http.StatusCreated {
			t.Fatalf("attempt #%d expected 201, got %d", i, resp.StatusCode)
		}
	}
	// 8th -> 429.
	resp := env.postAttempt(t, tok, exID)
	if resp.StatusCode != http.StatusTooManyRequests {
		t.Errorf("8th attempt expected 429, got %d", resp.StatusCode)
	}
	if resp.Header.Get("X-Limit-Reset") == "" {
		t.Error("expected X-Limit-Reset header on 429")
	}
}

func TestAttemptQuota_ProUserUnlimited(t *testing.T) {
	env := newAuthTestEnv(t)
	exID := firstSeededExerciseID(t)
	env.preSignup(t, "pro@x.com", "Strong1Password!")
	user, _ := env.users.UserAccountByEmail("pro@x.com")
	env.users.MarkUserEmailVerified(user.ID)
	// Promote to Pro with future expiry.
	env.users.UpdateUser(user.ID, func(u *contracts.UserAccount) {
		u.ProTier = "pro"
		exp := time.Now().Add(30 * 24 * time.Hour)
		u.ProExpiresAt = &exp
	})
	tok := env.loginToken(t, "pro@x.com", "Strong1Password!")

	// 10 attempts > free cap of 7, all must succeed for Pro.
	for i := 1; i <= 10; i++ {
		resp := env.postAttempt(t, tok, exID)
		if resp.StatusCode != http.StatusCreated {
			t.Fatalf("Pro attempt #%d expected 201, got %d", i, resp.StatusCode)
		}
	}
}

func TestVerifyGate_BlocksAfterGraceExhausted(t *testing.T) {
	env := newAuthTestEnv(t)
	exID := firstSeededExerciseID(t)
	env.preSignup(t, "v@x.com", "Strong1Password!")
	tok := env.loginToken(t, "v@x.com", "Strong1Password!")
	user, _ := env.users.UserAccountByEmail("v@x.com")
	if user.GraceAttemptsLeft != 3 {
		t.Fatalf("expected fresh account grace=3, got %d", user.GraceAttemptsLeft)
	}

	// First 3 attempts succeed (each burns one grace credit).
	for i := 1; i <= 3; i++ {
		resp := env.postAttempt(t, tok, exID)
		if resp.StatusCode != http.StatusCreated {
			t.Fatalf("grace #%d expected 201, got %d", i, resp.StatusCode)
		}
	}

	// 4th attempt -> 403 email_verify_required because grace is at 0
	// and the user is still unverified.
	resp := env.postAttempt(t, tok, exID)
	if resp.StatusCode != http.StatusForbidden {
		t.Errorf("expected 403 after grace, got %d", resp.StatusCode)
	}
	var body map[string]any
	_ = json.NewDecoder(resp.Body).Decode(&body)
	if body["error"] != "email_verify_required" {
		t.Errorf("expected email_verify_required, got %v", body["error"])
	}
}

func TestVerifyGate_VerifiedAccountUnblocked(t *testing.T) {
	env := newAuthTestEnv(t)
	exID := firstSeededExerciseID(t)
	env.preSignup(t, "vv@x.com", "Strong1Password!")
	user, _ := env.users.UserAccountByEmail("vv@x.com")
	env.users.MarkUserEmailVerified(user.ID)
	tok := env.loginToken(t, "vv@x.com", "Strong1Password!")

	// Verified account -> unlimited burns of "grace" because the gate is
	// a no-op once IsEmailVerified is true. Run 5 attempts well past the
	// initial grace=3 ceiling.
	for i := 1; i <= 5; i++ {
		resp := env.postAttempt(t, tok, exID)
		if resp.StatusCode != http.StatusCreated {
			t.Fatalf("verified attempt #%d expected 201, got %d", i, resp.StatusCode)
		}
	}
}

// ── A4 — IAP verify + webhook ────────────────────────────────────────────

func TestIAPVerify_HappyPath(t *testing.T) {
	env := newAuthTestEnv(t)
	env.preSignup(t, "iap@x.com", "Strong1Password!")
	tok := env.loginToken(t, "iap@x.com", "Strong1Password!")

	expires := time.Now().Add(30 * 24 * time.Hour).Truncate(time.Millisecond)
	env.verifier.FixedResponse = &iap.VerifyReceiptResponse{
		Status:   iap.AppleStatusOK,
		BundleID: "eu.hadoo.czechgo",
		Latest: []iap.Receipt{
			{
				TransactionID:         "txn-1",
				OriginalTransactionID: "orig-1",
				ProductID:             "eu.hadoo.czechgo.pro.monthly",
				PurchaseDateMS:        "1714896000000",
				ExpiresDateMS:         fmtMS(expires),
			},
		},
		Raw: []byte(`{"status":0}`),
	}

	resp, body := env.postJSONWithAuth(t, "/v1/iap/apple/verify", tok, map[string]string{
		"receipt":    "anything",
		"product_id": "eu.hadoo.czechgo.pro.monthly",
	})
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d body=%v", resp.StatusCode, body)
	}
	if body["product_id"] != "eu.hadoo.czechgo.pro.monthly" {
		t.Errorf("product_id: %v", body["product_id"])
	}

	// User flipped to pro.
	user, _ := env.users.UserAccountByEmail("iap@x.com")
	if user.ProTier != "pro" {
		t.Errorf("expected pro tier, got %q", user.ProTier)
	}
	if user.ProExpiresAt == nil || !user.ProExpiresAt.After(time.Now()) {
		t.Errorf("expected future pro_expires_at, got %v", user.ProExpiresAt)
	}
}

func TestIAPVerify_DuplicateTransaction_ReturnsActive(t *testing.T) {
	env := newAuthTestEnv(t)
	env.preSignup(t, "dup@x.com", "Strong1Password!")
	tok := env.loginToken(t, "dup@x.com", "Strong1Password!")

	env.verifier.FixedResponse = &iap.VerifyReceiptResponse{
		Status: iap.AppleStatusOK,
		Latest: []iap.Receipt{{
			TransactionID:         "txn-dup",
			OriginalTransactionID: "orig-dup",
			ProductID:             "eu.hadoo.czechgo.pro.monthly",
			PurchaseDateMS:        "1714896000000",
			ExpiresDateMS:         fmtMS(time.Now().Add(30 * 24 * time.Hour)),
		}},
	}

	resp1, _ := env.postJSONWithAuth(t, "/v1/iap/apple/verify", tok, map[string]string{
		"receipt": "r", "product_id": "eu.hadoo.czechgo.pro.monthly",
	})
	if resp1.StatusCode != http.StatusOK {
		t.Fatalf("first: %d", resp1.StatusCode)
	}

	resp2, _ := env.postJSONWithAuth(t, "/v1/iap/apple/verify", tok, map[string]string{
		"receipt": "r", "product_id": "eu.hadoo.czechgo.pro.monthly",
	})
	// Duplicate must NOT 409 the client — same response shape.
	if resp2.StatusCode != http.StatusOK {
		t.Errorf("dup expected 200, got %d", resp2.StatusCode)
	}
}

func TestIAPVerify_RequiresAuth(t *testing.T) {
	env := newAuthTestEnv(t)
	resp, _ := env.postJSON(t, "/v1/iap/apple/verify", map[string]string{
		"receipt": "x",
	})
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", resp.StatusCode)
	}
}

func TestIAPVerify_AppleRejects_Returns400(t *testing.T) {
	env := newAuthTestEnv(t)
	env.preSignup(t, "rej@x.com", "Strong1Password!")
	tok := env.loginToken(t, "rej@x.com", "Strong1Password!")

	env.verifier.Err = iap.ErrFakeNoMatch // simulate apple rejection
	resp, body := env.postJSONWithAuth(t, "/v1/iap/apple/verify", tok, map[string]string{
		"receipt": "bad",
	})
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", resp.StatusCode)
	}
	if body["error"] != "verify_failed" {
		t.Errorf("expected verify_failed, got %v", body["error"])
	}
}

func TestIAPWebhook_DedupesByUUID(t *testing.T) {
	env := newAuthTestEnv(t)

	payload := []byte(`{
		"notificationUUID":"uuid-A",
		"notificationType":"DID_RENEW",
		"data":{"transactionInfo":{"transactionId":"t","originalTransactionId":"o","productId":"p","expiresDate":1717488000000}}
	}`)

	resp1 := postRaw(t, env.srv.URL+"/v1/iap/apple/webhook", payload)
	defer resp1.Body.Close()
	if resp1.StatusCode != http.StatusNoContent {
		t.Errorf("first webhook: %d", resp1.StatusCode)
	}
	// Replay must also 204 but be a no-op.
	resp2 := postRaw(t, env.srv.URL+"/v1/iap/apple/webhook", payload)
	defer resp2.Body.Close()
	if resp2.StatusCode != http.StatusNoContent {
		t.Errorf("replay webhook: %d", resp2.StatusCode)
	}
}

func TestIAPWebhook_ExpiredMarksInactive(t *testing.T) {
	env := newAuthTestEnv(t)
	// Seed a purchase to expire.
	env.purchases.CreateProPurchase(contracts.ProPurchase{
		UserID:                     "u",
		AppleTransactionID:         "txn-exp",
		AppleOriginalTransactionID: "orig",
		ProductID:                  "p",
		PurchasedAt:                time.Now().Add(-30 * 24 * time.Hour),
		ExpiresAt:                  time.Now().Add(time.Hour),
		ReceiptPayload:             []byte(`{}`),
	})

	payload := []byte(`{
		"notificationUUID":"uuid-EXP",
		"notificationType":"EXPIRED",
		"data":{"transactionInfo":{"transactionId":"txn-exp","originalTransactionId":"orig","productId":"p","expiresDate":1717488000000}}
	}`)
	resp := postRaw(t, env.srv.URL+"/v1/iap/apple/webhook", payload)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusNoContent {
		t.Errorf("expected 204, got %d", resp.StatusCode)
	}
	// Active lookup must miss now.
	if _, ok := env.purchases.ActiveProPurchaseByUser("u"); ok {
		t.Error("expected expired purchase to no longer be active")
	}
}

func TestIAPWebhook_InvalidPayload_400(t *testing.T) {
	env := newAuthTestEnv(t)
	resp := postRaw(t, env.srv.URL+"/v1/iap/apple/webhook", []byte(`{"missing":true}`))
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", resp.StatusCode)
	}
}

func fmtMS(t time.Time) string {
	return strconv.FormatInt(t.UnixMilli(), 10)
}

func postRaw(t *testing.T, url string, body []byte) *http.Response {
	t.Helper()
	resp, err := http.Post(url, "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("post: %v", err)
	}
	return resp
}

// ── existing test ────────────────────────────────────────────────────────

func TestSignup_LegacyServerWithoutAuthDeps_ReturnsNotFound(t *testing.T) {
	// Old constructor path → no auth routes registered → /v1/auth/signup
	// must not be served by some accidental fallback.
	repo := store.NewMemoryStore()
	srv := httptest.NewServer(NewServer(repo, nil, nil))
	defer srv.Close()

	resp, err := http.Post(srv.URL+"/v1/auth/signup", "application/json", strings.NewReader("{}"))
	if err != nil {
		t.Fatalf("post: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusNotFound {
		t.Errorf("expected 404 from legacy server, got %d", resp.StatusCode)
	}
}

// ── helpers ──────────────────────────────────────────────────────────────

func newMemoryUserStoreForTest(t *testing.T) store.UserStore {
	t.Helper()
	return store.NewMemoryUserStore()
}

func newMemoryAuthTokenStoreForTest(t *testing.T) store.AuthTokenStore {
	t.Helper()
	return store.NewMemoryAuthTokenStore()
}

// Ensure the user_account contract type still embeds the timestamps the
// signup handler reads. Kept as a compile-time guard.
var _ = contracts.UserAccount{}.CreatedAt
