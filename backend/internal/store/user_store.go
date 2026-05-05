package store

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// UserStore persists learner accounts. Soft-deleted accounts are excluded
// from every read path so the same email can be re-registered after the
// owner deletes their account.
type UserStore interface {
	// CreateUser inserts a new account. Email is normalized (lowercase,
	// trimmed) into EmailNormalized; conflicting active rows return
	// ErrDuplicateEmail.
	CreateUser(account contracts.UserAccount) (contracts.UserAccount, error)

	// UserAccountByID returns the account if present and not soft-deleted.
	UserAccountByID(id string) (contracts.UserAccount, bool)

	// UserAccountByEmail performs a case-insensitive lookup, ignoring
	// surrounding whitespace.
	UserAccountByEmail(email string) (contracts.UserAccount, bool)

	// UpdateUser applies the mutator to the live row and persists it. The
	// mutator must not change ID, CreatedAt, or DeletedAt — those are
	// preserved by the store regardless of what the mutator does.
	UpdateUser(id string, mutate func(*contracts.UserAccount)) (contracts.UserAccount, bool)

	// SoftDeleteUser sets DeletedAt and frees the email for re-registration.
	SoftDeleteUser(id string) bool

	// MarkUserEmailVerified flips EmailVerifiedAt and lifts the grace cap so
	// downstream rate limits no longer hard-block the learner.
	MarkUserEmailVerified(id string) bool

	// DecrementUserGrace lowers GraceAttemptsLeft by one, clamping at zero,
	// and returns the new value. Used by the verify-on-Nth-attempt gate.
	DecrementUserGrace(id string) (int, bool)
}

// ErrDuplicateEmail is returned when CreateUser is called with an email that
// already exists on an active row.
var ErrDuplicateEmail = errors.New("email already registered")

// graceAfterVerify is the value GraceAttemptsLeft is lifted to once the
// learner clicks the verify-email link. The exact ceiling is unimportant —
// it just has to be larger than any plausible per-day attempt count so the
// grace gate effectively disables itself.
const graceAfterVerify = 1_000_000

// normalizeEmail trims surrounding whitespace and lowercases the address so
// equivalent forms collide on lookup and unique-constraint checks.
func normalizeEmail(email string) string {
	return strings.ToLower(strings.TrimSpace(email))
}

// ── Memory implementation ────────────────────────────────────────────────

type memoryUserStore struct {
	mu    sync.RWMutex
	users map[string]*contracts.UserAccount // keyed by id
}

func newMemoryUserStore() UserStore {
	return &memoryUserStore{users: map[string]*contracts.UserAccount{}}
}

// NewMemoryUserStore returns a fresh in-memory UserStore. Exported for
// dev/test wiring outside this package; production callers should reach
// for NewPostgresUserStoreWithDB instead.
func NewMemoryUserStore() UserStore { return newMemoryUserStore() }

func (s *memoryUserStore) CreateUser(account contracts.UserAccount) (contracts.UserAccount, error) {
	if strings.TrimSpace(account.Email) == "" {
		return contracts.UserAccount{}, errors.New("email required")
	}
	if account.PasswordHash == "" {
		return contracts.UserAccount{}, errors.New("password_hash required")
	}

	now := time.Now().UTC()
	normalized := normalizeEmail(account.Email)

	s.mu.Lock()
	defer s.mu.Unlock()

	for _, existing := range s.users {
		if existing.DeletedAt != nil {
			continue
		}
		if existing.EmailNormalized == normalized {
			return contracts.UserAccount{}, ErrDuplicateEmail
		}
	}

	if account.ID == "" {
		account.ID = newUserID()
	}
	account.EmailNormalized = normalized
	if account.Role == "" {
		account.Role = "learner"
	}
	if account.ProTier == "" {
		account.ProTier = "free"
	}
	if account.Timezone == "" {
		account.Timezone = "Asia/Ho_Chi_Minh"
	}
	if account.GraceAttemptsLeft == 0 {
		account.GraceAttemptsLeft = 3
	}
	account.CreatedAt = now
	account.UpdatedAt = now
	account.DeletedAt = nil

	cp := account
	s.users[account.ID] = &cp
	return account, nil
}

func (s *memoryUserStore) UserAccountByID(id string) (contracts.UserAccount, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	u, ok := s.users[id]
	if !ok || u.DeletedAt != nil {
		return contracts.UserAccount{}, false
	}
	return *u, true
}

func (s *memoryUserStore) UserAccountByEmail(email string) (contracts.UserAccount, bool) {
	normalized := normalizeEmail(email)
	if normalized == "" {
		return contracts.UserAccount{}, false
	}
	s.mu.RLock()
	defer s.mu.RUnlock()
	for _, u := range s.users {
		if u.DeletedAt != nil {
			continue
		}
		if u.EmailNormalized == normalized {
			return *u, true
		}
	}
	return contracts.UserAccount{}, false
}

func (s *memoryUserStore) UpdateUser(id string, mutate func(*contracts.UserAccount)) (contracts.UserAccount, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	u, ok := s.users[id]
	if !ok || u.DeletedAt != nil {
		return contracts.UserAccount{}, false
	}
	immutableID := u.ID
	immutableCreated := u.CreatedAt
	immutableDeleted := u.DeletedAt

	mutate(u)

	u.ID = immutableID
	u.CreatedAt = immutableCreated
	u.DeletedAt = immutableDeleted
	u.UpdatedAt = time.Now().UTC()
	return *u, true
}

func (s *memoryUserStore) SoftDeleteUser(id string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	u, ok := s.users[id]
	if !ok || u.DeletedAt != nil {
		return false
	}
	now := time.Now().UTC()
	u.DeletedAt = &now
	u.UpdatedAt = now
	return true
}

func (s *memoryUserStore) MarkUserEmailVerified(id string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	u, ok := s.users[id]
	if !ok || u.DeletedAt != nil {
		return false
	}
	now := time.Now().UTC()
	u.EmailVerifiedAt = &now
	u.GraceAttemptsLeft = graceAfterVerify
	u.UpdatedAt = now
	return true
}

func (s *memoryUserStore) DecrementUserGrace(id string) (int, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	u, ok := s.users[id]
	if !ok || u.DeletedAt != nil {
		return 0, false
	}
	if u.GraceAttemptsLeft > 0 {
		u.GraceAttemptsLeft--
		u.UpdatedAt = time.Now().UTC()
	}
	return u.GraceAttemptsLeft, true
}

// newUserID returns a 16-hex-char identifier prefixed with "u_". Collisions
// are statistically negligible at the scale this product targets.
func newUserID() string {
	b := make([]byte, 8)
	if _, err := rand.Read(b); err != nil {
		return fmt.Sprintf("u_%d", time.Now().UnixNano())
	}
	return "u_" + hex.EncodeToString(b)
}
