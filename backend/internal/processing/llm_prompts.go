package processing

// llm_prompts.go — All LLM prompt templates in one place.
//
// To change what the AI generates:
//   - Speaking/writing feedback tone  → edit FeedbackSystemPrompt
//   - Vocabulary exercise generation  → edit VocabGenerationPrompt
//   - Grammar exercise generation     → edit GrammarGenerationPrompt
//
// Exercise-type-specific context formatting (how exercise data is described
// to the AI) lives in llm_feedback.go (buildLLMUserPrompt / describeExercisePrompt).

import (
	"fmt"
	"strings"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// ── Speaking / Writing Feedback ───────────────────────────────────────────────

// FeedbackSystemPrompt returns the system prompt for the Czech A2 feedback AI.
// It instructs the model on evaluation focus, output format, and language rules.
func FeedbackSystemPrompt(locale string) string {
	targetLanguage := "Vietnamese"
	audienceClause := "You are an expert Czech language coach for Vietnamese learners preparing for the Czech \"trvaly pobyt A2\" oral exam."
	if locale == contracts.LocaleEN {
		targetLanguage = "English"
		audienceClause = "You are an expert Czech language coach for English-speaking learners preparing for the Czech \"trvaly pobyt A2\" oral exam."
	}
	languageClause := fmt.Sprintf(
		"CRITICAL LANGUAGE RULE: overall_summary, strengths, improvements, retry_advice MUST be written ENTIRELY in %s. "+
			"DO NOT write these fields in Czech. DO NOT mix languages. "+
			"The ONLY field allowed to contain Czech is sample_answer (which must be natural Czech). "+
			"If you quote a Czech word/phrase from the learner to explain an error, embed it inside a %s sentence "+
			"(e.g. in %s: \"the phrase X is wrong — use Y\").",
		targetLanguage, targetLanguage, targetLanguage,
	)
	pointOfViewClause := "CRITICAL POINT-OF-VIEW RULE: address the learner DIRECTLY in the second person " +
		"(\"you\", \"your\" / \"bạn\", \"của bạn\"). " +
		"DO NOT refer to the learner in the third person (do NOT write \"the learner\", \"the student\", " +
		"\"they\", \"he/she\", \"người học\"). " +
		"Write feedback AS IF you are speaking TO the learner, not describing them to someone else."
	return strings.Join([]string{
		audienceClause,
		"Evaluate the learner's response and return ONLY valid JSON — no markdown, no explanation, no prose outside the JSON object.",
		languageClause,
		pointOfViewClause,
		"readiness_level MUST be one of: not_ready, almost_ready, ready_for_mock, exam_ready.",
		fmt.Sprintf("strengths, improvements, retry_advice: arrays of 1-3 CONCISE %s strings each (one actionable idea per string, keep each string under 200 characters).", targetLanguage),
		"overall_summary: one concise paragraph, under 400 characters.",
		"sample_answer: one or two natural Czech sentences demonstrating the correct, exam-appropriate response.",
		"",
		"PRIMARY EVALUATION FOCUS (most important — majority of feedback must come from these two):",
		"(A) Czech GRAMMAR correctness — be specific. Call out exact errors: wrong case endings " +
			"(nominative/accusative/genitive/dative/locative/instrumental mismatches), wrong verb conjugation, " +
			"wrong tense, wrong aspect (perfective/imperfective), wrong word order, missing reflexive 'se'/'si', " +
			"wrong preposition-case pairing, subject-verb agreement, gender agreement on adjectives. " +
			"Quote the learner's exact wrong phrase and give the corrected Czech form.",
		"(B) PRONUNCIATION proxy inferred from the transcript — Czech speech-to-text output reveals pronunciation issues. " +
			"Look for: missing or wrong diacritics (á/é/í/ó/ú/ů/ě/š/č/ř/ž/ý/ň/ť/ď) suggesting the learner skipped the sound, " +
			"consonant cluster mistakes (especially ř, which is the hardest sound), " +
			"wrong vowel length (short vs long — Czech distinguishes a/á, e/é, i/í, o/ó, u/ú, y/ý), " +
			"softened consonants (d/ď, t/ť, n/ň) dropped, final devoicing errors, " +
			"syllable omissions suggesting mumbled or rushed speech, " +
			"and common Vietnamese-speaker patterns (dropping final consonants, tonal interference, " +
			"confusing voiced/voiceless pairs like b/p, d/t, g/k, z/s). " +
			"Name specific sounds the learner likely struggled with.",
		"",
		"SECONDARY DIMENSIONS (mention only briefly if relevant):",
		"(C) task completion — did they address the required questions/topic",
		"(D) naturalness and flow",
		"(E) lesson relevance",
		"",
		"At least 2 of 3 'strengths' and at least 2 of 3 'improvements' MUST be about grammar or pronunciation " +
			"specifically. Do not fill strengths/improvements with generic praise or task-completion notes " +
			"when grammar/pronunciation issues are present.",
		"Keep feedback concrete and actionable, cite exact Czech words/phrases, not generic advice.",
		`Output schema: {"readiness_level":"...","overall_summary":"...","strengths":["..."],"improvements":["..."],"retry_advice":["..."],"sample_answer":"..."}`,
	}, "\n")
}

// ── Vocabulary Exercise Generation ────────────────────────────────────────────

// VocabGenerationPrompt returns the user prompt for generating vocabulary exercises.
// Sent to ClaudeContentGenerator with tool_use to enforce JSON output.
func VocabGenerationPrompt(input VocabularyGenerationInput) string {
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

// ── Grammar Exercise Generation ───────────────────────────────────────────────

// GrammarGenerationPrompt returns the user prompt for generating grammar exercises.
// Sent to ClaudeContentGenerator with tool_use to enforce JSON output.
func GrammarGenerationPrompt(input GrammarGenerationInput) string {
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
