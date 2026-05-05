package httpapi

import (
	"strings"
	"sync"
	"time"
)

// loginRateLimiter is a sliding-window failure counter keyed by the
// normalized email address. Five failures within a 15-minute window
// trigger a 429 from the login handler; a successful login resets the
// counter.
//
// The window is implemented as a slice of failure timestamps per email,
// with old entries pruned on every check. This is O(failures-in-window)
// per request, which is fine because the cap is 5.
//
// In V17 the backend is single-instance so an in-memory bucket suffices.
// V18 horizontal scaling will need to swap this for Redis (or a
// shared-nothing variant) — the surface area here is small enough to
// rewrite without disturbing handlers.
type loginRateLimiter struct {
	mu       sync.Mutex
	failures map[string][]time.Time
	window   time.Duration
	cap      int
	now      func() time.Time // injectable for tests
}

// newLoginRateLimiter returns a 5/15min sliding-window limiter.
func newLoginRateLimiter() *loginRateLimiter {
	return &loginRateLimiter{
		failures: map[string][]time.Time{},
		window:   15 * time.Minute,
		cap:      5,
		now:      time.Now,
	}
}

// IsBlocked reports whether the email has hit the failure cap inside the
// window. The pruning step keeps memory bounded over time.
func (l *loginRateLimiter) IsBlocked(email string) bool {
	key := strings.ToLower(strings.TrimSpace(email))
	if key == "" {
		return false
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	l.pruneLocked(key)
	return len(l.failures[key]) >= l.cap
}

// RecordFailure appends a failure timestamp for the email.
func (l *loginRateLimiter) RecordFailure(email string) {
	key := strings.ToLower(strings.TrimSpace(email))
	if key == "" {
		return
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	l.failures[key] = append(l.failures[key], l.now())
}

// Reset clears the failure history for the email — called on successful
// login so a learner who finally types the right password is not punished
// for earlier typos.
func (l *loginRateLimiter) Reset(email string) {
	key := strings.ToLower(strings.TrimSpace(email))
	if key == "" {
		return
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	delete(l.failures, key)
}

// ── Resend-verify cooldown ───────────────────────────────────────────────

// resendCooldownTracker enforces "no more than one resend per 60 seconds"
// per user. Keyed by user_id (not email) so a learner who changes email
// still gets their cooldown reset along with the new pending verify.
type resendCooldownTracker struct {
	mu       sync.Mutex
	last     map[string]time.Time
	cooldown time.Duration
	now      func() time.Time
}

// newResendCooldownTracker returns a 60s-per-user cooldown.
func newResendCooldownTracker() *resendCooldownTracker {
	return &resendCooldownTracker{
		last:     map[string]time.Time{},
		cooldown: 60 * time.Second,
		now:      time.Now,
	}
}

// Allow reports whether the user can request a resend right now and, if
// not, how long until they can. Must be combined with MarkSent to record
// the dispatch — separating the two lets the handler avoid burning the
// cooldown when the email send itself fails synchronously.
func (t *resendCooldownTracker) Allow(userID string) (bool, time.Duration) {
	if userID == "" {
		return false, 0
	}
	t.mu.Lock()
	defer t.mu.Unlock()
	last, ok := t.last[userID]
	if !ok {
		return true, 0
	}
	elapsed := t.now().Sub(last)
	if elapsed >= t.cooldown {
		return true, 0
	}
	return false, t.cooldown - elapsed
}

// MarkSent records a successful dispatch so the next Allow call enforces
// the cooldown.
func (t *resendCooldownTracker) MarkSent(userID string) {
	if userID == "" {
		return
	}
	t.mu.Lock()
	defer t.mu.Unlock()
	t.last[userID] = t.now()
}

// pruneLocked drops timestamps older than the window. Must be called with
// the lock held.
func (l *loginRateLimiter) pruneLocked(key string) {
	cutoff := l.now().Add(-l.window)
	src := l.failures[key]
	keep := src[:0]
	for _, t := range src {
		if t.After(cutoff) {
			keep = append(keep, t)
		}
	}
	if len(keep) == 0 {
		delete(l.failures, key)
		return
	}
	l.failures[key] = keep
}
