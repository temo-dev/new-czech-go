# Slice specs (frozen)

Per-slice spec snapshots. Each file describes **what was built and why**
during a particular slice (V8 schema flatten, V14 interview, V18
dictation, V21 CEFR levels, …). Once the slice ships, these specs are
**frozen** — they are not updated to reflect later changes.

For the **current** behaviour of any contract, see
[`docs/reference/`](../reference/README.md) instead. That is where each
contract's always-up-to-date description lives.

## Why both?

- `docs/reference/` answers "how does the system work *now*?"
- `docs/specs/` answers "how did we decide to build it that way?"
- `docs/ideas/` answers "what did we propose before we wrote the spec?"

Reading order for a new slice:
`docs/ideas/<slice>.md` → `docs/specs/<slice>.md` → eventual fold-in
to `docs/reference/`.

## Index

```
admin-user-management.md            attempt-repair-and-shadowing.md   ← proposal, not yet built
ano-ne-exercise-type.md             cefr-level-progression.md         ← V21 (UX paired below)
cefr-level-progression-ux.md        cefr-ui-wireup.md                 ← V21.3
deck-session-vocab-grammar.md       dictation-exercise.md
dictation-ocr.md                    exam-result-flow-implementation.md
exam-result-flow-redesign.md        exercise-dashboard-upgrade.md
exercise-dashboard-user-flow.md     iap-wire-real.md                  ← V25
interview-first-turn-fix.md         media-enrichment.md
poslech-1-image-ai-generate.md      poslech-1-image-options.md
poslech-1-image-upload-button.md    poslech-per-item-audio.md         ← V26
provider-aware-audio-replay.md      schema-flatten-skills.md
self-serve-learner-spec.md          skill-mastery-progress.md
v2-ui-spec.md                       v22-cms-catch-up.md
v23-exercise-authoring-polish.md    v24-doc-draft-generator.md
v36-interview-in-mock-exam.md       v37-vocab-item-polly-tts.md
v39-exam-flat-sort-player.md        ← planned 2026-05-12
```

## Update policy

Don't backfill changes into a frozen slice spec. If a later slice
amends a contract documented here, the amend goes into:

1. The new slice's own spec, *and*
2. The relevant `docs/reference/` doc (if a stable contract is involved).

The frozen slice spec stays as-is — it is a historical record, not a
living document.
