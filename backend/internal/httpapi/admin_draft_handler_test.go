package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/processing"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

const (
	adminDraftPath = "/v1/admin/exercises/generate-draft"
)

// ── test helpers ──────────────────────────────────────────────────────────────

func validReadingDraft() *contracts.ReadingDraft {
	return &contracts.ReadingDraft{
		ExerciseType: "cteni_2",
		Detail: contracts.Cteni2Detail{
			Text: testDraftPassage(120),
			Questions: []contracts.ReadingQuestion{
				{QuestionNo: 6, Prompt: "Q1?", Options: fourOptions()},
				{QuestionNo: 7, Prompt: "Q2?", Options: fourOptions()},
				{QuestionNo: 8, Prompt: "Q3?", Options: fourOptions()},
				{QuestionNo: 9, Prompt: "Q4?", Options: fourOptions()},
				{QuestionNo: 10, Prompt: "Q5?", Options: fourOptions()},
			},
			CorrectAnswers: map[string]string{"6": "A", "7": "B", "8": "C", "9": "D", "10": "A"},
		},
		Metadata: contracts.ReadingDraftMeta{Model: "mock", DurationMs: 1},
	}
}

func testDraftPassage(words int) string {
	return strings.TrimSpace(strings.Repeat("slovo ", words))
}

func fourOptions() []contracts.MultipleChoiceOption {
	return []contracts.MultipleChoiceOption{
		{Key: "A", Text: "a"},
		{Key: "B", Text: "b"},
		{Key: "C", Text: "c"},
		{Key: "D", Text: "d"},
	}
}

// adminDraftServer wires a Server with the given mock and a seeded grammar
// rule for tests.
func adminDraftServer(t *testing.T, gen processing.ReadingDraftGenerator) (*httptest.Server, *store.MemoryStore, string) {
	t.Helper()
	repo := store.NewMemoryStore()
	rule, err := repo.CreateGrammarRule(contracts.GrammarRule{
		Title:    "minulý čas",
		Level:    "A2",
		ModuleID: "module-day-1",
	})
	if err != nil {
		t.Fatalf("seed grammar rule: %v", err)
	}

	s := &Server{
		repo:                  repo,
		readingDraftGenerator: gen,
		readingDraftRL:        newReadingDraftRateLimiter(),
		mux:                   http.NewServeMux(),
	}
	s.routes()
	srv := httptest.NewServer(s.withCORS(s.mux))
	t.Cleanup(srv.Close)
	return srv, repo, rule.ID
}

func validDraftBody(grammarID string) map[string]any {
	return map[string]any{
		"exercise_type":      "cteni_2",
		"topic":              "đi khám bác sĩ",
		"grammar_point_ids":  []string{grammarID},
		"level":              "A2",
		"extra_instructions": "tone neutral",
	}
}

// ── tests ─────────────────────────────────────────────────────────────────────

func TestGenerateDraft_HappyPath_ReturnsDraft(t *testing.T) {
	mock := &processing.MockReadingDraftGenerator{Draft: validReadingDraft()}
	srv, _, gid := adminDraftServer(t, mock)

	resp := postJSONWithToken(t, srv, adminDraftPath, adminToken, validDraftBody(gid))

	data, ok := resp["data"].(map[string]any)
	if !ok {
		t.Fatalf("expected data object, got %v", resp)
	}
	if data["exercise_type"] != "cteni_2" {
		t.Fatalf("expected exercise_type cteni_2, got %v", data["exercise_type"])
	}
	if _, hasDetail := data["detail"]; !hasDetail {
		t.Fatal("expected detail in response")
	}
	if _, hasMeta := data["metadata"]; !hasMeta {
		t.Fatal("expected metadata in response")
	}
}

func TestGenerateDraft_NotConfigured_Returns503(t *testing.T) {
	srv, _, gid := adminDraftServer(t, nil) // generator nil

	status, body := postJSONAllowErrorWithToken(t, srv, adminDraftPath, adminToken, validDraftBody(gid))

	if status != http.StatusServiceUnavailable {
		t.Fatalf("expected 503, got %d", status)
	}
	if errCode(body) != "not_configured" {
		t.Fatalf("expected error.code=not_configured, got %v", body["error"])
	}
}

func TestGenerateDraft_InvalidJSON_Returns400(t *testing.T) {
	mock := &processing.MockReadingDraftGenerator{Draft: validReadingDraft()}
	srv, _, _ := adminDraftServer(t, mock)

	req, _ := http.NewRequest(http.MethodPost, srv.URL+adminDraftPath, strings.NewReader("{not json"))
	req.Header.Set("Authorization", "Bearer "+adminToken)
	req.Header.Set("Content-Type", "application/json")
	resp, err := srv.Client().Do(req)
	if err != nil {
		t.Fatalf("request: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", resp.StatusCode)
	}
}

func TestGenerateDraft_FieldValidation(t *testing.T) {
	mock := &processing.MockReadingDraftGenerator{Draft: validReadingDraft()}
	srv, _, gid := adminDraftServer(t, mock)

	cases := []struct {
		name    string
		mutate  func(b map[string]any)
		wantSub string
	}{
		{"missing exercise_type", func(b map[string]any) { delete(b, "exercise_type") }, "exercise_type"},
		{"unknown exercise_type", func(b map[string]any) { b["exercise_type"] = "uloha_1" }, "exercise_type"},
		{"topic too short", func(b map[string]any) { b["topic"] = "ab" }, "topic"},
		{"topic too long", func(b map[string]any) { b["topic"] = strings.Repeat("a", 201) }, "topic"},
		{"missing grammar", func(b map[string]any) { b["grammar_point_ids"] = []string{} }, "grammar_point_ids"},
		{"too many grammar", func(b map[string]any) { b["grammar_point_ids"] = []string{"a", "b", "c", "d"} }, "grammar_point_ids"},
		{"unknown level", func(b map[string]any) { b["level"] = "C2" }, "level"},
		{"extra too long", func(b map[string]any) { b["extra_instructions"] = strings.Repeat("a", 501) }, "extra_instructions"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			body := validDraftBody(gid)
			tc.mutate(body)
			status, resp := postJSONAllowErrorWithToken(t, srv, adminDraftPath, adminToken, body)
			if status != http.StatusBadRequest {
				t.Fatalf("expected 400, got %d (resp=%v)", status, resp)
			}
			if errCode(resp) != "invalid_request" {
				t.Fatalf("expected invalid_request, got %v", resp["error"])
			}
			msg := errMessage(resp)
			if !strings.Contains(msg, tc.wantSub) {
				t.Fatalf("expected message to mention %q, got %q", tc.wantSub, msg)
			}
		})
	}
}

func TestGenerateDraft_GrammarPointNotFound_Returns404(t *testing.T) {
	mock := &processing.MockReadingDraftGenerator{Draft: validReadingDraft()}
	srv, _, _ := adminDraftServer(t, mock)

	body := validDraftBody("non-existent-grammar-id")
	status, resp := postJSONAllowErrorWithToken(t, srv, adminDraftPath, adminToken, body)

	if status != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", status)
	}
	if errCode(resp) != "grammar_point_not_found" {
		t.Fatalf("expected grammar_point_not_found, got %v", resp["error"])
	}
}

func TestGenerateDraft_SchemaMismatch_Returns422(t *testing.T) {
	// Mock returns a draft that fails ValidateReadingDraft (4 questions, not 5).
	bad := validReadingDraft()
	d := bad.Detail.(contracts.Cteni2Detail)
	d.Questions = d.Questions[:4]
	bad.Detail = d
	mock := &processing.MockReadingDraftGenerator{Draft: bad}
	srv, _, gid := adminDraftServer(t, mock)

	status, resp := postJSONAllowErrorWithToken(t, srv, adminDraftPath, adminToken, validDraftBody(gid))

	if status != http.StatusUnprocessableEntity {
		t.Fatalf("expected 422, got %d", status)
	}
	if errCode(resp) != "schema_mismatch" {
		t.Fatalf("expected schema_mismatch, got %v", resp["error"])
	}
}

func TestGenerateDraft_LLMError_Returns502(t *testing.T) {
	mock := &processing.MockReadingDraftGenerator{Err: errors.New("upstream-down")}
	srv, _, gid := adminDraftServer(t, mock)

	status, resp := postJSONAllowErrorWithToken(t, srv, adminDraftPath, adminToken, validDraftBody(gid))

	if status != http.StatusBadGateway {
		t.Fatalf("expected 502, got %d", status)
	}
	if errCode(resp) != "llm_error" {
		t.Fatalf("expected llm_error, got %v", resp["error"])
	}
}

func TestGenerateDraft_RateLimit_Returns429AfterCap(t *testing.T) {
	mock := &processing.MockReadingDraftGenerator{Draft: validReadingDraft()}
	srv, _, gid := adminDraftServer(t, mock)

	body := validDraftBody(gid)
	for i := 0; i < readingDraftRateLimit; i++ {
		status, resp := postJSONAllowErrorWithToken(t, srv, adminDraftPath, adminToken, body)
		if status != http.StatusOK {
			t.Fatalf("call %d: expected 200, got %d (resp=%v)", i+1, status, resp)
		}
	}

	status, resp := postJSONAllowErrorWithToken(t, srv, adminDraftPath, adminToken, body)
	if status != http.StatusTooManyRequests {
		t.Fatalf("expected 429 on call %d, got %d (resp=%v)", readingDraftRateLimit+1, status, resp)
	}
	if errCode(resp) != "rate_limited" {
		t.Fatalf("expected rate_limited, got %v", resp["error"])
	}
}

// slowReadingDraftGenerator honours context cancellation so we can exercise
// the timeout path.
type slowReadingDraftGenerator struct {
	delay time.Duration
}

func (g *slowReadingDraftGenerator) Generate(ctx context.Context, _ contracts.ReadingDraftInput) (*contracts.ReadingDraft, error) {
	select {
	case <-time.After(g.delay):
		return validReadingDraft(), nil
	case <-ctx.Done():
		return nil, ctx.Err()
	}
}

func TestGenerateDraft_Timeout_Returns504(t *testing.T) {
	// Override the package-level timeout for this test; restore at end.
	origTimeout := readingDraftTestTimeout(50 * time.Millisecond)
	t.Cleanup(func() { readingDraftTestTimeout(origTimeout) })

	gen := &slowReadingDraftGenerator{delay: 200 * time.Millisecond}
	srv, _, gid := adminDraftServer(t, gen)

	status, resp := postJSONAllowErrorWithToken(t, srv, adminDraftPath, adminToken, validDraftBody(gid))

	if status != http.StatusGatewayTimeout {
		t.Fatalf("expected 504, got %d (resp=%v)", status, resp)
	}
	if errCode(resp) != "timeout" {
		t.Fatalf("expected timeout, got %v", resp["error"])
	}
}

func TestGenerateDraft_WrongMethod_Returns405(t *testing.T) {
	mock := &processing.MockReadingDraftGenerator{Draft: validReadingDraft()}
	srv, _, _ := adminDraftServer(t, mock)

	req, _ := http.NewRequest(http.MethodGet, srv.URL+adminDraftPath, nil)
	req.Header.Set("Authorization", "Bearer "+adminToken)
	resp, err := srv.Client().Do(req)
	if err != nil {
		t.Fatalf("request: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405, got %d", resp.StatusCode)
	}
}

// I3: ensure withRole("admin") middleware actually enforces the role gate.
func TestGenerateDraft_NoToken_Returns401(t *testing.T) {
	mock := &processing.MockReadingDraftGenerator{Draft: validReadingDraft()}
	srv, _, gid := adminDraftServer(t, mock)

	body, err := json.Marshal(validDraftBody(gid))
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	req, _ := http.NewRequest(http.MethodPost, srv.URL+adminDraftPath, bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	// no Authorization header
	resp, err := srv.Client().Do(req)
	if err != nil {
		t.Fatalf("request: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", resp.StatusCode)
	}
}

func TestGenerateDraft_LearnerToken_Returns403(t *testing.T) {
	mock := &processing.MockReadingDraftGenerator{Draft: validReadingDraft()}
	srv, _, gid := adminDraftServer(t, mock)

	status, body := postJSONAllowErrorWithToken(t, srv, adminDraftPath, "dev-learner-token", validDraftBody(gid))
	if status != http.StatusForbidden {
		t.Fatalf("expected 403, got %d (resp=%v)", status, body)
	}
	if errCode(body) != "forbidden" {
		t.Fatalf("expected forbidden, got %v", body["error"])
	}
}

// ── small helpers ─────────────────────────────────────────────────────────────

func errMessage(body map[string]any) string {
	e, _ := body["error"].(map[string]any)
	m, _ := e["message"].(string)
	return m
}
