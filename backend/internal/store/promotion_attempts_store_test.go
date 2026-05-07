package store

import (
	"reflect"
	"testing"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

func TestMemoryMockTestStore_LatestPromotionMockTest_FiltersByLevelAndStatus(t *testing.T) {
	store := newMemoryMockTestStore()

	// Draft promotion mock for B1 — must be ignored.
	if _, err := store.CreateMockTest(contracts.MockTest{
		Title: "Draft B1 Promote", Status: "draft",
		IsPromotion: true, TargetLevel: "b1",
	}); err != nil {
		t.Fatalf("seed draft: %v", err)
	}
	// Published promotion mock for A2 — wrong target.
	if _, err := store.CreateMockTest(contracts.MockTest{
		Title: "A2 Promote", Status: "published",
		IsPromotion: true, TargetLevel: "a2",
	}); err != nil {
		t.Fatalf("seed a2: %v", err)
	}
	// Published promotion mock for B1 — should win.
	winner, err := store.CreateMockTest(contracts.MockTest{
		Title: "B1 Promote", Status: "published",
		IsPromotion: true, TargetLevel: "b1",
	})
	if err != nil {
		t.Fatalf("seed b1: %v", err)
	}

	got, ok := store.LatestPromotionMockTest("b1")
	if !ok {
		t.Fatal("LatestPromotionMockTest('b1') = (_, false), want hit")
	}
	if got.ID != winner.ID {
		t.Errorf("got %q, want %q (newest published B1 promotion)", got.ID, winner.ID)
	}

	if _, ok := store.LatestPromotionMockTest("a0"); ok {
		t.Errorf("LatestPromotionMockTest('a0') matched but no a0 promotion exists")
	}
	if _, ok := store.LatestPromotionMockTest(""); ok {
		t.Errorf("LatestPromotionMockTest('') must miss — empty target is invalid")
	}
}

func TestMemoryPromotionAttemptsStore_Create_AssignsIDAndReturnsRow(t *testing.T) {
	s := newMemoryPromotionAttemptsStore()

	in := contracts.PromotionAttempt{
		UserID:        "u_1",
		MockTestID:    "mt_b1_promote",
		SourceLevel:   "a2",
		TargetLevel:   "b1",
		FullSessionID: "fes_1",
		CreatedAt:     time.Date(2026, 5, 7, 9, 0, 0, 0, time.UTC),
	}
	out, err := s.Create(in)
	if err != nil {
		t.Fatalf("Create: %v", err)
	}
	if out.ID == "" {
		t.Error("Create did not assign an ID")
	}
	if out.UserID != "u_1" || out.TargetLevel != "b1" {
		t.Errorf("Create returned wrong row: %+v", out)
	}
	if out.Passed {
		t.Error("Create row should default to passed=false")
	}
}

func TestMemoryPromotionAttemptsStore_GetLatestFailedAttempt_HitMostRecent(t *testing.T) {
	s := newMemoryPromotionAttemptsStore()

	older, _ := s.Create(contracts.PromotionAttempt{
		UserID:      "u_1",
		MockTestID:  "mt_b1_promote",
		SourceLevel: "a2",
		TargetLevel: "b1",
		CreatedAt:   time.Date(2026, 5, 6, 9, 0, 0, 0, time.UTC),
	})
	newer, _ := s.Create(contracts.PromotionAttempt{
		UserID:      "u_1",
		MockTestID:  "mt_b1_promote",
		SourceLevel: "a2",
		TargetLevel: "b1",
		CreatedAt:   time.Date(2026, 5, 7, 9, 0, 0, 0, time.UTC),
	})

	got, ok := s.GetLatestFailedAttempt("u_1", "b1")
	if !ok {
		t.Fatal("expected ok=true with two failed attempts")
	}
	if got.ID != newer.ID {
		t.Errorf("GetLatestFailedAttempt = %s, want %s (most recent)", got.ID, newer.ID)
	}
	if got.ID == older.ID {
		t.Error("returned older attempt instead of newer one")
	}
}

func TestMemoryPromotionAttemptsStore_GetLatestFailedAttempt_IgnoresPassedAndOtherUsers(t *testing.T) {
	s := newMemoryPromotionAttemptsStore()

	// User u_1 has only a passed attempt → should not match.
	passed, _ := s.Create(contracts.PromotionAttempt{
		UserID: "u_1", MockTestID: "mt_b1_promote",
		SourceLevel: "a2", TargetLevel: "b1",
		CreatedAt: time.Date(2026, 5, 7, 9, 0, 0, 0, time.UTC),
	})
	_, _ = s.MarkResult(passed.ID, true, 78.0, map[string]float64{"noi": 80, "viet": 75})

	// User u_other has a failed attempt for the same target — must not leak.
	_, _ = s.Create(contracts.PromotionAttempt{
		UserID: "u_other", MockTestID: "mt_b1_promote",
		SourceLevel: "a2", TargetLevel: "b1",
		CreatedAt: time.Date(2026, 5, 7, 10, 0, 0, 0, time.UTC),
	})

	if _, ok := s.GetLatestFailedAttempt("u_1", "b1"); ok {
		t.Error("expected ok=false for u_1 (only passed attempt + other-user fail)")
	}

	// And a different target_level for the same user should also miss.
	_, _ = s.Create(contracts.PromotionAttempt{
		UserID: "u_1", MockTestID: "mt_a2_promote",
		SourceLevel: "a1", TargetLevel: "a2",
		CreatedAt: time.Date(2026, 5, 6, 11, 0, 0, 0, time.UTC),
	})
	if _, ok := s.GetLatestFailedAttempt("u_1", "b1"); ok {
		t.Error("expected ok=false: only failed attempt on different target_level")
	}
}

func TestMemoryPromotionAttemptsStore_MarkResult_UpdatesAndIsIdempotent(t *testing.T) {
	s := newMemoryPromotionAttemptsStore()

	created, _ := s.Create(contracts.PromotionAttempt{
		UserID: "u_1", MockTestID: "mt_b1_promote",
		SourceLevel: "a2", TargetLevel: "b1",
		CreatedAt: time.Date(2026, 5, 7, 9, 0, 0, 0, time.UTC),
	})

	perSkill := map[string]float64{"noi": 80, "viet": 70, "nghe": 75, "doc": 72, "tu_vung": 78, "ngu_phap": 70}
	updated, err := s.MarkResult(created.ID, true, 74.5, perSkill)
	if err != nil {
		t.Fatalf("MarkResult: %v", err)
	}
	if !updated.Passed {
		t.Error("MarkResult did not flip passed to true")
	}
	if updated.ScorePct != 74.5 {
		t.Errorf("ScorePct = %v, want 74.5", updated.ScorePct)
	}
	if !reflect.DeepEqual(updated.PerSkillPct, perSkill) {
		t.Errorf("PerSkillPct = %v, want %v", updated.PerSkillPct, perSkill)
	}

	// Replaying the same MarkResult must produce the same row (no-op idempotency).
	again, err := s.MarkResult(created.ID, true, 74.5, perSkill)
	if err != nil {
		t.Fatalf("MarkResult replay: %v", err)
	}
	if again.ID != updated.ID {
		t.Errorf("replay ID changed: %s -> %s", updated.ID, again.ID)
	}
	if !again.Passed || again.ScorePct != 74.5 {
		t.Errorf("replay altered state: %+v", again)
	}

	// MarkResult on unknown ID is a not-found error.
	if _, err := s.MarkResult("does-not-exist", true, 1.0, nil); err == nil {
		t.Error("MarkResult on unknown ID expected error, got nil")
	}
}
