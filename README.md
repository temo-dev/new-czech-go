# A2 Mluvení Sprint

Speaking-prep app for Vietnamese learners taking the Czech `trvalý
pobyt A2` exam (and `občanství B1` once content lands).

**Status**: V2 → V21.1 shipped. CEFR level progression (A0/A1/A2/B1)
gating live behind a 2-gate promotion (mastery threshold → promotion
exam). Existing learners backfill to A2.

## Stack

| Surface | Tech | Where |
|---|---|---|
| Backend | Go 1.24, Postgres 16 | `backend/` |
| CMS | Next.js 15, TypeScript | `cms/` |
| Learner app | Flutter (iOS-first), Dart 3 | `flutter_app/` |

## Quick start

```bash
# 1. Compose stack (postgres + backend + cms)
cp .env.compose.example .env
# Edit .env: AUDIO_SIGN_SECRET=$(openssl rand -hex 32)
make compose-up

# 2. Verify
curl -s http://localhost:8080/v1/me \
  -H "Authorization: Bearer dev-learner-token" | jq .
open http://localhost:3000          # CMS

# 3. Flutter against the compose backend (separate terminal)
cd flutter_app
flutter run --dart-define=API_BASE_URL=http://localhost:8080
```

Detailed walkthroughs:

- [docs/guides/dev-workflow.md](docs/guides/dev-workflow.md) — native (no-docker) setup
- [docs/guides/v21-local-docker.md](docs/guides/v21-local-docker.md) — compose end-to-end with V21 seeding

## Daily commands

```bash
make verify                # backend-build + cms-lint + cms-build + flutter-analyze + flutter-test
make backend-test          # Go suite (647 tests)
make smoke-promotion-flow  # V21 end-to-end smoke
make smoke-all             # every smoke flow
make compose-down          # stop compose stack (keep volume)
make compose-down -v       # full reset
```

Per RTK convention, the Makefile prefixes shell commands with `rtk` for
token-optimized output. See [RTK.md](RTK.md) for direct invocations.

## Doc map

- **[AGENTS.md](AGENTS.md)** — operational guide for working in this
  repo (build rules, scope discipline, conventions). **Read this first**
  if you're picking up the project.
- **[CHANGELOG.md](CHANGELOG.md)** — per-slice history with file
  changes, decisions, and final test counts (V2 → V21.1).
- **[SPEC.md](SPEC.md)** — frozen per-slice spec summaries.
- **[CLAUDE.md](CLAUDE.md)** — AI assistant config (refs
  [RTK.md](RTK.md) and the project [AGENTS.md](AGENTS.md)).
- **[docs/](docs/README.md)** — full documentation tree:
  - [`reference/`](docs/reference/README.md) — stable contracts (api,
    state machine, scoring pipeline, infrastructure baseline, …)
  - [`specs/`](docs/specs/README.md) — frozen post-ship slice specs
  - [`ideas/`](docs/ideas/) — pre-spec one-pagers
  - [`guides/`](docs/guides/README.md) — dev / deploy / smoke / admin handbooks
  - [`architecture/`](docs/architecture/) — code shape + refactor map
  - [`features/`](docs/features/) — user-facing feature descriptions
  - [`design/`](docs/design/) — design system + HTML mockups
  - [`screens/`](docs/screens/) — per-screen behaviour notes

## Test totals (V21.1)

| Layer | Tests |
|---|---|
| Backend | **647** |
| Flutter | **309** |
| CMS | **144** |

`make verify` exits 0; `make smoke-promotion-flow` exits 0.

## Scope discipline

This is a narrow speaking-prep app for the Czech `trvalý pobyt` exam.
**Do not expand into**:

- free-form AI tutoring
- live teacher marketplace
- advanced analytics platform
- pronunciation-first product positioning

See [AGENTS.md § Scope Discipline](AGENTS.md#scope-discipline) for the
full list.

## Contributing

Slices land in this order:

1. Refine the idea → `docs/ideas/<slice>.md`
2. Write the spec → `docs/specs/<slice>.md`
3. Plan the work → `tasks/<slice>-plan.md` + `tasks/<slice>-todo.md`
4. Build incrementally — TDD per task, commit per checkpoint
5. Verify — `make verify` + `make smoke-<slice>-flow`
6. Document — fold stable contract changes into `docs/reference/`,
   freeze the slice spec, add a CHANGELOG entry

The detailed convention lives in [AGENTS.md](AGENTS.md).
