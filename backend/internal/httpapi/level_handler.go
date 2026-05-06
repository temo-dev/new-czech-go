package httpapi

// level_handler.go — V21 GET /v1/users/me/level-progress.
//
// Server-authoritative gating state for the home screen. Reads V19 mastery
// rows + V21 user-level + promotion-attempts state via processing.LevelService
// and returns the LevelProgressResponse the Flutter client renders. The
// client never recomputes promotion_unlocked / all_skills_pass — those are
// always derived here.

import (
	"net/http"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/processing"
)

// LevelDeps bundles the V21 gating service so callers can wire the handler
// from either the V17 auth bootstrap path or the legacy dev-fixture path
// (mirrors MasteryDeps for V19). Only Service is required; everything else
// the service needs is closed over inside the *processing.LevelService.
type LevelDeps struct {
	Service *processing.LevelService
}

// SetLevelDeps wires the V21 level gating service. The level-progress route
// is only registered when Service is non-nil; passing nil disables the
// feature and the route returns 404.
func (s *Server) SetLevelDeps(d LevelDeps) {
	s.levelService = d.Service
}

func (s *Server) handleUserLevelProgress(w http.ResponseWriter, r *http.Request, user contracts.User) {
	if r.Method != http.MethodGet {
		writeMethodNotAllowed(w)
		return
	}
	if s.levelService == nil {
		writeError(w, http.StatusNotFound, "feature_disabled",
			"Level progression is not enabled on this server.", false)
		return
	}
	progress, err := s.levelService.ComputeLevelProgress(user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", err.Error(), false)
		return
	}
	// Gating state must always be fresh — never let intermediaries (CDN,
	// Flutter http_cache, etc.) serve a stale unlock state.
	w.Header().Set("Cache-Control", "no-store")
	writeJSON(w, http.StatusOK, map[string]any{
		"data": progress,
		"meta": map[string]any{},
	})
}
