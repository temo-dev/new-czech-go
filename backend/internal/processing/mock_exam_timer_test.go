package processing

import (
	"testing"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

// V39 — sweeper integration. Tests use the real MemoryStore so the timer
// math, the SetSessionStartedAtForTesting escape hatch, and the
// ExpireMockExam transition are all exercised end-to-end.

func newSweeperFixture(t *testing.T) (*store.MemoryStore, contracts.MockExamSession) {
	t.Helper()
	repo := store.NewMemoryStore()
	ex := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "uloha_1_topic_answers", Status: "published", Pool: "exam",
	})
	mt, err := repo.CreateMockTest(contracts.MockTest{
		Title:  "Sweeper fixture",
		Status: "published",
		Sections: []contracts.MockTestSection{
			{SequenceNo: 1, ExerciseID: ex.ID, ExerciseType: ex.ExerciseType, MaxPoints: 5},
		},
	})
	if err != nil {
		t.Fatalf("CreateMockTest: %v", err)
	}
	session, err := repo.CreateMockExam("learner-1", mt.ID)
	if err != nil {
		t.Fatalf("CreateMockExam: %v", err)
	}
	return repo, session
}

func TestRunMockExamTimerSweep_CompletesExpiredSession(t *testing.T) {
	repo, session := newSweeperFixture(t)
	// Push start back 100 minutes so the 90-minute timer has elapsed.
	if !repo.SetMockExamStartedAtForTesting(session.ID, time.Now().Add(-100*time.Minute)) {
		t.Fatal("SetMockExamStartedAtForTesting failed")
	}

	runMockExamTimerSweep(repo)

	got, ok := repo.MockExamByID(session.ID)
	if !ok {
		t.Fatal("session vanished after sweep")
	}
	if got.Status != "completed" {
		t.Errorf("Status = %q, want completed", got.Status)
	}
	if got.Sections[0].Status != "skipped" {
		t.Errorf("Section status = %q, want skipped (was pending at expiry)", got.Sections[0].Status)
	}
}

func TestRunMockExamTimerSweep_DoubleTickIsIdempotent(t *testing.T) {
	repo, session := newSweeperFixture(t)
	repo.SetMockExamStartedAtForTesting(session.ID, time.Now().Add(-100*time.Minute))

	runMockExamTimerSweep(repo)
	runMockExamTimerSweep(repo) // must not error or revert state

	got, _ := repo.MockExamByID(session.ID)
	if got.Status != "completed" {
		t.Errorf("after double sweep Status = %q, want completed", got.Status)
	}
}

func TestRunMockExamTimerSweep_FreshSessionUntouched(t *testing.T) {
	repo, session := newSweeperFixture(t)
	// No StartedAt push — session is brand new, well within its 90-min window.

	runMockExamTimerSweep(repo)

	got, _ := repo.MockExamByID(session.ID)
	if got.Status != "in_progress" {
		t.Errorf("Status = %q, want in_progress (timer should not have expired)", got.Status)
	}
}
