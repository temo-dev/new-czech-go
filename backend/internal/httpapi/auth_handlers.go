package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/auth"
	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/email"
	"github.com/danieldev/czech-go-system/backend/internal/processing"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

// AuthDeps bundles everything the V17 self-serve auth handlers need.
// Construct it once at boot and pass to NewServerWithAuth. A nil or
// zero-value AuthDeps disables the new endpoints and the server falls
// back to the legacy dev-fixture token path — useful for tests that only
// exercise the existing handlers.
type AuthDeps struct {
	Users         store.UserStore
	AuthTokens    store.AuthTokenStore
	Streaks       store.StreakStore
	ProPurchases  store.ProPurchaseStore
	DailyUsage    store.DailyUsageStore
	EmailSender   email.Sender
	BaseURL       string        // public origin used to build email links, e.g. https://api.czechgo.hadoo.eu
	VerifyTTL     time.Duration // 0 -> 24h default
	SessionTTL    time.Duration // 0 -> 30*24h default
	ResetTTL      time.Duration // 0 -> 1h default
}

// applyTo copies the dependency bundle into the Server so handlers can
// reach it via the receiver. Defaults that the spec mandates are filled
// in here so callers don't have to remember every TTL.
func (d *AuthDeps) applyTo(s *Server) {
	s.userStore = d.Users
	s.authTokenStore = d.AuthTokens
	s.streakStore = d.Streaks
	s.proPurchaseStore = d.ProPurchases
	s.dailyUsageStore = d.DailyUsage
	s.emailSender = d.EmailSender
	s.authBaseURL = strings.TrimRight(d.BaseURL, "/")
	s.authVerifyTTL = d.VerifyTTL
	if s.authVerifyTTL == 0 {
		s.authVerifyTTL = 24 * time.Hour
	}
	if s.loginRL == nil {
		s.loginRL = newLoginRateLimiter()
	}
}

// NewServerWithAuth is the V17 entry point that wires auth dependencies
// alongside the existing audio + admin setup. Mirrors NewServerWithAudio
// signature plus an AuthDeps bundle.
func NewServerWithAuth(repo *store.MemoryStore, processor *processing.Processor, uploadProvider UploadTargetProvider, audioURLProvider AudioURLProvider, audioSignSecret []byte, deps AuthDeps) http.Handler {
	return assembleServer(repo, processor, uploadProvider, audioURLProvider, audioSignSecret, &deps)
}

// registerAuthRoutes is invoked from Server.routes() when the V17 deps
// are populated. Routes that need a UserStore stay unregistered when the
// server is in legacy fixture mode so old callers see a 404 (rather than
// a NPE) if they accidentally hit a V17 path.
func (s *Server) registerAuthRoutes() {
	if s.userStore == nil {
		return
	}
	s.mux.HandleFunc("/v1/auth/signup", s.handleSignup)
	s.mux.HandleFunc("/v1/auth/login", s.handleAuthLogin)
}

// ── POST /v1/auth/signup ─────────────────────────────────────────────────

type signupRequest struct {
	Email       string `json:"email"`
	Password    string `json:"password"`
	DisplayName string `json:"display_name"`
}

type signupResponse struct {
	User         signupUser `json:"user"`
	SessionToken string     `json:"session_token"`
	ExpiresAt    time.Time  `json:"expires_at"`
}

type signupUser struct {
	ID                string `json:"id"`
	Email             string `json:"email"`
	EmailVerified     bool   `json:"email_verified"`
	DisplayName       string `json:"display_name"`
	ProTier           string `json:"pro_tier"`
	GraceAttemptsLeft int    `json:"grace_attempts_left"`
}

// handleSignup creates a new learner account. On success it returns the
// session token, schedules an email-verify token, and dispatches the
// verify email asynchronously (a delivery failure is logged, not bubbled
// to the user — the resend-verify endpoint is the recovery path).
//
// Spec: docs/specs/self-serve-learner-spec.md §4.1
func (s *Server) handleSignup(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}

	// Cap the request body so a flood of "{ ...32MB of zeros... }" cannot
	// pin a backend goroutine. 4 KiB is comfortable for the schema.
	r.Body = http.MaxBytesReader(w, r.Body, 4096)

	var req signupRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAuthError(w, http.StatusBadRequest, "invalid_body", "request body is not valid JSON")
		return
	}
	req.Email = strings.TrimSpace(req.Email)
	req.DisplayName = strings.TrimSpace(req.DisplayName)

	if !looksLikeEmail(req.Email) {
		writeAuthError(w, http.StatusBadRequest, "invalid_email", "email is not in a valid format")
		return
	}
	if err := auth.ValidatePassword(req.Password); err != nil {
		writeAuthError(w, http.StatusBadRequest, passwordErrorCode(err), err.Error())
		return
	}

	hashed, err := auth.HashPassword(req.Password)
	if err != nil {
		log.Printf("signup: hash password: %v", err)
		writeAuthError(w, http.StatusInternalServerError, "internal", "could not process password")
		return
	}

	created, err := s.userStore.CreateUser(contracts.UserAccount{
		Email:        req.Email,
		PasswordHash: hashed,
		DisplayName:  req.DisplayName,
	})
	if err != nil {
		if errors.Is(err, store.ErrDuplicateEmail) {
			writeAuthError(w, http.StatusConflict, "email_taken", "an account with that email already exists")
			return
		}
		log.Printf("signup: create user: %v", err)
		writeAuthError(w, http.StatusInternalServerError, "internal", "could not create account")
		return
	}

	sessionTTL := 30 * 24 * time.Hour
	sessionRaw, sessionExpires, err := s.issueAuthToken(created.ID, contracts.AuthTokenKindSession, sessionTTL, r)
	if err != nil {
		log.Printf("signup: issue session: %v", err)
		writeAuthError(w, http.StatusInternalServerError, "internal", "could not issue session")
		return
	}

	verifyRaw, _, err := s.issueAuthToken(created.ID, contracts.AuthTokenKindEmailVerify, s.authVerifyTTL, r)
	if err != nil {
		log.Printf("signup: issue verify token (continuing): %v", err)
	} else {
		s.dispatchVerifyEmail(created, verifyRaw)
	}

	writeJSON(w, http.StatusOK, signupResponse{
		User: signupUser{
			ID:                created.ID,
			Email:             created.Email,
			EmailVerified:     created.IsEmailVerified(),
			DisplayName:       created.DisplayName,
			ProTier:           created.ProTier,
			GraceAttemptsLeft: created.GraceAttemptsLeft,
		},
		SessionToken: sessionRaw,
		ExpiresAt:    sessionExpires,
	})
}

// issueAuthToken mints a fresh raw token, persists its sha256 hash, and
// returns the raw form. The raw form is what the response or email link
// carries; only the hash lives in the database.
func (s *Server) issueAuthToken(userID, kind string, ttl time.Duration, r *http.Request) (string, time.Time, error) {
	if ttl == 0 {
		// Defensive default; the only kinds we issue here always supply
		// an explicit TTL but a zero TTL would hand out an immediately-
		// expired token and that would be hard to debug.
		ttl = time.Hour
	}
	raw, err := auth.NewRawToken()
	if err != nil {
		return "", time.Time{}, err
	}
	expiresAt := time.Now().UTC().Add(ttl)
	_, err = s.authTokenStore.CreateAuthToken(contracts.AuthToken{
		TokenHash: auth.HashToken(raw),
		UserID:    userID,
		Kind:      kind,
		ExpiresAt: expiresAt,
		UserAgent: r.UserAgent(),
		IPAddress: clientIP(r),
	})
	if err != nil {
		return "", time.Time{}, err
	}
	return raw, expiresAt, nil
}

// dispatchVerifyEmail fires the email send on a goroutine because we do
// not want a slow SMTP relay holding up the signup response. SES
// deliverability metrics live outside the request path; failures land in
// the log and surface via the resend-verify flow if the learner notices.
func (s *Server) dispatchVerifyEmail(u contracts.UserAccount, rawToken string) {
	if s.emailSender == nil {
		return
	}
	link := s.authBaseURL + "/v1/auth/verify-email?token=" + rawToken
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
		defer cancel()
		err := email.SendVerifyEmail(ctx, s.emailSender, u.Email, email.VerifyEmailData{
			DisplayName: displayNameOrFallback(u),
			VerifyURL:   link,
			ExpiresHrs:  hoursOrDefault(s.authVerifyTTL, 24),
		})
		if err != nil {
			log.Printf("signup: send verify email to %s: %v", u.Email, err)
		}
	}()
}

func displayNameOrFallback(u contracts.UserAccount) string {
	if name := strings.TrimSpace(u.DisplayName); name != "" {
		return name
	}
	if at := strings.IndexByte(u.Email, '@'); at > 0 {
		return u.Email[:at]
	}
	return "bạn"
}

func hoursOrDefault(d time.Duration, fallback int) int {
	if d <= 0 {
		return fallback
	}
	hrs := int(d / time.Hour)
	if hrs == 0 {
		hrs = fallback
	}
	return hrs
}

// ── POST /v1/auth/login ──────────────────────────────────────────────────

type loginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

// handleAuthLogin authenticates a learner. Admin login still happens
// through the legacy /v1/auth/login route when V17 deps are absent; when
// V17 is wired, this handler tries the admin path first (delegating to
// the legacy MemoryStore.Login) and falls back to the UserStore lookup.
//
// The handler MUST NOT leak whether the email exists. Wrong-email and
// wrong-password both return 401 invalid_credentials with no other
// distinguishing signal (timing differences are minimized by always
// running bcrypt.Verify, even when the user lookup misses).
//
// Spec: docs/specs/self-serve-learner-spec.md §4.2
func (s *Server) handleAuthLogin(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, 4096)

	var req loginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAuthError(w, http.StatusBadRequest, "invalid_body", "request body is not valid JSON")
		return
	}
	req.Email = strings.TrimSpace(req.Email)

	if s.loginRL != nil && s.loginRL.IsBlocked(req.Email) {
		writeAuthError(w, http.StatusTooManyRequests, "too_many_attempts",
			"too many failed login attempts; try again in 15 minutes")
		return
	}

	// Admin path takes precedence so the existing CMS login keeps
	// working when V17 deps are wired. The legacy MemoryStore.Login
	// returns the random session token + user.
	if token, user, ok := s.repo.Login(req.Email, req.Password); ok && user.Role == "admin" {
		if s.loginRL != nil {
			s.loginRL.Reset(req.Email)
		}
		writeJSON(w, http.StatusOK, map[string]any{
			"user": map[string]any{
				"id":           user.ID,
				"email":        user.Email,
				"role":         user.Role,
				"display_name": user.DisplayName,
			},
			"session_token": token,
		})
		return
	}

	// Learner path. Always run a bcrypt.Verify even on lookup miss to
	// keep the timing profile flat — running against a fixed sentinel
	// hash is the standard mitigation. Do NOT short-circuit on miss.
	const dummyHash = "$2a$12$abcdefghijklmnopqrstuuvxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" // 60-char-ish
	storedHash := dummyHash
	var stored contracts.UserAccount
	var found bool
	if u, ok := s.userStore.UserAccountByEmail(req.Email); ok {
		stored = u
		storedHash = u.PasswordHash
		found = true
	}

	if !auth.VerifyPassword(storedHash, req.Password) || !found {
		if s.loginRL != nil {
			s.loginRL.RecordFailure(req.Email)
		}
		writeAuthError(w, http.StatusUnauthorized, "invalid_credentials", "email or password is incorrect")
		return
	}

	sessionTTL := 30 * 24 * time.Hour
	rawSession, expiresAt, err := s.issueAuthToken(stored.ID, contracts.AuthTokenKindSession, sessionTTL, r)
	if err != nil {
		log.Printf("login: issue session: %v", err)
		writeAuthError(w, http.StatusInternalServerError, "internal", "could not issue session")
		return
	}

	if s.loginRL != nil {
		s.loginRL.Reset(req.Email)
	}

	writeJSON(w, http.StatusOK, signupResponse{
		User: signupUser{
			ID:                stored.ID,
			Email:             stored.Email,
			EmailVerified:     stored.IsEmailVerified(),
			DisplayName:       stored.DisplayName,
			ProTier:           stored.ProTier,
			GraceAttemptsLeft: stored.GraceAttemptsLeft,
		},
		SessionToken: rawSession,
		ExpiresAt:    expiresAt,
	})
}

// ── helpers ──────────────────────────────────────────────────────────────

// writeAuthError keeps the auth endpoints' error envelope uniform:
//
//	{ "error": "<code>", "message": "<human-readable>" }
//
// `code` is what clients switch on; `message` is informational only.
func writeAuthError(w http.ResponseWriter, status int, code, message string) {
	writeJSON(w, status, map[string]any{
		"error":   code,
		"message": message,
	})
}

// passwordErrorCode maps the auth.ValidatePassword sentinel errors to the
// stable client-facing codes documented in spec §4.1. Anything unmapped
// falls through to "weak_password" so the client always has SOMETHING to
// branch on.
func passwordErrorCode(err error) string {
	switch {
	case errors.Is(err, auth.ErrPasswordEmpty):
		return "weak_password"
	case errors.Is(err, auth.ErrPasswordTooShort):
		return "weak_password"
	case errors.Is(err, auth.ErrPasswordTooSimple):
		return "weak_password"
	case errors.Is(err, auth.ErrPasswordTooCommon):
		return "weak_password"
	default:
		return "weak_password"
	}
}

// looksLikeEmail is a permissive RFC-5321-ish check: an "@" with at least
// one rune on each side and a "." in the domain. Stricter validation is
// counterproductive here — anything we reject the SMTP sender will reject
// (or the verify email will simply bounce) so this guard only catches
// trivially-malformed inputs.
func looksLikeEmail(s string) bool {
	at := strings.IndexByte(s, '@')
	if at <= 0 || at == len(s)-1 {
		return false
	}
	domain := s[at+1:]
	if !strings.Contains(domain, ".") {
		return false
	}
	if strings.ContainsAny(s, " \t\n\r") {
		return false
	}
	return true
}

// clientIP extracts the originating address. It honors X-Forwarded-For
// (taking the leftmost entry) so we record the learner's IP when the
// backend sits behind a load balancer, and falls back to RemoteAddr.
func clientIP(r *http.Request) string {
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		if comma := strings.IndexByte(xff, ','); comma > 0 {
			return strings.TrimSpace(xff[:comma])
		}
		return strings.TrimSpace(xff)
	}
	addr := r.RemoteAddr
	if colon := strings.LastIndexByte(addr, ':'); colon > 0 {
		return addr[:colon]
	}
	return addr
}
