package store

import (
	"fmt"
	"sync"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

type ModuleStore interface {
	// kind="" means all kinds; courseID="" means all courses
	ListModules(kind, courseID string) []contracts.Module
	ModuleByID(id string) (contracts.Module, bool)
	CreateModule(m contracts.Module) (contracts.Module, error)
	UpdateModule(id string, update contracts.Module) (contracts.Module, bool)
	DeleteModule(id string) bool
}

type memoryModuleStore struct {
	mu      sync.RWMutex
	modules map[string]*contracts.Module
	nextID  int
}

func newMemoryModuleStore(seed []contracts.Module) ModuleStore {
	m := &memoryModuleStore{
		modules: make(map[string]*contracts.Module, len(seed)),
		nextID:  len(seed) + 1,
	}
	for _, mod := range seed {
		cp := mod
		m.modules[mod.ID] = &cp
	}
	return m
}

func (s *memoryModuleStore) ListModules(kind, courseID string) []contracts.Module {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]contracts.Module, 0, len(s.modules))
	for _, m := range s.modules {
		if kind != "" && m.ModuleKind != kind {
			continue
		}
		if courseID != "" && m.CourseID != courseID {
			continue
		}
		out = append(out, *m)
	}
	return out
}

func (s *memoryModuleStore) ModuleByID(id string) (contracts.Module, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	m, ok := s.modules[id]
	if !ok {
		return contracts.Module{}, false
	}
	return *m, true
}

func (s *memoryModuleStore) CreateModule(m contracts.Module) (contracts.Module, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	m.ID = fmt.Sprintf("module-%d", s.nextID)
	s.nextID++
	if m.Status == "" {
		m.Status = "draft"
	}
	cp := m
	s.modules[m.ID] = &cp
	return cp, nil
}

func (s *memoryModuleStore) UpdateModule(id string, update contracts.Module) (contracts.Module, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	existing, ok := s.modules[id]
	if !ok {
		return contracts.Module{}, false
	}
	if update.Title != "" {
		existing.Title = update.Title
	}
	if update.Description != "" {
		existing.Description = update.Description
	}
	if update.Status != "" {
		existing.Status = update.Status
	}
	if update.CourseID != "" {
		existing.CourseID = update.CourseID
	}
	if update.SequenceNo != 0 {
		existing.SequenceNo = update.SequenceNo
	}
	return *existing, true
}

func (s *memoryModuleStore) DeleteModule(id string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, ok := s.modules[id]
	if !ok {
		return false
	}
	delete(s.modules, id)
	return true
}
