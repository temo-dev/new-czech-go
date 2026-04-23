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
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

const (
	llmProviderDev    = "dev"
	llmProviderClaude = "claude"

	defaultClaudeModel = "claude-haiku-4-5-20251001"
	claudeAPIEndpoint  = "https://api.anthropic.com/v1/messages"
	claudeAPIVersion   = "2023-06-01"
	llmRequestTimeout  = 30 * time.Second
)

type LLMFeedbackProvider interface {
	GenerateFeedback(exercise contracts.Exercise, transcript contracts.Transcript, reliability transcriptReliability, locale string) (contracts.AttemptFeedback, error)
}

type DevLLMFeedbackProvider struct{}

func (DevLLMFeedbackProvider) GenerateFeedback(_ contracts.Exercise, _ contracts.Transcript, _ transcriptReliability, _ string) (contracts.AttemptFeedback, error) {
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
	model := strings.TrimSpace(os.Getenv("LLM_MODEL"))
	if model == "" {
		model = defaultClaudeModel
	}
	return &ClaudeLLMFeedbackProvider{
		apiKey: apiKey,
		model:  model,
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

func (c *ClaudeLLMFeedbackProvider) GenerateFeedback(exercise contracts.Exercise, transcript contracts.Transcript, reliability transcriptReliability, locale string) (contracts.AttemptFeedback, error) {
	systemPrompt := buildLLMSystemPrompt(locale)
	userPrompt := buildLLMUserPrompt(exercise, transcript, reliability, locale)

	reqBody := claudeMessageRequest{
		Model:     c.model,
		MaxTokens: 2048,
		System:    systemPrompt,
		Messages: []claudeMessage{
			{Role: "user", Content: userPrompt},
		},
	}
	payload, err := json.Marshal(reqBody)
	if err != nil {
		return contracts.AttemptFeedback{}, fmt.Errorf("marshal claude request: %w", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), llmRequestTimeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, claudeAPIEndpoint, bytes.NewReader(payload))
	if err != nil {
		return contracts.AttemptFeedback{}, fmt.Errorf("build claude request: %w", err)
	}
	req.Header.Set("content-type", "application/json")
	req.Header.Set("x-api-key", c.apiKey)
	req.Header.Set("anthropic-version", claudeAPIVersion)

	resp, err := c.client.Do(req)
	if err != nil {
		return contracts.AttemptFeedback{}, fmt.Errorf("call claude: %w", err)
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return contracts.AttemptFeedback{}, fmt.Errorf("read claude response: %w", err)
	}
	if resp.StatusCode >= 400 {
		return contracts.AttemptFeedback{}, fmt.Errorf("claude api status %d: %s", resp.StatusCode, string(body))
	}

	var parsed claudeMessageResponse
	if err := json.Unmarshal(body, &parsed); err != nil {
		return contracts.AttemptFeedback{}, fmt.Errorf("unmarshal claude response: %w", err)
	}
	if parsed.Error != nil {
		return contracts.AttemptFeedback{}, fmt.Errorf("claude api error %s: %s", parsed.Error.Type, parsed.Error.Message)
	}
	if len(parsed.Content) == 0 || parsed.Content[0].Text == "" {
		return contracts.AttemptFeedback{}, fmt.Errorf("claude response empty")
	}

	raw := extractJSONBlock(parsed.Content[0].Text)
	var fb llmFeedbackJSON
	if err := json.Unmarshal([]byte(raw), &fb); err != nil {
		return contracts.AttemptFeedback{}, fmt.Errorf("parse feedback json: %w; body=%s", err, raw)
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

func buildLLMSystemPrompt(locale string) string {
	targetLanguage := "Vietnamese"
	audienceClause := "You are an expert Czech language coach for Vietnamese learners preparing for the Czech \"trvaly pobyt A2\" oral exam."
	if locale == contracts.LocaleEN {
		targetLanguage = "English"
		audienceClause = "You are an expert Czech language coach for English-speaking learners preparing for the Czech \"trvaly pobyt A2\" oral exam."
	}
	languageClause := fmt.Sprintf("CRITICAL LANGUAGE RULE: overall_summary, strengths, improvements, retry_advice MUST be written ENTIRELY in %s. DO NOT write these fields in Czech. DO NOT mix languages. The ONLY field allowed to contain Czech is sample_answer (which must be natural Czech). If you quote a Czech word/phrase from the learner to explain an error, embed it inside a %s sentence (e.g. in %s: \"the phrase X is wrong — use Y\").", targetLanguage, targetLanguage, targetLanguage)
	return strings.Join([]string{
		audienceClause,
		"Evaluate the learner's response and return ONLY valid JSON — no markdown, no explanation, no prose outside the JSON object.",
		languageClause,
		"readiness_level MUST be one of: not_ready, almost_ready, ready_for_mock, exam_ready.",
		fmt.Sprintf("strengths, improvements, retry_advice: arrays of 1-3 CONCISE %s strings each (one actionable idea per string, keep each string under 200 characters).", targetLanguage),
		"overall_summary: one concise paragraph, under 400 characters.",
		"sample_answer: one or two natural Czech sentences demonstrating the correct, exam-appropriate response.",
		"",
		"PRIMARY EVALUATION FOCUS (most important — majority of feedback must come from these two):",
		"(A) Czech GRAMMAR correctness — be specific. Call out exact errors: wrong case endings (nominative/accusative/genitive/dative/locative/instrumental mismatches), wrong verb conjugation, wrong tense, wrong aspect (perfective/imperfective), wrong word order, missing reflexive 'se'/'si', wrong preposition-case pairing, subject-verb agreement, gender agreement on adjectives. Quote the learner's exact wrong phrase and give the corrected Czech form.",
		"(B) PRONUNCIATION proxy inferred from the transcript — Czech speech-to-text output reveals pronunciation issues. Look for: missing or wrong diacritics (á/é/í/ó/ú/ů/ě/š/č/ř/ž/ý/ň/ť/ď) suggesting the learner skipped the sound, consonant cluster mistakes (especially ř, which is the hardest sound), wrong vowel length (short vs long — Czech distinguishes a/á, e/é, i/í, o/ó, u/ú, y/ý), softened consonants (d/ď, t/ť, n/ň) dropped, final devoicing errors, syllable omissions suggesting mumbled or rushed speech, and common Vietnamese-speaker patterns (dropping final consonants, tonal interference, confusing voiced/voiceless pairs like b/p, d/t, g/k, z/s). Name specific sounds the learner likely struggled with.",
		"",
		"SECONDARY DIMENSIONS (mention only briefly if relevant):",
		"(C) task completion — did they address the required questions/topic",
		"(D) naturalness and flow",
		"(E) lesson relevance",
		"",
		"At least 2 of 3 'strengths' and at least 2 of 3 'improvements' MUST be about grammar or pronunciation specifically. Do not fill strengths/improvements with generic praise or task-completion notes when grammar/pronunciation issues are present.",
		"Keep feedback concrete and actionable, cite exact Czech words/phrases, not generic advice.",
		"Output schema: {\"readiness_level\":\"...\",\"overall_summary\":\"...\",\"strengths\":[\"...\"],\"improvements\":[\"...\"],\"retry_advice\":[\"...\"],\"sample_answer\":\"...\"}",
	}, "\n")
}

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
				b.WriteString("Narrative checkpoints the learner should cover:\n")
				for _, c := range d.NarrativeCheckpoints {
					fmt.Fprintf(&b, "- %s\n", c)
				}
			}
			if len(d.GrammarFocus) > 0 {
				b.WriteString("Grammar focus: " + strings.Join(d.GrammarFocus, ", ") + "\n")
			}
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
			return b.String()
		}
	}
	return ""
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
