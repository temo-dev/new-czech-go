package contracts

import "time"

// LearnerStateResponse is the wire shape returned by
// `GET /v1/admin/users/:id/state` powering the V22 admin Learner X-Ray
// screen. Read-only aggregator across V17 user, V21 user_levels,
// V21.2 daily_usage, V19 user_skill_mastery, V21 promotion_attempts,
// and the attempts ledger.
type LearnerStateResponse struct {
	User              LearnerStateUser        `json:"user"`
	DailyUsage        LearnerStateDailyUsage  `json:"daily_usage"`
	LevelState        LearnerStateLevel       `json:"level_state"`
	Mastery           []LearnerStateMastery   `json:"mastery"`
	PromotionAttempts []LearnerStatePromotion `json:"promotion_attempts"`
	HasMorePromotion  bool                    `json:"has_more_promotion"`
	RecentAttempts    []LearnerStateAttempt   `json:"recent_attempts"`
}

// LearnerStateUser is the admin-facing identity projection. Mirrors
// adminUserView from admin_users.go but excludes attempts_today (the
// daily-usage block carries that), keeping each block single-purpose.
type LearnerStateUser struct {
	ID                string     `json:"id"`
	Email             string     `json:"email"`
	DisplayName       string     `json:"display_name"`
	Role              string     `json:"role"`
	ProTier           string     `json:"pro_tier"`
	GraceAttemptsLeft int        `json:"grace_attempts_left"`
	CreatedAt         time.Time  `json:"created_at"`
	UpdatedAt         time.Time  `json:"updated_at"`
	ProExpiresAt      *time.Time `json:"pro_expires_at,omitempty"`
}

// LearnerStateDailyUsage carries today's free-tier counter. Day is the
// local-civil-day string in YYYY-MM-DD; AttemptsCap is the same
// freeTierAttemptsPerDay the existing list endpoint already exposes.
type LearnerStateDailyUsage struct {
	Day           string `json:"day"`
	AttemptsCount int    `json:"attempts_count"`
	AttemptsCap   int    `json:"attempts_cap"`
}

// LearnerStateLevel is the V21 CEFR gating state. unlocked_levels is
// sorted ascending; placement_taken_at is omitted for users who have not
// yet completed placement.
type LearnerStateLevel struct {
	CurrentLevel     string     `json:"current_level"`
	UnlockedLevels   []string   `json:"unlocked_levels"`
	PlacementTakenAt *time.Time `json:"placement_taken_at,omitempty"`
}

// LearnerStateMastery is one row of the V19 user_skill_mastery
// aggregate. ModuleLabel resolves to the module title at request time so
// the CMS does not need a separate module lookup; empty when ModuleID is
// "" (exam pool) or the module has been deleted.
type LearnerStateMastery struct {
	SkillKind     string    `json:"skill_kind"`
	ModuleID      string    `json:"module_id"`
	ModuleLabel   string    `json:"module_label"`
	Score         float64   `json:"score"`
	AttemptsCount int       `json:"attempts_count"`
	UpdatedAt     time.Time `json:"updated_at"`
}

// LearnerStatePromotion is one row of the V21 promotion_attempts
// ledger. The list is ordered DESC by created_at and capped to 20 with
// LearnerStateResponse.HasMorePromotion=true signalling truncation.
type LearnerStatePromotion struct {
	ID          string    `json:"id"`
	TargetLevel string    `json:"target_level"`
	SourceLevel string    `json:"source_level"`
	ScorePct    float64   `json:"score_pct"`
	Passed      bool      `json:"passed"`
	CreatedAt   time.Time `json:"created_at"`
}

// LearnerStateAttempt is the per-attempt summary the X-Ray "Recent
// attempts" table renders. ExerciseLabel + SkillKind resolve at request
// time from the exercise store; ReadinessLevel is the LLM-rolled-up
// score band (`not_ready` / `almost_ready` / `ready_for_mock` /
// `exam_ready`) — empty for in-flight attempts.
type LearnerStateAttempt struct {
	ID             string `json:"id"`
	ExerciseID     string `json:"exercise_id"`
	ExerciseLabel  string `json:"exercise_label"`
	SkillKind      string `json:"skill_kind"`
	ReadinessLevel string `json:"readiness_level,omitempty"`
	StartedAt      string `json:"started_at"`
	Status         string `json:"status,omitempty"`
}
