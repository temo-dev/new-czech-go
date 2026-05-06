# Dictation OCR Submission (V18.1 — psani_3_dictation Phase 2)

## Problem Statement
How might we let A2 learners submit handwritten Czech sentences (photo of paper) for the dictation exercise, so they practice the muscle-memory of writing diacritics by hand instead of typing — without adding a new vendor or DB schema?

## Recommended Direction
Add a `submission_mode` field to `DictationDetail` with three values: `"type"` (V18 default), `"ocr"` (camera/photo only), `"both"` (learner picks). Implement OCR via **Claude Vision** through the existing Anthropic API key — zero new SDK, no new secret, no new vendor. Each sentence is one image. Backend `POST /v1/attempts/:id/submit-dictation-ocr` accepts multipart upload of N images, runs Claude Vision in parallel to extract Czech text per image, then funnels the OCR'd text into the **same `dictation_processor` Levenshtein scorer** so scoring stays deterministic and consistent with type submissions.

UX uses **preview-then-confirm** (already endorsed in V18 idea doc § Recommended Direction line 10): learner snaps photo → sees OCR'd text in editable TextField pre-filled below the photo → corrects misreads → taps Submit. This protects against OCR errors penalizing handwriting that humans would read correctly.

This stays inside V1 scope: same `image_asset_id` storage pipeline as V11, same Anthropic key as `LLMReviewProvider`, same `dictation_processor` scoring path as V18, same `DictationFeedback` response shape (no Flutter result-screen changes needed).

## Key Assumptions to Validate
- [ ] **Claude Vision OCRs adult Vietnamese-learner Czech handwriting at ≥90% char accuracy with diacritics** — pilot gold set: 20 photos × 6 sentences = 120 lines. Measure char error rate including č/š/ž/ě/ř/ý/á/í/ú. If <90%, ship `submission_mode="both"` only and warn admin.
- [ ] **Preview-then-confirm UX prevents OCR errors from tanking scores** — measure: % of submissions where learner edits OCR text before Submit; target ≥30%. Lower means OCR is too good (great) OR learners trust it blindly (risk).
- [ ] **Per-image latency p95 < 5s** — Claude Vision call + base64 encoding + network. If too slow, add server-side spinner with per-sentence progress indicator.
- [ ] **5MB per image cap is enough** — iPhone HEIC/JPEG at 1024px width fits comfortably; pre-resize on Flutter side via `ImagePicker.pickImage(maxWidth: 1024, imageQuality: 85)` (V17.2 pattern).
- [ ] **Persist OCR images for 30-day debug window doesn't blow storage** — 8 sentences × 200KB × 100 attempts/day × 30 days = ~5GB. Acceptable on existing S3. Evict via cron (out of V18.1).

## MVP Scope

**In:**
- New `submission_mode` field on `DictationDetail` (default `"type"` to preserve V18 behavior)
- Backend OCR provider: `processing/dictation_ocr.go` — `OCRProvider` interface + `ClaudeVisionOCR` impl; reuse `ANTHROPIC_API_KEY`; new env `LLM_OCR_MODEL` (default `claude-opus-4-7`)
- New endpoint: `POST /v1/attempts/:id/submit-dictation-ocr` (multipart, N images, max 8, max 5MB each, JPEG/PNG/HEIC whitelist)
- OCR result fans out into same `dictation_processor.ProcessDictationAttempt` → same `DictationFeedback` response shape (no consumer changes)
- Persist images as `attempt_assets` (new optional table OR reuse existing `media_assets` with `attempt_id` foreign key — plan-phase decision)
- CMS `DictationFields.tsx`: `submission_mode` dropdown (Type / OCR / Both); inline hint per choice
- Flutter `DictationExerciseScreen`: branch on `submission_mode`; for OCR/both add per-sentence "📷 Chụp ảnh" button → `image_picker` → upload → OCR result pre-fills TextField → confirm → Next; for `both`, learner toggles Type vs OCR per sentence
- New widget `DictationOCRPreviewCard`: photo thumbnail + editable TextField + "Chụp lại" / "Dùng văn bản này"
- i18n VI+EN: ~8 new keys
- LLM prompts in 4 SoT files per AGENTS.md
- Tests: backend OCR provider mock + endpoint integration; Flutter widget tests for OCR preview card + screen branch; CMS Vitest for submission_mode validation

**Out (V18.2 or later):**
- Standalone OCR for `psani_2_email` (long-form essay handwriting)
- Auto-rotation / deskew preprocessing
- Local on-device OCR fallback (Vision Framework iOS, ML Kit Android) — adds platform-channel complexity, defer until Claude Vision proves expensive
- 30-day image eviction cron — handle in V18.3 ops slice
- Multi-line photo (one photo for all sentences) — preview-confirm UX assumes one photo per sentence
- Penalty for handwriting illegibility — out of pedagogical scope

## Why this works
- Zero new vendor or secret — Claude Vision is multimodal on existing key
- Zero new DB table — reuse `media_assets` + `attempt_id` column (or `attempt_assets` if cleaner)
- Zero scoring drift — OCR text feeds into same scorer; learner sees identical result UI
- Preview-confirm UX protects accuracy — OCR errors become learner-correctable, not score penalties
- Backward compat — `submission_mode` default `"type"` keeps existing V18 exercises unchanged
