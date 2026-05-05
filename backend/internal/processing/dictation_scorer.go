package processing

import (
	"math"
	"regexp"
	"strings"

	"golang.org/x/text/unicode/norm"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// dictation_scorer.go — V18 deterministic scorer for psani_3_dictation.
//
// Pipeline:
//  1. NFC-compose (so decomposed `c + ̌` matches precomposed `č`)
//  2. lowercase
//  3. trim + collapse internal whitespace
//  4. weighted Levenshtein where:
//       - equal runes cost 0
//       - diacritic-pair runes cost 0.5 (e.g. c↔č, a↔á, u↔ů)
//       - any other substitution costs 1.0
//       - insertion / deletion cost 1.0
//
// Per-sentence accuracy = clamp(1 - distance / max(len(refNorm), 1), 0, 1).
// Overall score = round(mean(accuracies) × max_points).
// Passed       = overall_score ≥ ceil(max_points × pass_threshold_percent / 100).
//
// LLM annotation runs separately (see dictation_llm.go); failure does not
// block the deterministic score.

var collapseWhitespace = regexp.MustCompile(`\s+`)

// DictationSubmissionLimits caps body shape for psani_3_dictation submissions.
const (
	DictationMaxSentenceChars = 200
)

// ValidateDictationSubmission enforces shape rules for psani_3_dictation
// submissions. The exercise's authored sentence count must equal the number
// of submitted sentence answers, and every sentence text must be ≤
// DictationMaxSentenceChars runes after trimming. Empty learner answers are
// allowed (scored as 0); whitespace-only is treated as empty.
func ValidateDictationSubmission(detail contracts.DictationDetail, sub contracts.DictationSubmission) error {
	if len(detail.Sentences) == 0 {
		return errDictationDetailEmpty
	}
	if len(sub.Sentences) != len(detail.Sentences) {
		return errDictationSentenceCountMismatch
	}
	for _, ans := range sub.Sentences {
		if ans.Idx < 0 || ans.Idx >= len(detail.Sentences) {
			return errDictationSentenceCountMismatch
		}
		trimmed := strings.TrimSpace(ans.Text)
		if len([]rune(trimmed)) > DictationMaxSentenceChars {
			return errDictationSentenceTooLong
		}
	}
	return nil
}

// errDictationSentenceCountMismatch and friends are sentinel errors so the
// HTTP handler can pick a stable error code without string-matching the
// message. The handler maps these to 400 + a code; everything else stays 500.
var (
	errDictationDetailEmpty           = dictationValidationError("dictation_detail_empty")
	errDictationSentenceCountMismatch = dictationValidationError("invalid_sentence_count")
	errDictationSentenceTooLong       = dictationValidationError("sentence_too_long")
)

// DictationValidationError is the error type returned by
// ValidateDictationSubmission. It carries a stable `Code` for the HTTP layer
// while still satisfying the standard error interface.
type DictationValidationError struct{ Code string }

func (e DictationValidationError) Error() string { return e.Code }

func dictationValidationError(code string) DictationValidationError {
	return DictationValidationError{Code: code}
}

// diacriticPairs lists Czech base↔diacritic substitutions that score 0.5
// instead of 1.0. Pairs are stored as base→accented; lookups check both
// directions in subCost.
var diacriticPairs = map[rune]rune{
	'c': 'č',
	's': 'š',
	'z': 'ž',
	'e': 'ě',
	'r': 'ř',
	'n': 'ň',
	't': 'ť',
	'd': 'ď',
	'a': 'á',
	'i': 'í',
	'o': 'ó',
	'y': 'ý',
}

// extraPairs covers vowels with multiple diacritic forms (é vs ě, ú vs ů).
// Each entry maps a "near" rune to its base equivalent for cost-0.5 substitution.
var extraPairs = map[rune]rune{
	'é': 'e',
	'ě': 'e',
	'ú': 'u',
	'ů': 'u',
}

// normalizeForScoring brings a string into a canonical form for comparison.
// NFC composes combining-mark sequences so visually identical Czech text
// compares equal regardless of input method.
func normalizeForScoring(s string) string {
	s = norm.NFC.String(s)
	s = strings.ToLower(s)
	s = strings.TrimSpace(s)
	s = collapseWhitespace.ReplaceAllString(s, " ")
	return s
}

// subCost returns the substitution cost between two runes:
// 0 (equal), 0.5 (diacritic pair), or 1.0 (otherwise).
func subCost(a, b rune) float64 {
	if a == b {
		return 0
	}
	if accented, ok := diacriticPairs[a]; ok && accented == b {
		return 0.5
	}
	if accented, ok := diacriticPairs[b]; ok && accented == a {
		return 0.5
	}
	if base, ok := extraPairs[a]; ok && base == b {
		return 0.5
	}
	if base, ok := extraPairs[b]; ok && base == a {
		return 0.5
	}
	return 1.0
}

// dictationDistance is a weighted Levenshtein distance over rune slices.
// Insertions and deletions cost 1.0; substitutions use subCost.
func dictationDistance(a, b []rune) float64 {
	la, lb := len(a), len(b)
	if la == 0 {
		return float64(lb)
	}
	if lb == 0 {
		return float64(la)
	}
	prev := make([]float64, lb+1)
	curr := make([]float64, lb+1)
	for j := 0; j <= lb; j++ {
		prev[j] = float64(j)
	}
	for i := 1; i <= la; i++ {
		curr[0] = float64(i)
		for j := 1; j <= lb; j++ {
			subc := prev[j-1] + subCost(a[i-1], b[j-1])
			delc := prev[j] + 1.0
			insc := curr[j-1] + 1.0
			curr[j] = math.Min(subc, math.Min(delc, insc))
		}
		prev, curr = curr, prev
	}
	return prev[lb]
}

// SentenceAccuracy returns 0..1 accuracy for a single ref/learner pair.
// Both inputs are normalized first, then weighted-Levenshtein distance is
// divided by max(len(refNorm), 1) and subtracted from 1. Result is clamped
// to [0, 1] and is never NaN.
func SentenceAccuracy(ref, learner string) float64 {
	refN := []rune(normalizeForScoring(ref))
	lrnN := []rune(normalizeForScoring(learner))
	if len(refN) == 0 && len(lrnN) == 0 {
		return 1.0
	}
	if len(refN) == 0 {
		return 0
	}
	d := dictationDistance(refN, lrnN)
	maxLen := math.Max(float64(len(refN)), 1)
	acc := 1.0 - d/maxLen
	if acc < 0 || math.IsNaN(acc) {
		return 0
	}
	if acc > 1.0 {
		return 1.0
	}
	return acc
}

// ComputeDictationScore aggregates per-sentence accuracies into a feedback
// record. It always returns the same number of sentences as len(refs);
// missing learner answers are treated as empty strings.
//
// passThresholdPercent of 0 falls back to 60% (project default).
func ComputeDictationScore(refs []string, learners []string, maxPoints int, passThresholdPercent int) contracts.DictationFeedback {
	if passThresholdPercent <= 0 {
		passThresholdPercent = 60
	}
	if maxPoints <= 0 {
		maxPoints = 10
	}

	sentences := make([]contracts.DictationSentenceScore, 0, len(refs))
	if len(refs) == 0 {
		return contracts.DictationFeedback{
			MaxPoints:        maxPoints,
			PassThresholdPct: passThresholdPercent,
			Sentences:        sentences,
		}
	}

	var sum float64
	for i, ref := range refs {
		var learner string
		if i < len(learners) {
			learner = learners[i]
		}
		refN := []rune(normalizeForScoring(ref))
		lrnN := []rune(normalizeForScoring(learner))
		dist := dictationDistance(refN, lrnN)
		acc := SentenceAccuracy(ref, learner)
		sum += acc
		sentences = append(sentences, contracts.DictationSentenceScore{
			Idx:              i,
			Reference:        ref,
			Learner:          learner,
			Accuracy:         acc,
			DistanceWeighted: dist,
		})
	}

	avg := sum / float64(len(refs))
	overall := int(math.Round(avg * float64(maxPoints)))
	threshold := int(math.Ceil(float64(maxPoints) * float64(passThresholdPercent) / 100.0))

	return contracts.DictationFeedback{
		OverallScore:     overall,
		MaxPoints:        maxPoints,
		Passed:           overall >= threshold,
		PassThresholdPct: passThresholdPercent,
		Sentences:        sentences,
	}
}
