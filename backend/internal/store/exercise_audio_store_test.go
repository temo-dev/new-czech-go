package store

import (
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

func TestExerciseAudioStore_SetAndGet(t *testing.T) {
	s := newMemoryExerciseAudioStore()

	audio := contracts.ExerciseAudio{
		ExerciseID: "ex-1",
		StorageKey: "audio/ex-1.mp3",
		MimeType:   "audio/mpeg",
		SourceType: "polly",
	}
	s.SetExerciseAudio("ex-1", audio)

	got, ok := s.ExerciseAudioByExercise("ex-1")
	if !ok {
		t.Fatal("expected audio to be found")
	}
	if got.StorageKey != "audio/ex-1.mp3" {
		t.Errorf("expected storage key, got %s", got.StorageKey)
	}
}

func TestExerciseAudioStore_GetMissing(t *testing.T) {
	s := newMemoryExerciseAudioStore()
	_, ok := s.ExerciseAudioByExercise("nonexistent")
	if ok {
		t.Fatal("expected not found")
	}
}
