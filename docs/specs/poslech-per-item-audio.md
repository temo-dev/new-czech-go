# Poslech 1 Per-item Audio (V26) — Spec

**Slice:** V26 — poslech_1 per-item audio generation + render
**Status:** Draft — chờ human approve trước khi sang plan
**Owner:** TBD
**Last updated:** 2026-05-09

Liên quan:
- Idea: [`docs/ideas/poslech-per-item-audio.md`](../ideas/poslech-per-item-audio.md)
- Plan: [`tasks/v26-poslech-per-item-audio-plan.md`](../../tasks/v26-poslech-per-item-audio-plan.md)
- Todo: [`tasks/v26-poslech-per-item-audio-todo.md`](../../tasks/v26-poslech-per-item-audio-todo.md)
- Reference: [`docs/reference/content-and-attempt-model.md`](../reference/content-and-attempt-model.md) § Listening
- Precedent: V18 dictation per-sentence audio (`exercise_sentence_audio`)

---

## 1. Objective

`poslech_1` chuyển từ **1 audio gộp** sang **5 audio per-item**, mỗi
`ListeningItem` có `AudioSource.AssetID` populated từ Polly TTS. Flutter
render 1 mini-player per question card. Fallback single audio cho seed cũ.

**Out of scope:** poslech_2/3/4, vocab V11, image A-D per choice.

---

## 2. Quyết định đã chốt

| # | Quyết định | Lý do |
|---|---|---|
| D1 | poslech_1 only, không gộp poslech_2/3/4 | Scope nhỏ, ship nhanh, đo learner reaction trước khi mở rộng |
| D2 | DB: populate `Items[i].AudioSource.AssetID` trực tiếp, không tạo bảng `exercise_item_audio` | Asset_id là storage key (theo `infrastructure-baseline.md`). Tránh thêm bảng + migration. Mutation lưu vào `exercises.detail` JSON column. |
| D3 | Storage key pattern `exercise-audio/<exerciseID>/item-<n>.mp3` | Khác `sentence-<idx>.mp3` (V18 dictation) để tránh namespace collision khi exercise vừa có dictation vừa listening (không xảy ra hiện tại nhưng rõ ràng) |
| D4 | Admin endpoint reuse `POST /v1/admin/exercises/:id/generate-audio` | Fork branch theo `exercise_type`. Không thêm route mới. CMS chỉ cần 1 nút "Generate audio" như cũ. |
| D5 | Backward compat: fallback single audio | Flutter check `Items.every(asset_id != "")`; nếu false → render top-level player với `exerciseAudioUri(id)` legacy. Seed cũ không broken. |
| D6 | Flutter render: pause-others-on-play coordinate | Single `_PlaybackCoordinator` notifier. Khi player A play → pause B/C/D/E. |
| D7 | Sequential Polly generation, không parallel | Đơn giản hoá; throttling-safe; 5 calls × ~2s = ~10s acceptable cho admin generate |
| D8 | Detail mutation + file write rollback on partial failure | Nếu file 3/5 fail → xóa file 1,2 đã write + return error. Detail không persist. State consistent. |
| D9 | Generate-audio response giữ shape cũ (storage_key, mime_type, source_type, generated_at) | Backward compat CMS UI. Per-item info nằm trong `exercise.detail.items[*].audio_source.asset_id` khi GET exercise. |
| D10 | Không bỏ legacy single-audio path | poslech_3/4/5 vẫn dùng. Admin endpoint giữ branch single-voice cho các type khác. |

---

## 3. Acceptance Criteria

### A. Backend audio generation

**A1.** `processing.BuildExerciseItemTexts(exercise) []ItemText` returns
slice cho poslech_1: `[{ItemNo: 1, Text: "..."}, ...]`. Skip items có
`AudioSource.AssetID != ""` (uploaded file). Trả `nil` cho non-poslech_1.

**A2.** `PollyExerciseAudioGenerator.GenerateItemAudio(exerciseID,
itemNo, text)` returns `*ExerciseAudio` với `StorageKey =
exercise-audio/<exerciseID>/item-<n>.mp3`. Mirror `GenerateSentenceAudio`
(V18 pattern).

**A3.** Test: gọi `GenerateItemAudio` với mock TTS → file written ở đúng
path; storage key đúng format.

### B. Backend admin endpoint

**B1.** `handleAdminGenerateAudio` cho `exercise_type == "poslech_1"`:
- Loop 5 items.
- Skip item nếu `AudioSource.AssetID != ""` (admin upload).
- Loop call `GenerateItemAudio`.
- Mutate `exercise.Detail.Items[i].AudioSource.AssetID = result.StorageKey`.
- Persist via `repo.UpdateExercise`.
- On any error: rollback (delete written files) + return 500.
- Response shape: giữ field `storage_key` (= cuối cùng của file thứ 5
  cho compat); thêm field `meta.item_count = 5`.

**B2.** Test integration: admin POST → 200 → GET exercise → `detail.items`
có asset_id ở mỗi item.

**B3.** Test rollback: mock TTS fail ở item 3 → response 500 → file 1,2
đã xóa → exercise detail unchanged.

### C. Flutter render

**C1.** `listening_exercise_screen.dart`: nếu `d.poslechItems.every((it)
=> it.audioSource.assetId.isNotEmpty)` → render per-item player. Else
→ render top-level single player (legacy fallback).

**C2.** Per-item: mỗi question card có inline `_AudioPlayerBar` ở trên
question label, dùng `mediaUri(asset_id)` làm URL.

**C3.** `_PlaybackCoordinator`: ValueNotifier<int?> tracking active
player index. Khi player tap play → set notifier → các player khác listen
& pause.

**C4.** Widget test: render with all per-item asset_ids → 5 players. Render
without asset_ids → 1 top-level player (legacy mode).

### D. Backward compat & safety

**D1.** Existing seeded poslech_1 (no per-item asset_ids) phải vẫn play
được single audio.

**D2.** Migration: không bắt buộc. Admin click "Generate audio" cho exercise
cũ sẽ tự upgrade sang per-item.

**D3.** `BuildExerciseAudioText` cho poslech_1 vẫn return concatenated
text (giữ legacy generate path nếu admin dùng exercise type khác hoặc
fallback). Không xóa.

### E. Docs

**E1.** Update `docs/reference/content-and-attempt-model.md` § listening
ghi rõ poslech_1 audio = per-item kể từ V26, fallback single nếu legacy.

**E2.** CHANGELOG entry V26.

---

## 4. Wire shape changes

### Before (V25)

```json
{
  "exercise_type": "poslech_1",
  "detail": {
    "items": [
      {"question_no": 1, "question": "...", "audio_source": {"segments": [...]}, "options": [...]},
      ...
    ],
    "correct_answers": {"1": "B", ...}
  }
}
```

`audio_source.asset_id` luôn rỗng cho text-source items. Audio served từ
`exercise-audio/<eid>/audio.mp3`.

### After (V26)

```json
{
  "exercise_type": "poslech_1",
  "detail": {
    "items": [
      {
        "question_no": 1,
        "question": "...",
        "audio_source": {
          "asset_id": "exercise-audio/abc123/item-1.mp3",
          "segments": [...]
        },
        "options": [...]
      },
      ...
    ],
    "correct_answers": {"1": "B", ...}
  }
}
```

`audio_source.asset_id` populated sau khi admin generate. `segments` giữ
nguyên cho re-generate. Single `audio.mp3` legacy có thể vẫn tồn tại nhưng
không được Flutter dùng nếu per-item available.

---

## 5. Test plan

| Layer | Test |
|---|---|
| Backend unit | `BuildExerciseItemTexts` (skip uploaded, nil cho non-poslech_1) |
| Backend unit | `GenerateItemAudio` storage key format, write to correct path |
| Backend integ | `handleAdminGenerateAudio` poslech_1 → 5 files + detail mutated |
| Backend integ | Rollback test: mock fail item 3 → detail unchanged + files cleaned |
| Backend integ | Backward compat: legacy single-audio exercise vẫn served |
| Flutter widget | Per-item render mode: 5 players visible |
| Flutter widget | Legacy fallback: 1 top-level player when asset_ids empty |
| Flutter widget | Pause-others coordination |

---

## 6. Risks & mitigations

| Risk | Mitigation |
|---|---|
| 5× Polly API throttling | Sequential gen; log per-item progress; abort on first fail |
| Detail mutation race với UpdateExercise concurrent edits | Generate-audio holds short critical section; concurrent edits trên cùng exercise = admin user error, accept last-write-wins |
| Flutter 5 AudioPlayer memory | just_audio docs confirm multi-instance OK; lazy load (chỉ setAudioSource khi tap play) |
| File leak khi rollback fail | Best-effort delete; log warning; not blocking response |
| Spec creep sang poslech_2/3/4 | Out of scope explicit (D1); scope discipline trong plan |
