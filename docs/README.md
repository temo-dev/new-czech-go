# Docs Index

## Purpose
This is the landing page for the project documentation of `A2 Mluveni Sprint`.

Use this index when you want to orient quickly in the docs tree and choose the right level of detail:
- product direction
- implementation plan
- technical contracts
- architecture shape
- feature-level behavior
- screen-level behavior

## Recommended Reading Order

### 1. Product Direction
Start here if you want to understand what we are building and why.

- [Idea One-Pager](/Users/daniel.dev/Desktop/czech-go-system/docs/ideas/a2-mluveni-sprint.md)
- [Attempt Repair And Shadowing](/Users/daniel.dev/Desktop/czech-go-system/docs/ideas/attempt-repair-and-shadowing.md)

### 2. Delivery Plan
Read this next if you want the execution order and scope breakdown.

- [Implementation Plan](/Users/daniel.dev/Desktop/czech-go-system/docs/plans/v1-implementation-plan.md)
- [Attempt Repair And Shadowing Plan](/Users/daniel.dev/Desktop/czech-go-system/docs/plans/attempt-repair-and-shadowing-plan.md)

### 3. Technical Source Of Truth
Read these when you need stable implementation contracts.

- [Content And Attempt Model](/Users/daniel.dev/Desktop/czech-go-system/docs/specs/content-and-attempt-model.md)
- [API Contracts](/Users/daniel.dev/Desktop/czech-go-system/docs/specs/api-contracts.md)
- [Attempt State Machine](/Users/daniel.dev/Desktop/czech-go-system/docs/specs/attempt-state-machine.md)
- [Infrastructure Baseline](/Users/daniel.dev/Desktop/czech-go-system/docs/specs/infrastructure-baseline.md)
- [Scoring Pipeline](/Users/daniel.dev/Desktop/czech-go-system/docs/specs/scoring-pipeline.md)

### 3b. Build-Ready Extension Specs
Read these when you are preparing the next major feature slice but do not want to blur today’s shipped contracts.

- [Attempt Repair And Shadowing Spec](/Users/daniel.dev/Desktop/czech-go-system/docs/specs/attempt-repair-and-shadowing.md)

### 4. Architecture Layer
Read these when you want a graph-backed view of the codebase and refactor priorities.

- [Architecture Index](/Users/daniel.dev/Desktop/czech-go-system/docs/architecture/README.md)
- [Current Code Shape](/Users/daniel.dev/Desktop/czech-go-system/docs/architecture/current-code-shape.md)
- [Refactor Map V1](/Users/daniel.dev/Desktop/czech-go-system/docs/architecture/refactor-map-v1.md)

### 5. Design Layer
Read this when you want the shared visual language for Flutter and CMS.

- [Design System V1](/Users/daniel.dev/Desktop/czech-go-system/docs/design/design-system-v1.md)

### 6. Feature Layer
Read these when you want a feature-oriented view across backend, CMS, and Flutter.

- [Feature Docs Index](/Users/daniel.dev/Desktop/czech-go-system/docs/features/README.md)
- [Uloha 1 Practice](/Users/daniel.dev/Desktop/czech-go-system/docs/features/uloha-1-practice.md)
- [CMS Exercise Management](/Users/daniel.dev/Desktop/czech-go-system/docs/features/cms-exercise-management.md)
- [Attempt Lifecycle And Feedback](/Users/daniel.dev/Desktop/czech-go-system/docs/features/attempt-lifecycle-and-feedback.md)

### 7. Screen Layer
Read these when you want UI-level behavior for Flutter and CMS.

- [Screen Docs Index](/Users/daniel.dev/Desktop/czech-go-system/docs/screens/README.md)
- [Flutter Learner Shell](/Users/daniel.dev/Desktop/czech-go-system/docs/screens/flutter-learner-shell.md)
- [Flutter Exercise Practice](/Users/daniel.dev/Desktop/czech-go-system/docs/screens/flutter-exercise-practice.md)
- [CMS Exercise Dashboard](/Users/daniel.dev/Desktop/czech-go-system/docs/screens/cms-exercise-dashboard.md)

### 8. Dev Workflow
Read this when you want the fastest repeatable way to run the local stack.

- [Dev Workflow](/Users/daniel.dev/Desktop/czech-go-system/docs/dev-workflow.md)
- [CI And Release](/Users/daniel.dev/Desktop/czech-go-system/docs/ci-release.md)

## Docs Tree
- `docs/ideas/` product direction and one-pagers
- `docs/plans/` implementation plans and task breakdowns
- `docs/specs/` stable technical contracts
- `docs/architecture/` graph-backed code shape and refactor guidance
- `docs/design/` UI foundation and shared visual rules
- `docs/features/` feature-level behavior and status
- `docs/screens/` concrete screen-level behavior
- `docs/dev-workflow.md` daily startup and verification flow

## Which Doc To Update

### Update `ideas`
When product direction or scope changes materially.

### Update `plans`
When task order, delivery scope, or sequencing changes.

### Update `specs`
When contracts or technical source of truth change.

### Update `architecture`
When code shape or refactor guidance changes materially.

### Update `design`
When shared visual tokens, UI principles, or cross-surface component rules change.

### Update `features`
When a feature becomes real, changes behavior, or crosses new surfaces.

### Update `screens`
When a Flutter or CMS screen changes meaningfully in state, actions, or API usage.

### Update `dev-workflow`
When the recommended startup order, local URLs, or daily dev commands change.

## Code Review Graph
The architecture, feature, and screen docs are intended to stay informed by `code-review-graph`.

The repo currently has:
- git initialized
- a local graph database at `.code-review-graph/graph.db`

Use graph-backed review when documenting:
- file hotspots
- flow concentration
- refactor pressure
- cross-surface dependencies
