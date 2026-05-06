package httpapi

import (
	"net/http"
	"os"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// handleUsersMeAvatar dispatches POST (upload) and DELETE (clear) for the
// authenticated learner's avatar image. GET is intentionally not exposed
// here — the asset is served via /v1/media/file?key=... so a single learner-
// auth gate covers all media reads.
//
// Wrapped through withAuthAccount so the handler receives the resolved
// UserAccount (matches the rest of the /v1/users/me handlers).
func (s *Server) handleUsersMeAvatar(w http.ResponseWriter, r *http.Request) {
	user, ok := s.requireV17User(r)
	if !ok {
		writeAuthError(w, http.StatusUnauthorized, "missing_token", "authentication required")
		return
	}
	switch r.Method {
	case http.MethodPost:
		s.uploadItemImage(w, r, user.ID, "avatars",
			func(id string) string {
				if u, ok := s.userStore.UserAccountByID(id); ok {
					return u.AvatarAssetID
				}
				return ""
			},
			func(id, key string) bool {
				_, ok := s.userStore.UpdateUser(id, func(u *contracts.UserAccount) {
					u.AvatarAssetID = key
				})
				return ok
			},
		)
	case http.MethodDelete:
		if user.AvatarAssetID != "" {
			os.Remove(localExerciseAssetPath(user.AvatarAssetID))
		}
		if _, ok := s.userStore.UpdateUser(user.ID, func(u *contracts.UserAccount) {
			u.AvatarAssetID = ""
		}); !ok {
			writeError(w, http.StatusInternalServerError, "internal", "could not clear avatar", false)
			return
		}
		w.WriteHeader(http.StatusNoContent)
	default:
		writeMethodNotAllowed(w)
	}
}
