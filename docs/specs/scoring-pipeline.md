# Scoring Pipeline

## Purpose
This document defines how `A2 Mluveni Sprint` V1 converts a learner's spoken attempt into stable, learner-facing feedback.

The pipeline begins after:
- audio upload is complete
- speech-to-text returns a final transcript
- the attempt enters `scoring`

The pipeline ends when:
- `AttemptFeedback` is fully generated
- the attempt can transition from `scoring` to `completed`

## Goals
- produce useful feedback for learners preparing for the `trvaly pobyt A2` oral exam
- stay robust when Czech speech-to-text is imperfect
- keep the output contract stable for the learner app
- support task-specific evaluation without building a heavy AI examiner
- fit a V1 architecture that is simple enough for `1 person + Codex`

## Non-Goals
- academic-grade pronunciation scoring
- open-ended conversational evaluation
- fully automated official-exam equivalence
- deep linguistic error analysis
- sentence-by-sentence tutor dialogue

## V1 Principles
- Score for `exam usefulness`, not linguistic perfection.
- Penalize missing task completion more than minor grammar mistakes.
- Be tolerant of transcript noise and accented speech.
- Use structured rules first, model judgment second.
- Keep learner-facing feedback short, actionable, and repeatable.

## Pipeline Summary
```text
AttemptAudio
  -> Transcription
  -> Transcript Validation
  -> Transcript Normalization
  -> Task Context Loading
  -> Task Completion Evaluation
  -> Grammar Evaluation
  -> Feedback Aggregation
  -> Learner-Facing Result Rendering
  -> AttemptFeedback persisted
```

## Inputs

The scoring pipeline requires:
- `Attempt`
- `AttemptAudio`
- `AttemptTranscript`
- `Exercise`
- task-specific exercise detail payload
- active `ScoringTemplate`

Optional inputs:
- transcript confidence
- word timestamps
- sample answer text
- prompt assets metadata

## Output Contract
The scoring pipeline must produce a valid `AttemptFeedback` object with:
- `readiness_level`
- `overall_summary`
- `strengths`
- `improvements`
- `task_completion`
- `grammar_feedback`
- `retry_advice`
- optional sample answer data

This shape must match [content-and-attempt-model.md](/Users/daniel.dev/Desktop/czech-go-system/docs/specs/content-and-attempt-model.md).

## Pipeline Stages

## Stage 0: Preconditions
This stage begins only when:
- attempt state is `scoring`
- transcript exists
- scoring template exists
- exercise is still valid and published or historically available

If any required input is missing:
- mark attempt `failed`
- set `failure_code = scoring_failed`

## Stage 1: Transcript Validation
Goal: decide whether the transcript is usable enough for scoring.

Checks:
- transcript text is non-empty
- transcript length exceeds minimum threshold for the task
- transcript is not obvious garbage
- transcript locale is `cs-CZ`

Examples of obvious garbage:
- empty string
- only punctuation
- repeated filler with no content
- provider payload failure with no text body

Possible outcomes:
- `usable`
- `usable_with_warnings`
- `unusable`

Rules:
- `unusable` => fail the attempt with `transcription_failed` or `scoring_failed`, depending on source
- `usable_with_warnings` => continue scoring, but avoid overconfident negative feedback

## Stage 2: Transcript Normalization
Goal: make the transcript easier to score consistently without changing learner intent.

Normalization operations may include:
- trim whitespace
- collapse repeated spaces
- standardize punctuation
- normalize obvious casing issues
- preserve original transcript separately

Optional task-aware normalization:
- map common transcript artifacts to stable forms
- remove duplicated fragments caused by STT repetition

Rules:
- do not hallucinate missing content
- do not rewrite full learner answers before task-completion scoring
- preserve enough fidelity for future debugging

Outputs:
- `raw_transcript`
- `normalized_transcript`
- optional `normalization_notes`

## Stage 3: Task Context Loading
Goal: load the right rubric context for the current exercise.

Required context:
- `exercise_type`
- instructions
- task-specific detail payload
- scoring template
- sample answer if enabled

The pipeline must branch by `ExerciseType`:
- `uloha_1_topic_answers`
- `uloha_2_dialogue_questions`
- `uloha_3_story_narration`
- `uloha_4_choice_reasoning`

## Stage 4: Task Completion Evaluation
Goal: determine whether the learner actually did the task.

This is the most important scoring layer in V1.

### Common Task Completion Dimensions
All tasks should check some version of:
- relevance to prompt
- sufficient response length
- evidence of task completion
- clarity of intent

Task completion output:
```json
{
  "score_band": "ok",
  "criteria_results": [
    {
      "criterion_key": "answered_question",
      "label": "Tra loi dung cau hoi",
      "met": true,
      "comment": "Ban da tra loi dung y chinh."
    }
  ]
}
```

### Uloha 1: Topic Answers
Primary checks:
- learner answered the active question or question set
- answer stays on topic
- answer includes at least one meaningful detail where expected

Suggested criteria keys:
- `answered_question`
- `stayed_on_topic`
- `gave_supporting_detail`

Scoring notes:
- short answers can still pass if they are direct and relevant
- missing detail should reduce quality, not automatically fail task completion

### Uloha 2: Dialogue Questions
Primary checks:
- learner requested the required information slots
- learner formed actual questions, not just keywords
- learner included a valid extra question if the task requires it

Suggested criteria keys:
- `covered_required_slots`
- `used_question_form`
- `included_custom_question`

Scoring notes:
- tolerate minor phrasing errors if intent is clear
- prioritize information-seeking intent over grammar purity

### Uloha 3: Story Narration
Primary checks:
- learner covers all or most narrative checkpoints
- learner describes a sequence rather than isolated words
- learner shows some past-tense or event narration behavior

Suggested criteria keys:
- `covered_story_events`
- `narrative_sequence_present`
- `used_story_language`

Scoring notes:
- do not require every image detail to appear verbatim
- missing a major checkpoint matters more than imperfect tense use

### Uloha 4: Choice and Reasoning
Primary checks:
- learner made a clear choice
- learner gave at least one supporting reason
- learner's reason connects to one of the available options

Suggested criteria keys:
- `made_clear_choice`
- `gave_reason`
- `reason_matches_choice`

Scoring notes:
- if no clear choice is made, task completion should be weak even if grammar is okay

## Stage 5: Grammar Evaluation
Goal: provide limited but actionable language feedback without pretending to be a full grammar checker.

Grammar evaluation should answer:
- was the language understandable?
- were there recurring basic mistakes?
- what one or two things should the learner fix next?

### What Grammar Evaluation Should Focus On
- sentence clarity
- common tense issues
- word order issues
- agreement issues if obvious
- question formation issues for `Uloha 2`

### What Grammar Evaluation Should Avoid
- exhaustive correction of every error
- highly technical grammar labels
- criticism based solely on low-confidence transcript artifacts

Output shape:
```json
{
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
}
```

### Grammar Scoring Bands
- `weak`
- `ok`
- `strong`

Suggested interpretation:
- `weak`: several issues reduce clarity
- `ok`: understandable, but noticeable basic issues
- `strong`: mostly clear and natural for this exam level

## Stage 6: Transcript Reliability Adjustment
Goal: prevent overconfident bad feedback when transcript quality is questionable.

Signals:
- low transcript confidence if available
- unusually short transcript vs audio duration
- high repetition or artifact rate
- mismatch between expected response length and transcript length

Adjustment rules:
- when reliability is low, prefer softer wording
- avoid specific grammar criticism that depends on exact wording
- emphasize retrying with a clearer recording if needed
- never mark a strong transcript problem as learner grammar with high certainty

Examples:
- prefer `Cau tra loi chua ro o mot vai doan` over `Ban chia dong tu sai`
- prefer `Thu ghi am lai ro hon` when transcript reliability is weak

## Stage 7: Feedback Aggregation
Goal: combine task completion and grammar into one learner-facing result.

### Aggregation Priorities
Order of importance:
1. task completion
2. clarity / intelligibility
3. grammar
4. style refinement

This ordering reflects exam usefulness. A learner who answers the task clearly but imperfectly should score better than a learner with cleaner grammar who misses the task.

### Readiness Mapping
Suggested mapping:

| Task Completion | Grammar | Readiness Level |
|------|------|------|
| weak | any | `not_ready` |
| ok | weak | `needs_work` |
| ok | ok | `almost_ready` |
| strong | ok/strong | `ready_for_mock` |

Rules:
- if task completion is `weak`, readiness cannot exceed `needs_work`
- if transcript reliability is low, readiness may be capped at `almost_ready`

### Strengths
Must be:
- true
- specific
- short

Examples:
- `Ban tra loi dung chu de`
- `Ban da dua ra lua chon ro rang`
- `Ban ke duoc trinh tu cau chuyen`

### Improvements
Must be:
- actionable
- limited to the top 1-3 issues
- phrased for retry

Examples:
- `Them 1 ly do cu the hon`
- `Hoi day du cac thong tin can thiet`
- `Noi ro hon tung buoc cua cau chuyen`

### Retry Advice
Must sound like the next thing to do, not a lecture.

Examples:
- `Thu tra loi lai trong 20-30 giay`
- `O bai nay, hay noi ro ban chon phuong an nao truoc`
- `Hay nhac den ca 4 tranh theo dung thu tu`

Current implementation note:
- `Uloha 1` retry advice is tied to the actual missing criterion, such as answering directly, staying on topic, or adding a `protoze` detail.
- `Uloha 2` retry advice is tied to question-form coverage, required info slots, and whether the learner added a natural extra question.
- All four task types now route through the `LLMFeedbackProvider` path. When `LLM_PROVIDER=claude`, the `readiness_level`, `overall_summary`, `strengths`, `improvements`, `retry_advice`, and `sample_answer` fields are generated by Claude (claude-haiku-4-5-20251001). Rule-based `task_completion` and `grammar_feedback` sub-structs are always computed first and merged with LLM output. If the LLM call fails or `LLM_PROVIDER` is unset, the pipeline falls back to rule-based feedback automatically.

## Stage 8: Sample Answer Handling
Goal: optionally attach a model answer without making it feel like the learner must match it word-for-word.

Rules:
- sample answer is optional
- sample answer must not be used as the only basis for scoring
- if shown, frame it as `mot cach tra loi tot`, not `dap an duy nhat`

Eligible sources:
- `ScoringTemplate.sample_answer_text`
- `ScoringTemplate.sample_answer_audio_asset_id`

## Stage 9: Persistence
When aggregation is successful:
- write `AttemptFeedback`
- set `scored_at`
- set attempt state to `completed`

When aggregation fails:
- do not partially mark the attempt `completed`
- mark attempt `failed`
- set `failure_code = scoring_failed`

## Stage 10: Review Artifact Handoff
After the attempt transitions to `completed`, a separate `AttemptReviewArtifact` generation stage runs. That stage is out of scope for this document and is specified in [attempt-repair-and-shadowing.md](/Users/daniel.dev/Desktop/czech-go-system/docs/specs/attempt-repair-and-shadowing.md). The scoring pipeline must not block on it — review artifact failure must not revert the attempt out of `completed`.

## Scoring Strategy by Component

## Rule-Based Components
Best suited for:
- response length checks
- option detection for `Uloha 4`
- slot coverage detection for `Uloha 2`
- narrative checkpoint presence for `Uloha 3`
- missing-answer detection

Benefits:
- predictable
- cheap
- easy to debug

## Model-Assisted Components
Best suited for:
- judging whether an answer is on-topic
- soft grammar summarization
- generating concise learner-facing summaries
- rewriting a better example sentence

Benefits:
- flexible
- more natural feedback

Risks:
- can overreact to noisy transcripts
- can sound generic if prompted poorly

V1 recommendation:
- use model judgment only after rule-based checks establish the task context
- require structured JSON output from the model

## Recommended Internal Scoring Steps
One practical V1 implementation sequence:
1. load attempt + transcript + exercise + scoring template
2. run transcript validation and normalization
3. run rule-based task checks
4. assemble a compact scoring context
5. call the model for:
   - grammar summary
   - task-aware explanation
   - learner-facing summary
6. merge rule outputs and model outputs
7. validate result shape
8. persist `AttemptFeedback`

## Example Internal Scoring Context
Illustrative shape sent to the model layer:

```json
{
  "exercise_type": "uloha_4_choice_reasoning",
  "instruction": "Choose one option and explain why.",
  "normalized_transcript": "Myslim, ze park je dobry napad, protoze tam bude klid.",
  "task_checks": {
    "made_clear_choice": true,
    "gave_reason": true,
    "reason_matches_choice": true
  },
  "scoring_template": {
    "feedback_style": "supportive_direct_vi"
  },
  "transcript_reliability": "usable"
}
```

## Model Output Constraints
If a model is used, it should return structured JSON only.

Required constraints:
- no markdown
- no long essays
- no unsupported fields
- strengths capped to 3
- improvements capped to 3
- grammar issues capped to 3
- summary should be short

If model output is malformed:
- retry once with stricter formatting
- if still invalid, fail scoring or fall back to template-driven feedback

## Fallback Behavior
V1 should not depend on one perfect model call.

Fallback options:
- template-based feedback from rule results only
- reduced grammar feedback with generic but safe wording
- omit rewritten example if confidence is too low

Current implementation note:
- The repo now has an `LLMFeedbackProvider` layer backed by Claude. Rule-based logic is always the fallback.
- `Uloha 1` summaries mention the active topic label; `Uloha 2` summaries mention the scenario title. Both are included in the LLM prompt context.
- `Uloha 3` and `Uloha 4` LLM prompts include the narrative/choice detail but task-completion rules for those types are still less refined than `Uloha 1` and `Uloha 2`.

Fallback should still aim to produce:
- `overall_summary`
- at least 1 `improvement`
- valid `task_completion`
- valid `grammar_feedback`

## Latency Targets
V1 does not need sub-second scoring, but it should feel responsive.

Suggested targets after transcript is ready:
- rule checks: under 1 second
- model-assisted scoring: under 5 seconds
- total scoring stage: target under 8 seconds

If scoring exceeds the allowed timeout window:
- mark attempt `failed`
- set `failure_code = timeout` or `scoring_failed` per implementation policy

## Quality Guidelines
Good feedback is:
- short
- concrete
- exam-oriented
- forgiving of STT uncertainty
- encouraging without being fake

Bad feedback is:
- generic praise
- overly technical grammar explanation
- contradiction between strengths and improvements
- harsh certainty based on noisy transcript

## Review and Tuning Loop
V1 tuning should use real learner attempts from pilot users.

Review questions:
- are learners getting the same generic advice too often?
- are rule checks missing obvious task completion?
- is grammar feedback too harsh for noisy transcripts?
- are readiness labels too optimistic or too strict?

Tune in this order:
1. task completion rules
2. transcript reliability heuristics
3. feedback phrasing
4. model prompt

## Failure Modes

### Transcript Too Weak
Handling:
- avoid strong grammar claims
- encourage retry with clearer recording
- fail only if transcript is too empty to score

### Model Output Too Generic
Handling:
- tighten prompt with task context
- require criterion-linked explanations
- cap verbosity

### Rule and Model Disagree
Handling:
- rule-based task checks win for structural task completion
- model may shape wording, not overturn hard task facts

### Missing Scoring Template
Handling:
- mark `scoring_failed`
- log as content configuration problem

## Open Questions
- Do we want a separate internal `transcript_reliability` field persisted for later analysis?
- Should `pass likelihood` be added later as a derived field, or is readiness level enough for V1?
- Do we want a hard cap on how often identical retry advice can appear across attempts for the same learner?
