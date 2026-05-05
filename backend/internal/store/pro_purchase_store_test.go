package store

import (
	"errors"
	"testing"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

func TestMemoryProPurchaseStore_CreateAndLookup(t *testing.T) {
	s := newMemoryProPurchaseStore()

	now := time.Now().UTC()
	p, err := s.CreateProPurchase(contracts.ProPurchase{
		UserID:                     "u_1",
		AppleTransactionID:         "1000000123",
		AppleOriginalTransactionID: "1000000100",
		ProductID:                  "eu.hadoo.czechgo.pro.monthly",
		PurchasedAt:                now,
		ExpiresAt:                  now.Add(30 * 24 * time.Hour),
		ReceiptPayload:             []byte(`{"raw":"..."}`),
	})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if p.ID == "" {
		t.Error("expected generated id")
	}
	if !p.IsActive {
		t.Error("expected new purchase to be active by default")
	}

	got, ok := s.ActiveProPurchaseByUser("u_1")
	if !ok {
		t.Fatal("expected active purchase lookup to succeed")
	}
	if got.AppleTransactionID != "1000000123" {
		t.Errorf("unexpected purchase: %+v", got)
	}
}

func TestMemoryProPurchaseStore_DuplicateAppleTxn_Rejected(t *testing.T) {
	s := newMemoryProPurchaseStore()

	now := time.Now().UTC()
	base := contracts.ProPurchase{
		UserID:                     "u_1",
		AppleTransactionID:         "1000000123",
		AppleOriginalTransactionID: "1000000100",
		ProductID:                  "eu.hadoo.czechgo.pro.monthly",
		PurchasedAt:                now,
		ExpiresAt:                  now.Add(30 * 24 * time.Hour),
		ReceiptPayload:             []byte(`{}`),
	}
	if _, err := s.CreateProPurchase(base); err != nil {
		t.Fatalf("first: %v", err)
	}
	_, err := s.CreateProPurchase(base)
	if !errors.Is(err, ErrDuplicateAppleTxn) {
		t.Fatalf("expected ErrDuplicateAppleTxn, got %v", err)
	}
}

func TestMemoryProPurchaseStore_MarkInactive(t *testing.T) {
	s := newMemoryProPurchaseStore()

	now := time.Now().UTC()
	p, _ := s.CreateProPurchase(contracts.ProPurchase{
		UserID:                     "u_1",
		AppleTransactionID:         "txn_1",
		AppleOriginalTransactionID: "orig_1",
		ProductID:                  "eu.hadoo.czechgo.pro.monthly",
		PurchasedAt:                now,
		ExpiresAt:                  now.Add(30 * 24 * time.Hour),
		ReceiptPayload:             []byte(`{}`),
	})

	if !s.MarkProPurchaseInactive(p.AppleTransactionID) {
		t.Fatal("expected mark inactive to succeed")
	}

	if _, ok := s.ActiveProPurchaseByUser("u_1"); ok {
		t.Error("inactive purchase must not surface as active")
	}

	// Idempotent re-call returns false.
	if s.MarkProPurchaseInactive(p.AppleTransactionID) {
		t.Error("re-mark inactive should report no-op")
	}
}

func TestMemoryProPurchaseStore_LatestActiveWins(t *testing.T) {
	// Apple sends one purchase per renewal — the lookup should return the
	// one with the latest ExpiresAt so the user sees the most distant
	// expiry on Profile.
	s := newMemoryProPurchaseStore()

	now := time.Now().UTC()
	older := contracts.ProPurchase{
		UserID:                     "u_1",
		AppleTransactionID:         "older",
		AppleOriginalTransactionID: "orig",
		ProductID:                  "eu.hadoo.czechgo.pro.monthly",
		PurchasedAt:                now.Add(-60 * 24 * time.Hour),
		ExpiresAt:                  now.Add(-30 * 24 * time.Hour), // already expired
		ReceiptPayload:             []byte(`{}`),
	}
	newer := contracts.ProPurchase{
		UserID:                     "u_1",
		AppleTransactionID:         "newer",
		AppleOriginalTransactionID: "orig",
		ProductID:                  "eu.hadoo.czechgo.pro.monthly",
		PurchasedAt:                now,
		ExpiresAt:                  now.Add(30 * 24 * time.Hour),
		ReceiptPayload:             []byte(`{}`),
	}
	if _, err := s.CreateProPurchase(older); err != nil {
		t.Fatalf("older: %v", err)
	}
	if _, err := s.CreateProPurchase(newer); err != nil {
		t.Fatalf("newer: %v", err)
	}

	got, ok := s.ActiveProPurchaseByUser("u_1")
	if !ok {
		t.Fatal("expected active lookup to succeed")
	}
	if got.AppleTransactionID != "newer" {
		t.Errorf("expected newer purchase to win, got %s", got.AppleTransactionID)
	}
}

func TestMemoryProPurchaseStore_NoActive_ReturnsFalse(t *testing.T) {
	s := newMemoryProPurchaseStore()
	if _, ok := s.ActiveProPurchaseByUser("u_unknown"); ok {
		t.Error("expected no active purchase for unknown user")
	}
}
