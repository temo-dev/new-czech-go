# V29 Poslech 1 Image Upload Button — Plan

**Spec**: [docs/specs/poslech-1-image-upload-button.md](../docs/specs/poslech-1-image-upload-button.md)
**Idea**: [docs/ideas/poslech-1-image-upload-button.md](../docs/ideas/poslech-1-image-upload-button.md)
**Todo**: [v29-poslech-1-image-upload-button-todo.md](v29-poslech-1-image-upload-button-todo.md)
**Last updated:** 2026-05-10

## Approach

Tiny CMS-only slice. 2 phase.

- **Phase A** (PoslechFields wire ~80 LOC + test ~30 LOC): handler +
  hidden file input + label button per option K.
- **Phase B** (docs ship ~30 LOC): reference + CHANGELOG + SPEC.

Backend + Flutter zero change.

## Phase A — PoslechFields upload wire

| # | Task | Acceptance |
|---|---|---|
| A1 | RED: `parseUploadResponse(json)` test happy + missing field | Helper not yet exported → fail |
| A1 | GREEN: add `parseUploadResponse` to poslech-model.ts | Test passes |
| A2 | Add `handleP12ImageUpload` async handler in PoslechFields | Calls /assets/upload with FormData, returns asset_id, patches imgK |
| A3 | Add UI per option K: hidden file input + label button next to AiImageButton | Visual smoke OK |
| A. | Verify CMS test + lint + build clean | npm test + make cms-{lint,build} |

## Phase B — Docs ship

| # | Task | Acceptance |
|---|---|---|
| B1 | Update content-and-attempt-model.md § listening — V29 note | Diff small |
| B2 | CHANGELOG V29 entry | Mirror V28 |
| B3 | SPEC.md digest row V29 | 1 row |
| B4 | Spec status Draft → Shipped | Header line |

## Out of scope

- ❌ poslech_2/3/4
- ❌ Backend endpoint changes
- ❌ Flutter changes
- ❌ Drag-drop, multi-file, preview/crop UI
