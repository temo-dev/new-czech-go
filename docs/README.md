# Docs Index

Documentation tree for `A2 Mluvení Sprint`. The repo has shipped V2 →
V21.1; doc surface was systematized in P1..P5 (see CHANGELOG).

For the **fastest** orientation see the root [README](../README.md) and
[AGENTS.md](../AGENTS.md). This index is for finding the doc that fits
the question you're holding.

## How the tree is split

```
docs/
  reference/    Stable, always-current contracts. Update before shipping.
  specs/        Frozen per-slice specs (V2..V21.1). Don't backfill.
  ideas/        Pre-spec one-pagers. Per-slice.
  plans/        Slice-level implementation plans.
  guides/       Dev / deploy / smoke / admin handbooks.
  architecture/ Code shape + refactor map.
  features/     User-facing feature descriptions.
  design/       Design system + HTML mockups (`mockups/`).
  screens/      Per-screen behaviour notes.
  content/      Content authoring guidance.
```

Three sibling sources of truth at repo root:

- [AGENTS.md](../AGENTS.md) — operational rules, scope discipline, conventions
- [CHANGELOG.md](../CHANGELOG.md) — per-slice history with file changes + counts
- [SPEC.md](../SPEC.md) — frozen per-slice spec summaries

## Pick by what you need

### "How does feature X actually work right now?"
→ [`reference/`](reference/README.md)
8 stable contract docs (api-contracts, attempt-state-machine,
content-and-attempt-model, scoring-pipeline, infrastructure-baseline,
learner-profile-identity, i18n-spec, voice-selection-spec).

### "Why was it built this way?"
→ [`specs/`](specs/README.md)
19 frozen slice specs. Don't update — these are historical decisions.

### "What was the original idea?"
→ [`ideas/`](ideas/)
24 one-pagers, one per slice. Predate the spec; useful for context.

### "How do I run / deploy / smoke?"
→ [`guides/`](guides/README.md)
9 handbooks split across daily-dev / verifying / deploying / admin.

### "What does the codebase actually look like today?"
→ [`architecture/current-code-shape.md`](architecture/current-code-shape.md)
Refreshed to V21.1 — graph-backed snapshot of the 419-file repo.

### "How does Uloha 3 work as a learner?"
→ [`features/`](features/README.md)
User-facing feature descriptions — Uloha 1–4, dictation, attempt
lifecycle, CMS exercise management.

### "What's on screen at a given step?"
→ [`screens/`](screens/README.md)
Per-screen behaviour notes for Flutter + CMS surfaces.

### "What does the brand look like?"
→ [`design/`](design/)
Design system tokens + HTML mockups under `design/mockups/`.

## When to update which doc

| Change | Update |
|---|---|
| New contract change | `reference/<doc>.md` |
| New slice ships | `specs/<slice>.md` (frozen) + `CHANGELOG.md` + relevant `reference/` |
| New idea proposed | `ideas/<slice>.md` |
| New plan written | `tasks/<slice>-plan.md` + `tasks/<slice>-todo.md` |
| Dev / deploy command changes | `guides/<topic>.md` |
| Code shape shifts materially | `architecture/current-code-shape.md` |
| New user-facing feature | `features/<feature>.md` |
| Screen behaviour changes | `screens/<surface>-<screen>.md` |
| Design tokens change | `design/system.md` (or `design-system-v1.md`) |

## Code Review Graph

The architecture, feature, and screen docs are intended to stay
informed by `code-review-graph` (MCP wired for this repo — see
[CLAUDE.md](../CLAUDE.md)).

Repo currently has:

- git initialized
- a local graph database at `.code-review-graph/graph.db`
- 419 files / 4634 nodes / 37147 edges (build at commit 55c4b177ffe9)

Use graph-backed review when documenting: file hotspots, flow
concentration, refactor pressure, cross-surface dependencies.
