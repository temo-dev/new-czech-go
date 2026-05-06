package contracts

import "time"

// LevelProgressResponse is the wire shape returned by
// `GET /v1/users/me/level-progress`. The client uses it to render the home
// LevelProgressRing, the locked-course delta bars, and the promotion banner.
//
// Server is the single authority for `PromotionUnlocked` and `AllSkillsPass`
// — the client never recomputes these (per V21 spec § Boundaries).
type LevelProgressResponse struct {
	UserID                 string                      `json:"user_id"`
	CurrentLevel           string                      `json:"current_level"`
	UnlockedLevels         []string                    `json:"unlocked_levels"`
	NextLevel              string                      `json:"next_level"`
	PlacementTakenAt       *time.Time                  `json:"placement_taken_at,omitempty"`
	SkillMastery           map[string]SkillMasteryInfo `json:"skill_mastery"`
	CoveragePct            float64                     `json:"coverage_pct"`
	CoverageThresholdPct   float64                     `json:"coverage_threshold_pct"`
	AllSkillsPass          bool                        `json:"all_skills_pass"`
	PromotionUnlocked      bool                        `json:"promotion_unlocked"`
	PromotionTestID        string                      `json:"promotion_test_id,omitempty"`
	PromotionCooldownUntil *time.Time                  `json:"promotion_cooldown_until,omitempty"`
}

// SkillMasteryInfo carries the per-skill snapshot that the home ring renders.
// Pct is in [0, 100]; Passes is server-derived from Pct ≥ ThresholdPct so the
// client never needs to know the threshold in two places.
type SkillMasteryInfo struct {
	Pct          float64 `json:"pct"`
	ThresholdPct float64 `json:"threshold_pct"`
	Passes       bool    `json:"passes"`
}
