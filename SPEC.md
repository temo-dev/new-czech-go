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
