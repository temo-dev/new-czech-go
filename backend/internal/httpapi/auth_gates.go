package httpapi

import (
	"errors"
	"fmt"
	"net/http"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// gateBlocked is the sentinel an enforcement helper returns when the
// caller has been blocked. The handler translates it into the right HTTP
// response; the message string is what surfaces to the client.
type gateBlockedError struct {
	Code    string
	Message string
	Status  int
	Header  map[string]string
}

func (e *gateBlockedError) Error() string { return e.Message }

// errIs reports whether err is a gate block AND, if so, returns the
// underlying type. The handler uses this to short-circuit further work.
func asGateBlocked(err error) (*gateBlockedError, bool) {
	if err == nil {
		return nil, false
	}
	var ge *gateBlockedError
	if errors.As(err, &ge) {
		return ge, true
	}
	return nil, false
}

// writeGateBlocked emits the 4xx response a gate produced.
func writeGateBlocked(w http.ResponseWriter, ge *gateBlockedError) {
	for k, v := range ge.Header {
		w.Header().Set(k, v)
	}
	writeAuthError(w, ge.Status, ge.Code, ge.Message)
}

// ── A3.1 — attempts quota ────────────────────────────────────────────────

// checkAndIncrAttemptQuota enforces the free-tier daily attempts cap.
//
// Behavior:
//   - V17 stores not wired -> no-op (nil error, 0 count). Legacy callers
//     that bypass V17 still work.
//   - admin role -> no-op so CMS/QA can hit attempts endpoints freely.
//   - Pro tier active -> no-op, no counter increment (Pro is unlimited
//     so we don't need to track usage for them at all).
//   - Free tier -> read attempts_count first, block at the cap, then
//     increment ONLY when the request is granted. This prevents the
//     counter from ballooning past the cap when a learner spam-taps
//     past their daily allowance (each rejected request used to burn
//     a counter slot).
//
// The gate is invoked BEFORE the attempt is created so a 429 does not
// leave a stranded attempt row. Two concurrent requests at the cap
// boundary may both pass the check and increment — that is an
// acceptable trade for not leaking the counter on every rejection.
func (s *Server) checkAndIncrAttemptQuota(user contracts.User) error {
	if s.dailyUsageStore == nil || s.userStore == nil {
		return nil
	}
	if user.Role == "admin" {
		return nil
	}
	account, ok := s.userStore.UserAccountByID(user.ID)
	if !ok {
		// V17 user lookup miss -> caller is on the legacy fixture path;
		// do not enforce the V17 quota against them.
		return nil
	}
	now := time.Now().UTC()
	if account.IsPro(now) {
		return nil
	}

	_, granted, err := s.dailyUsageStore.TryIncrementAttempts(user.ID, now, freeTierAttemptsPerDay)
	if err != nil {
		// Store failure must not block the request — the worst case is
		// a learner sneaking past their cap by a request or two, which
		// is far better than blocking everyone on a transient DB issue.
		return nil
	}
	if !granted {
		return &gateBlockedError{
			Code:    "attempts_quota_exceeded",
			Message: fmt.Sprintf("daily free-tier limit of %d attempts reached", freeTierAttemptsPerDay),
			Status:  http.StatusTooManyRequests,
			Header: map[string]string{
				"X-Limit-Reset": fmt.Sprintf("%d", nextVNDayBoundary(now).Unix()),
			},
		}
	}
	return nil
}

// ── A3.2 — interview weekly quota ────────────────────────────────────────

// checkAndIncrInterviewQuota enforces the 1-interview-per-week free-tier
// cap on /v1/interview-sessions/token. Same opt-in rules as the attempts
// quota: nil stores -> no-op; admin -> no-op; Pro -> no-op.
//
// The "1/week" semantic is implemented as "no more than freeTierInterviewsPerWeek
// interviews logged in the last 7 VN-civil days". We DO NOT use the
// per-day daily_usage row in isolation because then the counter would
// reset on the day boundary and let a learner do two interviews on
// adjacent days. Instead we sum the 7 most-recent rows.
func (s *Server) checkAndIncrInterviewQuota(user contracts.User) error {
	if s.dailyUsageStore == nil || s.userStore == nil {
		return nil
	}
	if user.Role == "admin" {
		return nil
	}
	account, ok := s.userStore.UserAccountByID(user.ID)
	if !ok {
		return nil
	}
	now := time.Now().UTC()
	if account.IsPro(now) {
		return nil
	}

	// Sum the trailing 7 days (inclusive of today) BEFORE incrementing
	// so the cap reflects "this week so far".
	var weekTotal int
	for i := 0; i < 7; i++ {
		day := now.AddDate(0, 0, -i)
		if u, ok := s.dailyUsageStore.DailyUsageByUserDay(user.ID, day); ok {
			weekTotal += u.InterviewsCount
		}
	}
	if weekTotal >= freeTierInterviewsPerWeek {
		return &gateBlockedError{
			Code:    "interview_quota_exceeded",
			Message: fmt.Sprintf("free-tier limit of %d interview(s) per week reached", freeTierInterviewsPerWeek),
			Status:  http.StatusTooManyRequests,
		}
	}
	if _, err := s.dailyUsageStore.IncrementInterviews(user.ID, now); err != nil {
		// Tolerate increment failures for the same reason as the
		// attempts quota: better to over-allow than to over-block.
		return nil
	}
	return nil
}

// ── A3.4 — verify gate ───────────────────────────────────────────────────

// checkVerifyGate blocks unverified learners who have exhausted their
// 3-attempt grace allowance. When V17 stores are absent, when the user
// is admin, or when the account is already verified, this is a no-op.
//
// Decrement-on-deny semantics: this gate is invoked BEFORE the attempt
// is created. We decrement the grace counter on EVERY pre-attempt check
// and only block once the counter is at zero. That way the learner's
// FIRST 3 unverified attempts succeed (per spec §2 "grace mode 3
// attempts"); the 4th lands here with grace at 0 and gets the verify
// prompt.
func (s *Server) checkVerifyGate(user contracts.User) error {
	if s.userStore == nil {
		return nil
	}
	if user.Role == "admin" {
		return nil
	}
	account, ok := s.userStore.UserAccountByID(user.ID)
	if !ok {
		return nil
	}
	if account.IsEmailVerified() {
		return nil
	}
	if account.GraceAttemptsLeft <= 0 {
		return &gateBlockedError{
			Code:    "email_verify_required",
			Message: "please verify your email to continue",
			Status:  http.StatusForbidden,
		}
	}
	// Burn one grace credit for this attempt. The decrement clamps at 0
	// inside the store so calling it on the last unit leaves the row at
	// zero and the next call hits the block branch above.
	s.userStore.DecrementUserGrace(account.ID)
	return nil
}

// ── time helpers ─────────────────────────────────────────────────────────

// nextVNDayBoundary returns the next VN-civil-day midnight after now.
// Used as the X-Limit-Reset hint on a 429 so the client can surface
// "limit resets at 00:00".
func nextVNDayBoundary(now time.Time) time.Time {
	loc, err := time.LoadLocation("Asia/Ho_Chi_Minh")
	if err != nil {
		loc = time.FixedZone("VN", 7*60*60)
	}
	local := now.In(loc)
	next := time.Date(local.Year(), local.Month(), local.Day()+1, 0, 0, 0, 0, loc)
	return next.UTC()
}
