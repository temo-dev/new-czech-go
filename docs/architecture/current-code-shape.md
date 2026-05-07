# Current Code Shape

Snapshot of how the repo is split today. Not a target architecture —
a description of the structure that emerged after V2..V22 shipped.

Last refreshed: V23 (2026-05-08). V23 additions on top of V22:

- Backend: extends `GET /v1/admin/exercises` to wrap each row with
  `validation_flags` computed by the new
  `computeValidationFlags(repo, ex)` helper. Same helper backs the
  V22 aggregate Content Health page — 5 rule definitions live in
  one place.
- CMS: introduces the `components/exercise-preview/` directory
  pattern — preview pane + per-type renderer files + small hooks
  (`useDebouncedForm`, `useMediaQuery`) — alongside the
  `*-utils.ts` companion convention from V22. Quick-fix modal +
  validation badges follow the same pattern. The preview layout
  ships standalone for V23; wiring into the existing slide-over
  form is the V24 slice's job (boundary preserved: V23 does not
  refactor the 1361 LOC form monolith).
- Conventions reinforced: Strict modal scope (publish + audio
  regen only), per-row validation_flags inline (not separate
  query param), clone-shares-asset / skip-audio (admin regenerates
  via existing endpoint).

V22 additions on top of V21.3 baseline:

- Backend: 2 new admin handlers (`admin_user_state.go`,
  `admin_content_health.go`) + 3 new list/find methods on existing
  store interfaces (`PromotionAttempts.ListForUser`,
  `Attempt.ListAttemptsForUser`, `MockTest.FindPublishedPromotionByLevel`).
  No new store package. Promotion uniqueness guard lives in
  `server.go` as `checkPromotionUniqueness` rather than a separate
  validator layer.
- CMS: 2 new components (`learner-xray.tsx`, `content-health.tsx`)
  with paired `*-utils.ts` helper files for unit-testability, plus 1
  new helper file (`mock-test-dashboard-utils.ts`) extracted from the
  existing dashboard. 2 new page routes (`/users/[userId]`,
  `/content-health`) + 2 new proxy routes. Sidebar gained one entry.
  No new abstraction layer — components fetch directly through the
  existing `/api/admin/*` proxy pattern.
- The pattern of "component + `*-utils.ts` companion file" is now
  the V22+ convention for any non-trivial CMS surface, since CMS
  test infra remains pure-vitest (no `@testing-library/react`) and
  component render is delegated to manual smoke.

Graph stats from session-start (built at commit `8b5c05e44ec6` before
V21.3 — V22 not yet re-indexed):

- **467 files** parsed (post-V21.3 ~478 with new Flutter + backend files)
- **5038 nodes**
- **40981 edges**
- **10 languages**: go, typescript, javascript, swift, c, dart, bash, tsx, python, java

## High-level shape

Monorepo with three product surfaces and a documentation surface:

```
backend/        Go API + processing pipeline + Postgres stores
cms/            Next.js content desk
flutter_app/    Flutter learner app (iOS-first)
docs/           Reference contracts, slice specs, ideas, guides, design
```

Architectural style:
- contract-first
- vertical-slice oriented (V2..V21.1)
- monolithic inside each surface
- mock providers behind interfaces (LLM, TTS, STT, OCR)

## Backend layout

`backend/internal/` packages (not exhaustive — touched lightly):

```
contracts/        DTOs shared between handlers + stores. One file per domain.
                  V21 added: level.go, user_level.go, promotion_attempt.go.

httpapi/          HTTP handlers + Server struct + route table.
                  server.go is the edge — it composes auth, deps wiring,
                  and route registration. Per-feature handler files
                  (placement_handler.go, promotion_handler.go,
                  level_handler.go, dictation_*.go, …) live alongside.

processing/       Pure logic — no HTTP, no DB writes. Each subsystem owns
                  one file pair: <topic>.go + <topic>_test.go.
                  Key files: processor.go (attempt funnel),
                  mastery_updater.go (V19 hook), level_service.go (V21
                  gating), level_promotion.go (V21 hook),
                  *_config.go (env loaders), llm_*.go (prompts +
                  model IDs — single source of truth per AGENTS.md).

store/            Persistence. Each domain has interface + memory impl
                  + postgres impl + ensureSchema runtime DDL.
                  Pattern: <domain>_store.go (interface + memory) +
                  postgres_<domain>.go (Postgres impl). Some domains
                  collapse both into one file. The Postgres store
                  ensures its schema on first construction; canonical
                  migrations also live in backend/db/migrations/*.sql.

contracts/, processing/, store/, httpapi/  — strict acyclic order.
```

Bootstrap path: `cmd/api/main.go` constructs each Postgres store via
`NewPostgres<Domain>Store`, wires them into a `MemoryStore` facade
(legacy compatibility) + a `Processor`, then assembles the HTTP server
through `httpapi.NewServerWithAuth` / `NewServerWithMastery` /
`NewServerWithAudio`. V21.3 added mandatory in-memory `LevelDeps`
(UserLevelStore + PromotionAttemptsStore + LevelService) wired via
`assembleServer`'s variadic `*LevelDeps` parameter — all three
constructors now accept it.

## Backend gravity wells

Files that own a wide span of responsibility — natural extraction
candidates if pressure mounts:

| File | Lines | Owns |
|---|---|---|
| `internal/httpapi/server.go` | ~2400 | route registration, auth wrappers, learner + admin handler bodies that haven't been pulled into per-feature files yet, helper functions (writeJSON, writeError) |
| `internal/store/memory.go` | ~750 | facade for every store interface; legacy in-memory paths kept for tests |
| `internal/contracts/types.go` | ~1000 | shared DTOs for V8+ exercise / attempt / mock tests; new V21 types live in dedicated files |

`server.go` has been growing slice-by-slice. Per-feature handler files
(V18.1 dictation OCR, V21 placement / promotion / level) are the
established escape valve — pulling more handler bodies out of
`server.go` is the next natural move when it crosses ~3000 lines.

## CMS layout

`cms/` Next.js app router:

```
app/                            Next.js routes (pages.tsx + api/admin/*)
components/                     React components — one per dashboard surface
  course-dashboard.tsx            includes V21 level + demo exercise fields
  mock-test-dashboard.tsx         includes V21 promotion / placement flags
  exercise-form/                  per-skill form fields (inline VI strings
                                  per AGENTS.md form-field convention)
  exercise-dashboard.tsx          (legacy, large)
lib/
  level.ts                        V21 CEFR level constants + sanitizers
  mockTestFlags.ts                V21 promotion/placement mutex helpers
  i18n.tsx                        VI/EN context — sidebar + dashboards only
  api/                            client for backend endpoints
__tests__/                      Vitest unit tests for the lib/ helpers
```

Forms use **inline VI strings** per repo convention; the `lib/i18n.tsx`
context is reserved for sidebar / dashboards / list views.

CMS is intentionally a content desk, not a second product. New form
fields land inline in the dashboard; helper logic that needs unit
tests (V21 mutex, level sanitization) lives under `lib/`.

## Flutter layout

`flutter_app/lib/`:

```
core/
  api/api_client.dart             monolithic ApiClient (~30 KB)
  api/level_api.dart              V21 typed client + LevelApiException
                                  (V21.3 added skipPlacement())
  api/progress_api.dart           V20 cache wrapper around getProgress
  level_utils.dart                V21 CefrLevel enum + parsers + ladder
  skill_utils.dart                V19 skill_kind helpers
  storage/cefr_prefs.dart         V21.3 SharedPreferences helper for
                                  two CEFR keys (prompt_shown, banner_dismissed)
  theme/                          AppColors, AppTypography, AppSpacing
                                  (Babbel-inspired tokens — orange + teal)
  auth/, streak/, voice/, …       per-feature client subsystems

features/
  home/
    screens/course_list_screen.dart  V21.3: accepts LevelApi?;
                                     mounts HomeLevelHeader + LockedCourseTile +
                                     PromotionExamFlow routing
    widgets/                         level_badge, level_progress_ring,
                                     promotion_banner, home_level_header,
                                     streak_ring, plan_strip, home_progress_card
  courses/widgets/                   locked_course_tile, locked_course_sheet
  onboarding/                        V21.3 full CEFR onboarding:
                                     cefr_auth_gate.dart (routing gate)
                                     placement_test_screen.dart (exam wrapper)
                                     existing_level_confirm_dialog.dart (one-time)
                                     welcome_screen.dart (placement intro)
                                     placement_result_screen.dart (level reveal)
  promotion/                         pre_exam_screen, promotion_result_screen
                                     promotion_exam_flow.dart (V21.3 orchestrator:
                                     PreExam → MockExam → PromotionResult)
  progress/                          skill mastery detail
  exercise/                          per-skill exercise screens
  mock_exam/                         full-exam runner (V21.3: onCompleted hook)
  interview/, deck_session/, …       per-feature flows

models/models.dart                  one file holds Course / Exercise /
                                    LevelProgressResponse / SkillMasteryInfo
                                    / MockTest / Attempt …  (~50 KB)

l10n/                               VI + EN ARB; gen-l10n produces
                                    AppLocalizations. VI = EN key counts
                                    are required.

shared/widgets/                     cross-feature primitives (feedback_card,
                                    primary_button, score_ring, …)
```

Per AGENTS.md: every learner-facing string goes through ARB →
AppLocalizations; VI = EN key count must match. Form-internal strings
in CMS stay inline.

## Test surface (post-V21.3)

| Layer | Tests | Coverage style |
|---|---|---|
| Backend | 659 | unit (per-package) + integration (httpapi spins NewServerForTest) + E2E smoke (`level_flow_test.go`, exam flows). Memory + Postgres stores both targeted from the same interface. V21.3 +5 (placement/skip handler). |
| CMS | 144 Vitest | pure logic helpers (`lib/*.ts`) + form payload utilities. No React-component rendering tests yet. |
| Flutter | 345 | unit (models, utils, CefrPrefs) + widget (per-screen + per-widget, _FakeLevelApi pattern for API-dependent screens) + API client integration (loopback HttpServer). V21.3 +36 across 7 new test files. |

## What is structurally good

- Backend pkg split (contracts → store → processing → httpapi) holds
  cleanly across 21 slices.
- LLM / TTS / OCR config centralised — single source of truth at
  `processing/llm_*.go` per AGENTS.md rule.
- Per-slice idea + spec discipline produced 24 ideas + 19 frozen
  slice specs documented under `docs/`.
- V19 mastery hook + V21 promotion hook both wired through
  `processor.completeAttempt` / `repo.CompleteMockExam` so a new
  side-effect doesn't need a new fan-out point.
- Postgres ensureSchema runs at every store boot — no manual
  migration step required for dev / compose deploys.

## What is structurally fragile

- `httpapi/server.go` ~2400 lines — admin + learner + helper bodies
  still mixed. New per-feature handler files are the standing escape
  valve, but the backlog of un-extracted handlers has grown.
- `store/memory.go` ~750 lines — facade carries every store
  interface; tests still use it as the convenient one-stop wiring.
- `models/models.dart` ~50 KB — Flutter parses every wire shape from
  one file. Splitting per domain is the natural next move.
- V19 mean vs V21 max mastery aggregation is documented but means
  the home ring (V21) shows different per-skill numbers than the
  progress detail (V19). Acceptable but worth flagging in onboarding
  for new contributors.
- ARB key count must stay matched VI=EN; `flutter gen-l10n` catches
  drift but onboarding contributors hit this every time they add a
  string.

## Refactor pressure to watch

When you next touch the backend at scale (V22+), expect to land:

- A second wave of `httpapi/server.go` extraction. Course / exercise
  handlers are the next obvious targets — they predate the V18+
  per-feature file convention.
- A `Repo` interface that supersedes the `MemoryStore` facade. The
  legacy facade is the largest acyclic-violation risk — the test
  wiring expects "one store to rule them all" while production
  bootstraps each Postgres store independently.
- Splitting `models/models.dart` once Flutter onboarding feels the
  weight. Domain split (course/, attempt/, exam/, level/) mirrors
  the backend `contracts/` layout.

## Bottom line

V21.1 ships with a multi-slice-tested architecture. The gravity wells
(`server.go`, `memory.go`, `models.dart`) are well-known, are flagged
by `code-review-graph` hub analysis, and have established escape
valves. The shape is appropriate for the current phase: it lets each
slice land in 1–9 days without forcing a structural rewrite, and the
tests catch regressions across all three surfaces.

Next structural moves should be incremental, not architectural — pull
the next handler bundle out of `server.go`, split the next contract
domain out of `models.dart`, etc.
