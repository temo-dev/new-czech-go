package contracts

import "time"

// StreakDay records whether a learner attempted (or grace-passed) a single
// civil date in the Asia/Ho_Chi_Minh timezone. The Day field is always a
// midnight-anchored VN-local time so two attempts on the same VN calendar
// day collapse to one row regardless of when they hit the server.
type StreakDay struct {
	UserID    string    `json:"user_id"`
	Day       time.Time `json:"day"`
	Completed bool      `json:"completed"`
	GraceUsed bool      `json:"grace_used"`
	CreatedAt time.Time `json:"created_at"`
}

// StreakSummary is the rolled-up view shown on the Home streak ring and
// the Profile streak history calendar.
//
// `Current` counts consecutive days ending at the AsOf day (or the most
// recent completion if AsOf has no activity yet). Both `Completed` and
// `GraceUsed` days extend the current run.
//
// `GracePassesUsedThisWeek` is scoped to ISO week (Monday-anchored) of
// AsOf so Pro learners can see how many of their weekly grace passes
// remain.
type StreakSummary struct {
	Current                 int       `json:"current"`
	Longest                 int       `json:"longest"`
	LastCompletedDay        time.Time `json:"last_completed_day"`
	GracePassesUsedThisWeek int       `json:"grace_passes_used_this_week"`
}
