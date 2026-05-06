package contracts

import "time"

// PromotionAttempt is the per-attempt ledger row written each time a learner
// invokes `POST /v1/promotion-attempts` for a level-up MockTest. The store
// is append-only after Create — only Passed / ScorePct / PerSkillPct change
// once the scoring pipeline finishes (V21-B8 promotion hook).
//
// PerSkillPct keys are skill_kind values (`noi`, `viet`, ...) and values are
// pcts in [0, 100], matching the per-section breakdown the promotion fail
// screen renders (V21-D8).
type PromotionAttempt struct {
	ID            string             `json:"id"`
	UserID        string             `json:"user_id"`
	MockTestID    string             `json:"mock_test_id"`
	SourceLevel   string             `json:"source_level"`
	TargetLevel   string             `json:"target_level"`
	FullSessionID string             `json:"full_session_id"`
	Passed        bool               `json:"passed"`
	ScorePct      float64            `json:"score_pct"`
	PerSkillPct   map[string]float64 `json:"per_skill_pct"`
	CreatedAt     time.Time          `json:"created_at"`
}
