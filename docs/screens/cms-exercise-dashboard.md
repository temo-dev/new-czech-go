# Screen: CMS Exercise Dashboard

## Surface
`Next.js CMS`

## Main Files
- [cms/app/page.tsx](/Users/daniel.dev/Desktop/czech-go-system/cms/app/page.tsx)
- [cms/components/exercise-dashboard.tsx](/Users/daniel.dev/Desktop/czech-go-system/cms/components/exercise-dashboard.tsx)

## Graph Notes
Graph inspection shows the CMS dashboard is currently a compact single-component screen with two internal action functions:
- `loadExercises`
- `handleSubmit`

This is consistent with the intended V1 shape of a thin content desk rather than a fully segmented admin product.

## Purpose
This screen is the first CMS control surface. It lets the team inspect existing exercises and create a new `Uloha 1` draft.

## What The User Sees
- CMS hero panel with intro copy and lightweight summary cards
- create form for a `Uloha 1` exercise
- existing exercise list
- refresh action
- loading and error states

## Visual Direction
- same orange and neutral system as the learner app
- calmer, brighter admin panels instead of a heavy admin look
- slightly denser than Flutter, but still whitespace-first
- card-based summary and content list presentation

## Actions
- create exercise
- refresh the exercise list

## Data Dependencies
- `GET /v1/admin/exercises`
- `POST /v1/admin/exercises`

## Main States
- loading
- error
- saving
- loaded

## Current Limitations
- no dedicated edit page
- no publish/archive controls in UI
- no asset upload UI
- admin auth is a local hard-coded token
- the summary cards are static product cues, not analytics backed by a metrics model

## Next Step
Add edit support and task-specific forms so the CMS can manage all four oral task types.
