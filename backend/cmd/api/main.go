package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/email"
	"github.com/danieldev/czech-go-system/backend/internal/httpapi"
	"github.com/danieldev/czech-go-system/backend/internal/iap"
	"github.com/danieldev/czech-go-system/backend/internal/processing"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

func main() {
	addr := os.Getenv("API_ADDR")
	if addr == "" {
		addr = ":8080"
	}

	var attemptStore store.AttemptStore
	var exerciseStore store.ExerciseStore
	var mockExamStore store.MockExamStore
	var mockTestStore store.MockTestStore
	var courseStore store.CourseStore
	var moduleStore store.ModuleStore
	var vocabularyStore store.VocabularyStore
	var grammarStore store.GrammarStore
	var generationJobStore store.GenerationJobStore
	var exerciseAudioStore store.ExerciseAudioStore
	var exerciseSentenceAudioStore store.ExerciseSentenceAudioStore
	if databaseURL := os.Getenv("DATABASE_URL"); databaseURL != "" {
		// Dev fixture users (learner@example.com etc.) must exist in the
		// Postgres `users` table before any V17/V19 store FK fires, otherwise
		// dev logins silently fail every downstream INSERT (mastery,
		// streaks, pro_purchases, ...). Production builds skip this — real
		// users come through the V17 signup flow.
		if strings.ToLower(strings.TrimSpace(os.Getenv("ENV"))) != "production" {
			if err := store.EnsureDevFixtureUsers(databaseURL); err != nil {
				log.Printf("warning: dev fixture users seed failed: %v", err)
			} else {
				log.Printf("dev fixture users ensured in Postgres (learner/learner2/admin)")
			}
		}

		attemptStore = mustPostgresStore("attempt", store.NewPostgresAttemptStore, databaseURL)
		exerciseStore = mustPostgresStore("exercise", store.NewPostgresExerciseStore, databaseURL)
		mockExamStore = mustPostgresStore("mock exam", store.NewPostgresMockExamStore, databaseURL)
		mockTestStore = mustPostgresStore("mock test", store.NewPostgresMockTestStore, databaseURL)
		courseStore = mustPostgresStore("course", store.NewPostgresCourseStore, databaseURL)
		moduleStore = mustPostgresStore("module", store.NewPostgresModuleStore, databaseURL)
		vocabularyStore = mustPostgresStore("vocabulary", store.NewPostgresVocabularyStore, databaseURL)
		grammarStore = mustPostgresStore("grammar", store.NewPostgresGrammarStore, databaseURL)
		generationJobStore = mustPostgresStore("generation job", store.NewPostgresGenerationJobStore, databaseURL)
		exerciseAudioStore = mustPostgresStore("exercise audio", store.NewPostgresExerciseAudioStore, databaseURL)
		exerciseSentenceAudioStore = mustPostgresStore("exercise sentence audio", store.NewPostgresExerciseSentenceAudioStore, databaseURL)
		log.Printf("full Postgres persistence enabled (attempts, exercises, mock exams/tests, courses, modules, vocabulary, grammar, generation_jobs, exercise_audio, exercise_sentence_audio)")
	}

	repo := store.NewMemoryStoreWithStores(attemptStore, exerciseStore)
	if mockExamStore != nil {
		repo.SetMockExamStore(mockExamStore)
	}
	if mockTestStore != nil {
		repo.SetMockTestStore(mockTestStore)
	}
	if courseStore != nil {
		repo.SetCourseStore(courseStore)
		repo.SetModuleStore(moduleStore)
	}
	if vocabularyStore != nil {
		repo.SetVocabularyStore(vocabularyStore)
		repo.SetGrammarStore(grammarStore)
		repo.SetGenerationJobStore(generationJobStore)
	}
	if exerciseAudioStore != nil {
		repo.SetExerciseAudioStore(exerciseAudioStore)
	}
	if exerciseSentenceAudioStore != nil {
		repo.SetExerciseSentenceAudioStore(exerciseSentenceAudioStore)
	}
	transcriber, err := processing.NewConfiguredTranscriber(context.Background())
	if err != nil {
		log.Fatalf("could not configure transcriber: %v", err)
	}
	if provider := processing.ConfiguredTranscriberProvider(); provider == "dev" {
		log.Printf("warning: backend is using synthetic transcript mode; transcript and feedback will not reflect the learner's real audio. Set ATTEMPT_UPLOAD_PROVIDER=s3, TRANSCRIBER_PROVIDER=amazon_transcribe, and REQUIRE_REAL_TRANSCRIPT=true for real transcript testing.")
	} else {
		log.Printf("transcriber provider enabled: %s", provider)
	}
	ttsProvider, err := processing.NewConfiguredTTSProvider()
	if err != nil {
		log.Fatalf("could not configure tts provider: %v", err)
	}
	log.Printf("tts provider enabled: %s", processing.ConfiguredTTSProvider())
	llmProvider, err := processing.NewConfiguredLLMFeedbackProvider()
	if err != nil {
		log.Printf("warning: llm feedback provider disabled, falling back to rule-based: %v", err)
		llmProvider = nil
	} else {
		log.Printf("llm feedback provider enabled: %s", processing.ConfiguredLLMFeedbackProvider())
	}
	reviewProvider, err := processing.NewConfiguredLLMReviewProvider()
	if err != nil {
		log.Printf("warning: llm review provider disabled, falling back: %v", err)
		reviewProvider = nil
	}
	uploadProvider, err := httpapi.NewConfiguredUploadTargetProvider(context.Background())
	if err != nil {
		log.Fatalf("could not configure upload target provider: %v", err)
	}
	audioSignSecret := httpapi.AudioSigningSecretFromEnv(log.Printf)
	if os.Getenv("AUDIO_SIGN_SECRET") == "" {
		log.Fatalf("AUDIO_SIGN_SECRET must be set; generate with: openssl rand -hex 32")
	}
	audioURLProvider, err := httpapi.NewConfiguredAudioURLProvider(context.Background(), audioSignSecret)
	if err != nil {
		log.Fatalf("could not configure audio url provider: %v", err)
	}
	// V17 self-serve learner — opt-in via the standard env shape.
	// Requires DATABASE_URL (so V17 stores live in Postgres) AND
	// USE_V17_AUTH=true so legacy fixture builds keep working
	// unchanged. Missing dependencies fall through to the legacy
	// NewServerWithAudio path (no V17 routes).
	authDeps, useAuth := buildV17AuthDeps()

	processorInst := processing.NewProcessor(repo, transcriber, ttsProvider, llmProvider, reviewProvider)

	// V19: skill mastery aggregate runs independently of V17 self-serve auth.
	// Build the store + config once and let either constructor (V17 path or
	// dev fixture path) wire it through.
	var masteryDeps httpapi.MasteryDeps
	if databaseURL := os.Getenv("DATABASE_URL"); databaseURL != "" {
		masteryStore, err := store.NewPostgresSkillMasteryStore(databaseURL)
		if err != nil {
			log.Fatalf("V19 skill_mastery store: %v", err)
		}
		masteryDeps = httpapi.MasteryDeps{
			Store:  masteryStore,
			Config: processing.LoadMasteryConfig(),
		}
		log.Printf("V19 skill_mastery aggregate wired (mastery_updater + GET /v1/users/me/progress)")
	}

	var handler http.Handler
	switch {
	case useAuth:
		log.Printf("V17 self-serve auth enabled (signup/login/IAP/quota gates)")
		// V17 callers populate AuthDeps.SkillMastery so applyTo wires the
		// updater; passing masteryDeps too would be redundant.
		authDeps.SkillMastery = masteryDeps.Store
		handler = httpapi.NewServerWithAuth(repo, processorInst, uploadProvider, audioURLProvider, audioSignSecret, authDeps)
	case masteryDeps.Store != nil:
		handler = httpapi.NewServerWithMastery(repo, processorInst, uploadProvider, audioURLProvider, audioSignSecret, masteryDeps)
	default:
		handler = httpapi.NewServerWithAudio(repo, processorInst, uploadProvider, audioURLProvider, audioSignSecret)
	}

	log.Printf("backend listening on %s", addr)
	if err := http.ListenAndServe(addr, handler); err != nil {
		log.Fatal(err)
	}
}

// buildV17AuthDeps assembles the V17 dependency bundle from env. Returns
// (deps, false) when any required piece is missing — caller falls back
// to the legacy NewServerWithAudio path so existing dev/test setups
// keep working without USE_V17_AUTH.
//
// Required:
//   - USE_V17_AUTH=true
//   - DATABASE_URL (for the four V17 Postgres stores)
//
// Optional but recommended:
//   - EMAIL_SMTP_* env vars (no email = signup verify links don't ship)
//   - APPLE_SHARED_SECRET + APPLE_BUNDLE_ID (no IAP verify path)
//   - V17_BASE_URL (defaults to http://localhost:8080)
func buildV17AuthDeps() (httpapi.AuthDeps, bool) {
	if strings.ToLower(strings.TrimSpace(os.Getenv("USE_V17_AUTH"))) != "true" {
		return httpapi.AuthDeps{}, false
	}
	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		log.Printf("V17 auth requested but DATABASE_URL is empty; falling back to legacy")
		return httpapi.AuthDeps{}, false
	}

	users, err := store.NewPostgresUserStore(databaseURL)
	if err != nil {
		log.Fatalf("V17 user store: %v", err)
	}
	tokens, err := store.NewPostgresAuthTokenStore(databaseURL)
	if err != nil {
		log.Fatalf("V17 auth_token store: %v", err)
	}
	streaks, err := store.NewPostgresStreakStore(databaseURL)
	if err != nil {
		log.Fatalf("V17 streak store: %v", err)
	}
	purchases, err := store.NewPostgresProPurchaseStore(databaseURL)
	if err != nil {
		log.Fatalf("V17 pro_purchase store: %v", err)
	}
	usage, err := store.NewPostgresDailyUsageStore(databaseURL)
	if err != nil {
		log.Fatalf("V17 daily_usage store: %v", err)
	}
	// V19 mastery is built once at the top of main() and passed via
	// AuthDeps.SkillMastery (see SkillMastery field on the returned struct
	// being filled in by the caller, not here).

	var sender email.Sender
	if smtpHost := strings.TrimSpace(os.Getenv("EMAIL_SMTP_HOST")); smtpHost != "" {
		s, err := email.NewSMTPSenderFromEnv()
		if err != nil {
			log.Printf("warning: V17 email sender disabled (%v); verify links will not be sent", err)
		} else {
			sender = s
		}
	}

	var appleVerifier iap.AppleVerifier
	if secret := strings.TrimSpace(os.Getenv("APPLE_SHARED_SECRET")); secret != "" {
		bundle := strings.TrimSpace(os.Getenv("APPLE_BUNDLE_ID"))
		if bundle == "" {
			bundle = "eu.hadoo.czechgo"
		}
		appleVerifier = iap.DefaultHTTPAppleVerifier(secret, bundle)
	}

	baseURL := strings.TrimSpace(os.Getenv("V17_BASE_URL"))
	if baseURL == "" {
		baseURL = "http://localhost:8080"
	}

	return httpapi.AuthDeps{
		Users:         users,
		AuthTokens:    tokens,
		Streaks:       streaks,
		ProPurchases:  purchases,
		DailyUsage:    usage,
		EmailSender:   sender,
		AppleVerifier: appleVerifier,
		BaseURL:       baseURL,
		VerifyTTL:     24 * time.Hour,
	}, true
}

func mustPostgresStore[T any](label string, ctor func(string) (T, error), databaseURL string) T {
	s, err := ctor(databaseURL)
	if err != nil {
		log.Fatalf("could not initialize postgres %s store: %v", label, err)
	}
	return s
}
