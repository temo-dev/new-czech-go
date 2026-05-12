package httpapi

// promotion_handler.go — V21 POST /v1/promotion-attempts.
//
// Creates a promotion attempt against a level-up MockTest after running the
// full gating pipeline. The handler is the **single client-facing entry
// point** that mutates promotion state — the post-scoring hook in V21-B8
// later writes the attempt outcome (passed / score_pct / per_skill_pct).
//
// Error precedence (returns the first matching error):
//   1. 404 mock_test_not_found
//   2. 400 mock_test_not_promotion
//   3. 409 level_already_unlocked
//   4. 400 promotion_locked
//   5. 400 cooldown_active (with retry_after)

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

func (s *Server) handlePromotionAttempts(w http.ResponseWriter, r *http.Request, user contracts.User) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}
	if s.levelService == nil || s.userLevelStore == nil || s.promoAttemptsStore == nil {
		writeError(w, http.StatusNotFound, "feature_disabled",
			"Level progression is not enabled on this server.", false)
		return
	}

	var body struct {
		MockTestID string `json:"mock_test_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil && !errors.Is(err, io.EOF) {
		writeJSON(w, http.StatusBadRequest, map[string]any{
			"error": map[string]any{"code": "invalid_body", "message": err.Error()},
		})
		return
	}
	if body.MockTestID == "" {
		writeError(w, http.StatusBadRequest, "missing_mock_test_id",
			"mock_test_id is required.", false)
		return
	}

	// 1. mock_test_not_found.
	mock, ok := s.repo.MockTestByID(body.MockTestID)
	if !ok {
		writeError(w, http.StatusNotFound, "mock_test_not_found",
			"The requested mock test does not exist.", false)
		return
	}

	// 2. mock_test_not_promotion.
	if !mock.IsPromotion || mock.TargetLevel == "" {
		writeError(w, http.StatusBadRequest, "mock_test_not_promotion",
			"This mock test is not configured as a promotion exam.", false)
		return
	}

	// 3. level_already_unlocked.
	currentLevel, _ := s.userLevelStore.GetUserLevel(user.ID)
	for _, lvl := range currentLevel.UnlockedLevels {
		if lvl == mock.TargetLevel {
			writeError(w, http.StatusConflict, "level_already_unlocked",
				"You have already unlocked this level.", false)
			return
		}
	}

	progress, err := s.levelService.ComputeLevelProgress(user.ID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]any{
			"error": map[string]any{"code": "internal_error", "message": err.Error()},
		})
		return
	}

	// 4. promotion_locked — gates not met (mastery / coverage), or the
	//    target level isn't the user's next level on the ladder.
	gatesMet := progress.AllSkillsPass && progress.CoveragePct >= progress.CoverageThresholdPct
	if !gatesMet || progress.NextLevel != mock.TargetLevel {
		writeError(w, http.StatusBadRequest, "promotion_locked",
			"You have not met the requirements to attempt this promotion.", false)
		return
	}

	// 5. cooldown_active — last failed attempt still inside the cooldown
	//    window. Surface retry_after so the client can render the timer.
	if progress.PromotionCooldownUntil != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{
			"error": map[string]any{
				"code":        "cooldown_active",
				"message":     "Wait before attempting this promotion again.",
				"retry_after": progress.PromotionCooldownUntil.UTC().Format("2006-01-02T15:04:05Z07:00"),
			},
		})
		return
	}

	// All gates pass — create session + attempt ledger row.
	session, err := s.repo.CreateMockExam(user.ID, mock.ID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]any{
			"error": map[string]any{"code": "promotion_create_failed", "message": err.Error()},
		})
		return
	}
	attempt, err := s.promoAttemptsStore.Create(contracts.PromotionAttempt{
		UserID:        user.ID,
		MockTestID:    mock.ID,
		SourceLevel:   currentLevel.CurrentLevel,
		TargetLevel:   mock.TargetLevel,
		FullSessionID: session.ID,
	})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]any{
			"error": map[string]any{"code": "promotion_attempt_failed", "message": err.Error()},
		})
		return
	}

	writeJSON(w, http.StatusCreated, map[string]any{
		"data": map[string]any{
			"promotion_attempt_id": attempt.ID,
			"full_session_id":      session.ID,
			"target_level":         mock.TargetLevel,
			// S7: inline the full session so the client doesn't need a
			// follow-up GET /v1/mock-exams/:id round-trip.
			"session": session,
		},
		"meta": map[string]any{},
	})
}
