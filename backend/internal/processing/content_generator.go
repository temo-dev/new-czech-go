package processing

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// VocabularyGenerationInput is the input for vocabulary content generation.
type VocabularyGenerationInput struct {
	Items           []contracts.VocabularyItem
	Level           string   // A1 | A2 | B1
	ExplanationLang string   // vi | en | cs
	ExerciseTypes   []string // subset of quizcard_basic/matching/fill_blank/choice_word
	NumPerType      map[string]int
}

// GrammarGenerationInput is the input for grammar content generation.
type GrammarGenerationInput struct {
	Title         string
	Level         string
	ExplanationVI string
	Forms         map[string]string // e.g. {"já":"jsem","ty":"jsi"}
	Constraints   string
	ExerciseTypes []string
	NumPerType    map[string]int
}

// ContentGenerator generates exercise drafts using LLM.
type ContentGenerator interface {
	GenerateVocabulary(ctx context.Context, input VocabularyGenerationInput) (*contracts.GeneratedPayload, error)
	GenerateGrammar(ctx context.Context, input GrammarGenerationInput) (*contracts.GeneratedPayload, error)
}

// ── Mock implementation for tests ─────────────────────────────────────────────

type MockContentGenerator struct {
	Payload *contracts.GeneratedPayload
	Err     error
}

func (m *MockContentGenerator) GenerateVocabulary(_ context.Context, _ VocabularyGenerationInput) (*contracts.GeneratedPayload, error) {
	return m.Payload, m.Err
}
func (m *MockContentGenerator) GenerateGrammar(_ context.Context, _ GrammarGenerationInput) (*contracts.GeneratedPayload, error) {
	return m.Payload, m.Err
}

// ── Claude implementation ─────────────────────────────────────────────────────

type ClaudeContentGenerator struct {
	apiKey string
	client *http.Client
}

// Timeout and model defaults are in llm_config.go. Prompts are in llm_prompts.go.

func NewClaudeContentGenerator(apiKey string) *ClaudeContentGenerator {
	return &ClaudeContentGenerator{
		apiKey: apiKey,
		client: &http.Client{Timeout: contentGenerationTimeout},
	}
}

func (g *ClaudeContentGenerator) GenerateVocabulary(ctx context.Context, input VocabularyGenerationInput) (*contracts.GeneratedPayload, error) {
	return g.callClaude(ctx, VocabGenerationPrompt(input), input.ExerciseTypes)
}

func (g *ClaudeContentGenerator) GenerateGrammar(ctx context.Context, input GrammarGenerationInput) (*contracts.GeneratedPayload, error) {
	return g.callClaude(ctx, GrammarGenerationPrompt(input), input.ExerciseTypes)
}

func (g *ClaudeContentGenerator) callClaude(ctx context.Context, prompt string, exerciseTypes []string) (*contracts.GeneratedPayload, error) {
	reqBody := map[string]any{
		"model":      LoadLLMModels().Content,
		"max_tokens": 8192,
		"tools": []map[string]any{
			{
				"name":         "save_exercises",
				"description":  "Save the generated exercises as structured data",
				"input_schema": buildExerciseToolSchema(exerciseTypes),
			},
		},
		"tool_choice": map[string]string{"type": "tool", "name": "save_exercises"},
		"messages":    []map[string]any{{"role": "user", "content": prompt}},
	}

	payload, err := json.Marshal(reqBody)
	if err != nil {
		return nil, fmt.Errorf("marshal claude request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, claudeAPIEndpoint, bytes.NewReader(payload))
	if err != nil {
		return nil, fmt.Errorf("build claude request: %w", err)
	}
	req.Header.Set("content-type", "application/json")
	req.Header.Set("x-api-key", g.apiKey)
	req.Header.Set("anthropic-version", claudeAPIVersion)

	resp, err := g.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("call claude: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read response: %w", err)
	}
	if resp.StatusCode >= 400 {
		return nil, fmt.Errorf("claude api status %d: %s", resp.StatusCode, string(body))
	}

	return extractToolUsePayload(body)
}

func extractToolUsePayload(body []byte) (*contracts.GeneratedPayload, error) {
	var resp struct {
		Content []struct {
			Type  string          `json:"type"`
			Input json.RawMessage `json:"input"`
		} `json:"content"`
		Error *struct {
			Type    string `json:"type"`
			Message string `json:"message"`
		} `json:"error"`
	}
	if err := json.Unmarshal(body, &resp); err != nil {
		return nil, fmt.Errorf("unmarshal response: %w", err)
	}
	if resp.Error != nil {
		return nil, fmt.Errorf("claude api error %s: %s", resp.Error.Type, resp.Error.Message)
	}
	for _, c := range resp.Content {
		if c.Type == "tool_use" {
			var payload contracts.GeneratedPayload
			if err := json.Unmarshal(c.Input, &payload); err != nil {
				return nil, fmt.Errorf("unmarshal tool input: %w", err)
			}
			return &payload, nil
		}
	}
	return nil, fmt.Errorf("no tool_use block in response")
}

func buildExerciseToolSchema(exerciseTypes []string) map[string]any {
	return map[string]any{
		"type": "object",
		"properties": map[string]any{
			"exercises": map[string]any{
				"type": "array",
				"items": map[string]any{
					"type":     "object",
					"required": []string{"exercise_type", "explanation"},
					"properties": map[string]any{
						"exercise_type":       map[string]any{"type": "string", "enum": exerciseTypes},
						"front_text":          map[string]any{"type": "string"},
						"back_text":           map[string]any{"type": "string"},
						"example_sentence":    map[string]any{"type": "string"},
						"example_translation": map[string]any{"type": "string"},
						"prompt":              map[string]any{"type": "string"},
						"options":             map[string]any{"type": "array", "items": map[string]any{"type": "string"}},
						"correct_answer":      map[string]any{"type": "string"},
						"grammar_note":        map[string]any{"type": "string"},
						"pairs": map[string]any{
							"type": "array",
							"items": map[string]any{
								"type":     "object",
								"required": []string{"left", "right"},
								"properties": map[string]any{
									"left":  map[string]any{"type": "string"},
									"right": map[string]any{"type": "string"},
								},
							},
						},
						"explanation": map[string]any{"type": "string"},
					},
				},
			},
		},
		"required": []string{"exercises"},
	}
}

// VocabGenerationPrompt and GrammarGenerationPrompt are in llm_prompts.go.
