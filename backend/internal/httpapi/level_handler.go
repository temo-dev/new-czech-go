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
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

// LevelDeps bundles the V21 gating dependencies so callers can wire the
// handlers from either the V17 auth bootstrap path or the legacy
// dev-fixture path (mirrors MasteryDeps for V19). Only Service is required
// for the read-only level-progress endpoint; mutation handlers (placement,
// promotion) additionally require UserLevels and/or PromoAttempts.
type LevelDeps struct {
	Service       *processing.LevelService
	UserLevels    store.UserLevelStore
	PromoAttempts store.PromotionAttemptsStore
}

// SetLevelDeps wires the V21 level gating service + stores. Endpoints that
// require a missing dependency return 404 feature_disabled.
//
// Side-effect: when Service is non-nil, we install a default
// PromotionTestForLevel resolver that looks up the latest published
// promotion MockTest for a given target level (V21 review I5). The
// resolver lives on the Server so it can read s.repo at request time
// rather than capturing a snapshot at boot.
func (s *Server) SetLevelDeps(d LevelDeps) {
	s.levelService = d.Service
	s.userLevelStore = d.UserLevels
	s.promoAttemptsStore = d.PromoAttempts
	if s.placementRL == nil {
		s.placementRL = newPlacementRateLimiter()
	}
	if d.Service != nil && d.Service.PromotionTestForLevel == nil {
		d.Service.PromotionTestForLevel = func(targetLevel string) (string, bool) {
			mock, ok := s.repo.LatestPromotionMockTest(targetLevel)
			if !ok {
				return "", false
			}
			return mock.ID, true
		}
	}
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
