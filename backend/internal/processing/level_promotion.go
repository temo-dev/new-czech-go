package processing

// level_promotion.go — V21 atomic promotion outcome hook.
//
// Fires after a mock_exam_session completes. If the session is linked to a
// promotion_attempts row (created by POST /v1/promotion-attempts in
// V21-B6), we:
//
//   1. Compute per-skill % from the section scores.
//   2. Update the promotion_attempts row with passed / score_pct /
//      per_skill_pct.
//   3. On pass, append the target level to the user's unlocked_levels and
//      set current_level — both via store.UserLevelStore.SetUserLevel,
//      which is race-safe and idempotent (B1 single-statement UPDATE with
//      `array_append` + `ANY` guard).
//
// Both writes are individually idempotent, so replaying the hook with the
// same session leaves the database in the same state. Tests verify this
// directly (TestHandlePromotionOutcome_ReplayIsIdempotent).
//
// The hook is intentionally **not** a side-effect inside MasteryUpdater —
// promotion is a session-level concern (driven by overall_score), whereas
// mastery is per-attempt. Wiring at the session-completion handler keeps
// the layering clean and lets us land it without touching the per-attempt
// scoring path.

import (
	"fmt"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

// PromotionHookDeps bundles the stores the V21 promotion hook writes
// against. Both fields are required; HandlePromotionOutcome returns an
// error when either is nil.
type PromotionHookDeps struct {
	PromoAttempts store.PromotionAttemptsStore
	UserLevels    store.UserLevelStore
}

// HandlePromotionOutcome is the V21 post-scoring hook. Returns processed=true
// when the session is linked to a promotion_attempts row (the caller can
// gate response shape on this); processed=false when the session belongs to
// a regular practice / mock flow.
func HandlePromotionOutcome(deps PromotionHookDeps, session contracts.MockExamSession) (bool, error) {
	if deps.PromoAttempts == nil || deps.UserLevels == nil {
		return false, fmt.Errorf("promotion hook missing dependencies")
	}
	pa, ok := deps.PromoAttempts.GetByFullSessionID(session.ID)
	if !ok {
		return false, nil
	}

	scorePct := float64(session.OverallScore)
	perSkill := perSkillPctFromSections(session.Sections)

	if _, err := deps.PromoAttempts.MarkResult(pa.ID, session.Passed, scorePct, perSkill); err != nil {
		return true, fmt.Errorf("mark promotion result: %w", err)
	}
	if session.Passed {
		if _, err := deps.UserLevels.SetUserLevel(pa.UserID, pa.TargetLevel); err != nil {
			return true, fmt.Errorf("promote user level: %w", err)
		}
	}
	return true, nil
}

// perSkillPctFromSections aggregates section-level scores into per-skill
// percentages. Multiple sections for the same skill_kind sum their scores
// and max points; the result is (sum_score / sum_max) * 100. Skills with
// max_points == 0 are skipped (avoid divide-by-zero on misconfigured
// sections).
func perSkillPctFromSections(sections []contracts.MockExamSessionItem) map[string]float64 {
	type bucket struct{ score, max int }
	by := map[string]*bucket{}
	for _, sec := range sections {
		if sec.SkillKind == "" || sec.MaxPoints <= 0 {
			continue
		}
		b, ok := by[sec.SkillKind]
		if !ok {
			b = &bucket{}
			by[sec.SkillKind] = b
		}
		b.score += sec.SectionScore
		b.max += sec.MaxPoints
	}
	out := make(map[string]float64, len(by))
	for k, b := range by {
		if b.max == 0 {
			continue
		}
		out[k] = float64(b.score) / float64(b.max) * 100
	}
	return out
}
