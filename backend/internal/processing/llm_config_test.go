package processing

import (
	"testing"
)

func TestLoadLLMModels_ReadingDraftDefaultsToBuiltIn(t *testing.T) {
	t.Setenv("LLM_READING_DRAFT_MODEL", "")

	models := LoadLLMModels()

	if models.ReadingDraft != DefaultReadingDraftModel {
		t.Fatalf("ReadingDraft default = %q, want %q", models.ReadingDraft, DefaultReadingDraftModel)
	}
}

func TestLoadLLMModels_ReadingDraftHonoursEnv(t *testing.T) {
	t.Setenv("LLM_READING_DRAFT_MODEL", "claude-sonnet-4-6")

	models := LoadLLMModels()

	if models.ReadingDraft != "claude-sonnet-4-6" {
		t.Fatalf("ReadingDraft env = %q, want claude-sonnet-4-6", models.ReadingDraft)
	}
}
