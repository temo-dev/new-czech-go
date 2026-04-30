# Voice Selection

## Problem Statement

How might we let learners choose a Czech TTS voice they find natural, making model-answer playback more pleasant without adding backend complexity?

## Recommended Direction

Single voice picker in Profile screen. User chọn 1 trong 4 giọng Czech (2 female: Jitka/AWS + EL female; 2 male: Tomas/EL + EL male). Preference lưu trong Flutter `SharedPreferences`. Mỗi lần gửi attempt hoặc request TTS, Flutter gửi kèm `voice_id` trong request body. Backend dùng `voice_id` đó thay vì env var, fallback về env var nếu không có.

Profile screen hiển thị 4 card: tên giọng + gender + provider label + nút Preview (phát 3–5 giây mẫu). Không có khái niệm "Sub voice" trên UI — hệ thống tự chọn sub = opposite gender khi cần (dự phòng cho dialog tương lai).

Ảnh hưởng thực tế:
- ✅ Model answer TTS trong speaking review
- ✅ Model answer TTS trong writing review
- ❌ Poslech pre-generated MP3 — không thay đổi được (đã baked)

## Key Assumptions to Validate

- [ ] ElevenLabs Czech voices nghe tự nhiên — test audio sample trước khi chọn voice ID
- [ ] Learner sẽ khám phá và dùng tính năng này — cân nhắc onboarding prompt sau lần đầu login
- [ ] 4 giọng đủ khác biệt để xứng đáng 4 option — nếu không, rút xuống 2 (male/female)
- [ ] `voice_id` trong request body không gây regression ở các handler hiện tại

## MVP Scope

**Trong scope:**
- Flutter Profile screen: 4 voice card + Preview button + lưu SharedPreferences
- Flutter: gửi `preferred_voice_id` trong request body khi submit attempt và trigger TTS
- Backend: đọc `preferred_voice_id` từ request body, route đến đúng TTS provider/voice; fallback về env var
- 4 voice IDs cấu hình qua env vars: `VOICE_ID_1..4` (không hardcode)

**Ngoài scope:**
- Không lưu preference lên DB (V1 — cross-device sync defer)
- Không personalize poslech pre-generated audio
- Không có "Sub voice" picker trên UI
- Không thêm voice thứ 5+ trong slice này

## Not Doing (and Why)

- **Main+Sub picker trên Profile** — Sub không ảnh hưởng pre-generated poslech dialog; gây confusion cho learner
- **DB storage for preference** — overkill cho V1, SharedPreferences đủ dùng
- **Per-exercise-type voice** — thêm complexity, learner không cần granularity đó
- **Pre-generate tất cả voice combo cho poslech** — chi phí storage + latency không xứng

## Open Questions

- ElevenLabs voice IDs cho Czech female/male: cần chọn và test trước khi code
- Preview audio: host static sample MP3 (CDN/S3) hay generate on-demand khi nhấn Preview?
- Fallback khi ElevenLabs rate limit: dùng AWS Polly tương ứng gender hay fail silently?
