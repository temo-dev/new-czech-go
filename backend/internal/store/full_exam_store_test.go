package store

import (
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

func TestFullExamStore_SetAndGet(t *testing.T) {
	s := newMemoryFullExamStore()

	sess := contracts.FullExamSession{
		ID:            "fullexam-test-1",
		LearnerID:     "learner-1",
		PisemnaScore:  50,
		UstniScore:    30,
		PisemnaPassed: true,
		UstniPassed:   true,
		OverallPassed: true,
		Status:        "completed",
	}

	s.SetFullExamSession(sess)

	got, ok := s.GetFullExamSession("fullexam-test-1")
	if !ok {
		t.Fatal("expected session to be found")
	}
	if got.LearnerID != "learner-1" {
		t.Errorf("expected learner-1, got %s", got.LearnerID)
	}
	if got.PisemnaScore != 50 {
		t.Errorf("expected 50, got %d", got.PisemnaScore)
	}
	if !got.OverallPassed {
		t.Error("expected OverallPassed=true")
	}
}

func TestFullExamStore_List(t *testing.T) {
	s := newMemoryFullExamStore()

	s.SetFullExamSession(contracts.FullExamSession{ID: "fe-1", LearnerID: "learner-A", Status: "completed"})
	s.SetFullExamSession(contracts.FullExamSession{ID: "fe-2", LearnerID: "learner-A", Status: "in_progress"})
	s.SetFullExamSession(contracts.FullExamSession{ID: "fe-3", LearnerID: "learner-B", Status: "completed"})

	listA := s.ListFullExamSessions("learner-A")
	if len(listA) != 2 {
		t.Errorf("expected 2 for learner-A, got %d", len(listA))
	}
	listB := s.ListFullExamSessions("learner-B")
	if len(listB) != 1 {
		t.Errorf("expected 1 for learner-B, got %d", len(listB))
	}
}

func TestFullExamStore_GetMissing(t *testing.T) {
	s := newMemoryFullExamStore()
	_, ok := s.GetFullExamSession("nonexistent")
	if ok {
		t.Fatal("expected not found for missing session")
	}
}
