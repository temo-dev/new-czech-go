# V26 Poslech Per-item Audio — Plan

**Spec**: [docs/specs/poslech-per-item-audio.md](../docs/specs/poslech-per-item-audio.md)
**Idea**: [docs/ideas/poslech-per-item-audio.md](../docs/ideas/poslech-per-item-audio.md)
**Todo**: [v26-poslech-per-item-audio-todo.md](v26-poslech-per-item-audio-todo.md)
**Last updated:** 2026-05-09

## Approach

Vertical slicing 4 phase. Backend foundation (A) trước, integration
(B) tiếp theo, Flutter (C) song song được sau khi B định wire shape,
docs (D) đóng slice.

- **Phase A** (backend, ~150 LOC): nâng `processing` package — text
  extraction per-item + Polly per-item gen.
- **Phase B** (backend, ~120 LOC): admin endpoint fork branch + detail
  mutation + rollback.
- **Phase C** (Flutter, ~200 LOC): UI refactor + playback coordinator
  + fallback path.
- **Phase D** (docs, <50 LOC): reference update + CHANGELOG.

**Critical invariant:**
- Detail mutation atomic với file write (rollback on partial fail).
- Legacy single-audio path không removed (poslech_3/4/5 + fallback).
- `BuildExerciseAudioText` poslech_1 giữ logic concat (used cho seed cũ + test).
- Storage key namespace `item-<n>.mp3` không trùng `sentence-<idx>.mp3`.

**Critical kill switch:** nếu Phase A2 (`GenerateItemAudio`) không pass
test golden path, Phase B không start. C có thể vẫn refactor render
logic dựa vào fixture detail.

## Dependency Graph

```
A (backend foundation) ──┬─→ B (admin endpoint)
                         │
                         └─→ C (Flutter render) — chỉ cần wire shape A định nghĩa

B + C ─→ D (docs + CHANGELOG)
```

## Phase A — Backend foundation

| # | Task | Acceptance |
|---|---|---|
| A1 | Add `BuildExerciseItemTexts(exercise) []ItemText` trong `exercise_audio.go` | Test: poslech_1 returns 5 items với text đã join từ segments; skip items có AssetID; nil cho non-poslech_1 |
| A2 | Add `GenerateItemAudio(exerciseID, itemNo, text)` method on `PollyExerciseAudioGenerator` | Test: storage key = `exercise-audio/<eid>/item-<n>.mp3`; file written; mock TTS provider verifies signature |
| A3 | Add interface `ItemAudioGenerator` trong package processing để admin endpoint check qua type assertion | Test: PollyExerciseAudioGenerator satisfies; mock generator dùng được trong test |

**Files:**
- `backend/internal/processing/exercise_audio.go` (+~80 LOC)
- `backend/internal/processing/exercise_audio_test.go` (+~70 LOC)
- `backend/internal/processing/exercise_audio_item_test.go` (mới, ~80 LOC)

## Phase B — Backend admin endpoint integration

| # | Task | Acceptance |
|---|---|---|
| B1 | Fork `handleAdminGenerateAudio` cho `exercise_type == "poslech_1"`: loop generate per-item, mutate detail, persist | Test integration: POST → 200 → GET exercise có asset_id mỗi item |
| B2 | Implement rollback: if generate item N fail → delete files 1..N-1, return 500, detail unchanged | Test: mock TTS fail at item 3 → response 500 → repo.Exercise() detail không có asset_id; files 1,2 deleted |
| B3 | Response shape giữ compat: `storage_key` = file cuối; thêm `meta.item_count` | Test: response JSON shape match expected |

**Files:**
- `backend/internal/httpapi/server.go` (~80 LOC modified ở `handleAdminGenerateAudio`)
- `backend/internal/httpapi/admin_generate_audio_test.go` hoặc tương đương (mới ~150 LOC)

## Phase C — Flutter render

| # | Task | Acceptance |
|---|---|---|
| C1 | Refactor `_AudioPlayerBar` → accept `audioUri` param thay vì hardcode top-level | Build clean, existing single-audio path vẫn render |
| C2 | Add `_PlaybackCoordinator` ValueNotifier<int?> để pause-others | Unit test: notifier transitions correct |
| C3 | Refactor `_buildItemAnswers`: detect per-item mode (`items.every(asset_id != "")`); render mini-player per item | Widget test: 5 players visible khi per-item mode |
| C4 | Fallback path: nếu không phải per-item mode, render top-level player như cũ | Widget test: 1 player khi legacy mode |
| C5 | Handle setAudioSource lazy (chỉ load khi user tap play đầu tiên) | Manual smoke: scroll qua không trigger 5 network calls |

**Files:**
- `flutter_app/lib/features/exercise/screens/listening_exercise_screen.dart` (~150 LOC modified)
- `flutter_app/test/features/exercise/listening_exercise_screen_test.dart` (~100 LOC mới hoặc extend)

## Phase D — Docs & CHANGELOG

| # | Task | Acceptance |
|---|---|---|
| D1 | Update `docs/reference/content-and-attempt-model.md` § listening | Diff ghi rõ poslech_1 audio per-item kể từ V26; fallback single |
| D2 | CHANGELOG entry V26 | Format mirror V25; ghi files changed + test counts |
| D3 | Update `SPEC.md` digest table | 1 row V26 |

**Files:**
- `docs/reference/content-and-attempt-model.md`
- `CHANGELOG.md`
- `SPEC.md`

## Verification

Sau mỗi phase:
- Phase A: `make backend-test` (chỉ test mới + regression)
- Phase B: `make backend-test` + `make backend-build`
- Phase C: `make flutter-analyze` + `make flutter-test`
- Phase D: review docs visually

Final ship: `make verify` toàn bộ.

## Out of scope (explicit)

- ❌ poslech_2/3/4 per-item audio
- ❌ Vocab V11 per-item TTS
- ❌ Image A-D per choice (slice riêng)
- ❌ CMS UI thay đổi (button "Generate audio" reuse như cũ)
- ❌ Migration batch regenerate seed cũ (admin tự click khi muốn)
