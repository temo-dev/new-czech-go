package store

import (
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// ── V9 exam_mode tests ───────────────────────────────────────────────────────

func TestCreateMockTestPreservesExamModeReal(t *testing.T) {
	repo := NewMemoryStore()
	mt, err := repo.CreateMockTest(contracts.MockTest{
		Title:    "Full A2",
		Status:   "published",
		ExamMode: "real",
	})
	if err != nil {
		t.Fatalf("CreateMockTest: %v", err)
	}
	got, ok := repo.MockTestByID(mt.ID)
	if !ok {
		t.Fatal("MockTestByID should find created test")
	}
	if got.ExamMode != "real" {
		t.Errorf("ExamMode = %q, want %q", got.ExamMode, "real")
	}
}

func TestCreateMockTestExamModeDefaultsToEmpty(t *testing.T) {
	repo := NewMemoryStore()
	mt, err := repo.CreateMockTest(contracts.MockTest{
		Title:  "Sprint practice",
		Status: "published",
	})
	if err != nil {
		t.Fatalf("CreateMockTest: %v", err)
	}
	got, ok := repo.MockTestByID(mt.ID)
	if !ok {
		t.Fatal("MockTestByID should find created test")
	}
	if got.ExamMode != "" {
		t.Errorf("ExamMode = %q, want empty string (practice default)", got.ExamMode)
	}
}

func TestUpdateMockTestPreservesExamMode(t *testing.T) {
	repo := NewMemoryStore()
	mt, _ := repo.CreateMockTest(contracts.MockTest{
		Title:    "Initial",
		Status:   "draft",
		ExamMode: "practice",
	})
	updated, ok := repo.UpdateMockTest(mt.ID, contracts.MockTest{
		Title:                "Updated",
		Status:               "published",
		ExamMode:             "real",
		PassThresholdPercent: 60,
	})
	if !ok {
		t.Fatal("UpdateMockTest should succeed")
	}
	if updated.ExamMode != "real" {
		t.Errorf("ExamMode after update = %q, want %q", updated.ExamMode, "real")
	}
}

// ── computeScoring tests ─────────────────────────────────────────────────────

func scoringInputsFromLevels(levels []string, maxPoints []int) []mockExamScoringInput {
	inputs := make([]mockExamScoringInput, len(levels))
	for i, level := range levels {
		inputs[i] = mockExamScoringInputFromFeedback(&contracts.AttemptFeedback{ReadinessLevel: level}, maxPoints[i])
	}
	return inputs
}

func TestComputeScoringDefaultThreshold(t *testing.T) {
	// 0 → falls back to 60
	levels := []string{"almost", "almost", "almost", "almost"} // 0.75 each
	maxPts := []int{8, 12, 10, 7}
	// section scores: 6, 9, 8, 5 = 28; bonus = round(0.75*3)=2; overall=30
	// 60%: 30*100=3000 >= 40*60=2400 → passed
	_, _, score, passed := computeScoring(scoringInputsFromLevels(levels, maxPts), 0, true)
	if !passed {
		t.Errorf("expected passed=true with 0 threshold (default 60%%), got score=%d passed=%v", score, passed)
	}
}

func TestComputeScoringCustomThreshold80(t *testing.T) {
	// 1 section, maxPoints=10, "needs_work" (0.5) → section=5, no sprint bonus
	// 80%: 5*100=500 >= 10*80=800 → NOT passed
	_, _, score, passed := computeScoring(scoringInputsFromLevels([]string{"needs_work"}, []int{10}), 80, false)
	if passed {
		t.Errorf("expected passed=false with needs_work and 80%% threshold, got score=%d", score)
	}
}

func TestComputeScoringCustomThreshold80Passes(t *testing.T) {
	// "almost" (0.75): section=round(0.75*10)=8, no sprint bonus
	// 80%: 8*100=800 >= 10*80=800 → passed
	_, _, score, passed := computeScoring(scoringInputsFromLevels([]string{"almost"}, []int{10}), 80, false)
	if !passed {
		t.Errorf("expected passed=true with almost and 80%% threshold, got score=%d", score)
	}
}

func TestComputeScoringBoundaryExactlyAt60(t *testing.T) {
	// "ready" (1.0): section=10, no sprint bonus
	// 60%: 10*100=1000 >= 10*60=600 → passed
	// "not_ready" (0.0): section=0, bonus=0, overall=0
	// 60%: 0*100=0 >= 10*60=600 → NOT passed
	_, _, _, passedReady := computeScoring(scoringInputsFromLevels([]string{"ready"}, []int{10}), 60, false)
	_, _, _, passedNotReady := computeScoring(scoringInputsFromLevels([]string{"weak"}, []int{10}), 60, false)
	if !passedReady {
		t.Error("ready at 60% should pass")
	}
	if passedNotReady {
		t.Error("not_ready at 60% should fail")
	}
}

func TestComputeScoringEmptyLevels(t *testing.T) {
	scores, bonus, overall, passed := computeScoring(nil, 60, false)
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
	// "needs_work" (0.5): section=5, no sprint bonus; totalMax=10
	// 60%: 5*100=500 < 10*60=600 → FAIL
	_, passed := completeMockExamHelper(t, 60, "needs_work")
	if passed {
		t.Error("needs_work with 60% threshold should fail")
	}
}

func TestCompleteMockExamWith80ThresholdNeedsWork(t *testing.T) {
	// "needs_work" (0.5): section=5, no sprint bonus; totalMax=10
	// 80%: 5*100=500 < 10*80=800 → FAIL
	_, passed := completeMockExamHelper(t, 80, "needs_work")
	if passed {
		t.Error("needs_work with 80% threshold should fail")
	}
}

func TestCompleteMockExamWith80ThresholdAlmost(t *testing.T) {
	// "almost" (0.75): section=round(0.75*10)=8, no sprint bonus; totalMax=10
	// 80%: 8*100=800 >= 10*80=800 → PASS
	_, passed := completeMockExamHelper(t, 80, "almost")
	if !passed {
		t.Error("almost with 80% threshold should pass")
	}
}

func TestCompleteMockExamUsesObjectiveResultScore(t *testing.T) {
	repo := NewMemoryStore()
	ex := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "cteni_1",
		Status:       "published",
		Pool:         "exam",
	})
	mt, _ := repo.CreateMockTest(contracts.MockTest{
		Title:                "Reading sprint",
		Status:               "published",
		PassThresholdPercent: 60,
		Sections: []contracts.MockTestSection{
			{SequenceNo: 1, SkillKind: "doc", ExerciseID: ex.ID, ExerciseType: ex.ExerciseType, MaxPoints: 5},
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
	repo.CompleteAttempt(attempt.ID, contracts.Transcript{FullText: "answers"}, contracts.AttemptFeedback{
		ReadinessLevel: "strong",
		ObjectiveResult: &contracts.ObjectiveResult{
			Score:    3,
			MaxScore: 5,
		},
	})
	if _, err := repo.AdvanceMockExam(session.ID, attempt.ID); err != nil {
		t.Fatalf("AdvanceMockExam: %v", err)
	}

	completed, err := repo.CompleteMockExam(session.ID)
	if err != nil {
		t.Fatalf("CompleteMockExam: %v", err)
	}
	if completed.OverallScore != 3 {
		t.Fatalf("overall score = %d, want exact objective score 3", completed.OverallScore)
	}
	if completed.Sections[0].SectionScore != 3 {
		t.Fatalf("section score = %d, want 3", completed.Sections[0].SectionScore)
	}
}

func TestCompleteMockExamScoresCurrentSpeakingReadinessLabels(t *testing.T) {
	score, passed := completeMockExamHelper(t, 60, "ready_for_mock")
	if score != 10 {
		t.Fatalf("ready_for_mock score = %d, want section 10 without sprint bonus", score)
	}
	if !passed {
		t.Fatal("ready_for_mock should pass at 60%")
	}
}

func TestCompleteMockExamDoesNotAddPronunciationBonusToMixedSprint(t *testing.T) {
	repo := NewMemoryStore()
	speaking := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "uloha_1_topic_answers",
		Status:       "published",
		Pool:         "exam",
	})
	reading := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "cteni_1",
		Status:       "published",
		Pool:         "exam",
	})
	mt, _ := repo.CreateMockTest(contracts.MockTest{
		Title:                "Mixed sprint",
		Status:               "published",
		PassThresholdPercent: 60,
		Sections: []contracts.MockTestSection{
			{SequenceNo: 1, SkillKind: "noi", ExerciseID: speaking.ID, ExerciseType: speaking.ExerciseType, MaxPoints: 8},
			{SequenceNo: 2, SkillKind: "doc", ExerciseID: reading.ID, ExerciseType: reading.ExerciseType, MaxPoints: 5},
		},
	})
	session, err := repo.CreateMockExam("learner-1", mt.ID)
	if err != nil {
		t.Fatalf("CreateMockExam: %v", err)
	}
	speakingAttempt, err := repo.CreateAttempt("learner-1", speaking.ID, "ios", "1.0", "vi")
	if err != nil {
		t.Fatalf("CreateAttempt speaking: %v", err)
	}
	repo.CompleteAttempt(speakingAttempt.ID, contracts.Transcript{FullText: "speaking"}, contracts.AttemptFeedback{
		ReadinessLevel: "ready_for_mock",
	})
	readingAttempt, err := repo.CreateAttempt("learner-1", reading.ID, "ios", "1.0", "vi")
	if err != nil {
		t.Fatalf("CreateAttempt reading: %v", err)
	}
	repo.CompleteAttempt(readingAttempt.ID, contracts.Transcript{FullText: "answers"}, contracts.AttemptFeedback{
		ReadinessLevel: "strong",
		ObjectiveResult: &contracts.ObjectiveResult{
			Score:    5,
			MaxScore: 5,
		},
	})
	if _, err := repo.AdvanceMockExam(session.ID, speakingAttempt.ID); err != nil {
		t.Fatalf("AdvanceMockExam speaking: %v", err)
	}
	if _, err := repo.AdvanceMockExam(session.ID, readingAttempt.ID); err != nil {
		t.Fatalf("AdvanceMockExam reading: %v", err)
	}

	completed, err := repo.CompleteMockExam(session.ID)
	if err != nil {
		t.Fatalf("CompleteMockExam: %v", err)
	}
	if completed.OverallScore != 13 {
		t.Fatalf("mixed sprint overall score = %d, want 13 without pronunciation bonus", completed.OverallScore)
	}
}

func TestAdvanceMockExamRejectsAttemptForDifferentExercise(t *testing.T) {
	repo := NewMemoryStore()
	expected := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "cteni_1",
		Status:       "published",
		Pool:         "exam",
	})
	other := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "cteni_2",
		Status:       "published",
		Pool:         "exam",
	})
	mt, _ := repo.CreateMockTest(contracts.MockTest{
		Title:                "Reading sprint",
		Status:               "published",
		PassThresholdPercent: 60,
		Sections: []contracts.MockTestSection{
			{SequenceNo: 1, SkillKind: "doc", ExerciseID: expected.ID, ExerciseType: expected.ExerciseType, MaxPoints: 5},
		},
	})
	session, err := repo.CreateMockExam("learner-1", mt.ID)
	if err != nil {
		t.Fatalf("CreateMockExam: %v", err)
	}
	attempt, err := repo.CreateAttempt("learner-1", other.ID, "ios", "1.0", "vi")
	if err != nil {
		t.Fatalf("CreateAttempt: %v", err)
	}
	repo.CompleteAttempt(attempt.ID, contracts.Transcript{FullText: "answers"}, contracts.AttemptFeedback{
		ReadinessLevel: "strong",
		ObjectiveResult: &contracts.ObjectiveResult{
			Score:    5,
			MaxScore: 5,
		},
	})

	if _, err := repo.AdvanceMockExam(session.ID, attempt.ID); err == nil {
		t.Fatal("AdvanceMockExam should reject an attempt for a different exercise")
	}
	unchanged, ok := repo.MockExamByID(session.ID)
	if !ok {
		t.Fatal("MockExamByID should still find session")
	}
	if unchanged.Sections[0].Status != "pending" || unchanged.Sections[0].AttemptID != "" {
		t.Fatalf("section mutated after rejected advance: %+v", unchanged.Sections[0])
	}
}

func TestCompleteMockExamRejectsUnanalysedAttempt(t *testing.T) {
	repo := NewMemoryStore()
	ex := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "cteni_1",
		Status:       "published",
		Pool:         "exam",
	})
	mt, _ := repo.CreateMockTest(contracts.MockTest{
		Title:                "Reading sprint",
		Status:               "published",
		PassThresholdPercent: 60,
		Sections: []contracts.MockTestSection{
			{SequenceNo: 1, SkillKind: "doc", ExerciseID: ex.ID, ExerciseType: ex.ExerciseType, MaxPoints: 5},
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

	advanced, err := repo.AdvanceMockExam(session.ID, attempt.ID)
	if err != nil {
		t.Fatalf("AdvanceMockExam should accept a recorded attempt before analysis: %v", err)
	}
	if advanced.Sections[0].Status != "completed" || advanced.Sections[0].AttemptID != attempt.ID {
		t.Fatalf("section not attached after advance: %+v", advanced.Sections[0])
	}
	if _, err := repo.CompleteMockExam(session.ID); err == nil {
		t.Fatal("CompleteMockExam should reject attempts that have not been analysed")
	}
}
