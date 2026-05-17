package processing

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// fileWritingMockTTS is a TTSProvider used by per-item / per-sentence audio
// tests. Generate records every call AND pre-writes a fake mp3 at the review
// path so the calling generator can ReadFile the blob.
type fileWritingMockTTS struct {
	calls   []mockTTSCall
	failOn  string // if attemptID contains this substring, return error
	failErr error
}

type mockTTSCall struct {
	AttemptID string
	Text      string
}

func (m *fileWritingMockTTS) Generate(attemptID, text string) (*contracts.ReviewArtifactAudio, error) {
	m.calls = append(m.calls, mockTTSCall{AttemptID: attemptID, Text: text})
	if m.failOn != "" && strings.Contains(attemptID, m.failOn) {
		return nil, m.failErr
	}
	storageKey := fmt.Sprintf("review/%s.mp3", attemptID)
	path := localReviewAudioPath(storageKey)
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return nil, err
	}
	if err := os.WriteFile(path, []byte("fake-mp3-"+attemptID), 0o644); err != nil {
		return nil, err
	}
	return &contracts.ReviewArtifactAudio{StorageKey: storageKey, MimeType: "audio/mpeg"}, nil
}

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

func TestHasMultipleSpeakers_Dialog(t *testing.T) {
	exercise := contracts.Exercise{
		ExerciseType: "poslech_1",
		Detail: contracts.Poslech1Detail{
			Items: []contracts.ListeningItem{
				{
					QuestionNo: 1,
					AudioSource: contracts.ListeningAudioSource{
						Segments: []contracts.AudioSegment{
							{Speaker: "Muž", Text: "Dobrý den, prosím vás."},
							{Speaker: "Žena", Text: "Dobrý den."},
						},
					},
				},
			},
		},
	}
	if !HasMultipleSpeakers(exercise) {
		t.Error("expected HasMultipleSpeakers = true for Muž/Žena dialog")
	}
	segs := BuildExerciseDialogSegments(exercise)
	if len(segs) != 2 {
		t.Errorf("BuildExerciseDialogSegments = %d segments, want 2", len(segs))
	}
	if segs[0].Speaker != "Muž" {
		t.Errorf("segment 0 speaker = %q, want Muž", segs[0].Speaker)
	}
	if segs[1].Speaker != "Žena" {
		t.Errorf("segment 1 speaker = %q, want Žena", segs[1].Speaker)
	}
}

func TestHasMultipleSpeakers_SingleVoice(t *testing.T) {
	exercise := contracts.Exercise{
		ExerciseType: "poslech_5",
		Detail: contracts.Poslech5Detail{
			AudioSource: contracts.ListeningAudioSource{
				Segments: []contracts.AudioSegment{
					{Text: "Ahoj Lído, tady Eva."},
					{Text: "Dostala jsem lístky na balet."},
				},
			},
		},
	}
	if HasMultipleSpeakers(exercise) {
		t.Error("expected HasMultipleSpeakers = false for single-speaker segments")
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

func TestBuildExerciseAudioText_Poslech6_Passage(t *testing.T) {
	exercise := contracts.Exercise{
		ExerciseType: "poslech_6",
		Detail: contracts.AnoNeDetail{
			Passage: "Vlašim. Městský úřad je otevřen v pondělí od osmi hodin.",
			Statements: []contracts.AnoNeStatement{
				{QuestionNo: 1, Statement: "Úřad je zavřen v pátek."},
			},
			CorrectAnswers: map[string]string{"1": "ANO"},
		},
	}
	got := BuildExerciseAudioText(exercise)
	want := "Vlašim. Městský úřad je otevřen v pondělí od osmi hodin."
	if got != want {
		t.Errorf("BuildExerciseAudioText = %q, want %q", got, want)
	}
}

func TestBuildExerciseAudioText_Cteni6_ReturnsEmpty(t *testing.T) {
	exercise := contracts.Exercise{
		ExerciseType: "cteni_6",
		Detail: contracts.AnoNeDetail{
			Passage:        "Vlašim text",
			CorrectAnswers: map[string]string{"1": "ANO"},
		},
	}
	got := BuildExerciseAudioText(exercise)
	if got != "" {
		t.Errorf("cteni_6 should return empty (no audio), got %q", got)
	}
}

// ── V26: per-item audio text extraction ──────────────────────────────────────

func TestBuildExerciseItemTexts_Poslech1_PerItem(t *testing.T) {
	exercise := contracts.Exercise{
		ExerciseType: "poslech_1",
		Detail: contracts.Poslech1Detail{
			Items: []contracts.ListeningItem{
				{
					QuestionNo: 1,
					AudioSource: contracts.ListeningAudioSource{
						Segments: []contracts.AudioSegment{{Text: "Kde je nádraží?"}},
					},
				},
				{
					QuestionNo: 2,
					AudioSource: contracts.ListeningAudioSource{
						Segments: []contracts.AudioSegment{{Text: "Jak se jmenujete?"}},
					},
				},
				{
					QuestionNo: 3,
					AudioSource: contracts.ListeningAudioSource{
						Segments: []contracts.AudioSegment{
							{Speaker: "A", Text: "Dobrý den."},
							{Speaker: "B", Text: "Ahoj."},
						},
					},
				},
			},
		},
	}
	got := BuildExerciseItemTexts(exercise)
	want := []ItemText{
		{ItemNo: 1, Text: "Kde je nádraží?"},
		{ItemNo: 2, Text: "Jak se jmenujete?"},
		{ItemNo: 3, Text: "Dobrý den. Ahoj."},
	}
	if len(got) != len(want) {
		t.Fatalf("got %d items, want %d: %+v", len(got), len(want), got)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Errorf("item %d = %+v, want %+v", i, got[i], want[i])
		}
	}
}

func TestBuildExerciseItemTexts_Poslech1_SkipsUploadedAsset(t *testing.T) {
	exercise := contracts.Exercise{
		ExerciseType: "poslech_1",
		Detail: contracts.Poslech1Detail{
			Items: []contracts.ListeningItem{
				{
					QuestionNo: 1,
					AudioSource: contracts.ListeningAudioSource{
						Segments: []contracts.AudioSegment{{Text: "First"}},
					},
				},
				{
					QuestionNo:  2,
					AudioSource: contracts.ListeningAudioSource{AssetID: "uploaded-file-key"},
				},
				{
					QuestionNo: 3,
					AudioSource: contracts.ListeningAudioSource{
						Segments: []contracts.AudioSegment{{Text: "Third"}},
					},
				},
			},
		},
	}
	got := BuildExerciseItemTexts(exercise)
	if len(got) != 2 {
		t.Fatalf("got %d items, want 2 (uploaded skipped): %+v", len(got), got)
	}
	if got[0] != (ItemText{ItemNo: 1, Text: "First"}) {
		t.Errorf("got[0] = %+v", got[0])
	}
	if got[1] != (ItemText{ItemNo: 3, Text: "Third"}) {
		t.Errorf("got[1] = %+v", got[1])
	}
}

func TestBuildExerciseItemTexts_Poslech1_SkipsEmptyText(t *testing.T) {
	exercise := contracts.Exercise{
		ExerciseType: "poslech_1",
		Detail: contracts.Poslech1Detail{
			Items: []contracts.ListeningItem{
				{
					QuestionNo: 1,
					AudioSource: contracts.ListeningAudioSource{
						Segments: []contracts.AudioSegment{{Text: "Real text"}},
					},
				},
				{
					QuestionNo: 2,
					AudioSource: contracts.ListeningAudioSource{
						Segments: []contracts.AudioSegment{{Text: "   "}},
					},
				},
				{QuestionNo: 3},
			},
		},
	}
	got := BuildExerciseItemTexts(exercise)
	if len(got) != 1 {
		t.Fatalf("got %d items, want 1 (empty text skipped): %+v", len(got), got)
	}
	if got[0].ItemNo != 1 {
		t.Errorf("got[0].ItemNo = %d, want 1", got[0].ItemNo)
	}
}

func TestBuildExerciseItemTexts_Poslech2_OutOfScope(t *testing.T) {
	exercise := contracts.Exercise{
		ExerciseType: "poslech_2",
		Detail: contracts.Poslech2Detail{
			Items: []contracts.ListeningItem{
				{
					QuestionNo: 1,
					AudioSource: contracts.ListeningAudioSource{
						Segments: []contracts.AudioSegment{{Text: "Test"}},
					},
				},
			},
		},
	}
	if got := BuildExerciseItemTexts(exercise); got != nil {
		t.Errorf("poslech_2 should return nil (V26 scope = poslech_1 only), got %+v", got)
	}
}

func TestBuildExerciseItemTexts_NonListening_Nil(t *testing.T) {
	exercise := contracts.Exercise{ExerciseType: "psani_1_formular"}
	if got := BuildExerciseItemTexts(exercise); got != nil {
		t.Errorf("non-listening should return nil, got %+v", got)
	}
}

// V31 — Poslech1MissingTranscripts gate. Pre-V31, an exercise with a partial
// transcript set quietly generated audio only for the items that had text
// and silently fell back to legacy single-audio because the per-item gate
// (`itemsHavePerItemAudio`) requires every item to carry asset_id.

func TestPoslech1MissingTranscripts_AllFilled_NoneMissing(t *testing.T) {
	exercise := contracts.Exercise{
		ExerciseType: "poslech_1",
		Detail: contracts.Poslech1Detail{
			Items: []contracts.ListeningItem{
				{QuestionNo: 1, AudioSource: contracts.ListeningAudioSource{Segments: []contracts.AudioSegment{{Text: "a"}}}},
				{QuestionNo: 2, AudioSource: contracts.ListeningAudioSource{Segments: []contracts.AudioSegment{{Text: "b"}}}},
				{QuestionNo: 3, AudioSource: contracts.ListeningAudioSource{Segments: []contracts.AudioSegment{{Text: "c"}}}},
				{QuestionNo: 4, AudioSource: contracts.ListeningAudioSource{Segments: []contracts.AudioSegment{{Text: "d"}}}},
				{QuestionNo: 5, AudioSource: contracts.ListeningAudioSource{Segments: []contracts.AudioSegment{{Text: "e"}}}},
			},
		},
	}
	if got := Poslech1MissingTranscripts(exercise); len(got) != 0 {
		t.Errorf("got missing %+v, want none", got)
	}
}

func TestPoslech1MissingTranscripts_OnlyLastFilled_FourMissing(t *testing.T) {
	exercise := contracts.Exercise{
		ExerciseType: "poslech_1",
		Detail: contracts.Poslech1Detail{
			Items: []contracts.ListeningItem{
				{QuestionNo: 1},
				{QuestionNo: 2, AudioSource: contracts.ListeningAudioSource{Segments: []contracts.AudioSegment{{Text: "  "}}}},
				{QuestionNo: 3},
				{QuestionNo: 4},
				{QuestionNo: 5, AudioSource: contracts.ListeningAudioSource{Segments: []contracts.AudioSegment{{Text: "last"}}}},
			},
		},
	}
	got := Poslech1MissingTranscripts(exercise)
	want := []int{1, 2, 3, 4}
	if len(got) != len(want) {
		t.Fatalf("got %v, want %v", got, want)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Errorf("missing[%d] = %d, want %d", i, got[i], want[i])
		}
	}
}

func TestPoslech1MissingTranscripts_UploadedItemsExempt(t *testing.T) {
	exercise := contracts.Exercise{
		ExerciseType: "poslech_1",
		Detail: contracts.Poslech1Detail{
			Items: []contracts.ListeningItem{
				{QuestionNo: 1, AudioSource: contracts.ListeningAudioSource{AssetID: "uploaded-1"}},
				{QuestionNo: 2, AudioSource: contracts.ListeningAudioSource{AssetID: "uploaded-2"}},
				{QuestionNo: 3, AudioSource: contracts.ListeningAudioSource{Segments: []contracts.AudioSegment{{Text: "c"}}}},
				{QuestionNo: 4, AudioSource: contracts.ListeningAudioSource{AssetID: "uploaded-4"}},
				{QuestionNo: 5, AudioSource: contracts.ListeningAudioSource{Segments: []contracts.AudioSegment{{Text: "e"}}}},
			},
		},
	}
	if got := Poslech1MissingTranscripts(exercise); len(got) != 0 {
		t.Errorf("uploaded items should not count as missing, got %+v", got)
	}
}

func TestPoslech1MissingTranscripts_AllEmpty_ReportsAll(t *testing.T) {
	exercise := contracts.Exercise{
		ExerciseType: "poslech_1",
		Detail: contracts.Poslech1Detail{
			Items: []contracts.ListeningItem{
				{QuestionNo: 1}, {QuestionNo: 2}, {QuestionNo: 3}, {QuestionNo: 4}, {QuestionNo: 5},
			},
		},
	}
	got := Poslech1MissingTranscripts(exercise)
	if len(got) != 5 {
		t.Errorf("got %d missing, want 5", len(got))
	}
}

func TestPoslech1MissingTranscripts_NonPoslech1_Nil(t *testing.T) {
	exercise := contracts.Exercise{ExerciseType: "poslech_2"}
	if got := Poslech1MissingTranscripts(exercise); got != nil {
		t.Errorf("non-poslech_1 should return nil, got %+v", got)
	}
}

func TestPollyExerciseAudioGenerator_GenerateItemAudio_StorageKey(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("LOCAL_ASSETS_DIR", dir)

	mock := &fileWritingMockTTS{}
	gen := NewPollyExerciseAudioGenerator(mock)

	audio, err := gen.GenerateItemAudio("ex-abc", 3, "Kde je nádraží?")
	if err != nil {
		t.Fatalf("GenerateItemAudio error: %v", err)
	}
	wantKey := "exercise-audio/ex-abc/item-3.mp3"
	if audio.StorageKey != wantKey {
		t.Errorf("StorageKey = %q, want %q", audio.StorageKey, wantKey)
	}
	if audio.MimeType != "audio/mpeg" {
		t.Errorf("MimeType = %q, want audio/mpeg", audio.MimeType)
	}
	if audio.SourceType != "polly" {
		t.Errorf("SourceType = %q, want polly", audio.SourceType)
	}
	if audio.GeneratedAt == "" {
		t.Error("GeneratedAt empty")
	}
	if audio.ExerciseID != "ex-abc" {
		t.Errorf("ExerciseID = %q, want ex-abc", audio.ExerciseID)
	}

	// File should land at exercise-audio path with the same bytes the mock wrote.
	dstPath := localExerciseAudioPath(wantKey)
	data, err := os.ReadFile(dstPath)
	if err != nil {
		t.Fatalf("expected file at %s: %v", dstPath, err)
	}
	if !strings.Contains(string(data), "ex-abc") {
		t.Errorf("file content unexpected: %q", string(data))
	}

	// TTS attemptID should encode the item index so each call is unique.
	if len(mock.calls) != 1 {
		t.Fatalf("expected 1 TTS call, got %d", len(mock.calls))
	}
	if !strings.Contains(mock.calls[0].AttemptID, "item-3") {
		t.Errorf("TTS attemptID = %q, want substring item-3", mock.calls[0].AttemptID)
	}
	if mock.calls[0].Text != "Kde je nádraží?" {
		t.Errorf("TTS text = %q", mock.calls[0].Text)
	}
}

func TestPollyExerciseAudioGenerator_GenerateItemAudio_EmptyText(t *testing.T) {
	gen := NewPollyExerciseAudioGenerator(&fileWritingMockTTS{})
	_, err := gen.GenerateItemAudio("ex-abc", 1, "   ")
	if err == nil {
		t.Fatal("expected error for whitespace-only text")
	}
}

func TestItemAudioGenerator_InterfaceSatisfaction(t *testing.T) {
	// Compile-time assertion: both Dev and Polly generators implement
	// ItemAudioGenerator. The admin endpoint relies on this for type assertion.
	var _ ItemAudioGenerator = DevExerciseAudioGenerator{}
	var _ ItemAudioGenerator = (*PollyExerciseAudioGenerator)(nil)
}

func TestDevExerciseAudioGenerator_GenerateItemAudio(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("LOCAL_ASSETS_DIR", dir)

	audio, err := DevExerciseAudioGenerator{}.GenerateItemAudio("ex-xyz", 2, "ignored text")
	if err != nil {
		t.Fatalf("GenerateItemAudio error: %v", err)
	}
	wantKey := "exercise-audio/ex-xyz/item-2.wav"
	if audio.StorageKey != wantKey {
		t.Errorf("StorageKey = %q, want %q", audio.StorageKey, wantKey)
	}
	if audio.SourceType != "dev" {
		t.Errorf("SourceType = %q, want dev", audio.SourceType)
	}
	info, err := os.Stat(localExerciseAudioPath(audio.StorageKey))
	if err != nil {
		t.Fatalf("expected stub file at %s: %v", audio.StorageKey, err)
	}
	if info.Size() == 0 {
		t.Fatal("expected non-empty stub item audio")
	}
}

// ── V39: per-item dialog audio (poslech_1 multi-speaker) ─────────────────────

func TestBuildExerciseItemDialogs_PreservesSpeakers(t *testing.T) {
	exercise := contracts.Exercise{
		ExerciseType: "poslech_1",
		Detail: contracts.Poslech1Detail{
			Items: []contracts.ListeningItem{
				{
					QuestionNo: 1,
					AudioSource: contracts.ListeningAudioSource{
						Segments: []contracts.AudioSegment{
							{Speaker: "Žena", Text: "Dobrý den."},
							{Speaker: "Muž", Text: "Dobrý den, ano."},
							{Speaker: "Žena", Text: "Děkuju."},
						},
					},
				},
				{
					QuestionNo: 2,
					AudioSource: contracts.ListeningAudioSource{
						Segments: []contracts.AudioSegment{{Text: "Jak se jmenujete?"}},
					},
				},
			},
		},
	}
	got := BuildExerciseItemDialogs(exercise)
	if len(got) != 2 {
		t.Fatalf("got %d dialogs, want 2", len(got))
	}
	if got[0].ItemNo != 1 || len(got[0].Segments) != 3 {
		t.Fatalf("dialog 0 = %+v, want item 1 with 3 segments", got[0])
	}
	if got[0].Segments[0].Speaker != "Žena" || got[0].Segments[0].Text != "Dobrý den." {
		t.Errorf("seg 0 = %+v", got[0].Segments[0])
	}
	if got[0].Segments[1].Speaker != "Muž" {
		t.Errorf("seg 1 speaker = %q, want Muž", got[0].Segments[1].Speaker)
	}
	if got[1].ItemNo != 2 || got[1].Segments[0].Speaker != "" {
		t.Errorf("dialog 1 = %+v, want item 2 single anonymous segment", got[1])
	}
}

func TestBuildExerciseItemDialogs_SkipsUploadedAndEmpty(t *testing.T) {
	exercise := contracts.Exercise{
		ExerciseType: "poslech_1",
		Detail: contracts.Poslech1Detail{
			Items: []contracts.ListeningItem{
				{QuestionNo: 1, AudioSource: contracts.ListeningAudioSource{AssetID: "uploaded"}},
				{QuestionNo: 2, AudioSource: contracts.ListeningAudioSource{Segments: []contracts.AudioSegment{{Text: "   "}}}},
				{QuestionNo: 3, AudioSource: contracts.ListeningAudioSource{Segments: []contracts.AudioSegment{{Speaker: "A", Text: "Real"}}}},
			},
		},
	}
	got := BuildExerciseItemDialogs(exercise)
	if len(got) != 1 || got[0].ItemNo != 3 {
		t.Fatalf("got %+v, want only item 3", got)
	}
}

func TestBuildExerciseItemDialogs_NonPoslech1_Nil(t *testing.T) {
	exercise := contracts.Exercise{ExerciseType: "poslech_2"}
	if got := BuildExerciseItemDialogs(exercise); got != nil {
		t.Errorf("non-poslech_1 should return nil, got %+v", got)
	}
}

func TestItemDialogHasMultipleSpeakers(t *testing.T) {
	cases := []struct {
		name string
		segs []contracts.AudioSegment
		want bool
	}{
		{"two distinct", []contracts.AudioSegment{{Speaker: "Žena", Text: "a"}, {Speaker: "Muž", Text: "b"}}, true},
		{"same speaker twice", []contracts.AudioSegment{{Speaker: "Žena", Text: "a"}, {Speaker: "Žena", Text: "b"}}, false},
		{"no speakers", []contracts.AudioSegment{{Text: "a"}, {Text: "b"}}, false},
		{"one labeled one unlabeled", []contracts.AudioSegment{{Speaker: "Žena", Text: "a"}, {Text: "b"}}, false},
		{"empty", nil, false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := ItemDialogHasMultipleSpeakers(tc.segs); got != tc.want {
				t.Errorf("ItemDialogHasMultipleSpeakers = %v, want %v", got, tc.want)
			}
		})
	}
}

func TestPollyExerciseAudioGenerator_GenerateItemDialogAudio_SpeakerRouting(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("LOCAL_ASSETS_DIR", dir)

	primary := &fileWritingMockTTS{}   // voice A — Polly female (g.tts)
	secondary := &fileWritingMockTTS{} // voice B — ElevenLabs male (g.ttsB)
	gen := NewPollyExerciseAudioGenerator(primary).WithDialogVoice(secondary)

	segments := []contracts.AudioSegment{
		{Speaker: "Žena", Text: "Dobrý den."},
		{Speaker: "Muž", Text: "Dobrý den, ano, to jsem já."},
		{Speaker: "Žena", Text: "Teď se právě dívám."},
		{Speaker: "Muž", Text: "Chci na ten kurz."},
	}
	audio, err := gen.GenerateItemDialogAudio("ex-99", 1, segments)
	if err != nil {
		t.Fatalf("GenerateItemDialogAudio error: %v", err)
	}

	wantKey := "exercise-audio/ex-99/item-1.mp3"
	if audio.StorageKey != wantKey {
		t.Errorf("StorageKey = %q, want %q", audio.StorageKey, wantKey)
	}
	if audio.SourceType != "polly" {
		t.Errorf("SourceType = %q, want polly", audio.SourceType)
	}

	if len(primary.calls) != 2 {
		t.Errorf("primary female voice calls = %d, want 2", len(primary.calls))
	}
	if len(secondary.calls) != 2 {
		t.Errorf("secondary male voice calls = %d, want 2", len(secondary.calls))
	}
	if len(primary.calls) >= 1 && primary.calls[0].Text != "Dobrý den." {
		t.Errorf("primary first call text = %q, want female opening", primary.calls[0].Text)
	}
	if len(secondary.calls) >= 1 && secondary.calls[0].Text != "Dobrý den, ano, to jsem já." {
		t.Errorf("secondary first call text = %q, want male reply", secondary.calls[0].Text)
	}

	// Concatenated file should land at exercise-audio path.
	if _, err := os.Stat(localExerciseAudioPath(wantKey)); err != nil {
		t.Errorf("merged file missing: %v", err)
	}
}

func TestPollyExerciseAudioGenerator_GenerateItemDialogAudio_NoTtsBFallsBackToTts(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("LOCAL_ASSETS_DIR", dir)

	primary := &fileWritingMockTTS{}
	gen := NewPollyExerciseAudioGenerator(primary) // no WithDialogVoice — ttsB nil

	segments := []contracts.AudioSegment{
		{Speaker: "Žena", Text: "Ahoj."},
		{Speaker: "Muž", Text: "Ahoj."},
	}
	_, err := gen.GenerateItemDialogAudio("ex-x", 2, segments)
	if err != nil {
		t.Fatalf("GenerateItemDialogAudio error: %v", err)
	}
	// Without ttsB the first-speaker slot maps to nil; both segments must
	// fall through to the index-based fallback which always uses tts when
	// ttsB is nil. So both calls land on the primary.
	if len(primary.calls) != 2 {
		t.Errorf("primary calls = %d, want 2 (ttsB nil → all on primary)", len(primary.calls))
	}
}

func TestPollyExerciseAudioGenerator_GenerateItemDialogAudio_EmptySegments(t *testing.T) {
	gen := NewPollyExerciseAudioGenerator(&fileWritingMockTTS{})
	if _, err := gen.GenerateItemDialogAudio("ex", 1, nil); err == nil {
		t.Fatal("expected error for empty segments")
	}
}

func TestItemDialogAudioGenerator_InterfaceSatisfaction(t *testing.T) {
	// Compile-time assertion: Polly satisfies the new dialog interface and
	// Dev keeps the stub implementation so dev-mode admins can still test
	// the per-item multi-speaker route.
	var _ ItemDialogAudioGenerator = (*PollyExerciseAudioGenerator)(nil)
	var _ ItemDialogAudioGenerator = DevExerciseAudioGenerator{}
}

// ── V39: poslech_4 multi-speaker routing ─────────────────────────────────────

func TestHasMultipleSpeakers_Poslech4_DialogTurns(t *testing.T) {
	exercise := contracts.Exercise{
		ExerciseType: "poslech_4",
		Detail: contracts.Poslech4Detail{
			Items: []contracts.DialogItem{
				{
					QuestionNo: 1,
					AudioSource: contracts.ListeningAudioSource{
						Segments: []contracts.AudioSegment{
							{Speaker: "Žena", Text: "Co byste si přál?"},
							{Speaker: "Muž", Text: "Kávu prosím."},
						},
					},
				},
			},
		},
	}
	if !HasMultipleSpeakers(exercise) {
		t.Fatal("poslech_4 with Žena+Muž turns must report multi-speaker")
	}
	segs := BuildExerciseDialogSegments(exercise)
	if len(segs) != 2 {
		t.Fatalf("got %d segments, want 2", len(segs))
	}
	if segs[0].Speaker != "Žena" || segs[1].Speaker != "Muž" {
		t.Errorf("segment speakers = %q,%q; want Žena,Muž", segs[0].Speaker, segs[1].Speaker)
	}
}

func TestHasMultipleSpeakers_Poslech4_SingleVoicePerItem(t *testing.T) {
	// Legacy P4 design — each item one anonymous segment. Should not be
	// treated as multi-speaker; the server still routes through the
	// per-item index-alternation path.
	exercise := contracts.Exercise{
		ExerciseType: "poslech_4",
		Detail: contracts.Poslech4Detail{
			Items: []contracts.DialogItem{
				{QuestionNo: 1, AudioSource: contracts.ListeningAudioSource{Segments: []contracts.AudioSegment{{Text: "Ahoj."}}}},
				{QuestionNo: 2, AudioSource: contracts.ListeningAudioSource{Segments: []contracts.AudioSegment{{Text: "Nazdar."}}}},
			},
		},
	}
	if HasMultipleSpeakers(exercise) {
		t.Error("anonymous segments should not count as multi-speaker")
	}
}

// ── V39: poslech_6 passage speaker parsing ───────────────────────────────────

func TestParseSpeakerPassage_MultiSpeaker(t *testing.T) {
	passage := "[Žena]: Dobrý den, tady úřad.\n[Muž]: Děkuji, na shledanou."
	got := parseSpeakerPassage(passage)
	if len(got) != 2 {
		t.Fatalf("got %d segments, want 2", len(got))
	}
	if got[0].Speaker != "Žena" || got[0].Text != "Dobrý den, tady úřad." {
		t.Errorf("seg 0 = %+v", got[0])
	}
	if got[1].Speaker != "Muž" || got[1].Text != "Děkuji, na shledanou." {
		t.Errorf("seg 1 = %+v", got[1])
	}
}

func TestParseSpeakerPassage_NoMarkers(t *testing.T) {
	passage := "Plain prose without speaker labels.\nSecond line."
	got := parseSpeakerPassage(passage)
	if len(got) != 2 {
		t.Fatalf("got %d segments, want 2 anonymous lines", len(got))
	}
	for i, seg := range got {
		if seg.Speaker != "" {
			t.Errorf("seg %d unexpectedly has speaker %q", i, seg.Speaker)
		}
	}
}

func TestParseSpeakerPassage_SpeakerContinuationLines(t *testing.T) {
	passage := "[Žena]: Dobrý den, tady jazyková škola Atlas. Vy jste poslal přihlášku\n" +
		"do kurzu češtiny pro cizince?\n" +
		"[Muž]: Ano, poslal jsem ji minulý týden."
	got := parseSpeakerPassage(passage)
	if len(got) != 2 {
		t.Fatalf("got %d segments, want 2 merged speaker turns: %+v", len(got), got)
	}
	if got[0].Speaker != "Žena" {
		t.Fatalf("first speaker = %q, want Žena", got[0].Speaker)
	}
	wantFirst := "Dobrý den, tady jazyková škola Atlas. Vy jste poslal přihlášku do kurzu češtiny pro cizince?"
	if got[0].Text != wantFirst {
		t.Errorf("first text = %q, want %q", got[0].Text, wantFirst)
	}
	if got[1].Speaker != "Muž" {
		t.Errorf("second speaker = %q, want Muž", got[1].Speaker)
	}
}

func TestParseSpeakerPassage_MixedAndEmptyLines(t *testing.T) {
	passage := "[Žena]: Hello.\n\nPlain line.\n[Muž]: World.\n  \n[Žena]:   "
	got := parseSpeakerPassage(passage)
	// Empty / whitespace-only lines skipped; trailing empty speaker line skipped.
	if len(got) != 3 {
		t.Fatalf("got %d segments, want 3: %+v", len(got), got)
	}
	if got[0].Speaker != "Žena" || got[1].Speaker != "" || got[2].Speaker != "Muž" {
		t.Errorf("speakers = %+v", got)
	}
}

func TestHasMultipleSpeakers_Poslech6_Passage(t *testing.T) {
	exercise := contracts.Exercise{
		ExerciseType: "poslech_6",
		Detail: contracts.AnoNeDetail{
			Passage: "[Žena]: Dobrý den.\n[Muž]: Dobrý den, prosím vás.",
		},
	}
	if !HasMultipleSpeakers(exercise) {
		t.Fatal("poslech_6 passage with [Žena]+[Muž] markers must be multi-speaker")
	}
	segs := BuildExerciseDialogSegments(exercise)
	if len(segs) != 2 || segs[0].Speaker != "Žena" || segs[1].Speaker != "Muž" {
		t.Errorf("dialog segments = %+v", segs)
	}
}

func TestHasMultipleSpeakers_Poslech6_PlainPassage(t *testing.T) {
	exercise := contracts.Exercise{
		ExerciseType: "poslech_6",
		Detail: contracts.AnoNeDetail{
			Passage: "Vlašim. Městský úřad je otevřen v pondělí.",
		},
	}
	if HasMultipleSpeakers(exercise) {
		t.Error("plain passage without speaker markers should not count as multi-speaker")
	}
}

func TestBuildExerciseAudioText_Poslech6_StripsSpeakerMarkers(t *testing.T) {
	// Single-speaker fallback: even when the passage has one [Žena]: marker,
	// the flat text must drop the bracketed prefix so Polly doesn't read
	// "Žena colon Hello" out loud.
	exercise := contracts.Exercise{
		ExerciseType: "poslech_6",
		Detail: contracts.AnoNeDetail{
			Passage: "[Žena]: Dobrý den, tady úřad.",
		},
	}
	got := BuildExerciseAudioText(exercise)
	want := "Dobrý den, tady úřad."
	if got != want {
		t.Errorf("BuildExerciseAudioText = %q, want %q", got, want)
	}
}
