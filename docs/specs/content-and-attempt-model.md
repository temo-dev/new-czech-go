# Content and Attempt Model

## Purpose
This document defines the core data model for `A2 Mluveni Sprint` V1. It is the shared source of truth for the `Go` backend, `Flutter` learner app, and `Next.js` CMS.

The goal is not to model every future product need. The goal is to model the minimum set of entities needed to:
- create oral exam content
- assign that content to learners
- capture speaking attempts
- store transcripts and scoring outputs
- show useful feedback in the learner app

## Scope
This spec covers:
- content entities
- learner-facing exercise entities
- attempt lifecycle entities
- transcript and feedback payloads
- basic relationships between entities

This spec does not yet cover:
- payment
- subscriptions
- multi-tenant organizations
- teacher workflows beyond content CRUD
- deep analytics warehouses
- production pronunciation assessment for Czech

## V1 Assumptions
- V1 targets `iOS learner app + web CMS`.
- V1 is a small pilot and can use invite-only or lightweight account access.
- V1 supports the four oral task types from the official model exam.
- Audio recording is uploaded as a completed file for scoring. Partial streaming is optional later, but the full uploaded audio remains the source of truth.

## Design Principles
- Prefer explicit task-specific fields over overly generic nested blobs.
- Keep learner result payloads stable even if internal scoring changes.
- Separate `content definition` from `attempt result`.
- Treat transcript and scoring outputs as derived artifacts, not primary input data.

## Entity Overview
```text
User
  |
  +-- LearningPlanAssignment
  |
  +-- Attempt
         |
         +-- AttemptAudio
         +-- AttemptTranscript
         +-- AttemptFeedback
         +-- AttemptReviewArtifact

Course
  |
  +-- Module
         |
         +-- Exercise
                |
                +-- PromptAsset
                +-- ScoringTemplate
```

## Core Enums

### UserRole
- `learner`
- `admin`
- `reviewer`

### ExerciseType
- `uloha_1_topic_answers`
- `uloha_2_dialogue_questions`
- `uloha_3_story_narration`
- `uloha_4_choice_reasoning`

### ExerciseStatus
- `draft`
- `published`
- `archived`

### AttemptStatus
- `created`
- `recording_started`
- `recording_uploaded`
- `transcribing`
- `scoring`
- `completed`
- `failed`

### AttemptFailureCode
- `upload_failed`
- `audio_invalid`
- `transcription_failed`
- `scoring_failed`
- `timeout`
- `internal_error`

### TranscriptSource
- `dev_stub`
- `amazon_transcribe`
- `manual_override`

### FeedbackReadinessLevel
- `not_ready`
- `needs_work`
- `almost_ready`
- `ready_for_mock`

## Entity Definitions

## User
Represents a learner or CMS/admin user.

| Field | Type | Required | Notes |
|------|------|----------|------|
| `id` | `uuid` | yes | Primary identifier |
| `role` | `UserRole` | yes | `learner`, `admin`, or `reviewer` |
| `email` | `string` | yes | Unique |
| `display_name` | `string` | yes | Shown in learner app and CMS |
| `preferred_language` | `string` | no | Default `vi` |
| `created_at` | `timestamp` | yes | Audit |
| `last_active_at` | `timestamp` | no | Optional |

## Course
Logical grouping for the first release. V1 can use a single course, but modeling it now avoids hard-coding everything to one flat list.

| Field | Type | Required | Notes |
|------|------|----------|------|
| `id` | `uuid` | yes | Primary identifier |
| `slug` | `string` | yes | Unique |
| `title` | `string` | yes | Example: `A2 Mluveni Sprint` |
| `description` | `text` | no | Short course description |
| `status` | `ExerciseStatus` | yes | Reuses lifecycle semantics |
| `created_at` | `timestamp` | yes | Audit |
| `updated_at` | `timestamp` | yes | Audit |

## Module
Represents a grouping like `Day 1`, `Mock Exam`, or `Story Practice`.

| Field | Type | Required | Notes |
|------|------|----------|------|
| `id` | `uuid` | yes | Primary identifier |
| `course_id` | `uuid` | yes | FK to `Course` |
| `slug` | `string` | yes | Unique within course |
| `title` | `string` | yes | Learner-visible |
| `description` | `text` | no | Optional |
| `sequence_no` | `int` | yes | Ordering |
| `module_kind` | `string` | yes | `daily_plan`, `practice`, `mock_exam` |
| `status` | `ExerciseStatus` | yes | Draft/published/archive |
| `created_at` | `timestamp` | yes | Audit |
| `updated_at` | `timestamp` | yes | Audit |

## Exercise
The main learner-facing content unit. Each exercise is one task instance the learner can open and attempt.

| Field | Type | Required | Notes |
|------|------|----------|------|
| `id` | `uuid` | yes | Primary identifier |
| `module_id` | `uuid` | yes | FK to `Module` |
| `exercise_type` | `ExerciseType` | yes | Determines detail payload |
| `title` | `string` | yes | Learner-visible |
| `short_instruction` | `string` | yes | Shown in list cards |
| `learner_instruction` | `text` | yes | Full instructions |
| `estimated_duration_sec` | `int` | yes | Used in learner UI |
| `prep_time_sec` | `int` | no | Optional countdown before recording |
| `recording_time_limit_sec` | `int` | no | Optional hard limit |
| `sample_answer_enabled` | `bool` | yes | V1 can default to true |
| `status` | `ExerciseStatus` | yes | Draft/published/archive |
| `sequence_no` | `int` | yes | Ordering within module |
| `created_at` | `timestamp` | yes | Audit |
| `updated_at` | `timestamp` | yes | Audit |

## Exercise Detail Payloads
Each exercise has a task-specific detail record. These may live as typed tables or as validated JSON columns. For V1, either storage strategy is acceptable as long as the API contracts stay stable.

### Uloha1Detail
Topic-based short answers.

| Field | Type | Required | Notes |
|------|------|----------|------|
| `exercise_id` | `uuid` | yes | FK to `Exercise` |
| `topic_label` | `string` | yes | Example: `Pocasi` |
| `question_prompts` | `string[]` | yes | Usually 4 questions |
| `target_answer_style` | `string` | no | Example: `short_direct_answer` |
| `grammar_focus` | `string[]` | no | Example: `present_tense`, `basic sentence order` |

### Uloha2Detail
Dialogue where learner asks for missing information.

| Field | Type | Required | Notes |
|------|------|----------|------|
| `exercise_id` | `uuid` | yes | FK to `Exercise` |
| `scenario_title` | `string` | yes | Example: `Shoes shop` |
| `scenario_prompt` | `text` | yes | Situation card text |
| `required_info_slots` | `RequiredInfoSlot[]` | yes | Example: size, price, material |
| `custom_question_hint` | `string` | no | Optional hint for the extra question |

`RequiredInfoSlot`
| Field | Type | Required | Notes |
|------|------|----------|------|
| `slot_key` | `string` | yes | Stable internal key |
| `label` | `string` | yes | Learner-facing |
| `sample_question` | `string` | no | Used for rubric/template guidance |

### Uloha3Detail
Storytelling from four images.

| Field | Type | Required | Notes |
|------|------|----------|------|
| `exercise_id` | `uuid` | yes | FK to `Exercise` |
| `story_title` | `string` | yes | Learner-visible |
| `image_asset_ids` | `uuid[]` | yes | Exactly 4 in V1 |
| `narrative_checkpoints` | `string[]` | yes | Events the story should cover |
| `grammar_focus` | `string[]` | no | Example: `past_tense` |

### Uloha4Detail
Choose one option and justify the choice.

| Field | Type | Required | Notes |
|------|------|----------|------|
| `exercise_id` | `uuid` | yes | FK to `Exercise` |
| `scenario_prompt` | `text` | yes | Situation framing |
| `options` | `ChoiceOption[]` | yes | Usually 3 options |
| `expected_reasoning_axes` | `string[]` | no | Example: price, comfort, distance |

`ChoiceOption`
| Field | Type | Required | Notes |
|------|------|----------|------|
| `option_key` | `string` | yes | Stable internal key |
| `label` | `string` | yes | Learner-facing |
| `image_asset_id` | `uuid` | no | Optional image |
| `description` | `string` | no | Optional supporting text |

## PromptAsset
Represents media attached to an exercise, such as images or prompt audio.

| Field | Type | Required | Notes |
|------|------|----------|------|
| `id` | `uuid` | yes | Primary identifier |
| `exercise_id` | `uuid` | yes | FK to `Exercise` |
| `asset_kind` | `string` | yes | `image`, `prompt_audio`, `sample_audio` |
| `storage_key` | `string` | yes | S3 or object storage path |
| `mime_type` | `string` | yes | Example: `image/jpeg`, `audio/mpeg` |
| `duration_sec` | `int` | no | For audio assets |
| `sequence_no` | `int` | no | Needed for image ordering |
| `created_at` | `timestamp` | yes | Audit |

## ScoringTemplate
The content-side configuration that tells the scoring layer what to evaluate. This is not the learner result.

| Field | Type | Required | Notes |
|------|------|----------|------|
| `id` | `uuid` | yes | Primary identifier |
| `exercise_id` | `uuid` | yes | FK to `Exercise` |
| `rubric_version` | `string` | yes | Example: `v1` |
| `task_completion_rules` | `json` | yes | Structured checks per task type |
| `feedback_style` | `string` | yes | Example: `supportive_direct_vi` |
| `sample_answer_text` | `text` | no | Optional |
| `sample_answer_audio_asset_id` | `uuid` | no | Optional FK to `PromptAsset` |
| `created_at` | `timestamp` | yes | Audit |
| `updated_at` | `timestamp` | yes | Audit |

## LearningPlanAssignment
Tracks the learner's path through the 14-day plan.

| Field | Type | Required | Notes |
|------|------|----------|------|
| `id` | `uuid` | yes | Primary identifier |
| `user_id` | `uuid` | yes | FK to `User` |
| `course_id` | `uuid` | yes | FK to `Course` |
| `start_date` | `date` | yes | Learner-local date |
| `current_day` | `int` | yes | Starts at 1 |
| `status` | `string` | yes | `active`, `completed`, `paused` |
| `created_at` | `timestamp` | yes | Audit |
| `updated_at` | `timestamp` | yes | Audit |

## Attempt
Represents one learner submission for one exercise.

| Field | Type | Required | Notes |
|------|------|----------|------|
| `id` | `uuid` | yes | Primary identifier |
| `user_id` | `uuid` | yes | FK to `User` |
| `exercise_id` | `uuid` | yes | FK to `Exercise` |
| `status` | `AttemptStatus` | yes | Attempt lifecycle |
| `attempt_no` | `int` | yes | Sequential per user/exercise |
| `started_at` | `timestamp` | yes | Attempt creation time |
| `recording_started_at` | `timestamp` | no | When learner began recording |
| `recording_uploaded_at` | `timestamp` | no | When audio file upload completed |
| `completed_at` | `timestamp` | no | Final success time |
| `failed_at` | `timestamp` | no | Final failure time |
| `failure_code` | `AttemptFailureCode` | no | Present if failed |
| `client_platform` | `string` | yes | Example: `ios` |
| `app_version` | `string` | no | Useful for support |

## AttemptAudio
Stores metadata for the uploaded audio file.

| Field | Type | Required | Notes |
|------|------|----------|------|
| `attempt_id` | `uuid` | yes | PK/FK to `Attempt` |
| `storage_key` | `string` | yes | S3 object key |
| `mime_type` | `string` | yes | Example: `audio/m4a`, `audio/webm` |
| `duration_ms` | `int` | yes | Duration of full recording |
| `sample_rate_hz` | `int` | no | Optional if available from client |
| `channels` | `int` | no | Usually 1 |
| `file_size_bytes` | `int` | yes | Validation and debugging |
| `uploaded_at` | `timestamp` | yes | Audit |

## AttemptTranscript
Stores the best available transcript for an attempt.

| Field | Type | Required | Notes |
|------|------|----------|------|
| `attempt_id` | `uuid` | yes | PK/FK to `Attempt` |
| `source` | `TranscriptSource` | yes | STT or override |
| `locale` | `string` | yes | `cs-CZ` for V1 |
| `full_text` | `text` | yes | Best final transcript |
| `confidence` | `float` | no | If provided by STT |
| `word_timestamps` | `json` | no | Optional detailed timings |
| `raw_provider_payload` | `json` | no | Stored for debugging if needed |
| `created_at` | `timestamp` | yes | Audit |
| `updated_at` | `timestamp` | yes | Audit |

## AttemptFeedback
Stores the learner-visible evaluation result. This should be stable even if the underlying scoring implementation changes.

| Field | Type | Required | Notes |
|------|------|----------|------|
| `attempt_id` | `uuid` | yes | PK/FK to `Attempt` |
| `readiness_level` | `FeedbackReadinessLevel` | yes | High-level label |
| `overall_summary` | `text` | yes | Short learner-facing summary |
| `strengths` | `string[]` | yes | Plain-language positives |
| `improvements` | `string[]` | yes | Plain-language fixes |
| `task_completion` | `TaskCompletionResult` | yes | Structured task score |
| `grammar_feedback` | `GrammarFeedbackResult` | yes | Structured grammar feedback |
| `retry_advice` | `string[]` | yes | Actionable next steps |
| `sample_answer_text` | `text` | no | If enabled |
| `sample_answer_audio_asset_id` | `uuid` | no | Optional |
| `scored_at` | `timestamp` | yes | Audit |

## AttemptReviewArtifact
Planned extension artifact for the post-attempt `repair and shadowing` loop.

This entity should stay separate from `AttemptFeedback` so the current `completed` attempt flow remains stable even if repair generation runs slightly later.

| Field | Type | Required | Notes |
|------|------|----------|------|
| `attempt_id` | `uuid` | yes | PK/FK to `Attempt` |
| `status` | `string` | yes | `pending`, `ready`, `failed` |
| `source_transcript_text` | `text` | yes | Snapshot of transcript used for repair |
| `source_transcript_provider` | `string` | no | Example: `amazon_transcribe`, `dev_stub` |
| `corrected_transcript_text` | `text` | no | Czech repair close to learner meaning |
| `model_answer_text` | `text` | no | Slightly stronger answer used for shadowing |
| `speaking_focus_items` | `SpeakingFocusItem[]` | no | Small learner-facing focus list |
| `diff_chunks` | `DiffChunk[]` | no | Readable comparison between learner and corrected text |
| `tts_storage_key` | `string` | no | Stored audio for the model answer |
| `tts_mime_type` | `string` | no | Example: `audio/mpeg` |
| `repair_provider` | `string` | no | Which repair engine generated the artifact |
| `generated_at` | `timestamp` | no | Success audit |
| `failed_at` | `timestamp` | no | Failure audit |
| `failure_code` | `string` | no | Example: `repair_generation_failed` |

`SpeakingFocusItem`
| Field | Type | Required | Notes |
|------|------|----------|------|
| `focus_key` | `string` | yes | Stable internal key |
| `label` | `string` | yes | Short learner-facing label |
| `learner_fragment` | `string` | no | Learner-side fragment |
| `target_fragment` | `string` | no | Corrected or model fragment |
| `issue_type` | `string` | yes | Example: `word_form`, `question_form`, `missing_detail` |
| `comment_vi` | `string` | yes | Practical explanation in Vietnamese |
| `confidence_band` | `string` | no | `low`, `medium`, `high` |

`DiffChunk`
| Field | Type | Required | Notes |
|------|------|----------|------|
| `kind` | `string` | yes | `unchanged`, `inserted`, `deleted`, `replaced` |
| `source_text` | `string` | no | Learner-side text |
| `target_text` | `string` | no | Corrected-side text |

`TaskCompletionResult`
| Field | Type | Required | Notes |
|------|------|----------|------|
| `score_band` | `string` | yes | `weak`, `ok`, `strong` |
| `criteria_results` | `CriterionResult[]` | yes | Task-specific checks |

`GrammarFeedbackResult`
| Field | Type | Required | Notes |
|------|------|----------|------|
| `score_band` | `string` | yes | `weak`, `ok`, `strong` |
| `issues` | `GrammarIssue[]` | yes | Small list only |
| `rewritten_example` | `string` | no | Better phrasing |

`CriterionResult`
| Field | Type | Required | Notes |
|------|------|----------|------|
| `criterion_key` | `string` | yes | Stable internal key |
| `label` | `string` | yes | Learner-facing |
| `met` | `bool` | yes | Pass/fail style |
| `comment` | `string` | no | Short explanation |

`GrammarIssue`
| Field | Type | Required | Notes |
|------|------|----------|------|
| `issue_key` | `string` | yes | Example: `verb_tense` |
| `label` | `string` | yes | Learner-facing |
| `comment` | `string` | yes | Short explanation |
| `example_fix` | `string` | no | Better phrasing |

## MockExamSession
Groups multiple attempts taken as part of a full mock oral exam.

| Field | Type | Required | Notes |
|------|------|----------|------|
| `id` | `uuid` | yes | Primary identifier |
| `user_id` | `uuid` | yes | FK to `User` |
| `course_id` | `uuid` | yes | FK to `Course` |
| `status` | `string` | yes | `created`, `in_progress`, `completed`, `failed` |
| `started_at` | `timestamp` | yes | Audit |
| `completed_at` | `timestamp` | no | Audit |
| `overall_readiness_level` | `FeedbackReadinessLevel` | no | Final summary |
| `overall_summary` | `text` | no | Final summary text |

## MockExamSessionItem
Connects exercises and attempts to a mock exam session.

| Field | Type | Required | Notes |
|------|------|----------|------|
| `id` | `uuid` | yes | Primary identifier |
| `session_id` | `uuid` | yes | FK to `MockExamSession` |
| `exercise_id` | `uuid` | yes | FK to `Exercise` |
| `sequence_no` | `int` | yes | Order in exam |
| `attempt_id` | `uuid` | no | Filled after completion |

## Relationships Summary
- One `Course` has many `Module` rows.
- One `Module` has many `Exercise` rows.
- One `Exercise` has one task-specific detail record and may have many `PromptAsset` rows.
- One `Exercise` has one active `ScoringTemplate` in V1.
- One `User` has many `Attempt` rows.
- One `Attempt` has exactly one `AttemptAudio`, one `AttemptTranscript`, and one `AttemptFeedback` after successful completion.
- One `Attempt` may later have one `AttemptReviewArtifact` after the repair-and-shadowing layer runs.
- One `MockExamSession` has many `MockExamSessionItem` rows.

## Minimum Validation Rules

### Exercise
- `title` must not be empty.
- `estimated_duration_sec` must be greater than zero.
- `recording_time_limit_sec`, if present, must be greater than `prep_time_sec`.

### Uloha 1
- Must contain at least 2 question prompts.
- Should contain 4 question prompts in standard exam-style content.

### Uloha 2
- Must contain at least 3 required info slots.
- Must allow one extra learner-generated question.

### Uloha 3
- Must contain exactly 4 image assets in V1.
- Must contain at least 3 narrative checkpoints.

### Uloha 4
- Must contain at least 3 choices in V1.
- Each choice must have a unique `option_key`.

### Attempt
- A learner cannot have two active attempts for the same exercise in `recording_started`, `recording_uploaded`, `transcribing`, or `scoring` at the same time.
- `attempt_no` increments by one per learner and exercise.

## Learner-Facing Result Shape
This is the contract the learner app should consume. Internal scoring systems may change, but this top-level shape should remain stable.

```json
{
  "attempt_id": "0c64ff53-3f06-4e86-bede-2b5fe1d4c481",
  "exercise_id": "c46ab0f5-b4f2-451d-b555-aef7d1fd2288",
  "status": "completed",
  "transcript": {
    "full_text": "V Cechach casto snezi v lednu a unoru.",
    "locale": "cs-CZ"
  },
  "feedback": {
    "readiness_level": "almost_ready",
    "overall_summary": "Ban tra loi dung huong, nhung can noi tu nhien hon va bo sung chi tiet ro hon.",
    "strengths": [
      "Tra loi dung chu de",
      "Cau tra loi ngan gon va de hieu"
    ],
    "improvements": [
      "Them ly do cu the hon",
      "Can on dinh hon o chia dong tu"
    ],
    "task_completion": {
      "score_band": "ok",
      "criteria_results": [
        {
          "criterion_key": "answered_question",
          "label": "Tra loi dung cau hoi",
          "met": true,
          "comment": "Ban da tra loi dung y chinh."
        }
      ]
    },
    "grammar_feedback": {
      "score_band": "ok",
      "issues": [
        {
          "issue_key": "word_order",
          "label": "Tu thu cau",
          "comment": "Mot vai cau nghe hoi go.",
          "example_fix": "V Cechach casto snezi v lednu a unoru."
        }
      ],
      "rewritten_example": "Mne se libi teple pocasi, protoze muzu byt venku."
    },
    "retry_advice": [
      "Thu tra loi lai trong 20 giay",
      "Them 1 ly do ro rang vao moi cau"
    ]
  },
  "review_artifact": {
    "status": "pending"
  }
}
```

## CMS Editing Shape
The CMS should work with explicit task-type forms rather than a raw JSON editor for V1.

Minimum fields the CMS must support:
- common exercise metadata
- task-specific detail fields
- prompt assets upload
- scoring template fields
- publish/draft state

## Open Questions
- Should `sample_answer_text` be mandatory for all published exercises, or optional in V1?
- Should the learner history keep all attempts forever in V1, or only the latest N attempts per exercise in the default view?
- Do we want a separate `review_notes` field for internal CMS use, or can that wait?
