# Screen: CMS Exercise Dashboard

## Surface
`Next.js CMS`

## Main Files
- [cms/app/page.tsx](/Users/daniel.dev/Desktop/czech-go-system/cms/app/page.tsx)
- [cms/components/exercise-dashboard.tsx](/Users/daniel.dev/Desktop/czech-go-system/cms/components/exercise-dashboard.tsx)

## Graph Notes
Graph inspection shows the CMS dashboard is currently a compact single-component screen with a few key internal action functions:
- `loadExercises`
- `handleSubmit`
- `startEditing`
- `handleDelete`

This is consistent with the intended V1 shape of a thin content desk rather than a fully segmented admin product.

## Purpose
This screen is the CMS control surface for the oral-task content desk. It lets the team inspect existing exercises and create, edit, or delete drafts for all four V1 oral tasks.

## What The User Sees
- CMS hero panel with intro copy and lightweight summary cards
- task-specific form for `Uloha 1` through `Uloha 4`
- existing exercise list
- edit and delete actions per exercise card
- cancel-edit state when the admin backs out of changes
- refresh action
- loading and error states

## Visual Direction
- same orange and neutral system as the learner app
- calmer, brighter admin panels instead of a heavy admin look
- slightly denser than Flutter, but still whitespace-first
- card-based summary and content list presentation

## Actions
- create exercise
- update exercise
- delete exercise
- refresh the exercise list

## Data Dependencies
- `GET /v1/admin/exercises`
- `POST /v1/admin/exercises`
- `PATCH /v1/admin/exercises/:exercise_id`
- `DELETE /v1/admin/exercises/:exercise_id`

## Main States
- loading
- error
- saving
- loaded

## Current Limitations
- edit happens inline in the same dashboard form, not in a dedicated detail screen
- no publish/archive controls in UI
- no asset upload UI
- admin auth is a local hard-coded token
- the summary cards are static product cues, not analytics backed by a metrics model

## Next Step
Add asset upload plus richer content preview so the inline dashboard can stay useful without becoming bloated.
