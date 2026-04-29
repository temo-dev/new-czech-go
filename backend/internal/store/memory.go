package store

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

type MemoryStore struct {
	mu             sync.RWMutex
	usersByToken   map[string]contracts.User
	tokenExpiry    map[string]time.Time // only set for dynamically issued tokens
	adminEmail     string
	adminPassword  string
	plan           contracts.LearningPlan
	courses        CourseStore
	modules        ModuleStore
	skills         SkillStore
	exercises      ExerciseStore
	attempts       AttemptStore
	mockExams      MockExamStore
	mockTests      MockTestStore
	exerciseAudio  map[string]contracts.ExerciseAudio // exercise_id → audio
	fullExamStore  FullExamStore                      // Postgres-backed when available
	vocabulary     VocabularyStore
	grammar        GrammarStore
	generationJobs GenerationJobStore
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

	return &MemoryStore{
		adminEmail:    adminEmail,
		adminPassword: adminPassword,
		tokenExpiry:   map[string]time.Time{},
		usersByToken: map[string]contracts.User{
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
			// dev-admin-token stays valid for backward compat (tests, local CMS dev)
			"dev-admin-token": {
				ID:                "user-admin-1",
				Role:              "admin",
				Email:             "admin@example.com",
				DisplayName:       "CMS Admin",
				PreferredLanguage: "vi",
			},
		},
		plan: contracts.LearningPlan{
			StartDate:  time.Now().Format("2006-01-02"),
			CurrentDay: 1,
			Status:     "active",
		},
		courses:   newMemoryCourseStore(seedCourses()),
		modules:   newMemoryModuleStore(seedDailyPlanModules()),
		skills:    newMemorySkillStore(seedSkills(seedDailyPlanModules())),
		exercises: exercises,
		attempts:  attempts,
		mockExams:      newMemoryMockExamStore(exercises, attempts),
		mockTests:      newMemoryMockTestStore(),
		exerciseAudio: map[string]contracts.ExerciseAudio{},
		fullExamStore: newMemoryFullExamStore(),
		vocabulary:    newMemoryVocabularyStore(),
		grammar:        newMemoryGrammarStore(),
		generationJobs: newMemoryGenerationJobStore(),
	}
}

func (s *MemoryStore) Login(email, password string) (string, contracts.User, bool) {
	email = strings.ToLower(strings.TrimSpace(email))

	// Admin login — credentials from env (fallback: admin@example.com / demo123)
	if email == strings.ToLower(s.adminEmail) && password == s.adminPassword {
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

// Skill CRUD
func (s *MemoryStore) SkillsByModule(moduleID string) []contracts.Skill {
	return s.skills.SkillsByModule(moduleID)
}
func (s *MemoryStore) AdminSkillsByModule(moduleID string) []contracts.Skill {
	return s.skills.AdminSkillsByModule(moduleID)
}
func (s *MemoryStore) AllAdminSkills() []contracts.Skill {
	return s.skills.AllAdminSkills()
}
func (s *MemoryStore) SkillByID(id string) (contracts.Skill, bool) {
	return s.skills.SkillByID(id)
}
func (s *MemoryStore) CreateSkill(sk contracts.Skill) (contracts.Skill, error) {
	return s.skills.CreateSkill(sk)
}
func (s *MemoryStore) UpdateSkill(id string, update contracts.Skill) (contracts.Skill, bool) {
	return s.skills.UpdateSkill(id, update)
}
func (s *MemoryStore) DeleteSkill(id string) bool {
	return s.skills.DeleteSkill(id)
}

// ExercisesBySkill returns published exercises for a skill (pool=course).
func (s *MemoryStore) ExercisesBySkill(skillID string) []contracts.Exercise {
	s.mu.RLock()
	defer s.mu.RUnlock()
	all := s.exercises.ListExercises("course")
	var out []contracts.Exercise
	for _, ex := range all {
		if ex.SkillID == skillID && ex.Status == "published" {
			out = append(out, ex)
		}
	}
	return out
}

func (s *MemoryStore) ExercisesByModule(moduleID string) []contracts.Exercise {
	skills := s.skills.SkillsByModule(moduleID)
	skillIDs := make(map[string]bool, len(skills))
	for _, sk := range skills {
		skillIDs[sk.ID] = true
	}
	all := s.exercises.ListExercises("")
	out := make([]contracts.Exercise, 0)
	for _, ex := range all {
		if skillIDs[ex.SkillID] && ex.Status == "published" {
			out = append(out, ex)
		}
	}
	return out
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

func (s *MemoryStore) SetSkillStore(ss SkillStore) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.skills = ss
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
func (s *MemoryStore) ListVocabularyItems(setID string) []contracts.VocabularyItem {
	return s.vocabulary.ListVocabularyItems(setID)
}
func (s *MemoryStore) DeleteVocabularyItem(id string) bool {
	return s.vocabulary.DeleteVocabularyItem(id)
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

// FullExamSession methods — delegate to fullExamStore (memory or Postgres)

func (s *MemoryStore) SetFullExamStore(store FullExamStore) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.fullExamStore = store
}

func (s *MemoryStore) FullExamSession(id string) (*contracts.FullExamSession, bool) {
	sess, ok := s.fullExamStore.GetFullExamSession(id)
	if !ok {
		return nil, false
	}
	return &sess, true
}

func (s *MemoryStore) SetFullExamSession(session contracts.FullExamSession) {
	s.fullExamStore.SetFullExamSession(session)
}

func (s *MemoryStore) ListFullExamSessions(learnerID string) []contracts.FullExamSession {
	return s.fullExamStore.ListFullExamSessions(learnerID)
}

// ExerciseAudio methods

func (s *MemoryStore) ExerciseAudioByExercise(exerciseID string) (*contracts.ExerciseAudio, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	a, ok := s.exerciseAudio[exerciseID]
	if !ok {
		return nil, false
	}
	cp := a
	return &cp, true
}

func (s *MemoryStore) SetExerciseAudio(exerciseID string, audio contracts.ExerciseAudio) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.exerciseAudio[exerciseID] = audio
}

func rollupReadiness(levels []string) (string, string) {
	if len(levels) == 0 {
		return "not_ready", "Chưa có đủ feedback để đánh giá."
	}
	score := map[string]int{
		"ready":      3,
		"almost":     2,
		"needs_work": 1,
		"not_ready":  0,
	}
	total := 0
	for _, lv := range levels {
		total += score[lv]
	}
	avg := float64(total) / float64(len(levels))
	var overall, summary string
	switch {
	case avg >= 2.5:
		overall = "ready"
		summary = "Bạn đã sẵn sàng cho bài thi! Cả 4 phần đều đạt yêu cầu."
	case avg >= 1.5:
		overall = "almost"
		summary = "Gần đến rồi! Ôn thêm một vài phần và bạn sẽ sẵn sàng."
	case avg >= 0.75:
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

