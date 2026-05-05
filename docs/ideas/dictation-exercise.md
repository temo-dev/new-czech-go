# Dictation Exercise (psani_3_dictation)

## Problem Statement
How might we add a dictation drill to the `viet` skill so A2 learners practice transcribing spoken Czech accurately — diacritics, casing, word boundaries — using existing Polly + LLM infrastructure without adding new heavy dependencies?

## Recommended Direction

Add a new exercise type `psani_3_dictation` to the `viet` skill. Admin authors a topic + context image + 4–8 reference sentences. Polly generates one MP3 per sentence at publish time. Learner plays sentence 1, can repeat up to 3 times, types (or photographs and OCR-confirms) the sentence, taps Next, repeats for all sentences, then submits the full attempt. Backend computes word-level Levenshtein per sentence (with diacritic-mismatch weight 0.5) for the deterministic score, then asks Claude to annotate error types (missing diacritic, wrong case, missing word, spelling) and produce a friendly per-sentence feedback string. Result reuses `_DiffTextBlock` highlighting plus a per-sentence accuracy bar.

OCR submission uses Claude Vision (already in stack) with a mandatory **preview-then-confirm** step: learner snaps photo → backend returns OCR'd text → learner sees it side-by-side with the photo and edits inline → only then `Submit`. Type-only ships first; OCR ships as a secondary input mode after type-only is verified end-to-end.

This stays inside V1 scope: same `submit-text` pattern as `psani_2_email`, same Polly pipeline as poslech, same Claude integration as `LLMReviewProvider`, same `image_asset_id` plumbing as V11.

## Key Assumptions to Validate

- [ ] **Polly Czech reads numbers/abbreviations cleanly enough for A2 dictation** — admin previews each sentence's audio before publish; reject any sentence where Polly mispronounces. Add a "regenerate sentence N" button in CMS.
- [ ] **Word-level Levenshtein with diacritic-weight 0.5 maps to a fair A2 score** — pilot on 20 real submissions; compare LLM-only score vs hybrid score; if disagreement >15%, retune weights.
- [ ] **Claude Vision OCRs Czech handwriting with diacritics at >90% char accuracy** — manual test: 30 photos from 5 learners, write blind handwriting, measure char error rate including č/š/ž/ě/ř/ý/á/í/ú. If <90%, OCR ships disabled by default per exercise.
- [ ] **Per-sentence MP3 storage scales** — 8 sentences × 30KB × 200 exercises = ~50MB. Negligible vs current S3 footprint. No action needed unless miscalculated.
- [ ] **3-repeat cap is the right pressure for A2 practice mode** — admin-configurable per exercise (`max_replays_per_sentence`, default 3); revisit after 50 attempts of telemetry.

## MVP Scope

**In:**
- New `exercise_type = "psani_3_dictation"` under `skill_kind = "viet"`
- Exercise schema: `topic`, `context_image_asset_id`, `sentences[{idx, text, audio_asset_id}]`, `max_replays_per_sentence` (default 3), `max_points` (default 10)
- CMS form `DictationFields.tsx`: topic input + image upload (reuse V11) + sentence repeater (textarea + per-row "Tạo audio" Polly button + audio preview) + replay-cap input + AI image button (V15)
- Backend: extend `BuildExerciseAudioText` for per-sentence generation; new `DictationScorer` (word-level Levenshtein + diacritic-weight 0.5 + LLM annotation via new `DictationFeedbackProvider`); reuse `POST /v1/attempts/:id/submit-text` with payload shape `{sentences: [{idx, text}]}`
- Flutter: `DictationExerciseScreen` — sentence stepper (1/N), Play / Repeat (counter X/3) / Next buttons, TextField per sentence (locked once Next pressed), final Submit; reuse `WritingResultPoller`; result screen shows per-sentence accuracy + diff highlight
- LLM prompts in `llm_prompts.go` (`DictationSystemPrompt`) + `llm_user_prompts.go` (`buildDictationUserPrompt`) + `llm_fallbacks.go` (`dictationFallbackFeedback`) per AGENTS.md SoT rule
- DB: no new tables; `psani_3_dictation` slots into existing `exercises` row (per-sentence data in `details_json`); per-sentence MP3 keys in same `exercise_audios` table with new `(exercise_id, sentence_idx)` composite index
- i18n keys VI+EN: `dictationListenInstruction`, `dictationRepeatCount`, `dictationNextSentence`, `dictationSubmitAll`, `dictationSentenceLabel`
- Tests: backend Levenshtein-with-diacritic-weight unit tests; CMS Vitest for sentence repeater; Flutter widget test for stepper state machine

**Out (Phase 2):**
- OCR photo submission (Claude Vision) — ship after type-only verified
- Per-learner replay-count telemetry server-side (client-only counter for MVP)
- Speech-to-text on learner's own voice (out of scope; this is *writing* skill)
- Multi-attempt practice mode where missed sentences requeue (later iteration)

## Not Doing (and Why)

- **Tesseract / Google Vision OCR** — Claude Vision already in stack; adding a second OCR provider is unjustified complexity for an unproven feature.
- **SSML `<break>` markers in single MP3 with timestamp seek** — looks elegant but per-sentence repeat-counter UX becomes brittle (have to map button presses to seek-back-to-marker-N). Discrete MP3s per sentence is the boring, correct choice.
- **Speech-to-text scoring of learner pronunciation during dictation** — that's the `noi` skill's job. Mixing the two muddies what a dictation exercise teaches.
- **Server-enforced replay limits** — pure UX constraint; no anti-cheat value (learner can replay outside the app anyway). Client-only counter keeps API surface clean.
- **Adaptive sentence difficulty per learner** — V1 stays static authored content; adaptive pedagogy is a different product than `A2 Mluveni Sprint`.
- **Auto-grade against learner's own previous attempts** — retry creates new attempt (per AGENTS.md); no historical comparison in MVP.

## Open Questions

- **Should the diff highlight surface per-error-type icons** (missing-diacritic vs wrong-word) or just red/green? Decide after seeing first 10 real submissions.
- **Does CMS need a "split paragraph into sentences" helper button** so admin pastes a Czech paragraph and gets pre-split sentences? Probably yes — Polly per-sentence button is per-row, manual splitting is friction.
- **Should `max_replays_per_sentence = 0` mean unlimited** or be disallowed? Pick `0 = unlimited` for forward compat with practice-mode toggle.
- **How does this interact with MockTest exam pool?** Likely `pool=exam` excludes dictation in V1 (no official A2 exam dictation task) — confirm with content team.
