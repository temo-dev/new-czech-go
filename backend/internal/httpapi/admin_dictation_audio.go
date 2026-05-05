package httpapi

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/processing"
)

// admin_dictation_audio.go — V18 admin endpoints for per-sentence dictation audio.
//
// Routes (registered by handleAdminExerciseByID):
//   POST   /v1/admin/exercises/:id/dictation/sentences/:idx/audio
//   DELETE /v1/admin/exercises/:id/dictation/sentences/:idx/audio
//
// POST body: {"text": "<Czech sentence>"}. Polly synthesises the MP3,
// the blob is written to LOCAL_ASSETS_DIR/<storage_key>, and the
// (exercise_id, sentence_idx) row is upserted in exercise_sentence_audio.
//
// DELETE removes both the row and the file on disk (best-effort).

// dictationAudioRequest is the JSON body of the POST endpoint.
type dictationAudioRequest struct {
	Text string `json:"text"`
}

const dictationSentenceTextMaxBytes = 1024 // ample for ≤250 Czech chars (UTF-8 worst-case ~4× rune)

func (s *Server) handleAdminDictationSentenceAudio(w http.ResponseWriter, r *http.Request, exerciseID string, sentenceIdx int) {
	switch r.Method {
	case http.MethodPost:
		s.handleAdminDictationSentenceAudioPost(w, r, exerciseID, sentenceIdx)
	case http.MethodDelete:
		s.handleAdminDictationSentenceAudioDelete(w, r, exerciseID, sentenceIdx)
	default:
		writeMethodNotAllowed(w)
	}
}

func (s *Server) handleAdminDictationSentenceAudioPost(w http.ResponseWriter, r *http.Request, exerciseID string, sentenceIdx int) {
	if _, ok := s.repo.Exercise(exerciseID); !ok {
		writeNotFound(w)
		return
	}
	gen, ok := s.audioGenerator.(processing.SentenceExerciseAudioGenerator)
	if !ok {
		writeError(w, http.StatusServiceUnavailable, "audio_unavailable", "Sentence audio generation is not configured.", true)
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, dictationSentenceTextMaxBytes)
	defer r.Body.Close()
	var req dictationAudioRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "validation_error", "Invalid request body.", false)
		return
	}
	text := strings.TrimSpace(req.Text)
	if text == "" {
		writeError(w, http.StatusBadRequest, "validation_error", "Text is required.", false)
		return
	}
	if len([]rune(text)) > 250 {
		writeError(w, http.StatusBadRequest, "validation_error", "Sentence is too long (max 250 characters).", false)
		return
	}

	audio, err := gen.GenerateSentenceAudio(exerciseID, sentenceIdx, text)
	if err != nil {
		log.Printf("dictation sentence audio gen ex=%s idx=%d: %v", exerciseID, sentenceIdx, err)
		writeError(w, http.StatusInternalServerError, "internal_error", "Audio generation failed.", true)
		return
	}
	s.repo.SetSentenceAudio(exerciseID, sentenceIdx, *audio)

	writeJSON(w, http.StatusOK, map[string]any{
		"data": map[string]any{
			"exercise_id":  exerciseID,
			"sentence_idx": sentenceIdx,
			"storage_key":  audio.StorageKey,
			"mime_type":    audio.MimeType,
			"source_type":  audio.SourceType,
			"generated_at": audio.GeneratedAt,
		},
		"meta": map[string]any{},
	})
}

func (s *Server) handleAdminDictationSentenceAudioDelete(w http.ResponseWriter, _ *http.Request, exerciseID string, sentenceIdx int) {
	existing, _ := s.repo.SentenceAudio(exerciseID, sentenceIdx)
	if err := s.repo.DeleteSentenceAudio(exerciseID, sentenceIdx); err != nil {
		log.Printf("delete sentence audio ex=%s idx=%d: %v", exerciseID, sentenceIdx, err)
		writeError(w, http.StatusInternalServerError, "internal_error", "Failed to delete sentence audio.", true)
		return
	}
	if existing != nil {
		// Best-effort blob removal — log but don't fail the request if the file
		// is already gone (e.g. dev WAV in /tmp wiped by reboot).
		path := filepath.Join(localAssetsDir(), existing.StorageKey)
		if err := os.Remove(path); err != nil && !os.IsNotExist(err) {
			log.Printf("delete sentence audio blob path=%s: %v", path, err)
		}
	}
	w.WriteHeader(http.StatusNoContent)
}

// localAssetsDir mirrors processing.localExerciseAudioPath's base resolution.
func localAssetsDir() string {
	if v := strings.TrimSpace(os.Getenv("LOCAL_ASSETS_DIR")); v != "" {
		return v
	}
	return "/tmp/czech-go-assets"
}

// parseDictationSentencePath extracts (exerciseID, sentenceIdx) from a path
// shaped `<exerciseID>/dictation/sentences/<idx>/audio`. Returns ok=false on
// any structural problem so the dispatcher can 404 cleanly.
func parseDictationSentencePath(path string) (exerciseID string, sentenceIdx int, ok bool) {
	const marker = "/dictation/sentences/"
	i := strings.Index(path, marker)
	if i <= 0 {
		return "", 0, false
	}
	exerciseID = path[:i]
	rest := path[i+len(marker):]
	rest = strings.TrimSuffix(rest, "/audio")
	if rest == "" || strings.Contains(rest, "/") {
		return "", 0, false
	}
	idx := 0
	for _, r := range rest {
		if r < '0' || r > '9' {
			return "", 0, false
		}
		idx = idx*10 + int(r-'0')
		if idx > 1000 {
			return "", 0, false // sanity cap
		}
	}
	return exerciseID, idx, true
}

// Compile-time interface assertion: contracts.ExerciseAudio is the wire shape
// used by both POST responses and DELETE preflight reads.
var _ = contracts.ExerciseAudio{}
