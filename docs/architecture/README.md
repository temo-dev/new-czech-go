# Architecture Docs

## Purpose
This folder indexes architecture-level documents for `A2 Mluveni Sprint`.

These docs sit above feature and screen docs. They answer questions like:
- what shape the codebase has right now
- where structural pressure is building
- what should be refactored next
- which architectural constraints V1 is intentionally keeping

## Reading Order

### 1. Current Snapshot
- [Current Code Shape](/Users/daniel.dev/Desktop/czech-go-system/docs/architecture/current-code-shape.md)

Read this first when you want a graph-backed snapshot of the codebase as it exists today.

### 2. Refactor Sequence
- [Refactor Map V1](/Users/daniel.dev/Desktop/czech-go-system/docs/architecture/refactor-map-v1.md)

Read this when you want to know:
- what not to refactor yet
- what to split next
- what should trigger each refactor
- how to refactor incrementally without stalling product work

## Related Docs

### Product And Planning
- [Idea One-Pager](/Users/daniel.dev/Desktop/czech-go-system/docs/ideas/a2-mluveni-sprint.md)
- [Implementation Plan](/Users/daniel.dev/Desktop/czech-go-system/docs/plans/v1-implementation-plan.md)

### Technical Source Of Truth
- [Content And Attempt Model](/Users/daniel.dev/Desktop/czech-go-system/docs/specs/content-and-attempt-model.md)
- [API Contracts](/Users/daniel.dev/Desktop/czech-go-system/docs/specs/api-contracts.md)
- [Attempt State Machine](/Users/daniel.dev/Desktop/czech-go-system/docs/specs/attempt-state-machine.md)
- [Infrastructure Baseline](/Users/daniel.dev/Desktop/czech-go-system/docs/specs/infrastructure-baseline.md)
- [Scoring Pipeline](/Users/daniel.dev/Desktop/czech-go-system/docs/specs/scoring-pipeline.md)

### Feature And UI Layers
- [Feature Docs](/Users/daniel.dev/Desktop/czech-go-system/docs/features/README.md)
- [Screen Docs](/Users/daniel.dev/Desktop/czech-go-system/docs/screens/README.md)

## When To Update These Docs
Update architecture docs when:
- the current code shape materially changes
- a large file is split in a meaningful way
- a mock boundary becomes a real integration boundary
- the recommended refactor order changes

Do not update them for:
- small UI tweaks
- internal renames
- refactors that do not change structural responsibilities

## Code Review Graph
These docs are intended to stay informed by `code-review-graph`.

Use graph-backed review especially when:
- a file is becoming a hotspot
- a refactor is being considered
- a feature starts touching multiple surfaces

The repo currently has a local graph database at:
- `.code-review-graph/graph.db`
