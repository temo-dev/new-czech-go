package httpapi

// progress_handler.go — V19 GET /v1/users/me/progress.
//
// Aggregates user_skill_mastery rows on read. Per-module rows roll up into
// per-skill summaries, then per-skill mastery scores fold into a weighted
// overall_progress using MasteryConfig.Weights().

import (
	"net/http"
	"sort"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/processing"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

// SetMasteryDeps wires the V19 user_skill_mastery store + config. The progress
// route is only registered when both are present; passing nil is treated as
// "feature disabled" and the route returns 404.
func (s *Server) SetMasteryDeps(st store.SkillMasteryStore, cfg processing.MasteryConfig) {
	s.masteryStore = st
	s.masteryConfig = cfg
}

func (s *Server) handleUserProgress(w http.ResponseWriter, r *http.Request, user contracts.User) {
	if r.Method != http.MethodGet {
		writeMethodNotAllowed(w)
		return
	}
	if s.masteryStore == nil {
		writeJSON(w, http.StatusOK, map[string]any{
			"data": buildEmptyProgress(s.masteryConfig),
			"meta": map[string]any{},
		})
		return
	}

	rows := s.masteryStore.ListForUser(user.ID)
	progress := buildProgress(rows, s.masteryConfig)
	writeJSON(w, http.StatusOK, map[string]any{
		"data": progress,
		"meta": map[string]any{},
	})
}

// buildEmptyProgress returns the zero-row shape so the Flutter empty state
// can render exclusively from the API response.
func buildEmptyProgress(cfg processing.MasteryConfig) contracts.Progress {
	return contracts.Progress{
		OverallProgress: 0,
		OverallBand:     cfg.BandFromMastery(0),
		Skills:          []contracts.SkillProgress{},
		Bands:           bandsFromConfig(cfg),
		Weights:         cfg.Weights(),
	}
}

// buildProgress folds the flat per-module rows into per-skill groups and
// computes the weighted overall. Rows are assumed pre-sorted by skill_kind
// (the store's ListForUser guarantees that).
func buildProgress(rows []contracts.SkillMasteryRow, cfg processing.MasteryConfig) contracts.Progress {
	skills := groupBySkill(rows, cfg)
	overall := weightedOverall(skills, cfg)

	return contracts.Progress{
		OverallProgress: overall,
		OverallBand:     cfg.BandFromMastery(overall),
		Skills:          skills,
		Bands:           bandsFromConfig(cfg),
		Weights:         cfg.Weights(),
	}
}

func groupBySkill(rows []contracts.SkillMasteryRow, cfg processing.MasteryConfig) []contracts.SkillProgress {
	bySkill := map[string]*contracts.SkillProgress{}
	for _, r := range rows {
		group, ok := bySkill[r.SkillKind]
		if !ok {
			group = &contracts.SkillProgress{SkillKind: r.SkillKind}
			bySkill[r.SkillKind] = group
		}
		group.Modules = append(group.Modules, contracts.ModuleProgress{
			ModuleID:      r.ModuleID,
			Mastery:       r.MasteryScore,
			Band:          cfg.BandFromMastery(r.MasteryScore),
			AttemptsCount: r.AttemptsCount,
			LastAttemptAt: r.LastAttemptAt,
		})
		group.AttemptsCount += r.AttemptsCount
		if r.LastAttemptAt.After(group.LastAttemptAt) {
			group.LastAttemptAt = r.LastAttemptAt
		}
	}

	out := make([]contracts.SkillProgress, 0, len(bySkill))
	for _, g := range bySkill {
		// Per-skill mastery is the unweighted mean across the skill's modules
		// so a single weak module doesn't sink an otherwise-strong skill.
		var sum float64
		for _, m := range g.Modules {
			sum += m.Mastery
		}
		if len(g.Modules) > 0 {
			g.Mastery = sum / float64(len(g.Modules))
		}
		g.Band = cfg.BandFromMastery(g.Mastery)
		out = append(out, *g)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].SkillKind < out[j].SkillKind })
	return out
}

func weightedOverall(skills []contracts.SkillProgress, cfg processing.MasteryConfig) float64 {
	var num float64
	var denom int
	for _, s := range skills {
		w := cfg.OverallWeight(s.SkillKind)
		if w <= 0 {
			continue
		}
		num += s.Mastery * float64(w)
		denom += w
	}
	if denom == 0 {
		// Fall back to equal-weight mean across present skills so a learner
		// with rows but zero weights still sees a non-NaN overall.
		if len(skills) == 0 {
			return 0
		}
		var sum float64
		for _, s := range skills {
			sum += s.Mastery
		}
		return sum / float64(len(skills))
	}
	return num / float64(denom)
}

func bandsFromConfig(cfg processing.MasteryConfig) contracts.ProgressBands {
	return contracts.ProgressBands{
		NeedsWork: cfg.BandLearning,
		Solid:     cfg.BandSolid,
		Ready:     cfg.BandReady,
	}
}
