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
func ScoreObjectiveAnswers(learner, correct map[string]string) contracts.ObjectiveResult {
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
			QuestionNo:    n,
			LearnerAnswer: learnerAns,
			CorrectAnswer: correctAns,
			IsCorrect:     isCorrect,
		})
	}
	sortBreakdown(breakdown)
	return contracts.ObjectiveResult{
		Score:     score,
		MaxScore:  len(correct),
		Breakdown: breakdown,
	}
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

	result := ScoreObjectiveAnswers(sub.Answers, correct)
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
