# V28 Poslech 1 AI Image Generate — Todo

**Plan:** [v28-poslech-1-image-ai-generate-plan.md](v28-poslech-1-image-ai-generate-plan.md)
**Spec:** [docs/specs/poslech-1-image-ai-generate.md](../docs/specs/poslech-1-image-ai-generate.md)
**Status:** In progress (started 2026-05-10)

## Phase A — PoslechFields AiImageButton wire

- [ ] A1. RED: wire callback updates state.items[i].imgK
- [ ] A1. GREEN: import + render AiImageButton per option K
- [ ] A1. Verify: callback test passes
- [ ] A2. RED: isolation test
- [ ] A2. Verify: per-item per-option independent
- [ ] A3. RED: disabled state
- [ ] A3. Verify: disabled prop wired
- [ ] A. CMS regression: `npm test`
- [ ] A. Lint: `make cms-lint`
- [ ] A. Commit: `feat(v28-A): CMS PoslechFields AI image generate per option`

## Phase B — Docs ship

- [ ] B1. Update `docs/reference/content-and-attempt-model.md` § listening
- [ ] B2. CHANGELOG V28 entry
- [ ] B3. SPEC.md digest row V28
- [ ] B4. Spec status: Draft → Shipped
- [ ] B. Commit: `docs(v28-ship): CHANGELOG + reference + SPEC digest`

## Final ship

- [ ] `make verify` (regression)
- [ ] Manual smoke: generate 1 ảnh per option, save published, reload edit, verify image_asset_id persisted.
- [ ] Manual smoke: Flutter render 2×2 image grid với AI-generated images.

## Acceptance criteria checklist (from spec)

- [ ] A1. AiImageButton render per option key K ∈ {A,B,C,D}
- [ ] A2. existingAssetId, disabled, onAssetCreated wired correctly
- [ ] A3. imgK update triggers buildPoslechDetail re-emit
- [ ] B1. Wire callback test
- [ ] B2. State isolation test
- [ ] B3. Disabled state test
- [ ] C1. Reference doc updated
- [ ] C2. CHANGELOG entry shipped
- [ ] C3. SPEC digest row added
