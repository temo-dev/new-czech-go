package contracts

import "time"

// SkillMasteryRow is one persisted EMA-smoothed mastery row keyed by
// (user_id, skill_kind, module_id). One row per user per skill per module.
//
// Exam-pool aggregate: rows where the source attempt has Pool="exam" use an
// empty ModuleID so the unique index (user_id, skill_kind, module_id) still
// holds and the read endpoint can group exam attempts under a virtual
// "exam" module on the client side.
//
// Defined under contracts/ so both store/ and processing/mastery/ can depend
// on it without an import cycle.
type SkillMasteryRow struct {
	ID             string    `json:"id"`
	UserID         string    `json:"user_id"`
	SkillKind      string    `json:"skill_kind"`
	ModuleID       string    `json:"module_id"`
	MasteryScore   float64   `json:"mastery_score"`
	AttemptsCount  int       `json:"attempts_count"`
	LastAttemptID  string    `json:"last_attempt_id"`
	LastAttemptAt  time.Time `json:"last_attempt_at"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}
