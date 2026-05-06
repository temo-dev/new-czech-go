package contracts

import "time"

// UserLevel captures a learner's V21 CEFR gating state. The fields live
// alongside core user account data on the Postgres `users` table but are
// owned by store.UserLevelStore so the gating surface can evolve
// independently of the auth/account contract.
//
// Wire shape mirrors the JSON returned by `GET /v1/users/me/level-progress`
// (scope of V21-B4) — keeping the contract close to the consumer keeps
// renames cheap as the slice ships.
type UserLevel struct {
	UserID           string     `json:"user_id"`
	CurrentLevel     string     `json:"current_level"`     // "a0" | "a1" | "a2" | "b1"
	UnlockedLevels   []string   `json:"unlocked_levels"`   // sorted ascending, deduplicated
	PlacementTakenAt *time.Time `json:"placement_taken_at,omitempty"`
}
