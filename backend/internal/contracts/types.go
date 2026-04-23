package contracts

type User struct {
	ID                string `json:"id"`
	Role              string `json:"role"`
	Email             string `json:"email,omitempty"`
	DisplayName       string `json:"display_name"`
	PreferredLanguage string `json:"preferred_language,omitempty"`
}

type Course struct {
	ID    string `json:"id"`
	Slug  string `json:"slug"`
	Title string `json:"title"`
}

type LearningPlan struct {
	StartDate  string `json:"start_date"`
	CurrentDay int    `json:"current_day"`
	Status     string `json:"status"`
}

type Module struct {
	ID          string `json:"id"`
	Slug        string `json:"slug"`
	Title       string `json:"title"`
	ModuleKind  string `json:"module_kind"`
	SequenceNo  int    `json:"sequence_no"`
	Description string `json:"description,omitempty"`
}

type Exercise struct {
	ID                     string          `json:"id"`
	ModuleID               string          `json:"module_id,omitempty"`
	ExerciseType           string          `json:"exercise_type"`
	Title                  string          `json:"title"`
	ShortInstruction       string          `json:"short_instruction"`
	LearnerInstruction     string          `json:"learner_instruction,omitempty"`
	EstimatedDurationSec   int             `json:"estimated_duration_sec"`
	PrepTimeSec            int             `json:"prep_time_sec,omitempty"`
	RecordingTimeLimitSec  int             `json:"recording_time_limit_sec,omitempty"`
	SampleAnswerEnabled    bool            `json:"sample_answer_enabled"`
	Status                 string          `json:"status,omitempty"`
	SequenceNo             int             `json:"sequence_no,omitempty"`
	Prompt                 any             `json:"prompt,omitempty"`
	Assets                 []PromptAsset   `json:"assets,omitempty"`
	Detail                 any             `json:"detail,omitempty"`
	ScoringTemplatePreview *ScoringPreview `json:"scoring_template_preview,omitempty"`
}

type PromptAsset struct {
	ID         string `json:"id"`
	AssetKind  string `json:"asset_kind"`
	StorageKey string `json:"storage_key"`
	MimeType   string `json:"mime_type"`
	SequenceNo int    `json:"sequence_no,omitempty"`
}

type ScoringPreview struct {
	RubricVersion string `json:"rubric_version"`
	FeedbackStyle string `json:"feedback_style"`
}

type Uloha1Prompt struct {
	TopicLabel      string   `json:"topic_label"`
	QuestionPrompts []string `json:"question_prompts"`
}

type RequiredInfoSlot struct {
	SlotKey        string `json:"slot_key"`
	Label          string `json:"label"`
	SampleQuestion string `json:"sample_question,omitempty"`
}

type Uloha2Detail struct {
	ScenarioTitle      string             `json:"scenario_title"`
	ScenarioPrompt     string             `json:"scenario_prompt"`
	RequiredInfoSlots  []RequiredInfoSlot `json:"required_info_slots"`
	CustomQuestionHint string             `json:"custom_question_hint,omitempty"`
}

type Uloha3Detail struct {
	StoryTitle           string   `json:"story_title"`
	ImageAssetIDs        []string `json:"image_asset_ids"`
	NarrativeCheckpoints []string `json:"narrative_checkpoints"`
	GrammarFocus         []string `json:"grammar_focus,omitempty"`
}

type ChoiceOption struct {
	OptionKey    string `json:"option_key"`
	Label        string `json:"label"`
	ImageAssetID string `json:"image_asset_id,omitempty"`
	Description  string `json:"description,omitempty"`
}

type Uloha4Detail struct {
	ScenarioPrompt        string         `json:"scenario_prompt"`
	Options               []ChoiceOption `json:"options"`
	ExpectedReasoningAxes []string       `json:"expected_reasoning_axes,omitempty"`
}

type Attempt struct {
	ID                      string                        `json:"id"`
	UserID                  string                        `json:"user_id,omitempty"`
	ExerciseID              string                        `json:"exercise_id"`
	ExerciseType            string                        `json:"exercise_type,omitempty"`
	Status                  string                        `json:"status"`
	AttemptNo               int                           `json:"attempt_no"`
	StartedAt               string                        `json:"started_at"`
	RecordingStartedAt      string                        `json:"recording_started_at,omitempty"`
	RecordingUploadedAt     string                        `json:"recording_uploaded_at,omitempty"`
	CompletedAt             string                        `json:"completed_at,omitempty"`
	FailedAt                string                        `json:"failed_at,omitempty"`
	FailureCode             string                        `json:"failure_code,omitempty"`
	ReadinessLevel          string                        `json:"readiness_level,omitempty"`
	ClientPlatform          string                        `json:"client_platform,omitempty"`
	AppVersion              string                        `json:"app_version,omitempty"`
	Audio                   *AttemptAudio                 `json:"audio,omitempty"`
	Transcript              *Transcript                   `json:"transcript,omitempty"`
	Feedback                *AttemptFeedback              `json:"feedback,omitempty"`
	ReviewArtifact          *AttemptReviewArtifactSummary `json:"review_artifact,omitempty"`
	PendingUploadStorageKey string                        `json:"-"`
	UploadTargetIssuedAt    string                        `json:"-"`
}

type AttemptAudio struct {
	StorageKey     string `json:"storage_key"`
	MimeType       string `json:"mime_type"`
	DurationMs     int    `json:"duration_ms,omitempty"`
	SampleRateHz   int    `json:"sample_rate_hz,omitempty"`
	Channels       int    `json:"channels,omitempty"`
	FileSizeBytes  int    `json:"file_size_bytes,omitempty"`
	StoredFilePath string `json:"stored_file_path,omitempty"`
}

type Transcript struct {
	FullText    string  `json:"full_text"`
	Locale      string  `json:"locale"`
	Confidence  float64 `json:"confidence,omitempty"`
	Provider    string  `json:"provider,omitempty"`
	IsSynthetic bool    `json:"is_synthetic,omitempty"`
}

type AttemptFeedback struct {
	ReadinessLevel  string          `json:"readiness_level"`
	OverallSummary  string          `json:"overall_summary"`
	Strengths       []string        `json:"strengths"`
	Improvements    []string        `json:"improvements"`
	TaskCompletion  TaskCompletion  `json:"task_completion"`
	GrammarFeedback GrammarFeedback `json:"grammar_feedback"`
	RetryAdvice     []string        `json:"retry_advice"`
	SampleAnswer    string          `json:"sample_answer_text,omitempty"`
}

type AttemptReviewArtifactSummary struct {
	Status         string `json:"status"`
	FailureCode    string `json:"failure_code,omitempty"`
	GeneratedAt    string `json:"generated_at,omitempty"`
	RepairProvider string `json:"repair_provider,omitempty"`
}

type AttemptReviewArtifact struct {
	AttemptID                string               `json:"attempt_id"`
	Status                   string               `json:"status"`
	SourceTranscriptText     string               `json:"source_transcript_text"`
	SourceTranscriptProvider string               `json:"source_transcript_provider,omitempty"`
	CorrectedTranscriptText  string               `json:"corrected_transcript_text,omitempty"`
	ModelAnswerText          string               `json:"model_answer_text,omitempty"`
	SpeakingFocusItems       []SpeakingFocusItem  `json:"speaking_focus_items,omitempty"`
	DiffChunks               []DiffChunk          `json:"diff_chunks,omitempty"`
	TTSAudio                 *ReviewArtifactAudio `json:"tts_audio,omitempty"`
	RepairProvider           string               `json:"repair_provider,omitempty"`
	GeneratedAt              string               `json:"generated_at,omitempty"`
	FailedAt                 string               `json:"failed_at,omitempty"`
	FailureCode              string               `json:"failure_code,omitempty"`
}

type SpeakingFocusItem struct {
	FocusKey        string `json:"focus_key"`
	Label           string `json:"label"`
	LearnerFragment string `json:"learner_fragment,omitempty"`
	TargetFragment  string `json:"target_fragment,omitempty"`
	IssueType       string `json:"issue_type"`
	CommentVI       string `json:"comment_vi"`
	ConfidenceBand  string `json:"confidence_band,omitempty"`
}

type DiffChunk struct {
	Kind       string `json:"kind"`
	SourceText string `json:"source_text,omitempty"`
	TargetText string `json:"target_text,omitempty"`
}

type ReviewArtifactAudio struct {
	StorageKey string `json:"storage_key"`
	MimeType   string `json:"mime_type"`
}

type TaskCompletion struct {
	ScoreBand       string           `json:"score_band"`
	CriteriaResults []CriterionCheck `json:"criteria_results"`
}

type CriterionCheck struct {
	CriterionKey string `json:"criterion_key"`
	Label        string `json:"label"`
	Met          bool   `json:"met"`
	Comment      string `json:"comment,omitempty"`
}

type GrammarFeedback struct {
	ScoreBand        string         `json:"score_band"`
	Issues           []GrammarIssue `json:"issues"`
	RewrittenExample string         `json:"rewritten_example,omitempty"`
}

type GrammarIssue struct {
	IssueKey   string `json:"issue_key"`
	Label      string `json:"label"`
	Comment    string `json:"comment"`
	ExampleFix string `json:"example_fix,omitempty"`
}

type UploadTarget struct {
	Method       string            `json:"method"`
	URL          string            `json:"url"`
	Headers      map[string]string `json:"headers"`
	StorageKey   string            `json:"storage_key"`
	ExpiresInSec int               `json:"expires_in_sec"`
}

type MockExamSession struct {
	ID                    string                `json:"id"`
	Status                string                `json:"status"`
	OverallReadinessLevel string                `json:"overall_readiness_level,omitempty"`
	OverallSummary        string                `json:"overall_summary,omitempty"`
	Sections              []MockExamSessionItem `json:"sections"`
}

type MockExamSessionItem struct {
	SequenceNo   int    `json:"sequence_no"`
	ExerciseID   string `json:"exercise_id"`
	ExerciseType string `json:"exercise_type"`
	AttemptID    string `json:"attempt_id,omitempty"`
	Status       string `json:"status"`
}
