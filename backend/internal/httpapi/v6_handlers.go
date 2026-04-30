package httpapi

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/processing"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

// ── Vocabulary Sets ───────────────────────────────────────────────────────────

func (s *Server) handleAdminVocabSets(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	switch r.Method {
	case http.MethodGet:
		moduleID := r.URL.Query().Get("module_id")
		sets := s.repo.ListVocabularySets(moduleID)
		writeJSON(w, http.StatusOK, map[string]any{"data": sets, "meta": map[string]any{}})

	case http.MethodPost:
		var req struct {
			ModuleID        string                     `json:"module_id"`
			Title           string                     `json:"title"`
			Level           string                     `json:"level"`
			ExplanationLang string                     `json:"explanation_lang"`
			Items           []contracts.VocabularyItem `json:"items"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Title == "" || req.ModuleID == "" {
			writeError(w, http.StatusBadRequest, "validation_error", "title and module_id required.", false)
			return
		}
		if req.Level == "" {
			req.Level = "A2"
		}
		if req.ExplanationLang == "" {
			req.ExplanationLang = "vi"
		}
		set, err := s.repo.CreateVocabularySet(contracts.VocabularySet{
			ModuleID:        req.ModuleID,
			Title:           req.Title,
			Level:           req.Level,
			ExplanationLang: req.ExplanationLang,
			Status:          "draft",
		})
		if err != nil {
			writeError(w, http.StatusInternalServerError, "create_error", err.Error(), true)
			return
		}
		for i, item := range req.Items {
			item.SetID = set.ID
			item.SequenceNo = i
			s.repo.CreateVocabularyItem(item)
		}
		writeJSON(w, http.StatusCreated, map[string]any{"data": set, "meta": map[string]any{}})
	default:
		writeMethodNotAllowed(w)
	}
}

func (s *Server) handleAdminVocabSetByID(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	path := strings.TrimPrefix(r.URL.Path, "/v1/admin/vocabulary-sets/")

	// Handle items sub-resource: /vocabulary-sets/:id/items
	if strings.HasSuffix(path, "/items") {
		setID := strings.TrimSuffix(path, "/items")
		if r.Method == http.MethodGet {
			items := s.repo.ListVocabularyItems(setID)
			writeJSON(w, http.StatusOK, map[string]any{"data": items, "meta": map[string]any{}})
		} else if r.Method == http.MethodPost {
			var item contracts.VocabularyItem
			if err := json.NewDecoder(r.Body).Decode(&item); err != nil || item.Term == "" {
				writeError(w, http.StatusBadRequest, "validation_error", "term required.", false)
				return
			}
			item.SetID = setID
			created := s.repo.CreateVocabularyItem(item)
			writeJSON(w, http.StatusCreated, map[string]any{"data": created, "meta": map[string]any{}})
		} else {
			writeMethodNotAllowed(w)
		}
		return
	}

	id := path
	switch r.Method {
	case http.MethodGet:
		set, ok := s.repo.GetVocabularySet(id)
		if !ok {
			writeNotFound(w)
			return
		}
		items := s.repo.ListVocabularyItems(id)
		writeJSON(w, http.StatusOK, map[string]any{"data": map[string]any{"set": set, "items": items}, "meta": map[string]any{}})

	case http.MethodPatch:
		var update contracts.VocabularySet
		if err := json.NewDecoder(r.Body).Decode(&update); err != nil {
			writeError(w, http.StatusBadRequest, "validation_error", "invalid body.", false)
			return
		}
		set, ok := s.repo.UpdateVocabularySet(id, update)
		if !ok {
			writeNotFound(w)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"data": set, "meta": map[string]any{}})

	case http.MethodDelete:
		if !s.repo.DeleteVocabularySet(id) {
			writeNotFound(w)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"data": map[string]any{"id": id, "deleted": true}, "meta": map[string]any{}})

	default:
		writeMethodNotAllowed(w)
	}
}

// ── Grammar Rules ─────────────────────────────────────────────────────────────

func (s *Server) handleAdminGrammarRules(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	switch r.Method {
	case http.MethodGet:
		moduleID := r.URL.Query().Get("module_id")
		rules := s.repo.ListGrammarRules(moduleID)
		writeJSON(w, http.StatusOK, map[string]any{"data": rules, "meta": map[string]any{}})

	case http.MethodPost:
		var req struct {
			ModuleID        string            `json:"module_id"`
			Title           string            `json:"title"`
			Level           string            `json:"level"`
			ExplanationVI   string            `json:"explanation_vi"`
			RuleTable       map[string]string `json:"rule_table"`
			ConstraintsText string            `json:"constraints_text"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Title == "" || req.ModuleID == "" {
			writeError(w, http.StatusBadRequest, "validation_error", "title and module_id required.", false)
			return
		}
		if req.Level == "" {
			req.Level = "A2"
		}
		rule, err := s.repo.CreateGrammarRule(contracts.GrammarRule{
			ModuleID:        req.ModuleID,
			Title:           req.Title,
			Level:           req.Level,
			ExplanationVI:   req.ExplanationVI,
			RuleTable:       req.RuleTable,
			ConstraintsText: req.ConstraintsText,
			Status:          "draft",
		})
		if err != nil {
			writeError(w, http.StatusInternalServerError, "create_error", err.Error(), true)
			return
		}
		writeJSON(w, http.StatusCreated, map[string]any{"data": rule, "meta": map[string]any{}})

	default:
		writeMethodNotAllowed(w)
	}
}

func (s *Server) handleAdminGrammarRuleByID(w http.ResponseWriter, r *http.Request, u contracts.User) {
	path := strings.TrimPrefix(r.URL.Path, "/v1/admin/grammar-rules/")

	// Sub-resource: /grammar-rules/:id/image
	if strings.HasSuffix(path, "/image") {
		s.handleAdminGrammarRuleImage(w, r, u)
		return
	}

	id := path
	switch r.Method {
	case http.MethodGet:
		rule, ok := s.repo.GetGrammarRule(id)
		if !ok {
			writeNotFound(w)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"data": rule, "meta": map[string]any{}})

	case http.MethodPatch:
		var update contracts.GrammarRule
		if err := json.NewDecoder(r.Body).Decode(&update); err != nil {
			writeError(w, http.StatusBadRequest, "validation_error", "invalid body.", false)
			return
		}
		rule, ok := s.repo.UpdateGrammarRule(id, update)
		if !ok {
			writeNotFound(w)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"data": rule, "meta": map[string]any{}})

	case http.MethodDelete:
		if !s.repo.DeleteGrammarRule(id) {
			writeNotFound(w)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"data": map[string]any{"id": id, "deleted": true}, "meta": map[string]any{}})

	default:
		writeMethodNotAllowed(w)
	}
}

// ── Content Generation Jobs ───────────────────────────────────────────────────

func (s *Server) handleAdminGenJobs(w http.ResponseWriter, r *http.Request, user contracts.User) {
	switch r.Method {
	case http.MethodGet:
		// List jobs (basic — filter by source_id or status via query params, not yet impl)
		writeJSON(w, http.StatusOK, map[string]any{"data": []any{}, "meta": map[string]any{}})

	case http.MethodPost:
		var req contracts.GenerationJobInput
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil ||
			req.SourceType == "" || req.SourceID == "" || req.ModuleID == "" || len(req.ExerciseTypes) == 0 {
			writeError(w, http.StatusBadRequest, "validation_error", "source_type, source_id, module_id, exercise_types required.", false)
			return
		}
		if req.SourceType != "vocabulary_set" && req.SourceType != "grammar_rule" {
			writeError(w, http.StatusBadRequest, "validation_error", "source_type must be vocabulary_set or grammar_rule.", false)
			return
		}

		// Rate limit: 1 active job per admin per module
		if existing, ok := s.repo.FindActiveGenerationJob("admin", req.ModuleID); ok {
			writeJSON(w, http.StatusConflict, map[string]any{
				"error": map[string]any{
					"code":    "active_job_exists",
					"message": "An active generation job already exists for this module. Wait or reject it first.",
					"job_id":  existing.ID,
				},
			})
			return
		}

		if s.contentGenerator == nil {
			writeError(w, http.StatusServiceUnavailable, "llm_unavailable", "LLM not configured (ANTHROPIC_API_KEY missing).", false)
			return
		}

		inputJSON, _ := json.Marshal(req)
		job := s.repo.CreateGenerationJob(contracts.ContentGenerationJob{
			ModuleID:     req.ModuleID,
			SourceType:   req.SourceType,
			SourceID:     req.SourceID,
			RequestedBy:  "admin",
			InputPayload: inputJSON,
			Provider:     "claude",
			Model:        "claude-sonnet-4-6",
		})

		// Spawn async generation goroutine
		go s.runGenerationJob(job.ID, req)

		writeJSON(w, http.StatusAccepted, map[string]any{
			"data": map[string]any{"job_id": job.ID, "status": "pending"},
			"meta": map[string]any{},
		})

	default:
		writeMethodNotAllowed(w)
	}
}

func (s *Server) handleAdminGenJobByID(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	path := strings.TrimPrefix(r.URL.Path, "/v1/admin/content-generation-jobs/")

	// Sub-actions: /:id/draft, /:id/publish, /:id/reject
	if idx := strings.LastIndex(path, "/"); idx >= 0 {
		id := path[:idx]
		action := path[idx+1:]
		switch action {
		case "draft":
			if r.Method != http.MethodPatch {
				writeMethodNotAllowed(w)
				return
			}
			var body struct {
				EditedPayload json.RawMessage `json:"edited_payload"`
			}
			if err := json.NewDecoder(r.Body).Decode(&body); err != nil || len(body.EditedPayload) == 0 {
				writeError(w, http.StatusBadRequest, "validation_error", "edited_payload required.", false)
				return
			}
			if !s.repo.UpdateGenerationJobDraft(id, body.EditedPayload) {
				writeNotFound(w)
				return
			}
			writeJSON(w, http.StatusOK, map[string]any{"data": map[string]any{"saved": true}, "meta": map[string]any{}})
			return

		case "publish":
			if r.Method != http.MethodPost {
				writeMethodNotAllowed(w)
				return
			}
			s.handlePublishGenJob(w, id)
			return

		case "reject":
			if r.Method != http.MethodPost {
				writeMethodNotAllowed(w)
				return
			}
			if !s.repo.UpdateGenerationJobRejected(id) {
				writeNotFound(w)
				return
			}
			writeJSON(w, http.StatusOK, map[string]any{"data": map[string]any{"rejected": true}, "meta": map[string]any{}})
			return
		}
	}

	// GET /:id — poll status
	id := path
	job, ok := s.repo.GetGenerationJob(id)
	if !ok {
		writeNotFound(w)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": store.JobViewFromDB(job), "meta": map[string]any{}})
}

// handlePublishGenJob validates all exercises then creates them atomically.
func (s *Server) handlePublishGenJob(w http.ResponseWriter, jobID string) {
	job, ok := s.repo.GetGenerationJob(jobID)
	if !ok {
		writeNotFound(w)
		return
	}
	if job.Status != "generated" {
		writeError(w, http.StatusBadRequest, "validation_error",
			"job must be in 'generated' status to publish.", false)
		return
	}

	payload := job.EditedPayload
	if len(payload) == 0 {
		payload = job.GeneratedPayload
	}

	var gp contracts.GeneratedPayload
	if err := json.Unmarshal(payload, &gp); err != nil {
		writeError(w, http.StatusBadRequest, "validation_error", "invalid payload JSON.", false)
		return
	}

	// Validate all exercises first (all-or-nothing)
	type validationError struct {
		Index   int      `json:"index"`
		Type    string   `json:"exercise_type"`
		Errors  []string `json:"errors"`
	}
	var valErrs []validationError
	for i, ex := range gp.Exercises {
		errs := processing.ValidateGeneratedExercise(ex)
		if len(errs) > 0 {
			valErrs = append(valErrs, validationError{Index: i, Type: ex.ExerciseType, Errors: errs})
		}
	}
	if len(valErrs) > 0 {
		writeJSON(w, http.StatusBadRequest, map[string]any{
			"error": map[string]any{
				"code":              "validation_error",
				"message":           "Some exercises failed validation. Nothing published.",
				"validation_errors": valErrs,
			},
		})
		return
	}

	skillKind := skillKindFromSourceType(job.SourceType)

	// Pre-fetch vocab items once to avoid N+1 queries when injecting images.
	vocabItemsByTerm := map[string]contracts.VocabularyItem{}
	if job.SourceType == "vocabulary_set" {
		for _, item := range s.repo.ListVocabularyItems(job.SourceID) {
			vocabItemsByTerm[item.Term] = item
		}
	}

	// Publish all exercises
	exerciseIDs := make([]string, 0, len(gp.Exercises))
	for _, ex := range gp.Exercises {
		exercise, err := processing.BuildExerciseFromGenerated(ex)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "build_error", err.Error(), true)
			return
		}
		exercise.ModuleID = job.ModuleID
		exercise.SkillKind = skillKind
		exercise.SourceType = job.SourceType
		exercise.SourceID = job.SourceID
		exercise.GenerationJobID = job.ID

		// Inject vocabulary item image into quizcard detail when available.
		if ex.ExerciseType == "quizcard_basic" {
			if item, ok := vocabItemsByTerm[ex.FrontText]; ok && item.ImageAssetID != "" {
				if detail, ok := exercise.Detail.(contracts.QuizcardBasicDetail); ok {
					detail.ImageAssetID = item.ImageAssetID
					exercise.Detail = detail
				}
			}
		}

		created := s.repo.CreateExercise(exercise)
		exerciseIDs = append(exerciseIDs, created.ID)
	}

	s.repo.UpdateGenerationJobPublished(jobID)

	// Update the source (vocabulary_set / grammar_rule) status to "published"
	switch job.SourceType {
	case "vocabulary_set":
		if set, ok := s.repo.GetVocabularySet(job.SourceID); ok {
			set.Status = "published"
			s.repo.UpdateVocabularySet(job.SourceID, set)
		}
	case "grammar_rule":
		if rule, ok := s.repo.GetGrammarRule(job.SourceID); ok {
			rule.Status = "published"
			s.repo.UpdateGrammarRule(job.SourceID, rule)
		}
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"data": map[string]any{"exercise_ids": exerciseIDs, "count": len(exerciseIDs)},
		"meta": map[string]any{},
	})
}

// runGenerationJob is the goroutine that calls LLM and updates job status.
func (s *Server) runGenerationJob(jobID string, req contracts.GenerationJobInput) {
	s.repo.UpdateGenerationJobRunning(jobID)
	start := time.Now()
	ctx, cancel := context.WithTimeout(context.Background(), 200*time.Second)
	defer cancel()

	var payload *contracts.GeneratedPayload
	var genErr error

	switch req.SourceType {
	case "vocabulary_set":
		set, ok := s.repo.GetVocabularySet(req.SourceID)
		if !ok {
			s.repo.UpdateGenerationJobFailed(jobID, "vocabulary_set not found: "+req.SourceID)
			return
		}
		items := s.repo.ListVocabularyItems(req.SourceID)
		payload, genErr = s.contentGenerator.GenerateVocabulary(ctx, processing.VocabularyGenerationInput{
			Items:           items,
			Level:           set.Level,
			ExplanationLang: set.ExplanationLang,
			ExerciseTypes:   req.ExerciseTypes,
			NumPerType:      req.NumPerType,
		})

	case "grammar_rule":
		rule, ok := s.repo.GetGrammarRule(req.SourceID)
		if !ok {
			s.repo.UpdateGenerationJobFailed(jobID, "grammar_rule not found: "+req.SourceID)
			return
		}
		payload, genErr = s.contentGenerator.GenerateGrammar(ctx, processing.GrammarGenerationInput{
			Title:         rule.Title,
			Level:         rule.Level,
			ExplanationVI: rule.ExplanationVI,
			Forms:         rule.RuleTable,
			Constraints:   rule.ConstraintsText,
			ExerciseTypes: req.ExerciseTypes,
			NumPerType:    req.NumPerType,
		})

	default:
		s.repo.UpdateGenerationJobFailed(jobID, "unknown source_type: "+req.SourceType)
		return
	}

	durationMs := int(time.Since(start).Milliseconds())

	if genErr != nil {
		log.Printf("content generation job %s failed: %v", jobID, genErr)
		s.repo.UpdateGenerationJobFailed(jobID, genErr.Error())
		return
	}

	payloadJSON, err := json.Marshal(payload)
	if err != nil {
		s.repo.UpdateGenerationJobFailed(jobID, "marshal payload: "+err.Error())
		return
	}

	s.repo.UpdateGenerationJobGenerated(jobID, payloadJSON, 0, 0, 0, durationMs)
	log.Printf("content generation job %s completed: %d exercises in %dms", jobID, len(payload.Exercises), durationMs)
}

// skillKindFromSourceType maps content generation source types to skill kinds.
func skillKindFromSourceType(sourceType string) string {
	switch sourceType {
	case "vocabulary_set":
		return "tu_vung"
	case "grammar_rule":
		return "ngu_phap"
	}
	return ""
}
