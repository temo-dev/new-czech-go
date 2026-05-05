package store

import (
	"testing"
	"time"
)

func TestMemoryDailyUsageStore_IncrementAttempts_ReturnsRunningCount(t *testing.T) {
	s := newMemoryDailyUsageStore()

	day := vnDay(2026, 5, 5)
	for want := 1; want <= 3; want++ {
		got, err := s.IncrementAttempts("u_1", day)
		if err != nil {
			t.Fatalf("incr %d: %v", want, err)
		}
		if got != want {
			t.Errorf("expected count=%d, got %d", want, got)
		}
	}
}

func TestMemoryDailyUsageStore_IncrementInterviews_SeparateFromAttempts(t *testing.T) {
	s := newMemoryDailyUsageStore()

	day := vnDay(2026, 5, 5)
	if _, err := s.IncrementAttempts("u_1", day); err != nil {
		t.Fatalf("attempts: %v", err)
	}
	got, err := s.IncrementInterviews("u_1", day)
	if err != nil {
		t.Fatalf("interviews: %v", err)
	}
	if got != 1 {
		t.Errorf("interviews count should be 1, got %d", got)
	}

	usage, ok := s.DailyUsageByUserDay("u_1", day)
	if !ok {
		t.Fatal("expected usage row")
	}
	if usage.AttemptsCount != 1 {
		t.Errorf("attempts unaffected: want 1 got %d", usage.AttemptsCount)
	}
	if usage.InterviewsCount != 1 {
		t.Errorf("interviews: want 1 got %d", usage.InterviewsCount)
	}
}

func TestMemoryDailyUsageStore_DayBoundary_VN(t *testing.T) {
	s := newMemoryDailyUsageStore()

	// Two timestamps that span midnight VN: 2026-05-05 23:30 vs
	// 2026-05-06 00:30. They MUST land on different rows.
	loc := vnDay(2026, 5, 5).Location()
	pre := time.Date(2026, 5, 5, 23, 30, 0, 0, loc)
	post := time.Date(2026, 5, 6, 0, 30, 0, 0, loc)

	if _, err := s.IncrementAttempts("u_1", pre); err != nil {
		t.Fatalf("pre: %v", err)
	}
	if _, err := s.IncrementAttempts("u_1", post); err != nil {
		t.Fatalf("post: %v", err)
	}

	if u, _ := s.DailyUsageByUserDay("u_1", vnDay(2026, 5, 5)); u.AttemptsCount != 1 {
		t.Errorf("day-1 should be 1, got %d", u.AttemptsCount)
	}
	if u, _ := s.DailyUsageByUserDay("u_1", vnDay(2026, 5, 6)); u.AttemptsCount != 1 {
		t.Errorf("day-2 should be 1, got %d", u.AttemptsCount)
	}
}

func TestMemoryDailyUsageStore_LookupMissing_ReturnsZero(t *testing.T) {
	s := newMemoryDailyUsageStore()

	usage, ok := s.DailyUsageByUserDay("u_unknown", vnDay(2026, 5, 5))
	if ok {
		t.Error("expected lookup miss to return false")
	}
	if usage.AttemptsCount != 0 || usage.InterviewsCount != 0 {
		t.Errorf("expected zero usage on miss, got %+v", usage)
	}
}

func TestMemoryDailyUsageStore_PerUserIsolation(t *testing.T) {
	s := newMemoryDailyUsageStore()

	day := vnDay(2026, 5, 5)
	if _, err := s.IncrementAttempts("u_1", day); err != nil {
		t.Fatalf("u_1: %v", err)
	}
	if _, err := s.IncrementAttempts("u_2", day); err != nil {
		t.Fatalf("u_2: %v", err)
	}

	if u, _ := s.DailyUsageByUserDay("u_1", day); u.AttemptsCount != 1 {
		t.Errorf("u_1 should be 1, got %d", u.AttemptsCount)
	}
	if u, _ := s.DailyUsageByUserDay("u_2", day); u.AttemptsCount != 1 {
		t.Errorf("u_2 should be 1, got %d", u.AttemptsCount)
	}
}
