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

type Attempt struct {
	ID                  string           `json:"id"`
	ExerciseID          string           `json:"exercise_id"`
	ExerciseType        string           `json:"exercise_type,omitempty"`
	Status              string           `json:"status"`
	AttemptNo           int              `json:"attempt_no"`
	StartedAt           string           `json:"started_at"`
	RecordingStartedAt  string           `json:"recording_started_at,omitempty"`
	RecordingUploadedAt string           `json:"recording_uploaded_at,omitempty"`
	CompletedAt         string           `json:"completed_at,omitempty"`
	FailureCode         string           `json:"failure_code,omitempty"`
	ReadinessLevel      string           `json:"readiness_level,omitempty"`
	Audio               *AttemptAudio    `json:"audio,omitempty"`
	Transcript          *Transcript      `json:"transcript,omitempty"`
	Feedback            *AttemptFeedback `json:"feedback,omitempty"`
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
	FullText   string  `json:"full_text"`
	Locale     string  `json:"locale"`
	Confidence float64 `json:"confidence,omitempty"`
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
