package main

import (
	"log"
	"net/http"
	"os"

	"github.com/danieldev/czech-go-system/backend/internal/httpapi"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

func main() {
	addr := os.Getenv("API_ADDR")
	if addr == "" {
		addr = ":8080"
	}

	repo := store.NewMemoryStore()
	handler := httpapi.NewServer(repo)

	log.Printf("backend listening on %s", addr)
	if err := http.ListenAndServe(addr, handler); err != nil {
		log.Fatal(err)
	}
}
