package store

import (
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// ── computeScoring tests ─────────────────────────────────────────────────────

func TestComputeScoringDefaultThreshold(t *testing.T) {
	// 0 → falls back to 60
	levels := []string{"almost", "almost", "almost", "almost"} // 0.75 each
	maxPts := []int{8, 12, 10, 7}
	// section scores: 6, 9, 8, 5 = 28; bonus = round(0.75*3)=2; overall=30
	// 60%: 30*100=3000 >= 37*60=2220 → passed
	_, _, score, passed := computeScoring(levels, maxPts, 0)
	if !passed {
		t.Errorf("expected passed=true with 0 threshold (default 60%%), got score=%d passed=%v", score, passed)
	}
}

func TestComputeScoringCustomThreshold80(t *testing.T) {
	// 1 section, maxPoints=10, "needs_work" (0.5) → section=5, bonus=round(0.5*3)=2, overall=7
	// 80%: 7*100=700 >= 10*80=800 → NOT passed
	_, _, score, passed := computeScoring([]string{"needs_work"}, []int{10}, 80)
	if passed {
		t.Errorf("expected passed=false with needs_work and 80%% threshold, got score=%d", score)
	}
}

func TestComputeScoringCustomThreshold80Passes(t *testing.T) {
	// "almost" (0.75): section=round(0.75*10)=8, bonus=round(0.75*3)=2, overall=10
	// 80%: 10*100=1000 >= 10*80=800 → passed
	_, _, score, passed := computeScoring([]string{"almost"}, []int{10}, 80)
	if !passed {
		t.Errorf("expected passed=true with almost and 80%% threshold, got score=%d", score)
	}
}

func TestComputeScoringBoundaryExactlyAt60(t *testing.T) {
	// "ready" (1.0): section=10, bonus=3, overall=13; totalMax=10
	// 60%: 13*100=1300 >= 10*60=600 → passed (well above)
	// "not_ready" (0.0): section=0, bonus=0, overall=0
	// 60%: 0*100=0 >= 10*60=600 → NOT passed
	_, _, _, passedReady := computeScoring([]string{"ready"}, []int{10}, 60)
	_, _, _, passedNotReady := computeScoring([]string{"not_ready"}, []int{10}, 60)
	if !passedReady {
		t.Error("ready at 60% should pass")
	}
	if passedNotReady {
		t.Error("not_ready at 60% should fail")
	}
}

func TestComputeScoringEmptyLevels(t *testing.T) {
	scores, bonus, overall, passed := computeScoring(nil, nil, 60)
	if scores != nil || bonus != 0 || overall != 0 || passed {
		t.Errorf("empty input: want nil,0,0,false; got %v,%d,%d,%v", scores, bonus, overall, passed)
	}
}

// ── MockTest threshold clamping ───────────────────────────────────────────────

func TestCreateMockTestClampsThresholdZero(t *testing.T) {
	repo := NewMemoryStore()
	mt, _ := repo.CreateMockTest(contracts.MockTest{
		Title:                "Sprint",
		Status:               "draft",
		PassThresholdPercent: 0,
	})
	if mt.PassThresholdPercent != 60 {
		t.Errorf("threshold 0 should clamp to 60, got %d", mt.PassThresholdPercent)
	}
}

func TestCreateMockTestClampsThresholdOver100(t *testing.T) {
	repo := NewMemoryStore()
	mt, _ := repo.CreateMockTest(contracts.MockTest{
		Title:                "Bad",
		Status:               "draft",
		PassThresholdPercent: 150,
	})
	if mt.PassThresholdPercent != 60 {
		t.Errorf("threshold 150 should clamp to 60, got %d", mt.PassThresholdPercent)
	}
}

func TestCreateMockTestPreservesValidThreshold(t *testing.T) {
	repo := NewMemoryStore()
	for _, pct := range []int{1, 50, 80, 100} {
		mt, _ := repo.CreateMockTest(contracts.MockTest{
			Title:                "Sprint",
			Status:               "draft",
			PassThresholdPercent: pct,
		})
		if mt.PassThresholdPercent != pct {
			t.Errorf("threshold %d should be preserved, got %d", pct, mt.PassThresholdPercent)
		}
	}
}

// ── MockExam inherits threshold from MockTest ────────────────────────────────

func TestMockExamSessionInheritsThreshold(t *testing.T) {
	repo := NewMemoryStore()

	ex := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "uloha_1_topic_answers",
		Status:       "published",
		Pool:         "exam",
	})
	mt, _ := repo.CreateMockTest(contracts.MockTest{
		Title:                "Sprint 80%",
		Status:               "published",
		PassThresholdPercent: 80,
		Sections: []contracts.MockTestSection{
			{SequenceNo: 1, ExerciseID: ex.ID, ExerciseType: ex.ExerciseType, MaxPoints: 10},
		},
	})

	session, err := repo.CreateMockExam("learner-1", mt.ID)
	if err != nil {
		t.Fatalf("CreateMockExam error: %v", err)
	}
	if session.PassThresholdPercent != 80 {
		t.Errorf("session threshold = %d, want 80", session.PassThresholdPercent)
	}
}

func TestMockExamSessionDefaultThresholdWithoutMockTest(t *testing.T) {
	repo := NewMemoryStore()
	// no mockTestID → uses default exercises, threshold = 60
	session, err := repo.CreateMockExam("learner-1", "")
	if err != nil {
		t.Fatalf("CreateMockExam error: %v", err)
	}
	if session.PassThresholdPercent != 60 {
		t.Errorf("default session threshold = %d, want 60", session.PassThresholdPercent)
	}
}

// ── CompleteMockExam uses session threshold ──────────────────────────────────

func completeMockExamHelper(t *testing.T, threshold int, readiness string) (score int, passed bool) {
	t.Helper()
	repo := NewMemoryStore()

	ex := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "uloha_1_topic_answers",
		Status:       "published",
		Pool:         "exam",
	})
	mt, _ := repo.CreateMockTest(contracts.MockTest{
		Title:                "Test",
		Status:               "published",
		PassThresholdPercent: threshold,
		Sections: []contracts.MockTestSection{
			{SequenceNo: 1, ExerciseID: ex.ID, ExerciseType: ex.ExerciseType, MaxPoints: 10},
		},
	})

	session, err := repo.CreateMockExam("learner-1", mt.ID)
	if err != nil {
		t.Fatalf("CreateMockExam: %v", err)
	}

	attempt, err := repo.CreateAttempt("learner-1", ex.ID, "ios", "1.0", "vi")
	if err != nil {
		t.Fatalf("CreateAttempt: %v", err)
	}
	repo.CompleteAttempt(attempt.ID, contracts.Transcript{FullText: "test"}, contracts.AttemptFeedback{
		ReadinessLevel: readiness,
	})

	if _, err := repo.AdvanceMockExam(session.ID, attempt.ID); err != nil {
		t.Fatalf("AdvanceMockExam: %v", err)
	}

	completed, err := repo.CompleteMockExam(session.ID)
	if err != nil {
		t.Fatalf("CompleteMockExam: %v", err)
	}
	return completed.OverallScore, completed.Passed
}

func TestCompleteMockExamWith60ThresholdNeedsWork(t *testing.T) {
	// "needs_work" (0.5): section=5, bonus=2, overall=7; totalMax=10
	// 60%: 7*100=700 >= 10*60=600 → PASS
	_, passed := completeMockExamHelper(t, 60, "needs_work")
	if !passed {
		t.Error("needs_work with 60% threshold should pass")
	}
}

func TestCompleteMockExamWith80ThresholdNeedsWork(t *testing.T) {
	// "needs_work" (0.5): section=5, bonus=2, overall=7; totalMax=10
	// 80%: 7*100=700 >= 10*80=800 → FAIL (700 < 800)
	_, passed := completeMockExamHelper(t, 80, "needs_work")
	if passed {
		t.Error("needs_work with 80% threshold should fail")
	}
}

func TestCompleteMockExamWith80ThresholdAlmost(t *testing.T) {
	// "almost" (0.75): section=round(0.75*10)=8, bonus=round(0.75*3)=2, overall=10; totalMax=10
	// 80%: 10*100=1000 >= 10*80=800 → PASS
	_, passed := completeMockExamHelper(t, 80, "almost")
	if !passed {
		t.Error("almost with 80% threshold should pass")
	}
}
