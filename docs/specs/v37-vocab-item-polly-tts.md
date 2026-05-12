# V37 Vocab Item Per-item Polly TTS — Spec

> **Status**: ✅ frozen on 2026-05-12 (slice shipped).
>
> **Linked idea**: [`docs/ideas/v37-vocab-item-polly-tts.md`](../ideas/v37-vocab-item-polly-tts.md).
>
> **Plan**: [`tasks/v37-vocab-item-polly-tts-plan.md`](../../tasks/v37-vocab-item-polly-tts-plan.md).

---

## 1. Slice Goal

Add per-item Polly TTS audio for vocab items, end to end (DB → admin
endpoint → CMS button → Flutter quizcard playback).

---

## 2. Decisions (frozen)

| # | Decision | Resolution |
|---|---|---|
| D1 | Polly Czech voice | Default (Jakub via existing TTSProvider). No voice picker MVP. |
| D2 | Regen cap | None. Admin self-regulates. |
| D3 | Storage retention on item delete | Implicit: storage key only referenced from item row; orphan blobs acceptable for MVP. |
| D4 | Stale audio warning when Term changes | Not surfaced in UI; admin re-clicks 🔊 manually. |
| D5 | Storage namespace | Reuse `exercise-audio/<itemID>/audio.{mp3,wav}`; vocab item IDs are unique under the same prefix so no collision. |
| D6 | Wire injection point | Vocab → exercise publish path (`v6_handlers.go`) injects `audio_storage_key` onto `QuizcardBasicDetail` at the same hook as `image_asset_id` (V11). |
| D7 | Flutter playback | `QuizcardWidget` adds an optional mic button (cyan, matches V36 interview accent); `just_audio` plays storage URL with auth headers. |
| D8 | Migration shape | Single `ALTER TABLE vocabulary_items ADD COLUMN IF NOT EXISTS audio_storage_key TEXT NOT NULL DEFAULT ''` (migration 029 + addColumnIfMissing on startup). |

---

## 3. Contracts

### 3.1 Wire (Go)

`contracts.VocabularyItem` gains:

```go
AudioStorageKey string `json:"audio_storage_key,omitempty"`
```

`contracts.QuizcardBasicDetail` gains the same field (injected at
publish time):

```go
AudioStorageKey string `json:"audio_storage_key,omitempty"`
```

### 3.2 HTTP

`POST /v1/admin/vocabulary-items/:id/generate-audio` (admin role):

- 200 OK → `{data: {id, audio_storage_key, mime_type, source_type, generated_at}}`
- 404 not_found → item missing
- 400 validation_error → item.Term is blank
- 500 internal_error → Polly synth failed
- 405 → non-POST

### 3.3 CMS

`/api/admin/vocabulary-items/[itemId]/generate-audio` (Next.js route)
proxies the admin token; CMS browser code never sees it.

### 3.4 Flutter

`ExerciseDetail.flashcardAudioStorageKey` — empty when no audio.
`QuizcardWidget.audioUrl` — optional; renders the mic button only when
non-empty.

---

## 4. Test Plan (implemented)

- **Backend**: 3 tests in `vocab_item_audio_test.go` — happy path
  (persists key + returns it), 404 missing item, 400 empty term.
- **Flutter**: 3 tests in `quizcard_audio_test.dart` — null/empty/set
  audioUrl visibility.
- **CMS**: visual only; admin row action wired via existing pattern,
  308 vitest tests unchanged.

---

## 5. Rollout

- Migration 029 applies via `addColumnIfMissing` on next backend
  startup — no downtime.
- Pre-V37 builds ignore `audio_storage_key` (Flutter parses with `??
  ''` and the mic button hides when empty).
- Cost projection from idea § 3: ~$0.04 per 1k vocab items; well
  under the existing exercise-audio Polly budget.

---

## 6. References

- [docs/ideas/v37-vocab-item-polly-tts.md](../ideas/v37-vocab-item-polly-tts.md)
- `backend/internal/processing/exercise_audio.go` — Polly generator.
- `backend/internal/httpapi/v6_handlers.go` — vocab publish hook.
- `flutter_app/lib/features/exercise/widgets/quizcard_widget.dart`.
