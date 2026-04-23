# Feature: CMS Exercise Management

## Purpose
This feature gives the team a thin content desk for listing, creating, editing, and deleting `Uloha 1`, `Uloha 2`, `Uloha 3`, and `Uloha 4` exercises against the current backend contracts.

## User Flow
1. Admin opens the CMS homepage.
2. CMS loads existing exercises from the backend.
3. Admin chooses a task type and fills the task-specific form for one of the four V1 oral tasks.
4. CMS submits either a create or update request to the backend.
5. CMS refreshes the list and shows the saved draft exercise.
6. Admin can delete a draft or obsolete exercise directly from the inventory list.

## Surfaces
- `Next.js CMS`
- `Go backend`

## Main Files
- [cms/app/page.tsx](/Users/daniel.dev/Desktop/czech-go-system/cms/app/page.tsx)
- [cms/components/exercise-dashboard.tsx](/Users/daniel.dev/Desktop/czech-go-system/cms/components/exercise-dashboard.tsx)
- [backend/internal/httpapi/server.go](/Users/daniel.dev/Desktop/czech-go-system/backend/internal/httpapi/server.go)
- [backend/internal/store/exercise_store.go](/Users/daniel.dev/Desktop/czech-go-system/backend/internal/store/exercise_store.go)
- [backend/internal/store/postgres_exercises.go](/Users/daniel.dev/Desktop/czech-go-system/backend/internal/store/postgres_exercises.go)

## Graph Notes
`code-review-graph` shows that the CMS feature is intentionally thin right now:
- `cms/components/exercise-dashboard.tsx` remains the dominant node for this slice, with list loading, form submission, and inline edit/delete actions still centered in one place
- most CMS behavior currently fans into backend handlers rather than internal CMS abstractions

That is still appropriate for V1, but asset upload and richer content preview will likely be the first reasons to split the dashboard into smaller components.

## APIs Involved
- `GET /v1/admin/exercises`
- `POST /v1/admin/exercises`
- `GET /v1/admin/exercises/:exercise_id`
- `PATCH /v1/admin/exercises/:exercise_id`
- `DELETE /v1/admin/exercises/:exercise_id`

## Current Status
Implemented today:
- exercise listing
- create form for `Uloha 1`
- create form for `Uloha 2` with scenario title, scenario prompt, required info slots, and extra-question hint
- create form for `Uloha 3` with story title, image asset ids, narrative checkpoints, and grammar focus
- create form for `Uloha 4` with scenario prompt, options, and expected reasoning axes
- inline edit flow for all four oral task types from the same dashboard form
- inline delete flow from the exercise inventory list
- task-specific form reset/cancel behavior while editing
- local image upload and preview inside the CMS for `Uloha 3` and `Uloha 4`
- asset registration now persists `PromptAsset` metadata on the exercise record
- uploaded `Uloha 3` assets can be inserted straight into the image-id list from the same dashboard
- `Uloha 4` choice lines now support an optional fourth column for `image_asset_id`
- server-side proxy from the CMS to the backend admin API
- optional `HTTP Basic Auth` gate at the CMS web layer so the admin desk is not public-open in production
- exercise persistence can be backed by `Postgres` when `DATABASE_URL` is configured
- local default seed exercises are auto-inserted into `Postgres` on first startup so the CMS and learner shell still have demo content

Not implemented yet:
- scoring template editor
- publish workflow
- richer validation per task type
- durable object-storage-backed prompt assets for production authoring

## Data Touchpoints
- exercise common fields
- `Uloha 1` prompt questions
- `Uloha 2` scenario detail
- `Uloha 3` story detail
- `Uloha 4` choice detail
- draft status
- scoring preview metadata

## Out Of Scope
- multi-user content workflow
- approvals
- role delegation
- analytics dashboard

## Risks
- CMS still depends on a simple shared admin token between the Next.js layer and backend
- the CMS web layer is only protected if `CMS_BASIC_AUTH_USER` and `CMS_BASIC_AUTH_PASSWORD` are set in the runtime environment
- form coverage is only good enough for the first slice
- the backend still auto-creates the exercise schema on startup, so migration orchestration is not separated yet
- prompt-asset upload currently stores local files for CMS preview; production asset hardening is still a follow-up step

## Next Step
Add asset upload plus richer content preview so `Uloha 3` and `Uloha 4` can move beyond text-only authoring.
