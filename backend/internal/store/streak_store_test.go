package store

import (
	"testing"
	"time"
)

// vnDay returns a civil date in the Asia/Ho_Chi_Minh timezone — the
// authoritative timezone for streak boundaries per V17 spec §3.3.
func vnDay(year int, month time.Month, day int) time.Time {
	loc, err := time.LoadLocation("Asia/Ho_Chi_Minh")
	if err != nil {
		panic(err)
	}
	return time.Date(year, month, day, 0, 0, 0, 0, loc)
}

func TestMemoryStreakStore_MarkDayCompleted_Idempotent(t *testing.T) {
	s := newMemoryStreakStore()

	day := vnDay(2026, 5, 5)
	if err := s.MarkDayCompleted("u_1", day); err != nil {
		t.Fatalf("first mark: %v", err)
	}
	if err := s.MarkDayCompleted("u_1", day); err != nil {
		t.Fatalf("second mark: %v", err)
	}

	got, err := s.StreakDaysByUserBetween("u_1", day, day)
	if err != nil {
		t.Fatalf("range: %v", err)
	}
	if len(got) != 1 {
		t.Fatalf("expected 1 row, got %d", len(got))
	}
	if !got[0].Completed {
		t.Error("expected completed=true after MarkDayCompleted")
	}
}

func TestMemoryStreakStore_ApplyGracePass_NoOverwriteCompleted(t *testing.T) {
	s := newMemoryStreakStore()

	day := vnDay(2026, 5, 5)
	if err := s.MarkDayCompleted("u_1", day); err != nil {
		t.Fatalf("mark: %v", err)
	}
	if err := s.ApplyGracePass("u_1", day); err != nil {
		t.Fatalf("grace: %v", err)
	}

	got, _ := s.StreakDaysByUserBetween("u_1", day, day)
	if !got[0].Completed {
		t.Error("Completed must remain true after grace overlay on a completed day")
	}
	if !got[0].GraceUsed {
		t.Error("expected grace_used=true after ApplyGracePass")
	}
}

func TestMemoryStreakStore_StreakSummary_CurrentAndLongest(t *testing.T) {
	s := newMemoryStreakStore()

	// Mon..Wed completed, Thu skipped, Fri..Sat completed -> current run = 2,
	// longest = 3.
	for _, d := range []int{4, 5, 6, 8, 9} { // 4=Mon, 5=Tue, 6=Wed, 7=Thu skip, 8=Fri, 9=Sat
		if err := s.MarkDayCompleted("u_1", vnDay(2026, 5, d)); err != nil {
			t.Fatalf("mark day %d: %v", d, err)
		}
	}

	asOf := vnDay(2026, 5, 9)
	summary, err := s.StreakSummary("u_1", asOf)
	if err != nil {
		t.Fatalf("summary: %v", err)
	}
	if summary.Current != 2 {
		t.Errorf("expected current=2 (Fri+Sat), got %d", summary.Current)
	}
	if summary.Longest != 3 {
		t.Errorf("expected longest=3 (Mon+Tue+Wed), got %d", summary.Longest)
	}
	if !summary.LastCompletedDay.Equal(asOf) {
		t.Errorf("expected last_completed=2026-05-09, got %v", summary.LastCompletedDay)
	}
}

func TestMemoryStreakStore_StreakSummary_GraceExtendsCurrent(t *testing.T) {
	s := newMemoryStreakStore()

	// Mon completed, Tue grace pass (no attempt that day), Wed completed.
	// Current streak as of Wed should be 3 because the grace pass bridges
	// the gap.
	must(t, s.MarkDayCompleted("u_1", vnDay(2026, 5, 4)))
	must(t, s.ApplyGracePass("u_1", vnDay(2026, 5, 5)))
	must(t, s.MarkDayCompleted("u_1", vnDay(2026, 5, 6)))

	summary, err := s.StreakSummary("u_1", vnDay(2026, 5, 6))
	if err != nil {
		t.Fatalf("summary: %v", err)
	}
	if summary.Current != 3 {
		t.Errorf("expected grace pass to bridge: current=3, got %d", summary.Current)
	}
}

func TestMemoryStreakStore_StreakSummary_BreaksWhenNoActivityToday(t *testing.T) {
	s := newMemoryStreakStore()

	must(t, s.MarkDayCompleted("u_1", vnDay(2026, 5, 4)))
	must(t, s.MarkDayCompleted("u_1", vnDay(2026, 5, 5)))

	// asOf is two days after the last completion (no grace) -> streak broke.
	summary, err := s.StreakSummary("u_1", vnDay(2026, 5, 7))
	if err != nil {
		t.Fatalf("summary: %v", err)
	}
	if summary.Current != 0 {
		t.Errorf("expected current=0 after gap, got %d", summary.Current)
	}
	if summary.Longest != 2 {
		t.Errorf("expected longest=2, got %d", summary.Longest)
	}
}

func TestMemoryStreakStore_StreakSummary_GracePassesUsedThisWeek(t *testing.T) {
	s := newMemoryStreakStore()

	// Week of 2026-05-04 (Mon) .. 2026-05-10 (Sun). Two grace passes on
	// Tue and Thu, one grace pass last week on the previous Sun (excluded
	// from this-week count).
	must(t, s.ApplyGracePass("u_1", vnDay(2026, 4, 26))) // Sun previous week
	must(t, s.ApplyGracePass("u_1", vnDay(2026, 5, 5)))  // Tue
	must(t, s.ApplyGracePass("u_1", vnDay(2026, 5, 7)))  // Thu

	summary, err := s.StreakSummary("u_1", vnDay(2026, 5, 9))
	if err != nil {
		t.Fatalf("summary: %v", err)
	}
	if summary.GracePassesUsedThisWeek != 2 {
		t.Errorf("expected 2 grace passes this week, got %d", summary.GracePassesUsedThisWeek)
	}
}

func TestMemoryStreakStore_StreakSummary_EmptyUser(t *testing.T) {
	s := newMemoryStreakStore()

	summary, err := s.StreakSummary("u_unknown", vnDay(2026, 5, 5))
	if err != nil {
		t.Fatalf("summary: %v", err)
	}
	if summary.Current != 0 || summary.Longest != 0 {
		t.Errorf("expected zero summary for unknown user, got %+v", summary)
	}
	if !summary.LastCompletedDay.IsZero() {
		t.Errorf("expected zero last_completed_day for unknown user, got %v", summary.LastCompletedDay)
	}
}

func TestMemoryStreakStore_DaysAreNormalizedToVNCivilDate(t *testing.T) {
	s := newMemoryStreakStore()

	// Same VN civil day expressed in different wall-clock instants.
	morningVN := time.Date(2026, 5, 5, 8, 30, 0, 0, vnDay(2026, 5, 5).Location())
	eveningVN := time.Date(2026, 5, 5, 23, 59, 0, 0, vnDay(2026, 5, 5).Location())

	must(t, s.MarkDayCompleted("u_1", morningVN))
	must(t, s.MarkDayCompleted("u_1", eveningVN))

	rows, _ := s.StreakDaysByUserBetween("u_1", vnDay(2026, 5, 5), vnDay(2026, 5, 5))
	if len(rows) != 1 {
		t.Errorf("two timestamps in same VN day should fold to 1 row, got %d", len(rows))
	}
}

func must(t *testing.T, err error) {
	t.Helper()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
}
