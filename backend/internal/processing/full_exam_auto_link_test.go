package processing

import (
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// TestAutoLinkUstniSession verifies that findOpenFullExamForAutoLink returns
// the first FullExamSession in 'pisemna_done' status with no ustni link.
func TestAutoLinkUstniSession(t *testing.T) {
	sessions := []contracts.FullExamSession{
		{ID: "fe-completed", LearnerID: "l1", Status: "completed", UstniMockExamSessionID: "some-id"},
		{ID: "fe-open",      LearnerID: "l1", Status: "pisemna_done"},
		{ID: "fe-linked",    LearnerID: "l1", Status: "pisemna_done", UstniMockExamSessionID: "already-linked"},
	}

	got := FindOpenFullExamForAutoLink(sessions)

	if got == nil {
		t.Fatal("expected to find open full exam session")
	}
	if got.ID != "fe-open" {
		t.Errorf("expected fe-open, got %s", got.ID)
	}
}

func TestAutoLinkUstniSession_NoneAvailable(t *testing.T) {
	sessions := []contracts.FullExamSession{
		{ID: "fe-1", LearnerID: "l1", Status: "completed"},
		{ID: "fe-2", LearnerID: "l1", Status: "pisemna_done", UstniMockExamSessionID: "linked"},
	}
	got := FindOpenFullExamForAutoLink(sessions)
	if got != nil {
		t.Errorf("expected nil, got %+v", got)
	}
}
