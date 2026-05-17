package httpapi

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"github.com/danieldev/czech-go-system/backend/internal/processing"
	"github.com/danieldev/czech-go-system/backend/internal/store"
)

// newCoursesLevelTestServer wires the V21 deps onto a fresh server and
// returns the test server, the underlying repo, and the user-level store
// so individual tests can seed published courses + an exercise inside one
// of them, then promote the user to varying levels.
func newCoursesLevelTestServer(t *testing.T) (*httptest.Server, *store.MemoryStore, store.UserLevelStore) {
	t.Helper()
	unsetMasteryEnv(t)
	unsetLevelEnv(t)

	repo := store.NewMemoryStore()
	mastery := store.NewMemorySkillMasteryStore()
	userLevels := store.NewMemoryUserLevelStore()
	promo := store.NewMemoryPromotionAttemptsStore()

	srv := NewServerForTest(repo, nil)
	srv.SetMasteryDeps(mastery, processing.LoadMasteryConfig())
	srv.SetLevelDeps(LevelDeps{
		Service: &processing.LevelService{
			Config:        processing.LoadLevelConfig(),
			Mastery:       mastery,
			UserLevels:    userLevels,
			PromoAttempts: promo,
			Now:           func() time.Time { return time.Date(2026, 5, 7, 12, 0, 0, 0, time.UTC) },
		},
		UserLevels:    userLevels,
		PromoAttempts: promo,
	})
	return httptest.NewServer(srv.Handler()), repo, userLevels
}

func get(t *testing.T, srv *httptest.Server, path, token string) (int, map[string]any) {
	t.Helper()
	req, err := http.NewRequest(http.MethodGet, srv.URL+path, nil)
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	resp, err := srv.Client().Do(req)
	if err != nil {
		t.Fatalf("do: %v", err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	if len(raw) == 0 {
		return resp.StatusCode, nil
	}
	var decoded map[string]any
	if err := json.Unmarshal(raw, &decoded); err != nil {
		t.Fatalf("decode: %v; body=%s", err, raw)
	}
	return resp.StatusCode, decoded
}

func seedCoursesByLevel(t *testing.T, repo *store.MemoryStore) (a2ID, b1ID, demoExID string) {
	t.Helper()
	a2, err := repo.CreateCourse(contracts.Course{Title: "Course A2", Status: "published", Level: "a2"})
	if err != nil {
		t.Fatalf("seed a2: %v", err)
	}
	a2ID = a2.ID

	b1, err := repo.CreateCourse(contracts.Course{Title: "Course B1", Status: "published", Level: "b1"})
	if err != nil {
		t.Fatalf("seed b1: %v", err)
	}
	b1ID = b1.ID

	mod, err := repo.CreateModule(contracts.Module{
		Title: "B1 Mod 1", Status: "published", CourseID: b1ID,
	})
	if err != nil {
		t.Fatalf("seed module: %v", err)
	}

	demoEx := repo.CreateExercise(contracts.Exercise{
		Title: "B1 Demo", ExerciseType: "cteni_1", Status: "published",
		Pool: "course", ModuleID: mod.ID, SkillKind: "doc",
	})
	demoExID = demoEx.ID

	_ = repo.CreateExercise(contracts.Exercise{
		Title: "B1 Gated", ExerciseType: "cteni_1", Status: "published",
		Pool: "course", ModuleID: mod.ID, SkillKind: "doc",
	})

	// Wire demo exercise on the b1 course.
	if _, ok := repo.UpdateCourse(b1ID, contracts.Course{
		Title: "Course B1", Status: "published", Level: "b1",
		DemoExerciseID: demoExID,
	}); !ok {
		t.Fatalf("update b1 course with demo exercise id failed")
	}
	return a2ID, b1ID, demoExID
}

func TestCoursesList_AddsLevelAndUnlockState(t *testing.T) {
	srv, repo, userLevels := newCoursesLevelTestServer(t)
	defer srv.Close()
	a2ID, b1ID, _ := seedCoursesByLevel(t, repo)

	if _, err := userLevels.SetUserLevel("user-learner-1", "a2"); err != nil {
		t.Fatalf("seed user level: %v", err)
	}

	status, body := get(t, srv, "/v1/courses", "dev-learner-token")
	if status != http.StatusOK {
		t.Fatalf("status = %d; body=%v", status, body)
	}
	courses, _ := body["data"].([]any)
	if len(courses) < 2 {
		t.Fatalf("expected at least 2 courses; got %d", len(courses))
	}
	byID := map[string]map[string]any{}
	for _, c := range courses {
		m := c.(map[string]any)
		byID[m["id"].(string)] = m
	}

	if got := byID[a2ID]["level"].(string); got != "a2" {
		t.Errorf("a2 course level = %q, want a2", got)
	}
	if got := byID[a2ID]["unlock_state"].(string); got != "unlocked" {
		t.Errorf("a2 unlock_state = %q, want unlocked", got)
	}
	if got := byID[b1ID]["level"].(string); got != "b1" {
		t.Errorf("b1 level = %q, want b1", got)
	}
	if got := byID[b1ID]["unlock_state"].(string); got != "demo" {
		t.Errorf("b1 unlock_state = %q, want demo (has demo_exercise_id)", got)
	}
}

func TestCoursesList_LevelQueryFilter(t *testing.T) {
	srv, repo, _ := newCoursesLevelTestServer(t)
	defer srv.Close()
	_, b1ID, _ := seedCoursesByLevel(t, repo)

	status, body := get(t, srv, "/v1/courses?level=b1", "dev-learner-token")
	if status != http.StatusOK {
		t.Fatalf("status = %d; body=%v", status, body)
	}
	courses, _ := body["data"].([]any)
	if len(courses) != 1 {
		t.Fatalf("expected exactly 1 course in level=b1; got %d", len(courses))
	}
	if courses[0].(map[string]any)["id"].(string) != b1ID {
		t.Errorf("got %v, want b1 course %q", courses[0], b1ID)
	}
}

func TestCourseByID_HasLevelAndDemoExerciseID(t *testing.T) {
	srv, repo, userLevels := newCoursesLevelTestServer(t)
	defer srv.Close()
	_, b1ID, demoID := seedCoursesByLevel(t, repo)

	if _, err := userLevels.SetUserLevel("user-learner-1", "a2"); err != nil {
		t.Fatalf("seed user level: %v", err)
	}

	status, body := get(t, srv, "/v1/courses/"+b1ID, "dev-learner-token")
	if status != http.StatusOK {
		t.Fatalf("status = %d; body=%v", status, body)
	}
	data := body["data"].(map[string]any)
	if data["level"].(string) != "b1" {
		t.Errorf("level = %v, want b1", data["level"])
	}
	if data["demo_exercise_id"].(string) != demoID {
		t.Errorf("demo_exercise_id = %v, want %s", data["demo_exercise_id"], demoID)
	}
	if data["unlock_state"].(string) != "demo" {
		t.Errorf("unlock_state = %v, want demo", data["unlock_state"])
	}
}

func TestExercise_InLockedCourse_403(t *testing.T) {
	srv, repo, userLevels := newCoursesLevelTestServer(t)
	defer srv.Close()
	_, b1ID, demoID := seedCoursesByLevel(t, repo)

	if _, err := userLevels.SetUserLevel("user-learner-1", "a2"); err != nil {
		t.Fatalf("seed user level: %v", err)
	}

	// Find the gated (non-demo) exercise inside the b1 course.
	mods := repo.ListModules("", b1ID)
	if len(mods) == 0 {
		t.Fatalf("no modules under b1 course")
	}
	exes := repo.ListExercises("")
	var gatedID string
	for _, ex := range exes {
		if ex.ModuleID == mods[0].ID && ex.ID != demoID {
			gatedID = ex.ID
			break
		}
	}
	if gatedID == "" {
		t.Fatalf("could not locate gated exercise")
	}

	status, body := get(t, srv, "/v1/exercises/"+gatedID, "dev-learner-token")
	if status != http.StatusForbidden {
		t.Fatalf("status = %d, want 403; body=%v", status, body)
	}
	if code := errCode(body); code != "level_locked" {
		t.Errorf("error.code = %q, want level_locked", code)
	}
}

func TestExercise_DemoExercise_Allowed(t *testing.T) {
	srv, repo, userLevels := newCoursesLevelTestServer(t)
	defer srv.Close()
	_, _, demoID := seedCoursesByLevel(t, repo)

	if _, err := userLevels.SetUserLevel("user-learner-1", "a2"); err != nil {
		t.Fatalf("seed user level: %v", err)
	}

	status, body := get(t, srv, "/v1/exercises/"+demoID, "dev-learner-token")
	if status != http.StatusOK {
		t.Fatalf("demo status = %d, want 200; body=%v", status, body)
	}
	data := body["data"].(map[string]any)
	if data["id"].(string) != demoID {
		t.Errorf("response id = %v, want %s", data["id"], demoID)
	}
}

func TestExercise_InLockedCourse_AllowedForOwnedMockExamSession(t *testing.T) {
	srv, repo, userLevels := newCoursesLevelTestServer(t)
	defer srv.Close()
	_, b1ID, demoID := seedCoursesByLevel(t, repo)

	if _, err := userLevels.SetUserLevel("user-learner-1", "a2"); err != nil {
		t.Fatalf("seed user level: %v", err)
	}

	gated := findGatedExerciseForCourse(t, repo, b1ID, demoID)
	mockTest, err := repo.CreateMockTest(contracts.MockTest{
		Title:  "B1 mock",
		Status: "published",
		Sections: []contracts.MockTestSection{{
			SequenceNo:   1,
			SkillKind:    gated.SkillKind,
			ExerciseID:   gated.ID,
			ExerciseType: gated.ExerciseType,
			MaxPoints:    5,
		}},
	})
	if err != nil {
		t.Fatalf("create mock test: %v", err)
	}
	session, err := repo.CreateMockExam("user-learner-1", mockTest.ID)
	if err != nil {
		t.Fatalf("create mock exam: %v", err)
	}

	status, body := get(t, srv, "/v1/exercises/"+gated.ID+"?mock_exam_session_id="+session.ID, "dev-learner-token")
	if status != http.StatusOK {
		t.Fatalf("status = %d, want 200; body=%v", status, body)
	}
	data := body["data"].(map[string]any)
	if data["id"].(string) != gated.ID {
		t.Errorf("response id = %v, want %s", data["id"], gated.ID)
	}
}

func TestExercise_InLockedCourse_RejectsBorrowedMockExamSession(t *testing.T) {
	srv, repo, userLevels := newCoursesLevelTestServer(t)
	defer srv.Close()
	_, b1ID, demoID := seedCoursesByLevel(t, repo)

	if _, err := userLevels.SetUserLevel("user-learner-1", "a2"); err != nil {
		t.Fatalf("seed user level: %v", err)
	}

	gated := findGatedExerciseForCourse(t, repo, b1ID, demoID)
	mockTest, err := repo.CreateMockTest(contracts.MockTest{
		Title:  "B1 mock",
		Status: "published",
		Sections: []contracts.MockTestSection{{
			SequenceNo:   1,
			SkillKind:    gated.SkillKind,
			ExerciseID:   gated.ID,
			ExerciseType: gated.ExerciseType,
			MaxPoints:    5,
		}},
	})
	if err != nil {
		t.Fatalf("create mock test: %v", err)
	}
	session, err := repo.CreateMockExam("user-someone-else", mockTest.ID)
	if err != nil {
		t.Fatalf("create mock exam: %v", err)
	}

	status, body := get(t, srv, "/v1/exercises/"+gated.ID+"?mock_exam_session_id="+session.ID, "dev-learner-token")
	if status != http.StatusForbidden {
		t.Fatalf("status = %d, want 403; body=%v", status, body)
	}
	if code := errCode(body); code != "level_locked" {
		t.Errorf("error.code = %q, want level_locked", code)
	}
}

func findGatedExerciseForCourse(t *testing.T, repo *store.MemoryStore, courseID, demoID string) contracts.Exercise {
	t.Helper()
	mods := repo.ListModules("", courseID)
	if len(mods) == 0 {
		t.Fatalf("no modules under course %s", courseID)
	}
	for _, ex := range repo.ListExercises("") {
		if ex.ModuleID == mods[0].ID && ex.ID != demoID {
			return ex
		}
	}
	t.Fatalf("could not locate gated exercise")
	return contracts.Exercise{}
}
