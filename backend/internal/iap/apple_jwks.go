package iap

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/lestrrat-go/jwx/v2/jwk"
	"github.com/lestrrat-go/jwx/v2/jwt"
)

// AppleIssuer is the only issuer claim Apple ID tokens carry. Anything
// else is treated as forgery.
const AppleIssuer = "https://appleid.apple.com"

// DefaultAppleJWKSURL is the public JWKS endpoint Apple publishes its
// signing keys at. Apple rotates keys without warning; the cache below
// auto-refreshes so a fresh kid is always reachable.
const DefaultAppleJWKSURL = "https://appleid.apple.com/auth/keys"

// AppleClaims is the subset of identity_token claims the V25 auth path
// reads. Strings are returned verbatim; the bool fields normalise both
// the JSON-bool and JSON-string-"true" forms Apple has shipped over
// time.
type AppleClaims struct {
	Sub            string
	Email          string
	EmailVerified  bool
	Nonce          string
	NonceSupported bool
	Aud            string
	Iss            string
	Exp            time.Time
}

// AppleIdentityVerifier is the interface the auth handler depends on so
// tests can substitute a deterministic fake. Production builds wire
// AppleJWKSVerifier; tests use NewAppleJWKSVerifierWithSet.
type AppleIdentityVerifier interface {
	Verify(ctx context.Context, idToken string) (AppleClaims, error)
}

// keySetProvider abstracts the source of the verifying JWK Set. The
// production implementation hits Apple's JWKS endpoint and caches the
// response; the testing implementation returns a fixed in-memory set.
type keySetProvider interface {
	Get(ctx context.Context) (jwk.Set, error)
}

// AppleJWKSVerifier verifies Apple identity tokens against a JWKS
// fetched from a configurable URL. The underlying jwk.Cache rotates
// keys on its own schedule; callers do not need to invalidate
// explicitly even when Apple rolls a new kid.
type AppleJWKSVerifier struct {
	bundleID string
	provider keySetProvider
}

// NewAppleJWKSVerifier wires the production verifier. It performs an
// eager initial fetch so a misconfigured URL fails on boot rather than
// silently on the first request. The cache is owned by ctx and lives
// for the process lifetime when ctx is the server-root context.
func NewAppleJWKSVerifier(ctx context.Context, jwksURL, bundleID string) (*AppleJWKSVerifier, error) {
	if bundleID == "" {
		return nil, errors.New("apple jwks: bundleID is required")
	}
	if jwksURL == "" {
		jwksURL = DefaultAppleJWKSURL
	}
	cache := jwk.NewCache(ctx)
	if err := cache.Register(jwksURL, jwk.WithMinRefreshInterval(15*time.Minute)); err != nil {
		return nil, fmt.Errorf("apple jwks register: %w", err)
	}
	if _, err := cache.Refresh(ctx, jwksURL); err != nil {
		return nil, fmt.Errorf("apple jwks initial fetch: %w", err)
	}
	return &AppleJWKSVerifier{
		bundleID: bundleID,
		provider: &cachedProvider{cache: cache, url: jwksURL},
	}, nil
}

// NewAppleJWKSVerifierWithSet builds a verifier from a static JWK Set.
// Intended for unit tests + offline fixtures only — production code
// must use NewAppleJWKSVerifier so key rotation is handled.
func NewAppleJWKSVerifierWithSet(set jwk.Set, bundleID string) *AppleJWKSVerifier {
	return &AppleJWKSVerifier{
		bundleID: bundleID,
		provider: &staticProvider{set: set},
	}
}

// Verify validates the JWT signature against the cached JWKS, enforces
// iss / aud / exp, and decodes the claim subset the V25 handler needs.
// All failures collapse to a single error returned to the caller.
func (v *AppleJWKSVerifier) Verify(ctx context.Context, idToken string) (AppleClaims, error) {
	set, err := v.provider.Get(ctx)
	if err != nil {
		return AppleClaims{}, fmt.Errorf("apple jwks: %w", err)
	}
	tok, err := jwt.Parse([]byte(idToken),
		jwt.WithKeySet(set),
		jwt.WithIssuer(AppleIssuer),
		jwt.WithAudience(v.bundleID),
		jwt.WithValidate(true),
	)
	if err != nil {
		return AppleClaims{}, err
	}

	claims := AppleClaims{
		Sub: tok.Subject(),
		Iss: tok.Issuer(),
		Exp: tok.Expiration(),
	}
	if auds := tok.Audience(); len(auds) > 0 {
		claims.Aud = auds[0]
	}
	if raw, ok := tok.Get("email"); ok {
		if s, isString := raw.(string); isString {
			claims.Email = s
		}
	}
	if raw, ok := tok.Get("email_verified"); ok {
		claims.EmailVerified = parseAppleBool(raw)
	}
	if raw, ok := tok.Get("nonce"); ok {
		if s, isString := raw.(string); isString {
			claims.Nonce = s
		}
	}
	if raw, ok := tok.Get("nonce_supported"); ok {
		claims.NonceSupported = parseAppleBool(raw)
	}
	return claims, nil
}

// parseAppleBool accepts both the bool form Apple ships in identity
// tokens today and the string-"true"/"false" form some legacy fixtures
// still carry.
func parseAppleBool(raw any) bool {
	switch t := raw.(type) {
	case bool:
		return t
	case string:
		return t == "true"
	}
	return false
}

// cachedProvider is the production keySetProvider, backed by jwk.Cache.
type cachedProvider struct {
	cache *jwk.Cache
	url   string
}

func (p *cachedProvider) Get(ctx context.Context) (jwk.Set, error) {
	return p.cache.Get(ctx, p.url)
}

// staticProvider returns the same in-memory jwk.Set on every call.
// Used by NewAppleJWKSVerifierWithSet so unit tests do not need a
// running JWKS endpoint.
type staticProvider struct {
	set jwk.Set
}

func (p *staticProvider) Get(_ context.Context) (jwk.Set, error) {
	if p.set == nil {
		return nil, errors.New("apple jwks: static set is nil")
	}
	return p.set, nil
}
