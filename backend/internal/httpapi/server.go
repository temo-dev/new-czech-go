package httpapi

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

type Server struct {
	repo *store.MemoryStore
	mux  *http.ServeMux
}

func NewServer(repo *store.MemoryStore) http.Handler {
	s := &Server{
		repo: repo,
		mux:  http.NewServeMux(),
	}
	s.routes()
	return s.withCORS(s.mux)
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
	if r.Method != http.MethodGet {
		writeMethodNotAllowed(w)
		return
	}
	id := strings.TrimPrefix(r.URL.Path, "/v1/exercises/")
	exercise, ok := s.repo.Exercise(id)
	if !ok {
		writeNotFound(w)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": exercise, "meta": map[string]any{}})
}

func (s *Server) handleAttempts(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	switch r.Method {
	case http.MethodGet:
		writeJSON(w, http.StatusOK, map[string]any{
			"data": s.repo.ListAttempts(),
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
		attempt, err := s.repo.CreateAttempt(req.ExerciseID)
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

func (s *Server) handleAttemptByID(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	path := strings.TrimPrefix(r.URL.Path, "/v1/attempts/")
	if strings.HasSuffix(path, "/recording-started") {
		s.handleRecordingStarted(w, r, strings.TrimSuffix(path, "/recording-started"))
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
	target := contracts.UploadTarget{
		Method: "PUT",
		URL:    buildAbsoluteURL(r, fmt.Sprintf("/v1/attempts/%s/audio", attemptID)),
		Headers: map[string]string{
			"Content-Type": req.MimeType,
		},
		StorageKey:   fmt.Sprintf("attempt-audio/%s/audio.%s", attemptID, extensionForMime(req.MimeType)),
		ExpiresInSec: 900,
	}
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
	audio := contracts.AttemptAudio{
		StorageKey:     req.StorageKey,
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
	go s.simulateScoring(attemptID)
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
			ModuleID              string   `json:"module_id"`
			ExerciseType          string   `json:"exercise_type"`
			Title                 string   `json:"title"`
			ShortInstruction      string   `json:"short_instruction"`
			LearnerInstruction    string   `json:"learner_instruction"`
			EstimatedDurationSec  int      `json:"estimated_duration_sec"`
			PrepTimeSec           int      `json:"prep_time_sec"`
			RecordingTimeLimitSec int      `json:"recording_time_limit_sec"`
			SampleAnswerEnabled   bool     `json:"sample_answer_enabled"`
			Detail                any      `json:"detail"`
			Questions             []string `json:"questions"`
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
			Detail:                 req.Detail,
			ScoringTemplatePreview: &contracts.ScoringPreview{RubricVersion: "v1", FeedbackStyle: "supportive_direct_vi"},
		}
		if len(req.Questions) > 0 {
			exercise.Prompt = contracts.Uloha1Prompt{
				TopicLabel:      req.Title,
				QuestionPrompts: req.Questions,
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
		writeJSON(w, http.StatusOK, map[string]any{
			"data": map[string]any{
				"upload": contracts.UploadTarget{
					Method: "PUT",
					URL:    "https://example.invalid/mock-asset-upload",
					Headers: map[string]string{
						"Content-Type": "application/octet-stream",
					},
					StorageKey:   fmt.Sprintf("exercise-assets/%s/asset", strings.TrimSuffix(path, "/assets/upload-url")),
					ExpiresInSec: 900,
				},
			},
			"meta": map[string]any{},
		})
	case strings.HasSuffix(path, "/assets"):
		writeJSON(w, http.StatusCreated, map[string]any{
			"data": map[string]any{"status": "registered"},
			"meta": map[string]any{},
		})
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
		default:
			writeMethodNotAllowed(w)
		}
	}
}

func (s *Server) simulateScoring(attemptID string) {
	s.repo.SetAttemptStatus(attemptID, "transcribing")
	time.Sleep(1200 * time.Millisecond)
	s.repo.SetAttemptStatus(attemptID, "scoring")
	time.Sleep(1200 * time.Millisecond)
	s.repo.CompleteAttempt(attemptID, contracts.Transcript{
		FullText:   "Mne se libi teple pocasi, protoze muzu byt venku.",
		Locale:     "cs-CZ",
		Confidence: 0.92,
	}, contracts.AttemptFeedback{
		ReadinessLevel: "almost_ready",
		OverallSummary: "Ban tra loi dung chu de va de hieu, nhung can them chi tiet cu the hon de giong bai thi that.",
		Strengths: []string{
			"Ban tra loi dung chu de",
			"Cau tra loi ngan gon va de theo doi",
		},
		Improvements: []string{
			"Them mot ly do cu the hon",
			"Thu noi tu nhien hon o cuoi cau",
		},
		TaskCompletion: contracts.TaskCompletion{
			ScoreBand: "ok",
			CriteriaResults: []contracts.CriterionCheck{
				{
					CriterionKey: "answered_question",
					Label:        "Tra loi dung cau hoi",
					Met:          true,
					Comment:      "Ban da tra loi dung y chinh.",
				},
			},
		},
		GrammarFeedback: contracts.GrammarFeedback{
			ScoreBand: "ok",
			Issues: []contracts.GrammarIssue{
				{
					IssueKey:   "detail_depth",
					Label:      "Do cu the",
					Comment:    "Cau tra loi dung y, nhung con hoi ngan.",
					ExampleFix: "Mne se libi teple pocasi, protoze muzu byt dlouho venku s rodinou.",
				},
			},
			RewrittenExample: "Mne se libi teple pocasi, protoze muzu byt dlouho venku s rodinou.",
		},
		RetryAdvice: []string{
			"Thu tra loi lai trong 20-30 giay",
			"Them mot ly do cu the vao cau tra loi",
		},
		SampleAnswer: "Mne se libi teple pocasi, protoze muzu byt venku a chodit do parku.",
	})
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
	switch mime {
	case "audio/m4a":
		return "m4a"
	case "audio/mpeg":
		return "mp3"
	case "audio/wav":
		return "wav"
	default:
		return "bin"
	}
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
