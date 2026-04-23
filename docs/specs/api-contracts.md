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

## GET /v1/course
Returns the learner's active course shell and current day state.

### Response
```json
{
  "data": {
    "course": {
      "id": "f6122020-d85d-4dd6-a5ce-88f7ed4c9f43",
      "slug": "a2-mluveni-sprint",
      "title": "A2 Mluveni Sprint"
    },
    "learning_plan": {
      "start_date": "2026-04-21",
      "current_day": 3,
      "status": "active"
    }
  },
  "meta": {}
}
```

## GET /v1/modules
Returns published modules available to the learner.

### Query Params
- `kind` optional: `daily_plan`, `practice`, `mock_exam`

### Response
```json
{
  "data": [
    {
      "id": "a8b74ad2-2f5c-41c6-bdd9-cc1d5e388558",
      "slug": "day-1",
      "title": "Day 1",
      "module_kind": "daily_plan",
      "sequence_no": 1
    }
  ],
  "meta": {}
}
```

## GET /v1/modules/:module_id/exercises
Returns learner-visible exercises for one module.

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

In the current dev implementation, this target points back to the backend host so the learner app can exercise the same request sequence before durable object storage is added.

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
- provider-aware replay for cloud-only review audio is still a follow-up concern

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
- the current Flutter learner implementation may download this file into app temp storage before playback instead of streaming the authenticated URL directly
- local or cloud `s3` upload mode may still return `404` here until backend replay becomes provider-aware, because the current implementation is strongest when the backend also owns a local `stored_file_path`

### Response
- `200` with binary audio body
- `Content-Type` matches the stored attempt audio mime type

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

## Mock Exam Endpoints

## POST /v1/mock-exams
Creates a new mock oral exam session.

### Request
```json
{
  "course_id": "f6122020-d85d-4dd6-a5ce-88f7ed4c9f43"
}
```

### Response
```json
{
  "data": {
    "session": {
      "id": "3b3319e3-01c4-4878-9362-cf64b6b3d326",
      "status": "created",
      "sections": [
        {
          "sequence_no": 1,
          "exercise_id": "c46ab0f5-b4f2-451d-b555-aef7d1fd2288",
          "exercise_type": "uloha_1_topic_answers"
        },
        {
          "sequence_no": 2,
          "exercise_id": "f4c09b2b-55d3-4bc1-a549-d21fa523e47b",
          "exercise_type": "uloha_3_story_narration"
        }
      ]
    }
  },
  "meta": {}
}
```

## GET /v1/mock-exams/:session_id
Returns mock exam session progress and section status.

### Response
```json
{
  "data": {
    "id": "3b3319e3-01c4-4878-9362-cf64b6b3d326",
    "status": "in_progress",
    "sections": [
      {
        "sequence_no": 1,
        "exercise_id": "c46ab0f5-b4f2-451d-b555-aef7d1fd2288",
        "attempt_id": "0c64ff53-3f06-4e86-bede-2b5fe1d4c481",
        "status": "completed"
      },
      {
        "sequence_no": 2,
        "exercise_id": "f4c09b2b-55d3-4bc1-a549-d21fa523e47b",
        "attempt_id": null,
        "status": "pending"
      }
    ]
  },
  "meta": {}
}
```

## POST /v1/mock-exams/:session_id/complete
Marks the mock exam session complete and returns the aggregated summary.

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
    "overall_readiness_level": "needs_work",
    "overall_summary": "Ban da hoan thanh bai mock, nhung can on dinh hon o phan tra loi va giai thich ly do."
  },
  "meta": {}
}
```

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

## GET /v1/admin/exercises
Returns exercise rows for the CMS table view.

### Query Params
- `status` optional
- `exercise_type` optional
- `module_id` optional

## POST /v1/admin/exercises
Creates an exercise with common fields and task-specific detail.

### Request
```json
{
  "module_id": "a8b74ad2-2f5c-41c6-bdd9-cc1d5e388558",
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

## Open Questions
- Do we want `POST /v1/auth/magic-link` later for pilot onboarding, or is email/password enough for now?
- Keep `GET /v1/attempts/:attempt_id/audio/file` as the playback surface, or later fold playback URLs into the attempt payload if cloud-only playback becomes simpler?
- If `Uloha 2` is delayed in implementation, should its API contracts still ship now or be hidden until the task is active?
