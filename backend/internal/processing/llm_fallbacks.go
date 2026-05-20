package processing

// llm_fallbacks.go — Rule-based fallback feedback when the LLM provider is
// unavailable or fails. All copy is currently Vietnamese (matches the default
// learner locale); change here to localize.

import "github.com/danieldev/czech-go-system/backend/internal/contracts"

func vocabularyQuizcardFallbackExplanation(term, meaning, lang string) string {
	switch lang {
	case "en":
		return term + " means " + meaning + "."
	case "cs":
		return term + " znamená " + meaning + "."
	default:
		return term + " nghĩa là " + meaning + "."
	}
}

func grammarFormFallbackExplanation(cue, form string) string {
	return "Dạng đúng cho " + cue + " là " + form + "."
}

func grammarMatchingFallbackExplanation(title string) string {
	if title == "" {
		return "Ghép từng ngữ cảnh với dạng ngữ pháp đúng."
	}
	return "Ghép từng ngữ cảnh với dạng đúng của quy tắc " + title + "."
}

// writingFallbackFeedback returns minimal rule-based feedback for writing
// attempts when the LLM is unavailable.
func writingFallbackFeedback() contracts.AttemptFeedback {
	return contracts.AttemptFeedback{
		ReadinessLevel:  "needs_work",
		OverallSummary:  "Bài viết đã được ghi nhận. Phản hồi chi tiết sẽ có khi AI sẵn sàng.",
		Strengths:       []string{"Bạn đã hoàn thành bài viết"},
		Improvements:    []string{"Hãy kiểm tra lại ngữ pháp và từ vựng"},
		TaskCompletion:  contracts.TaskCompletion{ScoreBand: "ok"},
		GrammarFeedback: contracts.GrammarFeedback{ScoreBand: "ok"},
		RetryAdvice:     []string{"Thử lại với câu văn đầy đủ và rõ ràng hơn"},
	}
}

// dictationFallbackFeedback returns a short Vietnamese sentence used per-sentence
// when the LLM annotator is unavailable. Tone is encouraging and acknowledges
// the deterministic accuracy without quoting an exact percentage.
func dictationFallbackFeedback(idx int, accuracy float64) string {
	switch {
	case accuracy >= 0.95:
		return "Tuyệt vời! Bạn viết câu này rất chuẩn."
	case accuracy >= 0.75:
		return "Khá tốt — chỉ cần kiểm tra lại dấu phụ và chính tả."
	case accuracy >= 0.4:
		return "Bạn nghe được phần lớn nội dung, hãy luyện thêm dấu và viết hoa."
	default:
		return "Câu này còn khó với bạn. Hãy nghe lại và viết theo trí nhớ."
	}
}

// interviewFallbackFeedback returns minimal rule-based feedback for interview
// sessions when the LLM is unavailable.
func interviewFallbackFeedback() contracts.AttemptFeedback {
	return contracts.AttemptFeedback{
		ReadinessLevel:  "needs_work",
		OverallSummary:  "Phiên phỏng vấn đã được ghi nhận. Phản hồi chi tiết sẽ có khi AI sẵn sàng.",
		Strengths:       []string{"Bạn đã hoàn thành buổi luyện tập"},
		Improvements:    []string{"Hãy luyện thêm câu trả lời đầy đủ và chi tiết"},
		RetryAdvice:     []string{"Thử lại với câu văn hoàn chỉnh hơn"},
		TaskCompletion:  contracts.TaskCompletion{ScoreBand: "ok"},
		GrammarFeedback: contracts.GrammarFeedback{ScoreBand: "ok"},
	}
}
