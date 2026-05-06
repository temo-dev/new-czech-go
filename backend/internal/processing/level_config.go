package processing

// level_config.go — V21 CEFR level progression tunables.
//
// Sibling to processing_config.go (mastery aggregate config) and
// llm_config.go (model IDs/endpoints): this file owns every env var that
// configures the level gating service (V21-B3) and the placement-band
// mapping (V21-B5). Per AGENTS.md "single source of truth" rule, no other
// file in the backend reads LEVEL_* env vars.
//
// Defaults match docs/specs/cefr-level-progression.md § "Configuration".

import (
	"encoding/json"
	"log"
	"os"
	"sort"
	"strconv"
	"strings"
)

// LevelConfig captures every tunable consumed by the level gating service.
// Values are pcts in [0, 100] (not unit), to match the V19 mastery rows that
// already store percentages on the wire and to keep the spec's "≥70%" copy
// directly readable.
type LevelConfig struct {
	// MasteryThresholdPct is the per-skill mastery floor that the learner
	// must clear (across every skill) for the promotion exam to unlock.
	MasteryThresholdPct float64

	// CoverageThresholdPct is the % of modules in the current-level course
	// the learner must have at least one attempt in. Prevents farming a
	// single skill to unlock promotion.
	CoverageThresholdPct float64

	// PromotionPassPct is the per-section score required to pass a
	// promotion exam. Default mirrors the Czech state exam threshold.
	PromotionPassPct float64

	// PromotionCooldownHours is the wait between failed promotion
	// attempts on the same target level.
	PromotionCooldownHours int

	// DemoExercisePerLevel is how many demo exercises a learner can see
	// (no mastery write) inside a locked upper-level course.
	DemoExercisePerLevel int

	// AllowB1Placement controls whether the placement test can land a
	// learner directly on B1. V21 ships with this off because B1 content
	// has not been authored yet.
	AllowB1Placement bool

	// placementBands map a numeric placement score → assigned level.
	// Sorted ascending by MinScore on load.
	placementBands []placementBand
}

// placementBand is a half-open band: [MinScore, next.MinScore) → Level.
type placementBand struct {
	MinScore float64 `json:"min_score"`
	Level    string  `json:"level"`
}

// defaultPlacementBands matches the spec table:
//   <30 → a0; 30–54 → a1; 55–74 → a2; ≥75 → b1 (capped to a2 when
//   AllowB1Placement is false).
var defaultPlacementBands = []placementBand{
	{MinScore: 0, Level: "a0"},
	{MinScore: 30, Level: "a1"},
	{MinScore: 55, Level: "a2"},
	{MinScore: 75, Level: "b1"},
}

// LevelFromPlacementScore returns the assigned level for a numeric placement
// score (0–100). The score is matched to the largest band whose MinScore
// is ≤ score; if AllowB1Placement is false, any "b1" assignment is capped
// down to "a2".
func (c LevelConfig) LevelFromPlacementScore(score float64) string {
	bands := c.placementBands
	if len(bands) == 0 {
		bands = defaultPlacementBands
	}
	level := bands[0].Level
	for _, b := range bands {
		if score >= b.MinScore {
			level = b.Level
		}
	}
	if level == "b1" && !c.AllowB1Placement {
		return "a2"
	}
	return level
}

// LoadLevelConfig resolves LevelConfig from environment variables with
// fallback defaults. Call once at server boot; pass the result to consumers
// rather than re-reading env in hot paths.
//
// Hardening:
//   - Pct values clamp to [0, 100]; negative inputs become 0 and >100 cap.
//   - Counts clamp to ≥0 so a typo cannot make the cooldown negative or
//     advertise -1 demo exercises.
//   - Malformed LEVEL_PLACEMENT_BANDS_JSON falls back to defaults with a
//     log warning so the placement test still works.
func LoadLevelConfig() LevelConfig {
	cfg := LevelConfig{
		MasteryThresholdPct:    clampPct(envFloat("LEVEL_MASTERY_THRESHOLD_PCT", 70.0)),
		CoverageThresholdPct:   clampPct(envFloat("LEVEL_COVERAGE_THRESHOLD_PCT", 80.0)),
		PromotionPassPct:       clampPct(envFloat("LEVEL_PROMOTION_PASS_PCT", 60.0)),
		PromotionCooldownHours: clampNonNegative(envInt("LEVEL_PROMOTION_COOLDOWN_HOURS", 24)),
		DemoExercisePerLevel:   clampNonNegative(envInt("LEVEL_DEMO_EXERCISE_PER_LEVEL", 1)),
		AllowB1Placement:       envBool("LEVEL_PLACEMENT_ALLOW_B1", false),
		placementBands:         loadPlacementBands(),
	}
	return cfg
}

func loadPlacementBands() []placementBand {
	raw := strings.TrimSpace(os.Getenv("LEVEL_PLACEMENT_BANDS_JSON"))
	if raw == "" {
		return append([]placementBand(nil), defaultPlacementBands...)
	}
	var parsed []placementBand
	if err := json.Unmarshal([]byte(raw), &parsed); err != nil {
		log.Printf("warning: LEVEL_PLACEMENT_BANDS_JSON malformed (%v); using defaults", err)
		return append([]placementBand(nil), defaultPlacementBands...)
	}
	if len(parsed) == 0 {
		log.Printf("warning: LEVEL_PLACEMENT_BANDS_JSON empty; using defaults")
		return append([]placementBand(nil), defaultPlacementBands...)
	}
	// Sort ascending by MinScore so the linear scan in
	// LevelFromPlacementScore is well-defined for any band order in JSON.
	sort.Slice(parsed, func(i, j int) bool { return parsed[i].MinScore < parsed[j].MinScore })
	return parsed
}

func clampPct(v float64) float64 {
	if v < 0 {
		return 0
	}
	if v > 100 {
		return 100
	}
	return v
}

func clampNonNegative(n int) int {
	if n < 0 {
		return 0
	}
	return n
}

func envBool(key string, fallback bool) bool {
	v := strings.TrimSpace(os.Getenv(key))
	if v == "" {
		return fallback
	}
	b, err := strconv.ParseBool(v)
	if err != nil {
		log.Printf("warning: %s=%q is not a valid bool; using default %v", key, v, fallback)
		return fallback
	}
	return b
}
