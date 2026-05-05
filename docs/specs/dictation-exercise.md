# Spec: Dictation Exercise (`psani_3_dictation`)

> Status: V18 candidate — frozen contracts
> Skill: `viet`
> Pool: `course` only (no exam pool)
> Date: 2026-05-05
> Idea source: `docs/ideas/dictation-exercise.md`
> Design: `docs/designs/dictation-exercise.html`

---

## 0. Decisions locked (do not relitigate without explicit scope change)

| # | Decision | Value |
|---|----------|-------|
| D1 | Voice picker | Admin per-exercise, `voice_id` field on exercise. Reuse `POLLY_VOICE_ID` / `POLLY_VOICE_ID_2`. No learner override. |
| D2 | Pass threshold | Default 60%, admin override per-exercise via existing `pass_threshold_percent` (V7). |
| D3 | Replay-count storage | `attempts.details_json.replay_counts: [int]`. No new column, no migration. |
| D4 | Sentence count | Min 3, Max 8 hard. |
| D5 | OCR | **Out of V18.** Type-only ships first. Add behind exercise-level toggle in V18.1 after Claude Vision pilot. |
| D6 | Audio storage | N MP3s, one per sentence. Extend `exercise_audios` with nullable `sentence_idx INT`. |
| D7 | Submit endpoint | Reuse `POST /v1/attempts/:id/submit-text`, payload shape extended (multi-sentence array). |
| D8 | LLM annotation | Async/parallel with deterministic score. LLM failure does not block result. |
| D9 | Replay cap | Client-only enforcement; server logs telemetry only. |
| D10 | Pool | `course` only. Excluded from MockTest exam pool in V1. |

---

## 1. Objective and target users

**Objective:** Add a per-sentence dictation drill to the `viet` skill so A2 learners practice transcribing spoken Czech with correct diacritics, capitalization, and word boundaries — using existing Polly + LLM infrastructure without new heavyweight dependencies.

**Target users:**
- **Primary:** A2 Vietnamese learners preparing for `trvalý pobyt A2` exam, weakest at producing `č/š/ž/ě/ř/ň/ť/ď` and at distinguishing voiced/unvoiced contrasts.
- **Secondary:** Admins (content editors) authoring 4–8 sentence Czech dictations with topic + optional context image.

**Non-goals:**
- Replacing the listening (`nghe`) skill. Listening tests comprehension; dictation tests transcription.
- Pronunciation feedback on learner's voice — that is the `noi` skill.
- Adaptive difficulty — V1 stays static authored content.

---

## 2. Core features and acceptance criteria

### 2.1 Features (in scope V18)

F1. New exercise type `psani_3_dictation` under `skill_kind = "viet"`.
F2. Admin authors topic + optional image + 3–8 Czech sentences. CMS auto-splits transcript on `[.!?]\s+`. Per-sentence Polly TTS button. Admin previews each sentence audio before publish.
F3. Learner stepper UI: per-sentence audio (auto-play first time, manual repeat capped at `max_replays_per_sentence`), TextField, Czech keyboard hint chip row, Prev/Next, Submit on last sentence.
F4. Backend computes deterministic per-sentence score using NFC-normalized weighted Levenshtein (diacritic-pair substitution weight 0.5).
F5. Backend asks Claude for per-sentence diff annotation (`error_tags`, `feedback_vi`, `feedback_en`, `diff_chunks`); falls back to deterministic-only diff on LLM failure.
F6. Result screen: hero score + PASS/FAIL badge, per-sentence accuracy bars, expandable diff per sentence, audio replay button per sentence on result.
F7. i18n VI + EN for all new strings.
F8. Pool: `course` only. Excluded from MockTest section pickers (CMS filter).

### 2.2 Acceptance criteria (measurable)

AC1. Admin can publish a new dictation exercise from CMS with 3–8 sentences in under 2 minutes (transcript paste → auto-split → Polly per row → preview → publish).
AC2. Learner submitting a perfect transcription (all 6 sentences exactly matching reference, NFC-normalized) scores `max_points` × 1.0.
AC3. Learner submitting reference text minus all diacritics (e.g., `kavarny` instead of `kavárny`) scores ≥ 50% (because diacritic substitutions weight 0.5, not 1.0).
AC4. Submit succeeds within p95 < 2.5 s on mid-tier mobile network for a 6-sentence exercise (text payload < 2 KB).
AC5. LLM annotation arrives within p95 < 8 s after submit; if not, result screen falls back to deterministic-only diff with banner.
AC6. Replay-count cap: client never sends > `max_replays_per_sentence` plays per sentence to the audio endpoint per attempt session (verified by widget test).
AC7. CMS validation blocks publish when any sentence row lacks `audio_asset_id`.
AC8. Submitting < 3 or > 8 sentences returns HTTP 400 with `error="invalid_sentence_count"`.
AC9. All learner-facing strings have VI + EN translations (no hardcoded text on the screen).
AC10. Backend, CMS, and Flutter test suites all pass; total test count grows by ≥ 25 (10 BE + 5 CMS + 10 Flutter).

---

## 3. Tech stack and constraints

| Layer | Tech | Constraint |
|-------|------|------------|
| Backend | Go (existing), `github.com/aws/aws-sdk-go-v2/service/polly` (existing) | New code goes in `backend/internal/processing/dictation_scorer.go` + extend `processing/exercise_audio.go` |
| LLM | Claude (existing) via `LLMReviewProvider` model | Prompts in `processing/llm_prompts.go` + `processing/llm_user_prompts.go` per AGENTS.md SoT rule |
| DB | Postgres (existing) | Extend `exercise_audios` with `sentence_idx` via `addColumnIfMissing()`; no new tables |
| API | Existing `submit-text` endpoint, payload extended | Backwards compatible — old `text` and `answers` keys still work |
| CMS | Next.js + React + TS + Vitest (existing) | New `cms/components/exercise-form/DictationFields.tsx` + utils |
| Mobile | Flutter (existing) | New `flutter_app/lib/features/exercise/screens/dictation_exercise_screen.dart` + widgets |
| i18n | ARB + generated `AppLocalizations` (existing) | 8 new keys minimum |

**Non-negotiable constraints:**
- No new SDK adds in V18 (image_picker, just_audio, http already in pubspec).
- No microservices, no SQS, no new infra.
- All LLM prompts/models/fallbacks stay inside the 4 SoT files (`llm_config.go`, `llm_prompts.go`, `llm_user_prompts.go`, `llm_fallbacks.go`).

---

## 4. Canonical contracts

### 4.1 Backend Go structs (`backend/internal/contracts/types.go`)

```go
// DictationDetail surfaces in ExerciseDetail.details_json for type=psani_3_dictation
type DictationDetail struct {
    Topic                  string                 `json:"topic"`
    ContextImageAssetID    string                 `json:"context_image_asset_id,omitempty"`
    Sentences              []DictationSentence    `json:"sentences"`
    MaxReplaysPerSentence  int                    `json:"max_replays_per_sentence"`
    VoiceID                string                 `json:"voice_id"`
}

type DictationSentence struct {
    Idx          int    `json:"idx"`
    Text         string `json:"text"`
    AudioAssetID string `json:"audio_asset_id,omitempty"`
}

// DictationSubmission is the payload shape used by submit-text for this exercise type.
// It coexists with the existing `{text}` / `{answers}` shapes — handler dispatches on exercise type.
type DictationSubmission struct {
    Sentences []DictationSentenceAnswer `json:"sentences"`
}

type DictationSentenceAnswer struct {
    Idx          int    `json:"idx"`
    Text         string `json:"text"`
    ReplayCount  int    `json:"replay_count"`
}

// DictationFeedback stored in attempts.feedback_json after scoring
type DictationFeedback struct {
    OverallScore     int                      `json:"overall_score"`
    MaxPoints        int                      `json:"max_points"`
    Passed           bool                     `json:"passed"`
    PassThresholdPct int                      `json:"pass_threshold_percent"`
    Sentences        []DictationSentenceScore `json:"sentences"`
}

type DictationSentenceScore struct {
    Idx              int          `json:"idx"`
    Reference        string       `json:"reference"`
    Learner          string       `json:"learner"`
    Accuracy         float64      `json:"accuracy"`         // 0.0–1.0
    DistanceWeighted float64      `json:"distance_weighted"`
    AudioAssetID     string       `json:"audio_asset_id,omitempty"`
    ErrorTags        []string     `json:"error_tags,omitempty"`
    FeedbackVI       string       `json:"feedback_vi,omitempty"`
    FeedbackEN       string       `json:"feedback_en,omitempty"`
    DiffChunks       []DiffChunk  `json:"diff_chunks,omitempty"`
}

// DiffChunk reuses existing shape from psani_2_email LLM review
```

### 4.2 Flutter Dart classes (`flutter_app/lib/models/models.dart`)

```dart
class DictationDetail {
  final String topic;
  final String? contextImageAssetId;
  final List<DictationSentence> sentences;
  final int maxReplaysPerSentence;
  final String voiceId;
  DictationDetail.fromJson(Map<String, dynamic> j) : ...;
}

class DictationSentence {
  final int idx;
  final String text;
  final String? audioAssetId;
}

class DictationSentenceScore { /* mirrors backend */ }
```

`ExerciseDetail.dictationDetail` getter parses `details_json` when `exerciseType == 'psani_3_dictation'`.

### 4.3 CMS TS types (`cms/components/exercise-form/exercise-utils.ts`)

```ts
export interface DictationFormState {
  topic: string;
  contextImageAssetId: string | null;
  sentences: DictationSentenceForm[];
  maxReplaysPerSentence: number;
  voiceId: string;
  maxPoints: number;
  passThresholdPercent: number;
}

export interface DictationSentenceForm {
  idx: number;
  text: string;
  audioAssetId: string | null;
  audioBytes: number | null;
  audioDurationSec: number | null;
  generating: boolean;
}
```

### 4.4 API endpoints

| Method | Path | Notes |
|--------|------|-------|
| `POST` | `/v1/attempts/:id/submit-text` | Existing endpoint. New code branch: when `exercise.type == "psani_3_dictation"`, parse `DictationSubmission` from body. Validate sentence count matches exercise. |
| `POST` | `/v1/admin/exercises/:id/dictation/sentences/:idx/audio` | **New.** Generates Polly MP3 for one sentence. Body: `{voice_id, text}`. Returns `{audio_asset_id}`. Reuses existing Polly client. |
| `DELETE` | `/v1/admin/exercises/:id/dictation/sentences/:idx/audio` | **New.** Removes sentence audio (clears `audio_asset_id`, deletes blob). |

### 4.5 Submit-text request shape (extended)

Existing shape (still works for psani_1/2):
```json
{ "text": "...", "answers": ["...", "...", "..."] }
```

New shape for psani_3:
```json
{
  "sentences": [
    { "idx": 0, "text": "Pavel jde do kavárny.", "replay_count": 1 },
    { "idx": 1, "text": "Chce si dát čaj a koláč.", "replay_count": 2 }
  ]
}
```

Handler dispatches on `exercise.exercise_type` lookup before parsing body.

### 4.6 Limits

| Limit | Value | Enforced where |
|-------|-------|----------------|
| Total request body | 16 KB | `http.MaxBytesReader` in handler |
| Sentence count submitted | Must equal exercise sentence count | Validator → 400 `invalid_sentence_count` |
| Sentence text length | ≤ 200 chars | Validator → 400 `sentence_too_long` |
| Sentence count authored | 3 ≤ N ≤ 8 | CMS form + backend on publish |
| `max_replays_per_sentence` | 0..10 (`0` = unlimited) | CMS form + backend |
| Total Polly cost guard | ≤ 250 chars per sentence sent to Polly | Backend validator on publish |

---

## 5. Scoring algorithm

### 5.1 Normalization

```go
func normalizeForScoring(s string) string {
    s = norm.NFC.String(s)
    s = strings.ToLower(s)
    s = strings.TrimSpace(s)
    s = whitespaceCollapseRegex.ReplaceAllString(s, " ")
    return s
}
```

### 5.2 Diacritic-aware Levenshtein

Diacritic pairs (substitution weight 0.5):
```
c↔č, s↔š, z↔ž, e↔ě, r↔ř, n↔ň, t↔ť, d↔ď,
a↔á, e↔é, i↔í, o↔ó, u↔ú, u↔ů, y↔ý
```

Implementation: standard 2D DP with custom `subCost(a, b)` returning `0.5` for diacritic-pairs, `0.0` for equal, `1.0` otherwise. Insertion and deletion cost `1.0`.

```go
func dictationDistance(a, b []rune) float64 {
    // ... DP with subCost
}

func sentenceAccuracy(ref, learner string) float64 {
    refN := []rune(normalizeForScoring(ref))
    lrnN := []rune(normalizeForScoring(learner))
    d := dictationDistance(refN, lrnN)
    maxLen := math.Max(float64(len(refN)), 1)
    acc := 1 - d/maxLen
    if acc < 0 { acc = 0 }
    return acc
}
```

### 5.3 Aggregation

```go
overallAccuracy := mean(sentenceAccuracies)
overallScore := int(math.Round(overallAccuracy * float64(maxPoints)))
passed := overallScore >= int(math.Ceil(float64(maxPoints) * float64(passThresholdPct) / 100.0))
```

### 5.4 LLM annotation flow

After deterministic score computed:
1. Build prompt per sentence (only sentences with accuracy < 1.0).
2. Single Claude call with array of `{idx, ref, learner, distance}` → returns array of `DictationSentenceScore` annotation fields.
3. Merge into the deterministic score record. On LLM error, leave `error_tags`, `feedback_*`, `diff_chunks` empty.

System prompt skeleton (final string lives in `llm_prompts.go`):
> You are a Czech language tutor for A2 Vietnamese learners. For each sentence, compare the reference and the learner's transcription. Output JSON with `error_tags` (subset of `["missing_diacritic","wrong_case","missing_word","extra_word","spelling","wrong_word"]`), `feedback_vi` (one short sentence in Vietnamese, encouraging, max 25 words), `feedback_en`, and `diff_chunks` (array with `{type:"unchanged|deleted|inserted|replaced", ref, learner}`). Do not score; deterministic scoring is already computed. ...

User prompt shape (`llm_user_prompts.go`):
```
buildDictationUserPrompt(sentences []DictationLLMInput) string
```

---

## 6. Project structure (file changes)

### 6.1 Backend (Go)

| Action | File | Purpose |
|--------|------|---------|
| New | `backend/internal/processing/dictation_scorer.go` | Levenshtein + aggregation |
| New | `backend/internal/processing/dictation_scorer_test.go` | Levenshtein unit tests, 30+ char-pair fixtures |
| New | `backend/internal/processing/dictation_llm.go` | LLM annotation provider (interface + Claude impl + nil fallback) |
| Edit | `backend/internal/processing/exercise_audio.go` | Add `GenerateSentenceAudio(ctx, exerciseID, sentenceIdx, text, voiceID)` returning `audio_asset_id` |
| Edit | `backend/internal/processing/llm_config.go` | Add `DictationModel` constant + env loader |
| Edit | `backend/internal/processing/llm_prompts.go` | Add `DictationSystemPrompt` |
| Edit | `backend/internal/processing/llm_user_prompts.go` | Add `buildDictationUserPrompt` + `extractDictationSentences` helper |
| Edit | `backend/internal/processing/llm_fallbacks.go` | Add `dictationFallbackFeedback` |
| Edit | `backend/internal/contracts/types.go` | Add `DictationDetail`, `DictationSentence`, `DictationSubmission`, `DictationFeedback`, `DictationSentenceScore` |
| Edit | `backend/internal/httpapi/server.go` | Wire new admin endpoint routes |
| New | `backend/internal/httpapi/admin_dictation_audio.go` | `POST/DELETE /v1/admin/exercises/:id/dictation/sentences/:idx/audio` |
| Edit | `backend/internal/httpapi/attempts.go` | Branch `submit-text` handler on `exercise_type == psani_3_dictation` |
| New | `backend/internal/httpapi/dictation_test.go` | Integration test: full submit-text → score → result |
| Edit | `backend/internal/store/postgres_exercise_audio.go` | Migrate `exercise_audios` add `sentence_idx INT NULL` via `addColumnIfMissing()` + composite query |
| Edit | `backend/internal/store/exercise_audio.go` | Update `ExerciseAudioStore` interface methods to accept optional `sentenceIdx *int` |

### 6.2 CMS (Next.js)

| Action | File | Purpose |
|--------|------|---------|
| New | `cms/components/exercise-form/DictationFields.tsx` | Form: topic, image, transcript textarea, sentence repeater, Polly per row, voice picker, replay cap, max_points |
| Edit | `cms/components/exercise-form/exercise-utils.ts` | Add `DictationFormState`, `dictationFormStateFromExercise`, `dictationPayloadFromForm`, `validateDictation` |
| Edit | `cms/components/exercise-form/index.tsx` | Wire `psani_3_dictation` branch; prefill module + skill_kind |
| Edit | `cms/lib/i18n.tsx` | Add VI + EN strings (CMS form labels + buttons) |
| New | `cms/app/api/admin/exercises/[exerciseId]/dictation/sentences/[idx]/audio/route.ts` | Proxy POST/DELETE |
| New | `cms/components/__tests__/dictation-fields.test.ts` | Vitest: split helper, validate, payload, form state mapper |

### 6.3 Flutter

| Action | File | Purpose |
|--------|------|---------|
| New | `flutter_app/lib/features/exercise/screens/dictation_exercise_screen.dart` | Stepper screen |
| New | `flutter_app/lib/features/exercise/widgets/dictation_audio_card.dart` | Audio card + replay counter (extends AudioPlayerWidget) |
| New | `flutter_app/lib/features/exercise/widgets/czech_keyboard_chips.dart` | Horizontal chip row that inserts at TextField cursor |
| New | `flutter_app/lib/features/exercise/widgets/dictation_result_card.dart` | 3-tab result (Tổng quan / Phản hồi / Sửa bài) |
| Edit | `flutter_app/lib/models/models.dart` | Add `DictationDetail`, `DictationSentence`, `DictationSentenceScore` parsers |
| Edit | `flutter_app/lib/features/exercise/screens/exercise_router.dart` (or equivalent dispatcher) | Route `psani_3_dictation` → `DictationExerciseScreen` |
| Edit | `flutter_app/lib/core/api/api_client.dart` | Add `submitDictation(attemptId, sentences)` (wraps `submit-text`) |
| Edit | `flutter_app/lib/l10n/app_vi.arb` and `app_en.arb` | Add 8 new keys |
| New | `flutter_app/test/dictation_exercise_screen_test.dart` | Widget tests: stepper, replay cap, chip insert, submit gate |
| New | `flutter_app/test/dictation_models_test.dart` | Parser unit tests |

### 6.4 Database

Single inline migration via `addColumnIfMissing()` at startup:
```sql
ALTER TABLE exercise_audios
  ADD COLUMN IF NOT EXISTS sentence_idx INT NULL;
CREATE INDEX IF NOT EXISTS idx_exercise_audios_exercise_sentence
  ON exercise_audios(exercise_id, sentence_idx);
```

No goose migration file. Per AGENTS.md V11 RDS caveat: `czech_user` must own the table or have `ALTER` privilege; if not, run a one-time `ALTER TABLE ... OWNER TO czech_user` post-deploy.

---

## 7. Code style

Follows existing project conventions. Specific to this slice:

| Rule | Why |
|------|-----|
| All Levenshtein logic stays in `dictation_scorer.go`; no inlining in handlers | Single source of truth for scoring |
| LLM prompt strings live only in `llm_prompts.go` / `llm_user_prompts.go` | Per AGENTS.md SoT rule |
| Czech chip glyphs hardcoded in `czech_keyboard_chips.dart` constant list | Static set; no runtime injection |
| Sentence-split regex lives in one shared TS helper used by CMS only | Backend trusts CMS-split sentences as canonical |
| TextField uses `autocorrect: false, enableSuggestions: false` | Vietnamese-locale autocorrect destroys Czech words |
| All copy goes through `AppLocalizations.of(context).*` | No `'vi'` hardcoded strings |
| Card radius 16, button height 48, spacing on 8 grid | Match V2 design system |
| Replay-counter increments only on `manual` repeat tap, not on auto-play of new sentence | Auto-play is "free" |

---

## 8. Testing strategy

### 8.1 Backend (Go)

| Test | File | What it proves |
|------|------|----------------|
| `TestDictationDistance_*` (10+ cases) | `dictation_scorer_test.go` | Diacritic pairs cost 0.5; non-pairs cost 1.0; insertion/deletion cost 1.0 |
| `TestSentenceAccuracy_PerfectMatch` | same | Returns exactly 1.0 |
| `TestSentenceAccuracy_AllDiacriticsMissing` | same | Returns ≥ 0.5 (proves diacritic weight) |
| `TestSentenceAccuracy_TotallyDifferent` | same | Returns 0.0, no panic on empty |
| `TestNormalize_NFC_Lowercase_Whitespace` | same | NFC composes `c + ̌ → č`, lowercases, collapses spaces |
| `TestSubmitDictation_Happy` | `dictation_test.go` | Full submit → score → fetch result |
| `TestSubmitDictation_WrongSentenceCount` | same | Returns 400 `invalid_sentence_count` |
| `TestSubmitDictation_SentenceTooLong` | same | Returns 400 `sentence_too_long` |
| `TestSubmitDictation_LLMFailure` | same | Falls back to deterministic-only diff |
| `TestSubmitDictation_BodyTooLarge` | same | Returns 413 |
| `TestGenerateSentenceAudio_Happy` | `exercise_audio_test.go` | Polly stub generates MP3, returns `audio_asset_id` |

Target: +10 backend tests minimum.

### 8.2 CMS (Vitest)

| Test | What |
|------|------|
| `splitTranscript_basic` | `[.!?]\s+` splits 6 sentences correctly |
| `splitTranscript_keepsAbbreviations` | `Mgr. Pavel` not split (admin can manual-correct) |
| `validateDictation_minSentences` | Rejects < 3 |
| `validateDictation_maxSentences` | Rejects > 8 |
| `dictationPayloadFromForm` | Produces correct shape |

Target: +5 CMS Vitest minimum.

### 8.3 Flutter (widget + unit)

| Test | What |
|------|------|
| `dictation_models_test`: parses `DictationDetail` from JSON | Parser correctness |
| `dictation_exercise_screen_test`: initial sentence index = 0, audio auto-plays | Initial state |
| `dictation_exercise_screen_test`: Repeat tap increments counter, blocks at cap | Cap enforcement |
| `dictation_exercise_screen_test`: Next disabled when TextField empty | Submit gate |
| `dictation_exercise_screen_test`: Last sentence Next becomes Submit | Stepper end |
| `czech_keyboard_chips_test`: chip tap inserts at cursor | Chip behavior |
| `dictation_result_card_test`: 3 tabs render correctly | Result UI |
| `dictation_result_card_test`: per-sentence accuracy bar color (green ≥80%, orange < 80%) | Accuracy color thresholds |

Target: +10 Flutter tests minimum.

### 8.4 Manual verification

| ID | Step | Expected |
|----|------|----------|
| MAN-1 | Admin authors 6-sentence dictation, Polly per row, publish | Exercise appears in learner Module |
| MAN-2 | Learner attempts, types perfect text | Score = max_points (10/10), PASS |
| MAN-3 | Learner types ref minus diacritics | Score 50–70%, PASS or FAIL near threshold (proves diacritic weight) |
| MAN-4 | Replay 3× on sentence 2, then move on | Repeat button disables at 3/3 |
| MAN-5 | Submit fail (network off) | Banner shows Retry, text not lost |
| MAN-6 | Background app mid-attempt, return | TextField content + replay counter preserved |
| MAN-7 | Result screen tab Sửa bài | Diff highlights in green/red as expected |
| MAN-8 | LLM service down (mock fail) | Result still renders deterministic-only diff |

---

## 9. Boundaries

### Always do
- Use existing `submit-text` endpoint with extended payload
- Use existing `image_asset_id` pipeline for context image
- Reuse `AppColors` / `AppSpacing` / `AppTypography` tokens
- Put all LLM strings in the 4 SoT files
- NFC-normalize before comparison
- Write VI + EN for every new copy string
- Cap Polly per-sentence text at 250 chars before generation

### Ask first
- Adding new exercise pool inclusion (e.g., `pool=exam` later)
- Changing default `max_replays_per_sentence` from 3
- Changing pass threshold default from 60%
- Adding any new SDK / dependency
- Touching the existing `psani_1_formular` or `psani_2_email` writing scorer

### Never do
- Add OCR in this slice (Phase 2 V18.1)
- Rely on LLM for the score itself (deterministic Levenshtein is the score)
- Use a single MP3 with SSML breaks instead of N MP3s
- Penalize learners for using clipboard paste or Czech chip helpers
- Block the result screen when LLM annotation fails
- Persist replay-count anti-cheat policy server-side (it is telemetry, not enforcement)
- Block submit on missing sentence audio at runtime — admin already prevented this at publish
- Mix dictation submissions into MockTest scoring

---

## 10. Open items (for plan phase, not spec)

- Exact endpoint slug: `/dictation/sentences/:idx/audio` vs reuse `/audio?sentence_idx=:idx` on existing endpoint. Plan-phase decision.
- Whether to store `replay_counts` in `attempts.details_json` as a top-level key or under `metadata.dictation`. Plan-phase decision.
- Whether to allow admin to "regenerate all audio" with a single button. Plan-phase decision.

---

## 11. Verification ledger (for shipping)

| Step | Command | Pass |
|------|---------|------|
| BE-build | `make backend-build` | ✓ |
| BE-test | `make backend-test` | ≥ +10 new tests |
| CMS-lint | `make cms-lint` | clean |
| CMS-test | `cd cms && npm test` | ≥ +5 new tests |
| CMS-build | `make cms-build` | ✓ |
| FE-analyze | `make flutter-analyze` | clean |
| FE-test | `make flutter-test` | ≥ +10 new tests |
| Smoke | `make smoke-attempt-flow` (extend with dictation) | ✓ |
| Verify | `make verify` | ✓ |
