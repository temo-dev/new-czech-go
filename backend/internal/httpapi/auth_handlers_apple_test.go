package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/email"
	"github.com/danieldev/czech-go-system/backend/internal/iap"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

// fakeAppleIdentityVerifier is a swappable AppleIdentityVerifier used
// by handler tests. Set Result to drive the happy path; set Err to
// drive verify failures. Calls are counted so tests can assert the
// handler hit the verifier (and exactly once).
type fakeAppleIdentityVerifier struct {
	Result iap.AppleClaims
	Err    error
	calls  int32
}

func (f *fakeAppleIdentityVerifier) Verify(_ context.Context, _ string) (iap.AppleClaims, error) {
	atomic.AddInt32(&f.calls, 1)
	if f.Err != nil {
		return iap.AppleClaims{}, f.Err
	}
	return f.Result, nil
}

func (f *fakeAppleIdentityVerifier) Calls() int { return int(atomic.LoadInt32(&f.calls)) }

// appleAuthEnv mirrors authTestEnv but wires an AppleIdentityVerifier
// so /v1/auth/apple is registered. Keeping a separate constructor
// avoids regressing the legacy email-only auth tests.
type appleAuthEnv struct {
	srv      *httptest.Server
	users    store.UserStore
	tokens   store.AuthTokenStore
	verifier *fakeAppleIdentityVerifier
}

func newAppleAuthEnv(t *testing.T) *appleAuthEnv {
	t.Helper()
	repo := store.NewMemoryStore()
	users := newMemoryUserStoreForTest(t)
	tokens := newMemoryAuthTokenStoreForTest(t)
	streaks := store.NewMemoryStreakStore()
	usage := store.NewMemoryDailyUsageStore()
	purchases := store.NewMemoryProPurchaseStore()
	rec := email.NewRecorderSender()
	identity := &fakeAppleIdentityVerifier{}

	deps := AuthDeps{
		Users:         users,
		AuthTokens:    tokens,
		Streaks:       streaks,
		DailyUsage:    usage,
		ProPurchases:  purchases,
		EmailSender:   rec,
		AppleVerifier: &iap.FakeAppleVerifier{},
		AppleJWKS:     identity,
		BaseURL:       "https://api.example.test",
		VerifyTTL:     24 * time.Hour,
	}
	handler := NewServerWithAuth(repo, nil, nil, nil, nil, deps)
	srv := httptest.NewServer(handler)
	t.Cleanup(srv.Close)
	return &appleAuthEnv{srv: srv, users: users, tokens: tokens, verifier: identity}
}

func (env *appleAuthEnv) postApple(t *testing.T, body map[string]string) (*http.Response, map[string]any) {
	t.Helper()
	buf, _ := json.Marshal(body)
	resp, err := http.Post(env.srv.URL+"/v1/auth/apple", "application/json", bytes.NewReader(buf))
	if err != nil {
		t.Fatalf("post apple: %v", err)
	}
	t.Cleanup(func() { resp.Body.Close() })
	var out map[string]any
	_ = json.NewDecoder(resp.Body).Decode(&out)
	return resp, out
}

// ── happy paths ──────────────────────────────────────────────────────────

func TestHandleAuthApple_ValidToken_NewUser(t *testing.T) {
	env := newAppleAuthEnv(t)
	env.verifier.Result = iap.AppleClaims{
		Sub:           "apple_sub_001",
		Email:         "anh@privaterelay.appleid.com",
		EmailVerified: true,
		Nonce:         "nonce_abc",
	}

	resp, body := env.postApple(t, map[string]string{
		"identity_token":     "fake.identity.token",
		"authorization_code": "code123",
		"nonce":              "nonce_abc",
		"given_name":         "Anh",
		"family_name":        "Nguyễn",
	})
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d body=%v", resp.StatusCode, body)
	}
	if env.verifier.Calls() != 1 {
		t.Errorf("expected verifier called exactly once, got %d", env.verifier.Calls())
	}
	if body["session_token"] == nil || body["session_token"] == "" {
		t.Errorf("expected session_token in response, got %v", body)
	}
	user, _ := body["user"].(map[string]any)
	if user == nil {
		t.Fatalf("missing user in response: %v", body)
	}
	if user["email"] != "anh@privaterelay.appleid.com" {
		t.Errorf("expected email round-trip, got %v", user["email"])
	}
	if user["email_verified"] != true {
		t.Error("expected email_verified=true (Apple has verified)")
	}
	if user["pro_tier"] != "free" {
		t.Errorf("expected free tier on signup, got %v", user["pro_tier"])
	}

	// User is keyed by apple_sub in the store. Calling UpsertByAppleSub
	// again must return the row the handler created, not insert a new one.
	stored, err := env.users.UpsertByAppleSub("apple_sub_001", "", "")
	if err != nil {
		t.Fatalf("re-upsert: %v", err)
	}
	if stored.AppleSub != "apple_sub_001" {
		t.Errorf("expected stored user keyed by apple_sub, got %q", stored.AppleSub)
	}
	if stored.DisplayName != "Anh Nguyễn" {
		t.Errorf("expected display name from given+family, got %q", stored.DisplayName)
	}
}

func TestHandleAuthApple_ValidToken_ExistingUser(t *testing.T) {
	env := newAppleAuthEnv(t)

	// Pre-create the Apple-linked user via the store directly so we can
	// assert the handler returns the same row instead of duplicating.
	first, err := env.users.UpsertByAppleSub("apple_sub_002", "bao@example.com", "Bảo")
	if err != nil {
		t.Fatalf("seed: %v", err)
	}

	env.verifier.Result = iap.AppleClaims{
		Sub:           "apple_sub_002",
		Email:         "bao@example.com",
		EmailVerified: true,
		Nonce:         "nonce_xyz",
	}

	resp, body := env.postApple(t, map[string]string{
		"identity_token": "fake.identity.token",
		"nonce":          "nonce_xyz",
		// Apple does NOT resend given_name/family_name on subsequent
		// sign-ins; the handler must still return the original record.
	})
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d body=%v", resp.StatusCode, body)
	}
	user := body["user"].(map[string]any)
	if user["id"] != first.ID {
		t.Errorf("expected same user_id on replay, got %v vs %q", user["id"], first.ID)
	}
	if user["display_name"] != "Bảo" {
		t.Errorf("expected display name preserved on replay, got %v", user["display_name"])
	}
}

// ── error paths ──────────────────────────────────────────────────────────

func TestHandleAuthApple_InvalidJWS(t *testing.T) {
	env := newAppleAuthEnv(t)
	env.verifier.Err = errors.New("could not verify message: signature verification failed")

	resp, body := env.postApple(t, map[string]string{
		"identity_token": "tampered",
		"nonce":          "any",
	})
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d body=%v", resp.StatusCode, body)
	}
	if body["error"] != "invalid_token" {
		t.Errorf("expected error=invalid_token, got %v", body["error"])
	}
}

func TestHandleAuthApple_NonceMismatch(t *testing.T) {
	env := newAppleAuthEnv(t)
	env.verifier.Result = iap.AppleClaims{
		Sub:   "apple_sub_003",
		Email: "x@y.com",
		Nonce: "server_says_abc",
	}

	resp, body := env.postApple(t, map[string]string{
		"identity_token": "tok",
		"nonce":          "client_thought_xyz",
	})
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d body=%v", resp.StatusCode, body)
	}
	if body["error"] != "nonce_mismatch" {
		t.Errorf("expected nonce_mismatch, got %v", body["error"])
	}
}

func TestHandleAuthApple_ExpiredToken(t *testing.T) {
	env := newAppleAuthEnv(t)
	// jwx wraps expired tokens with an "exp not satisfied" message; the
	// classifier maps it to "expired_token".
	env.verifier.Err = errors.New(`"exp" not satisfied`)

	resp, body := env.postApple(t, map[string]string{
		"identity_token": "expired_tok",
		"nonce":          "any",
	})
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d body=%v", resp.StatusCode, body)
	}
	if body["error"] != "expired_token" {
		t.Errorf("expected expired_token, got %v", body["error"])
	}
}

func TestHandleAuthApple_AudienceMismatch(t *testing.T) {
	env := newAppleAuthEnv(t)
	env.verifier.Err = errors.New(`"aud" not satisfied`)

	resp, body := env.postApple(t, map[string]string{
		"identity_token": "wrong_aud",
		"nonce":          "any",
	})
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d body=%v", resp.StatusCode, body)
	}
	if body["error"] != "invalid_audience" {
		t.Errorf("expected invalid_audience, got %v", body["error"])
	}
}

func TestHandleAuthApple_MissingFields(t *testing.T) {
	env := newAppleAuthEnv(t)

	cases := []struct {
		name string
		body map[string]string
		code string
	}{
		{"missing identity_token", map[string]string{"nonce": "x"}, "invalid_token"},
		{"missing nonce", map[string]string{"identity_token": "tok"}, "missing_nonce"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			resp, body := env.postApple(t, tc.body)
			if resp.StatusCode != http.StatusBadRequest {
				t.Fatalf("expected 400, got %d body=%v", resp.StatusCode, body)
			}
			if body["error"] != tc.code {
				t.Errorf("expected error=%s, got %v", tc.code, body["error"])
			}
		})
	}
}

// TestServer_AuthApple_Integration is the B2 smoke test: the session
// token returned by /v1/auth/apple must authenticate against /v1/users/me
// without further mutation. Catches regressions where the Apple handler
// mints a token via a different code path than the email login flow.
func TestServer_AuthApple_Integration(t *testing.T) {
	env := newAppleAuthEnv(t)
	env.verifier.Result = iap.AppleClaims{
		Sub:           "apple_sub_e2e",
		Email:         "e2e@privaterelay.appleid.com",
		EmailVerified: true,
		Nonce:         "e2e_nonce",
	}

	resp, body := env.postApple(t, map[string]string{
		"identity_token": "fake.identity.token",
		"nonce":          "e2e_nonce",
		"given_name":     "E2E",
		"family_name":    "Tester",
	})
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("apple post: expected 200, got %d body=%v", resp.StatusCode, body)
	}
	token, _ := body["session_token"].(string)
	if token == "" {
		t.Fatalf("expected session_token, got body=%v", body)
	}

	meReq, _ := http.NewRequest(http.MethodGet, env.srv.URL+"/v1/users/me", nil)
	meReq.Header.Set("Authorization", "Bearer "+token)
	meResp, err := http.DefaultClient.Do(meReq)
	if err != nil {
		t.Fatalf("me request: %v", err)
	}
	defer meResp.Body.Close()
	if meResp.StatusCode != http.StatusOK {
		t.Fatalf("expected /v1/users/me to authenticate via apple session, got %d", meResp.StatusCode)
	}
	var me map[string]any
	_ = json.NewDecoder(meResp.Body).Decode(&me)
	user, _ := me["user"].(map[string]any)
	if user == nil {
		t.Fatalf("expected user block in /v1/users/me response, got %v", me)
	}
	if email, _ := user["email"].(string); email != "e2e@privaterelay.appleid.com" {
		t.Errorf("expected /v1/users/me email round-trip, got %v", user["email"])
	}
}

func TestHandleAuthApple_DisabledWhenNoVerifier(t *testing.T) {
	// When AppleJWKS is nil, the route is not registered → 404.
	repo := store.NewMemoryStore()
	users := newMemoryUserStoreForTest(t)
	tokens := newMemoryAuthTokenStoreForTest(t)
	deps := AuthDeps{
		Users:        users,
		AuthTokens:   tokens,
		Streaks:      store.NewMemoryStreakStore(),
		DailyUsage:   store.NewMemoryDailyUsageStore(),
		ProPurchases: store.NewMemoryProPurchaseStore(),
		EmailSender:  email.NewRecorderSender(),
		BaseURL:      "https://api.example.test",
	}
	handler := NewServerWithAuth(repo, nil, nil, nil, nil, deps)
	srv := httptest.NewServer(handler)
	defer srv.Close()

	resp, err := http.Post(srv.URL+"/v1/auth/apple", "application/json", bytes.NewReader([]byte(`{}`)))
	if err != nil {
		t.Fatalf("post: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusNotFound {
		t.Fatalf("expected 404 when verifier is nil, got %d", resp.StatusCode)
	}
}
