# API Contracts

## Purpose
This document defines the V1 API contracts for `A2 Mluveni Sprint`. These contracts are designed to support:
- learner authentication and content access
- attempt creation and audio upload
- transcript and feedback retrieval
- mock oral exam flows
- thin CMS content management

The API is intentionally narrow. It is designed for one learner app, one CMS, and one backend service.

## Scope
This spec covers:
- HTTP endpoints
- request and response payloads
- status and error contracts
- attempt lifecycle transitions exposed through the API

This spec does not yet cover:
- websocket realtime streaming contracts
- internal worker contracts
- provider-specific speech service payloads
- analytics exports

## V1 Assumptions
- API style: JSON over HTTPS
- Auth style: bearer token after login
- Upload style: presigned upload for completed audio files
- Scoring style: async after audio upload
- Locale: `cs-CZ` for speech tasks, `vi` for most learner-facing feedback copy

Current dev implementation note:
- the learner still requests an upload target through `POST /v1/attempts/:attempt_id/upload-url`
- the backend can return either a same-host authenticated `PUT` target for local development or an `S3` presigned `PUT` target when `ATTEMPT_UPLOAD_PROVIDER=s3`
- the client upload contract stays the same in both modes: the learner app receives `method`, `url`, `headers`, and `storage_key`
- `POST /v1/attempts/:attempt_id/upload-complete` must match the `storage_key` from the most recently issued upload target for that attempt
- transcript payloads now include provenance metadata so the learner app can distinguish synthetic dev transcripts from real provider transcripts
- the learner-coaching slice now persists backend review artifacts for completed `Uloha 1` attempts and exposes learner-authenticated review endpoints for artifact fetch plus review-audio playback

## Common Conventions

### Base Paths
- Learner API: `/v1`
- CMS API: `/v1/admin`

### Headers
- `Authorization: Bearer <token>` for authenticated endpoints
- `Content-Type: application/json` for JSON requests
- `X-Client-Version: <version>` optional but recommended

### Response Envelope
Successful responses should use this shape:

```json
{
  "data": {},
  "meta": {}
}
```

Error responses should use this shape:

```json
{
  "error": {
    "code": "transcription_failed",
    "message": "Transcription could not be completed.",
    "retryable": true,
    "details": {}
  }
}
```

### Common Error Codes
- `unauthorized`
- `forbidden`
- `not_found`
- `validation_error`
- `conflict`
- `upload_failed`
- `audio_invalid`
- `transcription_failed`
- `scoring_failed`
- `rate_limited`
- `internal_error`

## Attempt State Machine
The API should expose a simple, explicit attempt lifecycle:

```text
created
  -> recording_started
  -> recording_uploaded
  -> transcribing
  -> scoring
  -> completed

created|recording_started|recording_uploaded|transcribing|scoring
  -> failed
```

Notes:
- `recording_started` can be set by client event or inferred from upload start.
- `recording_uploaded` means the full audio file is safely stored and ready for processing.
- `completed` means transcript and learner-facing feedback are both available.

## Authentication Endpoints

## POST /v1/auth/login
Returns a bearer token for learner or admin access.

### Request
```json
{
  "email": "learner@example.com",
  "password": "secret"
}
```

### Response
```json
{
  "data": {
    "access_token": "jwt-or-session-token",
    "token_type": "Bearer",
    "expires_in_sec": 3600,
    "user": {
      "id": "9dad7f97-1f0c-4b24-8807-2191d25c58b7",
      "role": "learner",
      "display_name": "Nguyen An",
      "preferred_language": "vi"
    }
  },
  "meta": {}
}
```

## GET /v1/me
Returns the authenticated user profile used by the learner app shell.

### Response
```json
{
  "data": {
    "id": "9dad7f97-1f0c-4b24-8807-2191d25c58b7",
    "role": "learner",
    "display_name": "Nguyen An",
    "preferred_language": "vi"
  },
  "meta": {}
}
```

## Learner Content Endpoints

## GET /v1/courses
Returns all published courses ordered by sequence_no.

### Response
```json
{
  "data": [
    { "id": "course-1", "slug": "giao-tiep-co-ban", "title": "Giao tiếp cơ bản", "description": "...", "sequence_no": 1 },
    { "id": "course-2", "slug": "di-urad", "title": "Đi urad", "description": "...", "sequence_no": 2 }
  ],
  "meta": {}
}
```

## GET /v1/courses/:course_id
Returns one course.

## GET /v1/courses/:course_id/modules
Returns published modules in a course ordered by sequence_no.

### Response
```json
{
  "data": [
    { "id": "mod-1", "course_id": "course-1", "title": "Ở bưu điện", "description": "...", "sequence_no": 1 }
  ],
  "meta": {}
}
```

## GET /v1/modules/:module_id/skills
Returns published skills in a module ordered by sequence_no.

### Response
```json
{
  "data": [
    { "id": "skill-1", "module_id": "mod-1", "skill_kind": "noi", "title": "Kỹ năng nói", "sequence_no": 1 },
    { "id": "skill-2", "module_id": "mod-1", "skill_kind": "nghe", "title": "Kỹ năng nghe", "sequence_no": 2 }
  ],
  "meta": {}
}
```

## GET /v1/skills/:skill_id/exercises
Returns published exercises for one skill (pool=course only).

### Response
```json
{
  "data": [
    { "id": "ex-1", "skill_id": "skill-1", "exercise_type": "uloha_1_topic_answers", "title": "Chủ đề: Gia đình", "pool": "course" }
  ],
  "meta": {}
}
```

## GET /v1/course
**Deprecated** — kept for backward compat. Returns first published course + learning_plan.

### Response
```json
{
  "data": {
    "course": { "id": "course-1", "slug": "a2-mluveni-sprint", "title": "A2 Mluveni Sprint" },
    "learning_plan": { "start_date": "2026-04-21", "current_day": 3, "status": "active" }
  },
  "meta": {}
}
```

## GET /v1/modules
Returns published modules. **Prefer** `GET /v1/courses/:id/modules`.

### Query Params
- `kind` optional: `daily_plan`, `practice`
- `course_id` optional: filter by course

### Response
```json
{
  "data": [
    { "id": "mod-1", "course_id": "course-1", "slug": "day-1", "title": "Day 1", "module_kind": "daily_plan", "sequence_no": 1 }
  ],
  "meta": {}
}
```

## GET /v1/modules/:module_id/exercises
Returns learner-visible exercises for one module. **Deprecated** — use `/v1/skills/:id/exercises`. Aggregates across all skills in module for backward compat.

### Response
```json
{
  "data": [
    {
      "id": "c46ab0f5-b4f2-451d-b555-aef7d1fd2288",
      "exercise_type": "uloha_1_topic_answers",
      "title": "Pocasi 1",
      "short_instruction": "Tra loi ngan gon theo chu de",
      "estimated_duration_sec": 90,
      "sample_answer_enabled": true
    }
  ],
  "meta": {}
}
```

## GET /v1/exercises/:exercise_id
Returns full learner-facing exercise detail.

### Query Parameters
- `mock_exam_session_id` (optional) — V39.1 mock-exam context. When
  provided, the level/course unlock gate may be bypassed only if the
  authenticated learner owns that mock-exam session and the requested
  exercise is one of its sections. Borrowed or unrelated session IDs
  still return `403 level_locked`.

### Response
```json
{
  "data": {
    "id": "c46ab0f5-b4f2-451d-b555-aef7d1fd2288",
    "exercise_type": "uloha_1_topic_answers",
    "title": "Pocasi 1",
    "learner_instruction": "Ban se tra loi 4 cau hoi ngan ve chu de thoi tiet.",
    "estimated_duration_sec": 90,
    "prep_time_sec": 10,
    "recording_time_limit_sec": 45,
    "prompt": {
      "topic_label": "Pocasi",
      "question_prompts": [
        "Ve kterem mesici v Cesku casto snezi a mrzne?",
        "Jake pocasi mate rad/a a proc?"
      ]
    },
    "assets": [],
    "sample_answer_enabled": true
  },
  "meta": {}
}
```

## GET /v1/exercises/:exercise_id/assets/:asset_id/file
Returns one learner-visible prompt asset file for the exercise, such as a `Uloha 3` story image or a `Uloha 4` choice image.

## Attempt Endpoints

## POST /v1/attempts
Creates an attempt before recording upload starts.

### Request
```json
{
  "exercise_id": "c46ab0f5-b4f2-451d-b555-aef7d1fd2288",
  "client_platform": "ios",
  "app_version": "0.1.0"
}
```

### Response
```json
{
  "data": {
    "attempt": {
      "id": "0c64ff53-3f06-4e86-bede-2b5fe1d4c481",
      "exercise_id": "c46ab0f5-b4f2-451d-b555-aef7d1fd2288",
      "status": "created",
      "attempt_no": 2,
      "started_at": "2026-04-21T08:30:00Z"
    }
  },
  "meta": {}
}
```

## POST /v1/attempts/:attempt_id/recording-started
Optional endpoint to mark that the learner began recording.

### Request
```json
{
  "recording_started_at": "2026-04-21T08:30:12Z"
}
```

### Response
```json
{
  "data": {
    "attempt_id": "0c64ff53-3f06-4e86-bede-2b5fe1d4c481",
    "status": "recording_started"
  },
  "meta": {}
}
```

## POST /v1/attempts/:attempt_id/upload-url
Creates a presigned upload target for the final audio file.

The target points back to the backend host in local mode. When `ATTEMPT_UPLOAD_PROVIDER=s3`, it returns an S3 presigned `PUT` target and the same `storage_key` is later used by Amazon Transcribe and provider-aware playback.

### Request
```json
{
  "mime_type": "audio/m4a",
  "file_size_bytes": 482120,
  "duration_ms": 28100
}
```

### Response
```json
{
  "data": {
    "upload": {
      "method": "PUT",
      "url": "http://localhost:8080/v1/attempts/0c64ff53-3f06-4e86-bede-2b5fe1d4c481/audio",
      "headers": {
        "Content-Type": "audio/m4a"
      },
      "storage_key": "attempt-audio/0c64ff53-3f06-4e86-bede-2b5fe1d4c481/audio.m4a",
      "expires_in_sec": 900
    }
  },
  "meta": {}
}
```

## POST /v1/attempts/:attempt_id/upload-complete
Confirms the upload finished and starts async processing.

### Request
```json
{
  "storage_key": "attempt-audio/0c64ff53-3f06-4e86-bede-2b5fe1d4c481/audio.m4a",
  "mime_type": "audio/m4a",
  "duration_ms": 28100,
  "sample_rate_hz": 44100,
  "channels": 1,
  "file_size_bytes": 182044,
  "stored_file_path": "/tmp/czech-go-system/attempt-audio/0c64ff53-3f06-4e86-bede-2b5fe1d4c481/audio.m4a"
}
```

### Response
```json
{
  "data": {
    "attempt_id": "0c64ff53-3f06-4e86-bede-2b5fe1d4c481",
    "status": "transcribing"
  },
  "meta": {}
}
```

## GET /v1/attempts/:attempt_id
Returns current attempt status. Used for polling while transcription and scoring are running.

### Response: In Progress
```json
{
  "data": {
    "id": "0c64ff53-3f06-4e86-bede-2b5fe1d4c481",
    "exercise_id": "c46ab0f5-b4f2-451d-b555-aef7d1fd2288",
    "status": "scoring",
    "started_at": "2026-04-21T08:30:00Z",
    "audio": {
      "storage_key": "attempt-audio/0c64ff53-3f06-4e86-bede-2b5fe1d4c481/audio.m4a",
      "mime_type": "audio/m4a",
      "duration_ms": 28100,
      "sample_rate_hz": 44100,
      "channels": 1,
      "file_size_bytes": 182044
    }
  },
  "meta": {}
}
```

### Response: Completed
```json
{
  "data": {
    "id": "0c64ff53-3f06-4e86-bede-2b5fe1d4c481",
    "exercise_id": "c46ab0f5-b4f2-451d-b555-aef7d1fd2288",
    "status": "completed",
    "audio": {
      "storage_key": "attempt-audio/0c64ff53-3f06-4e86-bede-2b5fe1d4c481/audio.m4a",
      "mime_type": "audio/m4a",
      "duration_ms": 28100,
      "sample_rate_hz": 44100,
      "channels": 1,
      "file_size_bytes": 182044
    },
    "transcript": {
      "full_text": "Mne se libi teple pocasi, protoze muzu byt venku.",
      "locale": "cs-CZ",
      "confidence": 0.92,
      "provider": "amazon_transcribe",
      "is_synthetic": false
    },
    "feedback": {
      "readiness_level": "almost_ready",
      "overall_summary": "Ban tra loi dung huong, nhung can them chi tiet cu the hon.",
      "strengths": [
        "Dung chu de",
        "De hieu"
      ],
      "improvements": [
        "Noi ro ly do hon"
      ],
      "task_completion": {
        "score_band": "ok",
        "criteria_results": []
      },
      "grammar_feedback": {
        "score_band": "ok",
        "issues": [],
        "rewritten_example": "Mne se libi teple pocasi, protoze muzu byt venku."
      },
      "retry_advice": [
        "Thu tra loi lai voi 1 ly do cu the"
      ]
    },
    "review_artifact": {
      "status": "pending"
    }
  },
  "meta": {}
}
```

### Response: Failed
```json
{
  "data": {
    "id": "0c64ff53-3f06-4e86-bede-2b5fe1d4c481",
    "exercise_id": "c46ab0f5-b4f2-451d-b555-aef7d1fd2288",
    "status": "failed",
    "failure_code": "transcription_failed"
  },
  "meta": {}
}
```

## Review Artifact Extension
This extension now exists at the backend-contract level for the first learner-coaching slice. The current implementation covers persisted `Uloha 1` review artifacts plus learner-authenticated fetch and review-audio playback endpoints.

### Review Artifact Summary On Attempt Payload
The main attempt payload may expose only a lightweight nested status:

```json
{
  "review_artifact": {
    "status": "pending",
    "failure_code": null,
    "generated_at": null,
    "repair_provider": null
  }
}
```

Rules:
- keep `AttemptStatus` unchanged
- do not block the current `completed` result on review generation
- use `review_artifact.status` values `pending`, `ready`, or `failed`

## GET /v1/attempts/:attempt_id/review
Returns the full repair-and-shadowing artifact for one learner-owned attempt.

Notes:
- if the attempt exists but no full artifact has been persisted yet, the backend returns a lightweight `pending` artifact stub
- if an artifact exists, the backend returns the persisted corrected transcript, model answer, speaking focus items, diff chunks, and optional `tts_audio`

### Response
```json
{
  "data": {
    "attempt_id": "attempt-123",
    "status": "ready",
    "source_transcript_text": "dobry den ja chci listek",
    "source_transcript_provider": "amazon_transcribe",
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
    },
    "repair_provider": "task_aware_repair_v1",
    "generated_at": "2026-04-23T07:10:00Z"
  },
  "meta": {}
}
```

## GET /v1/attempts/:attempt_id/review/audio/file
Returns authenticated playback of the model-answer TTS audio when the review artifact has `tts_audio` metadata.

Notes:
- this now mirrors the current completed-attempt audio replay pattern for local-backed review audio
- in the current slice, local/dev review audio is served from backend temp storage using the persisted `tts_audio.storage_key`
- `GET /v1/attempts/:attempt_id/review/audio/url` is the preferred learner-app endpoint; it returns a short-lived HMAC-signed backend stream URL for locally generated review audio
- when attempt playback is configured for S3, review audio still falls back to the local signed stream because model-answer TTS is stored by the backend

## GET /v1/attempts
Returns recent attempts for the authenticated learner, newest first.

Notes:
- learner responses should include only that learner's own attempts
- admin responses may include the wider attempt list

### Response
```json
{
  "data": [
    {
      "id": "attempt-12",
      "exercise_id": "exercise-uloha1-weather",
      "status": "completed",
      "started_at": "2026-04-22T19:48:00Z",
      "readiness_level": "almost_ready",
      "transcript": {
        "full_text": "Mne se libi teple pocasi, protoze muzu byt venku.",
        "provider": "amazon_transcribe",
        "is_synthetic": false
      },
      "feedback": {
        "overall_summary": "Ban dang o gan muc on, chi can them vai chi tiet cu the de bai noi thuyet phuc hon."
      },
      "review_artifact": {
        "status": "ready"
      }
    }
  ],
  "meta": {
    "next_cursor": null
  }
}
```
## GET /v1/attempts/:attempt_id/audio/file
Returns the stored audio file for one uploaded or completed attempt so the learner app can replay the submitted answer from backend storage.

Notes:
- requires learner auth
- a learner may only fetch their own attempt audio
- local dev returns the stored file directly from backend temp storage
- cloud-backed deployments may satisfy the same endpoint by redirecting or streaming from durable storage
- this is now a compatibility endpoint; the Flutter learner should prefer `GET /v1/attempts/:attempt_id/audio/url`
- in `s3` upload mode, this endpoint can still return `404` for cloud-only attempts that have no backend `stored_file_path`

### Response
- `200` with binary audio body
- `Content-Type` matches the stored attempt audio mime type

## GET /v1/attempts/:attempt_id/audio/url
Returns a short-lived playable URL for the learner's submitted attempt audio.

Notes:
- requires learner auth to mint the URL
- local upload mode returns an HMAC-signed backend stream URL under `/v1/attempt-audio/stream`
- `s3` upload mode returns a presigned S3 `GET` URL for attempt audio
- if `ATTEMPT_AUDIO_URL_PROVIDER` is unset and `ATTEMPT_UPLOAD_PROVIDER=s3`, the backend automatically uses S3 presigned playback for attempt audio
- if `ATTEMPT_AUDIO_URL_PROVIDER=local` is explicitly set, the backend uses the local stream path and cloud-only attempts without `stored_file_path` can still fail to play
- the returned URL is already authorized; the audio player must not add the learner bearer token to a cloud URL

### Response
```json
{
  "data": {
    "url": "https://...",
    "mime_type": "audio/m4a",
    "expires_at": "2026-04-30T09:10:00Z"
  },
  "meta": {}
}
```

## GET /v1/attempts
Returns learner history.

### Query Params
- `exercise_id` optional
- `limit` optional, default `20`
- `cursor` optional

### Response
```json
{
  "data": [
    {
      "id": "0c64ff53-3f06-4e86-bede-2b5fe1d4c481",
      "exercise_id": "c46ab0f5-b4f2-451d-b555-aef7d1fd2288",
      "exercise_type": "uloha_1_topic_answers",
      "status": "completed",
      "readiness_level": "almost_ready",
      "started_at": "2026-04-21T08:30:00Z",
      "completed_at": "2026-04-21T08:31:30Z"
    }
  ],
  "meta": {
    "next_cursor": null
  }
}
```

## Mock Test Endpoints (learner)

## GET /v1/mock-tests
Returns all published mock test templates. Learner uses this to pick an exam before starting.

### Response
```json
{
  "data": [
    {
      "id": "mt-1",
      "title": "Modelový test 2 — Mluvení",
      "description": "Full A2 speaking exam: 4 sections, 40 points total.",
      "estimated_duration_minutes": 15,
      "status": "published",
      "sections": [
        { "sequence_no": 1, "exercise_id": "...", "exercise_type": "uloha_1_topic_answers", "max_points": 8 },
        { "sequence_no": 2, "exercise_id": "...", "exercise_type": "uloha_2_dialogue_questions", "max_points": 12 },
        { "sequence_no": 3, "exercise_id": "...", "exercise_type": "uloha_3_story_narration", "max_points": 10 },
        { "sequence_no": 4, "exercise_id": "...", "exercise_type": "uloha_4_choice_reasoning", "max_points": 7 }
      ]
    }
  ],
  "meta": {}
}
```

## Mock Exam Endpoints

## POST /v1/mock-exams
Creates a new mock oral exam session. `mock_test_id` is optional — if omitted, falls back to hardcoded one-exercise-per-type selection.

V39 — every new session carries a server-anchored timer: `started_at` (mirrors `created_at`), `duration_sec` (copied from `mock_tests.estimated_duration_minutes * 60`, with 5400 only as the template-less fallback), and `expires_at` (derived). Sections include a `display_order` int — server ranks them by `(max_points ASC, sequence_no ASC)` and exposes them already sorted. Pre-V39 sessions report `duration_sec=0`; the timer sweeper ignores them.

### Request
```json
{
  "mock_test_id": "mt-1"
}
```

### Response
```json
{
  "data": {
    "id": "3b3319e3-01c4-4878-9362-cf64b6b3d326",
    "status": "in_progress",
    "mock_test_id": "mt-1",
    "overall_score": 0,
    "passed": false,
    "started_at": "2026-05-12T10:00:00Z",
    "duration_sec": 900,
    "expires_at": "2026-05-12T10:15:00Z",
    "sections": [
      { "sequence_no": 4, "display_order": 1, "exercise_id": "...", "exercise_type": "uloha_4_choice_reasoning", "max_points": 7, "status": "pending" },
      { "sequence_no": 1, "display_order": 2, "exercise_id": "...", "exercise_type": "uloha_1_topic_answers", "max_points": 8, "status": "pending" },
      { "sequence_no": 3, "display_order": 3, "exercise_id": "...", "exercise_type": "uloha_3_story_narration", "max_points": 10, "status": "pending" },
      { "sequence_no": 2, "display_order": 4, "exercise_id": "...", "exercise_type": "uloha_2_dialogue_questions", "max_points": 12, "status": "pending" }
    ]
  },
  "meta": {}
}
```

## GET /v1/mock-exams/:session_id
Returns mock exam session progress and section status. Sections sorted by `display_order` ASC.

V39 — pass `?include_server_time=true` to receive `meta.server_time` (RFC3339Nano) so the client can anchor countdown without drift.

### Response
```json
{
  "data": {
    "id": "3b3319e3-01c4-4878-9362-cf64b6b3d326",
    "status": "in_progress",
    "mock_test_id": "mt-1",
    "overall_score": 0,
    "passed": false,
    "started_at": "2026-05-12T10:00:00Z",
    "duration_sec": 900,
    "expires_at": "2026-05-12T10:15:00Z",
    "sections": [
      { "sequence_no": 4, "display_order": 1, "exercise_id": "...", "exercise_type": "uloha_4_choice_reasoning", "max_points": 7, "attempt_id": "0c64ff53-...", "section_score": 0, "status": "completed" },
      { "sequence_no": 1, "display_order": 2, "exercise_id": "...", "exercise_type": "uloha_1_topic_answers", "max_points": 8, "attempt_id": "", "section_score": 0, "status": "skipped" },
      { "sequence_no": 3, "display_order": 3, "exercise_id": "...", "exercise_type": "uloha_3_story_narration", "max_points": 10, "attempt_id": "", "section_score": 0, "status": "pending" }
    ]
  },
  "meta": { "server_time": "2026-05-12T10:05:30.123Z" }
}
```

Section `status` values (V39): `pending` | `completed` | `skipped`.

## POST /v1/mock-exams/:session_id/advance
Associates a section with an attempt ID. Two modes:

**Linear (default)** — server finds the next pending section whose exercise matches the attempt and marks it `completed`.

**Jump-back (V39)** — when `target_display_order` is present, the server attaches the attempt to the section at that `display_order` regardless of prior status. Used by the answer-sheet revisit flow; works on `pending` / `skipped` / `completed` sections (overwrites the prior `attempt_id` on the latter two).

Notes:
- the attempt must belong to the authenticated learner
- linear mode: the attempt exercise must match the next pending section exercise
- for speaking sections, the attempt may be recorded but not analysed yet; this lets the learner complete all recordings before the bulk analysis step
- for listening, reading, and writing sections, the Flutter flow calls this only after the section attempt is already scored
- this endpoint does not compute section scores

### Request
```json
{ "attempt_id": "0c64ff53-3f06-4e86-bede-2b5fe1d4c481" }
```

With jump-back:
```json
{
  "attempt_id": "0c64ff53-...",
  "target_display_order": 3
}
```

### Response
Updated session (same shape as GET).

## POST /v1/mock-exams/:session_id/skip
V39 — marks a pending section as `skipped` so the learner can move past it. The section stays addressable from the answer sheet; revisits land on `/advance` with `target_display_order` and overwrite the skipped state with the new attempt.

### Request
```json
{ "display_order": 3 }
```

### Response
- 200 OK → updated session (same shape as GET) with that section's `status='skipped'`, `attempt_id=''`
- 400 invalid_request → `display_order` missing or ≤ 0
- 403 forbidden → caller is not the session owner
- 404 not_found → unknown session or `(session_id, display_order)` does not exist
- 409 section_not_skippable → section is already `completed`/`skipped` or the session has been completed

## POST /v1/mock-exams/:session_id/expire
V39 — learner-facing "Nộp bài ngay". Marks remaining `pending` sections as `skipped` and flips the session to `completed`. Same logic the server-side timer sweeper invokes when `expires_at` passes; idempotent for already-completed sessions. No scoring rollup — completed-attempt scoring happens through the regular `/complete` path or shows up at section_score=0 when expired.

### Request
```json
{}
```

### Response
- 200 OK → updated session (same shape as GET) with `status='completed'`
- 403 forbidden → caller is not the session owner
- 404 not_found → unknown session

## POST /v1/mock-exams/:session_id/complete
Computes scores, marks session complete, returns final result.

Preconditions (V39 updated):
- every section is either `completed` (linked to a scored attempt) or `skipped`
- every linked attempt has `status=completed`
- every linked attempt has feedback or objective scoring metadata
- skipped sections score 0 and do not block this endpoint
- speaking-only mock tests receive the 3-point pronunciation/readiness bonus only for the canonical 4-section, 37-point oral exam shape

### Request
```json
{}
```

### Response
```json
{
  "data": {
    "id": "3b3319e3-01c4-4878-9362-cf64b6b3d326",
    "status": "completed",
    "mock_test_id": "mt-1",
    "overall_score": 28,
    "passed": true,
    "overall_readiness_level": "almost",
    "overall_summary": "Gần đến rồi! Ôn thêm một vài phần và bạn sẽ sẵn sàng.",
    "sections": [
      { "sequence_no": 1, "exercise_type": "uloha_1_topic_answers", "max_points": 8, "section_score": 6, "attempt_id": "...", "status": "completed" },
      { "sequence_no": 2, "exercise_type": "uloha_2_dialogue_questions", "max_points": 12, "section_score": 9, "attempt_id": "...", "status": "completed" },
      { "sequence_no": 3, "exercise_type": "uloha_3_story_narration", "max_points": 10, "section_score": 7, "attempt_id": "...", "status": "completed" },
      { "sequence_no": 4, "exercise_type": "uloha_4_choice_reasoning", "max_points": 7, "section_score": 4, "attempt_id": "...", "status": "completed" }
    ]
  },
  "meta": {}
}
```

## CMS Mock Test Endpoints

## GET /v1/admin/mock-tests
List all mock test templates (all statuses).

## POST /v1/admin/mock-tests
Create a new mock test template.

### Request
```json
{
  "title": "Modelový test 2 — Mluvení",
  "description": "Full A2 speaking exam: 4 sections, 40 points total.",
  "estimated_duration_minutes": 15,
  "status": "draft",
  "sections": [
    { "sequence_no": 1, "exercise_id": "...", "exercise_type": "uloha_1_topic_answers", "max_points": 8 },
    { "sequence_no": 2, "exercise_id": "...", "exercise_type": "uloha_2_dialogue_questions", "max_points": 12 },
    { "sequence_no": 3, "exercise_id": "...", "exercise_type": "uloha_3_story_narration", "max_points": 10 },
    { "sequence_no": 4, "exercise_id": "...", "exercise_type": "uloha_4_choice_reasoning", "max_points": 7 }
  ]
}
```

## GET /v1/admin/mock-tests/:id
Get a single mock test template.

## PATCH /v1/admin/mock-tests/:id
Update title, description, duration, status, or sections. Sections are fully replaced.

## DELETE /v1/admin/mock-tests/:id
Delete a draft mock test. Published tests cannot be deleted.

## Learning Plan Endpoint

## GET /v1/plan
Returns the learner's simple 14-day plan.

### Response
```json
{
  "data": {
    "current_day": 3,
    "days": [
      {
        "day": 1,
        "label": "Lam quen voi cau hoi theo chu de",
        "status": "completed",
        "module_id": "a8b74ad2-2f5c-41c6-bdd9-cc1d5e388558"
      },
      {
        "day": 2,
        "label": "Ke chuyen theo tranh",
        "status": "completed",
        "module_id": "0d55a030-5704-445c-a09d-42b13b8c1097"
      },
      {
        "day": 3,
        "label": "Chon va giai thich",
        "status": "current",
        "module_id": "bf9104af-dd12-46db-8d55-226f6e534dc1"
      }
    ]
  },
  "meta": {}
}
```

## CMS Endpoints

## GET /v1/admin/courses
List all courses (all statuses).

## POST /v1/admin/courses
Create a course. Body: `{ title, description, sequence_no, status }`.

## GET /v1/admin/courses/:id
## PATCH /v1/admin/courses/:id
## DELETE /v1/admin/courses/:id — draft only.

## GET /v1/admin/modules
List all modules. Query params: `?course_id=`, `?kind=`.

## POST /v1/admin/modules
Create a module. Body: `{ course_id, title, description, module_kind, sequence_no, status }`.

## GET /v1/admin/modules/:id
## PATCH /v1/admin/modules/:id
## DELETE /v1/admin/modules/:id — draft only.

## GET /v1/admin/skills
List all skills. Query params: `?module_id=`.

## POST /v1/admin/skills
Create a skill. Body: `{ module_id, skill_kind, title, sequence_no, status }`.

## GET /v1/admin/skills/:id
## PATCH /v1/admin/skills/:id
## DELETE /v1/admin/skills/:id — draft only.

## GET /v1/admin/exercises
Returns exercise rows for the CMS table view.

### Query Params
- `status` optional
- `exercise_type` optional
- `pool` optional: `course` or `exam`
- `skill_id` optional

## POST /v1/admin/exercises
Creates an exercise with common fields and task-specific detail.

### Request
```json
{
  "skill_id": "skill-abc123",
  "exercise_type": "uloha_3_story_narration",
  "title": "Nakup televize",
  "short_instruction": "Ke lai pribeh podle 4 obrazku.",
  "learner_instruction": "Musite mluvit v minulem case a pouzit vsechny 4 obrazky.",
  "estimated_duration_sec": 120,
  "prep_time_sec": 15,
  "recording_time_limit_sec": 60,
  "sample_answer_enabled": true,
  "detail": {
    "story_title": "Nakup televize",
    "image_asset_ids": [
      "af5a6de6-4d67-4bbf-8d5c-c9bc1bb2d19f",
      "d4474a46-c66d-41de-b0ae-ec9be132fc99",
      "9add3d85-fbee-49a2-a723-92539509650c",
      "d294ba76-fb40-4eb8-89a1-e1cbc385637a"
    ],
    "narrative_checkpoints": [
      "otec a syn sli do obchodu",
      "divali se na televize",
      "vybrali jednu televizi",
      "odnesli ji domu"
    ],
    "grammar_focus": [
      "past_tense"
    ]
  }
}
```

### Response
```json
{
  "data": {
    "id": "f4c09b2b-55d3-4bc1-a549-d21fa523e47b",
    "status": "draft"
  },
  "meta": {}
}
```

## GET /v1/admin/exercises/:exercise_id
Returns the full CMS editing payload for one exercise.

## PATCH /v1/admin/exercises/:exercise_id
Updates common fields, detail fields, or status.

## DELETE /v1/admin/exercises/:exercise_id
Deletes one exercise from the CMS inventory.

### Response
```json
{
  "data": {
    "id": "f4c09b2b-55d3-4bc1-a549-d21fa523e47b",
    "deleted": true
  },
  "meta": {}
}
```

## POST /v1/admin/exercises/:exercise_id/assets/upload-url
Returns a presigned upload target for exercise assets.

### Request
```json
{
  "asset_kind": "image",
  "mime_type": "image/jpeg"
}
```

## POST /v1/admin/exercises/:exercise_id/assets
Registers an uploaded asset against the exercise.

### Request
```json
{
  "asset_kind": "image",
  "storage_key": "exercise-assets/2026/04/story-1.jpg",
  "mime_type": "image/jpeg",
  "sequence_no": 1
}
```

## PUT /v1/admin/exercises/:exercise_id/scoring-template
Creates or replaces the scoring template for an exercise.

### Request
```json
{
  "rubric_version": "v1",
  "task_completion_rules": {
    "must_cover_all_images": true,
    "min_reason_count": 0
  },
  "feedback_style": "supportive_direct_vi",
  "sample_answer_text": "Vcera sli otec a syn do obchodu a koupili novou televizi."
}
```

## GET /v1/admin/attempts
Returns attempts for review in the CMS.

### Query Params
- `exercise_id` optional
- `user_id` optional
- `status` optional
- `limit` optional

## GET /v1/admin/attempts/:attempt_id
Returns the full review payload, including transcript and learner-visible feedback.

## Polling and Client Behavior

### Learner Attempt Flow
1. `POST /v1/attempts`
2. Optional `POST /v1/attempts/:attempt_id/recording-started`
3. `POST /v1/attempts/:attempt_id/upload-url`
4. Client uploads audio directly to storage
5. `POST /v1/attempts/:attempt_id/upload-complete`
6. Poll `GET /v1/attempts/:attempt_id` until `completed` or `failed`

### Recommended Polling Policy
- Poll every `2 seconds` for the first `20 seconds`
- Then poll every `4 seconds`
- Stop polling at `completed` or `failed`
- Offer retry on `failed` if `retryable=true`

## Validation Rules by Endpoint

### POST /v1/attempts
- Reject if the exercise is not published.
- Reject if the learner already has an active attempt on the same exercise.

### POST /v1/attempts/:attempt_id/upload-url
- Reject unsupported MIME types.
- Reject file sizes over the configured maximum.

### POST /v1/attempts/:attempt_id/upload-complete
- Reject if the attempt is not in a pre-upload state.
- Reject if the storage key does not match the issued upload target.

### POST /v1/admin/exercises
- Reject if task-specific required fields are missing.
- Reject if exercise type and detail payload do not match.

## POST /v1/attempts/:attempt_id/submit-text

Submit written text for a writing attempt. Handler dispatches on
`exercise_type`:
- `psani_1_formular` → `answers[]`
- `psani_2_email` → `text`
- `psani_3_dictation` → `sentences[]` (V18)

Triggers async LLM scoring — poll `GET /v1/attempts/:attempt_id` until
`status=completed`.

### Request
```json
{
  "answers": ["câu trả lời 1", "câu trả lời 2"],
  "text": "full email text",
  "sentences": [
    { "idx": 0, "text": "Pavel jde do kavárny.", "replay_count": 1 },
    { "idx": 1, "text": "Děkuji.", "replay_count": 0 }
  ]
}
```
- `answers`: one string per `psani_1_formular` question; at least 1 answer. Each ≥10 words (server-side validation, 400 otherwise).
- `text`: single string for `psani_2_email`. ≥35 words.
- `sentences`: V18 dictation — count must match exercise sentence count, each text ≤200 runes. `replay_count` is telemetry only (never affects score).
- Only one field is used per `exercise_type`.

### Response
```json
{ "data": { "attempt_id": "...", "status": "scoring" }, "meta": {} }
```

### Errors
- `400 invalid_word_count` — writing text below minimum
- `400 invalid_sentence_count` — dictation sentence count mismatch
- `400 sentence_too_long` — dictation sentence > 200 runes
- `409 attempt_not_pending` — attempt not in `created` state

---

## POST /v1/attempts/:attempt_id/dictation-ocr-preview *(V18.1)*

Single-image preview for dictation OCR submissions. Learner uploads
one handwritten-sentence photo; backend runs Claude Vision and returns
the recognized text + the persisted asset_id the client echoes back at
submit time.

**OCR is fail-soft**: any provider error returns 200 with `text: ""`
so the learner can retake the photo or type instead. The endpoint
never returns 5xx because of OCR.

### Request (multipart/form-data)
| Field | Type | Notes |
|-------|------|-------|
| `idx` | int form field | 0..7 — sentence index |
| `image` | file field | jpeg/png/webp, ≤5 MB |

### Response 200
```json
{
  "data": {
    "idx": 0,
    "text": "Včera jsem byl v kavárně.",
    "asset_id": "dictation-ocr/<attempt_id>/img-<nanos>.jpg"
  },
  "meta": {}
}
```

### Errors
- `400 validation_error` — non-dictation attempt, missing `idx` field, missing `image` file
- `400 invalid_idx` — idx outside 0..7
- `403 forbidden` — caller doesn't own the attempt
- `415 image_invalid_type` — MIME not in {jpeg, png, webp}
- `413 image_too_large` — image > 5 MB
- `429 rate_limited` — > 30 preview calls per minute per user

### Notes
- Image persisted under `LOCAL_ASSETS_DIR/dictation-ocr/<attempt_id>/img-<nanos>.<ext>` for audit
- `asset_id` returned is the storage key; learner echoes it back at submit time
- Backend env: `LLM_OCR_PROVIDER=claude` + `ANTHROPIC_API_KEY` required for non-empty OCR; otherwise NoopOCR returns empty text

---

## POST /v1/attempts/:attempt_id/submit-dictation-ocr *(V18.1)*

Final submit for dictation OCR (or mixed type/OCR via
`submission_mode="both"`). Each row carries the learner-confirmed text
+ the asset_id from the preview step. Backend reuses the V18
deterministic Levenshtein scorer — score parity with submit-text.

### Request (multipart/form-data)
| Field | Type | Notes |
|-------|------|-------|
| `sentences` | JSON form field | array of `{idx, text, asset_id, replay_count}` |

```json
[
  {"idx": 0, "text": "Pavel jde do kavárny.", "asset_id": "dictation-ocr/.../img-1.jpg", "replay_count": 1},
  {"idx": 1, "text": "Děkuji.", "asset_id": "", "replay_count": 0}
]
```
- For `submission_mode="both"`, type-mode rows have empty `asset_id`.
- `replay_count` is telemetry only.

### Response 202
```json
{ "data": { "attempt_id": "...", "status": "scoring" }, "meta": {} }
```

### Errors
- `400 validation_error` — non-dictation attempt, missing `sentences` field
- `400 invalid_sentence_count` — count doesn't match exercise
- `400 sentence_too_long` — any text > 200 runes
- `403 forbidden` — caller doesn't own the attempt
- `409 attempt_not_pending` — attempt not in `created` state
- `413 payload_too_large` — body > 64 KB

---

## POST /v1/attempts/:attempt_id/submit-answers

Submit objective answers for listening (`poslech_*`) or reading (`cteni_*`) attempts.
Scoring là **synchronous** — response trả về attempt đã `completed`, không cần poll.

### Request
```json
{ "answers": { "1": "B", "2": "A", "3": "D", "4": "C", "5": "B" } }
```
- Keys = question_no (string "1"–"N")
- Values = answer string: multiple-choice key ("A"/"B"/...) hoặc fill-in text

### Response
```json
{
  "data": {
    "id": "attempt-123",
    "status": "completed",
    "feedback": {
      "readiness_level": "ok",
      "objective_result": {
        "score": 4,
        "max_score": 5,
        "breakdown": [
          { "question_no": 1, "learner_answer": "B", "correct_answer": "B", "is_correct": true },
          { "question_no": 2, "learner_answer": "A", "correct_answer": "C", "is_correct": false }
        ]
      }
    }
  },
  "meta": {}
}
```

### Errors
- `400 validation_error` — body invalid hoặc `answers` rỗng
- `403 forbidden` — caller không sở hữu attempt
- `409 attempt_not_pending` — attempt không còn ở trạng thái `created`
- `422 content_invalid` — bài khách quan đã publish nhưng thiếu
  `correct_answers`, nên backend không thể chấm. Admin cần bổ sung đáp án
  trong CMS rồi học viên làm lại attempt mới.
- `500 internal_error` — lỗi scorer ngoài lỗi cấu hình nội dung đã biết

---

## GET /v1/exercises/:exercise_id/audio

Trả về audio cho listening exercises (`poslech_*`). Same signed-URL pattern as attempt audio.

### Response
```json
{ "data": { "url": "https://...", "expires_in_sec": 300 }, "meta": {} }
```

---

## POST /v1/admin/exercises/:exercise_id/generate-audio

Gọi Polly TTS để generate audio từ text trong exercise detail. Lưu vào `exercise_audio` table.

### Request
```json
{}
```
(Lấy text từ exercise detail — không cần body)

### Response
```json
{ "data": { "storage_key": "exercise-audio/...", "mime_type": "audio/mpeg", "duration_sec": 45 }, "meta": {} }
```

---

---

## POST /v1/interview-sessions/token

Tạo short-lived ElevenLabs Conversational AI signed URL. API key ở server — không expose cho Flutter.

### Auth
Bearer token (learner).

### Request
```json
{
  "exercise_id": "ex-abc",
  "attempt_id": "att-xyz",
  "selected_option": "Praha"
}
```
- `selected_option`: tùy chọn, chỉ dùng cho `interview_choice_explain`. Inject vào `system_prompt` thay `{selected_option}`.
- `selected_option` tối đa 200 ký tự.
- `exercise_id` phải khớp `attempt.exercise_id`.

### Response
```json
{ "data": { "signed_url": "wss://api.elevenlabs.io/...", "expires_in": 30 }, "meta": {} }
```

Flutter mở WebSocket tới `signed_url` trong vòng 30 giây.

### Errors
- `400` — thiếu fields hoặc `selected_option` > 200 chars
- `403` — attempt không thuộc learner, hoặc exercise_id không khớp attempt
- `503` — `ELEVENLABS_API_KEY` chưa cấu hình trên server

---

## POST /v1/attempts/:attempt_id/submit-interview

Nộp transcript interview session. Kích hoạt async LLM scoring.

### Auth
Bearer token (learner, owner của attempt).

### Request
```json
{
  "transcript": [
    { "speaker": "examiner", "text": "Jak se jmenujete?", "at_sec": 0 },
    { "speaker": "learner",  "text": "Jmenuji se Anna.", "at_sec": 3 }
  ],
  "duration_sec": 187
}
```

### Response
```json
{ "data": { "attempt_id": "att-xyz", "status": "scoring" }, "meta": {} }
```

Poll `GET /v1/attempts/:id` cho đến `status=completed`.

---

## Learner Profile Identity (V17.2)

Học viên đã đăng nhập có thể đặt biệt danh + ảnh đại diện. Tất cả endpoint dùng V17 session Bearer token.

## POST /v1/users/me/avatar

Upload ảnh đại diện. Multipart/form-data với field `file`.

### Limits
- Max body 5 MB
- MIME whitelist: `image/jpeg`, `image/png`, `image/webp`

### Response 200
```json
{
  "data": {
    "image_asset_id": "avatars/u_e330f213007ba960/img-1714912088123456789.png",
    "mime_type": "image/png"
  },
  "meta": {}
}
```

`image_asset_id` chính là storage key dùng cho `GET /v1/media/file?key=...` để load ảnh. Backend tự cập nhật `users.avatar_asset_id`; client không cần PATCH thêm.

### Errors
- `413 payload_too_large` — > 5 MB
- `415 unsupported_media_type` — MIME không trong whitelist
- `400 validation_error` — multipart parse fail
- `401` — không có Bearer token

---

## DELETE /v1/users/me/avatar

Xoá avatar hiện tại. File trên disk bị remove + `users.avatar_asset_id` reset về rỗng.

Response: `204 No Content`

---

## PATCH /v1/users/me (V17.2 extension)

Endpoint cũ thêm 2 field optional:
- `avatar_asset_id` — storage key để set/clear avatar (UI thường dùng `/avatar` endpoint trên thay vì gọi trực tiếp)
- `display_name` — biệt danh, validate ≤ 60 runes (UTF-8 aware, đếm ký tự tiếng Việt đúng)

### Errors (mới)
- `400 display_name_too_long` — `display_name` > 60 ký tự

---

## Admin User Management (V17.1)

Tất cả endpoint dưới đây yêu cầu `withRole("admin")` — Bearer token của legacy `dev-admin-token` hoặc V17 admin session.

## GET /v1/admin/users

List tài khoản học viên đang active (chưa soft-delete), paginate + optional search.

### Query
- `limit` (default 50, max 200)
- `offset` (default 0)
- `search` — case-insensitive substring match trên `email` + `display_name`
- `role` — exact match (e.g. `learner`)

### Response 200
```json
{
  "data": [
    {
      "id": "u_e330f213007ba960",
      "email": "anh.ngt18@gmail.com",
      "email_verified": false,
      "display_name": "tuan anh",
      "role": "learner",
      "pro_tier": "free",
      "current_level": "a0",
      "unlocked_levels": ["a0"],
      "grace_attempts_left": 3,
      "attempts_today": 4,
      "attempts_cap": 7,
      "created_at": "2026-05-05T12:12:06Z",
      "updated_at": "2026-05-05T12:12:06Z"
    }
  ],
  "meta": { "total": 12, "limit": 50, "offset": 0 }
}
```

`attempts_today` is the VN-civil-day counter from `daily_usage`. `attempts_cap`
is `freeTierAttemptsPerDay` (currently 7) — the same constant the gate uses
to decide 429. Pro accounts are unlimited; the field is still returned
(both still numeric) but the CMS hides it behind a Pro badge.
`current_level` + `unlocked_levels` mirror the V21 user-level store so
admin can see and manually raise a learner's CEFR level from the Users desk.

### Errors
- `401` — không có Bearer token
- `403` — không phải admin
- `503 users_unavailable` — V17 user store chưa wired

---

## DELETE /v1/admin/users/:id

Soft-delete học viên: anonymise PII, revoke mọi auth_token, free email cho re-register.

### Auth
Admin Bearer.

### Response
`204 No Content`

### Side Effects
1. `users.email = "deleted_<id>@deleted.local"`, `display_name = "(deleted)"`, `avatar_asset_id = ""`, `push_token = ""`, `push_token_platform = ""`
2. `users.deleted_at = now()`
3. Tất cả `auth_tokens` (session + verify + reset) bị `RevokeAllAuthTokensForUser`
4. Email gốc giải phóng cho re-registration (unique index `WHERE deleted_at IS NULL`)
5. Lịch sử `attempts.user_id` không bị xoá để giữ audit trail

### Errors
- `400 self_delete_forbidden` — `caller.ID == target.ID`
- `403 admin_delete_forbidden` — `target.Role == "admin"`
- `404` — user không tồn tại hoặc đã soft-deleted

---

## POST /v1/admin/users/:id/reset-password

Admin đặt password mới trực tiếp cho học viên. Dùng khi học viên mất quyền truy cập email và không tự reset được.

### Auth
Admin Bearer.

### Request
```json
{ "new_password": "BrandNew123!" }
```
Body cap 4 KiB. Password phải đạt strength rule của `auth.ValidatePassword`:
- Min 8 ký tự
- Có ít nhất 1 chữ số hoặc ký tự đặc biệt
- Không có trong common-password block list

### Response
`204 No Content`

### Side Effects
1. `users.password_hash` cập nhật (bcrypt cost 12)
2. Tất cả session token của target bị revoke → mọi thiết bị logout
3. Login rate limiter cho `target.Email` được reset → user có thể login ngay với password mới

### Errors
- `400 invalid_body` — JSON không hợp lệ
- `400 weak_password` / `400 weak_password_common` — password không đạt strength
- `403 admin_reset_forbidden` — `target.Role == "admin"` (admin tự rotate cred ngoài endpoint này)
- `404` — user không tồn tại

**Lưu ý vận hành:** Admin nhập password trong CMS modal rồi gửi cho học viên qua kênh tin cậy (chat/sms), KHÔNG bao giờ gửi qua email vì email có thể đã bị compromise.

---

## POST /v1/admin/users/:id/usage/reset

Admin reset `attempts_count` về 0 cho ngày hôm nay (giờ VN) khi học viên hit
free-tier cap và cần unblock cho QA / support flow. Counter `interviews_count`
giữ nguyên (interview dùng rolling 7-day window, không phải daily reset).

### Auth
Admin Bearer.

### Request
Empty body (POST không cần payload).

### Response
`204 No Content`

### Side Effects
1. `daily_usage.attempts_count = 0 WHERE user_id = $1 AND day = vnCivilDay(now)`
2. Học viên có thể tạo attempt mới ngay lập tức (gate đọc count trước khi increment)

### Errors
- `404` — user không tồn tại
- `503 usage_unavailable` — V17 dailyUsageStore chưa wired

---

## POST /v1/admin/users/:id/level

Admin manually raises a learner's CEFR level, e.g. a learner at A0 can be
set to A1 without running placement / promotion exam flow.

### Auth
Admin Bearer.

### Request
```json
{ "current_level": "a1" }
```

- `current_level` is case-insensitive on input and normalised to lowercase.
- Valid values: `a0`, `a1`, `a2`, `b1`.
- The change is monotonic: same-level is idempotent, higher levels are
  accepted, lower levels return `400 level_downgrade_forbidden`.

### Response
`200 OK`
```json
{
  "data": {
    "id": "u_…",
    "email": "learner@example.com",
    "email_verified": true,
    "display_name": "Học viên",
    "role": "learner",
    "pro_tier": "free",
    "current_level": "a1",
    "unlocked_levels": ["a0", "a1"],
    "grace_attempts_left": 0,
    "attempts_today": 0,
    "attempts_cap": 7,
    "created_at": "2026-04-01T...",
    "updated_at": "2026-05-12T..."
  },
  "meta": {}
}
```

Cùng shape với row của `GET /v1/admin/users`.

### Side Effects
1. Calls `UserLevelStore.SetUserLevel(user_id, current_level)`.
2. `users.current_level` becomes the target level.
3. Target level is appended to `users.unlocked_levels` if missing.
4. No `promotion_attempts` row is created; this is an explicit admin override.

### Errors
- `400 invalid_body` — JSON malformed
- `400 invalid_level` — `current_level` không thuộc `{a0,a1,a2,b1}`
- `400 level_downgrade_forbidden` — target thấp hơn current level
- `403 admin_level_forbidden` — target có `role="admin"`
- `404` — user không tồn tại
- `503 level_store_unavailable` — V21 userLevelStore chưa wired

---

## POST /v1/admin/users/:id/pro

Admin grant / extend / downgrade Pro entitlement on a learner account.
Manual lever — không liên quan tới Apple IAP flow (`ProPurchase` ledger giữ
nguyên). Dùng cho promo, bồi thường, demo trial, comp account.

### Auth
Admin Bearer.

### Request
```json
{ "duration_days": 30 }
```

- `duration_days` **integer**, bắt buộc.
- `> 0` → grant or extend. Set `pro_tier="pro"` và:
  - Nếu user đang **free** hoặc Pro đã hết hạn: `pro_expires_at = now + duration_days * 24h`.
  - Nếu user đang **Pro với hạn còn**: `pro_expires_at = current_expiry + duration_days * 24h` (cộng dồn, học viên không mất ngày còn lại).
- `= 0` → downgrade. Set `pro_tier="free"` và `pro_expires_at=null`.
- `< 0` hoặc `> 3650` (~10 năm) → `400 invalid_duration`.

### Response
`200 OK`
```json
{
  "data": {
    "id": "u_…",
    "email": "learner@example.com",
    "email_verified": true,
    "display_name": "Học viên",
    "role": "learner",
    "pro_tier": "pro",
    "pro_expires_at": "2026-06-11T15:00:00Z",
    "current_level": "a1",
    "unlocked_levels": ["a0", "a1"],
    "grace_attempts_left": 0,
    "attempts_today": 3,
    "attempts_cap": 7,
    "created_at": "2026-04-01T...",
    "updated_at": "2026-05-12T..."
  },
  "meta": {}
}
```

Cùng shape với row của `GET /v1/admin/users`.

### Errors
- `400 invalid_body` — JSON malformed
- `400 invalid_duration` — `duration_days` âm hoặc vượt 3650
- `403 admin_pro_forbidden` — target có `role="admin"` (admin không dùng Pro entitlement)
- `404` — user không tồn tại
- `503 users_unavailable` — V17 userStore chưa wired

### Notes
- Endpoint chỉ chạm `users.pro_tier` + `users.pro_expires_at`. Không tạo
  `ProPurchase` row (admin grant ≠ Apple receipt).
- Free-tier daily attempts gate (V21.2) tự bypass khi Pro còn hạn — không
  cần reset `daily_usage` riêng sau khi nâng cấp.
- Đảo chiều an toàn: gọi lại với `duration_days=0` để hạ về free; gọi tiếp
  với `>0` để bật lại (rebase từ now nếu lúc đó Pro đã expired).

---

## Free-tier attempts gate (V21.2 hardening)

`POST /v1/attempts` đi qua `checkAndIncrAttemptQuota` cho mọi non-admin /
non-pro user. Semantics:

1. Đọc `daily_usage.attempts_count` cho `(user_id, vnCivilDay(now))`.
2. Nếu count `>= freeTierAttemptsPerDay (7)` → trả `429 attempts_quota_exceeded`
   với header `X-Limit-Reset: <unix-epoch>` (next VN civil-day midnight).
3. Nếu count `< cap` → atomic guarded UPSERT bumps count, request proceeds.

**Counter pinned at cap** — trước V21.2, gate increment trước khi check, mỗi
429 burn 1 slot và counter grow vô hạn (8, 9, 10, ...). V21.2 dùng atomic
SQL CTE `INSERT ... ON CONFLICT DO UPDATE WHERE attempts_count < $cap` để
chỉ bump khi dưới cap. Concurrent requests at cap boundary có thể overshoot
1-2 (race acceptable cho free-tier UX) thay vì leak counter.

Admin reset endpoint phía trên là escape hatch khi cần unblock 1 học viên cụ
thể (QA, support).

---

## V24 Reading Draft Generator

### POST /v1/admin/exercises/generate-draft

Admin-only. Generates a draft cteni payload (text + questions + correct
answers) for a given `(topic, grammar, level)` triple via Claude
`tool_use`. Returns the draft for the CMS to fill into the form. The
endpoint never persists; admin reviews + saves manually via the existing
`POST /v1/admin/exercises` (which now also accepts `created_by_llm:true`).

Full schema spec: [docs/specs/v24-doc-draft-generator.md](../specs/v24-doc-draft-generator.md) §4.

**Request body**:

```json
{
  "exercise_type": "cteni_2",
  "topic": "đi khám bác sĩ",
  "grammar_point_ids": ["<uuid>"],
  "level": "A2",
  "extra_instructions": "tone neutral"
}
```

| Field | Constraint |
|---|---|
| `exercise_type` | `cteni_1` … `cteni_6` |
| `topic` | 3–200 chars, trimmed |
| `grammar_point_ids` | 1–3 uuids; each must resolve via `s.repo.GetGrammarRule`; free-text grammar labels are not accepted |
| `level` | `A0` \| `A1` \| `A2` \| `B1` |
| `extra_instructions` | optional, ≤500 chars |

**Response 200**:

```json
{
  "data": {
    "exercise_type": "cteni_2",
    "detail": { /* one of Cteni1Detail … Cteni5Detail or AnoNeDetail */ },
    "metadata": {
      "model": "claude-haiku-4-5-20251001",
      "duration_ms": 6234,
      "input_tokens": 412,
      "output_tokens": 891
    }
  }
}
```

**Generated detail invariants**:

| Type | Server-side validator requirements |
|---|---|
| `cteni_1` | `items[].item_no` exactly `1..5`; 8 options keyed `A..H`; no generated `asset_id`; correct answers cover `1..5` with unique values in `A..H`. |
| `cteni_2` | `text` 100-200 words; 5 questions with `question_no` exactly `6..10`; each question has options `A..D`; correct answers cover `6..10`. |
| `cteni_3` | `texts[].item_no` exactly `1..4`; 5 persons keyed `A..E` with names and optional descriptions; correct answers cover `1..4` with unique values in `A..E`. |
| `cteni_4` | `context` is optional and is the canonical context field; 6 questions with `question_no` exactly `15..20`; each question has options `A..D`; correct answers cover `15..20`. |
| `cteni_5` | `text` 80-150 words; 5 questions with `question_no` exactly `21..25`; correct answers cover `21..25`; each answer is 1-30 chars. |
| `cteni_6` | `passage` 80-150 words; 1-5 statements with `question_no` exactly `1..N`; correct answers are uppercase `ANO`/`NE`; `max_points == len(statements)`. |

CMS compatibility note: older local `cteni_4` drafts that used `text`
are read as context on edit, but newly saved `cteni_4` payloads use
`context`.

**Errors**:

| Status | code | Trigger |
|---|---|---|
| 400 | `invalid_request` | Field validation (8 cases — bad enum, topic length, grammar count, etc.) |
| 404 | `grammar_point_not_found` | Any `grammar_point_ids` entry missing |
| 405 | `method_not_allowed` | Non-POST |
| 422 | `schema_mismatch` | LLM output rejected by `processing.ValidateReadingDraft` |
| 429 | `rate_limited` | >5 calls/min for the same admin email |
| 502 | `llm_error` | Generator returned an error |
| 503 | `not_configured` | `ANTHROPIC_API_KEY` unset (V24 off-switch) |
| 504 | `timeout` | LLM call exceeded 30s |

### POST /v1/admin/exercises (V24 addition)

`POST /v1/admin/exercises` accepts an optional `created_by_llm` boolean
in the request body. Default `false`. The flag is sticky on update —
once `true` an admin edit cannot clear it (`postgres_exercises.upsertExercise`
uses `created_by_llm = exercises.created_by_llm OR EXCLUDED.created_by_llm`).
Used for analytics + dashboard filtering of AI-drafted content.

---

## Open Questions
- Do we want `POST /v1/auth/magic-link` later for pilot onboarding, or is email/password enough for now?
- Keep `GET /v1/attempts/:attempt_id/audio/file` as the playback surface, or later fold playback URLs into the attempt payload if cloud-only playback becomes simpler?
