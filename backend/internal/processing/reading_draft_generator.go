package processing

import (
	"context"
	"fmt"
	"net/http"

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
func (g *ClaudeReadingDraftGenerator) Generate(_ context.Context, in contracts.ReadingDraftInput) (*contracts.ReadingDraft, error) {
	switch in.ExerciseType {
	case "cteni_1", "cteni_2", "cteni_3", "cteni_4", "cteni_5", "cteni_6":
		return nil, fmt.Errorf("%w: %s", ErrReadingDraftNotImplemented, in.ExerciseType)
	default:
		return nil, fmt.Errorf("reading draft generator: unsupported exercise_type %q", in.ExerciseType)
	}
}
