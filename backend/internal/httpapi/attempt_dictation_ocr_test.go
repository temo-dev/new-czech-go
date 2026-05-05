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
	"time"

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

// ── Submit endpoint (V18.1-B1) ───────────────────────────────────────────────

// newDictationOCRSubmitTestServer creates a server with a 3-sentence published
// dictation exercise wired with `submission_mode="ocr"` and a created attempt.
func newDictationOCRSubmitTestServer(t *testing.T, ocrText string) (*httptest.Server, *store.MemoryStore, string, string) {
	t.Helper()
	t.Setenv("LOCAL_ASSETS_DIR", t.TempDir())
	repo := store.NewMemoryStore()
	created := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "psani_3_dictation",
		SkillKind:    "viet",
		ModuleID:     "mod-viet",
		Status:       "published",
		Detail: map[string]any{
			"topic":                    "Test",
			"max_replays_per_sentence": float64(3),
			"max_points":               float64(10),
			"pass_threshold_percent":   float64(60),
			"submission_mode":          "ocr",
			"sentences": []any{
				map[string]any{"idx": float64(0), "text": "Pavel jde do kavárny."},
				map[string]any{"idx": float64(1), "text": "Chce si dát čaj."},
				map[string]any{"idx": float64(2), "text": "Děkuji."},
			},
		},
	})
	s := NewServerForTest(repo, nil)
	s.SetOCRProvider(&fakeOCR{text: ocrText})
	att, err := repo.CreateAttempt("user-learner-1", created.ID, "ios", "1.0", "vi")
	if err != nil {
		t.Fatalf("create attempt: %v", err)
	}
	srv := httptest.NewServer(s.Handler())
	t.Cleanup(srv.Close)
	return srv, repo, created.ID, att.ID
}

func postOCRSubmit(t *testing.T, srv *httptest.Server, attemptID string, sentencesJSON string, token string) *http.Response {
	t.Helper()
	body := &bytes.Buffer{}
	mw := multipart.NewWriter(body)
	_ = mw.WriteField("sentences", sentencesJSON)
	mw.Close()

	url := fmt.Sprintf("%s/v1/attempts/%s/submit-dictation-ocr", srv.URL, attemptID)
	req, _ := http.NewRequest(http.MethodPost, url, body)
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", mw.FormDataContentType())
	resp, err := srv.Client().Do(req)
	if err != nil {
		t.Fatalf("post: %v", err)
	}
	return resp
}

func TestSubmitDictationOCR_HappyPath(t *testing.T) {
	srv, _, _, attemptID := newDictationOCRSubmitTestServer(t, "")
	payload := `[
		{"idx":0,"text":"Pavel jde do kavárny.","asset_id":"a-0","replay_count":0},
		{"idx":1,"text":"Chce si dát čaj.","asset_id":"a-1","replay_count":1},
		{"idx":2,"text":"Děkuji.","asset_id":"a-2","replay_count":2}
	]`
	resp := postOCRSubmit(t, srv, attemptID, payload, devLearnerToken)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusAccepted {
		raw, _ := io.ReadAll(resp.Body)
		t.Fatalf("status=%d body=%s", resp.StatusCode, string(raw))
	}
	var env struct {
		Data map[string]any `json:"data"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&env); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if got, _ := env.Data["status"].(string); got != "scoring" {
		t.Errorf("status: %v", env.Data["status"])
	}
}

func TestSubmitDictationOCR_RejectsCountMismatch(t *testing.T) {
	srv, _, _, attemptID := newDictationOCRSubmitTestServer(t, "")
	// 3-sentence exercise, only 2 submitted
	payload := `[{"idx":0,"text":"x","asset_id":"a"},{"idx":1,"text":"y","asset_id":"b"}]`
	resp := postOCRSubmit(t, srv, attemptID, payload, devLearnerToken)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", resp.StatusCode)
	}
	var env struct {
		Error struct {
			Code string `json:"code"`
		} `json:"error"`
	}
	json.NewDecoder(resp.Body).Decode(&env)
	if env.Error.Code != "invalid_sentence_count" {
		t.Errorf("error code: %q", env.Error.Code)
	}
}

func TestSubmitDictationOCR_RejectsLargeBody(t *testing.T) {
	srv, _, _, attemptID := newDictationOCRSubmitTestServer(t, "")
	huge := bytes.Repeat([]byte("x"), 50*1024*1024)
	body := &bytes.Buffer{}
	mw := multipart.NewWriter(body)
	_ = mw.WriteField("sentences", string(huge))
	mw.Close()
	url := fmt.Sprintf("%s/v1/attempts/%s/submit-dictation-ocr", srv.URL, attemptID)
	req, _ := http.NewRequest(http.MethodPost, url, body)
	req.Header.Set("Authorization", "Bearer "+devLearnerToken)
	req.Header.Set("Content-Type", mw.FormDataContentType())
	resp, err := srv.Client().Do(req)
	if err != nil {
		t.Fatalf("do: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusRequestEntityTooLarge {
		t.Errorf("expected 413, got %d", resp.StatusCode)
	}
}

func TestSubmitDictationOCR_NonDictationExerciseReturns400(t *testing.T) {
	t.Setenv("LOCAL_ASSETS_DIR", t.TempDir())
	repo := store.NewMemoryStore()
	created := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "psani_2_email", SkillKind: "viet", ModuleID: "m", Status: "published",
	})
	s := NewServerForTest(repo, nil)
	att, _ := repo.CreateAttempt("user-learner-1", created.ID, "ios", "1.0", "vi")
	srv := httptest.NewServer(s.Handler())
	t.Cleanup(srv.Close)
	resp := postOCRSubmit(t, srv, att.ID, `[{"idx":0,"text":"x"}]`, devLearnerToken)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", resp.StatusCode)
	}
}

func TestConvertOCRSubmission_PreservesIdxTextReplay(t *testing.T) {
	in := []contracts.DictationOCRSentenceSubmission{
		{Idx: 2, Text: "C", AssetID: "a-2", ReplayCount: 5},
		{Idx: 0, Text: "A", AssetID: "a-0", ReplayCount: 1},
		{Idx: 1, Text: "B", AssetID: "a-1", ReplayCount: 3},
	}
	out := convertOCRSubmissionToDictation(in)
	if len(out.Sentences) != 3 {
		t.Fatalf("len: %d", len(out.Sentences))
	}
	for _, s := range out.Sentences {
		switch s.Idx {
		case 0:
			if s.Text != "A" || s.ReplayCount != 1 {
				t.Errorf("idx 0: %+v", s)
			}
		case 1:
			if s.Text != "B" || s.ReplayCount != 3 {
				t.Errorf("idx 1: %+v", s)
			}
		case 2:
			if s.Text != "C" || s.ReplayCount != 5 {
				t.Errorf("idx 2: %+v", s)
			}
		}
	}
}

// TestSubmitDictationOCR_ScoreParityWithSubmitText guarantees that posting the
// same learner text via the OCR endpoint produces the same overall score as
// posting it via the V18 submit-text JSON endpoint. This is the V18.1 AC8
// contract: OCR must NOT alter scoring; it only changes the input pipeline.
func TestSubmitDictationOCR_ScoreParityWithSubmitText(t *testing.T) {
	t.Setenv("LOCAL_ASSETS_DIR", t.TempDir())
	repo := store.NewMemoryStore()
	created := repo.CreateExercise(contracts.Exercise{
		ExerciseType: "psani_3_dictation",
		SkillKind:    "viet",
		ModuleID:     "mod-viet",
		Status:       "published",
		Detail: map[string]any{
			"topic":                    "Parity",
			"max_replays_per_sentence": float64(3),
			"max_points":               float64(10),
			"pass_threshold_percent":   float64(60),
			"sentences": []any{
				map[string]any{"idx": float64(0), "text": "Pavel jde do kavárny."},
				map[string]any{"idx": float64(1), "text": "Děkuji."},
			},
		},
	})
	s := NewServerForTest(repo, nil)
	srv := httptest.NewServer(s.Handler())
	t.Cleanup(srv.Close)

	// Same learner text submitted via two different attempts → identical score.
	learnerSentences := []map[string]any{
		{"idx": 0, "text": "Pavel jde do kavarny.", "replay_count": 1}, // missing diacritic
		{"idx": 1, "text": "Děkuji.", "replay_count": 0},
	}

	// Path 1 — submit-text (V18 JSON).
	att1, _ := repo.CreateAttempt("user-learner-1", created.ID, "ios", "1.0", "vi")
	body1, _ := json.Marshal(map[string]any{"sentences": learnerSentences})
	req1, _ := http.NewRequest(http.MethodPost,
		fmt.Sprintf("%s/v1/attempts/%s/submit-text", srv.URL, att1.ID),
		bytes.NewReader(body1))
	req1.Header.Set("Authorization", "Bearer "+devLearnerToken)
	req1.Header.Set("Content-Type", "application/json")
	resp1, err := srv.Client().Do(req1)
	if err != nil {
		t.Fatalf("submit-text: %v", err)
	}
	resp1.Body.Close()
	if resp1.StatusCode != http.StatusAccepted {
		t.Fatalf("submit-text status: %d", resp1.StatusCode)
	}
	score1 := waitForDictationScore(t, repo, att1.ID)

	// Path 2 — submit-dictation-ocr (V18.1 multipart).
	att2, _ := repo.CreateAttempt("user-learner-1", created.ID, "ios", "1.0", "vi")
	rows := []map[string]any{
		{"idx": 0, "text": "Pavel jde do kavarny.", "asset_id": "a-0", "replay_count": 1},
		{"idx": 1, "text": "Děkuji.", "asset_id": "a-1", "replay_count": 0},
	}
	rowsJSON, _ := json.Marshal(rows)
	resp2 := postOCRSubmit(t, srv, att2.ID, string(rowsJSON), devLearnerToken)
	if resp2.StatusCode != http.StatusAccepted {
		raw, _ := io.ReadAll(resp2.Body)
		resp2.Body.Close()
		t.Fatalf("submit-dictation-ocr status=%d body=%s", resp2.StatusCode, string(raw))
	}
	resp2.Body.Close()
	score2 := waitForDictationScore(t, repo, att2.ID)

	if score1 != score2 {
		t.Errorf("score parity violated: submit-text=%d submit-dictation-ocr=%d", score1, score2)
	}
	if score1 == 0 {
		t.Errorf("score=0 means scorer didn't run; check provider wiring")
	}
}

// waitForDictationScore polls the attempt store until DictationResult is
// populated. ProcessDictationAttempt is goroutine-dispatched and the dev OCR
// provider returns synchronously, so the loop usually exits within a few ms.
func waitForDictationScore(t *testing.T, repo *store.MemoryStore, attemptID string) int {
	t.Helper()
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		att, ok := repo.Attempt(attemptID)
		if !ok {
			t.Fatalf("attempt %s vanished", attemptID)
		}
		if att.Feedback != nil && att.Feedback.DictationResult != nil {
			return att.Feedback.DictationResult.OverallScore
		}
		time.Sleep(20 * time.Millisecond)
	}
	t.Fatalf("dictation score never arrived for attempt %s", attemptID)
	return -1
}

// silence unused import lint when filepath isn't otherwise referenced
var _ = filepath.Separator
