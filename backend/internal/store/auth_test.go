package store

import (
	"testing"
)

func TestLoginWithEnvCredentials(t *testing.T) {
	t.Setenv("ADMIN_EMAIL", "boss@company.com")
	t.Setenv("ADMIN_PASSWORD", "supersecret")

	s := NewMemoryStore()

	token, user, ok := s.Login("boss@company.com", "supersecret")
	if !ok {
		t.Fatal("login should succeed with env credentials")
	}
	if user.Role != "admin" {
		t.Errorf("expected role=admin, got %s", user.Role)
	}
	if token == "dev-admin-token" {
		t.Error("token should not be the static dev-admin-token")
	}
	if len(token) < 32 {
		t.Errorf("expected a random token (len≥32), got %q (len=%d)", token, len(token))
	}
}

func TestLoginWrongPasswordFails(t *testing.T) {
	t.Setenv("ADMIN_EMAIL", "admin@example.com")
	t.Setenv("ADMIN_PASSWORD", "correct123")

	s := NewMemoryStore()

	_, _, ok := s.Login("admin@example.com", "wrongpass")
	if ok {
		t.Fatal("login should fail with wrong password")
	}
}

func TestLoginIssuedTokenIsValidInUserByToken(t *testing.T) {
	t.Setenv("ADMIN_EMAIL", "admin@example.com")
	t.Setenv("ADMIN_PASSWORD", "demo123")

	s := NewMemoryStore()

	token, _, ok := s.Login("admin@example.com", "demo123")
	if !ok {
		t.Fatal("login should succeed")
	}

	user, found := s.UserByToken(token)
	if !found {
		t.Fatal("issued token should be valid in UserByToken")
	}
	if user.Role != "admin" {
		t.Errorf("expected admin role, got %s", user.Role)
	}
}

func TestDevAdminTokenRemainsValidForBackwardCompat(t *testing.T) {
	s := NewMemoryStore()

	user, ok := s.UserByToken("dev-admin-token")
	if !ok {
		t.Fatal("dev-admin-token must remain valid for backward compat")
	}
	if user.Role != "admin" {
		t.Errorf("expected admin role, got %s", user.Role)
	}
}

func TestUnknownTokenIsRejected(t *testing.T) {
	s := NewMemoryStore()

	_, ok := s.UserByToken("not-a-real-token")
	if ok {
		t.Fatal("unknown token should be rejected")
	}
}
