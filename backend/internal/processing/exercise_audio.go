package processing

import (
	"bytes"
	"encoding/binary"
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

// DialogExerciseAudioGenerator extends ExerciseAudioGenerator with 2-voice dialog support.
// Implemented by PollyExerciseAudioGenerator when a second voice is configured.
type DialogExerciseAudioGenerator interface {
	ExerciseAudioGenerator
	// GenerateDialogAudio synthesizes each segment with speaker-based or index-based
	// voice alternation, then concatenates into one MP3.
	GenerateDialogAudio(exerciseID string, segments []contracts.AudioSegment) (*contracts.ExerciseAudio, error)
}

// HasMultipleSpeakers returns true when the exercise has segments with ≥2 distinct
// speaker labels, indicating dialog (2-voice) TTS should be used.
func HasMultipleSpeakers(exercise contracts.Exercise) bool {
	speakers := map[string]bool{}
	for _, seg := range allExerciseSegments(exercise) {
		if seg.Speaker != "" {
			speakers[seg.Speaker] = true
			if len(speakers) >= 2 {
				return true
			}
		}
	}
	return false
}

// BuildExerciseDialogSegments returns each non-empty segment as a dialog turn,
// preserving speaker labels for voice assignment.
func BuildExerciseDialogSegments(exercise contracts.Exercise) []contracts.AudioSegment {
	var out []contracts.AudioSegment
	for _, seg := range allExerciseSegments(exercise) {
		if t := strings.TrimSpace(seg.Text); t != "" {
			out = append(out, contracts.AudioSegment{Speaker: seg.Speaker, Text: t})
		}
	}
	return out
}

// allExerciseSegments collects every AudioSegment from any poslech_* exercise.
func allExerciseSegments(exercise contracts.Exercise) []contracts.AudioSegment {
	switch exercise.ExerciseType {
	case "poslech_1", "poslech_2":
		var segs []contracts.AudioSegment
		for _, item := range toListening1Detail(exercise.Detail) {
			segs = append(segs, item.AudioSource.Segments...)
		}
		return segs
	case "poslech_3":
		var segs []contracts.AudioSegment
		for _, item := range toListening3Items(exercise.Detail) {
			segs = append(segs, item.AudioSource.Segments...)
		}
		return segs
	case "poslech_4":
		var segs []contracts.AudioSegment
		for _, item := range toListening4Items(exercise.Detail) {
			segs = append(segs, item.AudioSource.Segments...)
		}
		return segs
	case "poslech_5":
		return toListening5Source(exercise.Detail).Segments
	}
	return nil
}

// DevExerciseAudioGenerator writes a stub silent WAV file for use in development.
type DevExerciseAudioGenerator struct{}

func (DevExerciseAudioGenerator) GenerateAudio(exerciseID, _ string) (*contracts.ExerciseAudio, error) {
	storageKey := fmt.Sprintf("exercise-audio/%s/audio.wav", exerciseID)
	dst := localExerciseAudioPath(storageKey)
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return nil, fmt.Errorf("dev audio dir: %w", err)
	}
	if err := os.WriteFile(dst, devSilentWAV(), 0o644); err != nil {
		return nil, fmt.Errorf("dev audio write: %w", err)
	}
	return &contracts.ExerciseAudio{
		ExerciseID:  exerciseID,
		StorageKey:  storageKey,
		MimeType:    "audio/wav",
		SourceType:  "dev",
		GeneratedAt: time.Now().UTC().Format(time.RFC3339),
	}, nil
}

// GenerateDialogAudio for dev: same stub WAV regardless of dialog content.
func (DevExerciseAudioGenerator) GenerateDialogAudio(exerciseID string, _ []contracts.AudioSegment) (*contracts.ExerciseAudio, error) {
	return (DevExerciseAudioGenerator{}).GenerateAudio(exerciseID, "")
}

// devSilentWAV returns a minimal valid 44-byte WAV file (0 audio samples).
func devSilentWAV() []byte {
	buf := make([]byte, 44)
	copy(buf[0:4], "RIFF")
	binary.LittleEndian.PutUint32(buf[4:8], 36) // file size - 8
	copy(buf[8:12], "WAVE")
	copy(buf[12:16], "fmt ")
	binary.LittleEndian.PutUint32(buf[16:20], 16)    // fmt chunk size
	binary.LittleEndian.PutUint16(buf[20:22], 1)     // PCM
	binary.LittleEndian.PutUint16(buf[22:24], 1)     // mono
	binary.LittleEndian.PutUint32(buf[24:28], 44100) // sample rate
	binary.LittleEndian.PutUint32(buf[28:32], 88200) // byte rate
	binary.LittleEndian.PutUint16(buf[32:34], 2)     // block align
	binary.LittleEndian.PutUint16(buf[34:36], 16)    // bits/sample
	copy(buf[36:40], "data")
	binary.LittleEndian.PutUint32(buf[40:44], 0) // data size: 0 samples
	return buf
}

// PollyExerciseAudioGenerator generates exercise audio via Amazon Polly.
// ttsB is optional: when set, poslech_4 dialogs alternate between tts and ttsB.
type PollyExerciseAudioGenerator struct {
	tts  TTSProvider // voice A (primary)
	ttsB TTSProvider // voice B for poslech_4 dialogs (optional)
}

func NewPollyExerciseAudioGenerator(tts TTSProvider) *PollyExerciseAudioGenerator {
	return &PollyExerciseAudioGenerator{tts: tts}
}

// WithDialogVoice sets the second voice for poslech_4 dialog alternation.
func (g *PollyExerciseAudioGenerator) WithDialogVoice(ttsB TTSProvider) *PollyExerciseAudioGenerator {
	g.ttsB = ttsB
	return g
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

// ── Poslech 4 — 2-voice dialog support ───────────────────────────────────────

// BuildExerciseDialogTexts returns one segment per dialog item for poslech_4.
// Speaker is empty (index-based alternation). Returns nil for other types.
// Uploaded items (AssetID set) are excluded.
func BuildExerciseDialogTexts(exercise contracts.Exercise) []contracts.AudioSegment {
	if exercise.ExerciseType != "poslech_4" {
		return nil
	}
	items := toListening4Items(exercise.Detail)
	var segs []contracts.AudioSegment
	for _, item := range items {
		if item.AudioSource.AssetID != "" {
			continue
		}
		if t := joinSegments(item.AudioSource.Segments); t != "" {
			segs = append(segs, contracts.AudioSegment{Text: t})
		}
	}
	return segs
}

// concatMP3 concatenates multiple MP3 byte slices.
// MP3 is a stream of self-contained frames; concatenation produces a valid stream.
func concatMP3(parts [][]byte) []byte {
	return bytes.Join(parts, nil)
}

// GenerateDialogAudio synthesizes each segment with speaker-based voice assignment
// when speaker labels are present, otherwise falls back to index alternation.
// Voice mapping: first unique speaker → ttsB (custom voice), second → tts (primary).
// This ensures [Muž] (typically first) uses the cloned voice and [Žena] uses Polly.
func (g *PollyExerciseAudioGenerator) GenerateDialogAudio(exerciseID string, segments []contracts.AudioSegment) (*contracts.ExerciseAudio, error) {
	if len(segments) == 0 {
		return nil, fmt.Errorf("exercise %s: no dialog segments", exerciseID)
	}

	// Build speaker → provider mapping from first two unique speakers.
	// First speaker → ttsB (custom/cloned voice), second → tts (primary).
	speakerVoice := map[string]TTSProvider{}
	for _, seg := range segments {
		if seg.Speaker == "" {
			continue
		}
		if _, seen := speakerVoice[seg.Speaker]; seen {
			continue
		}
		if len(speakerVoice) == 0 {
			speakerVoice[seg.Speaker] = g.ttsB // first speaker → voice B (e.g. ElevenLabs male)
		} else {
			speakerVoice[seg.Speaker] = g.tts // second speaker → voice A (e.g. Polly female)
			break
		}
	}

	var audioParts [][]byte
	for i, seg := range segments {
		var provider TTSProvider
		if seg.Speaker != "" {
			provider = speakerVoice[seg.Speaker]
		}
		if provider == nil {
			// No speaker label or first speaker has no ttsB: index-based fallback.
			provider = g.tts
			if g.ttsB != nil && i%2 == 1 {
				provider = g.ttsB
			}
		}
		result, err := provider.Generate(fmt.Sprintf("%s-dialog-%d", exerciseID, i), seg.Text)
		if err != nil {
			return nil, fmt.Errorf("generate dialog item %d: %w", i, err)
		}
		data, err := os.ReadFile(localReviewAudioPath(result.StorageKey))
		if err != nil {
			return nil, fmt.Errorf("read dialog audio %d: %w", i, err)
		}
		audioParts = append(audioParts, data)
	}

	merged := concatMP3(audioParts)
	storageKey := fmt.Sprintf("exercise-audio/%s/audio.mp3", exerciseID)
	dstPath := localExerciseAudioPath(storageKey)
	if err := os.MkdirAll(filepath.Dir(dstPath), 0o755); err != nil {
		return nil, fmt.Errorf("prepare exercise audio dir: %w", err)
	}
	if err := os.WriteFile(dstPath, merged, 0o644); err != nil {
		return nil, fmt.Errorf("write dialog audio: %w", err)
	}
	return &contracts.ExerciseAudio{
		ExerciseID:  exerciseID,
		StorageKey:  storageKey,
		MimeType:    "audio/mpeg",
		SourceType:  "polly",
		GeneratedAt: time.Now().UTC().Format(time.RFC3339),
	}, nil
}
