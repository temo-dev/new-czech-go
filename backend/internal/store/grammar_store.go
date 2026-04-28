package store

import (
	"fmt"
	"sync"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

type GrammarStore interface {
	CreateGrammarRule(rule contracts.GrammarRule) (contracts.GrammarRule, error)
	GetGrammarRule(id string) (contracts.GrammarRule, bool)
	ListGrammarRules(skillID string) []contracts.GrammarRule
	UpdateGrammarRule(id string, update contracts.GrammarRule) (contracts.GrammarRule, bool)
	DeleteGrammarRule(id string) bool
}

type memoryGrammarStore struct {
	mu    sync.RWMutex
	rules map[string]*contracts.GrammarRule
	next  int
}

func newMemoryGrammarStore() GrammarStore {
	return &memoryGrammarStore{
		rules: make(map[string]*contracts.GrammarRule),
		next:  1,
	}
}

func (s *memoryGrammarStore) CreateGrammarRule(rule contracts.GrammarRule) (contracts.GrammarRule, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	rule.ID = fmt.Sprintf("grammar-%d", s.next)
	s.next++
	if rule.Status == "" {
		rule.Status = "draft"
	}
	cp := rule
	s.rules[rule.ID] = &cp
	return cp, nil
}

func (s *memoryGrammarStore) GetGrammarRule(id string) (contracts.GrammarRule, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	r, ok := s.rules[id]
	if !ok {
		return contracts.GrammarRule{}, false
	}
	return *r, true
}

func (s *memoryGrammarStore) ListGrammarRules(skillID string) []contracts.GrammarRule {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]contracts.GrammarRule, 0)
	for _, r := range s.rules {
		if skillID == "" || r.SkillID == skillID {
			out = append(out, *r)
		}
	}
	return out
}

func (s *memoryGrammarStore) UpdateGrammarRule(id string, update contracts.GrammarRule) (contracts.GrammarRule, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	existing, ok := s.rules[id]
	if !ok {
		return contracts.GrammarRule{}, false
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
	if update.ExplanationVI != "" {
		existing.ExplanationVI = update.ExplanationVI
	}
	if update.ConstraintsText != "" {
		existing.ConstraintsText = update.ConstraintsText
	}
	if len(update.RuleTable) > 0 {
		existing.RuleTable = update.RuleTable
	}
	return *existing, true
}

func (s *memoryGrammarStore) DeleteGrammarRule(id string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.rules[id]; !ok {
		return false
	}
	delete(s.rules, id)
	return true
}
