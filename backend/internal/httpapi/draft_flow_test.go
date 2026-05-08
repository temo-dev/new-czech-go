package httpapi

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/processing"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

// TestV24DraftFlow_E2E_AdminGeneratesAndSavesCteni2 exercises the V24 happy
// path end-to-end against the in-process HTTP server:
//
//	seed grammar rule → POST /v1/admin/exercises/generate-draft (mock LLM)
//	→ POST /v1/admin/exercises with {created_by_llm: true, detail: <draft>}
//	→ GET /v1/admin/exercises/<id> → assert created_by_llm round-trips.
//
// Standalone smoke target — `make smoke-draft-flow` shells out to
// `go test -run TestV24DraftFlow_E2E`. Self-contained, no real Claude
// API key required, no docker bring-up.
func TestV24DraftFlow_E2E_AdminGeneratesAndSavesCteni2(t *testing.T) {
	repo := store.NewMemoryStore()
	rule, err := repo.CreateGrammarRule(contracts.GrammarRule{
		Title:    "minulý čas",
		Level:    "A2",
		ModuleID: "module-day-1",
	})
	if err != nil {
		t.Fatalf("seed grammar: %v", err)
	}

	mockDraft := &contracts.ReadingDraft{
		ExerciseType: "cteni_2",
		Detail: contracts.Cteni2Detail{
			Text: "Pavel byl nemocný a šel k lékaři.",
			Questions: []contracts.ReadingQuestion{
				draftQ(6, "Q1?"), draftQ(7, "Q2?"), draftQ(8, "Q3?"),
				draftQ(9, "Q4?"), draftQ(10, "Q5?"),
			},
			CorrectAnswers: map[string]string{"6": "A", "7": "B", "8": "C", "9": "D", "10": "A"},
		},
		Metadata: contracts.ReadingDraftMeta{Model: "mock", DurationMs: 1},
	}

	s := &Server{
		repo:                  repo,
		readingDraftGenerator: &processing.MockReadingDraftGenerator{Draft: mockDraft},
		readingDraftRL:        newReadingDraftRateLimiter(),
		mux:                   http.NewServeMux(),
	}
	s.routes()
	srv := httptest.NewServer(s.withCORS(s.mux))
	defer srv.Close()

	// 1. POST generate-draft → 200 with detail + metadata.
	genResp := postJSONWithToken(t, srv, "/v1/admin/exercises/generate-draft", adminToken, map[string]any{
		"exercise_type":     "cteni_2",
		"topic":             "đi khám bác sĩ",
		"grammar_point_ids": []string{rule.ID},
		"level":             "A2",
	})
	data, ok := genResp["data"].(map[string]any)
	if !ok {
		t.Fatalf("expected data object, got %v", genResp)
	}
	detail, ok := data["detail"].(map[string]any)
	if !ok {
		t.Fatalf("expected detail object, got %v", data)
	}
	if data["exercise_type"] != "cteni_2" {
		t.Fatalf("expected cteni_2 exercise_type, got %v", data["exercise_type"])
	}

	// 2. POST exercise with the AI-generated detail + created_by_llm flag.
	createResp := postJSONWithToken(t, srv, "/v1/admin/exercises", adminToken, map[string]any{
		"exercise_type":          "cteni_2",
		"title":                  "AI-drafted reading",
		"short_instruction":      "Doc text.",
		"learner_instruction":    "Doc va vyber spravnou odpoved.",
		"estimated_duration_sec": 180,
		"sample_answer_enabled":  false,
		"module_id":              "module-day-1",
		"skill_kind":             "doc",
		"detail":                 detail,
		"created_by_llm":         true,
	})
	created, ok := createResp["data"].(map[string]any)
	if !ok {
		t.Fatalf("expected data object on create, got %v", createResp)
	}
	exerciseID, _ := created["id"].(string)
	if exerciseID == "" {
		t.Fatalf("expected exercise id on create, got %v", created)
	}
	if got, _ := created["created_by_llm"].(bool); !got {
		t.Fatalf("expected created_by_llm=true on create response, got %v", created["created_by_llm"])
	}

	// 3. GET exercise → assert flag round-trips through the store.
	req, _ := http.NewRequest(http.MethodGet, srv.URL+"/v1/admin/exercises/"+exerciseID, nil)
	req.Header.Set("Authorization", "Bearer "+adminToken)
	resp, err := srv.Client().Do(req)
	if err != nil {
		t.Fatalf("GET exercise: %v", err)
	}
	defer resp.Body.Close()
	var got map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&got); err != nil {
		t.Fatalf("decode GET response: %v", err)
	}
	gotData, _ := got["data"].(map[string]any)
	if got, _ := gotData["created_by_llm"].(bool); !got {
		t.Fatalf("expected created_by_llm=true after refetch, got %v", gotData["created_by_llm"])
	}
}

func draftQ(no int, prompt string) contracts.ReadingQuestion {
	return contracts.ReadingQuestion{
		QuestionNo: no,
		Prompt:     prompt,
		Options: []contracts.MultipleChoiceOption{
			{Key: "A", Text: "a"},
			{Key: "B", Text: "b"},
			{Key: "C", Text: "c"},
			{Key: "D", Text: "d"},
		},
	}
}
