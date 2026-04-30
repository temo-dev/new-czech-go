package store

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

type postgresVocabularyStore struct{ db *sql.DB }

func NewPostgresVocabularyStore(databaseURL string) (VocabularyStore, error) {
	db, err := sql.Open("postgres", databaseURL)
	if err != nil {
		return nil, fmt.Errorf("open vocab db: %w", err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := db.PingContext(ctx); err != nil {
		db.Close()
		return nil, fmt.Errorf("ping vocab db: %w", err)
	}
	// Migration 020: image_asset_id on vocabulary_items (idempotent)
	if _, err := db.ExecContext(ctx,
		`ALTER TABLE vocabulary_items ADD COLUMN IF NOT EXISTS image_asset_id TEXT NOT NULL DEFAULT ''`,
	); err != nil {
		db.Close()
		return nil, fmt.Errorf("migrate vocabulary_items image_asset_id: %w", err)
	}
	return &postgresVocabularyStore{db: db}, nil
}

func (s *postgresVocabularyStore) CreateVocabularySet(set contracts.VocabularySet) (contracts.VocabularySet, error) {
	if set.ID == "" {
		set.ID = "vocset-" + newUUIDLikeID()
	}
	if set.Status == "" {
		set.Status = "draft"
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_, err := s.db.ExecContext(ctx,
		`INSERT INTO vocabulary_sets (id, module_id, title, level, explanation_lang, status)
		 VALUES ($1,$2,$3,$4,$5,$6)`,
		set.ID, set.ModuleID, set.Title, set.Level, set.ExplanationLang, set.Status,
	)
	if err != nil {
		return contracts.VocabularySet{}, fmt.Errorf("insert vocabulary_set: %w", err)
	}
	got, ok := s.GetVocabularySet(set.ID)
	if !ok {
		return contracts.VocabularySet{}, fmt.Errorf("vocabulary_set not found after insert")
	}
	return got, nil
}

func (s *postgresVocabularyStore) GetVocabularySet(id string) (contracts.VocabularySet, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	var vs contracts.VocabularySet
	err := s.db.QueryRowContext(ctx,
		`SELECT id, module_id, title, level, explanation_lang, status,
		        to_char(created_at,'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
		        to_char(updated_at,'YYYY-MM-DD"T"HH24:MI:SS"Z"')
		 FROM vocabulary_sets WHERE id = $1`, id,
	).Scan(&vs.ID, &vs.ModuleID, &vs.Title, &vs.Level, &vs.ExplanationLang, &vs.Status, &vs.CreatedAt, &vs.UpdatedAt)
	if err != nil {
		return contracts.VocabularySet{}, false
	}
	return vs, true
}

func (s *postgresVocabularyStore) ListVocabularySets(moduleID string) []contracts.VocabularySet {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	query := `SELECT id, module_id, title, level, explanation_lang, status,
	                 to_char(created_at,'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
	                 to_char(updated_at,'YYYY-MM-DD"T"HH24:MI:SS"Z"')
	          FROM vocabulary_sets`
	var rows *sql.Rows
	var err error
	if moduleID != "" {
		rows, err = s.db.QueryContext(ctx, query+` WHERE module_id = $1 ORDER BY created_at DESC`, moduleID)
	} else {
		rows, err = s.db.QueryContext(ctx, query+` ORDER BY created_at DESC`)
	}
	if err != nil {
		return nil
	}
	defer rows.Close()
	var out []contracts.VocabularySet
	for rows.Next() {
		var vs contracts.VocabularySet
		if err := rows.Scan(&vs.ID, &vs.ModuleID, &vs.Title, &vs.Level, &vs.ExplanationLang, &vs.Status, &vs.CreatedAt, &vs.UpdatedAt); err == nil {
			out = append(out, vs)
		}
	}
	return out
}

func (s *postgresVocabularyStore) UpdateVocabularySet(id string, update contracts.VocabularySet) (contracts.VocabularySet, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_, err := s.db.ExecContext(ctx,
		`UPDATE vocabulary_sets SET
		    title            = CASE WHEN $2 <> '' THEN $2 ELSE title END,
		    level            = CASE WHEN $3 <> '' THEN $3 ELSE level END,
		    explanation_lang = CASE WHEN $4 <> '' THEN $4 ELSE explanation_lang END,
		    status           = CASE WHEN $5 <> '' THEN $5 ELSE status END,
		    updated_at       = now()
		 WHERE id = $1`,
		id, update.Title, update.Level, update.ExplanationLang, update.Status,
	)
	if err != nil {
		return contracts.VocabularySet{}, false
	}
	return s.GetVocabularySet(id)
}

func (s *postgresVocabularyStore) DeleteVocabularySet(id string) bool {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	res, err := s.db.ExecContext(ctx, `DELETE FROM vocabulary_sets WHERE id = $1`, id)
	if err != nil {
		return false
	}
	n, _ := res.RowsAffected()
	return n > 0
}

func (s *postgresVocabularyStore) CreateVocabularyItem(item contracts.VocabularyItem) contracts.VocabularyItem {
	if item.ID == "" {
		item.ID = "vocitem-" + newUUIDLikeID()
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	s.db.ExecContext(ctx,
		`INSERT INTO vocabulary_items (id, set_id, term, meaning, part_of_speech, example_sentence, example_translation, sequence_no)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
		item.ID, item.SetID, item.Term, item.Meaning,
		item.PartOfSpeech, item.ExampleSentence, item.ExampleTranslation, item.SequenceNo,
	)
	return item
}

func (s *postgresVocabularyStore) GetVocabularyItem(id string) (contracts.VocabularyItem, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	var vi contracts.VocabularyItem
	err := s.db.QueryRowContext(ctx,
		`SELECT id, set_id, term, meaning, part_of_speech, example_sentence, example_translation, sequence_no, image_asset_id
		 FROM vocabulary_items WHERE id = $1`, id,
	).Scan(&vi.ID, &vi.SetID, &vi.Term, &vi.Meaning,
		&vi.PartOfSpeech, &vi.ExampleSentence, &vi.ExampleTranslation, &vi.SequenceNo, &vi.ImageAssetID)
	if err != nil {
		return contracts.VocabularyItem{}, false
	}
	return vi, true
}

func (s *postgresVocabularyStore) ListVocabularyItems(setID string) []contracts.VocabularyItem {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	rows, err := s.db.QueryContext(ctx,
		`SELECT id, set_id, term, meaning, part_of_speech, example_sentence, example_translation, sequence_no, image_asset_id
		 FROM vocabulary_items WHERE set_id = $1 ORDER BY sequence_no, id`, setID)
	if err != nil {
		return nil
	}
	defer rows.Close()
	var out []contracts.VocabularyItem
	for rows.Next() {
		var vi contracts.VocabularyItem
		if err := rows.Scan(&vi.ID, &vi.SetID, &vi.Term, &vi.Meaning,
			&vi.PartOfSpeech, &vi.ExampleSentence, &vi.ExampleTranslation, &vi.SequenceNo, &vi.ImageAssetID); err == nil {
			out = append(out, vi)
		}
	}
	return out
}

func (s *postgresVocabularyStore) SetVocabularyItemImage(id, storageKey string) bool {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	res, err := s.db.ExecContext(ctx,
		`UPDATE vocabulary_items SET image_asset_id = $2 WHERE id = $1`,
		id, storageKey,
	)
	if err != nil {
		return false
	}
	n, _ := res.RowsAffected()
	return n > 0
}

func (s *postgresVocabularyStore) DeleteVocabularyItem(id string) bool {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	res, err := s.db.ExecContext(ctx, `DELETE FROM vocabulary_items WHERE id = $1`, id)
	if err != nil {
		return false
	}
	n, _ := res.RowsAffected()
	return n > 0
}
