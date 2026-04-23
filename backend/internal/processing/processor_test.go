package processing

import (
	"fmt"
	"strings"
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

func TestProcessorCompletesAttemptWithStructuredFeedback(t *testing.T) {
	repo := store.NewMemoryStore()
	attemptID := seedUploadedAttempt(t, repo, 18000)

	processor := NewProcessor(repo, nil, mockTTSProvider{
		audio: &contracts.ReviewArtifactAudio{StorageKey: "attempt-review/" + attemptID + "/model-answer.wav", MimeType: "audio/wav"},
	})
	if err := processor.ProcessAttempt(attemptID); err != nil {
		t.Fatalf("ProcessAttempt returned error: %v", err)
	}

	attempt, ok := repo.Attempt(attemptID)
	if !ok {
		t.Fatalf("attempt %s not found after processing", attemptID)
	}
	if attempt.Status != "completed" {
		t.Fatalf("expected completed status, got %s", attempt.Status)
	}
	if attempt.Transcript == nil {
		t.Fatal("expected transcript to be stored")
	}
	if attempt.Transcript.Locale != "cs-CZ" {
		t.Fatalf("expected transcript locale cs-CZ, got %s", attempt.Transcript.Locale)
	}
	if attempt.Feedback == nil {
		t.Fatal("expected feedback to be stored")
	}
	if attempt.Feedback.TaskCompletion.ScoreBand == "" {
		t.Fatal("expected task completion score band")
	}
	if !criterionMet(attempt.Feedback.TaskCompletion.CriteriaResults, "answered_question") {
		t.Fatal("expected answered_question criterion to pass")
	}
	if !criterionMet(attempt.Feedback.TaskCompletion.CriteriaResults, "gave_supporting_detail") {
		t.Fatal("expected gave_supporting_detail criterion to pass for a longer answer")
	}
	if attempt.Feedback.ReadinessLevel == "" {
		t.Fatal("expected readiness level")
	}
}

func TestProcessorUsesSofterFeedbackForShortRecordings(t *testing.T) {
	repo := store.NewMemoryStore()
	attemptID := seedUploadedAttempt(t, repo, 3500)

	processor := NewProcessor(repo, nil, mockTTSProvider{
		audio: &contracts.ReviewArtifactAudio{StorageKey: "attempt-review/" + attemptID + "/model-answer.wav", MimeType: "audio/wav"},
	})
	if err := processor.ProcessAttempt(attemptID); err != nil {
		t.Fatalf("ProcessAttempt returned error: %v", err)
	}

	attempt, ok := repo.Attempt(attemptID)
	if !ok {
		t.Fatalf("attempt %s not found after processing", attemptID)
	}
	if attempt.Status != "completed" {
		t.Fatalf("expected completed status, got %s", attempt.Status)
	}
	if attempt.Feedback == nil {
		t.Fatal("expected feedback to be stored")
	}
	if attempt.Feedback.ReadinessLevel != "needs_work" {
		t.Fatalf("expected needs_work readiness for short recording, got %s", attempt.Feedback.ReadinessLevel)
	}
	if criterionMet(attempt.Feedback.TaskCompletion.CriteriaResults, "gave_supporting_detail") {
		t.Fatal("expected gave_supporting_detail criterion to fail for a short answer")
	}
	if len(attempt.Feedback.Improvements) == 0 {
		t.Fatal("expected at least one improvement")
	}
	if attempt.ReviewArtifact == nil {
		t.Fatal("expected review artifact summary to be stored")
	}
	if attempt.ReviewArtifact.Status != "ready" {
		t.Fatalf("expected ready review artifact summary, got %q", attempt.ReviewArtifact.Status)
	}
}

func TestBuildFeedbackUsesTaskAwareSummaryForUloha1(t *testing.T) {
	exercise := contracts.Exercise{
		ID:           "exercise-uloha1-weather",
		ExerciseType: "uloha_1_topic_answers",
		Title:        "Pocasi 1",
		Prompt: contracts.Uloha1Prompt{
			TopicLabel: "Pocasi",
		},
	}

	feedback, ok := buildFeedback(exercise, contracts.Transcript{
		FullText: "Mam rad pocasi.",
		Locale:   "cs-CZ",
	}, reliabilityUsable)
	if !ok {
		t.Fatal("expected feedback to be generated")
	}
	if feedback.OverallSummary == "" {
		t.Fatal("expected non-empty summary")
	}
	if !strings.Contains(feedback.OverallSummary, "Pocasi") {
		t.Fatalf("expected summary to mention topic label, got %q", feedback.OverallSummary)
	}
	if len(feedback.RetryAdvice) == 0 {
		t.Fatal("expected retry advice")
	}
	if !containsString(feedback.RetryAdvice, "protoze") {
		t.Fatalf("expected retry advice to suggest adding detail, got %#v", feedback.RetryAdvice)
	}
}

func TestBuildFeedbackUsesTaskAwareSummaryForUloha2(t *testing.T) {
	exercise := contracts.Exercise{
		ID:           "exercise-uloha2-cinema",
		ExerciseType: "uloha_2_dialogue_questions",
		Title:        "Kino vecer",
		Detail: contracts.Uloha2Detail{
			ScenarioTitle: "Navsteva kina",
		},
	}

	feedback, ok := buildFeedback(exercise, contracts.Transcript{
		FullText: "Kolik to stoji a v kolik hodin to zacina?",
		Locale:   "cs-CZ",
	}, reliabilityUsable)
	if !ok {
		t.Fatal("expected feedback to be generated")
	}
	if !strings.Contains(feedback.OverallSummary, "Navsteva kina") {
		t.Fatalf("expected summary to mention scenario title, got %q", feedback.OverallSummary)
	}
	if len(feedback.RetryAdvice) == 0 {
		t.Fatal("expected retry advice")
	}
	if !containsString(feedback.RetryAdvice, "cau hoi bo sung") {
		t.Fatalf("expected retry advice to mention follow-up question, got %#v", feedback.RetryAdvice)
	}
}

func TestProcessorCreatesTextOnlyReviewArtifactForStrongUloha1Attempt(t *testing.T) {
	repo := store.NewMemoryStore()
	attemptID := seedUploadedAttempt(t, repo, 18000)

	processor := NewProcessor(repo, mockTranscriber{
		transcript: contracts.Transcript{
			FullText:    "ja mam rad teple pocasi protoze muzu byt dlouho venku s rodinou",
			Locale:      "cs-CZ",
			Provider:    "amazon_transcribe",
			IsSynthetic: false,
		},
		reliability: reliabilityUsable,
		usable:      true,
	}, mockTTSProvider{
		audio: &contracts.ReviewArtifactAudio{StorageKey: "attempt-review/" + attemptID + "/model-answer.wav", MimeType: "audio/wav"},
	})
	if err := processor.ProcessAttempt(attemptID); err != nil {
		t.Fatalf("ProcessAttempt returned error: %v", err)
	}

	attempt, ok := repo.Attempt(attemptID)
	if !ok {
		t.Fatalf("attempt %s not found after processing", attemptID)
	}
	if attempt.ReviewArtifact == nil || attempt.ReviewArtifact.Status != "ready" {
		t.Fatalf("expected ready review artifact summary, got %+v", attempt.ReviewArtifact)
	}

	artifact, ok := repo.ReviewArtifact(attemptID)
	if !ok {
		t.Fatalf("expected review artifact for attempt %s", attemptID)
	}
	if artifact.CorrectedTranscriptText != "Mam rad teple pocasi protoze muzu byt dlouho venku s rodinou." {
		t.Fatalf("unexpected corrected transcript %q", artifact.CorrectedTranscriptText)
	}
	if artifact.ModelAnswerText == "" {
		t.Fatal("expected model answer text")
	}
	if artifact.ModelAnswerText != artifact.CorrectedTranscriptText {
		t.Fatalf("expected strong answer to keep model answer close to corrected transcript, got corrected=%q model=%q", artifact.CorrectedTranscriptText, artifact.ModelAnswerText)
	}
	if len(artifact.DiffChunks) == 0 {
		t.Fatal("expected diff chunks for review artifact")
	}
	if len(artifact.SpeakingFocusItems) == 0 {
		t.Fatal("expected speaking focus items for review artifact")
	}
	if artifact.TTSAudio == nil || artifact.TTSAudio.MimeType != "audio/wav" {
		t.Fatalf("expected generated TTS audio metadata, got %+v", artifact.TTSAudio)
	}
}

func TestProcessorCreatesTextOnlyReviewArtifactForWeakUloha1Attempt(t *testing.T) {
	repo := store.NewMemoryStore()
	attemptID := seedUploadedAttempt(t, repo, 3500)

	processor := NewProcessor(repo, mockTranscriber{
		transcript: contracts.Transcript{
			FullText:    "ja mam rad pocasi",
			Locale:      "cs-CZ",
			Provider:    "amazon_transcribe",
			IsSynthetic: false,
		},
		reliability: reliabilityUsableWithWarnings,
		usable:      true,
	}, mockTTSProvider{
		audio: &contracts.ReviewArtifactAudio{StorageKey: "attempt-review/" + attemptID + "/model-answer.wav", MimeType: "audio/wav"},
	})
	if err := processor.ProcessAttempt(attemptID); err != nil {
		t.Fatalf("ProcessAttempt returned error: %v", err)
	}

	artifact, ok := repo.ReviewArtifact(attemptID)
	if !ok {
		t.Fatalf("expected review artifact for attempt %s", attemptID)
	}
	if artifact.CorrectedTranscriptText != "Mam rad pocasi." {
		t.Fatalf("unexpected corrected transcript %q", artifact.CorrectedTranscriptText)
	}
	if !strings.Contains(artifact.ModelAnswerText, "protoze") {
		t.Fatalf("expected weaker answer to receive a stronger model answer, got %q", artifact.ModelAnswerText)
	}
	if len(artifact.SpeakingFocusItems) == 0 {
		t.Fatal("expected speaking focus items for weaker answer")
	}
	if artifact.SpeakingFocusItems[0].CommentVI == "" {
		t.Fatal("expected learner-facing comment on speaking focus item")
	}
}

func TestProcessorCreatesTaskAwareReviewArtifactForUloha2Attempt(t *testing.T) {
	repo := store.NewMemoryStore()
	attemptID := seedUploadedAttemptForExercise(t, repo, "exercise-uloha2-cinema", 18000)

	processor := NewProcessor(repo, mockTranscriber{
		transcript: contracts.Transcript{
			FullText:    "kolik to stoji a v kolik hodin to zacina",
			Locale:      "cs-CZ",
			Provider:    "amazon_transcribe",
			IsSynthetic: false,
		},
		reliability: reliabilityUsable,
		usable:      true,
	}, mockTTSProvider{
		audio: &contracts.ReviewArtifactAudio{StorageKey: "attempt-review/" + attemptID + "/model-answer.wav", MimeType: "audio/wav"},
	})
	if err := processor.ProcessAttempt(attemptID); err != nil {
		t.Fatalf("ProcessAttempt returned error: %v", err)
	}

	artifact, ok := repo.ReviewArtifact(attemptID)
	if !ok {
		t.Fatalf("expected review artifact for attempt %s", attemptID)
	}
	if artifact.CorrectedTranscriptText == "" {
		t.Fatal("expected corrected transcript text")
	}
	if !strings.Contains(artifact.CorrectedTranscriptText, "?") {
		t.Fatalf("expected corrected transcript to use question form, got %q", artifact.CorrectedTranscriptText)
	}
	if !strings.Contains(artifact.CorrectedTranscriptText, "Kolik stoji jeden listek?") {
		t.Fatalf("expected corrected transcript to keep price question intent, got %q", artifact.CorrectedTranscriptText)
	}
	if !strings.Contains(artifact.CorrectedTranscriptText, "V kolik hodin film zacina?") {
		t.Fatalf("expected corrected transcript to keep start-time question intent, got %q", artifact.CorrectedTranscriptText)
	}
	if !strings.Contains(artifact.ModelAnswerText, "Muzu si koupit listek online?") {
		t.Fatalf("expected model answer to add the missing required slot, got %q", artifact.ModelAnswerText)
	}
	if !strings.Contains(artifact.ModelAnswerText, "A jsou tam titulky?") {
		t.Fatalf("expected model answer to include an extra natural question, got %q", artifact.ModelAnswerText)
	}
	if len(artifact.SpeakingFocusItems) == 0 {
		t.Fatal("expected speaking focus items for Uloha 2 review artifact")
	}
}

func TestBuildUloha2SpeakingFocusMentionsQuestionFormAndMissingSlots(t *testing.T) {
	exercise := contracts.Exercise{
		ID:           "exercise-uloha2-cinema",
		ExerciseType: "uloha_2_dialogue_questions",
		Title:        "Kino vecer",
		Detail: contracts.Uloha2Detail{
			ScenarioTitle: "Navsteva kina",
			RequiredInfoSlots: []contracts.RequiredInfoSlot{
				{SlotKey: "start_time", Label: "Cas zacatku", SampleQuestion: "V kolik hodin film zacina?"},
				{SlotKey: "price", Label: "Cena listku", SampleQuestion: "Kolik stoji jeden listek?"},
				{SlotKey: "online_ticket", Label: "Nakup online", SampleQuestion: "Muzu si koupit listek online?"},
			},
			CustomQuestionHint: "Pridejte jeste jednu prirozenou doplnujici otazku, treba na titulky nebo sal.",
		},
	}
	feedback := contracts.AttemptFeedback{
		TaskCompletion: contracts.TaskCompletion{
			CriteriaResults: []contracts.CriterionCheck{
				{CriterionKey: "covered_required_slots", Met: false},
				{CriterionKey: "used_question_form", Met: false},
				{CriterionKey: "included_custom_question", Met: false},
			},
		},
	}

	items := buildUloha2SpeakingFocus(exercise, "kino cena", "Kolik stoji jeden listek?", feedback)
	if len(items) < 2 {
		t.Fatalf("expected at least two speaking focus items, got %+v", items)
	}
	if !containsFocusKey(items, "question_form") {
		t.Fatalf("expected question-form focus item, got %+v", items)
	}
	if !containsFocusKey(items, "required_slots") {
		t.Fatalf("expected required-slots focus item, got %+v", items)
	}
}

func TestProcessorStillCompletesAttemptWhenReviewArtifactPersistenceFails(t *testing.T) {
	baseRepo := store.NewMemoryStore()
	attemptID := seedUploadedAttempt(t, baseRepo, 18000)
	repo := failingReviewArtifactRepo{MemoryStore: baseRepo}

	processor := NewProcessor(repo, mockTranscriber{
		transcript: contracts.Transcript{
			FullText:    "ja mam rad teple pocasi protoze muzu byt venku",
			Locale:      "cs-CZ",
			Provider:    "amazon_transcribe",
			IsSynthetic: false,
		},
		reliability: reliabilityUsable,
		usable:      true,
	}, mockTTSProvider{
		err: fmt.Errorf("tts offline"),
	})
	if err := processor.ProcessAttempt(attemptID); err != nil {
		t.Fatalf("ProcessAttempt returned error: %v", err)
	}

	attempt, ok := baseRepo.Attempt(attemptID)
	if !ok {
		t.Fatalf("attempt %s not found after processing", attemptID)
	}
	if attempt.Status != "completed" {
		t.Fatalf("expected attempt to remain completed, got %s", attempt.Status)
	}
	if attempt.Feedback == nil {
		t.Fatal("expected feedback to remain stored even if review artifact persistence fails")
	}
	if attempt.ReviewArtifact != nil {
		t.Fatalf("expected no review artifact summary after persistence failure, got %+v", attempt.ReviewArtifact)
	}
}

func TestProcessorPersistsTTSAudioMetadataOnReadyReviewArtifact(t *testing.T) {
	repo := store.NewMemoryStore()
	attemptID := seedUploadedAttempt(t, repo, 18000)

	processor := NewProcessor(repo, mockTranscriber{
		transcript: contracts.Transcript{
			FullText:    "ja mam rad teple pocasi protoze muzu byt dlouho venku",
			Locale:      "cs-CZ",
			Provider:    "amazon_transcribe",
			IsSynthetic: false,
		},
		reliability: reliabilityUsable,
		usable:      true,
	}, mockTTSProvider{
		audio: &contracts.ReviewArtifactAudio{
			StorageKey: "attempt-review/" + attemptID + "/model-answer.wav",
			MimeType:   "audio/wav",
		},
	})
	if err := processor.ProcessAttempt(attemptID); err != nil {
		t.Fatalf("ProcessAttempt returned error: %v", err)
	}

	artifact, ok := repo.ReviewArtifact(attemptID)
	if !ok {
		t.Fatalf("expected review artifact for attempt %s", attemptID)
	}
	if artifact.TTSAudio == nil {
		t.Fatal("expected TTS audio metadata to be persisted")
	}
	if artifact.TTSAudio.StorageKey == "" || artifact.TTSAudio.MimeType == "" {
		t.Fatalf("expected TTS metadata to be populated, got %+v", artifact.TTSAudio)
	}
	if artifact.GeneratedAt == "" {
		t.Fatal("expected generated_at on review artifact")
	}
}

func TestProcessorKeepsTextArtifactWhenTTSGenerationFails(t *testing.T) {
	repo := store.NewMemoryStore()
	attemptID := seedUploadedAttempt(t, repo, 18000)

	processor := NewProcessor(repo, mockTranscriber{
		transcript: contracts.Transcript{
			FullText:    "ja mam rad pocasi",
			Locale:      "cs-CZ",
			Provider:    "amazon_transcribe",
			IsSynthetic: false,
		},
		reliability: reliabilityUsableWithWarnings,
		usable:      true,
	}, mockTTSProvider{
		err: fmt.Errorf("tts provider unavailable"),
	})
	if err := processor.ProcessAttempt(attemptID); err != nil {
		t.Fatalf("ProcessAttempt returned error: %v", err)
	}

	attempt, ok := repo.Attempt(attemptID)
	if !ok {
		t.Fatalf("attempt %s not found after processing", attemptID)
	}
	if attempt.Status != "completed" {
		t.Fatalf("expected completed attempt, got %s", attempt.Status)
	}

	artifact, ok := repo.ReviewArtifact(attemptID)
	if !ok {
		t.Fatalf("expected review artifact for attempt %s", attemptID)
	}
	if artifact.CorrectedTranscriptText == "" || artifact.ModelAnswerText == "" {
		t.Fatalf("expected text artifact to remain even when TTS fails, got %+v", artifact)
	}
	if artifact.TTSAudio != nil {
		t.Fatalf("expected no TTS metadata on TTS failure, got %+v", artifact.TTSAudio)
	}
}

func TestProcessorFailsAttemptWithoutUploadedAudio(t *testing.T) {
	repo := store.NewMemoryStore()
	attempt, err := repo.CreateAttempt("user-learner-1", "exercise-uloha1-weather", "ios", "0.1.0")
	if err != nil {
		t.Fatalf("CreateAttempt returned error: %v", err)
	}

	processor := NewProcessor(repo, nil, mockTTSProvider{})
	if err := processor.ProcessAttempt(attempt.ID); err != nil {
		t.Fatalf("ProcessAttempt returned error: %v", err)
	}

	updated, ok := repo.Attempt(attempt.ID)
	if !ok {
		t.Fatalf("attempt %s not found after processing", attempt.ID)
	}
	if updated.Status != "failed" {
		t.Fatalf("expected failed status, got %s", updated.Status)
	}
	if updated.FailureCode != "audio_invalid" {
		t.Fatalf("expected failure code audio_invalid, got %s", updated.FailureCode)
	}
}

func TestProcessorUsesInjectedTranscriberOutput(t *testing.T) {
	repo := store.NewMemoryStore()
	attemptID := seedUploadedAttempt(t, repo, 18000)

	processor := NewProcessor(repo, mockTranscriber{
		transcript: contracts.Transcript{
			FullText:   "Tohle je transcript z injektovaneho transcriberu.",
			Locale:     "cs-CZ",
			Confidence: 0.77,
		},
		reliability: reliabilityUsable,
		usable:      true,
	}, mockTTSProvider{})
	if err := processor.ProcessAttempt(attemptID); err != nil {
		t.Fatalf("ProcessAttempt returned error: %v", err)
	}

	attempt, ok := repo.Attempt(attemptID)
	if !ok {
		t.Fatalf("attempt %s not found after processing", attemptID)
	}
	if attempt.Transcript == nil {
		t.Fatal("expected transcript to be stored")
	}
	if attempt.Transcript.FullText != "Tohle je transcript z injektovaneho transcriberu." {
		t.Fatalf("expected injected transcript text, got %q", attempt.Transcript.FullText)
	}
}

func TestProcessorFailsWhenTranscriberReturnsUnusableTranscript(t *testing.T) {
	repo := store.NewMemoryStore()
	attemptID := seedUploadedAttempt(t, repo, 18000)

	processor := NewProcessor(repo, mockTranscriber{
		reliability: reliabilityUnusable,
		usable:      false,
	}, mockTTSProvider{})
	if err := processor.ProcessAttempt(attemptID); err != nil {
		t.Fatalf("ProcessAttempt returned error: %v", err)
	}

	attempt, ok := repo.Attempt(attemptID)
	if !ok {
		t.Fatalf("attempt %s not found after processing", attemptID)
	}
	if attempt.Status != "failed" {
		t.Fatalf("expected failed status, got %s", attempt.Status)
	}
	if attempt.FailureCode != "transcription_failed" {
		t.Fatalf("expected transcription_failed, got %s", attempt.FailureCode)
	}
}

func seedUploadedAttempt(t *testing.T, repo *store.MemoryStore, durationMs int) string {
	t.Helper()

	attempt, err := repo.CreateAttempt("user-learner-1", "exercise-uloha1-weather", "ios", "0.1.0")
	if err != nil {
		t.Fatalf("CreateAttempt returned error: %v", err)
	}

	audio := contracts.AttemptAudio{
		StorageKey:     fmt.Sprintf("attempt-audio/%s/audio.m4a", attempt.ID),
		MimeType:       "audio/m4a",
		DurationMs:     durationMs,
		SampleRateHz:   44100,
		Channels:       1,
		FileSizeBytes:  182044,
		StoredFilePath: fmt.Sprintf("/tmp/czech-go-system/attempt-audio/%s/audio.m4a", attempt.ID),
	}
	if _, ok := repo.MarkUploadComplete(attempt.ID, audio); !ok {
		t.Fatalf("MarkUploadComplete failed for attempt %s", attempt.ID)
	}

	return attempt.ID
}

func seedUploadedAttemptForExercise(t *testing.T, repo *store.MemoryStore, exerciseID string, durationMs int) string {
	t.Helper()

	attempt, err := repo.CreateAttempt("user-learner-1", exerciseID, "ios", "0.1.0")
	if err != nil {
		t.Fatalf("CreateAttempt returned error: %v", err)
	}

	audio := contracts.AttemptAudio{
		StorageKey:     fmt.Sprintf("attempt-audio/%s/audio.m4a", attempt.ID),
		MimeType:       "audio/m4a",
		DurationMs:     durationMs,
		SampleRateHz:   44100,
		Channels:       1,
		FileSizeBytes:  182044,
		StoredFilePath: fmt.Sprintf("/tmp/czech-go-system/attempt-audio/%s/audio.m4a", attempt.ID),
	}
	if _, ok := repo.MarkUploadComplete(attempt.ID, audio); !ok {
		t.Fatalf("MarkUploadComplete failed for attempt %s", attempt.ID)
	}

	return attempt.ID
}

func criterionMet(criteria []contracts.CriterionCheck, key string) bool {
	for _, criterion := range criteria {
		if criterion.CriterionKey == key {
			return criterion.Met
		}
	}
	return false
}

type mockTranscriber struct {
	transcript  contracts.Transcript
	reliability transcriptReliability
	usable      bool
	err         error
}

func (m mockTranscriber) Transcribe(_ contracts.Exercise, _ contracts.AttemptAudio) (contracts.Transcript, transcriptReliability, bool, error) {
	return m.transcript, m.reliability, m.usable, m.err
}

type mockTTSProvider struct {
	audio *contracts.ReviewArtifactAudio
	err   error
}

func (m mockTTSProvider) Generate(_, _ string) (*contracts.ReviewArtifactAudio, error) {
	if m.err != nil {
		return nil, m.err
	}
	return m.audio, nil
}

func containsString(items []string, want string) bool {
	for _, item := range items {
		if strings.Contains(item, want) {
			return true
		}
	}
	return false
}

func containsFocusKey(items []contracts.SpeakingFocusItem, want string) bool {
	for _, item := range items {
		if item.FocusKey == want {
			return true
		}
	}
	return false
}

func TestBuildReadableDiffChunksCoversReplacement(t *testing.T) {
	chunks := buildReadableDiffChunks("ja mam rad pocasi", "Mam rad pocasi.")

	if len(chunks) == 0 {
		t.Fatal("expected diff chunks")
	}
	foundReplacement := false
	for _, chunk := range chunks {
		if chunk.Kind == "replaced" {
			foundReplacement = true
			if chunk.SourceText == "" || chunk.TargetText == "" {
				t.Fatalf("expected replacement chunk to carry source and target text, got %+v", chunk)
			}
		}
	}
	if !foundReplacement {
		t.Fatalf("expected at least one replacement chunk, got %+v", chunks)
	}
}

func TestBuildReadableDiffChunksCoversInsertion(t *testing.T) {
	chunks := buildReadableDiffChunks("Mam rad pocasi.", "Mam rad teple pocasi.")

	if len(chunks) == 0 {
		t.Fatal("expected diff chunks")
	}
	foundInsertion := false
	for _, chunk := range chunks {
		if chunk.Kind == "inserted" || chunk.Kind == "replaced" {
			foundInsertion = true
		}
	}
	if !foundInsertion {
		t.Fatalf("expected insertion-like diff chunk, got %+v", chunks)
	}
}

func TestBuildReadableDiffChunksCoversNoChange(t *testing.T) {
	chunks := buildReadableDiffChunks("Mam rad teple pocasi.", "Mam rad teple pocasi.")

	if len(chunks) != 1 {
		t.Fatalf("expected exactly one unchanged chunk, got %+v", chunks)
	}
	if chunks[0].Kind != "unchanged" {
		t.Fatalf("expected unchanged diff chunk, got %+v", chunks[0])
	}
}

func TestBuildUloha1SpeakingFocusReturnsPracticalItems(t *testing.T) {
	exercise := contracts.Exercise{
		ID:           "exercise-uloha1-weather",
		ExerciseType: "uloha_1_topic_answers",
		Title:        "Pocasi 1",
		Prompt: contracts.Uloha1Prompt{
			TopicLabel: "Pocasi",
		},
	}
	feedback := contracts.AttemptFeedback{
		TaskCompletion: contracts.TaskCompletion{
			CriteriaResults: []contracts.CriterionCheck{
				{CriterionKey: "answered_question", Met: true},
				{CriterionKey: "stayed_on_topic", Met: true},
				{CriterionKey: "gave_supporting_detail", Met: false},
			},
		},
	}

	items := buildUloha1SpeakingFocus(exercise, "ja mam rad pocasi", "Mam rad pocasi.", feedback)
	if len(items) == 0 {
		t.Fatal("expected speaking focus items")
	}
	if items[0].Label == "" || items[0].CommentVI == "" {
		t.Fatalf("expected practical focus item content, got %+v", items[0])
	}
}

type failingReviewArtifactRepo struct {
	*store.MemoryStore
}

func (r failingReviewArtifactRepo) UpsertReviewArtifact(_ string, _ contracts.AttemptReviewArtifact) (*contracts.AttemptReviewArtifact, bool) {
	return nil, false
}
