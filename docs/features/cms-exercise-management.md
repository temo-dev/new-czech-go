# Feature: CMS Exercise Management

## Purpose
This feature gives the team a thin content desk for listing existing exercises and creating new `Uloha 1` exercises against the current backend contracts.

## User Flow
1. Admin opens the CMS homepage.
2. CMS loads existing exercises from the backend.
3. Admin fills the create form for a `Uloha 1` exercise.
4. CMS submits the new exercise to the backend.
5. CMS refreshes the list and shows the new draft exercise.

## Surfaces
- `Next.js CMS`
- `Go backend`

## Main Files
- [cms/app/page.tsx](/Users/daniel.dev/Desktop/czech-go-system/cms/app/page.tsx)
- [cms/components/exercise-dashboard.tsx](/Users/daniel.dev/Desktop/czech-go-system/cms/components/exercise-dashboard.tsx)
- [backend/internal/httpapi/server.go](/Users/daniel.dev/Desktop/czech-go-system/backend/internal/httpapi/server.go)
- [backend/internal/store/memory.go](/Users/daniel.dev/Desktop/czech-go-system/backend/internal/store/memory.go)

## Graph Notes
`code-review-graph` shows that the CMS feature is intentionally thin right now:
- `cms/components/exercise-dashboard.tsx` contains `4` graph nodes: the file itself, `ExerciseDashboard`, `loadExercises`, and `handleSubmit`
- most CMS behavior currently fans into backend handlers rather than internal CMS abstractions

That is appropriate for V1, but it also means future work such as edit flows, asset upload, and richer task-specific forms will likely expand this component quickly unless the CMS is split into smaller components.

## APIs Involved
- `GET /v1/admin/exercises`
- `POST /v1/admin/exercises`
- `GET /v1/admin/exercises/:exercise_id`
- `PATCH /v1/admin/exercises/:exercise_id`

## Current Status
Implemented today:
- exercise listing
- create form for `Uloha 1`
- admin token based access against the in-memory backend

Not implemented yet:
- edit screen
- asset upload flow
- scoring template editor
- publish workflow
- richer validation per task type

## Data Touchpoints
- exercise common fields
- `Uloha 1` prompt questions
- draft status
- scoring preview metadata

## Out Of Scope
- multi-user content workflow
- approvals
- role delegation
- analytics dashboard

## Risks
- CMS currently depends on a hard-coded admin token for local iteration
- form coverage is only good enough for the first slice

## Next Step
Add task-specific edit screens and persist exercises in Postgres so CMS data survives backend restarts.
