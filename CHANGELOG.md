# Changelog

Detailed history of completed slices. Newest first. AGENTS.md keeps the
operational guide; this file keeps the receipts.

For each slice the entry lists: scope, key file changes, decisions
worth remembering, and final test counts. When a slice introduces a new
contract or convention, the canonical home is its own spec under
`docs/specs/` — the entry here points there rather than inlining.

---

## V18.1 — Dictation OCR Submission — 2026-05-05

- Extends `psani_3_dictation` with handwriting-photo input via
  Claude Vision OCR (zero new vendor — reuses `ANTHROPIC_API_KEY`).
- `DictationDetail.submission_mode: "type" | "ocr" | "both"`, default
  `"type"` for V18 backward-compat. `Mode()` getter normalises.
- Backend: `processing/dictation_ocr.go` (`OCRProvider` interface +
  `ClaudeVisionOCR` + `NoopOCR` fallback); `LLM_OCR_MODEL` env (default
  `claude-opus-4-7`). Prompts in SoT files. Fail-soft: OCR error returns
  `("", nil)` so the endpoint never 5xx because of OCR.
- Endpoints (multipart):
  - `POST /v1/attempts/:id/dictation-ocr-preview` — single image,
    5 MB cap, MIME jpeg/png/webp, idx 0..7, per-user RL 30/min.
    Returns `{idx, text, asset_id}`. OCR fail → 200 with empty text.
  - `POST /v1/attempts/:id/submit-dictation-ocr` — `sentences` JSON form
    field, 64 KB cap. Reuses `ProcessDictationAttempt` so scoring is
    identical to V18 type-mode (AC: score parity).
- Storage: file-based under `dictation-ocr/<attempt_id>/img-<nanos>.<ext>`
  via `LOCAL_ASSETS_DIR`. No new DB table — storage key serves as
  `asset_id`.
- Compose: `LLM_OCR_PROVIDER` + `LLM_OCR_MODEL` threaded through
  `docker-compose.yml` + `docker-compose.ec2.yml`. Without the host
  shell setting these, backend defaults to `NoopOCR` (silent empty
  preview).
- Server hooks: `Server.ocrProvider` field + `dictationOCRRL`
  rate limiter; new `NewServerForTest` + `Handler()` + `SetOCRProvider`
  for fake-OCR injection in widget tests.
- CMS: `DictationFields.tsx` adds "Chế độ nộp bài" select + per-mode
  hint paragraph. `DictationFormState.submissionMode` parsed safely
  (`"type"` default for unknown/missing). `validateDictation` rejects
  invalid enum values.
- Flutter: `ExerciseDetail.dictationSubmissionMode` + `isOCRMode` /
  `isTypeMode` / `isBothMode` getters. `DictationOCRPreviewCard` widget
  (thumbnail + editable TextField + Retake/Confirm + isUploading
  spinner + optional failedBanner). `DictationExerciseScreen` branches
  on submission mode: "type" keeps V18 flow, "ocr" replaces TextField
  with camera CTA, "both" adds per-sentence ChoiceChip toggle. Lazy-
  creates the attempt at first OCR preview (preview endpoint needs
  attemptId). Submit dispatches OCR endpoint when any sentence used the
  photo path.
- Camera: `image_picker: ^1.1.2` (already in pubspec from V17.2),
  `pickImage(source: camera, maxWidth: 1024, imageQuality: 85)`.
  Injectable via `DictationImagePicker` typedef so widget tests stub
  the platform channel.
- API client: `dictationOCRPreview()` + `submitDictationOCR()` use the
  same dart:io HttpClient multipart helper as V17.2 avatar upload.
  Reuses existing `AuthException`.
- i18n: 8 new ARB keys VI + EN (mode labels, preview titles/hints,
  buttons, banners). 4 admin-side hint strings inline in
  `DictationFields.tsx` (matches existing exercise-form-fields
  convention; `cms/lib/i18n.tsx` scope is sidebar/dashboards only).
- Spec: `docs/specs/dictation-ocr.md` · idea: `docs/ideas/dictation-ocr.md`
  · plan: `tasks/plan.md § V18.1` · summary: `SPEC.md § V18.1`.
- Tests: backend +22 (510 → 532), Flutter +11 (211 → 222), CMS +5
  (116 → 121); analyze + lint + build clean across all three.
- E2E + pilot remain manual: TestFlight smoke MAN-1..MAN-8 + 20×6 photo
  gold set across 5 learners measuring CER ≤10% before promoting OCR
  to default mode in V18.2.

---

## V18 — Dictation Exercise (`psani_3_dictation`) — 2026-05-05

- New exercise type under `viet`: 3–8 Czech sentences, per-sentence
  Polly TTS, learner stepper UI (auto-play once + manual repeats with
  client-side cap), keyboard-typing input + Czech diacritic chip row.
- Backend: `processing/dictation_scorer.go` weighted Levenshtein
  (diacritic substitution weight 0.5, NFC-normalized) →
  `DictationFeedback`; `processing/dictation_processor.go` orchestrator;
  `processing/dictation_llm.go` async Claude annotator (fail-soft to
  deterministic-only diff). `POST /v1/attempts/:id/submit-text`
  branches on exercise_type to dispatch the dictation goroutine.
- Storage: `exercise_audios.sentence_idx` nullable column added via
  `addColumnIfMissing`; `ExerciseSentenceAudioStore` interface; admin
  per-sentence audio endpoint `POST/DELETE /v1/admin/exercises/:id/dictation/sentences/:idx/audio`.
- CMS: `DictationFields.tsx` (transcript paste → auto-split with Czech
  abbreviation handling: Mgr./Dr./Bc./Ph.D./pan./ing.; per-row Polly
  button + preview; replay-cap + max_points + threshold + voice inputs;
  inline validation banner). `validateExercise` blocks publish when a
  sentence lacks audio.
- Flutter: `DictationExerciseScreen` stepper + `DictationAudioCard` +
  `CzechKeyboardChips` + `DictationResultCard` 3-tab (Score / Sửa bài
  diff / Phản hồi). `submitDictation` API client.
- Spec: `docs/specs/dictation-exercise.md` · summary: `SPEC.md § V18`.
- Tests: backend 510, Flutter 211, CMS 116; smoke pass; verify green.
- Hot fixes: Postgres `ExerciseSentenceAudioStore` wired in main.go;
  audio_asset_id hydrated from sentence_audio store at exercise read;
  edit dialog rehydrates the transcript textarea.

---

## V17.2 — Learner Profile Identity (Avatar + Nickname) — 2026-05-05

- `POST /v1/users/me/avatar` (multipart, 5 MB cap, jpg/png/webp) +
  `DELETE /v1/users/me/avatar`. `patchMeRequest.avatar_asset_id`
  optional pointer; `display_name` 60-rune cap via
  `utf8.RuneCountInString` (Vietnamese-safe).
- Backend reuses V11 `uploadItemImage` helper with
  `storagePrefix=avatars`. Storage key
  `avatars/<user_id>/img-<nanos>.<ext>`; old file removed on rewrite or
  delete.
- Flutter: `image_picker: ^1.1.2`, `ApiClient.uploadAvatarV17(File)`
  via `dart:io HttpClient` multipart, `mediaUri(asset_id)` reused for
  serve. ProfileScreen redesign: V17AccountSection promotes to top as
  centered hero (avatar 96pt + name 22pt + edit pencil + email + chip
  pills + email-verify warning).
- `_AvatarTile` `Stack(fit: StackFit.expand)` + `Image.network(width,
  height, fit: BoxFit.cover)` to fix avatar circle clipping. Action
  sheet: capture / pick from library / delete / cancel; client-side
  resize via `pickImage(maxWidth: 1024, maxHeight: 1024, imageQuality:
  85)`.
- Bug fix `AuthService._adoptUser`: always `notifyListeners()` when
  `_user` mutates so `AnimatedBuilder` rebuilds.
- iOS Info.plist: `NSPhotoLibraryUsageDescription` (camera permission
  was already added in V14).
- Initials fallback derived from `display_name` (first 2 chars) or
  email local-part when avatar is absent.
- Specs: `docs/specs/learner-profile-identity.md` · idea:
  `docs/ideas/learner-profile-identity.md`.
- Tests: 452 backend (+5), 201 Flutter, 95 CMS Vitest.

---

## V17.1 — Admin User Management — 2026-05-05

- `GET /v1/admin/users` (paginate + search + role filter), `DELETE
  /v1/admin/users/:id` (soft-delete + revoke tokens; frees email for
  re-register), `POST /v1/admin/users/:id/reset-password` (admin sets
  password directly; validates strength via `auth.ValidatePassword`;
  revokes sessions; resets login RL).
- `UserStore.ListUsers(opts)` added to interface + memory + postgres
  impls (LIKE search on email + display_name + COUNT total).
- Sub-route dispatch in `handleAdminUserByID` on path suffix after
  `:id` (`/reset-password`).
- Security guards: refuse self-delete (`caller.ID == target.ID`),
  refuse admin-role target (delete + reset-password both 403), 4 KiB
  body cap.
- CMS `/users` page: search input + paginate footer + Reset/Delete row
  actions. Admin row shows `—`. Reset modal: 2 password inputs +
  confirm + inline strength hint; success state nudges admin to share
  via secure channel (chat/sms, not email).
- Soft-delete keeps `attempts.user_id` for audit; partial unique index
  `WHERE deleted_at IS NULL` allows re-register.
- Specs: `docs/specs/admin-user-management.md`.
- Tests: 447 backend (+12), 95 CMS Vitest.

---

## V17 — Self-serve Learner Auth — earlier 2026-05

- Signup/login/IAP/quota gates (see `docs/specs/self-serve-learner-spec.md`).

---

## V16 — Interview First-Turn Fix + Push-to-Talk + UX Polish — 2026-05-04

- Audio gate routes Simli chunks on `onVideoReady` (first frame), not
  WS START. Buffer pending chunks, flush on ready, fallback timer
  `audio_buffer_timeout_ms` (default 1500ms; 500..5000 clamp) →
  `PcmAudioPlayer` local.
- Simli opt-in via Profile (`InterviewPreferenceService.avatarEnabled`,
  default false). Disabled mode uses sound wave + local PCM player and
  removes the 11–15s SPEAK delay we saw in production logs.
- Local examiner volume slider 100–180% (`localAudioVolume`, default
  135%). PCM16 gain with safe clipping.
- Server-derived `display_prompt` from `system_prompt` (strip "You
  are…", extract `ÚKOL`/`TASK` block, drop `{selected_option}`
  placeholder). Helper `processing.DerivePromptForLearner` +
  `processing.EnrichInterviewDetail`.
- Admin preview endpoint: `POST /v1/admin/interview/preview-prompt`
  (RL 30/min/admin); CMS `PromptPreview` debounced 400ms.
- `InterviewPromptCard` bottom panel widget; pulse 1.5s on
  `agent_response_complete` (skip first); "Hoàn thành" / "Finish"
  sticky CTA → `popUntil(home)`.
- Push-to-talk mic (`_PttMicButton`): tap toggle replaces always-on
  VAD. State authoritative from Simli SPEAK/SILENT WS messages. 12s
  agent-wait timer after user turn. 550ms preroll buffer + 1600 byte
  minimum before flushing to ElevenLabs. Sound-wave mode applies fixed
  outbound PCM gain `2.4×` with safe clipping for VAD sensitivity.
  `canStartInterviewMic` + `shouldReleaseInterviewMicPreroll` pure
  helpers for tests.
- Empty-turn filter (`_isMeaningfulTranscript`): `\p{L}|\p{N}` regex
  drops "..." / whitespace turns from VAD false positives.
- Defensive state in `_startConversation`: flip `_state`
  speaking→ready so mic enables even when the safety timer fires
  outside `agent_response_complete`. 3s no-audio fallback enables mic
  for learner-speaks-first scenarios.
- iOS audio session switching: Simli duplex uses `playAndRecord +
  videoChat`; sound-wave PTT uses `playAndRecord + measurement` to
  avoid AEC/noise gate suppressing ElevenLabs detection. Sound-wave
  examiner playback returns to `AudioSessionConfiguration.speech()`
  before each turn to dodge iOS ducking attenuation.
- Local playback turn gate: sound-wave mode waits for
  `PcmAudioPlayer.flushAndPlay()` before re-enabling mic; chunks
  auto-flush to reduce latency, mic only re-opens on
  `agent_response_complete` or silence timeout. `flushAndPlay` defers
  while mic active to avoid iOS `AVAudioSession` `!pri`.
- Responsive layout: bottom panel scroll lane for transcript + prompt
  card, separate fixed control lane for timer/mic/end. Compact-height
  uses prompt max-height; widget tests at 360×640 catch overflow.
- Audio diagnostics: per-turn counter logs
  `Interview turn=N audio chunks: simli=X local=Y buffered=Z
  useSimliAudio=A videoReady=B`; mic `rawPeak`/`sentPeak`/`micGain`;
  ElevenLabs `vad_score` max log; `flushAndPlay` logs sample rate +
  gain + bytes + duration.
- ElevenLabs agent settings required (in Security): "Allow client
  override system_prompt", "first_message", "TTS voice". Without
  first_message override, the 3s fallback enables mic.
- Specs: `docs/specs/interview-first-turn-fix.md` · plan:
  `docs/plans/interview-first-turn-fix-plan.md`.
- Tests: 298 backend, 159 Flutter, 95 CMS Vitest.

---

## V15 — AI Image Generation in CMS — 2026-05-03

- "✨ Tạo bằng AI" button next to upload at exercise context_image,
  cteni_1 per-item, Course banner, MockTest banner (4 sites).
- Backend: `POST /v1/admin/ai/generate-image` (Replicate Flux.1-schnell,
  poll + download + local save) + `POST /v1/admin/ai/set-banner`. RL
  5/min/admin. `REPLICATE_API_KEY` env.
- CMS `AiImageButton.tsx`: 6-state machine
  (idle→open→generating→preview→uploading→done/error). Confirm flow:
  generate → preview Replicate CDN → "Dùng ảnh này" → POST `/assets`
  register → reload.
- Image format JPEG 512×512; output_format `"jpg"` (not `"jpeg"`).
  Compose adds `REPLICATE_API_KEY`. DNS fix (8.8.8.8) for Docker.
- Specs: `docs/ideas/ai-image-generation.md`.
- Tests: backend +10 (rate limiter + mock Replicate), CMS +17 Vitest.

---

## V14 — Interview Skill — 2026-05-02

- `skill_kind = "interview"` with 2 exercise types:
  `interview_conversation` + `interview_choice_explain`.
- Backend: `POST /v1/interview-sessions/token` (ephemeral ElevenLabs
  signed URL, injects `{selected_option}`); `POST
  /v1/attempts/:id/submit-interview`; `interview_scorer.go` post-
  session LLM scoring.
- CMS: `InterviewConversationFields.tsx` +
  `InterviewChoiceExplainFields.tsx` with `system_prompt`, `max_turns`,
  `show_transcript` toggle. `interview_choice_explain.options[].tips`
  for per-option learner hints.
- Flutter: `ElevenLabsWsClient` (custom Dart WS, PCM16 streaming) +
  `SimliSessionManager` (wraps `simli_client`); InterviewList →
  InterviewIntro → InterviewSession → InterviewResult screens.
- Audio pipeline: PCM16 buffer → WAV → `just_audio` (Sprint 1); pipe
  to `simliClient.sendAudioData()` for avatar lip-sync (Sprint 2).
- Security: API key server-side only; Flutter receives ephemeral
  signed URL.
- iOS deployment target 13.0 (flutter_webrtc requirement); camera +
  mic permissions added.
- `SIMLI_API_KEY` + `SIMLI_FACE_ID` via `--dart-define`; avatar
  disabled when key empty.
- `ELEVENLABS_VOICE_ID_C` env: when set, backend returns `voice_id` in
  `InterviewTokenResponse`; Flutter injects into
  `conversation_config_override.tts.voice_id`. **Requires** "Allow
  client to override TTS voice" in ElevenLabs agent Security settings —
  WS reject otherwise.
- Specs: `docs/ideas/interview-skill.md` · `docs/designs/interview-skill.html`.
- Tests: 263 backend, 61 CMS Vitest, 102 Flutter.

---

## V13 — Ano/Ne Exercise Type — 2026-05-02

- Two new exercise types: `cteni_6` (read passage → Ano/Ne) +
  `poslech_6` (TTS passage → Ano/Ne). 1–5 statements each.
- Backend: `AnoNeDetail`/`AnoNeStatement` contracts;
  `extractQuestionTexts` branch on `statements[].statement`;
  `BuildExerciseAudioText` case `poslech_6`; `isAnoNeKey()` exact-match
  guard prevents substring collision ("NEANO" ≠ "ANO").
- CMS: `AnoNeFields.tsx` (passage textarea + statement repeater +
  ANO/NE toggle + max_points + Polly button); wired before
  `startsWith` checks in `exercise-form/index.tsx`. 4 Vitest tests.
- Flutter: `AnoNeWidget` + `_AnoNeRow` (44pt tap target, animated
  states); `_buildCteni6Layout` + poslech_6 branch; `_hasAllAnswers`
  empty-guard; `AnoNeStatementView` model. 5 i18n keys VI+EN. 5 widget
  tests.
- Scoring reuses `objective_scorer.go` — no LLM, no migrations, no new
  endpoints.
- Specs: `docs/specs/ano-ne-exercise-type.md`.
- Tests: 243 backend, 53 CMS Vitest, 69 Flutter.

---

## V12 — Deck Session Mode — 2026-05-01

- `TypeGroupScreen`: tu_vung/ngu_phap groups exercises by exerciseType
  in 2-col grid with count badge.
- `DeckSessionScreen`: queue (`ListQueue`), progress bar, 4 card types
  (quizcard_basic, choice_word, fill_blank, matching).
- Local scoring on choice_word / fill_blank (substring check) — no
  backend round-trip.
- `_CompletionView` shows Đã biết / Ôn lại counts.
- 11 widget tests in `deck_session_test.dart`.

---

## V11 — Media Enrichment — 2026-05-01

- `image_asset_id` added to `VocabularyItem`, `GrammarRule`,
  `MultipleChoiceOption`, `MatchOption` (contracts + migrations
  020/021).
- `QuizcardBasicDetail.ImageAssetID` injected at publish time from the
  vocab item; `ApiClient.mediaUri(key)` → `GET /v1/media/file?key=`.
- `QuizcardWidget` 16:9 image slot (priority: context_image asset >
  flashcardImageAssetId).
- `MultipleChoiceWidget` switches to 2×2 image grid when all options
  carry `imageAssetId`. `MatchingWidget` right column shows image card.
- `ExerciseContextImage` widget on all 4 exercise screens
  (listening/reading/writing/vocab-grammar) + `DeckSessionScreen`.
- Exercise form: "🖼 Ảnh minh họa" collapsible section for every
  exercise type; `DELETE /admin/exercises/:id/assets/:assetId`.
- cteni_1 per-item image upload in CMS (CteniFields image/text
  toggle); Flutter `_buildCteni1Layout` redesign.
- `Course.BannerImageID` + `MockTest.BannerImageID` with
  `POST/DELETE /admin/{courses,mock-tests}/:id/banner`. CMS card
  header + Flutter Course/MockTest cards show banner.
- Security fix: `isSafeAssetKey()` uses `filepath.Clean + HasPrefix`
  instead of `strings.Contains("..")`.
- DB: inline `ALTER TABLE ADD COLUMN IF NOT EXISTS` at startup for all
  stores — no manual goose run. **RDS caveat**: `ALTER TABLE` requires
  table owner; if goose ran as a different user, app user can't ALTER.
  Fix: (1) one-time `ALTER TABLE ... OWNER TO <app_user>` after
  initial migration (see `deploy-first-release-checklist.md`); (2)
  `addColumnIfMissing()` checks `information_schema` first.
- Specs: `docs/specs/media-enrichment.md`.

---

## V10 — Exam Result Flow Redesign — 2026-04-30

- `MockExamSectionDetailScreen` accepts `skillKind` + `maxPoints`,
  dispatches `SectionResultCard` instead of always `ResultCard`.
- `SectionResultCard`: unified header (skill icon + label + score +
  progress bar) + body per skill (noi/viet → `ResultCard`, nghe/doc →
  `ObjectiveResultCard`).
- `ObjectiveResultCard`: card-per-question (green/red bg), 2-line
  wrong-answer layout, passage collapsible for doc.
- `_buildAnalyzingView`: LinearProgressIndicator + step list per
  speaking section (✓/⏳/○).
- 4 i18n keys: `objectiveYourAnswer`, `objectiveCorrectAnswer`,
  `viewPassage`, `hidePassage`.
- Bug fix `AdvanceMockExam`: query went from "first pending" to JOIN
  attempts ON exercise_id — fixes 400 on mixed-skill exams.
- Feature: `QuestionResult.question_text`,
  `QuestionResult.learner_answer_text` + `correct_answer_text` —
  backend extracts option text so Flutter renders "A — Nová kavárna".
- Bug fix: overall score invisible in result hero — `RichText` root
  `TextSpan` did not inherit `DefaultTextStyle`; explicit `color:
  AppColors.onSurface` added.
- Specs: `docs/specs/exam-result-flow-redesign.md` +
  `exam-result-flow-implementation.md`.
- Tests: 16 widget tests in `section_result_card_test.dart`.

---

## V9 — CMS Exercise Dashboard Upgrade — 2026-04-30

- `exercise-dashboard.tsx` 2036 lines → 5 files: `exercise-utils.ts`,
  `exercise-list.tsx`, `exercise-form/index.tsx`, `exercise-matrix.tsx`,
  `exercise-dashboard.tsx` (thin orchestrator, 211 lines).
- Coverage Matrix: Module rows × 4 cols (Nói/Nghe/Viết/Đọc), color by
  published count vs target 20, grouped by Course, sorted by
  sequence_no.
- Cell click → set module+skill_kind filter + smooth scroll; toggle
  cell → clear filter.
- Tab "Exam Pool": mini-matrix per exercise_type (Tổng / Published /
  Có ảnh) + flat list; click row → filter.
- Form prefill: matrix-cell-active tap on "+ Tạo exercise" auto-fills
  moduleId + skillKind and advances wizard to step 2.
- Loading skeleton + API error banner with retry.
- Vitest 49 unit tests on `buildMatrix`, parse/build, payload builders.
- Specs: `docs/specs/exercise-dashboard-upgrade.md`.

---

## V8 — Schema Flatten — 2026-04-30

- `skills` table dropped (migrations 017–019).
- `exercises.module_id` + `exercises.skill_kind` replaces
  `exercises.skill_id → skills`.
- `vocabulary_sets.module_id`, `grammar_rules.module_id` replace
  `skill_id`.
- `GET /v1/modules/:id/skills` returns computed `SkillSummary[]`.
- `GET /v1/modules/:id/exercises?skill_kind=X` filters server-side.
- CMS removed `/skills` page; exercise form picks module directly.
- Flutter: `SkillSummary` replaces `Skill`.
- Specs: `docs/specs/schema-flatten-skills.md`.

---

## V7 — Flexible Sprint MockTest — 2026-04-29

- Per-MockTest `pass_threshold_percent` (default 80 sprint / 60 full).
- Admin picks any exercise types per section (not locked to
  session_type).
- Flutter `MockExamScreen` routes section to correct screen
  (speaking/listening/reading/writing).
- `computeScoring` uses dynamic threshold (no hardcoded 24).
- CMS removes `session_type`; adds `pass_threshold_percent` input.
- Intro screen passScore from threshold; result shows % threshold met.

---

## V6 — LLM-Assisted Vocab & Grammar — 2026-04-28

- Async LLM job (Claude tool_use) → admin review/edit → publish atomic.
- Postgres tables: `vocabulary_sets`, `vocabulary_items`,
  `grammar_rules`, `content_generation_jobs`.
- CMS `/vocabulary`: VocabularySet list + edit/delete + Generate →
  inline editors → Save draft / resume / Publish. CMS `/grammar`: full
  parity.
- Flutter: `VocabGrammarExerciseScreen` + `QuizcardWidget` (flip) +
  `MatchingWidget` + filter pills.
- Rate limit: 1 active generation job per admin per module.

---

## Earlier slices (V2–V5) — late 2026-04

- **V2 Writing** (`psani_1_formular`, `psani_2_email`): submit-text
  endpoint, writing scorer, LLM feedback with diff highlight,
  `WritingExerciseScreen` with word-count gate. Bug fixes: parser
  type-coercion for `detail['questions']`, `writingMinWords` defaults
  per type, `_WritingResultPoller` 2-min timeout, `LocaleScope.code`
  used everywhere, `defer recover()` on async scoring goroutine,
  `MaxBytesReader(64KB)` + 500-word cap, Czech UTF-8 fix in
  `api_client.dart` (`_IOSinkImpl` was latin1).
- **V3 Listening** (`poslech_1-5`): submit-answers sync, Polly TTS
  per exercise (2 voices for poslech_4), audio store +
  `GET/POST /v1/exercises/:id/audio`, MultipleChoice/FillIn widgets,
  ObjectiveResultCard.
- **V4 Reading** (`cteni_1-5`): reuses objective scorer with
  case-insensitive substring match for fill-in; SelectableText passage
  in Flutter.
- **V5 Full MockTest**: `session_type` (speaking/pisemna/full) +
  `FullExamSession` (pisemna_score ≥42/70 + ustni_score ≥24/40);
  `POST /v1/full-exams`, `GET /v1/full-exams/:id`, `complete`. Auto-link
  speaking session into open FullExamSession.

---

## V1 baseline (mock + AWS path verified)

- Go backend with attempt upload, learner polling, transcript
  provenance, task-aware feedback for all four oral task types.
- Postgres persistence (opt-in) for exercises, attempts, transcripts,
  feedback.
- S3 + Amazon Transcribe path (verified end-to-end on production).
- LLMFeedbackProvider + LLMReviewProvider (Claude), fail-soft to
  rule-based on error or when unset.
- Amazon Polly TTS for model-answer audio in review artifacts.
- CMS CRUD for all four oral task types with status select; only
  `published` exercises surface to learners.
- CMS prompt-asset upload + preview for `Uloha 3` and `Uloha 4`.
- Compose: named volumes for `backend_assets` + `backend_attempts`;
  `AUDIO_SIGN_SECRET` threaded; `TRANSCRIBE_TIMEOUT` default 3m;
  `LOCAL_ASSETS_DIR` set to volume path.
- Flutter learner flow for all four oral tasks: split Stop/Analyze,
  AnalysisScreen, ResultCard, recent attempts, audio replay, review
  artifact.
- i18n VI + EN via ARB / `cms/lib/i18n.tsx`.
- Provider-aware audio streaming with short-lived signed URLs.
- Mock exam V2: per-section max_points, intro screen, scored result.
- V2 UI design system (Babbel orange `#FF6A14` + warm cream `#FBF3E7` +
  teal `#0F3D3A`; Inter / Fraunces; CMS sidebar; Flutter screen
  redesigns).
- `criteria_results` parsed in Flutter `AttemptFeedbackView` as
  `CriterionCheckView`.
- Admin content guide: `docs/admin-guide.md`.

---

## Cross-cutting hardening rounds

### Infrastructure (2026-04-29 + 2026-05-01)

- `ExerciseAudioStore` + `postgresExerciseAudioStore`: audio metadata
  persists across restart. `LOCAL_ASSETS_DIR` must point to a named
  volume so the MP3 also persists.
- `FullExamStore` + `postgresFullExamStore`: full exam sessions
  persist.
- Polly 2-voice dialog generator for `poslech_4`:
  `DialogExerciseAudioGenerator` + `GenerateDialogAudio()` alternating
  voices + MP3 concat. `POLLY_VOICE_ID_2` env.
- Polly TTS for writing `model_answer_text` in `ProcessWritingAttempt`.

### Security (2026-04-29)

- Dev tokens (`dev-admin-token`, `dev-learner-token`,
  `dev-learner-2-token`) only seed when `ENV != production`. Production
  must set `ENV=production` before deploy.
- `ADMIN_PASSWORD` startup guard: fatal exit if empty or `"demo123"`
  in production. Bcrypt support (`$2a$`/`$2b$` prefix) via
  `golang.org/x/crypto/bcrypt`; dev still plaintext.
- `handleSubmitText`: `MaxBytesReader(64KB)` + 500-word cap.
- CORS: `withCORS` reads `CORS_ALLOWED_ORIGINS` (comma-separated).
  Production without var → no ACAO header. Dev without var → wildcard.
- Audio upload ownership: `handleRecordingStarted`, `handleUploadURL`,
  `handleAttemptAudioUpload`, `handleUploadComplete` all run
  `authorizedAttemptForUser`.
- CMS `admin_token` cookie: `secure: true` when `NODE_ENV=production`.
- `CORS_ALLOWED_ORIGINS` required in `.env.ec2` production.
