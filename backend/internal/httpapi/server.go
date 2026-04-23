package httpapi

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/processing"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

type Server struct {
	repo           *store.MemoryStore
	processor      *processing.Processor
	uploadProvider UploadTargetProvider
	mux            *http.ServeMux
}

func NewServer(repo *store.MemoryStore, processor *processing.Processor, uploadProvider UploadTargetProvider) http.Handler {
	if processor == nil {
		processor = processing.NewProcessor(repo, nil, nil)
	}
	if uploadProvider == nil {
		uploadProvider = NewLocalUploadTargetProvider()
	}
	s := &Server{
		repo:           repo,
		processor:      processor,
		uploadProvider: uploadProvider,
		mux:            http.NewServeMux(),
	}
	s.routes()
	return s.withRequestLog(s.withCORS(s.mux))
}

func (s *Server) routes() {
	s.mux.HandleFunc("/healthz", s.handleHealth)
	s.mux.HandleFunc("/v1/auth/login", s.handleLogin)
	s.mux.HandleFunc("/v1/me", s.withAuth(s.handleMe))
	s.mux.HandleFunc("/v1/course", s.withAuth(s.handleCourse))
	s.mux.HandleFunc("/v1/plan", s.withAuth(s.handlePlan))
	s.mux.HandleFunc("/v1/modules", s.withAuth(s.handleModules))
	s.mux.HandleFunc("/v1/modules/", s.withAuth(s.handleModuleExercises))
	s.mux.HandleFunc("/v1/exercises/", s.withAuth(s.handleExercise))
	s.mux.HandleFunc("/v1/attempts", s.withAuth(s.handleAttempts))
	s.mux.HandleFunc("/v1/attempts/", s.withAuth(s.handleAttemptByID))
	s.mux.HandleFunc("/v1/mock-exams", s.withAuth(s.handleMockExams))
	s.mux.HandleFunc("/v1/mock-exams/", s.withAuth(s.handleMockExamByID))
	s.mux.HandleFunc("/v1/admin/exercises", s.withRole("admin", s.handleAdminExercises))
	s.mux.HandleFunc("/v1/admin/exercises/", s.withRole("admin", s.handleAdminExerciseByID))
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"data": map[string]any{
			"status":  "ok",
			"service": "czech-go-system-backend",
		},
		"meta": map[string]any{},
	})
}

func (s *Server) handleLogin(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}
	var req struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "validation_error", "Invalid login payload.", false)
		return
	}
	token, user, ok := s.repo.Login(req.Email, req.Password)
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized", "Invalid credentials.", false)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"data": map[string]any{
			"access_token":   token,
			"token_type":     "Bearer",
			"expires_in_sec": 3600,
			"user":           user,
		},
		"meta": map[string]any{},
	})
}

func (s *Server) handleMe(w http.ResponseWriter, _ *http.Request, user contracts.User) {
	writeJSON(w, http.StatusOK, map[string]any{"data": user, "meta": map[string]any{}})
}

func (s *Server) handleCourse(w http.ResponseWriter, _ *http.Request, _ contracts.User) {
	writeJSON(w, http.StatusOK, map[string]any{
		"data": map[string]any{
			"course":        s.repo.Course(),
			"learning_plan": s.repo.Plan(),
		},
		"meta": map[string]any{},
	})
}

func (s *Server) handlePlan(w http.ResponseWriter, _ *http.Request, _ contracts.User) {
	writeJSON(w, http.StatusOK, map[string]any{
		"data": map[string]any{
			"current_day": s.repo.Plan().CurrentDay,
			"days": []map[string]any{
				{"day": 1, "label": "Lam quen voi cau hoi theo chu de", "status": "current", "module_id": "module-day-1"},
				{"day": 2, "label": "Ke chuyen theo tranh", "status": "upcoming", "module_id": "module-day-2"},
				{"day": 3, "label": "Mock oral exam", "status": "upcoming", "module_id": "module-mock"},
			},
		},
		"meta": map[string]any{},
	})
}

func (s *Server) handleModules(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	writeJSON(w, http.StatusOK, map[string]any{
		"data": s.repo.Modules(r.URL.Query().Get("kind")),
		"meta": map[string]any{},
	})
}

func (s *Server) handleModuleExercises(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	if !strings.HasSuffix(r.URL.Path, "/exercises") || r.Method != http.MethodGet {
		writeNotFound(w)
		return
	}
	moduleID := strings.TrimSuffix(strings.TrimPrefix(r.URL.Path, "/v1/modules/"), "/exercises")
	writeJSON(w, http.StatusOK, map[string]any{
		"data": s.repo.ExercisesByModule(moduleID),
		"meta": map[string]any{},
	})
}

func (s *Server) handleExercise(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	path := strings.TrimPrefix(r.URL.Path, "/v1/exercises/")
	if strings.Contains(path, "/assets/") && strings.HasSuffix(path, "/file") {
		exerciseID, assetID, ok := splitExerciseAssetPath(path, "file")
		if !ok {
			writeNotFound(w)
			return
		}
		s.handleLearnerAssetFile(w, r, exerciseID, assetID)
		return
	}

	if r.Method != http.MethodGet {
		writeMethodNotAllowed(w)
		return
	}
	exercise, ok := s.repo.Exercise(path)
	if !ok {
		writeNotFound(w)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": exercise, "meta": map[string]any{}})
}

func (s *Server) handleAttempts(w http.ResponseWriter, r *http.Request, user contracts.User) {
	switch r.Method {
	case http.MethodGet:
		attempts := s.visibleAttemptsForUser(user)
		writeJSON(w, http.StatusOK, map[string]any{
			"data": attempts,
			"meta": map[string]any{"next_cursor": nil},
		})
	case http.MethodPost:
		var req struct {
			ExerciseID     string `json:"exercise_id"`
			ClientPlatform string `json:"client_platform"`
			AppVersion     string `json:"app_version"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.ExerciseID == "" {
			writeError(w, http.StatusBadRequest, "validation_error", "Exercise ID is required.", false)
			return
		}
		clientPlatform := req.ClientPlatform
		if clientPlatform == "" {
			clientPlatform = "unknown"
		}
		attempt, err := s.repo.CreateAttempt(user.ID, req.ExerciseID, clientPlatform, req.AppVersion)
		if err != nil {
			writeError(w, http.StatusNotFound, "not_found", "Exercise not found.", false)
			return
		}
		writeJSON(w, http.StatusCreated, map[string]any{
			"data": map[string]any{"attempt": attempt},
			"meta": map[string]any{},
		})
	default:
		writeMethodNotAllowed(w)
	}
}

func (s *Server) visibleAttemptsForUser(user contracts.User) []contracts.Attempt {
	items := s.repo.ListAttempts()
	visible := make([]contracts.Attempt, 0, len(items))
	for _, attempt := range items {
		if user.Role == "admin" || attempt.UserID == user.ID {
			visible = append(visible, attempt)
		}
	}

	sort.SliceStable(visible, func(i, j int) bool {
		left := parseRFC3339OrZero(visible[i].StartedAt)
		right := parseRFC3339OrZero(visible[j].StartedAt)
		if left.Equal(right) {
			return attemptSequenceOrZero(visible[i].ID) > attemptSequenceOrZero(visible[j].ID)
		}
		return left.After(right)
	})

	return visible
}

func (s *Server) handleAttemptByID(w http.ResponseWriter, r *http.Request, user contracts.User) {
	path := strings.TrimPrefix(r.URL.Path, "/v1/attempts/")
	if strings.HasSuffix(path, "/review/audio/file") {
		s.handleAttemptReviewAudioFile(w, r, user, strings.TrimSuffix(path, "/review/audio/file"))
		return
	}
	if strings.HasSuffix(path, "/review") {
		s.handleAttemptReview(w, r, user, strings.TrimSuffix(path, "/review"))
		return
	}
	if strings.HasSuffix(path, "/recording-started") {
		s.handleRecordingStarted(w, r, strings.TrimSuffix(path, "/recording-started"))
		return
	}
	if strings.HasSuffix(path, "/audio/file") {
		s.handleAttemptAudioFile(w, r, user, strings.TrimSuffix(path, "/audio/file"))
		return
	}
	if strings.HasSuffix(path, "/audio") {
		s.handleAttemptAudioUpload(w, r, strings.TrimSuffix(path, "/audio"))
		return
	}
	if strings.HasSuffix(path, "/upload-url") {
		s.handleUploadURL(w, r, strings.TrimSuffix(path, "/upload-url"))
		return
	}
	if strings.HasSuffix(path, "/upload-complete") {
		s.handleUploadComplete(w, r, strings.TrimSuffix(path, "/upload-complete"))
		return
	}
	if r.Method != http.MethodGet {
		writeMethodNotAllowed(w)
		return
	}
	attempt, ok := s.repo.Attempt(path)
	if !ok {
		writeNotFound(w)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": attempt, "meta": map[string]any{}})
}

func (s *Server) handleAttemptReview(w http.ResponseWriter, r *http.Request, user contracts.User, attemptID string) {
	if r.Method != http.MethodGet {
		writeMethodNotAllowed(w)
		return
	}

	attempt, ok := s.authorizedAttemptForUser(w, user, attemptID)
	if !ok {
		return
	}

	if artifact, ok := s.repo.ReviewArtifact(attemptID); ok {
		writeJSON(w, http.StatusOK, map[string]any{"data": artifact, "meta": map[string]any{}})
		return
	}

	pending := contracts.AttemptReviewArtifact{
		AttemptID: attemptID,
		Status:    "pending",
	}
	if attempt.ReviewArtifact != nil {
		pending.Status = attempt.ReviewArtifact.Status
		pending.FailureCode = attempt.ReviewArtifact.FailureCode
		pending.GeneratedAt = attempt.ReviewArtifact.GeneratedAt
		pending.RepairProvider = attempt.ReviewArtifact.RepairProvider
	}

	writeJSON(w, http.StatusOK, map[string]any{"data": pending, "meta": map[string]any{}})
}

func (s *Server) handleAttemptReviewAudioFile(w http.ResponseWriter, r *http.Request, user contracts.User, attemptID string) {
	if r.Method != http.MethodGet {
		writeMethodNotAllowed(w)
		return
	}

	if _, ok := s.authorizedAttemptForUser(w, user, attemptID); !ok {
		return
	}

	artifact, ok := s.repo.ReviewArtifact(attemptID)
	if !ok || artifact.TTSAudio == nil {
		log.Printf("attempt review audio missing: attempt_id=%s user_id=%s", attemptID, user.ID)
		writeNotFound(w)
		return
	}

	audio := artifact.TTSAudio
	if strings.HasPrefix(audio.StorageKey, "http://") || strings.HasPrefix(audio.StorageKey, "https://") {
		log.Printf("attempt review audio redirect: attempt_id=%s storage_key=%q", attemptID, audio.StorageKey)
		http.Redirect(w, r, audio.StorageKey, http.StatusTemporaryRedirect)
		return
	}

	filePath := processing.ReviewAudioLocalPath(audio.StorageKey)
	file, err := os.Open(filePath)
	if err != nil {
		log.Printf(
			"attempt review audio open failed: attempt_id=%s storage_key=%q local_review_audio_path=%q error=%v",
			attemptID,
			audio.StorageKey,
			filePath,
			err,
		)
		writeNotFound(w)
		return
	}
	defer file.Close()

	if audio.MimeType != "" {
		w.Header().Set("Content-Type", audio.MimeType)
	}
	w.WriteHeader(http.StatusOK)
	_, _ = io.Copy(w, file)
}

func (s *Server) authorizedAttemptForUser(w http.ResponseWriter, user contracts.User, attemptID string) (*contracts.Attempt, bool) {
	attempt, ok := s.repo.Attempt(attemptID)
	if !ok {
		writeNotFound(w)
		return nil, false
	}
	if user.Role != "admin" && attempt.UserID != user.ID {
		writeError(w, http.StatusForbidden, "forbidden", "You do not have access to this resource.", false)
		return nil, false
	}
	return attempt, true
}

func (s *Server) handleAttemptAudioFile(w http.ResponseWriter, r *http.Request, user contracts.User, attemptID string) {
	if r.Method != http.MethodGet {
		writeMethodNotAllowed(w)
		return
	}
	attempt, ok := s.repo.Attempt(attemptID)
	if !ok {
		log.Printf("attempt audio file not found: attempt_id=%s user_id=%s", attemptID, user.ID)
		writeNotFound(w)
		return
	}
	if user.Role != "admin" && attempt.UserID != user.ID {
		log.Printf(
			"attempt audio file forbidden: attempt_id=%s attempt_user_id=%s requester_user_id=%s role=%s",
			attemptID,
			attempt.UserID,
			user.ID,
			user.Role,
		)
		writeError(w, http.StatusForbidden, "forbidden", "You do not have access to this resource.", false)
		return
	}
	if attempt.Audio == nil {
		log.Printf("attempt audio missing: attempt_id=%s user_id=%s", attemptID, user.ID)
		writeNotFound(w)
		return
	}

	audio := attempt.Audio
	if strings.HasPrefix(audio.StorageKey, "http://") || strings.HasPrefix(audio.StorageKey, "https://") {
		log.Printf("attempt audio redirect: attempt_id=%s storage_key=%q", attemptID, audio.StorageKey)
		http.Redirect(w, r, audio.StorageKey, http.StatusTemporaryRedirect)
		return
	}
	if strings.TrimSpace(audio.StoredFilePath) == "" {
		log.Printf("attempt audio missing stored file path: attempt_id=%s storage_key=%q", attemptID, audio.StorageKey)
		writeNotFound(w)
		return
	}

	file, err := os.Open(audio.StoredFilePath)
	if err != nil {
		log.Printf(
			"attempt audio open failed: attempt_id=%s storage_key=%q stored_file_path=%q error=%v",
			attemptID,
			audio.StorageKey,
			audio.StoredFilePath,
			err,
		)
		writeNotFound(w)
		return
	}
	defer file.Close()

	if audio.MimeType != "" {
		w.Header().Set("Content-Type", audio.MimeType)
	}
	w.WriteHeader(http.StatusOK)
	_, _ = io.Copy(w, file)
}

func (s *Server) handleRecordingStarted(w http.ResponseWriter, r *http.Request, attemptID string) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}
	var req struct {
		RecordingStartedAt string `json:"recording_started_at"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.RecordingStartedAt == "" {
		req.RecordingStartedAt = time.Now().UTC().Format(time.RFC3339)
	}
	attempt, ok := s.repo.UpdateAttemptRecordingStarted(attemptID, req.RecordingStartedAt)
	if !ok {
		writeNotFound(w)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"data": map[string]any{
			"attempt_id": attempt.ID,
			"status":     attempt.Status,
		},
		"meta": map[string]any{},
	})
}

func (s *Server) handleUploadURL(w http.ResponseWriter, r *http.Request, attemptID string) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}
	var req struct {
		MimeType      string `json:"mime_type"`
		FileSizeBytes int    `json:"file_size_bytes"`
		DurationMs    int    `json:"duration_ms"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.MimeType == "" {
		writeError(w, http.StatusBadRequest, "validation_error", "Upload metadata is required.", false)
		return
	}
	if _, ok := s.repo.Attempt(attemptID); !ok {
		writeNotFound(w)
		return
	}
	target, err := s.uploadProvider.CreateAttemptUploadTarget(r.Context(), AttemptUploadTargetInput{
		AttemptID:     attemptID,
		MimeType:      req.MimeType,
		FileSizeBytes: req.FileSizeBytes,
		DurationMs:    req.DurationMs,
		BaseURL:       buildAbsoluteURL(r, ""),
	})
	if err != nil {
		log.Printf(
			"attempt upload target failed: attempt_id=%s mime_type=%q file_size_bytes=%d duration_ms=%d error=%v",
			attemptID,
			req.MimeType,
			req.FileSizeBytes,
			req.DurationMs,
			err,
		)
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not prepare upload target.", true)
		return
	}
	if strings.TrimSpace(target.StorageKey) == "" {
		writeError(w, http.StatusInternalServerError, "internal_error", "Upload target is missing a storage key.", true)
		return
	}
	s.repo.RecordUploadTargetIssued(attemptID, target.StorageKey)
	writeJSON(w, http.StatusOK, map[string]any{
		"data": map[string]any{"upload": target},
		"meta": map[string]any{},
	})
}

func (s *Server) handleAttemptAudioUpload(w http.ResponseWriter, r *http.Request, attemptID string) {
	if r.Method != http.MethodPut {
		writeMethodNotAllowed(w)
		return
	}
	if _, ok := s.repo.Attempt(attemptID); !ok {
		writeNotFound(w)
		return
	}
	mimeType := strings.TrimSpace(r.Header.Get("Content-Type"))
	if mimeType == "" {
		writeError(w, http.StatusBadRequest, "validation_error", "Content-Type is required.", false)
		return
	}

	storageKey := fmt.Sprintf("attempt-audio/%s/audio.%s", attemptID, extensionForMime(mimeType))
	filePath := filepath.Join(
		os.TempDir(),
		"czech-go-system",
		filepath.FromSlash(storageKey),
	)
	if err := os.MkdirAll(filepath.Dir(filePath), 0o755); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not prepare audio storage.", true)
		return
	}

	file, err := os.Create(filePath)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not open audio storage.", true)
		return
	}
	defer file.Close()

	size, err := io.Copy(file, r.Body)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "upload_failed", "Could not store uploaded audio.", true)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"data": map[string]any{
			"attempt_id":       attemptID,
			"storage_key":      storageKey,
			"stored_file_path": filePath,
			"size_bytes":       size,
			"mime_type":        mimeType,
		},
		"meta": map[string]any{},
	})
}

func (s *Server) handleUploadComplete(w http.ResponseWriter, r *http.Request, attemptID string) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}
	var req struct {
		StorageKey     string `json:"storage_key"`
		MimeType       string `json:"mime_type"`
		DurationMs     int    `json:"duration_ms"`
		SampleRateHz   int    `json:"sample_rate_hz"`
		Channels       int    `json:"channels"`
		FileSizeBytes  int    `json:"file_size_bytes"`
		StoredFilePath string `json:"stored_file_path"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "validation_error", "Upload completion payload is required.", false)
		return
	}
	attempt, ok := s.repo.Attempt(attemptID)
	if !ok {
		writeNotFound(w)
		return
	}
	expectedStorageKey := strings.TrimSpace(attempt.PendingUploadStorageKey)
	if expectedStorageKey == "" {
		writeError(w, http.StatusConflict, "conflict", "Request an upload target before completing the upload.", false)
		return
	}
	storageKey := strings.TrimSpace(req.StorageKey)
	if storageKey == "" {
		storageKey = expectedStorageKey
	}
	if storageKey != expectedStorageKey {
		writeError(w, http.StatusConflict, "conflict", "Upload completion does not match the issued upload target.", false)
		return
	}
	audio := contracts.AttemptAudio{
		StorageKey:     storageKey,
		MimeType:       req.MimeType,
		DurationMs:     req.DurationMs,
		SampleRateHz:   req.SampleRateHz,
		Channels:       req.Channels,
		FileSizeBytes:  req.FileSizeBytes,
		StoredFilePath: req.StoredFilePath,
	}
	if _, ok := s.repo.MarkUploadComplete(attemptID, audio); !ok {
		writeNotFound(w)
		return
	}
	go func() {
		if err := s.processor.ProcessAttempt(attemptID); err != nil {
			log.Printf("attempt %s processing error: %v", attemptID, err)
		}
	}()
	writeJSON(w, http.StatusOK, map[string]any{
		"data": map[string]any{
			"attempt_id": attemptID,
			"status":     "transcribing",
		},
		"meta": map[string]any{},
	})
}

func (s *Server) handleMockExams(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{
		"data": map[string]any{"session": s.repo.MockExam()},
		"meta": map[string]any{},
	})
}

func (s *Server) handleMockExamByID(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	if r.Method != http.MethodGet {
		writeMethodNotAllowed(w)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"data": s.repo.MockExam(),
		"meta": map[string]any{},
	})
}

func (s *Server) handleAdminExercises(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	switch r.Method {
	case http.MethodGet:
		writeJSON(w, http.StatusOK, map[string]any{"data": s.repo.ListExercises(), "meta": map[string]any{}})
	case http.MethodPost:
		var req struct {
			ModuleID              string          `json:"module_id"`
			ExerciseType          string          `json:"exercise_type"`
			Title                 string          `json:"title"`
			ShortInstruction      string          `json:"short_instruction"`
			LearnerInstruction    string          `json:"learner_instruction"`
			EstimatedDurationSec  int             `json:"estimated_duration_sec"`
			PrepTimeSec           int             `json:"prep_time_sec"`
			RecordingTimeLimitSec int             `json:"recording_time_limit_sec"`
			SampleAnswerEnabled   bool            `json:"sample_answer_enabled"`
			Detail                json.RawMessage `json:"detail"`
			Questions             []string        `json:"questions"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Title == "" || req.ExerciseType == "" {
			writeError(w, http.StatusBadRequest, "validation_error", "Title and exercise type are required.", false)
			return
		}
		exercise := contracts.Exercise{
			ModuleID:               req.ModuleID,
			ExerciseType:           req.ExerciseType,
			Title:                  req.Title,
			ShortInstruction:       req.ShortInstruction,
			LearnerInstruction:     req.LearnerInstruction,
			EstimatedDurationSec:   req.EstimatedDurationSec,
			PrepTimeSec:            req.PrepTimeSec,
			RecordingTimeLimitSec:  req.RecordingTimeLimitSec,
			SampleAnswerEnabled:    req.SampleAnswerEnabled,
			Status:                 "draft",
			ScoringTemplatePreview: &contracts.ScoringPreview{RubricVersion: "v1", FeedbackStyle: "supportive_direct_vi"},
		}
		switch req.ExerciseType {
		case "uloha_1_topic_answers":
			if len(req.Questions) == 0 {
				writeError(w, http.StatusBadRequest, "validation_error", "Question prompts are required for Uloha 1.", false)
				return
			}
			exercise.Prompt = contracts.Uloha1Prompt{
				TopicLabel:      req.Title,
				QuestionPrompts: req.Questions,
			}
		case "uloha_2_dialogue_questions":
			if len(req.Detail) == 0 || string(req.Detail) == "null" {
				writeError(w, http.StatusBadRequest, "validation_error", "Scenario detail is required for Uloha 2.", false)
				return
			}
			var detail contracts.Uloha2Detail
			if err := json.Unmarshal(req.Detail, &detail); err != nil {
				writeError(w, http.StatusBadRequest, "validation_error", "Invalid Uloha 2 detail payload.", false)
				return
			}
			if detail.ScenarioTitle == "" || detail.ScenarioPrompt == "" || len(detail.RequiredInfoSlots) == 0 {
				writeError(w, http.StatusBadRequest, "validation_error", "Scenario title, prompt, and required info slots are required for Uloha 2.", false)
				return
			}
			exercise.Detail = detail
		case "uloha_3_story_narration":
			if len(req.Detail) == 0 || string(req.Detail) == "null" {
				writeError(w, http.StatusBadRequest, "validation_error", "Story detail is required for Uloha 3.", false)
				return
			}
			var detail contracts.Uloha3Detail
			if err := json.Unmarshal(req.Detail, &detail); err != nil {
				writeError(w, http.StatusBadRequest, "validation_error", "Invalid Uloha 3 detail payload.", false)
				return
			}
			if detail.StoryTitle == "" || len(detail.ImageAssetIDs) == 0 || len(detail.NarrativeCheckpoints) == 0 {
				writeError(w, http.StatusBadRequest, "validation_error", "Story title, image asset ids, and narrative checkpoints are required for Uloha 3.", false)
				return
			}
			exercise.Detail = detail
		case "uloha_4_choice_reasoning":
			if len(req.Detail) == 0 || string(req.Detail) == "null" {
				writeError(w, http.StatusBadRequest, "validation_error", "Choice detail is required for Uloha 4.", false)
				return
			}
			var detail contracts.Uloha4Detail
			if err := json.Unmarshal(req.Detail, &detail); err != nil {
				writeError(w, http.StatusBadRequest, "validation_error", "Invalid Uloha 4 detail payload.", false)
				return
			}
			if detail.ScenarioPrompt == "" || len(detail.Options) == 0 {
				writeError(w, http.StatusBadRequest, "validation_error", "Scenario prompt and options are required for Uloha 4.", false)
				return
			}
			exercise.Detail = detail
		default:
			if len(req.Detail) > 0 && string(req.Detail) != "null" {
				var detail any
				if err := json.Unmarshal(req.Detail, &detail); err != nil {
					writeError(w, http.StatusBadRequest, "validation_error", "Invalid exercise detail payload.", false)
					return
				}
				exercise.Detail = detail
			}
		}
		created := s.repo.CreateExercise(exercise)
		writeJSON(w, http.StatusCreated, map[string]any{"data": created, "meta": map[string]any{}})
	default:
		writeMethodNotAllowed(w)
	}
}

func (s *Server) handleAdminExerciseByID(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	path := strings.TrimPrefix(r.URL.Path, "/v1/admin/exercises/")
	switch {
	case strings.HasSuffix(path, "/assets/upload-url"):
		s.handleAdminAssetUploadURL(w, r, strings.TrimSuffix(path, "/assets/upload-url"))
	case strings.HasSuffix(path, "/assets"):
		s.handleAdminAssetRegister(w, r, strings.TrimSuffix(path, "/assets"))
	case strings.Contains(path, "/assets/") && strings.HasSuffix(path, "/blob"):
		exerciseID, assetID, ok := splitExerciseAssetPath(path, "blob")
		if !ok {
			writeNotFound(w)
			return
		}
		s.handleAdminAssetBlobUpload(w, r, exerciseID, assetID)
	case strings.Contains(path, "/assets/") && strings.HasSuffix(path, "/file"):
		exerciseID, assetID, ok := splitExerciseAssetPath(path, "file")
		if !ok {
			writeNotFound(w)
			return
		}
		s.handleAdminAssetFile(w, r, exerciseID, assetID)
	case strings.HasSuffix(path, "/scoring-template"):
		writeJSON(w, http.StatusOK, map[string]any{
			"data": map[string]any{"status": "saved"},
			"meta": map[string]any{},
		})
	default:
		id := path
		switch r.Method {
		case http.MethodGet:
			exercise, ok := s.repo.Exercise(id)
			if !ok {
				writeNotFound(w)
				return
			}
			writeJSON(w, http.StatusOK, map[string]any{"data": exercise, "meta": map[string]any{}})
		case http.MethodPatch:
			var req contracts.Exercise
			if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
				writeError(w, http.StatusBadRequest, "validation_error", "Invalid exercise update payload.", false)
				return
			}
			exercise, ok := s.repo.UpdateExercise(id, req)
			if !ok {
				writeNotFound(w)
				return
			}
			writeJSON(w, http.StatusOK, map[string]any{"data": exercise, "meta": map[string]any{}})
		case http.MethodDelete:
			if ok := s.repo.DeleteExercise(id); !ok {
				writeNotFound(w)
				return
			}
			writeJSON(w, http.StatusOK, map[string]any{
				"data": map[string]any{"id": id, "deleted": true},
				"meta": map[string]any{},
			})
		default:
			writeMethodNotAllowed(w)
		}
	}
}

func (s *Server) handleAdminAssetUploadURL(w http.ResponseWriter, r *http.Request, exerciseID string) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}
	if _, ok := s.repo.Exercise(exerciseID); !ok {
		writeNotFound(w)
		return
	}

	var req struct {
		AssetKind string `json:"asset_kind"`
		MimeType  string `json:"mime_type"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || strings.TrimSpace(req.MimeType) == "" {
		writeError(w, http.StatusBadRequest, "validation_error", "Asset kind and mime type are required.", false)
		return
	}

	assetID := newLocalAssetID()
	storageKey := exerciseAssetStorageKey(exerciseID, assetID, req.MimeType)
	values := url.Values{}
	values.Set("storage_key", storageKey)

	writeJSON(w, http.StatusOK, map[string]any{
		"data": map[string]any{
			"asset": map[string]any{
				"id":         assetID,
				"asset_kind": strings.TrimSpace(req.AssetKind),
				"mime_type":  strings.TrimSpace(req.MimeType),
			},
			"upload": contracts.UploadTarget{
				Method: "PUT",
				URL: buildAbsoluteURL(
					r,
					fmt.Sprintf("/v1/admin/exercises/%s/assets/%s/blob?%s", exerciseID, assetID, values.Encode()),
				),
				Headers: map[string]string{
					"Content-Type": strings.TrimSpace(req.MimeType),
				},
				StorageKey:   storageKey,
				ExpiresInSec: 900,
			},
		},
		"meta": map[string]any{},
	})
}

func (s *Server) handleAdminAssetBlobUpload(w http.ResponseWriter, r *http.Request, exerciseID, assetID string) {
	if r.Method != http.MethodPut {
		writeMethodNotAllowed(w)
		return
	}
	if _, ok := s.repo.Exercise(exerciseID); !ok {
		writeNotFound(w)
		return
	}

	storageKey := strings.TrimSpace(r.URL.Query().Get("storage_key"))
	if storageKey == "" {
		writeError(w, http.StatusBadRequest, "validation_error", "storage_key is required.", false)
		return
	}
	mimeType := strings.TrimSpace(r.Header.Get("Content-Type"))
	if mimeType == "" {
		writeError(w, http.StatusBadRequest, "validation_error", "Content-Type is required.", false)
		return
	}

	filePath := localExerciseAssetPath(storageKey)
	if err := os.MkdirAll(filepath.Dir(filePath), 0o755); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not prepare asset storage.", true)
		return
	}
	file, err := os.Create(filePath)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not open asset storage.", true)
		return
	}
	defer file.Close()

	size, err := io.Copy(file, r.Body)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "upload_failed", "Could not store uploaded asset.", true)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"data": map[string]any{
			"asset_id":         assetID,
			"storage_key":      storageKey,
			"stored_file_path": filePath,
			"size_bytes":       size,
			"mime_type":        mimeType,
		},
		"meta": map[string]any{},
	})
}

func (s *Server) handleAdminAssetRegister(w http.ResponseWriter, r *http.Request, exerciseID string) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}

	exercise, ok := s.repo.Exercise(exerciseID)
	if !ok {
		writeNotFound(w)
		return
	}

	var req struct {
		ID         string `json:"id"`
		AssetKind  string `json:"asset_kind"`
		StorageKey string `json:"storage_key"`
		MimeType   string `json:"mime_type"`
		SequenceNo int    `json:"sequence_no"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil ||
		strings.TrimSpace(req.AssetKind) == "" ||
		strings.TrimSpace(req.StorageKey) == "" ||
		strings.TrimSpace(req.MimeType) == "" {
		writeError(w, http.StatusBadRequest, "validation_error", "Asset id, kind, storage key, and mime type are required.", false)
		return
	}

	assetID := strings.TrimSpace(req.ID)
	if assetID == "" {
		assetID = newLocalAssetID()
	}

	newAsset := contracts.PromptAsset{
		ID:         assetID,
		AssetKind:  strings.TrimSpace(req.AssetKind),
		StorageKey: strings.TrimSpace(req.StorageKey),
		MimeType:   strings.TrimSpace(req.MimeType),
		SequenceNo: req.SequenceNo,
	}

	assets := upsertPromptAsset(exercise.Assets, newAsset)
	updated, ok := s.repo.UpdateExercise(exerciseID, contracts.Exercise{Assets: assets})
	if !ok {
		writeNotFound(w)
		return
	}

	writeJSON(w, http.StatusCreated, map[string]any{
		"data": map[string]any{
			"asset":   newAsset,
			"assets":  updated.Assets,
			"preview": buildAbsoluteURL(r, fmt.Sprintf("/v1/admin/exercises/%s/assets/%s/file", exerciseID, assetID)),
		},
		"meta": map[string]any{},
	})
}

func (s *Server) handleAdminAssetFile(w http.ResponseWriter, r *http.Request, exerciseID, assetID string) {
	if r.Method != http.MethodGet {
		writeMethodNotAllowed(w)
		return
	}
	s.serveExerciseAssetFile(w, r, exerciseID, assetID)
}

func (s *Server) handleLearnerAssetFile(w http.ResponseWriter, r *http.Request, exerciseID, assetID string) {
	if r.Method != http.MethodGet {
		writeMethodNotAllowed(w)
		return
	}
	s.serveExerciseAssetFile(w, r, exerciseID, assetID)
}

func (s *Server) withAuth(next func(http.ResponseWriter, *http.Request, contracts.User)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		user, ok := s.authenticatedUser(r)
		if !ok {
			writeError(w, http.StatusUnauthorized, "unauthorized", "Authentication required.", false)
			return
		}
		next(w, r, user)
	}
}

func (s *Server) withRole(role string, next func(http.ResponseWriter, *http.Request, contracts.User)) http.HandlerFunc {
	return s.withAuth(func(w http.ResponseWriter, r *http.Request, user contracts.User) {
		if user.Role != role {
			writeError(w, http.StatusForbidden, "forbidden", "You do not have access to this resource.", false)
			return
		}
		next(w, r, user)
	})
}

func (s *Server) authenticatedUser(r *http.Request) (contracts.User, bool) {
	token := strings.TrimSpace(strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer"))
	if token == "" {
		return contracts.User{}, false
	}
	return s.repo.UserByToken(token)
}

func (s *Server) withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type, X-Client-Version")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PATCH, PUT, OPTIONS")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func (s *Server) withRequestLog(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		startedAt := time.Now()
		recorder := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(recorder, r)
		log.Printf(
			"http request method=%s path=%s status=%d duration_ms=%d remote_addr=%q",
			r.Method,
			r.URL.Path,
			recorder.status,
			time.Since(startedAt).Milliseconds(),
			r.RemoteAddr,
		)
	})
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (r *statusRecorder) WriteHeader(statusCode int) {
	r.status = statusCode
	r.ResponseWriter.WriteHeader(statusCode)
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func writeError(w http.ResponseWriter, status int, code, message string, retryable bool) {
	writeJSON(w, status, map[string]any{
		"error": map[string]any{
			"code":      code,
			"message":   message,
			"retryable": retryable,
			"details":   map[string]any{},
		},
	})
}

func writeNotFound(w http.ResponseWriter) {
	writeError(w, http.StatusNotFound, "not_found", "Resource not found.", false)
}

func writeMethodNotAllowed(w http.ResponseWriter) {
	writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "Method not allowed.", false)
}

func extensionForMime(mime string) string {
	switch strings.TrimSpace(strings.ToLower(mime)) {
	case "image/jpeg", "image/jpg", "image/pjpeg":
		return "jpg"
	case "image/png":
		return "png"
	case "image/webp":
		return "webp"
	case "image/gif":
		return "gif"
	case "image/svg+xml":
		return "svg"
	case "audio/m4a", "audio/mp4a-latm", "audio/x-m4a":
		return "m4a"
	case "audio/mp4":
		return "mp4"
	case "audio/mpeg":
		return "mp3"
	case "audio/wav", "audio/x-wav", "audio/wave", "audio/vnd.wave":
		return "wav"
	case "audio/flac":
		return "flac"
	case "audio/webm":
		return "webm"
	default:
		return "bin"
	}
}

func splitExerciseAssetPath(path, action string) (exerciseID, assetID string, ok bool) {
	parts := strings.Split(path, "/")
	if len(parts) != 4 || parts[1] != "assets" || parts[3] != action {
		return "", "", false
	}
	return parts[0], parts[2], true
}

func localExerciseAssetPath(storageKey string) string {
	return filepath.Join(os.TempDir(), "czech-go-system-assets", filepath.FromSlash(storageKey))
}

func exerciseAssetStorageKey(exerciseID, assetID, mimeType string) string {
	return fmt.Sprintf("exercise-assets/%s/%s.%s", exerciseID, assetID, extensionForMime(mimeType))
}

func upsertPromptAsset(existing []contracts.PromptAsset, newAsset contracts.PromptAsset) []contracts.PromptAsset {
	assets := make([]contracts.PromptAsset, 0, len(existing)+1)
	replaced := false
	for _, asset := range existing {
		if asset.ID == newAsset.ID {
			assets = append(assets, newAsset)
			replaced = true
			continue
		}
		assets = append(assets, asset)
	}
	if !replaced {
		assets = append(assets, newAsset)
	}
	return assets
}

func newLocalAssetID() string {
	return fmt.Sprintf("asset-%d", time.Now().UTC().UnixNano())
}

func (s *Server) serveExerciseAssetFile(w http.ResponseWriter, r *http.Request, exerciseID, assetID string) {
	asset, ok := s.lookupExerciseAsset(exerciseID, assetID)
	if !ok {
		writeNotFound(w)
		return
	}
	if strings.HasPrefix(asset.StorageKey, "http://") || strings.HasPrefix(asset.StorageKey, "https://") {
		http.Redirect(w, r, asset.StorageKey, http.StatusTemporaryRedirect)
		return
	}

	filePath := localExerciseAssetPath(asset.StorageKey)
	file, err := os.Open(filePath)
	if err != nil {
		writeNotFound(w)
		return
	}
	defer file.Close()

	if asset.MimeType != "" {
		w.Header().Set("Content-Type", asset.MimeType)
	}
	w.WriteHeader(http.StatusOK)
	_, _ = io.Copy(w, file)
}

func (s *Server) lookupExerciseAsset(exerciseID, assetID string) (contracts.PromptAsset, bool) {
	exercise, ok := s.repo.Exercise(exerciseID)
	if !ok {
		return contracts.PromptAsset{}, false
	}
	for _, asset := range exercise.Assets {
		if asset.ID == assetID {
			return asset, true
		}
	}
	return contracts.PromptAsset{}, false
}

func buildAbsoluteURL(r *http.Request, path string) string {
	scheme := "http"
	if forwardedProto := strings.TrimSpace(r.Header.Get("X-Forwarded-Proto")); forwardedProto != "" {
		scheme = forwardedProto
	} else if r.TLS != nil {
		scheme = "https"
	}
	return fmt.Sprintf("%s://%s%s", scheme, r.Host, path)
}

func parseRFC3339OrZero(value string) time.Time {
	parsed, err := time.Parse(time.RFC3339, value)
	if err != nil {
		return time.Time{}
	}
	return parsed
}

func attemptSequenceOrZero(attemptID string) int {
	value := strings.TrimPrefix(attemptID, "attempt-")
	sequence, err := strconv.Atoi(value)
	if err != nil {
		return 0
	}
	return sequence
}
