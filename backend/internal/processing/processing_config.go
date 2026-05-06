package processing

// processing_config.go — Non-LLM runtime config for the processing layer.
//
// Sibling to llm_config.go: where llm_config.go owns model IDs / endpoints /
// timeouts for AI providers, this file owns mastery aggregate tunables
// (band thresholds, per-skill weights, EMA smoothing constants).
//
// All values are env-overridable (see field comments). Defaults match
// docs/specs/skill-mastery-progress.md § "Configuration".

import (
	"os"
	"strconv"
	"strings"
)

// MasteryConfig captures every tunable consumed by the user_skill_mastery
// aggregate and the GET /v1/users/me/progress handler.
type MasteryConfig struct {
	// Band thresholds. mastery < BandLearning → "needs_work";
	// < BandSolid → "learning"; < BandReady → "solid"; ≥ BandReady → "ready".
	BandLearning float64
	BandSolid    float64
	BandReady    float64

	// EMA smoothing.
	//   attempts_count <= EarlyAttemptCap  → new = old*(1-EarlyAlpha)  + score*EarlyAlpha
	//   attempts_count >  EarlyAttemptCap  → new = old*(1-SteadyAlpha) + score*SteadyAlpha
	// First attempt always sets mastery directly (no smoothing) — see Updater.
	EarlyAttemptCap int
	EarlyAlpha      float64
	SteadyAlpha     float64

	// Per-skill_kind weights (0–100) used to compute overall_progress. Weights
	// are normalised on read; zero excludes the skill from the overall.
	weights map[string]int
}

// OverallWeight returns the configured percentage weight for a skill_kind.
// Unknown skills return 0 (excluded from overall_progress).
func (c MasteryConfig) OverallWeight(skillKind string) int {
	if c.weights == nil {
		return 0
	}
	return c.weights[skillKind]
}

// Weights returns a copy of the per-skill weight map. Used by the progress
// handler to surface tuning to clients (so Flutter never has to guess defaults).
func (c MasteryConfig) Weights() map[string]int {
	out := make(map[string]int, len(c.weights))
	for k, v := range c.weights {
		out[k] = v
	}
	return out
}

// BandFromMastery maps an EMA mastery score to the canonical band label
// returned alongside each row in the progress endpoint.
func (c MasteryConfig) BandFromMastery(mastery float64) string {
	switch {
	case mastery >= c.BandReady:
		return "ready"
	case mastery >= c.BandSolid:
		return "solid"
	case mastery >= c.BandLearning:
		return "learning"
	default:
		return "needs_work"
	}
}

// LoadMasteryConfig resolves MasteryConfig from environment variables with
// fallback defaults. Call once at server boot; pass the result to consumers
// rather than calling this in hot paths.
func LoadMasteryConfig() MasteryConfig {
	return MasteryConfig{
		BandLearning: envFloat("MASTERY_BAND_LEARNING", 0.40),
		BandSolid:    envFloat("MASTERY_BAND_SOLID", 0.70),
		BandReady:    envFloat("MASTERY_BAND_READY", 0.85),

		EarlyAttemptCap: 3,
		EarlyAlpha:      0.5,
		SteadyAlpha:     0.3,

		weights: map[string]int{
			"noi":       envInt("MASTERY_OVERALL_NOI", 25),
			"viet":      envInt("MASTERY_OVERALL_VIET", 20),
			"nghe":      envInt("MASTERY_OVERALL_NGHE", 20),
			"doc":       envInt("MASTERY_OVERALL_DOC", 20),
			"ngu_phap":  envInt("MASTERY_OVERALL_NGU_PHAP", 10),
			"tu_vung":   envInt("MASTERY_OVERALL_TU_VUNG", 5),
			"interview": envInt("MASTERY_OVERALL_INTERVIEW", 0),
		},
	}
}

func envFloat(key string, fallback float64) float64 {
	v := strings.TrimSpace(os.Getenv(key))
	if v == "" {
		return fallback
	}
	f, err := strconv.ParseFloat(v, 64)
	if err != nil {
		return fallback
	}
	return f
}

func envInt(key string, fallback int) int {
	v := strings.TrimSpace(os.Getenv(key))
	if v == "" {
		return fallback
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		return fallback
	}
	return n
}
