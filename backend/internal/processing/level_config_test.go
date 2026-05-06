package processing

import (
	"testing"
)

func TestLoadLevelConfig_Defaults(t *testing.T) {
	clearLevelEnv(t)
	cfg := LoadLevelConfig()

	if cfg.MasteryThresholdPct != 70.0 {
		t.Errorf("MasteryThresholdPct default = %v, want 70.0", cfg.MasteryThresholdPct)
	}
	if cfg.CoverageThresholdPct != 80.0 {
		t.Errorf("CoverageThresholdPct default = %v, want 80.0", cfg.CoverageThresholdPct)
	}
	if cfg.PromotionPassPct != 60.0 {
		t.Errorf("PromotionPassPct default = %v, want 60.0", cfg.PromotionPassPct)
	}
	if cfg.PromotionCooldownHours != 24 {
		t.Errorf("PromotionCooldownHours default = %d, want 24", cfg.PromotionCooldownHours)
	}
	if cfg.DemoExercisePerLevel != 1 {
		t.Errorf("DemoExercisePerLevel default = %d, want 1", cfg.DemoExercisePerLevel)
	}
	if cfg.AllowB1Placement {
		t.Errorf("AllowB1Placement default = true, want false (V21 ships without B1 content)")
	}

	wantBandMap := map[float64]string{
		0:    "a0",
		29.9: "a0",
		30:   "a1",
		54.9: "a1",
		55:   "a2",
		74.9: "a2",
		75:   "a2", // capped from b1 because AllowB1Placement is false by default
		100:  "a2",
	}
	for score, want := range wantBandMap {
		if got := cfg.LevelFromPlacementScore(score); got != want {
			t.Errorf("LevelFromPlacementScore(%v) default = %q, want %q", score, got, want)
		}
	}
}

func TestLoadLevelConfig_EnvOverride(t *testing.T) {
	clearLevelEnv(t)
	t.Setenv("LEVEL_MASTERY_THRESHOLD_PCT", "65")
	t.Setenv("LEVEL_COVERAGE_THRESHOLD_PCT", "75")
	t.Setenv("LEVEL_PROMOTION_PASS_PCT", "55")
	t.Setenv("LEVEL_PROMOTION_COOLDOWN_HOURS", "48")
	t.Setenv("LEVEL_DEMO_EXERCISE_PER_LEVEL", "3")
	t.Setenv("LEVEL_PLACEMENT_ALLOW_B1", "true")

	cfg := LoadLevelConfig()
	if cfg.MasteryThresholdPct != 65.0 {
		t.Errorf("MasteryThresholdPct = %v, want 65.0", cfg.MasteryThresholdPct)
	}
	if cfg.CoverageThresholdPct != 75.0 {
		t.Errorf("CoverageThresholdPct = %v, want 75.0", cfg.CoverageThresholdPct)
	}
	if cfg.PromotionPassPct != 55.0 {
		t.Errorf("PromotionPassPct = %v, want 55.0", cfg.PromotionPassPct)
	}
	if cfg.PromotionCooldownHours != 48 {
		t.Errorf("PromotionCooldownHours = %d, want 48", cfg.PromotionCooldownHours)
	}
	if cfg.DemoExercisePerLevel != 3 {
		t.Errorf("DemoExercisePerLevel = %d, want 3", cfg.DemoExercisePerLevel)
	}
	if !cfg.AllowB1Placement {
		t.Errorf("AllowB1Placement = false, want true with override")
	}
	// With B1 placement allowed, the top band should map to b1.
	if got := cfg.LevelFromPlacementScore(80); got != "b1" {
		t.Errorf("LevelFromPlacementScore(80) with AllowB1Placement = %q, want b1", got)
	}
}

func TestLoadLevelConfig_PlacementBandsJSONOverride(t *testing.T) {
	clearLevelEnv(t)
	// Custom bands shift the boundary between a1 and a2 down to 50.
	t.Setenv("LEVEL_PLACEMENT_ALLOW_B1", "true")
	t.Setenv("LEVEL_PLACEMENT_BANDS_JSON",
		`[{"min_score":0,"level":"a0"},{"min_score":25,"level":"a1"},{"min_score":50,"level":"a2"},{"min_score":80,"level":"b1"}]`)

	cfg := LoadLevelConfig()
	cases := []struct {
		score float64
		want  string
	}{
		{0, "a0"},
		{24.9, "a0"},
		{25, "a1"},
		{49.9, "a1"},
		{50, "a2"},
		{79.9, "a2"},
		{80, "b1"},
		{100, "b1"},
	}
	for _, c := range cases {
		if got := cfg.LevelFromPlacementScore(c.score); got != c.want {
			t.Errorf("LevelFromPlacementScore(%v) custom bands = %q, want %q", c.score, got, c.want)
		}
	}
}

func TestLoadLevelConfig_MalformedBandsJSON(t *testing.T) {
	clearLevelEnv(t)
	// Malformed JSON falls back to defaults so a typo cannot disable the
	// placement test entirely.
	t.Setenv("LEVEL_PLACEMENT_BANDS_JSON", `not really json {{`)
	cfg := LoadLevelConfig()

	// Default bands should still classify correctly.
	if got := cfg.LevelFromPlacementScore(0); got != "a0" {
		t.Errorf("LevelFromPlacementScore(0) after malformed JSON = %q, want a0", got)
	}
	if got := cfg.LevelFromPlacementScore(50); got != "a1" {
		t.Errorf("LevelFromPlacementScore(50) after malformed JSON = %q, want a1", got)
	}

	// Empty-array JSON is also malformed (we need at least one band) — fallback applies.
	t.Setenv("LEVEL_PLACEMENT_BANDS_JSON", `[]`)
	cfg2 := LoadLevelConfig()
	if got := cfg2.LevelFromPlacementScore(60); got != "a2" {
		t.Errorf("LevelFromPlacementScore(60) after empty-array JSON = %q, want a2", got)
	}
}

func TestLoadLevelConfig_NegativeAndOOBValuesClamped(t *testing.T) {
	clearLevelEnv(t)
	t.Setenv("LEVEL_MASTERY_THRESHOLD_PCT", "-10")
	t.Setenv("LEVEL_COVERAGE_THRESHOLD_PCT", "150")
	t.Setenv("LEVEL_PROMOTION_PASS_PCT", "200")
	t.Setenv("LEVEL_PROMOTION_COOLDOWN_HOURS", "-3")
	t.Setenv("LEVEL_DEMO_EXERCISE_PER_LEVEL", "-1")

	cfg := LoadLevelConfig()
	// Pcts clamp to [0, 100]; ints clamp to ≥0.
	if cfg.MasteryThresholdPct != 0 {
		t.Errorf("MasteryThresholdPct clamp = %v, want 0", cfg.MasteryThresholdPct)
	}
	if cfg.CoverageThresholdPct != 100 {
		t.Errorf("CoverageThresholdPct clamp = %v, want 100", cfg.CoverageThresholdPct)
	}
	if cfg.PromotionPassPct != 100 {
		t.Errorf("PromotionPassPct clamp = %v, want 100", cfg.PromotionPassPct)
	}
	if cfg.PromotionCooldownHours != 0 {
		t.Errorf("PromotionCooldownHours clamp = %d, want 0", cfg.PromotionCooldownHours)
	}
	if cfg.DemoExercisePerLevel != 0 {
		t.Errorf("DemoExercisePerLevel clamp = %d, want 0", cfg.DemoExercisePerLevel)
	}
}

// clearLevelEnv unsets every LEVEL_* env var read by LoadLevelConfig so each
// test starts from defaults. t.Setenv lifetimes auto-restore on test end.
func clearLevelEnv(t *testing.T) {
	t.Helper()
	for _, k := range []string{
		"LEVEL_MASTERY_THRESHOLD_PCT",
		"LEVEL_COVERAGE_THRESHOLD_PCT",
		"LEVEL_PROMOTION_PASS_PCT",
		"LEVEL_PROMOTION_COOLDOWN_HOURS",
		"LEVEL_DEMO_EXERCISE_PER_LEVEL",
		"LEVEL_PLACEMENT_ALLOW_B1",
		"LEVEL_PLACEMENT_BANDS_JSON",
	} {
		t.Setenv(k, "")
	}
}
