package processing

import (
	"testing"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

func newPromotionHookDeps() (PromotionHookDeps, store.PromotionAttemptsStore, store.UserLevelStore) {
	promo := store.NewMemoryPromotionAttemptsStore()
	userLevels := store.NewMemoryUserLevelStore()
	return PromotionHookDeps{PromoAttempts: promo, UserLevels: userLevels}, promo, userLevels
}

func TestHandlePromotionOutcome_PassPromotesUser(t *testing.T) {
	deps, promo, userLevels := newPromotionHookDeps()

	if _, err := userLevels.SetUserLevel("u_pass", "a2"); err != nil {
		t.Fatalf("seed user level: %v", err)
	}
	pa, _ := promo.Create(contracts.PromotionAttempt{
		UserID: "u_pass", MockTestID: "mt_b1", SourceLevel: "a2", TargetLevel: "b1",
		FullSessionID: "fes_pass",
		CreatedAt:     time.Date(2026, 5, 7, 9, 0, 0, 0, time.UTC),
	})

	// OverallScore is raw points (sum of section_score + bonus). The hook
	// divides by sum(MaxPoints) to get the percentage written to
	// promotion_attempts.score_pct (V21 review C2).
	session := contracts.MockExamSession{
		ID:                   "fes_pass",
		LearnerID:            "u_pass",
		Status:               "completed",
		MockTestID:           "mt_b1",
		OverallScore:         16, // 9 + 7 raw points / 20 max → 80%
		Passed:               true,
		PassThresholdPercent: 60,
		Sections: []contracts.MockExamSessionItem{
			{SkillKind: "doc", MaxPoints: 10, SectionScore: 9, Status: "completed"},
			{SkillKind: "viet", MaxPoints: 10, SectionScore: 7, Status: "completed"},
		},
	}

	processed, err := HandlePromotionOutcome(deps, session)
	if err != nil {
		t.Fatalf("HandlePromotionOutcome: %v", err)
	}
	if !processed {
		t.Fatal("expected processed=true for a linked promotion attempt")
	}

	updatedPA, ok := promo.GetByFullSessionID("fes_pass")
	if !ok {
		t.Fatal("promotion attempt not found after hook")
	}
	if updatedPA.ID != pa.ID {
		t.Errorf("hook found a different promotion_attempt: got %s want %s", updatedPA.ID, pa.ID)
	}
	if !updatedPA.Passed {
		t.Errorf("Passed = false, want true")
	}
	if updatedPA.ScorePct != 80 {
		t.Errorf("ScorePct = %v, want 80 (16 raw / 20 max × 100)", updatedPA.ScorePct)
	}
	if got := updatedPA.PerSkillPct["doc"]; got != 90 {
		t.Errorf("PerSkillPct[doc] = %v, want 90 (9/10*100)", got)
	}

	// User level should now include b1.
	got, _ := userLevels.GetUserLevel("u_pass")
	if got.CurrentLevel != "b1" {
		t.Errorf("CurrentLevel = %q, want b1 after pass", got.CurrentLevel)
	}
	foundB1 := false
	for _, lvl := range got.UnlockedLevels {
		if lvl == "b1" {
			foundB1 = true
		}
	}
	if !foundB1 {
		t.Errorf("UnlockedLevels = %v, want to contain b1", got.UnlockedLevels)
	}
}

func TestHandlePromotionOutcome_FailRecordsResultButNoPromotion(t *testing.T) {
	deps, promo, userLevels := newPromotionHookDeps()

	if _, err := userLevels.SetUserLevel("u_fail", "a2"); err != nil {
		t.Fatalf("seed user level: %v", err)
	}
	_, _ = promo.Create(contracts.PromotionAttempt{
		UserID: "u_fail", MockTestID: "mt_b1", SourceLevel: "a2", TargetLevel: "b1",
		FullSessionID: "fes_fail",
		CreatedAt:     time.Date(2026, 5, 7, 9, 0, 0, 0, time.UTC),
	})

	session := contracts.MockExamSession{
		ID:                   "fes_fail",
		LearnerID:            "u_fail",
		Status:               "completed",
		MockTestID:           "mt_b1",
		OverallScore:         4, // 4 / 10 → 40%
		Passed:               false,
		PassThresholdPercent: 60,
		Sections: []contracts.MockExamSessionItem{
			{SkillKind: "viet", MaxPoints: 10, SectionScore: 4, Status: "completed"},
		},
	}

	processed, err := HandlePromotionOutcome(deps, session)
	if err != nil {
		t.Fatalf("HandlePromotionOutcome: %v", err)
	}
	if !processed {
		t.Fatal("expected processed=true even on fail")
	}

	updatedPA, _ := promo.GetByFullSessionID("fes_fail")
	if updatedPA.Passed {
		t.Errorf("Passed = true, want false")
	}
	if updatedPA.ScorePct != 40 {
		t.Errorf("ScorePct = %v, want 40 (4 raw / 10 max × 100)", updatedPA.ScorePct)
	}

	got, _ := userLevels.GetUserLevel("u_fail")
	if got.CurrentLevel != "a2" {
		t.Errorf("CurrentLevel = %q, want a2 (no promotion on fail)", got.CurrentLevel)
	}
}

func TestHandlePromotionOutcome_NoLinkedAttempt_ReturnsFalse(t *testing.T) {
	deps, _, userLevels := newPromotionHookDeps()
	if _, err := userLevels.SetUserLevel("u_other", "a2"); err != nil {
		t.Fatalf("seed user level: %v", err)
	}
	session := contracts.MockExamSession{
		ID:        "fes_no_promo",
		LearnerID: "u_other",
		Status:    "completed",
	}
	processed, err := HandlePromotionOutcome(deps, session)
	if err != nil {
		t.Fatalf("HandlePromotionOutcome: %v", err)
	}
	if processed {
		t.Errorf("processed = true, want false (no linked promotion attempt)")
	}
	// No state changes for unrelated session.
	got, _ := userLevels.GetUserLevel("u_other")
	if got.CurrentLevel != "a2" {
		t.Errorf("CurrentLevel = %q, want a2 (untouched)", got.CurrentLevel)
	}
}

// V21 review C2: OverallScore is raw points; the helper must convert to
// a 0–100 percentage by dividing by sum(MaxPoints). Misconfigured
// sessions (zero max) return 0 instead of crashing.
func TestOverallScorePctFromSession_RawPointsToPercent(t *testing.T) {
	cases := []struct {
		name     string
		session  contracts.MockExamSession
		expected float64
	}{
		{
			name: "happy path 78 / 110",
			session: contracts.MockExamSession{
				OverallScore: 78,
				Sections: []contracts.MockExamSessionItem{
					{MaxPoints: 8, SectionScore: 6},
					{MaxPoints: 12, SectionScore: 9},
					{MaxPoints: 10, SectionScore: 8},
					{MaxPoints: 7, SectionScore: 5},
					{MaxPoints: 25, SectionScore: 18},
					{MaxPoints: 25, SectionScore: 17},
					{MaxPoints: 23, SectionScore: 15},
				},
			},
			expected: 78.0 / 110.0 * 100,
		},
		{
			name: "perfect score = 100",
			session: contracts.MockExamSession{
				OverallScore: 20,
				Sections: []contracts.MockExamSessionItem{
					{MaxPoints: 10, SectionScore: 10},
					{MaxPoints: 10, SectionScore: 10},
				},
			},
			expected: 100.0,
		},
		{
			name: "zero max → 0 (no crash)",
			session: contracts.MockExamSession{
				OverallScore: 50,
				Sections: []contracts.MockExamSessionItem{
					{MaxPoints: 0, SectionScore: 50},
				},
			},
			expected: 0,
		},
		{
			name:    "no sections → 0",
			session: contracts.MockExamSession{OverallScore: 25},
			expected: 0,
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got := OverallScorePctFromSession(c.session)
			if got < c.expected-0.01 || got > c.expected+0.01 {
				t.Errorf("got %v, want %v", got, c.expected)
			}
		})
	}
}

func TestHandlePromotionOutcome_ReplayIsIdempotent(t *testing.T) {
	deps, promo, userLevels := newPromotionHookDeps()

	if _, err := userLevels.SetUserLevel("u_replay", "a2"); err != nil {
		t.Fatalf("seed user level: %v", err)
	}
	_, _ = promo.Create(contracts.PromotionAttempt{
		UserID: "u_replay", MockTestID: "mt_b1", SourceLevel: "a2", TargetLevel: "b1",
		FullSessionID: "fes_replay",
		CreatedAt:     time.Date(2026, 5, 7, 9, 0, 0, 0, time.UTC),
	})

	session := contracts.MockExamSession{
		ID: "fes_replay", LearnerID: "u_replay", Status: "completed",
		MockTestID: "mt_b1", OverallScore: 8, Passed: true, // 8 / 10 → 80%
		Sections: []contracts.MockExamSessionItem{
			{SkillKind: "doc", MaxPoints: 10, SectionScore: 8, Status: "completed"},
		},
	}

	first, err := HandlePromotionOutcome(deps, session)
	if err != nil || !first {
		t.Fatalf("first run: processed=%v err=%v", first, err)
	}
	gotAfterFirst, _ := userLevels.GetUserLevel("u_replay")
	firstUnlocks := append([]string(nil), gotAfterFirst.UnlockedLevels...)

	second, err := HandlePromotionOutcome(deps, session)
	if err != nil || !second {
		t.Fatalf("second run: processed=%v err=%v", second, err)
	}
	gotAfterSecond, _ := userLevels.GetUserLevel("u_replay")
	if len(gotAfterSecond.UnlockedLevels) != len(firstUnlocks) {
		t.Errorf("replay added duplicate level: first=%v second=%v",
			firstUnlocks, gotAfterSecond.UnlockedLevels)
	}
	pa, _ := promo.GetByFullSessionID("fes_replay")
	if !pa.Passed || pa.ScorePct != 80 {
		t.Errorf("promotion attempt diverged on replay: %+v", pa)
	}
}
