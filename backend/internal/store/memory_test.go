package store

import (
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

func TestReviewArtifactCanBeCreatedUpdatedAndReadBack(t *testing.T) {
	repo := NewMemoryStore()

	attempt, err := repo.CreateAttempt("user-learner-1", "exercise-uloha1-weather", "ios", "0.1.0", "vi")
	if err != nil {
		t.Fatalf("CreateAttempt returned error: %v", err)
	}

	repo.CompleteAttempt(attempt.ID, contracts.Transcript{
		FullText:    "ja mam rad teple pocasi",
		Locale:      "cs-CZ",
		Provider:    "amazon_transcribe",
		IsSynthetic: false,
	}, contracts.AttemptFeedback{
		ReadinessLevel: "almost_ready",
		OverallSummary: "Ban da noi dung huong, nhung can tu nhien hon.",
		Strengths:      []string{"Dung chu de"},
		Improvements:   []string{"Them chi tiet"},
		TaskCompletion: contracts.TaskCompletion{ScoreBand: "ok"},
		GrammarFeedback: contracts.GrammarFeedback{
			ScoreBand: "ok",
		},
		RetryAdvice: []string{"Thu noi lai voi 1 ly do cu the."},
	})

	created, ok := repo.UpsertReviewArtifact(attempt.ID, contracts.AttemptReviewArtifact{
		Status:                   "pending",
		SourceTranscriptText:     "ja mam rad teple pocasi",
		SourceTranscriptProvider: "amazon_transcribe",
		RepairProvider:           "task_aware_repair_v1",
	})
	if !ok {
		t.Fatalf("expected review artifact to be created for attempt %s", attempt.ID)
	}
	if created.Status != "pending" {
		t.Fatalf("expected pending review artifact, got %q", created.Status)
	}

	updated, ok := repo.UpsertReviewArtifact(attempt.ID, contracts.AttemptReviewArtifact{
		Status:                   "ready",
		SourceTranscriptText:     "ja mam rad teple pocasi",
		SourceTranscriptProvider: "amazon_transcribe",
		CorrectedTranscriptText:  "Ja mam rad teple pocasi.",
		ModelAnswerText:          "Mam rad teple pocasi, protoze muzu byt dlouho venku.",
		SpeakingFocusItems: []contracts.SpeakingFocusItem{
			{
				FocusKey:        "word_form",
				Label:           "Uprav tvar vety",
				LearnerFragment: "ja mam rad",
				TargetFragment:  "Mam rad",
				IssueType:       "word_form",
				CommentVI:       "Thu bo cau truc thua de cau nghe tu nhien hon.",
			},
		},
		DiffChunks: []contracts.DiffChunk{
			{Kind: "replaced", SourceText: "ja mam rad teple pocasi", TargetText: "Mam rad teple pocasi"},
		},
		TTSAudio: &contracts.ReviewArtifactAudio{
			StorageKey: "attempt-review/" + attempt.ID + "/model-answer.mp3",
			MimeType:   "audio/mpeg",
		},
		RepairProvider: "task_aware_repair_v1",
		GeneratedAt:    "2026-04-23T08:00:00Z",
	})
	if !ok {
		t.Fatalf("expected review artifact to be updated for attempt %s", attempt.ID)
	}
	if updated.Status != "ready" {
		t.Fatalf("expected ready review artifact, got %q", updated.Status)
	}
	if updated.TTSAudio == nil || updated.TTSAudio.MimeType != "audio/mpeg" {
		t.Fatalf("expected persisted TTS audio metadata, got %+v", updated.TTSAudio)
	}

	storedArtifact, ok := repo.ReviewArtifact(attempt.ID)
	if !ok {
		t.Fatalf("expected review artifact lookup for attempt %s", attempt.ID)
	}
	if storedArtifact.CorrectedTranscriptText != "Ja mam rad teple pocasi." {
		t.Fatalf("unexpected corrected transcript %q", storedArtifact.CorrectedTranscriptText)
	}
	if len(storedArtifact.SpeakingFocusItems) != 1 {
		t.Fatalf("expected 1 speaking focus item, got %d", len(storedArtifact.SpeakingFocusItems))
	}

	storedAttempt, ok := repo.Attempt(attempt.ID)
	if !ok {
		t.Fatalf("expected attempt lookup for %s", attempt.ID)
	}
	if storedAttempt.ReviewArtifact == nil || storedAttempt.ReviewArtifact.Status != "ready" {
		t.Fatalf("expected attempt review summary to be ready, got %+v", storedAttempt.ReviewArtifact)
	}
	if storedAttempt.Transcript == nil || storedAttempt.Transcript.FullText == "" {
		t.Fatal("expected transcript to remain attached after review artifact update")
	}
	if storedAttempt.Feedback == nil || storedAttempt.Feedback.OverallSummary == "" {
		t.Fatal("expected feedback to remain attached after review artifact update")
	}
}

func TestCreateAttemptStoresUserAndClientContext(t *testing.T) {
	repo := NewMemoryStore()

	attempt, err := repo.CreateAttempt("user-learner-1", "exercise-uloha1-weather", "ios", "0.1.0", "vi")
	if err != nil {
		t.Fatalf("CreateAttempt returned error: %v", err)
	}

	if attempt.UserID != "user-learner-1" {
		t.Fatalf("expected user id to be stored, got %q", attempt.UserID)
	}
	if attempt.ClientPlatform != "ios" {
		t.Fatalf("expected client platform ios, got %q", attempt.ClientPlatform)
	}
	if attempt.AppVersion != "0.1.0" {
		t.Fatalf("expected app version 0.1.0, got %q", attempt.AppVersion)
	}
	if attempt.AttemptNo != 1 {
		t.Fatalf("expected first attempt number to be 1, got %d", attempt.AttemptNo)
	}
}

func TestAttemptNumbersAreSequentialPerUserAndExercise(t *testing.T) {
	repo := NewMemoryStore()

	first, err := repo.CreateAttempt("user-learner-1", "exercise-uloha1-weather", "ios", "0.1.0", "vi")
	if err != nil {
		t.Fatalf("CreateAttempt returned error: %v", err)
	}
	second, err := repo.CreateAttempt("user-learner-1", "exercise-uloha1-weather", "ios", "0.1.0", "vi")
	if err != nil {
		t.Fatalf("CreateAttempt returned error: %v", err)
	}
	otherUser, err := repo.CreateAttempt("user-learner-2", "exercise-uloha1-weather", "ios", "0.1.0", "vi")
	if err != nil {
		t.Fatalf("CreateAttempt returned error: %v", err)
	}

	if first.AttemptNo != 1 {
		t.Fatalf("expected first attempt number 1, got %d", first.AttemptNo)
	}
	if second.AttemptNo != 2 {
		t.Fatalf("expected second attempt number 2, got %d", second.AttemptNo)
	}
	if otherUser.AttemptNo != 1 {
		t.Fatalf("expected a different user to start back at attempt number 1, got %d", otherUser.AttemptNo)
	}
}

func TestCreateAndUpdateExercisePreservesPromptAndPreview(t *testing.T) {
	repo := NewMemoryStore()

	created := repo.CreateExercise(contracts.Exercise{
		ModuleID:             "module-day-1",
		ExerciseType:         "uloha_1_topic_answers",
		Title:                "Bydleni 1",
		ShortInstruction:     "Tra loi ngan gon ve chu de nha o.",
		LearnerInstruction:   "Ban se tra loi ngan gon ve chu de nha o.",
		EstimatedDurationSec: 90,
		SampleAnswerEnabled:  true,
		Prompt:               contracts.Uloha1Prompt{TopicLabel: "Bydleni", QuestionPrompts: []string{"Kde bydlite?"}},
		ScoringTemplatePreview: &contracts.ScoringPreview{
			RubricVersion: "v1",
			FeedbackStyle: "supportive_direct_vi",
		},
	})

	if created.ID == "" {
		t.Fatal("expected created exercise id")
	}
	if created.Status != "draft" {
		t.Fatalf("expected default draft status, got %q", created.Status)
	}

	updated, ok := repo.UpdateExercise(created.ID, contracts.Exercise{
		Status: "published",
		Prompt: contracts.Uloha1Prompt{
			TopicLabel:      "Bydleni",
			QuestionPrompts: []string{"Kde bydlite?", "Bydlite v byte nebo v dome?"},
		},
	})
	if !ok {
		t.Fatalf("expected exercise %s to be updated", created.ID)
	}

	prompt, ok := updated.Prompt.(contracts.Uloha1Prompt)
	if !ok {
		t.Fatalf("expected prompt to stay typed as Uloha1Prompt, got %T", updated.Prompt)
	}
	if len(prompt.QuestionPrompts) != 2 {
		t.Fatalf("expected 2 question prompts after update, got %d", len(prompt.QuestionPrompts))
	}
	if updated.ScoringTemplatePreview == nil || updated.ScoringTemplatePreview.FeedbackStyle != "supportive_direct_vi" {
		t.Fatal("expected scoring template preview to be preserved")
	}
}

func TestCreateExercisePreservesCreatedByLLM(t *testing.T) {
	repo := NewMemoryStore()

	created := repo.CreateExercise(contracts.Exercise{
		ModuleID:             "module-day-1",
		SkillKind:            "doc",
		ExerciseType:         "cteni_2",
		Title:                "AI-drafted reading",
		ShortInstruction:     "Doc text a vyber spravnou odpoved.",
		EstimatedDurationSec: 180,
		CreatedByLLM:         true,
	})

	if created.ID == "" {
		t.Fatal("expected created exercise id")
	}
	if !created.CreatedByLLM {
		t.Fatal("expected CreatedByLLM=true on returned exercise")
	}

	fetched, ok := repo.Exercise(created.ID)
	if !ok {
		t.Fatalf("expected to fetch exercise %s", created.ID)
	}
	if !fetched.CreatedByLLM {
		t.Fatal("expected CreatedByLLM=true after refetch")
	}

	manual := repo.CreateExercise(contracts.Exercise{
		ModuleID:             "module-day-1",
		SkillKind:            "doc",
		ExerciseType:         "cteni_2",
		Title:                "Manual reading",
		ShortInstruction:     "x",
		EstimatedDurationSec: 180,
	})
	if manual.CreatedByLLM {
		t.Fatal("expected CreatedByLLM=false (default) on manual exercise")
	}
}

func TestCreateExercisePreservesUloha2DetailType(t *testing.T) {
	repo := NewMemoryStore()

	created := repo.CreateExercise(contracts.Exercise{
		ModuleID:             "module-day-1",
		ExerciseType:         "uloha_2_dialogue_questions",
		Title:                "Knihovna 1",
		ShortInstruction:     "Zeptejte se na chybejici informace v knihovne.",
		LearnerInstruction:   "Ban can hoi nhung thong tin con thieu o thu vien.",
		EstimatedDurationSec: 90,
		SampleAnswerEnabled:  true,
		Detail: contracts.Uloha2Detail{
			ScenarioTitle:  "Knihovna",
			ScenarioPrompt: "Chcete se prihlasit do knihovny a zjistit dulezite informace.",
			RequiredInfoSlots: []contracts.RequiredInfoSlot{
				{SlotKey: "opening_hours", Label: "Oteviraci doba", SampleQuestion: "Kdy mate otevreno?"},
				{SlotKey: "membership_fee", Label: "Clensky poplatek", SampleQuestion: "Kolik stoji registrace?"},
			},
			CustomQuestionHint: "Zeptejte se i na vypujcni dobu.",
		},
	})

	detail, ok := created.Detail.(contracts.Uloha2Detail)
	if !ok {
		t.Fatalf("expected detail to stay typed as Uloha2Detail, got %T", created.Detail)
	}
	if detail.ScenarioTitle != "Knihovna" {
		t.Fatalf("expected scenario title Knihovna, got %q", detail.ScenarioTitle)
	}
	if len(detail.RequiredInfoSlots) != 2 {
		t.Fatalf("expected 2 required info slots, got %d", len(detail.RequiredInfoSlots))
	}
}

func TestCreateExercisePreservesUloha3DetailType(t *testing.T) {
	repo := NewMemoryStore()

	created := repo.CreateExercise(contracts.Exercise{
		ModuleID:             "module-day-2",
		ExerciseType:         "uloha_3_story_narration",
		Title:                "Cesta domu",
		ShortInstruction:     "Vypravejte pribeh podle 4 kroku.",
		LearnerInstruction:   "Ban ke lai cau chuyen theo thu tu.",
		EstimatedDurationSec: 120,
		SampleAnswerEnabled:  true,
		Detail: contracts.Uloha3Detail{
			StoryTitle: "Cesta domu",
			ImageAssetIDs: []string{
				"asset-1",
				"asset-2",
				"asset-3",
				"asset-4",
			},
			NarrativeCheckpoints: []string{
				"Prisli na zastavku.",
				"Cekali na autobus.",
				"Nastoupili do autobusu.",
				"Dojeli domu.",
			},
			GrammarFocus: []string{"past_tense"},
		},
	})

	detail, ok := created.Detail.(contracts.Uloha3Detail)
	if !ok {
		t.Fatalf("expected detail to stay typed as Uloha3Detail, got %T", created.Detail)
	}
	if detail.StoryTitle != "Cesta domu" {
		t.Fatalf("expected story title Cesta domu, got %q", detail.StoryTitle)
	}
	if len(detail.NarrativeCheckpoints) != 4 {
		t.Fatalf("expected 4 narrative checkpoints, got %d", len(detail.NarrativeCheckpoints))
	}
}

func TestCreateExercisePreservesUloha4DetailType(t *testing.T) {
	repo := NewMemoryStore()

	created := repo.CreateExercise(contracts.Exercise{
		ModuleID:             "module-day-2",
		ExerciseType:         "uloha_4_choice_reasoning",
		Title:                "Doprava do prace",
		ShortInstruction:     "Vyberte jednu moznost a vysvetlete proc.",
		LearnerInstruction:   "Ban can chon mot phuong an roi giai thich.",
		EstimatedDurationSec: 90,
		SampleAnswerEnabled:  true,
		Detail: contracts.Uloha4Detail{
			ScenarioPrompt: "Jak pojedete do prace?",
			Options: []contracts.ChoiceOption{
				{OptionKey: "bus", Label: "Autobus", Description: "Levny a pomaly."},
				{OptionKey: "metro", Label: "Metro", Description: "Rychle a pohodlne."},
				{OptionKey: "bike", Label: "Kolo", Description: "Zdrave, ale narocne."},
			},
			ExpectedReasoningAxes: []string{"price", "speed"},
		},
	})

	detail, ok := created.Detail.(contracts.Uloha4Detail)
	if !ok {
		t.Fatalf("expected detail to stay typed as Uloha4Detail, got %T", created.Detail)
	}
	if detail.ScenarioPrompt != "Jak pojedete do prace?" {
		t.Fatalf("expected scenario prompt to round-trip, got %q", detail.ScenarioPrompt)
	}
	if len(detail.Options) != 3 {
		t.Fatalf("expected 3 options, got %d", len(detail.Options))
	}
}

func TestExercisesByModuleSkipsArchivedItems(t *testing.T) {
	repo := NewMemoryStore()

	published := repo.CreateExercise(contracts.Exercise{
		ModuleID:             "module-day-1",
		SkillKind:            "noi",
		ExerciseType:         "uloha_1_topic_answers",
		Title:                "Cestovani 1",
		ShortInstruction:     "Tra loi ve chu de di lai.",
		LearnerInstruction:   "Ban se noi ngan gon ve viec di lai.",
		EstimatedDurationSec: 90,
		Status:               "published",
	})
	repo.CreateExercise(contracts.Exercise{
		ModuleID:             "module-day-1",
		SkillKind:            "noi",
		ExerciseType:         "uloha_1_topic_answers",
		Title:                "Cestovani 2",
		ShortInstruction:     "Tra loi ve chu de di lai.",
		LearnerInstruction:   "Ban se noi ngan gon ve viec di lai.",
		EstimatedDurationSec: 90,
		Status:               "archived",
	})

	items := repo.ExercisesByModule("module-day-1")

	foundPublished := false
	for _, item := range items {
		if item.ID == published.ID {
			foundPublished = true
		}
		if item.Status == "archived" {
			t.Fatalf("did not expect archived item %s in learner list", item.ID)
		}
	}
	if !foundPublished {
		t.Fatalf("expected published exercise %s to be returned", published.ID)
	}
}

func TestExercisesByModuleReturnsEmptySliceWhenModuleHasNoExercises(t *testing.T) {
	repo := NewMemoryStore()

	items := repo.ExercisesByModule("module-empty")

	if items == nil {
		t.Fatal("expected empty slice, got nil")
	}
	if len(items) != 0 {
		t.Fatalf("expected no exercises, got %d", len(items))
	}
}

func TestDeleteExerciseRemovesItem(t *testing.T) {
	repo := NewMemoryStore()

	created := repo.CreateExercise(contracts.Exercise{
		ModuleID:             "module-day-1",
		ExerciseType:         "uloha_1_topic_answers",
		Title:                "Mazani 1",
		ShortInstruction:     "Delete me",
		LearnerInstruction:   "Delete me",
		EstimatedDurationSec: 90,
	})

	if ok := repo.DeleteExercise(created.ID); !ok {
		t.Fatalf("expected exercise %s to be deleted", created.ID)
	}
	if _, ok := repo.Exercise(created.ID); ok {
		t.Fatalf("expected exercise %s to be gone after delete", created.ID)
	}
}

func TestRollupReadiness(t *testing.T) {
	tests := []struct {
		name          string
		levels        []string
		wantLevel     string
		wantSummaryOK bool // summary must be non-empty and not contain ":"
	}{
		{
			name:          "all ready → ready",
			levels:        []string{"ready", "ready", "ready", "ready"},
			wantLevel:     "ready",
			wantSummaryOK: true,
		},
		{
			name:          "mix ready+almost → almost",
			levels:        []string{"ready", "almost", "almost", "needs_work"},
			wantLevel:     "almost",
			wantSummaryOK: true,
		},
		{
			name:          "mix almost+needs_work → needs_work",
			levels:        []string{"almost", "needs_work", "needs_work", "not_ready"},
			wantLevel:     "needs_work",
			wantSummaryOK: true,
		},
		{
			name:          "all not_ready → not_ready",
			levels:        []string{"not_ready", "not_ready", "not_ready", "not_ready"},
			wantLevel:     "not_ready",
			wantSummaryOK: true,
		},
		{
			name:          "empty → not_ready",
			levels:        []string{},
			wantLevel:     "not_ready",
			wantSummaryOK: true,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			level, summary := rollupReadiness(tc.levels)
			if level != tc.wantLevel {
				t.Errorf("level = %q, want %q", level, tc.wantLevel)
			}
			if summary == "" {
				t.Error("summary must not be empty")
			}
			for _, ch := range summary {
				if ch == ':' {
					t.Errorf("summary looks like debug format (contains ':'): %q", summary)
					break
				}
			}
		})
	}
}

// V22 CMS Catch-Up — Phase B1.
// ListAttemptsForUser is the per-user descending-by-started_at list used by
// the X-Ray screen "Recent attempts" section. Limit clamps the slice;
// limit=0 means unlimited.
func TestMemoryAttemptStore_ListAttemptsForUser_FiltersAndLimits(t *testing.T) {
	s := newMemoryAttemptStore()

	// Seed 2 attempts for user-A and 1 for user-B.
	if _, err := s.CreateAttempt("user-A", "ex-1", "uloha_1", "ios", "0.1", "vi"); err != nil {
		t.Fatalf("seed user-A #1: %v", err)
	}
	if _, err := s.CreateAttempt("user-A", "ex-2", "uloha_1", "ios", "0.1", "vi"); err != nil {
		t.Fatalf("seed user-A #2: %v", err)
	}
	if _, err := s.CreateAttempt("user-B", "ex-3", "uloha_1", "ios", "0.1", "vi"); err != nil {
		t.Fatalf("seed user-B: %v", err)
	}

	out := s.ListAttemptsForUser("user-A", 10)
	if len(out) != 2 {
		t.Fatalf("expected 2 attempts for user-A, got %d", len(out))
	}
	for _, a := range out {
		if a.UserID != "user-A" {
			t.Errorf("found attempt leaked from another user: %s", a.UserID)
		}
	}

	// Limit clamps result length.
	if got := s.ListAttemptsForUser("user-A", 1); len(got) != 1 {
		t.Errorf("limit=1 expected 1 row, got %d", len(got))
	}

	// Unknown user → empty slice.
	if got := s.ListAttemptsForUser("user-Z", 10); len(got) != 0 {
		t.Errorf("expected empty slice for unknown user, got %d", len(got))
	}
}
