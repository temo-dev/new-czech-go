package httpapi

import (
	"encoding/json"
	"fmt"
	"strconv"
	"strings"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

func (s *Server) validateObjectivePublish(exercise contracts.Exercise) error {
	if strings.TrimSpace(exercise.Status) != "published" {
		return nil
	}
	keys, label, objective, err := objectivePublishAnswerKeys(exercise.ExerciseType, exercise.Detail)
	if !objective || err != nil {
		return err
	}
	if len(keys) == 0 {
		return fmt.Errorf("%s requires at least 1 question before publish.", label)
	}
	answers, err := objectivePublishCorrectAnswers(exercise.Detail)
	if err != nil {
		return err
	}
	for _, key := range keys {
		if strings.TrimSpace(answers[key]) == "" {
			return fmt.Errorf("%s question %s is missing correct answer.", label, key)
		}
	}
	return nil
}

func objectivePublishCorrectAnswers(detail any) (map[string]string, error) {
	var out struct {
		CorrectAnswers map[string]string `json:"correct_answers"`
	}
	b, err := json.Marshal(detail)
	if err != nil {
		return nil, fmt.Errorf("Could not read exercise detail.")
	}
	if err := json.Unmarshal(b, &out); err != nil {
		return nil, fmt.Errorf("correct_answers must be a string map.")
	}
	if len(out.CorrectAnswers) == 0 {
		return nil, fmt.Errorf("correct_answers are required before publish.")
	}
	return out.CorrectAnswers, nil
}

func objectivePublishAnswerKeys(exerciseType string, detail any) ([]string, string, bool, error) {
	b, err := json.Marshal(detail)
	if err != nil {
		return nil, exerciseType, true, fmt.Errorf("Could not read exercise detail.")
	}

	switch exerciseType {
	case "cteni_1":
		var d struct {
			Items []struct {
				ItemNo int `json:"item_no"`
			} `json:"items"`
		}
		if err := json.Unmarshal(b, &d); err != nil {
			return nil, exerciseType, true, fmt.Errorf("Invalid cteni_1 detail.")
		}
		return keysFromRows(len(d.Items), func(i int) int { return d.Items[i].ItemNo }, 1), exerciseType, true, nil
	case "cteni_2":
		return questionKeysFromDetail(b, exerciseType, 6)
	case "cteni_3":
		var d struct {
			Texts []struct {
				ItemNo int `json:"item_no"`
			} `json:"texts"`
		}
		if err := json.Unmarshal(b, &d); err != nil {
			return nil, exerciseType, true, fmt.Errorf("Invalid cteni_3 detail.")
		}
		return keysFromRows(len(d.Texts), func(i int) int { return d.Texts[i].ItemNo }, 1), exerciseType, true, nil
	case "cteni_4":
		return questionKeysFromDetail(b, exerciseType, 15)
	case "cteni_5":
		return questionKeysFromDetail(b, exerciseType, 21)
	case "cteni_6", "poslech_6":
		var d struct {
			Statements []struct {
				QuestionNo int `json:"question_no"`
			} `json:"statements"`
		}
		if err := json.Unmarshal(b, &d); err != nil {
			return nil, exerciseType, true, fmt.Errorf("Invalid %s detail.", exerciseType)
		}
		return keysFromRows(len(d.Statements), func(i int) int { return d.Statements[i].QuestionNo }, 1), exerciseType, true, nil
	case "poslech_1", "poslech_2", "poslech_3", "poslech_4":
		var d struct {
			Items []struct {
				QuestionNo int `json:"question_no"`
			} `json:"items"`
		}
		if err := json.Unmarshal(b, &d); err != nil {
			return nil, exerciseType, true, fmt.Errorf("Invalid %s detail.", exerciseType)
		}
		return keysFromRows(len(d.Items), func(i int) int { return d.Items[i].QuestionNo }, 1), exerciseType, true, nil
	case "poslech_5":
		return questionKeysFromDetail(b, exerciseType, 21)
	default:
		return nil, exerciseType, false, nil
	}
}

func questionKeysFromDetail(b []byte, label string, fallbackStart int) ([]string, string, bool, error) {
	var d struct {
		Questions []struct {
			QuestionNo int `json:"question_no"`
		} `json:"questions"`
	}
	if err := json.Unmarshal(b, &d); err != nil {
		return nil, label, true, fmt.Errorf("Invalid %s detail.", label)
	}
	return keysFromRows(len(d.Questions), func(i int) int { return d.Questions[i].QuestionNo }, fallbackStart), label, true, nil
}

func keysFromRows(count int, questionNo func(int) int, fallbackStart int) []string {
	keys := make([]string, 0, count)
	for i := 0; i < count; i++ {
		n := questionNo(i)
		if n <= 0 {
			n = fallbackStart + i
		}
		keys = append(keys, strconv.Itoa(n))
	}
	return keys
}
