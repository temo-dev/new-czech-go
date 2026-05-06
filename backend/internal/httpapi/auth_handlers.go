package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"net/mail"
	"strings"
	"time"
	"unicode/utf8"

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
	SkillMastery  store.SkillMasteryStore // V19 — nil disables /v1/users/me/progress
	EmailSender   email.Sender
	AppleVerifier AppleVerifier
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
	if d.SkillMastery != nil {
		s.SetMasteryDeps(d.SkillMastery, processing.LoadMasteryConfig())
		s.processor.WithMasteryUpdater(processing.NewMasteryUpdater(d.SkillMastery, s.masteryConfig, nil))
	}
	s.emailSender = d.EmailSender
	s.appleVerifier = d.AppleVerifier
	s.authBaseURL = strings.TrimRight(d.BaseURL, "/")
	s.authVerifyTTL = d.VerifyTTL
	if s.authVerifyTTL == 0 {
		s.authVerifyTTL = 24 * time.Hour
	}
	if s.loginRL == nil {
		s.loginRL = newLoginRateLimiter()
	}
	if s.signupRL == nil {
		s.signupRL = newSignupRateLimiter()
	}
	if s.resendCooldown == nil {
		s.resendCooldown = newResendCooldownTracker()
	}
	s.ensureIAPDefaults()
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
	s.mux.HandleFunc("/v1/auth/logout", s.handleLogout)
	s.mux.HandleFunc("/v1/auth/verify-email", s.handleVerifyEmail)
	s.mux.HandleFunc("/v1/auth/resend-verify", s.handleResendVerify)
	s.mux.HandleFunc("/v1/auth/forgot-password", s.handleForgotPassword)
	s.mux.HandleFunc("/v1/auth/reset-password", s.handleResetPassword)
	s.mux.HandleFunc("/v1/auth/change-password", s.handleChangePassword)

	s.mux.HandleFunc("/v1/users/me", s.handleUsersMe)
	s.mux.HandleFunc("/v1/users/me/avatar", s.handleUsersMeAvatar)
	s.mux.HandleFunc("/v1/users/me/email-change", s.handleEmailChange)

	s.registerIAPRoutes()
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

	// Per-IP signup rate limit (10/hour) — cheapest mitigation for an
	// attacker harvesting SES quota by registering throwaway accounts.
	if s.signupRL != nil && !s.signupRL.Allow(clientIP(r)) {
		writeAuthError(w, http.StatusTooManyRequests, "too_many_signups",
			"too many signups from this address; try again later")
		return
	}

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
			log.Printf("signup: send verify email to %s: %v", redactEmail(u.Email), err)
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

	// Legacy path takes precedence so the existing CMS admin login + the
	// dev-fixture learner credentials (learner@example.com/demo123) keep
	// working when V17 deps are wired. The legacy MemoryStore.Login
	// returns the random session token + user; we emit both the V17
	// shape (`session_token`) AND the legacy shape (`data.access_token`)
	// so existing smoke scripts that read `data.access_token` keep
	// passing without code changes.
	if token, user, ok := s.repo.Login(req.Email, req.Password); ok {
		if s.loginRL != nil {
			s.loginRL.Reset(req.Email)
		}
		userBlock := map[string]any{
			"id":           user.ID,
			"email":        user.Email,
			"role":         user.Role,
			"display_name": user.DisplayName,
		}
		writeJSON(w, http.StatusOK, map[string]any{
			"user":          userBlock,
			"session_token": token,
			"data": map[string]any{
				"access_token": token,
				"user":         userBlock,
			},
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

// ── POST /v1/auth/logout ─────────────────────────────────────────────────

// handleLogout revokes the current session token. Returns 204 on success;
// 401 if the bearer token is missing or invalid (idempotent re-logout
// after the session is gone hits 401 — that's fine, the client treats
// either response as "session is dead").
//
// Spec: docs/specs/self-serve-learner-spec.md §4.3
func (s *Server) handleLogout(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}
	rawToken, ok := bearerToken(r)
	if !ok {
		writeAuthError(w, http.StatusUnauthorized, "missing_token", "missing bearer token")
		return
	}
	hash := auth.HashToken(rawToken)
	if !s.authTokenStore.RevokeAuthToken(hash) {
		// Either unknown or already revoked — both look the same to the
		// client, mirroring the rest of the auth surface that does not
		// leak existence.
		writeAuthError(w, http.StatusUnauthorized, "invalid_token", "session is not active")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ── GET /v1/auth/verify-email ────────────────────────────────────────────

// handleVerifyEmail consumes a verify-email token. The link comes from
// the email body, so the response is HTML (small confirmation page that
// also redirects via a meta-refresh to the app deep link). The token is
// revoked on success so it cannot be replayed; the user's
// EmailVerifiedAt is set and grace_attempts_left is lifted to the
// effective-infinity ceiling.
//
// Spec: docs/specs/self-serve-learner-spec.md §4.4
func (s *Server) handleVerifyEmail(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeMethodNotAllowed(w)
		return
	}
	raw := strings.TrimSpace(r.URL.Query().Get("token"))
	if raw == "" {
		writeVerifyHTML(w, http.StatusBadRequest, "Link không hợp lệ. Hãy yêu cầu gửi lại email xác minh.")
		return
	}
	hash := auth.HashToken(raw)
	tok, ok := s.authTokenStore.AuthTokenByHash(hash)
	if !ok || tok.Kind != contracts.AuthTokenKindEmailVerify {
		writeVerifyHTML(w, http.StatusBadRequest, "Link đã hết hạn hoặc không còn hiệu lực. Mở app và yêu cầu gửi lại.")
		return
	}
	if !s.userStore.MarkUserEmailVerified(tok.UserID) {
		writeVerifyHTML(w, http.StatusInternalServerError, "Không cập nhật được trạng thái xác minh. Liên hệ hỗ trợ.")
		return
	}
	// One-shot — revoke so the link cannot be replayed.
	s.authTokenStore.RevokeAuthToken(hash)
	writeVerifyHTML(w, http.StatusOK,
		"Đã xác minh email thành công. Quay lại app để tiếp tục.")
}

// writeVerifyHTML renders a minimal confirmation page. The deep link
// `czechgo://verified` triggers a return to the Flutter app on devices
// where the URL scheme is registered; on a desktop browser the meta
// refresh is harmless because the scheme is unknown there and the
// fallback paragraph is what the user reads.
func writeVerifyHTML(w http.ResponseWriter, status int, message string) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(status)
	tpl := `<!doctype html>
<html lang="vi">
<head>
  <meta charset="utf-8">
  <meta http-equiv="refresh" content="2; url=czechgo://verified">
  <title>Czech Go — Xác minh email</title>
  <style>
    body{font-family:Inter,system-ui,sans-serif;background:#FBF3E7;color:#14110C;margin:0;padding:48px 16px;text-align:center;}
    .card{background:#FFFFFF;border-radius:16px;padding:32px;max-width:480px;margin:0 auto;box-shadow:0 4px 24px rgba(20,17,12,.06);}
    h1{color:#0F3D3A;margin:0 0 16px 0;font-size:22px;}
    p{margin:0 0 12px 0;line-height:1.6;}
    a.btn{display:inline-block;margin-top:16px;padding:14px 28px;background:#FF6A14;color:#fff;text-decoration:none;border-radius:12px;font-weight:600;}
  </style>
</head>
<body>
  <div class="card">
    <h1>Czech Go</h1>
    <p>` + htmlEscape(message) + `</p>
    <a class="btn" href="czechgo://verified">Mở app</a>
  </div>
</body>
</html>`
	_, _ = w.Write([]byte(tpl))
}

// ── POST /v1/auth/resend-verify ──────────────────────────────────────────

// handleResendVerify issues a fresh verify-email token, revokes the
// learner's previous pending verify tokens, and dispatches a new email.
// Cooldown 60s per user, enforced via resendCooldownTracker.
//
// Spec: docs/specs/self-serve-learner-spec.md §4.5
func (s *Server) handleResendVerify(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}

	user, ok := s.requireV17User(r)
	if !ok {
		writeAuthError(w, http.StatusUnauthorized, "missing_token", "authentication required")
		return
	}
	if user.IsEmailVerified() {
		// Already verified — nothing to send. 200 + no-op so the client
		// can call this idempotently after a deep link without a
		// confusing error.
		w.WriteHeader(http.StatusNoContent)
		return
	}

	if allowed, retryAfter := s.resendCooldown.Allow(user.ID); !allowed {
		w.Header().Set("Retry-After", fmt.Sprintf("%d", int(retryAfter.Seconds())+1))
		writeAuthError(w, http.StatusTooManyRequests, "cooldown",
			fmt.Sprintf("please wait %d more seconds before resending", int(retryAfter.Seconds())+1))
		return
	}

	// Invalidate any earlier pending verify tokens so only the freshest
	// link works. Spec mandates this so a stolen old link cannot be
	// replayed if the learner forwards their inbox by accident.
	s.authTokenStore.RevokeAllAuthTokensByKind(user.ID, contracts.AuthTokenKindEmailVerify)

	verifyRaw, _, err := s.issueAuthToken(user.ID, contracts.AuthTokenKindEmailVerify, s.authVerifyTTL, r)
	if err != nil {
		log.Printf("resend-verify: issue token: %v", err)
		writeAuthError(w, http.StatusInternalServerError, "internal", "could not issue token")
		return
	}
	s.dispatchVerifyEmail(user, verifyRaw)
	s.resendCooldown.MarkSent(user.ID)
	w.WriteHeader(http.StatusNoContent)
}

// requireV17User pulls the bearer token, looks it up in the V17
// auth_tokens store, and resolves the owning UserAccount. Until the
// withAuth middleware is swapped in A2.7, V17 handlers call this helper
// directly.
func (s *Server) requireV17User(r *http.Request) (contracts.UserAccount, bool) {
	rawToken, ok := bearerToken(r)
	if !ok {
		return contracts.UserAccount{}, false
	}
	tok, ok := s.authTokenStore.AuthTokenByHash(auth.HashToken(rawToken))
	if !ok || tok.Kind != contracts.AuthTokenKindSession {
		return contracts.UserAccount{}, false
	}
	user, ok := s.userStore.UserAccountByID(tok.UserID)
	if !ok {
		return contracts.UserAccount{}, false
	}
	return user, true
}

// ── POST /v1/auth/forgot-password ────────────────────────────────────────

type forgotPasswordRequest struct {
	Email string `json:"email"`
}

// handleForgotPassword issues a one-shot password-reset token and sends
// the reset email. To avoid leaking which addresses are registered the
// endpoint ALWAYS returns 200 — whether the email matches a real user
// or not — and only dispatches when a user is found.
//
// Spec: docs/specs/self-serve-learner-spec.md §4.6
func (s *Server) handleForgotPassword(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, 4096)

	var req forgotPasswordRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAuthError(w, http.StatusBadRequest, "invalid_body", "request body is not valid JSON")
		return
	}
	emailAddr := strings.TrimSpace(req.Email)
	// Always succeed — even on garbage input — so timing + status do not
	// leak existence. The 400 path above is the only signal a malformed
	// REQUEST gets, never a missing USER.
	if user, ok := s.userStore.UserAccountByEmail(emailAddr); ok && emailAddr != "" {
		// Revoke any earlier resets so only the freshest link works.
		s.authTokenStore.RevokeAllAuthTokensByKind(user.ID, contracts.AuthTokenKindPasswordReset)
		raw, _, err := s.issueAuthToken(user.ID, contracts.AuthTokenKindPasswordReset, time.Hour, r)
		if err != nil {
			log.Printf("forgot-password: issue token: %v", err)
		} else {
			s.dispatchPasswordResetEmail(user, raw)
		}
	}
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(`{"status":"ok"}`))
}

func (s *Server) dispatchPasswordResetEmail(u contracts.UserAccount, rawToken string) {
	if s.emailSender == nil {
		return
	}
	link := s.authBaseURL + "/v1/auth/reset-password?token=" + rawToken
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
		defer cancel()
		err := email.SendPasswordResetEmail(ctx, s.emailSender, u.Email, email.PasswordResetEmailData{
			DisplayName: displayNameOrFallback(u),
			ResetURL:    link,
			ExpiresMin:  60,
		})
		if err != nil {
			log.Printf("forgot-password: send reset email to %s: %v", redactEmail(u.Email), err)
		}
	}()
}

func (s *Server) dispatchPasswordChangedEmail(u contracts.UserAccount) {
	if s.emailSender == nil {
		return
	}
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
		defer cancel()
		err := email.SendPasswordChangedEmail(ctx, s.emailSender, u.Email, email.PasswordChangedEmailData{
			DisplayName: displayNameOrFallback(u),
			ChangedAt:   time.Now().UTC().Format("2006-01-02 15:04 MST"),
		})
		if err != nil {
			log.Printf("password-changed: send notification to %s: %v", redactEmail(u.Email), err)
		}
	}()
}

// ── POST /v1/auth/reset-password ─────────────────────────────────────────

type resetPasswordRequest struct {
	Token       string `json:"token"`
	NewPassword string `json:"new_password"`
}

// handleResetPassword consumes the one-shot reset token, replaces the
// password hash, revokes the token, and revokes ALL the user's session
// tokens — every device must re-login after a reset, that's the spec.
// A change-notification email is dispatched async.
//
// Spec: docs/specs/self-serve-learner-spec.md §4.7
func (s *Server) handleResetPassword(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, 4096)

	var req resetPasswordRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAuthError(w, http.StatusBadRequest, "invalid_body", "request body is not valid JSON")
		return
	}
	if req.Token == "" {
		writeAuthError(w, http.StatusBadRequest, "invalid_token", "missing reset token")
		return
	}

	// Token lookup BEFORE password validation. Reverse-order
	// throughput attack: invalid tokens are cheap to reject (indexed
	// sha256 lookup), so an attacker spamming bogus tokens with
	// strong passwords does not get to do password-policy work
	// (cheap but more than a hash compare) on every request. Order
	// also matches the spec wording: "the reset token is the
	// authority".
	tok, ok := s.authTokenStore.AuthTokenByHash(auth.HashToken(req.Token))
	if !ok || tok.Kind != contracts.AuthTokenKindPasswordReset {
		writeAuthError(w, http.StatusBadRequest, "invalid_token", "reset token is invalid or expired")
		return
	}

	if err := auth.ValidatePassword(req.NewPassword); err != nil {
		writeAuthError(w, http.StatusBadRequest, passwordErrorCode(err), err.Error())
		return
	}

	user, ok := s.userStore.UserAccountByID(tok.UserID)
	if !ok {
		writeAuthError(w, http.StatusBadRequest, "invalid_token", "reset token references a missing account")
		return
	}

	hashed, err := auth.HashPassword(req.NewPassword)
	if err != nil {
		log.Printf("reset-password: hash: %v", err)
		writeAuthError(w, http.StatusInternalServerError, "internal", "could not process password")
		return
	}
	if _, ok := s.userStore.UpdateUser(user.ID, func(u *contracts.UserAccount) {
		u.PasswordHash = hashed
	}); !ok {
		writeAuthError(w, http.StatusInternalServerError, "internal", "could not update password")
		return
	}

	// Single-use: kill the reset token immediately.
	s.authTokenStore.RevokeAuthToken(auth.HashToken(req.Token))
	// Force every device to re-login.
	s.authTokenStore.RevokeAllAuthTokensByKind(user.ID, contracts.AuthTokenKindSession)
	// Reset login rate-limit so the learner can immediately log in again.
	if s.loginRL != nil {
		s.loginRL.Reset(user.Email)
	}

	updated, _ := s.userStore.UserAccountByID(user.ID)
	s.dispatchPasswordChangedEmail(updated)

	w.WriteHeader(http.StatusNoContent)
}

// ── POST /v1/auth/change-password ────────────────────────────────────────

type changePasswordRequest struct {
	CurrentPassword string `json:"current_password"`
	NewPassword     string `json:"new_password"`
}

// handleChangePassword requires the current password (defense in depth
// against session-hijack), updates the hash, revokes the user's OTHER
// session tokens — the current session keeps working so the client does
// not have to re-login — and dispatches the change-notification email.
//
// Spec: docs/specs/self-serve-learner-spec.md §4.8
func (s *Server) handleChangePassword(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, 4096)

	user, ok := s.requireV17User(r)
	if !ok {
		writeAuthError(w, http.StatusUnauthorized, "missing_token", "authentication required")
		return
	}

	var req changePasswordRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAuthError(w, http.StatusBadRequest, "invalid_body", "request body is not valid JSON")
		return
	}
	if !auth.VerifyPassword(user.PasswordHash, req.CurrentPassword) {
		writeAuthError(w, http.StatusUnauthorized, "invalid_current_password",
			"current password is incorrect")
		return
	}
	if err := auth.ValidatePassword(req.NewPassword); err != nil {
		writeAuthError(w, http.StatusBadRequest, passwordErrorCode(err), err.Error())
		return
	}

	hashed, err := auth.HashPassword(req.NewPassword)
	if err != nil {
		log.Printf("change-password: hash: %v", err)
		writeAuthError(w, http.StatusInternalServerError, "internal", "could not process password")
		return
	}
	if _, ok := s.userStore.UpdateUser(user.ID, func(u *contracts.UserAccount) {
		u.PasswordHash = hashed
	}); !ok {
		writeAuthError(w, http.StatusInternalServerError, "internal", "could not update password")
		return
	}

	// V17 simplification: revoke EVERY session including the current
	// one. The current device will get a 401 on its next request and
	// the AuthService logout-on-401 path routes the learner back to
	// Welcome — that's mildly worse UX than "stay signed in here, log
	// out everywhere else", but it avoids a per-user-list method on
	// AuthTokenStore that V17 would otherwise be the only consumer of.
	// V18 can refine this once the store grows its per-user iteration.
	_ = s.authTokenStore.RevokeAllAuthTokensByKind(user.ID, contracts.AuthTokenKindSession)

	updated, _ := s.userStore.UserAccountByID(user.ID)
	s.dispatchPasswordChangedEmail(updated)

	w.WriteHeader(http.StatusNoContent)
}

// ── /v1/users/me — GET / PATCH / DELETE ──────────────────────────────────

// handleUsersMe dispatches the three verbs the spec defines for /users/me
// onto the same handler so we share auth resolution + error envelope.
func (s *Server) handleUsersMe(w http.ResponseWriter, r *http.Request) {
	user, ok := s.requireV17User(r)
	if !ok {
		writeAuthError(w, http.StatusUnauthorized, "missing_token", "authentication required")
		return
	}
	switch r.Method {
	case http.MethodGet:
		s.serveGetMe(w, r, user)
	case http.MethodPatch:
		s.servePatchMe(w, r, user)
	case http.MethodDelete:
		s.serveDeleteMe(w, r, user)
	default:
		writeMethodNotAllowed(w)
	}
}

type meResponse struct {
	User       meUser     `json:"user"`
	Streak     meStreak   `json:"streak"`
	UsageToday meUsage    `json:"usage_today"`
	Pro        meProState `json:"pro"`
}

type meUser struct {
	ID                string `json:"id"`
	Email             string `json:"email"`
	EmailVerified     bool   `json:"email_verified"`
	DisplayName       string `json:"display_name"`
	AvatarAssetID     string `json:"avatar_asset_id,omitempty"`
	Role              string `json:"role"`
	ProTier           string `json:"pro_tier"`
	OnboardingGoal    string `json:"onboarding_goal,omitempty"`
	OnboardingLevel   string `json:"onboarding_level,omitempty"`
	DailyReminderAt   string `json:"daily_reminder_at,omitempty"`
	PushTokenPlatform string `json:"push_token_platform,omitempty"`
	Timezone          string `json:"timezone"`
	GraceAttemptsLeft int    `json:"grace_attempts_left"`
}

type meStreak struct {
	CurrentDays            int    `json:"current_days"`
	LongestDays            int    `json:"longest_days"`
	LastCompletedDay       string `json:"last_completed_day,omitempty"`
	GracePassesLeftThisWk  int    `json:"grace_passes_left_this_week"`
}

type meUsage struct {
	Attempts        int `json:"attempts"`
	AttemptsLimit   int `json:"attempts_limit"`
	Interviews      int `json:"interviews_this_week"`
	InterviewsLimit int `json:"interviews_limit"`
}

type meProState struct {
	Active    bool   `json:"active"`
	ProductID string `json:"product_id,omitempty"`
}

// gracePassesPerWeek is the cap surfaced to Pro learners. Free learners
// see 0; the actual limit is enforced in the IAP/streak handlers, but
// the response carries the remaining count for the UI.
const gracePassesPerWeek = 1

// serveGetMe assembles the user + streak + usage + pro snapshot. Streak
// and usage stores are optional in V17 (memory-only deployments may omit
// them) so the handler degrades gracefully.
func (s *Server) serveGetMe(w http.ResponseWriter, _ *http.Request, user contracts.UserAccount) {
	now := time.Now().UTC()

	resp := meResponse{
		User: toMeUser(user),
		Pro: meProState{
			Active: user.IsPro(now),
		},
	}

	if s.streakStore != nil {
		summary, err := s.streakStore.StreakSummary(user.ID, now)
		if err == nil {
			resp.Streak = meStreak{
				CurrentDays: summary.Current,
				LongestDays: summary.Longest,
			}
			if !summary.LastCompletedDay.IsZero() {
				resp.Streak.LastCompletedDay = summary.LastCompletedDay.Format("2006-01-02")
			}
			left := gracePassesPerWeek - summary.GracePassesUsedThisWeek
			if left < 0 {
				left = 0
			}
			resp.Streak.GracePassesLeftThisWk = left
		}
	}

	resp.UsageToday.AttemptsLimit = freeTierAttemptsPerDay
	resp.UsageToday.InterviewsLimit = freeTierInterviewsPerWeek
	if s.dailyUsageStore != nil {
		usage, _ := s.dailyUsageStore.DailyUsageByUserDay(user.ID, now)
		resp.UsageToday.Attempts = usage.AttemptsCount
		resp.UsageToday.Interviews = usage.InterviewsCount
	}

	if s.proPurchaseStore != nil {
		if p, ok := s.proPurchaseStore.ActiveProPurchaseByUser(user.ID); ok {
			resp.Pro.ProductID = p.ProductID
		}
	}

	writeJSON(w, http.StatusOK, resp)
}

// freeTierAttemptsPerDay / freeTierInterviewsPerWeek are surfaced in
// /v1/users/me so the client can render a quota indicator without a
// second round-trip. The actual enforcement lives in the V17 phase A3
// middleware.
const (
	freeTierAttemptsPerDay    = 7
	freeTierInterviewsPerWeek = 1
)

func toMeUser(u contracts.UserAccount) meUser {
	return meUser{
		ID:                u.ID,
		Email:             u.Email,
		EmailVerified:     u.IsEmailVerified(),
		DisplayName:       u.DisplayName,
		AvatarAssetID:     u.AvatarAssetID,
		Role:              u.Role,
		ProTier:           u.ProTier,
		OnboardingGoal:    u.OnboardingGoal,
		OnboardingLevel:   u.OnboardingLevel,
		DailyReminderAt:   u.DailyReminderAt,
		PushTokenPlatform: u.PushTokenPlatform,
		Timezone:          u.Timezone,
		GraceAttemptsLeft: u.GraceAttemptsLeft,
	}
}

// patchMeRequest enumerates the only fields a learner is allowed to
// change on themselves. Email goes through /email-change; password
// through /change-password; ProTier is server-set via IAP. Everything
// else is pure preference data.
type patchMeRequest struct {
	DisplayName       *string `json:"display_name,omitempty"`
	AvatarAssetID     *string `json:"avatar_asset_id,omitempty"`
	OnboardingGoal    *string `json:"onboarding_goal,omitempty"`
	OnboardingLevel   *string `json:"onboarding_level,omitempty"`
	DailyReminderAt   *string `json:"daily_reminder_at,omitempty"`
	PushToken         *string `json:"push_token,omitempty"`
	PushTokenPlatform *string `json:"push_token_platform,omitempty"`
	Timezone          *string `json:"timezone,omitempty"`
}

func (s *Server) servePatchMe(w http.ResponseWriter, r *http.Request, user contracts.UserAccount) {
	r.Body = http.MaxBytesReader(w, r.Body, 4096)
	var req patchMeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAuthError(w, http.StatusBadRequest, "invalid_body", "request body is not valid JSON")
		return
	}

	if req.DisplayName != nil {
		trimmed := strings.TrimSpace(*req.DisplayName)
		if rc := utf8.RuneCountInString(trimmed); rc > 60 {
			writeAuthError(w, http.StatusBadRequest, "display_name_too_long",
				"display name must be 60 characters or fewer")
			return
		}
	}

	updated, ok := s.userStore.UpdateUser(user.ID, func(u *contracts.UserAccount) {
		if req.DisplayName != nil {
			u.DisplayName = strings.TrimSpace(*req.DisplayName)
		}
		if req.AvatarAssetID != nil {
			u.AvatarAssetID = strings.TrimSpace(*req.AvatarAssetID)
		}
		if req.OnboardingGoal != nil {
			u.OnboardingGoal = strings.TrimSpace(*req.OnboardingGoal)
		}
		if req.OnboardingLevel != nil {
			u.OnboardingLevel = strings.TrimSpace(*req.OnboardingLevel)
		}
		if req.DailyReminderAt != nil {
			u.DailyReminderAt = strings.TrimSpace(*req.DailyReminderAt)
		}
		if req.PushToken != nil {
			u.PushToken = strings.TrimSpace(*req.PushToken)
		}
		if req.PushTokenPlatform != nil {
			u.PushTokenPlatform = strings.TrimSpace(*req.PushTokenPlatform)
		}
		if req.Timezone != nil {
			tz := strings.TrimSpace(*req.Timezone)
			if tz != "" {
				u.Timezone = tz
			}
		}
	})
	if !ok {
		writeAuthError(w, http.StatusInternalServerError, "internal", "could not update user")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"user": toMeUser(updated)})
}

// serveDeleteMe soft-deletes the user account: anonymizes the email,
// clears the push token, drops the display name, and revokes every
// session. The legal/contractual ID stays around so attempts.user_id
// references do not become dangling — V18 may add a hard-delete cron.
//
// App Store guideline 5.1.1(v): account deletion must be available
// in-app for any app that supports account creation. This satisfies
// that without losing the audit trail a learner's attempts represent.
func (s *Server) serveDeleteMe(w http.ResponseWriter, _ *http.Request, user contracts.UserAccount) {
	if _, ok := s.userStore.UpdateUser(user.ID, func(u *contracts.UserAccount) {
		u.Email = "deleted_" + u.ID + "@deleted.local"
		u.EmailNormalized = u.Email
		u.DisplayName = "(deleted)"
		u.AvatarAssetID = ""
		u.PushToken = ""
		u.PushTokenPlatform = ""
	}); !ok {
		writeAuthError(w, http.StatusInternalServerError, "internal", "could not anonymize")
		return
	}
	if !s.userStore.SoftDeleteUser(user.ID) {
		writeAuthError(w, http.StatusInternalServerError, "internal", "could not soft-delete")
		return
	}
	s.authTokenStore.RevokeAllAuthTokensForUser(user.ID)
	w.WriteHeader(http.StatusNoContent)
}

// ── POST /v1/users/me/email-change ───────────────────────────────────────

type emailChangeRequest struct {
	NewEmail        string `json:"new_email"`
	CurrentPassword string `json:"current_password"`
}

// handleEmailChange swaps the account email after the learner reverifies
// their current password. The new address must not collide with another
// active account (case-insensitive). The flow updates the email field +
// resets EmailVerifiedAt, then dispatches a verify email to the new
// address.
//
// Spec: docs/specs/self-serve-learner-spec.md §4.13
func (s *Server) handleEmailChange(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, 4096)

	user, ok := s.requireV17User(r)
	if !ok {
		writeAuthError(w, http.StatusUnauthorized, "missing_token", "authentication required")
		return
	}
	var req emailChangeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAuthError(w, http.StatusBadRequest, "invalid_body", "request body is not valid JSON")
		return
	}
	req.NewEmail = strings.TrimSpace(req.NewEmail)
	if !looksLikeEmail(req.NewEmail) {
		writeAuthError(w, http.StatusBadRequest, "invalid_email", "new email is not in a valid format")
		return
	}
	if !auth.VerifyPassword(user.PasswordHash, req.CurrentPassword) {
		writeAuthError(w, http.StatusUnauthorized, "invalid_current_password",
			"current password is incorrect")
		return
	}

	// Reject collisions with another active account. Same-email-as-self
	// is a no-op success so the client can call this idempotently.
	normalized := strings.ToLower(req.NewEmail)
	if normalized == strings.ToLower(user.Email) {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	if existing, ok := s.userStore.UserAccountByEmail(req.NewEmail); ok && existing.ID != user.ID {
		writeAuthError(w, http.StatusConflict, "email_taken",
			"another account already uses that email")
		return
	}

	updated, ok := s.userStore.UpdateUser(user.ID, func(u *contracts.UserAccount) {
		u.Email = req.NewEmail
		u.EmailNormalized = normalized
		u.EmailVerifiedAt = nil
	})
	if !ok {
		writeAuthError(w, http.StatusInternalServerError, "internal", "could not update email")
		return
	}

	// Issue a fresh verify token and dispatch to the NEW address.
	s.authTokenStore.RevokeAllAuthTokensByKind(user.ID, contracts.AuthTokenKindEmailVerify)
	if raw, _, err := s.issueAuthToken(user.ID, contracts.AuthTokenKindEmailVerify, s.authVerifyTTL, r); err == nil {
		s.dispatchVerifyEmail(updated, raw)
	}

	w.WriteHeader(http.StatusNoContent)
}

// htmlEscape replaces the four characters that matter for the
// confirmation page so a future caller passing externally-controlled
// content cannot inject markup. The verify endpoint currently passes
// only constants, but constants drift.
func htmlEscape(s string) string {
	r := strings.NewReplacer(
		"&", "&amp;",
		"<", "&lt;",
		">", "&gt;",
		"\"", "&quot;",
	)
	return r.Replace(s)
}

// bearerToken extracts the raw token from an "Authorization: Bearer ..."
// header. Returns "", false when the header is missing or malformed.
func bearerToken(r *http.Request) (string, bool) {
	v := strings.TrimSpace(r.Header.Get("Authorization"))
	if v == "" {
		return "", false
	}
	const prefix = "Bearer "
	if !strings.HasPrefix(v, prefix) {
		return "", false
	}
	tok := strings.TrimSpace(v[len(prefix):])
	if tok == "" {
		return "", false
	}
	return tok, true
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

// looksLikeEmail validates the address using the stdlib mail.ParseAddress
// parser. This is stricter than the previous hand-rolled check: it
// rejects display-name forms (`"Anh" <a@x>`), embedded whitespace, and
// most malformed inputs SES would otherwise bounce on. We additionally
// require the parser's normalized address to equal the input so a
// sneaky `<a@x>` does not slip through.
//
// Domain still must contain a dot — `name@local` is technically valid
// per RFC but not useful for sending mail in practice.
func looksLikeEmail(s string) bool {
	addr, err := mail.ParseAddress(s)
	if err != nil {
		return false
	}
	if addr.Address != s {
		return false
	}
	at := strings.IndexByte(s, '@')
	if at < 0 {
		return false
	}
	if !strings.Contains(s[at+1:], ".") {
		return false
	}
	return true
}

// redactEmail keeps logs useful for debugging without dumping the full
// learner email into log aggregation. "an@example.com" -> "a***@example.com".
func redactEmail(email string) string {
	at := strings.IndexByte(email, '@')
	if at <= 0 {
		return "***"
	}
	local := email[:at]
	domain := email[at+1:]
	if len(local) <= 1 {
		return local + "***@" + domain
	}
	return local[:1] + "***@" + domain
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
