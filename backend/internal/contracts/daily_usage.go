package contracts

import "time"

// DailyUsage is the per-day rate-limit ledger for free-tier learners. The
// counters are denormalized: attempts and interviews are tracked
// separately because they have different free-tier caps (7/day vs 1/week).
// Per-day reset is implicit — each new VN civil day creates a new row.
type DailyUsage struct {
	UserID          string    `json:"user_id"`
	Day             time.Time `json:"day"`
	AttemptsCount   int       `json:"attempts_count"`
	InterviewsCount int       `json:"interviews_count"`
}
