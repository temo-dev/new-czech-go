package httpapi

import (
	"encoding/json"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// registerAppleAuthRoute wires POST /v1/auth/apple. Stays unregistered
// when the V25 dependency (AppleJWKS verifier) is absent so the legacy
// dev-fixture and email-only deploys keep their existing 404 surface.
func (s *Server) registerAppleAuthRoute() {
	if s.appleJWKS == nil || s.userStore == nil || s.authTokenStore == nil {
		return
	}
	s.mux.HandleFunc("/v1/auth/apple", s.handleAuthApple)
}

// appleAuthRequest mirrors the body Flutter posts after the native Sign
// in with Apple sheet completes. given_name + family_name are optional
// and only populated on the very first sign-in for a given Apple ID.
type appleAuthRequest struct {
	IdentityToken     string `json:"identity_token"`
	AuthorizationCode string `json:"authorization_code"`
	Nonce             string `json:"nonce"`
	GivenName         string `json:"given_name"`
	FamilyName        string `json:"family_name"`
}

// handleAuthApple verifies an Apple identity_token, upserts the
// learner keyed by the Apple subject claim, and issues a session
// token. The response shape mirrors signupResponse so the Flutter
// client can drive the same post-auth flow regardless of which path
// the user picked.
//
// Spec: docs/specs/iap-wire-real.md §4.2
func (s *Server) handleAuthApple(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}
	if s.appleJWKS == nil {
		writeAuthError(w, http.StatusServiceUnavailable, "apple_disabled",
			"sign in with apple is not configured")
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, 32*1024) // identity tokens are ~1-2 KiB; leave headroom

	var req appleAuthRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAuthError(w, http.StatusBadRequest, "invalid_body", "request body is not valid JSON")
		return
	}
	if strings.TrimSpace(req.IdentityToken) == "" {
		writeAuthError(w, http.StatusBadRequest, "invalid_token", "identity_token is required")
		return
	}
	if strings.TrimSpace(req.Nonce) == "" {
		writeAuthError(w, http.StatusBadRequest, "missing_nonce", "nonce is required")
		return
	}

	claims, err := s.appleJWKS.Verify(r.Context(), req.IdentityToken)
	if err != nil {
		// jwx returns one of several typed errors; the body distinguishes
		// them but the public surface collapses to a single 400 so the
		// client cannot probe valid claim values.
		log.Printf("auth-apple: identity_token verify: %v", err)
		writeAuthError(w, http.StatusBadRequest, classifyAppleVerifyError(err),
			"identity_token did not validate")
		return
	}
	if claims.Sub == "" {
		writeAuthError(w, http.StatusBadRequest, "invalid_token", "identity_token has no subject")
		return
	}
	// Constant-time-ish comparison would be overkill — the nonce is not
	// secret, just a replay guard.
	if claims.Nonce != req.Nonce {
		writeAuthError(w, http.StatusBadRequest, "nonce_mismatch", "nonce does not match")
		return
	}

	displayName := strings.TrimSpace(req.GivenName + " " + req.FamilyName)
	user, err := s.userStore.UpsertByAppleSub(claims.Sub, claims.Email, displayName)
	if err != nil {
		log.Printf("auth-apple: upsert user: %v", err)
		writeAuthError(w, http.StatusInternalServerError, "internal", "could not create account")
		return
	}

	sessionTTL := 30 * 24 * time.Hour
	rawSession, expiresAt, err := s.issueAuthToken(user.ID, contracts.AuthTokenKindSession, sessionTTL, r)
	if err != nil {
		log.Printf("auth-apple: issue session: %v", err)
		writeAuthError(w, http.StatusInternalServerError, "internal", "could not issue session")
		return
	}

	writeJSON(w, http.StatusOK, signupResponse{
		User: signupUser{
			ID:                user.ID,
			Email:             user.Email,
			EmailVerified:     user.IsEmailVerified(),
			DisplayName:       user.DisplayName,
			ProTier:           user.ProTier,
			GraceAttemptsLeft: user.GraceAttemptsLeft,
		},
		SessionToken: rawSession,
		ExpiresAt:    expiresAt,
	})
}

// classifyAppleVerifyError translates a jwx verify error into one of
// the documented public error codes. jwx's wording has shifted over
// versions ("exp not satisfied" vs `"exp" not satisfied` vs "exp not
// satisfied: token is expired") so we match on the claim name as a
// substring and accept either quoted or unquoted form. Unknown
// failures fall back to "invalid_token" so a future jwx update with a
// new error category degrades gracefully instead of leaking details.
func classifyAppleVerifyError(err error) string {
	if err == nil {
		return "invalid_token"
	}
	msg := err.Error()
	switch {
	case containsAny(msg, "exp not satisfied", `"exp" not satisfied`, "token is expired"):
		return "expired_token"
	case containsAny(msg, "iss not satisfied", `"iss" not satisfied`):
		return "issuer_mismatch"
	case containsAny(msg, "aud not satisfied", `"aud" not satisfied`):
		return "invalid_audience"
	}
	return "invalid_token"
}

func containsAny(s string, needles ...string) bool {
	for _, n := range needles {
		if strings.Contains(s, n) {
			return true
		}
	}
	return false
}
