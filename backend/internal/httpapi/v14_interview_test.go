package httpapi

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

// Helpers are defined in server_test.go (same package).

// IV-1: skillKindForExerciseType maps interview_* → "interview"

func TestSkillKindForInterviewConversation(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	resp := postJSONWithToken(t, server, "/v1/admin/exercises", "dev-admin-token", map[string]any{
		"module_id":     "module-interview-1",
		"exercise_type": "interview_conversation",
		"title":         "Gia đình và bạn bè",
		"detail": map[string]any{
			"topic":           "Gia đình và bạn bè",
			"system_prompt":   "You are Jana, a Czech A2 examiner. Ask about family.",
			"max_turns":       8,
			"show_transcript": true,
		},
	})

	data := resp["data"].(map[string]any)
	if data["skill_kind"] != "interview" {
		t.Fatalf("expected skill_kind=interview, got %v", data["skill_kind"])
	}
	if data["exercise_type"] != "interview_conversation" {
		t.Fatalf("expected exercise_type=interview_conversation, got %v", data["exercise_type"])
	}
}

func TestSkillKindForInterviewChoiceExplain(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	resp := postJSONWithToken(t, server, "/v1/admin/exercises", "dev-admin-token", map[string]any{
		"module_id":     "module-interview-1",
		"exercise_type": "interview_choice_explain",
		"title":         "Chọn địa điểm du lịch",
		"detail": map[string]any{
			"question":      "Bạn muốn đi du lịch ở đâu?",
			"system_prompt": "You are Jana. The learner chose {selected_option}. Ask why.",
			"max_turns":     6,
			"options": []map[string]any{
				{"id": "1", "label": "Praha"},
				{"id": "2", "label": "Brno"},
				{"id": "3", "label": "Krkonoše"},
			},
		},
	})

	data := resp["data"].(map[string]any)
	if data["skill_kind"] != "interview" {
		t.Fatalf("expected skill_kind=interview, got %v", data["skill_kind"])
	}
}

func TestAdminCreateExercise_InterviewConversation_DetailRoundTrip(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	resp := postJSONWithToken(t, server, "/v1/admin/exercises", "dev-admin-token", map[string]any{
		"module_id":     "module-interview-1",
		"exercise_type": "interview_conversation",
		"title":         "Práce a zaměstnání",
		"detail": map[string]any{
			"topic":           "Práce a zaměstnání",
			"tips":            []string{"Odpovídejte celou větou", "Použijte sloveso pracovat"},
			"system_prompt":   "You are Jana, a Czech A2 examiner. Interview about work.",
			"max_turns":       8,
			"show_transcript": false,
		},
	})

	data := resp["data"].(map[string]any)
	detail := data["detail"].(map[string]any)
	if detail["topic"] != "Práce a zaměstnání" {
		t.Fatalf("expected topic to round-trip, got %v", detail["topic"])
	}
	if detail["system_prompt"] == "" {
		t.Fatal("expected system_prompt to persist")
	}
}

func TestAdminCreateExercise_InterviewChoiceExplain_3Options_Valid(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	resp := postJSONWithToken(t, server, "/v1/admin/exercises", "dev-admin-token", map[string]any{
		"module_id":     "module-interview-1",
		"exercise_type": "interview_choice_explain",
		"title":         "Volný čas",
		"detail": map[string]any{
			"question":      "Co děláte o víkendu?",
			"system_prompt": "You are Jana. The learner chose {selected_option}.",
			"max_turns":     6,
			"options": []map[string]any{
				{"id": "1", "label": "Sportuji"},
				{"id": "2", "label": "Čtu knihy"},
				{"id": "3", "label": "Vařím"},
			},
		},
	})

	data := resp["data"].(map[string]any)
	detail := data["detail"].(map[string]any)
	opts := detail["options"].([]any)
	if len(opts) != 3 {
		t.Fatalf("expected 3 options to round-trip, got %d", len(opts))
	}
}

func TestAdminCreateExercise_InterviewChoiceExplain_4Options_Valid(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	resp := postJSONWithToken(t, server, "/v1/admin/exercises", "dev-admin-token", map[string]any{
		"module_id":     "module-interview-1",
		"exercise_type": "interview_choice_explain",
		"title":         "Volný čas 4",
		"detail": map[string]any{
			"question":      "Co rádi děláte?",
			"system_prompt": "You are Jana. The learner chose {selected_option}.",
			"max_turns":     6,
			"options": []map[string]any{
				{"id": "1", "label": "Praha"},
				{"id": "2", "label": "Brno"},
				{"id": "3", "label": "Ostrava"},
				{"id": "4", "label": "Plzeň"},
			},
		},
	})

	data := resp["data"].(map[string]any)
	if data["exercise_type"] != "interview_choice_explain" {
		t.Fatalf("expected exercise_type=interview_choice_explain, got %v", data["exercise_type"])
	}
}

func TestAdminCreateExercise_InterviewChoiceExplain_OneOption_Valid(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	status, resp := postJSONAllowErrorWithToken(t, server, "/v1/admin/exercises", "dev-admin-token", map[string]any{
		"module_id":     "module-interview-1",
		"exercise_type": "interview_choice_explain",
		"title":         "One option",
		"detail": map[string]any{
			"question":      "Jaké boty chcete?",
			"system_prompt": "You are Jana.",
			"max_turns":     2,
			"options": []map[string]any{
				{"id": "1", "label": "Bílé boty"},
			},
		},
	})

	if status != 201 {
		t.Fatalf("expected 201 for one option, got %d; resp: %v", status, resp)
	}
}

func TestAdminCreateExercise_InterviewChoiceExplain_NoOptions_Rejected(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	status, resp := postJSONAllowErrorWithToken(t, server, "/v1/admin/exercises", "dev-admin-token", map[string]any{
		"module_id":     "module-interview-1",
		"exercise_type": "interview_choice_explain",
		"title":         "No options",
		"detail": map[string]any{
			"question":      "Kde bydlíte?",
			"system_prompt": "You are Jana.",
			"options":       []map[string]any{},
		},
	})

	if status != 400 {
		t.Fatalf("expected 400 for no options, got %d; resp: %v", status, resp)
	}
}

func TestAdminCreateExercise_InterviewChoiceExplain_TooManyOptions_Rejected(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	status, resp := postJSONAllowErrorWithToken(t, server, "/v1/admin/exercises", "dev-admin-token", map[string]any{
		"module_id":     "module-interview-1",
		"exercise_type": "interview_choice_explain",
		"title":         "Too many",
		"detail": map[string]any{
			"question":      "Co máte rádi?",
			"system_prompt": "You are Jana.",
			"options": []map[string]any{
				{"id": "1", "label": "A"},
				{"id": "2", "label": "B"},
				{"id": "3", "label": "C"},
				{"id": "4", "label": "D"},
				{"id": "5", "label": "E"},
			},
		},
	})

	if status != 400 {
		t.Fatalf("expected 400 for too many options, got %d; resp: %v", status, resp)
	}
}

func TestAdminCreateExercise_InterviewConversation_EmptySystemPrompt_Rejected(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	status, resp := postJSONAllowErrorWithToken(t, server, "/v1/admin/exercises", "dev-admin-token", map[string]any{
		"module_id":     "module-interview-1",
		"exercise_type": "interview_conversation",
		"title":         "Empty prompt",
		"detail": map[string]any{
			"topic":         "Rodina",
			"system_prompt": "",
			"max_turns":     8,
		},
	})

	if status != 400 {
		t.Fatalf("expected 400 for empty system_prompt, got %d; resp: %v", status, resp)
	}
}

func TestAdminCreateExercise_InterviewChoiceExplain_EmptySystemPrompt_Rejected(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	status, resp := postJSONAllowErrorWithToken(t, server, "/v1/admin/exercises", "dev-admin-token", map[string]any{
		"module_id":     "module-interview-1",
		"exercise_type": "interview_choice_explain",
		"title":         "Empty prompt choice",
		"detail": map[string]any{
			"question":      "Kde bydlíte?",
			"system_prompt": "",
			"options": []map[string]any{
				{"id": "1", "label": "Praha"},
				{"id": "2", "label": "Brno"},
				{"id": "3", "label": "Ostrava"},
			},
		},
	})

	if status != 400 {
		t.Fatalf("expected 400 for empty system_prompt in choice_explain, got %d; resp: %v", status, resp)
	}
}

// IV-2: interview-sessions/token — 503 when no API key configured

func TestInterviewSessionToken_NoAPIKey_Returns503(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	// Create an exercise and attempt first
	exerciseResp := postJSONWithToken(t, server, "/v1/admin/exercises", "dev-admin-token", map[string]any{
		"module_id":     "mod-1",
		"exercise_type": "interview_conversation",
		"title":         "Test interview",
		"detail": map[string]any{
			"topic":         "Familie",
			"system_prompt": "You are Jana.",
			"max_turns":     6,
		},
	})
	exerciseID := exerciseResp["data"].(map[string]any)["id"].(string)

	attemptResp := postJSONWithToken(t, server, "/v1/attempts", "dev-learner-token", map[string]any{
		"exercise_id": exerciseID,
	})
	attemptID := attemptResp["data"].(map[string]any)["attempt"].(map[string]any)["id"].(string)

	status, _ := postJSONAllowErrorWithToken(t, server, "/v1/interview-sessions/token", "dev-learner-token", map[string]any{
		"exercise_id": exerciseID,
		"attempt_id":  attemptID,
	})

	// No ELEVENLABS_API_KEY set in test env → 503
	if status != http.StatusServiceUnavailable {
		t.Fatalf("expected 503 when no API key configured, got %d", status)
	}
}

func TestInterviewSessionToken_WrongOwner_Returns403(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	exerciseResp := postJSONWithToken(t, server, "/v1/admin/exercises", "dev-admin-token", map[string]any{
		"module_id":     "mod-1",
		"exercise_type": "interview_conversation",
		"title":         "Test interview",
		"detail": map[string]any{
			"topic":         "Familie",
			"system_prompt": "You are Jana.",
			"max_turns":     6,
		},
	})
	exerciseID := exerciseResp["data"].(map[string]any)["id"].(string)

	// Create attempt as learner 1
	attemptResp := postJSONWithToken(t, server, "/v1/attempts", "dev-learner-token", map[string]any{
		"exercise_id": exerciseID,
	})
	attemptID := attemptResp["data"].(map[string]any)["attempt"].(map[string]any)["id"].(string)

	// Try to get token as learner 2
	status, _ := postJSONAllowErrorWithToken(t, server, "/v1/interview-sessions/token", "dev-learner-2-token", map[string]any{
		"exercise_id": exerciseID,
		"attempt_id":  attemptID,
	})

	if status != http.StatusForbidden {
		t.Fatalf("expected 403 for wrong owner, got %d", status)
	}
}

func TestInterviewSessionToken_MissingFields_Returns400(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	status, _ := postJSONAllowErrorWithToken(t, server, "/v1/interview-sessions/token", "dev-learner-token", map[string]any{
		"exercise_id": "ex-1",
		// missing attempt_id
	})

	if status != http.StatusBadRequest {
		t.Fatalf("expected 400 for missing attempt_id, got %d", status)
	}
}

// IV-2: submit-interview

func TestSubmitInterview_Valid_ReturnsScoringStatus(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	exerciseResp := postJSONWithToken(t, server, "/v1/admin/exercises", "dev-admin-token", map[string]any{
		"module_id":     "mod-1",
		"exercise_type": "interview_conversation",
		"title":         "Familie",
		"detail": map[string]any{
			"topic":         "Familie",
			"system_prompt": "You are Jana.",
			"max_turns":     6,
		},
	})
	exerciseID := exerciseResp["data"].(map[string]any)["id"].(string)

	attemptResp := postJSONWithToken(t, server, "/v1/attempts", "dev-learner-token", map[string]any{
		"exercise_id": exerciseID,
	})
	attemptID := attemptResp["data"].(map[string]any)["attempt"].(map[string]any)["id"].(string)

	resp := postJSONWithToken(t, server, fmt.Sprintf("/v1/attempts/%s/submit-interview", attemptID), "dev-learner-token", map[string]any{
		"transcript": []map[string]any{
			{"speaker": "examiner", "text": "Jak se jmenujete?", "at_sec": 0},
			{"speaker": "learner", "text": "Jmenuji se Anna.", "at_sec": 3},
		},
		"duration_sec": 60,
	})

	data := resp["data"].(map[string]any)
	if data["status"] != "scoring" {
		t.Fatalf("expected status=scoring, got %v", data["status"])
	}
	if data["attempt_id"] != attemptID {
		t.Fatalf("expected attempt_id=%s, got %v", attemptID, data["attempt_id"])
	}
}

func TestSubmitInterview_WrongOwner_Returns403(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	exerciseResp := postJSONWithToken(t, server, "/v1/admin/exercises", "dev-admin-token", map[string]any{
		"module_id":     "mod-1",
		"exercise_type": "interview_conversation",
		"title":         "Familie",
		"detail": map[string]any{
			"topic":         "Familie",
			"system_prompt": "You are Jana.",
			"max_turns":     6,
		},
	})
	exerciseID := exerciseResp["data"].(map[string]any)["id"].(string)

	attemptResp := postJSONWithToken(t, server, "/v1/attempts", "dev-learner-token", map[string]any{
		"exercise_id": exerciseID,
	})
	attemptID := attemptResp["data"].(map[string]any)["attempt"].(map[string]any)["id"].(string)

	status, _ := postJSONAllowErrorWithToken(t, server, fmt.Sprintf("/v1/attempts/%s/submit-interview", attemptID), "dev-learner-2-token", map[string]any{
		"transcript":   []map[string]any{},
		"duration_sec": 10,
	})
	if status != http.StatusForbidden {
		t.Fatalf("expected 403, got %d", status)
	}
}

// Ensure unused import doesn't cause compile error
var _ = contracts.InterviewOption{}
