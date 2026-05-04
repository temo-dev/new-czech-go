package processing

import "testing"

func TestDerivePromptForLearner(t *testing.T) {
	tests := []struct {
		name   string
		input  string
		expect string
	}{
		{
			name:   "empty input returns empty",
			input:  "",
			expect: "",
		},
		{
			name: "ukol block extracted",
			input: `You are an examiner for Czech A2 oral exam.

ÚKOL:
Mô tả công việc bạn muốn làm ở Cộng hòa Séc.

Speak naturally and ask follow-up questions.`,
			expect: "Mô tả công việc bạn muốn làm ở Cộng hòa Séc.",
		},
		{
			name: "TASK block extracted (English)",
			input: `Act as a Czech examiner.

TASK:
Describe your daily routine in Czech.

Be supportive but rigorous.`,
			expect: "Describe your daily routine in Czech.",
		},
		{
			name: "Đề bài block extracted (Vietnamese)",
			input: `Bạn là giám khảo kỳ thi A2.

Đề bài:
Hãy mô tả gia đình của bạn.

Hỏi thêm 2-3 câu chi tiết.`,
			expect: "Hãy mô tả gia đình của bạn.",
		},
		{
			name:   "instruction prefix stripped without task block",
			input:  "You are an examiner. Tell me about your hobbies in Czech.",
			expect: "Tell me about your hobbies in Czech.",
		},
		{
			name:   "Bạn là prefix stripped",
			input:  "Bạn là giám khảo. Hỏi học viên về công việc.",
			expect: "Hỏi học viên về công việc.",
		},
		{
			name: "selected_option placeholder stripped",
			input: `You are an examiner.

ÚKOL:
Vysvětlete proč jste si vybral {selected_option} jako povolání.

Ask follow-ups.`,
			expect: "Vysvětlete proč jste si vybral  jako povolání.",
		},
		{
			name: "multi-paragraph fallback returns first paragraph",
			input: `You are an examiner. Discuss work topics.

This is the second paragraph that should be ignored.`,
			expect: "Discuss work topics.",
		},
		{
			name:   "whitespace only returns empty",
			input:  "   \n\n  \t  ",
			expect: "",
		},
		{
			name: "ukol block with leading whitespace",
			input: `Act as examiner.

   ÚKOL:
   Describe your job.

End.`,
			expect: "Describe your job.",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := DerivePromptForLearner(tc.input)
			if got != tc.expect {
				t.Errorf("DerivePromptForLearner() = %q, want %q", got, tc.expect)
			}
		})
	}
}

func TestCleanPromptText(t *testing.T) {
	tests := []struct {
		name   string
		input  string
		expect string
	}{
		{name: "trim spaces", input: "  hello  ", expect: "hello"},
		{name: "strip placeholder", input: "vyberte {selected_option} prosím", expect: "vyberte  prosím"},
		{name: "multi placeholder", input: "{selected_option} a {selected_option}", expect: "a"},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := cleanPromptText(tc.input)
			if got != tc.expect {
				t.Errorf("cleanPromptText() = %q, want %q", got, tc.expect)
			}
		})
	}
}
