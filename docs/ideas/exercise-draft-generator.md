# Exercise Draft Generator

**Idea decided**: 2026-05-08
**Owner**: TBD
**Status**: Pre-spec — pending Czech-quality validation

## Problem Statement

How might we let admin input `(topic, grammar_point, level)` and have the
AI draft a full exercise of a chosen `skill_kind + exercise_type`, so the
admin only reviews/edits the form instead of authoring from scratch?

## Recommended Direction

**Per-type generator, ship `doc` (cteni 1-6) first.**

Reuse the existing LLM-authoring pattern already proven for `tu_vung` and
`ngu_phap` (`VocabGenerationPrompt`, `GrammarGenerationPrompt` in
`backend/internal/processing/llm_prompts.go`). Extend with one new system
prompt per exercise_type, dispatched by `(skill_kind, exercise_type)`.

Sync flow: CMS form has a "Generate draft" button → backend calls Claude
with a strict JSON schema for that exercise type → response fills the
`exercise-form/*Fields.tsx` fields → admin edits and saves as a normal
exercise. No new persistence layer; `content_generation_jobs` is overkill
for sync per-exercise generation.

Why `doc` first:
- highest authoring ROI (long passage + 4-6 questions = 30+ min/exercise)
- self-contained — no audio pipeline coupling
- 6 exercise_types under one skill = good test of schema dispatch
- if Czech-quality assumption (A1) fails here, we kill the project before
  building TTS coupling for `nghe` or `viet`

`viet` ships next (psani_1_formular, psani_2_email — skip dictation; needs
audio gen). `nghe` after that (text + Polly pipeline). `noi` deprioritized
— prompt is 1-2 sentences, ROI doesn't justify the work.

## Key Assumptions to Validate

- [ ] **A1 — Czech A2/B1 quality.** Claude Sonnet 4.6 produces natural,
      grammatically correct Czech (vid, pády, A2 vocab range). Test:
      generate 10 `cteni_1` drafts pre-build, have a Czech-native or
      teacher rate quality. Kill switch if <70% usable.
- [ ] **A2 — Grammar input specificity.** Admin can describe grammar
      precisely enough for generation. Test: prototype free-text vs
      grammar-point-picker (fed from existing `grammar_rules` table) on
      5 admin authoring sessions.
- [ ] **A3 — JSON schema reliability.** Claude returns valid exercise JSON
      ≥95% of the time across 6 cteni types. Test: 50 calls × 6 types
      with `tool_use` mode + schema. Reject + retry on invalid.
- [ ] **A4 — Topic/grammar matching.** Generated passage actually uses
      the requested grammar point. Test: post-gen, second LLM call
      verifies "does this passage demonstrate {grammar}? List occurrences."
      Threshold ≥3 uses or regenerate.

## MVP Scope

**In:**
- `POST /v1/admin/exercises/generate-draft` — body: `{skill_kind: "doc",
  exercise_type, topic, grammar_point_id, level}`. Returns draft JSON
  matching the exercise_type schema.
- One new system prompt `ReadingGenerationPrompt` in `llm_prompts.go`
  with 6 exercise_type templates inside.
- One new user prompt builder `buildReadingGenerationUserPrompt` in
  `llm_user_prompts.go`.
- `LLMReadingDraftModel` constant + env loader in `llm_config.go`.
- CMS exercise-form: "Generate draft" button visible only when
  `skill_kind=doc`. Loading state + error toast. On success → fill form
  fields client-side, no auto-save.
- Schema validation backend-side (reject malformed JSON, return 422).
- `exercises.created_by_llm boolean` column (default false) for analytics.
- Admin still hits "Save" manually — no auto-publish.

**Out (V1):**
- Bulk module generator (B variant)
- Two-stage gated flow (C variant)
- `nghe`, `viet`, `noi` generators
- Audio generation as part of draft
- Variant picker (3 drafts → choose 1)
- Async via `content_generation_jobs`
- Auto grammar/level second-pass check (A4 validation is offline test only)

## Not Doing (and Why)

- **Bulk module generator** — drift risk across 7 skills + multi-call
  cost. Ship per-type first, prove quality, then consider bulk.
- **`noi` generator** — Úloha 1-4 prompts are 1-2 sentences. Admin
  authors in 5 min. ROI doesn't justify a new prompt + schema.
- **Variant picker (3 drafts)** — 3× token cost for marginal value.
  Admin already edits inline; better to make 1 draft good than offer 3
  mediocre ones.
- **Async job queue** — `content_generation_jobs` is overkill for a
  single sync request returning in <10s. Add later if batch generation
  ships.
- **Free-text grammar input** — too vague ("past tense" generates wrong
  Czech). Use a grammar_point picker fed from existing `grammar_rules`.
- **Auto-publish AI drafts** — every draft must pass human review.
  Non-negotiable for a learner-facing exam-prep app.
- **Schema-less prompting** — without `tool_use` + JSON schema, output
  reliability tanks. Don't even try free-form text → parse.

## Open Questions

- Does Czech-native review of 10 sample drafts pass the A1 quality bar?
  (Blocker — run before sprint kickoff.)
- Should `grammar_point_id` reference existing `grammar_rules` rows, or
  allow free text + map server-side? (Probably former — UX hinges on it.)
- Reading-passage length policy per cteni type? (cteni_1 ≈ 150 words,
  cteni_6 Ano/Ne ≈ 80 words. Lock in spec.)
- Where does "draft origin" surface in CMS list view? (Filter chip
  "AI-drafted" + reviewed-by-human badge?)
- Cost ceiling per generation call? (Sonnet 4.6 ~150 input + 600 output
  tokens ≈ $0.012/draft. Acceptable.)
