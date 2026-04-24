# Plan: Provider-Aware Audio Replay

> **Status (2026-04-25):** Shipped. Backend exposes `GET /v1/attempts/:id/audio/url` and `.../review/audio/url` returning signed playable URLs (presigned S3 for cloud, HMAC-signed backend stream for local). Flutter playback cards stream via `just_audio.setUrl` and refresh the URL on playback errors. Legacy download helpers removed. AGENTS.md updated.

## Goal
Ship streaming playback for attempt + review audio across both storage modes (local file and S3) without forwarding bearer tokens to cloud storage.

## Strategy
Three tight phases. Backend first so Flutter can stream against a stable contract.

- **Phase 1** — backend signing primitive + two new endpoints. No Flutter change.
- **Phase 2** — Flutter playback cards switch from download-then-play to stream-by-URL.
- **Phase 3** — cleanup old download path, trim unused helpers.

Each phase leaves repo shippable.

---

## Phase 1: Backend

### Task 1.1 — `AudioURLProvider` interface + HMAC local scheme
**Files:**
- `backend/internal/processing/audio_url_provider.go` (new)
- `backend/internal/processing/audio_url_provider_test.go` (new)

Interface:
```go
type AudioURLProvider interface {
    SignedAudioURL(ctx context.Context, scope Scope, storageKey, attemptID string, expiresIn time.Duration) (string, error)
}
```

Two implementations:
- `localSignedProvider` — HMAC-signs `(attempt_id | expiry_unix | scope)`, returns `{baseURL}/v1/attempts/:id/audio/file?t=<b64>&exp=<unix>` (or `/review/audio/file`).
- `s3PresignedProvider` — reuses existing S3 client; returns 10-min GET URL.

**Acceptance:**
- [ ] HMAC signs and verifies round-trip with shared secret.
- [ ] Expired token returns `ErrAudioURLExpired`.
- [ ] Wrong-scope token returns `ErrAudioURLWrongScope`.

### Task 1.2 — Token verification in `/audio/file` + `/review/audio/file`
**Files:**
- `backend/internal/httpapi/server.go`

Add `verifyAudioQueryToken(r, attemptID, scope)` helper. If `t` present and valid, skip bearer check. Else keep bearer path unchanged.

**Acceptance:**
- [ ] GET `/audio/file?t=<valid>&exp=<future>` returns the audio bytes without `Authorization`.
- [ ] Invalid token → 401 `audio_url_invalid`.
- [ ] Expired token → 401 `audio_url_expired`.
- [ ] Bearer path keeps working with no query token.

### Task 1.3 — Two new URL endpoints
**Files:**
- `backend/internal/httpapi/server.go`
- `backend/internal/httpapi/server_test.go`

Routes:
- `GET /v1/attempts/:id/audio/url`
- `GET /v1/attempts/:id/review/audio/url`

Response shape per spec.

**Acceptance:**
- [ ] Cloud storage key → response URL is the presigned cloud URL.
- [ ] Local storage key → response URL is `{baseURL}/v1/attempts/:id/(review/)?audio/file?t=...&exp=...`.
- [ ] 404 when no stored audio / no review TTS audio.
- [ ] 403 for non-owner non-admin.

### Task 1.4 — Wire provider into `main.go`
**Files:**
- `backend/cmd/api/main.go`

Read `AUDIO_SIGN_SECRET`; if empty, generate random at boot and log a dev-only warning. Pick `s3PresignedProvider` when `S3_BUCKET` is set, otherwise `localSignedProvider`.

**Acceptance:**
- [ ] Dev mode (no secret, no bucket) works and signs locally.
- [ ] Cloud mode returns presigned URLs.

### Phase 1 Verification
- `/usr/local/go/bin/go test ./...`
- Manual: `curl -H 'Authorization: Bearer <t>' .../v1/attempts/<id>/audio/url` returns JSON with playable URL; `curl -sL <url>` streams bytes.

---

## Phase 2: Flutter

### Task 2.1 — API client additions
**Files:**
- `flutter_app/lib/core/api/api_client.dart`

Add:
```dart
Future<AttemptAudioUrl> getAttemptAudioUrl(String attemptId);
Future<AttemptAudioUrl> getAttemptReviewAudioUrl(String attemptId);
```

Tiny model: `{ Uri url, DateTime expiresAt, String mimeType }`.

### Task 2.2 — Rewire `AttemptAudioPlaybackCard` + `ReviewAudioPlaybackCard`
**Files:**
- `flutter_app/lib/shared/widgets/audio_playback_card.dart`

Replace `_prepare()` download block with:
```dart
final info = await widget.client.getAttemptAudioUrl(widget.attemptId);
final dur = await _player.setUrl(info.url.toString());
```

Drop `getTemporaryDirectory` import + `downloadAttempt*Audio` usage. Keep error-path messages and loading spinner.

**Acceptance:**
- [ ] Playback on iOS starts within ~1s against S3-backed attempt.
- [ ] Playback works against local backend (dev).
- [ ] Replay during same session does not refetch URL unless expiry within 60s.

### Task 2.3 — URL refresh on playback error
**Files:**
- `flutter_app/lib/shared/widgets/audio_playback_card.dart`

If player error stream fires once, fetch fresh URL and call `setUrl` again. Guard with single-retry flag.

### Task 2.4 — Widget test
**Files:**
- `flutter_app/test/widget_test.dart` or new file

Use fake `ApiClient` returning a fixed data URL or fixture file URL. Assert `setUrl` was called with the provided URL.

### Phase 2 Verification
- `make flutter-analyze && make flutter-test`
- Manual: learner records on iOS, taps play — hears first audio under 2s.
- Manual: review-card TTS plays immediately on load.

---

## Phase 3: Cleanup

### Task 3.1 — Delete download helpers if unused
**Files:**
- `flutter_app/lib/core/api/api_client.dart`

Remove `downloadAttemptAudio` + `downloadAttemptReviewAudio` if no remaining callers.

### Task 3.2 — Spec doc pointer in `AGENTS.md`
**Files:**
- `AGENTS.md`

Strike "provider-aware replay for cloud-only audio artifacts" from the Good Next Steps list; move to a "shipped" line or remove.

### Task 3.3 — Update plan status banner
**Files:**
- `docs/plans/provider-aware-audio-replay-plan.md`

Flip to `Status: Shipped 2026-..-..`.

---

## Scope Discipline
- Do not add disk caching. URL-level streaming only.
- Do not change upload path. Only the playback path.
- Do not rename `/audio/file` — keep existing contract intact.
- Do not introduce a new audio library — `just_audio` already handles streaming.

## Risks
| Risk | Phase | Mitigation |
|---|---|---|
| iOS AVPlayer forwards `Authorization` on redirect | 2 | Eliminated by never putting bearer on final URL; final URL is already resolved server-side. |
| Clock skew invalidates expiry | 1 | 10-min TTL absorbs typical skew; refresh-on-error covers edge. |
| Dev environment has no persistent signing secret | 1 | Boot-time random secret OK for dev; log warning; production must set env. |
| Player keeps buffering pre-expiry URL across replays | 2 | `just_audio` re-requests on `setUrl`, not during replay of a buffered session. Session cache is short. |

## Recommended Build Order
1. Task 1.1 → 1.2 → 1.3 → 1.4 (backend)
2. Task 2.1 → 2.2 → 2.3 → 2.4 (Flutter)
3. Task 3.1 → 3.2 → 3.3 (cleanup)

## Definition Of Ready
- [x] Spec accepted.
- [x] TTL + token scheme acknowledged.
- [ ] Production env can set `AUDIO_SIGN_SECRET`.
