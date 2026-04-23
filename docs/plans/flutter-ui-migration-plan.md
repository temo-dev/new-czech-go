# Flutter UI Migration Plan

**Goal**: Adopt UI/UX patterns from `lib_demo` while keeping current technical stack (Go backend, custom HTTP client, StatefulWidget, `just_audio`, `record`).

**Not adopting**: Supabase, Riverpod, any lib_demo backend logic.

---

## Stack Comparison

| Layer | lib_demo (old) | flutter_app (keep) |
|-------|---------------|-------------------|
| Backend | Supabase | Go API (custom) |
| State | Riverpod | StatefulWidget |
| HTTP | Supabase client | `api_client.dart` |
| Auth | Supabase Auth | TBD / simple token |
| Audio | just_audio + record | just_audio + record ✓ |
| Nav | GoRouter | adopt GoRouter (lightweight) |
| Design | AppColors/Typography | copy from lib_demo ✓ |

---

## Target Folder Structure

```
flutter_app/lib/
├── core/
│   ├── theme/
│   │   ├── app_colors.dart
│   │   ├── app_typography.dart
│   │   ├── app_spacing.dart
│   │   ├── app_radius.dart
│   │   └── app_theme.dart
│   ├── router/
│   │   ├── app_router.dart
│   │   └── app_routes.dart
│   └── api/
│       └── api_client.dart        ← move from lib/
├── models/
│   └── models.dart                ← move from lib/
├── features/
│   ├── shell/
│   │   └── learner_shell.dart     ← extract from main.dart
│   ├── home/
│   │   └── screens/
│   │       └── home_screen.dart   ← exercise list + recent attempts
│   ├── uloha_1/
│   │   └── screens/
│   │       ├── uloha1_prompt_screen.dart
│   │       ├── uloha1_recording_screen.dart
│   │       └── uloha1_feedback_screen.dart
│   ├── uloha_2/
│   │   └── screens/
│   │       ├── uloha2_prompt_screen.dart
│   │       ├── uloha2_recording_screen.dart
│   │       └── uloha2_feedback_screen.dart
│   ├── uloha_3/
│   │   └── screens/
│   │       ├── uloha3_prompt_screen.dart
│   │       ├── uloha3_recording_screen.dart
│   │       └── uloha3_feedback_screen.dart
│   └── uloha_4/
│       └── screens/
│           ├── uloha4_prompt_screen.dart
│           ├── uloha4_recording_screen.dart
│           └── uloha4_feedback_screen.dart
└── shared/
    └── widgets/
        ├── primary_button.dart
        ├── score_ring.dart
        ├── feedback_card.dart
        ├── audio_playback_card.dart
        ├── diff_block.dart
        └── info_pill.dart
```

---

## Migration Tasks

### Phase 1 — Design System (no logic change)

- [ ] **1.1** Copy `core/theme/` from lib_demo verbatim
  - `app_colors.dart` — color palette
  - `app_typography.dart` — text styles
  - `app_spacing.dart` — spacing constants
  - `app_radius.dart` — border radius constants
  - `app_theme.dart` — ThemeData build
- [ ] **1.2** Wire `app_theme.dart` into `MaterialApp` in `main.dart`
- [ ] **1.3** Replace hardcoded colors/sizes in existing widgets with theme tokens

**Deliverable**: App looks identical but uses design system. Zero logic change.

---

### Phase 2 — Router

- [ ] **2.1** Add `go_router` to `pubspec.yaml`
- [ ] **2.2** Create `core/router/app_routes.dart` — route name constants
- [ ] **2.3** Create `core/router/app_router.dart` — GoRouter config
  - Routes: `/`, `/uloha/:taskType/prompt`, `/uloha/:taskType/recording`, `/uloha/:taskType/feedback/:attemptId`
- [ ] **2.4** Replace `Navigator.push` calls in main.dart with `context.go()`

**Deliverable**: Navigation declarative, deep-linkable.

---

### Phase 3 — Extract Shared Widgets

Extract from `main.dart` into `shared/widgets/`:

- [ ] **3.1** `PrimaryButton` — styled CTA button
- [ ] **3.2** `ScoreRing` — circular score display (from `_ResultCard`)
- [ ] **3.3** `FeedbackCard` — metric breakdown card
- [ ] **3.4** `AudioPlaybackCard` — from `_AttemptAudioPlaybackCard` + `_ReviewArtifactAudioPlaybackCard`
- [ ] **3.5** `DiffBlock` — from `_ReviewDiffBlock` + `_DiffChunkTile`
- [ ] **3.6** `InfoPill` — from `_InfoPill`

**Deliverable**: shared/widgets/ usable across all 4 Uloha screens.

---

### Phase 4 — Extract Shell & Home

- [ ] **4.1** Extract `LearnerShell` → `features/shell/learner_shell.dart`
- [ ] **4.2** Extract exercise list + recent attempts → `features/home/screens/home_screen.dart`
- [ ] **4.3** Move `api_client.dart` → `core/api/api_client.dart`
- [ ] **4.4** Move `models.dart` → `models/models.dart`

**Deliverable**: `main.dart` shrinks to ~50 lines (just app bootstrap).

---

### Phase 5 — Uloha Screens (UX from lib_demo)

Each Uloha gets 3 screens adapting lib_demo's speaking flow UX:

#### PromptScreen (adapt `SpeakingPromptScreen`)
- Show exercise prompt/image/hint
- Tips panel (collapsible)
- "Bắt đầu ghi âm" CTA → RecordingScreen
- **API**: `GET /exercises/:id` (already exists)

#### RecordingScreen (adapt `SpeakingRecordingScreen`)
- Waveform visualizer
- Recording timer
- States: `idle` → `recording` → `uploading` → `processing`
- Stop button → upload → poll → navigate to FeedbackScreen
- **API**: `POST /attempts` + `GET /attempts/:id` poll (already exists)

#### FeedbackScreen (adapt `SpeakingFeedbackScreen`)
- Score ring (total)
- Metric breakdown cards
- Diff block (transcript vs model)
- Audio playback (attempt + reference)
- "Thử lại" → back to PromptScreen
- **API**: `GET /attempts/:id/review` (already exists)

**Uloha differences** (same screens, different content fields):

| | Uloha 1 | Uloha 2 | Uloha 3 | Uloha 4 |
|-|---------|---------|---------|---------|
| Prompt | Topic card | Dialogue cues | Story image | Choice image |
| Tips | Topic tips | Dialogue tips | Narration tips | Reasoning tips |
| Feedback metrics | Fluency/Vocab/Grammar | Fluency/Vocab/Grammar | Fluency/Vocab/Grammar | Fluency/Vocab/Grammar |
| Extra UI | — | Turn indicator | Image prominent | Options shown |

- [ ] **5.1** Build Uloha 1 screens (reference impl)
- [ ] **5.2** Build Uloha 2 screens (adapt for dialogue cues)
- [ ] **5.3** Build Uloha 3 screens (image-prominent prompt)
- [ ] **5.4** Build Uloha 4 screens (show choice options in prompt)

---

### Phase 6 — Polish

- [ ] **6.1** Loading states: shimmer skeleton on FeedbackScreen while polling
- [ ] **6.2** Error states: retry button on all screens
- [ ] **6.3** `make flutter-analyze` clean
- [ ] **6.4** `make flutter-test` passing

---

## What We Are NOT Building

- Dashboard / XP / streaks / leaderboard
- Auth screens (login/signup) — add later if needed
- Chat / friends / social
- Writing AI
- Course / module / lesson hierarchy
- Teacher feedback threads
- Subscription / premium gates
- Simulator / mock test MCQ

---

## Execution Order

```
Phase 1 (theme)  →  Phase 2 (router)  →  Phase 3 (widgets)
     ↓
Phase 4 (shell/home extract)
     ↓
Phase 5.1 (Uloha 1 screens — reference)
     ↓
Phase 5.2–5.4 (Uloha 2–4, reuse Phase 5.1 pattern)
     ↓
Phase 6 (polish + verify)
```

Each phase keeps app runnable. No big-bang rewrites.
