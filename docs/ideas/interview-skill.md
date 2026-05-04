# Interview Skill (Phỏng vấn trực tiếp)

## Problem Statement

How Might We: Làm thế nào để người học A2 có thể luyện nói tiếng Czech với một người phỏng vấn AI theo thời gian thực — nghe, hỏi lại, phản ứng — thay vì luồng ghi âm → chờ async hiện tại?

Luồng `noi` hiện tại là: Record → Upload → Transcribe (async) → Score → Feedback. Không có back-and-forth. Người học không được "bị hỏi lại" như trong phòng thi thật.

## Recommended Direction

Một `skill_kind` mới (`interview`) với avatar Czech examiner real-time, được dựng trên:

- **ElevenLabs Conversational AI** — real-time WebSocket conversation (STT + LLM + TTS được tích hợp sẵn)
- **Simli** (`simli_client` Flutter package) — render avatar face lip-synced với audio PCM16 từ ElevenLabs

**Integration flow:**
```
Mic (PCM16) → ElevenLabs ConvAI WebSocket
                       ↓ speech audio (PCM16)
              SimliClient.sendAudioData(chunk)
                       ↓
              RTCVideoView (avatar Czech examiner)
                       ↓
    Session end → transcript → Go backend → Claude score
```

**Triển khai theo 3 sprint:**

- **Sprint 0 (spike, ~2 ngày):** Validate 2 unknown lớn: (1) Czech language quality trên ElevenLabs ConvAI agent, (2) `simli_client` v1.0.1 hoạt động ổn trên iOS device
- **Sprint 1:** Dart WebSocket client cho ElevenLabs ConvAI + conversation flow hoàn chỉnh (không cần avatar). Post-session transcript → Go backend scoring.
- **Sprint 2:** Pipe PCM16 audio sang SimliClient → RTCVideoView. Thêm avatar.

## Exercise Types

### 1. Hội thoại theo chủ đề (Conversation)
- Admin tạo topic + system prompt cho ElevenLabs agent qua CMS
- Ví dụ: "Gia đình", "Công việc", "Sở thích", "Cuộc sống hàng ngày"
- Agent hỏi 5–8 câu tự nhiên, người học trả lời
- Session kết thúc sau `max_turns` hoặc người học bấm "Kết thúc"
- Go backend nhận transcript, Claude đánh giá theo rubric A2

### 2. Chọn phương án + giải thích (Choice & Explain)
- Admin tạo 1–4 options (text hoặc ảnh) + system prompt
- Ví dụ: 3 ảnh địa điểm, learner chọn nơi muốn đến và giải thích
- UI hiện options trước khi bắt đầu conversation
- ElevenLabs agent hỏi tiếp: "Tại sao bạn chọn X? Bạn sẽ làm gì ở đó?"
- Go backend score dựa trên chất lượng giải thích + vocabulary range

## Key Assumptions to Validate

- [ ] ElevenLabs Conversational AI hỗ trợ Czech đủ tốt — test trên ElevenLabs dashboard với system prompt Czech examiner
- [ ] PCM16 output từ ElevenLabs tương thích với `simli_client.sendAudioData()` — spike Dart test
- [ ] `simli_client` v1.0.1 ổn định trên iOS (low community activity: 1 like, 16 tháng không update) — build sample app
- [ ] Latency chấp nhận được: ElevenLabs response + Simli render < 1s trên iPhone — đo thực tế
- [ ] Cost model chấp nhận: ElevenLabs ConvAI ~$0.10–0.15/phút, Simli ~$0.05/phút — estimate usage

## MVP Scope

**In:**
- `skill_kind = "interview"`, Flutter iOS only
- Dart WebSocket client tự viết cho ElevenLabs Conversational AI API
- 2 exercise types: `interview_conversation` + `interview_choice_explain`
- CMS form: tiêu đề, chủ đề, system_prompt, options (cho choice type), max_turns
- Simli avatar với 1 face ID cố định (Czech examiner)
- Post-session: transcript hiển thị trong Flutter + gửi về Go backend để Claude score
- Go backend: new handler `POST /v1/interview-sessions`, reuse `LLMFeedbackProvider`

**Out:**
- Multiple avatar faces / voice selection
- Real-time scoring trong lúc hội thoại
- Pronunciation breakdown per word
- MockTest integration (exercise pool = exam) trong MVP

## Not Doing (và tại sao)

- **WebView hybrid** — `simli_client` Flutter package native tốt hơn, không cần WebView
- **elevenlabs_flutter package** — package đó chỉ là TTS wrapper, không phải Conversational AI
- **Scoring trong real-time** — đủ phức tạp để tách sang V2; MVP dùng post-session
- **Nhiều avatar** — 1 face ID cố định đủ cho MVP, giảm thiểu Simli cost
- **Full exam simulation ngay** — validate conversation quality trước khi gắn vào MockTest

## Open Questions

- ~~Cần backend proxy ElevenLabs ConvAI WebSocket không?~~ **Đã quyết định:** Backend cấp ephemeral token (Go gọi ElevenLabs API → signed session URL ngắn hạn), Flutter kết nối WebSocket thẳng tới ElevenLabs. API key giữ ở server, không có proxy latency.
  ```
  Flutter → POST /v1/interview-sessions/token (auth check)
                    ↓
          Go → ElevenLabs API → signed session URL
                    ↓
          Flutter → WebSocket thẳng tới ElevenLabs
  ```
- `simli_client` v1.0.1 có vẫn tương thích với Simli API hiện tại không? (package 16 tháng cũ) — cần test trong Sprint 0
- ElevenLabs ConvAI có expose full transcript cuối session không, hay phải tự accumulate từ events?
- CMS system prompt cho ElevenLabs agent: lưu plain text hay có template syntax?
