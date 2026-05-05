package auth

import (
	"encoding/hex"
	"errors"
	"strings"
	"testing"
)

// ── bcrypt ───────────────────────────────────────────────────────────────

func TestHashPassword_RoundTrip(t *testing.T) {
	hashed, err := HashPassword("Strong1Password!")
	if err != nil {
		t.Fatalf("hash: %v", err)
	}
	if !strings.HasPrefix(hashed, "$2") {
		t.Errorf("expected bcrypt $2 prefix, got %q", hashed[:4])
	}
	if !VerifyPassword(hashed, "Strong1Password!") {
		t.Error("expected verify to succeed for matching password")
	}
}

func TestVerifyPassword_RejectsWrong(t *testing.T) {
	hashed, _ := HashPassword("Strong1Password!")
	if VerifyPassword(hashed, "wrong-password") {
		t.Error("expected verify to fail for non-matching password")
	}
}

func TestHashPassword_CostMatchesPolicy(t *testing.T) {
	hashed, _ := HashPassword("Strong1Password!")
	// bcrypt cost is encoded as decimal between the second and third $.
	// Format: $2a$12$<22-char-salt><31-char-hash>
	parts := strings.Split(hashed, "$")
	if len(parts) < 4 {
		t.Fatalf("unexpected bcrypt format: %q", hashed)
	}
	if parts[2] != "12" {
		t.Errorf("expected bcrypt cost=12, got %q", parts[2])
	}
}

func TestHashPassword_TruncatesAt72Bytes(t *testing.T) {
	// bcrypt silently ignores bytes past index 72; HashPassword should not
	// surface that as an error.
	long := strings.Repeat("a", 200)
	if _, err := HashPassword(long); err != nil {
		t.Errorf("expected long password to hash without error, got %v", err)
	}
}

// ── tokens ───────────────────────────────────────────────────────────────

func TestNewRawToken_LengthAndCharset(t *testing.T) {
	tok, err := NewRawToken()
	if err != nil {
		t.Fatalf("new token: %v", err)
	}
	// 32 random bytes encoded as base64-url (no padding) -> 43 chars.
	if len(tok) != 43 {
		t.Errorf("expected 43-char token, got %d (%q)", len(tok), tok)
	}
	for _, r := range tok {
		ok := (r >= 'A' && r <= 'Z') ||
			(r >= 'a' && r <= 'z') ||
			(r >= '0' && r <= '9') ||
			r == '-' || r == '_'
		if !ok {
			t.Errorf("non-base64url char %q in token %q", r, tok)
		}
	}
}

func TestNewRawToken_Unique(t *testing.T) {
	seen := map[string]bool{}
	for i := 0; i < 100; i++ {
		tok, err := NewRawToken()
		if err != nil {
			t.Fatalf("iter %d: %v", i, err)
		}
		if seen[tok] {
			t.Fatalf("collision at iter %d: %q", i, tok)
		}
		seen[tok] = true
	}
}

func TestHashToken_DeterministicSHA256(t *testing.T) {
	const raw = "deterministic-test-input"
	a := HashToken(raw)
	b := HashToken(raw)
	if a != b {
		t.Errorf("expected stable hash, got %q vs %q", a, b)
	}
	if len(a) != 64 {
		t.Errorf("expected 64-char hex (sha256), got %d", len(a))
	}
	if _, err := hex.DecodeString(a); err != nil {
		t.Errorf("expected hex output, got %q (%v)", a, err)
	}
}

func TestHashToken_DifferentInputDifferentHash(t *testing.T) {
	if HashToken("a") == HashToken("b") {
		t.Fatal("hashes should differ for different inputs")
	}
}

// ── password policy ──────────────────────────────────────────────────────

func TestValidatePassword_AcceptsStrong(t *testing.T) {
	for _, candidate := range []string{
		"Strong1Password!",
		"abcdef1g",      // 8 chars, has digit
		"abcdefgh!",     // 8 chars, has special
		"ănăvi3tn4m",    // unicode + digits is fine
	} {
		if err := ValidatePassword(candidate); err != nil {
			t.Errorf("expected %q to be accepted, got %v", candidate, err)
		}
	}
}

func TestValidatePassword_RejectsTooShort(t *testing.T) {
	err := ValidatePassword("Ab1!")
	if !errors.Is(err, ErrPasswordTooShort) {
		t.Errorf("expected ErrPasswordTooShort, got %v", err)
	}
}

func TestValidatePassword_RejectsNoDigitOrSpecial(t *testing.T) {
	err := ValidatePassword("abcdefghij")
	if !errors.Is(err, ErrPasswordTooSimple) {
		t.Errorf("expected ErrPasswordTooSimple, got %v", err)
	}
}

func TestValidatePassword_RejectsCommonTopList(t *testing.T) {
	for _, weak := range []string{
		"password",
		"12345678",
		"qwerty123",
		"abc12345",
		"password1",
	} {
		err := ValidatePassword(weak)
		if !errors.Is(err, ErrPasswordTooCommon) {
			t.Errorf("expected %q to be rejected as common, got %v", weak, err)
		}
	}
}

func TestValidatePassword_CommonListIsCaseInsensitive(t *testing.T) {
	if err := ValidatePassword("PASSWORD"); !errors.Is(err, ErrPasswordTooCommon) {
		t.Errorf("expected uppercase common password to be rejected, got %v", err)
	}
}

func TestValidatePassword_RejectsEmpty(t *testing.T) {
	if err := ValidatePassword(""); err == nil {
		t.Error("expected empty password to be rejected")
	}
}
