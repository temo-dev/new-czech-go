package httpapi

import (
	"net/http/httptest"
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/store"
)

// Helpers postJSONWithToken and postJSONAllowErrorWithToken are defined in server_test.go.

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

func TestAdminCreateExercise_InterviewChoiceExplain_TooFewOptions_Rejected(t *testing.T) {
	repo := store.NewMemoryStore()
	server := httptest.NewServer(NewServer(repo, nil, nil))
	defer server.Close()

	status, resp := postJSONAllowErrorWithToken(t, server, "/v1/admin/exercises", "dev-admin-token", map[string]any{
		"module_id":     "module-interview-1",
		"exercise_type": "interview_choice_explain",
		"title":         "Too few",
		"detail": map[string]any{
			"question":      "Kde bydlíte?",
			"system_prompt": "You are Jana.",
			"options": []map[string]any{
				{"id": "1", "label": "Praha"},
				{"id": "2", "label": "Brno"},
			},
		},
	})

	if status != 400 {
		t.Fatalf("expected 400 for too few options, got %d; resp: %v", status, resp)
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
