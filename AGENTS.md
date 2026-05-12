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

## Documentation Convention

**Strict.** Don't sprawl docs. Every doc has exactly one home. Don't
invent new directories. Don't leave drafts at `docs/` root or repo
root.

### Doc tree (canonical)

```
ROOT (5 files only — don't add more):
  README.md           project overview + quick start
  AGENTS.md           this file — operational contract
  CLAUDE.md           AI assistant config (imports AGENTS.md)
  CHANGELOG.md        per-slice history (newest first)
  SPEC.md             slice digest table (NOT inline content)

docs/
  reference/   ←  STABLE always-current contracts. Update on every
                  contract change. Live forever.
  specs/       ←  FROZEN per-slice specs. Don't backfill after ship.
  ideas/       ←  Pre-spec one-pagers. Per-slice.
  plans/       ←  Slice-level implementation briefs (legacy; new
                  slices use `tasks/<slice>-plan.md` instead).
  guides/      ←  Dev / deploy / smoke / admin handbooks. Always-current.
  architecture/ ← Code shape + refactor map. Refresh per major slice.
  features/    ←  User-facing feature descriptions.
  design/      ←  Design system + `mockups/` HTML.
  screens/     ←  Per-screen behaviour notes.
  content/     ←  Content authoring guidance.

tasks/
  plan.md             index pointing at per-slice plan files
  todo.md             active backlog index
  <slice>-plan.md     per-slice plan with phases A..E
  <slice>-todo.md     per-slice task checklist
  *-archive-*.md      frozen mega-files preserved from earlier slices
                      (e.g. plan-archive-v2-to-v20.md). Don't update.
```

Archive files are allowed in any subdirectory **as long as they sit
next to the doc they're archiving** (e.g.
`docs/specs/SPEC-archive-v2-to-v18.md` next to slice specs,
`tasks/plan-archive-v2-to-v20.md` next to `plan.md`). Naming pattern
is always `<original-name>-archive-<version-range>.md`.

### Where does it go? (decision table)

| What you're writing | Goes in |
|---|---|
| New always-current contract (api shape, env var, lifecycle, etc) | `docs/reference/<topic>.md` |
| New slice's spec (frozen on ship) | `docs/specs/<slice>.md` |
| Pre-spec idea / one-pager | `docs/ideas/<slice>.md` |
| Slice plan + tasks | `tasks/<slice>-plan.md` + `tasks/<slice>-todo.md` |
| Dev / deploy / smoke / admin guide | `docs/guides/<topic>.md` |
| Code shape snapshot | `docs/architecture/current-code-shape.md` |
| User-facing feature description | `docs/features/<feature>.md` |
| Per-screen behaviour | `docs/screens/<surface>-<screen>.md` |
| Design tokens / mockups | `docs/design/*.md` or `docs/design/mockups/*.html` |
| Slice summary row | `SPEC.md` table + `CHANGELOG.md` entry |

### Slice doc lifecycle

Each slice produces docs in this order. Don't skip steps; don't
write docs out of order:

1. **Idea** → `docs/ideas/<slice>.md` (one-pager, decided date stamped)
2. **Spec** → `docs/specs/<slice>.md` (frozen on ship; can have a
   paired `<slice>-ux.md`)
3. **Plan** → `tasks/<slice>-plan.md` + `tasks/<slice>-todo.md`
4. **Build** → commits per task; CHANGELOG entry on ship
5. **Fold stable contracts** → if the slice changes a contract that
   spans slices (api shape, attempt lifecycle, infra env, etc),
   update the relevant `docs/reference/<topic>.md`. **Do not** wait
   for a future slice to do this.
6. **Add summary rows** → one line in `SPEC.md` table; full entry in
   `CHANGELOG.md`.

### Strict rules

- ❌ **No new top-level files.** Five exist; don't add a sixth. If
  you need a new doc, it goes inside `docs/`.
- ❌ **No drafts at `docs/` root.** Pick the right subdirectory or
  don't write the doc.
- ❌ **No new top-level directories under `docs/`.** Use one of the
  existing nine.
- ❌ **No backfilling frozen slice specs.** When V22 changes V21
  behaviour, the V22 spec captures the change + the relevant
  `docs/reference/` doc gets updated. The V21 slice spec stays as-is.
- ❌ **No inlining V2..V21 spec content into `SPEC.md`.** That's
  what `docs/specs/SPEC-archive-v2-to-v18.md` exists for. SPEC.md is a digest
  table.
- ❌ **No ephemeral notes (next-session.md, scratch.md, todo-temp.md).**
  Use `tasks/todo.md` for in-flight items.
- ❌ **No duplicate dirs.** `design/` ≠ `designs/` ≠ `Design/`. Pick
  one — it's `design/`.
- ❌ **No absolute paths in markdown links.** Use relative
  (`../docs/...`) so the repo is portable.
- ❌ **No "doc-only" feature work.** Don't write a spec without an
  idea note. Don't ship code without a CHANGELOG entry.

### When in doubt

- "Is this contract going to outlive the slice?" → `docs/reference/`
- "Is this a snapshot of how V21 was decided?" → `docs/specs/`
- "Is this a one-pager that predates the spec?" → `docs/ideas/`
- "Is this a how-to for running / deploying?" → `docs/guides/`
- "Will I keep updating this every slice?" → `docs/reference/` or
  `docs/architecture/`
- "Is this a frozen historical record?" → `docs/specs/` or one of
  the `*-archive-*.md` files at the appropriate level

If still unsure, check `docs/README.md` § "Pick by what you need" —
it routes by question.

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

All planned slices V2 → V38 shipped. See [CHANGELOG.md](CHANGELOG.md)
for per-slice file changes, decisions, and final test counts.
`tasks/todo.md` tracks active backlog.

**Latest** (2026-05-12): V38 — CMS hotfix. (1) Unlock `poslech_1..5`
fixed shapes: `poslech-model.ts` respects raw collection length;
`PoslechFields.tsx` exposes per-row `Xóa` + list-level `+ Thêm…`
buttons (poslech_3/4 keep ≥2 options; removing an option clears item
answers that point at it; option keys generate A..Z). Defaults stay
5/7/6/5 to match A2 exam template. (2) `validation.ts` skips the
`Phải chọn Module.` common check when `payload.pool === 'exam'`
(matches form's conditional render). CMS only — backend already
iterates collections dynamically. CMS tests 308 → 311 (+3 regression).
`make cms-{lint,build}` + `npm test` green.

**Previous** (2026-05-07): V21.2 — exam-flow runtime hotfixes from MobAI
test on iPhone 17 Pro Max simulator. Fixes 1 Critical + 2 Important +
adds admin escape hatch:

- **Critical** — free-tier gate `checkAndIncrAttemptQuota` no longer
  leaks `daily_usage.attempts_count` past cap on rejected requests.
  New `TryIncrementAttempts(userID, day, cap)` does an atomic guarded
  UPSERT (`ON CONFLICT DO UPDATE WHERE attempts_count < $cap`).
  Counter pins at cap regardless of how many 429s land.
- **Important** — speaking screen `_friendlyError` now parses
  `ApiException` (new subclass of `HttpException` carrying statusCode
  + headers) and renders `recordErrorRateLimit{resetTime}` from
  `X-Limit-Reset` instead of `e.toString()`. Existing `catch
  (HttpException)` callers unaffected.
- **Important** — Psaní + dictation forms add
  `MediaQuery.viewInsetsOf(context).bottom` to ListView padding so
  lower TextFields stay tappable when the soft keyboard is up. Without
  this fix, tap on field 2 didn't transfer focus and `type` actions
  leaked into field 1.
- **Admin escape hatch** — `POST /v1/admin/users/:id/usage/reset`
  zeros today's `attempts_count` (interview counter untouched). CMS
  Users desk gains "Hôm nay" column (X/cap, red bold at cap, ∞ for
  Pro) + "Reset usage" action with confirm dialog. `GET /v1/admin/users`
  rows now carry `attempts_today` + `attempts_cap`.

Backend 654 tests (was 647 → +7), Flutter 309, CMS 144 in 7 files.
`make backend-test` + `make cms-{lint,build}` + `npm test` + `make
flutter-{analyze,test}` all green.

V21 CEFR Level Progression (A0 → B1) — pivot from "A2-only sprint" to
a level-gated CEFR ladder with a 2-gate promotion (mastery threshold
unlocks a promotion exam, passing the exam promotes the learner). MVP
ships A2 + B1; A0/A1 schema-ready, content deferred. Server is sole
authority for `unlock_state` and `promotion_unlocked` (client never
recomputes gates). Existing users backfill to A2 via migration 026
(idempotent — guarded by `current_level='a0' AND placement_taken_at
IS NULL`). Adds `promotion_attempts` ledger, `LevelService` gating
math + atomic promotion hook (`HandlePromotionOutcome`, idempotent
on replay), demo-aware `WithDemoCheck` so taste-test runs skip
mastery aggregate.

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
