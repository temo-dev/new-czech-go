# V24 — Reading Exercise Draft Generator

**Status**: Spec frozen on ship · **Decided**: 2026-05-08
**Skill scope**: `doc` (cteni_1..cteni_6) only
**Pre-spec**: [docs/ideas/exercise-draft-generator.md](../ideas/exercise-draft-generator.md)
**UX**: [docs/ideas/exercise-draft-generator-ux.md](../ideas/exercise-draft-generator-ux.md)
**Depends on**: V8 schema (skill_kind on exercises), V21 (level field), V22 CMS Catch-Up, V23 Exercise Authoring Polish

## 1. Objective

Admin opens "New Reading Exercise" in CMS, picks `exercise_type`, fills
`(topic, grammar_points[], level, optional_extra)`, clicks **"Sinh nháp"**.
Backend calls Claude with a strict JSON-schema tool definition for that
exercise_type, returns a fully-formed cteni payload, CMS fills the form
fields. Admin edits and saves as a normal exercise. The exercise is
flagged `created_by_llm=true` for analytics.

**Why**: cteni passages take 20-40 min to author by hand. AI draft cuts
this to 5-10 min (read + edit). Validates Czech generation quality before
expanding to `viet`/`nghe`.

**Non-goals**:
- `viet`/`nghe`/`noi` generators (separate slices)
- Bulk module generation
- Preview pane / variant picker / diff view
- Auto-publish without human review
- Image generation (cteni_1 items get text only; admin uploads images)

## 2. Architecture

```
┌────────────────────────┐
│ CMS — ReadingFields    │
│ + AiDraftPanel         │
└─────────┬──────────────┘
          │ POST /v1/admin/exercises/generate-draft
          │  body: { exercise_type, topic, grammar_point_ids[], level,
          │          extra_instructions }
          ▼
┌─────────────────────────────────────────┐
│ httpapi/admin_draft_handler.go          │
│  - validate request                     │
│  - load grammar_points from store       │
│  - dispatch by exercise_type            │
└─────────┬───────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────┐
│ processing/reading_draft_generator.go   │
│  - extends ContentGenerator interface   │
│  - GenerateReadingDraft(input) →        │
│    contracts.ReadingDraft               │
│  - calls Claude w/ tool_use + per-type  │
│    JSON schema                          │
└─────────┬───────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────┐
│ Claude API (tool_use enforced)          │
│  - returns JSON matching schema         │
└─────────┬───────────────────────────────┘
          │
          ▼ (response → contracts.ReadingDraft)
┌─────────────────────────────────────────┐
│ Server-side validation:                 │
│  - schema shape correct                 │
│  - count matches type (5 q for cteni_2)│
│  - correct_answers covers all questions│
└─────────┬───────────────────────────────┘
          │
          ▼ 200 OK { data: ReadingDraft }
┌────────────────────────┐
│ CMS — fillForm(payload)│
│ admin reviews + Saves  │
└────────────────────────┘
```

**No async job, no DB write before save.** Sync only. If admin closes
form mid-generation, request is aborted; nothing persists.

## 3. API Contract

### `POST /v1/admin/exercises/generate-draft`

**Auth**: admin only (existing CMS bearer token).

**Request body**:

```json
{
  "exercise_type": "cteni_2",
  "topic": "đi khám bác sĩ",
  "grammar_point_ids": ["uuid-of-minuly-cas", "uuid-of-akuzativ"],
  "level": "A2",
  "extra_instructions": "Dùng giọng văn thân mật, có 2 nhân vật"
}
```

**Field validation**:

| Field | Type | Required | Constraints |
|---|---|---|---|
| `exercise_type` | enum | yes | `cteni_1`, `cteni_2`, `cteni_3`, `cteni_4`, `cteni_5`, `cteni_6` |
| `topic` | string | yes | 3-200 chars, trimmed, non-empty |
| `grammar_point_ids` | string[] | yes | 1-3 UUIDs; each must exist in `grammar_rules` |
| `level` | enum | yes | `A0`, `A1`, `A2`, `B1` |
| `extra_instructions` | string | no | ≤500 chars |

**Response 200**:

```json
{
  "data": {
    "exercise_type": "cteni_2",
    "detail": { /* per-type shape, see §4 */ },
    "metadata": {
      "model": "claude-haiku-4-5-20251001",
      "duration_ms": 6234,
      "input_tokens": 412,
      "output_tokens": 891
    }
  }
}
```

**Error responses**:

| Status | Code | When |
|---|---|---|
| 400 | `invalid_request` | Validation fails (missing field, wrong enum, etc.) |
| 404 | `grammar_point_not_found` | Any `grammar_point_ids[i]` not in DB |
| 422 | `schema_mismatch` | LLM returned malformed JSON after tool_use |
| 429 | `rate_limited` | >5 generation requests/min from this admin (simple in-memory limiter) |
| 502 | `llm_error` | Claude API returned non-2xx |
| 504 | `timeout` | LLM call exceeded 30s |

Error body: `{"error":{"code":"...","message":"..."}}`.

**Idempotency**: not required. Each call generates a fresh draft.

## 4. Per-Type JSON Schemas

The handler dispatches to one of six tool schemas. Schema is enforced via
Claude's `tool_use` mode (not parsed from free text).

### cteni_1 — match items → A-H

```json
{
  "items": [
    {"item_no": 1, "text": "..."},
    {"item_no": 2, "text": "..."},
    {"item_no": 3, "text": "..."},
    {"item_no": 4, "text": "..."},
    {"item_no": 5, "text": "..."}
  ],
  "options": [
    {"key": "A", "text": "..."},
    {"key": "B", "text": "..."},
    {"key": "C", "text": "..."},
    {"key": "D", "text": "..."},
    {"key": "E", "text": "..."},
    {"key": "F", "text": "..."},
    {"key": "G", "text": "..."},
    {"key": "H", "text": "..."}
  ],
  "correct_answers": {"1": "C", "2": "A", "3": "F", "4": "B", "5": "G"}
}
```

Validation: 5 items, 8 options (A-H), 5 correct keys, each value in A-H,
no duplicate values. `asset_id` omitted — admin uploads images post-fill.

### cteni_2 — text + 5 questions × A-D

```json
{
  "text": "Pavel byl nemocný a šel k lékaři...",
  "questions": [
    {
      "question_no": 1,
      "prompt": "Kam šel Pavel?",
      "options": [
        {"key": "A", "text": "..."},
        {"key": "B", "text": "..."},
        {"key": "C", "text": "..."},
        {"key": "D", "text": "..."}
      ]
    }
    /* total 5 */
  ],
  "correct_answers": {"1": "B", "2": "A", "3": "D", "4": "C", "5": "A"}
}
```

Validation: 5 questions, exactly 4 options each, all correct keys A-D.
`text` 100-200 words.

### cteni_3 — match 4 texts → persons A-E

```json
{
  "texts": [
    {"item_no": 1, "text": "..."},
    {"item_no": 2, "text": "..."},
    {"item_no": 3, "text": "..."},
    {"item_no": 4, "text": "..."}
  ],
  "persons": [
    {"key": "A", "name": "Pavel", "description": "..."},
    {"key": "B", "name": "Marie", "description": "..."},
    {"key": "C", "name": "...", "description": "..."},
    {"key": "D", "name": "...", "description": "..."},
    {"key": "E", "name": "...", "description": "..."}
  ],
  "correct_answers": {"1": "C", "2": "A", "3": "E", "4": "B"}
}
```

Validation: 4 texts, 5 persons (1 distractor), 4 correct keys A-E unique.

### cteni_4 — 6 questions × A-D (optional context)

```json
{
  "context": "...",
  "questions": [ /* 6 items, same shape as cteni_2 */ ],
  "correct_answers": {"1": "...", "2": "...", "3": "...", "4": "...", "5": "...", "6": "..."}
}
```

Validation: 6 questions, 4 options each. `context` optional but recommended.

### cteni_5 — text + 5 fill-info questions

```json
{
  "text": "...",
  "questions": [
    {"question_no": 1, "prompt": "Jméno autora:"}
    /* total 5 */
  ],
  "correct_answers": {"1": "Pavel", "2": "lékař", "3": "30", "4": "Praha", "5": "úterý"}
}
```

Validation: 5 questions, all correct values are short strings (1-30 chars).
`text` 80-150 words.

### cteni_6 — Ano/Ne (1-5 statements)

```json
{
  "passage": "...",
  "statements": [
    {"question_no": 1, "statement": "Pavel je doktor."}
    /* 1-5 */
  ],
  "correct_answers": {"1": "ANO", "2": "NE", "3": "ANO"},
  "max_points": 3
}
```

Validation: 1-5 statements, each value `ANO` or `NE` (uppercase),
`max_points = len(statements)`. `passage` 80-150 words.

## 5. Prompt Strategy

One system prompt + per-type user prompt builders. Strict adherence to
existing centralization rules.

### System prompt — `ReadingDraftSystemPrompt`

Add to `backend/internal/processing/llm_prompts.go`:

```go
const ReadingDraftSystemPrompt = `You are a Czech language content
creator producing reading-comprehension exercises for Vietnamese
learners preparing for the trvalý pobyt A2 / B1 exams.

Output rules:
- Generate authentic, natural Czech matching the requested CEFR level
- Use vocabulary and grammar appropriate for that level only
- Demonstrate the requested grammar point(s) explicitly in the passage
  (use each point at least 2 times when feasible)
- Keep tone neutral and exam-appropriate
- Do NOT mention you are an AI or reference the prompt
- All Czech text must be free of English/Vietnamese/transliteration
- Distractors in multiple-choice questions must be plausible — same
  semantic field, same grammatical category as the correct answer
- correct_answers map keys are stringified question_no ("1", "2", ...)
- For cteni_6, correct_answers values must be UPPERCASE "ANO" or "NE"`
```

### Per-type user prompts — `llm_user_prompts.go`

```go
func BuildReadingDraftUserPrompt(in ReadingDraftInput) string
```

dispatches by `in.ExerciseType` and inlines:
- topic
- grammar point titles + rule_table summary (loaded from `grammar_rules`)
- level
- extra_instructions (if non-empty)
- type-specific structural requirements (e.g., "Generate exactly 5
  questions of 4 options each" for cteni_2).

Each branch produces a complete user prompt; the system prompt stays
constant.

### Tool schema builder

`buildReadingDraftToolSchema(exerciseType string) map[string]any` —
returns one of 6 schemas matching §4 exactly. Driven by exercise_type
literal, not data, so static schemas live in code.

## 6. Backend File Map

### New files

| File | Purpose |
|---|---|
| `backend/internal/processing/reading_draft_generator.go` | `ReadingDraftGenerator` interface + Claude impl + `MockReadingDraftGenerator` |
| `backend/internal/processing/reading_draft_generator_test.go` | Unit tests for prompt builders + schema dispatch |
| `backend/internal/processing/reading_draft_validator.go` | Per-type validation (counts, key uniqueness, ranges) |
| `backend/internal/processing/reading_draft_validator_test.go` | Validation cases per type (golden fixtures) |
| `backend/internal/httpapi/admin_draft_handler.go` | `POST /v1/admin/exercises/generate-draft` handler |
| `backend/internal/httpapi/admin_draft_handler_test.go` | Handler tests with `MockReadingDraftGenerator` |

### Modified files

| File | Change |
|---|---|
| `backend/internal/processing/llm_prompts.go` | Add `ReadingDraftSystemPrompt` const |
| `backend/internal/processing/llm_user_prompts.go` | Add `BuildReadingDraftUserPrompt` + `ReadingDraftInput` struct |
| `backend/internal/processing/llm_config.go` | Add `LLMReadingDraftModel` field + env var `LLM_READING_DRAFT_MODEL` (default = `DefaultContentModel`) |
| `backend/internal/contracts/types.go` | Add `ReadingDraft`, `ReadingDraftInput`, `Cteni1DraftDetail`...`Cteni6DraftDetail` (= existing `Cteni*Detail` shapes; reuse where possible) |
| `backend/internal/httpapi/server.go` | Wire route + inject `ReadingDraftGenerator` into `Server` |
| `backend/internal/httpapi/v6_handlers.go` | Optionally: add `created_by_llm` to exercise create payload (only if not already there) |
| `backend/internal/store/postgres_migrate.go` | Migration 027 — add `exercises.created_by_llm BOOLEAN DEFAULT FALSE` |

### Centralization rules (per AGENTS.md)

- ❌ No prompt strings in `admin_draft_handler.go` or `reading_draft_generator.go`
- ❌ No `claude-*` literals outside `llm_config.go`
- ❌ No `os.Getenv("LLM_*")` outside `llm_config.go`

## 7. CMS File Map

### New files

| File | Purpose |
|---|---|
| `cms/components/ai-draft/AiDraftPanel.tsx` | Collapsible inline panel (matches §UX mockup) |
| `cms/components/ai-draft/GrammarPointPicker.tsx` | Free-text combobox; queries `/v1/admin/grammar-rules` for autocomplete |
| `cms/components/ai-draft/LevelRadio.tsx` | A0/A1/A2/B1 radio group |
| `cms/hooks/useGenerateDraft.ts` | POST + abort + error handling |
| `cms/hooks/useGrammarRules.ts` | GET + cache for autocomplete |

### Modified files

| File | Change |
|---|---|
| `cms/components/exercise-form/ReadingFields.tsx` | Mount `<AiDraftPanel exerciseType={watch('exercise_type')} onApply={fillReadingFields} />` at top of form |
| `cms/components/exercise-form/types.ts` | Add `fillReadingFields(detail, type)` helper to map `ReadingDraft.detail` → form fields |
| `cms/lib/api.ts` | Add `generateDraft(req)` client wrapper with AbortController support |
| `cms/components/exercises/ExerciseListView.tsx` | Add ✨ icon next to title when `exercise.created_by_llm = true`; filter chip "AI-drafted" |

### Inline VI strings

Per CMS convention (`AGENTS.md § CMS Conventions`), all UI strings in
`exercise-form/*` are inline VI. New components follow the same rule.

## 8. Database Changes

Migration 027 (`addColumnIfMissing` style — RDS-safe):

```sql
ALTER TABLE exercises
  ADD COLUMN IF NOT EXISTS created_by_llm BOOLEAN DEFAULT FALSE;
```

No backfill — existing rows default `false`. New rows from the AI flow
set `true` via the existing exercise create endpoint (CMS forwards a
flag).

No new tables. `content_generation_jobs` is **not** used.

## 9. State Machine (CMS)

Defined in `useGenerateDraft.ts`:

```
idle ──[generate(input)]──▶ loading
loading ──[200]──▶ success (returns ReadingDraft)
loading ──[abort]──▶ idle
loading ──[error]──▶ error
success ──[regenerate(input)]──▶ loading
error ──[retry]──▶ loading
```

`AiDraftPanel` owns local UI state (collapsed/expanded, form values,
filled-chip visibility). Parent `ReadingFields` receives only
`onApply(detail, type)` callback.

## 10. Validation & Error Handling

### Server-side validation order

1. JSON unmarshal — return 400 on syntax error
2. Field constraints (§3 table) — return 400 with field name
3. `grammar_point_ids` lookup — return 404 if any missing
4. Rate limit check (per-admin, 5/min in-memory) — return 429
5. LLM call (timeout 30s) — return 504 / 502 on infra error
6. Tool-use response parse — return 422 if malformed
7. Schema validator (per type, §4 rules) — return 422 with reason
8. 200 with `data`

### Client-side validation

- `topic`: 3-200 chars (`maxLength` + visible counter when >180)
- `grammar_point_ids`: 1-3 chips required
- `level`: must be selected
- `extra_instructions`: ≤500 chars
- Disable "Sinh nháp" until all required fields valid

### User-visible error mapping

| Server code | UI message |
|---|---|
| `invalid_request` | "Thiếu thông tin: {field}" |
| `grammar_point_not_found` | "Điểm ngữ pháp đã chọn không tồn tại. Tải lại trang." |
| `schema_mismatch` | "AI trả output sai cho {exercise_type}. Bấm Tạo lại." |
| `rate_limited` | "Quá nhiều lần sinh. Thử lại sau {n}s." (countdown chip) |
| `llm_error`, `timeout` | "Không kết nối được AI. Thử lại sau." |

## 11. Testing Strategy

### Unit tests (Go) — must pass in CI

- `reading_draft_generator_test.go`:
  - `BuildReadingDraftUserPrompt` produces expected substrings per type
  - System prompt const not modified per call
  - Mock generator returns canned `ReadingDraft` (no real Claude call)
- `reading_draft_validator_test.go`:
  - Per-type valid fixture passes
  - 30+ malformed fixtures (wrong count, missing key, bad enum) reject
    with specific error
- `admin_draft_handler_test.go`:
  - 400 on invalid body
  - 404 when grammar_point unknown
  - 422 when validator rejects
  - 200 happy path with `MockReadingDraftGenerator`
  - Verify `metadata` echoed in response

### Integration tests (Go)

- `make backend-test` covers above. No real Claude in CI.

### Manual integration (pre-merge gate)

Before merging V22:
- Generate 5 drafts × 6 cteni types = 30 calls against real Claude
  Haiku 4.5
- Czech native or teacher rates each (target: ≥70% usable without
  major rewrite)
- If <70%: switch to Claude Sonnet 4.6 via `LLM_READING_DRAFT_MODEL`
  env var, retest. If still <70% — kill V22, do not ship.

### CMS tests

- `useGenerateDraft.test.ts` — mock fetch, verify abort, retry flow
- `AiDraftPanel.test.tsx` — render states (collapsed/expanded/loading/
  filled/error), confirm-overwrite dialog flow
- `GrammarPointPicker.test.tsx` — autocomplete keyboard nav, max 3 chips

### Smoke

Add to `make smoke-course-flow` (no new make target):
- Admin login → create cteni_2 exercise via UI → click Generate Draft →
  verify form fields populated → save → assert exercise persisted with
  `created_by_llm=true`.

## 12. Acceptance Criteria

Slice ships when:

- [ ] Backend: `POST /v1/admin/exercises/generate-draft` returns valid
      `ReadingDraft` for all 6 cteni types in <15s p99 (mocked)
- [ ] Backend: 30+ unit tests added, all `make backend-test` green
- [ ] Backend: Migration 027 applied without errors on local + staging DB
- [ ] CMS: `AiDraftPanel` renders inline in `ReadingFields`
- [ ] CMS: Generate → fill works for all 6 cteni types end-to-end
- [ ] CMS: Regenerate with confirm-overwrite dialog works
- [ ] CMS: All 5 error states show user-friendly messages
- [ ] CMS: Lighthouse a11y on the form ≥95
- [ ] CMS: `make cms-lint` + `make cms-build` + `cd cms && npm test` green
- [ ] Admin Czech-quality review (§11 manual gate) ≥70% usable
- [ ] CHANGELOG entry + `SPEC.md` digest row added
- [ ] `docs/reference/api-contracts.md` updated with new endpoint
- [ ] `docs/reference/infrastructure-baseline.md` LLM env table updated
      with `LLM_READING_DRAFT_MODEL`

## 13. Rollout

1. Merge migration 027 first; verify column added on staging + prod
2. Merge backend with feature flag-style env: if
   `LLM_READING_DRAFT_MODEL=""` set explicitly to empty, return 503
   from endpoint (off switch). Default: enabled.
3. Merge CMS — panel only renders when admin has `cms_role` (existing).
4. Soft launch to internal admins for 1 week
5. Track via `exercises.created_by_llm` count + endpoint p99 latency
6. If usable rate >70% in week 1, plan V25 for `viet` generator

## 14. Out of Scope (V24)

- `viet`, `nghe`, `noi` generators → V25+
- Bulk module / multi-exercise generation
- Variant picker / 3-draft comparison
- Two-stage gated flow (passage → questions split)
- Auto image generation for cteni_1 (Replicate Flux integration)
- Auto grammar/level second-pass quality verification
- Admin audit log of every generation call (only `created_by_llm`
  flag persists)
- Cost tracking dashboard (raw Claude usage logs only)
- Prompt versioning / A/B test harness
- Multi-tenant isolation (single admin pool assumed)

## 15. Open Items

- Final Czech quality test result before merge — blocker
- Decide whether to re-run quality check periodically (every model
  change?) — decide post-V22
- Consider exposing the prompt template to CMS for power-admin tuning
  later — not V22

## 16. Glossary

- **Draft**: AI-generated `ReadingDraft` payload, never persisted alone
- **Exercise**: existing `exercises` row, may be `created_by_llm=true`
- **Grammar point**: row in existing `grammar_rules` table
- **Apply / Fill**: client action of writing draft fields into form state

---

**File ownership**: this spec is frozen on V24 ship. Subsequent
behavior changes land in V25+ specs + relevant `docs/reference/`
files, not here.
