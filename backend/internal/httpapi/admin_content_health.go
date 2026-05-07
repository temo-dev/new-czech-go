package httpapi

import (
	"net/http"
	"strings"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

// V22 CMS Catch-Up — Phase E. Content Health Report.
// Read-only aggregator that surfaces content rot — orphan exercises,
// missing audio, empty containers — so the solo admin can spot drift
// before it shows up in a learner-facing flow. Six fixed checks,
// on-demand only (no cron V22).

const contentHealthItemCap = 50

// ContentHealthCheck is the per-rule wire shape returned by
// GET /v1/admin/content-health.
type ContentHealthCheck struct {
	ID          string              `json:"id"`
	Label       string              `json:"label"`
	Description string              `json:"description"`
	Count       int                 `json:"count"`
	Items       []ContentHealthItem `json:"items"`
	Truncated   bool                `json:"truncated"`
}

// ContentHealthItem is one row of evidence for a check. EntityType +
// EntityID let the CMS click-through to the offending row.
type ContentHealthItem struct {
	EntityType string `json:"entity_type"`
	EntityID   string `json:"entity_id"`
	Label      string `json:"label"`
	Extra      string `json:"extra,omitempty"`
}

// ValidationFlags is the V23 per-exercise quality projection rendered
// inline in the admin Exercises list. Each flag is true when the
// corresponding rule fires; false otherwise. The aggregate
// content-health checks (V22) call this helper per row so a single
// rule definition serves both the per-row badge and the aggregate
// dashboard count.
type ValidationFlags struct {
	MissingAudio         bool `json:"missing_audio"`
	MissingSentenceAudio bool `json:"missing_sentence_audio"`
	Orphan               bool `json:"orphan"`
	MissingSample        bool `json:"missing_sample"`
	Unpublished          bool `json:"unpublished"`
}

// exerciseWithFlags is the wire shape returned by GET
// /v1/admin/exercises — flat-merged Exercise plus the per-row V23
// quality projection. Existing callers that ignore the new field
// keep working unchanged.
type exerciseWithFlags struct {
	contracts.Exercise
	ValidationFlags ValidationFlags `json:"validation_flags"`
}

// computeValidationFlags evaluates the 5 V23 quality rules against a
// single Exercise. The store argument is needed for has-row checks on
// the audio + sentence-audio sub-stores.
func computeValidationFlags(repo *store.MemoryStore, ex contracts.Exercise) ValidationFlags {
	missingAudio := false
	if ex.SkillKind == "nghe" {
		if _, ok := repo.ExerciseAudioByExercise(ex.ID); !ok {
			missingAudio = true
		}
	}
	missingSentenceAudio := false
	if ex.ExerciseType == "psani_3_dictation" {
		if rows := repo.SentenceAudiosByExercise(ex.ID); len(rows) == 0 {
			missingSentenceAudio = true
		}
	}
	missingSample := false
	if (ex.SkillKind == "noi" || ex.SkillKind == "viet") &&
		ex.SampleAnswerEnabled &&
		strings.TrimSpace(ex.SampleAnswerText) == "" {
		missingSample = true
	}
	return ValidationFlags{
		MissingAudio:         missingAudio,
		MissingSentenceAudio: missingSentenceAudio,
		Orphan:               ex.Pool == "course" && ex.ModuleID == "",
		MissingSample:        missingSample,
		Unpublished:          ex.Status == "draft",
	}
}

// handleAdminContentHealth serves GET /v1/admin/content-health. Runs
// all six checks against the in-memory facade and returns the results.
func (s *Server) handleAdminContentHealth(w http.ResponseWriter, r *http.Request, _ contracts.User) {
	if r.Method != http.MethodGet {
		writeMethodNotAllowed(w)
		return
	}
	results := []ContentHealthCheck{
		s.checkOrphanExercises(),
		s.checkMissingListeningAudio(),
		s.checkModuleEmpty(),
		s.checkMockTestMissingSection(),
		s.checkCourseMissingModule(),
		s.checkDictationMissingSentenceAudio(),
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"checked_at": time.Now().UTC().Format(time.RFC3339),
		"checks":     results,
	})
}

// appendCapped pushes one item into the slice unless the cap has been
// reached; returns the new slice + a hit flag so the caller knows when
// to mark Truncated=true on the next overflow.
func appendCapped(items []ContentHealthItem, item ContentHealthItem) ([]ContentHealthItem, bool) {
	if len(items) >= contentHealthItemCap {
		return items, true
	}
	return append(items, item), false
}

// 1. orphan_exercises — pool=course but module_id is empty.
func (s *Server) checkOrphanExercises() ContentHealthCheck {
	out := ContentHealthCheck{
		ID:          "orphan_exercises",
		Label:       "Bài tập mồ côi",
		Description: "pool=course nhưng module_id rỗng",
		Items:       []ContentHealthItem{},
	}
	for _, ex := range s.repo.ListExercises("course") {
		if ex.ModuleID != "" {
			continue
		}
		out.Count++
		var truncated bool
		out.Items, truncated = appendCapped(out.Items, ContentHealthItem{
			EntityType: "exercise",
			EntityID:   ex.ID,
			Label:      ex.Title,
			Extra:      "skill=" + ex.SkillKind,
		})
		if truncated {
			out.Truncated = true
		}
	}
	return out
}

// 2. missing_audio_listening — skill_kind=nghe but exercise_audio missing.
func (s *Server) checkMissingListeningAudio() ContentHealthCheck {
	out := ContentHealthCheck{
		ID:          "missing_audio_listening",
		Label:       "Bài nghe thiếu audio",
		Description: "skill_kind=nghe chưa có exercise_audio",
		Items:       []ContentHealthItem{},
	}
	for _, ex := range s.repo.ListExercises("") {
		if ex.SkillKind != "nghe" {
			continue
		}
		if _, ok := s.repo.ExerciseAudioByExercise(ex.ID); ok {
			continue
		}
		out.Count++
		var truncated bool
		out.Items, truncated = appendCapped(out.Items, ContentHealthItem{
			EntityType: "exercise",
			EntityID:   ex.ID,
			Label:      ex.Title,
		})
		if truncated {
			out.Truncated = true
		}
	}
	return out
}

// 3. module_empty — module without any exercise. V22 simplifies the
// "untested skill" rule down to "module has zero exercises". Per-skill
// granularity defers to V23+.
func (s *Server) checkModuleEmpty() ContentHealthCheck {
	out := ContentHealthCheck{
		ID:          "module_empty",
		Label:       "Module trống",
		Description: "module không có bài tập nào",
		Items:       []ContentHealthItem{},
	}
	exercises := s.repo.ListExercises("")
	hasExercise := map[string]bool{}
	for _, ex := range exercises {
		if ex.ModuleID != "" {
			hasExercise[ex.ModuleID] = true
		}
	}
	for _, m := range s.repo.ListModules("", "") {
		if hasExercise[m.ID] {
			continue
		}
		out.Count++
		var truncated bool
		out.Items, truncated = appendCapped(out.Items, ContentHealthItem{
			EntityType: "module",
			EntityID:   m.ID,
			Label:      m.Title,
		})
		if truncated {
			out.Truncated = true
		}
	}
	return out
}

// 4. mock_test_missing_section — mock_tests with zero sections.
func (s *Server) checkMockTestMissingSection() ContentHealthCheck {
	out := ContentHealthCheck{
		ID:          "mock_test_missing_section",
		Label:       "Mock test thiếu section",
		Description: "mock_test chưa có phần thi nào",
		Items:       []ContentHealthItem{},
	}
	for _, mt := range s.repo.ListMockTests("") {
		if len(mt.Sections) > 0 {
			continue
		}
		out.Count++
		var truncated bool
		out.Items, truncated = appendCapped(out.Items, ContentHealthItem{
			EntityType: "mock_test",
			EntityID:   mt.ID,
			Label:      mt.Title,
			Extra:      mt.Status,
		})
		if truncated {
			out.Truncated = true
		}
	}
	return out
}

// 5. course_missing_module — course without any module.
func (s *Server) checkCourseMissingModule() ContentHealthCheck {
	out := ContentHealthCheck{
		ID:          "course_missing_module",
		Label:       "Course thiếu module",
		Description: "course chưa có module nào",
		Items:       []ContentHealthItem{},
	}
	courses := s.repo.ListCourses("")
	for _, c := range courses {
		modules := s.repo.ListModules("", c.ID)
		if len(modules) > 0 {
			continue
		}
		out.Count++
		var truncated bool
		out.Items, truncated = appendCapped(out.Items, ContentHealthItem{
			EntityType: "course",
			EntityID:   c.ID,
			Label:      c.Title,
		})
		if truncated {
			out.Truncated = true
		}
	}
	return out
}

// 6. dictation_missing_sentence_audio — psani_3_dictation exercises
// without per-sentence audio rows.
func (s *Server) checkDictationMissingSentenceAudio() ContentHealthCheck {
	out := ContentHealthCheck{
		ID:          "dictation_missing_sentence_audio",
		Label:       "Dictation thiếu audio câu",
		Description: "psani_3_dictation chưa có exercise_sentence_audio",
		Items:       []ContentHealthItem{},
	}
	for _, ex := range s.repo.ListExercises("") {
		if ex.ExerciseType != "psani_3_dictation" {
			continue
		}
		if rows := s.repo.SentenceAudiosByExercise(ex.ID); len(rows) > 0 {
			continue
		}
		out.Count++
		var truncated bool
		out.Items, truncated = appendCapped(out.Items, ContentHealthItem{
			EntityType: "exercise",
			EntityID:   ex.ID,
			Label:      ex.Title,
		})
		if truncated {
			out.Truncated = true
		}
	}
	return out
}
