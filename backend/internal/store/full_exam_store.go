package store

import (
	"sync"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// FullExamStore persists full exam sessions (písemná + ústní combined).
type FullExamStore interface {
	GetFullExamSession(id string) (contracts.FullExamSession, bool)
	SetFullExamSession(session contracts.FullExamSession)
	ListFullExamSessions(learnerID string) []contracts.FullExamSession
}

// ── Memory implementation ─────────────────────────────────────────────────────

type memoryFullExamStore struct {
	mu       sync.RWMutex
	sessions map[string]contracts.FullExamSession
}

func newMemoryFullExamStore() FullExamStore {
	return &memoryFullExamStore{sessions: map[string]contracts.FullExamSession{}}
}

func (s *memoryFullExamStore) GetFullExamSession(id string) (contracts.FullExamSession, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	sess, ok := s.sessions[id]
	return sess, ok
}

func (s *memoryFullExamStore) SetFullExamSession(session contracts.FullExamSession) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.sessions[session.ID] = session
}

func (s *memoryFullExamStore) ListFullExamSessions(learnerID string) []contracts.FullExamSession {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]contracts.FullExamSession, 0)
	for _, sess := range s.sessions {
		if sess.LearnerID == learnerID {
			out = append(out, sess)
		}
	}
	return out
}
