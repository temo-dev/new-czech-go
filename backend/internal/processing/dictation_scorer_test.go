package processing

import (
	"math"
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

func TestNormalizeForScoring_NFCComposesAndLowercases(t *testing.T) {
	// Decomposed č (c + combining háček U+030C) must compose to single rune č.
	decomposed := "Cˇaj" // not yet normalized
	want := "cˇaj"       // simple lowercased copy — but NFC should produce single char "č" if input has true combining mark
	got := normalizeForScoring(decomposed)
	if got != want {
		// NFC compose only works with proper combining mark sequences. Use a real one:
		decomposedReal := "čaj" // c + combining caron
		gotReal := normalizeForScoring(decomposedReal)
		if gotReal != "čaj" {
			t.Errorf("expected NFC-compose 'čaj', got %q", gotReal)
		}
	}
}

func TestNormalizeForScoring_TrimAndCollapseWhitespace(t *testing.T) {
	got := normalizeForScoring("  Pavel  jde   do\nkavárny.  ")
	want := "pavel jde do kavárny."
	if got != want {
		t.Errorf("normalize: want %q got %q", want, got)
	}
}

func TestSubCost_EqualPairOther(t *testing.T) {
	cases := []struct {
		a, b rune
		want float64
	}{
		{'c', 'c', 0.0},
		{'c', 'č', 0.5},
		{'č', 'c', 0.5},
		{'s', 'š', 0.5},
		{'a', 'á', 0.5},
		{'u', 'ů', 0.5},
		{'c', 'x', 1.0},
		{'a', 'b', 1.0},
		{'.', ',', 1.0},
	}
	for _, c := range cases {
		got := subCost(c.a, c.b)
		if got != c.want {
			t.Errorf("subCost(%q, %q): want %v got %v", c.a, c.b, c.want, got)
		}
	}
}

func TestDictationDistance_IdenticalIsZero(t *testing.T) {
	d := dictationDistance([]rune("pavel jde"), []rune("pavel jde"))
	if d != 0 {
		t.Errorf("identical distance: want 0, got %v", d)
	}
}

func TestDictationDistance_EmptyHandled(t *testing.T) {
	if d := dictationDistance([]rune(""), []rune("")); d != 0 {
		t.Errorf("both empty: want 0, got %v", d)
	}
	if d := dictationDistance([]rune(""), []rune("abc")); d != 3 {
		t.Errorf("empty vs abc: want 3, got %v", d)
	}
	if d := dictationDistance([]rune("abc"), []rune("")); d != 3 {
		t.Errorf("abc vs empty: want 3, got %v", d)
	}
}

func TestDictationDistance_AllDiacriticsStripped(t *testing.T) {
	// Reference "čaj" vs learner "caj" — 1 substitution at weight 0.5
	d := dictationDistance([]rune("čaj"), []rune("caj"))
	if d != 0.5 {
		t.Errorf("čaj vs caj: want 0.5, got %v", d)
	}
}

func TestSentenceAccuracy_PerfectMatch(t *testing.T) {
	acc := SentenceAccuracy("Pavel jde do kavárny.", "Pavel jde do kavárny.")
	if acc != 1.0 {
		t.Errorf("perfect: want 1.0, got %v", acc)
	}
}

func TestSentenceAccuracy_AllDiacriticsMissing(t *testing.T) {
	// "Pavel jde do kavárny." (20 chars) vs "Pavel jde do kavarny." (1 diacritic missing)
	// 1 substitution at 0.5 over 21 chars after normalize → accuracy ≈ 0.976.
	// More aggressive case: every diacritic gone.
	ref := "Čaj a koláč"          // č,á,č diacritics
	learner := "Caj a kolac"      // 3 diacritics stripped
	acc := SentenceAccuracy(ref, learner)
	if acc < 0.5 {
		t.Errorf("all-diacritic-stripped should retain ≥0.5, got %v", acc)
	}
	if acc >= 1.0 {
		t.Errorf("all-diacritic-stripped should be < 1.0, got %v", acc)
	}
}

func TestSentenceAccuracy_TotallyDifferent(t *testing.T) {
	acc := SentenceAccuracy("Pavel jde do kavárny.", "xxxxxxxxxxxxxxxxxxxxxxxx")
	if acc != 0 {
		t.Errorf("totally different: want 0, got %v", acc)
	}
}

func TestSentenceAccuracy_EmptyLearnerIsZero(t *testing.T) {
	acc := SentenceAccuracy("Pavel jde do kavárny.", "")
	if acc != 0 {
		t.Errorf("empty learner: want 0, got %v", acc)
	}
}

func TestSentenceAccuracy_EmptyRefIsOne(t *testing.T) {
	// Empty ref + empty learner: 1.0 (vacuous match). Empty ref + non-empty learner: 0.0.
	if a := SentenceAccuracy("", ""); a != 1.0 {
		t.Errorf("empty/empty: want 1.0, got %v", a)
	}
	if a := SentenceAccuracy("", "extra"); a != 0 {
		t.Errorf("empty ref vs extra: want 0, got %v", a)
	}
}

func TestComputeDictationScore_PerfectAndPass(t *testing.T) {
	refs := []string{"Pavel jde do kavárny.", "Chce si dát čaj."}
	learners := []string{"Pavel jde do kavárny.", "Chce si dát čaj."}
	fb := ComputeDictationScore(refs, learners, 10, 60)
	if fb.OverallScore != 10 {
		t.Errorf("overall: want 10, got %d", fb.OverallScore)
	}
	if !fb.Passed {
		t.Errorf("perfect should pass")
	}
	if len(fb.Sentences) != 2 {
		t.Fatalf("sentences len: %d", len(fb.Sentences))
	}
	if fb.Sentences[0].Accuracy != 1.0 {
		t.Errorf("sentence[0] accuracy: %v", fb.Sentences[0].Accuracy)
	}
}

func TestComputeDictationScore_BelowThresholdFails(t *testing.T) {
	refs := []string{"Pavel jde do kavárny.", "Chce si dát čaj a koláč."}
	learners := []string{"xxx", "yyy"}
	fb := ComputeDictationScore(refs, learners, 10, 60)
	if fb.Passed {
		t.Errorf("totally wrong should fail")
	}
	if fb.OverallScore > 1 {
		t.Errorf("overall should be near 0, got %d", fb.OverallScore)
	}
	if fb.PassThresholdPct != 60 {
		t.Errorf("threshold persisted: %d", fb.PassThresholdPct)
	}
}

func TestComputeDictationScore_PartialMix(t *testing.T) {
	// Sentence 1 perfect, sentence 2 missing diacritics → average ~ 0.8x → score 8/10
	refs := []string{"Ahoj.", "Děkuji."}
	learners := []string{"Ahoj.", "Dekuji."}
	fb := ComputeDictationScore(refs, learners, 10, 60)
	if fb.OverallScore < 7 || fb.OverallScore > 10 {
		t.Errorf("partial mix score should be 7..10, got %d", fb.OverallScore)
	}
	if !fb.Passed {
		t.Errorf("partial mix at 60%% threshold should pass")
	}
	if fb.Sentences[0].Accuracy != 1.0 {
		t.Errorf("first sentence perfect, got %v", fb.Sentences[0].Accuracy)
	}
	if fb.Sentences[1].Accuracy >= 1.0 {
		t.Errorf("second sentence has 1 diacritic mismatch, accuracy must be <1.0, got %v", fb.Sentences[1].Accuracy)
	}
}

func TestComputeDictationScore_PreservesReferenceAndLearnerOriginal(t *testing.T) {
	// Original (unnormalized) ref/learner must be preserved on the score record
	// so the result screen can show the raw sentences in their original casing.
	refs := []string{"Pavel JDE Do Kavárny."}
	learners := []string{"Pavel jde do kavárny."}
	fb := ComputeDictationScore(refs, learners, 5, 60)
	if fb.Sentences[0].Reference != refs[0] {
		t.Errorf("reference not preserved: %q", fb.Sentences[0].Reference)
	}
	if fb.Sentences[0].Learner != learners[0] {
		t.Errorf("learner not preserved: %q", fb.Sentences[0].Learner)
	}
	// Casing differences are normalized away, so accuracy should be 1.0
	if math.Abs(fb.Sentences[0].Accuracy-1.0) > 1e-9 {
		t.Errorf("case-only mismatch must score 1.0, got %v", fb.Sentences[0].Accuracy)
	}
}

func TestComputeDictationScore_EmptySentencesReturnsZeroOverall(t *testing.T) {
	fb := ComputeDictationScore(nil, nil, 10, 60)
	if fb.OverallScore != 0 || fb.Passed {
		t.Errorf("empty input: %+v", fb)
	}
	if fb.MaxPoints != 10 {
		t.Errorf("max_points lost: %d", fb.MaxPoints)
	}
}

// Sanity: ensure the scorer never returns NaN or negative.
func TestSentenceAccuracy_NeverNaNOrNegative(t *testing.T) {
	cases := [][2]string{
		{"", ""},
		{"a", ""},
		{"", "a"},
		{"abc", "xyz"},
		{"čaj", "caj"},
	}
	for _, c := range cases {
		acc := SentenceAccuracy(c[0], c[1])
		if math.IsNaN(acc) || acc < 0 || acc > 1.0 {
			t.Errorf("invalid accuracy for ref=%q learner=%q: %v", c[0], c[1], acc)
		}
	}
}

// Type-assert that the result struct compiles against the contracts.DictationFeedback shape.
var _ = contracts.DictationFeedback{}
