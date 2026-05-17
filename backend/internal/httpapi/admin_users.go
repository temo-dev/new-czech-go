package httpapi

import (
	"encoding/json"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/auth"
	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

// adminUserView is the admin-facing projection of a learner account. Password
// hashes + push tokens stay server-side; the CMS only needs identity + status
// fields to render the Users table.
type adminUserView struct {
	ID                string     `json:"id"`
	Email             string     `json:"email"`
	EmailVerified     bool       `json:"email_verified"`
	DisplayName       string     `json:"display_name"`
	Role              string     `json:"role"`
	ProTier           string     `json:"pro_tier"`
	CurrentLevel      string     `json:"current_level"`
	UnlockedLevels    []string   `json:"unlocked_levels"`
	GraceAttemptsLeft int        `json:"grace_attempts_left"`
	AttemptsToday     int        `json:"attempts_today"`
	AttemptsCap       int        `json:"attempts_cap"`
	CreatedAt         time.Time  `json:"created_at"`
	UpdatedAt         time.Time  `json:"updated_at"`
	ProExpiresAt      *time.Time `json:"pro_expires_at,omitempty"`
}

func toAdminUserView(u contracts.UserAccount, attemptsToday int, level contracts.UserLevel) adminUserView {
	if level.CurrentLevel == "" {
		level.CurrentLevel = "a0"
	}
	if len(level.UnlockedLevels) == 0 {
		level.UnlockedLevels = []string{"a0"}
	}
	return adminUserView{
		ID:                u.ID,
		Email:             u.Email,
		EmailVerified:     u.IsEmailVerified(),
		DisplayName:       u.DisplayName,
		Role:              u.Role,
		ProTier:           u.ProTier,
		CurrentLevel:      level.CurrentLevel,
		UnlockedLevels:    append([]string(nil), level.UnlockedLevels...),
		GraceAttemptsLeft: u.GraceAttemptsLeft,
		AttemptsToday:     attemptsToday,
		AttemptsCap:       freeTierAttemptsPerDay,
		CreatedAt:         u.CreatedAt,
		UpdatedAt:         u.UpdatedAt,
		ProExpiresAt:      u.ProExpiresAt,
	}
}

func (s *Server) adminUserLevelState(userID string) contracts.UserLevel {
	if s.userLevelStore != nil {
		level, _ := s.userLevelStore.GetUserLevel(userID)
		if level.CurrentLevel != "" || len(level.UnlockedLevels) > 0 {
			return level
		}
	}
	return contracts.UserLevel{
		UserID:         userID,
		CurrentLevel:   "a0",
		UnlockedLevels: []string{"a0"},
	}
}

func adminAttemptsToday(s *Server, userID string, now time.Time) int {
	if s.dailyUsageStore == nil {
		return 0
	}
	if usage, ok := s.dailyUsageStore.DailyUsageByUserDay(userID, now); ok {
		return usage.AttemptsCount
	}
	return 0
}

// handleAdminUsers serves GET /v1/admin/users. Returns paginated, optionally
// search-filtered list of active accounts. Requires V17 auth deps wired —
// otherwise userStore is nil and we 503 so the CMS surfaces the missing dep
// rather than an empty list.
func (s *Server) handleAdminUsers(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	if r.Method != http.MethodGet {
		writeMethodNotAllowed(w)
		return
	}
	if s.userStore == nil {
		writeError(w, http.StatusServiceUnavailable, "users_unavailable",
			"V17 user store is not wired on this backend", false)
		return
	}
	q := r.URL.Query()
	limit, _ := strconv.Atoi(q.Get("limit"))
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	offset, _ := strconv.Atoi(q.Get("offset"))
	if offset < 0 {
		offset = 0
	}

	users, total, err := s.userStore.ListUsers(store.ListUsersOptions{
		Limit:  limit,
		Offset: offset,
		Search: q.Get("search"),
		Role:   q.Get("role"),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, "list_failed", err.Error(), false)
		return
	}
	now := time.Now().UTC()
	views := make([]adminUserView, 0, len(users))
	for _, u := range users {
		views = append(views, toAdminUserView(u, adminAttemptsToday(s, u.ID, now), s.adminUserLevelState(u.ID)))
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"data": views,
		"meta": map[string]any{
			"total":  total,
			"limit":  limit,
			"offset": offset,
		},
	})
}

// handleAdminUserByID serves DELETE /v1/admin/users/:id. Soft-deletes the
// account: anonymises identity fields, revokes every active session, and
// flips deleted_at. Refuses to delete the calling admin (footgun guard) and
// other admin-role accounts (admins manage admins out-of-band).
func (s *Server) handleAdminUserByID(w http.ResponseWriter, r *http.Request, caller contracts.User) {
	if s.userStore == nil {
		writeError(w, http.StatusServiceUnavailable, "users_unavailable",
			"V17 user store is not wired on this backend", false)
		return
	}
	rest := strings.TrimPrefix(r.URL.Path, "/v1/admin/users/")
	rest = strings.TrimSuffix(rest, "/")
	if rest == "" {
		writeError(w, http.StatusBadRequest, "missing_id", "user id required", false)
		return
	}
	// Sub-resource routing: /v1/admin/users/:id/{reset-password,usage/reset,state}
	if idx := strings.Index(rest, "/"); idx >= 0 {
		id := rest[:idx]
		sub := rest[idx+1:]
		switch sub {
		case "reset-password":
			s.handleAdminResetUserPassword(w, r, caller, id)
		case "usage/reset":
			s.handleAdminResetUserUsage(w, r, id)
		case "state":
			s.handleAdminUserState(w, r, caller, id)
		case "pro":
			s.handleAdminSetUserPro(w, r, id)
		case "level":
			s.handleAdminSetUserLevel(w, r, id)
		default:
			writeNotFound(w)
		}
		return
	}
	id := rest
	switch r.Method {
	case http.MethodDelete:
		if id == caller.ID {
			writeError(w, http.StatusBadRequest, "self_delete_forbidden",
				"admin cannot delete their own account from this endpoint", false)
			return
		}
		target, ok := s.userStore.UserAccountByID(id)
		if !ok {
			writeNotFound(w)
			return
		}
		if target.Role == "admin" {
			writeError(w, http.StatusForbidden, "admin_delete_forbidden",
				"admin accounts cannot be deleted via this endpoint", false)
			return
		}
		if _, ok := s.userStore.UpdateUser(id, func(u *contracts.UserAccount) {
			u.Email = "deleted_" + u.ID + "@deleted.local"
			u.EmailNormalized = u.Email
			u.DisplayName = "(deleted)"
			u.AvatarAssetID = ""
			u.PushToken = ""
			u.PushTokenPlatform = ""
		}); !ok {
			writeError(w, http.StatusInternalServerError, "anonymize_failed",
				"could not anonymize user", false)
			return
		}
		if !s.userStore.SoftDeleteUser(id) {
			writeError(w, http.StatusInternalServerError, "delete_failed",
				"could not soft-delete user", false)
			return
		}
		if s.authTokenStore != nil {
			s.authTokenStore.RevokeAllAuthTokensForUser(id)
		}
		w.WriteHeader(http.StatusNoContent)
	default:
		writeMethodNotAllowed(w)
	}
}

type adminResetPasswordRequest struct {
	NewPassword string `json:"new_password"`
}

// handleAdminResetUserPassword serves POST /v1/admin/users/:id/reset-password.
// Admin sets a new password for the target learner directly. The new password
// must meet the same strength rules as self-serve resets. Every active session
// is revoked so the learner is forced to log in again with the new password.
//
// Refuses on admin-role targets so admins must rotate their own credentials
// out-of-band rather than through this CMS endpoint.
func (s *Server) handleAdminResetUserPassword(w http.ResponseWriter, r *http.Request, _ contracts.User, id string) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, 4096)
	var req adminResetPasswordRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_body", "request body is not valid JSON", false)
		return
	}
	if err := auth.ValidatePassword(req.NewPassword); err != nil {
		writeError(w, http.StatusBadRequest, passwordErrorCode(err), err.Error(), false)
		return
	}
	target, ok := s.userStore.UserAccountByID(id)
	if !ok {
		writeNotFound(w)
		return
	}
	if target.Role == "admin" {
		writeError(w, http.StatusForbidden, "admin_reset_forbidden",
			"admin password cannot be reset via this endpoint", false)
		return
	}
	hashed, err := auth.HashPassword(req.NewPassword)
	if err != nil {
		log.Printf("admin reset-password: hash: %v", err)
		writeError(w, http.StatusInternalServerError, "internal", "could not process password", false)
		return
	}
	if _, ok := s.userStore.UpdateUser(id, func(u *contracts.UserAccount) {
		u.PasswordHash = hashed
	}); !ok {
		writeError(w, http.StatusInternalServerError, "update_failed", "could not update password", false)
		return
	}
	if s.authTokenStore != nil {
		s.authTokenStore.RevokeAllAuthTokensByKind(id, contracts.AuthTokenKindSession)
	}
	if s.loginRL != nil {
		s.loginRL.Reset(target.Email)
	}
	w.WriteHeader(http.StatusNoContent)
}

// handleAdminResetUserUsage serves POST /v1/admin/users/:id/usage/reset.
// Clears the learner's attempts_count for today (VN civil day) so QA /
// support can unblock a learner who has hit the free-tier daily cap. The
// interview counter is left intact — interviews use a 7-day rolling
// window, not a daily reset.
func (s *Server) handleAdminResetUserUsage(w http.ResponseWriter, r *http.Request, id string) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}
	if s.dailyUsageStore == nil {
		writeError(w, http.StatusServiceUnavailable, "usage_unavailable",
			"daily usage store is not wired on this backend", false)
		return
	}
	if _, ok := s.userStore.UserAccountByID(id); !ok {
		writeNotFound(w)
		return
	}
	if err := s.dailyUsageStore.ResetAttempts(id, time.Now().UTC()); err != nil {
		log.Printf("admin reset usage: user_id=%s err=%v", id, err)
		writeError(w, http.StatusInternalServerError, "reset_failed",
			"could not reset usage", false)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type adminSetUserLevelRequest struct {
	CurrentLevel string `json:"current_level"`
}

func cefrLevelRank(level string) (int, bool) {
	switch level {
	case "a0":
		return 0, true
	case "a1":
		return 1, true
	case "a2":
		return 2, true
	case "b1":
		return 3, true
	default:
		return 0, false
	}
}

// handleAdminSetUserLevel serves POST /v1/admin/users/:id/level.
//
// Body: { "current_level": "a1" }
//
// This is a support/admin promotion lever for cases where placement or the
// promotion exam should be bypassed manually. It is intentionally monotonic:
// UserLevelStore.SetUserLevel appends to unlocked_levels, so this endpoint
// refuses downgrades instead of producing current_level=a1 with b1 still
// unlocked.
func (s *Server) handleAdminSetUserLevel(w http.ResponseWriter, r *http.Request, id string) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}
	if s.userLevelStore == nil {
		writeError(w, http.StatusServiceUnavailable, "level_store_unavailable",
			"V21 user level store is not wired on this backend", false)
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, 4096)
	var req adminSetUserLevelRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_body", "request body is not valid JSON", false)
		return
	}
	targetLevel := strings.ToLower(strings.TrimSpace(req.CurrentLevel))
	if _, ok := validCefrLevels[targetLevel]; !ok {
		writeError(w, http.StatusBadRequest, "invalid_level",
			"current_level must be one of a0, a1, a2, b1", false)
		return
	}

	target, ok := s.userStore.UserAccountByID(id)
	if !ok {
		writeNotFound(w)
		return
	}
	if target.Role == "admin" {
		writeError(w, http.StatusForbidden, "admin_level_forbidden",
			"admin accounts do not use learner CEFR progression", false)
		return
	}

	current := s.adminUserLevelState(id)
	currentRank, ok := cefrLevelRank(current.CurrentLevel)
	if !ok {
		currentRank = 0
	}
	targetRank, _ := cefrLevelRank(targetLevel)
	if targetRank < currentRank {
		writeError(w, http.StatusBadRequest, "level_downgrade_forbidden",
			"manual level changes can only keep or raise the learner level", false)
		return
	}

	updatedLevel, err := s.userLevelStore.SetUserLevel(id, targetLevel)
	if err != nil {
		log.Printf("admin set level: user_id=%s level=%s err=%v", id, targetLevel, err)
		writeError(w, http.StatusInternalServerError, "update_failed",
			"could not update learner level", false)
		return
	}
	now := time.Now().UTC()
	writeJSON(w, http.StatusOK, map[string]any{
		"data": toAdminUserView(target, adminAttemptsToday(s, id, now), updatedLevel),
		"meta": map[string]any{},
	})
}

// adminSetProRequest is the request body for the Pro grant/downgrade endpoint.
// DurationDays > 0 grants or extends Pro by that many days; DurationDays == 0
// downgrades the user to free.
type adminSetProRequest struct {
	DurationDays int `json:"duration_days"`
}

// proGrantMaxDays caps a single admin grant. Higher values usually indicate
// admin typos rather than a real intent to grant decade-long Pro.
const proGrantMaxDays = 3650 // ~10 years

// handleAdminSetUserPro serves POST /v1/admin/users/:id/pro.
//
// Body: { "duration_days": int }
//   - duration_days > 0: ProTier="pro", ProExpiresAt = max(now, current expiry
//     if still active) + duration_days*24h. Extending an already-Pro user adds
//     time on top of the remaining entitlement instead of overwriting from now.
//   - duration_days == 0: ProTier="free", ProExpiresAt=nil.
//
// Refuses admin targets (admins are managed out-of-band). Refuses negative or
// implausibly large values.
func (s *Server) handleAdminSetUserPro(w http.ResponseWriter, r *http.Request, id string) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}
	if s.userStore == nil {
		writeError(w, http.StatusServiceUnavailable, "users_unavailable",
			"V17 user store is not wired on this backend", false)
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, 4096)
	var req adminSetProRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_body", "request body is not valid JSON", false)
		return
	}
	if req.DurationDays < 0 {
		writeError(w, http.StatusBadRequest, "invalid_duration",
			"duration_days must be >= 0", false)
		return
	}
	if req.DurationDays > proGrantMaxDays {
		writeError(w, http.StatusBadRequest, "invalid_duration",
			"duration_days exceeds maximum grant length", false)
		return
	}

	target, ok := s.userStore.UserAccountByID(id)
	if !ok {
		writeNotFound(w)
		return
	}
	if target.Role == "admin" {
		writeError(w, http.StatusForbidden, "admin_pro_forbidden",
			"admin accounts do not use the Pro entitlement", false)
		return
	}

	now := time.Now().UTC()
	updated, ok := s.userStore.UpdateUser(id, func(u *contracts.UserAccount) {
		if req.DurationDays == 0 {
			u.ProTier = "free"
			u.ProExpiresAt = nil
			return
		}
		base := now
		if u.ProTier == "pro" && u.ProExpiresAt != nil && u.ProExpiresAt.After(now) {
			base = *u.ProExpiresAt
		}
		exp := base.Add(time.Duration(req.DurationDays) * 24 * time.Hour)
		u.ProTier = "pro"
		u.ProExpiresAt = &exp
	})
	if !ok {
		writeError(w, http.StatusInternalServerError, "update_failed",
			"could not update Pro entitlement", false)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"data": toAdminUserView(updated, adminAttemptsToday(s, updated.ID, now), s.adminUserLevelState(updated.ID)),
		"meta": map[string]any{},
	})
}
