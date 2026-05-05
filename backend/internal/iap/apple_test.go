package iap

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestHTTPAppleVerifier_HappyPathProduction(t *testing.T) {
	wantBundle := "eu.hadoo.czechgo"
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]any{
			"status":    AppleStatusOK,
			"bundle_id": wantBundle,
			"latest_receipt_info": []map[string]string{
				{
					"transaction_id":          "1",
					"original_transaction_id": "1",
					"product_id":              "eu.hadoo.czechgo.pro.monthly",
					"purchase_date_ms":        "1714896000000",
					"expires_date_ms":         "1717488000000",
				},
			},
		})
	}))
	defer srv.Close()

	v := &HTTPAppleVerifier{
		HTTPClient: &http.Client{Timeout: 2 * time.Second},
		BundleID:   wantBundle,
		ProdURL:    srv.URL,
		SandboxURL: srv.URL,
	}
	resp, err := v.VerifyReceipt(context.Background(), "any-receipt")
	if err != nil {
		t.Fatalf("verify: %v", err)
	}
	if resp.Status != AppleStatusOK {
		t.Errorf("status: %d", resp.Status)
	}
	r, ok := resp.PickLatestForProduct("eu.hadoo.czechgo.pro.monthly")
	if !ok {
		t.Fatal("expected to pick the receipt")
	}
	if r.TransactionID != "1" {
		t.Errorf("txn id: %q", r.TransactionID)
	}
}

func TestHTTPAppleVerifier_FallsBackToSandbox(t *testing.T) {
	prod := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]any{
			"status": AppleStatusSandboxOnProd,
		})
	}))
	defer prod.Close()
	sbx := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]any{
			"status":    AppleStatusOK,
			"bundle_id": "eu.hadoo.czechgo",
		})
	}))
	defer sbx.Close()

	v := &HTTPAppleVerifier{
		HTTPClient: &http.Client{Timeout: 2 * time.Second},
		BundleID:   "eu.hadoo.czechgo",
		ProdURL:    prod.URL,
		SandboxURL: sbx.URL,
	}
	resp, err := v.VerifyReceipt(context.Background(), "any")
	if err != nil {
		t.Fatalf("verify: %v", err)
	}
	if resp.Status != AppleStatusOK {
		t.Errorf("expected OK from sandbox fallback, got %d", resp.Status)
	}
}

func TestHTTPAppleVerifier_RejectsBundleMismatch(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]any{
			"status":    AppleStatusOK,
			"bundle_id": "eu.example.other",
		})
	}))
	defer srv.Close()
	v := &HTTPAppleVerifier{
		HTTPClient: &http.Client{Timeout: 2 * time.Second},
		BundleID:   "eu.hadoo.czechgo",
		ProdURL:    srv.URL,
		SandboxURL: srv.URL,
	}
	_, err := v.VerifyReceipt(context.Background(), "x")
	if err == nil || !strings.Contains(err.Error(), "bundle id mismatch") {
		t.Errorf("expected bundle mismatch error, got %v", err)
	}
}

func TestDecodeNotificationPayload_HappyPath(t *testing.T) {
	body := []byte(`{
		"notificationUUID": "uuid-1",
		"notificationType": "DID_RENEW",
		"data": {
			"transactionInfo": {
				"transactionId": "txn-2",
				"originalTransactionId": "orig-1",
				"productId": "eu.hadoo.czechgo.pro.monthly",
				"expiresDate": 1717488000000
			}
		}
	}`)
	notif, err := DecodeNotificationPayload(body)
	if err != nil {
		t.Fatalf("decode: %v", err)
	}
	if notif.UUID != "uuid-1" || notif.Type != "DID_RENEW" || notif.TransactionID != "txn-2" {
		t.Errorf("unexpected: %+v", notif)
	}
	if notif.ExpiresAt.IsZero() {
		t.Error("expected expires parsed")
	}
}

func TestDecodeNotificationPayload_RejectsMissingUUID(t *testing.T) {
	if _, err := DecodeNotificationPayload([]byte(`{"notificationType":"X"}`)); err == nil {
		t.Error("expected error for missing uuid")
	}
}

func TestPickLatestForProduct_PicksFreshest(t *testing.T) {
	resp := &VerifyReceiptResponse{
		Latest: []Receipt{
			{TransactionID: "old", ProductID: "p", ExpiresDateMS: "1000000"},
			{TransactionID: "new", ProductID: "p", ExpiresDateMS: "9999999999"},
			{TransactionID: "other", ProductID: "q", ExpiresDateMS: "9999999999"},
		},
	}
	r, ok := resp.PickLatestForProduct("p")
	if !ok || r.TransactionID != "new" {
		t.Errorf("expected freshest 'new', got %q", r.TransactionID)
	}
}
