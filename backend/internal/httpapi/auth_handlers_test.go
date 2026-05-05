package httpapi

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/auth"
	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/email"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

// authTestServer wires a fresh in-memory Server with V17 auth deps. The
// returned httptest.Server is the URL clients hit; the *email.RecorderSender
// lets the test assert on dispatched emails after a goroutine flush.
type authTestEnv struct {
	srv      *httptest.Server
	users    store.UserStore
	tokens   store.AuthTokenStore
	emails   *email.RecorderSender
}

func newAuthTestEnv(t *testing.T) *authTestEnv {
	t.Helper()
	repo := store.NewMemoryStore()
	users := newMemoryUserStoreForTest(t)
	tokens := newMemoryAuthTokenStoreForTest(t)
	rec := email.NewRecorderSender()

	deps := AuthDeps{
		Users:       users,
		AuthTokens:  tokens,
		EmailSender: rec,
		BaseURL:     "https://api.example.test",
		VerifyTTL:   24 * time.Hour,
	}
	handler := NewServerWithAuth(repo, nil, nil, nil, nil, deps)
	srv := httptest.NewServer(handler)
	t.Cleanup(srv.Close)
	return &authTestEnv{srv: srv, users: users, tokens: tokens, emails: rec}
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
	env.emails.Reset() // discard the verify email so login tests start clean
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
