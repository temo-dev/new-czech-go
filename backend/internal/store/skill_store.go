package store

import (
	"fmt"
	"sync"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

type SkillStore interface {
	SkillsByModule(moduleID string) []contracts.Skill
	SkillByID(id string) (contracts.Skill, bool)
	CreateSkill(s contracts.Skill) (contracts.Skill, error)
	UpdateSkill(id string, update contracts.Skill) (contracts.Skill, bool)
	DeleteSkill(id string) bool
}

type memorySkillStore struct {
	mu     sync.RWMutex
	skills map[string]*contracts.Skill
	nextID int
}

func newMemorySkillStore(seed []contracts.Skill) SkillStore {
	m := &memorySkillStore{
		skills: make(map[string]*contracts.Skill, len(seed)),
		nextID: len(seed) + 1,
	}
	for _, sk := range seed {
		cp := sk
		m.skills[sk.ID] = &cp
	}
	return m
}

func (s *memorySkillStore) SkillsByModule(moduleID string) []contracts.Skill {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]contracts.Skill, 0)
	for _, sk := range s.skills {
		if sk.ModuleID == moduleID && sk.Status == "published" {
			out = append(out, *sk)
		}
	}
	return out
}

func (s *memorySkillStore) SkillByID(id string) (contracts.Skill, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	sk, ok := s.skills[id]
	if !ok {
		return contracts.Skill{}, false
	}
	return *sk, true
}

func (s *memorySkillStore) CreateSkill(sk contracts.Skill) (contracts.Skill, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	sk.ID = fmt.Sprintf("skill-%d", s.nextID)
	s.nextID++
	if sk.Status == "" {
		sk.Status = "draft"
	}
	cp := sk
	s.skills[sk.ID] = &cp
	return cp, nil
}

func (s *memorySkillStore) UpdateSkill(id string, update contracts.Skill) (contracts.Skill, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	existing, ok := s.skills[id]
	if !ok {
		return contracts.Skill{}, false
	}
	if update.Title != "" {
		existing.Title = update.Title
	}
	if update.Status != "" {
		existing.Status = update.Status
	}
	if update.SequenceNo != 0 {
		existing.SequenceNo = update.SequenceNo
	}
	return *existing, true
}

func (s *memorySkillStore) DeleteSkill(id string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, ok := s.skills[id]
	if !ok {
		return false
	}
	delete(s.skills, id)
	return true
}

// skillKindLabel returns a Vietnamese display label for a skill kind.
func skillKindLabel(kind string) string {
	switch kind {
	case "noi":
		return "Kỹ năng nói"
	case "nghe":
		return "Kỹ năng nghe"
	case "doc":
		return "Kỹ năng đọc"
	case "viet":
		return "Kỹ năng viết"
	case "tu_vung":
		return "Từ vựng"
	case "ngu_phap":
		return "Ngữ pháp"
	default:
		return kind
	}
}

func seedSkills(modules []contracts.Module) []contracts.Skill {
	var out []contracts.Skill
	for i, m := range modules {
		if m.ModuleKind != "daily_plan" {
			continue
		}
		out = append(out, contracts.Skill{
			ID:         fmt.Sprintf("skill-noi-%s", m.ID),
			ModuleID:   m.ID,
			SkillKind:  "noi",
			Title:      skillKindLabel("noi"),
			SequenceNo: 1,
			Status:     "published",
		})
		_ = i
	}
	return out
}
