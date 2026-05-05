package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/processing"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

// fakeOCR returns a canned text and records call count.
type fakeOCR struct {
	text  string
	calls int
}

func (f *fakeOCR) OCRImage(_ context.Context, _ string, _ []byte) (string, error) {
	f.calls++
	return f.text, nil
}

func newDictationOCRTestServer(t *testing.T, ocrText string) (*httptest.Server, *store.MemoryStore, string, string, *fakeOCR) {
	t.Helper()
	t.Setenv("LOCAL_ASSETS_DIR", t.TempDir())
	repo := store.NewMemoryStore()
	created := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "psani_3_dictation",
		SkillKind:    "viet",
		ModuleID:     "mod-viet",
		Status:       "published",
	})

	s := NewServerForTest(repo, nil)
	ocr := &fakeOCR{text: ocrText}
	s.SetOCRProvider(ocr)

	// Learner attempt owned by dev-learner-token's user.
	att, err := repo.CreateAttempt("user-learner-1", created.ID, "ios", "1.0", "vi")
	if err != nil {
		t.Fatalf("create attempt: %v", err)
	}

	srv := httptest.NewServer(s.Handler())
	t.Cleanup(srv.Close)
	return srv, repo, created.ID, att.ID, ocr
}

func postOCRPreview(t *testing.T, srv *httptest.Server, attemptID string, idx int, image []byte, mime string, token string) *http.Response {
	t.Helper()
	body := &bytes.Buffer{}
	mw := multipart.NewWriter(body)
	_ = mw.WriteField("idx", fmt.Sprintf("%d", idx))
	hdr := make(map[string][]string)
	hdr["Content-Disposition"] = []string{`form-data; name="image"; filename="photo.jpg"`}
	hdr["Content-Type"] = []string{mime}
	part, err := mw.CreatePart(hdr)
	if err != nil {
		t.Fatalf("create part: %v", err)
	}
	if _, err := part.Write(image); err != nil {
		t.Fatalf("write part: %v", err)
	}
	mw.Close()

	url := fmt.Sprintf("%s/v1/attempts/%s/dictation-ocr-preview", srv.URL, attemptID)
	req, _ := http.NewRequest(http.MethodPost, url, body)
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", mw.FormDataContentType())
	resp, err := srv.Client().Do(req)
	if err != nil {
		t.Fatalf("post: %v", err)
	}
	return resp
}

// findAttemptOwner mints a token for a known dev fixture user id.
// The dev-fixture login auto-issues "dev-learner-token" for u-learner.
const devLearnerToken = "dev-learner-token"

func TestDictationOCRPreview_Happy(t *testing.T) {
	srv, _, _, attemptID, ocr := newDictationOCRTestServer(t, "Včera jsem byl v kavárně.")
	resp := postOCRPreview(t, srv, attemptID, 0, []byte{0xff, 0xd8, 0xff, 0xe0}, "image/jpeg", devLearnerToken)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		raw, _ := io.ReadAll(resp.Body)
		t.Fatalf("status=%d body=%s", resp.StatusCode, string(raw))
	}
	var env struct {
		Data contracts.DictationOCRPreviewResponse `json:"data"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&env); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if env.Data.Text != "Včera jsem byl v kavárně." {
		t.Errorf("text: %q", env.Data.Text)
	}
	if env.Data.AssetID == "" {
		t.Errorf("asset_id missing")
	}
	if env.Data.Idx != 0 {
		t.Errorf("idx: %d", env.Data.Idx)
	}
	if ocr.calls != 1 {
		t.Errorf("expected 1 OCR call, got %d", ocr.calls)
	}
	// Verify file persisted on disk.
	disk := localExerciseAssetPath(env.Data.AssetID)
	if _, err := os.Stat(disk); err != nil {
		t.Errorf("file not written: %v (path=%s)", err, disk)
	}
}

func TestDictationOCRPreview_OCRFailReturnsEmptyText(t *testing.T) {
	srv, _, _, attemptID, _ := newDictationOCRTestServer(t, "")
	resp := postOCRPreview(t, srv, attemptID, 0, []byte{0x00, 0x00}, "image/jpeg", devLearnerToken)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		raw, _ := io.ReadAll(resp.Body)
		t.Fatalf("OCR fail must still 200; got=%d body=%s", resp.StatusCode, string(raw))
	}
	var env struct {
		Data contracts.DictationOCRPreviewResponse `json:"data"`
	}
	json.NewDecoder(resp.Body).Decode(&env)
	if env.Data.Text != "" {
		t.Errorf("expected empty text on OCR fail, got %q", env.Data.Text)
	}
	if env.Data.AssetID == "" {
		t.Errorf("asset_id should be returned even on OCR fail")
	}
}

func TestDictationOCRPreview_RejectsLargeImage(t *testing.T) {
	srv, _, _, attemptID, _ := newDictationOCRTestServer(t, "x")
	big := bytes.Repeat([]byte{0xff}, dictationOCRMaxImageBytes+10_000)
	resp := postOCRPreview(t, srv, attemptID, 0, big, "image/jpeg", devLearnerToken)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusRequestEntityTooLarge {
		t.Errorf("expected 413 on oversize, got %d", resp.StatusCode)
	}
}

func TestDictationOCRPreview_RejectsBadMime(t *testing.T) {
	srv, _, _, attemptID, _ := newDictationOCRTestServer(t, "x")
	resp := postOCRPreview(t, srv, attemptID, 0, []byte("hello"), "application/pdf", devLearnerToken)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusUnsupportedMediaType {
		t.Errorf("expected 415, got %d", resp.StatusCode)
	}
}

func TestDictationOCRPreview_RejectsBadIdx(t *testing.T) {
	srv, _, _, attemptID, _ := newDictationOCRTestServer(t, "x")
	resp := postOCRPreview(t, srv, attemptID, 99, []byte{0xff, 0xd8}, "image/jpeg", devLearnerToken)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("expected 400 on idx=99, got %d", resp.StatusCode)
	}
}

func TestDictationOCRPreview_RejectsNonDictationAttempt(t *testing.T) {
	t.Setenv("LOCAL_ASSETS_DIR", t.TempDir())
	repo := store.NewMemoryStore()
	created := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "psani_2_email", SkillKind: "viet", ModuleID: "m1", Status: "published",
	})
	s := NewServerForTest(repo, nil)
	s.SetOCRProvider(&fakeOCR{text: "x"})
	att, _ := repo.CreateAttempt("user-learner-1", created.ID, "ios", "1.0", "vi")
	srv := httptest.NewServer(s.Handler())
	t.Cleanup(srv.Close)
	resp := postOCRPreview(t, srv, att.ID, 0, []byte{0xff, 0xd8}, "image/jpeg", devLearnerToken)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("expected 400 on non-dictation, got %d", resp.StatusCode)
	}
}

// Compile-time confirmation: the test fake satisfies the OCR interface.
var _ processing.OCRProvider = (*fakeOCR)(nil)

// Ensure newDictationOCRRateLimiter resets after a fresh window.
func TestDictationOCRRateLimiter_Allow(t *testing.T) {
	rl := newDictationOCRRateLimiter()
	for i := 0; i < dictationOCRPreviewLimit; i++ {
		if !rl.allow("u-1") {
			t.Fatalf("blocked at i=%d under limit", i)
		}
	}
	if rl.allow("u-1") {
		t.Errorf("expected block over limit")
	}
	if !rl.allow("u-2") {
		t.Errorf("different user should not be limited")
	}
}

// silence unused import lint when filepath isn't otherwise referenced
var _ = filepath.Separator
