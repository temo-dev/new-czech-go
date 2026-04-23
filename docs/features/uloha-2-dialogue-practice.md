# Feature: Uloha 2 Dialogue Practice

## Purpose
This feature lets the learner open a dialogue-style oral task, see the scenario card, identify the required information slots, record one spoken attempt, and receive transcript plus feedback through the same attempt pipeline already used by `Uloha 1`.

## User Flow
1. Learner opens the Flutter app.
2. Learner sees a seeded or CMS-created `Uloha 2` exercise in the module list.
3. Learner opens the exercise and reads the scenario card.
4. Learner reviews the required information slots and the extra-question hint.
5. Learner records and uploads one spoken attempt.
6. Backend transcribes, scores, and returns transcript plus feedback.
7. When the shared review artifact is ready, the learner can see corrected question forms, a stronger model question sequence, speaking-focus hints, and retry from the same exercise.

## Surfaces
- `Flutter`
- `Go backend`
- `Next.js CMS`

## Main Files
- [flutter_app/lib/main.dart](/Users/daniel.dev/Desktop/czech-go-system/flutter_app/lib/main.dart)
- [flutter_app/lib/models.dart](/Users/daniel.dev/Desktop/czech-go-system/flutter_app/lib/models.dart)
- [flutter_app/test/models_test.dart](/Users/daniel.dev/Desktop/czech-go-system/flutter_app/test/models_test.dart)
- [backend/internal/contracts/types.go](/Users/daniel.dev/Desktop/czech-go-system/backend/internal/contracts/types.go)
- [backend/internal/httpapi/server.go](/Users/daniel.dev/Desktop/czech-go-system/backend/internal/httpapi/server.go)
- [backend/internal/store/exercise_store.go](/Users/daniel.dev/Desktop/czech-go-system/backend/internal/store/exercise_store.go)
- [cms/components/exercise-dashboard.tsx](/Users/daniel.dev/Desktop/czech-go-system/cms/components/exercise-dashboard.tsx)

## APIs Involved
- `GET /v1/modules/:module_id/exercises`
- `GET /v1/exercises/:exercise_id`
- `POST /v1/admin/exercises`
- `POST /v1/attempts`
- `POST /v1/attempts/:attempt_id/recording-started`
- `POST /v1/attempts/:attempt_id/upload-url`
- `POST /v1/attempts/:attempt_id/upload-complete`
- `GET /v1/attempts/:attempt_id`
- `GET /v1/attempts/:attempt_id/review`
- `GET /v1/attempts/:attempt_id/review/audio/file`

## Current Status
Implemented today:
- typed backend contract for `Uloha2Detail`
- seeded `Uloha 2` sample exercise in the backend store
- admin create flow in the CMS for `Uloha 2`
- Flutter parsing for `scenario_title`, `scenario_prompt`, `required_info_slots`, and `custom_question_hint`
- learner UI rendering for the dialogue scenario and required slot checklist
- shared attempt-result rendering for the `Repair and shadowing` block after a completed attempt
- backend review generation for `Uloha 2` that keeps corrected/model output in question form and can fill missing required slots from the seeded slot questions

Still simplified:
- scoring still uses the current heuristic dialogue evaluation
- `Uloha 2` still uses the shared review/result screen rather than a dedicated dialogue compare surface
- the CMS still uses one compact dashboard instead of a richer edit screen

## Risks
- `Uloha 2` content validation is still intentionally light and only checks the required scenario fields
- learner feedback and review generation for `Uloha 2` are still heuristic and tied to slot/question cues, not a richer rubric-specific worker

## Next Step
Add retry-history compare so a second `Uloha 2` attempt can be read against the previous review artifact instead of only seeing the newest result card.
