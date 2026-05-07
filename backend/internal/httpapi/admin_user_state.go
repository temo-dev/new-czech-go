package httpapi

import (
	"net/http"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// promotionAttemptsLimit is the V22 cap for the X-Ray promotion ledger.
// One row past this triggers HasMorePromotion=true (caller fetches +1
// sentinel row from the store).
const promotionAttemptsLimit = 20

// recentAttemptsLimit caps the X-Ray "Recent attempts" section.
const recentAttemptsLimit = 20

// handleAdminUserState serves GET /v1/admin/users/:id/state. Read-only
// aggregator powering the V22 CMS Learner X-Ray screen. Sub-stores
// must be wired (V17 user, V19 mastery, V21 user-levels + promotion,
// V21.2 daily-usage); a missing dep returns 503 so the CMS surfaces
// the gap rather than silent empties.
func (s *Server) handleAdminUserState(w http.ResponseWriter, r *http.Request, _ contracts.User, id string) {
	if r.Method != http.MethodGet {
		writeMethodNotAllowed(w)
		return
	}
	if s.userStore == nil || s.userLevelStore == nil || s.masteryStore == nil ||
		s.promoAttemptsStore == nil || s.dailyUsageStore == nil {
		writeError(w, http.StatusServiceUnavailable, "x_ray_unavailable",
			"X-Ray requires V17 + V19 + V21 stores wired on this backend", false)
		return
	}

	user, ok := s.userStore.UserAccountByID(id)
	if !ok {
		writeNotFound(w)
		return
	}

	now := time.Now().UTC()

	// Level state — auto-defaults to a0 / [a0] when no row exists yet.
	level, _ := s.userLevelStore.GetUserLevel(id)
	levelState := contracts.LearnerStateLevel{
		CurrentLevel:     level.CurrentLevel,
		UnlockedLevels:   level.UnlockedLevels,
		PlacementTakenAt: level.PlacementTakenAt,
	}

	// Daily usage — zero when the user hasn't attempted today.
	var attemptsToday int
	if usage, ok := s.dailyUsageStore.DailyUsageByUserDay(id, now); ok {
		attemptsToday = usage.AttemptsCount
	}

	// Mastery rows — resolve module label per row. Pre-fetch the full
	// module list once and key by ID; over postgres that is a single
	// SELECT vs N individual ModuleByID lookups, and a learner can
	// realistically have 30 mastery rows.
	masteryRows := s.masteryStore.ListForUser(id)
	moduleTitleByID := map[string]string{}
	if len(masteryRows) > 0 {
		for _, mod := range s.repo.ListModules("", "") {
			moduleTitleByID[mod.ID] = mod.Title
		}
	}
	masteryView := make([]contracts.LearnerStateMastery, 0, len(masteryRows))
	for _, m := range masteryRows {
		masteryView = append(masteryView, contracts.LearnerStateMastery{
			SkillKind:     m.SkillKind,
			ModuleID:      m.ModuleID,
			ModuleLabel:   moduleTitleByID[m.ModuleID],
			Score:         m.MasteryScore,
			AttemptsCount: m.AttemptsCount,
			UpdatedAt:     m.UpdatedAt,
		})
	}

	// Promotion attempts — fetch limit+1 sentinel to detect truncation.
	promoRaw := s.promoAttemptsStore.ListForUser(id, promotionAttemptsLimit+1)
	hasMore := len(promoRaw) > promotionAttemptsLimit
	if hasMore {
		promoRaw = promoRaw[:promotionAttemptsLimit]
	}
	promoView := make([]contracts.LearnerStatePromotion, 0, len(promoRaw))
	for _, p := range promoRaw {
		promoView = append(promoView, contracts.LearnerStatePromotion{
			ID:          p.ID,
			TargetLevel: p.TargetLevel,
			SourceLevel: p.SourceLevel,
			ScorePct:    p.ScorePct,
			Passed:      p.Passed,
			CreatedAt:   p.CreatedAt,
		})
	}

	// Recent attempts — DESC by started_at, exercise label resolved.
	attempts := s.repo.ListAttemptsForUser(id, recentAttemptsLimit)
	attemptsView := make([]contracts.LearnerStateAttempt, 0, len(attempts))
	for _, a := range attempts {
		label := ""
		skillKind := ""
		if ex, ok := s.repo.Exercise(a.ExerciseID); ok {
			label = ex.Title
			skillKind = ex.SkillKind
		}
		attemptsView = append(attemptsView, contracts.LearnerStateAttempt{
			ID:             a.ID,
			ExerciseID:     a.ExerciseID,
			ExerciseLabel:  label,
			SkillKind:      skillKind,
			ReadinessLevel: a.ReadinessLevel,
			StartedAt:      a.StartedAt,
			Status:         a.Status,
		})
	}

	resp := contracts.LearnerStateResponse{
		User: contracts.LearnerStateUser{
			ID:                user.ID,
			Email:             user.Email,
			DisplayName:       user.DisplayName,
			Role:              user.Role,
			ProTier:           user.ProTier,
			GraceAttemptsLeft: user.GraceAttemptsLeft,
			CreatedAt:         user.CreatedAt,
			UpdatedAt:         user.UpdatedAt,
			ProExpiresAt:      user.ProExpiresAt,
		},
		DailyUsage: contracts.LearnerStateDailyUsage{
			Day:           now.Format("2006-01-02"),
			AttemptsCount: attemptsToday,
			AttemptsCap:   freeTierAttemptsPerDay,
		},
		LevelState:        levelState,
		Mastery:           masteryView,
		PromotionAttempts: promoView,
		HasMorePromotion:  hasMore,
		RecentAttempts:    attemptsView,
	}
	writeJSON(w, http.StatusOK, resp)
}
