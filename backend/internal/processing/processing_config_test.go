package processing

import (
	"testing"
)

func TestLoadMasteryConfig_Defaults(t *testing.T) {
	clearMasteryEnv(t)
	cfg := LoadMasteryConfig()

	if cfg.BandLearning != 0.40 {
		t.Errorf("BandLearning default = %v, want 0.40", cfg.BandLearning)
	}
	if cfg.BandSolid != 0.70 {
		t.Errorf("BandSolid default = %v, want 0.70", cfg.BandSolid)
	}
	if cfg.BandReady != 0.85 {
		t.Errorf("BandReady default = %v, want 0.85", cfg.BandReady)
	}

	wantWeights := map[string]int{
		"noi": 25, "viet": 20, "nghe": 20, "doc": 20,
		"ngu_phap": 10, "tu_vung": 5, "interview": 0,
	}
	for skill, want := range wantWeights {
		if got := cfg.OverallWeight(skill); got != want {
			t.Errorf("OverallWeight(%q) default = %d, want %d", skill, got, want)
		}
	}

	if cfg.EarlyAttemptCap != 3 {
		t.Errorf("EarlyAttemptCap = %d, want 3", cfg.EarlyAttemptCap)
	}
	if cfg.EarlyAlpha != 0.5 {
		t.Errorf("EarlyAlpha = %v, want 0.5", cfg.EarlyAlpha)
	}
	if cfg.SteadyAlpha != 0.3 {
		t.Errorf("SteadyAlpha = %v, want 0.3", cfg.SteadyAlpha)
	}
}

func TestLoadMasteryConfig_EnvOverride(t *testing.T) {
	clearMasteryEnv(t)
	t.Setenv("MASTERY_BAND_LEARNING", "0.35")
	t.Setenv("MASTERY_BAND_SOLID", "0.65")
	t.Setenv("MASTERY_BAND_READY", "0.90")
	t.Setenv("MASTERY_OVERALL_NOI", "30")
	t.Setenv("MASTERY_OVERALL_INTERVIEW", "5")

	cfg := LoadMasteryConfig()

	if cfg.BandLearning != 0.35 {
		t.Errorf("BandLearning = %v, want 0.35", cfg.BandLearning)
	}
	if cfg.BandSolid != 0.65 {
		t.Errorf("BandSolid = %v, want 0.65", cfg.BandSolid)
	}
	if cfg.BandReady != 0.90 {
		t.Errorf("BandReady = %v, want 0.90", cfg.BandReady)
	}
	if got := cfg.OverallWeight("noi"); got != 30 {
		t.Errorf("noi weight = %d, want 30", got)
	}
	if got := cfg.OverallWeight("interview"); got != 5 {
		t.Errorf("interview weight = %d, want 5", got)
	}
	// Untouched keys keep defaults.
	if got := cfg.OverallWeight("nghe"); got != 20 {
		t.Errorf("nghe weight = %d, want 20", got)
	}
}

func TestLoadMasteryConfig_BandFromMastery(t *testing.T) {
	clearMasteryEnv(t)
	cfg := LoadMasteryConfig()
	cases := []struct {
		mastery float64
		want    string
	}{
		{0.00, "needs_work"}, // < BandLearning
		{0.39, "needs_work"},
		{0.40, "learning"},
		{0.69, "learning"},
		{0.70, "solid"},
		{0.84, "solid"},
		{0.85, "ready"},
		{1.00, "ready"},
	}
	for _, c := range cases {
		got := cfg.BandFromMastery(c.mastery)
		if got != c.want {
			t.Errorf("BandFromMastery(%v) = %q, want %q", c.mastery, got, c.want)
		}
	}
}

func TestLoadMasteryConfig_OverallWeightUnknownSkill(t *testing.T) {
	clearMasteryEnv(t)
	cfg := LoadMasteryConfig()
	if got := cfg.OverallWeight("not_a_skill"); got != 0 {
		t.Errorf("unknown skill weight = %d, want 0", got)
	}
}

func TestLoadMasteryConfig_ClampsBandsToUnit(t *testing.T) {
	clearMasteryEnv(t)
	t.Setenv("MASTERY_BAND_LEARNING", "-0.5")
	t.Setenv("MASTERY_BAND_READY", "1.5")
	cfg := LoadMasteryConfig()
	if cfg.BandLearning != 0 {
		t.Errorf("negative band floor not clamped: BandLearning=%v", cfg.BandLearning)
	}
	if cfg.BandReady != 1 {
		t.Errorf(">1 band floor not clamped: BandReady=%v", cfg.BandReady)
	}
}

func TestLoadMasteryConfig_ClampsWeightsToRange(t *testing.T) {
	clearMasteryEnv(t)
	t.Setenv("MASTERY_OVERALL_NOI", "-10")
	t.Setenv("MASTERY_OVERALL_VIET", "250")
	cfg := LoadMasteryConfig()
	if got := cfg.OverallWeight("noi"); got != 0 {
		t.Errorf("negative weight not clamped: noi=%d", got)
	}
	if got := cfg.OverallWeight("viet"); got != 100 {
		t.Errorf(">100 weight not clamped: viet=%d", got)
	}
}

func TestLoadMasteryConfig_RestoresMonotonicBands(t *testing.T) {
	clearMasteryEnv(t)
	// Operator entered floors out of order — solid below learning.
	t.Setenv("MASTERY_BAND_LEARNING", "0.80")
	t.Setenv("MASTERY_BAND_SOLID", "0.60")
	t.Setenv("MASTERY_BAND_READY", "0.90")
	cfg := LoadMasteryConfig()
	if cfg.BandLearning > cfg.BandSolid {
		t.Errorf("non-monotonic bands not swapped: learning=%v solid=%v",
			cfg.BandLearning, cfg.BandSolid)
	}
	if cfg.BandSolid > cfg.BandReady {
		t.Errorf("non-monotonic bands: solid=%v ready=%v",
			cfg.BandSolid, cfg.BandReady)
	}
}

func TestLoadMasteryConfig_FallsBackOnInvalidEnv(t *testing.T) {
	clearMasteryEnv(t)
	t.Setenv("MASTERY_BAND_LEARNING", "0,40") // comma decimal — invalid
	t.Setenv("MASTERY_OVERALL_NOI", "twenty-five")
	cfg := LoadMasteryConfig()
	if cfg.BandLearning != 0.40 {
		t.Errorf("invalid band float should fall back to default 0.40, got %v", cfg.BandLearning)
	}
	if got := cfg.OverallWeight("noi"); got != 25 {
		t.Errorf("invalid weight int should fall back to default 25, got %d", got)
	}
}

// clearMasteryEnv unsets every MASTERY_* env var that LoadMasteryConfig reads,
// so a test starts from documented defaults regardless of host environment.
func clearMasteryEnv(t *testing.T) {
	t.Helper()
	keys := []string{
		"MASTERY_BAND_LEARNING", "MASTERY_BAND_SOLID", "MASTERY_BAND_READY",
		"MASTERY_OVERALL_NOI", "MASTERY_OVERALL_VIET", "MASTERY_OVERALL_NGHE",
		"MASTERY_OVERALL_DOC", "MASTERY_OVERALL_NGU_PHAP", "MASTERY_OVERALL_TU_VUNG",
		"MASTERY_OVERALL_INTERVIEW",
	}
	for _, k := range keys {
		t.Setenv(k, "")
	}
}
