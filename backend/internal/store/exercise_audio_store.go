package store

import (
	"sync"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// ExerciseAudioStore persists generated/uploaded audio metadata per exercise.
type ExerciseAudioStore interface {
	ExerciseAudioByExercise(exerciseID string) (*contracts.ExerciseAudio, bool)
	SetExerciseAudio(exerciseID string, audio contracts.ExerciseAudio)
}

// ── Memory implementation ─────────────────────────────────────────────────────

type memoryExerciseAudioStore struct {
	mu    sync.RWMutex
	items map[string]contracts.ExerciseAudio
}

func newMemoryExerciseAudioStore() ExerciseAudioStore {
	return &memoryExerciseAudioStore{items: map[string]contracts.ExerciseAudio{}}
}

func (s *memoryExerciseAudioStore) ExerciseAudioByExercise(exerciseID string) (*contracts.ExerciseAudio, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	a, ok := s.items[exerciseID]
	if !ok {
		return nil, false
	}
	cp := a
	return &cp, true
}

func (s *memoryExerciseAudioStore) SetExerciseAudio(exerciseID string, audio contracts.ExerciseAudio) {
	s.mu.Lock()
	defer s.mu.Unlock()
	audio.ExerciseID = exerciseID
	s.items[exerciseID] = audio
}
