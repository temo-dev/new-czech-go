package processing

import (
	"encoding/json"
	"fmt"
	"strings"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// ScoreObjectiveAnswers compares learner answers to correct answers.
// Fill-in answers use case-insensitive substring match.
// Multiple-choice answers (≤4 chars) use case-insensitive exact match.
// questions: optional map[qno -> question_text]; optionTexts: optional map[qno -> map[key -> text]].
func ScoreObjectiveAnswers(learner, correct, questions map[string]string, optionTexts map[string]map[string]string) contracts.ObjectiveResult {
	breakdown := make([]contracts.QuestionResult, 0, len(correct))
	score := 0
	for qno, correctAns := range correct {
		learnerAns := strings.TrimSpace(learner[qno])
		isCorrect := matchObjectiveAnswer(learnerAns, correctAns)
		if isCorrect {
			score++
		}
		n := 0
		fmt.Sscanf(qno, "%d", &n)
		breakdown = append(breakdown, contracts.QuestionResult{
			QuestionNo:        n,
			QuestionText:      questions[qno],
			LearnerAnswer:     learnerAns,
			LearnerAnswerText: lookupOptionText(optionTexts, qno, learnerAns),
			CorrectAnswer:     correctAns,
			CorrectAnswerText: lookupOptionText(optionTexts, qno, correctAns),
			IsCorrect:         isCorrect,
		})
	}
	sortBreakdown(breakdown)
	return contracts.ObjectiveResult{
		Score:     score,
		MaxScore:  len(correct),
		Breakdown: breakdown,
	}
}

// lookupOptionText returns the display text for an option key in the given question.
// Falls back to the global wildcard bucket "*" for matching/image exercises.
func lookupOptionText(optionTexts map[string]map[string]string, qno, key string) string {
	if optionTexts == nil || key == "" {
		return ""
	}
	upper := strings.ToUpper(key)
	if opts, ok := optionTexts[qno]; ok {
		if text, ok := opts[upper]; ok {
			return text
		}
	}
	if opts, ok := optionTexts["*"]; ok {
		if text, ok := opts[upper]; ok {
			return text
		}
	}
	return ""
}

// matchObjectiveAnswer: single-letter A-H = exact match (choice key); anything else = bidirectional substring (fill-in).
func matchObjectiveAnswer(learner, correct string) bool {
	l := strings.ToLower(strings.TrimSpace(learner))
	c := strings.ToLower(strings.TrimSpace(correct))
	if l == "" || c == "" {
		return false
	}
	if isChoiceKey(c) {
		return l == c
	}
	return strings.Contains(l, c) || strings.Contains(c, l)
}

// isChoiceKey returns true for single-letter option keys A-H (case-insensitive).
func isChoiceKey(s string) bool {
	return len(s) == 1 && s[0] >= 'a' && s[0] <= 'h'
}

func sortBreakdown(breakdown []contracts.QuestionResult) {
	for i := 1; i < len(breakdown); i++ {
		for j := i; j > 0 && breakdown[j].QuestionNo < breakdown[j-1].QuestionNo; j-- {
			breakdown[j], breakdown[j-1] = breakdown[j-1], breakdown[j]
		}
	}
}

// ReadinessFromObjective maps score fraction to weak/ok/strong.
func ReadinessFromObjective(score, maxScore int) string {
	if maxScore == 0 {
		return "weak"
	}
	frac := float64(score) / float64(maxScore)
	switch {
	case frac >= 0.8:
		return "strong"
	case frac >= 0.5:
		return "ok"
	default:
		return "weak"
	}
}

// BuildObjectiveFeedback builds AttemptFeedback for objective (listening/reading) attempts.
func BuildObjectiveFeedback(result contracts.ObjectiveResult) contracts.AttemptFeedback {
	readiness := ReadinessFromObjective(result.Score, result.MaxScore)
	return contracts.AttemptFeedback{
		ReadinessLevel:  readiness,
		OverallSummary:  fmt.Sprintf("Bạn trả lời đúng %d/%d câu.", result.Score, result.MaxScore),
		Strengths:       []string{},
		Improvements:    []string{},
		TaskCompletion:  contracts.TaskCompletion{ScoreBand: readiness},
		GrammarFeedback: contracts.GrammarFeedback{ScoreBand: "n/a"},
		RetryAdvice:     []string{},
		ObjectiveResult: &result,
	}
}

// ProcessObjectiveAttempt scores a listening or reading attempt synchronously.
// Replaces the stub in writing_scorer.go.
func (p *Processor) ProcessObjectiveAttempt(attemptID string, sub contracts.AnswerSubmission) (*contracts.Attempt, error) {
	attempt, ok := p.repo.Attempt(attemptID)
	if !ok {
		return nil, fmt.Errorf("attempt %s not found", attemptID)
	}
	exercise, ok := p.repo.Exercise(attempt.ExerciseID)
	if !ok {
		return nil, fmt.Errorf("exercise %s not found", attempt.ExerciseID)
	}
	correct, err := extractCorrectAnswers(exercise)
	if err != nil {
		return nil, fmt.Errorf("exercise %s: %w", exercise.ID, err)
	}
	questions := extractQuestionTexts(exercise)
	optionTexts := extractOptionTexts(exercise)

	result := ScoreObjectiveAnswers(sub.Answers, correct, questions, optionTexts)
	feedback := BuildObjectiveFeedback(result)

	transcript := contracts.Transcript{
		FullText:    formatAnswersAsText(sub.Answers),
		Locale:      attempt.Locale,
		IsSynthetic: true,
		Provider:    "objective_scorer",
	}

	p.repo.SetAttemptStatus(attemptID, "scoring")
	p.repo.CompleteAttempt(attemptID, transcript, feedback)

	completed, ok := p.repo.Attempt(attemptID)
	if !ok {
		return nil, fmt.Errorf("attempt %s missing after completion", attemptID)
	}
	return completed, nil
}

func extractCorrectAnswers(exercise contracts.Exercise) (map[string]string, error) {
	type withCorrectAnswers struct {
		CorrectAnswers map[string]string `json:"correct_answers"`
	}
	b, err := json.Marshal(exercise.Detail)
	if err != nil {
		return nil, err
	}
	var d withCorrectAnswers
	if err := json.Unmarshal(b, &d); err != nil || len(d.CorrectAnswers) == 0 {
		return nil, fmt.Errorf("no correct_answers in detail")
	}
	return d.CorrectAnswers, nil
}

func formatAnswersAsText(answers map[string]string) string {
	var parts []string
	for k, v := range answers {
		parts = append(parts, fmt.Sprintf("Q%s: %s", k, v))
	}
	return strings.Join(parts, ", ")
}

func unmarshalJSON(b []byte, v any) error {
	return json.Unmarshal(b, v)
}

// extractOptionTexts returns map[question_no_str -> map[option_key -> option_text]].
// For per-question options (poslech_1/2/3 items, cteni_2/4 questions), each
// question has its own key→text map.
// For global options (poslech_3 match labels, cteni_1/3 text/person options),
// all questions share a single map stored under the wildcard key "*".
func extractOptionTexts(exercise contracts.Exercise) map[string]map[string]string {
	b, err := json.Marshal(exercise.Detail)
	if err != nil {
		return nil
	}

	result := make(map[string]map[string]string)

	// Per-question options via "items" (poslech_1/2/3)
	var withItemsOpts struct {
		Items []struct {
			QuestionNo int `json:"question_no"`
			Options    []struct {
				Key  string `json:"key"`
				Text string `json:"text"`
			} `json:"options"`
		} `json:"items"`
	}
	if json.Unmarshal(b, &withItemsOpts) == nil {
		for _, item := range withItemsOpts.Items {
			opts := make(map[string]string)
			for _, o := range item.Options {
				if o.Key != "" && o.Text != "" {
					opts[strings.ToUpper(o.Key)] = o.Text
				}
			}
			if len(opts) > 0 {
				result[fmt.Sprintf("%d", item.QuestionNo)] = opts
			}
		}
	}

	// Per-question options via "questions" (cteni_2/4)
	var withQuestionsOpts struct {
		Questions []struct {
			QuestionNo int `json:"question_no"`
			Options    []struct {
				Key  string `json:"key"`
				Text string `json:"text"`
			} `json:"options"`
		} `json:"questions"`
	}
	if json.Unmarshal(b, &withQuestionsOpts) == nil {
		for _, q := range withQuestionsOpts.Questions {
			opts := make(map[string]string)
			for _, o := range q.Options {
				if o.Key != "" && o.Text != "" {
					opts[strings.ToUpper(o.Key)] = o.Text
				}
			}
			if len(opts) > 0 {
				result[fmt.Sprintf("%d", q.QuestionNo)] = opts
			}
		}
	}

	// Global options shared across questions (poslech_3 MatchOption label,
	// cteni_1 TextOption text, cteni_3 PersonOption name).
	var withGlobal struct {
		Options []struct {
			Key   string `json:"key"`
			Text  string `json:"text"`
			Label string `json:"label"`
		} `json:"options"`
		Persons []struct {
			Key  string `json:"key"`
			Name string `json:"name"`
		} `json:"persons"`
	}
	if json.Unmarshal(b, &withGlobal) == nil {
		global := make(map[string]string)
		for _, o := range withGlobal.Options {
			text := o.Text
			if text == "" {
				text = o.Label
			}
			if o.Key != "" && text != "" {
				global[strings.ToUpper(o.Key)] = text
			}
		}
		for _, p := range withGlobal.Persons {
			if p.Key != "" && p.Name != "" {
				global[strings.ToUpper(p.Key)] = p.Name
			}
		}
		if len(global) > 0 {
			result["*"] = global
		}
	}

	// Matching exercise: right-column options keyed by right_id (A/B/C/D...).
	var withPairs struct {
		Pairs []struct {
			RightID string `json:"right_id"`
			Right   string `json:"right"`
		} `json:"pairs"`
	}
	if json.Unmarshal(b, &withPairs) == nil && len(withPairs.Pairs) > 0 {
		global := result["*"]
		if global == nil {
			global = make(map[string]string)
		}
		for _, p := range withPairs.Pairs {
			if p.RightID != "" && p.Right != "" {
				global[strings.ToUpper(p.RightID)] = p.Right
			}
		}
		result["*"] = global
	}

	return result
}

// extractQuestionTexts returns a map[question_no_str -> question_text] from the
// exercise detail. Works for all exercise types that store questions in either
// an "items" array (ListeningItem.question) or a "questions" array
// (ReadingQuestion.prompt / FillQuestion.prompt).
func extractQuestionTexts(exercise contracts.Exercise) map[string]string {
	b, err := json.Marshal(exercise.Detail)
	if err != nil {
		return nil
	}

	texts := make(map[string]string)

	// Try "items" (poslech_1/2/3 — ListeningItem.question)
	var withItems struct {
		Items []struct {
			QuestionNo int    `json:"question_no"`
			Question   string `json:"question"`
		} `json:"items"`
	}
	if json.Unmarshal(b, &withItems) == nil {
		for _, item := range withItems.Items {
			if item.Question != "" {
				texts[fmt.Sprintf("%d", item.QuestionNo)] = item.Question
			}
		}
	}

	// Try "questions" with "prompt" (cteni_2/4/5, poslech_5 — ReadingQuestion/FillQuestion)
	var withQuestions struct {
		Questions []struct {
			QuestionNo int    `json:"question_no"`
			Prompt     string `json:"prompt"`
		} `json:"questions"`
	}
	if json.Unmarshal(b, &withQuestions) == nil {
		for _, q := range withQuestions.Questions {
			if q.Prompt != "" {
				texts[fmt.Sprintf("%d", q.QuestionNo)] = q.Prompt
			}
		}
	}

	// Matching exercise: left column (left_id → left text).
	var withPairsQ struct {
		Pairs []struct {
			LeftID string `json:"left_id"`
			Left   string `json:"left"`
		} `json:"pairs"`
	}
	if json.Unmarshal(b, &withPairsQ) == nil {
		for _, p := range withPairsQ.Pairs {
			if p.LeftID != "" && p.Left != "" {
				texts[p.LeftID] = p.Left
			}
		}
	}

	return texts
}
