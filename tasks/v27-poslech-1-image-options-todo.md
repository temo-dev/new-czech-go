# V27 Poslech 1 Image Options — Todo

**Plan:** [v27-poslech-1-image-options-plan.md](v27-poslech-1-image-options-plan.md)
**Spec:** [docs/specs/poslech-1-image-options.md](../docs/specs/poslech-1-image-options.md)
**Status:** In progress (started 2026-05-09)

## Phase A — CMS PoslechFields image fields

- [ ] A1. RED: round-trip test for P12Item with image_asset_ids
- [ ] A1. GREEN: extend `P12Item` type with imgA-D fields
- [ ] A1. GREEN: initState reads `options[*].image_asset_id`
- [ ] A1. GREEN: buildDetail emits `image_asset_id` when non-empty
- [ ] A1. Verify: round-trip test passes
- [ ] A2. UI: render image_asset_id input next to text option (P12 branch)
- [ ] A2. Verify: visual check via storybook or running CMS dev
- [ ] A3. RED: poslech_2 cross-pollution test (no image fields)
- [ ] A3. GREEN: state branch keeps poslech_2 isolated
- [ ] A3. Verify: tests pass
- [ ] A. Commit: `feat(v27-A): CMS PoslechFields image_asset_id per option`

## Phase B — CMS validation all-or-none

- [ ] B1. RED: validation test 2/4 set → error
- [ ] B1. GREEN: add rule in validation.ts poslech_1 branch
- [ ] B1. Verify: error message matches "Câu N: hoặc tất cả 4..."
- [ ] B2. RED: validation 0/4 → no error; 4/4 → no error
- [ ] B2. Verify: tests pass
- [ ] B3. Drafts skip rule check (status check)
- [ ] B. Commit: `feat(v27-B): CMS validation all-or-none image rule`

## Phase C — Docs ship

- [ ] C1. Update `docs/reference/content-and-attempt-model.md` § listening
- [ ] C2. CHANGELOG V27 entry
- [ ] C3. SPEC.md digest row V27
- [ ] C4. Spec status: Draft → Shipped
- [ ] C. Commit: `docs(v27-ship): CHANGELOG + reference + SPEC digest`

## Final ship

- [ ] `make cms-lint` + `make cms-build` + `cd cms && npm test`
- [ ] `make verify` (regression)
- [ ] Manual smoke: tạo poslech_1 trong CMS với 4 image_asset_id per item, save published; mở Flutter → verify 2×2 image grid.
- [ ] Manual smoke validation: nhập 2/4 ảnh → publish → verify error message.

## Acceptance criteria checklist (from spec)

- [ ] A1. P12Item extends imgA-D fields
- [ ] A2. initState reads image_asset_id from each option
- [ ] A3. buildDetail emits image_asset_id when set, omits when empty
- [ ] B1. UI: image_asset_id input rendered alongside text input
- [ ] C1. Validation: 1-3 set → error
- [ ] C2. Validation: 0 or 4 set → no error
- [ ] C3. Drafts skip rule
- [ ] D1. Round-trip test
- [ ] D2. Validation truth-table tests
- [ ] D3. poslech_2 cross-pollution test
- [ ] E1. content-and-attempt-model.md updated
- [ ] E2. CHANGELOG entry shipped
