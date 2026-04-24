# Idea: Provider-Aware Audio Replay

## Problem
Flutter currently downloads each audio asset (learner attempt, TTS model answer) to a temp file before playback. That means:

- learner waits for full file download before they hear anything
- every replay re-downloads the same file
- mobile data cost scales with retry count
- offline replay is impossible today even when audio is already cached

Backend already redirects cloud-stored audio (S3) via `307 Temporary Redirect` to a presigned URL. But the Flutter client does not stream that directly — it pipes the HTTP body to disk first.

## Goal
Let the learner hear audio as soon as enough bytes are buffered, regardless of whether the audio lives on the backend host or in cloud object storage, without breaking the current auth model.

Non-goals:
- no offline download library
- no background prefetch of audio assets
- no peer-to-peer or WebRTC streaming
- no transcoding

## Why Now
- Review-card shadowing flow makes replay a core learner loop — learners now replay the TTS model answer multiple times per attempt.
- Mock exam adds 4x attempts per session, so audio replay cost scales fast.
- S3-stored audio is already the production default; local-file path is mostly a dev convenience.

## Shape
Two surfaces:

1. **Backend**: expose `GET /v1/attempts/:id/audio/url` and `GET /v1/attempts/:id/review/audio/url` that return `{ url, expires_at, mime_type }`. URL may be:
   - a presigned cloud URL (if backend stores cloud storage keys)
   - a short-lived signed path pointing back at the existing `/audio/file` endpoint (for local-file mode)

2. **Flutter**: replace download-then-play with `just_audio.setUrl(url)` using the URL returned above. No `Authorization` header forwarded to cloud. Keep a small in-memory cache of `(attemptId, url, expiresAt)` so replay during same session skips the URL roundtrip until close to expiry.

## Out Of Scope For First Cut
- no disk caching across app launches
- no prewarm on home screen
- no lazy transcoding to smaller codec
- no quality selection toggle
- no websocket-based streaming

## Risks
- presigned URL expiry mid-session — mitigate with `expires_at` and refresh-on-failure
- local-file signed URL scheme adds an auth path distinct from bearer — accept small new primitive, keep it narrow
- iOS AVPlayer quirks with redirect + auth header — eliminated by returning final URL upfront

## Metric For Success
- first-audio-byte → first-playable-frame drops by the current full-download duration
- replay of same asset within session issues zero extra network bytes beyond streaming buffer
