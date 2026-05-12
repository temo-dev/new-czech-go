package httpapi

import (
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

// V36 — interview as a 5th skill in mock test sections. Backend already
// accepts skill_kind="interview" on mock_test_sections (TEXT free-form
// column). These tests pin the scoring + advance contract so future
// changes don't silently break interview-in-exam.

func TestMockExam_InterviewSectionAggregatesIntoOverallScore(t *testing.T) {
	repo := store.NewMemoryStore()
	exercise := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "interview_conversation",
		SkillKind:    "interview",
		Status:       "published",
		Pool:         "exam",
	})
	mockTest, err := repo.CreateMockTest(contracts.MockTest{
		Title:                "Interview-only sprint",
		Status:               "published",
		PassThresholdPercent: 80,
		Sections: []contracts.MockTestSection{
			{
				SequenceNo:   1,
				SkillKind:    "interview",
				ExerciseID:   exercise.ID,
				ExerciseType: exercise.ExerciseType,
				MaxPoints:    20,
			},
		},
	})
	if err != nil {
		t.Fatalf("CreateMockTest: %v", err)
	}
	session, err := repo.CreateMockExam("user-learner-1", mockTest.ID)
	if err != nil {
		t.Fatalf("CreateMockExam: %v", err)
	}
	attempt, err := repo.CreateAttempt("user-learner-1", exercise.ID, "ios", "0.1.0", "vi")
	if err != nil {
		t.Fatalf("CreateAttempt: %v", err)
	}
	// Simulate the interview submit pipeline marking the attempt as
	// "ready" (full marks under the readiness fraction table).
	repo.CompleteAttempt(attempt.ID,
		contracts.Transcript{FullText: "Dobry den, jmenuji se Tuan.", Provider: "elevenlabs", IsSynthetic: false},
		contracts.AttemptFeedback{ReadinessLevel: "ready", OverallSummary: "Strong interview."},
	)

	if _, err := repo.AdvanceMockExam(session.ID, attempt.ID); err != nil {
		t.Fatalf("AdvanceMockExam: %v", err)
	}
	completed, err := repo.CompleteMockExam(session.ID)
	if err != nil {
		t.Fatalf("CompleteMockExam: %v", err)
	}
	if completed.OverallScore != 20 {
		t.Fatalf("OverallScore = %d, want 20", completed.OverallScore)
	}
	if !completed.Passed {
		t.Fatalf("expected Passed=true (overall 20/20 >= 80%%), got false")
	}
	if completed.Sections[0].SkillKind != "interview" {
		t.Fatalf("section[0].SkillKind = %q, want interview", completed.Sections[0].SkillKind)
	}
	if completed.Sections[0].SectionScore != 20 {
		t.Fatalf("section[0].SectionScore = %d, want 20", completed.Sections[0].SectionScore)
	}
}

func TestMockExam_InterviewSectionMixedWithReading(t *testing.T) {
	repo := store.NewMemoryStore()
	interview := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "interview_choice_explain",
		SkillKind:    "interview",
		Status:       "published",
		Pool:         "exam",
	})
	reading := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "cteni_1",
		SkillKind:    "doc",
		Status:       "published",
		Pool:         "exam",
	})
	mockTest, err := repo.CreateMockTest(contracts.MockTest{
		Title:                "Mixed exam",
		Status:               "published",
		PassThresholdPercent: 60,
		Sections: []contracts.MockTestSection{
			{SequenceNo: 1, SkillKind: "doc", ExerciseID: reading.ID, ExerciseType: reading.ExerciseType, MaxPoints: 5},
			{SequenceNo: 2, SkillKind: "interview", ExerciseID: interview.ID, ExerciseType: interview.ExerciseType, MaxPoints: 20},
		},
	})
	if err != nil {
		t.Fatalf("CreateMockTest: %v", err)
	}
	session, err := repo.CreateMockExam("user-learner-1", mockTest.ID)
	if err != nil {
		t.Fatalf("CreateMockExam: %v", err)
	}

	readingAttempt, err := repo.CreateAttempt("user-learner-1", reading.ID, "ios", "0.1.0", "vi")
	if err != nil {
		t.Fatalf("CreateAttempt reading: %v", err)
	}
	repo.CompleteAttempt(readingAttempt.ID,
		contracts.Transcript{FullText: "", Provider: "dev_stub", IsSynthetic: true},
		contracts.AttemptFeedback{
			ReadinessLevel: "ready",
			ObjectiveResult: &contracts.ObjectiveResult{
				Score: 4, MaxScore: 5,
			},
		},
	)

	interviewAttempt, err := repo.CreateAttempt("user-learner-1", interview.ID, "ios", "0.1.0", "vi")
	if err != nil {
		t.Fatalf("CreateAttempt interview: %v", err)
	}
	repo.CompleteAttempt(interviewAttempt.ID,
		contracts.Transcript{FullText: "Vybral jsem prvni moznost.", Provider: "elevenlabs"},
		contracts.AttemptFeedback{ReadinessLevel: "almost_ready", OverallSummary: "Almost there."},
	)

	if _, err := repo.AdvanceMockExam(session.ID, readingAttempt.ID); err != nil {
		t.Fatalf("AdvanceMockExam reading: %v", err)
	}
	if _, err := repo.AdvanceMockExam(session.ID, interviewAttempt.ID); err != nil {
		t.Fatalf("AdvanceMockExam interview: %v", err)
	}
	completed, err := repo.CompleteMockExam(session.ID)
	if err != nil {
		t.Fatalf("CompleteMockExam: %v", err)
	}

	// reading: 4/5 → 4 pts. interview: almost_ready (0.75) × 20 = 15 pts.
	// total = 19, max = 25 → 76% ≥ 60% pass.
	if completed.OverallScore != 19 {
		t.Fatalf("OverallScore = %d, want 19", completed.OverallScore)
	}
	if !completed.Passed {
		t.Fatalf("expected Passed=true, got false")
	}
	if got := completed.Sections[1].SectionScore; got != 15 {
		t.Fatalf("interview section score = %d, want 15", got)
	}
}

func TestMockExam_MultipleInterviewSections(t *testing.T) {
	repo := store.NewMemoryStore()
	conv := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "interview_conversation",
		SkillKind:    "interview",
		Status:       "published",
		Pool:         "exam",
	})
	choice := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "interview_choice_explain",
		SkillKind:    "interview",
		Status:       "published",
		Pool:         "exam",
	})
	mockTest, err := repo.CreateMockTest(contracts.MockTest{
		Title:                "Double interview",
		Status:               "published",
		PassThresholdPercent: 80,
		Sections: []contracts.MockTestSection{
			{SequenceNo: 1, SkillKind: "interview", ExerciseID: conv.ID, ExerciseType: conv.ExerciseType, MaxPoints: 20},
			{SequenceNo: 2, SkillKind: "interview", ExerciseID: choice.ID, ExerciseType: choice.ExerciseType, MaxPoints: 20},
		},
	})
	if err != nil {
		t.Fatalf("CreateMockTest: %v", err)
	}
	session, err := repo.CreateMockExam("user-learner-1", mockTest.ID)
	if err != nil {
		t.Fatalf("CreateMockExam: %v", err)
	}

	a1, _ := repo.CreateAttempt("user-learner-1", conv.ID, "ios", "0.1.0", "vi")
	repo.CompleteAttempt(a1.ID,
		contracts.Transcript{FullText: "Mluvim cesky kazdy den."},
		contracts.AttemptFeedback{ReadinessLevel: "ready"},
	)
	a2, _ := repo.CreateAttempt("user-learner-1", choice.ID, "ios", "0.1.0", "vi")
	repo.CompleteAttempt(a2.ID,
		contracts.Transcript{FullText: "Vybral jsem byt B."},
		contracts.AttemptFeedback{ReadinessLevel: "needs_work"},
	)

	if _, err := repo.AdvanceMockExam(session.ID, a1.ID); err != nil {
		t.Fatalf("Advance 1: %v", err)
	}
	if _, err := repo.AdvanceMockExam(session.ID, a2.ID); err != nil {
		t.Fatalf("Advance 2: %v", err)
	}
	completed, err := repo.CompleteMockExam(session.ID)
	if err != nil {
		t.Fatalf("CompleteMockExam: %v", err)
	}

	// ready=1.0 × 20 = 20. needs_work=0.5 × 20 = 10. total=30 / 40 = 75%.
	// pass_threshold=80 → 30*100 = 3000, 40*80 = 3200 → fail.
	if completed.OverallScore != 30 {
		t.Fatalf("OverallScore = %d, want 30", completed.OverallScore)
	}
	if completed.Passed {
		t.Fatalf("expected Passed=false (30/40 = 75%% < 80%%), got true")
	}
}
