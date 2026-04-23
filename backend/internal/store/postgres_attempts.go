package store

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	_ "github.com/lib/pq"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

type postgresAttemptStore struct {
	db *sql.DB
}

func NewPostgresAttemptStore(databaseURL string) (AttemptStore, error) {
	db, err := sql.Open("postgres", databaseURL)
	if err != nil {
		return nil, fmt.Errorf("open postgres connection: %w", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := db.PingContext(ctx); err != nil {
		db.Close()
		return nil, fmt.Errorf("ping postgres: %w", err)
	}

	store := &postgresAttemptStore{db: db}
	if err := store.ensureSchema(ctx); err != nil {
		db.Close()
		return nil, fmt.Errorf("ensure attempt schema: %w", err)
	}

	return store, nil
}

func (s *postgresAttemptStore) ensureSchema(ctx context.Context) error {
	_, err := s.db.ExecContext(ctx, `
CREATE TABLE IF NOT EXISTS attempts (
	id TEXT PRIMARY KEY,
	user_id TEXT NOT NULL,
	exercise_id TEXT NOT NULL,
	exercise_type TEXT NOT NULL,
	status TEXT NOT NULL,
	attempt_no INTEGER NOT NULL,
	started_at TIMESTAMPTZ NOT NULL,
	recording_started_at TIMESTAMPTZ,
	recording_uploaded_at TIMESTAMPTZ,
	completed_at TIMESTAMPTZ,
	failed_at TIMESTAMPTZ,
	failure_code TEXT,
	readiness_level TEXT,
	client_platform TEXT NOT NULL,
	app_version TEXT,
	pending_upload_storage_key TEXT,
	upload_target_issued_at TIMESTAMPTZ,
	UNIQUE (user_id, exercise_id, attempt_no)
);

CREATE TABLE IF NOT EXISTS attempt_audio (
	attempt_id TEXT PRIMARY KEY REFERENCES attempts(id) ON DELETE CASCADE,
	storage_key TEXT NOT NULL,
	mime_type TEXT NOT NULL,
	duration_ms INTEGER NOT NULL,
	sample_rate_hz INTEGER,
	channels INTEGER,
	file_size_bytes INTEGER NOT NULL,
	stored_file_path TEXT,
	uploaded_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS attempt_transcripts (
	attempt_id TEXT PRIMARY KEY REFERENCES attempts(id) ON DELETE CASCADE,
	full_text TEXT NOT NULL,
	locale TEXT NOT NULL,
	confidence DOUBLE PRECISION,
	provider TEXT,
	is_synthetic BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS attempt_feedback (
	attempt_id TEXT PRIMARY KEY REFERENCES attempts(id) ON DELETE CASCADE,
	payload JSONB NOT NULL
);

CREATE TABLE IF NOT EXISTS attempt_review_artifacts (
	attempt_id TEXT PRIMARY KEY REFERENCES attempts(id) ON DELETE CASCADE,
	status TEXT NOT NULL,
	source_transcript_text TEXT NOT NULL,
	source_transcript_provider TEXT,
	corrected_transcript_text TEXT,
	model_answer_text TEXT,
	speaking_focus_items JSONB,
	diff_chunks JSONB,
	tts_storage_key TEXT,
	tts_mime_type TEXT,
	repair_provider TEXT,
	generated_at TIMESTAMPTZ,
	failed_at TIMESTAMPTZ,
	failure_code TEXT
);

ALTER TABLE attempts ADD COLUMN IF NOT EXISTS pending_upload_storage_key TEXT;
ALTER TABLE attempts ADD COLUMN IF NOT EXISTS upload_target_issued_at TIMESTAMPTZ;
ALTER TABLE attempts ADD COLUMN IF NOT EXISTS locale TEXT NOT NULL DEFAULT 'vi';
ALTER TABLE attempt_transcripts ADD COLUMN IF NOT EXISTS provider TEXT;
ALTER TABLE attempt_transcripts ADD COLUMN IF NOT EXISTS is_synthetic BOOLEAN NOT NULL DEFAULT FALSE;
`)
	return err
}

func (s *postgresAttemptStore) CreateAttempt(userID, exerciseID, exerciseType, clientPlatform, appVersion, locale string) (*contracts.Attempt, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	if _, err := tx.ExecContext(ctx, `SELECT pg_advisory_xact_lock(hashtext($1 || ':' || $2))`, userID, exerciseID); err != nil {
		return nil, err
	}

	var attemptNo int
	if err := tx.QueryRowContext(ctx, `SELECT COALESCE(MAX(attempt_no), 0) + 1 FROM attempts WHERE user_id = $1 AND exercise_id = $2`, userID, exerciseID).Scan(&attemptNo); err != nil {
		return nil, err
	}

	now := time.Now().UTC()
	attempt := &contracts.Attempt{
		ID:             newUUIDLikeID(),
		UserID:         userID,
		ExerciseID:     exerciseID,
		ExerciseType:   exerciseType,
		Status:         "created",
		AttemptNo:      attemptNo,
		StartedAt:      now.Format(time.RFC3339),
		ClientPlatform: clientPlatform,
		AppVersion:     appVersion,
		Locale:         locale,
	}

	_, err = tx.ExecContext(
		ctx,
		`INSERT INTO attempts (
			id, user_id, exercise_id, exercise_type, status, attempt_no, started_at, client_platform, app_version, locale
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
		attempt.ID,
		attempt.UserID,
		attempt.ExerciseID,
		attempt.ExerciseType,
		attempt.Status,
		attempt.AttemptNo,
		now,
		attempt.ClientPlatform,
		nullIfEmpty(attempt.AppVersion),
		attempt.Locale,
	)
	if err != nil {
		return nil, err
	}

	if err := tx.Commit(); err != nil {
		return nil, err
	}
	return cloneAttempt(attempt), nil
}

func (s *postgresAttemptStore) UpdateAttemptRecordingStarted(id string, timestamp string) (*contracts.Attempt, bool) {
	parsed := parseRFC3339(timestamp)
	if parsed.IsZero() {
		parsed = time.Now().UTC()
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	result, err := s.db.ExecContext(
		ctx,
		`UPDATE attempts SET status = $2, recording_started_at = $3 WHERE id = $1`,
		id,
		"recording_started",
		parsed,
	)
	if err != nil {
		return nil, false
	}
	if !hasRows(result) {
		return nil, false
	}
	return s.Attempt(id)
}

func (s *postgresAttemptStore) RecordUploadTargetIssued(id, storageKey string) (*contracts.Attempt, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	result, err := s.db.ExecContext(
		ctx,
		`UPDATE attempts
		SET pending_upload_storage_key = $2, upload_target_issued_at = $3
		WHERE id = $1`,
		id,
		storageKey,
		time.Now().UTC(),
	)
	if err != nil || !hasRows(result) {
		return nil, false
	}
	return s.Attempt(id)
}

func (s *postgresAttemptStore) MarkUploadComplete(id string, audio contracts.AttemptAudio) (*contracts.Attempt, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, false
	}
	defer tx.Rollback()

	uploadedAt := time.Now().UTC()
	result, err := tx.ExecContext(
		ctx,
		`UPDATE attempts
		SET status = $2, recording_uploaded_at = $3, pending_upload_storage_key = NULL, upload_target_issued_at = NULL
		WHERE id = $1`,
		id,
		"recording_uploaded",
		uploadedAt,
	)
	if err != nil || !hasRows(result) {
		return nil, false
	}

	_, err = tx.ExecContext(
		ctx,
		`INSERT INTO attempt_audio (
			attempt_id, storage_key, mime_type, duration_ms, sample_rate_hz, channels, file_size_bytes, stored_file_path, uploaded_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		ON CONFLICT (attempt_id) DO UPDATE SET
			storage_key = EXCLUDED.storage_key,
			mime_type = EXCLUDED.mime_type,
			duration_ms = EXCLUDED.duration_ms,
			sample_rate_hz = EXCLUDED.sample_rate_hz,
			channels = EXCLUDED.channels,
			file_size_bytes = EXCLUDED.file_size_bytes,
			stored_file_path = EXCLUDED.stored_file_path,
			uploaded_at = EXCLUDED.uploaded_at`,
		id,
		audio.StorageKey,
		audio.MimeType,
		audio.DurationMs,
		nullIfZero(audio.SampleRateHz),
		nullIfZero(audio.Channels),
		audio.FileSizeBytes,
		nullIfEmpty(audio.StoredFilePath),
		uploadedAt,
	)
	if err != nil {
		return nil, false
	}

	if err := tx.Commit(); err != nil {
		return nil, false
	}
	return s.Attempt(id)
}

func (s *postgresAttemptStore) SetAttemptStatus(id, status string) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_, _ = s.db.ExecContext(ctx, `UPDATE attempts SET status = $2 WHERE id = $1`, id, status)
}

func (s *postgresAttemptStore) CompleteAttempt(id string, transcript contracts.Transcript, feedback contracts.AttemptFeedback) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return
	}
	defer tx.Rollback()

	completedAt := time.Now().UTC()
	if _, err := tx.ExecContext(
		ctx,
		`UPDATE attempts SET
			status = $2,
			completed_at = $3,
			failed_at = NULL,
			failure_code = NULL,
			readiness_level = $4
		WHERE id = $1`,
		id,
		"completed",
		completedAt,
		feedback.ReadinessLevel,
	); err != nil {
		return
	}

	if _, err := tx.ExecContext(
		ctx,
		`INSERT INTO attempt_transcripts (attempt_id, full_text, locale, confidence, provider, is_synthetic)
		VALUES ($1, $2, $3, $4, $5, $6)
		ON CONFLICT (attempt_id) DO UPDATE SET
			full_text = EXCLUDED.full_text,
			locale = EXCLUDED.locale,
			confidence = EXCLUDED.confidence,
			provider = EXCLUDED.provider,
			is_synthetic = EXCLUDED.is_synthetic`,
		id,
		transcript.FullText,
		transcript.Locale,
		transcript.Confidence,
		nullIfEmpty(transcript.Provider),
		transcript.IsSynthetic,
	); err != nil {
		return
	}

	payload, err := json.Marshal(feedback)
	if err != nil {
		return
	}
	if _, err := tx.ExecContext(
		ctx,
		`INSERT INTO attempt_feedback (attempt_id, payload)
		VALUES ($1, $2)
		ON CONFLICT (attempt_id) DO UPDATE SET payload = EXCLUDED.payload`,
		id,
		payload,
	); err != nil {
		return
	}

	_ = tx.Commit()
}

func (s *postgresAttemptStore) UpsertReviewArtifact(id string, artifact contracts.AttemptReviewArtifact) (*contracts.AttemptReviewArtifact, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var speakingFocus any
	if len(artifact.SpeakingFocusItems) > 0 {
		encoded, err := json.Marshal(artifact.SpeakingFocusItems)
		if err != nil {
			return nil, false
		}
		speakingFocus = encoded
	}

	var diffChunks any
	if len(artifact.DiffChunks) > 0 {
		encoded, err := json.Marshal(artifact.DiffChunks)
		if err != nil {
			return nil, false
		}
		diffChunks = encoded
	}

	result, err := s.db.ExecContext(
		ctx,
		`INSERT INTO attempt_review_artifacts (
			attempt_id, status, source_transcript_text, source_transcript_provider,
			corrected_transcript_text, model_answer_text, speaking_focus_items, diff_chunks,
			tts_storage_key, tts_mime_type, repair_provider, generated_at, failed_at, failure_code
		) VALUES (
			$1, $2, $3, $4,
			$5, $6, $7, $8,
			$9, $10, $11, $12, $13, $14
		)
		ON CONFLICT (attempt_id) DO UPDATE SET
			status = EXCLUDED.status,
			source_transcript_text = EXCLUDED.source_transcript_text,
			source_transcript_provider = EXCLUDED.source_transcript_provider,
			corrected_transcript_text = EXCLUDED.corrected_transcript_text,
			model_answer_text = EXCLUDED.model_answer_text,
			speaking_focus_items = EXCLUDED.speaking_focus_items,
			diff_chunks = EXCLUDED.diff_chunks,
			tts_storage_key = EXCLUDED.tts_storage_key,
			tts_mime_type = EXCLUDED.tts_mime_type,
			repair_provider = EXCLUDED.repair_provider,
			generated_at = EXCLUDED.generated_at,
			failed_at = EXCLUDED.failed_at,
			failure_code = EXCLUDED.failure_code`,
		id,
		artifact.Status,
		artifact.SourceTranscriptText,
		nullIfEmpty(artifact.SourceTranscriptProvider),
		nullIfEmpty(artifact.CorrectedTranscriptText),
		nullIfEmpty(artifact.ModelAnswerText),
		speakingFocus,
		diffChunks,
		nullIfEmpty(reviewArtifactAudioStorageKey(artifact.TTSAudio)),
		nullIfEmpty(reviewArtifactAudioMimeType(artifact.TTSAudio)),
		nullIfEmpty(artifact.RepairProvider),
		nullIfTime(parseRFC3339(artifact.GeneratedAt)),
		nullIfTime(parseRFC3339(artifact.FailedAt)),
		nullIfEmpty(artifact.FailureCode),
	)
	if err != nil || !hasRows(result) {
		return nil, false
	}

	return s.ReviewArtifact(id)
}

func (s *postgresAttemptStore) ReviewArtifact(id string) (*contracts.AttemptReviewArtifact, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	row := s.db.QueryRowContext(ctx, `
SELECT
	attempt_id,
	status,
	source_transcript_text,
	source_transcript_provider,
	corrected_transcript_text,
	model_answer_text,
	speaking_focus_items,
	diff_chunks,
	tts_storage_key,
	tts_mime_type,
	repair_provider,
	generated_at,
	failed_at,
	failure_code
FROM attempt_review_artifacts
WHERE attempt_id = $1`, id)

	artifact, err := scanReviewArtifactRow(row.Scan)
	if err == sql.ErrNoRows {
		return nil, false
	}
	if err != nil {
		return nil, false
	}
	return artifact, true
}

func (s *postgresAttemptStore) FailAttempt(id, failureCode string) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_, _ = s.db.ExecContext(
		ctx,
		`UPDATE attempts
		SET status = $2, failed_at = $3, failure_code = $4
		WHERE id = $1`,
		id,
		"failed",
		time.Now().UTC(),
		failureCode,
	)
}

func (s *postgresAttemptStore) Attempt(id string) (*contracts.Attempt, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	row := s.db.QueryRowContext(ctx, attemptSelectQuery+` WHERE a.id = $1`, id)
	attempt, err := scanAttemptRow(row.Scan)
	if err == sql.ErrNoRows {
		return nil, false
	}
	if err != nil {
		return nil, false
	}
	return attempt, true
}

func (s *postgresAttemptStore) ListAttempts() []contracts.Attempt {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	rows, err := s.db.QueryContext(ctx, attemptSelectQuery+` ORDER BY a.started_at DESC`)
	if err != nil {
		return nil
	}
	defer rows.Close()

	items := make([]contracts.Attempt, 0)
	for rows.Next() {
		attempt, err := scanAttemptRow(rows.Scan)
		if err != nil {
			continue
		}
		items = append(items, *attempt)
	}
	return items
}

const attemptSelectQuery = `
SELECT
	a.id,
	a.user_id,
	a.exercise_id,
	a.exercise_type,
	a.status,
	a.attempt_no,
	a.started_at,
	a.recording_started_at,
	a.recording_uploaded_at,
	a.completed_at,
	a.failed_at,
	a.failure_code,
	a.readiness_level,
	a.client_platform,
	a.app_version,
	a.pending_upload_storage_key,
	a.upload_target_issued_at,
	a.locale,
	aa.storage_key,
	aa.mime_type,
	aa.duration_ms,
	aa.sample_rate_hz,
	aa.channels,
	aa.file_size_bytes,
	aa.stored_file_path,
	at.full_text,
	at.locale,
	at.confidence,
	at.provider,
	at.is_synthetic,
	af.payload,
	ar.status,
	ar.failure_code,
	ar.generated_at,
	ar.repair_provider
FROM attempts a
LEFT JOIN attempt_audio aa ON aa.attempt_id = a.id
LEFT JOIN attempt_transcripts at ON at.attempt_id = a.id
LEFT JOIN attempt_feedback af ON af.attempt_id = a.id
LEFT JOIN attempt_review_artifacts ar ON ar.attempt_id = a.id
`

type scanFunc func(dest ...any) error

func scanAttemptRow(scan scanFunc) (*contracts.Attempt, error) {
	var (
		id                      string
		userID                  string
		exerciseID              string
		exerciseType            string
		status                  string
		attemptNo               int
		startedAt               time.Time
		recordingStartedAt      sql.NullTime
		recordingUploadedAt     sql.NullTime
		completedAt             sql.NullTime
		failedAt                sql.NullTime
		failureCode             sql.NullString
		readinessLevel          sql.NullString
		clientPlatform          string
		appVersion              sql.NullString
		pendingUploadStorageKey sql.NullString
		uploadTargetIssuedAt    sql.NullTime
		locale                  sql.NullString
		audioStorageKey         sql.NullString
		audioMimeType           sql.NullString
		audioDurationMs         sql.NullInt64
		audioSampleRateHz       sql.NullInt64
		audioChannels           sql.NullInt64
		audioFileSizeBytes      sql.NullInt64
		audioStoredFilePath     sql.NullString
		transcriptFullText      sql.NullString
		transcriptLocale        sql.NullString
		transcriptConfidence    sql.NullFloat64
		transcriptProvider      sql.NullString
		transcriptIsSynthetic   sql.NullBool
		feedbackPayload         []byte
		reviewStatus            sql.NullString
		reviewFailureCode       sql.NullString
		reviewGeneratedAt       sql.NullTime
		reviewRepairProvider    sql.NullString
	)

	err := scan(
		&id,
		&userID,
		&exerciseID,
		&exerciseType,
		&status,
		&attemptNo,
		&startedAt,
		&recordingStartedAt,
		&recordingUploadedAt,
		&completedAt,
		&failedAt,
		&failureCode,
		&readinessLevel,
		&clientPlatform,
		&appVersion,
		&pendingUploadStorageKey,
		&uploadTargetIssuedAt,
		&locale,
		&audioStorageKey,
		&audioMimeType,
		&audioDurationMs,
		&audioSampleRateHz,
		&audioChannels,
		&audioFileSizeBytes,
		&audioStoredFilePath,
		&transcriptFullText,
		&transcriptLocale,
		&transcriptConfidence,
		&transcriptProvider,
		&transcriptIsSynthetic,
		&feedbackPayload,
		&reviewStatus,
		&reviewFailureCode,
		&reviewGeneratedAt,
		&reviewRepairProvider,
	)
	if err != nil {
		return nil, err
	}

	attempt := &contracts.Attempt{
		ID:                      id,
		UserID:                  userID,
		ExerciseID:              exerciseID,
		ExerciseType:            exerciseType,
		Status:                  status,
		AttemptNo:               attemptNo,
		StartedAt:               startedAt.UTC().Format(time.RFC3339),
		RecordingStartedAt:      formatNullTime(recordingStartedAt),
		RecordingUploadedAt:     formatNullTime(recordingUploadedAt),
		CompletedAt:             formatNullTime(completedAt),
		FailedAt:                formatNullTime(failedAt),
		FailureCode:             failureCode.String,
		ReadinessLevel:          readinessLevel.String,
		ClientPlatform:          clientPlatform,
		AppVersion:              appVersion.String,
		PendingUploadStorageKey: pendingUploadStorageKey.String,
		UploadTargetIssuedAt:    formatNullTime(uploadTargetIssuedAt),
		Locale:                  localeOrVI(locale.String),
	}

	if audioStorageKey.Valid {
		attempt.Audio = &contracts.AttemptAudio{
			StorageKey:     audioStorageKey.String,
			MimeType:       audioMimeType.String,
			DurationMs:     int(audioDurationMs.Int64),
			SampleRateHz:   int(audioSampleRateHz.Int64),
			Channels:       int(audioChannels.Int64),
			FileSizeBytes:  int(audioFileSizeBytes.Int64),
			StoredFilePath: audioStoredFilePath.String,
		}
	}

	if transcriptFullText.Valid {
		attempt.Transcript = &contracts.Transcript{
			FullText:    transcriptFullText.String,
			Locale:      transcriptLocale.String,
			Confidence:  transcriptConfidence.Float64,
			Provider:    transcriptProvider.String,
			IsSynthetic: transcriptIsSynthetic.Bool,
		}
	}

	if len(feedbackPayload) > 0 {
		var feedback contracts.AttemptFeedback
		if err := json.Unmarshal(feedbackPayload, &feedback); err == nil {
			attempt.Feedback = &feedback
		}
	}

	if reviewStatus.Valid {
		attempt.ReviewArtifact = &contracts.AttemptReviewArtifactSummary{
			Status:         reviewStatus.String,
			FailureCode:    reviewFailureCode.String,
			GeneratedAt:    formatNullTime(reviewGeneratedAt),
			RepairProvider: reviewRepairProvider.String,
		}
	}

	return attempt, nil
}

func scanReviewArtifactRow(scan scanFunc) (*contracts.AttemptReviewArtifact, error) {
	var (
		attemptID                string
		status                   string
		sourceTranscriptText     string
		sourceTranscriptProvider sql.NullString
		correctedTranscriptText  sql.NullString
		modelAnswerText          sql.NullString
		speakingFocusPayload     []byte
		diffChunksPayload        []byte
		ttsStorageKey            sql.NullString
		ttsMimeType              sql.NullString
		repairProvider           sql.NullString
		generatedAt              sql.NullTime
		failedAt                 sql.NullTime
		failureCode              sql.NullString
	)

	if err := scan(
		&attemptID,
		&status,
		&sourceTranscriptText,
		&sourceTranscriptProvider,
		&correctedTranscriptText,
		&modelAnswerText,
		&speakingFocusPayload,
		&diffChunksPayload,
		&ttsStorageKey,
		&ttsMimeType,
		&repairProvider,
		&generatedAt,
		&failedAt,
		&failureCode,
	); err != nil {
		return nil, err
	}

	artifact := &contracts.AttemptReviewArtifact{
		AttemptID:                attemptID,
		Status:                   status,
		SourceTranscriptText:     sourceTranscriptText,
		SourceTranscriptProvider: sourceTranscriptProvider.String,
		CorrectedTranscriptText:  correctedTranscriptText.String,
		ModelAnswerText:          modelAnswerText.String,
		RepairProvider:           repairProvider.String,
		GeneratedAt:              formatNullTime(generatedAt),
		FailedAt:                 formatNullTime(failedAt),
		FailureCode:              failureCode.String,
	}

	if len(speakingFocusPayload) > 0 {
		_ = json.Unmarshal(speakingFocusPayload, &artifact.SpeakingFocusItems)
	}
	if len(diffChunksPayload) > 0 {
		_ = json.Unmarshal(diffChunksPayload, &artifact.DiffChunks)
	}
	if ttsStorageKey.Valid {
		artifact.TTSAudio = &contracts.ReviewArtifactAudio{
			StorageKey: ttsStorageKey.String,
			MimeType:   ttsMimeType.String,
		}
	}

	return artifact, nil
}

func hasRows(result sql.Result) bool {
	rows, err := result.RowsAffected()
	return err == nil && rows > 0
}

func formatNullTime(value sql.NullTime) string {
	if !value.Valid {
		return ""
	}
	return value.Time.UTC().Format(time.RFC3339)
}

func parseRFC3339(value string) time.Time {
	parsed, err := time.Parse(time.RFC3339, value)
	if err != nil {
		return time.Time{}
	}
	return parsed.UTC()
}

func nullIfEmpty(value string) any {
	if value == "" {
		return nil
	}
	return value
}

func nullIfZero(value int) any {
	if value == 0 {
		return nil
	}
	return value
}

func nullIfTime(value time.Time) any {
	if value.IsZero() {
		return nil
	}
	return value
}

func reviewArtifactAudioStorageKey(audio *contracts.ReviewArtifactAudio) string {
	if audio == nil {
		return ""
	}
	return audio.StorageKey
}

func reviewArtifactAudioMimeType(audio *contracts.ReviewArtifactAudio) string {
	if audio == nil {
		return ""
	}
	return audio.MimeType
}

func localeOrVI(raw string) string {
	if v, ok := contracts.NormalizeLocale(raw); ok {
		return v
	}
	return contracts.DefaultLocale
}

func newUUIDLikeID() string {
	var data [16]byte
	if _, err := rand.Read(data[:]); err != nil {
		return fmt.Sprintf("attempt-%d", time.Now().UTC().UnixNano())
	}

	data[6] = (data[6] & 0x0f) | 0x40
	data[8] = (data[8] & 0x3f) | 0x80

	return fmt.Sprintf(
		"%x-%x-%x-%x-%x",
		data[0:4],
		data[4:6],
		data[6:8],
		data[8:10],
		data[10:16],
	)
}
