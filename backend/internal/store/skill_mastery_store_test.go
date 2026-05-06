package store

import (
	"testing"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

func TestMemorySkillMasteryStore_UpsertNewRow(t *testing.T) {
	s := newMemorySkillMasteryStore()

	now := time.Date(2026, 5, 6, 12, 0, 0, 0, time.UTC)
	in := contracts.SkillMasteryRow{
		UserID:        "u_1",
		SkillKind:     "noi",
		ModuleID:      "m_basic",
		MasteryScore:  0.45,
		AttemptsCount: 1,
		LastAttemptID: "a_1",
		LastAttemptAt: now,
		CreatedAt:     now,
		UpdatedAt:     now,
	}
	out, err := s.Upsert(in)
	if err != nil {
		t.Fatalf("upsert: %v", err)
	}
	if out.ID == "" {
		t.Error("expected ID assigned on insert")
	}
	if out.MasteryScore != 0.45 || out.AttemptsCount != 1 {
		t.Errorf("upsert returned wrong row: %+v", out)
	}
}

func TestMemorySkillMasteryStore_UpsertUpdatesByCompositeKey(t *testing.T) {
	s := newMemorySkillMasteryStore()

	now := time.Date(2026, 5, 6, 12, 0, 0, 0, time.UTC)
	first, _ := s.Upsert(contracts.SkillMasteryRow{
		UserID: "u_1", SkillKind: "noi", ModuleID: "m_a",
		MasteryScore: 0.30, AttemptsCount: 1,
		LastAttemptID: "a_1", LastAttemptAt: now, CreatedAt: now, UpdatedAt: now,
	})
	later := now.Add(time.Hour)
	second, _ := s.Upsert(contracts.SkillMasteryRow{
		UserID: "u_1", SkillKind: "noi", ModuleID: "m_a",
		MasteryScore: 0.55, AttemptsCount: 2,
		LastAttemptID: "a_2", LastAttemptAt: later, UpdatedAt: later,
	})

	if first.ID != second.ID {
		t.Errorf("expected same ID on upsert update; got %q vs %q", first.ID, second.ID)
	}
	if second.MasteryScore != 0.55 || second.AttemptsCount != 2 {
		t.Errorf("expected updated mastery/count, got %+v", second)
	}
	if !second.CreatedAt.Equal(now) {
		t.Errorf("CreatedAt must be preserved on update; got %v", second.CreatedAt)
	}
}

func TestMemorySkillMasteryStore_GetForKey(t *testing.T) {
	s := newMemorySkillMasteryStore()

	now := time.Date(2026, 5, 6, 12, 0, 0, 0, time.UTC)
	_, _ = s.Upsert(contracts.SkillMasteryRow{
		UserID: "u_1", SkillKind: "nghe", ModuleID: "m_basic",
		MasteryScore: 0.70, AttemptsCount: 4,
		LastAttemptID: "a_9", LastAttemptAt: now, CreatedAt: now, UpdatedAt: now,
	})

	got, ok := s.GetForKey("u_1", "nghe", "m_basic")
	if !ok {
		t.Fatal("expected hit")
	}
	if got.MasteryScore != 0.70 || got.AttemptsCount != 4 {
		t.Errorf("unexpected row: %+v", got)
	}

	if _, ok := s.GetForKey("u_1", "nghe", "m_other"); ok {
		t.Error("different module must not match")
	}
	if _, ok := s.GetForKey("u_1", "doc", "m_basic"); ok {
		t.Error("different skill must not match")
	}
	if _, ok := s.GetForKey("u_2", "nghe", "m_basic"); ok {
		t.Error("different user must not match")
	}
}

func TestMemorySkillMasteryStore_ListForUser(t *testing.T) {
	s := newMemorySkillMasteryStore()

	now := time.Date(2026, 5, 6, 12, 0, 0, 0, time.UTC)
	insert := func(skill, module string, score float64) {
		_, _ = s.Upsert(contracts.SkillMasteryRow{
			UserID: "u_1", SkillKind: skill, ModuleID: module,
			MasteryScore: score, AttemptsCount: 1,
			LastAttemptAt: now, CreatedAt: now, UpdatedAt: now,
		})
	}
	insert("noi", "m_a", 0.40)
	insert("noi", "m_b", 0.60)
	insert("nghe", "m_a", 0.80)
	// Different user MUST be excluded.
	_, _ = s.Upsert(contracts.SkillMasteryRow{
		UserID: "u_2", SkillKind: "noi", ModuleID: "m_a",
		MasteryScore: 0.99, AttemptsCount: 1,
		LastAttemptAt: now, CreatedAt: now, UpdatedAt: now,
	})

	rows := s.ListForUser("u_1")
	if len(rows) != 3 {
		t.Fatalf("len = %d, want 3", len(rows))
	}
	// Deterministic ordering by (skill_kind, module_id) — required by progress
	// handler grouping.
	want := [][2]string{{"nghe", "m_a"}, {"noi", "m_a"}, {"noi", "m_b"}}
	for i, w := range want {
		if rows[i].SkillKind != w[0] || rows[i].ModuleID != w[1] {
			t.Errorf("row[%d] = (%s,%s), want (%s,%s)",
				i, rows[i].SkillKind, rows[i].ModuleID, w[0], w[1])
		}
	}
}

func TestMemorySkillMasteryStore_ListForUser_EmptyUser(t *testing.T) {
	s := newMemorySkillMasteryStore()
	rows := s.ListForUser("u_unknown")
	if len(rows) != 0 {
		t.Errorf("expected empty slice; got %d rows", len(rows))
	}
}

func TestMemorySkillMasteryStore_EmptyModuleAllowed(t *testing.T) {
	// Exam-pool attempts persist with ModuleID="" so the (user, skill, module)
	// uniqueness still holds.
	s := newMemorySkillMasteryStore()
	now := time.Date(2026, 5, 6, 12, 0, 0, 0, time.UTC)
	_, err := s.Upsert(contracts.SkillMasteryRow{
		UserID: "u_1", SkillKind: "noi", ModuleID: "",
		MasteryScore: 0.50, AttemptsCount: 1,
		LastAttemptAt: now, CreatedAt: now, UpdatedAt: now,
	})
	if err != nil {
		t.Fatalf("empty module upsert: %v", err)
	}
	got, ok := s.GetForKey("u_1", "noi", "")
	if !ok || got.MasteryScore != 0.50 {
		t.Errorf("expected exam-pool row to round-trip; got=%+v ok=%v", got, ok)
	}
}

func TestMemorySkillMasteryStore_RejectsMissingUserOrSkill(t *testing.T) {
	s := newMemorySkillMasteryStore()
	now := time.Date(2026, 5, 6, 12, 0, 0, 0, time.UTC)

	cases := []contracts.SkillMasteryRow{
		{UserID: "", SkillKind: "noi", ModuleID: "m", LastAttemptAt: now, UpdatedAt: now},
		{UserID: "u_1", SkillKind: "", ModuleID: "m", LastAttemptAt: now, UpdatedAt: now},
	}
	for i, in := range cases {
		if _, err := s.Upsert(in); err == nil {
			t.Errorf("case %d: expected error for invalid key %+v", i, in)
		}
	}
}
