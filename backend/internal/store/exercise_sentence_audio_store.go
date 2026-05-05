package store

import (
	"sort"
	"sync"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// ExerciseSentenceAudioStore persists per-sentence audio metadata for V18
// dictation exercises. Each (exercise_id, sentence_idx) pair owns one row.
//
// Why a separate store from ExerciseAudioStore: existing single-row audio
// (poslech, writing model_answer) keeps its (exercise_id) primary key and
// is unaffected by V18.
type ExerciseSentenceAudioStore interface {
	SentenceAudio(exerciseID string, sentenceIdx int) (*contracts.ExerciseSentenceAudio, bool)
	SentenceAudiosByExercise(exerciseID string) []contracts.ExerciseSentenceAudio
	SetSentenceAudio(exerciseID string, sentenceIdx int, audio contracts.ExerciseAudio)
	DeleteSentenceAudio(exerciseID string, sentenceIdx int) error
}

// ── Memory implementation ─────────────────────────────────────────────────────

type memorySentenceKey struct {
	exerciseID  string
	sentenceIdx int
}

type memoryExerciseSentenceAudioStore struct {
	mu    sync.RWMutex
	items map[memorySentenceKey]contracts.ExerciseSentenceAudio
}

func newMemoryExerciseSentenceAudioStore() ExerciseSentenceAudioStore {
	return &memoryExerciseSentenceAudioStore{items: map[memorySentenceKey]contracts.ExerciseSentenceAudio{}}
}

func (s *memoryExerciseSentenceAudioStore) SentenceAudio(exerciseID string, sentenceIdx int) (*contracts.ExerciseSentenceAudio, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	a, ok := s.items[memorySentenceKey{exerciseID, sentenceIdx}]
	if !ok {
		return nil, false
	}
	cp := a
	return &cp, true
}

func (s *memoryExerciseSentenceAudioStore) SentenceAudiosByExercise(exerciseID string) []contracts.ExerciseSentenceAudio {
	s.mu.RLock()
	defer s.mu.RUnlock()
	var rows []contracts.ExerciseSentenceAudio
	for k, v := range s.items {
		if k.exerciseID == exerciseID {
			rows = append(rows, v)
		}
	}
	sort.Slice(rows, func(i, j int) bool { return rows[i].SentenceIdx < rows[j].SentenceIdx })
	return rows
}

func (s *memoryExerciseSentenceAudioStore) SetSentenceAudio(exerciseID string, sentenceIdx int, audio contracts.ExerciseAudio) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.items[memorySentenceKey{exerciseID, sentenceIdx}] = contracts.ExerciseSentenceAudio{
		ExerciseID:  exerciseID,
		SentenceIdx: sentenceIdx,
		StorageKey:  audio.StorageKey,
		MimeType:    audio.MimeType,
		SourceType:  audio.SourceType,
		GeneratedAt: audio.GeneratedAt,
	}
}

func (s *memoryExerciseSentenceAudioStore) DeleteSentenceAudio(exerciseID string, sentenceIdx int) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.items, memorySentenceKey{exerciseID, sentenceIdx})
	return nil
}
