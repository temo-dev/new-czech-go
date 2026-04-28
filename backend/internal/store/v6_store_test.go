package store

import (
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// ── VocabularyStore ───────────────────────────────────────────────────────────

func TestVocabularyStore_CreateAndGet(t *testing.T) {
	s := newMemoryVocabularyStore()

	set, err := s.CreateVocabularySet(contracts.VocabularySet{
		SkillID:         "skill-tu-vung",
		Title:           "Động từ di chuyển",
		Level:           "A2",
		ExplanationLang: "vi",
	})
	if err != nil {
		t.Fatalf("CreateVocabularySet: %v", err)
	}
	if set.ID == "" {
		t.Error("expected non-empty ID")
	}
	if set.Status != "draft" {
		t.Errorf("expected status=draft, got %s", set.Status)
	}

	got, ok := s.GetVocabularySet(set.ID)
	if !ok {
		t.Fatal("GetVocabularySet: not found")
	}
	if got.Title != "Động từ di chuyển" {
		t.Errorf("wrong title: %s", got.Title)
	}
}

func TestVocabularyStore_List(t *testing.T) {
	s := newMemoryVocabularyStore()

	s.CreateVocabularySet(contracts.VocabularySet{SkillID: "skill-1", Title: "A"})
	s.CreateVocabularySet(contracts.VocabularySet{SkillID: "skill-1", Title: "B"})
	s.CreateVocabularySet(contracts.VocabularySet{SkillID: "skill-2", Title: "C"})

	all := s.ListVocabularySets("")
	if len(all) != 3 {
		t.Errorf("expected 3 sets, got %d", len(all))
	}

	filtered := s.ListVocabularySets("skill-1")
	if len(filtered) != 2 {
		t.Errorf("expected 2 filtered sets, got %d", len(filtered))
	}
}

func TestVocabularyStore_Items(t *testing.T) {
	s := newMemoryVocabularyStore()
	set, _ := s.CreateVocabularySet(contracts.VocabularySet{SkillID: "skill-1", Title: "Test"})

	s.CreateVocabularyItem(contracts.VocabularyItem{SetID: set.ID, Term: "chodím", Meaning: "đi bộ"})
	s.CreateVocabularyItem(contracts.VocabularyItem{SetID: set.ID, Term: "jedu", Meaning: "đi xe"})

	items := s.ListVocabularyItems(set.ID)
	if len(items) != 2 {
		t.Errorf("expected 2 items, got %d", len(items))
	}
}

func TestVocabularyStore_Delete(t *testing.T) {
	s := newMemoryVocabularyStore()
	set, _ := s.CreateVocabularySet(contracts.VocabularySet{SkillID: "skill-1", Title: "Test"})
	s.CreateVocabularyItem(contracts.VocabularyItem{SetID: set.ID, Term: "chodím", Meaning: "đi bộ"})

	ok := s.DeleteVocabularySet(set.ID)
	if !ok {
		t.Fatal("DeleteVocabularySet returned false")
	}
	if _, found := s.GetVocabularySet(set.ID); found {
		t.Error("set still exists after delete")
	}
	// cascade: items should also be gone
	if items := s.ListVocabularyItems(set.ID); len(items) != 0 {
		t.Errorf("expected 0 items after cascade delete, got %d", len(items))
	}
}

func TestVocabularyStore_DeleteNotFound(t *testing.T) {
	s := newMemoryVocabularyStore()
	ok := s.DeleteVocabularySet("nonexistent")
	if ok {
		t.Error("expected false for deleting nonexistent set")
	}
}

// ── GrammarStore ──────────────────────────────────────────────────────────────

func TestGrammarStore_CreateAndGet(t *testing.T) {
	s := newMemoryGrammarStore()

	rule, err := s.CreateGrammarRule(contracts.GrammarRule{
		SkillID: "skill-ngu-phap",
		Title:   "Verb být",
		Level:   "A1",
		RuleTable: map[string]string{
			"já":  "jsem",
			"ty":  "jsi",
			"on":  "je",
		},
	})
	if err != nil {
		t.Fatalf("CreateGrammarRule: %v", err)
	}
	if rule.ID == "" {
		t.Error("expected non-empty ID")
	}
	if rule.Status != "draft" {
		t.Errorf("expected status=draft, got %s", rule.Status)
	}

	got, ok := s.GetGrammarRule(rule.ID)
	if !ok {
		t.Fatal("GetGrammarRule: not found")
	}
	if got.RuleTable["já"] != "jsem" {
		t.Errorf("wrong rule table entry: %v", got.RuleTable)
	}
}

func TestGrammarStore_Update(t *testing.T) {
	s := newMemoryGrammarStore()
	rule, _ := s.CreateGrammarRule(contracts.GrammarRule{SkillID: "sk", Title: "original"})

	updated, ok := s.UpdateGrammarRule(rule.ID, contracts.GrammarRule{Title: "updated"})
	if !ok {
		t.Fatal("UpdateGrammarRule returned false")
	}
	if updated.Title != "updated" {
		t.Errorf("expected title=updated, got %s", updated.Title)
	}
}

func TestGrammarStore_Delete(t *testing.T) {
	s := newMemoryGrammarStore()
	rule, _ := s.CreateGrammarRule(contracts.GrammarRule{SkillID: "sk", Title: "Test"})

	if !s.DeleteGrammarRule(rule.ID) {
		t.Fatal("DeleteGrammarRule returned false")
	}
	if _, found := s.GetGrammarRule(rule.ID); found {
		t.Error("rule still exists after delete")
	}
}

// ── GenerationJobStore ────────────────────────────────────────────────────────

func TestGenerationJobStore_Lifecycle(t *testing.T) {
	s := newMemoryGenerationJobStore()

	job := s.CreateJob(contracts.ContentGenerationJob{
		ModuleID:    "module-1",
		SourceType:  "vocabulary_set",
		SourceID:    "vocset-1",
		RequestedBy: "admin",
	})
	if job.ID == "" {
		t.Fatal("expected non-empty job ID")
	}
	if job.Status != "pending" {
		t.Errorf("expected status=pending, got %s", job.Status)
	}

	// pending → running
	s.UpdateJobRunning(job.ID)
	got, _ := s.GetJob(job.ID)
	if got.Status != "running" {
		t.Errorf("expected running, got %s", got.Status)
	}

	// running → generated
	payload := []byte(`{"exercises":[]}`)
	s.UpdateJobGenerated(job.ID, payload, 100, 200, 0.001, 5000)
	got, _ = s.GetJob(job.ID)
	if got.Status != "generated" {
		t.Errorf("expected generated, got %s", got.Status)
	}
	if string(got.GeneratedPayload) != string(payload) {
		t.Error("GeneratedPayload not set")
	}
	if got.InputTokens != 100 || got.OutputTokens != 200 {
		t.Errorf("tokens not set: in=%d out=%d", got.InputTokens, got.OutputTokens)
	}

	// generated → published
	ok := s.UpdateJobPublished(job.ID)
	if !ok {
		t.Fatal("UpdateJobPublished returned false")
	}
	got, _ = s.GetJob(job.ID)
	if got.Status != "published" {
		t.Errorf("expected published, got %s", got.Status)
	}
	if got.PublishedAt == "" {
		t.Error("PublishedAt not set")
	}
}

func TestGenerationJobStore_Failed(t *testing.T) {
	s := newMemoryGenerationJobStore()
	job := s.CreateJob(contracts.ContentGenerationJob{ModuleID: "m", RequestedBy: "admin"})

	s.UpdateJobRunning(job.ID)
	s.UpdateJobFailed(job.ID, "API rate limit exceeded")

	got, _ := s.GetJob(job.ID)
	if got.Status != "failed" {
		t.Errorf("expected failed, got %s", got.Status)
	}
	if got.ErrorMessage != "API rate limit exceeded" {
		t.Errorf("wrong error message: %s", got.ErrorMessage)
	}
}

func TestGenerationJobStore_FindActiveJob(t *testing.T) {
	s := newMemoryGenerationJobStore()

	// No active jobs initially
	_, found := s.FindActiveJob("admin", "module-1")
	if found {
		t.Error("expected no active job initially")
	}

	// Create a pending job
	job := s.CreateJob(contracts.ContentGenerationJob{
		ModuleID:    "module-1",
		RequestedBy: "admin",
	})

	_, found = s.FindActiveJob("admin", "module-1")
	if !found {
		t.Error("expected to find pending job")
	}

	// Different module: no conflict
	_, found = s.FindActiveJob("admin", "module-2")
	if found {
		t.Error("should not find job for different module")
	}

	// After rejection, no longer active
	s.UpdateJobRejected(job.ID)
	_, found = s.FindActiveJob("admin", "module-1")
	if found {
		t.Error("rejected job should not be active")
	}
}

func TestGenerationJobStore_MarkAllRunningFailed(t *testing.T) {
	s := newMemoryGenerationJobStore()

	j1 := s.CreateJob(contracts.ContentGenerationJob{ModuleID: "m1", RequestedBy: "admin"})
	j2 := s.CreateJob(contracts.ContentGenerationJob{ModuleID: "m2", RequestedBy: "admin"})
	j3 := s.CreateJob(contracts.ContentGenerationJob{ModuleID: "m3", RequestedBy: "admin"})

	s.UpdateJobRunning(j1.ID)
	s.UpdateJobRunning(j2.ID)
	// j3 stays pending

	s.MarkAllRunningFailed("Server restarted")

	for id, expected := range map[string]string{
		j1.ID: "failed",
		j2.ID: "failed",
		j3.ID: "pending", // was pending, not running — should be unchanged
	} {
		got, _ := s.GetJob(id)
		if got.Status != expected {
			t.Errorf("job %s: expected %s, got %s", id, expected, got.Status)
		}
	}
}

func TestGenerationJobStore_UpdateDraft(t *testing.T) {
	s := newMemoryGenerationJobStore()
	job := s.CreateJob(contracts.ContentGenerationJob{ModuleID: "m", RequestedBy: "admin"})
	s.UpdateJobRunning(job.ID)
	s.UpdateJobGenerated(job.ID, []byte(`{"exercises":[]}`), 0, 0, 0, 0)

	edited := []byte(`{"exercises":[{"exercise_type":"quizcard_basic"}]}`)
	ok := s.UpdateJobDraft(job.ID, edited)
	if !ok {
		t.Fatal("UpdateJobDraft returned false")
	}

	got, _ := s.GetJob(job.ID)
	if string(got.EditedPayload) != string(edited) {
		t.Error("EditedPayload not updated")
	}
}
