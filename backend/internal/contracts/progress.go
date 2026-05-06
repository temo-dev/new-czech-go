package contracts

import "time"

// Progress is the wire shape returned by GET /v1/users/me/progress.
//
// Bands and Weights are surfaced so the Flutter client never has to guess
// thresholds or default skill weights — the backend stays the single source
// of truth for tuning. See docs/specs/skill-mastery-progress.md.
type Progress struct {
	OverallProgress float64          `json:"overall_progress"`
	OverallBand     string           `json:"overall_band"`
	Skills          []SkillProgress  `json:"skills"`
	Bands           ProgressBands    `json:"bands"`
	Weights         map[string]int   `json:"weights"`
}

// SkillProgress aggregates one skill_kind across all module rows for one user.
// MasteryScore here is the unweighted average across the skill's modules; the
// per-skill weighting only applies to OverallProgress.
type SkillProgress struct {
	SkillKind     string           `json:"skill_kind"`
	Mastery       float64          `json:"mastery"`
	Band          string           `json:"band"`
	AttemptsCount int              `json:"attempts_count"`
	LastAttemptAt time.Time        `json:"last_attempt_at,omitempty"`
	Modules       []ModuleProgress `json:"modules"`
}

// ModuleProgress is one persisted user_skill_mastery row in wire form. ModuleID
// is the empty string for the exam-pool aggregate row; the Flutter client
// surfaces those under a virtual "exam" group. ModuleTitle is the human-readable
// title resolved from the modules table at read time; empty when ModuleID is
// empty (exam aggregate) or when the module row no longer exists.
type ModuleProgress struct {
	ModuleID      string    `json:"module_id"`
	ModuleTitle   string    `json:"module_title,omitempty"`
	Mastery       float64   `json:"mastery"`
	Band          string    `json:"band"`
	AttemptsCount int       `json:"attempts_count"`
	LastAttemptAt time.Time `json:"last_attempt_at,omitempty"`
}

// ProgressBands mirrors MasteryConfig band thresholds in wire form. The
// client uses these to render colour-coded bars without hardcoding numbers.
type ProgressBands struct {
	NeedsWork float64 `json:"needs_work"`
	Solid     float64 `json:"solid"`
	Ready     float64 `json:"ready"`
}
