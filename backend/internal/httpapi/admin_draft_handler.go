package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/processing"
)

// V24 admin reading-draft generator. See docs/specs/v24-doc-draft-generator.md.

const (
	readingDraftRateLimit  = 5 // max requests per minute per admin
	readingDraftMinTopic   = 3
	readingDraftMaxTopic   = 200
	readingDraftMaxExtra   = 500
	readingDraftMinGrammar = 1
	readingDraftMaxGrammar = 3
)

// readingDraftTimeout caps the per-call LLM request. var (not const) so the
// timeout test in admin_draft_handler_test.go can shorten it.
var readingDraftTimeout = 30 * time.Second

// readingDraftTestTimeout overrides readingDraftTimeout for tests. Returns the
// previous value so the test can restore it via t.Cleanup.
func readingDraftTestTimeout(d time.Duration) time.Duration {
	prev := readingDraftTimeout
	readingDraftTimeout = d
	return prev
}

// readingDraftRateLimiter — same algorithm as aiImageRateLimiter; kept
// separate so the two endpoints have independent windows.
type readingDraftRateLimiter struct {
	mu      sync.Mutex
	windows map[string]rateWindow
}

func newReadingDraftRateLimiter() *readingDraftRateLimiter {
	return &readingDraftRateLimiter{windows: make(map[string]rateWindow)}
}

func (rl *readingDraftRateLimiter) allow(email string) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	now := time.Now()
	w := rl.windows[email]
	if now.After(w.windowEnd) {
		rl.windows[email] = rateWindow{count: 1, windowEnd: now.Add(time.Minute)}
		return true
	}
	if w.count >= readingDraftRateLimit {
		return false
	}
	w.count++
	rl.windows[email] = w
	return true
}

var validReadingExerciseTypes = map[string]bool{
	"cteni_1": true, "cteni_2": true, "cteni_3": true,
	"cteni_4": true, "cteni_5": true, "cteni_6": true,
}

var validReadingLevels = map[string]bool{
	"A0": true, "A1": true, "A2": true, "B1": true,
}

// handleAdminGenerateDraft serves POST /v1/admin/exercises/generate-draft.
// Body: {exercise_type, topic, grammar_point_ids[], level, extra_instructions}.
// Returns {data: ReadingDraft} on 200; see spec §3 for error codes.
func (s *Server) handleAdminGenerateDraft(w http.ResponseWriter, r *http.Request, user contracts.User) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}
	if s.readingDraftGenerator == nil {
		writeError(w, http.StatusServiceUnavailable, "not_configured",
			"Reading draft generator not configured (ANTHROPIC_API_KEY missing).", false)
		return
	}

	var req struct {
		ExerciseType      string   `json:"exercise_type"`
		Topic             string   `json:"topic"`
		GrammarPointIDs   []string `json:"grammar_point_ids"`
		Level             string   `json:"level"`
		ExtraInstructions string   `json:"extra_instructions"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "Invalid JSON body.", false)
		return
	}

	if !validReadingExerciseTypes[req.ExerciseType] {
		writeError(w, http.StatusBadRequest, "invalid_request",
			"exercise_type must be one of cteni_1..cteni_6.", false)
		return
	}
	topic := strings.TrimSpace(req.Topic)
	if len(topic) < readingDraftMinTopic || len(topic) > readingDraftMaxTopic {
		writeError(w, http.StatusBadRequest, "invalid_request",
			fmt.Sprintf("topic must be %d-%d characters.", readingDraftMinTopic, readingDraftMaxTopic), false)
		return
	}
	if n := len(req.GrammarPointIDs); n < readingDraftMinGrammar || n > readingDraftMaxGrammar {
		writeError(w, http.StatusBadRequest, "invalid_request",
			fmt.Sprintf("grammar_point_ids must contain %d-%d ids.", readingDraftMinGrammar, readingDraftMaxGrammar), false)
		return
	}
	if !validReadingLevels[req.Level] {
		writeError(w, http.StatusBadRequest, "invalid_request",
			"level must be one of A0, A1, A2, B1.", false)
		return
	}
	extra := strings.TrimSpace(req.ExtraInstructions)
	if len(extra) > readingDraftMaxExtra {
		writeError(w, http.StatusBadRequest, "invalid_request",
			fmt.Sprintf("extra_instructions must be ≤%d characters.", readingDraftMaxExtra), false)
		return
	}

	grammarPoints := make([]contracts.GrammarRule, 0, len(req.GrammarPointIDs))
	for _, id := range req.GrammarPointIDs {
		rule, ok := s.repo.GetGrammarRule(strings.TrimSpace(id))
		if !ok {
			writeError(w, http.StatusNotFound, "grammar_point_not_found",
				fmt.Sprintf("grammar_point id %q not found.", id), false)
			return
		}
		grammarPoints = append(grammarPoints, rule)
	}

	if !s.readingDraftRL.allow(user.Email) {
		writeError(w, http.StatusTooManyRequests, "rate_limited",
			fmt.Sprintf("Rate limit: %d requests per minute exceeded. Try again shortly.", readingDraftRateLimit), false)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), readingDraftTimeout)
	defer cancel()

	draft, err := s.readingDraftGenerator.Generate(ctx, contracts.ReadingDraftInput{
		ExerciseType:      req.ExerciseType,
		Topic:             topic,
		GrammarPoints:     grammarPoints,
		Level:             req.Level,
		ExtraInstructions: extra,
	})
	if err != nil {
		if errors.Is(ctx.Err(), context.DeadlineExceeded) {
			writeError(w, http.StatusGatewayTimeout, "timeout",
				"Generation timed out after 30 seconds.", true)
			return
		}
		log.Printf("admin generate-draft: %v", err)
		writeError(w, http.StatusBadGateway, "llm_error",
			"AI generator failed: "+err.Error(), true)
		return
	}

	if err := processing.ValidateReadingDraft(draft); err != nil {
		log.Printf("admin generate-draft: schema validation failed: %v", err)
		writeError(w, http.StatusUnprocessableEntity, "schema_mismatch",
			"AI returned invalid output: "+err.Error(), true)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{"data": draft})
}
