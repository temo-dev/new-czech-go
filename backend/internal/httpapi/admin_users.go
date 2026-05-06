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
	GraceAttemptsLeft int        `json:"grace_attempts_left"`
	CreatedAt         time.Time  `json:"created_at"`
	UpdatedAt         time.Time  `json:"updated_at"`
	ProExpiresAt      *time.Time `json:"pro_expires_at,omitempty"`
}

func toAdminUserView(u contracts.UserAccount) adminUserView {
	return adminUserView{
		ID:                u.ID,
		Email:             u.Email,
		EmailVerified:     u.IsEmailVerified(),
		DisplayName:       u.DisplayName,
		Role:              u.Role,
		ProTier:           u.ProTier,
		GraceAttemptsLeft: u.GraceAttemptsLeft,
		CreatedAt:         u.CreatedAt,
		UpdatedAt:         u.UpdatedAt,
		ProExpiresAt:      u.ProExpiresAt,
	}
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
	views := make([]adminUserView, 0, len(users))
	for _, u := range users {
		views = append(views, toAdminUserView(u))
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
	// Sub-resource routing: /v1/admin/users/:id/reset-password
	if idx := strings.Index(rest, "/"); idx >= 0 {
		id := rest[:idx]
		sub := rest[idx+1:]
		switch sub {
		case "reset-password":
			s.handleAdminResetUserPassword(w, r, caller, id)
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
