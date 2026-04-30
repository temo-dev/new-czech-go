package store

import "github.com/danieldev/czech-go-system/backend/internal/contracts"

// SkillStore is removed — skills table is dropped.
// Use SkillSummariesByModule on ExerciseStore for computed skill aggregates.

// skillKindLabel returns a Vietnamese display label for a skill kind.
func skillKindLabel(kind string) string {
	switch kind {
	case "noi":
		return "Kỹ năng nói"
	case "nghe":
		return "Kỹ năng nghe"
	case "doc":
		return "Kỹ năng đọc"
	case "viet":
		return "Kỹ năng viết"
	case "tu_vung":
		return "Từ vựng"
	case "ngu_phap":
		return "Ngữ pháp"
	default:
		return kind
	}
}

// SkillSummaryStore computes skill aggregates from exercises.
type SkillSummaryStore interface {
	SkillSummariesByModule(moduleID string) []contracts.SkillSummary
}
