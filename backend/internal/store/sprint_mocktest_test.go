package store

import (
	"testing"
	"time"

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
	// V39 flat-sort: sections are ordered by max_points ASC, so the reading
	// section (5 points) comes before the speaking section (8 points). The
	// memory store's strict first-pending check requires advancing in that
	// order until S7 introduces target-display-order semantics.
	if _, err := repo.AdvanceMockExam(session.ID, readingAttempt.ID); err != nil {
		t.Fatalf("AdvanceMockExam reading: %v", err)
	}
	if _, err := repo.AdvanceMockExam(session.ID, speakingAttempt.ID); err != nil {
		t.Fatalf("AdvanceMockExam speaking: %v", err)
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

// ── V39 display_order tests ─────────────────────────────────────────────────

func TestMockExamDisplayOrderSortsByMaxPointsAsc(t *testing.T) {
	repo := NewMemoryStore()
	ex8 := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "uloha_1_topic_answers", Status: "published", Pool: "exam",
	})
	ex12 := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "uloha_2_dialogue_questions", Status: "published", Pool: "exam",
	})
	ex7 := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "uloha_4_choice_reasoning", Status: "published", Pool: "exam",
	})
	mt, _ := repo.CreateMockTest(contracts.MockTest{
		Title:  "Mixed points",
		Status: "published",
		Sections: []contracts.MockTestSection{
			{SequenceNo: 1, ExerciseID: ex8.ID, ExerciseType: ex8.ExerciseType, MaxPoints: 8},
			{SequenceNo: 2, ExerciseID: ex12.ID, ExerciseType: ex12.ExerciseType, MaxPoints: 12},
			{SequenceNo: 3, ExerciseID: ex7.ID, ExerciseType: ex7.ExerciseType, MaxPoints: 7},
		},
	})
	session, err := repo.CreateMockExam("learner-1", mt.ID)
	if err != nil {
		t.Fatalf("CreateMockExam: %v", err)
	}
	if len(session.Sections) != 3 {
		t.Fatalf("section count = %d, want 3", len(session.Sections))
	}
	wantMaxPts := []int{7, 8, 12}
	wantDispOrder := []int{1, 2, 3}
	wantOriginalSeq := []int{3, 1, 2}
	for i, sec := range session.Sections {
		if sec.MaxPoints != wantMaxPts[i] {
			t.Errorf("sections[%d].MaxPoints = %d, want %d", i, sec.MaxPoints, wantMaxPts[i])
		}
		if sec.DisplayOrder != wantDispOrder[i] {
			t.Errorf("sections[%d].DisplayOrder = %d, want %d", i, sec.DisplayOrder, wantDispOrder[i])
		}
		if sec.SequenceNo != wantOriginalSeq[i] {
			t.Errorf("sections[%d].SequenceNo = %d, want %d (original)", i, sec.SequenceNo, wantOriginalSeq[i])
		}
	}
}

func TestMockExamDisplayOrderTiesBreakBySequenceNoAsc(t *testing.T) {
	repo := NewMemoryStore()
	a := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "uloha_1_topic_answers", Status: "published", Pool: "exam",
	})
	b := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "uloha_2_dialogue_questions", Status: "published", Pool: "exam",
	})
	c := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "uloha_3_story_narration", Status: "published", Pool: "exam",
	})
	mt, _ := repo.CreateMockTest(contracts.MockTest{
		Title:  "Tied points",
		Status: "published",
		Sections: []contracts.MockTestSection{
			{SequenceNo: 1, ExerciseID: a.ID, ExerciseType: a.ExerciseType, MaxPoints: 5},
			{SequenceNo: 2, ExerciseID: b.ID, ExerciseType: b.ExerciseType, MaxPoints: 5},
			{SequenceNo: 3, ExerciseID: c.ID, ExerciseType: c.ExerciseType, MaxPoints: 10},
		},
	})
	session, err := repo.CreateMockExam("learner-1", mt.ID)
	if err != nil {
		t.Fatalf("CreateMockExam: %v", err)
	}
	wantOrder := []string{a.ID, b.ID, c.ID}
	wantDisp := []int{1, 2, 3}
	for i, sec := range session.Sections {
		if sec.ExerciseID != wantOrder[i] {
			t.Errorf("sections[%d].ExerciseID = %s, want %s", i, sec.ExerciseID, wantOrder[i])
		}
		if sec.DisplayOrder != wantDisp[i] {
			t.Errorf("sections[%d].DisplayOrder = %d, want %d", i, sec.DisplayOrder, wantDisp[i])
		}
	}
}

// ── V39 server-anchored timer tests ─────────────────────────────────────────

func TestMockExamSessionHasTimerFieldsPopulated(t *testing.T) {
	repo := NewMemoryStore()
	ex := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "uloha_1_topic_answers", Status: "published", Pool: "exam",
	})
	mt, _ := repo.CreateMockTest(contracts.MockTest{
		Title:  "Timer fields",
		Status: "published",
		Sections: []contracts.MockTestSection{
			{SequenceNo: 1, ExerciseID: ex.ID, ExerciseType: ex.ExerciseType, MaxPoints: 5},
		},
	})
	session, err := repo.CreateMockExam("learner-1", mt.ID)
	if err != nil {
		t.Fatalf("CreateMockExam: %v", err)
	}
	if session.DurationSec != DefaultMockExamDurationSec {
		t.Errorf("DurationSec = %d, want %d", session.DurationSec, DefaultMockExamDurationSec)
	}
	if session.StartedAt.IsZero() {
		t.Error("StartedAt is zero")
	}
	wantExpires := session.StartedAt.Add(time.Duration(DefaultMockExamDurationSec) * time.Second)
	if !session.ExpiresAt.Equal(wantExpires) {
		t.Errorf("ExpiresAt = %v, want %v", session.ExpiresAt, wantExpires)
	}
}

func TestListExpiredReturnsOnlyExpiredInProgressSessions(t *testing.T) {
	repo := NewMemoryStore()
	ex := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "uloha_1_topic_answers", Status: "published", Pool: "exam",
	})
	mt, _ := repo.CreateMockTest(contracts.MockTest{
		Title:  "ExpiredSweep",
		Status: "published",
		Sections: []contracts.MockTestSection{
			{SequenceNo: 1, ExerciseID: ex.ID, ExerciseType: ex.ExerciseType, MaxPoints: 5},
		},
	})
	fresh, _ := repo.CreateMockExam("learner-1", mt.ID)
	expired, _ := repo.CreateMockExam("learner-1", mt.ID)
	// Move "expired" 100 minutes into the past.
	if !repo.SetMockExamStartedAtForTesting(expired.ID, time.Now().Add(-100*time.Minute)) {
		t.Fatal("SetMockExamStartedAtForTesting failed")
	}
	ids, err := repo.ListExpiredMockExams(time.Now())
	if err != nil {
		t.Fatalf("ListExpiredMockExams: %v", err)
	}
	if len(ids) != 1 || ids[0] != expired.ID {
		t.Errorf("ListExpiredMockExams = %v, want [%s] (fresh=%s)", ids, expired.ID, fresh.ID)
	}
}

func TestListExpiredIgnoresCompletedSessionsAndZeroDuration(t *testing.T) {
	repo := NewMemoryStore()
	ex := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "uloha_1_topic_answers", Status: "published", Pool: "exam",
	})
	mt, _ := repo.CreateMockTest(contracts.MockTest{
		Title:  "Ignore",
		Status: "published",
		Sections: []contracts.MockTestSection{
			{SequenceNo: 1, ExerciseID: ex.ID, ExerciseType: ex.ExerciseType, MaxPoints: 5},
		},
	})
	expired, _ := repo.CreateMockExam("learner-1", mt.ID)
	repo.SetMockExamStartedAtForTesting(expired.ID, time.Now().Add(-100*time.Minute))
	// Expire it once.
	if _, err := repo.ExpireMockExam(expired.ID); err != nil {
		t.Fatalf("ExpireMockExam: %v", err)
	}
	// Now it's completed; should not appear in ListExpired again.
	ids, err := repo.ListExpiredMockExams(time.Now())
	if err != nil {
		t.Fatalf("ListExpired: %v", err)
	}
	for _, id := range ids {
		if id == expired.ID {
			t.Errorf("ListExpired included completed session %s", id)
		}
	}
}

func TestExpireMockExamFlipsPendingToSkippedAndSessionCompleted(t *testing.T) {
	repo := NewMemoryStore()
	ex := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "uloha_1_topic_answers", Status: "published", Pool: "exam",
	})
	mt, _ := repo.CreateMockTest(contracts.MockTest{
		Title:  "Expire",
		Status: "published",
		Sections: []contracts.MockTestSection{
			{SequenceNo: 1, ExerciseID: ex.ID, ExerciseType: ex.ExerciseType, MaxPoints: 5},
		},
	})
	session, _ := repo.CreateMockExam("learner-1", mt.ID)
	expired, err := repo.ExpireMockExam(session.ID)
	if err != nil {
		t.Fatalf("ExpireMockExam: %v", err)
	}
	if expired.Status != "completed" {
		t.Errorf("Status = %q, want completed", expired.Status)
	}
	if expired.Sections[0].Status != "skipped" {
		t.Errorf("Section status = %q, want skipped", expired.Sections[0].Status)
	}
}

func TestExpireMockExamIdempotentForCompletedSession(t *testing.T) {
	repo := NewMemoryStore()
	ex := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "uloha_1_topic_answers", Status: "published", Pool: "exam",
	})
	mt, _ := repo.CreateMockTest(contracts.MockTest{
		Title:  "Idempotent",
		Status: "published",
		Sections: []contracts.MockTestSection{
			{SequenceNo: 1, ExerciseID: ex.ID, ExerciseType: ex.ExerciseType, MaxPoints: 5},
		},
	})
	session, _ := repo.CreateMockExam("learner-1", mt.ID)
	if _, err := repo.ExpireMockExam(session.ID); err != nil {
		t.Fatalf("first ExpireMockExam: %v", err)
	}
	if _, err := repo.ExpireMockExam(session.ID); err != nil {
		t.Fatalf("second ExpireMockExam: %v (want no-op)", err)
	}
}

func TestExpireMockExamReturnsNotFoundForUnknownID(t *testing.T) {
	repo := NewMemoryStore()
	if _, err := repo.ExpireMockExam("does-not-exist"); err == nil {
		t.Error("ExpireMockExam should return error for unknown session")
	}
}

func TestMockExamDisplayOrderStableAcrossReads(t *testing.T) {
	repo := NewMemoryStore()
	a := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "uloha_1_topic_answers", Status: "published", Pool: "exam",
	})
	b := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "uloha_2_dialogue_questions", Status: "published", Pool: "exam",
	})
	mt, _ := repo.CreateMockTest(contracts.MockTest{
		Title:  "Stable",
		Status: "published",
		Sections: []contracts.MockTestSection{
			{SequenceNo: 1, ExerciseID: a.ID, ExerciseType: a.ExerciseType, MaxPoints: 10},
			{SequenceNo: 2, ExerciseID: b.ID, ExerciseType: b.ExerciseType, MaxPoints: 5},
		},
	})
	created, err := repo.CreateMockExam("learner-1", mt.ID)
	if err != nil {
		t.Fatalf("CreateMockExam: %v", err)
	}
	read1, ok := repo.MockExamByID(created.ID)
	if !ok {
		t.Fatal("MockExamByID first read failed")
	}
	read2, ok := repo.MockExamByID(created.ID)
	if !ok {
		t.Fatal("MockExamByID second read failed")
	}
	if len(read1.Sections) != 2 || len(read2.Sections) != 2 {
		t.Fatalf("section counts: read1=%d read2=%d", len(read1.Sections), len(read2.Sections))
	}
	for i := 0; i < 2; i++ {
		if read1.Sections[i].DisplayOrder != read2.Sections[i].DisplayOrder {
			t.Errorf("read1.Sections[%d].DisplayOrder=%d != read2.Sections[%d].DisplayOrder=%d",
				i, read1.Sections[i].DisplayOrder, i, read2.Sections[i].DisplayOrder)
		}
		if read1.Sections[i].ExerciseID != read2.Sections[i].ExerciseID {
			t.Errorf("read1.Sections[%d].ExerciseID=%s != read2.Sections[%d].ExerciseID=%s",
				i, read1.Sections[i].ExerciseID, i, read2.Sections[i].ExerciseID)
		}
	}
	// Expected: B (max_points=5) first, A (max_points=10) second.
	if read1.Sections[0].ExerciseID != b.ID {
		t.Errorf("read1.Sections[0].ExerciseID = %s, want %s (lowest max_points)",
			read1.Sections[0].ExerciseID, b.ID)
	}
	if read1.Sections[0].DisplayOrder != 1 {
		t.Errorf("read1.Sections[0].DisplayOrder = %d, want 1", read1.Sections[0].DisplayOrder)
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
