package processing

import (
	"fmt"
	"strconv"
	"strings"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// ValidateReadingDraft enforces the per-cteni-type structural rules from
// docs/specs/v24-doc-draft-generator.md §4. Returns nil when the draft
// matches the expected shape for its exercise_type.
//
// Each cteni type has its own validator; this function dispatches.
func ValidateReadingDraft(d *contracts.ReadingDraft) error {
	if d == nil {
		return fmt.Errorf("reading draft is nil")
	}
	switch d.ExerciseType {
	case "cteni_2":
		detail, ok := d.Detail.(contracts.Cteni2Detail)
		if !ok {
			return fmt.Errorf("cteni_2: expected Cteni2Detail, got %T", d.Detail)
		}
		return validateCteni2(detail)
	default:
		return fmt.Errorf("reading draft: unsupported exercise_type %q", d.ExerciseType)
	}
}

// ── cteni_2 ───────────────────────────────────────────────────────────────────

func validateCteni2(d contracts.Cteni2Detail) error {
	if strings.TrimSpace(d.Text) == "" {
		return fmt.Errorf("cteni_2: text must be non-empty")
	}
	if len(d.Questions) != 5 {
		return fmt.Errorf("cteni_2: expected 5 questions, got %d", len(d.Questions))
	}
	for i, q := range d.Questions {
		if len(q.Options) != 4 {
			return fmt.Errorf("cteni_2: question %d must have 4 options, got %d", i+1, len(q.Options))
		}
		seenKeys := map[string]bool{}
		for _, opt := range q.Options {
			if opt.Key != "A" && opt.Key != "B" && opt.Key != "C" && opt.Key != "D" {
				return fmt.Errorf("cteni_2: question %d option key must be A-D, got %q", i+1, opt.Key)
			}
			if seenKeys[opt.Key] {
				return fmt.Errorf("cteni_2: question %d has duplicate option key %q", i+1, opt.Key)
			}
			seenKeys[opt.Key] = true
			if strings.TrimSpace(opt.Text) == "" {
				return fmt.Errorf("cteni_2: question %d option %s has empty option text", i+1, opt.Key)
			}
		}
	}
	if err := requireCorrectAnswers(d.CorrectAnswers, len(d.Questions), "cteni_2", "A-D", []string{"A", "B", "C", "D"}); err != nil {
		return err
	}
	return nil
}

// ── shared helpers ────────────────────────────────────────────────────────────

// requireCorrectAnswers verifies the correct_answers map has exactly one entry
// per question_no (1..n) and each value is one of allowed.
func requireCorrectAnswers(answers map[string]string, questionCount int, label, allowedDescription string, allowed []string) error {
	allow := map[string]bool{}
	for _, v := range allowed {
		allow[v] = true
	}
	for i := 1; i <= questionCount; i++ {
		key := strconv.Itoa(i)
		v, ok := answers[key]
		if !ok {
			return fmt.Errorf("%s: missing correct_answer for question %d", label, i)
		}
		if !allow[v] {
			return fmt.Errorf("%s: correct_answer for question %d must be one of %s, got %q", label, i, allowedDescription, v)
		}
	}
	if len(answers) != questionCount {
		return fmt.Errorf("%s: correct_answers should cover %d questions, got %d entries", label, questionCount, len(answers))
	}
	return nil
}
