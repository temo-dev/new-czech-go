# Screen: Flutter Learner Shell

## Surface
`Flutter`

## Main File
- [flutter_app/lib/main.dart](/Users/daniel.dev/Desktop/czech-go-system/flutter_app/lib/main.dart)

## Graph Notes
`code-review-graph` shows this screen lives inside a larger all-in-one Flutter file:
- `LearnerShell`
- `_LearnerShellState`
- `_bootstrap`
- `_ModuleCard`

This means the shell screen currently owns both page bootstrapping and a chunk of reusable presentation logic.

## Purpose
This is the learner app home screen. It logs the learner into the demo backend, loads modules and exercises, and acts as the launch point for practice.

## What The User Sees
- app title
- learner greeting
- compact coaching pills that explain the product rhythm
- module cards
- exercise cards inside each module
- loading and retry states

## Visual Direction
- bright hero card on a white surface
- restrained orange used for CTA and key emphasis
- low-density spacing
- card-based module layout that matches the V1 design system

## Actions
- retry bootstrap if the app fails to load
- open an exercise from a module card

## Data Dependencies
- `POST /v1/auth/login`
- `GET /v1/modules`
- `GET /v1/modules/:module_id/exercises`

## Main States
- loading
- error
- loaded

## Current Limitations
- login is hard-coded to the demo learner
- no persisted auth session
- no history or day-progress entry point on this screen yet
- `14-day plan` context is still hinted at visually, not backed by a full progress model

## Next Step
Add visible `14-day plan` context and route history/mock exam entry points from the shell.
