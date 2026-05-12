package store

import (
	"os"
	"reflect"
	"sort"
	"testing"
	"time"
)

func TestMemoryUserLevelStore_GetUserLevel_FreshReturnsDefaultsAndNotFound(t *testing.T) {
	s := newMemoryUserLevelStore()

	got, ok := s.GetUserLevel("u_fresh")
	if ok {
		t.Errorf("expected ok=false for never-seen user, got true")
	}
	if got.CurrentLevel != "a0" {
		t.Errorf("CurrentLevel = %q, want a0", got.CurrentLevel)
	}
	wantUnlocks := []string{"a0"}
	if !reflect.DeepEqual(got.UnlockedLevels, wantUnlocks) {
		t.Errorf("UnlockedLevels = %v, want %v", got.UnlockedLevels, wantUnlocks)
	}
	if got.PlacementTakenAt != nil {
		t.Errorf("PlacementTakenAt = %v, want nil", got.PlacementTakenAt)
	}
}

func TestMemoryUserLevelStore_SetUserLevel_PromotesAndAppendsUnlocks(t *testing.T) {
	s := newMemoryUserLevelStore()

	got, err := s.SetUserLevel("u_1", "a2")
	if err != nil {
		t.Fatalf("SetUserLevel: %v", err)
	}
	if got.CurrentLevel != "a2" {
		t.Errorf("CurrentLevel = %q, want a2", got.CurrentLevel)
	}
	wantUnlocks := []string{"a0", "a2"}
	sort.Strings(got.UnlockedLevels)
	if !reflect.DeepEqual(got.UnlockedLevels, wantUnlocks) {
		t.Errorf("UnlockedLevels = %v, want %v (after promote a2 from default a0)",
			got.UnlockedLevels, wantUnlocks)
	}

	// Subsequent Get should return the persisted state.
	persisted, ok := s.GetUserLevel("u_1")
	if !ok {
		t.Fatal("expected ok=true after SetUserLevel")
	}
	if persisted.CurrentLevel != "a2" {
		t.Errorf("persisted CurrentLevel = %q, want a2", persisted.CurrentLevel)
	}
}

func TestMemoryUserLevelStore_SetUserLevel_DoublePromoteIsIdempotent(t *testing.T) {
	s := newMemoryUserLevelStore()

	if _, err := s.SetUserLevel("u_2", "a1"); err != nil {
		t.Fatalf("first SetUserLevel: %v", err)
	}
	again, err := s.SetUserLevel("u_2", "a1")
	if err != nil {
		t.Fatalf("second SetUserLevel: %v", err)
	}
	count := 0
	for _, lvl := range again.UnlockedLevels {
		if lvl == "a1" {
			count++
		}
	}
	if count != 1 {
		t.Errorf("a1 appeared %d times in unlocked_levels, want exactly 1 (idempotent)", count)
	}
}

func TestMemoryUserLevelStore_SetUserLevel_KeepsLowerLevelsUnlocked(t *testing.T) {
	s := newMemoryUserLevelStore()

	// First land on a1, then on a2 — both must remain unlocked alongside the
	// default a0 so the learner can revisit lower-level content.
	if _, err := s.SetUserLevel("u_3", "a1"); err != nil {
		t.Fatalf("a1 promote: %v", err)
	}
	got, err := s.SetUserLevel("u_3", "a2")
	if err != nil {
		t.Fatalf("a2 promote: %v", err)
	}
	if got.CurrentLevel != "a2" {
		t.Errorf("CurrentLevel = %q, want a2 (latest target)", got.CurrentLevel)
	}
	sort.Strings(got.UnlockedLevels)
	want := []string{"a0", "a1", "a2"}
	if !reflect.DeepEqual(got.UnlockedLevels, want) {
		t.Errorf("UnlockedLevels = %v, want %v", got.UnlockedLevels, want)
	}
}

func TestMemoryUserLevelStore_MarkPlacementTaken_SetsLevelAndTimestamp(t *testing.T) {
	s := newMemoryUserLevelStore()
	when := time.Date(2026, 5, 7, 10, 0, 0, 0, time.UTC)

	got, err := s.MarkPlacementTaken("u_4", "a2", when)
	if err != nil {
		t.Fatalf("MarkPlacementTaken: %v", err)
	}
	if got.CurrentLevel != "a2" {
		t.Errorf("CurrentLevel = %q, want a2", got.CurrentLevel)
	}
	if got.PlacementTakenAt == nil || !got.PlacementTakenAt.Equal(when) {
		t.Errorf("PlacementTakenAt = %v, want %v", got.PlacementTakenAt, when)
	}

	// Subsequent set on the same user keeps the placement timestamp — only
	// MarkPlacementTaken should overwrite it.
	bumped, err := s.SetUserLevel("u_4", "b1")
	if err != nil {
		t.Fatalf("post-placement set: %v", err)
	}
	if bumped.PlacementTakenAt == nil || !bumped.PlacementTakenAt.Equal(when) {
		t.Errorf("PlacementTakenAt after promote = %v, want preserved %v",
			bumped.PlacementTakenAt, when)
	}
}

// TestV21BackfillUserLevels_FileShapesIdempotentBackfill validates migration
// 026 — the one-shot UPDATE that lands pre-V21 users on a2 with all lower
// levels unlocked. The check is static (no Postgres apply) matching the
// repo convention; the SQL is exercised by docker-compose / RDS at deploy.
func TestV21BackfillUserLevels_FileShapesIdempotentBackfill(t *testing.T) {
	path := findMigration(t, "026_v21_backfill_user_levels.sql")

	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read migration: %v", err)
	}
	sql := string(raw)
	mustContain(t, sql, "UPDATE users")
	mustContain(t, sql, "current_level = 'a2'")
	mustContain(t, sql, "ARRAY['a0','a1','a2']")
	// Idempotency guard: only update users still on the migration default
	// AND who have not taken placement, so re-runs are no-ops.
	mustContain(t, sql, "current_level = 'a0'")
	mustContain(t, sql, "placement_taken_at IS NULL")
	// S8: explicit V21_EPOCH guard so the backfill only touches users
	// that existed before V21 shipped; a new A0 sign-up landing in the
	// gap between migration apply and first placement no longer gets
	// auto-promoted to a2.
	mustContain(t, sql, "created_at < ")
	mustContain(t, sql, "2026-05-07")
}
