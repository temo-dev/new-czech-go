package main

import (
	"context"
	"log"
	"net/http"
	"os"

	"github.com/danieldev/czech-go-system/backend/internal/httpapi"
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
	var skillStore store.SkillStore
	var vocabularyStore store.VocabularyStore
	var grammarStore store.GrammarStore
	var generationJobStore store.GenerationJobStore
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
		persistentSkillStore, err := store.NewPostgresSkillStore(databaseURL)
		if err != nil {
			log.Fatalf("could not initialize postgres skill store: %v", err)
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
		attemptStore = persistentAttemptStore
		exerciseStore = persistentExerciseStore
		mockExamStore = persistentMockExamStore
		mockTestStore = persistentMockTestStore
		courseStore = persistentCourseStore
		moduleStore = persistentModuleStore
		skillStore = persistentSkillStore
		vocabularyStore = persistentVocabularyStore
		grammarStore = persistentGrammarStore
		generationJobStore = persistentGenerationJobStore
		log.Printf("full Postgres persistence enabled (attempts, exercises, mock exams/tests, courses, modules, skills, vocabulary, grammar, generation_jobs)")
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
		repo.SetSkillStore(skillStore)
	}
	if vocabularyStore != nil {
		repo.SetVocabularyStore(vocabularyStore)
		repo.SetGrammarStore(grammarStore)
		repo.SetGenerationJobStore(generationJobStore)
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
	handler := httpapi.NewServerWithAudio(repo, processing.NewProcessor(repo, transcriber, ttsProvider, llmProvider, reviewProvider), uploadProvider, audioURLProvider, audioSignSecret)

	log.Printf("backend listening on %s", addr)
	if err := http.ListenAndServe(addr, handler); err != nil {
		log.Fatal(err)
	}
}
