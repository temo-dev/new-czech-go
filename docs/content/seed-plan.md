# Seed Content Plan

## Purpose
Minimum content pack needed to onboard one real Vietnamese learner onto the four oral tasks of the Czech `trvaly pobyt A2` exam. Matches [v1-implementation-plan.md](../plans/v1-implementation-plan.md) Task 11.

## Scope
- Only the four V1 oral tasks: `Uloha 1`, `Uloha 2`, `Uloha 3`, `Uloha 4`.
- At least **one complete content set per task type**, with Vietnamese learner framing.
- Content must be entered through the CMS (`https://cmscz.hadoo.eu` in prod, `make dev-cms` local).

## Target Seed Volume
| Task type | Minimum items | Stretch | Notes |
|-----------|---------------|---------|-------|
| `Uloha 1` | 3 | 10 | Everyday topics: family, work, free time |
| `Uloha 2` | 3 | 8 | Service scenarios: post office, doctor, apartment rental |
| `Uloha 3` | 2 | 5 | 4-image story sequences — requires prompt assets uploaded |
| `Uloha 4` | 2 | 5 | 3-option decision scenarios — optional images per option |

Minimum target is what unblocks the first pilot learner. Stretch target covers one full 14-day plan.

## Content Shape Per Task Type

All items share the `Exercise` base (see [api-contracts.md](../specs/api-contracts.md) and [content-and-attempt-model.md](../specs/content-and-attempt-model.md)):
- `title` — short Czech label
- `short_instruction` — one-line Vietnamese hint
- `learner_instruction` — full Vietnamese coach framing
- `estimated_duration_sec`, `prep_time_sec`, `recording_time_limit_sec`
- `sample_answer_enabled` — set `true` only when a human-reviewed model answer exists

### Uloha 1 — Topic Answer
```json
{
  "exercise_type": "uloha1",
  "prompt": {
    "topic_label": "Moje rodina",
    "question_prompts": [
      "Kolik lidí je ve vaší rodině?",
      "Co dělá váš otec a vaše matka?",
      "Máte sourozence?"
    ]
  }
}
```
- Keep 3 question prompts, all answerable at A2 level.
- Avoid topics that assume Czech cultural context not covered in the exam prep books.

### Uloha 2 — Dialogue Question
```json
{
  "exercise_type": "uloha2",
  "detail": {
    "scenario_title": "Na poště",
    "scenario_prompt": "Chcete poslat balík do Vietnamu. Zeptejte se úředníka.",
    "required_info_slots": [
      { "slot_key": "price",    "label": "Cena", "sample_question": "Kolik to stojí?" },
      { "slot_key": "duration", "label": "Jak dlouho poslat", "sample_question": "Jak dlouho to trvá?" },
      { "slot_key": "papers",   "label": "Doklady", "sample_question": "Potřebuji nějaké papíry?" }
    ],
    "custom_question_hint": "Můžete zeptat se na pojištění nebo sledování balíku."
  }
}
```
- 3 required slots is the sweet spot — fewer feels trivial, more is hard for A2.
- Provide `sample_question` for each slot to seed rule-based feedback matching.

### Uloha 3 — Story Narration
```json
{
  "exercise_type": "uloha3",
  "detail": {
    "story_title": "Víkend v parku",
    "image_asset_ids": ["asset-1", "asset-2", "asset-3", "asset-4"],
    "narrative_checkpoints": [
      "Rodina jde do parku.",
      "Děti hrají s míčem.",
      "Začne pršet.",
      "Jdou domů."
    ],
    "grammar_focus": ["minulý čas", "spojky nejdřív/pak/nakonec"]
  }
}
```
- Upload 4 images via CMS asset upload first, then reference `asset-id`s.
- Keep `narrative_checkpoints` parallel to the image order — used for rule-based feedback coverage.

### Uloha 4 — Choice + Reasoning
```json
{
  "exercise_type": "uloha4",
  "detail": {
    "scenario_prompt": "Máte víkend volno. Kam jedete?",
    "options": [
      { "option_key": "a", "label": "Do hor",    "description": "Lyžovat nebo turistika." },
      { "option_key": "b", "label": "K moři",    "description": "Teplé počasí a pláž." },
      { "option_key": "c", "label": "Zůstat doma","description": "Odpočívat a vařit." }
    ],
    "expected_reasoning_axes": ["počasí", "cena", "preferuje aktivně vs odpočinek"]
  }
}
```
- Always 3 options — matches exam format.
- `expected_reasoning_axes` keeps feedback focused; do not leave empty.

## Entry Workflow
1. Start local CMS: `make dev-cms`.
2. Log in with `CMS_ADMIN_TOKEN` (dev value in `.env`).
3. For each task type, open the matching editor in CMS, fill fields exactly as schema above.
4. For `Uloha 3` and `Uloha 4` with images: upload assets first via the asset tab; copy the asset IDs into the `image_asset_ids` or `options[].image_asset_id` fields.
5. Save. Verify the exercise appears in the learner app by running `make dev-ios` and opening home.

## Acceptance Checklist (pre-pilot)
- [ ] 3 `Uloha 1` exercises live with coach-quality Vietnamese instructions.
- [ ] 3 `Uloha 2` exercises live, each with 3 required slots and sample questions.
- [ ] 2 `Uloha 3` exercises live, each with 4 images uploaded and linked.
- [ ] 2 `Uloha 4` exercises live, each with 3 options and reasoning axes.
- [ ] All items open cleanly in learner app.
- [ ] Each item has been recorded against at least once to confirm the attempt → feedback loop works with the new content.
- [ ] A native Czech speaker reviewed the prompts for naturalness.
- [ ] A Vietnamese-speaking coach reviewed the `learner_instruction` fields for clarity.

## Ongoing Content Ops
- Keep the stretch volume (8–10 per task type) in a backlog doc, add in batches as pilot feedback surfaces weak topics.
- Do not mass-import machine-translated content; every item should pass one native review pass before shipping.
- When a new locale is added (see [i18n-implementation-plan.md](../plans/i18n-implementation-plan.md)), `learner_instruction` is the main field that needs translation.

## Out Of Scope
- Full textbook-style lesson sequencing.
- Automated content generation.
- CMS bulk import tooling.
- Anything beyond the four V1 oral tasks.
