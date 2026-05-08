package iap

import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/lestrrat-go/jwx/v2/jwa"
	"github.com/lestrrat-go/jwx/v2/jwk"
	"github.com/lestrrat-go/jwx/v2/jwt"
)

// signedAppleToken builds an Apple-shaped identity token signed with
// `key`. `kid` lets us simulate Apple rotating keys; the token's kid
// header points the verifier at the right entry in the JWK Set.
func signedAppleToken(t *testing.T, key jwk.Key, audience string, claims map[string]any) []byte {
	t.Helper()
	tok := jwt.New()
	if err := tok.Set(jwt.IssuerKey, AppleIssuer); err != nil {
		t.Fatalf("set iss: %v", err)
	}
	if err := tok.Set(jwt.AudienceKey, audience); err != nil {
		t.Fatalf("set aud: %v", err)
	}
	if err := tok.Set(jwt.SubjectKey, "apple_sub_001"); err != nil {
		t.Fatalf("set sub: %v", err)
	}
	if err := tok.Set(jwt.ExpirationKey, time.Now().Add(10*time.Minute).Unix()); err != nil {
		t.Fatalf("set exp: %v", err)
	}
	if err := tok.Set(jwt.IssuedAtKey, time.Now().Unix()); err != nil {
		t.Fatalf("set iat: %v", err)
	}
	for k, v := range claims {
		if err := tok.Set(k, v); err != nil {
			t.Fatalf("set %s: %v", k, err)
		}
	}
	signed, err := jwt.Sign(tok, jwt.WithKey(jwa.RS256, key))
	if err != nil {
		t.Fatalf("sign: %v", err)
	}
	return signed
}

// freshAppleKey returns a private signing key + the corresponding
// public JWK that Apple's JWKS endpoint would publish.
func freshAppleKey(t *testing.T, kid string) (jwk.Key, jwk.Key) {
	t.Helper()
	priv, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatalf("rsa: %v", err)
	}
	privKey, err := jwk.FromRaw(priv)
	if err != nil {
		t.Fatalf("private jwk: %v", err)
	}
	if err := privKey.Set(jwk.KeyIDKey, kid); err != nil {
		t.Fatalf("set kid: %v", err)
	}
	if err := privKey.Set(jwk.AlgorithmKey, jwa.RS256); err != nil {
		t.Fatalf("set alg: %v", err)
	}
	pubKey, err := jwk.FromRaw(&priv.PublicKey)
	if err != nil {
		t.Fatalf("public jwk: %v", err)
	}
	if err := pubKey.Set(jwk.KeyIDKey, kid); err != nil {
		t.Fatalf("set kid pub: %v", err)
	}
	if err := pubKey.Set(jwk.AlgorithmKey, jwa.RS256); err != nil {
		t.Fatalf("set alg pub: %v", err)
	}
	return privKey, pubKey
}

func TestAppleJWKS_VerifyWithFixture(t *testing.T) {
	priv, pub := freshAppleKey(t, "fixture-1")
	set := jwk.NewSet()
	if err := set.AddKey(pub); err != nil {
		t.Fatalf("add: %v", err)
	}

	v := NewAppleJWKSVerifierWithSet(set, "eu.hadoo.czechgo")

	signed := signedAppleToken(t, priv, "eu.hadoo.czechgo", map[string]any{
		"email":           "anh@privaterelay.appleid.com",
		"email_verified":  true,
		"nonce":           "abc123",
		"nonce_supported": true,
	})

	claims, err := v.Verify(context.Background(), string(signed))
	if err != nil {
		t.Fatalf("verify: %v", err)
	}
	if claims.Sub != "apple_sub_001" {
		t.Errorf("expected sub=apple_sub_001, got %q", claims.Sub)
	}
	if claims.Email != "anh@privaterelay.appleid.com" {
		t.Errorf("expected email round-trip, got %q", claims.Email)
	}
	if !claims.EmailVerified {
		t.Error("expected email_verified=true")
	}
	if claims.Nonce != "abc123" {
		t.Errorf("expected nonce round-trip, got %q", claims.Nonce)
	}
	if !claims.NonceSupported {
		t.Error("expected nonce_supported=true")
	}
	if claims.Aud != "eu.hadoo.czechgo" {
		t.Errorf("expected aud=eu.hadoo.czechgo, got %q", claims.Aud)
	}
	if claims.Iss != AppleIssuer {
		t.Errorf("expected iss=%s, got %q", AppleIssuer, claims.Iss)
	}
}

func TestAppleJWKS_VerifyRejectsWrongAudience(t *testing.T) {
	priv, pub := freshAppleKey(t, "fixture-1")
	set := jwk.NewSet()
	_ = set.AddKey(pub)
	v := NewAppleJWKSVerifierWithSet(set, "eu.hadoo.czechgo")

	signed := signedAppleToken(t, priv, "com.evil.attacker", nil)
	if _, err := v.Verify(context.Background(), string(signed)); err == nil {
		t.Fatal("expected aud mismatch to be rejected")
	}
}

func TestAppleJWKS_VerifyRejectsExpiredToken(t *testing.T) {
	priv, pub := freshAppleKey(t, "fixture-1")
	set := jwk.NewSet()
	_ = set.AddKey(pub)
	v := NewAppleJWKSVerifierWithSet(set, "eu.hadoo.czechgo")

	tok := jwt.New()
	_ = tok.Set(jwt.IssuerKey, AppleIssuer)
	_ = tok.Set(jwt.AudienceKey, "eu.hadoo.czechgo")
	_ = tok.Set(jwt.SubjectKey, "apple_sub_999")
	_ = tok.Set(jwt.ExpirationKey, time.Now().Add(-1*time.Hour).Unix())
	signed, err := jwt.Sign(tok, jwt.WithKey(jwa.RS256, priv))
	if err != nil {
		t.Fatalf("sign: %v", err)
	}
	if _, err := v.Verify(context.Background(), string(signed)); err == nil {
		t.Fatal("expected expired token to be rejected")
	}
}

func TestAppleJWKS_KeyRotation(t *testing.T) {
	// Apple rotates signing keys on its own schedule. The cache must
	// pick the new public key on refresh so a token signed by the new
	// key validates without restart.
	keys := atomic.Pointer[jwk.Set]{}

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		current := keys.Load()
		if current == nil {
			http.Error(w, "no keys", http.StatusInternalServerError)
			return
		}
		buf, err := json.Marshal(*current)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write(buf)
	}))
	defer server.Close()

	// Seed the JWKS endpoint with key A before booting the verifier so
	// the eager initial fetch succeeds.
	privA, pubA := freshAppleKey(t, "key-A")
	setA := jwk.NewSet()
	_ = setA.AddKey(pubA)
	keys.Store(&setA)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	v, err := NewAppleJWKSVerifier(ctx, server.URL, "eu.hadoo.czechgo")
	if err != nil {
		t.Fatalf("new verifier: %v", err)
	}

	// A token signed by key A verifies fine.
	tokenA := signedAppleToken(t, privA, "eu.hadoo.czechgo", nil)
	if _, err := v.Verify(ctx, string(tokenA)); err != nil {
		t.Fatalf("verify token A: %v", err)
	}

	// Apple rotates: the JWKS endpoint now publishes only key B.
	privB, pubB := freshAppleKey(t, "key-B")
	setB := jwk.NewSet()
	_ = setB.AddKey(pubB)
	keys.Store(&setB)

	// A token signed by key A (no longer in the set) must fail —
	// otherwise the cache is silently keeping stale keys.
	tokenAStale := signedAppleToken(t, privA, "eu.hadoo.czechgo", nil)
	provider := v.provider.(*cachedProvider)
	if _, err := provider.cache.Refresh(ctx, provider.url); err != nil {
		t.Fatalf("refresh: %v", err)
	}
	if _, err := v.Verify(ctx, string(tokenAStale)); err == nil {
		t.Fatal("expected token signed by retired key A to fail after rotation")
	}

	// A token signed by key B verifies cleanly after the rotation.
	tokenB := signedAppleToken(t, privB, "eu.hadoo.czechgo", nil)
	claims, err := v.Verify(ctx, string(tokenB))
	if err != nil {
		t.Fatalf("verify token B: %v", err)
	}
	if !strings.HasPrefix(claims.Sub, "apple_sub_") {
		t.Errorf("expected sub passthrough, got %q", claims.Sub)
	}
}
