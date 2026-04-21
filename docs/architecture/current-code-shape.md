# Current Code Shape

## Purpose
This document captures the current code shape of the repository as it exists today.

It is not a target architecture. It is a graph-backed snapshot of:
- how the code is currently split
- where logic is concentrated
- which files are acting as early architectural anchors
- where future extraction pressure is likely to appear

This snapshot is based on `code-review-graph` data from `2026-04-21`.

## Graph Snapshot
From the current graph build:
- `19` files parsed
- `138` total nodes
- `616` total edges
- `83` functions
- `36` classes
- `19` file nodes

Languages currently present in the repo:
- `go`
- `javascript`
- `typescript`
- `tsx`
- `dart`
- `swift`
- `c`
- `objc`
- `bash`

Interpretation:
- the codebase is still small
- most architectural weight is in application files, not in a deep module tree
- the graph is useful for structure inspection, but the repo is not yet large enough to show meaningful communities

## High-Level Shape
The repository currently has three active product surfaces:
- `backend/` for the Go API and mock orchestration
- `cms/` for the Next.js content desk
- `flutter_app/` for the learner experience

This is a valid early monorepo shape for V1.

The current architectural style is:
- contract-first
- vertical-slice oriented
- intentionally monolithic inside each surface
- mock-heavy at the infrastructure boundary

That is the right bias for the current phase.

## Surface Breakdown

## Backend
The backend is the current coordination center of the system.

Graph-backed observations:
- [backend/internal/httpapi/server.go](/Users/daniel.dev/Desktop/czech-go-system/backend/internal/httpapi/server.go) contains `31` graph nodes
- [backend/internal/store/memory.go](/Users/daniel.dev/Desktop/czech-go-system/backend/internal/store/memory.go) contains `22` graph nodes
- [backend/internal/contracts/types.go](/Users/daniel.dev/Desktop/czech-go-system/backend/internal/contracts/types.go) holds shared response and payload types

What that means:
- `server.go` currently owns a wide span of responsibilities:
  - route registration
  - auth handling
  - learner endpoints
  - admin endpoints
  - attempt progression
  - mock scoring orchestration
  - response helpers
- `memory.go` currently owns:
  - seed data
  - in-memory persistence
  - exercise CRUD state
  - attempt lifecycle mutations

This split is understandable for the first slice, but it also means the backend currently has two gravity wells:
- transport/orchestration in `server.go`
- state/data logic in `memory.go`

## CMS
The CMS is intentionally thin right now.

Graph-backed observations:
- [cms/components/exercise-dashboard.tsx](/Users/daniel.dev/Desktop/czech-go-system/cms/components/exercise-dashboard.tsx) contains `4` graph nodes
- those nodes are:
  - file
  - `ExerciseDashboard`
  - `loadExercises`
  - `handleSubmit`

What that means:
- the CMS is still a single-screen admin surface
- it is not yet decomposed into smaller presentational and data modules
- almost all meaningful behavior is still concentrated in one component

That is fine for V1 because the CMS is supposed to remain a thin content desk rather than become a second product.

## Flutter Learner App
The learner app currently concentrates most UI and flow logic in one main file plus a small API client.

Graph-backed observations:
- [flutter_app/lib/main.dart](/Users/daniel.dev/Desktop/czech-go-system/flutter_app/lib/main.dart) contains `21` graph nodes
- [flutter_app/lib/api_client.dart](/Users/daniel.dev/Desktop/czech-go-system/flutter_app/lib/api_client.dart) contains `12` graph nodes

Important nodes inside `main.dart`:
- `MluveniSprintApp`
- `LearnerShell`
- `_LearnerShellState`
- `_bootstrap`
- `_ModuleCard`
- `ExerciseScreen`
- `_ExerciseScreenState`
- `_startRecording`
- `_stopRecording`
- `_ResultCard`

What that means:
- the learner app currently combines:
  - app shell
  - content loading
  - navigation
  - attempt orchestration
  - polling
  - result rendering
- this is acceptable for the first working slice
- this file will become the main refactor candidate once real audio and more task types arrive

## Large Function Hotspots
`code-review-graph` flagged the following larger functions with `>= 25` lines:

1. `ExerciseDashboard` in [cms/components/exercise-dashboard.tsx](/Users/daniel.dev/Desktop/czech-go-system/cms/components/exercise-dashboard.tsx) at `228` lines
2. `NewMemoryStore` in [backend/internal/store/memory.go](/Users/daniel.dev/Desktop/czech-go-system/backend/internal/store/memory.go) at `93` lines
3. `handleAdminExerciseByID` in [backend/internal/httpapi/server.go](/Users/daniel.dev/Desktop/czech-go-system/backend/internal/httpapi/server.go) at `55` lines
4. `simulateScoring` in [backend/internal/httpapi/server.go](/Users/daniel.dev/Desktop/czech-go-system/backend/internal/httpapi/server.go) at `50` lines
5. `handleAdminExercises` in [backend/internal/httpapi/server.go](/Users/daniel.dev/Desktop/czech-go-system/backend/internal/httpapi/server.go) at `48` lines
6. `handleSubmit` in [cms/components/exercise-dashboard.tsx](/Users/daniel.dev/Desktop/czech-go-system/cms/components/exercise-dashboard.tsx) at `39` lines
7. `UpdateExercise` in [backend/internal/store/memory.go](/Users/daniel.dev/Desktop/czech-go-system/backend/internal/store/memory.go) at `34` lines
8. `handleAttempts` in [backend/internal/httpapi/server.go](/Users/daniel.dev/Desktop/czech-go-system/backend/internal/httpapi/server.go) at `30` lines

Interpretation:
- the codebase is not broadly overgrown yet
- the current pressure points are exactly where you would expect in an early vertical slice:
  - the main CMS screen
  - the in-memory backend seed/store
  - the backend HTTP adapter

## What Is Structurally Good Right Now
- the repo is split cleanly by product surface
- docs already exist for idea, plan, specs, features, and screens
- the backend has a clear contracts package
- the Flutter app already separates API calls into `api_client.dart`
- the CMS is intentionally thin rather than prematurely abstracted
- the codebase is small enough to refactor safely before deeper dependencies harden

## What Is Structurally Fragile Right Now
- backend HTTP and domain orchestration are still tightly mixed in `server.go`
- backend seed data and state mutation are tightly mixed in `memory.go`
- Flutter shell and exercise flow still live in one large UI file
- CMS form, list, and network logic all live in one component
- the graph shows low structural depth, which is good for speed now but means future changes can quickly overload the current files

## Current Architectural Pattern
The code shape today can be summarized as:

### Repository level
- multi-surface monorepo

### Backend level
- monolithic service
- transport layer with embedded orchestration
- in-memory repository pattern

### CMS level
- single-screen dashboard
- component-local data fetching and mutation

### Flutter level
- single-flow shell
- API client plus stateful screen widgets

This is a healthy early-stage shape for contract validation and fast iteration.

## Refactor Pressure To Expect Next
If the next milestones are:
- real audio recording
- real upload to storage
- real STT
- persisted attempts and exercises
- more oral task types

then the most likely extraction points are:

### Backend
- split route registration from handler logic
- move attempt orchestration into a service layer
- replace `MemoryStore` with a persistent repository interface
- isolate scoring orchestration from HTTP handlers

### CMS
- split screen shell from the exercise form
- split list rendering from mutation logic
- introduce task-specific form components as more `Uloha` types arrive

### Flutter
- move learner shell and exercise practice into separate files
- extract attempt state orchestration from widget tree code
- separate result rendering from recording flow logic

## Suggested Next Structural Moves
These are the smallest high-value structural moves that preserve the current V1 speed:

1. Keep contracts stable, but add a backend service layer for attempts before real storage and STT land.
2. Extract Flutter practice flow into its own file before adding real audio recording.
3. Split the CMS dashboard into at least:
   - page shell
   - exercise list
   - create form
4. Keep `server.go` as the HTTP edge only as soon as real integrations begin.

## Limitations Of This Snapshot
- `code-review-graph` did not identify meaningful communities yet because the repo is still small and post-processing was minimal.
- Hub and bridge graph tools were not usable in this run due to tool-side resolution errors, so this document leans on graph stats, file summaries, and large-function analysis instead.
- This is a snapshot of current code shape, not a guarantee of long-term architecture quality.

## Bottom Line
The current code shape is good for the phase the project is in.

It is:
- small
- understandable
- vertically sliced
- fast to change

It is also clearly approaching the point where:
- `server.go`
- `memory.go`
- `main.dart`
- `exercise-dashboard.tsx`

will become the first files worth splitting.

That is not a problem yet. It is simply the next natural step once the mock boundaries turn real.
