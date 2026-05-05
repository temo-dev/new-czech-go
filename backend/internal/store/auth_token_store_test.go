package store

import (
	"testing"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

func TestMemoryAuthTokenStore_CreateAndLookup(t *testing.T) {
	s := newMemoryAuthTokenStore()

	now := time.Now().UTC()
	tok, err := s.CreateAuthToken(contracts.AuthToken{
		TokenHash: "h_session_1",
		UserID:    "u_1",
		Kind:      contracts.AuthTokenKindSession,
		ExpiresAt: now.Add(30 * 24 * time.Hour),
	})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if tok.CreatedAt.IsZero() {
		t.Error("expected created_at to be set")
	}

	got, ok := s.AuthTokenByHash("h_session_1")
	if !ok {
		t.Fatal("expected lookup by hash to succeed")
	}
	if got.UserID != "u_1" || got.Kind != contracts.AuthTokenKindSession {
		t.Errorf("unexpected token: %+v", got)
	}
}

func TestMemoryAuthTokenStore_ExpiredExcluded(t *testing.T) {
	s := newMemoryAuthTokenStore()

	past := time.Now().Add(-1 * time.Hour)
	_, err := s.CreateAuthToken(contracts.AuthToken{
		TokenHash: "h_expired",
		UserID:    "u_1",
		Kind:      contracts.AuthTokenKindEmailVerify,
		ExpiresAt: past,
	})
	if err != nil {
		t.Fatalf("create: %v", err)
	}

	if _, ok := s.AuthTokenByHash("h_expired"); ok {
		t.Error("expired token must not be returned")
	}
}

func TestMemoryAuthTokenStore_RevokedExcluded(t *testing.T) {
	s := newMemoryAuthTokenStore()

	_, err := s.CreateAuthToken(contracts.AuthToken{
		TokenHash: "h_rev",
		UserID:    "u_1",
		Kind:      contracts.AuthTokenKindSession,
		ExpiresAt: time.Now().Add(24 * time.Hour),
	})
	if err != nil {
		t.Fatalf("create: %v", err)
	}

	if !s.RevokeAuthToken("h_rev") {
		t.Fatal("expected revoke to succeed")
	}

	if _, ok := s.AuthTokenByHash("h_rev"); ok {
		t.Error("revoked token must not be returned by lookup")
	}

	// Idempotent re-revoke returns false (already revoked).
	if s.RevokeAuthToken("h_rev") {
		t.Error("expected re-revoke to be a no-op")
	}
}

func TestMemoryAuthTokenStore_RevokeAllForUser(t *testing.T) {
	s := newMemoryAuthTokenStore()

	expiry := time.Now().Add(24 * time.Hour)
	hashes := []string{"h_a", "h_b", "h_c"}
	for _, h := range hashes {
		if _, err := s.CreateAuthToken(contracts.AuthToken{
			TokenHash: h,
			UserID:    "u_revoke",
			Kind:      contracts.AuthTokenKindSession,
			ExpiresAt: expiry,
		}); err != nil {
			t.Fatalf("create %s: %v", h, err)
		}
	}
	// Token for a different user must NOT be revoked.
	if _, err := s.CreateAuthToken(contracts.AuthToken{
		TokenHash: "h_other",
		UserID:    "u_other",
		Kind:      contracts.AuthTokenKindSession,
		ExpiresAt: expiry,
	}); err != nil {
		t.Fatalf("create other: %v", err)
	}

	n := s.RevokeAllAuthTokensForUser("u_revoke")
	if n != len(hashes) {
		t.Errorf("expected %d revoked, got %d", len(hashes), n)
	}
	for _, h := range hashes {
		if _, ok := s.AuthTokenByHash(h); ok {
			t.Errorf("token %s should be revoked", h)
		}
	}
	if _, ok := s.AuthTokenByHash("h_other"); !ok {
		t.Error("other user's token must remain valid")
	}
}

func TestMemoryAuthTokenStore_RevokeAllByKind(t *testing.T) {
	s := newMemoryAuthTokenStore()

	expiry := time.Now().Add(24 * time.Hour)
	mustCreate(t, s, "h_session", "u_1", contracts.AuthTokenKindSession, expiry)
	mustCreate(t, s, "h_verify1", "u_1", contracts.AuthTokenKindEmailVerify, expiry)
	mustCreate(t, s, "h_verify2", "u_1", contracts.AuthTokenKindEmailVerify, expiry)

	n := s.RevokeAllAuthTokensByKind("u_1", contracts.AuthTokenKindEmailVerify)
	if n != 2 {
		t.Errorf("expected 2 verify tokens revoked, got %d", n)
	}
	if _, ok := s.AuthTokenByHash("h_session"); !ok {
		t.Error("session token must remain valid")
	}
	if _, ok := s.AuthTokenByHash("h_verify1"); ok {
		t.Error("verify token 1 should be revoked")
	}
	if _, ok := s.AuthTokenByHash("h_verify2"); ok {
		t.Error("verify token 2 should be revoked")
	}
}

func TestMemoryAuthTokenStore_CleanupExpired(t *testing.T) {
	s := newMemoryAuthTokenStore()

	now := time.Now().UTC()
	mustCreate(t, s, "h_old1", "u_1", contracts.AuthTokenKindSession, now.Add(-2*time.Hour))
	mustCreate(t, s, "h_old2", "u_1", contracts.AuthTokenKindEmailVerify, now.Add(-1*time.Hour))
	mustCreate(t, s, "h_live", "u_1", contracts.AuthTokenKindSession, now.Add(1*time.Hour))

	n := s.CleanupExpiredAuthTokens(now)
	if n != 2 {
		t.Errorf("expected 2 expired purged, got %d", n)
	}

	// Live token must still be lookable.
	if _, ok := s.AuthTokenByHash("h_live"); !ok {
		t.Error("live token must survive cleanup")
	}
}

func TestMemoryAuthTokenStore_TouchLastUsed(t *testing.T) {
	s := newMemoryAuthTokenStore()

	now := time.Now().UTC()
	mustCreate(t, s, "h_use", "u_1", contracts.AuthTokenKindSession, now.Add(24*time.Hour))

	if !s.TouchAuthTokenLastUsed("h_use", now.Add(time.Minute)) {
		t.Fatal("expected touch to succeed")
	}
	got, ok := s.AuthTokenByHash("h_use")
	if !ok {
		t.Fatal("token gone after touch")
	}
	if got.LastUsedAt == nil || !got.LastUsedAt.Equal(now.Add(time.Minute)) {
		t.Errorf("expected last_used_at to update, got %v", got.LastUsedAt)
	}
}

func TestMemoryAuthTokenStore_DuplicateHash_Rejected(t *testing.T) {
	s := newMemoryAuthTokenStore()

	expiry := time.Now().Add(24 * time.Hour)
	mustCreate(t, s, "h_dup", "u_1", contracts.AuthTokenKindSession, expiry)

	_, err := s.CreateAuthToken(contracts.AuthToken{
		TokenHash: "h_dup",
		UserID:    "u_2",
		Kind:      contracts.AuthTokenKindSession,
		ExpiresAt: expiry,
	})
	if err == nil {
		t.Fatal("expected duplicate token_hash to be rejected (sha256 collision is fatal)")
	}
}

func mustCreate(t *testing.T, s AuthTokenStore, hash, userID, kind string, expiresAt time.Time) {
	t.Helper()
	_, err := s.CreateAuthToken(contracts.AuthToken{
		TokenHash: hash,
		UserID:    userID,
		Kind:      kind,
		ExpiresAt: expiresAt,
	})
	if err != nil {
		t.Fatalf("create %s: %v", hash, err)
	}
}
