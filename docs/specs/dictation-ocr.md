# Spec: Dictation OCR Submission (V18.1)

> Status: V18.1 candidate — frozen contracts pending pilot
> Skill: `viet`
> Exercise type: `psani_3_dictation` (extends V18)
> Pool: `course` only
> Date: 2026-05-05
> Idea source: `docs/ideas/dictation-ocr.md`
> Parent spec: `docs/specs/dictation-exercise.md` (V18)

---

## 0. Decisions locked (do not relitigate without explicit scope change)

| # | Decision | Value |
|---|----------|-------|
| O1 | OCR provider | **Claude Vision** via existing `ANTHROPIC_API_KEY`. No new SDK, no new vendor. |
| O2 | Model | `LLM_OCR_MODEL` env (default `claude-opus-4-7`). Centralized in `processing/llm_config.go`. |
| O3 | Submission mode | `DictationDetail.submission_mode: "type" \| "ocr" \| "both"`. Default `"type"` (preserves V18). |
| O4 | Per-image granularity | One photo per sentence. Aligns with V18 stepper UX; simpler scoring; clearer learner mental model. |
| O5 | Preview-confirm | OCR text returns to learner pre-filled in editable TextField; learner edits + taps "Dùng văn bản này"; only then sentence is locked for Submit. |
| O6 | Score path | OCR'd text → existing `dictation_processor.ProcessDictationAttempt`. Same Levenshtein scorer, same `DictationFeedback` response. |
| O7 | Endpoint | New `POST /v1/attempts/:id/submit-dictation-ocr` (multipart). Coexists with `submit-text`. |
| O8 | Image storage | Persist via existing `media_assets` table with new optional `attempt_id` FK (or `dictation_attempt_images` if cleaner — finalize in plan). 30-day retention via future cron (out of V18.1). |
| O9 | Image cap | 8 images max per request, 5MB each, JPEG/PNG/HEIC whitelist. Mirror V17.2 avatar caps. |
| O10 | Pilot threshold | ≥90% char accuracy (CER ≤10%) on 20-photo gold set across 5 learners before enabling `submission_mode="ocr"` as default. |

---

## 1. Objective and target users

**Objective:** Add a handwriting-photo submission path to `psani_3_dictation` so A2 learners practice writing Czech with diacritics by hand — using Claude Vision OCR with preview-confirm UX, reusing the V18 deterministic Levenshtein scorer end-to-end.

**Target users:**
- **Primary:** A2 Vietnamese learners who learn diacritics better through hand-writing than typing (motor-memory hypothesis).
- **Secondary:** Admins who want to author drills targeting handwriting muscle memory specifically (toggle `submission_mode="ocr"`) or offer learners both modes (`"both"`).

**Non-goals:**
- OCR for any exercise other than `psani_3_dictation`.
- Standalone handwriting recognition without preview-confirm (would risk score errors from OCR errors).
- On-device OCR (Vision/ML Kit) — defer to V18.2+ if Claude Vision proves too slow or expensive.
- Multi-sentence single photo. Each sentence = one photo.
- Image post-processing (deskew, rotate, contrast). Learner re-shoots if illegible.

---

## 2. Core features and acceptance criteria

### 2.1 Features (in scope V18.1)

F1. New `submission_mode` field on `DictationDetail`: enum `"type" | "ocr" | "both"`, default `"type"`.
F2. CMS `DictationFields.tsx` adds dropdown for `submission_mode` with inline hint per choice.
F3. Backend `OCRProvider` interface + `ClaudeVisionOCR` impl (`processing/dictation_ocr.go`); fail-soft to empty string if vision call errors (learner sees blank, can type instead).
F4. New endpoint `POST /v1/attempts/:id/submit-dictation-ocr`: multipart with `images[]` field, N images (1..8), each 1..5MB, MIME whitelist `image/jpeg`, `image/png`, `image/heic`. Returns `DictationFeedback` (same shape as V18 `submit-text`).
F5. Per-sentence parallel OCR via goroutine fan-out + bounded errgroup (concurrency=4) to keep p95 latency down.
F6. OCR'd text feeds into existing `dictation_processor.ProcessDictationAttempt` — no scorer changes; `DictationFeedback` includes `submission_mode: "ocr"` field for client analytics.
F7. Flutter branches on `submission_mode`:
   - `"type"`: V18 flow unchanged.
   - `"ocr"`: each step shows "📷 Chụp ảnh" button only; tap → `image_picker.pickImage(maxWidth: 1024, imageQuality: 85)` → upload single image → OCR returns text → fills editable TextField inside `DictationOCRPreviewCard` → learner edits → "Dùng văn bản này" locks sentence → Next.
   - `"both"`: each step shows both "Gõ" and "📷 Chụp ảnh" affordances; toggle remembers per-sentence choice.
F8. On Submit (OCR mode or both): Flutter posts multipart with all confirmed image files (in idx order) to `/submit-dictation-ocr`. Server stores images, OCRs in parallel (lazy — already cached if learner used preview), runs scorer, returns feedback.
F9. **Preview-confirm contract:** OCR call happens client-side at "📷 Chụp ảnh" tap (single-image endpoint `POST /v1/attempts/:id/dictation-ocr-preview` returns `{idx, text, asset_id}`). On final Submit, learner sends back the asset IDs + (already-edited) text — server skips OCR if text+asset already paired (avoids double-charge to Anthropic).
F10. i18n VI+EN: 8 new keys (see § 5).
F11. Persist images via `media_assets` row tagged with `attempt_id` for 30-day audit window (eviction cron out of V18.1).
F12. LLM prompts in `processing/llm_prompts.go` (`DictationOCRSystemPrompt`) + `processing/llm_user_prompts.go` (`buildDictationOCRUserPrompt`) per AGENTS.md SoT rule.

### 2.2 Acceptance criteria (measurable)

AC1. Admin toggles `submission_mode` on a dictation exercise via CMS dropdown; published exercise reflects the value in `GET /v1/exercises/:id`.
AC2. With `submission_mode="ocr"`, learner Flutter screen hides the "Gõ" affordance entirely; only "📷 Chụp ảnh" appears.
AC3. With `submission_mode="both"`, learner toggle is per-sentence (sentence 1 can be Type while sentence 2 is OCR).
AC4. Preview endpoint `POST /v1/attempts/:id/dictation-ocr-preview` returns OCR'd text within p95 < 5s on a 200KB JPEG.
AC5. Final `POST /v1/attempts/:id/submit-dictation-ocr` returns `DictationFeedback` within p95 < 8s for 6 sentences (5 already OCR'd via preview, 1 fresh).
AC6. OCR provider fail returns 200 with empty `text=""` for that sentence — learner sees empty TextField and can type manually. Never returns 500.
AC7. Image >5MB or wrong MIME → 400 with `error="image_too_large"` or `error="image_invalid_type"`. Image count <1 or >8 → 400 with `error="invalid_image_count"`.
AC8. Score parity: same handwritten reference text typed-in vs photographed-and-OCR'd → identical `DictationFeedback.OverallScore` (after learner confirms preview).
AC9. Pilot gold set (20 photos × 6 sentences = 120 lines, 5 learners, blind handwriting): char error rate ≤10% measured via Levenshtein distance / reference length, averaged. **Gating** for promoting OCR from "feature flag" to "production-ready".
AC10. Backwards compatibility: V18 exercises without `submission_mode` field deserialize as `"type"`, behave identically.
AC11. Tests grow by ≥18 (8 BE + 4 CMS + 6 Flutter).
AC12. All learner-facing strings have VI + EN.

---

## 3. Tech stack and constraints

| Layer | Tech | Constraint |
|-------|------|------------|
| Backend | Go (existing); `net/http` multipart | No new SDK. Use `anthropic.com/v1/messages` HTTP API directly with `image` content block. |
| OCR | Claude Vision via existing `ANTHROPIC_API_KEY` | Model from `LLM_OCR_MODEL` env (default `claude-opus-4-7`). Image base64-encoded into messages payload. |
| DB | Postgres existing | Add `attempt_id UUID NULL` column to `media_assets` via `addColumnIfMissing()`. No new tables. |
| API | New multipart endpoints, existing JSON conventions | `submit-dictation-ocr` (final) + `dictation-ocr-preview` (per-image). Both protected by attempt ownership middleware. |
| CMS | Next.js + React + TS + Vitest existing | Add dropdown to `DictationFields.tsx`; one i18n key per option. |
| Flutter | `image_picker: ^1.1.2` (already in pubspec from V17.2) | New `DictationOCRPreviewCard` widget; new `ApiClient.dictationOCRPreview()` + `submitDictationOCR()` (multipart). |
| Storage | S3 / local filesystem via existing `media` package | Same `image_asset_id` pattern as V11. New storagePrefix `dictation-ocr`. |

**No-go list (per AGENTS.md):**
- New OCR vendor (Google Vision, Azure, Tesseract) — Claude Vision suffices.
- Local on-device OCR — adds platform channels, defer.
- New scoring algorithm — reuse V18 Levenshtein.
- Inline LLM prompt strings outside SoT files.
- New rate limiter — reuse existing per-user RL on `submit-*` endpoints; add 30/min cap on preview to match V16 admin pattern.

---

## 4. Contracts

### 4.1 `DictationDetail` extended

```go
type DictationDetail struct {
    Topic                 string              `json:"topic"`
    ContextImageAssetID   string              `json:"context_image_asset_id,omitempty"`
    Sentences             []DictationSentence `json:"sentences"`
    MaxReplaysPerSentence int                 `json:"max_replays_per_sentence"`
    VoiceID               string              `json:"voice_id,omitempty"`
    MaxPoints             int                 `json:"max_points,omitempty"`
    PassThresholdPercent  int                 `json:"pass_threshold_percent,omitempty"`
    SubmissionMode        string              `json:"submission_mode,omitempty"` // V18.1: "type" | "ocr" | "both", default "type"
}
```

Backwards compatible — empty/missing `submission_mode` deserializes as `"type"` via getter helper.

### 4.2 OCR preview endpoint

`POST /v1/attempts/:id/dictation-ocr-preview` — multipart
- `idx`: int form field, 0-indexed sentence number
- `image`: file field, 1..5MB, JPEG/PNG/HEIC

Response 200:
```json
{
  "idx": 0,
  "text": "Včera jsem byl v kavárně.",
  "asset_id": "dictation-ocr/<attempt_id>/img-1730900000.jpg"
}
```

Errors: 400 `image_too_large` | `image_invalid_type` | `invalid_idx`; 422 `ocr_failed` (returns `text:""` instead — fail-soft).

### 4.3 Final submission endpoint

`POST /v1/attempts/:id/submit-dictation-ocr` — multipart
- `sentences`: JSON form field, array shape `[{"idx":0,"text":"...","asset_id":"..."}, ...]`
- Optionally re-upload images via `image_<idx>` file fields if asset_id missing (server re-OCRs lazy — usually only used when preview was skipped).

Response: same `DictationFeedback` as V18 `submit-text`, plus optional metadata field for telemetry.

### 4.4 LLM contract

`DictationOCRSystemPrompt`:
```
You are an OCR engine for Czech handwritten text. Read the photo and return ONLY the
text exactly as written, including diacritics, punctuation, and capitalization.
Output JSON: {"text": "<read text or empty if illegible>"}.
Never explain. Never add commentary. Empty string if image unreadable.
```

`buildDictationOCRUserPrompt(image base64)` — wraps image in `messages` API content block.

---

## 5. New i18n keys (VI + EN)

| Key | VI | EN |
|---|---|---|
| `dictationModeTypeLabel` | Gõ | Type |
| `dictationModeOCRLabel` | 📷 Chụp ảnh | 📷 Take photo |
| `dictationOCRPreviewTitle` | Kiểm tra văn bản đã đọc | Review recognized text |
| `dictationOCRPreviewHint` | Sửa lại nếu cần, rồi xác nhận | Edit if needed, then confirm |
| `dictationOCRConfirmBtn` | Dùng văn bản này | Use this text |
| `dictationOCRRetakeBtn` | Chụp lại | Retake |
| `dictationOCRFailedBanner` | Không nhận diện được. Hãy chụp lại hoặc gõ tay | Could not read. Retake or type instead |
| `dictationOCRUploadingHint` | Đang nhận diện… | Recognizing… |

---

## 6. UX flow

### 6.1 `submission_mode = "type"` (V18 unchanged)
No change. Existing stepper.

### 6.2 `submission_mode = "ocr"`
1. Sentence card shows audio + replay (V18 same)
2. Below audio: "📷 Chụp ảnh" button (no TextField visible)
3. Tap → `image_picker.pickImage(camera, maxWidth: 1024, imageQuality: 85)`
4. Upload to `POST /dictation-ocr-preview` with idx
5. Spinner with `dictationOCRUploadingHint`
6. On 200 response: replace button with `DictationOCRPreviewCard`:
   - Photo thumbnail (top, 16:9, fit cover)
   - Editable TextField pre-filled with OCR'd text
   - 2 buttons: "Chụp lại" (`dictationOCRRetakeBtn`) | "Dùng văn bản này" (`dictationOCRConfirmBtn`)
7. Confirm → text locked + asset_id stored → Next enabled
8. On final Submit: post `submit-dictation-ocr` with all `{idx, text, asset_id}` rows.

### 6.3 `submission_mode = "both"`
Per-sentence toggle pill row above input area: "Gõ" | "📷 Chụp ảnh". Default to "Gõ" on first visit. Choice persists per sentence in widget state. Each sentence's chosen mode submits in unified `submit-dictation-ocr` payload (text-only sentences have empty `asset_id`).

### 6.4 Result screen
Unchanged. `DictationFeedback` shape is identical.

---

## 7. File changes

### Backend (new)
- `backend/internal/processing/dictation_ocr.go` — `OCRProvider` interface + `ClaudeVisionOCR` impl + `NoopOCR` fallback
- `backend/internal/processing/dictation_ocr_test.go` — mock provider + edge cases
- `backend/internal/httpapi/attempt_dictation_ocr.go` — both endpoints
- `backend/internal/httpapi/attempt_dictation_ocr_test.go` — integration tests

### Backend (edits)
- `backend/internal/contracts/types.go` — add `SubmissionMode` field
- `backend/internal/processing/llm_config.go` — add `LLMOCRModel` + `LLM_OCR_MODEL` env
- `backend/internal/processing/llm_prompts.go` — add `DictationOCRSystemPrompt`
- `backend/internal/processing/llm_user_prompts.go` — add `buildDictationOCRUserPrompt`
- `backend/internal/processing/dictation_processor.go` — accept either path (text or post-OCR text — minor refactor)
- `backend/internal/store/postgres_media_assets.go` — `addColumnIfMissing("media_assets", "attempt_id", "UUID NULL")`
- `backend/internal/httpapi/server.go` — register routes

### CMS (edits)
- `cms/components/exercise-form/DictationFields.tsx` — add `submission_mode` dropdown + i18n hint
- `cms/components/exercise-form/exercise-utils.ts` — add `submission_mode` to validation + payload
- `cms/lib/i18n.tsx` — 3 admin-side keys (`dictationSubmissionModeType` / `OCR` / `Both`)
- `cms/components/__tests__/dictation-fields.test.ts` — +4 Vitest

### Flutter (new)
- `flutter_app/lib/features/exercise/widgets/dictation_ocr_preview_card.dart`
- `flutter_app/test/dictation_ocr_preview_card_test.dart`

### Flutter (edits)
- `flutter_app/lib/features/exercise/screens/dictation_exercise_screen.dart` — branch on `submissionMode` + per-step OCR/type selector
- `flutter_app/lib/models/models.dart` — add `submissionMode` to `DictationDetail` parser; default `"type"`
- `flutter_app/lib/core/api/api_client.dart` — `dictationOCRPreview(attemptId, idx, file)` + `submitDictationOCR(attemptId, sentences, files)`
- `flutter_app/lib/l10n/app_vi.arb`, `app_en.arb` — 8 keys
- `flutter_app/test/dictation_models_test.dart` — `submissionMode` parser test (+1)
- `flutter_app/test/dictation_exercise_screen_test.dart` — branch tests (+4)

### Docs
- `docs/ideas/dictation-ocr.md` (this slice)
- `docs/specs/dictation-ocr.md` (this file)
- `SPEC.md` § V18.1 (append)
- `tasks/plan.md` § V18.1 (append)
- `tasks/todo.md` (V18 tick + V18.1 backlog)

---

## 8. Verification ledger

| Step | Command | Pass criteria |
|---|---|---|
| BE-1 | `make backend-build` | compile clean |
| BE-2 | `make backend-test` | +8 tests min — `TestClaudeVisionOCR_*`, `TestSubmitDictationOCR_*`, `TestDictationOCRPreview_*` |
| CMS-1 | `make cms-lint && cd cms && npm test && make cms-build` | +4 Vitest min |
| FE-1 | `make flutter-analyze && make flutter-test` | +6 widget tests min — preview card 4, screen branch 4, model parser 1 (some overlap) |
| MAN-1 | Admin author dictation with `submission_mode="ocr"` | Exercise saves; learner sees only camera button |
| MAN-2 | Learner photo perfect handwriting | OCR returns text, learner confirms, score 10/10 |
| MAN-3 | Learner photo illegible scribble | OCR returns empty, banner shown, learner can retake |
| MAN-4 | Learner photo decent handwriting with č/š/ž/ě/ř | OCR ≥90% chars; learner edits remaining 10%; PASS |
| MAN-5 | Network off mid-OCR | Preview shows error banner; can retry; image not lost |
| MAN-6 | Mixed mode (`submission_mode="both"`) | Per-sentence toggle works; final submit includes correct shape |
| MAN-7 | Old V18 exercise (no submission_mode) | Behaves identically to V18 |
| MAN-8 | Pilot gold set (20×6 photos) | CER ≤10% averaged |
| CHECKPOINT | `make verify` | full pass |

---

## 9. Boundaries

### Always do
- Reuse `ANTHROPIC_API_KEY` and existing `LLMReviewProvider` HTTP plumbing
- Preview-confirm before lock — never auto-submit OCR text
- Fail-soft on OCR error (empty text, never 500)
- Persist images for audit (30-day window) under `dictation-ocr/<attempt_id>/...`
- VI + EN for every new copy string
- Keep prompts in `llm_prompts.go` + `llm_user_prompts.go`
- Pre-resize on Flutter to maxWidth 1024 (V17.2 pattern)

### Ask first
- Adding new OCR vendor (Google Vision, Tesseract, etc.)
- Removing preview-confirm step
- Changing `submission_mode` default from `"type"`
- Adding image post-processing (deskew, contrast)
- Adding `submission_mode` to other exercise types
- Persisting >30-day image retention

### Never do
- Block result on OCR failure (must return empty text + let learner type)
- Penalize learner for OCR misreads (preview-confirm is the safety net)
- Re-OCR on Submit if asset_id already paired with text in same payload (cost waste)
- Add OCR to MockTest exam pool exercises
- Submit images larger than 5MB (HTTP 413 client-side enforcement first)

---

## 10. Open items (resolve in plan phase)

- `media_assets.attempt_id` FK vs new `dictation_attempt_images` table — **Recommend `media_assets.attempt_id` column**: smaller diff, reuses `image_asset_id` plumbing; FK can be nullable/non-strict.
- 30-day image eviction — defer to V18.3 ops slice; document in `docs/reference/infrastructure-baseline.md` as TODO.
- Anthropic preview cost monitoring — add per-day counter in admin dashboard (V18.2).
- Dropping preview endpoint and OCR-on-Submit only (saves an endpoint) — **Reject**: preview UX is the core safety net for AC9; cost is already paid once per image.

---

## 11. Out of V18.1 (parking lot)

- On-device OCR fallback (Vision Framework iOS, ML Kit Android)
- Multi-sentence single photo with line detection
- Auto-deskew / auto-rotate
- Penalty signal for OCR confidence (score discount if learner confirms low-confidence text without edits)
- Photo upload from gallery (V18.1 = camera capture only — `ImagePicker.pickImage(source: camera)`)
- OCR for `psani_2_email` / `psani_1_formular` (would need different scorer)
