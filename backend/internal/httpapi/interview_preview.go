package httpapi

import (
	"encoding/json"
	"net/http"
	"sync"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/processing"
)

const interviewPreviewRateLimit = 30 // requests per minute per admin

// interviewPreviewLimiter is a simple per-admin-per-minute counter. It mirrors
// aiImageRateLimiter but with a higher cap because admins type into the
// CMS preview field interactively.
type interviewPreviewLimiter struct {
	mu      sync.Mutex
	windows map[string]rateWindow
}

func newInterviewPreviewLimiter() *interviewPreviewLimiter {
	return &interviewPreviewLimiter{windows: make(map[string]rateWindow)}
}

func (rl *interviewPreviewLimiter) allow(email string) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	now := time.Now()
	w := rl.windows[email]
	if now.After(w.windowEnd) {
		rl.windows[email] = rateWindow{count: 1, windowEnd: now.Add(time.Minute)}
		return true
	}
	if w.count >= interviewPreviewRateLimit {
		return false
	}
	w.count++
	rl.windows[email] = w
	return true
}

// handleAdminInterviewPreviewPrompt serves POST /v1/admin/interview/preview-prompt.
// Returns the learner-facing display_prompt derived from the supplied
// system_prompt so the CMS can render a live preview while admins author
// interview exercises.
func (s *Server) handleAdminInterviewPreviewPrompt(w http.ResponseWriter, r *http.Request, user contracts.User) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}

	if !s.interviewPreviewRL.allow(user.Email) {
		writeError(w, http.StatusTooManyRequests, "rate_limited",
			"Rate limit exceeded for interview prompt preview.", false)
		return
	}

	var req struct {
		SystemPrompt string `json:"system_prompt"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "validation_error", "Invalid JSON body.", false)
		return
	}

	derived := processing.DerivePromptForLearner(req.SystemPrompt)
	writeJSON(w, http.StatusOK, map[string]any{
		"data": map[string]any{
			"display_prompt": derived,
		},
		"meta": map[string]any{},
	})
}
