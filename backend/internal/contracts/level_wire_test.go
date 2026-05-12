package contracts

import (
	"encoding/json"
	"strings"
	"testing"
)

// S6 — the wire used to ship `"next_level": ""` for learners at the top
// of the ladder. The empty string carried two meanings (no next OR the
// server forgot to set it), so the client had to special-case it. Make
// the field nullable on the wire: omit when empty so consumers see one
// canonical "no next" representation.

func TestLevelProgressResponse_OmitsEmptyNextLevel(t *testing.T) {
	resp := LevelProgressResponse{
		UserID:       "u_top",
		CurrentLevel: "b1",
		NextLevel:    "",
	}
	b, err := json.Marshal(resp)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}
	got := string(b)
	if strings.Contains(got, `"next_level"`) {
		t.Fatalf("expected next_level to be omitted when empty; got %s", got)
	}
}

func TestLevelProgressResponse_KeepsNonEmptyNextLevel(t *testing.T) {
	resp := LevelProgressResponse{
		UserID:       "u_mid",
		CurrentLevel: "a2",
		NextLevel:    "b1",
	}
	b, err := json.Marshal(resp)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}
	got := string(b)
	if !strings.Contains(got, `"next_level":"b1"`) {
		t.Fatalf("expected next_level=b1 in wire; got %s", got)
	}
}
