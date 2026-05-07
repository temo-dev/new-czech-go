package httpapi

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

// V22 CMS Catch-Up — Phase D2.
// App-layer guard "1 published promotion exam per target_level" applied
// in POST + PATCH /v1/admin/mock-tests handlers.

func newMockTestAdminEnv(t *testing.T) (*httptest.Server, *store.MemoryStore) {
	t.Helper()
	repo := store.NewMemoryStore()
	srv := NewServerForTest(repo, nil)
	httpsrv := httptest.NewServer(srv.Handler())
	t.Cleanup(httpsrv.Close)
	return httpsrv, repo
}

func mockTestPost(t *testing.T, server *httptest.Server, payload any) *http.Response {
	t.Helper()
	buf, _ := json.Marshal(payload)
	req, _ := http.NewRequest(http.MethodPost, server.URL+"/v1/admin/mock-tests", bytes.NewReader(buf))
	req.Header.Set("Authorization", "Bearer dev-admin-token")
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("POST: %v", err)
	}
	t.Cleanup(func() { resp.Body.Close() })
	return resp
}

func mockTestPatch(t *testing.T, server *httptest.Server, id string, payload any) *http.Response {
	t.Helper()
	buf, _ := json.Marshal(payload)
	req, _ := http.NewRequest(http.MethodPatch, server.URL+"/v1/admin/mock-tests/"+id, bytes.NewReader(buf))
	req.Header.Set("Authorization", "Bearer dev-admin-token")
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("PATCH: %v", err)
	}
	t.Cleanup(func() { resp.Body.Close() })
	return resp
}

func TestAdminMockTests_PromotionPublishedConflict_Returns409(t *testing.T) {
	server, _ := newMockTestAdminEnv(t)

	// Seed an already-published promotion exam for a2.
	resp1 := mockTestPost(t, server, contracts.MockTest{
		Title: "Đề pilot A2", Status: "published",
		IsPromotion: true, TargetLevel: "a2",
	})
	if resp1.StatusCode != http.StatusCreated {
		t.Fatalf("seed 1: want 201, got %d", resp1.StatusCode)
	}

	// Second published promotion for the same level → 409.
	resp2 := mockTestPost(t, server, contracts.MockTest{
		Title: "Đề mới A2", Status: "published",
		IsPromotion: true, TargetLevel: "a2",
	})
	if resp2.StatusCode != http.StatusConflict {
		t.Fatalf("conflict: want 409, got %d", resp2.StatusCode)
	}
	var body map[string]any
	_ = json.NewDecoder(resp2.Body).Decode(&body)
	errBlock, _ := body["error"].(map[string]any)
	if errBlock["code"] != "promotion_exam_already_published" {
		t.Errorf("error code = %v, want promotion_exam_already_published; body=%v", errBlock["code"], body)
	}
}

func TestAdminMockTests_PromotionDraft_NoCheck_Returns201(t *testing.T) {
	server, _ := newMockTestAdminEnv(t)

	// Seed published promotion.
	resp1 := mockTestPost(t, server, contracts.MockTest{
		Title: "Đề pilot A2", Status: "published",
		IsPromotion: true, TargetLevel: "a2",
	})
	if resp1.StatusCode != http.StatusCreated {
		t.Fatalf("seed 1: want 201, got %d", resp1.StatusCode)
	}

	// Draft promotion at same level — uniqueness check skipped → 201.
	resp2 := mockTestPost(t, server, contracts.MockTest{
		Title: "Đề draft A2", Status: "draft",
		IsPromotion: true, TargetLevel: "a2",
	})
	if resp2.StatusCode != http.StatusCreated {
		t.Errorf("draft second a2 promotion: want 201, got %d", resp2.StatusCode)
	}
}

func TestAdminMockTests_PromotionPatchSelfExcluded_Returns200(t *testing.T) {
	server, _ := newMockTestAdminEnv(t)

	// Seed a published promotion exam.
	resp := mockTestPost(t, server, contracts.MockTest{
		Title: "Đề pilot A2", Status: "published",
		IsPromotion: true, TargetLevel: "a2",
	})
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("seed: want 201, got %d", resp.StatusCode)
	}
	var body map[string]any
	_ = json.NewDecoder(resp.Body).Decode(&body)
	created, _ := body["data"].(map[string]any)
	id, _ := created["id"].(string)
	if id == "" {
		t.Fatalf("seed missing id; body=%v", body)
	}

	// PATCH the same row keeping is_promotion=true + same level + published.
	// Self-exclusion should let the update through.
	patch := mockTestPatch(t, server, id, contracts.MockTest{
		Title: "Đề pilot A2 (đã sửa title)", Status: "published",
		IsPromotion: true, TargetLevel: "a2",
	})
	if patch.StatusCode != http.StatusOK {
		t.Errorf("self PATCH: want 200, got %d", patch.StatusCode)
	}
}

func TestAdminMockTests_PromotionInvalidTargetLevel_Returns400(t *testing.T) {
	server, _ := newMockTestAdminEnv(t)

	resp := mockTestPost(t, server, contracts.MockTest{
		Title: "Đề thuốc", Status: "draft",
		IsPromotion: true, TargetLevel: "garbage",
	})
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("invalid target_level: want 400, got %d", resp.StatusCode)
	}
	var body map[string]any
	_ = json.NewDecoder(resp.Body).Decode(&body)
	errBlock, _ := body["error"].(map[string]any)
	if errBlock["code"] != "invalid_target_level" {
		t.Errorf("error code = %v, want invalid_target_level; body=%v", errBlock["code"], body)
	}
}

func TestAdminMockTests_PromotionEmptyTargetLevel_Returns400(t *testing.T) {
	server, _ := newMockTestAdminEnv(t)

	resp := mockTestPost(t, server, contracts.MockTest{
		Title: "No level", Status: "draft",
		IsPromotion: true, TargetLevel: "",
	})
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("missing target_level: want 400, got %d", resp.StatusCode)
	}
}

func TestAdminMockTests_NonPromotionInvalidTargetLevel_Returns201(t *testing.T) {
	server, _ := newMockTestAdminEnv(t)

	// Non-promotion mock with stray target_level — validation only fires
	// when is_promotion=true.
	resp := mockTestPost(t, server, contracts.MockTest{
		Title: "Normal mock", Status: "draft",
		IsPromotion: false, TargetLevel: "garbage",
	})
	if resp.StatusCode != http.StatusCreated {
		t.Errorf("non-promotion with stray target_level: want 201, got %d", resp.StatusCode)
	}
}

func TestAdminMockTests_NonPromotion_Unaffected_Returns201(t *testing.T) {
	server, _ := newMockTestAdminEnv(t)

	// Seed a published promotion exam at a2.
	resp1 := mockTestPost(t, server, contracts.MockTest{
		Title: "Đề pilot A2", Status: "published",
		IsPromotion: true, TargetLevel: "a2",
	})
	if resp1.StatusCode != http.StatusCreated {
		t.Fatalf("seed: want 201, got %d", resp1.StatusCode)
	}

	// Non-promotion mock test at same level — no uniqueness check → 201.
	resp2 := mockTestPost(t, server, contracts.MockTest{
		Title: "Đề luyện thi tổng hợp", Status: "published",
		IsPromotion: false, TargetLevel: "a2",
	})
	if resp2.StatusCode != http.StatusCreated {
		t.Errorf("non-promotion same level: want 201, got %d", resp2.StatusCode)
	}
}
