# Spec: Attempt Repair And Shadowing

## Status
Tasks 1-5 are landed for all four oral task types (`Uloha 1`–`Uloha 4`):
- contract types and persistence exist
- review artifacts generate corrected text, model answer text, diff chunks, and speaking-focus items for `Uloha 1`, `Uloha 2`, `Uloha 3`, `Uloha 4`
- backend generates one model-answer audio artifact through a pluggable `TTSProvider`
- learner-facing review endpoints, Flutter rendering, and `Retry with this model` are live on the shared result screen
- opt-in `LLMReviewProvider` (Claude) replaces the rule-based echo repair with a task-aware corrected transcript + model answer; falls back to rule-based on error
- authored `sample_answer_text` on `Exercise` is preferred as the model answer when present; rule-based fallback synthesizes from task detail (checkpoints for `Uloha 3`, choice + reasoning axis for `Uloha 4`)
- provider-aware audio replay landed: signed URLs from `GET /v1/attempts/:id/audio/url` and `.../review/audio/url` cover both local and S3 audio

Follow-up work:
- learner-surface polish for `Uloha 3` and `Uloha 4` feedback messaging
- broader sample-answer authoring coverage in CMS

## Purpose
This spec defines a post-attempt repair-and-shadowing layer for `A2 Mluveni Sprint`.

The goal is to extend the current `transcript + feedback` result with a more actionable coaching loop:
- show what the learner said
- show a corrected Czech version
- generate a task-aware model answer
- generate model audio for shadowing

## Current Implementation Snapshot
Today the backend attaches a persisted review artifact to completed attempts across all four oral task types.

That first slice currently includes:
- `status=ready`
- `source_transcript_text`
- `corrected_transcript_text`
- `model_answer_text`
- `diff_chunks`
- `speaking_focus_items`
- `repair_provider`
- `generated_at`
- optional `tts_audio`

Current generation notes:
- `TTS_PROVIDER=dev` writes a local debug WAV under backend temp storage
- `TTS_PROVIDER=amazon_polly` synthesizes `model_answer_text` through `Amazon Polly` and stores the returned audio in backend temp storage
- TTS failure does not erase the text review artifact or block the attempt from staying `completed`
- `Uloha 2` uses `required_info_slots` plus the extra-question hint to keep corrected/model output in question form instead of turning the review into a statement paragraph
- `Uloha 3` builders synthesize a past-tense narrative from `Uloha3Detail.NarrativeCheckpoints`; speaking-focus items cover checkpoint coverage, past tense, connectives
- `Uloha 4` builders default to `Vybírám {Option.Label}, protože {first reasoning axis}` and surface choice clarity, `protože` clause, axis coverage as focus items
- authored `Exercise.sample_answer_text` (when present) overrides the rule-based model answer for any task type
- when `LLM_REVIEW_PROVIDER=claude` (or `LLM_PROVIDER=claude` is set as the default), `corrected_transcript_text` and `model_answer_text` come from Claude, scoped to the exercise + learner transcript. Diff chunks are recomputed from the LLM-corrected text. Rule-based output is used as fallback
- backend startup is graceful: missing `ANTHROPIC_API_KEY` while `LLM_PROVIDER=claude` logs a warning and falls back to the rule-based provider instead of exiting

## Graph Notes
`code-review-graph` confirms the current attempt flow is concentrated in:
- [backend/internal/httpapi/server.go](/Users/daniel.dev/Desktop/czech-go-system/backend/internal/httpapi/server.go) for attempt orchestration and polling endpoints
- [flutter_app/lib/main.dart](/Users/daniel.dev/Desktop/czech-go-system/flutter_app/lib/main.dart) for result rendering and learner practice UX

That means this feature should be designed as an `extension layer` on top of the current attempt lifecycle, not a full rewrite of attempt creation or result delivery.

## Goals
- Give the learner an immediately usable corrected Czech result after each completed attempt.
- Preserve the difference between `what the learner said` and `what the app recommends`.
- Keep the repair output task-aware for the oral exam format.
- Add one model audio output suitable for shadowing.
- Fit the existing upload-first, async attempt pipeline.

## Non-Goals
- phoneme-level pronunciation scoring
- realtime feedback during recording
- replacing the current readiness feedback
- teacher review workflow
- generic AI tutor chat

## UX Principle
The app must never blur these three concepts:

1. `Transcript cua ban`
This is the recognized transcript from STT. It may be noisy.

2. `Ban nen noi`
This is a corrected Czech version that stays close to the learner intent.

3. `Ban mau de shadow`
This is the model answer the learner should repeat after listening.

The learner must be able to see where the system repaired their text and where the model answer goes further than a direct repair.

## Recommended Product Shape
After an attempt reaches `completed`, the learner should see a second result block called `Repair and shadowing`.

It should contain:
- corrected transcript
- task-aware model answer
- a short `speaking focus` section
- diff highlights
- TTS playback for the model answer
- a `Retry with this model` action

## Why This Should Not Change `AttemptStatus`
The current app already treats `completed` as the moment when transcript and readiness feedback are available.

To keep that behavior stable, the repair-and-shadowing layer should not add a new top-level attempt status like `repairing`.

Instead, add a nested artifact with its own status:
- `pending`
- `ready`
- `failed`

This lets the current result card appear quickly, while the richer coaching artifact can finish slightly later without breaking the existing flow.

## Proposed Data Model

### AttemptReviewArtifact
Derived artifact attached to one completed attempt.

| Field | Type | Required | Notes |
|------|------|----------|------|
| `attempt_id` | `uuid/text` | yes | FK to `Attempt` |
| `status` | `string` | yes | `pending`, `ready`, `failed` |
| `source_transcript_text` | `text` | yes | Snapshot of transcript used for repair |
| `source_transcript_provider` | `string` | no | Example: `amazon_transcribe`, `dev_stub` |
| `corrected_transcript_text` | `text` | no | Czech repair close to learner intent |
| `model_answer_text` | `text` | no | Slightly more exam-ready answer for shadowing |
| `speaking_focus_items` | `json[]` | no | Top learner-facing focus areas |
| `diff_chunks` | `json[]` | no | Highlight blocks for learner vs corrected |
| `tts_storage_key` | `string` | no | Stored audio for model answer |
| `tts_mime_type` | `string` | no | Example: `audio/mpeg` |
| `repair_provider` | `string` | no | Which repair engine generated it |
| `generated_at` | `timestamp` | no | Successful generation timestamp |
| `failed_at` | `timestamp` | no | Failure timestamp |
| `failure_code` | `string` | no | Example: `repair_generation_failed` |

### SpeakingFocusItem
V1 should stay lightweight and honest. This is not a phoneme engine.

| Field | Type | Required | Notes |
|------|------|----------|------|
| `focus_key` | `string` | yes | Stable key |
| `label` | `string` | yes | Short learner-facing label |
| `learner_fragment` | `string` | no | What learner said |
| `target_fragment` | `string` | no | What the corrected/model text uses |
| `issue_type` | `string` | yes | `word_form`, `spelling`, `missing_detail`, `question_form`, `clarity_hint` |
| `comment_vi` | `string` | yes | Short practical explanation |
| `confidence_band` | `string` | no | `low`, `medium`, `high` |

### DiffChunk
| Field | Type | Required | Notes |
|------|------|----------|------|
| `kind` | `string` | yes | `unchanged`, `inserted`, `deleted`, `replaced` |
| `source_text` | `string` | no | Learner-side text |
| `target_text` | `string` | no | Corrected-side text |

## Pipeline

### Current flow
`audio -> transcript -> feedback -> completed`

### Proposed flow
`audio -> transcript -> feedback -> completed`
`completed -> review artifact generation -> review artifact ready`

This keeps the current attempt lifecycle stable while allowing a second async output.

## Review Artifact Generation Steps

### Step 1: Input Gate
Run only if:
- attempt status is `completed`
- transcript exists
- transcript is non-empty
- transcript is not synthetic when strict real-transcript mode is expected

### Step 2: Task-Aware Repair
Generate a corrected Czech version of the learner answer.

Rules:
- preserve learner intent
- do not rewrite into a different scenario
- do not inflate a weak answer into a long perfect monologue
- fix obvious spelling, word-form, and question-form issues when possible

### Step 3: Model Answer Generation
Generate a short model answer suitable for shadowing.

Rules:
- still stay inside the task scope
- should be only one level better than the learner answer, not a giant leap
- should sound exam-appropriate and natural

### Step 4: Diff Generation
Compare learner transcript with corrected transcript and produce simple display chunks.

V1 should prefer readability over perfect token-level linguistic diff.

### Step 5: Speaking Focus Extraction
Generate 1-3 focus items.

Source signals may include:
- transcript repair diff
- task criteria that failed
- low-confidence transcript spans
- missing task elements

Important:
- call this `speaking focus`, not `pronunciation score`
- only claim pronunciation-specific insight when the evidence is strong enough

### Step 6: Model Audio Generation
Generate one TTS audio file from `model_answer_text`.

Recommended direction:
- use `Amazon Polly` for the first implementation because it already fits the project baseline
- keep the code behind a provider interface so the app does not lock itself into a single TTS vendor in UI contracts

Current implementation note:
- the provider interface already exists in backend processing
- the first slice persists `tts_audio.storage_key` and `tts_audio.mime_type` on the review artifact
- learner playback for this audio is intentionally deferred to the next API slice

### Step 7: Persistence
Store the generated artifact separately from the main attempt transcript and feedback.

## API Proposal

### Keep
- `GET /v1/attempts/:attempt_id`

### Extend
Add lightweight review status to the current attempt payload:

```json
{
  "review_artifact": {
    "status": "pending"
  }
}
```

### New Endpoint
`GET /v1/attempts/:attempt_id/review`

Purpose:
- fetch the full repair-and-shadowing artifact without bloating the main attempt payload

Current implementation note:
- this endpoint now exists in the backend
- it returns a lightweight `pending` stub when the attempt exists but no full review artifact has been stored yet
- it returns the persisted artifact when `status=ready` or `status=failed`

### Response Shape
```json
{
  "data": {
    "attempt_id": "attempt-123",
    "status": "ready",
    "source_transcript_text": "dobry den ja chci listek",
    "corrected_transcript_text": "Dobry den, chtel bych listek.",
    "model_answer_text": "Dobry den, chtel bych jeden listek, prosim.",
    "speaking_focus_items": [
      {
        "focus_key": "question_form",
        "label": "Dung mau cau day du",
        "learner_fragment": "ja chci listek",
        "target_fragment": "chtel bych jeden listek, prosim",
        "issue_type": "word_form",
        "comment_vi": "Thu dung mau lich su hon de cau nghe tu nhien trong bai thi."
      }
    ],
    "diff_chunks": [
      {
        "kind": "replaced",
        "source_text": "ja chci listek",
        "target_text": "chtel bych jeden listek, prosim"
      }
    ],
    "tts_audio": {
      "storage_key": "attempt-review/attempt-123/model-answer.mp3",
      "mime_type": "audio/mpeg"
    }
  },
  "meta": {}
}
```

### Audio Replay
Implemented endpoint:
- `GET /v1/attempts/:attempt_id/review/audio/file`

Current implementation note:
- local-backed review audio now reuses the completed-attempt playback pattern
- the current slice reads the model-answer audio from backend temp storage using the persisted `tts_audio.storage_key`
- cloud/provider-aware replay is still a follow-up improvement, not part of this first backend API slice

## Flutter UX Proposal

### Result Card Extension
After current transcript + readiness feedback:

1. show `Repair and shadowing`
2. if artifact is pending:
   - `Dang tao ban sua va audio mau...`
3. if ready:
   - `Transcript cua ban`
   - `Ban nen noi`
   - diff highlight block
   - `Speaking focus`
   - `Nghe ban mau`
   - `Retry with this model`

## MVP Scope
Ship first for:
- `Uloha 1`
- `Uloha 2`

Hold for later:
- `Uloha 3`
- `Uloha 4`

Reason:
- easier to validate text repair quality
- easier to generate short TTS outputs
- lower hallucination risk than story and choice tasks

## Risks
- The repair model may hallucinate a stronger answer than the learner actually intended.
- The app may accidentally blur corrected transcript and model answer unless the UI is explicit.
- Learners may over-trust `speaking focus` as pronunciation truth if the copy is too strong.
- TTS generation adds cost and latency to every completed attempt.
- If review generation is synchronous, the result screen may become noticeably slower.

## Guardrails
- Always keep learner transcript visible beside the corrected result.
- Do not call the output `pronunciation score` in MVP.
- Cap speaking focus items to top `3`.
- Keep model answer short and task-bound.
- If review generation fails, preserve the current attempt result experience.

## Recommended First Build Slice
1. Add persistence and API shape for `AttemptReviewArtifact`
2. Build text-only repair artifact for `Uloha 1`
3. Add diff rendering in Flutter
4. Add model answer generation
5. Add TTS audio generation and playback
6. Expand to `Uloha 2`
