package store

import (
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

func TestExerciseSentenceAudioStore_SetAndGet(t *testing.T) {
	s := newMemoryExerciseSentenceAudioStore()

	for idx := 0; idx < 3; idx++ {
		s.SetSentenceAudio("ex-1", idx, contracts.ExerciseAudio{
			StorageKey: storageKeyForIdx("ex-1", idx),
			MimeType:   "audio/mpeg",
			SourceType: "polly",
		})
	}

	got, ok := s.SentenceAudio("ex-1", 1)
	if !ok {
		t.Fatal("expected sentence 1 to be found")
	}
	if got.StorageKey != "audio/ex-1/s-1.mp3" {
		t.Errorf("storage key: %s", got.StorageKey)
	}
}

func TestExerciseSentenceAudioStore_ListByExercise(t *testing.T) {
	s := newMemoryExerciseSentenceAudioStore()
	s.SetSentenceAudio("ex-1", 0, contracts.ExerciseAudio{StorageKey: "k0", MimeType: "audio/mpeg"})
	s.SetSentenceAudio("ex-1", 1, contracts.ExerciseAudio{StorageKey: "k1", MimeType: "audio/mpeg"})
	s.SetSentenceAudio("ex-2", 0, contracts.ExerciseAudio{StorageKey: "k2", MimeType: "audio/mpeg"})

	got := s.SentenceAudiosByExercise("ex-1")
	if len(got) != 2 {
		t.Fatalf("expected 2 rows for ex-1, got %d", len(got))
	}
	// Must be ordered by idx ascending
	if got[0].SentenceIdx != 0 || got[1].SentenceIdx != 1 {
		t.Errorf("rows not sorted by idx: %+v", got)
	}
}

func TestExerciseSentenceAudioStore_Delete(t *testing.T) {
	s := newMemoryExerciseSentenceAudioStore()
	s.SetSentenceAudio("ex-1", 0, contracts.ExerciseAudio{StorageKey: "k", MimeType: "audio/mpeg"})

	if err := s.DeleteSentenceAudio("ex-1", 0); err != nil {
		t.Fatalf("delete: %v", err)
	}
	if _, ok := s.SentenceAudio("ex-1", 0); ok {
		t.Errorf("expected gone after delete")
	}
	// Delete missing must be a no-op (no error).
	if err := s.DeleteSentenceAudio("ex-1", 0); err != nil {
		t.Errorf("delete missing should not error: %v", err)
	}
}

func TestExerciseSentenceAudioStore_Upsert(t *testing.T) {
	s := newMemoryExerciseSentenceAudioStore()
	s.SetSentenceAudio("ex-1", 0, contracts.ExerciseAudio{StorageKey: "first", MimeType: "audio/mpeg"})
	s.SetSentenceAudio("ex-1", 0, contracts.ExerciseAudio{StorageKey: "second", MimeType: "audio/mpeg"})
	got, _ := s.SentenceAudio("ex-1", 0)
	if got.StorageKey != "second" {
		t.Errorf("upsert failed: %s", got.StorageKey)
	}
	rows := s.SentenceAudiosByExercise("ex-1")
	if len(rows) != 1 {
		t.Errorf("upsert should not duplicate rows: got %d", len(rows))
	}
}

func TestExerciseSentenceAudioStore_GetMissing(t *testing.T) {
	s := newMemoryExerciseSentenceAudioStore()
	if _, ok := s.SentenceAudio("nope", 0); ok {
		t.Errorf("expected not found")
	}
}

func storageKeyForIdx(exerciseID string, idx int) string {
	return "audio/" + exerciseID + "/s-" + itoaSimple(idx) + ".mp3"
}

func itoaSimple(i int) string {
	if i == 0 {
		return "0"
	}
	return string(rune('0' + i))
}
