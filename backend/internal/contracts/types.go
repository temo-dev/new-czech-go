package contracts

type User struct {
	ID                string `json:"id"`
	Role              string `json:"role"`
	Email             string `json:"email,omitempty"`
	DisplayName       string `json:"display_name"`
	PreferredLanguage string `json:"preferred_language,omitempty"`
}

type Course struct {
	ID          string `json:"id"`
	Slug        string `json:"slug"`
	Title       string `json:"title"`
	Description string `json:"description,omitempty"`
	Status      string `json:"status,omitempty"` // draft, published
	SequenceNo  int    `json:"sequence_no,omitempty"`
}

// SkillSummary is a computed aggregate of exercises grouped by skill_kind within a module.
type SkillSummary struct {
	SkillKind     string `json:"skill_kind"`
	ExerciseCount int    `json:"exercise_count"`
}

type LearningPlan struct {
	StartDate  string `json:"start_date"`
	CurrentDay int    `json:"current_day"`
	Status     string `json:"status"`
}

type Module struct {
	ID          string `json:"id"`
	CourseID    string `json:"course_id,omitempty"`
	Slug        string `json:"slug"`
	Title       string `json:"title"`
	ModuleKind  string `json:"module_kind"`
	SequenceNo  int    `json:"sequence_no"`
	Description string `json:"description,omitempty"`
	Status      string `json:"status,omitempty"` // draft, published
}

type Exercise struct {
	ID                     string          `json:"id"`
	ModuleID               string          `json:"module_id,omitempty"`
	SkillKind              string          `json:"skill_kind,omitempty"` // noi | nghe | doc | viet | tu_vung | ngu_phap
	Pool                   string          `json:"pool,omitempty"`       // course | exam
	ExerciseType           string          `json:"exercise_type"`
	Title                  string          `json:"title"`
	ShortInstruction       string          `json:"short_instruction"`
	LearnerInstruction     string          `json:"learner_instruction,omitempty"`
	EstimatedDurationSec   int             `json:"estimated_duration_sec"`
	PrepTimeSec            int             `json:"prep_time_sec,omitempty"`
	RecordingTimeLimitSec  int             `json:"recording_time_limit_sec,omitempty"`
	SampleAnswerEnabled    bool            `json:"sample_answer_enabled"`
	DisableSampleAnswer    bool            `json:"disable_sample_answer,omitempty"`
	SampleAnswerText       string          `json:"sample_answer_text,omitempty"`
	Status                 string          `json:"status,omitempty"`
	SequenceNo             int             `json:"sequence_no,omitempty"`
	Prompt                 any             `json:"prompt,omitempty"`
	Assets                 []PromptAsset   `json:"assets,omitempty"`
	Detail                 any             `json:"detail,omitempty"`
	ScoringTemplatePreview *ScoringPreview `json:"scoring_template_preview,omitempty"`
	// V6: LLM generation provenance (nullable — omitted for manually created exercises)
	SourceType      string `json:"source_type,omitempty"` // vocabulary_set | grammar_rule | custom
	SourceID        string `json:"source_id,omitempty"`
	GenerationJobID string `json:"generation_job_id,omitempty"`
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

// --- Listening (V3) ---

// AudioSegment is one speaker turn in a dialog or monologue used to generate Polly audio.
type AudioSegment struct {
	Speaker string `json:"speaker,omitempty"` // "A" or "B" for dialog
	Text    string `json:"text"`
}

// ListeningAudioSource describes where audio comes from: an uploaded asset or text→Polly segments.
type ListeningAudioSource struct {
	AssetID  string         `json:"asset_id,omitempty"` // uploaded file
	Segments []AudioSegment `json:"segments,omitempty"` // text→Polly
}

type MultipleChoiceOption struct {
	Key          string `json:"key"` // "A", "B", ...
	Text         string `json:"text"`
	ImageAssetID string `json:"image_asset_id,omitempty"`
}

type MatchOption struct {
	Key          string `json:"key"`
	Label        string `json:"label"`
	ImageAssetID string `json:"image_asset_id,omitempty"`
}

type ImageOption struct {
	Key     string `json:"key"`
	AssetID string `json:"asset_id"`
}

type TextOption struct {
	Key  string `json:"key"`
	Text string `json:"text"`
}

type PersonOption struct {
	Key         string `json:"key"` // "A"–"E"
	Name        string `json:"name"`
	Description string `json:"description,omitempty"`
}

type FillQuestion struct {
	QuestionNo int    `json:"question_no"`
	Prompt     string `json:"prompt"`
}

// ListeningItem is one question in a multi-choice listening exercise (poslech_1/2).
type ListeningItem struct {
	QuestionNo  int                    `json:"question_no"`
	Question    string                 `json:"question,omitempty"` // prompt shown to learner
	AudioSource ListeningAudioSource   `json:"audio_source"`
	Options     []MultipleChoiceOption `json:"options"`
}

// DialogItem is one dialog in poslech_4.
type DialogItem struct {
	QuestionNo  int                  `json:"question_no"`
	AudioSource ListeningAudioSource `json:"audio_source"`
}

// Poslech1Detail — 5 short passages → choose A-D (5 pts).
type Poslech1Detail struct {
	Items          []ListeningItem   `json:"items"`           // 5 items
	CorrectAnswers map[string]string `json:"correct_answers"` // {"1":"B",...}
}

// Poslech2Detail — same structure as Poslech1Detail.
type Poslech2Detail struct {
	Items          []ListeningItem   `json:"items"`
	CorrectAnswers map[string]string `json:"correct_answers"`
}

// Poslech3Detail — 5 passages → match A-G (2 extra, 5 pts).
type Poslech3Detail struct {
	Items          []ListeningItem   `json:"items"`   // 5 items
	Options        []MatchOption     `json:"options"` // A-G (7)
	CorrectAnswers map[string]string `json:"correct_answers"`
}

// Poslech4Detail — 5 dialogs → choose image A-F (1 extra, 5 pts).
type Poslech4Detail struct {
	Items          []DialogItem      `json:"items"`   // 5 dialogs
	Options        []ImageOption     `json:"options"` // A-F (6)
	CorrectAnswers map[string]string `json:"correct_answers"`
}

// Poslech5Detail — listen to voicemail → fill info (5 pts).
type Poslech5Detail struct {
	AudioSource    ListeningAudioSource `json:"audio_source"`
	Questions      []FillQuestion       `json:"questions"` // 5
	CorrectAnswers map[string]string    `json:"correct_answers"`
}

// ExerciseAudio stores generated audio metadata for a listening exercise.
type ExerciseAudio struct {
	ExerciseID  string `json:"exercise_id"`
	StorageKey  string `json:"storage_key"`
	MimeType    string `json:"mime_type"`
	SourceType  string `json:"source_type"` // "polly" | "upload"
	GeneratedAt string `json:"generated_at"`
}

// --- Reading (V4) ---

type ReadingItem struct {
	ItemNo  int    `json:"item_no"`
	AssetID string `json:"asset_id,omitempty"` // image asset for cteni_1
	Text    string `json:"text,omitempty"`     // short message text for cteni_1
}

type TextItem struct {
	ItemNo int    `json:"item_no"`
	Text   string `json:"text"`
}

type ReadingQuestion struct {
	QuestionNo int                    `json:"question_no"`
	Prompt     string                 `json:"prompt"`
	Options    []MultipleChoiceOption `json:"options"`
}

// Cteni1Detail — match 5 images/messages → A-H (3 extra, 5 pts).
type Cteni1Detail struct {
	Items          []ReadingItem     `json:"items"`   // 5 items
	Options        []TextOption      `json:"options"` // A-H (8)
	CorrectAnswers map[string]string `json:"correct_answers"`
}

// Cteni2Detail — read text → choose A-D (5 questions, 5 pts).
type Cteni2Detail struct {
	Text           string            `json:"text"`
	Questions      []ReadingQuestion `json:"questions"` // 5
	CorrectAnswers map[string]string `json:"correct_answers"`
}

// Cteni3Detail — match 4 texts → persons A-E (1 extra, 4 pts).
type Cteni3Detail struct {
	Texts          []TextItem        `json:"texts"`   // 4 texts
	Persons        []PersonOption    `json:"persons"` // A-E (5)
	CorrectAnswers map[string]string `json:"correct_answers"`
}

// Cteni4Detail — choose A-D (6 questions, 6 pts).
type Cteni4Detail struct {
	Context        string            `json:"context,omitempty"` // optional reading passage
	Questions      []ReadingQuestion `json:"questions"`         // 6
	CorrectAnswers map[string]string `json:"correct_answers"`
}

// Cteni5Detail — read text → fill info (5 questions, 5 pts).
type Cteni5Detail struct {
	Text           string            `json:"text"`
	Questions      []FillQuestion    `json:"questions"` // 5
	CorrectAnswers map[string]string `json:"correct_answers"`
}

// --- Writing (V2) ---

type Psani1Detail struct {
	Questions []string `json:"questions"` // 3 câu hỏi
	MinWords  int      `json:"min_words"` // default 10
}

type Psani2Detail struct {
	Prompt        string   `json:"prompt"`          // "Jste na dovolené..."
	ImageAssetIDs []string `json:"image_asset_ids"` // 5 ảnh
	Topics        []string `json:"topics"`          // ["KDE JSTE?", ...]
	MinWords      int      `json:"min_words"`       // default 35
}

// WritingSubmission is the body of POST /v1/attempts/:id/submit-text.
// Use Answers for psani_1_formular (3 items), Text for psani_2_email.
type WritingSubmission struct {
	Answers          []string `json:"answers,omitempty"`
	Text             string   `json:"text,omitempty"`
	PreferredVoiceID string   `json:"preferred_voice_id,omitempty"`
}

// --- Objective scoring (V3/V4) ---

// AnswerSubmission is the body of POST /v1/attempts/:id/submit-answers.
// Keys are question numbers as strings ("1", "2", ...).
type AnswerSubmission struct {
	Answers map[string]string `json:"answers"`
}

type ObjectiveResult struct {
	Score     int              `json:"score"`
	MaxScore  int              `json:"max_score"`
	Breakdown []QuestionResult `json:"breakdown"`
}

type QuestionResult struct {
	QuestionNo        int    `json:"question_no"`
	QuestionText      string `json:"question_text,omitempty"`
	LearnerAnswer     string `json:"learner_answer"`
	LearnerAnswerText string `json:"learner_answer_text,omitempty"`
	CorrectAnswer     string `json:"correct_answer"`
	CorrectAnswerText string `json:"correct_answer_text,omitempty"`
	IsCorrect         bool   `json:"is_correct"`
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
	Locale                  string                        `json:"locale"`
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
	ReadinessLevel  string           `json:"readiness_level"`
	OverallSummary  string           `json:"overall_summary"`
	Strengths       []string         `json:"strengths"`
	Improvements    []string         `json:"improvements"`
	TaskCompletion  TaskCompletion   `json:"task_completion"`
	GrammarFeedback GrammarFeedback  `json:"grammar_feedback"`
	RetryAdvice     []string         `json:"retry_advice"`
	SampleAnswer    string           `json:"sample_answer_text,omitempty"`
	ObjectiveResult *ObjectiveResult `json:"objective_result,omitempty"` // V3/V4: listening/reading
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

type MockTest struct {
	ID                       string            `json:"id"`
	Title                    string            `json:"title"`
	Description              string            `json:"description"`
	EstimatedDurationMinutes int               `json:"estimated_duration_minutes"`
	Status                   string            `json:"status"`                 // draft, published
	ExamMode                 string            `json:"exam_mode"`              // "real" | "practice" | "" (default practice)
	PassThresholdPercent     int               `json:"pass_threshold_percent"` // 0 = use default 60
	Sections                 []MockTestSection `json:"sections"`
}

type MockTestSection struct {
	SequenceNo   int    `json:"sequence_no"`
	SkillKind    string `json:"skill_kind"` // noi | nghe | doc | viet
	ExerciseID   string `json:"exercise_id"`
	ExerciseType string `json:"exercise_type"`
	MaxPoints    int    `json:"max_points"`
}

type MockExamSession struct {
	ID                    string                `json:"id"`
	LearnerID             string                `json:"learner_id,omitempty"`
	Status                string                `json:"status"`
	MockTestID            string                `json:"mock_test_id,omitempty"`
	OverallScore          int                   `json:"overall_score,omitempty"`
	Passed                bool                  `json:"passed,omitempty"`
	PassThresholdPercent  int                   `json:"pass_threshold_percent,omitempty"`
	OverallReadinessLevel string                `json:"overall_readiness_level,omitempty"`
	OverallSummary        string                `json:"overall_summary,omitempty"`
	Sections              []MockExamSessionItem `json:"sections"`
}


type MockExamSessionItem struct {
	SequenceNo   int    `json:"sequence_no"`
	SkillKind    string `json:"skill_kind"`
	ExerciseID   string `json:"exercise_id"`
	ExerciseType string `json:"exercise_type"`
	MaxPoints    int    `json:"max_points,omitempty"`
	AttemptID    string `json:"attempt_id,omitempty"`
	SectionScore int    `json:"section_score,omitempty"`
	Status       string `json:"status"`
}

// ── V6: Vocabulary & Grammar LLM-Assisted Authoring ─────────────────────────

type VocabularySet struct {
	ID              string `json:"id"`
	ModuleID        string `json:"module_id"`
	Title           string `json:"title"`
	Level           string `json:"level"`            // A1 | A2 | B1
	ExplanationLang string `json:"explanation_lang"` // vi | en | cs
	Status          string `json:"status"`           // draft | published | archived
	CreatedAt       string `json:"created_at,omitempty"`
	UpdatedAt       string `json:"updated_at,omitempty"`
}

type VocabularyItem struct {
	ID                 string `json:"id"`
	SetID              string `json:"set_id"`
	Term               string `json:"term"`
	Meaning            string `json:"meaning"`
	PartOfSpeech       string `json:"part_of_speech,omitempty"`
	ExampleSentence    string `json:"example_sentence,omitempty"`
	ExampleTranslation string `json:"example_translation,omitempty"`
	SequenceNo         int    `json:"sequence_no"`
	ImageAssetID       string `json:"image_asset_id,omitempty"`
}

type GrammarRule struct {
	ID              string            `json:"id"`
	ModuleID        string            `json:"module_id"`
	Title           string            `json:"title"`
	Level           string            `json:"level"`
	ExplanationVI   string            `json:"explanation_vi,omitempty"`
	RuleTable       map[string]string `json:"rule_table,omitempty"` // e.g. {"já":"jsem","ty":"jsi"}
	ConstraintsText string            `json:"constraints_text,omitempty"`
	Status          string            `json:"status"`
	ImageAssetID    string            `json:"image_asset_id,omitempty"`
	CreatedAt       string            `json:"created_at,omitempty"`
	UpdatedAt       string            `json:"updated_at,omitempty"`
}

type ContentGenerationJob struct {
	ID               string  `json:"id"`
	ModuleID         string  `json:"module_id"`
	SourceType       string  `json:"source_type"` // vocabulary_set | grammar_rule
	SourceID         string  `json:"source_id"`
	RequestedBy      string  `json:"requested_by"`
	InputPayload     []byte  `json:"-"` // raw JSON stored/retrieved from DB
	GeneratedPayload []byte  `json:"-"`
	EditedPayload    []byte  `json:"-"`
	Status           string  `json:"status"`
	Provider         string  `json:"provider"`
	Model            string  `json:"model"`
	InputTokens      int     `json:"input_tokens,omitempty"`
	OutputTokens     int     `json:"output_tokens,omitempty"`
	EstimatedCostUSD float64 `json:"estimated_cost_usd,omitempty"`
	DurationMs       int     `json:"duration_ms,omitempty"`
	ErrorMessage     string  `json:"error_message,omitempty"`
	CreatedAt        string  `json:"created_at,omitempty"`
	UpdatedAt        string  `json:"updated_at,omitempty"`
	PublishedAt      string  `json:"published_at,omitempty"`
}

// GenerationJobInput is the body of POST /admin/content-generation-jobs.
type GenerationJobInput struct {
	SourceType    string         `json:"source_type"` // vocabulary_set | grammar_rule
	SourceID      string         `json:"source_id"`
	ModuleID      string         `json:"module_id"`
	ExerciseTypes []string       `json:"exercise_types"` // subset of quizcard_basic/matching/fill_blank/choice_word
	NumPerType    map[string]int `json:"num_per_type"`
}

// ── V6 Exercise Detail Types ────────────────────────────────────────────────

type QuizcardBasicDetail struct {
	FrontText          string            `json:"front_text"`
	BackText           string            `json:"back_text"`
	ExampleSentence    string            `json:"example_sentence,omitempty"`
	ExampleTranslation string            `json:"example_translation,omitempty"`
	Explanation        string            `json:"explanation,omitempty"`
	ImageAssetID       string            `json:"image_asset_id,omitempty"` // storage key for flashcard image
	CorrectAnswers     map[string]string `json:"correct_answers"`          // always {"1":"known"}
}

// MatchingPair is one left→right pair in a matching exercise.
// left_id and right_id are used as keys for submission and scoring.
type MatchingPair struct {
	LeftID  string `json:"left_id"`  // "1","2","3"... (fixed order, learner sees left in this order)
	Left    string `json:"left"`     // Czech term
	RightID string `json:"right_id"` // "A","B","C"... (learner sees right shuffled by Flutter)
	Right   string `json:"right"`    // Vietnamese definition
}

// MatchingDetail stores pairs with option-key correct_answers for exact-match scoring.
// correct_answers: {"1":"A","2":"B"} — learner submits same format.
type MatchingDetail struct {
	Pairs          []MatchingPair    `json:"pairs"`
	Explanation    string            `json:"explanation,omitempty"`
	CorrectAnswers map[string]string `json:"correct_answers"`
}

type FillBlankDetail struct {
	Sentence       string            `json:"sentence"` // must contain "___"
	Hint           string            `json:"hint,omitempty"`
	Explanation    string            `json:"explanation,omitempty"`
	CorrectAnswers map[string]string `json:"correct_answers"` // {"1":"chodím"}
}

type ChoiceWordDetail struct {
	Stem           string                 `json:"stem"`
	Options        []MultipleChoiceOption `json:"options"` // reuse existing type, key A/B/C/D
	GrammarNote    string                 `json:"grammar_note,omitempty"`
	Explanation    string                 `json:"explanation,omitempty"`
	CorrectAnswers map[string]string      `json:"correct_answers"` // {"1":"B"}
}

// GeneratedExercise is one exercise in an LLM-generated draft payload.
type GeneratedExercise struct {
	ExerciseType string `json:"exercise_type"`
	// quizcard fields
	FrontText          string `json:"front_text,omitempty"`
	BackText           string `json:"back_text,omitempty"`
	ExampleSentence    string `json:"example_sentence,omitempty"`
	ExampleTranslation string `json:"example_translation,omitempty"`
	// fill_blank / choice_word fields
	Prompt        string   `json:"prompt,omitempty"`
	Options       []string `json:"options,omitempty"`
	CorrectAnswer string   `json:"correct_answer,omitempty"`
	GrammarNote   string   `json:"grammar_note,omitempty"`
	// matching fields
	Pairs []MatchingPair `json:"pairs,omitempty"`
	// common
	Explanation string `json:"explanation,omitempty"`
}

// GeneratedPayload is the full LLM output stored in a generation job.
type GeneratedPayload struct {
	Exercises []GeneratedExercise `json:"exercises"`
}
