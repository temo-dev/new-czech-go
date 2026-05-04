# Interview First-Turn Fix + Prompt-on-Screen — Technical Spec (V16)

> Source of truth: `docs/ideas/interview-first-turn-fix.md` (idea), `docs/designs/interview-first-turn-fix.html` (UI). File này là spec kỹ thuật cố định.
>
> Pre-reqs: V14 Interview Skill (`docs/ideas/interview-skill.md`).

---

## 1. Objective

Loại bỏ bug **miss audio examiner đầu session** khi Simli avatar bật + nâng cấp UX để learner thấy đề bài trong suốt session.

### Target users
Học viên Việt đang luyện phỏng vấn A2 Czech (skill_kind = `interview`).

### Success criteria
- 5 sessions liên tiếp với Simli ON (`SIMLI_API_KEY` set) → 0 lần miss audio đầu
- 1 session Simli OFF (`SIMLI_API_KEY` empty) → behavior không đổi (regression-free)
- Learner có thể tap card đề bài bất cứ lúc nào để xem lại đề khi đang nói
- Network slow simulator → fallback timeout flush local audio trong ≤2000ms

### Non-goals
- Không thay ElevenLabs / Simli
- Không redesign avatar layout
- Không thêm transcript scroll/replay trong session
- Không thêm DB column mới

---

## 2. Root Cause (đã verify)

Trong `flutter_app/lib/features/interview/services/simli_session_manager.dart`:

| Line | Sự kiện | State change |
|---|---|---|
| `394-396` | WS message `START` | `_markConnected()` → `_connected=true`, `isConnected=true` |
| `329-332` | First video frame | `_markVideoReady()` → `_videoReady=true`, `isVideoReady=true` |

Race window giữa 2 sự kiện ≈ 200-500ms. Trong window này:

- `interview_session_screen.dart:130` check `_simli?.isConnected == true` → return true (vì `_connected=true`)
- `shouldPlayInterviewAudioLocally` return `false` → route audio chunks vào Simli
- `_simli.sendAudio(chunk)` (manager line 451-454): chỉ kiểm `_connected && !_disposed && _webSocket != null` → ghi vào WS
- Simli WebRTC audio track chưa attached / first frame chưa render → chunks bị Simli pipeline drop silent

**Bằng chứng:** ElevenLabs dashboard log xác nhận chunks gửi ra. iOS speaker không phát tiếng đoạn đầu khi Simli bật. Simli OFF → nghe đầy đủ.

---

## 3. Solution Architecture

### 3.1 Audio gate redesign

```
ElevenLabs WS
    │ audio chunk
    ▼
onAudioChunk(chunk)
    │
    ├── _useSimliAudio == false → _audioPlayer.addChunk()  [LOCAL path]
    │
    └── _useSimliAudio == true:
            │
            ├── _simli.isVideoReady == true  → _simli.sendAudio(chunk)
            │
            └── _simli.isVideoReady == false → _pendingAgentChunks.add(chunk)
                                                │
                                                ├── on simli.onVideoReady → flush queue → _simli.sendAudio() x N
                                                │
                                                └── on fallback timeout (config) → flush queue → _audioPlayer.addChunk()
                                                                                     + _useSimliAudio = false
```

### 3.2 Display prompt derivation

Backend helper `derivePromptForLearner(systemPrompt string) string`:
- Strip leading examiner instructions ("You are an examiner...", "Act as...", "Pretend...")
- Extract task description block (giữa "TASK:" hoặc "ÚKOL:" và dòng trắng tiếp theo, fallback giữ original)
- Strip placeholder `{selected_option}` (sẽ thay bằng learner-facing text trong choice variant)
- Trả empty string nếu không tìm thấy task block → frontend hide card

### 3.3 Prompt card lifecycle

```
Session start
    │
    ▼
Mount card EXPANDED
    │
    ├── Auto-collapse Timer 8s ──→ State: MINI_PILL
    │                                  │
    │                                  ├── Tap → State: EXPANDED + reset Timer 8s
    │                                  │
    │                                  └── onAgentResponseComplete (skip first) → Pulse 1.5s (no state change)
    │
    └── Tap header → State: MINI_PILL
```

---

## 4. Backend Changes

### 4.1 `internal/processing/interview_prompt.go` (new file)

```go
package processing

import (
    "regexp"
    "strings"
)

// derivePromptForLearner extracts learner-facing task description from
// the LLM system_prompt. Returns empty string if no task block found.
func DerivePromptForLearner(systemPrompt string) string {
    s := strings.TrimSpace(systemPrompt)
    if s == "" {
        return ""
    }

    // Try ÚKOL: / TASK: / Task: blocks first
    taskRe := regexp.MustCompile(`(?is)(?:ÚKOL|TASK|Task|Đề bài)\s*:\s*\n?(.+?)(?:\n\s*\n|\z)`)
    if m := taskRe.FindStringSubmatch(s); len(m) > 1 {
        return cleanPromptText(m[1])
    }

    // Fallback: strip leading "You are..." / "Act as..." instructions, return remaining first paragraph
    instructionRe := regexp.MustCompile(`(?im)^(You are|Act as|Pretend|Bạn là|Hãy đóng vai)[^.\n]+\.\s*`)
    cleaned := instructionRe.ReplaceAllString(s, "")
    parts := strings.SplitN(strings.TrimSpace(cleaned), "\n\n", 2)
    if len(parts) > 0 {
        return cleanPromptText(parts[0])
    }
    return ""
}

func cleanPromptText(s string) string {
    s = strings.TrimSpace(s)
    // Strip placeholder; choice variant injects option text separately
    s = strings.ReplaceAll(s, "{selected_option}", "")
    return strings.TrimSpace(s)
}
```

### 4.2 `internal/contracts/types.go`

Mở rộng existing types (thêm fields, không break):

```go
type InterviewConversationDetail struct {
    SystemPrompt   string `json:"system_prompt"`
    MaxTurns       int    `json:"max_turns,omitempty"`
    ShowTranscript bool   `json:"show_transcript,omitempty"`

    // V16 additions
    DisplayPrompt          string `json:"display_prompt,omitempty"`            // computed by backend
    AudioBufferTimeoutMs   int    `json:"audio_buffer_timeout_ms,omitempty"`   // 500-5000, default 1500
}

type InterviewChoiceExplainDetail struct {
    SystemPrompt   string                 `json:"system_prompt"`
    Options        []InterviewChoiceOption `json:"options"`
    MaxTurns       int                    `json:"max_turns,omitempty"`
    ShowTranscript bool                   `json:"show_transcript,omitempty"`

    // V16 additions
    DisplayPrompt          string `json:"display_prompt,omitempty"`
    AudioBufferTimeoutMs   int    `json:"audio_buffer_timeout_ms,omitempty"`
}

type InterviewChoiceOption struct {
    Key     string `json:"key"`     // "A" / "B" / "C"
    Title   string `json:"title"`   // "Đầu bếp"
    Content string `json:"content"` // body shown in prompt card body when selected
}
```

### 4.3 Exercise detail builder

`internal/httpapi/server.go` (or wherever `GET /v1/exercises/:id` builds response):

- Khi `skill_kind == "interview"`, sau khi unmarshal detail → call `processing.DerivePromptForLearner(detail.SystemPrompt)` → set `detail.DisplayPrompt`
- Validate `AudioBufferTimeoutMs`: nếu 0 → set 1500; nếu out of [500, 5000] → clamp

### 4.4 No DB migration

Cả `display_prompt` lẫn `audio_buffer_timeout_ms` đều store trong existing `exercises.detail` JSONB. `DisplayPrompt` là computed (không persist). `AudioBufferTimeoutMs` admin nhập qua CMS → ghi vào JSON.

---

## 5. Flutter Changes

### 5.1 `models/models.dart` — `ExerciseDetail`

```dart
class ExerciseDetail {
  // ... existing fields

  // V16
  final String? interviewDisplayPrompt;
  final int interviewAudioBufferTimeoutMs;  // default 1500

  static ExerciseDetail fromJson(Map<String, dynamic> json) {
    final detail = json['detail'] as Map<String, dynamic>?;
    final timeoutRaw = detail?['audio_buffer_timeout_ms'];
    final timeout = (timeoutRaw is num) ? timeoutRaw.toInt().clamp(500, 5000) : 1500;
    return ExerciseDetail(
      // ...
      interviewDisplayPrompt: detail?['display_prompt'] as String?,
      interviewAudioBufferTimeoutMs: timeout,
    );
  }
}
```

### 5.2 `features/interview/services/simli_session_manager.dart`

Thêm method (optional, no-op nếu Simli không hỗ trợ format negotiation hiện tại):

```dart
String? _inputAudioFormat;

void setInputAudioFormat(String? format) {
  _inputAudioFormat = format;
  // If Simli WS supports a format-set message, send it; otherwise just record.
  // Current Compose API: format is part of token payload; runtime change not supported.
  // Method exists for future use and call-site clarity.
}
```

### 5.3 `features/interview/screens/interview_session_screen.dart`

**State:**
```dart
final List<Uint8List> _pendingAgentChunks = [];
Timer? _audioBufferTimeoutTimer;
bool _videoReadyFired = false;
```

**Modified `shouldPlayInterviewAudioLocally`** (top-level helper):
```dart
bool shouldPlayInterviewAudioLocally({
  required bool useSimliAudio,
  required bool simliVideoReady,  // CHANGED: was simliConnected
}) {
  return !(useSimliAudio && simliVideoReady);
}
```

**Wire `simli.onVideoReady`:**
```dart
simli.onVideoReady = () {
  debugPrint('Simli video ready');
  if (!mounted || _disposing) return;
  _videoReadyFired = true;
  _audioBufferTimeoutTimer?.cancel();
  _flushPendingChunksToSimli();
  setState(() => _simliConnected = true);
};
```

**Modified `onAudioChunk`:**
```dart
_wsClient.onAudioChunk = (Uint8List chunk) {
  if (!mounted || _ending) return;
  setState(() => _state = InterviewSessionState.speaking);

  if (!_useSimliAudio) {
    _audioPlayer.addChunk(chunk);
    _scheduleAgentAudioFlush();
    return;
  }

  if (_videoReadyFired) {
    _simli?.sendAudio(chunk);
    return;
  }

  // Buffer until video ready
  _pendingAgentChunks.add(chunk);
  _audioBufferTimeoutTimer ??= Timer(
    Duration(milliseconds: widget.detail.interviewAudioBufferTimeoutMs),
    _fallbackToLocalAudio,
  );
};
```

**Helpers:**
```dart
void _flushPendingChunksToSimli() {
  for (final c in _pendingAgentChunks) {
    _simli?.sendAudio(c);
  }
  _pendingAgentChunks.clear();
}

void _fallbackToLocalAudio() {
  if (_videoReadyFired || !mounted) return;
  debugPrint('Audio buffer timeout — fallback to local audio');
  setState(() => _useSimliAudio = false);
  for (final c in _pendingAgentChunks) {
    _audioPlayer.addChunk(c);
  }
  _pendingAgentChunks.clear();
  _scheduleAgentAudioFlush();
}
```

**`onMetadata` calls Simli:**
```dart
_wsClient.onMetadata = ({String? agentOutputAudioFormat, String? userInputAudioFormat}) {
  _audioPlayer.setOutputAudioFormat(agentOutputAudioFormat);
  _simli?.setInputAudioFormat(agentOutputAudioFormat);
};
```

**`dispose`:** thêm `_audioBufferTimeoutTimer?.cancel();` và `_pendingAgentChunks.clear();`

### 5.4 `features/interview/widgets/prompt_card.dart` (new file)

```dart
class InterviewPromptCard extends StatefulWidget {
  const InterviewPromptCard({
    required this.title,
    required this.body,
    this.choiceTitle,
    this.choiceContent,
    super.key,
  });

  final String title;
  final String body;
  final String? choiceTitle;     // "B — Y tá"
  final String? choiceContent;   // option content if choice variant

  @override
  State<InterviewPromptCard> createState() => InterviewPromptCardState();
}

class InterviewPromptCardState extends State<InterviewPromptCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = true;
  Timer? _autoCollapseTimer;
  late final AnimationController _pulseController;
  bool _firstAgentResponse = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scheduleAutoCollapse();
  }

  void _scheduleAutoCollapse() {
    _autoCollapseTimer?.cancel();
    if (!_expanded) return;
    _autoCollapseTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _expanded = false);
    });
  }

  void onAgentResponseComplete() {
    if (_firstAgentResponse) {
      _firstAgentResponse = false;
      return;
    }
    if (!mounted) return;
    _pulseController.forward(from: 0);
  }

  // ... build expanded card OR mini pill based on _expanded
}
```

Mount trong `interview_session_screen.dart`:
- Position: `Positioned(bottom: bottomSafe + 140, left: 14, right: 14, ...)` — trên controls bar
- Pass `widget.detail.interviewDisplayPrompt` vào `body`
- Choice variant: pass `selectedOption` + look up trong `widget.detail.interviewChoiceOptions` để fill `choiceTitle` + `choiceContent`
- Hook `_wsClient.onAgentResponseComplete` → call `_promptCardKey.currentState?.onAgentResponseComplete()`

### 5.5 `l10n/app_vi.arb` + `app_en.arb`

```json
{
  "interviewPromptLabel": "Đề bài",
  "interviewTapToView": "Tap để xem đề bài",
  "interviewVocabHints": "Gợi ý từ"
}
```

EN tương ứng: "Task", "Tap to view task", "Vocab hints".

---

## 6. CMS Changes

### 6.1 `cms/components/exercise-form/InterviewConversationFields.tsx`

Thêm 2 input dưới `system_prompt` textarea:

```tsx
<NumberInput
  label="Audio buffer timeout (ms)"
  hint="500-5000ms. Default 1500. Tăng nếu device chậm/Simli load lâu."
  min={500}
  max={5000}
  value={form.audio_buffer_timeout_ms ?? 1500}
  onChange={(v) => setForm({ ...form, audio_buffer_timeout_ms: v })}
/>

<PromptPreview systemPrompt={form.system_prompt} />
```

`PromptPreview` component: gọi `POST /v1/admin/interview/preview-prompt` (new endpoint) → backend chạy `DerivePromptForLearner` → trả `display_prompt` text. CMS hiện trong card "Preview cho học viên" để admin biết learner sẽ thấy gì.

### 6.2 `cms/components/exercise-form/InterviewChoiceExplainFields.tsx`

Thêm cùng 2 input + đảm bảo mỗi option có `title` + `content` (đã có từ V14 hoặc thêm mới).

### 6.3 Backend new endpoint

`POST /v1/admin/interview/preview-prompt`:
```json
{ "system_prompt": "..." }
```
→
```json
{ "display_prompt": "..." }
```

Auth: admin token (cùng middleware với các `/v1/admin/*` route hiện có).

---

## 7. Project Structure (touched files)

```
backend/
├── internal/contracts/types.go           # +DisplayPrompt, +AudioBufferTimeoutMs
├── internal/processing/
│   └── interview_prompt.go               # NEW · DerivePromptForLearner
├── internal/httpapi/
│   ├── server.go                         # exercise GET response · admin preview route
│   └── interview_prompt_test.go          # NEW · unit tests for derive
└── internal/processing/
    └── interview_prompt_test.go          # NEW · derive helper tests

flutter_app/lib/
├── models/models.dart                    # +interviewDisplayPrompt, +interviewAudioBufferTimeoutMs
├── features/interview/
│   ├── services/
│   │   ├── elevenlabs_ws_client.dart     # (no change)
│   │   └── simli_session_manager.dart    # +setInputAudioFormat method
│   ├── screens/
│   │   └── interview_session_screen.dart # queue + gate + fallback + prompt mount
│   └── widgets/
│       └── prompt_card.dart              # NEW · expanded ⇄ mini · pulse
├── l10n/app_vi.arb                       # +3 keys
└── l10n/app_en.arb                       # +3 keys

flutter_app/test/
├── interview_session_audio_gate_test.dart  # NEW · queue/flush/fallback widget test
├── prompt_card_test.dart                   # NEW · collapse/expand/pulse
└── interview_prompt_derive_test.dart       # NEW · model parsing

cms/
├── components/exercise-form/
│   ├── InterviewConversationFields.tsx   # +timeout input, +preview
│   └── InterviewChoiceExplainFields.tsx  # +timeout input, +preview
├── components/PromptPreview.tsx          # NEW · debounced preview call
└── pages/api/admin/interview/
    └── preview-prompt.ts                 # NEW · proxy

cms/__tests__/
└── interview-fields-v16.test.tsx         # NEW · timeout validation, preview render

docs/
├── ideas/interview-first-turn-fix.md     # exists
├── designs/interview-first-turn-fix.html # exists
└── specs/interview-first-turn-fix.md     # this file
```

---

## 8. API Contracts

### 8.1 `GET /v1/exercises/:id` (interview only)

Response detail bổ sung 2 field (computed/optional):

```json
{
  "id": "ex_abc",
  "skill_kind": "interview",
  "exercise_type": "interview_choice_explain",
  "detail": {
    "system_prompt": "You are an examiner...\n\nÚKOL: Mô tả công việc...",
    "max_turns": 6,
    "show_transcript": true,
    "options": [...],
    "display_prompt": "Mô tả công việc bạn muốn làm ở Cộng hòa Séc...",
    "audio_buffer_timeout_ms": 1500
  }
}
```

### 8.2 `POST /v1/admin/interview/preview-prompt`

**Request:**
```json
{ "system_prompt": "string" }
```

**Response 200:**
```json
{ "display_prompt": "string" }
```

**Auth:** `admin_token` cookie (CMS proxy injects).

**Rate limit:** 30 req/phút per admin (ngăn spam khi gõ liên tục — debounce client-side 400ms).

---

## 9. Code Style

Theo project conventions (xem `AGENTS.md`):
- Go: stdlib first, no new deps. Test bằng `go test ./...`.
- Flutter: `dart format` + `flutter analyze`. Widget tests trong `flutter_app/test/`.
- CMS: `next lint` + Vitest. Component PascalCase, hooks/utils camelCase.
- Commit format: `feat(v16): <slice>` hoặc `fix(v16): <slice>`.
- Comments: chỉ cho non-obvious WHY (race window note, fallback rationale).
- I18n: VI key trước, EN parity bắt buộc.

---

## 10. Testing Strategy

### Backend
- `interview_prompt_test.go`: 8 cases — empty, ÚKOL block, TASK block, "Bạn là..." prefix, multi-paragraph, `{selected_option}` strip, malformed, edge whitespace
- `httpapi` integration: mock exercise → assert `display_prompt` populated trong response
- Preview endpoint: assert auth required + clamp timeout

### Flutter
- `interview_prompt_derive_test.dart`: `ExerciseDetail.fromJson` parse + clamp `audio_buffer_timeout_ms` (0 → 1500, 100 → 500, 9999 → 5000)
- `interview_session_audio_gate_test.dart`:
  - Gate: chunks đến trước `onVideoReady` → push queue, không gọi `_simli.sendAudio`
  - Flush on ready: queue size 5 → fire `onVideoReady` → `_simli.sendAudio` called 5 times
  - Fallback: queue size 3 → wait 1500ms (override với fake clock 600ms) → assert `_audioPlayer.addChunk` called + `_useSimliAudio == false`
  - Local path: Simli OFF → chunks đi thẳng vào `_audioPlayer`, không buffer
- `prompt_card_test.dart`:
  - Mount → expanded
  - Wait 8s (fake timer) → mini pill
  - Tap mini → expanded + reset timer
  - `onAgentResponseComplete` lần 1 → no pulse
  - `onAgentResponseComplete` lần 2 → pulse animation triggered
  - Reduced motion ON → no animation, instant state change

### CMS Vitest
- `interview-fields-v16.test.tsx`:
  - Timeout input clamp validation (UI + submit payload)
  - PromptPreview debounce 400ms + render result

### Manual smoke
- 5 sessions liên tiếp Simli ON · không miss audio đầu (record video)
- 1 session Simli OFF (`SIMLI_API_KEY` empty) — full first message audible
- 1 session với Network Link Conditioner "3G slow" — verify fallback fires + still hear audio
- iOS reduced-motion ON — prompt card animation tắt
- Dynamic Type 1.3x — prompt card không truncate

### Run commands
```bash
make backend-test
make flutter-analyze
make flutter-test
make cms-lint && cd cms && npm test
make verify
```

---

## 11. Boundaries (Do / Ask / Never)

### Always Do
- Buffer chunks instead of dropping when Simli not ready
- Default timeout = 1500ms khi admin không nhập
- I18n parity VI=EN cho 3 keys mới
- `flutter analyze` + `go test` + `cms-lint` pass trước khi commit

### Ask First
- Nếu Simli API thay đổi format negotiation contract → confirm với human trước khi đổi `setInputAudioFormat` thành no-op
- Nếu cần thêm DB column thay vì JSONB store → confirm; mặc định KHÔNG thêm migration
- Nếu cần endpoint preview cho non-admin → confirm scope

### Never
- ❌ Mute mic để fix audio drop (root cause khác — sẽ regression cho learner ngắt lời)
- ❌ Đổi ElevenLabs SDK / Simli SDK
- ❌ Hardcode timeout fallback (phải đọc từ exercise detail)
- ❌ Lưu prompt derived vào DB (luôn compute từ system_prompt)
- ❌ Block first-message replay nếu Simli failed (luôn fallback local audio)
- ❌ Bypass admin auth cho preview endpoint
- ❌ Commit khi `flutter analyze` warn về new code

---

## 12. Rollout Order

Slice 1 (backend foundation):
1. `DerivePromptForLearner` + tests
2. Contract types + exercise GET response wiring
3. Preview admin endpoint + auth

Slice 2 (flutter audio fix):
4. `ExerciseDetail` parse new fields + tests
5. Queue + gate + fallback timer trong `interview_session_screen.dart`
6. Widget tests audio gate
7. Manual smoke 5 sessions

Slice 3 (flutter UI):
8. `InterviewPromptCard` widget + tests
9. Mount card trong session screen với position bottom
10. Hook `onAgentResponseComplete` → pulse
11. Choice variant: option title + content trong card body
12. I18n 3 keys

Slice 4 (CMS):
13. Timeout input + validation
14. `PromptPreview` component + proxy route
15. Vitest

Slice 5 (verify):
16. `make verify`
17. Manual smoke checklist § 10
18. Update `tasks/todo.md` mark V16 complete
19. Append summary block § V16 vào root `SPEC.md` + `CLAUDE.md`/`AGENTS.md`

---

## 13. Open Items After Ship

- Vocab hint per task (gợi ý từ vựng dưới body card) — backlog, không trong V16
- Per-exercise voice override (đã có ở V14 ELEVENLABS_VOICE_ID_C global)
- Telemetry: log `audio_buffer_timeout_fired` count để admin biết tỷ lệ fallback
- Localized `display_prompt` per learner locale — hiện tại 1 prompt cho mọi locale

---

## 14. Verification Checklist

- [ ] `derivePromptForLearner` 8 unit tests pass
- [ ] Exercise GET trả `display_prompt` non-empty cho fixture interview exercise
- [ ] `audio_buffer_timeout_ms` clamp test pass
- [ ] Audio gate widget test: queue/flush/fallback all green
- [ ] Prompt card test: collapse/expand/pulse green
- [ ] CMS Vitest: timeout + preview pass
- [ ] Manual: 5 Simli ON sessions · 0 miss
- [ ] Manual: Simli OFF regression check pass
- [ ] Manual: Slow network fallback fires
- [ ] `make verify` green
- [ ] Root `SPEC.md` § V16 added
- [ ] `AGENTS.md` mục Implemented Status update
