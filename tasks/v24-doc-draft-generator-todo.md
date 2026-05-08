# V24 Doc Draft Generator — Todo

**Plan**: [v24-doc-draft-generator-plan.md](v24-doc-draft-generator-plan.md)
**Spec**: [docs/specs/v24-doc-draft-generator.md](../docs/specs/v24-doc-draft-generator.md)

Status legend: `[ ]` open · `[~]` in progress · `[x]` done · `[→]` deferred

## Phase A — Foundation

- [x] **A1** Migration 027 — `exercises.created_by_llm BOOLEAN DEFAULT FALSE`
  - [x] Inline `ALTER TABLE ... ADD COLUMN IF NOT EXISTS created_by_llm BOOLEAN NOT NULL DEFAULT FALSE` in `postgres_exercises.go ensureSchema` (matches existing pattern; not the `addColumnIfMissing` helper)
  - [x] Idempotent — `IF NOT EXISTS` on every startup
  - [x] `Exercise.CreatedByLLM bool` field added to `contracts/types.go`
  - [x] `insertExercise`, `upsertExercise`, `exerciseSelectQuery`, `scanExercise` all updated; `created_by_llm` is sticky on upsert (`OR EXCLUDED.created_by_llm`)
  - [x] `TestCreateExercisePreservesCreatedByLLM` covers create + refetch + default-false
  - [x] `make backend-test` green
- [x] **A2** Contract types `ReadingDraftInput`, `ReadingDraft`, `ReadingDraftMeta` in `contracts/types.go`
  - [x] Reuse existing `Cteni*Detail` + `AnoNeDetail` via `Detail any` field
  - [x] `go build ./...` clean
- [x] **A3** `LLMModels.ReadingDraft` + env var `LLM_READING_DRAFT_MODEL`
  - [x] Default = `DefaultReadingDraftModel = claude-haiku-4-5-20251001`
  - [x] `llm_config_test.go` covers env-set + fallback
- [x] **A4** `ReadingDraftSystemPrompt` const in `llm_prompts.go`
  - [x] Includes ANO/NE casing rule, distractor rule, no English/VI rule, no asset_id for cteni_1, A2/B1
  - [x] `TestReadingDraftSystemPrompt_AnchorsOnExpectedRules` asserts key substrings
- [x] **A5** `ReadingDraftGenerator` interface + `MockReadingDraftGenerator` + Claude impl skeleton
  - [x] All 6 cteni types return `ErrReadingDraftNotImplemented` initially
  - [x] Unknown exercise_type rejected with distinct error
  - [x] Mock returns canned struct + propagates error
- [x] **Checkpoint A** commit `feat(v24-A): foundation — migration 027 + reading draft types/config/interface` (commit `0af995f`)

## Phase B — Per-cteni type generators

Each task: tool schema + prompt branch + validator (≥5 reject + 1 accept fixture) + tests + no leak of prompt/model strings.

- [x] **B1** cteni_2 — text + 5×4MC
  - [x] Tool schema (`cteni2ToolSchema`) matches spec §4: text, 5 questions × 4 options A-D, correct_answers map
  - [x] Prompt branch in `BuildReadingDraftUserPrompt` — echoes topic/level/grammar/extra + structural rules
  - [x] Validator (`validateCteni2`) + 7 reject fixtures (count, options, key range, missing key, empty text, empty option text, duplicate keys) + 1 accept fixture
  - [x] Generator dispatch wired (`Generate` calls `callClaude` for cteni_2; other types still skeleton)
  - [x] Tool schema unit test asserts shape
  - [x] `parseReadingDraftDetail("cteni_2", ...)` round-trip test
  - [x] Commit `feat(v24-B1): cteni_2 draft generator + validator` (commit `<pending>`)
- [x] **B2** cteni_4 — 6×4MC + optional context
  - [x] Tool schema (`cteni4ToolSchema`) — context optional, 6 questions × 4 options A-D
  - [x] Prompt branch in `readingDraftStructuralRequirements` (60-120 word context recommended)
  - [x] Validator (`validateCteni4`) reuses shared `validateMultiChoiceQuestions` helper extracted from cteni_2
  - [x] Generator dispatch wired (cteni_2 + cteni_4 share `callClaude` path)
  - [x] Tests +5 (validator accept w/ + w/o context, 5 reject fixtures, schema bounds, prompt content, parser round-trip)
  - [x] Commit `feat(v24-B2): cteni_4 draft generator + validator`
- [x] **B3** cteni_5 — text + 5 fill-info
  - [x] Tool schema (`cteni5ToolSchema`) — text + 5 FillQuestion + correct_answers minLength:1, maxLength:30
  - [x] Prompt branch — 80-150 word passage, 5 fill questions, answers verbatim from passage, ≤30 chars
  - [x] Validator (`validateCteni5`) rejects empty/long answers, missing keys, empty prompts
  - [x] Generator dispatch + parser branch wired
  - [x] Tests +9 (validator accept + 6 reject, prompt content, schema bounds, parser round-trip)
  - [x] Commit `feat(v24-B3): cteni_5 draft generator + validator`
- [ ] **B4** cteni_6 — Ano/Ne (1-5 statements)
  - [ ] Validator: UPPERCASE ANO/NE; max_points == len(statements); 1-5 range
  - [ ] Commit `feat(v24-B4): cteni_6 draft generator + validator`
- [ ] **B5** cteni_3 — 4 texts → persons A-E
  - [ ] Validator: 4 texts, 5 persons (1 distractor), unique correct keys
  - [ ] Commit `feat(v24-B5): cteni_3 draft generator + validator`
- [ ] **B6** cteni_1 — 5 items → A-H text-only
  - [ ] Prompt explicitly forbids `asset_id`
  - [ ] Validator: 5 items, 8 options A-H, 5 unique correct values
  - [ ] Commit `feat(v24-B6): cteni_1 draft generator + validator (text-only)`
- [ ] **Checkpoint B** all 6 types green via mock; backend test count +30; no HTTP route yet

## Phase C — HTTP endpoint + quality gate

- [ ] **C1** `admin_draft_handler.go` POST `/v1/admin/exercises/generate-draft`
  - [ ] All 6 error paths covered (400/404/422/429/502/504)
  - [ ] Mock-driven happy path returns 200 + metadata
  - [ ] In-memory rate limiter (5/min/admin) + test
- [ ] **C2** Server wiring
  - [ ] `Server.ReadingDraftGenerator` field + DI option
  - [ ] Route registered
  - [ ] Real Claude generator wired in `assembleServer`
  - [ ] `make backend-build` + `make backend-test` green
- [ ] **C3** `created_by_llm` flag on exercise create endpoint
  - [ ] Backward-compatible (omitted = false)
  - [ ] Test asserts persistence
- [ ] **C4 KILL SWITCH — Manual Czech-quality gate**
  - [ ] Generate 30 drafts (5 × 6 types) with Haiku 4.5 against local backend
  - [ ] Czech native review each — pass/fail tally per type
  - [ ] **Decision recorded here**: PASS / RETEST WITH SONNET / KILL
    - Result: _______________
    - Date: _______________
    - Reviewer: _______________
  - [ ] If retest with Sonnet 4.6 needed, repeat above
  - [ ] If KILL: stop, do not start Phase D, document reason in CHANGELOG
- [ ] **Checkpoint C** commit `feat(v24-C): admin generate-draft endpoint + created_by_llm flag`

## Phase D — CMS

**Do not start until C4 = PASS.**

- [ ] **D1** `cms/lib/api.ts` `generateDraft` + `useGrammarRules` hook
  - [ ] AbortController support
  - [ ] Cache by level
  - [ ] `cd cms && npm test` green
- [ ] **D2** `GrammarPointPicker.tsx` + `LevelRadio.tsx`
  - [ ] ARIA combobox pattern; max 3 chips
  - [ ] Component tests for keyboard nav
- [ ] **D3** `useGenerateDraft.ts` state machine
  - [ ] All transitions tested (idle/loading/success/error/abort)
  - [ ] Error code → UI message mapping per spec §10
- [ ] **D4** `AiDraftPanel.tsx` scaffold
  - [ ] All 5 visual states render (collapsed/expanded/loading/filled/error)
  - [ ] Lucide icons (no emoji); inline VI strings
  - [ ] Form field disable while loading
- [ ] **D5** `ReadingFields.tsx` + `fillReadingFields(detail, type)` mapper
  - [ ] All 6 types fill correctly (one test per type)
  - [ ] Form sets `created_by_llm=true` when AI used
- [ ] **D6** Confirm-overwrite dialog when regenerating dirty form
  - [ ] First generate skips dialog
  - [ ] Cancel returns focus to "Tạo lại"
- [ ] **D7** ExerciseListView ✨ badge + AI-drafted filter chip
  - [ ] Badge only when flag true
  - [ ] Filter narrows list correctly
- [ ] **D8** CMS verify
  - [ ] `make cms-lint` clean
  - [ ] `make cms-build` green
  - [ ] `cd cms && npm test` green; ≥10 new tests
- [ ] **Checkpoint D** commit `feat(v24-D): CMS AI draft panel + reading fields integration`

## Phase E — Ship docs

- [ ] **E1** smoke-course-flow extended with generate-draft step
- [ ] **E2** `docs/reference/api-contracts.md` updated with new endpoint
- [ ] **E3** `docs/reference/infrastructure-baseline.md` LLM env table adds `LLM_READING_DRAFT_MODEL`
- [ ] **E4** `SPEC.md` digest row added for V24
- [ ] **E5** `CHANGELOG.md` entry (file count, test deltas, decisions)
- [ ] **E6** `tasks/plan.md` + `tasks/todo.md` indexes updated with V24 row
- [ ] **E7** `make verify` green
- [ ] **Final commit** `chore(v24-E): docs + smoke + indexes for V24`

## Open questions (resolve during implementation)

- [ ] When does `extra_instructions` get cleared in the panel? (Spec
      §UX open: persist within session, clear on form unmount.)
- [ ] Should `LLM_READING_DRAFT_MODEL=""` empty truly disable the
      endpoint (503), or just fall back to default? (Spec rollout §1
      says off-switch — confirm behavior in C2 implementation.)
- [ ] Czech native reviewer identified for C4? Schedule before B is
      complete.

## Deferred (out of scope V24)

- [→] `viet`/`nghe`/`noi` generators → V25+
- [→] Bulk module generator → future slice
- [→] Image generation for cteni_1 (Replicate Flux integration) → future
- [→] Auto grammar/level second-pass quality verification → future
- [→] Cost tracking dashboard → future
- [→] Prompt versioning / A/B harness → future
