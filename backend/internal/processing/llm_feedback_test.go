package processing

import "testing"

func TestNormalizeReadinessLevel_NewVocab(t *testing.T) {
	cases := []struct {
		in, want string
	}{
		// New 4-band tokens pass through.
		{"not_ready", "not_ready"},
		{"needs_work", "needs_work"},
		{"almost_ready", "almost_ready"},
		{"ready_for_mock", "ready_for_mock"},

		// Legacy LLM exam_ready collapses into ready_for_mock.
		{"exam_ready", "ready_for_mock"},

		// Legacy objective tokens map to the new vocab.
		{"weak", "not_ready"},
		{"ok", "needs_work"},
		{"strong", "ready_for_mock"},

		// Whitespace + casing tolerated.
		{"  Not_Ready  ", "not_ready"},
		{"NEEDS_WORK", "needs_work"},

		// Empty / unknown defaults to needs_work (was almost_ready).
		{"", "needs_work"},
		{"garbage", "needs_work"},
	}
	for _, c := range cases {
		got := normalizeReadinessLevel(c.in)
		if got != c.want {
			t.Errorf("normalizeReadinessLevel(%q) = %q, want %q", c.in, got, c.want)
		}
	}
}

func TestReadinessToScore(t *testing.T) {
	cases := []struct {
		in   string
		want float64
	}{
		{"not_ready", 0.20},
		{"needs_work", 0.45},
		{"almost_ready", 0.70},
		{"ready_for_mock", 0.90},

		// Anything else falls back to the safe middle-low default 0.40.
		{"", 0.40},
		{"exam_ready", 0.40},
		{"garbage", 0.40},
	}
	for _, c := range cases {
		got := ReadinessToScore(c.in)
		if got != c.want {
			t.Errorf("ReadinessToScore(%q) = %v, want %v", c.in, got, c.want)
		}
	}
}
