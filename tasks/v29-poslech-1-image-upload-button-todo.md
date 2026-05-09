# V29 Poslech 1 Image Upload Button — Todo

**Plan:** [v29-poslech-1-image-upload-button-plan.md](v29-poslech-1-image-upload-button-plan.md)
**Spec:** [docs/specs/poslech-1-image-upload-button.md](../docs/specs/poslech-1-image-upload-button.md)
**Status:** In progress (started 2026-05-10)

## Phase A — PoslechFields upload wire

- [ ] A1. RED: parseUploadResponse helper test
- [ ] A1. GREEN: implement helper in poslech-model.ts
- [ ] A2. Add handleP12ImageUpload async handler
- [ ] A3. Add UI per option K: hidden input + label button
- [ ] A. Verify: npm test + make cms-{lint,build}
- [ ] A. Commit: `feat(v29-A): CMS PoslechFields manual image upload per option`

## Phase B — Docs ship

- [ ] B1. Update content-and-attempt-model.md
- [ ] B2. CHANGELOG V29 entry
- [ ] B3. SPEC.md digest row
- [ ] B4. Spec status flip
- [ ] B. Commit: `docs(v29-ship): CHANGELOG + reference + SPEC digest`

## Final ship

- [ ] make verify
- [ ] Manual smoke: upload .jpg per option → save → reload → imgK persisted
