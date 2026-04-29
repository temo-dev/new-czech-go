package processing

import (
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

func TestBuildExerciseDialogTexts_Poslech4(t *testing.T) {
	detail := contracts.Poslech4Detail{
		Items: []contracts.DialogItem{
			{QuestionNo: 1, AudioSource: contracts.ListeningAudioSource{
				Segments: []contracts.AudioSegment{{Text: "Ahoj, jak se máš?"}},
			}},
			{QuestionNo: 2, AudioSource: contracts.ListeningAudioSource{
				Segments: []contracts.AudioSegment{{Text: "Dobře, díky."}},
			}},
			{QuestionNo: 3, AudioSource: contracts.ListeningAudioSource{
				AssetID: "uploaded-asset", // should be skipped
			}},
		},
	}
	ex := contracts.Exercise{ExerciseType: "poslech_4", Detail: detail}
	texts := BuildExerciseDialogTexts(ex)

	if len(texts) != 2 { // item 3 skipped (uploaded)
		t.Fatalf("expected 2 dialog texts, got %d", len(texts))
	}
	if texts[0] != "Ahoj, jak se máš?" {
		t.Errorf("item 1 wrong: %q", texts[0])
	}
	if texts[1] != "Dobře, díky." {
		t.Errorf("item 2 wrong: %q", texts[1])
	}
}

func TestBuildExerciseDialogTexts_NonPoslech4(t *testing.T) {
	ex := contracts.Exercise{ExerciseType: "poslech_1"}
	texts := BuildExerciseDialogTexts(ex)
	if texts != nil {
		t.Errorf("expected nil for non-poslech_4, got %v", texts)
	}
}

func TestAlternateMp3_Concatenation(t *testing.T) {
	// Simple concat of 2 byte slices should produce joined result.
	a := []byte{0x49, 0x44, 0x33} // fake ID3 header
	b := []byte{0xFF, 0xFB}       // fake MP3 frame sync
	result := concatMP3([][]byte{a, b})
	if len(result) != 5 {
		t.Errorf("expected 5 bytes, got %d", len(result))
	}
}
