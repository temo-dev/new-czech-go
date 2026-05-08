package contracts

import "time"

// UserAccount is the database-backed learner identity that powers the V17
// self-serve flow. It is distinct from the lightweight User struct (used by
// the existing token-bearer middleware) so that introducing real signup
// does not have to rewrite every consumer of the legacy User type.
//
// `Email` preserves the exact form the learner typed; `EmailNormalized` is
// the lowercase, trimmed form used for unique lookup. Pointer timestamps
// represent nullable columns (NULL until the corresponding event happens).
type UserAccount struct {
	ID                string     `json:"id"`
	Email             string     `json:"email"`
	EmailNormalized   string     `json:"email_normalized"`
	EmailVerifiedAt   *time.Time `json:"email_verified_at,omitempty"`
	PasswordHash      string     `json:"-"` // never serialized to clients
	DisplayName       string     `json:"display_name"`
	AvatarAssetID     string     `json:"avatar_asset_id,omitempty"`
	Role              string     `json:"role"`     // "learner" | "admin"
	ProTier           string     `json:"pro_tier"` // "free" | "pro"
	ProExpiresAt      *time.Time `json:"pro_expires_at,omitempty"`
	OnboardingGoal    string     `json:"onboarding_goal,omitempty"`
	OnboardingLevel   string     `json:"onboarding_level,omitempty"`
	DailyReminderAt   string     `json:"daily_reminder_at,omitempty"` // "HH:MM" local
	PushToken         string     `json:"push_token,omitempty"`
	PushTokenPlatform string     `json:"push_token_platform,omitempty"`
	Timezone          string     `json:"timezone"`
	GraceAttemptsLeft int        `json:"grace_attempts_left"`
	AppleSub          string     `json:"apple_sub,omitempty"` // V25 Sign-in-with-Apple subject claim; empty for email accounts
	CreatedAt         time.Time  `json:"created_at"`
	UpdatedAt         time.Time  `json:"updated_at"`
	DeletedAt         *time.Time `json:"deleted_at,omitempty"`
}

// IsEmailVerified reports whether the account has confirmed its email.
func (u UserAccount) IsEmailVerified() bool { return u.EmailVerifiedAt != nil }

// IsPro reports whether the account currently holds an active Pro entitlement.
// `ProExpiresAt` is checked against the supplied `now` so callers can pass a
// deterministic clock in tests.
func (u UserAccount) IsPro(now time.Time) bool {
	if u.ProTier != "pro" {
		return false
	}
	if u.ProExpiresAt == nil {
		return false
	}
	return u.ProExpiresAt.After(now)
}
