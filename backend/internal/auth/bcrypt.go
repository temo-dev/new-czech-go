// Package auth holds the authentication primitives — password hashing,
// bearer-token issuance, and password policy enforcement — used by the
// V17 self-serve learner flow.
package auth

import "golang.org/x/crypto/bcrypt"

// BcryptCost is the bcrypt work factor for learner passwords. The admin
// auth flow uses cost 10 (the default V6 reuses); learners get 12 because
// the lifecycle is longer and the user surface is wider, so an attacker
// who exfiltrates the dump gets less leverage per CPU-second.
//
// At cost 12 a hash takes ~150-250ms on a modern x86 server core. The
// signup endpoint hashes once per call; login hashes once per call.
const BcryptCost = 12

// bcryptMaxBytes is the algorithm's hard limit. bcrypt silently ignores
// bytes past this index, but if we send a 73+ byte input through
// `bcrypt.GenerateFromPassword` it returns ErrPasswordTooLong. Pre-trim
// here so callers don't have to special-case it.
const bcryptMaxBytes = 72

// HashPassword returns a bcrypt hash of the supplied password using the
// learner-tier cost factor. Inputs longer than 72 bytes are silently
// truncated — that matches bcrypt's own behavior and keeps the policy
// transparent ("any password ≥8 chars is accepted").
func HashPassword(password string) (string, error) {
	input := []byte(password)
	if len(input) > bcryptMaxBytes {
		input = input[:bcryptMaxBytes]
	}
	out, err := bcrypt.GenerateFromPassword(input, BcryptCost)
	if err != nil {
		return "", err
	}
	return string(out), nil
}

// VerifyPassword reports whether the supplied password matches the stored
// bcrypt hash. The same 72-byte truncation applies; comparing against a
// truncated input matches the truncation that happened at hash time.
func VerifyPassword(hashed, password string) bool {
	input := []byte(password)
	if len(input) > bcryptMaxBytes {
		input = input[:bcryptMaxBytes]
	}
	return bcrypt.CompareHashAndPassword([]byte(hashed), input) == nil
}
