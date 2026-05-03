package processing

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

const (
	llmProviderDev    = "dev"
	llmProviderClaude = "claude"
	// API/timeout constants and model defaults are in llm_config.go.
	// Prompt templates are in llm_prompts.go.
)

type LLMFeedbackProvider interface {
	GenerateFeedback(exercise contracts.Exercise, transcript contracts.Transcript, reliability transcriptReliability, locale string) (contracts.AttemptFeedback, error)
	GenerateInterviewFeedback(turns []contracts.InterviewTranscriptTurn, exerciseType, topic string, durationSec int, locale string) (contracts.AttemptFeedback, error)
}

type DevLLMFeedbackProvider struct{}

func (DevLLMFeedbackProvider) GenerateFeedback(_ contracts.Exercise, _ contracts.Transcript, _ transcriptReliability, _ string) (contracts.AttemptFeedback, error) {
	return contracts.AttemptFeedback{}, fmt.Errorf("llm feedback disabled: dev provider")
}

func (DevLLMFeedbackProvider) GenerateInterviewFeedback(_ []contracts.InterviewTranscriptTurn, _, _ string, _ int, _ string) (contracts.AttemptFeedback, error) {
	return contracts.AttemptFeedback{}, fmt.Errorf("llm feedback disabled: dev provider")
}

func ConfiguredLLMFeedbackProvider() string {
	provider := strings.ToLower(strings.TrimSpace(os.Getenv("LLM_PROVIDER")))
	if provider == "" {
		return llmProviderDev
	}
	return provider
}

func NewConfiguredLLMFeedbackProvider() (LLMFeedbackProvider, error) {
	switch ConfiguredLLMFeedbackProvider() {
	case "", llmProviderDev:
		return DevLLMFeedbackProvider{}, nil
	case llmProviderClaude:
		return NewClaudeLLMFeedbackProviderFromEnv()
	default:
		return nil, fmt.Errorf("unsupported LLM_PROVIDER %q", os.Getenv("LLM_PROVIDER"))
	}
}

type ClaudeLLMFeedbackProvider struct {
	apiKey string
	model  string
	client *http.Client
}

func NewClaudeLLMFeedbackProviderFromEnv() (*ClaudeLLMFeedbackProvider, error) {
	apiKey := strings.TrimSpace(os.Getenv("ANTHROPIC_API_KEY"))
	if apiKey == "" {
		return nil, fmt.Errorf("ANTHROPIC_API_KEY is required when LLM_PROVIDER=claude")
	}
	return &ClaudeLLMFeedbackProvider{
		apiKey: apiKey,
		model:  LoadLLMModels().Feedback,
		client: &http.Client{Timeout: llmRequestTimeout},
	}, nil
}

type claudeMessageRequest struct {
	Model     string          `json:"model"`
	MaxTokens int             `json:"max_tokens"`
	System    string          `json:"system"`
	Messages  []claudeMessage `json:"messages"`
}

type claudeMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type claudeMessageResponse struct {
	Content []struct {
		Type string `json:"type"`
		Text string `json:"text"`
	} `json:"content"`
	Error *struct {
		Type    string `json:"type"`
		Message string `json:"message"`
	} `json:"error,omitempty"`
}

type llmFeedbackJSON struct {
	ReadinessLevel string   `json:"readiness_level"`
	OverallSummary string   `json:"overall_summary"`
	Strengths      []string `json:"strengths"`
	Improvements   []string `json:"improvements"`
	RetryAdvice    []string `json:"retry_advice"`
	SampleAnswer   string   `json:"sample_answer"`
}

// callClaude sends a system+user prompt to Claude and parses the JSON feedback response.
func (c *ClaudeLLMFeedbackProvider) callClaude(systemPrompt, userPrompt string) (llmFeedbackJSON, error) {
	reqBody := claudeMessageRequest{
		Model:     c.model,
		MaxTokens: 2048,
		System:    systemPrompt,
		Messages:  []claudeMessage{{Role: "user", Content: userPrompt}},
	}
	payload, err := json.Marshal(reqBody)
	if err != nil {
		return llmFeedbackJSON{}, fmt.Errorf("marshal claude request: %w", err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), llmRequestTimeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, claudeAPIEndpoint, bytes.NewReader(payload))
	if err != nil {
		return llmFeedbackJSON{}, fmt.Errorf("build claude request: %w", err)
	}
	req.Header.Set("content-type", "application/json")
	req.Header.Set("x-api-key", c.apiKey)
	req.Header.Set("anthropic-version", claudeAPIVersion)
	resp, err := c.client.Do(req)
	if err != nil {
		return llmFeedbackJSON{}, fmt.Errorf("call claude: %w", err)
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return llmFeedbackJSON{}, fmt.Errorf("read claude response: %w", err)
	}
	if resp.StatusCode >= 400 {
		return llmFeedbackJSON{}, fmt.Errorf("claude api status %d: %s", resp.StatusCode, string(body))
	}
	var parsed claudeMessageResponse
	if err := json.Unmarshal(body, &parsed); err != nil {
		return llmFeedbackJSON{}, fmt.Errorf("unmarshal claude response: %w", err)
	}
	if parsed.Error != nil {
		return llmFeedbackJSON{}, fmt.Errorf("claude api error %s: %s", parsed.Error.Type, parsed.Error.Message)
	}
	if len(parsed.Content) == 0 || parsed.Content[0].Text == "" {
		return llmFeedbackJSON{}, fmt.Errorf("claude response empty")
	}
	raw := extractJSONBlock(parsed.Content[0].Text)
	var fb llmFeedbackJSON
	if err := json.Unmarshal([]byte(raw), &fb); err != nil {
		return llmFeedbackJSON{}, fmt.Errorf("parse feedback json: %w; body=%s", err, raw)
	}
	return fb, nil
}

func (c *ClaudeLLMFeedbackProvider) GenerateFeedback(exercise contracts.Exercise, transcript contracts.Transcript, reliability transcriptReliability, locale string) (contracts.AttemptFeedback, error) {
	fb, err := c.callClaude(FeedbackSystemPrompt(locale), buildLLMUserPrompt(exercise, transcript, reliability, locale))
	if err != nil {
		return contracts.AttemptFeedback{}, err
	}
	return contracts.AttemptFeedback{
		ReadinessLevel: normalizeReadinessLevel(fb.ReadinessLevel),
		OverallSummary: strings.TrimSpace(fb.OverallSummary),
		Strengths:      sanitizeStringList(fb.Strengths),
		Improvements:   sanitizeStringList(fb.Improvements),
		RetryAdvice:    sanitizeStringList(fb.RetryAdvice),
		SampleAnswer:   strings.TrimSpace(fb.SampleAnswer),
	}, nil
}

func (c *ClaudeLLMFeedbackProvider) GenerateInterviewFeedback(turns []contracts.InterviewTranscriptTurn, exerciseType, topic string, durationSec int, locale string) (contracts.AttemptFeedback, error) {
	internal := make([]interviewTurn, len(turns))
	for i, t := range turns {
		internal[i] = interviewTurn{Speaker: t.Speaker, Text: t.Text, AtSec: t.AtSec}
	}
	fb, err := c.callClaude(interviewSystemPrompt(locale), buildInterviewUserPrompt(exerciseType, topic, internal, durationSec))
	if err != nil {
		return contracts.AttemptFeedback{}, err
	}
	return contracts.AttemptFeedback{
		ReadinessLevel: normalizeReadinessLevel(fb.ReadinessLevel),
		OverallSummary: strings.TrimSpace(fb.OverallSummary),
		Strengths:      sanitizeStringList(fb.Strengths),
		Improvements:   sanitizeStringList(fb.Improvements),
		RetryAdvice:    sanitizeStringList(fb.RetryAdvice),
		SampleAnswer:   strings.TrimSpace(fb.SampleAnswer),
	}, nil
}

// FeedbackSystemPrompt is in llm_prompts.go.

func buildLLMUserPrompt(exercise contracts.Exercise, transcript contracts.Transcript, reliability transcriptReliability, locale string) string {
	targetLanguage := "Vietnamese"
	if locale == contracts.LocaleEN {
		targetLanguage = "English"
	}
	var b strings.Builder
	fmt.Fprintf(&b, "OUTPUT LANGUAGE: %s (do NOT write overall_summary/strengths/improvements/retry_advice in Czech).\n", targetLanguage)
	fmt.Fprintf(&b, "Exercise type: %s\n", exercise.ExerciseType)
	if exercise.Title != "" {
		fmt.Fprintf(&b, "Exercise title: %s\n", exercise.Title)
	}
	if exercise.LearnerInstruction != "" {
		fmt.Fprintf(&b, "Learner instruction: %s\n", exercise.LearnerInstruction)
	}
	b.WriteString(describeExercisePrompt(exercise))
	b.WriteString("\n")
	fmt.Fprintf(&b, "Learner transcript: %q\n", strings.TrimSpace(transcript.FullText))
	if transcript.Confidence > 0 {
		fmt.Fprintf(&b, "Transcript confidence: %.2f\n", transcript.Confidence)
	}
	fmt.Fprintf(&b, "Transcript reliability: %s\n", reliability)
	if transcript.IsSynthetic {
		b.WriteString("Note: transcript was synthesized for testing — treat pronunciation evaluation with caution.\n")
	}
	fmt.Fprintf(&b, "\nReturn the JSON only. Reminder: overall_summary/strengths/improvements/retry_advice in %s; sample_answer in Czech.", targetLanguage)
	return b.String()
}

func describeExercisePrompt(exercise contracts.Exercise) string {
	switch exercise.ExerciseType {
	case "uloha_1_topic_answers":
		if p, ok := extractUloha1Prompt(exercise.Prompt); ok {
			var b strings.Builder
			if p.TopicLabel != "" {
				fmt.Fprintf(&b, "Topic: %s\n", p.TopicLabel)
			}
			if len(p.QuestionPrompts) > 0 {
				b.WriteString("Questions the learner should address:\n")
				for _, q := range p.QuestionPrompts {
					fmt.Fprintf(&b, "- %s\n", q)
				}
			}
			return b.String()
		}
	case "uloha_2_dialogue_questions":
		if d, ok := extractUloha2Detail(exercise.Detail); ok {
			var b strings.Builder
			if d.ScenarioTitle != "" {
				fmt.Fprintf(&b, "Scenario: %s\n", d.ScenarioTitle)
			}
			if d.ScenarioPrompt != "" {
				fmt.Fprintf(&b, "Scenario prompt: %s\n", d.ScenarioPrompt)
			}
			if len(d.RequiredInfoSlots) > 0 {
				b.WriteString("Required info the learner must ask about:\n")
				for _, s := range d.RequiredInfoSlots {
					fmt.Fprintf(&b, "- %s (%s)\n", s.Label, s.SlotKey)
				}
			}
			if d.CustomQuestionHint != "" {
				fmt.Fprintf(&b, "Hint: %s\n", d.CustomQuestionHint)
			}
			return b.String()
		}
	case "uloha_3_story_narration":
		if d, ok := extractUloha3Detail(exercise.Detail); ok {
			var b strings.Builder
			if d.StoryTitle != "" {
				fmt.Fprintf(&b, "Story: %s\n", d.StoryTitle)
			}
			if len(d.NarrativeCheckpoints) > 0 {
				b.WriteString("Narrative checkpoints the learner should cover (in order):\n")
				for i, c := range d.NarrativeCheckpoints {
					fmt.Fprintf(&b, "%d. %s\n", i+1, c)
				}
			}
			if len(d.GrammarFocus) > 0 {
				b.WriteString("Grammar focus: " + strings.Join(d.GrammarFocus, ", ") + "\n")
			}
			b.WriteString("TASK RUBRIC for Uloha 3 (story narration):\n")
			b.WriteString("- Coverage: how many listed checkpoints did the learner actually narrate? Name specific missing beats in improvements.\n")
			b.WriteString("- Sequence: does the story flow in correct order? Check for ordering markers (nejdriv, pak, potom, nakonec). If missing, suggest inserting them.\n")
			b.WriteString("- Past tense: stories require past tense (byl/byla/sli/videli/koupili...). Flag present-tense slips.\n")
			b.WriteString("- Connectives: praise or suggest 'a pak', 'potom', 'kdyz', 'protoze', 'takze' to link beats.\n")
			b.WriteString("- sample_answer: write 2-3 Czech sentences covering at least 3 checkpoints in order, with explicit past-tense verbs and at least one ordering marker.\n")
			return b.String()
		}
	case "uloha_4_choice_reasoning":
		if d, ok := extractUloha4Detail(exercise.Detail); ok {
			var b strings.Builder
			if d.ScenarioPrompt != "" {
				fmt.Fprintf(&b, "Scenario: %s\n", d.ScenarioPrompt)
			}
			if len(d.Options) > 0 {
				b.WriteString("Options the learner can choose between:\n")
				for _, o := range d.Options {
					fmt.Fprintf(&b, "- %s: %s\n", o.Label, o.Description)
				}
			}
			if len(d.ExpectedReasoningAxes) > 0 {
				b.WriteString("Expected reasoning axes: " + strings.Join(d.ExpectedReasoningAxes, ", ") + "\n")
			}
			b.WriteString("TASK RUBRIC for Uloha 4 (choice + reasoning):\n")
			b.WriteString("- Clear choice: did the learner pick exactly one of the listed options and name it? Expected opening: 'Vybiram...', 'Volim...', 'Chci...'. If missing, flag it explicitly.\n")
			b.WriteString("- Reason given: at least one 'protoze' (or equivalent 'nebot', 'kvuli') clause. Count clauses: 1 weak, 2 acceptable, 3+ strong.\n")
			b.WriteString("- Reason matches choice: the reason must connect to the chosen option, not a different option. Call out mismatches specifically.\n")
			b.WriteString("- Reasoning axes coverage: does the learner's reason touch the expected axes above? Name which axes are covered vs missed.\n")
			b.WriteString("- sample_answer: one Czech sentence with 'Vybiram [option]' + 'protoze [reason touching one expected axis]'.\n")
			return b.String()
		}
	case "psani_1_formular":
		if d, ok := extractPsani1Detail(exercise.Detail); ok {
			var b strings.Builder
			b.WriteString("WRITING TASK: Form answers (psani_1_formular)\n")
			b.WriteString("The learner wrote Czech answers to a satisfaction questionnaire. Each answer should be ≥10 words.\n")
			if len(d.Questions) > 0 {
				b.WriteString("Questions:\n")
				for i, q := range d.Questions {
					fmt.Fprintf(&b, "%d. %s\n", i+1, q)
				}
			}
			b.WriteString("TASK RUBRIC:\n")
			b.WriteString("- Task completion: did the learner answer each question with a full sentence?\n")
			b.WriteString("- Grammar: check case endings, verb conjugation, word order.\n")
			b.WriteString("- Vocabulary: appropriate register, no mixing of languages.\n")
			b.WriteString("- sample_answer: provide a correct Czech answer for each question, joined by double newlines.\n")
			return b.String()
		}
		return "WRITING TASK: Form answers. Evaluate Czech grammar, vocabulary, and task completion.\n"
	case "psani_2_email":
		if d, ok := extractPsani2Detail(exercise.Detail); ok {
			var b strings.Builder
			b.WriteString("WRITING TASK: Email (psani_2_email)\n")
			if d.Prompt != "" {
				fmt.Fprintf(&b, "Context: %s\n", d.Prompt)
			}
			if len(d.Topics) > 0 {
				b.WriteString("The learner must address these topics (one per image prompt):\n")
				for _, t := range d.Topics {
					fmt.Fprintf(&b, "- %s\n", t)
				}
			}
			b.WriteString("The email should be ≥35 words total.\n")
			b.WriteString("TASK RUBRIC:\n")
			b.WriteString("- Task completion: does the email address all required topics?\n")
			b.WriteString("- Opening/closing: appropriate greeting and sign-off for an informal email?\n")
			b.WriteString("- Grammar: case endings, verb conjugation, tense consistency.\n")
			b.WriteString("- sample_answer: a correct Czech email addressing all topics.\n")
			return b.String()
		}
		return "WRITING TASK: Email writing. Evaluate Czech grammar, vocabulary, and task completion.\n"
	}
	return ""
}

func extractPsani1Detail(v any) (contracts.Psani1Detail, bool) {
	if d, ok := v.(contracts.Psani1Detail); ok {
		return d, true
	}
	if m, ok := v.(map[string]any); ok {
		d := contracts.Psani1Detail{}
		if qs, ok := m["questions"].([]any); ok {
			for _, q := range qs {
				if s, ok := q.(string); ok {
					d.Questions = append(d.Questions, s)
				}
			}
		}
		if mw, ok := m["min_words"].(float64); ok {
			d.MinWords = int(mw)
		}
		return d, true
	}
	return contracts.Psani1Detail{}, false
}

func extractPsani2Detail(v any) (contracts.Psani2Detail, bool) {
	if d, ok := v.(contracts.Psani2Detail); ok {
		return d, true
	}
	if m, ok := v.(map[string]any); ok {
		d := contracts.Psani2Detail{}
		if s, ok := m["prompt"].(string); ok {
			d.Prompt = s
		}
		if ts, ok := m["topics"].([]any); ok {
			for _, t := range ts {
				if s, ok := t.(string); ok {
					d.Topics = append(d.Topics, s)
				}
			}
		}
		if mw, ok := m["min_words"].(float64); ok {
			d.MinWords = int(mw)
		}
		return d, true
	}
	return contracts.Psani2Detail{}, false
}

func extractUloha1Prompt(v any) (contracts.Uloha1Prompt, bool) {
	if p, ok := v.(contracts.Uloha1Prompt); ok {
		return p, true
	}
	if m, ok := v.(map[string]any); ok {
		p := contracts.Uloha1Prompt{}
		if s, ok := m["topic_label"].(string); ok {
			p.TopicLabel = s
		}
		if arr, ok := m["question_prompts"].([]any); ok {
			for _, item := range arr {
				if s, ok := item.(string); ok {
					p.QuestionPrompts = append(p.QuestionPrompts, s)
				}
			}
		}
		return p, true
	}
	return contracts.Uloha1Prompt{}, false
}

func extractUloha2Detail(v any) (contracts.Uloha2Detail, bool) {
	if d, ok := v.(contracts.Uloha2Detail); ok {
		return d, true
	}
	if m, ok := v.(map[string]any); ok {
		d := contracts.Uloha2Detail{}
		if s, ok := m["scenario_title"].(string); ok {
			d.ScenarioTitle = s
		}
		if s, ok := m["scenario_prompt"].(string); ok {
			d.ScenarioPrompt = s
		}
		if s, ok := m["custom_question_hint"].(string); ok {
			d.CustomQuestionHint = s
		}
		if arr, ok := m["required_info_slots"].([]any); ok {
			for _, item := range arr {
				if sm, ok := item.(map[string]any); ok {
					slot := contracts.RequiredInfoSlot{}
					if s, ok := sm["slot_key"].(string); ok {
						slot.SlotKey = s
					}
					if s, ok := sm["label"].(string); ok {
						slot.Label = s
					}
					if s, ok := sm["sample_question"].(string); ok {
						slot.SampleQuestion = s
					}
					d.RequiredInfoSlots = append(d.RequiredInfoSlots, slot)
				}
			}
		}
		return d, true
	}
	return contracts.Uloha2Detail{}, false
}

func extractUloha3Detail(v any) (contracts.Uloha3Detail, bool) {
	if d, ok := v.(contracts.Uloha3Detail); ok {
		return d, true
	}
	if m, ok := v.(map[string]any); ok {
		d := contracts.Uloha3Detail{}
		if s, ok := m["story_title"].(string); ok {
			d.StoryTitle = s
		}
		if arr, ok := m["narrative_checkpoints"].([]any); ok {
			for _, item := range arr {
				if s, ok := item.(string); ok {
					d.NarrativeCheckpoints = append(d.NarrativeCheckpoints, s)
				}
			}
		}
		if arr, ok := m["grammar_focus"].([]any); ok {
			for _, item := range arr {
				if s, ok := item.(string); ok {
					d.GrammarFocus = append(d.GrammarFocus, s)
				}
			}
		}
		return d, true
	}
	return contracts.Uloha3Detail{}, false
}

func extractUloha4Detail(v any) (contracts.Uloha4Detail, bool) {
	if d, ok := v.(contracts.Uloha4Detail); ok {
		return d, true
	}
	if m, ok := v.(map[string]any); ok {
		d := contracts.Uloha4Detail{}
		if s, ok := m["scenario_prompt"].(string); ok {
			d.ScenarioPrompt = s
		}
		if arr, ok := m["options"].([]any); ok {
			for _, item := range arr {
				if om, ok := item.(map[string]any); ok {
					opt := contracts.ChoiceOption{}
					if s, ok := om["option_key"].(string); ok {
						opt.OptionKey = s
					}
					if s, ok := om["label"].(string); ok {
						opt.Label = s
					}
					if s, ok := om["description"].(string); ok {
						opt.Description = s
					}
					d.Options = append(d.Options, opt)
				}
			}
		}
		if arr, ok := m["expected_reasoning_axes"].([]any); ok {
			for _, item := range arr {
				if s, ok := item.(string); ok {
					d.ExpectedReasoningAxes = append(d.ExpectedReasoningAxes, s)
				}
			}
		}
		return d, true
	}
	return contracts.Uloha4Detail{}, false
}

func normalizeReadinessLevel(raw string) string {
	v := strings.ToLower(strings.TrimSpace(raw))
	switch v {
	case "not_ready", "almost_ready", "ready_for_mock", "exam_ready":
		return v
	default:
		return "almost_ready"
	}
}

func sanitizeStringList(in []string) []string {
	out := make([]string, 0, len(in))
	for _, s := range in {
		s = strings.TrimSpace(s)
		if s == "" {
			continue
		}
		out = append(out, s)
	}
	return out
}

func extractJSONBlock(text string) string {
	trimmed := strings.TrimSpace(text)
	trimmed = strings.TrimPrefix(trimmed, "```json")
	trimmed = strings.TrimPrefix(trimmed, "```")
	trimmed = strings.TrimSuffix(trimmed, "```")
	trimmed = strings.TrimSpace(trimmed)
	start := strings.Index(trimmed, "{")
	end := strings.LastIndex(trimmed, "}")
	if start >= 0 && end > start {
		return trimmed[start : end+1]
	}
	return trimmed
}
