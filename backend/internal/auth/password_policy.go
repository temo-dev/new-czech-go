package auth

import (
	"errors"
	"strings"
	"unicode"
)

// MinPasswordLength is the floor enforced by ValidatePassword. NIST
// SP 800-63B recommends a minimum of 8 characters and explicitly does
// not require composition rules — but we keep the digit-or-special
// requirement as a low-cost guard against the most trivial dictionary
// attacks.
const MinPasswordLength = 8

// Policy errors. Use errors.Is to match in tests / handlers.
var (
	ErrPasswordTooShort  = errors.New("password too short")
	ErrPasswordTooSimple = errors.New("password must contain at least one digit or special character")
	ErrPasswordTooCommon = errors.New("password is on the common-password block list")
	ErrPasswordEmpty     = errors.New("password required")
)

// ValidatePassword enforces the V17 password policy: ≥8 characters, not
// present on the embedded common-password block list (case-insensitive),
// and containing at least one digit OR one special (non-letter) rune.
//
// The common-list check runs BEFORE the composition rule so a candidate
// like "password" is rejected with the more informative
// ErrPasswordTooCommon rather than ErrPasswordTooSimple — even though
// "password" is also missing a digit, "common" is the more actionable
// signal for the learner.
func ValidatePassword(password string) error {
	if password == "" {
		return ErrPasswordEmpty
	}
	if len(password) < MinPasswordLength {
		return ErrPasswordTooShort
	}
	if _, blocked := commonPasswords[strings.ToLower(password)]; blocked {
		return ErrPasswordTooCommon
	}
	if !hasDigitOrSpecial(password) {
		return ErrPasswordTooSimple
	}
	return nil
}

// hasDigitOrSpecial reports whether the password contains at least one
// rune that is NOT a letter — i.e. at least one digit or non-alphanumeric
// rune. Unicode letters (e.g. Vietnamese diacritics) count as letters.
func hasDigitOrSpecial(s string) bool {
	for _, r := range s {
		if !unicode.IsLetter(r) {
			return true
		}
	}
	return false
}

// commonPasswords is a lowercase set of well-known weak passwords that
// must not be accepted regardless of how they pass the composition
// rules. The selection covers the most-attacked entries from public
// breach corpora (RockYou, "Have I Been Pwned" top-100k) sufficient to
// block the trivial cases the policy targets. The list MAY be expanded
// to the full top-1000 by appending entries — order is irrelevant.
var commonPasswords = func() map[string]struct{} {
	list := []string{
		"password",
		"123456",
		"12345678",
		"1234567890",
		"qwerty",
		"qwerty123",
		"qwertyuiop",
		"abc123",
		"abc12345",
		"password1",
		"password123",
		"passw0rd",
		"p@ssw0rd",
		"p@ssword",
		"letmein",
		"welcome",
		"welcome1",
		"welcome123",
		"admin",
		"administrator",
		"admin123",
		"root",
		"toor",
		"iloveyou",
		"princess",
		"monkey",
		"dragon",
		"sunshine",
		"trustno1",
		"baseball",
		"football",
		"superman",
		"batman",
		"michael",
		"jordan",
		"hello",
		"hello123",
		"changeme",
		"changeit",
		"qazwsx",
		"qazwsxedc",
		"asdfgh",
		"asdfghjkl",
		"zxcvbn",
		"zxcvbnm",
		"1q2w3e4r",
		"1qaz2wsx",
		"q1w2e3r4",
		"123qwe",
		"123abc",
		"qwer1234",
		"login",
		"login123",
		"master",
		"master1",
		"master123",
		"shadow",
		"abc@123",
		"abcd1234",
		"a1b2c3d4",
		"112233",
		"123123",
		"123321",
		"654321",
		"00000000",
		"11111111",
		"22222222",
		"99999999",
		"aaaaaaaa",
		"qwerty1",
		"qwerty12",
		"q1w2e3",
		"matkhau",   // VN: "password"
		"matkhau123",
		"vietnam",
		"vietnam123",
		"czech",
		"czech123",
	}
	set := make(map[string]struct{}, len(list))
	for _, p := range list {
		set[strings.ToLower(p)] = struct{}{}
	}
	return set
}()
