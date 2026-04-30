package httpapi

import (
	"fmt"
	"io"
	"mime"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// allowedImageMIMEs lists accepted MIME types for item images.
var allowedImageMIMEs = map[string]string{
	"image/jpeg": "jpg",
	"image/jpg":  "jpg",
	"image/png":  "png",
	"image/webp": "webp",
}

const maxImageBytes = 5 * 1024 * 1024 // 5 MB

// ── Vocabulary Item Image ─────────────────────────────────────────────────────

func (s *Server) handleAdminVocabItemImage(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	itemID := strings.TrimPrefix(r.URL.Path, "/v1/admin/vocabulary-items/")
	itemID = strings.TrimSuffix(itemID, "/image")
	if itemID == "" {
		writeNotFound(w)
		return
	}

	switch r.Method {
	case http.MethodPost:
		s.uploadItemImage(w, r, itemID, "vocabulary-images", s.repo.SetVocabularyItemImage)
	case http.MethodDelete:
		if !s.repo.SetVocabularyItemImage(itemID, "") {
			writeNotFound(w)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"data": map[string]any{"id": itemID, "image_asset_id": ""}, "meta": map[string]any{}})
	default:
		writeMethodNotAllowed(w)
	}
}

func (s *Server) handleVocabItemImageFile(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	if r.Method != http.MethodGet {
		writeMethodNotAllowed(w)
		return
	}
	itemID := strings.TrimPrefix(r.URL.Path, "/v1/vocabulary-items/")
	itemID = strings.TrimSuffix(itemID, "/image/file")
	if itemID == "" {
		writeNotFound(w)
		return
	}
	item, ok := s.repo.GetVocabularyItem(itemID)
	if !ok || item.ImageAssetID == "" {
		writeNotFound(w)
		return
	}
	serveLocalAssetFile(w, r, item.ImageAssetID)
}

// ── Grammar Rule Image ────────────────────────────────────────────────────────

func (s *Server) handleAdminGrammarRuleImage(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	ruleID := strings.TrimPrefix(r.URL.Path, "/v1/admin/grammar-rules/")
	ruleID = strings.TrimSuffix(ruleID, "/image")
	if ruleID == "" {
		writeNotFound(w)
		return
	}

	switch r.Method {
	case http.MethodPost:
		s.uploadItemImage(w, r, ruleID, "grammar-images", s.repo.SetGrammarRuleImage)
	case http.MethodDelete:
		if !s.repo.SetGrammarRuleImage(ruleID, "") {
			writeNotFound(w)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"data": map[string]any{"id": ruleID, "image_asset_id": ""}, "meta": map[string]any{}})
	default:
		writeMethodNotAllowed(w)
	}
}

func (s *Server) handleGrammarRuleImageFile(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	if r.Method != http.MethodGet {
		writeMethodNotAllowed(w)
		return
	}
	ruleID := strings.TrimPrefix(r.URL.Path, "/v1/grammar-rules/")
	ruleID = strings.TrimSuffix(ruleID, "/image/file")
	if ruleID == "" {
		writeNotFound(w)
		return
	}
	rule, ok := s.repo.GetGrammarRule(ruleID)
	if !ok || rule.ImageAssetID == "" {
		writeNotFound(w)
		return
	}
	serveLocalAssetFile(w, r, rule.ImageAssetID)
}

// ── Shared helpers ────────────────────────────────────────────────────────────

// uploadItemImage handles multipart image upload for vocab items and grammar rules.
// storagePrefix is "vocabulary-images" or "grammar-images".
// setImage is the store method to call on success.
func (s *Server) uploadItemImage(w http.ResponseWriter, r *http.Request, entityID, storagePrefix string, setImage func(id, key string) bool) {
	r.Body = http.MaxBytesReader(w, r.Body, maxImageBytes+1024)
	if err := r.ParseMultipartForm(maxImageBytes); err != nil {
		var maxErr *http.MaxBytesError
		if isMaxBytesError(err, &maxErr) {
			writeError(w, http.StatusRequestEntityTooLarge, "payload_too_large", "Image must be under 5 MB.", false)
		} else {
			writeError(w, http.StatusBadRequest, "validation_error", "Invalid multipart form.", false)
		}
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		writeError(w, http.StatusBadRequest, "validation_error", "file field is required.", false)
		return
	}
	defer file.Close()

	mimeType := header.Header.Get("Content-Type")
	if mimeType == "" {
		mimeType = mime.TypeByExtension(filepath.Ext(header.Filename))
	}
	// Normalize: drop charset suffix
	if idx := strings.Index(mimeType, ";"); idx >= 0 {
		mimeType = strings.TrimSpace(mimeType[:idx])
	}
	ext, ok := allowedImageMIMEs[mimeType]
	if !ok {
		writeError(w, http.StatusUnsupportedMediaType, "unsupported_media_type", "Image must be jpeg, png, or webp.", false)
		return
	}

	assetID := fmt.Sprintf("img-%d", time.Now().UTC().UnixNano())
	storageKey := fmt.Sprintf("%s/%s/%s.%s", storagePrefix, entityID, assetID, ext)
	filePath := localExerciseAssetPath(storageKey)

	if err := os.MkdirAll(filepath.Dir(filePath), 0o755); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not prepare image storage.", true)
		return
	}
	dst, err := os.Create(filePath)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not open image storage.", true)
		return
	}
	defer dst.Close()

	size, err := io.Copy(dst, file)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "upload_failed", "Could not store uploaded image.", true)
		return
	}
	_ = size

	if !setImage(entityID, storageKey) {
		writeNotFound(w)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"data": map[string]any{
			"image_asset_id": storageKey,
			"mime_type":      mimeType,
		},
		"meta": map[string]any{},
	})
}

// serveLocalAssetFile streams a local asset file identified by its storage key.
func serveLocalAssetFile(w http.ResponseWriter, r *http.Request, storageKey string) {
	filePath := localExerciseAssetPath(storageKey)
	f, err := os.Open(filePath)
	if err != nil {
		writeNotFound(w)
		return
	}
	defer f.Close()

	ext := strings.ToLower(filepath.Ext(filePath))
	ct := mime.TypeByExtension(ext)
	if ct == "" {
		ct = "application/octet-stream"
	}
	w.Header().Set("Content-Type", ct)
	w.Header().Set("Cache-Control", "public, max-age=86400")
	io.Copy(w, f)
}

// isMaxBytesError checks if err is an *http.MaxBytesError (Go 1.19+).
func isMaxBytesError(err error, target **http.MaxBytesError) bool {
	if e, ok := err.(*http.MaxBytesError); ok {
		if target != nil {
			*target = e
		}
		return true
	}
	return false
}
