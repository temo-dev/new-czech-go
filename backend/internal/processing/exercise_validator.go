package processing

import (
	"encoding/json"
	"fmt"
	"strings"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// ValidateGeneratedExercise checks a single generated exercise for structural correctness.
// Returns a list of error messages; empty means valid.
func ValidateGeneratedExercise(ex contracts.GeneratedExercise) []string {
	var errs []string

	switch ex.ExerciseType {
	case "quizcard_basic":
		if strings.TrimSpace(ex.FrontText) == "" {
			errs = append(errs, "front_text required")
		}
		if strings.TrimSpace(ex.BackText) == "" {
			errs = append(errs, "back_text required")
		}

	case "choice_word":
		if strings.TrimSpace(ex.Prompt) == "" {
			errs = append(errs, "prompt required")
		}
		if len(ex.Options) < 2 {
			errs = append(errs, fmt.Sprintf("need ≥2 options, got %d", len(ex.Options)))
		}
		if ex.CorrectAnswer == "" {
			errs = append(errs, "correct_answer required")
		}
		found := false
		seen := map[string]bool{}
		for _, opt := range ex.Options {
			if seen[opt] {
				errs = append(errs, fmt.Sprintf("duplicate option %q", opt))
			}
			seen[opt] = true
			if opt == ex.CorrectAnswer {
				found = true
			}
		}
		if ex.CorrectAnswer != "" && !found {
			errs = append(errs, fmt.Sprintf("correct_answer %q not in options", ex.CorrectAnswer))
		}

	case "fill_blank":
		if !strings.Contains(ex.Prompt, "___") {
			errs = append(errs, "prompt must contain ___")
		}
		if strings.TrimSpace(ex.CorrectAnswer) == "" {
			errs = append(errs, "correct_answer required")
		}

	case "matching":
		if len(ex.Pairs) < 2 {
			errs = append(errs, fmt.Sprintf("need ≥2 pairs, got %d", len(ex.Pairs)))
		}
		seenLeft := map[string]bool{}
		seenRight := map[string]bool{}
		for i, p := range ex.Pairs {
			if strings.TrimSpace(p.Left) == "" {
				errs = append(errs, fmt.Sprintf("pair[%d].left required", i))
			}
			if strings.TrimSpace(p.Right) == "" {
				errs = append(errs, fmt.Sprintf("pair[%d].right required", i))
			}
			if seenLeft[p.Left] {
				errs = append(errs, fmt.Sprintf("duplicate left term %q", p.Left))
			}
			seenLeft[p.Left] = true
			if seenRight[p.Right] {
				errs = append(errs, fmt.Sprintf("duplicate right definition %q", p.Right))
			}
			seenRight[p.Right] = true
		}

	default:
		errs = append(errs, fmt.Sprintf("unknown exercise_type %q", ex.ExerciseType))
	}

	if strings.TrimSpace(ex.Explanation) == "" {
		errs = append(errs, "explanation required")
	}

	return errs
}

// BuildExerciseFromGenerated converts a GeneratedExercise into a publishable contracts.Exercise.
// The caller must set SkillID and source provenance fields.
func BuildExerciseFromGenerated(ex contracts.GeneratedExercise) (contracts.Exercise, error) {
	exercise := contracts.Exercise{
		ExerciseType:         ex.ExerciseType,
		Pool:                 "course",
		Status:               "published",
		SampleAnswerEnabled:  false,
		EstimatedDurationSec: estimatedDurationSec(ex.ExerciseType),
	}

	switch ex.ExerciseType {
	case "quizcard_basic":
		exercise.Title = ex.FrontText
		exercise.ShortInstruction = "Lật thẻ để xem nghĩa"
		exercise.LearnerInstruction = "Nhấn vào thẻ để xem nghĩa tiếng Việt. Sau đó chọn Đã biết hoặc Ôn lại."
		detail := contracts.QuizcardBasicDetail{
			FrontText:          ex.FrontText,
			BackText:           ex.BackText,
			ExampleSentence:    ex.ExampleSentence,
			ExampleTranslation: ex.ExampleTranslation,
			Explanation:        ex.Explanation,
			CorrectAnswers:     map[string]string{"1": "known"},
		}
		exercise.Detail = detail

	case "choice_word":
		exercise.Title = ex.Prompt
		exercise.ShortInstruction = "Chọn từ đúng để hoàn thành câu"
		exercise.LearnerInstruction = ex.Prompt
		opts := make([]contracts.MultipleChoiceOption, len(ex.Options))
		keys := []string{"A", "B", "C", "D", "E"}
		correctKey := ""
		for i, opt := range ex.Options {
			key := keys[i]
			opts[i] = contracts.MultipleChoiceOption{Key: key, Text: opt}
			if opt == ex.CorrectAnswer {
				correctKey = key
			}
		}
		detail := contracts.ChoiceWordDetail{
			Stem:           ex.Prompt,
			Options:        opts,
			GrammarNote:    ex.GrammarNote,
			Explanation:    ex.Explanation,
			CorrectAnswers: map[string]string{"1": correctKey},
		}
		exercise.Detail = detail

	case "fill_blank":
		exercise.Title = ex.Prompt
		exercise.ShortInstruction = "Điền từ vào chỗ trống"
		exercise.LearnerInstruction = ex.Prompt
		detail := contracts.FillBlankDetail{
			Sentence:       ex.Prompt,
			Explanation:    ex.Explanation,
			CorrectAnswers: map[string]string{"1": ex.CorrectAnswer},
		}
		exercise.Detail = detail

	case "matching":
		exercise.Title = "Ghép từ với nghĩa"
		exercise.ShortInstruction = "Ghép các từ tiếng Czech với nghĩa tiếng Việt"
		exercise.LearnerInstruction = "Nhấn vào từ bên trái, sau đó nhấn vào nghĩa tương ứng bên phải."
		rightKeys := []string{"A", "B", "C", "D", "E", "F", "G", "H"}
		pairs := make([]contracts.MatchingPair, len(ex.Pairs))
		correctAnswers := map[string]string{}
		for i, p := range ex.Pairs {
			leftID := fmt.Sprintf("%d", i+1)
			rightID := rightKeys[i]
			pairs[i] = contracts.MatchingPair{
				LeftID:  leftID,
				Left:    p.Left,
				RightID: rightID,
				Right:   p.Right,
			}
			correctAnswers[leftID] = rightID
		}
		detail := contracts.MatchingDetail{
			Pairs:          pairs,
			Explanation:    ex.Explanation,
			CorrectAnswers: correctAnswers,
		}
		exercise.Detail = detail

	default:
		return contracts.Exercise{}, fmt.Errorf("unsupported exercise type %q", ex.ExerciseType)
	}

	detailJSON, err := json.Marshal(exercise.Detail)
	if err != nil {
		return contracts.Exercise{}, fmt.Errorf("marshal detail: %w", err)
	}
	var detailAny any
	if err := json.Unmarshal(detailJSON, &detailAny); err != nil {
		return contracts.Exercise{}, fmt.Errorf("re-parse detail: %w", err)
	}
	exercise.Detail = detailAny
	return exercise, nil
}

func estimatedDurationSec(exerciseType string) int {
	switch exerciseType {
	case "quizcard_basic":
		return 30
	case "matching":
		return 120
	case "fill_blank":
		return 60
	case "choice_word":
		return 45
	default:
		return 60
	}
}
