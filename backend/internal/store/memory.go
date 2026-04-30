package store

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"log"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
	"golang.org/x/crypto/bcrypt"
)

type MemoryStore struct {
	mu                 sync.RWMutex
	usersByToken       map[string]contracts.User
	tokenExpiry        map[string]time.Time // only set for dynamically issued tokens
	adminEmail         string
	adminPassword      string
	plan               contracts.LearningPlan
	courses            CourseStore
	modules            ModuleStore
	exercises          ExerciseStore
	attempts           AttemptStore
	mockExams          MockExamStore
	mockTests          MockTestStore
	exerciseAudioStore ExerciseAudioStore // Postgres-backed when available
	vocabulary         VocabularyStore
	grammar            GrammarStore
	generationJobs     GenerationJobStore
}

func NewMemoryStore() *MemoryStore {
	return NewMemoryStoreWithStores(newMemoryAttemptStore(), newMemoryExerciseStore(seedExercises()))
}

func NewMemoryStoreWithAttemptStore(attempts AttemptStore) *MemoryStore {
	return NewMemoryStoreWithStores(attempts, newMemoryExerciseStore(seedExercises()))
}

func NewMemoryStoreWithStores(attempts AttemptStore, exercises ExerciseStore) *MemoryStore {
	if attempts == nil {
		attempts = newMemoryAttemptStore()
	}
	if exercises == nil {
		exercises = newMemoryExerciseStore(seedExercises())
	}

	adminEmail := strings.TrimSpace(os.Getenv("ADMIN_EMAIL"))
	if adminEmail == "" {
		adminEmail = "admin@example.com"
	}
	adminPassword := strings.TrimSpace(os.Getenv("ADMIN_PASSWORD"))
	if adminPassword == "" {
		adminPassword = "demo123"
	}
	if os.Getenv("ENV") == "production" && (adminPassword == "" || adminPassword == "demo123") {
		log.Fatal("ADMIN_PASSWORD must be set to a strong value in production (not empty or 'demo123')")
	}

	devTokens := map[string]contracts.User{}
	if os.Getenv("ENV") != "production" {
		devTokens = map[string]contracts.User{
			"dev-learner-token": {
				ID:                "user-learner-1",
				Role:              "learner",
				Email:             "learner@example.com",
				DisplayName:       "Nguyen An",
				PreferredLanguage: "vi",
			},
			"dev-learner-2-token": {
				ID:                "user-learner-2",
				Role:              "learner",
				Email:             "learner2@example.com",
				DisplayName:       "Tran Binh",
				PreferredLanguage: "vi",
			},
			"dev-admin-token": {
				ID:                "user-admin-1",
				Role:              "admin",
				Email:             "admin@example.com",
				DisplayName:       "CMS Admin",
				PreferredLanguage: "vi",
			},
		}
	}

	return &MemoryStore{
		adminEmail:    adminEmail,
		adminPassword: adminPassword,
		tokenExpiry:   map[string]time.Time{},
		usersByToken:  devTokens,
		plan: contracts.LearningPlan{
			StartDate:  time.Now().Format("2006-01-02"),
			CurrentDay: 1,
			Status:     "active",
		},
		courses:   newMemoryCourseStore(seedCourses()),
		modules:   newMemoryModuleStore(seedDailyPlanModules()),
		exercises: exercises,
		attempts:           attempts,
		mockExams:          newMemoryMockExamStore(exercises, attempts),
		mockTests:          newMemoryMockTestStore(),
		exerciseAudioStore: newMemoryExerciseAudioStore(),
		vocabulary:         newMemoryVocabularyStore(),
		grammar:            newMemoryGrammarStore(),
		generationJobs:     newMemoryGenerationJobStore(),
	}
}

// checkAdminPassword verifies a candidate password against the stored value.
// If the stored value is a bcrypt hash (starts with $2), uses bcrypt comparison.
// Otherwise falls back to direct string comparison (development convenience only).
func (s *MemoryStore) checkAdminPassword(candidate string) bool {
	stored := s.adminPassword
	if strings.HasPrefix(stored, "$2") {
		return bcrypt.CompareHashAndPassword([]byte(stored), []byte(candidate)) == nil
	}
	return stored == candidate
}

func (s *MemoryStore) Login(email, password string) (string, contracts.User, bool) {
	email = strings.ToLower(strings.TrimSpace(email))

	// Admin login — credentials from env.
	// ADMIN_PASSWORD may be a bcrypt hash ($2a$/b$/y$ prefix) or plaintext (dev only).
	if email == strings.ToLower(s.adminEmail) && s.checkAdminPassword(password) {
		token := newRandomToken()
		user := contracts.User{
			ID:                "user-admin-1",
			Role:              "admin",
			Email:             s.adminEmail,
			DisplayName:       "CMS Admin",
			PreferredLanguage: "vi",
		}
		s.mu.Lock()
		s.usersByToken[token] = user
		s.tokenExpiry[token] = time.Now().Add(24 * time.Hour)
		s.mu.Unlock()
		return token, user, true
	}

	// Learner dev login (static tokens, no expiry)
	switch email {
	case "learner@example.com":
		if password == "demo123" {
			return "dev-learner-token", s.usersByToken["dev-learner-token"], true
		}
	case "learner2@example.com":
		if password == "demo123" {
			return "dev-learner-2-token", s.usersByToken["dev-learner-2-token"], true
		}
	}

	return "", contracts.User{}, false
}

func (s *MemoryStore) UserByToken(token string) (contracts.User, bool) {
	s.mu.RLock()
	expiry, hasExpiry := s.tokenExpiry[token]
	user, ok := s.usersByToken[token]
	s.mu.RUnlock()

	if !ok {
		return contracts.User{}, false
	}
	if hasExpiry && time.Now().After(expiry) {
		s.mu.Lock()
		delete(s.usersByToken, token)
		delete(s.tokenExpiry, token)
		s.mu.Unlock()
		return contracts.User{}, false
	}
	return user, true
}

func newRandomToken() string {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return fmt.Sprintf("token-%d", time.Now().UnixNano())
	}
	return hex.EncodeToString(b)
}

func (s *MemoryStore) Course() contracts.Course {
	// backward compat: return first published course
	all := s.courses.ListCourses("published")
	if len(all) > 0 {
		return all[0]
	}
	return contracts.Course{ID: "course-a2-mluveni", Slug: "a2-mluveni-sprint", Title: "A2 Mluveni Sprint"}
}

func (s *MemoryStore) Plan() contracts.LearningPlan {
	return s.plan
}

// Modules returns modules filtered by kind. Kept for backward compat.
func (s *MemoryStore) Modules(kind string) []contracts.Module {
	return s.modules.ListModules(kind, "")
}

// Course CRUD
func (s *MemoryStore) ListCourses(status string) []contracts.Course {
	return s.courses.ListCourses(status)
}
func (s *MemoryStore) CourseByID(id string) (contracts.Course, bool) {
	return s.courses.CourseByID(id)
}
func (s *MemoryStore) CreateCourse(c contracts.Course) (contracts.Course, error) {
	return s.courses.CreateCourse(c)
}
func (s *MemoryStore) UpdateCourse(id string, update contracts.Course) (contracts.Course, bool) {
	return s.courses.UpdateCourse(id, update)
}
func (s *MemoryStore) DeleteCourse(id string) bool {
	return s.courses.DeleteCourse(id)
}

// Module CRUD
func (s *MemoryStore) ListModules(kind, courseID string) []contracts.Module {
	return s.modules.ListModules(kind, courseID)
}
func (s *MemoryStore) ModuleByID(id string) (contracts.Module, bool) {
	return s.modules.ModuleByID(id)
}
func (s *MemoryStore) CreateModule(m contracts.Module) (contracts.Module, error) {
	return s.modules.CreateModule(m)
}
func (s *MemoryStore) UpdateModule(id string, update contracts.Module) (contracts.Module, bool) {
	return s.modules.UpdateModule(id, update)
}
func (s *MemoryStore) DeleteModule(id string) bool {
	return s.modules.DeleteModule(id)
}

func (s *MemoryStore) ExercisesByModule(moduleID string) []contracts.Exercise {
	return s.exercises.ExercisesByModule(moduleID)
}

func (s *MemoryStore) SkillSummariesByModule(moduleID string) []contracts.SkillSummary {
	return s.exercises.SkillSummariesByModule(moduleID)
}

func (s *MemoryStore) ListExercises(pool string) []contracts.Exercise {
	return s.exercises.ListExercises(pool)
}

func (s *MemoryStore) Exercise(id string) (contracts.Exercise, bool) {
	return s.exercises.Exercise(id)
}

func (s *MemoryStore) CreateExercise(exercise contracts.Exercise) contracts.Exercise {
	return s.exercises.CreateExercise(exercise)
}

func (s *MemoryStore) UpdateExercise(id string, update contracts.Exercise) (contracts.Exercise, bool) {
	return s.exercises.UpdateExercise(id, update)
}

func (s *MemoryStore) DeleteExercise(id string) bool {
	return s.exercises.DeleteExercise(id)
}

func (s *MemoryStore) CreateAttempt(userID, exerciseID, clientPlatform, appVersion, locale string) (*contracts.Attempt, error) {
	s.mu.RLock()
	exercise, ok := s.exercises.Exercise(exerciseID)
	s.mu.RUnlock()
	if !ok {
		return nil, fmt.Errorf("exercise not found")
	}
	if locale == "" {
		locale = contracts.DefaultLocale
	}
	return s.attempts.CreateAttempt(userID, exerciseID, exercise.ExerciseType, clientPlatform, appVersion, locale)
}

func (s *MemoryStore) UpdateAttemptRecordingStarted(id string, timestamp string) (*contracts.Attempt, bool) {
	return s.attempts.UpdateAttemptRecordingStarted(id, timestamp)
}

func (s *MemoryStore) RecordUploadTargetIssued(id, storageKey string) (*contracts.Attempt, bool) {
	return s.attempts.RecordUploadTargetIssued(id, storageKey)
}

func (s *MemoryStore) MarkUploadComplete(id string, audio contracts.AttemptAudio) (*contracts.Attempt, bool) {
	return s.attempts.MarkUploadComplete(id, audio)
}

func (s *MemoryStore) SetAttemptStatus(id, status string) {
	s.attempts.SetAttemptStatus(id, status)
}

func (s *MemoryStore) CompleteAttempt(id string, transcript contracts.Transcript, feedback contracts.AttemptFeedback) {
	s.attempts.CompleteAttempt(id, transcript, feedback)
}

func (s *MemoryStore) UpsertReviewArtifact(id string, artifact contracts.AttemptReviewArtifact) (*contracts.AttemptReviewArtifact, bool) {
	return s.attempts.UpsertReviewArtifact(id, artifact)
}

func (s *MemoryStore) ReviewArtifact(id string) (*contracts.AttemptReviewArtifact, bool) {
	return s.attempts.ReviewArtifact(id)
}

func (s *MemoryStore) FailAttempt(id, failureCode string) {
	s.attempts.FailAttempt(id, failureCode)
}

func (s *MemoryStore) Attempt(id string) (*contracts.Attempt, bool) {
	return s.attempts.Attempt(id)
}

func (s *MemoryStore) ListAttempts() []contracts.Attempt {
	return s.attempts.ListAttempts()
}

func (s *MemoryStore) SetCourseStore(cs CourseStore) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.courses = cs
}

func (s *MemoryStore) SetModuleStore(ms ModuleStore) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.modules = ms
}

func (s *MemoryStore) SetMockExamStore(ms MockExamStore) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.mockExams = ms
}

func (s *MemoryStore) SetMockTestStore(ms MockTestStore) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.mockTests = ms
}

func (s *MemoryStore) SetVocabularyStore(vs VocabularyStore) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.vocabulary = vs
}

func (s *MemoryStore) SetGrammarStore(gs GrammarStore) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.grammar = gs
}

func (s *MemoryStore) SetGenerationJobStore(gjs GenerationJobStore) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.generationJobs = gjs
}

// Vocabulary delegates
func (s *MemoryStore) CreateVocabularySet(set contracts.VocabularySet) (contracts.VocabularySet, error) {
	return s.vocabulary.CreateVocabularySet(set)
}
func (s *MemoryStore) GetVocabularySet(id string) (contracts.VocabularySet, bool) {
	return s.vocabulary.GetVocabularySet(id)
}
func (s *MemoryStore) ListVocabularySets(skillID string) []contracts.VocabularySet {
	return s.vocabulary.ListVocabularySets(skillID)
}
func (s *MemoryStore) UpdateVocabularySet(id string, update contracts.VocabularySet) (contracts.VocabularySet, bool) {
	return s.vocabulary.UpdateVocabularySet(id, update)
}
func (s *MemoryStore) DeleteVocabularySet(id string) bool {
	return s.vocabulary.DeleteVocabularySet(id)
}
func (s *MemoryStore) CreateVocabularyItem(item contracts.VocabularyItem) contracts.VocabularyItem {
	return s.vocabulary.CreateVocabularyItem(item)
}
func (s *MemoryStore) GetVocabularyItem(id string) (contracts.VocabularyItem, bool) {
	return s.vocabulary.GetVocabularyItem(id)
}
func (s *MemoryStore) ListVocabularyItems(setID string) []contracts.VocabularyItem {
	return s.vocabulary.ListVocabularyItems(setID)
}
func (s *MemoryStore) DeleteVocabularyItem(id string) bool {
	return s.vocabulary.DeleteVocabularyItem(id)
}
func (s *MemoryStore) SetVocabularyItemImage(id, storageKey string) bool {
	return s.vocabulary.SetVocabularyItemImage(id, storageKey)
}

// Grammar delegates
func (s *MemoryStore) CreateGrammarRule(rule contracts.GrammarRule) (contracts.GrammarRule, error) {
	return s.grammar.CreateGrammarRule(rule)
}
func (s *MemoryStore) GetGrammarRule(id string) (contracts.GrammarRule, bool) {
	return s.grammar.GetGrammarRule(id)
}
func (s *MemoryStore) ListGrammarRules(skillID string) []contracts.GrammarRule {
	return s.grammar.ListGrammarRules(skillID)
}
func (s *MemoryStore) UpdateGrammarRule(id string, update contracts.GrammarRule) (contracts.GrammarRule, bool) {
	return s.grammar.UpdateGrammarRule(id, update)
}
func (s *MemoryStore) DeleteGrammarRule(id string) bool {
	return s.grammar.DeleteGrammarRule(id)
}
func (s *MemoryStore) SetGrammarRuleImage(id, storageKey string) bool {
	return s.grammar.SetGrammarRuleImage(id, storageKey)
}

// GenerationJob delegates
func (s *MemoryStore) CreateGenerationJob(job contracts.ContentGenerationJob) contracts.ContentGenerationJob {
	return s.generationJobs.CreateJob(job)
}
func (s *MemoryStore) GetGenerationJob(id string) (contracts.ContentGenerationJob, bool) {
	return s.generationJobs.GetJob(id)
}
func (s *MemoryStore) UpdateGenerationJobRunning(id string) {
	s.generationJobs.UpdateJobRunning(id)
}
func (s *MemoryStore) UpdateGenerationJobGenerated(id string, payload []byte, inputTokens, outputTokens int, costUSD float64, durationMs int) {
	s.generationJobs.UpdateJobGenerated(id, payload, inputTokens, outputTokens, costUSD, durationMs)
}
func (s *MemoryStore) UpdateGenerationJobFailed(id string, errMsg string) {
	s.generationJobs.UpdateJobFailed(id, errMsg)
}
func (s *MemoryStore) UpdateGenerationJobDraft(id string, editedPayload []byte) bool {
	return s.generationJobs.UpdateJobDraft(id, editedPayload)
}
func (s *MemoryStore) UpdateGenerationJobPublished(id string) bool {
	return s.generationJobs.UpdateJobPublished(id)
}
func (s *MemoryStore) UpdateGenerationJobRejected(id string) bool {
	return s.generationJobs.UpdateJobRejected(id)
}
func (s *MemoryStore) FindActiveGenerationJob(requestedBy, moduleID string) (contracts.ContentGenerationJob, bool) {
	return s.generationJobs.FindActiveJob(requestedBy, moduleID)
}
func (s *MemoryStore) MarkAllRunningJobsFailed(errMsg string) {
	s.generationJobs.MarkAllRunningFailed(errMsg)
}

func (s *MemoryStore) CreateMockExam(learnerID, mockTestID string) (contracts.MockExamSession, error) {
	return s.mockExams.CreateMockExam(learnerID, mockTestID, s.mockTests)
}

// MockTest CRUD methods
func (s *MemoryStore) CreateMockTest(t contracts.MockTest) (contracts.MockTest, error) {
	return s.mockTests.CreateMockTest(t)
}
func (s *MemoryStore) MockTestByID(id string) (contracts.MockTest, bool) {
	return s.mockTests.MockTestByID(id)
}
func (s *MemoryStore) ListMockTests(statusFilter string) []contracts.MockTest {
	return s.mockTests.ListMockTests(statusFilter)
}
func (s *MemoryStore) UpdateMockTest(id string, update contracts.MockTest) (contracts.MockTest, bool) {
	return s.mockTests.UpdateMockTest(id, update)
}
func (s *MemoryStore) DeleteMockTest(id string) bool {
	return s.mockTests.DeleteMockTest(id)
}

func (s *MemoryStore) MockExamByID(id string) (contracts.MockExamSession, bool) {
	return s.mockExams.MockExamByID(id)
}

func (s *MemoryStore) AdvanceMockExam(id, attemptID string) (contracts.MockExamSession, error) {
	return s.mockExams.AdvanceMockExam(id, attemptID)
}

func (s *MemoryStore) CompleteMockExam(id string) (contracts.MockExamSession, error) {
	return s.mockExams.CompleteMockExam(id)
}

// ExerciseAudio methods — delegate to exerciseAudioStore (memory or Postgres)

func (s *MemoryStore) SetExerciseAudioStore(store ExerciseAudioStore) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.exerciseAudioStore = store
}

func (s *MemoryStore) ExerciseAudioByExercise(exerciseID string) (*contracts.ExerciseAudio, bool) {
	return s.exerciseAudioStore.ExerciseAudioByExercise(exerciseID)
}

func (s *MemoryStore) SetExerciseAudio(exerciseID string, audio contracts.ExerciseAudio) {
	s.exerciseAudioStore.SetExerciseAudio(exerciseID, audio)
}

func rollupReadiness(levels []string) (string, string) {
	if len(levels) == 0 {
		return "not_ready", "Chưa có đủ feedback để đánh giá."
	}
	total := 0.0
	for _, lv := range levels {
		total += readinessToFraction(lv)
	}
	avg := float64(total) / float64(len(levels))
	var overall, summary string
	switch {
	case avg >= 0.875:
		overall = "ready"
		summary = "Bạn đã sẵn sàng cho bài thi! Cả 4 phần đều đạt yêu cầu."
	case avg >= 0.625:
		overall = "almost"
		summary = "Gần đến rồi! Ôn thêm một vài phần và bạn sẽ sẵn sàng."
	case avg >= 0.375:
		overall = "needs_work"
		summary = "Cần luyện thêm. Hãy ôn lại các phần chưa đạt trước khi thi."
	default:
		overall = "not_ready"
		summary = "Chưa sẵn sàng. Cần luyện tập thêm các phần cơ bản."
	}
	return overall, summary
}

func firstPublishedExerciseByType(items []contracts.Exercise, kind string) contracts.Exercise {
	for _, ex := range items {
		if ex.ExerciseType == kind && ex.Status == "published" {
			return ex
		}
	}
	return contracts.Exercise{}
}

func seedDailyPlanModules() []contracts.Module {
	days := []struct {
		title       string
		description string
	}{
		{"Day 1 · Uloha 1", "Chu de: Gia dinh. Tap tra loi cau hoi ngan."},
		{"Day 2 · Uloha 1", "Chu de: Cong viec. Luyen cau tra loi ro y."},
		{"Day 3 · Uloha 1", "Chu de: Thoi gian ranh. Tap noi tu tin hon."},
		{"Day 4 · Uloha 1", "Chu de: An uong. On lai cau truc co ban."},
		{"Day 5 · Uloha 2", "Scenario: Tren buu dien. Hoi du thong tin."},
		{"Day 6 · Uloha 2", "Scenario: O phong mach bac si. Dat cau hoi ro rang."},
		{"Day 7 · Uloha 2", "Scenario: Thue can ho. Luyen cau hoi da dang."},
		{"Day 8 · Uloha 3", "Story: Cuoi tuan trong cong vien. Ke theo tranh."},
		{"Day 9 · Uloha 3", "Story: Di cho. Dung nejdriv/pak/nakonec."},
		{"Day 10 · Uloha 3", "Story: Mot ngay o truong. Chu y thi qua khu."},
		{"Day 11 · Uloha 4", "Scenario: Chon diem du lich. Giai thich ly do."},
		{"Day 12 · Uloha 4", "Scenario: Chon mon an. Dung 'protoze'."},
		{"Day 13 · On tap", "Quay lai bai yeu nhat. Ghi am 1 lan cho moi Uloha."},
		{"Day 14 · Ready check", "Luyen toc do va su ro rang truoc mock exam."},
	}
	mods := make([]contracts.Module, 0, len(days)+1)
	for i, d := range days {
		seq := i + 1
		mods = append(mods, contracts.Module{
			ID:          fmt.Sprintf("module-day-%d", seq),
			CourseID:    "course-a2-mluveni",
			Slug:        fmt.Sprintf("day-%d", seq),
			Title:       d.title,
			ModuleKind:  "daily_plan",
			SequenceNo:  seq,
			Description: d.description,
			Status:      "published",
		})
	}
	mods = append(mods, contracts.Module{
		ID:          "module-mock",
		Slug:        "mock-1",
		Title:       "Mock Oral Exam",
		ModuleKind:  "mock_exam",
		SequenceNo:  len(days) + 1,
		Description: "Bai thi noi tong hop sau 14 ngay.",
	})
	return mods
}
