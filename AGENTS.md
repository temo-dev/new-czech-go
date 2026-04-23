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

When working on the next major learner-coaching slice, also read:
- `docs/ideas/attempt-repair-and-shadowing.md`
- `docs/specs/attempt-repair-and-shadowing.md`
- `docs/plans/attempt-repair-and-shadowing-plan.md`

When working on the i18n slice, also read:
- `docs/ideas/i18n-multi-language-support.md`
- `docs/specs/i18n-spec.md`
- `docs/plans/i18n-implementation-plan.md`

`code-review-graph` is available for this repo and should be used when documenting flows, reviewing structural changes, or checking file/entity relationships.

If code and docs disagree, prefer updating code to match the documented V1 contract unless the human explicitly changes scope.

## Repo Layout
- `backend/` Go API and processing service
- `cms/` Next.js content management app
- `flutter_app/` Flutter learner app
- `docs/` product, planning, and technical specs

## Current Implementation Status
The repo is now beyond the first mock-only slice.

The implemented V1 foundation currently includes:
- Go backend with real attempt upload flow, learner polling, transcript provenance, and task-aware feedback for all four oral task types
- opt-in `Postgres` persistence for exercises, attempts, transcripts, and feedback
- opt-in `S3 + Amazon Transcribe` path that has already been verified end-to-end on production
- opt-in `LLMFeedbackProvider` backed by Claude (`LLM_PROVIDER=claude`, `ANTHROPIC_API_KEY`); falls back to rule-based feedback automatically on error or when unset
- opt-in `LLMReviewProvider` that generates corrected transcript + model answer per exercise + learner response (`LLM_REVIEW_PROVIDER`, falls back to `LLM_PROVIDER` then to echo)
- opt-in `Amazon Polly` TTS for model-answer audio in review artifacts (`TTS_PROVIDER=amazon_polly`)
- CMS CRUD for all four oral task types
- CMS prompt-asset upload and preview for `Uloha 3` and `Uloha 4`
- Flutter learner flow for all four oral tasks: recording with split Stop/Analyze, dedicated `AnalysisScreen` spinner, result rendering, recent attempts, audio replay, review artifact display with TTS audio playback
- Flutter i18n (Vietnamese + English) via ARB + generated `AppLocalizations`, with in-app locale selector persisted via `SharedPreferences`
- Flutter bottom navigation with separate `Home` and `History` tabs

Important current limitations:
- local strict real-transcript mode still depends on valid AWS credentials plus `transcribe:*` IAM on the active local identity
- completed-attempt audio replay is strongest for backend-owned local files; provider-aware replay for cloud-only audio still needs more work
- task-aware feedback for `Uloha 3` and `Uloha 4` is not as refined as `Uloha 1` and `Uloha 2`

## Working Rules
- Build in thin vertical slices.
- Keep the repo working after every increment.
- Prefer simple, obvious code over reusable-looking abstractions.
- Treat docs as part of the product, not optional garnish.
- When in doubt, make the learner flow clearer before making the infrastructure fancier.
- Before starting a new major slice, make sure the matching idea/spec/plan docs exist and are current.

## Commands
Use the root `Makefile` when possible:
- `make install`
- `make backend-run`
- `make backend-build`
- `make backend-test`
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
- `make compose-up`
- `make compose-down`
- `make compose-logs`
- `make smoke-attempt-flow`
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
1. add provider-aware replay for cloud-only stored audio artifacts
2. refine `Uloha 3` and `Uloha 4` task-aware feedback to match `Uloha 1` / `Uloha 2` quality
3. tighten LLM prompt and schema coverage for shadowing on `Uloha 3` (story ordering) and `Uloha 4` (choice reasoning)
4. expand i18n coverage to any remaining untranslated strings and add the next learner-locale if scope changes

## Avoid
- adding generic plugin systems
- abstracting for multiple exam types
- building a queue-heavy platform before real load exists
- turning mock APIs into permanent hidden debt without updating the docs
- blurring `learner transcript`, `corrected transcript`, and `model answer`
- calling the next coaching slice a full pronunciation engine before the evidence supports that claim
