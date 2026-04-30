package store

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

type postgresGrammarStore struct{ db *sql.DB }

func NewPostgresGrammarStore(databaseURL string) (GrammarStore, error) {
	db, err := sql.Open("postgres", databaseURL)
	if err != nil {
		return nil, fmt.Errorf("open grammar db: %w", err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := db.PingContext(ctx); err != nil {
		db.Close()
		return nil, fmt.Errorf("ping grammar db: %w", err)
	}
	// Migration 021: image_asset_id on grammar_rules (idempotent)
	if _, err := db.ExecContext(ctx,
		`ALTER TABLE grammar_rules ADD COLUMN IF NOT EXISTS image_asset_id TEXT NOT NULL DEFAULT ''`,
	); err != nil {
		db.Close()
		return nil, fmt.Errorf("migrate grammar_rules image_asset_id: %w", err)
	}
	return &postgresGrammarStore{db: db}, nil
}

func (s *postgresGrammarStore) CreateGrammarRule(rule contracts.GrammarRule) (contracts.GrammarRule, error) {
	if rule.ID == "" {
		rule.ID = "grammar-" + newUUIDLikeID()
	}
	if rule.Status == "" {
		rule.Status = "draft"
	}
	tableJSON := []byte("{}")
	if len(rule.RuleTable) > 0 {
		tableJSON, _ = json.Marshal(rule.RuleTable)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_, err := s.db.ExecContext(ctx,
		`INSERT INTO grammar_rules (id, module_id, title, level, explanation_vi, rule_table_json, constraints_text, status)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
		rule.ID, rule.ModuleID, rule.Title, rule.Level,
		rule.ExplanationVI, tableJSON, rule.ConstraintsText, rule.Status,
	)
	if err != nil {
		return contracts.GrammarRule{}, fmt.Errorf("insert grammar_rule: %w", err)
	}
	got, ok := s.GetGrammarRule(rule.ID)
	if !ok {
		return contracts.GrammarRule{}, fmt.Errorf("grammar_rule not found after insert")
	}
	return got, nil
}

func (s *postgresGrammarStore) GetGrammarRule(id string) (contracts.GrammarRule, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	var gr contracts.GrammarRule
	var tableJSON []byte
	err := s.db.QueryRowContext(ctx,
		`SELECT id, module_id, title, level, explanation_vi, rule_table_json, constraints_text, status, image_asset_id,
		        to_char(created_at,'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
		        to_char(updated_at,'YYYY-MM-DD"T"HH24:MI:SS"Z"')
		 FROM grammar_rules WHERE id = $1`, id,
	).Scan(&gr.ID, &gr.ModuleID, &gr.Title, &gr.Level, &gr.ExplanationVI,
		&tableJSON, &gr.ConstraintsText, &gr.Status, &gr.ImageAssetID, &gr.CreatedAt, &gr.UpdatedAt)
	if err != nil {
		return contracts.GrammarRule{}, false
	}
	if len(tableJSON) > 0 {
		json.Unmarshal(tableJSON, &gr.RuleTable)
	}
	return gr, true
}

func (s *postgresGrammarStore) ListGrammarRules(moduleID string) []contracts.GrammarRule {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	query := `SELECT id, module_id, title, level, explanation_vi, rule_table_json, constraints_text, status, image_asset_id,
	                 to_char(created_at,'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
	                 to_char(updated_at,'YYYY-MM-DD"T"HH24:MI:SS"Z"')
	          FROM grammar_rules`
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
	var out []contracts.GrammarRule
	for rows.Next() {
		var gr contracts.GrammarRule
		var tableJSON []byte
		if err := rows.Scan(&gr.ID, &gr.ModuleID, &gr.Title, &gr.Level, &gr.ExplanationVI,
			&tableJSON, &gr.ConstraintsText, &gr.Status, &gr.ImageAssetID, &gr.CreatedAt, &gr.UpdatedAt); err == nil {
			if len(tableJSON) > 0 {
				json.Unmarshal(tableJSON, &gr.RuleTable)
			}
			out = append(out, gr)
		}
	}
	return out
}

func (s *postgresGrammarStore) SetGrammarRuleImage(id, storageKey string) bool {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	res, err := s.db.ExecContext(ctx,
		`UPDATE grammar_rules SET image_asset_id = $2, updated_at = now() WHERE id = $1`,
		id, storageKey,
	)
	if err != nil {
		return false
	}
	n, _ := res.RowsAffected()
	return n > 0
}

func (s *postgresGrammarStore) UpdateGrammarRule(id string, update contracts.GrammarRule) (contracts.GrammarRule, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	tableJSON := []byte(nil)
	if len(update.RuleTable) > 0 {
		tableJSON, _ = json.Marshal(update.RuleTable)
	}
	_, err := s.db.ExecContext(ctx,
		`UPDATE grammar_rules SET
		    title            = CASE WHEN $2 <> '' THEN $2 ELSE title END,
		    level            = CASE WHEN $3 <> '' THEN $3 ELSE level END,
		    explanation_vi   = CASE WHEN $4 <> '' THEN $4 ELSE explanation_vi END,
		    rule_table_json  = CASE WHEN $5 IS NOT NULL THEN $5 ELSE rule_table_json END,
		    constraints_text = CASE WHEN $6 <> '' THEN $6 ELSE constraints_text END,
		    status           = CASE WHEN $7 <> '' THEN $7 ELSE status END,
		    updated_at       = now()
		 WHERE id = $1`,
		id, update.Title, update.Level, update.ExplanationVI,
		tableJSON, update.ConstraintsText, update.Status,
	)
	if err != nil {
		return contracts.GrammarRule{}, false
	}
	return s.GetGrammarRule(id)
}

func (s *postgresGrammarStore) DeleteGrammarRule(id string) bool {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	res, err := s.db.ExecContext(ctx, `DELETE FROM grammar_rules WHERE id = $1`, id)
	if err != nil {
		return false
	}
	n, _ := res.RowsAffected()
	return n > 0
}
