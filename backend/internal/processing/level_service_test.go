package processing

import (
	"reflect"
	"sort"
	"testing"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// stubMasteryReader / stubUserLevelReader / stubPromoReader are minimal
// fakes that satisfy the read-only deps the LevelService consumes.

type stubMasteryReader struct {
	rows []contracts.SkillMasteryRow
}

func (s stubMasteryReader) ListForUser(userID string) []contracts.SkillMasteryRow {
	out := make([]contracts.SkillMasteryRow, 0, len(s.rows))
	for _, r := range s.rows {
		if r.UserID == userID {
			out = append(out, r)
		}
	}
	return out
}

type stubUserLevelReader struct{ row contracts.UserLevel }

func (s stubUserLevelReader) GetUserLevel(userID string) (contracts.UserLevel, bool) {
	if s.row.UserID == "" {
		return contracts.UserLevel{
			UserID:         userID,
			CurrentLevel:   "a0",
			UnlockedLevels: []string{"a0"},
		}, false
	}
	return s.row, true
}

type stubPromoReader struct{ latestFailed *contracts.PromotionAttempt }

func (s stubPromoReader) GetLatestFailedAttempt(userID, target string) (contracts.PromotionAttempt, bool) {
	if s.latestFailed == nil {
		return contracts.PromotionAttempt{}, false
	}
	return *s.latestFailed, true
}

// allSkillsPassingRows seeds 6 mastery rows (one per expected skill) all
// at score 0.80 — well above the default 70% gate.
func allSkillsPassingRows(userID string, when time.Time) []contracts.SkillMasteryRow {
	out := make([]contracts.SkillMasteryRow, 0, 6)
	for _, k := range []string{"noi", "viet", "nghe", "doc", "tu_vung", "ngu_phap"} {
		out = append(out, contracts.SkillMasteryRow{
			UserID: userID, SkillKind: k, ModuleID: "m1",
			MasteryScore: 0.80, AttemptsCount: 5, LastAttemptAt: when,
		})
	}
	return out
}

func newServiceWith(cfg LevelConfig, userLevel contracts.UserLevel, mastery []contracts.SkillMasteryRow, latestFailed *contracts.PromotionAttempt) *LevelService {
	return &LevelService{
		Config:        cfg,
		Mastery:       stubMasteryReader{rows: mastery},
		UserLevels:    stubUserLevelReader{row: userLevel},
		PromoAttempts: stubPromoReader{latestFailed: latestFailed},
		Now:           func() time.Time { return time.Date(2026, 5, 7, 12, 0, 0, 0, time.UTC) },
	}
}

func TestLevelService_ComputeLevelProgress_FreshUser(t *testing.T) {
	clearLevelEnv(t)
	cfg := LoadLevelConfig()
	svc := newServiceWith(cfg, contracts.UserLevel{
		UserID: "u_fresh", CurrentLevel: "a0", UnlockedLevels: []string{"a0"},
	}, nil, nil)

	got, err := svc.ComputeLevelProgress("u_fresh")
	if err != nil {
		t.Fatalf("ComputeLevelProgress: %v", err)
	}
	if got.CurrentLevel != "a0" {
		t.Errorf("CurrentLevel = %q, want a0", got.CurrentLevel)
	}
	if got.NextLevel != "a1" {
		t.Errorf("NextLevel = %q, want a1", got.NextLevel)
	}
	if got.AllSkillsPass {
		t.Errorf("AllSkillsPass = true with no mastery rows, want false")
	}
	if got.PromotionUnlocked {
		t.Errorf("PromotionUnlocked = true, want false (no mastery)")
	}
	if got.CoveragePct != 0 {
		t.Errorf("CoveragePct = %v, want 0", got.CoveragePct)
	}
	if len(got.SkillMastery) == 0 {
		t.Error("SkillMastery should contain entries for every expected skill")
	}
	for _, info := range got.SkillMastery {
		if info.Pct != 0 || info.Passes {
			t.Errorf("fresh user skill = %+v, want zero+not-passing", info)
		}
		if info.ThresholdPct != cfg.MasteryThresholdPct {
			t.Errorf("ThresholdPct = %v, want %v", info.ThresholdPct, cfg.MasteryThresholdPct)
		}
	}
}

func TestLevelService_ComputeLevelProgress_AllSkillsPass_Unlocked(t *testing.T) {
	clearLevelEnv(t)
	cfg := LoadLevelConfig()
	when := time.Date(2026, 5, 1, 0, 0, 0, 0, time.UTC)

	svc := newServiceWith(cfg, contracts.UserLevel{
		UserID: "u_ready", CurrentLevel: "a2", UnlockedLevels: []string{"a0", "a1", "a2"},
	}, allSkillsPassingRows("u_ready", when), nil)

	got, err := svc.ComputeLevelProgress("u_ready")
	if err != nil {
		t.Fatalf("ComputeLevelProgress: %v", err)
	}
	if !got.AllSkillsPass {
		t.Errorf("AllSkillsPass = false, want true (all skills 80%% above 70%%)")
	}
	if got.CoveragePct < cfg.CoverageThresholdPct {
		t.Errorf("CoveragePct = %v, want ≥ %v", got.CoveragePct, cfg.CoverageThresholdPct)
	}
	if !got.PromotionUnlocked {
		t.Errorf("PromotionUnlocked = false, want true (all gates pass + no cooldown)")
	}
	if got.NextLevel != "b1" {
		t.Errorf("NextLevel = %q, want b1 (a2 → b1)", got.NextLevel)
	}
}

func TestLevelService_ComputeLevelProgress_OneSkillBelowThreshold_Locked(t *testing.T) {
	clearLevelEnv(t)
	cfg := LoadLevelConfig()
	rows := allSkillsPassingRows("u_x", time.Date(2026, 5, 1, 0, 0, 0, 0, time.UTC))
	// Drop one skill below the gate.
	for i := range rows {
		if rows[i].SkillKind == "viet" {
			rows[i].MasteryScore = 0.50 // 50% — below 70% gate
		}
	}
	svc := newServiceWith(cfg, contracts.UserLevel{
		UserID: "u_x", CurrentLevel: "a2", UnlockedLevels: []string{"a0", "a1", "a2"},
	}, rows, nil)

	got, err := svc.ComputeLevelProgress("u_x")
	if err != nil {
		t.Fatalf("ComputeLevelProgress: %v", err)
	}
	if got.AllSkillsPass {
		t.Errorf("AllSkillsPass = true, want false (viet below 70%%)")
	}
	if got.PromotionUnlocked {
		t.Errorf("PromotionUnlocked = true, want false")
	}
	if got.SkillMastery["viet"].Passes {
		t.Errorf("viet.Passes = true, want false")
	}
}

func TestLevelService_ComputeLevelProgress_CoverageBelowThreshold_Locked(t *testing.T) {
	clearLevelEnv(t)
	cfg := LoadLevelConfig()
	when := time.Date(2026, 5, 1, 0, 0, 0, 0, time.UTC)
	// Only 4 of 6 skills touched — coverage = 66.7%, below default 80%.
	partial := []contracts.SkillMasteryRow{
		{UserID: "u_partial", SkillKind: "noi", ModuleID: "m1", MasteryScore: 0.85, AttemptsCount: 5, LastAttemptAt: when},
		{UserID: "u_partial", SkillKind: "viet", ModuleID: "m1", MasteryScore: 0.85, AttemptsCount: 5, LastAttemptAt: when},
		{UserID: "u_partial", SkillKind: "nghe", ModuleID: "m1", MasteryScore: 0.85, AttemptsCount: 5, LastAttemptAt: when},
		{UserID: "u_partial", SkillKind: "doc", ModuleID: "m1", MasteryScore: 0.85, AttemptsCount: 5, LastAttemptAt: when},
	}
	svc := newServiceWith(cfg, contracts.UserLevel{
		UserID: "u_partial", CurrentLevel: "a2", UnlockedLevels: []string{"a0", "a1", "a2"},
	}, partial, nil)

	got, err := svc.ComputeLevelProgress("u_partial")
	if err != nil {
		t.Fatalf("ComputeLevelProgress: %v", err)
	}
	if got.CoveragePct >= cfg.CoverageThresholdPct {
		t.Errorf("CoveragePct = %v, want < %v", got.CoveragePct, cfg.CoverageThresholdPct)
	}
	if got.PromotionUnlocked {
		t.Errorf("PromotionUnlocked = true, want false (coverage gap)")
	}
	// Untouched skills should still render with zero pct so the UI can show
	// "missing" tiles instead of dropping them.
	if _, ok := got.SkillMastery["tu_vung"]; !ok {
		t.Error("tu_vung not in SkillMastery; expected zero entry")
	}
}

func TestLevelService_ComputeLevelProgress_CooldownActive_LocksPromotion(t *testing.T) {
	clearLevelEnv(t)
	cfg := LoadLevelConfig()
	now := time.Date(2026, 5, 7, 12, 0, 0, 0, time.UTC)
	failedAt := now.Add(-1 * time.Hour) // 23h cooldown remaining

	svc := newServiceWith(cfg,
		contracts.UserLevel{UserID: "u_cool", CurrentLevel: "a2", UnlockedLevels: []string{"a0", "a1", "a2"}},
		allSkillsPassingRows("u_cool", now.Add(-24*time.Hour)),
		&contracts.PromotionAttempt{
			ID: "pa_1", UserID: "u_cool", TargetLevel: "b1",
			Passed: false, CreatedAt: failedAt,
		},
	)

	got, err := svc.ComputeLevelProgress("u_cool")
	if err != nil {
		t.Fatalf("ComputeLevelProgress: %v", err)
	}
	if !got.AllSkillsPass {
		t.Errorf("AllSkillsPass = false; cooldown test setup expects skills passing")
	}
	if got.PromotionUnlocked {
		t.Errorf("PromotionUnlocked = true, want false (cooldown active)")
	}
	if got.PromotionCooldownUntil == nil {
		t.Fatal("PromotionCooldownUntil = nil, want a timestamp")
	}
	wantUntil := failedAt.Add(time.Duration(cfg.PromotionCooldownHours) * time.Hour)
	if !got.PromotionCooldownUntil.Equal(wantUntil) {
		t.Errorf("PromotionCooldownUntil = %v, want %v", got.PromotionCooldownUntil, wantUntil)
	}
}

func TestLevelService_ComputeLevelProgress_CooldownExpired_Unlocks(t *testing.T) {
	clearLevelEnv(t)
	cfg := LoadLevelConfig()
	now := time.Date(2026, 5, 7, 12, 0, 0, 0, time.UTC)
	failedAt := now.Add(-25 * time.Hour) // outside the 24h window

	svc := newServiceWith(cfg,
		contracts.UserLevel{UserID: "u_thaw", CurrentLevel: "a2", UnlockedLevels: []string{"a0", "a1", "a2"}},
		allSkillsPassingRows("u_thaw", now.Add(-48*time.Hour)),
		&contracts.PromotionAttempt{
			ID: "pa_old", UserID: "u_thaw", TargetLevel: "b1",
			Passed: false, CreatedAt: failedAt,
		},
	)

	got, err := svc.ComputeLevelProgress("u_thaw")
	if err != nil {
		t.Fatalf("ComputeLevelProgress: %v", err)
	}
	if !got.PromotionUnlocked {
		t.Errorf("PromotionUnlocked = false, want true (cooldown expired)")
	}
	if got.PromotionCooldownUntil != nil {
		t.Errorf("PromotionCooldownUntil = %v, want nil for expired cooldown", got.PromotionCooldownUntil)
	}
}

func TestLevelService_ComputeLevelProgress_TopLevelHasNoNext(t *testing.T) {
	clearLevelEnv(t)
	cfg := LoadLevelConfig()
	svc := newServiceWith(cfg,
		contracts.UserLevel{UserID: "u_top", CurrentLevel: "b1", UnlockedLevels: []string{"a0", "a1", "a2", "b1"}},
		allSkillsPassingRows("u_top", time.Date(2026, 5, 1, 0, 0, 0, 0, time.UTC)),
		nil,
	)

	got, err := svc.ComputeLevelProgress("u_top")
	if err != nil {
		t.Fatalf("ComputeLevelProgress: %v", err)
	}
	if got.NextLevel != "" {
		t.Errorf("NextLevel = %q, want empty (top of ladder)", got.NextLevel)
	}
	if got.PromotionUnlocked {
		t.Errorf("PromotionUnlocked = true at top level; want false (nothing to promote to)")
	}
}

func TestLevelService_MapPlacementScoreToLevel_BandEdgesAndB1Cap(t *testing.T) {
	clearLevelEnv(t)
	cfg := LoadLevelConfig()
	svc := newServiceWith(cfg, contracts.UserLevel{}, nil, nil)

	cases := []struct {
		score float64
		want  string
	}{
		{0, "a0"}, {29.9, "a0"},
		{30, "a1"}, {54.9, "a1"},
		{55, "a2"}, {74.9, "a2"},
		{75, "a2"}, // capped from b1 because AllowB1Placement defaults false
		{100, "a2"},
	}
	for _, c := range cases {
		if got := svc.MapPlacementScoreToLevel(c.score); got != c.want {
			t.Errorf("MapPlacementScoreToLevel(%v) = %q, want %q", c.score, got, c.want)
		}
	}
}

// TestLevelService_NextLevelHelper covers the package-level helper that the
// LevelProgress payload uses to advertise the upcoming target.
func TestLevelService_NextLevelHelper(t *testing.T) {
	want := map[string]string{
		"a0": "a1",
		"a1": "a2",
		"a2": "b1",
		"b1": "",
	}
	for current, expected := range want {
		if got := nextLevelAfter(current); got != expected {
			t.Errorf("nextLevelAfter(%q) = %q, want %q", current, got, expected)
		}
	}
}

// Sanity check that the per-skill keys in SkillMastery cover every expected
// skill exactly once (set equality).
func TestLevelService_ComputeLevelProgress_SkillMasteryKeySetIsExhaustive(t *testing.T) {
	clearLevelEnv(t)
	cfg := LoadLevelConfig()
	svc := newServiceWith(cfg,
		contracts.UserLevel{UserID: "u_keys", CurrentLevel: "a0", UnlockedLevels: []string{"a0"}},
		nil, nil)
	got, err := svc.ComputeLevelProgress("u_keys")
	if err != nil {
		t.Fatalf("ComputeLevelProgress: %v", err)
	}
	wantKeys := []string{"noi", "viet", "nghe", "doc", "tu_vung", "ngu_phap"}
	gotKeys := make([]string, 0, len(got.SkillMastery))
	for k := range got.SkillMastery {
		gotKeys = append(gotKeys, k)
	}
	sort.Strings(wantKeys)
	sort.Strings(gotKeys)
	if !reflect.DeepEqual(wantKeys, gotKeys) {
		t.Errorf("SkillMastery keys = %v, want %v", gotKeys, wantKeys)
	}
}
