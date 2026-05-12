package processing

import (
	"context"
	"log"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// ExamTimerStore is the narrow surface the sweeper needs. The real
// `*store.MemoryStore` satisfies it; tests can substitute fakes.
type ExamTimerStore interface {
	ListExpiredMockExams(now time.Time) ([]string, error)
	ExpireMockExam(sessionID string) (contracts.MockExamSession, error)
}

// StartMockExamTimerSweeper runs a single goroutine that polls the store
// every `interval` for in_progress mock-exam sessions whose timer has
// expired. Each hit is auto-completed via ExpireMockExam (idempotent).
//
// The goroutine returns when `ctx` is cancelled. There is no second
// goroutine, no queue, no cron — this stays inside the V1 infrastructure
// baseline. `interval` defaults to 60s when zero is passed.
//
// V39.
func StartMockExamTimerSweeper(ctx context.Context, store ExamTimerStore, interval time.Duration) {
	if interval <= 0 {
		interval = 60 * time.Second
	}
	go func() {
		ticker := time.NewTicker(interval)
		defer ticker.Stop()
		// Run an immediate sweep so freshly-started servers don't wait one
		// interval before clearing already-expired rows from a prior boot.
		runMockExamTimerSweep(store)
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				runMockExamTimerSweep(store)
			}
		}
	}()
}

// runMockExamTimerSweep is exported via the package for testing without
// having to spin up the goroutine. One call performs one pass.
func runMockExamTimerSweep(store ExamTimerStore) {
	now := time.Now().UTC()
	ids, err := store.ListExpiredMockExams(now)
	if err != nil {
		log.Printf("mock exam timer sweeper: list expired failed: %v", err)
		return
	}
	for _, id := range ids {
		if _, err := store.ExpireMockExam(id); err != nil {
			log.Printf("mock exam timer sweeper: expire %s failed: %v", id, err)
			continue
		}
		log.Printf("mock exam timer sweeper: auto-submitted %s", id)
	}
}
