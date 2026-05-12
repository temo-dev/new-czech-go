# V37 Vocab Item Per-item Polly TTS — Idea + Requirements

> **Status**: ✅ promoted to spec on 2026-05-12. Spec authoritative:
> `docs/specs/v37-vocab-item-polly-tts.md`. Idea kept as historical
> pre-spec; nếu mâu thuẫn, theo spec.
>
> **Owner**: solo admin (tuananh.ngta@gmail.com).
>
> **Trigger**: V11 long-running backlog item — "Vocab item per-item Polly
> TTS" — deferred from V11 (2026-05-01). Learners ask for native
> pronunciation when learning new vocab; current vocab cards have no
> audio. Polly Czech voice already powers Poslech + dictation audio so
> the integration cost is small.

---

## 1. Problem Statement

> **HMW** giúp learner nghe được phát âm chuẩn cho mỗi từ trong vocab
> deck mà không tốn cost ngoài Polly hiện có?

Hiện trạng:

| Layer | Hiện trạng | V37 mục tiêu |
|---|---|---|
| Backend | Polly Czech voice qua `PollyExerciseAudioGenerator` (exercise scope) | Cùng generator wired cho `vocabulary_items` |
| Schema | `vocabulary_items` không có field audio | Thêm `audio_storage_key` (TEXT, nullable) |
| Admin endpoint | `POST /v1/admin/exercises/:id/generate-audio` chỉ cho exercise | Thêm `POST /v1/admin/vocabulary-items/:id/generate-audio` |
| CMS | Vocab item edit form không có nút generate | Nút "🔊 Tạo audio" cạnh ô Term |
| Flutter | Vocab card chỉ hiện text | Tap term → phát audio storage_key |

---

## 2. Recommended Direction

Phase A (backend) → Phase B (CMS) → Phase C (Flutter). ~1.5 ngày tổng.

### A. Backend (~0.5 ngày)
- DB migration: `ALTER TABLE vocabulary_items ADD COLUMN audio_storage_key TEXT`.
- Contract: `VocabularyItem.AudioStorageKey string \`json:"audio_storage_key,omitempty"\``.
- Handler: `POST /v1/admin/vocabulary-items/:id/generate-audio` body `{}` → reads item.Term + level voice → Polly synth → store → write `audio_storage_key` → return updated item.
- Auth: admin role.
- Test: TDD on the handler path; reuse `mockPollyClient` if exists.

### B. CMS (~0.5 ngày)
- `vocabulary-items-editor.tsx`: row action "🔊 Tạo audio". Loading + error states.
- After success, show small `▶` play preview from the storage URL.
- Validation: don't allow gen if Term empty.

### C. Flutter (~0.5 ngày)
- `VocabCard`: when `audio_storage_key` is non-empty, render mic icon top-right; tap → play via existing audio player.
- Pre-warm: don't auto-play; user-initiated only (battery + classroom etiquette).
- Fallback: nếu key resolve fail → snackbar "Không có audio cho từ này".

---

## 3. Key Assumptions to Validate

- [ ] Polly Czech voice ID chấp nhận term ngắn 1-3 từ không trả empty MP3 — verify với 5 term mẫu.
- [ ] Storage upload + signed URL flow giống exercise audio — không cần code mới.
- [ ] Cost: Polly $4/1M characters. 1000 vocab × avg 10 chars = 10k chars × $4/1M = $0.04. Acceptable.
- [ ] Learner pronunciation expectation: 1 audio per term đủ, không cần slow/fast variants — defer khi có feedback.
- [ ] Flutter audio player có thể play storage URL trực tiếp không cần download trước — verify với Polly URL.

---

## 4. MVP Scope (~1.5 ngày)

### IN
- Schema migration (1 column).
- 1 admin endpoint + tests.
- CMS row action generate.
- Flutter playback on tap.
- CHANGELOG V37 + SPEC.md row.

### OUT
- Bulk generate (defer — admin có thể click từng row OK với <100 items).
- Speed/pitch variants — defer.
- Pre-warm download cache — defer.
- Word-level highlight + timeline — defer.
- Vocab quiz "Listen and type" — defer V38+.
- Auto-regen khi term thay đổi — defer.

---

## 5. Detailed Requirements

### 5.1 Backend

| FR | Yêu cầu |
|---|---|
| FR-A1 | Migration `029_vocabulary_items_audio.sql` adds `audio_storage_key TEXT` (nullable). Latest existing migration is 028. |
| FR-A2 | `VocabularyItem.AudioStorageKey string \`json:"audio_storage_key,omitempty"\``. |
| FR-A3 | `POST /v1/admin/vocabulary-items/:id/generate-audio` returns 200 + updated item. |
| FR-A4 | Handler reuses `PollyExerciseAudioGenerator.GenerateAudio` API. Output storage key persisted on vocab item. |
| FR-A5 | Tests: success path + 404 (no item) + 400 (empty term) + storage error → 502. |

### 5.2 CMS

| FR | Yêu cầu |
|---|---|
| FR-B1 | Row in vocabulary items table: icon button 🔊 left of term column. |
| FR-B2 | Click → POST endpoint → toast success / error. |
| FR-B3 | After success, audio_storage_key visible as small `▶` preview cell. |

### 5.3 Flutter

| FR | Yêu cầu |
|---|---|
| FR-C1 | `VocabCard` renders mic icon top-right when `audioStorageKey != null`. |
| FR-C2 | Tap → resolve URL via `client.mediaUri(key)` → play. |
| FR-C3 | Loading state: spinner during fetch+play. |
| FR-C4 | Error: snackbar "Không nghe được audio. Thử lại sau." |

---

## 6. Acceptance Criteria

### Backend
- [ ] `make backend-test` xanh; +5 tests cho handler.
- [ ] Manual: tạo vocab item, gen audio, GET item trả audio_storage_key.

### CMS
- [ ] Vocab page: nút 🔊 hiện trên mỗi row.
- [ ] Click + reload: storage_key visible + preview phát.

### Flutter
- [ ] Vocab card có mic icon khi item có audio.
- [ ] Tap → phát Czech voice.
- [ ] Item không có audio → mic icon ẩn.

### Slice-level
- [ ] CHANGELOG V37 entry + SPEC.md row + reference fold.
- [ ] `make verify` xanh.

---

## 7. Open Questions

1. **Voice**: dùng Polly Czech voice mặc định (Jakub) hay add cho learner chọn male/female? Recommend mặc định Jakub, defer voice selection cho V38+.
2. **Item-level cost cap**: cap số lần regen mỗi vocab item / ngày để tránh admin click spam? Recommend không cap MVP; admin self-regulate.
3. **Storage retention**: nếu admin xoá vocab item, audio blob có xoá theo không? Recommend có (DELETE cascade trên audio).
4. **Term thay đổi sau khi gen audio**: audio stale; admin phải regen thủ công. Show warning? Recommend MVP: không warn; defer auto-invalidation.

---

## 8. References

- [V11 spec](../specs/media-enrichment.md) — V11 deferred per-item Polly TTS.
- `backend/internal/processing/exercise_audio.go` — Polly client.
- `backend/internal/contracts/types.go:777` — VocabularyItem.
- `cms/components/vocabulary-items-editor.tsx` — CMS editor (verify path before implementation).
- `flutter_app/lib/features/exercise/screens/vocab_grammar_exercise_screen.dart` — current learner vocab surface (no separate VocabCard yet; spec phase should decide whether to introduce one or extend existing screen).
