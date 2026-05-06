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
	"log"
	"os"
	"strconv"
	"strings"
)

// MasteryConfig captures every tunable consumed by the user_skill_mastery
// aggregate and the GET /v1/users/me/progress handler.
//
// Naming note: each Band* field is the *floor* (lower inclusive bound) of the
// band it names — `BandLearning = 0.40` means "mastery in [0.40, 0.70) is the
// learning band". The wire shape (`bands.needs_work`) reverses this convention
// and labels each value by the band that ENDS at it, so the API mapping in
// progress_handler.bandsFromConfig deliberately renames fields.
type MasteryConfig struct {
	// Band floors. mastery < BandLearning → "needs_work";
	// [BandLearning, BandSolid) → "learning"; [BandSolid, BandReady) → "solid";
	// ≥ BandReady → "ready". Values must satisfy 0 ≤ BandLearning ≤ BandSolid
	// ≤ BandReady ≤ 1; LoadMasteryConfig clamps and re-orders if a misconfig
	// produces a violation.
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
//
// Hardening:
//   - Band floors are clamped to [0, 1] and re-ordered if a misconfig leaves
//     them non-monotonic (so a typo can't return NaN bands or break
//     BandFromMastery).
//   - Weights are clamped to [0, 100]; negative weights would otherwise
//     corrupt weightedOverall in the progress handler.
//   - Env parse errors fall back to the default but log a warning so the
//     operator can spot the typo instead of silently shipping defaults.
func LoadMasteryConfig() MasteryConfig {
	cfg := MasteryConfig{
		BandLearning: clampUnit(envFloat("MASTERY_BAND_LEARNING", 0.40)),
		BandSolid:    clampUnit(envFloat("MASTERY_BAND_SOLID", 0.70)),
		BandReady:    clampUnit(envFloat("MASTERY_BAND_READY", 0.85)),

		EarlyAttemptCap: 3,
		EarlyAlpha:      0.5,
		SteadyAlpha:     0.3,

		weights: map[string]int{
			"noi":       clampWeight(envInt("MASTERY_OVERALL_NOI", 25)),
			"viet":      clampWeight(envInt("MASTERY_OVERALL_VIET", 20)),
			"nghe":      clampWeight(envInt("MASTERY_OVERALL_NGHE", 20)),
			"doc":       clampWeight(envInt("MASTERY_OVERALL_DOC", 20)),
			"ngu_phap":  clampWeight(envInt("MASTERY_OVERALL_NGU_PHAP", 10)),
			"tu_vung":   clampWeight(envInt("MASTERY_OVERALL_TU_VUNG", 5)),
			"interview": clampWeight(envInt("MASTERY_OVERALL_INTERVIEW", 0)),
		},
	}

	// Restore monotonic order if the operator entered floors out of sequence;
	// BandFromMastery relies on BandLearning ≤ BandSolid ≤ BandReady to
	// classify correctly.
	if cfg.BandLearning > cfg.BandSolid {
		log.Printf("warning: MASTERY_BAND_LEARNING (%v) > MASTERY_BAND_SOLID (%v); swapping",
			cfg.BandLearning, cfg.BandSolid)
		cfg.BandLearning, cfg.BandSolid = cfg.BandSolid, cfg.BandLearning
	}
	if cfg.BandSolid > cfg.BandReady {
		log.Printf("warning: MASTERY_BAND_SOLID (%v) > MASTERY_BAND_READY (%v); swapping",
			cfg.BandSolid, cfg.BandReady)
		cfg.BandSolid, cfg.BandReady = cfg.BandReady, cfg.BandSolid
	}
	return cfg
}

func clampUnit(v float64) float64 {
	if v < 0 {
		return 0
	}
	if v > 1 {
		return 1
	}
	return v
}

func clampWeight(n int) int {
	if n < 0 {
		return 0
	}
	if n > 100 {
		return 100
	}
	return n
}

func envFloat(key string, fallback float64) float64 {
	v := strings.TrimSpace(os.Getenv(key))
	if v == "" {
		return fallback
	}
	f, err := strconv.ParseFloat(v, 64)
	if err != nil {
		log.Printf("warning: %s=%q is not a valid float; using default %v", key, v, fallback)
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
		log.Printf("warning: %s=%q is not a valid int; using default %d", key, v, fallback)
		return fallback
	}
	return n
}
