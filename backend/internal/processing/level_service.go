package processing

import (
	"errors"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// LevelService composes V19 mastery + V21 user-level / promotion-attempts
// state into the gating answer the home screen and `level-progress`
// endpoint render. The service is **pure orchestration** — no HTTP, no DB
// writes, no LLM calls — so it stays fast and trivially testable.
//
// Server is the sole authority for `PromotionUnlocked` (per V21 spec
// § Boundaries); clients render whatever this struct returns and never
// recompute the gates.
type LevelService struct {
	Config        LevelConfig
	Mastery       LevelMasteryReader
	UserLevels    LevelUserReader
	PromoAttempts LevelPromoReader

	// Now overrides the wall clock for testing. Defaults to time.Now().UTC().
	Now func() time.Time

	// PromotionTestForLevel optionally resolves the promotion MockTest ID
	// for the given target level. When nil, LevelProgressResponse.PromotionTestID
	// stays empty and the handler is responsible for filling it.
	PromotionTestForLevel func(targetLevel string) (string, bool)
}

// LevelMasteryReader is the read-only subset of SkillMasteryStore the
// gating service needs.
type LevelMasteryReader interface {
	ListForUser(userID string) []contracts.SkillMasteryRow
}

// LevelUserReader is the read-only subset of UserLevelStore.
type LevelUserReader interface {
	GetUserLevel(userID string) (contracts.UserLevel, bool)
}

// LevelPromoReader is the read-only subset of PromotionAttemptsStore.
type LevelPromoReader interface {
	GetLatestFailedAttempt(userID, targetLevel string) (contracts.PromotionAttempt, bool)
}

// expectedSkills is the exhaustive set of skill_kind values the gating
// service expects to see mastery rows for. Keeping the list local (rather
// than deriving from MasteryConfig.Weights) means a zero-weight skill in
// the V19 weights map cannot silently drop out of the V21 gate.
var expectedSkills = []string{"noi", "viet", "nghe", "doc", "tu_vung", "ngu_phap"}

// nextLevelAfter returns the level a learner is promoted to from the given
// current level, or the empty string if they are at the top of the ladder.
// Centralising the order in one place lets the rest of the service stay
// table-free.
func nextLevelAfter(current string) string {
	switch current {
	case "a0":
		return "a1"
	case "a1":
		return "a2"
	case "a2":
		return "b1"
	default:
		return ""
	}
}

// MapPlacementScoreToLevel delegates to the configured placement bands.
// Exposed on the service so callers (the placement handler in V21-B5)
// have a single import surface.
func (s *LevelService) MapPlacementScoreToLevel(score float64) string {
	return s.Config.LevelFromPlacementScore(score)
}

// ComputeLevelProgress builds the `LevelProgressResponse` payload for the
// given user. The response is fully populated end-to-end including the
// derived `PromotionUnlocked` flag — clients render it as-is.
func (s *LevelService) ComputeLevelProgress(userID string) (contracts.LevelProgressResponse, error) {
	if userID == "" {
		return contracts.LevelProgressResponse{}, errors.New("user_id required")
	}
	if s.UserLevels == nil || s.Mastery == nil || s.PromoAttempts == nil {
		return contracts.LevelProgressResponse{}, errors.New("LevelService missing dependencies")
	}

	level, _ := s.UserLevels.GetUserLevel(userID)
	if level.UserID == "" {
		level.UserID = userID
	}
	if level.CurrentLevel == "" {
		level.CurrentLevel = "a0"
	}
	if len(level.UnlockedLevels) == 0 {
		level.UnlockedLevels = []string{"a0"}
	}

	rows := s.Mastery.ListForUser(userID)

	skillInfo := s.computeSkillMastery(rows)
	allSkillsPass := true
	for _, info := range skillInfo {
		if !info.Passes {
			allSkillsPass = false
			break
		}
	}
	coveragePct := s.computeCoverage(rows)
	coverageMet := coveragePct >= s.Config.CoverageThresholdPct

	next := nextLevelAfter(level.CurrentLevel)
	resp := contracts.LevelProgressResponse{
		UserID:               level.UserID,
		CurrentLevel:         level.CurrentLevel,
		UnlockedLevels:       append([]string(nil), level.UnlockedLevels...),
		NextLevel:            next,
		PlacementTakenAt:     level.PlacementTakenAt,
		SkillMastery:         skillInfo,
		CoveragePct:          coveragePct,
		CoverageThresholdPct: s.Config.CoverageThresholdPct,
		AllSkillsPass:        allSkillsPass,
	}

	// No upper level → nothing to promote to. Skip cooldown / unlock work.
	if next == "" {
		return resp, nil
	}

	cooldownUntil := s.cooldownUntil(userID, next)
	if cooldownUntil != nil {
		t := *cooldownUntil
		resp.PromotionCooldownUntil = &t
	}

	resp.PromotionUnlocked = allSkillsPass && coverageMet && cooldownUntil == nil

	if s.PromotionTestForLevel != nil {
		if id, ok := s.PromotionTestForLevel(next); ok {
			resp.PromotionTestID = id
		}
	}
	return resp, nil
}

// computeSkillMastery returns one entry per expected skill so the home
// ring always renders all six slots. Pct is the highest mastery score
// (across modules) for the skill, rendered as a percentage.
func (s *LevelService) computeSkillMastery(rows []contracts.SkillMasteryRow) map[string]contracts.SkillMasteryInfo {
	maxByKind := make(map[string]float64, len(expectedSkills))
	for _, k := range expectedSkills {
		maxByKind[k] = 0
	}
	for _, r := range rows {
		if _, expected := maxByKind[r.SkillKind]; !expected {
			continue
		}
		if r.AttemptsCount <= 0 {
			continue
		}
		if r.MasteryScore > maxByKind[r.SkillKind] {
			maxByKind[r.SkillKind] = r.MasteryScore
		}
	}
	out := make(map[string]contracts.SkillMasteryInfo, len(expectedSkills))
	for _, k := range expectedSkills {
		pct := maxByKind[k] * 100
		out[k] = contracts.SkillMasteryInfo{
			Pct:          pct,
			ThresholdPct: s.Config.MasteryThresholdPct,
			Passes:       pct >= s.Config.MasteryThresholdPct,
		}
	}
	return out
}

// computeCoverage returns the percentage of expected skills the learner
// has at least one attempt in. Anti-farming proxy: a learner who only
// drilled `noi` cannot unlock promotion even if their `noi` mastery is
// 100%.
func (s *LevelService) computeCoverage(rows []contracts.SkillMasteryRow) float64 {
	expected := make(map[string]bool, len(expectedSkills))
	for _, k := range expectedSkills {
		expected[k] = true
	}
	touched := make(map[string]bool, len(expectedSkills))
	for _, r := range rows {
		if expected[r.SkillKind] && r.AttemptsCount > 0 {
			touched[r.SkillKind] = true
		}
	}
	if len(expectedSkills) == 0 {
		return 0
	}
	return float64(len(touched)) / float64(len(expectedSkills)) * 100
}

// cooldownUntil returns the cooldown expiry for the (user, target) tuple
// or nil if the cooldown has expired (or there was no failed attempt).
func (s *LevelService) cooldownUntil(userID, targetLevel string) *time.Time {
	latest, ok := s.PromoAttempts.GetLatestFailedAttempt(userID, targetLevel)
	if !ok {
		return nil
	}
	until := latest.CreatedAt.Add(time.Duration(s.Config.PromotionCooldownHours) * time.Hour)
	if !s.now().Before(until) {
		return nil
	}
	return &until
}

func (s *LevelService) now() time.Time {
	if s.Now != nil {
		return s.Now()
	}
	return time.Now().UTC()
}
