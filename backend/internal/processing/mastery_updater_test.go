package processing

import (
	"context"
	"testing"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

func newUpdaterForTest(t *testing.T) (*MasteryUpdater, store.SkillMasteryStore) {
	t.Helper()
	clearMasteryEnv(t)
	cfg := LoadMasteryConfig()
	st := store.NewMemorySkillMasteryStore()
	clock := func() time.Time { return time.Date(2026, 5, 6, 12, 0, 0, 0, time.UTC) }
	return NewMasteryUpdater(st, cfg, clock), st
}

func attemptForUpdater(id, userID, readiness string) contracts.Attempt {
	return contracts.Attempt{
		ID:     id,
		UserID: userID,
		Feedback: &contracts.AttemptFeedback{
			ReadinessLevel: readiness,
		},
		CompletedAt: time.Date(2026, 5, 6, 12, 0, 0, 0, time.UTC).Format(time.RFC3339),
	}
}

func exerciseForUpdater(skill, module, pool string) contracts.Exercise {
	return contracts.Exercise{
		SkillKind: skill,
		ModuleID:  module,
		Pool:      pool,
	}
}

func TestMasteryUpdater_FirstAttemptSetsScore(t *testing.T) {
	u, st := newUpdaterForTest(t)
	a := attemptForUpdater("a_1", "u_1", "almost_ready")
	ex := exerciseForUpdater("noi", "m_basic", "course")

	if err := u.Update(context.Background(), a, ex); err != nil {
		t.Fatalf("update: %v", err)
	}
	row, ok := st.GetForKey("u_1", "noi", "m_basic")
	if !ok {
		t.Fatal("expected row inserted")
	}
	if row.AttemptsCount != 1 {
		t.Errorf("attempts_count = %d, want 1", row.AttemptsCount)
	}
	// First attempt sets mastery to the attempt score directly (no smoothing).
	if row.MasteryScore != 0.70 {
		t.Errorf("mastery = %v, want 0.70 (almost_ready score)", row.MasteryScore)
	}
	if row.LastAttemptID != "a_1" {
		t.Errorf("last_attempt_id = %q, want a_1", row.LastAttemptID)
	}
}

func TestMasteryUpdater_EMAConvergesOnStrongStreak(t *testing.T) {
	u, st := newUpdaterForTest(t)
	ex := exerciseForUpdater("noi", "m_basic", "course")

	// Five ready_for_mock attempts in a row → mastery climbs toward 0.90 but
	// never exceeds it under the EMA.
	for i := 1; i <= 5; i++ {
		a := attemptForUpdater("a_"+string(rune('0'+i)), "u_1", "ready_for_mock")
		if err := u.Update(context.Background(), a, ex); err != nil {
			t.Fatalf("update %d: %v", i, err)
		}
	}
	row, _ := st.GetForKey("u_1", "noi", "m_basic")
	if row.AttemptsCount != 5 {
		t.Errorf("attempts_count = %d, want 5", row.AttemptsCount)
	}
	if row.MasteryScore < 0.85 || row.MasteryScore > 0.90 {
		t.Errorf("mastery = %v, want band [0.85, 0.90]", row.MasteryScore)
	}
}

func TestMasteryUpdater_EMADecaysOnPoorStreak(t *testing.T) {
	u, st := newUpdaterForTest(t)
	ex := exerciseForUpdater("noi", "m_basic", "course")

	// Start strong, then four bad attempts. Mastery must drop below 0.5.
	_ = u.Update(context.Background(), attemptForUpdater("a_1", "u_1", "ready_for_mock"), ex)
	_ = u.Update(context.Background(), attemptForUpdater("a_2", "u_1", "not_ready"), ex)
	_ = u.Update(context.Background(), attemptForUpdater("a_3", "u_1", "not_ready"), ex)
	_ = u.Update(context.Background(), attemptForUpdater("a_4", "u_1", "not_ready"), ex)
	_ = u.Update(context.Background(), attemptForUpdater("a_5", "u_1", "not_ready"), ex)

	row, _ := st.GetForKey("u_1", "noi", "m_basic")
	if row.MasteryScore >= 0.50 {
		t.Errorf("mastery after decay = %v, expected < 0.50", row.MasteryScore)
	}
}

func TestMasteryUpdater_IdempotentOnDuplicateAttemptID(t *testing.T) {
	u, st := newUpdaterForTest(t)
	a := attemptForUpdater("a_1", "u_1", "almost_ready")
	ex := exerciseForUpdater("noi", "m_basic", "course")

	_ = u.Update(context.Background(), a, ex)
	_ = u.Update(context.Background(), a, ex) // duplicate
	row, _ := st.GetForKey("u_1", "noi", "m_basic")
	if row.AttemptsCount != 1 {
		t.Errorf("duplicate attempt double-counted: count = %d", row.AttemptsCount)
	}
}

func TestMasteryUpdater_ExamPoolEmptiesModuleID(t *testing.T) {
	u, st := newUpdaterForTest(t)
	a := attemptForUpdater("a_1", "u_1", "almost_ready")
	// Exam pool attempt with a non-empty exercise module: aggregate row uses
	// empty module_id so the (user, skill, module) unique index can hold a
	// single row per user-skill across the whole exam pool.
	ex := exerciseForUpdater("nghe", "m_module_does_not_apply", "exam")

	if err := u.Update(context.Background(), a, ex); err != nil {
		t.Fatalf("update: %v", err)
	}
	if _, ok := st.GetForKey("u_1", "nghe", ""); !ok {
		t.Error("expected exam-pool aggregate under empty module_id")
	}
	if _, ok := st.GetForKey("u_1", "nghe", "m_module_does_not_apply"); ok {
		t.Error("exam-pool attempt must not write under exercise's module_id")
	}
}

func TestMasteryUpdater_NoOpOnMissingUserOrSkill(t *testing.T) {
	u, st := newUpdaterForTest(t)

	cases := []struct {
		name     string
		attempt  contracts.Attempt
		exercise contracts.Exercise
	}{
		{
			name:     "missing user",
			attempt:  attemptForUpdater("a_1", "", "almost_ready"),
			exercise: exerciseForUpdater("noi", "m_basic", "course"),
		},
		{
			name:     "missing skill",
			attempt:  attemptForUpdater("a_1", "u_1", "almost_ready"),
			exercise: exerciseForUpdater("", "m_basic", "course"),
		},
		{
			name:     "missing feedback",
			attempt:  contracts.Attempt{ID: "a_1", UserID: "u_1"},
			exercise: exerciseForUpdater("noi", "m_basic", "course"),
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if err := u.Update(context.Background(), c.attempt, c.exercise); err != nil {
				t.Errorf("expected no-op (nil error); got %v", err)
			}
		})
	}
	if rows := st.ListForUser("u_1"); len(rows) != 0 {
		t.Errorf("expected no rows persisted; got %d", len(rows))
	}
}

func TestMasteryUpdater_LastAttemptAtFromCompletedAt(t *testing.T) {
	u, st := newUpdaterForTest(t)
	completedAt := time.Date(2026, 5, 5, 9, 30, 0, 0, time.UTC)
	a := attemptForUpdater("a_1", "u_1", "almost_ready")
	a.CompletedAt = completedAt.Format(time.RFC3339)
	ex := exerciseForUpdater("noi", "m_basic", "course")

	_ = u.Update(context.Background(), a, ex)
	row, _ := st.GetForKey("u_1", "noi", "m_basic")
	if !row.LastAttemptAt.Equal(completedAt) {
		t.Errorf("last_attempt_at = %v, want %v", row.LastAttemptAt, completedAt)
	}
}

func TestProcessor_WithMasteryUpdater_PersistsRowOnCompletion(t *testing.T) {
	clearMasteryEnv(t)
	repo := store.NewMemoryStore()
	masteryStore := store.NewMemorySkillMasteryStore()
	updater := NewMasteryUpdater(masteryStore, LoadMasteryConfig(), nil)

	attemptID := seedUploadedAttempt(t, repo, 18000)
	processor := NewProcessor(repo, nil, mockTTSProvider{
		audio: &contracts.ReviewArtifactAudio{StorageKey: "k", MimeType: "audio/wav"},
	}, nil, nil).WithMasteryUpdater(updater)

	if err := processor.ProcessAttempt(attemptID, ""); err != nil {
		t.Fatalf("ProcessAttempt: %v", err)
	}

	rows := masteryStore.ListForUser("user-learner-1")
	if len(rows) != 1 {
		t.Fatalf("expected 1 mastery row after attempt; got %d", len(rows))
	}
	if rows[0].AttemptsCount != 1 {
		t.Errorf("attempts_count = %d, want 1", rows[0].AttemptsCount)
	}
	if rows[0].MasteryScore <= 0 {
		t.Errorf("mastery_score = %v, want > 0", rows[0].MasteryScore)
	}
}

func TestMasteryUpdater_DemoExerciseSkipsWrite(t *testing.T) {
	updater, st := newUpdaterForTest(t)
	updater.WithDemoCheck(func(exerciseID string) bool {
		return exerciseID == "ex_demo"
	})

	demoEx := contracts.Exercise{ID: "ex_demo", SkillKind: "doc", ModuleID: "m1", Pool: "course"}
	demoAttempt := attemptForUpdater("a_demo", "u_x", "ready_for_mock")
	if err := updater.Update(context.Background(), demoAttempt, demoEx); err != nil {
		t.Fatalf("Update demo: %v", err)
	}
	if rows := st.ListForUser("u_x"); len(rows) != 0 {
		t.Errorf("demo attempt produced %d mastery rows; want 0", len(rows))
	}

	// Non-demo exercise still flows through normally — same skill/module.
	nonDemo := contracts.Exercise{ID: "ex_real", SkillKind: "doc", ModuleID: "m1", Pool: "course"}
	if err := updater.Update(context.Background(), attemptForUpdater("a_real", "u_x", "ready_for_mock"), nonDemo); err != nil {
		t.Fatalf("Update non-demo: %v", err)
	}
	if rows := st.ListForUser("u_x"); len(rows) != 1 {
		t.Errorf("non-demo attempt produced %d mastery rows; want 1", len(rows))
	}
}

func TestProcessor_WithoutMasteryUpdater_StaysQuiet(t *testing.T) {
	// Sanity check: omitting WithMasteryUpdater must not panic and must leave
	// no per-user mastery side-effects. Locks in the contract that the hook
	// is opt-in.
	repo := store.NewMemoryStore()
	attemptID := seedUploadedAttempt(t, repo, 18000)
	processor := NewProcessor(repo, nil, mockTTSProvider{
		audio: &contracts.ReviewArtifactAudio{StorageKey: "k", MimeType: "audio/wav"},
	}, nil, nil)

	if err := processor.ProcessAttempt(attemptID, ""); err != nil {
		t.Fatalf("ProcessAttempt: %v", err)
	}
}
