package processing

import (
	"bytes"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// speakerLineRE matches lines that start with a `[Speaker]:` prefix, e.g.
// "[Žena]: Dobrý den." Groups: 1 = speaker name, 2 = utterance text.
// Mirrors the CMS regex in `poslech-model.ts` so admins type the same
// markup everywhere (form fields, P6 passage textarea).
var speakerLineRE = regexp.MustCompile(`^\s*\[([^\]]+)\]:\s*(.*)$`)

// parseSpeakerPassage splits a prose passage into AudioSegments using the
// `[Speaker]: utterance` line convention. Lines without a speaker prefix keep
// the previous speaker when they are direct continuations; blank lines reset
// that continuation state. Trailing whitespace is trimmed per segment. Used
// by poslech_6 to opt into
// multi-speaker TTS without changing AnoNeDetail's wire shape. V39.
func parseSpeakerPassage(passage string) []contracts.AudioSegment {
	var out []contracts.AudioSegment
	currentSpeaker := ""
	for _, raw := range strings.Split(passage, "\n") {
		line := strings.TrimSpace(raw)
		if line == "" {
			currentSpeaker = ""
			continue
		}
		if m := speakerLineRE.FindStringSubmatch(line); m != nil {
			currentSpeaker = strings.TrimSpace(m[1])
			text := strings.TrimSpace(m[2])
			if text == "" {
				continue
			}
			out = append(out, contracts.AudioSegment{Speaker: currentSpeaker, Text: text})
			continue
		}
		if currentSpeaker != "" {
			if len(out) > 0 && out[len(out)-1].Speaker == currentSpeaker {
				out[len(out)-1].Text = strings.TrimSpace(out[len(out)-1].Text + " " + line)
			} else {
				out = append(out, contracts.AudioSegment{Speaker: currentSpeaker, Text: line})
			}
			continue
		}
		out = append(out, contracts.AudioSegment{Text: line})
	}
	return out
}

// ItemText pairs a listening item's question_no with its synthesizable text.
// V26 — used by per-item audio generation for poslech_1.
type ItemText struct {
	ItemNo int
	Text   string
}

// ItemDialog pairs a listening item's question_no with its dialog segments,
// preserving speaker labels so per-item audio generation can route each turn
// to the correct voice (e.g. [Žena]/[Muž]).
// V39 — used by per-item dialog audio generation for poslech_1.
type ItemDialog struct {
	ItemNo   int
	Segments []contracts.AudioSegment
}

// BuildExerciseItemTexts returns per-item synthesis input for poslech_1.
// Items with an uploaded AssetID or no text segments are skipped — the caller
// should not attempt TTS for those. Returns nil for any other exercise type
// (V26 scope = poslech_1 only; poslech_2/3/4 still use single-audio path).
func BuildExerciseItemTexts(exercise contracts.Exercise) []ItemText {
	if exercise.ExerciseType != "poslech_1" {
		return nil
	}
	items := toListening1Detail(exercise.Detail)
	var out []ItemText
	for _, item := range items {
		if item.AudioSource.AssetID != "" {
			continue
		}
		text := joinSegments(item.AudioSource.Segments)
		if text == "" {
			continue
		}
		out = append(out, ItemText{ItemNo: item.QuestionNo, Text: text})
	}
	return out
}

// BuildExerciseItemDialogs returns per-item dialog segments for poslech_1,
// preserving speaker labels so the caller can route each segment to a
// distinct TTS voice. Items with an uploaded AssetID or no text segments
// are skipped. V39 — fixes the V26 per-item path which collapsed every
// segment into one flat text and rendered multi-speaker items in a single
// voice.
func BuildExerciseItemDialogs(exercise contracts.Exercise) []ItemDialog {
	if exercise.ExerciseType != "poslech_1" {
		return nil
	}
	items := toListening1Detail(exercise.Detail)
	var out []ItemDialog
	for _, item := range items {
		if item.AudioSource.AssetID != "" {
			continue
		}
		var segs []contracts.AudioSegment
		for _, seg := range item.AudioSource.Segments {
			if t := strings.TrimSpace(seg.Text); t != "" {
				segs = append(segs, contracts.AudioSegment{Speaker: seg.Speaker, Text: t})
			}
		}
		if len(segs) == 0 {
			continue
		}
		out = append(out, ItemDialog{ItemNo: item.QuestionNo, Segments: segs})
	}
	return out
}

// ItemDialogHasMultipleSpeakers reports whether an item's segments contain
// ≥2 distinct non-empty speaker labels — i.e. it should use 2-voice
// synthesis.
func ItemDialogHasMultipleSpeakers(segments []contracts.AudioSegment) bool {
	seen := map[string]bool{}
	for _, seg := range segments {
		if seg.Speaker == "" {
			continue
		}
		seen[seg.Speaker] = true
		if len(seen) >= 2 {
			return true
		}
	}
	return false
}

type speakerVoiceRole int

const (
	speakerVoiceUnknown speakerVoiceRole = iota
	speakerVoicePrimary
	speakerVoiceSecondary
)

func speakerVoiceMap(segments []contracts.AudioSegment, primary, secondary TTSProvider) map[string]TTSProvider {
	out := map[string]TTSProvider{}
	var unknown []string
	for _, seg := range segments {
		speaker := strings.TrimSpace(seg.Speaker)
		if speaker == "" {
			continue
		}
		if _, seen := out[speaker]; seen {
			continue
		}
		switch voiceRoleForSpeakerLabel(speaker) {
		case speakerVoicePrimary:
			out[speaker] = primary
		case speakerVoiceSecondary:
			out[speaker] = secondary
			if out[speaker] == nil {
				out[speaker] = primary
			}
		default:
			unknown = append(unknown, speaker)
		}
	}
	for _, speaker := range unknown {
		if _, seen := out[speaker]; seen {
			continue
		}
		if len(out) == 0 && secondary != nil {
			out[speaker] = secondary
		} else {
			out[speaker] = primary
		}
	}
	return out
}

func voiceRoleForSpeakerLabel(label string) speakerVoiceRole {
	normalized := normalizeSpeakerLabel(label)
	switch {
	case strings.Contains(normalized, "muz") || strings.Contains(normalized, "pan ") || normalized == "pan":
		return speakerVoiceSecondary
	case strings.Contains(normalized, "zena") || strings.Contains(normalized, "pani") || strings.Contains(normalized, "slecn"):
		return speakerVoicePrimary
	default:
		return speakerVoiceUnknown
	}
}

func normalizeSpeakerLabel(label string) string {
	lower := strings.ToLower(strings.TrimSpace(label))
	replacer := strings.NewReplacer(
		"á", "a", "č", "c", "ď", "d", "é", "e", "ě", "e", "í", "i",
		"ň", "n", "ó", "o", "ř", "r", "š", "s", "ť", "t", "ú", "u",
		"ů", "u", "ý", "y", "ž", "z",
	)
	return replacer.Replace(lower)
}

// Poslech1MissingTranscripts returns the QuestionNo of every poslech_1 item
// that is missing both an uploaded AssetID and a non-empty transcript. The
// admin generate-audio handler uses this to gate the per-item path:
// admins must either fill every item's transcript or upload audio for the
// gaps before per-item generation can run, otherwise the result is a
// partial set of asset_ids and Flutter silently falls back to legacy
// single-audio (the per-item gate requires every item to carry asset_id).
//
// Returns nil for non-poslech_1 exercises.
func Poslech1MissingTranscripts(exercise contracts.Exercise) []int {
	if exercise.ExerciseType != "poslech_1" {
		return nil
	}
	items := toListening1Detail(exercise.Detail)
	var missing []int
	for _, item := range items {
		if item.AudioSource.AssetID != "" {
			continue // uploaded — no transcript needed
		}
		if joinSegments(item.AudioSource.Segments) != "" {
			continue
		}
		missing = append(missing, item.QuestionNo)
	}
	return missing
}

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
	case "poslech_6":
		return buildAnoNeAudioText(exercise.Detail)
	}
	return ""
}

func buildAnoNeAudioText(detail any) string {
	passage := toAnoNePassage(detail)
	if passage == "" {
		return ""
	}
	// V39 — strip optional `[Speaker]:` line prefixes so single-voice
	// fallback never reads "Žena colon ..." literally. Multi-speaker
	// passages take the dialog path before reaching this function.
	segs := parseSpeakerPassage(passage)
	if len(segs) == 0 {
		return passage
	}
	return joinSegments(segs)
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

// SentenceExerciseAudioGenerator extends ExerciseAudioGenerator with V18
// per-sentence dictation audio. Each call writes one MP3 keyed by
// (exercise_id, sentence_idx). Implemented by both Dev and Polly generators.
type SentenceExerciseAudioGenerator interface {
	ExerciseAudioGenerator
	GenerateSentenceAudio(exerciseID string, sentenceIdx int, text string) (*contracts.ExerciseAudio, error)
}

// ItemAudioGenerator extends ExerciseAudioGenerator with V26 per-item poslech_1
// audio. Each call writes one MP3 (or WAV in dev) keyed by (exercise_id,
// item_no). The admin generate-audio endpoint uses a type assertion against
// this interface to fork the per-item branch for poslech_1.
type ItemAudioGenerator interface {
	ExerciseAudioGenerator
	GenerateItemAudio(exerciseID string, itemNo int, text string) (*contracts.ExerciseAudio, error)
}

// ItemDialogAudioGenerator extends ItemAudioGenerator with V39 per-item
// 2-voice synthesis for poslech_1. Segments are synthesized one by one
// using speaker-based voice routing (`[Muž]` → ttsB, `[Žena]` → primary
// voice), then concatenated into a single per-item MP3 stored at
// `exercise-audio/<exerciseID>/item-<itemNo>.mp3`. Implemented by Polly when
// a second TTS voice is wired; the admin handler falls back to flat
// GenerateItemAudio when the assertion fails or only one speaker is present.
type ItemDialogAudioGenerator interface {
	ItemAudioGenerator
	GenerateItemDialogAudio(exerciseID string, itemNo int, segments []contracts.AudioSegment) (*contracts.ExerciseAudio, error)
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
	case "poslech_6":
		// V39 — poslech_6 keeps a single Passage string on the wire, but the
		// admin can opt into 2-voice synthesis by prefixing lines with
		// `[Speaker]:`. We parse those markers into AudioSegments so the
		// shared HasMultipleSpeakers / BuildExerciseDialogSegments code path
		// can route them to the dialog generator. Passages without markers
		// produce a single anonymous segment, which keeps HasMultipleSpeakers
		// returning false and routes back to the flat passage path.
		return parseSpeakerPassage(toAnoNePassage(exercise.Detail))
	}
	return nil
}

// toAnoNePassage extracts the prose passage from an AnoNe detail blob. Returns
// "" when the detail does not unmarshal — callers treat empty passage as
// "nothing to synthesize" already.
func toAnoNePassage(v any) string {
	b, err := json.Marshal(v)
	if err != nil {
		return ""
	}
	var d struct {
		Passage string `json:"passage"`
	}
	if err := json.Unmarshal(b, &d); err != nil {
		return ""
	}
	return strings.TrimSpace(d.Passage)
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

// GenerateSentenceAudio for dev: writes a stub silent WAV per (exercise, sentence).
func (DevExerciseAudioGenerator) GenerateSentenceAudio(exerciseID string, sentenceIdx int, _ string) (*contracts.ExerciseAudio, error) {
	storageKey := fmt.Sprintf("exercise-audio/%s/sentence-%d.wav", exerciseID, sentenceIdx)
	dst := localExerciseAudioPath(storageKey)
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return nil, fmt.Errorf("dev sentence audio dir: %w", err)
	}
	if err := os.WriteFile(dst, devSilentWAV(), 0o644); err != nil {
		return nil, fmt.Errorf("dev sentence audio write: %w", err)
	}
	return &contracts.ExerciseAudio{
		ExerciseID:  exerciseID,
		StorageKey:  storageKey,
		MimeType:    "audio/wav",
		SourceType:  "dev",
		GeneratedAt: time.Now().UTC().Format(time.RFC3339),
	}, nil
}

// GenerateItemAudio for dev: writes a stub silent WAV per (exercise, item).
// V26 — used by poslech_1 per-item audio path.
func (DevExerciseAudioGenerator) GenerateItemAudio(exerciseID string, itemNo int, _ string) (*contracts.ExerciseAudio, error) {
	storageKey := fmt.Sprintf("exercise-audio/%s/item-%d.wav", exerciseID, itemNo)
	dst := localExerciseAudioPath(storageKey)
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return nil, fmt.Errorf("dev item audio dir: %w", err)
	}
	if err := os.WriteFile(dst, devSilentWAV(), 0o644); err != nil {
		return nil, fmt.Errorf("dev item audio write: %w", err)
	}
	return &contracts.ExerciseAudio{
		ExerciseID:  exerciseID,
		StorageKey:  storageKey,
		MimeType:    "audio/wav",
		SourceType:  "dev",
		GeneratedAt: time.Now().UTC().Format(time.RFC3339),
	}, nil
}

// GenerateItemDialogAudio for dev: writes a stub silent WAV per (exercise,
// item) — same storage shape as GenerateItemAudio. Speaker labels are
// ignored in dev mode (the stub never plays). V39.
func (DevExerciseAudioGenerator) GenerateItemDialogAudio(exerciseID string, itemNo int, _ []contracts.AudioSegment) (*contracts.ExerciseAudio, error) {
	return (DevExerciseAudioGenerator{}).GenerateItemAudio(exerciseID, itemNo, "")
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

// GenerateItemAudio for Polly: synthesizes one MP3 per poslech_1 item.
// Storage key is `exercise-audio/<exerciseID>/item-<n>.mp3` so each item is
// addressable independently of the merged whole-exercise audio file.
// V26 — mirrors GenerateSentenceAudio (V18 dictation pattern).
func (g *PollyExerciseAudioGenerator) GenerateItemAudio(exerciseID string, itemNo int, text string) (*contracts.ExerciseAudio, error) {
	if strings.TrimSpace(text) == "" {
		return nil, fmt.Errorf("exercise %s item %d: no text to synthesize", exerciseID, itemNo)
	}
	ttsResult, err := g.tts.Generate(fmt.Sprintf("%s-item-%d", exerciseID, itemNo), text)
	if err != nil {
		return nil, fmt.Errorf("polly item audio: %w", err)
	}
	storageKey := fmt.Sprintf("exercise-audio/%s/item-%d.mp3", exerciseID, itemNo)
	srcPath := localReviewAudioPath(ttsResult.StorageKey)
	dstPath := localExerciseAudioPath(storageKey)
	if err := os.MkdirAll(filepath.Dir(dstPath), 0o755); err != nil {
		return nil, fmt.Errorf("prepare item audio dir: %w", err)
	}
	data, err := os.ReadFile(srcPath)
	if err != nil {
		return nil, fmt.Errorf("read polly output: %w", err)
	}
	if err := os.WriteFile(dstPath, data, 0o644); err != nil {
		return nil, fmt.Errorf("write item audio: %w", err)
	}
	return &contracts.ExerciseAudio{
		ExerciseID:  exerciseID,
		StorageKey:  storageKey,
		MimeType:    "audio/mpeg",
		SourceType:  "polly",
		GeneratedAt: time.Now().UTC().Format(time.RFC3339),
	}, nil
}

// GenerateItemDialogAudio for Polly: synthesizes each segment of a single
// poslech_1 item with speaker-based voice assignment, concatenates the
// per-segment MP3 blobs, and writes the merged stream at
// `exercise-audio/<exerciseID>/item-<itemNo>.mp3`. Voice routing mirrors
// GenerateDialogAudio so `[Muž]` routes to ttsB and `[Žena]` routes to the
// primary voice regardless of which speaker appears first.
// V39 — fixes V26 per-item path that always used a single voice.
func (g *PollyExerciseAudioGenerator) GenerateItemDialogAudio(exerciseID string, itemNo int, segments []contracts.AudioSegment) (*contracts.ExerciseAudio, error) {
	if len(segments) == 0 {
		return nil, fmt.Errorf("exercise %s item %d: no dialog segments", exerciseID, itemNo)
	}

	speakerVoice := speakerVoiceMap(segments, g.tts, g.ttsB)

	var audioParts [][]byte
	for i, seg := range segments {
		var provider TTSProvider
		if speaker := strings.TrimSpace(seg.Speaker); speaker != "" {
			provider = speakerVoice[speaker]
		}
		if provider == nil {
			provider = g.tts
			if g.ttsB != nil && i%2 == 1 {
				provider = g.ttsB
			}
		}
		result, err := provider.Generate(fmt.Sprintf("%s-item-%d-seg-%d", exerciseID, itemNo, i), seg.Text)
		if err != nil {
			return nil, fmt.Errorf("generate item %d segment %d: %w", itemNo, i, err)
		}
		data, err := os.ReadFile(localReviewAudioPath(result.StorageKey))
		if err != nil {
			return nil, fmt.Errorf("read item %d segment %d audio: %w", itemNo, i, err)
		}
		audioParts = append(audioParts, data)
	}

	merged := concatMP3(audioParts)
	storageKey := fmt.Sprintf("exercise-audio/%s/item-%d.mp3", exerciseID, itemNo)
	dstPath := localExerciseAudioPath(storageKey)
	if err := os.MkdirAll(filepath.Dir(dstPath), 0o755); err != nil {
		return nil, fmt.Errorf("prepare item dialog audio dir: %w", err)
	}
	if err := os.WriteFile(dstPath, merged, 0o644); err != nil {
		return nil, fmt.Errorf("write item dialog audio: %w", err)
	}
	return &contracts.ExerciseAudio{
		ExerciseID:  exerciseID,
		StorageKey:  storageKey,
		MimeType:    "audio/mpeg",
		SourceType:  "polly",
		GeneratedAt: time.Now().UTC().Format(time.RFC3339),
	}, nil
}

// GenerateSentenceAudio for Polly: synthesizes one MP3 per dictation sentence.
// Storage key is `exercise-audio/<exerciseID>/sentence-<idx>.mp3` so each
// sentence is addressable independently of the whole-exercise audio file.
func (g *PollyExerciseAudioGenerator) GenerateSentenceAudio(exerciseID string, sentenceIdx int, text string) (*contracts.ExerciseAudio, error) {
	if strings.TrimSpace(text) == "" {
		return nil, fmt.Errorf("exercise %s sentence %d: no text to synthesize", exerciseID, sentenceIdx)
	}
	// TTSProvider.Generate writes under attempt-review/...; rewrite the
	// blob into the per-sentence exercise-audio path so it survives
	// across attempts and is reachable by the dictation result UI.
	ttsResult, err := g.tts.Generate(fmt.Sprintf("%s-sentence-%d", exerciseID, sentenceIdx), text)
	if err != nil {
		return nil, fmt.Errorf("polly sentence audio: %w", err)
	}
	storageKey := fmt.Sprintf("exercise-audio/%s/sentence-%d.mp3", exerciseID, sentenceIdx)
	srcPath := localReviewAudioPath(ttsResult.StorageKey)
	dstPath := localExerciseAudioPath(storageKey)
	if err := os.MkdirAll(filepath.Dir(dstPath), 0o755); err != nil {
		return nil, fmt.Errorf("prepare sentence audio dir: %w", err)
	}
	data, err := os.ReadFile(srcPath)
	if err != nil {
		return nil, fmt.Errorf("read polly output: %w", err)
	}
	if err := os.WriteFile(dstPath, data, 0o644); err != nil {
		return nil, fmt.Errorf("write sentence audio: %w", err)
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
		base = filepath.Join(os.TempDir(), "czech-go-system-assets")
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
// Voice mapping: labels like [Muž] route to ttsB and labels like [Žena] route
// to the primary voice, regardless of which speaker appears first.
func (g *PollyExerciseAudioGenerator) GenerateDialogAudio(exerciseID string, segments []contracts.AudioSegment) (*contracts.ExerciseAudio, error) {
	if len(segments) == 0 {
		return nil, fmt.Errorf("exercise %s: no dialog segments", exerciseID)
	}

	speakerVoice := speakerVoiceMap(segments, g.tts, g.ttsB)

	var audioParts [][]byte
	for i, seg := range segments {
		var provider TTSProvider
		if speaker := strings.TrimSpace(seg.Speaker); speaker != "" {
			provider = speakerVoice[speaker]
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
