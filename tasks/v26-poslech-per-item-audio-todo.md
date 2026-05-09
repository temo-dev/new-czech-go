# V26 Poslech Per-item Audio — Todo

**Plan:** [v26-poslech-per-item-audio-plan.md](v26-poslech-per-item-audio-plan.md)
**Spec:** [docs/specs/poslech-per-item-audio.md](../docs/specs/poslech-per-item-audio.md)
**Status:** In progress (started 2026-05-09)

## Phase A — Backend foundation

- [ ] A1. RED: write failing test for `BuildExerciseItemTexts(poslech_1)` → returns 5 items
- [ ] A1. GREEN: implement `BuildExerciseItemTexts` in `exercise_audio.go`
- [ ] A1. Verify regression: `make backend-test`
- [ ] A2. RED: write failing test for `GenerateItemAudio` storage key
- [ ] A2. GREEN: implement `GenerateItemAudio` method
- [ ] A2. Verify regression: `make backend-test`
- [ ] A3. RED: write test for `ItemAudioGenerator` interface satisfaction
- [ ] A3. GREEN: declare interface; ensure Polly generator satisfies
- [ ] A3. Verify: `make backend-build` + `make backend-test`
- [ ] A. Commit: `feat(v26-A): per-item audio gen primitives`

## Phase B — Admin endpoint integration

- [ ] B1. RED: integration test POST `/v1/admin/exercises/:id/generate-audio` for poslech_1 → expects 5 asset_ids
- [ ] B1. GREEN: fork branch in `handleAdminGenerateAudio`
- [ ] B1. Verify: integration test passes
- [ ] B2. RED: rollback test (mock TTS fail at item 3)
- [ ] B2. GREEN: implement rollback (delete written files + skip persist)
- [ ] B2. Verify: rollback test passes
- [ ] B3. RED: assert response JSON shape contains `meta.item_count`
- [ ] B3. GREEN: emit field
- [ ] B3. Verify: shape test passes
- [ ] B. Verify backward compat: legacy poslech_1 (no asset_ids) generate path vẫn work
- [ ] B. Commit: `feat(v26-B): admin endpoint per-item audio + rollback`

## Phase C — Flutter render

- [ ] C1. Refactor `_AudioPlayerBar` accept `audioUri` param
- [ ] C1. Verify: existing tests pass (`make flutter-test`)
- [ ] C2. RED: unit test `_PlaybackCoordinator` notifier transitions
- [ ] C2. GREEN: implement coordinator
- [ ] C3. RED: widget test 5 per-item players visible khi all asset_ids set
- [ ] C3. GREEN: refactor `_buildItemAnswers` for per-item mode
- [ ] C4. RED: widget test 1 top-level player when asset_ids empty (legacy)
- [ ] C4. GREEN: fallback branch
- [ ] C5. Verify lazy load: smoke `make flutter-test` + manual device test
- [ ] C. Commit: `feat(v26-C): Flutter per-item player + legacy fallback`

## Phase D — Docs & CHANGELOG

- [ ] D1. Update `docs/reference/content-and-attempt-model.md` § listening
- [ ] D2. CHANGELOG V26 entry với file changes + test counts
- [ ] D3. SPEC.md digest table row V26
- [ ] D. Commit: `docs(v26): per-item audio reference + CHANGELOG`

## Final ship

- [ ] Run `make verify` (full test suite)
- [ ] Update spec status: `Draft` → `Shipped`
- [ ] Mark idea decided date confirmed
- [ ] Manual smoke: seed 1 poslech_1, click Generate audio in CMS, open Flutter → verify 5 players play independently
- [ ] Manual smoke legacy: existing seeded exercise → top-level player vẫn play

## Acceptance criteria checklist (from spec)

- [ ] A1. `BuildExerciseItemTexts` skip uploaded items, nil cho non-poslech_1
- [ ] A2. `GenerateItemAudio` storage key format correct
- [ ] B1. Admin endpoint generates 5 files + mutates detail
- [ ] B2. Rollback on partial failure (no orphan files, detail unchanged)
- [ ] C1. Per-item render mode khi all asset_ids set
- [ ] C4. Legacy fallback when no asset_ids
- [ ] D1. Backward compat: existing seeded poslech_1 vẫn play
- [ ] E1. Reference doc updated
- [ ] E2. CHANGELOG entry shipped
