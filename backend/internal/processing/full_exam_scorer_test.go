package processing

import (
	"testing"
)

func TestIsPisemnaPassed(t *testing.T) {
	cases := []struct {
		score int
		want  bool
	}{
		{42, true},  // boundary pass
		{43, true},
		{70, true},  // max
		{41, false}, // boundary fail
		{0, false},
	}
	for _, c := range cases {
		got := IsPisemnaPassed(c.score)
		if got != c.want {
			t.Errorf("IsPisemnaPassed(%d) = %v, want %v", c.score, got, c.want)
		}
	}
}

func TestIsUstniPassed(t *testing.T) {
	cases := []struct {
		score int
		want  bool
	}{
		{24, true},  // boundary pass
		{40, true},  // max
		{23, false}, // boundary fail
		{0, false},
	}
	for _, c := range cases {
		got := IsUstniPassed(c.score)
		if got != c.want {
			t.Errorf("IsUstniPassed(%d) = %v, want %v", c.score, got, c.want)
		}
	}
}

func TestIsFullExamPassed(t *testing.T) {
	if !IsFullExamPassed(true, true) {
		t.Error("expected pass when both passed")
	}
	if IsFullExamPassed(true, false) {
		t.Error("expected fail when ustni failed")
	}
	if IsFullExamPassed(false, true) {
		t.Error("expected fail when pisemna failed")
	}
	if IsFullExamPassed(false, false) {
		t.Error("expected fail when both failed")
	}
}

func TestComputePisemnaScore_FromAttempts(t *testing.T) {
	// Simulate 3 scored attempts (cteni=20, psani=15, poslech=18)
	scores := []int{20, 15, 18}
	got := SumPisemnaScores(scores)
	if got != 53 {
		t.Errorf("SumPisemnaScores = %d, want 53", got)
	}
}

func TestPisemnaMaxPoints(t *testing.T) {
	// cteni=25, psani=20, poslech=25 → 70 total
	if PisemnaMaxPoints != 70 {
		t.Errorf("PisemnaMaxPoints = %d, want 70", PisemnaMaxPoints)
	}
}

func TestUstniMaxPoints(t *testing.T) {
	if UstniMaxPoints != 40 {
		t.Errorf("UstniMaxPoints = %d, want 40", UstniMaxPoints)
	}
}
