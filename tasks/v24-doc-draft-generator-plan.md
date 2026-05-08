# V24 Doc Draft Generator — Plan

**Spec**: [docs/specs/v24-doc-draft-generator.md](../docs/specs/v24-doc-draft-generator.md)
**Idea**: [docs/ideas/exercise-draft-generator.md](../docs/ideas/exercise-draft-generator.md)
**UX**: [docs/ideas/exercise-draft-generator-ux.md](../docs/ideas/exercise-draft-generator-ux.md)

## Approach

Vertical slicing: each task in Phase B ships **one cteni type
end-to-end** (types + tool schema + prompt branch + validator + tests).
After all 6 types pass mocked tests, Phase C wires the HTTP endpoint and
gates manual Czech-quality validation **before** any CMS work.

**Critical kill switch**: if Phase C quality gate fails (<70% usable
across 30 manual reviews), Phase D is not started. Spec calls this out.

## Dependency Graph

```
A (foundation) ─┬─▶ B1 cteni_2 ─┐
                ├─▶ B2 cteni_4 ─┤
                ├─▶ B3 cteni_5 ─┤
                ├─▶ B4 cteni_6 ─├─▶ C (HTTP wire) ─▶ [QUALITY GATE] ─▶ D (CMS) ─▶ E (ship docs)
                ├─▶ B5 cteni_3 ─┤
                └─▶ B6 cteni_1 ─┘
```

B-tasks are independent of each other once A lands; can be parallelized
or interleaved. C cannot start until B is fully green. D cannot start
until quality gate passes.

## Phase A — Foundation (no behavior, compile only)

### A1. Migration 027

**Files**: `backend/internal/store/postgres_migrate.go`

- Add `addColumnIfMissing("exercises", "created_by_llm", "BOOLEAN DEFAULT FALSE")`
- No backfill (defaults to FALSE; existing rows untouched)

**Acceptance**:
- [ ] Local Postgres `make backend-run` start logs the column add
- [ ] Re-run idempotent (no error on second start)
- [ ] `make backend-test` green

### A2. Contract types

**Files**: `backend/internal/contracts/types.go`

Add (or extend) types for the draft request/response:

```go
type ReadingDraftInput struct {
    ExerciseType       string
    Topic              string
    GrammarPoints      []GrammarRule  // resolved from grammar_point_ids
    Level              string
    ExtraInstructions  string
}

type ReadingDraft struct {
    ExerciseType string         `json:"exercise_type"`
    Detail       any            `json:"detail"`     // one of Cteni*Detail
    Metadata     ReadingDraftMeta `json:"metadata"`
}

type ReadingDraftMeta struct {
    Model        string `json:"model"`
    DurationMs   int    `json:"duration_ms"`
    InputTokens  int    `json:"input_tokens,omitempty"`
    OutputTokens int    `json:"output_tokens,omitempty"`
}
```

Reuse existing `Cteni1Detail..Cteni5Detail` and `AnoNeDetail` for the
`Detail` payload. No duplicate shapes.

**Acceptance**:
- [ ] `go build ./...` passes
- [ ] No new test failures

### A3. LLM config

**Files**: `backend/internal/processing/llm_config.go`

- Add `ReadingDraft string` field on `LLMModels`
- Add `DefaultReadingDraftModel = DefaultContentModel` const
- Add env var `LLM_READING_DRAFT_MODEL` to `LoadLLMModels`

**Acceptance**:
- [ ] Field reads env value when set
- [ ] Falls back to `DefaultContentModel` when env empty
- [ ] Unit test in `processing_config_test.go` verifies both paths

### A4. System prompt

**Files**: `backend/internal/processing/llm_prompts.go`

- Add `ReadingDraftSystemPrompt` const exactly as defined in spec §5
- Add doc comment listing the 6 cteni types it covers

**Acceptance**:
- [ ] Constant compiles
- [ ] Smoke unit test asserts the prompt mentions A2/B1, no English/Vietnamese
      output, distractor rule, ANO/NE casing

### A5. Generator interface skeleton

**Files**:
- `backend/internal/processing/reading_draft_generator.go` (new)
- `backend/internal/processing/reading_draft_generator_test.go` (new)

```go
type ReadingDraftGenerator interface {
    Generate(ctx context.Context, in ReadingDraftInput) (*contracts.ReadingDraft, error)
}

type MockReadingDraftGenerator struct {
    Draft *contracts.ReadingDraft
    Err   error
}
```

Claude impl skeleton calls `BuildReadingDraftUserPrompt(in)` (added in
B-tasks) + `buildReadingDraftToolSchema(in.ExerciseType)`. Initially
returns `errors.New("not implemented for type X")` for all 6 types so
tests can prove dispatch works.

**Acceptance**:
- [ ] Interface + mock compile
- [ ] `MockReadingDraftGenerator` returns canned struct in test
- [ ] Real impl returns `not implemented` error for each type

### Checkpoint A

- [ ] `make backend-build` + `make backend-test` green
- [ ] No new behavior shipped; types + interface + config exist
- [ ] Commit: `feat(v24-A): foundation — migration 027 + reading draft types/config/interface`

## Phase B — Per-cteni type generators

Each B-task ships ONE cteni type. Same checklist per task:

- [ ] Tool schema function matches spec §4 exactly
- [ ] Per-type user prompt builder branch in `BuildReadingDraftUserPrompt`
- [ ] Validator function rejects 5+ malformed fixtures
- [ ] Validator function accepts 1 valid fixture
- [ ] Generator dispatch returns parsed payload (mock-driven test)
- [ ] No prompt strings or model literals leak outside `llm_*.go` /
      `llm_config.go`
- [ ] All tests green

**Files modified each task**:
- `backend/internal/processing/llm_user_prompts.go` — add prompt branch
- `backend/internal/processing/reading_draft_generator.go` — schema + dispatch
- `backend/internal/processing/reading_draft_validator.go` — validator
- `backend/internal/processing/reading_draft_generator_test.go` — tests
- `backend/internal/processing/reading_draft_validator_test.go` — tests

### B1. cteni_2 — text + 5×4MC (simplest)

Why first: most common shape, baseline for cteni_4. Establishes the
pattern.

**Acceptance**:
- [ ] Mock returns valid Cteni2Detail; dispatch + validator pass
- [ ] 5 malformed fixtures rejected (4-only options, 6 questions, missing
      correct_answer key, key not A-D, duplicate correct values when
      uniqueness applies)
- [ ] User prompt embeds topic + grammar titles + level + 100-200 word
      passage requirement
- [ ] Commit: `feat(v24-B1): cteni_2 draft generator + validator`

### B2. cteni_4 — 6×4MC + optional context

Reuses B1 pattern. Differs only in count (6 vs 5) + optional `context`.

**Acceptance**: same skeleton as B1, swap counts.
- [ ] Commit: `feat(v24-B2): cteni_4 draft generator + validator`

### B3. cteni_5 — text + 5 fill-info

Different shape: `FillQuestion` items, short string answers (1-30 chars).

**Acceptance**:
- [ ] Validator rejects answer >30 chars or empty
- [ ] Prompt instructs short-fact answers (single noun / number / date)
- [ ] Commit: `feat(v24-B3): cteni_5 draft generator + validator`

### B4. cteni_6 — Ano/Ne (1-5 statements)

Different shape: `AnoNeStatement[]` + `max_points`. Strict ANO/NE casing.

**Acceptance**:
- [ ] Validator enforces UPPERCASE ANO/NE
- [ ] Validator enforces `max_points == len(statements)`
- [ ] Validator accepts 1, 3, 5 statements; rejects 0 and 6
- [ ] Commit: `feat(v24-B4): cteni_6 draft generator + validator`

### B5. cteni_3 — 4 texts → persons A-E

Different shape: 4 texts, 5 persons (1 distractor).

**Acceptance**:
- [ ] Validator enforces 4 texts, 5 persons, unique correct keys A-E
- [ ] Each person has `name` + `description`
- [ ] Commit: `feat(v24-B5): cteni_3 draft generator + validator`

### B6. cteni_1 — 5 items → A-H (text-only)

Most complex match. AI generates `items[].text` only — `asset_id`
omitted (admin uploads images post-fill, per spec §1 non-goals).

**Acceptance**:
- [ ] Validator confirms no `asset_id` in payload (skip if present)
- [ ] 5 items, 8 options (A-H), 5 unique correct values in A-H
- [ ] Prompt explicitly says "do not produce asset_id; admin uploads
      images later"
- [ ] Commit: `feat(v24-B6): cteni_1 draft generator + validator (text-only)`

### Checkpoint B

- [ ] All 6 cteni types generate via `MockReadingDraftGenerator`
- [ ] All 6 validators have ≥5 reject fixtures + 1 accept fixture
- [ ] `make backend-test` green; test count grows ~30+
- [ ] No HTTP route yet — backend can dispatch but isn't reachable
- [ ] Commit checkpoint already covered by per-task commits

## Phase C — HTTP endpoint + quality gate

### C1. Handler

**Files**:
- `backend/internal/httpapi/admin_draft_handler.go` (new)
- `backend/internal/httpapi/admin_draft_handler_test.go` (new)

Implements `POST /v1/admin/exercises/generate-draft` per spec §3.

Logic:
1. Parse body, return 400 on invalid
2. Validate fields (enum, length, range), return 400
3. Look up `grammar_point_ids` via `repo.ListGrammarRules` filter, return 404 on miss
4. Rate-limit (per admin user_id, 5/min, in-memory map+sync.Mutex), return 429
5. Call `s.readingDraftGenerator.Generate(ctx, in)`, return 502/504
6. Validate output via `ReadingDraftValidator(type, detail)`, return 422
7. Write 200 with `{data: ReadingDraft}`

**Acceptance**:
- [ ] All 6 error paths covered by test
- [ ] Mock generator + valid fixture returns 200 with metadata
- [ ] Rate limit verified (6th call within 1min returns 429)

### C2. Server wiring

**Files**: `backend/internal/httpapi/server.go`

- Add `ReadingDraftGenerator processing.ReadingDraftGenerator` field on `Server`
- Add `WithReadingDraftGenerator` option (constructor injection pattern matches existing)
- Register route `mux.HandleFunc("POST /v1/admin/exercises/generate-draft", s.handleGenerateDraft)`
- Wire real Claude generator in `assembleServer.go` (or equivalent — match existing vocab/grammar wiring style)

**Acceptance**:
- [ ] `make backend-build` green
- [ ] `make backend-test` green (no broken existing tests)
- [ ] curl smoke against local server with mock generator returns 200

### C3. created_by_llm flag on exercise create

**Files**: `backend/internal/httpapi/v6_handlers.go` (or wherever exercise create lives)

- Accept `created_by_llm` in admin exercise create body
- Forward to store; default `false`
- Existing endpoint backward-compatible (omitted = false)

**Acceptance**:
- [ ] POST exercise with `created_by_llm:true` persists and returns the flag
- [ ] Existing test suite unaffected

### C4. CHECKPOINT — manual Czech-quality gate (KILL SWITCH)

**Cannot proceed to Phase D until this passes.**

Procedure:
1. Set `LLM_READING_DRAFT_MODEL=claude-haiku-4-5-20251001` (default)
2. Generate 5 drafts × 6 cteni types = 30 drafts via curl or Postman
   against local backend
3. Save raw outputs to a scratch directory (NOT committed)
4. Czech native or qualified teacher rates each:
   - **Pass**: usable as-is or with minor edits (≤5 word changes)
   - **Fail**: structural rewrite needed
5. Tally: ≥21/30 pass = proceed
6. If <21/30 pass: switch to `LLM_READING_DRAFT_MODEL=claude-sonnet-4-6`,
   re-run all 30. If still <21/30: kill V24, do not start D.

**Output of gate**:
- [ ] Quality report markdown (in scratch, not committed): per-type
      pass count + reviewer comments
- [ ] Decision recorded in `tasks/v24-doc-draft-generator-todo.md`
      (PASS / RETEST WITH SONNET / KILL)

### Checkpoint C

- [ ] Endpoint reachable
- [ ] Mock + integration tests green
- [ ] Quality gate passed
- [ ] Commit: `feat(v24-C): admin generate-draft endpoint + created_by_llm flag`

## Phase D — CMS

Only start after C4 passes.

### D1. API client + grammar-rules hook

**Files**:
- `cms/lib/api.ts` — add `generateDraft(req, signal)` and
  `listGrammarRules(level?)` functions
- `cms/hooks/useGrammarRules.ts` (new) — fetch + cache

**Acceptance**:
- [ ] `generateDraft` supports `AbortController.signal`
- [ ] Hook caches by level for session lifetime
- [ ] `cd cms && npm test` green

### D2. Form components

**Files**:
- `cms/components/ai-draft/GrammarPointPicker.tsx` (new)
- `cms/components/ai-draft/LevelRadio.tsx` (new)

Standalone, fully tested in isolation.

**Acceptance**:
- [ ] `GrammarPointPicker`: keyboard combobox; max 3 chips; uses ARIA pattern
- [ ] `LevelRadio`: A0/A1/A2/B1, controlled component
- [ ] Component tests cover keyboard nav + chip removal

### D3. useGenerateDraft hook + state machine

**Files**: `cms/hooks/useGenerateDraft.ts` (new)

Implements state machine from spec §9.

**Acceptance**:
- [ ] State transitions covered: idle → loading → success/error/idle(abort)
- [ ] Abort cancels in-flight fetch
- [ ] Test mocks `fetch` for all 6 spec error codes; UI mapping correct

### D4. AiDraftPanel scaffold

**Files**: `cms/components/ai-draft/AiDraftPanel.tsx` (new)

Renders collapsed/expanded/loading/filled/error states from UX mockup.

**Acceptance**:
- [ ] All 5 visual states render without prop drilling
- [ ] Inline VI strings (no i18n routing — per CMS convention)
- [ ] Lucide `Sparkles`, `Loader2`, `AlertCircle` icons (no emoji)
- [ ] Form fields disabled while `isLoading=true`
- [ ] Component test asserts each state render

### D5. ReadingFields integration

**Files**:
- `cms/components/exercise-form/ReadingFields.tsx` — mount panel + write `fillReadingFields`
- `cms/components/exercise-form/types.ts` — `fillReadingFields(detail, type)` mapper

`fillReadingFields` switches on exercise_type and writes the
`Cteni*Detail` payload into the corresponding form fields. Each cteni
type is one switch case.

**Acceptance**:
- [ ] All 6 types fill correctly (one test per type)
- [ ] Form `created_by_llm` field set true when AI used
- [ ] Manual test: open form, generate draft, see fields populated

### D6. Confirm-overwrite dialog

**Files**: extends `AiDraftPanel.tsx`

When admin clicks Regenerate AND form has unsaved content → confirm dialog.

**Acceptance**:
- [ ] Dialog blocks regenerate until user confirms
- [ ] First-time generate (empty form) skips dialog
- [ ] Cancel returns focus to "Tạo lại" button

### D7. List view badge

**Files**: `cms/components/exercises/ExerciseListView.tsx` (or current list view)

- ✨ Lucide icon next to title when `created_by_llm=true`
- Filter chip "AI-drafted" toggles list

**Acceptance**:
- [ ] Badge renders when flag true
- [ ] Filter narrows list correctly

### D8. CMS tests + lint + build

**Acceptance**:
- [ ] `make cms-lint` clean
- [ ] `make cms-build` green
- [ ] `cd cms && npm test` green; ≥10 new tests added across hooks/components

### Checkpoint D

- [ ] Full E2E: admin opens form → fills AI panel → generates → fills
      → edits → saves → list shows AI badge
- [ ] Commit: `feat(v24-D): CMS AI draft panel + reading fields integration`

## Phase E — Ship docs

### E1. Smoke

**Files**: `Makefile` — extend `make smoke-course-flow` (no new target)

Add a step: admin login → POST generate-draft (cteni_2) → assert 200 →
POST exercise with the draft → assert exercise persisted with
`created_by_llm=true`.

**Acceptance**:
- [ ] `make smoke-course-flow` includes the step and is green

### E2. docs/reference/api-contracts.md

Add new endpoint section with request/response shapes (link, don't
duplicate, the per-type schemas — point to spec §4).

**Acceptance**:
- [ ] Endpoint documented in api-contracts under `Admin endpoints`
- [ ] All 6 error codes listed

### E3. docs/reference/infrastructure-baseline.md

Update LLM env var table with `LLM_READING_DRAFT_MODEL` row.

**Acceptance**:
- [ ] Row added with default `claude-haiku-4-5-20251001`

### E4. SPEC.md digest row

Add one row to SPEC.md table summarising V24.

**Acceptance**:
- [ ] Row matches the existing digest format
- [ ] Link points to `docs/specs/v24-doc-draft-generator.md`

### E5. CHANGELOG entry

Add new top entry following existing format (file changes + final test
counts).

**Acceptance**:
- [ ] Entry includes file count, test count delta, decisions
- [ ] Reviewer can read the entry alone and understand what shipped

### E6. tasks/plan.md + tasks/todo.md indexes

Add V24 row to both indexes.

**Acceptance**:
- [ ] Both index files reference the V24 plan/todo

### E7. Final verify

**Acceptance**:
- [ ] `make verify` green
- [ ] All checkboxes in `v24-doc-draft-generator-todo.md` ticked
- [ ] One final commit: `chore(v24-E): docs + smoke + indexes for V24`

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Czech quality fails at C4 | Spec defines kill switch; switch model first; if both fail, abandon V24 — minimal sunk cost (no CMS work done) |
| Tool-use schema rejected by Claude for complex types (cteni_1 H options) | Test each schema in isolation in B-tasks; fall back to simpler schema if Claude refuses |
| Rate limiter races under concurrent requests | In-memory + mutex is fine for single-instance V1; revisit if multi-instance |
| Migration 027 fails on RDS owner mismatch | `addColumnIfMissing` already checks `information_schema` per existing pattern |
| Admin overrides `created_by_llm=true` without using AI | Server doesn't reject; analytics will be slightly noisy. Acceptable; add server-side validation in V25 if abuse seen |
| LLM_READING_DRAFT_MODEL unset interpreted as "off switch" breaks dev | Default to `DefaultContentModel`; off switch requires explicit empty string env (`LLM_READING_DRAFT_MODEL=""`) |

## Effort Estimate

Rough only — depends heavily on Phase B repetition speed:

| Phase | Tasks | Est. dev hours |
|---|---|---|
| A | A1-A5 | 4-6h |
| B | B1-B6 | 12-18h (2-3h per type after first) |
| C | C1-C4 | 6-8h + quality review session |
| D | D1-D8 | 14-20h |
| E | E1-E7 | 3-4h |
| **Total** | | **39-56h** |

Quality gate session (C4) requires Czech native availability — schedule
ahead.
