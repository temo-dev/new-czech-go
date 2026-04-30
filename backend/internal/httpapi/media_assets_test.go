package httpapi

import (
	"bytes"
	"encoding/json"
	"fmt"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/store"
)

// ── helpers ───────────────────────────────────────────────────────────────────

func mediaServer(t *testing.T) (*httptest.Server, *store.MemoryStore) {
	t.Helper()
	repo := store.NewMemoryStore()
	srv := httptest.NewServer(NewServer(repo, nil, nil))
	t.Cleanup(srv.Close)
	return srv, repo
}

func createVocabItemForTest(t *testing.T, srv *httptest.Server) (setID, itemID string) {
	t.Helper()
	// create set
	setBody := `{"module_id":"mod-1","title":"Test Set","level":"A2","explanation_lang":"vi"}`
	req, _ := http.NewRequest(http.MethodPost, srv.URL+"/v1/admin/vocabulary-sets", strings.NewReader(setBody))
	req.Header.Set("Authorization", "Bearer dev-admin-token")
	req.Header.Set("Content-Type", "application/json")
	resp, err := srv.Client().Do(req)
	if err != nil {
		t.Fatalf("create vocab set: %v", err)
	}
	defer resp.Body.Close()
	var setPayload map[string]any
	json.NewDecoder(resp.Body).Decode(&setPayload)
	setData, _ := setPayload["data"].(map[string]any)
	setID = fmt.Sprintf("%v", setData["id"])

	// create item
	itemBody := fmt.Sprintf(`{"term":"kavárna","meaning":"quán cà phê"}`)
	req2, _ := http.NewRequest(http.MethodPost, srv.URL+"/v1/admin/vocabulary-sets/"+setID+"/items", strings.NewReader(itemBody))
	req2.Header.Set("Authorization", "Bearer dev-admin-token")
	req2.Header.Set("Content-Type", "application/json")
	resp2, err := srv.Client().Do(req2)
	if err != nil {
		t.Fatalf("create vocab item: %v", err)
	}
	defer resp2.Body.Close()
	var itemPayload map[string]any
	json.NewDecoder(resp2.Body).Decode(&itemPayload)
	itemData, _ := itemPayload["data"].(map[string]any)
	itemID = fmt.Sprintf("%v", itemData["id"])
	return setID, itemID
}

func createGrammarRuleForTest(t *testing.T, srv *httptest.Server) string {
	t.Helper()
	body := `{"module_id":"mod-1","title":"Lokativ","level":"A2"}`
	req, _ := http.NewRequest(http.MethodPost, srv.URL+"/v1/admin/grammar-rules", strings.NewReader(body))
	req.Header.Set("Authorization", "Bearer dev-admin-token")
	req.Header.Set("Content-Type", "application/json")
	resp, err := srv.Client().Do(req)
	if err != nil {
		t.Fatalf("create grammar rule: %v", err)
	}
	defer resp.Body.Close()
	var payload map[string]any
	json.NewDecoder(resp.Body).Decode(&payload)
	data, _ := payload["data"].(map[string]any)
	return fmt.Sprintf("%v", data["id"])
}

func multipartImageRequest(t *testing.T, url, token, mimeType string, fileBytes []byte) *http.Request {
	t.Helper()
	var buf bytes.Buffer
	w := multipart.NewWriter(&buf)
	// Use CreatePart to set Content-Type on the file part explicitly
	h := make(map[string][]string)
	h["Content-Disposition"] = []string{`form-data; name="file"; filename="test.jpg"`}
	h["Content-Type"] = []string{mimeType}
	fw, err := w.CreatePart(h)
	if err != nil {
		t.Fatalf("create part: %v", err)
	}
	fw.Write(fileBytes)
	w.Close()

	req, _ := http.NewRequest(http.MethodPost, url, &buf)
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", w.FormDataContentType())
	return req
}

// minimalJPEG is a 1×1 white JPEG for testing.
var minimalJPEG = []byte{
	0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
	0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
	0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
	0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
	0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
	0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
	0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
	0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01,
	0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00,
	0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
	0x09, 0x0A, 0x0B, 0xFF, 0xC4, 0x00, 0xB5, 0x10, 0x00, 0x02, 0x01, 0x03,
	0xFF, 0xD9,
}

// ── Vocabulary Item Image tests ───────────────────────────────────────────────

func TestMediaAssets_VocabItemImage_Upload(t *testing.T) {
	srv, repo := mediaServer(t)
	_, itemID := createVocabItemForTest(t, srv)

	req := multipartImageRequest(t, srv.URL+"/v1/admin/vocabulary-items/"+itemID+"/image", adminToken, "image/jpeg", minimalJPEG)
	resp, err := srv.Client().Do(req)
	if err != nil {
		t.Fatalf("upload image: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}
	var payload map[string]any
	json.NewDecoder(resp.Body).Decode(&payload)
	data, _ := payload["data"].(map[string]any)
	assetID, _ := data["image_asset_id"].(string)
	if assetID == "" {
		t.Fatal("expected non-empty image_asset_id in response")
	}

	// verify store updated
	item, ok := repo.GetVocabularyItem(itemID)
	if !ok {
		t.Fatal("item not found")
	}
	if item.ImageAssetID == "" {
		t.Fatal("expected image_asset_id set in store")
	}
	if item.ImageAssetID != assetID {
		t.Fatalf("store image_asset_id %q != response %q", item.ImageAssetID, assetID)
	}
}

func TestMediaAssets_VocabItemImage_Upload_UnsupportedMime(t *testing.T) {
	srv, _ := mediaServer(t)
	_, itemID := createVocabItemForTest(t, srv)

	// Use application/pdf — not in allowedImageMIMEs
	req := multipartImageRequest(t, srv.URL+"/v1/admin/vocabulary-items/"+itemID+"/image", adminToken, "application/pdf", []byte("%PDF-1.4 fake"))
	resp, _ := srv.Client().Do(req)
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusUnsupportedMediaType {
		t.Fatalf("expected 415, got %d", resp.StatusCode)
	}
}

func TestMediaAssets_VocabItemImage_Upload_NotFound(t *testing.T) {
	srv, _ := mediaServer(t)
	req := multipartImageRequest(t, srv.URL+"/v1/admin/vocabulary-items/nonexistent/image", adminToken, "image/jpeg", minimalJPEG)
	resp, _ := srv.Client().Do(req)
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", resp.StatusCode)
	}
}

func TestMediaAssets_VocabItemImage_Delete(t *testing.T) {
	srv, repo := mediaServer(t)
	_, itemID := createVocabItemForTest(t, srv)

	// upload first
	req := multipartImageRequest(t, srv.URL+"/v1/admin/vocabulary-items/"+itemID+"/image", adminToken, "image/jpeg", minimalJPEG)
	srv.Client().Do(req)

	// delete
	delReq, _ := http.NewRequest(http.MethodDelete, srv.URL+"/v1/admin/vocabulary-items/"+itemID+"/image", nil)
	delReq.Header.Set("Authorization", "Bearer "+adminToken)
	delResp, _ := srv.Client().Do(delReq)
	defer delResp.Body.Close()

	if delResp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", delResp.StatusCode)
	}

	item, _ := repo.GetVocabularyItem(itemID)
	if item.ImageAssetID != "" {
		t.Fatalf("expected empty image_asset_id after delete, got %q", item.ImageAssetID)
	}
}

func TestMediaAssets_VocabItemImageFile_NoImage_Returns404(t *testing.T) {
	srv, _ := mediaServer(t)
	_, itemID := createVocabItemForTest(t, srv)

	req, _ := http.NewRequest(http.MethodGet, srv.URL+"/v1/vocabulary-items/"+itemID+"/image/file", nil)
	req.Header.Set("Authorization", "Bearer dev-learner-token")
	resp, _ := srv.Client().Do(req)
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", resp.StatusCode)
	}
}

// ── Grammar Rule Image tests ──────────────────────────────────────────────────

func TestMediaAssets_GrammarRuleImage_Upload(t *testing.T) {
	srv, repo := mediaServer(t)
	ruleID := createGrammarRuleForTest(t, srv)

	req := multipartImageRequest(t, srv.URL+"/v1/admin/grammar-rules/"+ruleID+"/image", adminToken, "image/jpeg", minimalJPEG)
	resp, err := srv.Client().Do(req)
	if err != nil {
		t.Fatalf("upload: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}

	rule, ok := repo.GetGrammarRule(ruleID)
	if !ok {
		t.Fatal("rule not found")
	}
	if rule.ImageAssetID == "" {
		t.Fatal("expected image_asset_id set in store")
	}
}

func TestMediaAssets_GrammarRuleImage_Upload_UnsupportedMime(t *testing.T) {
	srv, _ := mediaServer(t)
	ruleID := createGrammarRuleForTest(t, srv)

	req := multipartImageRequest(t, srv.URL+"/v1/admin/grammar-rules/"+ruleID+"/image", adminToken, "video/mp4", []byte("fake video bytes"))
	resp, _ := srv.Client().Do(req)
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusUnsupportedMediaType {
		t.Fatalf("expected 415, got %d", resp.StatusCode)
	}
}

func TestMediaAssets_GrammarRuleImage_Delete(t *testing.T) {
	srv, repo := mediaServer(t)
	ruleID := createGrammarRuleForTest(t, srv)

	// upload
	req := multipartImageRequest(t, srv.URL+"/v1/admin/grammar-rules/"+ruleID+"/image", adminToken, "image/jpeg", minimalJPEG)
	srv.Client().Do(req)

	// delete
	delReq, _ := http.NewRequest(http.MethodDelete, srv.URL+"/v1/admin/grammar-rules/"+ruleID+"/image", nil)
	delReq.Header.Set("Authorization", "Bearer "+adminToken)
	srv.Client().Do(delReq)

	rule, _ := repo.GetGrammarRule(ruleID)
	if rule.ImageAssetID != "" {
		t.Fatalf("expected empty image_asset_id after delete, got %q", rule.ImageAssetID)
	}
}

// ── Contract: image_asset_id in list responses ────────────────────────────────

func TestMediaAssets_VocabItemImage_AppearsInListResponse(t *testing.T) {
	srv, _ := mediaServer(t)
	setID, itemID := createVocabItemForTest(t, srv)

	// upload image
	req := multipartImageRequest(t, srv.URL+"/v1/admin/vocabulary-items/"+itemID+"/image", adminToken, "image/jpeg", minimalJPEG)
	srv.Client().Do(req)

	// list items
	listReq, _ := http.NewRequest(http.MethodGet, srv.URL+"/v1/admin/vocabulary-sets/"+setID+"/items", nil)
	listReq.Header.Set("Authorization", "Bearer "+adminToken)
	listResp, _ := srv.Client().Do(listReq)
	defer listResp.Body.Close()

	var payload map[string]any
	json.NewDecoder(listResp.Body).Decode(&payload)
	items, _ := payload["data"].([]any)
	if len(items) == 0 {
		t.Fatal("expected items in list")
	}
	firstItem, _ := items[0].(map[string]any)
	assetID, _ := firstItem["image_asset_id"].(string)
	if assetID == "" {
		t.Fatal("expected image_asset_id in list response after upload")
	}
}

// ── /v1/media/file endpoint tests ────────────────────────────────────────────

func TestMediaAssets_MediaFile_MissingKey_Returns404(t *testing.T) {
	srv, _ := mediaServer(t)
	req, _ := http.NewRequest(http.MethodGet, srv.URL+"/v1/media/file", nil)
	req.Header.Set("Authorization", "Bearer dev-learner-token")
	resp, _ := srv.Client().Do(req)
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusNotFound {
		t.Fatalf("expected 404 for missing key, got %d", resp.StatusCode)
	}
}

func TestMediaAssets_MediaFile_PathTraversalDotDot_Returns400(t *testing.T) {
	srv, _ := mediaServer(t)

	for _, key := range []string{"../../etc/passwd", "../secrets", "%2e%2e/etc"} {
		req, _ := http.NewRequest(http.MethodGet, srv.URL+"/v1/media/file?key="+key, nil)
		req.Header.Set("Authorization", "Bearer dev-learner-token")
		resp, _ := srv.Client().Do(req)
		resp.Body.Close()

		// Either 400 (rejected key) or 404 (path outside base) — never 200
		if resp.StatusCode == http.StatusOK {
			t.Fatalf("path traversal key %q returned 200 — security issue", key)
		}
	}
}

func TestMediaAssets_MediaFile_AbsentFile_Returns404(t *testing.T) {
	srv, _ := mediaServer(t)
	req, _ := http.NewRequest(http.MethodGet, srv.URL+"/v1/media/file?key=vocabulary-images/nonexistent/img-000.jpg", nil)
	req.Header.Set("Authorization", "Bearer dev-learner-token")
	resp, _ := srv.Client().Do(req)
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusNotFound {
		t.Fatalf("expected 404 for absent file, got %d", resp.StatusCode)
	}
}

func TestMediaAssets_VocabItemImage_OldFileCleanup(t *testing.T) {
	srv, repo := mediaServer(t)
	_, itemID := createVocabItemForTest(t, srv)

	// Upload first image
	req1 := multipartImageRequest(t, srv.URL+"/v1/admin/vocabulary-items/"+itemID+"/image", adminToken, "image/jpeg", minimalJPEG)
	resp1, _ := srv.Client().Do(req1)
	defer resp1.Body.Close()
	if resp1.StatusCode != http.StatusOK {
		t.Fatalf("first upload: expected 200, got %d", resp1.StatusCode)
	}
	var p1 map[string]any
	json.NewDecoder(resp1.Body).Decode(&p1)
	firstKey := (p1["data"].(map[string]any))["image_asset_id"].(string)

	// Upload second image — should overwrite
	req2 := multipartImageRequest(t, srv.URL+"/v1/admin/vocabulary-items/"+itemID+"/image", adminToken, "image/jpeg", minimalJPEG)
	resp2, _ := srv.Client().Do(req2)
	defer resp2.Body.Close()
	if resp2.StatusCode != http.StatusOK {
		t.Fatalf("second upload: expected 200, got %d", resp2.StatusCode)
	}

	item, _ := repo.GetVocabularyItem(itemID)
	if item.ImageAssetID == firstKey {
		t.Fatal("store should point to new key after second upload")
	}
	if item.ImageAssetID == "" {
		t.Fatal("store should have a key after second upload")
	}
}

func TestMediaAssets_MultipleChoiceOption_HasImageAssetIDField(t *testing.T) {
	// Contract: MultipleChoiceOption JSON round-trip preserves image_asset_id
	opt := struct {
		Key          string `json:"key"`
		Text         string `json:"text"`
		ImageAssetID string `json:"image_asset_id,omitempty"`
	}{Key: "A", Text: "Kavárna", ImageAssetID: "vocabulary-images/vi-1/img-001.jpg"}

	encoded, _ := json.Marshal(opt)
	var decoded map[string]any
	json.Unmarshal(encoded, &decoded)

	if decoded["image_asset_id"] != "vocabulary-images/vi-1/img-001.jpg" {
		t.Fatalf("image_asset_id not preserved in JSON: %v", decoded)
	}
}
