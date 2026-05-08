package processing

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// ReadingDraftGenerator produces a draft cteni payload from a topic + grammar
// + level. Used by the V24 admin draft endpoint. See spec
// docs/specs/v24-doc-draft-generator.md for the full contract.
type ReadingDraftGenerator interface {
	Generate(ctx context.Context, in contracts.ReadingDraftInput) (*contracts.ReadingDraft, error)
}

// MockReadingDraftGenerator is a static-canned generator for tests + the
// `LLM_READING_DRAFT_MODEL=""` off-switch path.
type MockReadingDraftGenerator struct {
	Draft *contracts.ReadingDraft
	Err   error
}

func (m *MockReadingDraftGenerator) Generate(_ context.Context, _ contracts.ReadingDraftInput) (*contracts.ReadingDraft, error) {
	return m.Draft, m.Err
}

// ── Claude implementation ─────────────────────────────────────────────────────

// ClaudeReadingDraftGenerator dispatches by ExerciseType to a per-type tool
// schema (registered in B1..B6) and a per-type user-prompt builder
// (BuildReadingDraftUserPrompt in llm_user_prompts.go).
//
// Until B1..B6 land, every exercise_type returns ErrReadingDraftNotImplemented
// so the wiring + dispatch can be tested in isolation.
type ClaudeReadingDraftGenerator struct {
	apiKey string
	client *http.Client
	model  string
}

// NewClaudeReadingDraftGenerator wires the Claude HTTP client. Caller resolves
// the model via processing.LoadLLMModels().ReadingDraft.
func NewClaudeReadingDraftGenerator(apiKey, model string) *ClaudeReadingDraftGenerator {
	return &ClaudeReadingDraftGenerator{
		apiKey: apiKey,
		client: &http.Client{Timeout: contentGenerationTimeout},
		model:  model,
	}
}

// ErrReadingDraftNotImplemented is returned by the Claude generator until the
// per-type tool schema + prompt branch ships in Phase B.
var ErrReadingDraftNotImplemented = fmt.Errorf("reading draft generator: exercise_type not yet implemented")

// Generate dispatches by exercise_type. Phase B fills in each branch.
func (g *ClaudeReadingDraftGenerator) Generate(ctx context.Context, in contracts.ReadingDraftInput) (*contracts.ReadingDraft, error) {
	switch in.ExerciseType {
	case "cteni_1", "cteni_2", "cteni_3", "cteni_4", "cteni_5", "cteni_6":
		return g.callClaude(ctx, in)
	default:
		return nil, fmt.Errorf("reading draft generator: unsupported exercise_type %q", in.ExerciseType)
	}
}

// callClaude issues the tool_use request and parses the response into a
// per-type Detail struct. Validation is the caller's responsibility (handler
// invokes ValidateReadingDraft).
func (g *ClaudeReadingDraftGenerator) callClaude(ctx context.Context, in contracts.ReadingDraftInput) (*contracts.ReadingDraft, error) {
	schema := buildReadingDraftToolSchema(in.ExerciseType)
	if schema == nil {
		return nil, fmt.Errorf("reading draft generator: no tool schema for %s", in.ExerciseType)
	}

	reqBody := map[string]any{
		"model":      g.model,
		"max_tokens": 4096,
		"system":     ReadingDraftSystemPrompt,
		"tools": []map[string]any{
			{
				"name":         "save_reading_draft",
				"description":  "Save the generated reading-comprehension draft as structured data.",
				"input_schema": schema,
			},
		},
		"tool_choice": map[string]string{"type": "tool", "name": "save_reading_draft"},
		"messages":    []map[string]any{{"role": "user", "content": BuildReadingDraftUserPrompt(in)}},
	}

	payload, err := json.Marshal(reqBody)
	if err != nil {
		return nil, fmt.Errorf("marshal claude request: %w", err)
	}

	start := time.Now()
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

	raw, usage, err := extractReadingDraftToolUse(body)
	if err != nil {
		return nil, err
	}

	detail, err := parseReadingDraftDetail(in.ExerciseType, raw)
	if err != nil {
		return nil, err
	}

	return &contracts.ReadingDraft{
		ExerciseType: in.ExerciseType,
		Detail:       detail,
		Metadata: contracts.ReadingDraftMeta{
			Model:        g.model,
			DurationMs:   int(time.Since(start).Milliseconds()),
			InputTokens:  usage.input,
			OutputTokens: usage.output,
		},
	}, nil
}

// ── Tool schemas ──────────────────────────────────────────────────────────────

// buildReadingDraftToolSchema returns the per-cteni-type JSON schema fed to
// Claude's tool_use parameter. Each schema mirrors the expected
// contracts.Cteni*Detail / AnoNeDetail wire shape so the model is forced to
// produce a payload our parser understands.
//
// Returns nil for an unsupported exercise_type; callers must handle that.
func buildReadingDraftToolSchema(exerciseType string) map[string]any {
	switch exerciseType {
	case "cteni_2":
		return cteni2ToolSchema()
	case "cteni_4":
		return cteni4ToolSchema()
	case "cteni_5":
		return cteni5ToolSchema()
	case "cteni_6":
		return cteni6ToolSchema()
	case "cteni_3":
		return cteni3ToolSchema()
	case "cteni_1":
		return cteni1ToolSchema()
	}
	return nil
}

func cteni1ToolSchema() map[string]any {
	// V24 generates text-only items; asset_id is intentionally omitted from
	// the schema so the model has no place to put an image reference.
	item := map[string]any{
		"type":     "object",
		"required": []string{"item_no", "text"},
		"properties": map[string]any{
			"item_no": map[string]any{"type": "integer", "minimum": 1, "maximum": 5},
			"text":    map[string]any{"type": "string", "minLength": 1},
		},
		"additionalProperties": false,
	}
	option := map[string]any{
		"type":     "object",
		"required": []string{"key", "text"},
		"properties": map[string]any{
			"key":  map[string]any{"type": "string", "enum": []string{"A", "B", "C", "D", "E", "F", "G", "H"}},
			"text": map[string]any{"type": "string", "minLength": 1},
		},
	}
	return map[string]any{
		"type":     "object",
		"required": []string{"items", "options", "correct_answers"},
		"properties": map[string]any{
			"items": map[string]any{
				"type":     "array",
				"minItems": 5,
				"maxItems": 5,
				"items":    item,
			},
			"options": map[string]any{
				"type":     "array",
				"minItems": 8,
				"maxItems": 8,
				"items":    option,
			},
			"correct_answers": map[string]any{
				"type": "object",
				"additionalProperties": map[string]any{
					"type": "string",
					"enum": []string{"A", "B", "C", "D", "E", "F", "G", "H"},
				},
			},
		},
	}
}

func cteni3ToolSchema() map[string]any {
	textItem := map[string]any{
		"type":     "object",
		"required": []string{"item_no", "text"},
		"properties": map[string]any{
			"item_no": map[string]any{"type": "integer", "minimum": 1, "maximum": 4},
			"text":    map[string]any{"type": "string", "minLength": 1},
		},
	}
	person := map[string]any{
		"type":     "object",
		"required": []string{"key", "name"},
		"properties": map[string]any{
			"key":         map[string]any{"type": "string", "enum": []string{"A", "B", "C", "D", "E"}},
			"name":        map[string]any{"type": "string", "minLength": 1},
			"description": map[string]any{"type": "string"},
		},
	}
	return map[string]any{
		"type":     "object",
		"required": []string{"texts", "persons", "correct_answers"},
		"properties": map[string]any{
			"texts": map[string]any{
				"type":     "array",
				"minItems": 4,
				"maxItems": 4,
				"items":    textItem,
			},
			"persons": map[string]any{
				"type":     "array",
				"minItems": 5,
				"maxItems": 5,
				"items":    person,
			},
			"correct_answers": map[string]any{
				"type": "object",
				"additionalProperties": map[string]any{
					"type": "string",
					"enum": []string{"A", "B", "C", "D", "E"},
				},
			},
		},
	}
}

func cteni6ToolSchema() map[string]any {
	statement := map[string]any{
		"type":     "object",
		"required": []string{"question_no", "statement"},
		"properties": map[string]any{
			"question_no": map[string]any{"type": "integer", "minimum": 1, "maximum": 5},
			"statement":   map[string]any{"type": "string", "minLength": 1},
		},
	}
	return map[string]any{
		"type":     "object",
		"required": []string{"passage", "statements", "correct_answers", "max_points"},
		"properties": map[string]any{
			"passage": map[string]any{"type": "string", "minLength": 1},
			"statements": map[string]any{
				"type":     "array",
				"minItems": 1,
				"maxItems": 5,
				"items":    statement,
			},
			"correct_answers": map[string]any{
				"type": "object",
				"additionalProperties": map[string]any{
					"type": "string",
					"enum": []string{"ANO", "NE"},
				},
			},
			"max_points": map[string]any{"type": "integer", "minimum": 1, "maximum": 5},
		},
	}
}

func cteni5ToolSchema() map[string]any {
	question := map[string]any{
		"type":     "object",
		"required": []string{"question_no", "prompt"},
		"properties": map[string]any{
			"question_no": map[string]any{"type": "integer", "minimum": 1, "maximum": 5},
			"prompt":      map[string]any{"type": "string", "minLength": 1},
		},
	}
	return map[string]any{
		"type":     "object",
		"required": []string{"text", "questions", "correct_answers"},
		"properties": map[string]any{
			"text": map[string]any{"type": "string", "minLength": 1},
			"questions": map[string]any{
				"type":     "array",
				"minItems": 5,
				"maxItems": 5,
				"items":    question,
			},
			"correct_answers": map[string]any{
				"type": "object",
				"additionalProperties": map[string]any{
					"type":      "string",
					"minLength": 1,
					"maxLength": cteni5MaxAnswerLen,
				},
			},
		},
	}
}

// multiChoiceQuestionSchema is the shared question shape for cteni_2 + cteni_4.
// 4 options keyed A-D, non-empty option text, integer question_no.
func multiChoiceQuestionSchema(maxQuestionNo int) map[string]any {
	option := map[string]any{
		"type":     "object",
		"required": []string{"key", "text"},
		"properties": map[string]any{
			"key":  map[string]any{"type": "string", "enum": []string{"A", "B", "C", "D"}},
			"text": map[string]any{"type": "string", "minLength": 1},
		},
	}
	return map[string]any{
		"type":     "object",
		"required": []string{"question_no", "prompt", "options"},
		"properties": map[string]any{
			"question_no": map[string]any{"type": "integer", "minimum": 1, "maximum": maxQuestionNo},
			"prompt":      map[string]any{"type": "string", "minLength": 1},
			"options": map[string]any{
				"type":     "array",
				"minItems": 4,
				"maxItems": 4,
				"items":    option,
			},
		},
	}
}

func cteni2ToolSchema() map[string]any {
	return map[string]any{
		"type":     "object",
		"required": []string{"text", "questions", "correct_answers"},
		"properties": map[string]any{
			"text": map[string]any{"type": "string", "minLength": 1},
			"questions": map[string]any{
				"type":     "array",
				"minItems": 5,
				"maxItems": 5,
				"items":    multiChoiceQuestionSchema(5),
			},
			"correct_answers": map[string]any{
				"type": "object",
				"additionalProperties": map[string]any{
					"type": "string",
					"enum": []string{"A", "B", "C", "D"},
				},
			},
		},
	}
}

func cteni4ToolSchema() map[string]any {
	return map[string]any{
		"type":     "object",
		"required": []string{"questions", "correct_answers"},
		"properties": map[string]any{
			"context": map[string]any{"type": "string"},
			"questions": map[string]any{
				"type":     "array",
				"minItems": 6,
				"maxItems": 6,
				"items":    multiChoiceQuestionSchema(6),
			},
			"correct_answers": map[string]any{
				"type": "object",
				"additionalProperties": map[string]any{
					"type": "string",
					"enum": []string{"A", "B", "C", "D"},
				},
			},
		},
	}
}

// ── Response parsing ──────────────────────────────────────────────────────────

type readingDraftUsage struct {
	input  int
	output int
}

// extractReadingDraftToolUse pulls the tool_use block out of the Claude
// response and returns its raw input JSON + token usage.
func extractReadingDraftToolUse(body []byte) (json.RawMessage, readingDraftUsage, error) {
	var resp struct {
		Content []struct {
			Type  string          `json:"type"`
			Input json.RawMessage `json:"input"`
		} `json:"content"`
		Usage struct {
			InputTokens  int `json:"input_tokens"`
			OutputTokens int `json:"output_tokens"`
		} `json:"usage"`
		Error *struct {
			Type    string `json:"type"`
			Message string `json:"message"`
		} `json:"error"`
	}
	if err := json.Unmarshal(body, &resp); err != nil {
		return nil, readingDraftUsage{}, fmt.Errorf("unmarshal response: %w", err)
	}
	if resp.Error != nil {
		return nil, readingDraftUsage{}, fmt.Errorf("claude api error %s: %s", resp.Error.Type, resp.Error.Message)
	}
	for _, c := range resp.Content {
		if c.Type == "tool_use" {
			return c.Input, readingDraftUsage{input: resp.Usage.InputTokens, output: resp.Usage.OutputTokens}, nil
		}
	}
	return nil, readingDraftUsage{}, fmt.Errorf("no tool_use block in response")
}

// parseReadingDraftDetail unmarshals the tool_use input JSON into the per-type
// Detail struct.
func parseReadingDraftDetail(exerciseType string, raw json.RawMessage) (any, error) {
	switch exerciseType {
	case "cteni_2":
		var d contracts.Cteni2Detail
		if err := json.Unmarshal(raw, &d); err != nil {
			return nil, fmt.Errorf("unmarshal cteni_2 detail: %w", err)
		}
		return d, nil
	case "cteni_4":
		var d contracts.Cteni4Detail
		if err := json.Unmarshal(raw, &d); err != nil {
			return nil, fmt.Errorf("unmarshal cteni_4 detail: %w", err)
		}
		return d, nil
	case "cteni_5":
		var d contracts.Cteni5Detail
		if err := json.Unmarshal(raw, &d); err != nil {
			return nil, fmt.Errorf("unmarshal cteni_5 detail: %w", err)
		}
		return d, nil
	case "cteni_6":
		var d contracts.AnoNeDetail
		if err := json.Unmarshal(raw, &d); err != nil {
			return nil, fmt.Errorf("unmarshal cteni_6 detail: %w", err)
		}
		return d, nil
	case "cteni_3":
		var d contracts.Cteni3Detail
		if err := json.Unmarshal(raw, &d); err != nil {
			return nil, fmt.Errorf("unmarshal cteni_3 detail: %w", err)
		}
		return d, nil
	case "cteni_1":
		var d contracts.Cteni1Detail
		if err := json.Unmarshal(raw, &d); err != nil {
			return nil, fmt.Errorf("unmarshal cteni_1 detail: %w", err)
		}
		return d, nil
	}
	return nil, fmt.Errorf("parse reading draft: unsupported exercise_type %q", exerciseType)
}
