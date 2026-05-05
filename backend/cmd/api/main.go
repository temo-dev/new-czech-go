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
		persistentAttemptStore, err := store.NewPostgresAttemptStore(databaseURL)
		if err != nil {
			log.Fatalf("could not initialize postgres attempt store: %v", err)
		}
		persistentExerciseStore, err := store.NewPostgresExerciseStore(databaseURL)
		if err != nil {
			log.Fatalf("could not initialize postgres exercise store: %v", err)
		}
		persistentMockExamStore, err := store.NewPostgresMockExamStore(databaseURL)
		if err != nil {
			log.Fatalf("could not initialize postgres mock exam store: %v", err)
		}
		persistentMockTestStore, err := store.NewPostgresMockTestStore(databaseURL)
		if err != nil {
			log.Fatalf("could not initialize postgres mock test store: %v", err)
		}
		persistentCourseStore, err := store.NewPostgresCourseStore(databaseURL)
		if err != nil {
			log.Fatalf("could not initialize postgres course store: %v", err)
		}
		persistentModuleStore, err := store.NewPostgresModuleStore(databaseURL)
		if err != nil {
			log.Fatalf("could not initialize postgres module store: %v", err)
		}
		persistentVocabularyStore, err := store.NewPostgresVocabularyStore(databaseURL)
		if err != nil {
			log.Fatalf("could not initialize postgres vocabulary store: %v", err)
		}
		persistentGrammarStore, err := store.NewPostgresGrammarStore(databaseURL)
		if err != nil {
			log.Fatalf("could not initialize postgres grammar store: %v", err)
		}
		persistentGenerationJobStore, err := store.NewPostgresGenerationJobStore(databaseURL)
		if err != nil {
			log.Fatalf("could not initialize postgres generation job store: %v", err)
		}
		persistentExerciseAudioStore, err := store.NewPostgresExerciseAudioStore(databaseURL)
		if err != nil {
			log.Fatalf("could not initialize postgres exercise audio store: %v", err)
		}
		exerciseAudioStore = persistentExerciseAudioStore
		persistentExerciseSentenceAudioStore, err := store.NewPostgresExerciseSentenceAudioStore(databaseURL)
		if err != nil {
			log.Fatalf("could not initialize postgres exercise sentence audio store: %v", err)
		}
		exerciseSentenceAudioStore = persistentExerciseSentenceAudioStore
		attemptStore = persistentAttemptStore
		exerciseStore = persistentExerciseStore
		mockExamStore = persistentMockExamStore
		mockTestStore = persistentMockTestStore
		courseStore = persistentCourseStore
		moduleStore = persistentModuleStore
		vocabularyStore = persistentVocabularyStore
		grammarStore = persistentGrammarStore
		generationJobStore = persistentGenerationJobStore
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
	var handler http.Handler
	if useAuth {
		log.Printf("V17 self-serve auth enabled (signup/login/IAP/quota gates)")
		handler = httpapi.NewServerWithAuth(repo, processorInst, uploadProvider, audioURLProvider, audioSignSecret, authDeps)
	} else {
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
