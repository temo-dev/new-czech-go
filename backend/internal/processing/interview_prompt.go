package processing

import (
	"encoding/json"
	"regexp"
	"strings"
)

// audioBufferTimeout bounds (V16). The lower bound keeps the fallback
// reactive on slow networks; the upper bound prevents indefinite drops.
const (
	audioBufferTimeoutDefaultMs = 1500
	audioBufferTimeoutMinMs     = 500
	audioBufferTimeoutMaxMs     = 5000
)

var (
	taskBlockRegex = regexp.MustCompile(`(?is)(?:ÚKOL|TASK|Task|Đề bài|Đề)\s*:\s*\n?(.+?)(?:\n\s*\n|\z)`)

	instructionPrefixRegex = regexp.MustCompile(`(?im)^\s*(You are|Act as|Pretend|Bạn là|Hãy đóng vai|You're)[^.\n]*\.\s*`)
)

// DerivePromptForLearner extracts learner-facing task description from the
// LLM system_prompt. Examiner instructions ("You are...", "Act as...") are
// stripped. The {selected_option} placeholder is removed since the choice
// variant injects option text via a separate UI affordance.
//
// Returns an empty string when no usable task block is found, in which case
// the frontend hides the prompt card rather than showing examiner-facing copy.
func DerivePromptForLearner(systemPrompt string) string {
	s := strings.TrimSpace(systemPrompt)
	if s == "" {
		return ""
	}

	if m := taskBlockRegex.FindStringSubmatch(s); len(m) > 1 {
		return cleanPromptText(m[1])
	}

	cleaned := instructionPrefixRegex.ReplaceAllString(s, "")
	parts := strings.SplitN(strings.TrimSpace(cleaned), "\n\n", 2)
	if len(parts) > 0 {
		return cleanPromptText(parts[0])
	}
	return ""
}

func cleanPromptText(s string) string {
	s = strings.TrimSpace(s)
	s = strings.ReplaceAll(s, "{selected_option}", "")
	s = strings.TrimSpace(s)
	return s
}

// ClampAudioBufferTimeoutMs returns a value within [500, 5000]. Zero or
// negative inputs use the 1500ms default.
func ClampAudioBufferTimeoutMs(ms int) int {
	if ms <= 0 {
		return audioBufferTimeoutDefaultMs
	}
	if ms < audioBufferTimeoutMinMs {
		return audioBufferTimeoutMinMs
	}
	if ms > audioBufferTimeoutMaxMs {
		return audioBufferTimeoutMaxMs
	}
	return ms
}

// EnrichInterviewDetail derives display_prompt and clamps audio_buffer_timeout_ms
// on an interview exercise detail before it is returned to clients.
//
// The detail may be either a typed struct (after admin create) or a
// map[string]any (after retrieval from DB). The function returns a value of
// the same kind with the V16 fields populated.
func EnrichInterviewDetail(detail any) any {
	if detail == nil {
		return detail
	}

	// Round-trip through JSON to normalise into map[string]any. The exercise
	// store can hand us either a typed struct (admin path) or a generic map
	// (DB load path), and we want one code path either way.
	raw, err := json.Marshal(detail)
	if err != nil {
		return detail
	}
	var m map[string]any
	if err := json.Unmarshal(raw, &m); err != nil || m == nil {
		return detail
	}

	systemPrompt, _ := m["system_prompt"].(string)
	derived := DerivePromptForLearner(systemPrompt)
	if derived != "" {
		m["display_prompt"] = derived
	} else {
		delete(m, "display_prompt")
	}

	timeout := 0
	switch v := m["audio_buffer_timeout_ms"].(type) {
	case float64:
		timeout = int(v)
	case int:
		timeout = v
	case json.Number:
		if n, err := v.Int64(); err == nil {
			timeout = int(n)
		}
	}
	m["audio_buffer_timeout_ms"] = ClampAudioBufferTimeoutMs(timeout)

	return m
}
