package httpapi

import (
	"bytes"
	"encoding/json"
	"io"
	"mime/multipart"
	"net/http"
	"strings"
	"testing"
)

// pngBytes is a minimal valid 1x1 PNG used as the upload payload. Avoids
// pulling in an image encoder for the test.
var pngBytes = []byte{
	0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
	0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
	0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
	0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
	0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
	0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
	0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
	0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
	0x42, 0x60, 0x82,
}

func uploadAvatar(t *testing.T, env *authTestEnv, token string, mime, filename string, body []byte) (*http.Response, map[string]any) {
	t.Helper()
	var buf bytes.Buffer
	mw := multipart.NewWriter(&buf)
	header := make(map[string][]string)
	header["Content-Disposition"] = []string{`form-data; name="file"; filename="` + filename + `"`}
	header["Content-Type"] = []string{mime}
	part, err := mw.CreatePart(header)
	if err != nil {
		t.Fatalf("create part: %v", err)
	}
	if _, err := io.Copy(part, bytes.NewReader(body)); err != nil {
		t.Fatalf("copy: %v", err)
	}
	mw.Close()

	req, _ := http.NewRequest(http.MethodPost, env.srv.URL+"/v1/users/me/avatar", &buf)
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", mw.FormDataContentType())
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("post avatar: %v", err)
	}
	t.Cleanup(func() { resp.Body.Close() })
	var out map[string]any
	_ = json.NewDecoder(resp.Body).Decode(&out)
	return resp, out
}

func TestAvatar_Upload_HappyPath(t *testing.T) {
	env := newAuthTestEnv(t)
	env.preSignup(t, "av@x.com", "Strong1Password!")
	tok := env.loginToken(t, "av@x.com", "Strong1Password!")

	resp, body := uploadAvatar(t, env, tok, "image/png", "me.png", pngBytes)
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("want 200, got %d body=%v", resp.StatusCode, body)
	}
	data, _ := body["data"].(map[string]any)
	key, _ := data["image_asset_id"].(string)
	if !strings.HasPrefix(key, "avatars/") {
		t.Errorf("storage key should be under avatars/, got %q", key)
	}

	// Confirm /v1/users/me reflects the new avatar_asset_id.
	_, me := env.getMe(t, tok)
	user := me["user"].(map[string]any)
	if user["avatar_asset_id"] != key {
		t.Errorf("avatar_asset_id mismatch: %v != %v", user["avatar_asset_id"], key)
	}
}

func TestAvatar_Upload_WrongMime_Returns415(t *testing.T) {
	env := newAuthTestEnv(t)
	env.preSignup(t, "av@x.com", "Strong1Password!")
	tok := env.loginToken(t, "av@x.com", "Strong1Password!")

	resp, _ := uploadAvatar(t, env, tok, "application/pdf", "doc.pdf", []byte("%PDF-1.4 fake"))
	if resp.StatusCode != http.StatusUnsupportedMediaType {
		t.Errorf("want 415, got %d", resp.StatusCode)
	}
}

func TestAvatar_Upload_RequiresAuth(t *testing.T) {
	env := newAuthTestEnv(t)
	resp, _ := uploadAvatar(t, env, "", "image/png", "me.png", pngBytes)
	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("want 401, got %d", resp.StatusCode)
	}
}

func TestAvatar_Delete_ClearsAssetId(t *testing.T) {
	env := newAuthTestEnv(t)
	env.preSignup(t, "av@x.com", "Strong1Password!")
	tok := env.loginToken(t, "av@x.com", "Strong1Password!")

	if _, body := uploadAvatar(t, env, tok, "image/png", "me.png", pngBytes); body == nil {
		t.Fatal("upload returned nil body")
	}

	req, _ := http.NewRequest(http.MethodDelete, env.srv.URL+"/v1/users/me/avatar", nil)
	req.Header.Set("Authorization", "Bearer "+tok)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("delete: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusNoContent {
		t.Fatalf("want 204, got %d", resp.StatusCode)
	}
	_, me := env.getMe(t, tok)
	user := me["user"].(map[string]any)
	if av, _ := user["avatar_asset_id"].(string); av != "" {
		t.Errorf("avatar_asset_id should be empty after delete, got %q", av)
	}
}

func TestPatchMe_UpdatesDisplayName_TooLongRejected(t *testing.T) {
	env := newAuthTestEnv(t)
	env.preSignup(t, "n@x.com", "Strong1Password!")
	tok := env.loginToken(t, "n@x.com", "Strong1Password!")

	long := strings.Repeat("a", 61)
	resp, _ := env.patchMe(t, tok, map[string]string{"display_name": long})
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("want 400 for >60-char display_name, got %d", resp.StatusCode)
	}
}
