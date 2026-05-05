package processing

// llm_fallbacks.go — Rule-based fallback feedback when the LLM provider is
// unavailable or fails. All copy is currently Vietnamese (matches the default
// learner locale); change here to localize.

import "github.com/danieldev/czech-go-system/backend/internal/contracts"

// writingFallbackFeedback returns minimal rule-based feedback for writing
// attempts when the LLM is unavailable.
func writingFallbackFeedback() contracts.AttemptFeedback {
	return contracts.AttemptFeedback{
		ReadinessLevel:  "ok",
		OverallSummary:  "Bài viết đã được ghi nhận. Phản hồi chi tiết sẽ có khi AI sẵn sàng.",
		Strengths:       []string{"Bạn đã hoàn thành bài viết"},
		Improvements:    []string{"Hãy kiểm tra lại ngữ pháp và từ vựng"},
		TaskCompletion:  contracts.TaskCompletion{ScoreBand: "ok"},
		GrammarFeedback: contracts.GrammarFeedback{ScoreBand: "ok"},
		RetryAdvice:     []string{"Thử lại với câu văn đầy đủ và rõ ràng hơn"},
	}
}

// interviewFallbackFeedback returns minimal rule-based feedback for interview
// sessions when the LLM is unavailable.
func interviewFallbackFeedback() contracts.AttemptFeedback {
	return contracts.AttemptFeedback{
		ReadinessLevel:  "ok",
		OverallSummary:  "Phiên phỏng vấn đã được ghi nhận. Phản hồi chi tiết sẽ có khi AI sẵn sàng.",
		Strengths:       []string{"Bạn đã hoàn thành buổi luyện tập"},
		Improvements:    []string{"Hãy luyện thêm câu trả lời đầy đủ và chi tiết"},
		RetryAdvice:     []string{"Thử lại với câu văn hoàn chỉnh hơn"},
		TaskCompletion:  contracts.TaskCompletion{ScoreBand: "ok"},
		GrammarFeedback: contracts.GrammarFeedback{ScoreBand: "ok"},
	}
}
