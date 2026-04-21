# Refactor Map V1

## Purpose
This document turns the current architecture snapshot into a practical refactor map for V1.

It answers:
- what should stay as-is for now
- what should be split next
- what triggers each refactor
- how to refactor incrementally without stalling product work

This is not a rewrite plan. It is a sequence of small structural moves that preserve the current V1 delivery pace.

## Inputs
This map is based on:
- [current-code-shape.md](/Users/daniel.dev/Desktop/czech-go-system/docs/architecture/current-code-shape.md)
- current feature docs
- current screen docs
- `code-review-graph` statistics and large-function analysis from `2026-04-21`

## Guiding Rule
Refactor only when one of these is true:
- a file is becoming the main blocker for the next feature
- the current shape makes contracts harder to keep stable
- mock boundaries are about to become real integrations
- testing or verification is materially harder because responsibilities are mixed

Do **not** refactor just because the current code is not elegant enough yet.

## What Should Not Be Refactored Yet

### Keep the repo split by surface
Do not collapse or reshuffle:
- `backend/`
- `cms/`
- `flutter_app/`

The monorepo shape is already clear and useful.

### Keep the backend monolithic
Do not introduce:
- microservices
- queue-driven orchestration
- multiple deployable backend packages

V1 does not need that complexity.

### Keep the CMS thin
Do not build:
- a generic schema form engine
- a workflow-heavy admin platform
- a component library for hypothetical future screens

### Keep Flutter simple
Do not add:
- elaborate state-management frameworks just yet
- generic recording coordinators before real recording lands
- a shared navigation abstraction for screens that do not exist yet

## Refactor Priorities

## Priority 0: Refactor Only When Real Integrations Arrive
These are the highest-value refactors once mock boundaries turn real.

### P0-A: Extract backend attempt orchestration from `server.go`
Current pressure:
- [backend/internal/httpapi/server.go](/Users/daniel.dev/Desktop/czech-go-system/backend/internal/httpapi/server.go) currently handles routing, auth, learner APIs, admin APIs, mock scoring, and helpers

Refactor trigger:
- real audio upload handling lands
- real STT lands
- scoring pipeline stops being mock-only

Target shape:
- HTTP handlers remain in `server.go` or an HTTP package
- attempt orchestration moves to a backend service layer

Suggested first slice:
1. introduce an `AttemptService` interface
2. move `create attempt`, `recording started`, `upload complete`, and `get attempt` coordination behind the service
3. keep request and response payloads unchanged

Do not do yet:
- split every endpoint into separate files all at once
- change API contracts during the refactor

### P0-B: Replace `MemoryStore` with a persistence-backed repository boundary
Current pressure:
- [backend/internal/store/memory.go](/Users/daniel.dev/Desktop/czech-go-system/backend/internal/store/memory.go) mixes seed content, auth tokens, exercise state, attempt state, and mock session data

Refactor trigger:
- Postgres work begins
- exercises and attempts need persistence across restarts

Target shape:
- repository interfaces for:
  - content
  - attempts
  - mock exam sessions
- in-memory implementation can remain for local/dev if useful

Suggested first slice:
1. define repository interfaces around the read/write methods already used by handlers
2. adapt the current memory store to satisfy those interfaces
3. add a Postgres implementation after the interfaces are already in place

Do not do yet:
- replace everything in one pass
- remove the memory implementation before persistence is stable

## Priority 1: Refactor Before the Next Big UI Expansion
These moves should happen before adding too much more UI logic.

### P1-A: Split Flutter practice flow out of `main.dart`
Current pressure:
- [flutter_app/lib/main.dart](/Users/daniel.dev/Desktop/czech-go-system/flutter_app/lib/main.dart) contains shell, module cards, exercise flow, polling, and result rendering
- graph sees `21` nodes in this file

Refactor trigger:
- real microphone recording lands
- `Uloha 3` and `Uloha 4` get learner screens
- result UI becomes richer

Target shape:
- `main.dart` becomes app shell entry only
- learner home screen moves to a dedicated file
- exercise practice screen moves to a dedicated file
- result card moves to a reusable widget file

Suggested first slice:
1. extract `LearnerShell` and `_ModuleCard`
2. extract `ExerciseScreen` and `_ResultCard`
3. keep `ApiClient` and payload models unchanged

Do not do yet:
- introduce a large state framework only to support the extraction

### P1-B: Split the CMS dashboard into screen shell plus subcomponents
Current pressure:
- [cms/components/exercise-dashboard.tsx](/Users/daniel.dev/Desktop/czech-go-system/cms/components/exercise-dashboard.tsx) is the largest graph-flagged function in the repo at `228` lines
- it contains load, save, form, list, and feedback UI together

Refactor trigger:
- edit support is added
- asset upload is added
- more `Uloha` types require task-specific forms

Target shape:
- dashboard shell
- exercise list component
- create/edit form component
- shared API client or CMS-side fetch helpers

Suggested first slice:
1. extract exercise list rendering
2. extract the `Uloha 1` create form
3. keep data fetching in the parent until a second screen appears

Do not do yet:
- create a form-builder abstraction
- generalize for every future exercise type upfront

## Priority 2: Refactor When Product Breadth Increases
These are useful later, but should not preempt current feature delivery.

### P2-A: Split admin and learner backend handlers
Current pressure:
- admin and learner APIs still live together in `server.go`

Refactor trigger:
- CMS grows beyond one dashboard
- admin auth rules and learner auth rules diverge

Target shape:
- learner handler module
- admin handler module
- shared middleware and response helpers

### P2-B: Introduce domain-specific backend packages
Refactor trigger:
- content management becomes more complex
- attempt and scoring logic deepen significantly

Potential domains:
- `content`
- `attempts`
- `scoring`
- `auth`

### P2-C: Add richer Flutter feature folders
Refactor trigger:
- more than one meaningful learner flow exists
- attempt history, mock exam, and multiple exercise types all live at once

Potential folders:
- `features/home`
- `features/exercise_practice`
- `features/mock_exam`
- `widgets/result`

## Refactor Order
Use this order unless product needs force a different one:

1. backend attempt service extraction
2. backend repository interface boundary
3. Flutter `main.dart` split
4. CMS dashboard split
5. backend admin/learner handler split
6. broader domain packaging

Why this order:
- backend contracts are the most likely place where real integrations will create pressure first
- Flutter and CMS can tolerate their current shapes slightly longer than the backend can tolerate real infra work inside the HTTP layer

## Incremental Refactor Slices

## Slice Pattern For Backend
Use this sequence:
1. create interface
2. adapt current implementation
3. route one endpoint through the new boundary
4. verify contracts stay stable
5. migrate the next endpoint

This avoids a big-bang rewrite.

## Slice Pattern For Flutter
Use this sequence:
1. extract one widget tree into a new file
2. keep all constructor arguments explicit
3. rerun analyze and tests
4. extract the next widget

Do not combine file extraction with behavior changes in the same slice.

## Slice Pattern For CMS
Use this sequence:
1. extract presentational subcomponent
2. keep mutation logic in the parent
3. verify build and lint
4. only then consider moving data calls into helper functions

## Acceptance Criteria For A Good Refactor
A refactor is successful when:
- the external API contract did not break unless intentionally changed
- the relevant build and tests still pass
- the number of responsibilities in the touched file is visibly reduced
- the next planned feature becomes easier to land

It is not successful if:
- the file count went up but complexity stayed the same
- abstractions were added without reducing future implementation risk
- the repo became harder to understand

## Warning Signs That A Refactor Is Premature
- the current file is large but still easy to change
- no next feature is blocked by the current shape
- the refactor would introduce more concepts than it removes
- the team would need to rewrite docs more than code

## Warning Signs That A Refactor Is Overdue
- feature changes repeatedly touch the same oversized file
- mocks are being replaced by real integrations inside mixed-responsibility code
- verification is getting slower because every change touches too much
- one file has become the default place to put unrelated new logic

## Verification Checklist
Before doing a refactor slice:
- confirm the specific trigger exists
- identify the exact file and responsibility being extracted
- confirm contracts that must stay stable

After a refactor slice:
- run the relevant checks
- update docs if the code shape meaningfully changed
- note what responsibility was removed from the old file

## Immediate Recommendation
Do not start with a large cleanup pass.

The best next refactor, when the next real integration begins, is:
1. extract backend attempt orchestration from `server.go`
2. then split Flutter practice flow out of `main.dart`

That sequence preserves V1 speed while reducing the two most likely pressure points before they turn into expensive tangles.
