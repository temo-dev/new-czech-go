package httpapi

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

// V39 — `POST /v1/mock-exams/:id/advance` with `target_display_order` lets
// the sheet jump back into a previously-skipped (or completed) section.
// Without the field, behaviour is the legacy first-pending advance.

func advanceAtEnv(t *testing.T) (*store.MemoryStore, *httptest.Server, contracts.MockExamSession, contracts.Exercise, contracts.Exercise) {
	t.Helper()
	repo := store.NewMemoryStore()
	reading := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "cteni_1", Status: "published", Pool: "exam",
	})
	speaking := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "uloha_1_topic_answers", Status: "published", Pool: "exam",
	})
	mt, _ := repo.CreateMockTest(contracts.MockTest{
		Title:                "Jump-back fixture",
		Status:               "published",
		PassThresholdPercent: 60,
		Sections: []contracts.MockTestSection{
			// reading (5 pts) → display_order=1; speaking (8 pts) → display_order=2.
			{SequenceNo: 1, SkillKind: "doc", ExerciseID: reading.ID, ExerciseType: reading.ExerciseType, MaxPoints: 5},
			{SequenceNo: 2, SkillKind: "noi", ExerciseID: speaking.ID, ExerciseType: speaking.ExerciseType, MaxPoints: 8},
		},
	})
	session, err := repo.CreateMockExam("user-learner-1", mt.ID)
	if err != nil {
		t.Fatalf("CreateMockExam: %v", err)
	}
	server := httptest.NewServer(NewServer(repo, nil, nil))
	t.Cleanup(server.Close)
	return repo, server, session, reading, speaking
}

func TestMockExamAdvance_TargetDisplayOrder_FlipsSkippedToCompleted(t *testing.T) {
	repo, server, session, reading, _ := advanceAtEnv(t)

	// Skip the reading section so it carries status='skipped'.
	if _, err := repo.SkipMockExamSection(session.ID, 1); err != nil {
		t.Fatalf("SkipMockExamSection: %v", err)
	}
	// Create + complete an attempt for the reading exercise that the learner
	// re-answered via the sheet jump.
	att, err := repo.CreateAttempt("user-learner-1", reading.ID, "ios", "1.0", "vi")
	if err != nil {
		t.Fatalf("CreateAttempt: %v", err)
	}
	repo.CompleteAttempt(att.ID,
		contracts.Transcript{FullText: "ok"},
		contracts.AttemptFeedback{ReadinessLevel: "ready"},
	)

	status, decoded := postJSONAllowErrorWithToken(t, server,
		"/v1/mock-exams/"+session.ID+"/advance", "dev-learner-token",
		map[string]any{
			"attempt_id":           att.ID,
			"target_display_order": 1,
		},
	)
	if status != http.StatusOK {
		t.Fatalf("expected 200, got %d: %#v", status, decoded)
	}
	data := decoded["data"].(map[string]any)
	sections := data["sections"].([]any)
	var reading0 map[string]any
	for _, raw := range sections {
		s := raw.(map[string]any)
		if int(s["display_order"].(float64)) == 1 {
			reading0 = s
			break
		}
	}
	if reading0 == nil {
		t.Fatal("display_order=1 missing from response")
	}
	if reading0["status"] != "completed" {
		t.Errorf("reading status = %v, want completed (jump-back overwrote skipped)", reading0["status"])
	}
	if reading0["attempt_id"] != att.ID {
		t.Errorf("attempt_id = %v, want %s", reading0["attempt_id"], att.ID)
	}
}

func TestMockExamAdvance_LegacyPathStillWorksWithoutTarget(t *testing.T) {
	repo, server, session, reading, _ := advanceAtEnv(t)

	att, err := repo.CreateAttempt("user-learner-1", reading.ID, "ios", "1.0", "vi")
	if err != nil {
		t.Fatalf("CreateAttempt: %v", err)
	}
	repo.CompleteAttempt(att.ID,
		contracts.Transcript{FullText: "ok"},
		contracts.AttemptFeedback{ReadinessLevel: "ready"},
	)

	status, _ := postJSONAllowErrorWithToken(t, server,
		"/v1/mock-exams/"+session.ID+"/advance", "dev-learner-token",
		map[string]any{"attempt_id": att.ID}, // no target_display_order
	)
	if status != http.StatusOK {
		t.Fatalf("legacy advance expected 200, got %d", status)
	}
}

func TestMockExamAdvance_TargetDisplayOrder_404ForUnknownSection(t *testing.T) {
	repo, server, session, reading, _ := advanceAtEnv(t)

	att, _ := repo.CreateAttempt("user-learner-1", reading.ID, "ios", "1.0", "vi")
	repo.CompleteAttempt(att.ID,
		contracts.Transcript{FullText: "ok"},
		contracts.AttemptFeedback{ReadinessLevel: "ready"},
	)

	status, _ := postJSONAllowErrorWithToken(t, server,
		"/v1/mock-exams/"+session.ID+"/advance", "dev-learner-token",
		map[string]any{
			"attempt_id":           att.ID,
			"target_display_order": 99,
		},
	)
	if status != http.StatusBadRequest {
		// AdvanceSectionAt returns ErrSectionNotFound; handler wraps it
		// into 400 via the existing mock_exam_advance_failed branch.
		t.Fatalf("expected 400, got %d", status)
	}
}
