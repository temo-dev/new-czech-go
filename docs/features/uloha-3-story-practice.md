# Feature: Uloha 3 Story Practice

## Purpose
This feature lets the learner open a story narration task, review the story title plus narrative checkpoints, record one spoken attempt, and receive transcript plus feedback through the same attempt pipeline already used by `Uloha 1` and `Uloha 2`.

## User Flow
1. Learner opens the Flutter app.
2. Learner opens a `Uloha 3` exercise from the module list.
3. Learner reviews the story title and the checkpoints the narration should cover.
4. Learner records one spoken attempt.
5. Backend transcribes, scores, and returns transcript plus feedback.

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

## Current Status
Implemented today:
- typed backend contract for `Uloha3Detail`
- seeded `Uloha 3` sample exercise detail in the backend store
- admin create flow in the CMS for `Uloha 3`
- CMS edit/delete flow for `Uloha 3`
- CMS local image upload plus preview for `Uloha 3` prompt assets
- uploaded asset ids can now be inserted into the `image_asset_ids` list directly from the CMS
- Flutter parsing for `story_title`, `image_asset_ids`, `narrative_checkpoints`, and `grammar_focus`
- learner UI rendering for story narration checkpoints
- learner UI now resolves `image_asset_ids` through registered `assets` and renders the prompt images in the exercise screen

Still simplified:
- scoring still uses the current heuristic story evaluation
- prompt assets currently live in local CMS/backend storage for authoring preview, not a production object-storage flow

## Risks
- `Uloha 3` still needs real prompt-image asset handling before it fully matches the intended exam presentation
- narration quality is still judged by the shared V1 scoring path, not a richer story-specific worker

## Next Step
Expand the same vertical slice pattern to `Uloha 4` so the app can cover all four V1 oral task types.
