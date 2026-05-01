# Ano/Ne Exercise Type (cteni_6 / poslech_6)

## Problem Statement

How might we add a True/False ("Ano/Ne") statement-verification exercise to both Reading and Listening skills, matching the format used in Modelový test A2 NPI?

## Recommended Direction

Add two new exercise types — `cteni_6` and `poslech_6` — that present a real-world document (schedule, notice, sign) alongside 1–5 statements. Learners select **ANO** or **NE** for each statement. Scoring is objective (binary per statement), with admin-configurable `max_points` per exercise.

This is the simplest possible extension: same `objective_scorer` pipeline, same `submit-answers` endpoint, same `ObjectiveResultCard` in Flutter. The only new surface is `AnoNeWidget` — a dedicated row per statement with two buttons.

## Data Model

```json
{
  "exercise_type": "cteni_6",
  "passage": "Vlašim\nMěstský úřad – úřední hodiny\nPondělí 8:00–11:30...",
  "questions": [
    { "statement": "Na úřadu města je zavřeno ve středu." },
    { "statement": "Ve čtvrtek je polední přestávka do jedné hodiny." },
    { "statement": "V úterý úřední hodiny končí ve dvě hodiny odpoledne." }
  ],
  "correct_answers": ["ne", "ne", "ano"],
  "max_points": 3
}
```

For `poslech_6`: same shape, but `passage` is the TTS script — Polly generates audio, learner hears the document read aloud then answers statements.

## Key Assumptions to Validate

- [ ] `objective_scorer` handles `correct_answers = ["ano","ne",...]` — case-insensitive string match already works
- [ ] Polly reading a formatted schedule (column layout) sounds natural enough for poslech_6 — may need to reformat as prose before TTS
- [ ] `AnoNeWidget` fits cleanly inside `ListeningExerciseScreen` and `ReadingExerciseScreen` without layout breakage

## MVP Scope

**In:**
- `cteni_6` and `poslech_6` exercise types
- CMS: passage textarea + statement repeater (1–5 rows) + correct_answer toggle (ANO/NE) per row + max_points field
- Backend: `EXERCISE_TYPE_CTENI_6`, `EXERCISE_TYPE_POSLECH_6` constants; `buildCteni6Layout` / `buildPoslech6Layout` in Flutter parse functions
- Flutter: `AnoNeWidget` (statement text + ANO/NE button pair, highlight selected, green/red after submit)
- `poslech_6`: reuse Polly audio generation via `generate-audio` admin endpoint

**Out:**
- Image per statement (can be added later via existing `image_asset_id` infrastructure)
- Per-statement feedback text (binary scoring is sufficient)
- Partially-correct scoring (each statement is 0 or 1 point)

## Not Doing (and Why)

- **Reusing MultipleChoiceWidget** — the ANO/NE button pair is visually distinct from A/B/C/D choice lists; a dedicated widget keeps the UI honest to the exam format
- **Single shared `ano_ne` type** — keeping `cteni_6`/`poslech_6` naming stays consistent with the existing cteni_1–5/poslech_1–5 series and makes CMS filtering straightforward
- **Fixed 3 statements** — variable 1–5 gives content authors flexibility without adding complexity to the scorer

## Open Questions

- Should `poslech_6` passage be stored as plain prose (for clean TTS) separately from a formatted display version shown to admins in CMS?
- Does the ObjectiveResultCard need a "passage reveal" toggle for cteni_6 result review, similar to `_PassageSection` in cteni_1–4?
