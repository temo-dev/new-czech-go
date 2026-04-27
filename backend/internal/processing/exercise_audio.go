package processing

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// BuildExerciseAudioText extracts a concatenated text string from a listening
// exercise's detail so it can be sent to Polly TTS.
// Returns "" when the exercise type is not listening or uses an uploaded asset.
func BuildExerciseAudioText(exercise contracts.Exercise) string {
	switch exercise.ExerciseType {
	case "poslech_1", "poslech_2":
		return buildFromItems(toListening1Detail(exercise.Detail))
	case "poslech_3":
		return buildFromItems(toListening3Items(exercise.Detail))
	case "poslech_4":
		return buildFromDialogItems(toListening4Items(exercise.Detail))
	case "poslech_5":
		return buildFromAudioSource(toListening5Source(exercise.Detail))
	}
	return ""
}

func buildFromAudioSource(src contracts.ListeningAudioSource) string {
	if src.AssetID != "" {
		return "" // uploaded asset — Polly not needed
	}
	return joinSegments(src.Segments)
}

func buildFromItems(items []contracts.ListeningItem) string {
	var parts []string
	for _, item := range items {
		if item.AudioSource.AssetID != "" {
			continue
		}
		if t := joinSegments(item.AudioSource.Segments); t != "" {
			parts = append(parts, t)
		}
	}
	return strings.Join(parts, " ")
}

func buildFromDialogItems(items []contracts.DialogItem) string {
	var parts []string
	for _, item := range items {
		if item.AudioSource.AssetID != "" {
			continue
		}
		if t := joinSegments(item.AudioSource.Segments); t != "" {
			parts = append(parts, t)
		}
	}
	return strings.Join(parts, " ")
}

func joinSegments(segments []contracts.AudioSegment) string {
	var parts []string
	for _, seg := range segments {
		if t := strings.TrimSpace(seg.Text); t != "" {
			parts = append(parts, t)
		}
	}
	return strings.Join(parts, " ")
}

// toListening1Detail unmarshals exercise.Detail into Poslech1Detail items.
func toListening1Detail(v any) []contracts.ListeningItem {
	b, err := json.Marshal(v)
	if err != nil {
		return nil
	}
	var d contracts.Poslech1Detail
	if err := json.Unmarshal(b, &d); err != nil {
		return nil
	}
	return d.Items
}

func toListening3Items(v any) []contracts.ListeningItem {
	b, err := json.Marshal(v)
	if err != nil {
		return nil
	}
	var d contracts.Poslech3Detail
	if err := json.Unmarshal(b, &d); err != nil {
		return nil
	}
	return d.Items
}

func toListening4Items(v any) []contracts.DialogItem {
	b, err := json.Marshal(v)
	if err != nil {
		return nil
	}
	var d contracts.Poslech4Detail
	if err := json.Unmarshal(b, &d); err != nil {
		return nil
	}
	return d.Items
}

func toListening5Source(v any) contracts.ListeningAudioSource {
	b, err := json.Marshal(v)
	if err != nil {
		return contracts.ListeningAudioSource{}
	}
	var d contracts.Poslech5Detail
	if err := json.Unmarshal(b, &d); err != nil {
		return contracts.ListeningAudioSource{}
	}
	return d.AudioSource
}

// ExerciseAudioGenerator generates audio for a listening exercise from its text.
type ExerciseAudioGenerator interface {
	GenerateAudio(exerciseID, text string) (*contracts.ExerciseAudio, error)
}

// DevExerciseAudioGenerator is a no-op used in development.
type DevExerciseAudioGenerator struct{}

func (DevExerciseAudioGenerator) GenerateAudio(exerciseID, _ string) (*contracts.ExerciseAudio, error) {
	return &contracts.ExerciseAudio{
		ExerciseID:  exerciseID,
		StorageKey:  fmt.Sprintf("exercise-audio/%s/audio.mp3", exerciseID),
		MimeType:    "audio/mpeg",
		SourceType:  "dev",
		GeneratedAt: time.Now().UTC().Format(time.RFC3339),
	}, nil
}

// PollyExerciseAudioGenerator generates exercise audio via Amazon Polly.
type PollyExerciseAudioGenerator struct {
	tts TTSProvider // reuses existing Polly provider
}

func NewPollyExerciseAudioGenerator(tts TTSProvider) *PollyExerciseAudioGenerator {
	return &PollyExerciseAudioGenerator{tts: tts}
}

func (g *PollyExerciseAudioGenerator) GenerateAudio(exerciseID, text string) (*contracts.ExerciseAudio, error) {
	if strings.TrimSpace(text) == "" {
		return nil, fmt.Errorf("exercise %s: no text to synthesize", exerciseID)
	}

	// TTSProvider.Generate stores to attempt-review/... path.
	// For exercise audio we want exercise-audio/... so we write it ourselves.
	ttsResult, err := g.tts.Generate(exerciseID, text)
	if err != nil {
		return nil, fmt.Errorf("polly exercise audio: %w", err)
	}

	// Rewrite storage key to exercise-audio namespace.
	storageKey := fmt.Sprintf("exercise-audio/%s/audio.mp3", exerciseID)
	srcPath := localReviewAudioPath(ttsResult.StorageKey)
	dstPath := localExerciseAudioPath(storageKey)
	if err := os.MkdirAll(filepath.Dir(dstPath), 0o755); err != nil {
		return nil, fmt.Errorf("prepare exercise audio dir: %w", err)
	}
	data, err := os.ReadFile(srcPath)
	if err != nil {
		return nil, fmt.Errorf("read polly output: %w", err)
	}
	if err := os.WriteFile(dstPath, data, 0o644); err != nil {
		return nil, fmt.Errorf("write exercise audio: %w", err)
	}

	return &contracts.ExerciseAudio{
		ExerciseID:  exerciseID,
		StorageKey:  storageKey,
		MimeType:    "audio/mpeg",
		SourceType:  "polly",
		GeneratedAt: time.Now().UTC().Format(time.RFC3339),
	}, nil
}

// localExerciseAudioPath returns the local filesystem path for exercise audio.
func localExerciseAudioPath(storageKey string) string {
	base := strings.TrimSpace(os.Getenv("LOCAL_ASSETS_DIR"))
	if base == "" {
		base = "/tmp/czech-go-assets"
	}
	return filepath.Join(base, storageKey)
}
