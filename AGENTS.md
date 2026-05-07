# AGENTS.md

Operational guide for working in this repo. For the per-slice history,
see [CHANGELOG.md](CHANGELOG.md).

## Purpose

`A2 Mluvení Sprint` — narrow speaking-prep app for Vietnamese learners
taking the Czech `trvalý pobyt A2` exam.

Stack:
- `Go` backend API
- `Next.js` CMS (admin desk)
- `Flutter` iOS learner app
- docs-first specs in `docs/`

## Product Scope

```
Course (e.g. "Giao tiếp cơ bản", "Đi úřad", "Ôn thi A2")
  └── Module (chủ đề)
       └── Exercise [pool=course, module_id + skill_kind]

MockTest (đề thi)
  └── MockTestSection → Exercise [pool=exam]
```

**Exercise pools**:
- `pool=course` — practice in Course → Module (module_id required)
- `pool=exam` — exam item in MockTest → Section (module_id="")

**Implemented skills** (see CHANGELOG for slice history):

| Skill | Exercise types | Status |
|-------|---------------|--------|
| `noi` (speaking) | Úloha 1–4 | LLM scoring + review artifact + Polly TTS model answer |
| `viet` (writing) | `psani_1_formular`, `psani_2_email`, `psani_3_dictation` | LLM + per-sentence dictation w/ Levenshtein. **V18.1**: dictation OCR via Claude Vision |
| `nghe` (listening) | `poslech_1-5`, `poslech_6` (Ano/Ne) | Polly TTS, objective scorer |
| `doc` (reading) | `cteni_1-5`, `cteni_6` (Ano/Ne) | Objective scorer |
| `tu_vung` | quizcard / matching / fill_blank / choice_word | LLM-assisted authoring |
| `ngu_phap` | matching / fill_blank / choice_word | LLM-assisted authoring |
| `interview` | `interview_conversation`, `interview_choice_explain` | ElevenLabs WS + optional Simli avatar |

**Schema (V8 flat)**: `exercises.module_id` + `exercises.skill_kind`
link directly. `skills` table dropped. `GET /v1/modules/:id/skills`
returns computed `SkillSummary[]` (skill_kind + exercise_count).

**Do not expand into**:
- free-form AI tutoring
- live teacher marketplace
- advanced analytics platform
- pronunciation-first product positioning

## Source Of Truth

Read before any structural change:

| File | Owns |
|------|------|
| `SPEC.md` | Per-slice spec summaries (V2..V21.1) — all decisions frozen |
| `tasks/plan.md` | Per-slice implementation plans with design decisions |
| `tasks/todo.md` | Task checklist with tick state |
| `CHANGELOG.md` | Per-slice history with file changes + final test counts |
| `docs/reference/content-and-attempt-model.md` | Exercise type catalog |
| `docs/reference/api-contracts.md` | Wire shapes |
| `docs/reference/attempt-state-machine.md` | Attempt lifecycle |
| `docs/reference/infrastructure-baseline.md` | V1 baseline + LLM env table |
| `docs/reference/scoring-pipeline.md` | Scoring contract |
| `docs/reference/learner-profile-identity.md` | V17 user account model |
| `docs/reference/i18n-spec.md` | Localization conventions |
| `docs/reference/voice-selection-spec.md` | TTS voice routing |

`docs/reference/` holds **stable, always-current** contracts. Slice-specific
specs (frozen after ship) live under `docs/specs/<slice>.md` plus a paired
`docs/ideas/<slice>.md` (idea note) and optional `docs/plans/<slice>-plan.md`.

`code-review-graph` MCP is wired for this repo — use it for impact
analysis and structural review (see `CLAUDE.md`).

If code and docs disagree, update the code to match the documented
contract unless the human explicitly changes scope.

## Repo Layout

- `backend/` Go API + processing service
- `cms/` Next.js content management app
- `flutter_app/` Flutter learner app
- `docs/` product, planning, and technical specs

## Working Rules

- Build in thin vertical slices; keep the repo working after each
  increment.
- Prefer simple, obvious code over reusable-looking abstractions.
- Treat docs as part of the product. Before starting a major slice,
  make sure idea/spec/plan files exist and are current.
- Make the learner flow clearer before making the infrastructure
  fancier.
- Retry should create a new attempt, never mutate a failed one.

## Commands

Use the root `Makefile`:

| Goal | Command |
|------|---------|
| Install all deps | `make install` |
| Backend dev loop | `make backend-run` / `make backend-build` / `make backend-test` |
| CMS dev loop | `make cms-build` / `make cms-lint` / `cd cms && npm test` |
| Flutter dev loop | `make flutter-analyze` / `make flutter-test` / `make flutter-devices` |
| Local stack | `make dev-backend` / `make dev-cms` / `make dev-ios` / `make dev-stop` |
| Compose stack | `make compose-up` / `make compose-down` / `make compose-logs` |
| Smoke tests | `make smoke-attempt-flow` / `make smoke-course-flow` / `make smoke-exam-flow` / `make smoke-all` |
| Full verify | `make verify` |

For daily local startup: [docs/guides/dev-workflow.md](docs/guides/dev-workflow.md).
For smoke usage and API notes: [docs/guides/smoke-test-guide.md](docs/guides/smoke-test-guide.md).

Per `RTK.md`, prefix shell commands with `rtk` (Makefile already does).

## Backend Conventions

- Monolithic in V1.
- Prefer standard library before adding deps.
- Align request/response payloads with `docs/reference/api-contracts.md`.
- Align learner-facing feedback with
  `docs/reference/content-and-attempt-model.md`.

### LLM prompts and model IDs — single source of truth

All prompts, model defaults, and fallback feedback live in 4 files
under `backend/internal/processing/`. **Do not inline prompt strings,
model IDs, or fallback strings anywhere else.**

| File | Owns |
|------|------|
| `llm_config.go` | API endpoint, version, timeouts, default model IDs (Claude / Replicate / ElevenLabs), `LoadLLMModels()` env loader |
| `llm_prompts.go` | All system prompts (`FeedbackSystemPrompt`, `ReviewSystemPrompt`, `InterviewSystemPrompt`, `VocabGenerationPrompt`, `GrammarGenerationPrompt`, `DictationSystemPrompt`, `DictationOCRSystemPrompt`) |
| `llm_user_prompts.go` | Per-call user-prompt builders + `describeExercisePrompt` + `extract*` exercise-detail helpers |
| `llm_fallbacks.go` | Rule-based feedback when LLM is unavailable |

When adding a new LLM call site:
1. Add `XxxSystemPrompt(...)` to `llm_prompts.go`.
2. Add `buildXxxUserPrompt(...)` to `llm_user_prompts.go`.
3. Add a default model constant + `LLMModels` field + env loader line
   in `llm_config.go`.
4. If there is a fallback path, put the fallback string in
   `llm_fallbacks.go`.
5. The call site holds **only** orchestration code — no prompt string
   literals, no model name literals, no inline VI/EN fallback copy.

Reject in code review:
- String literals containing prompt instructions ("You are…", "Output
  schema:", etc.) outside `llm_prompts.go` / `llm_user_prompts.go`.
- `claude-*` / `eleven_*` / `black-forest-labs/*` literals outside
  `llm_config.go`.
- `os.Getenv("LLM_*" / "ELEVENLABS_*" / "REPLICATE_*")` outside
  `llm_config.go`.

See `docs/reference/infrastructure-baseline.md` § "LLM configuration is
centralized" for the full env-var table.

### Storage

- Postgres for core entities (exercises, attempts, transcripts,
  feedback, mock_tests, full_exam_sessions, vocabulary,
  grammar_rules, content_generation_jobs, exercise_audio,
  exercise_sentence_audio).
- File-based asset storage under `LOCAL_ASSETS_DIR` (or S3 in cloud
  mode). The storage key acts as the asset_id; there is no
  `media_assets` DB table — entities (`exercises`, `vocabulary_items`,
  `courses`, `mock_tests`, `users`) carry the asset_id directly.
- Add columns via `addColumnIfMissing()`
  (`store/postgres_migrate.go`) — checks `information_schema` first so
  RDS-owner-mismatch does not break startup.

## CMS Conventions

- Thin content desk, not a second product.
- Prefer explicit task-specific forms over generic schema builders.
- Prioritize content CRUD + preview over workflow automation.
- Form-field components (`exercise-form/*Fields.tsx`) use **inline VI
  strings**. The `cms/lib/i18n.tsx` React context is scoped to
  sidebar / dashboards / list views.

## Flutter Conventions

- Optimize for the learner flow first.
- Keep UI copy practical and exam-oriented.
- Do not block app progress on perfect audio or pronunciation
  infrastructure.
- For local dev API calls on iOS, preserve the local-network
  allowance in `ios/Runner/Info.plist`.
- Reuse design tokens (`AppColors`, `AppSpacing`, `AppTypography`).
- Every learner-facing string goes through ARB → `AppLocalizations`;
  VI=EN key count must match.

## Infrastructure Conventions

- Stay within the V1 baseline in
  `docs/reference/infrastructure-baseline.md`.
- Do not introduce SQS, EventBridge, microservices, or Kubernetes
  unless the human explicitly changes scope.
- Prefer a long-running Go service over serverless complexity.

## Verification Expectations

Before closing a meaningful change, run:

| Layer | Commands |
|-------|----------|
| Backend | `make backend-build` + `make backend-test` |
| CMS | `make cms-lint` + `make cms-build` + `cd cms && npm test` |
| Flutter | `make flutter-analyze` + `make flutter-test` |
| Full slice | `make verify` |

If a command cannot run because of sandbox or SDK cache restrictions,
say so clearly and report what was verified instead.

## Scope Discipline

Do not mix the following in one change unless the human asks:
- feature work
- refactoring
- infra expansion
- visual redesign
- docs rewrites outside the touched slice

If you notice adjacent cleanup, note it separately rather than
silently expanding scope.

## Current Status

All planned slices V2 → V21 shipped. See [CHANGELOG.md](CHANGELOG.md)
for per-slice file changes, decisions, and final test counts.
`tasks/todo.md` tracks active backlog.

**Latest** (2026-05-07): V21 CEFR Level Progression (A0 → B1) — pivot
from "A2-only sprint" to a level-gated CEFR ladder with a 2-gate
promotion (mastery threshold unlocks a promotion exam, passing the
exam promotes the learner). MVP ships A2 + B1; A0/A1 schema-ready,
content deferred. Server is sole authority for `unlock_state` and
`promotion_unlocked` (client never recomputes gates). Existing users
backfill to A2 via migration 026 (idempotent — guarded by
`current_level='a0' AND placement_taken_at IS NULL`). Adds
`promotion_attempts` ledger, `LevelService` gating math + atomic
promotion hook (`HandlePromotionOutcome`, idempotent on replay),
demo-aware `WithDemoCheck` so taste-test runs skip mastery aggregate.
Backend 636 tests (570 + 66), Flutter 309 (266 + 43), CMS 144 (~123 +
21). `make verify` + `make smoke-promotion-flow` both green.

V19 skill mastery aggregate + `GET /v1/users/me/progress` and V20
Flutter UI ship as in CHANGELOG.

**Remaining backlog (low priority)**:
1. Seed sample content via CMS — at least 1 exercise per type for
   Flutter end-to-end (interview included). Includes B9 reseed:
   demo `cteni_5` exercise listed twice; demo `cteni_6` returned
   with empty `module_id`.
2. Vocab item per-item Polly TTS (deferred from V11).
3. V18.1 pilot: 20×6 photo gold set across 5 learners measuring
   handwriting OCR CER ≤10% before promoting OCR to default mode.

**Next coaching slice (if expanding)**: read
`docs/ideas/attempt-repair-and-shadowing.md` + paired spec/plan first.

## Avoid

- Adding generic plugin systems.
- Abstracting for multiple exam types.
- Building a queue-heavy platform before real load exists.
- Turning mock APIs into permanent hidden debt without updating docs.
- Blurring `learner transcript`, `corrected transcript`, and `model
  answer`.
- Calling the next coaching slice a full pronunciation engine before
  the evidence supports it.
