# V6 — LLM-Assisted Vocab & Grammar (Implementation-Ready Plan)

**Updated**: 2026-04-28 — all decisions finalized. Ready for VG-A.  
**Design**: Admin input → Async LLM job → Admin review/edit → Validate → Publish

---

## All Finalized Decisions

| # | Decision | Final |
|---|----------|-------|
| 1 | Generation mode | **Async job + goroutine + poll** (not sync) |
| 2 | Skill prerequisite | **Auto-create** tu_vung/ngu_phap skill per module if missing |
| 3 | Draft editing UI | **Separate editor per type**: Quizcard/ChoiceWord/FillBlank/Matching |
| 4 | Regenerate | **Per-job only** — reject job, create new job. No per-exercise regen. |
| 5 | Source traceability | **Add** `source_type`, `source_id`, `generation_job_id` nullable to `exercises` |
| 6 | Quizcard progress | **Completion only** in V6. known/review saved in `transcript_json`. No mastery dashboard. |
| 7 | Rate limit | **1 active job per admin** — 409 if another running. Log model/tokens/cost in job. |
| 8 | LLM boundary | **Authoring only** — never objective scoring. Published content scored deterministically in Go. |
| 9 | Publish behavior | **Validate all first**, then publish all atomically. Fail = 400 + error list, nothing published. |
| 10 | Flutter reuse | **Reuse** `FillInWidget` + `MultipleChoiceWidget` from V3. New: `QuizcardWidget` + `MatchingWidget`. |
| B1 | Matching format | **Option key A/B/C** — `correct_answers: {"1":"A","2":"B"}`. Exact match. No full text. |
| B2 | postgres_exercises.go | **Update** CreateExercise/UpdateExercise to write source_type/source_id/generation_job_id |
| B3 | Goroutine recovery | **On server start**: mark all `status='running'` jobs as `failed` (anti-leak) |
| B4 | Shared validation | **Extract** `ValidateExercisePayload()` + `BuildExerciseFromDraft()` — shared by HTTP handler + publish endpoint |
| G1 | Module selector | **In modal**: course dropdown → module dropdown cascade. No URL param. |
| G2 | Matching shuffle | **Flutter-side** — server stores deterministic pairs; Flutter shuffles right-side options for display |
| G3 | CMS polling | **useEffect + setInterval(2s)** — stop on terminal status, cleanup on unmount |
| G4 | Store interfaces | **3 interfaces**: `VocabularyStore`, `GrammarStore`, `GenerationJobStore` (with memory fallback) |
| G5 | ID generation | **Go-side** prefixed IDs: `vocset-`, `vocitem-`, `grammar-`, `genjob-` |
| M1 | ContentGenerator | **Interface + MockContentGenerator** for unit tests (no Claude calls in tests) |
| M2 | Rate limit scope | **Per admin per module** — `WHERE requested_by='admin' AND module_id=$1 AND status IN ('pending','running')` |

---

## Architecture

```
Admin (CMS)
  │
  ├─ /vocabulary   → VocabularySet CRUD + word list
  └─ /grammar      → GrammarRule CRUD + conjugation table
          │
          │ POST /admin/content-generation-jobs
          ▼
  content_generation_jobs table
  [pending → running → generated | failed]
          │
          │ goroutine: LLM (Claude tool_use, JSON schema enforced)
          ▼
  generated_payload_json (draft)
          │
          │ Admin reviews in CMS: type-specific editor per exercise
          │ PATCH /admin/content-generation-jobs/:id/draft
          ▼
  edited_payload_json
          │
          │ POST /admin/content-generation-jobs/:id/publish
          │ Backend validates all → fail atomically or write all
          ▼
  exercises table (pool=course, source_type, source_id, generation_job_id set)
          │
          │ Flutter learner
          ▼
  QuizcardWidget / MatchingWidget / FillInWidget / MultipleChoiceWidget
          │
          │ POST /v1/attempts/:id/submit-answers (objective scorer, pure Go)
          ▼
  ObjectiveResultCard (score + explanation)
```

---

## Implementation Contracts (previously missing, now locked)

### Matching Exercise — Full Contract

**Exercise payload stored in DB** (`MatchingDetail`):
```json
{
  "pairs": [
    { "left_id": "1", "left": "chodím", "right_id": "A", "right": "đi bộ" },
    { "left_id": "2", "left": "běžím",  "right_id": "B", "right": "chạy"  },
    { "left_id": "3", "left": "jedu",   "right_id": "C", "right": "đi (xe)" },
    { "left_id": "4", "left": "letím",  "right_id": "D", "right": "bay"   }
  ],
  "correct_answers": { "1": "A", "2": "B", "3": "C", "4": "D" }
}
```

**Flutter rendering**:
- Left column: Czech terms in `left_id` order (fixed, not shuffled)
- Right column: Vietnamese options shuffled from `right_id`/`right` pairs
- Learner taps a left term → taps a right option → creates pair
- Submit: `answers = {"1": "C", "2": "A", "3": "D", "4": "B"}` (whatever learner chose)

**Scoring** (exact match, `len(correct) <= 1 char` rule → exact):
```go
// right_id values are "A"/"B"/"C"/"D" — single char → exact match in ScoreObjectiveAnswers
correct_answers["1"] = "A"
learner_answers["1"] = "A"  // ✓ or "C" // ✗
```

No substring match. No fuzzy. Pure exact match inherited from existing scorer.

---

### Store Interfaces (Go — new in VG-A)

```go
type VocabularyStore interface {
    CreateVocabularySet(set contracts.VocabularySet) (contracts.VocabularySet, error)
    GetVocabularySet(id string) (contracts.VocabularySet, bool)
    ListVocabularySets(moduleID string) []contracts.VocabularySet
    UpdateVocabularySet(id string, update contracts.VocabularySet) (contracts.VocabularySet, bool)
    DeleteVocabularySet(id string) bool
    CreateVocabularyItem(item contracts.VocabularyItem) contracts.VocabularyItem
    ListVocabularyItems(setID string) []contracts.VocabularyItem
    DeleteVocabularyItem(id string) bool
}

type GrammarStore interface {
    CreateGrammarRule(rule contracts.GrammarRule) (contracts.GrammarRule, error)
    GetGrammarRule(id string) (contracts.GrammarRule, bool)
    ListGrammarRules(moduleID string) []contracts.GrammarRule
    UpdateGrammarRule(id string, update contracts.GrammarRule) (contracts.GrammarRule, bool)
    DeleteGrammarRule(id string) bool
}

type GenerationJobStore interface {
    CreateJob(job contracts.ContentGenerationJob) contracts.ContentGenerationJob
    GetJob(id string) (contracts.ContentGenerationJob, bool)
    UpdateJobRunning(id string)
    UpdateJobGenerated(id string, payload json.RawMessage, tokens, outputTokens int, costUSD float64, durationMs int)
    UpdateJobFailed(id string, errMsg string)
    UpdateJobDraft(id string, editedPayload json.RawMessage) bool
    UpdateJobPublished(id string, publishedAt time.Time) bool
    UpdateJobRejected(id string) bool
    FindActiveJob(requestedBy, moduleID string) (contracts.ContentGenerationJob, bool)
    MarkAllRunningFailed(errMsg string)  // called on server start
}
```

---

### ContentGenerator Interface + Mock (Go)

```go
// backend/internal/processing/content_generator.go

type VocabularyGenerationInput struct {
    Items           []contracts.VocabularyItem
    Level           string   // A1/A2/B1
    ExplanationLang string   // vi/en/cs
    ExerciseTypes   []string
    NumPerType      map[string]int
}

type GrammarGenerationInput struct {
    Title       string
    Level       string
    Forms       map[string]string // "já":"jsem","ty":"jsi"
    Constraints string
    ExerciseTypes []string
    NumPerType    map[string]int
}

type ContentGenerator interface {
    GenerateVocabulary(ctx context.Context, input VocabularyGenerationInput) (*contracts.GeneratedPayload, error)
    GenerateGrammar(ctx context.Context, input GrammarGenerationInput) (*contracts.GeneratedPayload, error)
}

// Production impl: ClaudeContentGenerator (uses tool_use)
// Test impl:
type MockContentGenerator struct {
    Payload *contracts.GeneratedPayload
    Err     error
}
func (m *MockContentGenerator) GenerateVocabulary(_ context.Context, _ VocabularyGenerationInput) (*contracts.GeneratedPayload, error) {
    return m.Payload, m.Err
}
func (m *MockContentGenerator) GenerateGrammar(_ context.Context, _ GrammarGenerationInput) (*contracts.GeneratedPayload, error) {
    return m.Payload, m.Err
}
```

---

### Shared Exercise Validation (Go — extracted from handleAdminExercises)

```go
// backend/internal/processing/exercise_validator.go

func ValidateExercisePayload(exerciseType string, ex contracts.GeneratedExercise) []string {
    var errs []string
    switch exerciseType {
    case "quizcard_basic":
        if ex.FrontText == "" { errs = append(errs, "front_text required") }
        if ex.BackText  == "" { errs = append(errs, "back_text required") }
    case "choice_word":
        if ex.Prompt == "" { errs = append(errs, "prompt required") }
        if len(ex.Options) < 2 { errs = append(errs, "need ≥2 options") }
        if !slices.Contains(ex.Options, ex.CorrectAnswer) { errs = append(errs, "correct_answer not in options") }
        if hasDuplicates(ex.Options) { errs = append(errs, "duplicate options") }
    case "fill_blank":
        if !strings.Contains(ex.Prompt, "___") { errs = append(errs, "prompt must contain ___") }
        if ex.CorrectAnswer == "" { errs = append(errs, "correct_answer required") }
    case "matching":
        if len(ex.Pairs) < 2 { errs = append(errs, "need ≥2 pairs") }
        // check no duplicate left or right
    }
    if ex.Explanation == "" { errs = append(errs, "explanation required") }
    return errs
}

func BuildExerciseFromDraft(ex contracts.GeneratedExercise, skillID, jobID, sourceType, sourceID string) (contracts.Exercise, error) {
    // Build contracts.Exercise with correct Detail struct per type
    // Set SkillID, SourceType, SourceID, GenerationJobID
    // Set Status = "published", Pool = "course"
    // Generate ID with prefix (vocset- etc)
}
```

Used by:
- `handleAdminExercises` POST (manual creation via CMS form)
- `handlePublishGenerationJob` (publish endpoint)

---

### CMS Polling Hook Pattern

```tsx
// In vocabulary/grammar pages — no SWR/React Query needed

function useJobPoller(jobId: string | null, onComplete: (job: GenerationJob) => void) {
  const [job, setJob] = useState<GenerationJob | null>(null);

  useEffect(() => {
    if (!jobId) return;
    const TERMINAL = ['generated', 'failed', 'rejected', 'published'];
    const id = setInterval(async () => {
      const res = await fetch(`/api/admin/content-generation-jobs/${jobId}`);
      const j = await res.json();
      setJob(j.data);
      if (TERMINAL.includes(j.data?.status)) {
        clearInterval(id);
        onComplete(j.data);
      }
    }, 2000);
    return () => clearInterval(id);  // cleanup on unmount
  }, [jobId]);

  return job;
}
```

---

### Server Startup Recovery

```go
// In main.go or repo initialization, after DB connection established:
if err := repo.MarkAllRunningJobsFailed("Server restarted while generation was running"); err != nil {
    log.Printf("warn: failed to recover stuck jobs: %v", err)
    // non-fatal, continue startup
}
```

SQL executed:
```sql
UPDATE content_generation_jobs
SET status = 'failed',
    error_message = $1,
    updated_at = NOW()
WHERE status = 'running';
```

---

### ID Generation Prefixes

```go
// Go-side, consistent with newUUIDLikeID() pattern
func newVocSetID()    string { return "vocset-"  + newUUIDLikeID() }
func newVocItemID()   string { return "vocitem-" + newUUIDLikeID() }
func newGrammarID()   string { return "grammar-" + newUUIDLikeID() }
func newGenJobID()    string { return "genjob-"  + newUUIDLikeID() }
```

Migration SQL: no DEFAULT for id column — let Go set it.

---

### CMS Module Selector (in VocabularySetModal + GrammarRuleModal)

```
VocabularySetModal fields (in order):
1. Course     <select> — load from GET /api/admin/courses
2. Module     <select> — load from GET /api/admin/modules?course_id={courseId} on course change
3. Title      <input>
4. Level      <select>  A1 / A2 / B1
5. Topic      <input>  (optional, used in LLM prompt)
6. Explanation lang  <select>  VI / EN / CS
7. Word list table  (term | meaning | POS columns, add/remove row)

On Save: POST /admin/vocabulary-sets { module_id, title, level, topic, explanation_lang, items[] }
Backend auto-creates tu_vung skill if module doesn't have one.
```

Same pattern for GrammarRuleModal with explanation_vi + rule_table key-value pairs.

---

## DB Schema (migrations 013–016)

### 013 — vocabulary_sets + vocabulary_items

```sql
CREATE TABLE vocabulary_sets (
    id TEXT PRIMARY KEY DEFAULT 'vocset-' || gen_random_uuid(),
    skill_id TEXT NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    level TEXT NOT NULL DEFAULT 'A2',
    explanation_lang TEXT NOT NULL DEFAULT 'vi',
    status TEXT NOT NULL DEFAULT 'draft',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE vocabulary_items (
    id TEXT PRIMARY KEY DEFAULT 'vocitem-' || gen_random_uuid(),
    set_id TEXT NOT NULL REFERENCES vocabulary_sets(id) ON DELETE CASCADE,
    term TEXT NOT NULL,
    meaning TEXT NOT NULL,
    part_of_speech TEXT,
    example_sentence TEXT,
    example_translation TEXT,
    sequence_no INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);
```

### 014 — grammar_rules

```sql
CREATE TABLE grammar_rules (
    id TEXT PRIMARY KEY DEFAULT 'gram-' || gen_random_uuid(),
    skill_id TEXT NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    level TEXT NOT NULL DEFAULT 'A2',
    explanation_vi TEXT,
    rule_table_json JSONB,
    constraints_text TEXT,
    status TEXT NOT NULL DEFAULT 'draft',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);
```

### 015 — content_generation_jobs

```sql
CREATE TABLE content_generation_jobs (
    id TEXT PRIMARY KEY DEFAULT 'cgjob-' || gen_random_uuid(),
    module_id TEXT NOT NULL,
    skill_id TEXT,
    source_type TEXT NOT NULL,    -- vocabulary_set | grammar_rule
    source_id TEXT NOT NULL,
    requested_by TEXT NOT NULL DEFAULT 'admin',
    input_payload_json JSONB NOT NULL,
    generated_payload_json JSONB,
    edited_payload_json JSONB,
    status TEXT NOT NULL DEFAULT 'pending',
    -- pending → running → generated | failed → rejected | published
    provider TEXT NOT NULL DEFAULT 'claude',
    model TEXT NOT NULL DEFAULT 'claude-sonnet-4-6',
    input_tokens INT,
    output_tokens INT,
    estimated_cost_usd NUMERIC(10,6),
    duration_ms INT,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    published_at TIMESTAMPTZ
);
```

### 016 — exercises add source columns

```sql
ALTER TABLE exercises
    ADD COLUMN IF NOT EXISTS source_type TEXT,         -- vocabulary_set | grammar_rule | custom
    ADD COLUMN IF NOT EXISTS source_id TEXT,
    ADD COLUMN IF NOT EXISTS generation_job_id TEXT;
```

---

## API Contracts

### Vocabulary & Grammar CRUD

```
POST   /v1/admin/vocabulary-sets          { title, skill_id?, module_id, level, explanation_lang, items[] }
GET    /v1/admin/vocabulary-sets          ?module_id=&status=
GET    /v1/admin/vocabulary-sets/:id      includes items[]
PATCH  /v1/admin/vocabulary-sets/:id
DELETE /v1/admin/vocabulary-sets/:id

POST   /v1/admin/grammar-rules            { title, skill_id?, module_id, level, explanation_vi, rule_table, constraints_text }
GET    /v1/admin/grammar-rules            ?module_id=&status=
GET    /v1/admin/grammar-rules/:id
PATCH  /v1/admin/grammar-rules/:id
DELETE /v1/admin/grammar-rules/:id
```

Note: if `skill_id` not provided, backend auto-creates tu_vung/ngu_phap skill for that module.

### Generation Job Lifecycle

```
POST /v1/admin/content-generation-jobs
  body: {
    source_type: "vocabulary_set" | "grammar_rule",
    source_id: string,
    module_id: string,
    exercise_types: ["quizcard_basic","matching","fill_blank","choice_word"],
    num_per_type: { quizcard_basic: 5, matching: 2, fill_blank: 5, choice_word: 5 }
  }
  → 202 { job_id, status: "pending" }
  → 409 if admin already has a running job

GET /v1/admin/content-generation-jobs/:id
  → { id, status, generated_payload, edited_payload, error_message, input_tokens, output_tokens }

PATCH /v1/admin/content-generation-jobs/:id/draft
  body: { edited_payload_json: GeneratedPayload }
  → 200 { status: "generated" }

POST /v1/admin/content-generation-jobs/:id/publish
  → validates edited_payload_json (all exercises)
  → on fail: 400 { validation_errors: [{index, type, message}] }
  → on success: creates exercises rows, job status=published, returns { exercise_ids[] }

POST /v1/admin/content-generation-jobs/:id/reject
  → job status=rejected

GET /v1/admin/content-generation-jobs?source_id=&status=
  → list jobs for a source
```

### LLM Generation (internal — not exposed to learner)

Goroutine spawned from POST endpoint:

```go
func generateAsync(jobID string, req GenerationRequest) {
    // 1. Update status=running
    // 2. Build prompt + tool schema
    // 3. Call Claude Messages API (tool_use, ~30-90s)
    // 4. Validate output per exercise type
    // 5. Update generated_payload_json + tokens + duration
    // 6. Update status=generated | failed + error_message
}
```

**Rate limit**: before spawning goroutine, check `content_generation_jobs WHERE requested_by=admin AND status IN ('pending','running')`. If exists → 409.

**Claude tool_use schema** (enforces JSON, no free text):
```json
{
  "name": "save_exercises",
  "description": "Save generated exercises",
  "input_schema": {
    "type": "object",
    "properties": {
      "exercises": {
        "type": "array",
        "items": {
          "type": "object",
          "required": ["exercise_type", "prompt", "correct_answer"],
          "properties": {
            "exercise_type": { "enum": ["quizcard_basic","matching","fill_blank","choice_word"] },
            "front_text": { "type": "string" },
            "back_text": { "type": "string" },
            "prompt": { "type": "string" },
            "options": { "type": "array", "items": { "type": "string" } },
            "pairs": { "type": "array", "items": { "type": "object" } },
            "correct_answer": { "type": "string" },
            "explanation": { "type": "string" }
          }
        }
      }
    },
    "required": ["exercises"]
  }
}
```

### Publish Validation (all-or-nothing)

```go
func validateEditedPayload(exercises []GeneratedExercise) []ValidationError {
    for i, ex := range exercises {
        switch ex.ExerciseType {
        case "quizcard_basic":
            require non-empty front_text, back_text
        case "choice_word":
            require prompt non-empty
            require len(options) >= 2
            require correct_answer ∈ options
            require no duplicate options
        case "fill_blank":
            require prompt contains "___"
            require correct_answer non-empty
        case "matching":
            require len(pairs) >= 2
            require each pair has term + definition
            require no duplicate terms
            require no duplicate definitions
        }
        require explanation non-empty (all types)
    }
    return errors // publish only if len(errors)==0
}
```

---

## Skill Auto-Creation

When POST /admin/vocabulary-sets or /admin/grammar-rules is called without skill_id:

```go
func ensureSkill(moduleID, skillKind, defaultTitle string) (skillID string, err error) {
    existing := repo.SkillsByModuleAndKind(moduleID, skillKind)
    if len(existing) > 0 {
        return existing[0].ID, nil
    }
    // Auto-create
    sk, err := repo.CreateSkill(contracts.Skill{
        ModuleID:   moduleID,
        SkillKind:  skillKind,   // "tu_vung" | "ngu_phap"
        Title:      defaultTitle, // "Từ vựng" | "Ngữ pháp"
        SequenceNo: 99,
        Status:     "published",
    })
    return sk.ID, err
}
```

---

## Vertical Slices (final)

### VG-A — DB + Go Contracts

**Migrations**: 013 (vocab), 014 (grammar), 015 (jobs), 016 (exercises columns)

**New Go structs** in `contracts/types.go`:
- `VocabularySet`, `VocabularyItem`
- `GrammarRule`
- `ContentGenerationJob`
- `QuizcardBasicDetail`, `MatchingDetail`, `FillBlankDetail`, `ChoiceWordDetail`
- `GeneratedExercise`, `GeneratedPayload`, `ValidationError`

**Update** `Skill.isImplemented` in Flutter `models.dart`:
```dart
bool get isImplemented => skillKind == 'noi' || skillKind == 'viet' ||
    skillKind == 'nghe' || skillKind == 'doc' ||
    skillKind == 'tu_vung' || skillKind == 'ngu_phap';
```

**AC**: `make backend-build` passes. Migrations apply. No Flutter compile errors.

---

### VG-B — Backend API + LLM Generator

**New file**: `backend/internal/processing/llm_content_generator.go`
- `ContentGenerator` interface + Claude implementation
- Goroutine pattern matching `LLMFeedbackProvider` structure
- Token/cost extraction from Claude response usage field

**New routes in server.go**:
- CRUD for vocabulary-sets, grammar-rules
- POST /admin/content-generation-jobs (spawn goroutine, 409 guard)
- GET /admin/content-generation-jobs/:id (poll)
- PATCH /admin/content-generation-jobs/:id/draft
- POST /admin/content-generation-jobs/:id/publish (validate + create exercises)
- POST /admin/content-generation-jobs/:id/reject

**`skillKindForExerciseType` allowlist**:
```go
var vocabGrammarTypeAllowedSkills = map[string][]string{
    "quizcard_basic": {"tu_vung"},
    "matching":       {"tu_vung", "ngu_phap"},
    "fill_blank":     {"tu_vung", "ngu_phap"},
    "choice_word":    {"tu_vung", "ngu_phap"},
}
```

**quizcard scoring**: In `ProcessObjectiveAttempt`, if `exerciseType == "quizcard_basic"`:
- Skip `ScoreObjectiveAnswers`
- Store submitted answer in `transcript_json.quizcard_result`
- Return `score=1, max_score=1, status=completed`

**AC**:
- POST job (vocab source) → 202 with job_id
- GET job → status transitions: pending→running→generated
- POST job while one running → 409
- POST publish with bad data → 400 + validation_errors list
- POST publish with clean data → exercises created with source_type/source_id/generation_job_id set
- `make backend-build && make backend-test`

---

### VG-C — CMS /vocabulary Page

**File**: `cms/app/vocabulary/page.tsx`

**Components**:
```
VocabularyPage
├── VocabularySetList (table: title, level, word count, status, actions)
├── VocabularySetModal (create/edit: title, level, explanation_lang, word table)
│   └── WordListTable (term | meaning | POS | add row | delete row | paste from clipboard)
├── GenerationScopePanel (exercise_types checkboxes + num_per_type sliders)
├── GenerationStatusPoller (polls GET /jobs/:id every 2s, shows spinner/progress)
└── DraftReviewPanel
    └── GeneratedExerciseReviewTable
        ├── QuizcardDraftEditor    (front textarea, back textarea, explanation)
        ├── ChoiceWordDraftEditor  (prompt, 4 option inputs, correct selector, explanation)
        ├── FillBlankDraftEditor   (sentence textarea, answer input, explanation)
        └── MatchingDraftEditor    (pair rows: term | definition, add/remove row)
```

**Per-editor validation** (client-side, real-time):
- ChoiceWord: correct_answer ∈ options, no dupes, ≥2 options
- FillBlank: `___` in prompt, answer non-empty
- Matching: ≥2 pairs, no dupe terms/definitions
- Quizcard: front + back non-empty

**Action buttons** on each exercise row in review:
- [Edit] toggle editor
- [Delete] remove from draft (client-side only, updates edited_payload)

**Page-level actions**:
- [Save Draft] → PATCH /jobs/:id/draft
- [Publish] → POST /jobs/:id/publish → show validation errors or success
- [Reject Draft] → POST /jobs/:id/reject
- [New Generation] → show GenerationScopePanel again

**AC**:
- Create set with 4 words → generate → see QuizcardDraftEditor + MatchingDraftEditor in review
- Edit explanation inline → save draft → reload → edits persisted
- Publish with bad choice_word → see error row highlighted
- Publish with all valid → exercises appear in /exercises inventory under tu_vung skill
- `make cms-build`

---

### VG-D — CMS /grammar Page

**File**: `cms/app/grammar/page.tsx`

Same pattern as VG-C but source = GrammarRule.

**Components**:
```
GrammarPage
├── GrammarRuleList
├── GrammarRuleModal
│   ├── title, level inputs
│   ├── explanation_vi textarea
│   ├── rule_table: key-value pair rows (e.g. "já → jsem")
│   └── constraints_text textarea
├── GenerationScopePanel (fill_blank + choice_word checkboxes only, matching optional)
├── GenerationStatusPoller
└── DraftReviewPanel (same GeneratedExerciseReviewTable, grammar exercises only)
```

**Note**: Grammar generation only offers fill_blank + choice_word by default.
Matching is optional (for grammar paradigm matching). quizcard_basic not available for ngu_phap.

**AC**:
- Create "Verb být" rule with 6-form table → generate 10 fill_blank + 10 choice_word
- Each exercise has explanation referencing the grammatical form
- Publish → 20 exercises under ngu_phap skill
- `make cms-build`

---

### VG-E — Flutter Screens

**models.dart updates**:
```dart
// ExerciseDetail new flags
bool get isQuizcard   => exerciseType == 'quizcard_basic';
bool get isMatching   => exerciseType == 'matching';
bool get isFillBlank  => exerciseType == 'fill_blank';
bool get isChoiceWord => exerciseType == 'choice_word';
bool get isVocabGrammar => isQuizcard || isMatching || isFillBlank || isChoiceWord;

// New parsed fields (from detail JSON)
final String flashcardFront;
final String flashcardBack;
final String flashcardExample;
final String flashcardExampleTranslation;
final List<MatchingPairView> matchingPairs;
final String fillBlankSentence;
final String fillBlankHint;
final String fillBlankExplanation;
final String choiceWordStem;
final String choiceWordExplanation;
final String choiceWordGrammarNote;

// New class
class MatchingPairView {
  final int pairNo;
  final String term;        // Czech
  final String definition;  // Vietnamese
}
```

**exercise_list_screen.dart**:
```dart
// _exerciseMatchesSkillKind
case 'tu_vung':  return ['quizcard_basic','matching','fill_blank','choice_word'].contains(exerciseType);
case 'ngu_phap': return ['matching','fill_blank','choice_word'].contains(exerciseType);

// _openExercise — add before fallback
if (detail.isVocabGrammar) {
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => VocabGrammarExerciseScreen(client: widget.client, detail: detail),
  ));
  return;
}
```

**New `VocabGrammarExerciseScreen`**:
```dart
// Routes by type:
if (detail.isQuizcard)   → QuizcardWidget (self-contained, no ObjectiveResultCard)
if (detail.isMatching)   → create attempt → MatchingWidget → submit → ObjectiveResultCard
if (detail.isFillBlank)  → create attempt → FillInWidget (reuse V3) → submit → ObjectiveResultCard
if (detail.isChoiceWord) → create attempt → MultipleChoiceWidget (reuse V3) → submit → ObjectiveResultCard
```

**New `QuizcardWidget`**:
- AnimationController 200ms ease-in-out flip
- Front: Czech term large + optional image
- Back: Vietnamese + example + example_translation (teal bg)
- After flip: [Đã biết ✓] [Ôn lại ↺]
- Both: POST /v1/attempts (create) → POST /v1/attempts/:id/submit-answers `{"1":"known"|"review"}` → show "Ghi nhận!"
- score=1/1 always, no ObjectiveResultCard (it would say "1/1" which is meaningless)

**New `MatchingWidget`**:
- Left: shuffled Czech terms (chip buttons)
- Right: shuffled Vietnamese definitions (chip buttons)
- Tap term → highlight; tap definition → create pair (same color badge)
- Tap connected pair → un-pair
- [Nộp] enabled when all pairs connected
- Submits `{"1":"def1","2":"def2",...}` (term pairNo → selected definition)
- Shows ObjectiveResultCard after submit

**i18n ARB** (both app_vi.arb + app_en.arb):
```json
"vocabKnown": "Đã biết",
"vocabReview": "Ôn lại",
"vocabFlip": "Nhấn để xem",
"vocabMatchInstruction": "Ghép từ với nghĩa tương ứng",
"vocabFillInstruction": "Điền từ vào chỗ trống",
"vocabChoiceInstruction": "Chọn từ đúng",
"vocabDone": "Ghi nhận!"
```

**AC**:
- `make flutter-analyze` 0 issues, `make flutter-test` passes
- Quizcard: flip 200ms, both buttons work, shows "Ghi nhận!", no misleading score
- Matching: connect 4 pairs → submit → score shows 3/4 if one wrong
- FillBlank: type correct word → 1/1 + explanation shown
- ChoiceWord: pick correct option → 1/1 + grammar note shown
- tu_vung/ngu_phap exercises NOT visible in noi/viet/nghe/doc skill lists

---

## Checkpoint VG

```bash
make backend-build && make backend-test && make cms-build && make flutter-analyze
```

**Manual smoke** (requires local backend + LLM configured):
1. CMS /vocabulary: create "Động từ di chuyển" (4 words) → Generate → poll → review 12 exercises → edit one explanation → Publish → verify in /exercises inventory under tu_vung
2. CMS /grammar: create "Verb být A1" → Generate → review 10 fill_blank + 10 choice_word → Publish under ngu_phap
3. Try generate while job running → see 409
4. Flutter: open quizcard → flip → "Đã biết" → Ghi nhận!
5. Flutter: open matching 4 pairs → connect all → submit → see score
6. Flutter: verify that tu_vung exercises do NOT appear in noi skill list

---

## Scope Boundaries (V6)

**In V6:**
- Vocabulary sets + items CRUD
- Grammar rules CRUD (with conjugation table)
- Async LLM generation (Claude, tool_use, structured JSON)
- Content generation jobs with full audit trail
- Admin review with type-specific editors
- Publish to exercises (atomic validation)
- QuizcardWidget + MatchingWidget (new Flutter)
- FillInWidget + MultipleChoiceWidget (reused from V3)
- source_type/source_id/generation_job_id on exercises

**Out of V6 (backlog):**
- Quizcard mastery rate / spaced repetition
- Per-exercise regenerate
- Cancel running job
- Learner vocabulary progress dashboard
- Audio for vocabulary (Polly TTS on vocab items)
- B2/C1 level content
- Cost dashboard / admin billing view
- Lesson entity

---

## Dependency Order

```
VG-A (DB migrations + contracts)
   │
   ▼
VG-B (backend API + LLM generator)
   │
   ├──────────────────────┐
   ▼                      ▼
VG-C (CMS /vocabulary)  VG-D (CMS /grammar)     VG-E (Flutter) ← can start after VG-A
   └──────────────────────┘                          │
                                               [CHECKPOINT VG]
```

VG-E can start in parallel with VG-B (exercise type routing + Flutter models need only VG-A contracts).
