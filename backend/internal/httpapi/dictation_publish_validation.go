package httpapi

import (
	"fmt"
	"strings"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/processing"
)

const (
	dictationPublishMinSentences = 3
	dictationPublishMaxSentences = 8
	dictationPublishMaxRunes     = 250
)

func (s *Server) validateDictationPublish(exerciseID string, exercise contracts.Exercise) error {
	if exercise.ExerciseType != "psani_3_dictation" || strings.TrimSpace(exercise.Status) != "published" {
		return nil
	}
	detail, ok := processing.ExtractDictationDetail(exercise.Detail)
	if !ok {
		return fmt.Errorf("Dictation detail is required before publish.")
	}
	if strings.TrimSpace(detail.Topic) == "" {
		return fmt.Errorf("Dictation topic is required before publish.")
	}
	if len(detail.Sentences) < dictationPublishMinSentences || len(detail.Sentences) > dictationPublishMaxSentences {
		return fmt.Errorf("Dictation must have %d-%d sentences before publish.", dictationPublishMinSentences, dictationPublishMaxSentences)
	}
	mode := detail.Mode()
	if mode != contracts.DictationModeType && mode != contracts.DictationModeOCR && mode != contracts.DictationModeBoth {
		return fmt.Errorf("Dictation submission_mode is invalid.")
	}
	for i, sentence := range detail.Sentences {
		if strings.TrimSpace(sentence.Text) == "" {
			return fmt.Errorf("Dictation sentence %d is missing text.", i+1)
		}
		if len([]rune(strings.TrimSpace(sentence.Text))) > dictationPublishMaxRunes {
			return fmt.Errorf("Dictation sentence %d is too long.", i+1)
		}
		if s.dictationSentenceAudioKey(exerciseID, i, sentence) == "" {
			return fmt.Errorf("Dictation sentence %d is missing audio.", i+1)
		}
	}
	return nil
}

func (s *Server) dictationSentenceAudioKey(exerciseID string, fallbackIdx int, sentence contracts.DictationSentence) string {
	if key := strings.TrimSpace(sentence.AudioAssetID); key != "" {
		return key
	}
	if strings.TrimSpace(exerciseID) == "" {
		return ""
	}
	if audio, ok := s.repo.SentenceAudio(exerciseID, sentence.Idx); ok && strings.TrimSpace(audio.StorageKey) != "" {
		return audio.StorageKey
	}
	if sentence.Idx != fallbackIdx {
		if audio, ok := s.repo.SentenceAudio(exerciseID, fallbackIdx); ok && strings.TrimSpace(audio.StorageKey) != "" {
			return audio.StorageKey
		}
	}
	return ""
}
