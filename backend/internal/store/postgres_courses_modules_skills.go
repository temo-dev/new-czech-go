package store

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"sort"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// ── Course ─────────────────────────────────────────────────────────────────────

type postgresCourseStore struct{ db *sql.DB }

func NewPostgresCourseStore(databaseURL string) (CourseStore, error) {
	db, err := openPostgresDB(databaseURL)
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if _, err := db.ExecContext(ctx, `
CREATE TABLE IF NOT EXISTS courses (
	id          TEXT        PRIMARY KEY,
	slug        TEXT        NOT NULL DEFAULT '',
	title       TEXT        NOT NULL,
	description TEXT        NOT NULL DEFAULT '',
	status      TEXT        NOT NULL DEFAULT 'draft',
	sequence_no INTEGER     NOT NULL DEFAULT 0,
	created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
	updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
)`); err != nil {
		db.Close()
		return nil, fmt.Errorf("ensure courses schema: %w", err)
	}
	return &postgresCourseStore{db: db}, nil
}

func (s *postgresCourseStore) ListCourses(status string) []contracts.Course {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	q := `SELECT id, slug, title, description, status, sequence_no FROM courses`
	args := []any{}
	if status != "" {
		q += ` WHERE status = $1`
		args = append(args, status)
	}
	q += ` ORDER BY sequence_no ASC, created_at ASC`
	rows, err := s.db.QueryContext(ctx, q, args...)
	if err != nil {
		return nil
	}
	defer rows.Close()
	var out []contracts.Course
	for rows.Next() {
		var c contracts.Course
		if err := rows.Scan(&c.ID, &c.Slug, &c.Title, &c.Description, &c.Status, &c.SequenceNo); err == nil {
			out = append(out, c)
		}
	}
	if err := rows.Err(); err != nil {
		log.Printf("postgresCourseStore.ListCourses rows error: %v", err)
		return nil
	}
	return out
}

func (s *postgresCourseStore) CourseByID(id string) (contracts.Course, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	var c contracts.Course
	err := s.db.QueryRowContext(ctx,
		`SELECT id, slug, title, description, status, sequence_no FROM courses WHERE id = $1`, id,
	).Scan(&c.ID, &c.Slug, &c.Title, &c.Description, &c.Status, &c.SequenceNo)
	if err != nil {
		return contracts.Course{}, false
	}
	return c, true
}

func (s *postgresCourseStore) CreateCourse(c contracts.Course) (contracts.Course, error) {
	if c.ID == "" {
		c.ID = "course-" + newUUIDLikeID()
	}
	if c.Status == "" {
		c.Status = "draft"
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_, err := s.db.ExecContext(ctx,
		`INSERT INTO courses (id, slug, title, description, status, sequence_no)
		 VALUES ($1,$2,$3,$4,$5,$6)
		 ON CONFLICT (id) DO NOTHING`,
		c.ID, c.Slug, c.Title, c.Description, c.Status, c.SequenceNo,
	)
	if err != nil {
		return contracts.Course{}, err
	}
	created, ok := s.CourseByID(c.ID)
	if !ok {
		return contracts.Course{}, fmt.Errorf("course not found after insert")
	}
	return created, nil
}

func (s *postgresCourseStore) UpdateCourse(id string, update contracts.Course) (contracts.Course, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_, err := s.db.ExecContext(ctx,
		`UPDATE courses SET
			slug        = CASE WHEN $2 <> '' THEN $2 ELSE slug END,
			title       = CASE WHEN $3 <> '' THEN $3 ELSE title END,
			description = CASE WHEN $4 <> '' THEN $4 ELSE description END,
			status      = CASE WHEN $5 <> '' THEN $5 ELSE status END,
			sequence_no = CASE WHEN $6 <> 0  THEN $6 ELSE sequence_no END,
			updated_at  = now()
		 WHERE id = $1`,
		id, update.Slug, update.Title, update.Description, update.Status, update.SequenceNo,
	)
	if err != nil {
		return contracts.Course{}, false
	}
	return s.CourseByID(id)
}

func (s *postgresCourseStore) DeleteCourse(id string) bool {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	res, err := s.db.ExecContext(ctx, `DELETE FROM courses WHERE id = $1`, id)
	if err != nil {
		return false
	}
	n, _ := res.RowsAffected()
	return n > 0
}

// ── Module ─────────────────────────────────────────────────────────────────────

type postgresModuleStore struct{ db *sql.DB }

func NewPostgresModuleStore(databaseURL string) (ModuleStore, error) {
	db, err := openPostgresDB(databaseURL)
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if _, err := db.ExecContext(ctx, `
CREATE TABLE IF NOT EXISTS modules (
	id          TEXT        PRIMARY KEY,
	course_id   TEXT        NOT NULL DEFAULT '',
	slug        TEXT        NOT NULL DEFAULT '',
	title       TEXT        NOT NULL,
	description TEXT        NOT NULL DEFAULT '',
	module_kind TEXT        NOT NULL DEFAULT 'daily_plan',
	sequence_no INTEGER     NOT NULL DEFAULT 0,
	status      TEXT        NOT NULL DEFAULT 'draft',
	created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
	updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
)`); err != nil {
		db.Close()
		return nil, fmt.Errorf("ensure modules schema: %w", err)
	}
	return &postgresModuleStore{db: db}, nil
}

func (s *postgresModuleStore) ListModules(kind, courseID string) []contracts.Module {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	q := `SELECT id, course_id, slug, title, description, module_kind, sequence_no, status FROM modules WHERE 1=1`
	args := []any{}
	if kind != "" {
		args = append(args, kind)
		q += fmt.Sprintf(` AND module_kind = $%d`, len(args))
	}
	if courseID != "" {
		args = append(args, courseID)
		q += fmt.Sprintf(` AND course_id = $%d`, len(args))
	}
	q += ` ORDER BY sequence_no ASC, created_at ASC`
	rows, err := s.db.QueryContext(ctx, q, args...)
	if err != nil {
		return nil
	}
	defer rows.Close()
	var out []contracts.Module
	for rows.Next() {
		var m contracts.Module
		if err := rows.Scan(&m.ID, &m.CourseID, &m.Slug, &m.Title, &m.Description, &m.ModuleKind, &m.SequenceNo, &m.Status); err == nil {
			out = append(out, m)
		}
	}
	if err := rows.Err(); err != nil {
		log.Printf("postgresModuleStore.ListModules rows error: %v", err)
		return nil
	}
	sort.Slice(out, func(i, j int) bool { return out[i].SequenceNo < out[j].SequenceNo })
	return out
}

func (s *postgresModuleStore) ModuleByID(id string) (contracts.Module, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	var m contracts.Module
	err := s.db.QueryRowContext(ctx,
		`SELECT id, course_id, slug, title, description, module_kind, sequence_no, status FROM modules WHERE id = $1`, id,
	).Scan(&m.ID, &m.CourseID, &m.Slug, &m.Title, &m.Description, &m.ModuleKind, &m.SequenceNo, &m.Status)
	if err != nil {
		return contracts.Module{}, false
	}
	return m, true
}

func (s *postgresModuleStore) CreateModule(m contracts.Module) (contracts.Module, error) {
	if m.ID == "" {
		m.ID = "module-" + newUUIDLikeID()
	}
	if m.Status == "" {
		m.Status = "draft"
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_, err := s.db.ExecContext(ctx,
		`INSERT INTO modules (id, course_id, slug, title, description, module_kind, sequence_no, status)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
		 ON CONFLICT (id) DO NOTHING`,
		m.ID, m.CourseID, m.Slug, m.Title, m.Description, m.ModuleKind, m.SequenceNo, m.Status,
	)
	if err != nil {
		return contracts.Module{}, err
	}
	created, ok := s.ModuleByID(m.ID)
	if !ok {
		return contracts.Module{}, fmt.Errorf("module not found after insert")
	}
	return created, nil
}

func (s *postgresModuleStore) UpdateModule(id string, update contracts.Module) (contracts.Module, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_, err := s.db.ExecContext(ctx,
		`UPDATE modules SET
			course_id   = CASE WHEN $2 <> '' THEN $2 ELSE course_id END,
			slug        = CASE WHEN $3 <> '' THEN $3 ELSE slug END,
			title       = CASE WHEN $4 <> '' THEN $4 ELSE title END,
			description = CASE WHEN $5 <> '' THEN $5 ELSE description END,
			module_kind = CASE WHEN $6 <> '' THEN $6 ELSE module_kind END,
			sequence_no = CASE WHEN $7 <> 0  THEN $7 ELSE sequence_no END,
			status      = CASE WHEN $8 <> '' THEN $8 ELSE status END,
			updated_at  = now()
		 WHERE id = $1`,
		id, update.CourseID, update.Slug, update.Title, update.Description,
		update.ModuleKind, update.SequenceNo, update.Status,
	)
	if err != nil {
		return contracts.Module{}, false
	}
	return s.ModuleByID(id)
}

func (s *postgresModuleStore) DeleteModule(id string) bool {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	res, err := s.db.ExecContext(ctx, `DELETE FROM modules WHERE id = $1`, id)
	if err != nil {
		return false
	}
	n, _ := res.RowsAffected()
	return n > 0
}

// ── Skill ──────────────────────────────────────────────────────────────────────

type postgresSkillStore struct{ db *sql.DB }

func NewPostgresSkillStore(databaseURL string) (SkillStore, error) {
	db, err := openPostgresDB(databaseURL)
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if _, err := db.ExecContext(ctx, `
CREATE TABLE IF NOT EXISTS skills (
	id          TEXT        PRIMARY KEY,
	module_id   TEXT        NOT NULL,
	skill_kind  TEXT        NOT NULL,
	title       TEXT        NOT NULL,
	sequence_no INTEGER     NOT NULL DEFAULT 0,
	status      TEXT        NOT NULL DEFAULT 'draft',
	created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
	updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
)`); err != nil {
		db.Close()
		return nil, fmt.Errorf("ensure skills schema: %w", err)
	}
	return &postgresSkillStore{db: db}, nil
}

func (s *postgresSkillStore) SkillsByModule(moduleID string) []contracts.Skill {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	rows, err := s.db.QueryContext(ctx,
		`SELECT id, module_id, skill_kind, title, sequence_no, status FROM skills
		 WHERE module_id = $1 AND status = 'published'
		 ORDER BY sequence_no ASC`, moduleID)
	if err != nil {
		return nil
	}
	defer rows.Close()
	var out []contracts.Skill
	for rows.Next() {
		var sk contracts.Skill
		if err := rows.Scan(&sk.ID, &sk.ModuleID, &sk.SkillKind, &sk.Title, &sk.SequenceNo, &sk.Status); err == nil {
			out = append(out, sk)
		}
	}
	if err := rows.Err(); err != nil {
		log.Printf("postgresSkillStore.SkillsByModule rows error: %v", err)
		return nil
	}
	return out
}

func (s *postgresSkillStore) AdminSkillsByModule(moduleID string) []contracts.Skill {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	rows, err := s.db.QueryContext(ctx,
		`SELECT id, module_id, skill_kind, title, sequence_no, status FROM skills
		 WHERE module_id = $1
		 ORDER BY sequence_no ASC`, moduleID)
	if err != nil {
		return nil
	}
	defer rows.Close()
	var out []contracts.Skill
	for rows.Next() {
		var sk contracts.Skill
		if err := rows.Scan(&sk.ID, &sk.ModuleID, &sk.SkillKind, &sk.Title, &sk.SequenceNo, &sk.Status); err == nil {
			out = append(out, sk)
		}
	}
	if err := rows.Err(); err != nil {
		log.Printf("postgresSkillStore.AdminSkillsByModule rows error: %v", err)
		return nil
	}
	return out
}

func (s *postgresSkillStore) AllAdminSkills() []contracts.Skill {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	rows, err := s.db.QueryContext(ctx,
		`SELECT id, module_id, skill_kind, title, sequence_no, status FROM skills
		 ORDER BY module_id, sequence_no ASC`)
	if err != nil {
		return nil
	}
	defer rows.Close()
	var out []contracts.Skill
	for rows.Next() {
		var sk contracts.Skill
		if err := rows.Scan(&sk.ID, &sk.ModuleID, &sk.SkillKind, &sk.Title, &sk.SequenceNo, &sk.Status); err == nil {
			out = append(out, sk)
		}
	}
	return out
}

func (s *postgresSkillStore) SkillByID(id string) (contracts.Skill, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	var sk contracts.Skill
	err := s.db.QueryRowContext(ctx,
		`SELECT id, module_id, skill_kind, title, sequence_no, status FROM skills WHERE id = $1`, id,
	).Scan(&sk.ID, &sk.ModuleID, &sk.SkillKind, &sk.Title, &sk.SequenceNo, &sk.Status)
	if err != nil {
		return contracts.Skill{}, false
	}
	return sk, true
}

func (s *postgresSkillStore) CreateSkill(sk contracts.Skill) (contracts.Skill, error) {
	if sk.ID == "" {
		sk.ID = "skill-" + newUUIDLikeID()
	}
	if sk.Status == "" {
		sk.Status = "draft"
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_, err := s.db.ExecContext(ctx,
		`INSERT INTO skills (id, module_id, skill_kind, title, sequence_no, status)
		 VALUES ($1,$2,$3,$4,$5,$6)
		 ON CONFLICT (id) DO NOTHING`,
		sk.ID, sk.ModuleID, sk.SkillKind, sk.Title, sk.SequenceNo, sk.Status,
	)
	if err != nil {
		return contracts.Skill{}, err
	}
	created, ok := s.SkillByID(sk.ID)
	if !ok {
		return contracts.Skill{}, fmt.Errorf("skill not found after insert")
	}
	return created, nil
}

func (s *postgresSkillStore) UpdateSkill(id string, update contracts.Skill) (contracts.Skill, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_, err := s.db.ExecContext(ctx,
		`UPDATE skills SET
			module_id   = CASE WHEN $2 <> '' THEN $2 ELSE module_id END,
			skill_kind  = CASE WHEN $3 <> '' THEN $3 ELSE skill_kind END,
			title       = CASE WHEN $4 <> '' THEN $4 ELSE title END,
			sequence_no = CASE WHEN $5 <> 0  THEN $5 ELSE sequence_no END,
			status      = CASE WHEN $6 <> '' THEN $6 ELSE status END,
			updated_at  = now()
		 WHERE id = $1`,
		id, update.ModuleID, update.SkillKind, update.Title, update.SequenceNo, update.Status,
	)
	if err != nil {
		return contracts.Skill{}, false
	}
	return s.SkillByID(id)
}

func (s *postgresSkillStore) DeleteSkill(id string) bool {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	res, err := s.db.ExecContext(ctx, `DELETE FROM skills WHERE id = $1`, id)
	if err != nil {
		return false
	}
	n, _ := res.RowsAffected()
	return n > 0
}

// ── Shared DB helper ───────────────────────────────────────────────────────────

func openPostgresDB(databaseURL string) (*sql.DB, error) {
	db, err := sql.Open("postgres", databaseURL)
	if err != nil {
		return nil, fmt.Errorf("open postgres: %w", err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := db.PingContext(ctx); err != nil {
		db.Close()
		return nil, fmt.Errorf("ping postgres: %w", err)
	}
	return db, nil
}
