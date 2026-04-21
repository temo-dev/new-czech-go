# AGENTS.md

## Purpose
This repository is for `A2 Mluveni Sprint`, a narrow speaking-prep app for Vietnamese learners taking the Czech `trvaly pobyt A2` exam.

The current stack is:
- `Go` backend API
- `Next.js` CMS
- `Flutter` iOS learner app
- docs-first product and architecture specs in `docs/`

## Product Scope
Keep the product narrow.

V1 is only for the oral exam flow:
- `Uloha 1`: topic answers
- `Uloha 2`: dialogue questions
- `Uloha 3`: story narration
- `Uloha 4`: choice and reasoning

Do not expand V1 into:
- full A2 exam prep
- free-form AI tutoring
- live teacher marketplace
- advanced analytics platform
- pronunciation-first product positioning

## Source Of Truth
Read these first before making structural changes:
- `docs/ideas/a2-mluveni-sprint.md`
- `docs/plans/v1-implementation-plan.md`
- `docs/specs/content-and-attempt-model.md`
- `docs/specs/api-contracts.md`
- `docs/specs/attempt-state-machine.md`
- `docs/specs/infrastructure-baseline.md`
- `docs/specs/scoring-pipeline.md`

`code-review-graph` is available for this repo and should be used when documenting flows, reviewing structural changes, or checking file/entity relationships.

If code and docs disagree, prefer updating code to match the documented V1 contract unless the human explicitly changes scope.

## Repo Layout
- `backend/` Go API and processing service
- `cms/` Next.js content management app
- `flutter_app/` Flutter learner app
- `docs/` product, planning, and technical specs

## Current Implementation Status
The repo currently contains a first vertical slice:
- in-memory Go backend with mock auth, content, attempts, and feedback
- CMS screen that lists and creates `Uloha 1` exercises
- Flutter learner shell that logs in, opens an exercise, simulates an attempt, polls result state, and renders transcript plus feedback

This is intentionally a contract-first slice. It does **not** yet include:
- real audio recording upload to S3
- real Postgres persistence
- real Amazon Transcribe integration
- real Amazon Polly generation pipeline
- production scoring workers

## Working Rules
- Build in thin vertical slices.
- Keep the repo working after every increment.
- Prefer simple, obvious code over reusable-looking abstractions.
- Treat docs as part of the product, not optional garnish.
- When in doubt, make the learner flow clearer before making the infrastructure fancier.

## Commands
Use the root `Makefile` when possible:
- `make install`
- `make backend-run`
- `make backend-build`
- `make cms-build`
- `make cms-lint`
- `make flutter-analyze`
- `make flutter-test`
- `make flutter-devices`
- `make dev-backend`
- `make dev-cms`
- `make dev-ios`
- `make dev-check`
- `make dev-stop-backend`
- `make dev-stop-cms`
- `make dev-stop`
- `make verify`

For daily local startup, prefer [docs/dev-workflow.md](/Users/daniel.dev/Desktop/czech-go-system/docs/dev-workflow.md).

Per the local repo rule in `RTK.md`, shell commands should be prefixed with `rtk`. The `Makefile` already does this.

## Backend Conventions
- Keep the backend monolithic in V1.
- Prefer standard library packages before adding dependencies.
- Keep request and response payloads aligned with `docs/specs/api-contracts.md`.
- Keep learner-facing feedback aligned with `docs/specs/content-and-attempt-model.md`.
- Retry should create a new attempt, not mutate a failed one.

## CMS Conventions
- The CMS is a thin content desk, not a second product.
- Prefer explicit task-specific forms over generic schema builders.
- Prioritize content CRUD and preview over workflow automation.

## Flutter Conventions
- Optimize for the learner flow first.
- Keep UI copy practical and exam-oriented.
- Do not block app progress on perfect audio or pronunciation infrastructure.
- If using local dev API calls on iOS, preserve the local-network allowance in `ios/Runner/Info.plist`.

## Infrastructure Conventions
- Stay within the V1 baseline in `docs/specs/infrastructure-baseline.md`.
- Do not introduce `SQS`, `EventBridge`, microservices, or Kubernetes unless the human explicitly changes scope.
- Prefer a long-running Go service over serverless complexity for V1.

## Verification Expectations
Before closing a meaningful code change, run the relevant checks:
- backend: `make backend-build` and `make backend-test`
- CMS: `make cms-lint` and `make cms-build`
- Flutter: `make flutter-analyze` and `make flutter-test`
- full slice: `make verify`

If a command cannot run because of sandbox or SDK cache restrictions, say so clearly and report what was verified instead.

## Scope Discipline
Do not mix these in one change unless the human asks:
- feature work
- refactoring
- infra expansion
- visual redesign
- docs rewrites outside the touched slice

If you notice adjacent cleanup, note it separately instead of silently expanding scope.

## Good Next Steps
Preferred sequence from the current repo state:
1. replace mock attempt progression with real recording/upload flow
2. persist exercises and attempts in Postgres
3. connect transcription to Amazon Transcribe
4. move scoring from mock payloads to the real scoring pipeline
5. expand from `Uloha 1` to the remaining oral tasks

## Avoid
- adding generic plugin systems
- abstracting for multiple exam types
- building a queue-heavy platform before real load exists
- turning mock APIs into permanent hidden debt without updating the docs
