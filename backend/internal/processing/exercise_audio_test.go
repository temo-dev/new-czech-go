package processing

import (
	"os"
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

func TestBuildExerciseAudioText_Poslech5_Voicemail(t *testing.T) {
	exercise := contracts.Exercise{
		ExerciseType: "poslech_5",
		Detail: contracts.Poslech5Detail{
			AudioSource: contracts.ListeningAudioSource{
				Segments: []contracts.AudioSegment{
					{Speaker: "", Text: "Ahoj Lído, tady Eva."},
					{Speaker: "", Text: "Dostala jsem lístky na balet."},
				},
			},
		},
	}
	got := BuildExerciseAudioText(exercise)
	want := "Ahoj Lído, tady Eva. Dostala jsem lístky na balet."
	if got != want {
		t.Errorf("BuildExerciseAudioText = %q, want %q", got, want)
	}
}

func TestBuildExerciseAudioText_Poslech1_Items(t *testing.T) {
	exercise := contracts.Exercise{
		ExerciseType: "poslech_1",
		Detail: contracts.Poslech1Detail{
			Items: []contracts.ListeningItem{
				{
					QuestionNo: 1,
					AudioSource: contracts.ListeningAudioSource{
						Segments: []contracts.AudioSegment{
							{Text: "Kde je nádraží?"},
						},
					},
				},
				{
					QuestionNo: 2,
					AudioSource: contracts.ListeningAudioSource{
						Segments: []contracts.AudioSegment{
							{Text: "Jak se jmenujete?"},
						},
					},
				},
			},
		},
	}
	got := BuildExerciseAudioText(exercise)
	// Items joined with pause marker
	if got == "" {
		t.Fatal("expected non-empty audio text for poslech_1")
	}
	if got != "Kde je nádraží? Jak se jmenujete?" {
		t.Errorf("BuildExerciseAudioText = %q", got)
	}
}

func TestBuildExerciseAudioText_Poslech4_Dialog(t *testing.T) {
	exercise := contracts.Exercise{
		ExerciseType: "poslech_4",
		Detail: contracts.Poslech4Detail{
			Items: []contracts.DialogItem{
				{
					QuestionNo: 1,
					AudioSource: contracts.ListeningAudioSource{
						Segments: []contracts.AudioSegment{
							{Speaker: "A", Text: "Dobrý den."},
							{Speaker: "B", Text: "Dobrý den, jak vám mohu pomoci?"},
						},
					},
				},
			},
		},
	}
	got := BuildExerciseAudioText(exercise)
	if got == "" {
		t.Fatal("expected non-empty audio text for poslech_4 dialog")
	}
}

func TestBuildExerciseAudioText_AssetOnly_Empty(t *testing.T) {
	// When audio source is an uploaded asset (not text segments), return empty —
	// no Polly generation needed.
	exercise := contracts.Exercise{
		ExerciseType: "poslech_5",
		Detail: contracts.Poslech5Detail{
			AudioSource: contracts.ListeningAudioSource{
				AssetID: "some-uploaded-asset-id",
			},
		},
	}
	got := BuildExerciseAudioText(exercise)
	if got != "" {
		t.Errorf("expected empty text for asset-based source, got %q", got)
	}
}

func TestBuildExerciseAudioText_NonListening_Empty(t *testing.T) {
	exercise := contracts.Exercise{ExerciseType: "psani_1_formular"}
	if got := BuildExerciseAudioText(exercise); got != "" {
		t.Errorf("expected empty for non-listening type, got %q", got)
	}
}

func TestDevExerciseAudioGenerator_WritesFile(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("LOCAL_ASSETS_DIR", dir)
	gen := DevExerciseAudioGenerator{}
	audio, err := gen.GenerateAudio("test-exercise-123", "ignored text")
	if err != nil {
		t.Fatalf("GenerateAudio error: %v", err)
	}
	if audio.StorageKey == "" {
		t.Fatal("expected non-empty storage key")
	}
	if audio.MimeType == "" {
		t.Fatal("expected non-empty mime type")
	}
	filePath := localExerciseAudioPath(audio.StorageKey)
	info, statErr := os.Stat(filePath)
	if statErr != nil {
		t.Fatalf("expected file at %s: %v", filePath, statErr)
	}
	if info.Size() == 0 {
		t.Fatal("expected non-empty stub audio file")
	}
}
