package httpapi

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

// ── C3 — signup rate limit ──────────────────────────────────────────────

func TestSignupRateLimiter_AllowsUpToCap(t *testing.T) {
	rl := newSignupRateLimiter()
	for i := 0; i < 10; i++ {
		if !rl.Allow("1.2.3.4") {
			t.Fatalf("attempt %d should be allowed (cap is 10)", i+1)
		}
	}
	if rl.Allow("1.2.3.4") {
		t.Error("11th attempt must be blocked")
	}
}

func TestSignupRateLimiter_PerIPIsolation(t *testing.T) {
	rl := newSignupRateLimiter()
	for i := 0; i < 10; i++ {
		rl.Allow("1.1.1.1")
	}
	// Other IP must not be affected.
	if !rl.Allow("2.2.2.2") {
		t.Error("different IP should not be blocked by another IP's rate limit")
	}
}

func TestSignupRateLimiter_EmptyIPDoesNotBlock(t *testing.T) {
	rl := newSignupRateLimiter()
	for i := 0; i < 100; i++ {
		if !rl.Allow("") {
			t.Fatal("empty ip should always be allowed (problem is upstream)")
		}
	}
}

// ── I4 — looksLikeEmail strictness via mail.ParseAddress ────────────────

func TestLooksLikeEmail_RejectsCommonMalformations(t *testing.T) {
	bad := []string{
		"",
		"plain",
		"@nohost",
		"name@",
		"name@nodot",
		"two@@example.com",
		"name with space@example.com",
		`"Anh" <a@x.com>`, // display-name form
		"a@b",             // no dot in domain
	}
	for _, s := range bad {
		if looksLikeEmail(s) {
			t.Errorf("expected %q to be rejected", s)
		}
	}
}

func TestLooksLikeEmail_AcceptsNormalAddresses(t *testing.T) {
	good := []string{
		"a@x.com",
		"learner+tag@example.co.uk",
		"first.last@czechgo.hadoo.eu",
	}
	for _, s := range good {
		if !looksLikeEmail(s) {
			t.Errorf("expected %q to be accepted", s)
		}
	}
}

// ── I6 — redactEmail ────────────────────────────────────────────────────

func TestRedactEmail_KeepsFirstLetterAndDomain(t *testing.T) {
	cases := map[string]string{
		"learner@example.com": "l***@example.com",
		"x@y.com":             "x***@y.com",
		"":                    "***",
		"no-at-sign":          "***",
	}
	for in, want := range cases {
		if got := redactEmail(in); got != want {
			t.Errorf("redactEmail(%q) = %q, want %q", in, got, want)
		}
	}
}

// ── C1 — IAP webhook shared-secret guard ────────────────────────────────

func TestIAPWebhook_DevWithoutSecret_AllowsAnything(t *testing.T) {
	t.Setenv("ENV", "")
	t.Setenv("IAP_WEBHOOK_SECRET", "")

	env := newAuthTestEnv(t)
	resp := postRaw(t, env.srv.URL+"/v1/iap/apple/webhook",
		[]byte(`{"notificationUUID":"u","notificationType":"DID_RENEW","data":{"transactionInfo":{"transactionId":"t","originalTransactionId":"o","productId":"p","expiresDate":1717488000000}}}`))
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusNoContent {
		t.Errorf("dev w/o secret: expected 204, got %d", resp.StatusCode)
	}
}

func TestIAPWebhook_ProductionWithoutSecret_Rejected(t *testing.T) {
	// Build the test env first (still in dev mode) so the
	// MemoryStore admin-password fatal guard doesn't fire; then flip
	// ENV=production right before hitting the webhook so the
	// allowIAPWebhook guard sees the production gate.
	env := newAuthTestEnv(t)

	t.Setenv("ENV", "production")
	t.Setenv("IAP_WEBHOOK_SECRET", "")

	resp := postRaw(t, env.srv.URL+"/v1/iap/apple/webhook", []byte(`{}`))
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("production w/o secret: expected 401, got %d", resp.StatusCode)
	}
}

func TestIAPWebhook_WithSecret_AcceptsMatching(t *testing.T) {
	t.Setenv("IAP_WEBHOOK_SECRET", "test-secret-abc")
	env := newAuthTestEnv(t)

	body := []byte(`{"notificationUUID":"u-match","notificationType":"DID_RENEW","data":{"transactionInfo":{"transactionId":"t","originalTransactionId":"o","productId":"p","expiresDate":1717488000000}}}`)
	req, _ := http.NewRequest(http.MethodPost, env.srv.URL+"/v1/iap/apple/webhook", bytes.NewReader(body))
	req.Header.Set("X-Czechgo-Webhook-Secret", "test-secret-abc")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("do: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusNoContent {
		t.Errorf("matching secret: expected 204, got %d", resp.StatusCode)
	}
}

func TestIAPWebhook_WithSecret_RejectsMismatching(t *testing.T) {
	t.Setenv("IAP_WEBHOOK_SECRET", "expected-secret")
	env := newAuthTestEnv(t)

	body := []byte(`{}`)
	req, _ := http.NewRequest(http.MethodPost, env.srv.URL+"/v1/iap/apple/webhook", bytes.NewReader(body))
	req.Header.Set("X-Czechgo-Webhook-Secret", "wrong-secret")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("do: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("wrong secret: expected 401, got %d", resp.StatusCode)
	}
}

// ── C3 — signup rate limit end-to-end via httptest ──────────────────────

func TestSignupHandler_ReturnsTooManyOnIPCap(t *testing.T) {
	env := newAuthTestEnv(t)

	// 10 successful signups from the same conceptual IP. httptest's
	// loopback uses 127.0.0.1; clientIP() reads X-Forwarded-For first
	// so we can pin a specific IP for the test.
	for i := 0; i < 10; i++ {
		buf, _ := json.Marshal(map[string]string{
			"email":        "rl-" + itoa(i) + "@x.com",
			"password":     "Strong1Password!",
			"display_name": "T",
		})
		req, _ := http.NewRequest(http.MethodPost, env.srv.URL+"/v1/auth/signup", bytes.NewReader(buf))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("X-Forwarded-For", "9.9.9.9")
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatalf("attempt %d: %v", i+1, err)
		}
		resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("attempt %d: expected 200, got %d", i+1, resp.StatusCode)
		}
	}

	// 11th from same IP -> 429.
	buf, _ := json.Marshal(map[string]string{
		"email":        "rl-overflow@x.com",
		"password":     "Strong1Password!",
		"display_name": "T",
	})
	req, _ := http.NewRequest(http.MethodPost, env.srv.URL+"/v1/auth/signup", bytes.NewReader(buf))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Forwarded-For", "9.9.9.9")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("overflow: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusTooManyRequests {
		t.Errorf("11th signup expected 429, got %d", resp.StatusCode)
	}
	var body map[string]any
	_ = json.NewDecoder(resp.Body).Decode(&body)
	if body["error"] != "too_many_signups" {
		t.Errorf("expected error=too_many_signups, got %v", body["error"])
	}
}

func itoa(i int) string {
	if i == 0 {
		return "0"
	}
	digits := []byte{}
	for i > 0 {
		digits = append([]byte{byte('0' + i%10)}, digits...)
		i /= 10
	}
	return string(digits)
}

// ensure httptest baseline still works after our changes.
var _ = httptest.NewServer
