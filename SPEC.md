# SPEC — A2 Mluvení Sprint

Per-slice spec digest. Each row points at the canonical doc — either
the frozen slice spec under [`docs/specs/`](docs/specs/README.md) or,
for stable contracts that span multiple slices, the always-current
doc under [`docs/reference/`](docs/reference/README.md).

The full inline V2..V18.1 spec content (1860 lines) is archived at
[SPEC-archive-v2-to-v18.md](docs/specs/SPEC-archive-v2-to-v18.md). Don't update
the archive — it is a historical record.

## Slice digest

| Slice | Date | Scope | Spec |
|---|---|---|---|
| V2 | 2026-04-25 | Psaní (writing) — `psani_1_formular`, `psani_2_email` | [docs/specs/v2-ui-spec.md](docs/specs/v2-ui-spec.md) |
| V3 | 2026-04-26 | Poslech (listening) — `poslech_1..5` objective | [docs/reference/scoring-pipeline.md](docs/reference/scoring-pipeline.md) |
| V4 | 2026-04-27 | Čtení (reading) — `cteni_1..5` objective | [docs/reference/scoring-pipeline.md](docs/reference/scoring-pipeline.md) |
| V5 | 2026-04-27 | Full MockTest — písemná + ústní (replaced by V8 exam_mode) | [SPEC-archive-v2-to-v18.md](docs/specs/SPEC-archive-v2-to-v18.md) |
| V6 | 2026-04-28 | Vocab + Grammar LLM-assisted authoring | [docs/specs/deck-session-vocab-grammar.md](docs/specs/deck-session-vocab-grammar.md) |
| V8 | 2026-04-30 | Voice selection (TTS routing) | [docs/reference/voice-selection-spec.md](docs/reference/voice-selection-spec.md) |
| V8 (schema) | 2026-04-30 | Flat skills schema — `exercises.module_id + skill_kind` | [docs/specs/schema-flatten-skills.md](docs/specs/schema-flatten-skills.md) |
| V9 | 2026-04-30 | Exam model cleanup — `ExamTemplate vs PracticeSet` | [SPEC-archive-v2-to-v18.md](docs/specs/SPEC-archive-v2-to-v18.md) |
| V10 | 2026-05-01 | Exam result flow redesign | [docs/specs/exam-result-flow-redesign.md](docs/specs/exam-result-flow-redesign.md) + [docs/specs/exam-result-flow-implementation.md](docs/specs/exam-result-flow-implementation.md) |
| V11 | 2026-05-01 | Media enrichment (images on exercises + vocab) | [docs/specs/media-enrichment.md](docs/specs/media-enrichment.md) |
| V11 (CMS) | 2026-05-01 | Exercise dashboard upgrade | [docs/specs/exercise-dashboard-upgrade.md](docs/specs/exercise-dashboard-upgrade.md) + [docs/specs/exercise-dashboard-user-flow.md](docs/specs/exercise-dashboard-user-flow.md) |
| V12 | 2026-05-02 | Deck session mode (vocab + grammar) | [docs/specs/deck-session-vocab-grammar.md](docs/specs/deck-session-vocab-grammar.md) |
| V13 | 2026-05-01 | Ano/Ne exercise type | [docs/specs/ano-ne-exercise-type.md](docs/specs/ano-ne-exercise-type.md) |
| V14 | 2026-05-03 | Interview skill — ElevenLabs + Simli avatar | [SPEC-archive-v2-to-v18.md](docs/specs/SPEC-archive-v2-to-v18.md) (`interview-skill` ideas) |
| V15 | 2026-05-03 | AI image generation in CMS | [SPEC-archive-v2-to-v18.md](docs/specs/SPEC-archive-v2-to-v18.md) (`ai-image-generation` ideas) |
| V16 | 2026-05-04 | Interview first-turn fix + push-to-talk | [docs/specs/interview-first-turn-fix.md](docs/specs/interview-first-turn-fix.md) |
| V17 | 2026-05-05 | Self-serve learner — signup, email verify, IAP, quotas | [docs/specs/self-serve-learner-spec.md](docs/specs/self-serve-learner-spec.md) + [docs/reference/learner-profile-identity.md](docs/reference/learner-profile-identity.md) |
| V17 admin | 2026-05-05 | Admin user management | [docs/specs/admin-user-management.md](docs/specs/admin-user-management.md) |
| V17 i18n | 2026-05-05 | VI/EN ARB localization | [docs/reference/i18n-spec.md](docs/reference/i18n-spec.md) |
| V18 | 2026-05-05 | Dictation exercise (`psani_3_dictation`) | [docs/specs/dictation-exercise.md](docs/specs/dictation-exercise.md) |
| V18.1 | 2026-05-05 | Dictation OCR submission (Claude Vision) | [docs/specs/dictation-ocr.md](docs/specs/dictation-ocr.md) |
| V19 | 2026-05-06 | Skill mastery progress aggregate | [docs/specs/skill-mastery-progress.md](docs/specs/skill-mastery-progress.md) |
| V20 | 2026-05-06 | Flutter skill mastery UI | (CHANGELOG entry — no separate spec) |
| V20.1 | 2026-05-06 | Hotfixes from learner-flow simulation | (CHANGELOG entry) |
| V21 | 2026-05-07 | CEFR level progression A0→B1 | [docs/specs/cefr-level-progression.md](docs/specs/cefr-level-progression.md) + [docs/specs/cefr-level-progression-ux.md](docs/specs/cefr-level-progression-ux.md) |
| V21.1 | 2026-05-07 | V21 review hotfixes (C1+C2 + I1+I3 + I4+I5+I2/I8 + I6 doc) | (CHANGELOG entry) |
| V21.2 | 2026-05-07 | Exam-flow runtime hotfixes (MobAI test) — gate counter pin + Flutter UX + admin usage/reset | (CHANGELOG entry) |
| V21.3 | 2026-05-07 | CEFR UI wire-up — auth gate, placement test, existing-A2 dialog, HomeLevelHeader, locked courses, promotion exam end-to-end | [docs/specs/cefr-ui-wireup.md](docs/specs/cefr-ui-wireup.md) |
| V22 | 2026-05-07 | CMS catch-up — Learner X-Ray (admin debug screen), promotion / placement badge + filter + uniqueness guard, on-demand Content Health Report (6 rules) | [docs/specs/v22-cms-catch-up.md](docs/specs/v22-cms-catch-up.md) |
| V23 | 2026-05-08 | Exercise authoring polish — quick-clone row action, validation_flags inline badges + quick-fix modal, inline preview pane MVP (top 5 type) | [docs/specs/v23-exercise-authoring-polish.md](docs/specs/v23-exercise-authoring-polish.md) |
| V24 | 2026-05-08 | Reading-exercise AI draft generator — admin enters topic + selected grammar IDs + level; backend `POST /v1/admin/exercises/generate-draft` calls Claude with per-cteni-type tool_use schema and strict exam-numbering / word-count validation. CMS AiDraftPanel direct-fills `cteni_1..5` via `CteniFields` and `cteni_6` via `AnoNeFields`. C4 Czech-quality gate remains required before prod promotion | [docs/specs/v24-doc-draft-generator.md](docs/specs/v24-doc-draft-generator.md) |
| V25 | 2026-05-08 | IAP wire real — production StoreKit (`in_app_purchase`) replaces V17 stub; `/v1/auth/apple` (App Store guideline 4.8) verifies identity_token via Apple JWKS (`lestrrat-go/jwx/v2`); webhook downgrade stitch (`FindByTransactionID` → `downgradeIfExpired`) auto-flips `pro_tier=free` on EXPIRED/REFUND without Flutter mediation; paywall disclosure + Terms/Privacy + 4 upgrade entry points (Profile, Home QuotaIndicator, Exercise/Interview 429); legal docs (EULA + Privacy) bilingual VI/EN. Pricing 99k/790k VND (-33% saving). H2/H3 (App Store Connect tax/banking + TestFlight beta review) remain operator-side | [docs/specs/iap-wire-real.md](docs/specs/iap-wire-real.md) |
| V26 | 2026-05-09 | Poslech 1 per-item audio — `BuildExerciseItemTexts` + `PollyExerciseAudioGenerator.GenerateItemAudio` (mirrors V18 dictation pattern, `exercise-audio/<eid>/item-<n>.mp3`); admin generate-audio fast-path loops 5 items, mutates `Detail.Items[i].AudioSource.AssetID`, persists via `UpdateExercise`; rollback removes written files + skips persist on partial failure; Flutter `PoslechItemView.audioAssetId` + `itemsHavePerItemAudio` switch between mini-player-per-item and legacy single-audio; `_PlaybackCoordinator` ensures only 1 item plays at a time. Backward compat: legacy seeds without per-item asset_ids fall back to top-level player. Scope: poslech_1 only; poslech_2/3/4 + Image A-D + vocab V11 TTS deferred | [docs/specs/poslech-per-item-audio.md](docs/specs/poslech-per-item-audio.md) |
| V27 | 2026-05-09 | Poslech 1 image options A-D — CMS-only wire of V11 `MultipleChoiceOption.ImageAssetID`. Extract `poslech-model.ts` from `PoslechFields.tsx` (matches `cteni-model.ts`); extend `P12Item` with `imgA-D`; `initPoslechState`/`buildPoslechDetail` round-trip `options[k].image_asset_id` (omitted when empty for V26 wire compat). UI: per option, sibling text input below `OptionRow` for `image_asset_id`. Validation: published poslech_1 enforces all-or-none per item (0/4 or 4/4); drafts skip. Backend + Flutter unchanged — `MultipleChoiceWidget._allHaveImages` already switches 2×2 image grid. Scope: poslech_1 only; poslech_2 + file upload UX + seed image data deferred | [docs/specs/poslech-1-image-options.md](docs/specs/poslech-1-image-options.md) |
| V28 | 2026-05-10 | Poslech 1 AI image generate — wire `<AiImageButton>` per A-D option in PoslechFields. `onAssetCreated` registers asset via `POST /api/admin/exercises/:id/assets` (cteni_1 pattern), then `makeOptionImagePatcher` sets `state.items[i].imgK` so V27 `buildPoslechDetail` re-emits `image_asset_id`. Disabled when no editingId. existingAssetId flips label "Tạo lại bằng AI". Backend + Flutter unchanged — Replicate Flux Schnell endpoint already shipped via `ai-image-generation` slice. Manual paste still works. Scope: poslech_1 only; poslech_2 + bulk generate + prompt auto-fill deferred | [docs/specs/poslech-1-image-ai-generate.md](docs/specs/poslech-1-image-ai-generate.md) |
| V29 | 2026-05-10 | Poslech 1 manual image upload button — wire "📁 Tải ảnh lên" / "🔄 Đổi ảnh" button per A-D option (mirror cteni_1). `handleP12ImageUpload` async handler does multipart `POST /api/admin/exercises/:id/assets/upload`; `parseUploadResponse` extracts `data.asset.id`; `uploadingKeyFor` encodes active cell as single-flight guard. Inline error per cell. Per option now has 3 asset_id paths: paste text (V27), AI generate (V28), upload local (V29). Backend + Flutter unchanged — endpoint already shipped. Scope: poslech_1 only; drag-drop, multi-file, preview/crop deferred | [docs/specs/poslech-1-image-upload-button.md](docs/specs/poslech-1-image-upload-button.md) |

## Stable contracts

These docs in [`docs/reference/`](docs/reference/README.md) hold the
**always-current** wire shapes / behavior. Update them every time the
contract changes:

- [api-contracts.md](docs/reference/api-contracts.md) — HTTP wire shapes
- [attempt-state-machine.md](docs/reference/attempt-state-machine.md) — attempt lifecycle
- [content-and-attempt-model.md](docs/reference/content-and-attempt-model.md) — exercise type catalog
- [scoring-pipeline.md](docs/reference/scoring-pipeline.md) — LLM + objective scoring
- [infrastructure-baseline.md](docs/reference/infrastructure-baseline.md) — V1 baseline + LLM env table
- [learner-profile-identity.md](docs/reference/learner-profile-identity.md) — V17 user account model
- [i18n-spec.md](docs/reference/i18n-spec.md) — ARB conventions
- [voice-selection-spec.md](docs/reference/voice-selection-spec.md) — TTS routing

## How to update SPEC.md

Add a row to the table above when a slice ships. Don't inline the
content here — that lives in `docs/specs/<slice>.md`. If the slice
changes a stable contract, also update the relevant `docs/reference/`
doc.

The frozen archive [SPEC-archive-v2-to-v18.md](docs/specs/SPEC-archive-v2-to-v18.md)
is **not** updated — it preserves the original inline form for
historical reference.
