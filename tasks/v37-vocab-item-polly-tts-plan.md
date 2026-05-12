# V37 Vocab Item Per-item Polly TTS — Plan

> **Status**: ✅ shipped 2026-05-12.
>
> **Spec**: [`docs/specs/v37-vocab-item-polly-tts.md`](../docs/specs/v37-vocab-item-polly-tts.md).
>
> **Todo**: [`v37-vocab-item-polly-tts-todo.md`](v37-vocab-item-polly-tts-todo.md).

---

Three phases + docs, ~1.5 days estimate; shipped in one session via TDD.

## Phase A — Backend (~0.5 ngày) — `feat(v37) backend per-item Polly audio for vocab items`

- Migration 029 `vocabulary_items.audio_storage_key` + addColumnIfMissing.
- `contracts.VocabularyItem.AudioStorageKey` + omitempty.
- `VocabularyStore.SetVocabularyItemAudio` (memory + postgres impls).
- `handleAdminVocabItem` router dispatching `/image` vs `/generate-audio`.
- `handleAdminVocabItemGenerateAudio` reuses existing `ExerciseAudioGenerator`.
- Tests: happy path, 404, 400 empty term.

## Phase B — CMS (~0.5 ngày) — `feat(v37) cms vocab editor — generate-audio row action`

- `/api/admin/vocabulary-items/[itemId]/generate-audio` Next.js route.
- 🔊 column in vocab editor between image + term.
- `handleItemAudioGenerate` with loading sentinel + alert fallback.
- Lint + build green.

## Phase C — Flutter (~0.5 ngày) — `feat(v37) flutter QuizcardWidget plays per-item Polly audio`

- `QuizcardBasicDetail.AudioStorageKey` (Go) + `ExerciseDetail.flashcardAudioStorageKey` (Dart).
- Inject from vocab → quizcard at publish (`v6_handlers.go`).
- `QuizcardWidget.audioUrl` optional; mic button on front face via just_audio.
- Both call sites pass `client.mediaUri(...)` when key present.
- Tests for null/empty/set audioUrl visibility.

## Phase D — Docs — `docs(v37) CHANGELOG + SPEC digest + reference fold`

- CHANGELOG V37 entry.
- SPEC.md row.
- `docs/reference/content-and-attempt-model.md` (VocabularyItem field).
- Idea status flip → promoted.
- Spec status flip → frozen.
- tasks/plan.md + tasks/todo.md updated.
