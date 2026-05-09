# Poslech 1 — Per-item Audio (idea)

**Decided:** 2026-05-09
**Slice:** V26
**Owner:** TBD

## Problem

Hiện tại `poslech_1` (5 đoạn ngắn → chọn A-D) phát **một file MP3 gộp**
chứa cả 5 đoạn liên tiếp. Learner muốn nghe lại đoạn 3 phải scrub
timeline thủ công. Đề thi A2 thật phát từng đoạn riêng có khoảng nghỉ
giữa các câu — UX hiện tại không match.

## Proposed change

Mỗi `ListeningItem` trong `Poslech1Detail.Items[]` có audio riêng:

- Backend: `POST /v1/admin/exercises/:id/generate-audio` cho poslech_1
  loop 5 lần Polly TTS, lưu storage key vào
  `Items[i].AudioSource.AssetID` (field đã tồn tại từ V3 schema, chưa
  từng populate từ Polly).
- Flutter: `listening_exercise_screen.dart` render 1 mini-player per
  question card thay vì 1 player top-level.
- Backward compat: nếu mọi `Items[i].AudioSource.AssetID` rỗng → fallback
  render single top-level player (legacy data).

## Why now

- Đã có precedent V18 dictation per-sentence (`GenerateSentenceAudio` +
  `exercise_sentence_audio` table). Pattern reusable.
- Schema `ListeningAudioSource.AssetID` chừa sẵn từ V3 — không cần
  contract change.
- V21.2 exam-flow runtime hotfix vừa ship, app stable, ngách nâng learner
  UX hợp lý.

## Why not (do nothing)

Giữ single audio: learner vẫn dùng được, scrub thủ công. Acceptable nhưng
inferior so với đề thi thật. Không có blocker.

## Scope V26

- ✅ poslech_1 per-item audio
- ✅ Flutter UI per-item player + fallback
- ✅ Backward compat cho seed cũ
- ❌ poslech_2/3/4 (defer slice sau dù schema giống)
- ❌ Vocab V11 per-item TTS (defer riêng dù cùng pattern)
- ❌ Image A-D per choice (slice riêng, đã review tách biệt)

## Risks

- 5× Polly API call per generate → throttling khi reseed batch lớn.
  Mitigation: sequential generation + progress log.
- Flutter 5 `AudioPlayer` instances song song → memory ~negligible
  (just_audio multi-instance OK), nhưng cần coordinate pause-others-on-play.
- Detail mutation + audio file write không atomic → rollback files on
  partial failure để tránh state corrupt.

## Open questions (resolved 2026-05-09)

- Q: Có gộp với feature ảnh A-D không? **A:** Không, tách 2 slice.
- Q: DB layer: bảng mới hay populate trực tiếp asset_id? **A:** Populate
  `AudioSource.AssetID` (option C, không bảng mới).
- Q: Backward compat policy? **A:** Fallback single audio nếu items
  rỗng asset_id. Admin tự re-generate khi muốn upgrade.

## Next

Spec → `docs/specs/poslech-per-item-audio.md`
