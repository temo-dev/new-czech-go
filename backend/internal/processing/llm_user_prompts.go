package processing

// llm_user_prompts.go — Per-attempt USER prompt builders fed into the LLM.
//
// System prompts (the model's role/rubric) are in llm_prompts.go.
// Each builder here renders the request-specific context (exercise data,
// learner transcript, prior coach summary) into the user message body.

import (
	"fmt"
	"strings"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// ── Speaking / Writing Feedback ───────────────────────────────────────────────

// buildLLMUserPrompt renders the user-message context for FeedbackSystemPrompt.
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

// ── Review Artifact ───────────────────────────────────────────────────────────

// buildLLMReviewUserPrompt renders the user-message context for ReviewSystemPrompt.
func buildLLMReviewUserPrompt(exercise contracts.Exercise, transcript contracts.Transcript, feedback contracts.AttemptFeedback, locale string) string {
	_ = locale
	var b strings.Builder
	fmt.Fprintf(&b, "Exercise type: %s\n", exercise.ExerciseType)
	if exercise.Title != "" {
		fmt.Fprintf(&b, "Exercise title: %s\n", exercise.Title)
	}
	if exercise.LearnerInstruction != "" {
		fmt.Fprintf(&b, "Learner instruction: %s\n", exercise.LearnerInstruction)
	}
	b.WriteString(describeExercisePrompt(exercise))
	b.WriteString("\n")
	fmt.Fprintf(&b, "Learner transcript (Czech, may contain errors): %q\n", strings.TrimSpace(transcript.FullText))
	if transcript.Confidence > 0 {
		fmt.Fprintf(&b, "Transcript confidence: %.2f\n", transcript.Confidence)
	}
	if transcript.IsSynthetic {
		b.WriteString("Note: transcript was synthesized for testing.\n")
	}
	if feedback.OverallSummary != "" {
		fmt.Fprintf(&b, "Coach summary of attempt: %s\n", feedback.OverallSummary)
	}
	if len(feedback.Improvements) > 0 {
		b.WriteString("Issues already identified:\n")
		for _, s := range feedback.Improvements {
			fmt.Fprintf(&b, "- %s\n", s)
		}
	}
	b.WriteString("\nReturn the JSON only. Both fields must be non-empty A2 Czech.")
	return b.String()
}

// ── Interview Scoring ─────────────────────────────────────────────────────────

// buildInterviewUserPrompt renders the user-message context for InterviewSystemPrompt.
func buildInterviewUserPrompt(exerciseType, topic string, turns []interviewTurn, durationSec int) string {
	transcriptText := buildInterviewTranscriptText(turns)
	topicLine := ""
	if topic != "" {
		topicLine = fmt.Sprintf("Topic: %s\n", topic)
	}
	return fmt.Sprintf(
		"Exercise type: %s\n%sDuration: %d seconds\n\nTranscript:\n%s",
		exerciseType, topicLine, durationSec, transcriptText,
	)
}

// ── Exercise context formatter ────────────────────────────────────────────────
//
// describeExercisePrompt is shared by feedback + review user-prompt builders.
// It renders task-specific context (topic, checkpoints, options, rubric) so the
// LLM can ground its evaluation in the exercise's actual requirements.

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

// ── Exercise detail extractors (used by describeExercisePrompt) ──────────────

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

// ── Dictation Annotation (V18) ───────────────────────────────────────────────

// DictationLLMInput is what the user prompt feeds the model for one sentence.
// DistanceWeighted is for context only — the model MUST NOT score.
type DictationLLMInput struct {
	Idx              int
	Reference        string
	Learner          string
	DistanceWeighted float64
}

// DictationLLMAnnotation is what the model returns per sentence (parsed JSON).
type DictationLLMAnnotation struct {
	Idx        int                   `json:"idx"`
	ErrorTags  []string              `json:"error_tags,omitempty"`
	FeedbackVI string                `json:"feedback_vi,omitempty"`
	FeedbackEN string                `json:"feedback_en,omitempty"`
	DiffChunks []contracts.DiffChunk `json:"diff_chunks,omitempty"`
}

// buildDictationUserPrompt renders the user-message context for
// DictationSystemPrompt. The reference and learner texts are passed in
// raw (not normalized) so the model can comment on case, spacing, and
// diacritics meaningfully.
func buildDictationUserPrompt(inputs []DictationLLMInput) string {
	var b strings.Builder
	b.WriteString("Annotate the following dictation attempts. Output a JSON array, one entry per input, in the SAME order. Do NOT score.\n\n")
	for _, in := range inputs {
		fmt.Fprintf(&b, "Sentence idx=%d (deterministic distance=%.2f):\n", in.Idx, in.DistanceWeighted)
		fmt.Fprintf(&b, "  reference: %q\n", in.Reference)
		fmt.Fprintf(&b, "  learner:   %q\n\n", in.Learner)
	}
	b.WriteString("Output format: [{\"idx\":N,\"error_tags\":[...],\"feedback_vi\":\"...\",\"feedback_en\":\"...\",\"diff_chunks\":[...]}, ...]")
	return b.String()
}

// buildDictationOCRUserPrompt renders the user-message text that accompanies
// the image content block sent to Claude Vision. The image itself is added
// as a separate content block by the caller.
func buildDictationOCRUserPrompt() string {
	return strings.Join([]string{
		"Read the handwritten Czech sentence in the photo above.",
		"Return ONLY a JSON object: {\"text\": \"...\"}.",
		"Preserve all diacritics and capitalization.",
		"If unreadable, return {\"text\": \"\"}.",
	}, " ")
}

// ── V24 Reading draft generation ─────────────────────────────────────────────

// BuildReadingDraftUserPrompt renders the per-cteni-type user message paired
// with ReadingDraftSystemPrompt. Type-specific structural requirements live
// in each branch; cross-cutting rules (CEFR fidelity, distractor quality,
// ANO/NE casing) live in the system prompt.
//
// Each branch must echo the topic, grammar points + their rule_table, level,
// and any extra_instructions provided by the admin.
func BuildReadingDraftUserPrompt(in contracts.ReadingDraftInput) string {
	var b strings.Builder
	fmt.Fprintf(&b, "Exercise type: %s\n", in.ExerciseType)
	fmt.Fprintf(&b, "Topic: %s\n", strings.TrimSpace(in.Topic))
	fmt.Fprintf(&b, "Level: %s\n", in.Level)
	b.WriteString("Grammar points to demonstrate:\n")
	for _, gp := range in.GrammarPoints {
		fmt.Fprintf(&b, "- %s", gp.Title)
		if gp.ExplanationVI != "" {
			fmt.Fprintf(&b, " (note: %s)", gp.ExplanationVI)
		}
		b.WriteString("\n")
		if len(gp.RuleTable) > 0 {
			b.WriteString("  forms: ")
			pairs := make([]string, 0, len(gp.RuleTable))
			for k, v := range gp.RuleTable {
				pairs = append(pairs, fmt.Sprintf("%s→%s", k, v))
			}
			b.WriteString(strings.Join(pairs, ", "))
			b.WriteString("\n")
		}
	}
	if extra := strings.TrimSpace(in.ExtraInstructions); extra != "" {
		fmt.Fprintf(&b, "Extra admin instructions: %s\n", extra)
	}
	b.WriteString("\nStructural requirements for this exercise type:\n")
	b.WriteString(readingDraftStructuralRequirements(in.ExerciseType))
	return b.String()
}

func readingDraftStructuralRequirements(exerciseType string) string {
	switch exerciseType {
	case "cteni_2":
		return strings.Join([]string{
			"- Generate exactly one passage of natural Czech, 100-200 words, in field `text`",
			"- Generate exactly 5 questions; question_no = 6, 7, 8, 9, 10 (matches A2 exam ordering after cteni_1 items 1-5)",
			"- Each question has exactly 4 options with keys A, B, C, D and non-empty option `text`",
			"- correct_answers map: keys \"6\"..\"10\", values are A, B, C, or D matching the correct option key",
			"- Distractors must be plausible (same semantic field, same grammatical category as the correct answer)",
		}, "\n")
	case "cteni_4":
		return strings.Join([]string{
			"- Optionally include a short reading context (60-120 words) in field `context`; questions may stand alone",
			"- Generate exactly 6 questions; question_no = 15, 16, 17, 18, 19, 20 (matches A2 exam ordering)",
			"- Each question has exactly 4 options with keys A, B, C, D and non-empty option `text`",
			"- correct_answers map: keys \"15\"..\"20\", values are A, B, C, or D matching the correct option key",
			"- Distractors must be plausible (same semantic field, same grammatical category as the correct answer)",
		}, "\n")
	case "cteni_5":
		return strings.Join([]string{
			"- Generate exactly one passage of natural Czech, 80-150 words, in field `text`",
			"- Generate exactly 5 fill-information questions; question_no = 21, 22, 23, 24, 25 (matches A2 exam ordering)",
			"- Each question has a non-empty `prompt` describing the slot (e.g. \"Jméno autora:\", \"Den:\")",
			"- correct_answers map: keys \"21\"..\"25\", values are short factual strings (single noun, number, or date) ≤30 characters",
			"- Answers must be findable verbatim in the passage",
		}, "\n")
	case "cteni_6":
		return strings.Join([]string{
			"- Generate exactly one passage of natural Czech, 80-150 words, in field `passage`",
			"- Generate between 1 and 5 Ano/Ne statements; each question_no = 1..N",
			"- correct_answers map: keys \"1\"..\"N\"; values must be UPPERCASE \"ANO\" or \"NE\"",
			"- Set max_points equal to the number of statements",
			"- Mix at least one ANO and one NE when N ≥ 2 to keep the exercise discriminating",
		}, "\n")
	case "cteni_3":
		return strings.Join([]string{
			"- Generate exactly 4 short text items (item_no = 1..4), each 30-60 words, expressing a personal preference or routine",
			"- Generate exactly 5 persons (keys A-E) with `name` and short `description`; one person is a distractor not matched by any text",
			"- correct_answers map: keys \"1\"..\"4\", values are unique person keys A-E (each person matches at most one text)",
			"- Persons must be distinguishable by description (different hobby, profession, or trait)",
		}, "\n")
	case "cteni_1":
		return strings.Join([]string{
			"- Generate exactly 5 short text items (item_no = 1..5), each one short message (10-25 words) the learner reads (e.g. SMS, sign, notice)",
			"- Each item has only `text` — DO NOT produce `asset_id`; the admin uploads accompanying images later",
			"- Generate exactly 8 options (keys A-H) summarising the message theme (e.g. \"info o schůzce\", \"info o cestování\")",
			"- correct_answers map: keys \"1\"..\"5\", values are unique option keys A-H (each option matches at most one item; 3 options are distractors)",
			"- Options must be plausible competing summaries — not obvious to the eye, requiring the learner to read the text",
		}, "\n")
	}
	return ""
}
