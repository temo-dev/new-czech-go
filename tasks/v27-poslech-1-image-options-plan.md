# V27 Poslech 1 Image Options — Plan

**Spec**: [docs/specs/poslech-1-image-options.md](../docs/specs/poslech-1-image-options.md)
**Idea**: [docs/ideas/poslech-1-image-options.md](../docs/ideas/poslech-1-image-options.md)
**Todo**: [v27-poslech-1-image-options-todo.md](v27-poslech-1-image-options-todo.md)
**Last updated:** 2026-05-09

## Approach

CMS-only slice. 3 phase, no parallel paths needed (small scope).

- **Phase A** (CMS form ~80 LOC): extend `P12Item` state + buildDetail
  emit image_asset_id + UI pair (text + image_asset_id) per option.
- **Phase B** (CMS validation ~30 LOC): all-or-none rule per item.
- **Phase C** (docs ~40 LOC): reference + CHANGELOG + SPEC digest.

Backend + Flutter untouched. No migration, no API change.

**Critical invariant:**
- `image_asset_id` field optional throughout — empty string serialised
  as omitted (preserve V26 wire shape for old data).
- Drafts allow partial state.
- Published exercises enforce all-or-none per item.

**Critical kill switch:** if Phase A round-trip test fails (state
loses image_asset_id), Phase B/C don't start. Build/CMS test gate.

## Dependency Graph

```
A (CMS form) ──→ B (validation) ──→ C (docs)
```

## Phase A — CMS PoslechFields image fields

| # | Task | Acceptance |
|---|---|---|
| A1 | RED: round-trip test (load detail with image_asset_ids → state → buildDetail → match) | Test FAILS until P12Item has imgA-D |
| A1 | GREEN: extend `P12Item` type with imgA-D fields. initState reads `options[*].image_asset_id`. buildDetail emits `image_asset_id` when non-empty | Round-trip test PASSES |
| A2 | UI: render image_asset_id input next to each text option in P12 branch | Visual check: 4 pair rows per item |
| A3 | RED: poslech_2 cross-pollution test (poslech_2 detail without image_asset_id round-trips clean) | Test PASSES (poslech_2 path unchanged) |

**Files:**
- `cms/components/exercise-form/PoslechFields.tsx` (~50 LOC modified)
- `cms/__tests__/exercise-utils.test.ts` or new `poslech-image.test.ts` (~80 LOC)

## Phase B — CMS validation all-or-none

| # | Task | Acceptance |
|---|---|---|
| B1 | RED: validation test with 2/4 image_asset_ids set → expect error | Test FAILS until rule added |
| B1 | GREEN: add rule in `validation.ts` poslech_1 branch — count item-level image_asset_ids; reject when ∈ {1,2,3} | Test PASSES |
| B2 | RED: validation test with 0 set → no error; 4 set → no error | Tests PASS already-or-after-fix |
| B3 | RED: drafts skip rule | Verified by Status check or pass status='draft' fixture |

**Files:**
- `cms/components/exercise-form/validation.ts` (~20 LOC modified)
- `cms/__tests__/exercise-quick-fix.test.ts` or extend ^^ (~50 LOC)

## Phase C — Docs ship

| # | Task | Acceptance |
|---|---|---|
| C1 | Update `docs/reference/content-and-attempt-model.md` § listening | Diff: poslech_1 entry mentions image_asset_id since V27 |
| C2 | CHANGELOG V27 entry | Format mirror V26 |
| C3 | SPEC.md digest row V27 | 1 row added |
| C4 | Spec status flip Draft → Shipped | `Status:` line updated |

**Files:**
- `docs/reference/content-and-attempt-model.md`
- `CHANGELOG.md`
- `SPEC.md`
- `docs/specs/poslech-1-image-options.md`

## Verification

- Phase A: `cd cms && npm test -- poslech` (focused) + `make cms-lint`
- Phase B: `cd cms && npm test -- validation` + lint
- Phase C: `make cms-build` (visual sanity)
- Final: `make verify` full backend + cms + flutter (regression)

## Out of scope

- ❌ poslech_2/3/4 image options
- ❌ Backend types (V11 already supports)
- ❌ Flutter render (MultipleChoiceWidget already supports)
- ❌ File upload UX (admin paste asset_id from existing uploader)
- ❌ Seed image data
- ❌ V22 content health rule mixed state
