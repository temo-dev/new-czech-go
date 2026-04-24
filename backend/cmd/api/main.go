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
	if databaseURL := os.Getenv("DATABASE_URL"); databaseURL != "" {
		persistentAttemptStore, err := store.NewPostgresAttemptStore(databaseURL)
		if err != nil {
			log.Fatalf("could not initialize postgres attempt store: %v", err)
		}
		persistentExerciseStore, err := store.NewPostgresExerciseStore(databaseURL)
		if err != nil {
			log.Fatalf("could not initialize postgres exercise store: %v", err)
		}
		attemptStore = persistentAttemptStore
		exerciseStore = persistentExerciseStore
		log.Printf("attempt and exercise persistence enabled with Postgres")
	}

	repo := store.NewMemoryStoreWithStores(attemptStore, exerciseStore)
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
		log.Fatalf("could not configure llm feedback provider: %v", err)
	}
	log.Printf("llm feedback provider enabled: %s", processing.ConfiguredLLMFeedbackProvider())
	reviewProvider, err := processing.NewConfiguredLLMReviewProvider()
	if err != nil {
		log.Fatalf("could not configure llm review provider: %v", err)
	}
	uploadProvider, err := httpapi.NewConfiguredUploadTargetProvider(context.Background())
	if err != nil {
		log.Fatalf("could not configure upload target provider: %v", err)
	}
	audioSignSecret := httpapi.AudioSigningSecretFromEnv(log.Printf)
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
