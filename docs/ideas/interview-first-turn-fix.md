# Interview First-Turn Fix + Prompt-on-Screen UX

## Problem Statement
Mọi session interview đều miss đoạn audio đầu tiên của examiner trên iOS khi Simli avatar bật, mặc dù ElevenLabs dashboard xác nhận chunks đã gửi. Đồng thời, learner không thấy đề bài rõ ràng trong khi nói chuyện → khó nhớ và phản xạ chậm.

Bug + UX gap → **HMW** đảm bảo lượt nói đầu tiên đến tai learner đầy đủ và đề bài luôn hiện diện hỗ trợ phản xạ trong suốt session.

## Recommended Direction

### A. Fix bug audio đầu (Direction A + C từ Phase 2)

**Root cause** (sau khi đọc `simli_session_manager.dart:394-398`): WS message `START` từ Simli kích hoạt `_markConnected()` → `isConnected=true`, nhưng `_markVideoReady()` chỉ chạy khi first frame render. Trong window giữa 2 sự kiện này, `interview_session_screen.dart` đã route audio chunks vào Simli (vì check `_simli?.isConnected==true`) nhưng Simli WebRTC audio track chưa fully attached → chunks rơi vào hư không.

**Fix**:
1. `interview_session_screen.dart` đổi gate từ `_simli?.isConnected` → `_simli?.isVideoReady` (đã expose sẵn ở line 150)
2. Thêm queue `List<Uint8List> _pendingAgentChunks` trong session screen. Chunks đến trước `isVideoReady=true` được buffer, flush khi ready
3. Pass `agentOutputAudioFormat` từ `onMetadata` → `_simli.setInputFormat()` (cần thêm method mới trong `SimliSessionManager`)
4. Fallback timeout 1500ms: nếu Simli vẫn chưa ready → flush chunks vào `PcmAudioPlayer` (local fallback) thay vì drop

### B. Prompt-on-screen (yêu cầu mới)

Hiển thị đề bài trong session UI để learner nhìn được trong lúc nói:

- **Layout**: Card "đề bài" cố định ở top (dưới status pill), expandable. Default: title + 2 dòng text. Tap → expand full prompt.
- **Source**: `widget.detail` đã có `interviewSystemPrompt` nhưng đó là prompt cho LLM, không user-facing. Cần field mới: `interview_display_prompt` (CMS admin nhập separately) hoặc trích phần "câu hỏi cho học viên" từ system_prompt.
- **Choice variant** (`interview_choice_explain`): hiển thị `selected_option` chip + nội dung option text trong card, nhỏ hơn nhưng prominent.
- **Auto-collapse** sau 8s không tap để khỏi che avatar; pulse subtle khi examiner hỏi câu mới (có thể detect qua `agent_response_complete` đầu).

## Key Assumptions to Validate

- [ ] **Simli `isVideoReady` đảm bảo audio track ready** — verify bằng cách log `ICE connection state` lúc `_markVideoReady` fire
- [ ] **Buffer 1500ms đủ cover race** — đo thời gian giữa `START` và first frame trong 5 sessions thực tế
- [ ] **Admin có muốn nhập display_prompt riêng không** — có thể tận dụng field hiện có (`interview_intro` từ exercise type?) trước khi thêm cột DB
- [ ] **Auto-collapse 8s** không gây UX khó chịu — A/B với always-visible mini card
- [ ] **iOS Audio Session** không phải thủ phạm — test 1 session với Simli disable → confirm nghe đầy đủ first message qua local PCM

## MVP Scope

**In:**
- `interview_session_screen.dart`: queue + flush + fallback timeout
- `simli_session_manager.dart`: expose stronger ready signal (combine `_connected && _videoReady && audioTrackAttached`)
- New optional `display_prompt` field trên Exercise (CMS) — fallback dùng `system_prompt` strip leading instructions
- Card UI hiển thị prompt trong `interview_session_screen.dart`
- Selected option chip nâng cấp: hiện cả option text khi `interview_choice_explain`
- Test thủ công: 5 sessions consecutive, không miss audio đầu

**Out:**
- Không redesign avatar layout
- Không touch backend scoring
- Không thêm transcript replay/scroll
- Không thay ElevenLabs

## Not Doing (and Why)

- **Replace ElevenLabs** — Direction F từ Phase 2. Quá lớn, scope là fix-bug.
- **Dual playback (local + Simli)** — Direction B Phase 2. Echo risk, 2x complexity.
- **Mute mic until first agent_response_complete** — User confirm dashboard có chunks → mic không phải root cause; thêm mute logic gây regression cho learner muốn cắt lời.
- **Server-side `first_message` config** — User confirm ElevenLabs Security đã bật override; client `firstMessage` đang fire OK.
- **Persistent transcript scroll** — Out of scope; learner chỉ cần thấy đề + lượt cuối.

## Decisions (resolved 2026-05-04)

1. **`display_prompt` = derive từ `system_prompt`** — không thêm DB column. Helper function `derivePromptForLearner(systemPrompt)` strip leading instructions ("You are an examiner...") + extract task description. Logic ở Flutter side hoặc backend; ưu tiên backend để CMS preview cùng output.
2. **Position: bottom** — card đặt **trên controls bar**, dưới transcript overlay. Tránh che mặt avatar. Layout reorder: avatar → transcript → **prompt card** → controls.
3. **Choice variant: chỉ hiện option đã chọn** — trong body card hiện title + content của `selectedOption`; không list 3 options.
4. **Fallback timeout: config qua CMS** — thêm field `interview_audio_buffer_timeout_ms` (default 1500) trong CMS form. Nếu null → dùng default. Range: 500-5000ms.

## UX Flow Summary

```
[Intro screen]
  └─ Đề bài full + selected option (nếu choice)
  └─ "Bắt đầu" CTA
       │
       ▼
[Session screen]
  ┌─ Status pill (top center)
  ├─ Selected option chip (top-right, only choice variant)
  ├─ Avatar full-bleed
  ├─ Transcript overlay (last turn only, mid-bottom)
  ├─ Prompt card (bottom, above controls — expanded 8s → mini)
  └─ Controls bar (timer + mic waveform + End button)
       │
       ▼  (End)
[Result screen]
  └─ Score + transcript replay
```

## Implementation Checklist

**Backend:**
- [ ] `derivePromptForLearner(systemPrompt string) string` helper trong `processing/interview_prompt.go`
- [ ] `InterviewConversationDetail` + `InterviewChoiceExplainDetail`: thêm field computed `display_prompt` (derived) trả về kèm response từ `GET /v1/exercises/:id`
- [ ] `audio_buffer_timeout_ms` optional field trên Exercise (DB cột mới hoặc JSON detail) — default 1500

**Flutter:**
- [ ] `_pendingAgentChunks` queue trong `_InterviewSessionScreenState`
- [ ] Đổi gate `_simli?.isConnected` → `_simli?.isVideoReady` trong `shouldPlayInterviewAudioLocally`
- [ ] Subscribe `simli.onVideoReady` → flush queue; nếu `_useSimliAudio=true` mà chưa ready → push queue
- [ ] Fallback Timer (config từ exercise.audioBufferTimeoutMs, default 1500) → flush queue vào `PcmAudioPlayer`, set `_useSimliAudio=false`
- [ ] `SimliSessionManager.setInputAudioFormat(String? format)` — pass từ `onMetadata`
- [ ] `ExerciseDetail.interviewDisplayPrompt` + `interviewAudioBufferTimeoutMs` field
- [ ] `_PromptCard` widget — bottom position, AnimatedContainer expanded ⇄ mini, 200ms ease-out
- [ ] Auto-collapse Timer 8s, reset on tap
- [ ] Pulse animation trigger từ `onAgentResponseComplete` (skip lần đầu)
- [ ] Choice variant: body card chỉ hiện option đã chọn

**CMS:**
- [ ] `InterviewConversationFields.tsx` + `InterviewChoiceExplainFields.tsx`: input number "Audio buffer timeout (ms)" range 500-5000, default 1500
- [ ] Preview block: hiện `derivePromptForLearner(systemPrompt)` real-time để admin thấy learner sẽ thấy gì

**Tests:**
- [ ] Unit `derivePromptForLearner` — strip "You are...", extract task
- [ ] Widget test queue flush khi `isVideoReady=true`
- [ ] Widget test fallback timeout flush local
- [ ] Widget test prompt card collapse/expand · pulse
- [ ] Manual: 5 sessions liên tiếp Simli ON · không miss audio đầu
- [ ] Manual: 1 session Simli OFF (`SIMLI_API_KEY` empty) — regression-free
- [ ] Manual: 1 session với network slow để force fallback timeout

## Design Reference
[docs/designs/interview-first-turn-fix.html](../designs/interview-first-turn-fix.html)
