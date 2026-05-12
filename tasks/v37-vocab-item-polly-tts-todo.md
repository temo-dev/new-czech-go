# V37 Vocab Item Per-item Polly TTS — Todo

> **Status**: ✅ Phase A-D shipped 2026-05-12.

## Phase A — Backend
- [x] Migration 029 + addColumnIfMissing wiring
- [x] `VocabularyItem.AudioStorageKey` contract field
- [x] `SetVocabularyItemAudio` on memory + postgres stores
- [x] `handleAdminVocabItem` router + `/generate-audio` handler
- [x] 3 backend tests (happy / 404 / empty term)
- [x] `go test ./...` green

## Phase B — CMS
- [x] Next.js route proxy `/api/admin/vocabulary-items/[id]/generate-audio`
- [x] 🔊 column in vocab editor with loading + persist states
- [x] `npm run lint` green
- [x] `npm run build` green

## Phase C — Flutter
- [x] `QuizcardBasicDetail.AudioStorageKey` injected at publish time
- [x] `ExerciseDetail.flashcardAudioStorageKey` parsed from wire
- [x] `QuizcardWidget.audioUrl` optional + just_audio playback
- [x] Both call sites forward `client.mediaUri(key)`
- [x] 3 widget tests (null / empty / set)
- [x] `flutter test` green (397 tests total)

## Phase D — Docs
- [x] CHANGELOG V37 entry
- [x] SPEC.md row
- [x] `docs/reference/content-and-attempt-model.md` update
- [x] Idea status flip
- [x] Spec status flip
- [x] `tasks/plan.md` + `tasks/todo.md` indexes
