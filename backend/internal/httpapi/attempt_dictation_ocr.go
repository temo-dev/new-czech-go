package httpapi

// attempt_dictation_ocr.go — V18.1 endpoints for psani_3_dictation handwriting
// OCR submission flow.
//
// Routes (registered in handleAttemptByID):
//   POST /v1/attempts/:id/dictation-ocr-preview   single-image preview (text + asset_id)
//
// The Submit endpoint (POST /v1/attempts/:id/submit-dictation-ocr) is wired in
// V18.1-B1.
//
// The preview endpoint runs Claude Vision once per sentence at the moment the
// learner taps "📷 Chụp ảnh", caches the result client-side, and returns the
// asset_id + recognized text. Final Submit re-uses those asset_ids without
// re-OCRing (cost saver). OCR failure is fail-soft: returns 200 with empty text
// so the learner can retake or type instead — never returns 5xx.

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"mime"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/processing"
)

const (
	// dictationOCRMaxImageBytes caps the multipart body for the preview endpoint.
	// Mirrors V17.2 avatar / V11 image-upload limits to keep the storage budget
	// predictable.
	dictationOCRMaxImageBytes = 5 * 1024 * 1024
	// dictationOCRStoragePrefix is the on-disk prefix under LOCAL_ASSETS_DIR.
	// One folder per attempt keeps eviction trivial (delete folder).
	dictationOCRStoragePrefix = "dictation-ocr"
	// dictationOCRPreviewLimit is the per-user RPM cap for the preview endpoint.
	dictationOCRPreviewLimit = 30
)

// dictationOCRRateLimiter enforces dictationOCRPreviewLimit requests per minute
// per user_id. Identical algorithm to aiImageRateLimiter / interviewPreviewLimiter
// but kept separate so quotas don't cross-contaminate features.
type dictationOCRRateLimiter struct {
	mu      sync.Mutex
	windows map[string]rateWindow
}

func newDictationOCRRateLimiter() *dictationOCRRateLimiter {
	return &dictationOCRRateLimiter{windows: make(map[string]rateWindow)}
}

func (rl *dictationOCRRateLimiter) allow(userID string) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()
	now := time.Now()
	w := rl.windows[userID]
	if now.After(w.windowEnd) {
		rl.windows[userID] = rateWindow{count: 1, windowEnd: now.Add(time.Minute)}
		return true
	}
	if w.count >= dictationOCRPreviewLimit {
		return false
	}
	w.count++
	rl.windows[userID] = w
	return true
}

// handleDictationOCRPreview serves POST /v1/attempts/:id/dictation-ocr-preview.
// Multipart fields:
//   - idx (form field): 0-indexed sentence number, 0..7
//   - image (file field): handwriting photo, ≤5MB, MIME jpeg/png/webp
//
// Returns DictationOCRPreviewResponse. OCR failure → 200 with empty `text`.
func (s *Server) handleDictationOCRPreview(w http.ResponseWriter, r *http.Request, user contracts.User, attemptID string) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}
	attempt, ok := s.authorizedAttemptForUser(w, user, attemptID)
	if !ok {
		return
	}
	exercise, ok := s.repo.Exercise(attempt.ExerciseID)
	if !ok || exercise.ExerciseType != "psani_3_dictation" {
		writeError(w, http.StatusBadRequest, "validation_error",
			"OCR preview is only available for dictation exercises.", false)
		return
	}
	if !s.dictationOCRRL.allow(user.ID) {
		writeError(w, http.StatusTooManyRequests, "rate_limited",
			"Too many OCR requests. Try again in a minute.", true)
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, dictationOCRMaxImageBytes+1024)
	if err := r.ParseMultipartForm(dictationOCRMaxImageBytes); err != nil {
		var maxErr *http.MaxBytesError
		if isMaxBytesError(err, &maxErr) {
			writeError(w, http.StatusRequestEntityTooLarge, "image_too_large",
				"Image must be under 5 MB.", false)
		} else {
			writeError(w, http.StatusBadRequest, "validation_error",
				"Invalid multipart form.", false)
		}
		return
	}

	idxRaw := strings.TrimSpace(r.FormValue("idx"))
	if idxRaw == "" {
		writeError(w, http.StatusBadRequest, "validation_error",
			"idx form field is required.", false)
		return
	}
	idx, err := strconv.Atoi(idxRaw)
	if err != nil || idx < 0 || idx > 7 {
		writeError(w, http.StatusBadRequest, "invalid_idx",
			"idx must be an integer between 0 and 7.", false)
		return
	}

	file, header, err := r.FormFile("image")
	if err != nil {
		writeError(w, http.StatusBadRequest, "validation_error",
			"image field is required.", false)
		return
	}
	defer file.Close()

	mimeType := header.Header.Get("Content-Type")
	if mimeType == "" {
		mimeType = mime.TypeByExtension(filepath.Ext(header.Filename))
	}
	if semi := strings.Index(mimeType, ";"); semi >= 0 {
		mimeType = strings.TrimSpace(mimeType[:semi])
	}
	ext, ok := allowedImageMIMEs[mimeType]
	if !ok {
		writeError(w, http.StatusUnsupportedMediaType, "image_invalid_type",
			"Image must be jpeg, png, or webp.", false)
		return
	}

	body, err := io.ReadAll(file)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error",
			"Could not read image upload.", true)
		return
	}

	// Persist before OCR so we always have an asset_id to echo back even
	// when OCR fails (learner can retake or type with the same image still
	// available for audit).
	storageKey := fmt.Sprintf("%s/%s/img-%d.%s",
		dictationOCRStoragePrefix, attemptID, time.Now().UTC().UnixNano(), ext)
	filePath := localExerciseAssetPath(storageKey)
	if err := os.MkdirAll(filepath.Dir(filePath), 0o755); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error",
			"Could not prepare image storage.", true)
		return
	}
	if err := os.WriteFile(filePath, body, 0o644); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error",
			"Could not write image file.", true)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 30*time.Second)
	defer cancel()
	text, _ := s.ocrProvider.OCRImage(ctx, mimeType, body) // fail-soft contract

	writeJSON(w, http.StatusOK, map[string]any{
		"data": contracts.DictationOCRPreviewResponse{
			Idx:     idx,
			Text:    text,
			AssetID: storageKey,
		},
		"meta": map[string]any{},
	})
}

// dictationOCRMaxSubmitBytes caps the multipart submit body. Practical worst
// case: 8 sentences × (asset_id ≤ 256 bytes + text ≤ 200 runes × 4 bytes ≈
// 1 KB) → ~8 KB. We allow 64 KB to absorb form overhead and any future audit
// fields. Keeps OOM risk low.
const dictationOCRMaxSubmitBytes = 64 * 1024

// handleSubmitDictationOCR serves POST /v1/attempts/:id/submit-dictation-ocr.
//
// Multipart fields:
//   - sentences (form field): JSON array shape `[{idx,text,asset_id,replay_count}, ...]`
//
// The handler converts the OCR submission into the V18 DictationSubmission
// shape and dispatches the same `ProcessDictationAttempt` goroutine. Score
// parity is enforced by reusing the deterministic Levenshtein scorer
// unchanged. `submission_mode="ocr"` is logged for analytics.
func (s *Server) handleSubmitDictationOCR(w http.ResponseWriter, r *http.Request, user contracts.User, attemptID string) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}
	attempt, ok := s.authorizedAttemptForUser(w, user, attemptID)
	if !ok {
		return
	}
	if attempt.Status != "created" {
		writeError(w, http.StatusConflict, "attempt_not_pending",
			"Attempt is not in the created state.", false)
		return
	}
	exercise, ok := s.repo.Exercise(attempt.ExerciseID)
	if !ok || exercise.ExerciseType != "psani_3_dictation" {
		writeError(w, http.StatusBadRequest, "validation_error",
			"OCR submission is only available for dictation exercises.", false)
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, dictationOCRMaxSubmitBytes+1024)
	if err := r.ParseMultipartForm(dictationOCRMaxSubmitBytes); err != nil {
		var maxErr *http.MaxBytesError
		if isMaxBytesError(err, &maxErr) {
			writeError(w, http.StatusRequestEntityTooLarge, "payload_too_large",
				"Submission payload exceeds 64 KB.", false)
		} else {
			writeError(w, http.StatusBadRequest, "validation_error",
				"Invalid multipart form.", false)
		}
		return
	}

	raw := strings.TrimSpace(r.FormValue("sentences"))
	if raw == "" {
		writeError(w, http.StatusBadRequest, "validation_error",
			"sentences form field is required.", false)
		return
	}
	var rows []contracts.DictationOCRSentenceSubmission
	if err := json.Unmarshal([]byte(raw), &rows); err != nil {
		writeError(w, http.StatusBadRequest, "validation_error",
			"sentences must be a JSON array.", false)
		return
	}

	detail, ok := processing.ExtractDictationDetail(exercise.Detail)
	if !ok || len(detail.Sentences) == 0 {
		writeError(w, http.StatusInternalServerError, "internal_error",
			"Exercise detail missing.", true)
		return
	}

	sub := convertOCRSubmissionToDictation(rows)
	if err := processing.ValidateDictationSubmission(detail, sub); err != nil {
		var ve processing.DictationValidationError
		if errors.As(err, &ve) {
			writeError(w, http.StatusBadRequest, ve.Code, err.Error(), false)
			return
		}
		writeError(w, http.StatusBadRequest, "validation_error", err.Error(), false)
		return
	}

	s.repo.SetAttemptStatus(attemptID, "scoring")
	log.Printf("dictation submit attempt=%s submission_mode=ocr sentences=%d",
		attemptID, len(sub.Sentences))
	go s.processor.ProcessDictationAttempt(attemptID, sub)

	writeJSON(w, http.StatusAccepted, map[string]any{
		"data": map[string]any{"attempt_id": attemptID, "status": "scoring"},
		"meta": map[string]any{},
	})
}

// convertOCRSubmissionToDictation maps the V18.1 OCR rows into the V18
// DictationSubmission shape consumed by ProcessDictationAttempt. AssetID is
// dropped from the scorer-facing payload — only Idx + Text + ReplayCount
// affect scoring (asset is only used by audit/server-side workflows).
func convertOCRSubmissionToDictation(rows []contracts.DictationOCRSentenceSubmission) contracts.DictationSubmission {
	out := contracts.DictationSubmission{
		Sentences: make([]contracts.DictationSentenceAnswer, 0, len(rows)),
	}
	for _, r := range rows {
		out.Sentences = append(out.Sentences, contracts.DictationSentenceAnswer{
			Idx:         r.Idx,
			Text:        r.Text,
			ReplayCount: r.ReplayCount,
		})
	}
	return out
}
