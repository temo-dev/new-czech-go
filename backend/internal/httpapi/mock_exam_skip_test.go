package httpapi

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

// V39 — skip endpoint contract tests. The endpoint flips a pending section's
// status to 'skipped' and lets the learner advance past it; the section
// remains addressable from the answer sheet (S7).

// skipTestEnv bootstraps a memory-backed server + a 2-section mock exam owned
// by user-learner-1. Returns the session and a function that issues
// `POST /v1/mock-exams/:id/skip` with the given token + display_order.
func skipTestEnv(t *testing.T) (*store.MemoryStore, *httptest.Server, contracts.MockExamSession) {
	t.Helper()
	repo := store.NewMemoryStore()
	reading := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "cteni_1", Status: "published", Pool: "exam",
	})
	speaking := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "uloha_1_topic_answers", Status: "published", Pool: "exam",
	})
	mockTest, err := repo.CreateMockTest(contracts.MockTest{
		Title:                "Skip-test mixed sprint",
		Status:               "published",
		PassThresholdPercent: 60,
		Sections: []contracts.MockTestSection{
			// reading (5 pts) → display_order=1; speaking (8 pts) → display_order=2.
			{SequenceNo: 1, SkillKind: "doc", ExerciseID: reading.ID, ExerciseType: reading.ExerciseType, MaxPoints: 5},
			{SequenceNo: 2, SkillKind: "noi", ExerciseID: speaking.ID, ExerciseType: speaking.ExerciseType, MaxPoints: 8},
		},
	})
	if err != nil {
		t.Fatalf("CreateMockTest: %v", err)
	}
	session, err := repo.CreateMockExam("user-learner-1", mockTest.ID)
	if err != nil {
		t.Fatalf("CreateMockExam: %v", err)
	}
	server := httptest.NewServer(NewServer(repo, nil, nil))
	t.Cleanup(server.Close)
	return repo, server, session
}

func TestMockExamSkip_HappyPathFlipsPendingToSkipped(t *testing.T) {
	_, server, session := skipTestEnv(t)

	status, decoded := postJSONAllowErrorWithToken(t, server,
		"/v1/mock-exams/"+session.ID+"/skip", "dev-learner-token",
		map[string]any{"display_order": 1},
	)
	if status != http.StatusOK {
		t.Fatalf("expected 200, got %d: %#v", status, decoded)
	}
	data := decoded["data"].(map[string]any)
	sections := data["sections"].([]any)
	if len(sections) != 2 {
		t.Fatalf("sections length = %d, want 2", len(sections))
	}
	first := sections[0].(map[string]any)
	if first["status"] != "skipped" {
		t.Fatalf("sections[0].status = %v, want skipped", first["status"])
	}
	second := sections[1].(map[string]any)
	if second["status"] != "pending" {
		t.Fatalf("sections[1].status = %v, want pending (untouched)", second["status"])
	}
}

func TestMockExamSkip_MissingDisplayOrderReturns400(t *testing.T) {
	_, server, session := skipTestEnv(t)

	status, decoded := postJSONAllowErrorWithToken(t, server,
		"/v1/mock-exams/"+session.ID+"/skip", "dev-learner-token",
		map[string]any{},
	)
	if status != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d: %#v", status, decoded)
	}
	if got := decoded["error"].(map[string]any)["code"]; got != "invalid_request" {
		t.Fatalf("error code = %v, want invalid_request", got)
	}
}

func TestMockExamSkip_ZeroDisplayOrderReturns400(t *testing.T) {
	_, server, session := skipTestEnv(t)

	status, _ := postJSONAllowErrorWithToken(t, server,
		"/v1/mock-exams/"+session.ID+"/skip", "dev-learner-token",
		map[string]any{"display_order": 0},
	)
	if status != http.StatusBadRequest {
		t.Fatalf("expected 400 for display_order=0, got %d", status)
	}
}

func TestMockExamSkip_SessionNotFoundReturns404(t *testing.T) {
	_, server, _ := skipTestEnv(t)

	status, _ := postJSONAllowErrorWithToken(t, server,
		"/v1/mock-exams/does-not-exist/skip", "dev-learner-token",
		map[string]any{"display_order": 1},
	)
	if status != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", status)
	}
}

func TestMockExamSkip_OutOfRangeDisplayOrderReturns404(t *testing.T) {
	_, server, session := skipTestEnv(t)

	status, decoded := postJSONAllowErrorWithToken(t, server,
		"/v1/mock-exams/"+session.ID+"/skip", "dev-learner-token",
		map[string]any{"display_order": 99},
	)
	if status != http.StatusNotFound {
		t.Fatalf("expected 404, got %d: %#v", status, decoded)
	}
}

func TestMockExamSkip_AlreadyCompletedSectionReturns409(t *testing.T) {
	repo, server, session := skipTestEnv(t)

	// Complete section display_order=1 (reading) via the normal advance path
	// so its status becomes 'completed'. Skip should then refuse.
	reading := session.Sections[0]
	attempt, err := repo.CreateAttempt("user-learner-1", reading.ExerciseID, "ios", "1.0", "vi")
	if err != nil {
		t.Fatalf("CreateAttempt: %v", err)
	}
	repo.CompleteAttempt(attempt.ID,
		contracts.Transcript{FullText: "ok"},
		contracts.AttemptFeedback{ReadinessLevel: "ready", ObjectiveResult: &contracts.ObjectiveResult{Score: 5, MaxScore: 5}},
	)
	if _, err := repo.AdvanceMockExam(session.ID, attempt.ID); err != nil {
		t.Fatalf("AdvanceMockExam: %v", err)
	}

	status, decoded := postJSONAllowErrorWithToken(t, server,
		"/v1/mock-exams/"+session.ID+"/skip", "dev-learner-token",
		map[string]any{"display_order": 1},
	)
	if status != http.StatusConflict {
		t.Fatalf("expected 409, got %d: %#v", status, decoded)
	}
	if got := decoded["error"].(map[string]any)["code"]; got != "section_not_skippable" {
		t.Fatalf("error code = %v, want section_not_skippable", got)
	}
}

func TestMockExamSkip_AlreadySkippedSectionReturns409(t *testing.T) {
	_, server, session := skipTestEnv(t)

	// First skip succeeds.
	status, _ := postJSONAllowErrorWithToken(t, server,
		"/v1/mock-exams/"+session.ID+"/skip", "dev-learner-token",
		map[string]any{"display_order": 1},
	)
	if status != http.StatusOK {
		t.Fatalf("first skip expected 200, got %d", status)
	}

	// Second skip on the same section is rejected.
	status, decoded := postJSONAllowErrorWithToken(t, server,
		"/v1/mock-exams/"+session.ID+"/skip", "dev-learner-token",
		map[string]any{"display_order": 1},
	)
	if status != http.StatusConflict {
		t.Fatalf("second skip expected 409, got %d: %#v", status, decoded)
	}
}

// V39 — `GET /v1/mock-exams/:id?include_server_time=true` exposes the
// server's clock under `meta.server_time` so the client can render the
// countdown without drift assumptions.
func TestGetMockExam_IncludeServerTimeAddsMetaField(t *testing.T) {
	_, server, session := skipTestEnv(t)

	req, err := http.NewRequest(http.MethodGet, server.URL+"/v1/mock-exams/"+session.ID+"?include_server_time=true", nil)
	if err != nil {
		t.Fatalf("NewRequest: %v", err)
	}
	req.Header.Set("Authorization", "Bearer dev-learner-token")
	resp, err := server.Client().Do(req)
	if err != nil {
		t.Fatalf("Do: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}
	var decoded map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&decoded); err != nil {
		t.Fatalf("decode: %v", err)
	}
	meta, ok := decoded["meta"].(map[string]any)
	if !ok {
		t.Fatal("meta missing")
	}
	if _, present := meta["server_time"]; !present {
		t.Errorf("meta.server_time absent; meta=%#v", meta)
	}
}

func TestGetMockExam_OmitsServerTimeWhenQueryParamMissing(t *testing.T) {
	_, server, session := skipTestEnv(t)

	req, _ := http.NewRequest(http.MethodGet, server.URL+"/v1/mock-exams/"+session.ID, nil)
	req.Header.Set("Authorization", "Bearer dev-learner-token")
	resp, _ := server.Client().Do(req)
	defer resp.Body.Close()
	var decoded map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&decoded); err != nil {
		t.Fatalf("decode: %v", err)
	}
	meta, _ := decoded["meta"].(map[string]any)
	if _, present := meta["server_time"]; present {
		t.Errorf("meta.server_time should be omitted; meta=%#v", meta)
	}
}

// V39 S9 — `POST /v1/mock-exams/:id/expire` is the learner-facing
// "Nộp bài ngay" path. Marks remaining pending sections as 'skipped'
// and flips the session to 'completed' in one round-trip.

func TestMockExamExpire_HappyPathFlipsPendingAndCompletes(t *testing.T) {
	_, server, session := skipTestEnv(t)

	status, decoded := postJSONAllowErrorWithToken(t, server,
		"/v1/mock-exams/"+session.ID+"/expire", "dev-learner-token",
		map[string]any{},
	)
	if status != http.StatusOK {
		t.Fatalf("expected 200, got %d: %#v", status, decoded)
	}
	data := decoded["data"].(map[string]any)
	if data["status"] != "completed" {
		t.Fatalf("session status = %v, want completed", data["status"])
	}
	for _, raw := range data["sections"].([]any) {
		s := raw.(map[string]any)
		if s["status"] == "pending" {
			t.Errorf("pending section remained after expire: %v", s)
		}
	}
}

func TestMockExamExpire_IdempotentOnCompletedSession(t *testing.T) {
	_, server, session := skipTestEnv(t)

	// First call → completes.
	if status, _ := postJSONAllowErrorWithToken(t, server,
		"/v1/mock-exams/"+session.ID+"/expire", "dev-learner-token",
		map[string]any{},
	); status != http.StatusOK {
		t.Fatalf("first expire expected 200, got %d", status)
	}
	// Second call → still 200 (no-op).
	status, _ := postJSONAllowErrorWithToken(t, server,
		"/v1/mock-exams/"+session.ID+"/expire", "dev-learner-token",
		map[string]any{},
	)
	if status != http.StatusOK {
		t.Fatalf("second expire expected 200 (idempotent), got %d", status)
	}
}

func TestMockExamExpire_DifferentLearnerReturns403(t *testing.T) {
	_, server, session := skipTestEnv(t)
	status, decoded := postJSONAllowErrorWithToken(t, server,
		"/v1/mock-exams/"+session.ID+"/expire", "dev-learner-2-token",
		map[string]any{},
	)
	if status != http.StatusForbidden {
		t.Fatalf("expected 403, got %d: %#v", status, decoded)
	}
}

func TestMockExamExpire_UnknownSessionReturns404(t *testing.T) {
	_, server, _ := skipTestEnv(t)
	status, _ := postJSONAllowErrorWithToken(t, server,
		"/v1/mock-exams/no-such-id/expire", "dev-learner-token",
		map[string]any{},
	)
	if status != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", status)
	}
}

func TestMockExamSkip_DifferentLearnerReturns403(t *testing.T) {
	_, server, session := skipTestEnv(t)

	status, decoded := postJSONAllowErrorWithToken(t, server,
		"/v1/mock-exams/"+session.ID+"/skip", "dev-learner-2-token",
		map[string]any{"display_order": 1},
	)
	if status != http.StatusForbidden {
		t.Fatalf("expected 403, got %d: %#v", status, decoded)
	}
	if got := decoded["error"].(map[string]any)["code"]; got != "forbidden" {
		t.Fatalf("error code = %v, want forbidden", got)
	}
}
