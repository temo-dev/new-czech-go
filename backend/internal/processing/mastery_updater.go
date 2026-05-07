package processing

// mastery_updater.go — V19 user_skill_mastery aggregate side-effect.
//
// The processor calls Update synchronously after persisting AttemptFeedback.
// Errors are logged at the call site and never propagate; mastery is a
// side-channel signal, not a learner-facing failure surface.
//
// Lives in package `processing` (not a sub-package) to avoid an import
// cycle: the processor wires the updater directly into the attempt persist
// path, and shares MasteryConfig + ReadinessToScore from this package.

import (
	"context"
	"fmt"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

// MasteryUpdater applies an attempt's readiness band to the per-user-per-skill
// EMA aggregate. The struct is created once at server boot and shared across
// requests — it carries no per-request state.
type MasteryUpdater struct {
	store  store.SkillMasteryStore
	config MasteryConfig
	now    func() time.Time

	// isDemo, when set, returns true for exercises that should not feed the
	// mastery aggregate. V21 wires this so attempts on a course's
	// demo_exercise (taste-test for locked upper-level content) leave no
	// trace in user_skill_mastery. nil disables the check (legacy
	// behaviour).
	isDemo func(exerciseID string) bool
}

// NewMasteryUpdater constructs an updater. `now` is injected so tests can
// freeze the clock; pass time.Now in production.
func NewMasteryUpdater(s store.SkillMasteryStore, cfg MasteryConfig, now func() time.Time) *MasteryUpdater {
	if now == nil {
		now = time.Now
	}
	return &MasteryUpdater{store: s, config: cfg, now: now}
}

// WithDemoCheck installs a callback that decides whether an attempt's
// exercise is a "demo" (V21). Returning true causes Update to skip the
// aggregate write. Pass nil (or skip the call entirely) to keep every
// attempt counting toward mastery — matches the pre-V21 default.
func (u *MasteryUpdater) WithDemoCheck(fn func(exerciseID string) bool) *MasteryUpdater {
	u.isDemo = fn
	return u
}

// Update applies one attempt to the aggregate. Returns nil on no-op cases
// (missing user/skill/feedback, idempotent re-run) so callers can ignore
// the return value safely.
func (u *MasteryUpdater) Update(_ context.Context, attempt contracts.Attempt, exercise contracts.Exercise) error {
	if u == nil || u.store == nil {
		return nil
	}
	if attempt.UserID == "" || exercise.SkillKind == "" {
		return nil
	}
	if attempt.Feedback == nil || attempt.Feedback.ReadinessLevel == "" {
		return nil
	}
	// V21 — demo attempts (taste-tests of locked upper-level content) must
	// not move mastery. Skip silently so the rest of the pipeline doesn't
	// need to know the difference.
	if u.isDemo != nil && exercise.ID != "" && u.isDemo(exercise.ID) {
		return nil
	}

	moduleID := exercise.ModuleID
	if exercise.Pool == "exam" {
		// Exam-pool attempts collapse into a single per-user-per-skill row so
		// the unique index keeps holding regardless of which exam exercise was
		// answered.
		moduleID = ""
	}

	existing, found := u.store.GetForKey(attempt.UserID, exercise.SkillKind, moduleID)
	if found && existing.LastAttemptID == attempt.ID {
		return nil
	}

	score := ReadinessToScore(attempt.Feedback.ReadinessLevel)
	mastery := u.computeMastery(found, existing, score)

	completedAt := parseAttemptTime(attempt.CompletedAt, u.now())
	updated := contracts.SkillMasteryRow{
		UserID:        attempt.UserID,
		SkillKind:     exercise.SkillKind,
		ModuleID:      moduleID,
		MasteryScore:  mastery,
		AttemptsCount: 1,
		LastAttemptID: attempt.ID,
		LastAttemptAt: completedAt,
		UpdatedAt:     u.now(),
	}
	if found {
		updated.AttemptsCount = existing.AttemptsCount + 1
	}

	if _, err := u.store.Upsert(updated); err != nil {
		return fmt.Errorf("upsert mastery: %w", err)
	}
	return nil
}

// computeMastery returns the new EMA value. First attempt sets mastery to the
// score directly. Within EarlyAttemptCap the smoothing is faster so the bar
// feels responsive; after the cap it settles into the steadier rate.
func (u *MasteryUpdater) computeMastery(found bool, existing contracts.SkillMasteryRow, score float64) float64 {
	if !found || existing.AttemptsCount == 0 {
		return score
	}
	alpha := u.config.SteadyAlpha
	if existing.AttemptsCount <= u.config.EarlyAttemptCap {
		alpha = u.config.EarlyAlpha
	}
	return existing.MasteryScore*(1-alpha) + score*alpha
}

// parseAttemptTime accepts attempt.CompletedAt as RFC3339; on parse failure or
// missing field, falls back to the injected wall-clock so the row still has
// a usable timestamp.
func parseAttemptTime(raw string, fallback time.Time) time.Time {
	if raw == "" {
		return fallback
	}
	if t, err := time.Parse(time.RFC3339, raw); err == nil {
		return t
	}
	return fallback
}
