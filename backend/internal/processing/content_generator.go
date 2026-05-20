package processing

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"sort"
	"strings"

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

type grammarFormEntry struct {
	Cue  string
	Form string
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
	return g.callClaude(ctx, VocabSystemPrompt, VocabGenerationPrompt(input), input.ExerciseTypes)
}

func (g *ClaudeContentGenerator) GenerateGrammar(ctx context.Context, input GrammarGenerationInput) (*contracts.GeneratedPayload, error) {
	return g.callClaude(ctx, "", GrammarGenerationPrompt(input), input.ExerciseTypes)
}

// EnsureVocabularyQuizcards makes quizcard generation lossless for a
// vocabulary set. Claude can under-produce or focus on a single term; flashcards
// are deterministic enough that the backend can safely backfill missing terms.
func EnsureVocabularyQuizcards(payload *contracts.GeneratedPayload, items []contracts.VocabularyItem, explanationLang string) *contracts.GeneratedPayload {
	if payload == nil {
		payload = &contracts.GeneratedPayload{}
	}

	seen := map[string]bool{}
	for _, ex := range payload.Exercises {
		if ex.ExerciseType != "quizcard_basic" {
			continue
		}
		term := strings.ToLower(strings.TrimSpace(ex.FrontText))
		if term != "" {
			seen[term] = true
		}
	}

	for _, item := range items {
		term := strings.TrimSpace(item.Term)
		meaning := strings.TrimSpace(item.Meaning)
		if term == "" || meaning == "" {
			continue
		}
		key := strings.ToLower(term)
		if seen[key] {
			continue
		}
		payload.Exercises = append(payload.Exercises, contracts.GeneratedExercise{
			ExerciseType:       "quizcard_basic",
			FrontText:          term,
			BackText:           meaning,
			ExampleSentence:    item.ExampleSentence,
			ExampleTranslation: item.ExampleTranslation,
			Explanation:        vocabularyQuizcardFallbackExplanation(term, meaning, explanationLang),
		})
		seen[key] = true
	}

	return payload
}

// EnsureGrammarExercises prevents grammar generation from collapsing onto a
// single table row. The generated draft remains editable, but every source
// form gets at least one deterministic exercise for selected deterministic
// exercise types.
func EnsureGrammarExercises(payload *contracts.GeneratedPayload, input GrammarGenerationInput) *contracts.GeneratedPayload {
	if payload == nil {
		payload = &contracts.GeneratedPayload{}
	}
	forms := sortedGrammarForms(input.Forms)
	if len(forms) == 0 {
		return payload
	}

	for _, exerciseType := range input.ExerciseTypes {
		switch exerciseType {
		case "fill_blank", "choice_word":
			targetCount := input.NumPerType[exerciseType]
			if targetCount < len(forms) {
				targetCount = len(forms)
			}
			ensureGrammarFormExercises(payload, exerciseType, forms, targetCount)
		case "matching":
			targetCount := input.NumPerType[exerciseType]
			if targetCount < 1 {
				targetCount = 1
			}
			ensureGrammarMatchingExercises(payload, forms, targetCount, input.Title)
		}
	}

	return payload
}

func (g *ClaudeContentGenerator) callClaude(ctx context.Context, systemPrompt, userPrompt string, exerciseTypes []string) (*contracts.GeneratedPayload, error) {
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
		"messages":    []map[string]any{{"role": "user", "content": userPrompt}},
	}
	if systemPrompt != "" {
		reqBody["system"] = []map[string]any{
			{
				"type":          "text",
				"text":          systemPrompt,
				"cache_control": map[string]string{"type": "ephemeral"},
			},
		}
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

func ensureGrammarFormExercises(payload *contracts.GeneratedPayload, exerciseType string, forms []grammarFormEntry, targetCount int) {
	seenForms := map[string]bool{}
	count := 0
	for _, ex := range payload.Exercises {
		if ex.ExerciseType != exerciseType {
			continue
		}
		count++
		answer := strings.TrimSpace(ex.CorrectAnswer)
		if answer != "" {
			seenForms[strings.ToLower(answer)] = true
		}
	}

	for _, form := range forms {
		if seenForms[strings.ToLower(form.Form)] {
			continue
		}
		payload.Exercises = append(payload.Exercises, buildGrammarFormExercise(exerciseType, form, forms))
		seenForms[strings.ToLower(form.Form)] = true
		count++
	}

	for count < targetCount {
		form := forms[count%len(forms)]
		payload.Exercises = append(payload.Exercises, buildGrammarFormExercise(exerciseType, form, forms))
		count++
	}
}

func ensureGrammarMatchingExercises(payload *contracts.GeneratedPayload, forms []grammarFormEntry, targetCount int, title string) {
	if len(forms) < 2 || len(forms) > 6 {
		return
	}

	count := 0
	hasCompleteMatch := false
	for _, ex := range payload.Exercises {
		if ex.ExerciseType != "matching" {
			continue
		}
		count++
		if matchingCoversAllForms(ex.Pairs, forms) {
			hasCompleteMatch = true
		}
	}
	if !hasCompleteMatch {
		payload.Exercises = append(payload.Exercises, buildGrammarMatchingExercise(forms, title))
		count++
	}
	for count < targetCount {
		payload.Exercises = append(payload.Exercises, buildGrammarMatchingExercise(forms, title))
		count++
	}
}

func buildGrammarFormExercise(exerciseType string, form grammarFormEntry, allForms []grammarFormEntry) contracts.GeneratedExercise {
	prompt := strings.TrimSpace(form.Cue) + " ___."
	exercise := contracts.GeneratedExercise{
		ExerciseType:  exerciseType,
		Prompt:        prompt,
		CorrectAnswer: form.Form,
		Explanation:   grammarFormFallbackExplanation(form.Cue, form.Form),
	}
	if exerciseType == "choice_word" {
		exercise.Options = grammarChoiceOptions(form.Form, allForms)
	}
	return exercise
}

func buildGrammarMatchingExercise(forms []grammarFormEntry, title string) contracts.GeneratedExercise {
	pairs := make([]contracts.MatchingPair, 0, len(forms))
	seenLeft := map[string]bool{}
	for _, form := range forms {
		left := form.Form
		leftKey := strings.ToLower(left)
		if seenLeft[leftKey] {
			left = form.Form + " (" + form.Cue + ")"
			leftKey = strings.ToLower(left)
		}
		seenLeft[leftKey] = true
		pairs = append(pairs, contracts.MatchingPair{
			Left:  left,
			Right: form.Cue,
		})
	}
	return contracts.GeneratedExercise{
		ExerciseType: "matching",
		Pairs:        pairs,
		Explanation:  grammarMatchingFallbackExplanation(title),
	}
}

func matchingCoversAllForms(pairs []contracts.MatchingPair, forms []grammarFormEntry) bool {
	seen := map[string]bool{}
	for _, pair := range pairs {
		left := strings.ToLower(strings.TrimSpace(pair.Left))
		right := strings.ToLower(strings.TrimSpace(pair.Right))
		if left != "" {
			seen[left] = true
		}
		if right != "" {
			seen[right] = true
		}
	}
	for _, form := range forms {
		formText := strings.ToLower(form.Form)
		cueText := strings.ToLower(form.Cue)
		if !seen[formText] && !seen[cueText] {
			return false
		}
	}
	return true
}

func grammarChoiceOptions(correct string, forms []grammarFormEntry) []string {
	options := make([]string, 0, 4)
	add := func(value string) {
		value = strings.TrimSpace(value)
		if value == "" {
			return
		}
		for _, existing := range options {
			if strings.EqualFold(existing, value) {
				return
			}
		}
		options = append(options, value)
	}

	add(correct)
	for _, form := range forms {
		add(form.Form)
		if len(options) == 4 {
			return options
		}
	}
	for _, fallback := range []string{"jsem", "jsi", "je", "jsme", "jste", "jsou", "mám", "máš", "má", "máme", "mají"} {
		add(fallback)
		if len(options) == 4 {
			return options
		}
	}
	return options
}

func sortedGrammarForms(forms map[string]string) []grammarFormEntry {
	keys := make([]string, 0, len(forms))
	for key := range forms {
		keys = append(keys, key)
	}
	sort.Strings(keys)

	out := make([]grammarFormEntry, 0, len(keys))
	for _, key := range keys {
		cue := strings.TrimSpace(key)
		form := strings.TrimSpace(forms[key])
		if cue == "" || form == "" {
			continue
		}
		out = append(out, grammarFormEntry{Cue: cue, Form: form})
	}
	return out
}

// VocabGenerationPrompt and GrammarGenerationPrompt are in llm_prompts.go.
