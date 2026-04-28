package store

import (
	"fmt"
	"sync"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

type VocabularyStore interface {
	CreateVocabularySet(set contracts.VocabularySet) (contracts.VocabularySet, error)
	GetVocabularySet(id string) (contracts.VocabularySet, bool)
	ListVocabularySets(skillID string) []contracts.VocabularySet
	UpdateVocabularySet(id string, update contracts.VocabularySet) (contracts.VocabularySet, bool)
	DeleteVocabularySet(id string) bool
	CreateVocabularyItem(item contracts.VocabularyItem) contracts.VocabularyItem
	ListVocabularyItems(setID string) []contracts.VocabularyItem
	DeleteVocabularyItem(id string) bool
}

type memoryVocabularyStore struct {
	mu      sync.RWMutex
	sets    map[string]*contracts.VocabularySet
	items   map[string]*contracts.VocabularyItem
	nextSet int
	nextItem int
}

func newMemoryVocabularyStore() VocabularyStore {
	return &memoryVocabularyStore{
		sets:  make(map[string]*contracts.VocabularySet),
		items: make(map[string]*contracts.VocabularyItem),
		nextSet: 1,
		nextItem: 1,
	}
}

func (s *memoryVocabularyStore) CreateVocabularySet(set contracts.VocabularySet) (contracts.VocabularySet, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	set.ID = fmt.Sprintf("vocset-%d", s.nextSet)
	s.nextSet++
	if set.Status == "" {
		set.Status = "draft"
	}
	cp := set
	s.sets[set.ID] = &cp
	return cp, nil
}

func (s *memoryVocabularyStore) GetVocabularySet(id string) (contracts.VocabularySet, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	v, ok := s.sets[id]
	if !ok {
		return contracts.VocabularySet{}, false
	}
	return *v, true
}

func (s *memoryVocabularyStore) ListVocabularySets(skillID string) []contracts.VocabularySet {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]contracts.VocabularySet, 0)
	for _, v := range s.sets {
		if skillID == "" || v.SkillID == skillID {
			out = append(out, *v)
		}
	}
	return out
}

func (s *memoryVocabularyStore) UpdateVocabularySet(id string, update contracts.VocabularySet) (contracts.VocabularySet, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	existing, ok := s.sets[id]
	if !ok {
		return contracts.VocabularySet{}, false
	}
	if update.Title != "" {
		existing.Title = update.Title
	}
	if update.Level != "" {
		existing.Level = update.Level
	}
	if update.Status != "" {
		existing.Status = update.Status
	}
	if update.ExplanationLang != "" {
		existing.ExplanationLang = update.ExplanationLang
	}
	return *existing, true
}

func (s *memoryVocabularyStore) DeleteVocabularySet(id string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.sets[id]; !ok {
		return false
	}
	delete(s.sets, id)
	// cascade delete items
	for itemID, item := range s.items {
		if item.SetID == id {
			delete(s.items, itemID)
		}
	}
	return true
}

func (s *memoryVocabularyStore) CreateVocabularyItem(item contracts.VocabularyItem) contracts.VocabularyItem {
	s.mu.Lock()
	defer s.mu.Unlock()
	item.ID = fmt.Sprintf("vocitem-%d", s.nextItem)
	s.nextItem++
	cp := item
	s.items[item.ID] = &cp
	return cp
}

func (s *memoryVocabularyStore) ListVocabularyItems(setID string) []contracts.VocabularyItem {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]contracts.VocabularyItem, 0)
	for _, v := range s.items {
		if v.SetID == setID {
			out = append(out, *v)
		}
	}
	return out
}

func (s *memoryVocabularyStore) DeleteVocabularyItem(id string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.items[id]; !ok {
		return false
	}
	delete(s.items, id)
	return true
}
