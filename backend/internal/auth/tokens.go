package auth

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
)

// rawTokenBytes controls the entropy of issued bearer tokens. 32 bytes
// (256 bits) is the standard recommendation for session tokens; encoded
// as base64-url without padding the result is 43 characters.
const rawTokenBytes = 32

// NewRawToken returns a fresh, cryptographically random bearer token in
// base64-url (no padding) form. Callers MUST hash the value with
// HashToken before persisting it; the raw form is only ever delivered to
// the client.
func NewRawToken() (string, error) {
	b := make([]byte, rawTokenBytes)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(b), nil
}

// HashToken returns the lowercase-hex sha256 of the supplied raw token,
// which is the form the AuthTokenStore persists. SHA-256 (not bcrypt) is
// the right choice here because the token itself already has 256 bits of
// entropy — a slow KDF would be wasted CPU.
func HashToken(raw string) string {
	sum := sha256.Sum256([]byte(raw))
	return hex.EncodeToString(sum[:])
}
