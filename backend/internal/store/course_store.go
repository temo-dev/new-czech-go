package store

import (
	"fmt"
	"sync"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

type CourseStore interface {
	ListCourses(status string) []contracts.Course
	CourseByID(id string) (contracts.Course, bool)
	CreateCourse(c contracts.Course) (contracts.Course, error)
	UpdateCourse(id string, update contracts.Course) (contracts.Course, bool)
	DeleteCourse(id string) bool
	SetCourseBannerImage(id, storageKey string) bool
}

type memoryCourseStore struct {
	mu     sync.RWMutex
	courses map[string]*contracts.Course
	nextID  int
}

func newMemoryCourseStore(seed []contracts.Course) CourseStore {
	m := &memoryCourseStore{
		courses: make(map[string]*contracts.Course, len(seed)),
		nextID:  len(seed) + 1,
	}
	for _, c := range seed {
		cp := c
		m.courses[c.ID] = &cp
	}
	return m
}

func (s *memoryCourseStore) ListCourses(status string) []contracts.Course {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]contracts.Course, 0, len(s.courses))
	for _, c := range s.courses {
		if status == "" || c.Status == status {
			out = append(out, *c)
		}
	}
	return out
}

func (s *memoryCourseStore) CourseByID(id string) (contracts.Course, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	c, ok := s.courses[id]
	if !ok {
		return contracts.Course{}, false
	}
	return *c, true
}

func (s *memoryCourseStore) CreateCourse(c contracts.Course) (contracts.Course, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	c.ID = fmt.Sprintf("course-%d", s.nextID)
	s.nextID++
	if c.Status == "" {
		c.Status = "draft"
	}
	cp := c
	s.courses[c.ID] = &cp
	return cp, nil
}

func (s *memoryCourseStore) UpdateCourse(id string, update contracts.Course) (contracts.Course, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	existing, ok := s.courses[id]
	if !ok {
		return contracts.Course{}, false
	}
	if update.Title != "" {
		existing.Title = update.Title
	}
	if update.Description != "" {
		existing.Description = update.Description
	}
	if update.Status != "" {
		existing.Status = update.Status
	}
	if update.SequenceNo != 0 {
		existing.SequenceNo = update.SequenceNo
	}
	return *existing, true
}

func (s *memoryCourseStore) DeleteCourse(id string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, ok := s.courses[id]
	if !ok {
		return false
	}
	delete(s.courses, id)
	return true
}

func (s *memoryCourseStore) SetCourseBannerImage(id, storageKey string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	c, ok := s.courses[id]
	if !ok {
		return false
	}
	c.BannerImageID = storageKey
	return true
}

func seedCourses() []contracts.Course {
	return []contracts.Course{
		{
			ID:          "course-a2-mluveni",
			Slug:        "a2-mluveni-sprint",
			Title:       "A2 Mluveni Sprint",
			Description: "Luyện thi nói A2 cho kỳ thi trvaly pobyt. 4 kỹ năng nói theo chuẩn Modelový test.",
			Status:      "published",
			SequenceNo:  1,
		},
		{
			ID:          "course-giao-tiep",
			Slug:        "giao-tiep-co-ban",
			Title:       "Giao tiếp cơ bản",
			Description: "Tiếng Czech giao tiếp hàng ngày: mua sắm, đi lại, hỏi đường, bưu điện.",
			Status:      "published",
			SequenceNo:  2,
		},
	}
}
