package store

import (
	"strings"
	"testing"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

func TestMemoryUserStore_CreateAndGetByID(t *testing.T) {
	s := newMemoryUserStore()

	u, err := s.CreateUser(contracts.UserAccount{
		Email:        "Bao@Example.COM",
		PasswordHash: "$2a$12$abc",
		DisplayName:  "Bao",
	})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if u.ID == "" {
		t.Fatal("expected generated id")
	}
	if u.EmailNormalized != "bao@example.com" {
		t.Errorf("expected email_normalized lowercased, got %q", u.EmailNormalized)
	}
	if u.Role != "learner" {
		t.Errorf("expected default role=learner, got %q", u.Role)
	}
	if u.ProTier != "free" {
		t.Errorf("expected default pro_tier=free, got %q", u.ProTier)
	}
	if u.GraceAttemptsLeft != 3 {
		t.Errorf("expected grace=3, got %d", u.GraceAttemptsLeft)
	}
	if u.Timezone != "Asia/Ho_Chi_Minh" {
		t.Errorf("expected default tz=Asia/Ho_Chi_Minh, got %q", u.Timezone)
	}
	if u.CreatedAt.IsZero() || u.UpdatedAt.IsZero() {
		t.Error("expected created/updated timestamps to be set")
	}

	got, ok := s.UserAccountByID(u.ID)
	if !ok {
		t.Fatal("expected user findable by id")
	}
	if got.Email != "Bao@Example.COM" {
		t.Errorf("expected original email preserved, got %q", got.Email)
	}
}

func TestMemoryUserStore_GetByEmail_CaseInsensitive(t *testing.T) {
	s := newMemoryUserStore()

	_, err := s.CreateUser(contracts.UserAccount{
		Email:        "Anh@Example.com",
		PasswordHash: "$2a$12$abc",
	})
	if err != nil {
		t.Fatalf("create: %v", err)
	}

	for _, q := range []string{"anh@example.com", "ANH@EXAMPLE.COM", "  Anh@Example.com  "} {
		got, ok := s.UserAccountByEmail(q)
		if !ok {
			t.Errorf("expected lookup to succeed for %q", q)
			continue
		}
		if got.EmailNormalized != "anh@example.com" {
			t.Errorf("for %q expected normalized email, got %q", q, got.EmailNormalized)
		}
	}
}

func TestMemoryUserStore_DuplicateEmail_Rejected(t *testing.T) {
	s := newMemoryUserStore()

	if _, err := s.CreateUser(contracts.UserAccount{Email: "x@y.com", PasswordHash: "h"}); err != nil {
		t.Fatalf("first create: %v", err)
	}
	_, err := s.CreateUser(contracts.UserAccount{Email: "X@Y.COM", PasswordHash: "h"})
	if err == nil {
		t.Fatal("expected duplicate email to fail")
	}
	if !strings.Contains(err.Error(), "email") {
		t.Errorf("expected error mentioning email, got %v", err)
	}
}

func TestMemoryUserStore_SoftDelete_HidesFromLookup(t *testing.T) {
	s := newMemoryUserStore()

	u, _ := s.CreateUser(contracts.UserAccount{Email: "del@y.com", PasswordHash: "h"})

	if !s.SoftDeleteUser(u.ID) {
		t.Fatal("expected soft delete to succeed")
	}

	if _, ok := s.UserAccountByID(u.ID); ok {
		t.Error("soft-deleted user should not be findable by id")
	}
	if _, ok := s.UserAccountByEmail("del@y.com"); ok {
		t.Error("soft-deleted user should not be findable by email")
	}

	// Soft-delete frees the email for re-registration.
	if _, err := s.CreateUser(contracts.UserAccount{Email: "del@y.com", PasswordHash: "h"}); err != nil {
		t.Errorf("expected re-registration with same email after soft delete to succeed, got %v", err)
	}
}

func TestMemoryUserStore_Update_PreservesImmutableFields(t *testing.T) {
	s := newMemoryUserStore()

	u, _ := s.CreateUser(contracts.UserAccount{Email: "u@y.com", PasswordHash: "h", DisplayName: "Old"})
	originalCreated := u.CreatedAt

	time.Sleep(2 * time.Millisecond)

	updated, ok := s.UpdateUser(u.ID, func(account *contracts.UserAccount) {
		account.DisplayName = "New"
		account.OnboardingGoal = "a2_pobyt"
	})
	if !ok {
		t.Fatal("expected update to succeed")
	}
	if updated.DisplayName != "New" {
		t.Errorf("expected name updated, got %q", updated.DisplayName)
	}
	if updated.OnboardingGoal != "a2_pobyt" {
		t.Errorf("expected goal set, got %q", updated.OnboardingGoal)
	}
	if updated.CreatedAt != originalCreated {
		t.Error("created_at should not change on update")
	}
	if !updated.UpdatedAt.After(originalCreated) {
		t.Error("updated_at should advance")
	}
}

func TestMemoryUserStore_MarkVerified_RaisesGrace(t *testing.T) {
	s := newMemoryUserStore()

	u, _ := s.CreateUser(contracts.UserAccount{Email: "v@y.com", PasswordHash: "h"})
	if u.EmailVerifiedAt != nil {
		t.Fatal("expected freshly created user to be unverified")
	}

	if !s.MarkUserEmailVerified(u.ID) {
		t.Fatal("expected mark verified to succeed")
	}
	got, _ := s.UserAccountByID(u.ID)
	if got.EmailVerifiedAt == nil {
		t.Error("expected verified_at to be set")
	}
	if got.GraceAttemptsLeft <= 3 {
		t.Errorf("expected grace_attempts_left to be raised after verify, got %d", got.GraceAttemptsLeft)
	}
}

func TestMemoryUserStore_DecrementGrace(t *testing.T) {
	s := newMemoryUserStore()

	u, _ := s.CreateUser(contracts.UserAccount{Email: "g@y.com", PasswordHash: "h"})

	for i := 3; i > 0; i-- {
		left, ok := s.DecrementUserGrace(u.ID)
		if !ok {
			t.Fatalf("decrement %d failed", i)
		}
		if left != i-1 {
			t.Errorf("after decrement expected %d, got %d", i-1, left)
		}
	}

	// Cannot go below zero.
	left, ok := s.DecrementUserGrace(u.ID)
	if !ok {
		t.Fatal("decrement should still be callable at floor")
	}
	if left != 0 {
		t.Errorf("expected grace floor at 0, got %d", left)
	}
}

func TestMemoryUserStore_UpsertByAppleSub_NewUser(t *testing.T) {
	s := newMemoryUserStore()

	u, err := s.UpsertByAppleSub("apple_sub_001", "anh@privaterelay.appleid.com", "Anh Nguyễn")
	if err != nil {
		t.Fatalf("upsert: %v", err)
	}
	if u.ID == "" {
		t.Fatal("expected generated id")
	}
	if u.AppleSub != "apple_sub_001" {
		t.Errorf("expected apple_sub stored, got %q", u.AppleSub)
	}
	if u.EmailNormalized != "anh@privaterelay.appleid.com" {
		t.Errorf("expected email_normalized lowercased, got %q", u.EmailNormalized)
	}
	if u.EmailVerifiedAt == nil {
		t.Error("expected email_verified_at to be set (Apple has verified)")
	}
	if u.GraceAttemptsLeft <= 3 {
		t.Errorf("expected grace lifted past default after Apple verify, got %d", u.GraceAttemptsLeft)
	}
	if u.Role != "learner" {
		t.Errorf("expected default role=learner, got %q", u.Role)
	}
	if u.ProTier != "free" {
		t.Errorf("expected default pro_tier=free, got %q", u.ProTier)
	}
	if u.PasswordHash == "" {
		t.Error("expected placeholder password_hash so legacy guard accepts the row")
	}
	if u.DisplayName != "Anh Nguyễn" {
		t.Errorf("expected display name preserved, got %q", u.DisplayName)
	}

	// Lookup by id confirms the row was persisted.
	got, ok := s.UserAccountByID(u.ID)
	if !ok {
		t.Fatal("expected upserted user findable by id")
	}
	if got.AppleSub != "apple_sub_001" {
		t.Errorf("expected apple_sub round-trip, got %q", got.AppleSub)
	}
}

func TestMemoryUserStore_UpsertByAppleSub_Idempotent(t *testing.T) {
	s := newMemoryUserStore()

	first, err := s.UpsertByAppleSub("apple_sub_002", "bao@example.com", "Bảo")
	if err != nil {
		t.Fatalf("first upsert: %v", err)
	}

	// Subsequent calls — Apple only returns email + name on the very first
	// sign-in, so the handler may pass empty strings on later calls. The
	// existing row must be returned untouched.
	second, err := s.UpsertByAppleSub("apple_sub_002", "", "")
	if err != nil {
		t.Fatalf("second upsert: %v", err)
	}
	if second.ID != first.ID {
		t.Errorf("expected same id on replay, got %q vs %q", second.ID, first.ID)
	}
	if second.Email != "bao@example.com" {
		t.Errorf("expected original email preserved on replay, got %q", second.Email)
	}
	if second.DisplayName != "Bảo" {
		t.Errorf("expected original display name preserved on replay, got %q", second.DisplayName)
	}
}

func TestMemoryUserStore_UpsertByAppleSub_EmptySubRejected(t *testing.T) {
	s := newMemoryUserStore()
	if _, err := s.UpsertByAppleSub("  ", "x@y.com", "X"); err == nil {
		t.Fatal("expected empty/whitespace sub to be rejected")
	}
}

func TestMemoryUserStore_UnknownID_ReturnsFalse(t *testing.T) {
	s := newMemoryUserStore()

	if _, ok := s.UserAccountByID("nope"); ok {
		t.Error("unknown id should not match")
	}
	if _, ok := s.UpdateUser("nope", func(*contracts.UserAccount) {}); ok {
		t.Error("update on unknown id should report not found")
	}
	if s.SoftDeleteUser("nope") {
		t.Error("soft delete on unknown id should report not found")
	}
	if s.MarkUserEmailVerified("nope") {
		t.Error("mark verified on unknown id should report not found")
	}
	if _, ok := s.DecrementUserGrace("nope"); ok {
		t.Error("decrement grace on unknown id should report not found")
	}
}
