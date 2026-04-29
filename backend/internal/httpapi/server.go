package httpapi

import (
	"encoding/json"
	"errors"
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
	repo             *store.MemoryStore
	processor        *processing.Processor
	uploadProvider   UploadTargetProvider
	audioURLProvider AudioURLProvider
	audioSignSecret  []byte
	audioGenerator   processing.ExerciseAudioGenerator
	fullExamScorer   *processing.FullExamScorer
	contentGenerator processing.ContentGenerator
	mux              *http.ServeMux
}

func NewServer(repo *store.MemoryStore, processor *processing.Processor, uploadProvider UploadTargetProvider) http.Handler {
	return NewServerWithAudio(repo, processor, uploadProvider, nil, nil)
}

// NewServerWithAudio is the full constructor that takes an explicit
// AudioURLProvider and signing secret. NewServer delegates here with defaults
// sourced from env.
func NewServerWithAudio(repo *store.MemoryStore, processor *processing.Processor, uploadProvider UploadTargetProvider, audioURLProvider AudioURLProvider, audioSignSecret []byte) http.Handler {
	if processor == nil {
		processor = processing.NewProcessor(repo, nil, nil, nil, nil)
	}
	if uploadProvider == nil {
		uploadProvider = NewLocalUploadTargetProvider()
	}
	if len(audioSignSecret) == 0 {
		audioSignSecret = AudioSigningSecretFromEnv(log.Printf)
	}
	if audioURLProvider == nil {
		audioURLProvider = NewLocalSignedAudioURLProvider(audioSignSecret)
	}
	var contentGen processing.ContentGenerator
	if apiKey := strings.TrimSpace(os.Getenv("ANTHROPIC_API_KEY")); apiKey != "" {
		contentGen = processing.NewClaudeContentGenerator(apiKey)
	}
	// Exercise audio generator: Polly when TTS is configured, dev otherwise.
	var audioGen processing.ExerciseAudioGenerator = processing.DevExerciseAudioGenerator{}
	if ttsProvider := processor.TTSProvider(); ttsProvider != nil {
		pollyGen := processing.NewPollyExerciseAudioGenerator(ttsProvider)
		// Wire second voice for poslech_4 dialogs (POLLY_VOICE_ID_2, default "Tomáš").
		if ttsB := processing.NewAmazonPollyTTSProviderWithVoice("Tomáš"); ttsB != nil {
			pollyGen = pollyGen.WithDialogVoice(ttsB)
		}
		audioGen = pollyGen
	}
	s := &Server{
		repo:             repo,
		processor:        processor,
		uploadProvider:   uploadProvider,
		audioURLProvider: audioURLProvider,
		audioSignSecret:  audioSignSecret,
		audioGenerator:   audioGen,
		fullExamScorer:   processing.NewFullExamScorer(repo),
		contentGenerator: contentGen,
		mux:              http.NewServeMux(),
	}
	// Recover any jobs stuck in "running" from a previous server crash.
	repo.MarkAllRunningJobsFailed("Server restarted while generation was running")
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
	s.mux.HandleFunc("/v1/attempt-audio/stream", s.handleAttemptAudioStream)
	s.mux.HandleFunc("/v1/mock-exams", s.withAuth(s.handleMockExams))
	s.mux.HandleFunc("/v1/mock-exams/", s.withAuth(s.handleMockExamByID))
	s.mux.HandleFunc("/v1/mock-tests", s.withAuth(s.handleMockTests))
	s.mux.HandleFunc("/v1/full-exams", s.withAuth(s.handleFullExams))
	s.mux.HandleFunc("/v1/full-exams/", s.withAuth(s.handleFullExamByID))
	// Course/Skill learner APIs
	s.mux.HandleFunc("/v1/courses", s.withAuth(s.handleCourses))
	s.mux.HandleFunc("/v1/courses/", s.withAuth(s.handleCourseByID))
	s.mux.HandleFunc("/v1/skills/", s.withAuth(s.handleSkillExercises))
	// Admin APIs
	s.mux.HandleFunc("/v1/admin/exercises", s.withRole("admin", s.handleAdminExercises))
	s.mux.HandleFunc("/v1/admin/exercises/", s.withRole("admin", s.handleAdminExerciseByID))
	s.mux.HandleFunc("/v1/admin/mock-tests", s.withRole("admin", s.handleAdminMockTests))
	s.mux.HandleFunc("/v1/admin/mock-tests/", s.withRole("admin", s.handleAdminMockTestByID))
	s.mux.HandleFunc("/v1/admin/courses", s.withRole("admin", s.handleAdminCourses))
	s.mux.HandleFunc("/v1/admin/courses/", s.withRole("admin", s.handleAdminCourseByID))
	s.mux.HandleFunc("/v1/admin/modules", s.withRole("admin", s.handleAdminModules))
	s.mux.HandleFunc("/v1/admin/modules/", s.withRole("admin", s.handleAdminModuleByID))
	s.mux.HandleFunc("/v1/admin/skills", s.withRole("admin", s.handleAdminSkills))
	s.mux.HandleFunc("/v1/admin/skills/", s.withRole("admin", s.handleAdminSkillByID))
	// V6: Vocab & Grammar content authoring
	s.mux.HandleFunc("/v1/admin/vocabulary-sets", s.withRole("admin", s.handleAdminVocabSets))
	s.mux.HandleFunc("/v1/admin/vocabulary-sets/", s.withRole("admin", s.handleAdminVocabSetByID))
	s.mux.HandleFunc("/v1/admin/grammar-rules", s.withRole("admin", s.handleAdminGrammarRules))
	s.mux.HandleFunc("/v1/admin/grammar-rules/", s.withRole("admin", s.handleAdminGrammarRuleByID))
	s.mux.HandleFunc("/v1/admin/content-generation-jobs", s.withRole("admin", s.handleAdminGenJobs))
	s.mux.HandleFunc("/v1/admin/content-generation-jobs/", s.withRole("admin", s.handleAdminGenJobByID))
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
	plan := s.repo.Plan()
	dailyModules := s.repo.Modules("daily_plan")
	mockModules := s.repo.Modules("mock_exam")

	days := make([]map[string]any, 0, len(dailyModules)+len(mockModules))
	for _, m := range dailyModules {
		days = append(days, map[string]any{
			"day":         m.SequenceNo,
			"label":       m.Title,
			"description": m.Description,
			"status":      planDayStatus(m.SequenceNo, plan.CurrentDay),
			"module_id":   m.ID,
			"module_kind": m.ModuleKind,
		})
	}
	for _, m := range mockModules {
		days = append(days, map[string]any{
			"day":         m.SequenceNo,
			"label":       m.Title,
			"description": m.Description,
			"status":      planDayStatus(m.SequenceNo, plan.CurrentDay),
			"module_id":   m.ID,
			"module_kind": m.ModuleKind,
		})
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"data": map[string]any{
			"current_day": plan.CurrentDay,
			"start_date":  plan.StartDate,
			"status":      plan.Status,
			"days":        days,
		},
		"meta": map[string]any{},
	})
}

func planDayStatus(seqNo, currentDay int) string {
	switch {
	case seqNo < currentDay:
		return "done"
	case seqNo == currentDay:
		return "current"
	default:
		return "upcoming"
	}
}

func (s *Server) handleModules(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	writeJSON(w, http.StatusOK, map[string]any{
		"data": s.repo.Modules(r.URL.Query().Get("kind")),
		"meta": map[string]any{},
	})
}

func (s *Server) handleModuleExercises(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	if r.Method != http.MethodGet {
		writeMethodNotAllowed(w)
		return
	}
	path := strings.TrimPrefix(r.URL.Path, "/v1/modules/")
	if strings.HasSuffix(path, "/skills") {
		moduleID := strings.TrimSuffix(path, "/skills")
		s.handleModuleSkills(w, moduleID)
		return
	}
	if strings.HasSuffix(path, "/exercises") {
		moduleID := strings.TrimSuffix(path, "/exercises")
		writeJSON(w, http.StatusOK, map[string]any{
			"data": s.repo.ExercisesByModule(moduleID),
			"meta": map[string]any{},
		})
		return
	}
	writeNotFound(w)
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
	if strings.HasSuffix(path, "/audio") {
		s.handleExerciseAudio(w, r, strings.TrimSuffix(path, "/audio"))
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
			Locale         string `json:"locale"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.ExerciseID == "" {
			writeError(w, http.StatusBadRequest, "validation_error", "Exercise ID is required.", false)
			return
		}
		clientPlatform := req.ClientPlatform
		if clientPlatform == "" {
			clientPlatform = "unknown"
		}
		locale, ok := contracts.NormalizeLocale(req.Locale)
		if !ok {
			writeError(w, http.StatusBadRequest, "invalid_locale", "Unsupported locale.", false)
			return
		}
		attempt, err := s.repo.CreateAttempt(user.ID, req.ExerciseID, clientPlatform, req.AppVersion, locale)
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
	if strings.HasSuffix(path, "/review/audio/url") {
		s.handleAttemptReviewAudioURL(w, r, user, strings.TrimSuffix(path, "/review/audio/url"))
		return
	}
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
	if strings.HasSuffix(path, "/audio/url") {
		s.handleAttemptAudioURL(w, r, user, strings.TrimSuffix(path, "/audio/url"))
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
	if strings.HasSuffix(path, "/submit-text") {
		s.handleSubmitText(w, r, user, strings.TrimSuffix(path, "/submit-text"))
		return
	}
	if strings.HasSuffix(path, "/submit-answers") {
		s.handleSubmitAnswers(w, r, user, strings.TrimSuffix(path, "/submit-answers"))
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

	stat, err := file.Stat()
	if err != nil {
		log.Printf("attempt review audio stat failed: attempt_id=%s error=%v", attemptID, err)
		writeNotFound(w)
		return
	}
	if audio.MimeType != "" {
		w.Header().Set("Content-Type", audio.MimeType)
	}
	w.Header().Set("Accept-Ranges", "bytes")
	w.Header().Set("Cache-Control", "no-store")
	http.ServeContent(w, r, filePath, stat.ModTime(), file)
}

func (s *Server) handleAttemptAudioURL(w http.ResponseWriter, r *http.Request, user contracts.User, attemptID string) {
	if r.Method != http.MethodGet {
		writeMethodNotAllowed(w)
		return
	}
	attempt, ok := s.authorizedAttemptForUser(w, user, attemptID)
	if !ok {
		return
	}
	if attempt.Audio == nil {
		writeError(w, http.StatusNotFound, "audio_missing", "No audio stored for this attempt.", false)
		return
	}
	signed, err := s.audioURLProvider.SignedAudioURL(r.Context(), AudioURLInput{
		AttemptID:  attemptID,
		Scope:      ScopeAttemptAudio,
		StorageKey: attempt.Audio.StorageKey,
		MimeType:   attempt.Audio.MimeType,
		BaseURL:    buildAbsoluteURL(r, ""),
		ExpiresIn:  10 * time.Minute,
	})
	if err != nil {
		log.Printf("attempt audio url sign failed: attempt_id=%s error=%v", attemptID, err)
		writeError(w, http.StatusBadGateway, "audio_url_provider_failed", "Could not sign audio URL.", true)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"data": map[string]any{
			"url":        signed.URL,
			"mime_type":  signed.MimeType,
			"expires_at": signed.ExpiresAt.Format(time.RFC3339),
		},
		"meta": map[string]any{},
	})
}

func (s *Server) handleAttemptReviewAudioURL(w http.ResponseWriter, r *http.Request, user contracts.User, attemptID string) {
	if r.Method != http.MethodGet {
		writeMethodNotAllowed(w)
		return
	}
	if _, ok := s.authorizedAttemptForUser(w, user, attemptID); !ok {
		return
	}
	artifact, ok := s.repo.ReviewArtifact(attemptID)
	if !ok || artifact.TTSAudio == nil {
		writeError(w, http.StatusNotFound, "audio_missing", "No review audio available.", false)
		return
	}
	signed, err := s.audioURLProvider.SignedAudioURL(r.Context(), AudioURLInput{
		AttemptID:  attemptID,
		Scope:      ScopeReviewAudio,
		StorageKey: artifact.TTSAudio.StorageKey,
		MimeType:   artifact.TTSAudio.MimeType,
		BaseURL:    buildAbsoluteURL(r, ""),
		ExpiresIn:  10 * time.Minute,
	})
	if err != nil {
		log.Printf("review audio url sign failed: attempt_id=%s error=%v", attemptID, err)
		writeError(w, http.StatusBadGateway, "audio_url_provider_failed", "Could not sign audio URL.", true)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"data": map[string]any{
			"url":        signed.URL,
			"mime_type":  signed.MimeType,
			"expires_at": signed.ExpiresAt.Format(time.RFC3339),
		},
		"meta": map[string]any{},
	})
}

func (s *Server) handleAttemptAudioStream(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet && r.Method != http.MethodHead {
		writeMethodNotAllowed(w)
		return
	}
	q := r.URL.Query()
	attemptID := strings.TrimSpace(q.Get("aid"))
	scope := AudioURLScope(strings.TrimSpace(q.Get("scope")))
	expRaw := strings.TrimSpace(q.Get("exp"))
	sig := strings.TrimSpace(q.Get("sig"))

	if attemptID == "" || scope == "" || expRaw == "" || sig == "" {
		writeError(w, http.StatusUnauthorized, "audio_url_invalid", "Missing token parameters.", false)
		return
	}
	expiry, err := strconv.ParseInt(expRaw, 10, 64)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "audio_url_invalid", "Invalid expiry.", false)
		return
	}

	if err := verifyAudioToken(s.audioSignSecret, attemptID, scope, expiry, sig); err != nil {
		switch err {
		case errAudioURLExpired:
			writeError(w, http.StatusUnauthorized, "audio_url_expired", "Audio URL has expired.", false)
		case errAudioURLInvalidSig, errAudioURLBadPayload:
			writeError(w, http.StatusUnauthorized, "audio_url_invalid", "Invalid audio URL signature.", false)
		default:
			writeError(w, http.StatusUnauthorized, "audio_url_invalid", "Invalid audio URL.", false)
		}
		return
	}

	switch scope {
	case ScopeAttemptAudio:
		s.streamAttemptAudio(w, r, attemptID)
	case ScopeReviewAudio:
		s.streamReviewAudio(w, r, attemptID)
	default:
		writeError(w, http.StatusUnauthorized, "audio_url_invalid", "Unknown scope.", false)
	}
}

func (s *Server) streamAttemptAudio(w http.ResponseWriter, r *http.Request, attemptID string) {
	attempt, ok := s.repo.Attempt(attemptID)
	if !ok || attempt.Audio == nil {
		writeNotFound(w)
		return
	}
	audio := attempt.Audio
	if strings.HasPrefix(audio.StorageKey, "http://") || strings.HasPrefix(audio.StorageKey, "https://") {
		http.Redirect(w, r, audio.StorageKey, http.StatusTemporaryRedirect)
		return
	}
	if strings.TrimSpace(audio.StoredFilePath) == "" {
		writeNotFound(w)
		return
	}
	file, err := os.Open(audio.StoredFilePath)
	if err != nil {
		log.Printf("stream attempt audio open failed: attempt_id=%s path=%q error=%v", attemptID, audio.StoredFilePath, err)
		writeNotFound(w)
		return
	}
	defer file.Close()
	stat, err := file.Stat()
	if err != nil {
		log.Printf("stream attempt audio stat failed: attempt_id=%s error=%v", attemptID, err)
		writeNotFound(w)
		return
	}
	if audio.MimeType != "" {
		w.Header().Set("Content-Type", audio.MimeType)
	}
	w.Header().Set("Accept-Ranges", "bytes")
	w.Header().Set("Cache-Control", "no-store")
	http.ServeContent(w, r, audio.StoredFilePath, stat.ModTime(), file)
}

func (s *Server) streamReviewAudio(w http.ResponseWriter, r *http.Request, attemptID string) {
	artifact, ok := s.repo.ReviewArtifact(attemptID)
	if !ok || artifact.TTSAudio == nil {
		writeNotFound(w)
		return
	}
	audio := artifact.TTSAudio
	if strings.HasPrefix(audio.StorageKey, "http://") || strings.HasPrefix(audio.StorageKey, "https://") {
		http.Redirect(w, r, audio.StorageKey, http.StatusTemporaryRedirect)
		return
	}
	filePath := processing.ReviewAudioLocalPath(audio.StorageKey)
	file, err := os.Open(filePath)
	if err != nil {
		log.Printf("stream review audio open failed: attempt_id=%s path=%q error=%v", attemptID, filePath, err)
		writeNotFound(w)
		return
	}
	defer file.Close()
	stat, err := file.Stat()
	if err != nil {
		log.Printf("stream review audio stat failed: attempt_id=%s error=%v", attemptID, err)
		writeNotFound(w)
		return
	}
	if audio.MimeType != "" {
		w.Header().Set("Content-Type", audio.MimeType)
	}
	w.Header().Set("Accept-Ranges", "bytes")
	w.Header().Set("Cache-Control", "no-store")
	http.ServeContent(w, r, filePath, stat.ModTime(), file)
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

	stat, err := file.Stat()
	if err != nil {
		log.Printf("attempt audio stat failed: attempt_id=%s error=%v", attemptID, err)
		writeNotFound(w)
		return
	}
	if audio.MimeType != "" {
		w.Header().Set("Content-Type", audio.MimeType)
	}
	w.Header().Set("Accept-Ranges", "bytes")
	w.Header().Set("Cache-Control", "no-store")
	http.ServeContent(w, r, audio.StoredFilePath, stat.ModTime(), file)
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

	const maxAudioBytes = 100 * 1024 * 1024 // 100 MB
	r.Body = http.MaxBytesReader(w, r.Body, maxAudioBytes)
	size, err := io.Copy(file, r.Body)
	if err != nil {
		var maxErr *http.MaxBytesError
		if errors.As(err, &maxErr) {
			writeError(w, http.StatusRequestEntityTooLarge, "payload_too_large", "Audio file exceeds 100 MB limit.", false)
		} else {
			writeError(w, http.StatusInternalServerError, "upload_failed", "Could not store uploaded audio.", true)
		}
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

// handleExerciseAudio serves a listening exercise's audio file.
// GET /v1/exercises/:id/audio
func (s *Server) handleExerciseAudio(w http.ResponseWriter, r *http.Request, exerciseID string) {
	if r.Method != http.MethodGet {
		writeMethodNotAllowed(w)
		return
	}
	audio, ok := s.repo.ExerciseAudioByExercise(exerciseID)
	if !ok {
		writeNotFound(w)
		return
	}
	filePath := localExerciseAudioPath(audio.StorageKey)
	if _, err := os.Stat(filePath); err != nil {
		writeNotFound(w)
		return
	}
	w.Header().Set("Content-Type", audio.MimeType)
	http.ServeFile(w, r, filePath)
}

// handleAdminGenerateAudio calls Polly TTS to generate audio for a listening exercise.
// POST /v1/admin/exercises/:id/generate-audio
func (s *Server) handleAdminGenerateAudio(w http.ResponseWriter, r *http.Request, exerciseID string) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}
	exercise, ok := s.repo.Exercise(exerciseID)
	if !ok {
		writeNotFound(w)
		return
	}
	// Poslech 4: use 2-voice dialog generation when generator supports it.
	var audio *contracts.ExerciseAudio
	if exercise.ExerciseType == "poslech_4" {
		if dialogGen, ok := s.audioGenerator.(processing.DialogExerciseAudioGenerator); ok {
			dialogTexts := processing.BuildExerciseDialogTexts(exercise)
			if len(dialogTexts) == 0 {
				writeError(w, http.StatusBadRequest, "validation_error", "No dialog text segments found.", false)
				return
			}
			var err error
			audio, err = dialogGen.GenerateDialogAudio(exerciseID, dialogTexts)
			if err != nil {
				log.Printf("generate-dialog-audio exercise %s: %v", exerciseID, err)
				writeError(w, http.StatusInternalServerError, "internal_error", "Dialog audio generation failed.", true)
				return
			}
		}
	}
	if audio == nil {
		// Standard single-voice path for all other types (and poslech_4 fallback)
		text := processing.BuildExerciseAudioText(exercise)
		if text == "" {
			writeError(w, http.StatusBadRequest, "validation_error", "No text segments found in exercise detail.", false)
			return
		}
		var genErr error
		audio, genErr = s.audioGenerator.GenerateAudio(exerciseID, text)
		if genErr != nil {
			log.Printf("generate-audio exercise %s: %v", exerciseID, genErr)
			writeError(w, http.StatusInternalServerError, "internal_error", "Audio generation failed.", true)
			return
		}
	}
	s.repo.SetExerciseAudio(exerciseID, *audio)
	writeJSON(w, http.StatusOK, map[string]any{
		"data": map[string]any{
			"storage_key":  audio.StorageKey,
			"mime_type":    audio.MimeType,
			"source_type":  audio.SourceType,
			"generated_at": audio.GeneratedAt,
		},
		"meta": map[string]any{},
	})
}

// POST /v1/full-exams — create full exam session (písemná part completed, compute score).
// GET  /v1/full-exams — list learner's full exam sessions.
func (s *Server) handleFullExams(w http.ResponseWriter, r *http.Request, user contracts.User) {
	switch r.Method {
	case http.MethodPost:
		var req contracts.FullExamCreateRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeError(w, http.StatusBadRequest, "validation_error", "Invalid request body.", false)
			return
		}
		// Default section max points: cteni=25, psani=20, poslech=25
		maxPoints := req.PisemnaSectionMaxPoints
		if len(maxPoints) == 0 {
			maxPoints = make([]int, len(req.PisemnaAttemptIDs))
			for i := range maxPoints {
				maxPoints[i] = 25 // default per section
			}
		}
		session, err := s.fullExamScorer.CreateSession(user.ID, req.MockTestID, req.PisemnaAttemptIDs, maxPoints)
		if err != nil {
			log.Printf("full exam create: %v", err)
			writeError(w, http.StatusBadRequest, "validation_error", err.Error(), false)
			return
		}
		writeJSON(w, http.StatusCreated, map[string]any{"data": session, "meta": map[string]any{}})
	case http.MethodGet:
		sessions := s.repo.ListFullExamSessions(user.ID)
		writeJSON(w, http.StatusOK, map[string]any{"data": sessions, "meta": map[string]any{}})
	default:
		writeMethodNotAllowed(w)
	}
}

// GET  /v1/full-exams/:id — get session.
// POST /v1/full-exams/:id/complete — link ústní session and compute overall_passed.
func (s *Server) handleFullExamByID(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	path := strings.TrimPrefix(r.URL.Path, "/v1/full-exams/")
	if strings.HasSuffix(path, "/complete") {
		id := strings.TrimSuffix(path, "/complete")
		if r.Method != http.MethodPost {
			writeMethodNotAllowed(w)
			return
		}
		var req contracts.FullExamCompleteRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeError(w, http.StatusBadRequest, "validation_error", "Invalid request body.", false)
			return
		}
		session, err := s.fullExamScorer.CompleteSession(id, req.UstniMockExamSessionID)
		if err != nil {
			writeError(w, http.StatusNotFound, "not_found", err.Error(), false)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"data": session, "meta": map[string]any{}})
		return
	}
	if r.Method != http.MethodGet {
		writeMethodNotAllowed(w)
		return
	}
	session, ok := s.repo.FullExamSession(path)
	if !ok {
		writeNotFound(w)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": session, "meta": map[string]any{}})
}

func localExerciseAudioPath(storageKey string) string {
	base := strings.TrimSpace(os.Getenv("LOCAL_ASSETS_DIR"))
	if base == "" {
		base = "/tmp/czech-go-assets"
	}
	return filepath.Join(base, storageKey)
}

func (s *Server) handleSubmitText(w http.ResponseWriter, r *http.Request, user contracts.User, attemptID string) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}
	attempt, ok := s.authorizedAttemptForUser(w, user, attemptID)
	if !ok {
		return
	}
	if attempt.Status != "created" {
		writeError(w, http.StatusConflict, "attempt_not_pending", "Attempt is not in the created state.", false)
		return
	}
	exercise, ok := s.repo.Exercise(attempt.ExerciseID)
	if !ok {
		writeError(w, http.StatusInternalServerError, "internal_error", "Exercise not found.", true)
		return
	}
	if exercise.ExerciseType != "psani_1_formular" && exercise.ExerciseType != "psani_2_email" {
		writeError(w, http.StatusBadRequest, "validation_error", "Exercise type does not support text submission.", false)
		return
	}
	var sub contracts.WritingSubmission
	if err := json.NewDecoder(r.Body).Decode(&sub); err != nil {
		writeError(w, http.StatusBadRequest, "validation_error", "Invalid submission body.", false)
		return
	}
	if err := processing.ValidateWritingSubmission(exercise.ExerciseType, sub); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_word_count", err.Error(), false)
		return
	}
	s.repo.SetAttemptStatus(attemptID, "scoring")
	go s.processor.ProcessWritingAttempt(attemptID, sub)
	writeJSON(w, http.StatusAccepted, map[string]any{
		"data": map[string]any{"attempt_id": attemptID, "status": "scoring"},
		"meta": map[string]any{},
	})
}

func (s *Server) handleSubmitAnswers(w http.ResponseWriter, r *http.Request, user contracts.User, attemptID string) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}
	attempt, ok := s.authorizedAttemptForUser(w, user, attemptID)
	if !ok {
		return
	}
	if attempt.Status != "created" {
		writeError(w, http.StatusConflict, "attempt_not_pending", "Attempt is not in the created state.", false)
		return
	}
	var sub contracts.AnswerSubmission
	if err := json.NewDecoder(r.Body).Decode(&sub); err != nil {
		writeError(w, http.StatusBadRequest, "validation_error", "Invalid submission body.", false)
		return
	}
	if len(sub.Answers) == 0 {
		writeError(w, http.StatusBadRequest, "validation_error", "answers map must not be empty.", false)
		return
	}
	// Objective scoring is synchronous — score and complete in-request.
	completed, err := s.processor.ProcessObjectiveAttempt(attemptID, sub)
	if err != nil {
		log.Printf("objective attempt %s scoring error: %v", attemptID, err)
		writeError(w, http.StatusInternalServerError, "internal_error", "Scoring failed.", true)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": completed, "meta": map[string]any{}})
}

func (s *Server) handleMockExams(w http.ResponseWriter, r *http.Request, user contracts.User) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}
	var body struct {
		MockTestID string `json:"mock_test_id"`
	}
	if r.ContentLength > 0 {
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]any{
				"error": map[string]any{"code": "invalid_body", "message": err.Error()},
			})
			return
		}
	}
	session, err := s.repo.CreateMockExam(user.ID, body.MockTestID)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{
			"error": map[string]any{"code": "mock_exam_create_failed", "message": err.Error()},
		})
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{
		"data": session,
		"meta": map[string]any{},
	})
}

// GET /v1/mock-tests — learner list of published mock tests
func (s *Server) handleMockTests(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	if r.Method != http.MethodGet {
		writeMethodNotAllowed(w)
		return
	}
	tests := s.repo.ListMockTests("published")
	writeJSON(w, http.StatusOK, map[string]any{
		"data": tests,
		"meta": map[string]any{},
	})
}

// Admin CRUD: /v1/admin/mock-tests
func (s *Server) handleAdminMockTests(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	switch r.Method {
	case http.MethodGet:
		tests := s.repo.ListMockTests("")
		writeJSON(w, http.StatusOK, map[string]any{"data": tests, "meta": map[string]any{}})
	case http.MethodPost:
		var t contracts.MockTest
		if err := json.NewDecoder(r.Body).Decode(&t); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]any{
				"error": map[string]any{"code": "invalid_body", "message": err.Error()},
			})
			return
		}
		created, err := s.repo.CreateMockTest(t)
		if err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]any{
				"error": map[string]any{"code": "create_failed", "message": err.Error()},
			})
			return
		}
		writeJSON(w, http.StatusCreated, map[string]any{"data": created, "meta": map[string]any{}})
	default:
		writeMethodNotAllowed(w)
	}
}

func (s *Server) handleAdminMockTestByID(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	id := strings.TrimPrefix(r.URL.Path, "/v1/admin/mock-tests/")
	if id == "" {
		writeNotFound(w)
		return
	}
	switch r.Method {
	case http.MethodGet:
		t, ok := s.repo.MockTestByID(id)
		if !ok {
			writeNotFound(w)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"data": t, "meta": map[string]any{}})
	case http.MethodPatch:
		var update contracts.MockTest
		if err := json.NewDecoder(r.Body).Decode(&update); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]any{
				"error": map[string]any{"code": "invalid_body", "message": err.Error()},
			})
			return
		}
		updated, ok := s.repo.UpdateMockTest(id, update)
		if !ok {
			writeNotFound(w)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"data": updated, "meta": map[string]any{}})
	case http.MethodDelete:
		if !s.repo.DeleteMockTest(id) {
			writeJSON(w, http.StatusBadRequest, map[string]any{
				"error": map[string]any{"code": "delete_failed", "message": "mock test not found"},
			})
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"data": map[string]any{}, "meta": map[string]any{}})
	default:
		writeMethodNotAllowed(w)
	}
}

func (s *Server) handleMockExamByID(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	path := strings.TrimPrefix(r.URL.Path, "/v1/mock-exams/")
	switch {
	case strings.HasSuffix(path, "/advance"):
		s.handleMockExamAdvance(w, r, strings.TrimSuffix(path, "/advance"))
	case strings.HasSuffix(path, "/complete"):
		s.handleMockExamComplete(w, r, strings.TrimSuffix(path, "/complete"))
	default:
		if r.Method != http.MethodGet {
			writeMethodNotAllowed(w)
			return
		}
		session, ok := s.repo.MockExamByID(path)
		if !ok {
			writeNotFound(w)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"data": session, "meta": map[string]any{}})
	}
}

func (s *Server) handleMockExamAdvance(w http.ResponseWriter, r *http.Request, id string) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}
	var req struct {
		AttemptID string `json:"attempt_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || strings.TrimSpace(req.AttemptID) == "" {
		writeJSON(w, http.StatusBadRequest, map[string]any{
			"error": map[string]any{"code": "invalid_request", "message": "attempt_id required"},
		})
		return
	}
	if _, ok := s.repo.Attempt(req.AttemptID); !ok {
		writeJSON(w, http.StatusBadRequest, map[string]any{
			"error": map[string]any{"code": "attempt_not_found", "message": "attempt not found"},
		})
		return
	}
	session, err := s.repo.AdvanceMockExam(id, req.AttemptID)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{
			"error": map[string]any{"code": "mock_exam_advance_failed", "message": err.Error()},
		})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": session, "meta": map[string]any{}})
}

func (s *Server) handleMockExamComplete(w http.ResponseWriter, r *http.Request, id string) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w)
		return
	}
	session, err := s.repo.CompleteMockExam(id)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{
			"error": map[string]any{"code": "mock_exam_complete_failed", "message": err.Error()},
		})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": session, "meta": map[string]any{}})
}

// skillKindForExerciseType returns the expected skill_kind for an exercise type.
// Returns "" for unknown types (no constraint applied).
func skillKindForExerciseType(exerciseType string) string {
	switch {
	case strings.HasPrefix(exerciseType, "uloha_"):
		return "noi"
	case strings.HasPrefix(exerciseType, "psani_"):
		return "viet"
	case strings.HasPrefix(exerciseType, "poslech_"):
		return "nghe"
	case strings.HasPrefix(exerciseType, "cteni_"):
		return "doc"
	default:
		return ""
	}
}

func (s *Server) handleAdminExercises(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	switch r.Method {
	case http.MethodGet:
		pool := r.URL.Query().Get("pool")
		writeJSON(w, http.StatusOK, map[string]any{"data": s.repo.ListExercises(pool), "meta": map[string]any{}})
	case http.MethodPost:
		var req struct {
			ExerciseType          string          `json:"exercise_type"`
			Title                 string          `json:"title"`
			ShortInstruction      string          `json:"short_instruction"`
			LearnerInstruction    string          `json:"learner_instruction"`
			EstimatedDurationSec  int             `json:"estimated_duration_sec"`
			PrepTimeSec           int             `json:"prep_time_sec"`
			RecordingTimeLimitSec int             `json:"recording_time_limit_sec"`
			SampleAnswerEnabled   bool            `json:"sample_answer_enabled"`
			SampleAnswerText      string          `json:"sample_answer_text"`
			Status                string          `json:"status"`
			SkillID               string          `json:"skill_id"`
			Detail                json.RawMessage `json:"detail"`
			Questions             []string        `json:"questions"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Title == "" || req.ExerciseType == "" {
			writeError(w, http.StatusBadRequest, "validation_error", "Title and exercise type are required.", false)
			return
		}
		if req.SkillID != "" {
			sk, ok := s.repo.SkillByID(req.SkillID)
			if !ok {
				writeError(w, http.StatusBadRequest, "validation_error", "skill_id not found.", false)
				return
			}
			if expected := skillKindForExerciseType(req.ExerciseType); expected != "" && sk.SkillKind != expected {
				writeError(w, http.StatusBadRequest, "validation_error",
					fmt.Sprintf("Exercise type %q requires skill_kind %q, but skill has kind %q.", req.ExerciseType, expected, sk.SkillKind), false)
				return
			}
		}
		status := strings.TrimSpace(req.Status)
		switch status {
		case "draft", "published", "archived":
		default:
			status = "draft"
		}
		exercise := contracts.Exercise{
			ExerciseType:           req.ExerciseType,
			Title:                  req.Title,
			ShortInstruction:       req.ShortInstruction,
			LearnerInstruction:     req.LearnerInstruction,
			EstimatedDurationSec:   req.EstimatedDurationSec,
			PrepTimeSec:            req.PrepTimeSec,
			RecordingTimeLimitSec:  req.RecordingTimeLimitSec,
			SampleAnswerEnabled:    req.SampleAnswerEnabled,
			SampleAnswerText:       strings.TrimSpace(req.SampleAnswerText),
			Status:                 status,
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
		exercise.SkillID = req.SkillID
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
	case strings.HasSuffix(path, "/generate-audio"):
		s.handleAdminGenerateAudio(w, r, strings.TrimSuffix(path, "/generate-audio"))
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
			if req.SkillID != "" && req.ExerciseType != "" {
				sk, ok := s.repo.SkillByID(req.SkillID)
				if !ok {
					writeError(w, http.StatusBadRequest, "validation_error", "skill_id not found.", false)
					return
				}
				if expected := skillKindForExerciseType(req.ExerciseType); expected != "" && sk.SkillKind != expected {
					writeError(w, http.StatusBadRequest, "validation_error",
						fmt.Sprintf("Exercise type %q requires skill_kind %q, but skill has kind %q.", req.ExerciseType, expected, sk.SkillKind), false)
					return
				}
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

	const maxAssetBytes = 100 * 1024 * 1024 // 100 MB
	r.Body = http.MaxBytesReader(w, r.Body, maxAssetBytes)
	size, err := io.Copy(file, r.Body)
	if err != nil {
		var maxErr *http.MaxBytesError
		if errors.As(err, &maxErr) {
			writeError(w, http.StatusRequestEntityTooLarge, "payload_too_large", "Asset file exceeds 100 MB limit.", false)
		} else {
			writeError(w, http.StatusInternalServerError, "upload_failed", "Could not store uploaded asset.", true)
		}
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

// ── Learner: Courses + Skills ────────────────────────────────────────────────

func (s *Server) handleCourses(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	if r.Method != http.MethodGet {
		writeMethodNotAllowed(w)
		return
	}
	courses := s.repo.ListCourses("published")
	writeJSON(w, http.StatusOK, map[string]any{"data": courses, "meta": map[string]any{}})
}

func (s *Server) handleCourseByID(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	path := strings.TrimPrefix(r.URL.Path, "/v1/courses/")
	if strings.HasSuffix(path, "/modules") {
		id := strings.TrimSuffix(path, "/modules")
		mods := s.repo.ListModules("", id)
		var published []contracts.Module
		for _, m := range mods {
			if m.Status == "published" {
				published = append(published, m)
			}
		}
		writeJSON(w, http.StatusOK, map[string]any{"data": published, "meta": map[string]any{}})
		return
	}
	if r.Method != http.MethodGet {
		writeMethodNotAllowed(w)
		return
	}
	c, ok := s.repo.CourseByID(path)
	if !ok {
		writeNotFound(w)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": c, "meta": map[string]any{}})
}

func (s *Server) handleSkillExercises(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	// /v1/skills/:id/exercises  OR  /v1/modules/:id/skills (handled via handleModuleExercises)
	path := strings.TrimPrefix(r.URL.Path, "/v1/skills/")
	if !strings.HasSuffix(path, "/exercises") {
		writeNotFound(w)
		return
	}
	skillID := strings.TrimSuffix(path, "/exercises")
	if r.Method != http.MethodGet {
		writeMethodNotAllowed(w)
		return
	}
	exercises := s.repo.ExercisesBySkill(skillID)
	writeJSON(w, http.StatusOK, map[string]any{"data": exercises, "meta": map[string]any{}})
}

// ── Admin: Courses ────────────────────────────────────────────────────────────

func (s *Server) handleAdminCourses(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	switch r.Method {
	case http.MethodGet:
		writeJSON(w, http.StatusOK, map[string]any{"data": s.repo.ListCourses(""), "meta": map[string]any{}})
	case http.MethodPost:
		var c contracts.Course
		if err := json.NewDecoder(r.Body).Decode(&c); err != nil {
			writeError(w, http.StatusBadRequest, "invalid_body", err.Error(), false)
			return
		}
		created, err := s.repo.CreateCourse(c)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "create_failed", err.Error(), false)
			return
		}
		writeJSON(w, http.StatusCreated, map[string]any{"data": created, "meta": map[string]any{}})
	default:
		writeMethodNotAllowed(w)
	}
}

func (s *Server) handleAdminCourseByID(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	id := strings.TrimPrefix(r.URL.Path, "/v1/admin/courses/")
	switch r.Method {
	case http.MethodGet:
		c, ok := s.repo.CourseByID(id)
		if !ok {
			writeNotFound(w)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"data": c, "meta": map[string]any{}})
	case http.MethodPatch:
		var update contracts.Course
		if err := json.NewDecoder(r.Body).Decode(&update); err != nil {
			writeError(w, http.StatusBadRequest, "invalid_body", err.Error(), false)
			return
		}
		updated, ok := s.repo.UpdateCourse(id, update)
		if !ok {
			writeNotFound(w)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"data": updated, "meta": map[string]any{}})
	case http.MethodDelete:
		if !s.repo.DeleteCourse(id) {
			writeError(w, http.StatusBadRequest, "delete_failed", "course not found", false)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"data": map[string]any{}, "meta": map[string]any{}})
	default:
		writeMethodNotAllowed(w)
	}
}

// ── Admin: Modules ────────────────────────────────────────────────────────────

func (s *Server) handleAdminModules(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	switch r.Method {
	case http.MethodGet:
		kind := r.URL.Query().Get("kind")
		courseID := r.URL.Query().Get("course_id")
		writeJSON(w, http.StatusOK, map[string]any{"data": s.repo.ListModules(kind, courseID), "meta": map[string]any{}})
	case http.MethodPost:
		var m contracts.Module
		if err := json.NewDecoder(r.Body).Decode(&m); err != nil {
			writeError(w, http.StatusBadRequest, "invalid_body", err.Error(), false)
			return
		}
		created, err := s.repo.CreateModule(m)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "create_failed", err.Error(), false)
			return
		}
		writeJSON(w, http.StatusCreated, map[string]any{"data": created, "meta": map[string]any{}})
	default:
		writeMethodNotAllowed(w)
	}
}

func (s *Server) handleAdminModuleByID(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	id := strings.TrimPrefix(r.URL.Path, "/v1/admin/modules/")
	switch r.Method {
	case http.MethodGet:
		m, ok := s.repo.ModuleByID(id)
		if !ok {
			writeNotFound(w)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"data": m, "meta": map[string]any{}})
	case http.MethodPatch:
		var update contracts.Module
		if err := json.NewDecoder(r.Body).Decode(&update); err != nil {
			writeError(w, http.StatusBadRequest, "invalid_body", err.Error(), false)
			return
		}
		updated, ok := s.repo.UpdateModule(id, update)
		if !ok {
			writeNotFound(w)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"data": updated, "meta": map[string]any{}})
	case http.MethodDelete:
		if !s.repo.DeleteModule(id) {
			writeError(w, http.StatusBadRequest, "delete_failed", "module not found", false)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"data": map[string]any{}, "meta": map[string]any{}})
	default:
		writeMethodNotAllowed(w)
	}
}

// ── Admin: Skills ─────────────────────────────────────────────────────────────

func (s *Server) handleAdminSkills(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	switch r.Method {
	case http.MethodGet:
		moduleID := r.URL.Query().Get("module_id")
		var skills []contracts.Skill
		if moduleID != "" {
			skills = s.repo.AdminSkillsByModule(moduleID)
		} else {
			skills = s.repo.AllAdminSkills()
		}
		writeJSON(w, http.StatusOK, map[string]any{"data": skills, "meta": map[string]any{}})
	case http.MethodPost:
		var sk contracts.Skill
		if err := json.NewDecoder(r.Body).Decode(&sk); err != nil {
			writeError(w, http.StatusBadRequest, "invalid_body", err.Error(), false)
			return
		}
		created, err := s.repo.CreateSkill(sk)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "create_failed", err.Error(), false)
			return
		}
		writeJSON(w, http.StatusCreated, map[string]any{"data": created, "meta": map[string]any{}})
	default:
		writeMethodNotAllowed(w)
	}
}

func (s *Server) handleAdminSkillByID(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	id := strings.TrimPrefix(r.URL.Path, "/v1/admin/skills/")
	switch r.Method {
	case http.MethodGet:
		sk, ok := s.repo.SkillByID(id)
		if !ok {
			writeNotFound(w)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"data": sk, "meta": map[string]any{}})
	case http.MethodPatch:
		var update contracts.Skill
		if err := json.NewDecoder(r.Body).Decode(&update); err != nil {
			writeError(w, http.StatusBadRequest, "invalid_body", err.Error(), false)
			return
		}
		updated, ok := s.repo.UpdateSkill(id, update)
		if !ok {
			writeNotFound(w)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"data": updated, "meta": map[string]any{}})
	case http.MethodDelete:
		if !s.repo.DeleteSkill(id) {
			writeError(w, http.StatusBadRequest, "delete_failed", "skill not found", false)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"data": map[string]any{}, "meta": map[string]any{}})
	default:
		writeMethodNotAllowed(w)
	}
}

// handleModulesSkills handles GET /v1/modules/:id/skills
// Injected into handleModuleExercises path matching.
func (s *Server) handleModuleSkills(w http.ResponseWriter, moduleID string) {
	skills := s.repo.SkillsByModule(moduleID)
	writeJSON(w, http.StatusOK, map[string]any{"data": skills, "meta": map[string]any{}})
}
