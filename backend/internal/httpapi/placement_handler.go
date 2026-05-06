package httpapi

// placement_handler.go — V21 onboarding placement test endpoints.
//
// POST /v1/users/me/placement-test/start
//   Picks the latest is_placement=true MockTest, creates a mock_exam_session
//   for the caller, and returns the session id. 409 placement_already_taken
//   when the user has placed before and ?force=true is not set.
//
// POST /v1/users/me/placement-test/complete
//   Reads the session's overall_score (server-of-truth — the client cannot
//   submit a level directly), maps it via LevelService.MapPlacementScoreToLevel,
//   and persists current_level + placement_taken_at via UserLevelStore.
//   404 when the session is missing or owned by someone else.

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

func (s *Server) handlePlacementTestStart(w http.ResponseWriter, r *http.Request, user contracts.User) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}
	if s.levelService == nil || s.userLevelStore == nil {
		writeError(w, http.StatusNotFound, "feature_disabled",
			"Level progression is not enabled on this server.", false)
		return
	}

	force := r.URL.Query().Get("force") == "true"
	if !force {
		if existing, ok := s.userLevelStore.GetUserLevel(user.ID); ok && existing.PlacementTakenAt != nil {
			writeError(w, http.StatusConflict, "placement_already_taken",
				"You have already taken the placement test. Pass ?force=true to retry.", false)
			return
		}
	}

	mock, ok := s.repo.LatestPlacementMockTest()
	if !ok {
		writeError(w, http.StatusNotFound, "placement_not_configured",
			"No placement test is configured for this server.", false)
		return
	}

	session, err := s.repo.CreateMockExam(user.ID, mock.ID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]any{
			"error": map[string]any{"code": "placement_create_failed", "message": err.Error()},
		})
		return
	}

	writeJSON(w, http.StatusCreated, map[string]any{
		"data": map[string]any{
			"mock_test_id":    mock.ID,
			"full_session_id": session.ID,
		},
		"meta": map[string]any{},
	})
}

func (s *Server) handlePlacementTestComplete(w http.ResponseWriter, r *http.Request, user contracts.User) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}
	if s.levelService == nil || s.userLevelStore == nil {
		writeError(w, http.StatusNotFound, "feature_disabled",
			"Level progression is not enabled on this server.", false)
		return
	}

	var body struct {
		FullSessionID string `json:"full_session_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil && !errors.Is(err, io.EOF) {
		writeJSON(w, http.StatusBadRequest, map[string]any{
			"error": map[string]any{"code": "invalid_body", "message": err.Error()},
		})
		return
	}
	if body.FullSessionID == "" {
		writeError(w, http.StatusBadRequest, "missing_full_session_id",
			"full_session_id is required.", false)
		return
	}

	session, ok := s.repo.MockExamByID(body.FullSessionID)
	if !ok || (session.LearnerID != "" && session.LearnerID != user.ID) {
		// Treat "not found" and "wrong owner" identically so the endpoint
		// never leaks the existence of someone else's session.
		writeNotFound(w)
		return
	}

	scorePct := float64(session.OverallScore)
	assignedLevel := s.levelService.MapPlacementScoreToLevel(scorePct)
	updated, err := s.userLevelStore.MarkPlacementTaken(user.ID, assignedLevel, time.Now().UTC())
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]any{
			"error": map[string]any{"code": "placement_assign_failed", "message": err.Error()},
		})
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"data": map[string]any{
			"assigned_level":     assignedLevel,
			"score_pct":          scorePct,
			"current_level":      updated.CurrentLevel,
			"unlocked_levels":    updated.UnlockedLevels,
			"placement_taken_at": updated.PlacementTakenAt,
		},
		"meta": map[string]any{},
	})
}
