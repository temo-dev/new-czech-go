# Spec: Provider-Aware Audio Replay

## Overview
This spec defines how the Flutter learner app streams stored audio (attempt recordings + TTS model answers) without downloading the whole file first, and without exposing backend bearer tokens to third-party cloud object storage.

Related:
- [idea](/Users/daniel.dev/Desktop/czech-go-system/docs/ideas/provider-aware-audio-replay.md)
- [api-contracts.md](/Users/daniel.dev/Desktop/czech-go-system/docs/specs/api-contracts.md)
- [infrastructure-baseline.md](/Users/daniel.dev/Desktop/czech-go-system/docs/specs/infrastructure-baseline.md)

## Goals
- Learner hears audio as soon as `just_audio` buffers enough bytes.
- Same contract covers local-file backend mode and cloud storage mode.
- No bearer token ever sent to cloud storage.
- No breaking change to `/audio/file` — existing clients keep working.

## Non-Goals
- persistent disk caching
- offline replay after app restart
- background prefetch
- transcoding

## API Additions

### `GET /v1/attempts/:attempt_id/audio/url`
Returns a short-lived playable URL for the learner's submitted attempt audio.

**Auth**: bearer token, same as `/audio/file`.

**Response 200**:
```json
{
  "data": {
    "url": "https://bucket.s3.region.amazonaws.com/...X-Amz-Signature=...",
    "mime_type": "audio/m4a",
    "expires_at": "2026-04-25T15:04:05Z"
  },
  "meta": {}
}
```

**Response 404**: attempt has no stored audio.

**Response 403**: caller not owner and not admin.

### `GET /v1/attempts/:attempt_id/review/audio/url`
Same contract for the TTS model-answer audio on the review artifact.

**Response 404**: review artifact absent or no TTS audio attached.

### URL Kinds
Two URL kinds may be returned:

1. **`cloud`** — direct presigned URL against the object store. Backend already has the signing primitive in the upload path. The URL is fully usable by any HTTP client; `Authorization` header **must not** be forwarded to it.
2. **`local`** — backend host URL with a short-lived query token, e.g. `https://api.example.com/v1/attempts/:id/audio/file?t=<opaque>&exp=<unix>`. The token is HMAC-signed over `(attempt_id, expiry, scope)` with a server secret. `/audio/file` accepts either `Authorization: Bearer ...` OR the `t` query param, not both required.

Clients never need to distinguish the two — they always just `setUrl` the returned value.

## TTL
- cloud URL expires in 10 minutes
- local signed URL expires in 10 minutes
- response carries `expires_at` as RFC 3339 UTC

## Client Behavior

### Flutter
- `AttemptAudioPlaybackCard` and `ReviewAudioPlaybackCard` stop using `downloadAttempt*Audio`.
- On `initState`, call `getAttemptAudioUrl(attemptId)` / `getAttemptReviewAudioUrl(attemptId)`, then `_player.setUrl(url)`.
- Cache `(attemptId, url, expiresAt)` in a tiny per-session map keyed off `ApiClient`. Skip refetch if `expiresAt` is more than 60s away.
- On playback error or HTTP 403/410 from cloud, fetch a fresh URL once and retry.

### Backend
- `handleAttemptAudioURL` + `handleAttemptReviewAudioURL` handlers in `backend/internal/httpapi/server.go`.
- New `AudioURLProvider` interface:
  ```go
  type AudioURLProvider interface {
      SignedAudioURL(ctx context.Context, storageKey string, expiresIn time.Duration) (string, error)
  }
  ```
  - S3 implementation returns presigned GET.
  - Local fallback returns `{base}/v1/attempts/:id/audio/file?t=...&exp=...` after HMAC signing.
- `/audio/file` handler accepts the `t` query param as an alternative to bearer, validates HMAC + expiry + matching attempt_id. Keeps bearer path untouched.

## Security Notes
- Signing secret comes from `AUDIO_SIGN_SECRET`; falls back to a random value generated at process start (dev only). Production must set it.
- HMAC payload: `attempt_id | expiry_unix | scope` where scope is `attempt_audio` or `review_audio`.
- Query-token scope is checked against endpoint. A token minted for `review_audio` cannot open `/audio/file`.
- No state persisted on backend — tokens are self-validating.

## Error Codes
| Case | HTTP | Code |
|---|---|---|
| no stored audio | 404 | `audio_missing` |
| attempt not owned | 403 | `forbidden` |
| token expired (local scheme) | 401 | `audio_url_expired` |
| token signature invalid | 401 | `audio_url_invalid` |
| provider failed to sign | 502 | `audio_url_provider_failed` |

## Migration
- `/audio/file` keeps working unchanged.
- New endpoints additive — clients upgrade when ready.
- No DB migration.

## Verification Hooks
- backend tests cover: local signing happy-path, expired token, wrong-scope token, missing audio, cloud provider returning URL.
- Flutter widget test covers: URL fetch + setUrl call; URL refresh on playback error.
- Manual: learner records attempt on iOS, taps play. Audio starts within ~1s even on 3G.
