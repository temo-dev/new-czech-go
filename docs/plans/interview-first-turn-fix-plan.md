# Implementation Plan: Interview First-Turn Fix (V16)

## Overview

Sửa bug audio examiner đầu session bị drop khi Simli avatar bật + thêm prompt card hiển thị đề bài bottom position. Chia thành 5 phase, 16 task atomic. Vertical slice ưu tiên: backend foundation → flutter audio fix (bug critical) → flutter UI → CMS → verify.

## Architecture Decisions

- **Buffer + gate** thay vì mute mic — root cause là Simli không drop ngay; mute mic regression cho learner ngắt lời
- **Derive prompt** thay vì DB column mới — không migration; helper Go strip instructions
- **Bottom card position** — không che avatar examiner
- **Choice variant** chỉ hiện option đã chọn — giảm noise UX
- **Timeout config qua CMS** (default 1500ms, range 500-5000) — admin tune theo device
- **Fallback timeout** flush vào local PcmAudioPlayer thay drop — luôn có audio path

## Source of truth

- Spec kỹ thuật: `docs/specs/interview-first-turn-fix.md`
- Idea + decisions: `docs/ideas/interview-first-turn-fix.md`
- UI mockup: `docs/designs/interview-first-turn-fix.html`

---

## Task List

### Phase 1: Backend foundation

#### Task 1: Implement `DerivePromptForLearner` helper

**Description:** Hàm Go strip examiner instructions khỏi `system_prompt`, extract task block (ÚKOL/TASK/Bạn là), trả learner-facing string.

**Acceptance criteria:**
- [ ] `DerivePromptForLearner("")` → `""`
- [ ] Prompt có block `ÚKOL:\n<text>\n\n<rest>` → trả `<text>` trimmed
- [ ] Prompt bắt đầu `You are an examiner. <task>` → trả `<task>` không có instruction
- [ ] Prompt chứa `{selected_option}` placeholder → strip placeholder, trả còn lại

**Verification:**
- [ ] `cd backend && go test ./internal/processing/ -run InterviewPrompt`
- [ ] 8 unit cases pass: empty, ÚKOL, TASK, Task, "Bạn là", multi-paragraph, placeholder strip, malformed

**Dependencies:** None

**Files likely touched:**
- `backend/internal/processing/interview_prompt.go` (new)
- `backend/internal/processing/interview_prompt_test.go` (new)

**Estimated scope:** S

---

#### Task 2: Extend interview detail contracts

**Description:** Thêm `DisplayPrompt` + `AudioBufferTimeoutMs` vào 2 detail struct interview. Optional fields, không break wire compat.

**Acceptance criteria:**
- [ ] `InterviewConversationDetail` có 2 field mới với json tag `omitempty`
- [ ] `InterviewChoiceExplainDetail` có 2 field mới
- [ ] Existing test fixtures vẫn unmarshal pass

**Verification:**
- [ ] `make backend-test` (no regression)
- [ ] `make backend-build`

**Dependencies:** None

**Files likely touched:**
- `backend/internal/contracts/types.go`

**Estimated scope:** XS

---

#### Task 3: Wire prompt derivation vào exercise GET

**Description:** Khi response `GET /v1/exercises/:id` cho `skill_kind=interview`, populate `display_prompt` từ helper task 1 + clamp `audio_buffer_timeout_ms` [500, 5000] với default 1500.

**Acceptance criteria:**
- [ ] Interview exercise response có `display_prompt` non-empty (nếu system_prompt valid)
- [ ] `audio_buffer_timeout_ms = 0` → response trả 1500
- [ ] `audio_buffer_timeout_ms = 100` → response trả 500 (clamp low)
- [ ] `audio_buffer_timeout_ms = 9999` → response trả 5000 (clamp high)
- [ ] Non-interview exercise không bị ảnh hưởng

**Verification:**
- [ ] `make backend-test` — new integration test cover 4 cases trên
- [ ] Manual: seed interview fixture → `curl /v1/exercises/<id>` → verify response

**Dependencies:** Task 1, Task 2

**Files likely touched:**
- `backend/internal/httpapi/server.go` (or exercise handler file)
- `backend/internal/httpapi/v16_interview_test.go` (new)

**Estimated scope:** S

---

#### Task 4: Admin preview-prompt endpoint

**Description:** `POST /v1/admin/interview/preview-prompt` cho CMS preview real-time. Auth admin, rate limit 30/phút.

**Acceptance criteria:**
- [ ] No cookie → 401
- [ ] Valid admin cookie + `{"system_prompt": "..."}` → 200 với `display_prompt`
- [ ] Empty `system_prompt` → 200 + `display_prompt: ""`
- [ ] >30 req/phút từ same admin → 429

**Verification:**
- [ ] `make backend-test` — `v16_interview_preview_test.go` 4 cases
- [ ] Manual: dev token → curl POST → 200

**Dependencies:** Task 1

**Files likely touched:**
- `backend/internal/httpapi/server.go`
- `backend/internal/httpapi/v16_interview_preview_test.go` (new)

**Estimated scope:** S

---

### Checkpoint: Phase 1 — Backend foundation

- [ ] `make backend-test` green
- [ ] `make backend-build` green
- [ ] Manual: seed fixture interview exercise → API response có `display_prompt` + clamped timeout
- [ ] Admin preview endpoint trả đúng output cho 3 prompt mẫu (ÚKOL block, instruction prefix, empty)

---

### Phase 2: Flutter audio fix (CRITICAL — bug fix)

#### Task 5: Parse interview detail fields trong Flutter

**Description:** `ExerciseDetail.fromJson` đọc `display_prompt` + `audio_buffer_timeout_ms` từ detail JSON. Clamp default 1500.

**Acceptance criteria:**
- [ ] `interviewDisplayPrompt` parse string hoặc null
- [ ] `interviewAudioBufferTimeoutMs` clamp [500, 5000], default 1500 nếu null/0/out-of-range
- [ ] Non-interview exercise default 1500 (không crash khi field missing)

**Verification:**
- [ ] `make flutter-test` — `interview_prompt_derive_test.dart` 5 cases pass
- [ ] `make flutter-analyze` no warning

**Dependencies:** Task 2 (contract), Task 3 (response shape)

**Files likely touched:**
- `flutter_app/lib/models/models.dart`
- `flutter_app/test/interview_prompt_derive_test.dart` (new)

**Estimated scope:** S

---

#### Task 6: Add `setInputAudioFormat` no-op stub vào SimliSessionManager

**Description:** Method nhận format string từ ElevenLabs metadata. Hiện tại Simli Compose API không support runtime change → no-op. Method tồn tại cho call-site clarity + future use.

**Acceptance criteria:**
- [ ] `setInputAudioFormat(String? format)` exists
- [ ] Method không throw, không có side effect khác ngoài lưu vào `_inputAudioFormat`
- [ ] Existing test `simli_session_manager_test.dart` (nếu có) vẫn pass

**Verification:**
- [ ] `make flutter-analyze`
- [ ] `make flutter-test`

**Dependencies:** None

**Files likely touched:**
- `flutter_app/lib/features/interview/services/simli_session_manager.dart`

**Estimated scope:** XS

---

#### Task 7: Audio chunk queue + flush gate

**Description:** Thay gate `_simli?.isConnected` bằng `isVideoReady`. Buffer chunks vào `_pendingAgentChunks` khi chưa ready. Flush khi `simli.onVideoReady` fire.

**Acceptance criteria:**
- [ ] `shouldPlayInterviewAudioLocally` đổi param `simliConnected` → `simliVideoReady`
- [ ] Khi `_useSimliAudio=true && !_videoReadyFired`: chunk push vào queue, không gọi `_simli.sendAudio`
- [ ] Khi `simli.onVideoReady` fire: flush all chunks bằng `_simli.sendAudio` đúng thứ tự FIFO, queue empty
- [ ] Khi `_videoReadyFired=true`: chunk gửi thẳng Simli, không qua queue
- [ ] Khi `_useSimliAudio=false`: chunk → `_audioPlayer.addChunk` (path local cũ giữ nguyên)
- [ ] `dispose()` clear queue + cancel timer

**Verification:**
- [ ] `make flutter-test` — `interview_session_audio_gate_test.dart`:
  - Buffer when not ready: queue size match
  - Flush on ready: order preserved, queue empty
  - Local path unaffected
- [ ] `make flutter-analyze`

**Dependencies:** Task 5, Task 6

**Files likely touched:**
- `flutter_app/lib/features/interview/screens/interview_session_screen.dart`
- `flutter_app/test/interview_session_audio_gate_test.dart` (new)

**Estimated scope:** M

---

#### Task 8: Fallback timeout → local PcmAudioPlayer

**Description:** Nếu Simli không ready trong `audioBufferTimeoutMs` (config từ exercise) → cancel Simli path, flush queue vào `_audioPlayer`, set `_useSimliAudio=false`.

**Acceptance criteria:**
- [ ] Timer khởi tạo khi chunk đầu vào queue (lazy)
- [ ] Timer fire trước `onVideoReady` → fallback executes
- [ ] Sau fallback: subsequent chunks dùng local path
- [ ] Sau fallback: `_useSimliAudio=false` ổn định
- [ ] `onVideoReady` fire **trước** timer → cancel timer, không fallback

**Verification:**
- [ ] `make flutter-test` — fake timer test:
  - Fire timeout before ready → assert `_audioPlayer.addChunk` called N times
  - Fire ready before timeout → assert timer cancelled, no fallback
- [ ] Manual smoke: Network Link Conditioner "3G slow" → fallback fires, audio nghe được

**Dependencies:** Task 7

**Files likely touched:**
- `flutter_app/lib/features/interview/screens/interview_session_screen.dart`
- `flutter_app/test/interview_session_audio_gate_test.dart`

**Estimated scope:** S

---

### Checkpoint: Phase 2 — Audio fix verified on device

- [ ] `make flutter-analyze` no warning
- [ ] `make flutter-test` all green
- [ ] **Manual smoke (REQUIRED)**:
  - [ ] 5 sessions liên tiếp trên iPhone với `SIMLI_API_KEY` set → 0 lần miss audio đầu (record video)
  - [ ] 1 session với `SIMLI_API_KEY` empty → regression check, audio đầy đủ
  - [ ] 1 session với "3G slow" Network Link Conditioner → fallback timer fire, audio nghe được
- [ ] Review checkpoint với human trước khi sang Phase 3

---

### Phase 3: Flutter prompt card UI

#### Task 9: `InterviewPromptCard` widget — expand/collapse + auto-collapse

**Description:** Stateful widget với 2 state (expanded / mini-pill). Auto-collapse 8s. Tap toggle. Reduced motion respect.

**Acceptance criteria:**
- [ ] Mount → state expanded
- [ ] Sau 8s không tap → state mini-pill, animation 200ms ease-out
- [ ] Tap mini-pill → expanded, reset timer
- [ ] Tap header expanded → mini-pill
- [ ] `MediaQuery.disableAnimations=true` → no animation, instant state change
- [ ] Touch target mini-pill ≥44pt
- [ ] Hide khi `body` empty

**Verification:**
- [ ] `make flutter-test` — `prompt_card_test.dart`:
  - Mount expanded
  - Auto-collapse after 8s (fake timer)
  - Tap toggle
  - Reduced motion path
  - Empty body hides

**Dependencies:** Task 5

**Files likely touched:**
- `flutter_app/lib/features/interview/widgets/prompt_card.dart` (new)
- `flutter_app/test/prompt_card_test.dart` (new)

**Estimated scope:** M

---

#### Task 10: Pulse animation on agent response complete

**Description:** Public method `onAgentResponseComplete()` trigger pulse 1.5s (scale 1 → 1.04 → 1). Skip lần đầu (mount-time agent intro).

**Acceptance criteria:**
- [ ] First call → no pulse (skip)
- [ ] Subsequent calls → `_pulseController.forward(from: 0)` triggered
- [ ] Reduced motion → no pulse
- [ ] Pulse không gây layout shift (transform-only)

**Verification:**
- [ ] `make flutter-test` — pulse cases trong `prompt_card_test.dart`:
  - First call no animation
  - Second call animation triggered
  - Reduced motion no animation

**Dependencies:** Task 9

**Files likely touched:**
- `flutter_app/lib/features/interview/widgets/prompt_card.dart`
- `flutter_app/test/prompt_card_test.dart`

**Estimated scope:** S

---

#### Task 11: Mount prompt card vào session screen

**Description:** Render `InterviewPromptCard` ở `Positioned(bottom: bottomSafe + 140)` trong `interview_session_screen.dart`. Hook `_wsClient.onAgentResponseComplete` → call card method qua GlobalKey. Choice variant fill option title + content.

**Acceptance criteria:**
- [ ] Card mount khi `widget.detail.interviewDisplayPrompt` non-empty
- [ ] Card không mount khi prompt empty/null
- [ ] Bottom position trên controls bar — không overlap mic waveform
- [ ] Transcript overlay đẩy lên (bottom 300+) tránh overlap card
- [ ] Choice variant: card body hiện title + content của `selectedOption`, không list options
- [ ] `onAgentResponseComplete` fire → card pulse (sau lần 1)

**Verification:**
- [ ] `make flutter-analyze`
- [ ] `make flutter-test` — widget test mount/hide cases
- [ ] Manual: chạy session, verify card hiển thị bottom đúng position, không che avatar

**Dependencies:** Task 9, Task 10

**Files likely touched:**
- `flutter_app/lib/features/interview/screens/interview_session_screen.dart`

**Estimated scope:** S

---

#### Task 12: I18n keys VI + EN

**Description:** Thêm 3 key i18n: `interviewPromptLabel`, `interviewTapToView`, `interviewVocabHints`. Generate `app_localizations`.

**Acceptance criteria:**
- [ ] `app_vi.arb` có 3 key mới với Vietnamese + dấu đầy đủ
- [ ] `app_en.arb` có 3 key tương ứng
- [ ] `flutter gen-l10n` chạy thành công
- [ ] Card widget dùng `AppLocalizations.of(context).interviewPromptLabel` (không hardcode)

**Verification:**
- [ ] `make flutter-analyze`
- [ ] `cd flutter_app && flutter gen-l10n` no error
- [ ] VI=EN key count parity

**Dependencies:** Task 11

**Files likely touched:**
- `flutter_app/lib/l10n/app_vi.arb`
- `flutter_app/lib/l10n/app_en.arb`

**Estimated scope:** XS

---

### Checkpoint: Phase 3 — UI complete

- [ ] `make flutter-analyze` clean
- [ ] `make flutter-test` all green
- [ ] Manual: card expanded mặc định, auto-collapse 8s, tap toggle
- [ ] Manual: examiner kết thúc câu mới → pulse subtle
- [ ] Manual: choice variant hiện đúng option đã chọn
- [ ] Reduced motion ON → no animation

---

### Phase 4: CMS form fields + preview

#### Task 13: Audio buffer timeout input trong 2 interview field component

**Description:** `<NumberInput>` trong `InterviewConversationFields.tsx` + `InterviewChoiceExplainFields.tsx`. Range 500-5000, default 1500, hint giải thích.

**Acceptance criteria:**
- [ ] Input render với min=500, max=5000
- [ ] Submit payload chứa `audio_buffer_timeout_ms` (number)
- [ ] Empty input → fall back default 1500
- [ ] Out-of-range → UI clamp + error message

**Verification:**
- [ ] `make cms-lint`
- [ ] `cd cms && npm test -- interview-fields-v16`
- [ ] Manual: open form, edit interview exercise, verify input render + clamp

**Dependencies:** Task 2 (contract field name)

**Files likely touched:**
- `cms/components/exercise-form/InterviewConversationFields.tsx`
- `cms/components/exercise-form/InterviewChoiceExplainFields.tsx`
- `cms/__tests__/interview-fields-v16.test.tsx` (new)

**Estimated scope:** S

---

#### Task 14: `PromptPreview` component + proxy route

**Description:** Component debounce 400ms gọi `/api/admin/interview/preview-prompt` → render derived display_prompt. Proxy route Next.js forward sang backend với admin cookie.

**Acceptance criteria:**
- [ ] Type vào system_prompt textarea → 400ms sau preview update
- [ ] Loading skeleton khi đang fetch
- [ ] Error state khi backend 4xx/5xx
- [ ] Empty system_prompt → preview hide hoặc "Chưa có đề bài"
- [ ] Proxy route `/api/admin/interview/preview-prompt` forward Authorization

**Verification:**
- [ ] `cd cms && npm test -- prompt-preview` — debounce + render mocked fetch
- [ ] `make cms-build` no error
- [ ] Manual: gõ vào textarea, preview update sau 400ms

**Dependencies:** Task 4 (backend endpoint), Task 13

**Files likely touched:**
- `cms/components/PromptPreview.tsx` (new)
- `cms/pages/api/admin/interview/preview-prompt.ts` (new)
- `cms/components/exercise-form/InterviewConversationFields.tsx`
- `cms/components/exercise-form/InterviewChoiceExplainFields.tsx`
- `cms/__tests__/prompt-preview.test.tsx` (new)

**Estimated scope:** M

---

### Checkpoint: Phase 4 — CMS complete

- [ ] `make cms-lint` clean
- [ ] `cd cms && npm test` all green
- [ ] `make cms-build` no error
- [ ] Manual: edit interview exercise, type system_prompt → preview real-time, save → reload exercise → timeout persisted

---

### Phase 5: Verify + docs

#### Task 15: `make verify` full pass + manual smoke

**Description:** Run all verify pipelines + checklist manual smoke spec § 10.

**Acceptance criteria:**
- [ ] `make verify` exits 0
- [ ] Manual checklist all green (xem spec § 10)

**Verification:**
- [ ] `make verify`
- [ ] Manual smoke checklist completed + recorded

**Dependencies:** Phase 1-4 done

**Files likely touched:** None (verification only)

**Estimated scope:** S

---

#### Task 16: Update root SPEC.md + AGENTS.md + tasks/todo.md

**Description:** Append `## V16` block vào root `SPEC.md`, update Implemented Status trong `AGENTS.md`, mark V16 complete trong `tasks/todo.md`.

**Acceptance criteria:**
- [ ] `SPEC.md` có section `## V16 — Interview First-Turn Fix` summary 5-8 dòng
- [ ] `AGENTS.md` "Current Implementation Status" có bullet V16 với date 2026-05-XX
- [ ] `tasks/todo.md` mark V16 ✅
- [ ] Cross-link đầy đủ giữa idea/spec/design/plan

**Verification:**
- [ ] Manual review docs
- [ ] `grep -n "V16" SPEC.md AGENTS.md tasks/todo.md` — present trong cả 3

**Dependencies:** Task 15

**Files likely touched:**
- `SPEC.md`
- `AGENTS.md`
- `tasks/todo.md`

**Estimated scope:** XS

---

### Checkpoint: Complete

- [ ] All 16 tasks pass acceptance criteria
- [ ] `make verify` green
- [ ] Manual smoke checklist completed
- [ ] Docs updated and cross-linked
- [ ] Ready for review/merge

---

## Dependency Graph

```
Task 1 (derive helper) ──┬──> Task 3 (exercise GET wiring) ──┐
                         │                                    │
                         └──> Task 4 (admin preview endpoint) │
                                          │                   │
Task 2 (contracts) ──────┴────────────────┴──> Task 5 (Flutter parse) ──> Task 7 (queue)
                                                              │              │
                                                Task 6 (Simli stub) ─────────┘
                                                              ▼
                                                          Task 8 (fallback)
                                                              ▼
                                                          [PHASE 2 CHECKPOINT — device smoke]
                                                              ▼
                                                Task 9 (card widget) ──> Task 10 (pulse)
                                                              ▼              ▼
                                                          Task 11 (mount card)
                                                              ▼
                                                          Task 12 (i18n)
                                                              ▼
                                                Task 13 (CMS input) ──> Task 14 (preview)
                                                              ▼
                                                          Task 15 (verify)
                                                              ▼
                                                          Task 16 (docs)
```

## Parallelization Opportunities

**Safe to parallelize:**
- Task 1 + Task 2 (independent backend pieces)
- Task 6 (Simli stub) + Task 5 (Flutter parse) — both no dependencies on each other
- Task 13 (CMS input) độc lập Task 11 (Flutter mount), nếu 2 dev cùng work

**Must be sequential:**
- Task 7 → Task 8 (cùng file, audio gate logic chained)
- Task 11 → Task 12 (i18n cần widget exist trước để wire keys)

**Needs coordination:**
- Task 3 + Task 5 share contract — Task 2 lock contract trước

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Simli `onVideoReady` không fire trên một số device | High | Fallback timeout (Task 8) đảm bảo audio path luôn có |
| `derivePromptForLearner` regex miss edge case → empty display_prompt | Medium | Frontend hide card khi empty (Task 11 acceptance), không crash |
| iOS audio session conflict khi switch Simli→local mid-session | Medium | Test fallback path manual trên device thật trong Phase 2 checkpoint |
| CMS preview endpoint bị spam khi gõ liên tục | Low | Debounce 400ms client (Task 14) + rate limit 30/phút server (Task 4) |
| Pulse animation gây layout shift hoặc jank | Low | Transform-only animation (Task 10 acceptance) — không animate width/height |
| Card che mặt examiner | Low | Bottom position + transcript đẩy lên (Task 11 acceptance) |
| Race: chunks đến trước khi `_useSimliAudio` set | Medium | `_useSimliAudio` set trước khi WS connect (existing flow line 109-110) |

---

## Open Questions

- Vocab hint per task có cần V16 không? (Idea § Open Questions) — **Decision: out of scope, backlog**
- Telemetry log `audio_buffer_timeout_fired` count? — **Decision: out of scope V16; thêm khi có bằng chứng cần tune**
- `display_prompt` có cần i18n riêng theo locale learner không? — **Decision: 1 prompt cho mọi locale; admin tự nhập VI/EN trong system_prompt nếu cần**

---

## Estimated Effort

| Phase | Tasks | Time |
|---|---|---|
| 1. Backend foundation | 1-4 | 4h |
| 2. Flutter audio fix | 5-8 | 5h dev + 2h device smoke |
| 3. Flutter UI | 9-12 | 4h |
| 4. CMS | 13-14 | 3h |
| 5. Verify + docs | 15-16 | 1.5h |

**Total: ~17.5h dev + 2h device smoke ≈ 2.5 working days**

---

## Verification Checklist (Pre-Implementation)

- [x] Every task has acceptance criteria
- [x] Every task has verification step
- [x] Task dependencies identified and ordered correctly
- [x] No task touches more than 5 files (Task 14 touches 5, edge OK)
- [x] Checkpoints exist between major phases (4 checkpoints)
- [x] Task sizing: XS/S/M only (no L/XL)
- [ ] **Human review and approval before Phase 1 starts**
