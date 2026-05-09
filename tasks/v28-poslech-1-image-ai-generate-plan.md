# V28 Poslech 1 AI Image Generate — Plan

**Spec**: [docs/specs/poslech-1-image-ai-generate.md](../docs/specs/poslech-1-image-ai-generate.md)
**Idea**: [docs/ideas/poslech-1-image-ai-generate.md](../docs/ideas/poslech-1-image-ai-generate.md)
**Todo**: [v28-poslech-1-image-ai-generate-todo.md](v28-poslech-1-image-ai-generate-todo.md)
**Last updated:** 2026-05-10

## Approach

Tiny CMS-only slice. 2 phase.

- **Phase A** (PoslechFields wire ~30 LOC + test ~50 LOC): render
  `<AiImageButton>` per option key in P12 branch. Wire callback to
  patch `state.items[i].img{K}`.
- **Phase B** (docs ~30 LOC): reference + CHANGELOG + SPEC digest +
  spec status flip.

Backend + Flutter zero change. No new endpoint, no schema migration.

**Critical invariant:**
- V27 wire shape unchanged. AiImageButton callback hands back
  `assetId: string`; PoslechFields uses it to populate the same
  `imgK` field V27 already round-trips through `image_asset_id`.
- 4 buttons per item, 5 items → 20 button instances. AiImageButton
  uses `display: 'contents'` so idle DOM is tiny.

## Dependency Graph

```
A (PoslechFields wire) ──→ B (docs ship)
```

## Phase A — PoslechFields AiImageButton wire

| # | Task | Acceptance |
|---|---|---|
| A1 | RED: wire test — simulate callback updates state.items[i].imgK | Test FAILS until callback wired |
| A1 | GREEN: import AiImageButton + render per option K below img input. Wire `onAssetCreated={(r) => patch({ [\`img${K}\`]: r.assetId })}` | Test PASSES |
| A2 | RED: isolation test — generate item 0 A doesn't touch item 1 A or item 0 B | Test ensures patch scoped correctly |
| A3 | RED: disabled test when editingId null | AiImageButton receives disabled=true |
| A. | Verify: full CMS test suite + lint clean | `npm test` + `make cms-lint` |

**Files:**
- `cms/components/exercise-form/PoslechFields.tsx` (~30 LOC modified)
- `cms/__tests__/poslech-image-options.test.ts` (extend, ~80 LOC tests)

## Phase B — Docs ship

| # | Task | Acceptance |
|---|---|---|
| B1 | Update `docs/reference/content-and-attempt-model.md` § listening: V28 AI-generate per option | Diff: existing V27 line gains V28 note |
| B2 | CHANGELOG V28 entry | Format mirror V27 |
| B3 | SPEC.md digest row V28 | 1 row |
| B4 | Spec status: Draft → Shipped | header line |

**Files:**
- `docs/reference/content-and-attempt-model.md`
- `CHANGELOG.md`
- `SPEC.md`
- `docs/specs/poslech-1-image-ai-generate.md`

## Verification

- Phase A: `cd cms && npm test -- poslech-image-options` + `make cms-lint`
- Phase B: visual review docs
- Final: `make verify` (regression — backend + flutter unchanged so
  no surprise expected)

## Out of scope

- ❌ poslech_2/3/4 AI generate
- ❌ Backend endpoint changes
- ❌ Flutter changes
- ❌ Bulk generate (1 prompt → 4 variations)
- ❌ Prompt template auto-fill from option text
- ❌ Rate limit improvements
