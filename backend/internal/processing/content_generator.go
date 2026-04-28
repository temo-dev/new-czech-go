package processing

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

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

// contentGenerationTimeout is separate from llmRequestTimeout (30s for feedback).
// Content generation can produce 20-40 exercises in one call — needs 2-3 minutes.
const contentGenerationTimeout = 180 * time.Second

func NewClaudeContentGenerator(apiKey string) *ClaudeContentGenerator {
	return &ClaudeContentGenerator{
		apiKey: apiKey,
		client: &http.Client{Timeout: contentGenerationTimeout},
	}
}

func (g *ClaudeContentGenerator) GenerateVocabulary(ctx context.Context, input VocabularyGenerationInput) (*contracts.GeneratedPayload, error) {
	prompt := buildVocabPrompt(input)
	return g.callClaude(ctx, prompt, input.ExerciseTypes)
}

func (g *ClaudeContentGenerator) GenerateGrammar(ctx context.Context, input GrammarGenerationInput) (*contracts.GeneratedPayload, error) {
	prompt := buildGrammarPrompt(input)
	return g.callClaude(ctx, prompt, input.ExerciseTypes)
}

func (g *ClaudeContentGenerator) callClaude(ctx context.Context, prompt string, exerciseTypes []string) (*contracts.GeneratedPayload, error) {
	reqBody := map[string]any{
		"model":      "claude-sonnet-4-6",
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

// ── Prompt builders ───────────────────────────────────────────────────────────

func buildVocabPrompt(input VocabularyGenerationInput) string {
	items := make([]string, len(input.Items))
	for i, item := range input.Items {
		items[i] = fmt.Sprintf("%s = %s", item.Term, item.Meaning)
		if item.PartOfSpeech != "" {
			items[i] += fmt.Sprintf(" (%s)", item.PartOfSpeech)
		}
	}

	typeCounts := make([]string, 0)
	for _, t := range input.ExerciseTypes {
		if n := input.NumPerType[t]; n > 0 {
			typeCounts = append(typeCounts, fmt.Sprintf("%d %s", n, t))
		}
	}

	lang := map[string]string{"vi": "Vietnamese", "en": "English", "cs": "Czech"}[input.ExplanationLang]
	if lang == "" {
		lang = "Vietnamese"
	}

	return fmt.Sprintf(`You are a Czech language content creator for Vietnamese learners.
Create exercises for these Czech vocabulary words at level %s:
%s

Generate %s.
Rules:
- Use simple, natural Czech sentences appropriate for level %s
- All explanations must be in %s
- For matching exercises: provide 4-6 pairs (left=Czech term, right=Vietnamese meaning)
- For fill_blank: sentence must contain exactly ___ (three underscores)
- For choice_word: provide exactly 4 options; correct_answer must equal the full text of the correct option
- For quizcard_basic: front_text=Czech term, back_text=%s meaning
- Distractors must come from the same semantic field
- Each exercise must have a clear explanation of why the answer is correct`,
		input.Level,
		strings.Join(items, "\n"),
		strings.Join(typeCounts, ", "),
		input.Level,
		lang,
		lang,
	)
}

func buildGrammarPrompt(input GrammarGenerationInput) string {
	forms := make([]string, 0, len(input.Forms))
	for pronoun, form := range input.Forms {
		forms = append(forms, fmt.Sprintf("%s → %s", pronoun, form))
	}

	typeCounts := make([]string, 0)
	for _, t := range input.ExerciseTypes {
		if n := input.NumPerType[t]; n > 0 {
			typeCounts = append(typeCounts, fmt.Sprintf("%d %s", n, t))
		}
	}

	constraints := "Use simple, everyday Czech sentences."
	if strings.TrimSpace(input.Constraints) != "" {
		constraints = input.Constraints
	}

	return fmt.Sprintf(`You are a Czech grammar teacher for Vietnamese learners.
Grammar rule: %s (level %s)
%s

Forms:
%s

Generate %s.
Rules:
- Each exercise targets exactly one grammatical form from the table
- For fill_blank: sentence must contain exactly ___ where the correct form goes
- For choice_word: provide exactly 4 options; the correct form plus 3 plausible distractors from the same paradigm
- correct_answer for choice_word must be the FULL TEXT of the correct option
- Explanation must state WHICH form is correct and WHY (reference person/number/case)
- All explanations in Vietnamese
- Constraints: %s`,
		input.Title,
		input.Level,
		input.ExplanationVI,
		strings.Join(forms, "\n"),
		strings.Join(typeCounts, ", "),
		constraints,
	)
}
