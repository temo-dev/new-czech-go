import { describe, it, expect } from 'vitest';
import {
  initPoslechState,
  buildPoslechDetail,
  countItemImages,
  makeOptionImagePatcher,
  parseUploadResponse,
  uploadingKeyFor,
  type P12State,
  type P12Item,
} from '../components/exercise-form/poslech-model';
import { validateExercise } from '../components/exercise-form/validation';

const optsAtoD = (
  withImage: boolean,
): Array<{ key: string; text: string; image_asset_id?: string }> => {
  const items = [
    { key: 'A', text: 'V praci' },
    { key: 'B', text: 'Doma' },
    { key: 'C', text: 'V obchode' },
    { key: 'D', text: 'U lekare' },
  ];
  if (!withImage) return items;
  return items.map((o, i) => ({
    ...o,
    image_asset_id: `media/items/q1-${o.key.toLowerCase()}.jpg`,
  }));
};

describe('PoslechFields image_asset_id (V27)', () => {
  describe('initPoslechState (poslech_1) reads image_asset_id', () => {
    it('hydrates imgA-D when options have image_asset_id', () => {
      const detail = {
        items: [
          {
            question_no: 1,
            question: 'Kde je pani Novakova?',
            audio_source: { segments: [{ text: 'Pani Novakova je doma.' }] },
            options: optsAtoD(true),
          },
        ],
        correct_answers: { '1': 'B' },
      };
      const state = initPoslechState('poslech_1', detail) as P12State;
      const item = state.items[0];
      expect(item.imgA).toBe('media/items/q1-a.jpg');
      expect(item.imgB).toBe('media/items/q1-b.jpg');
      expect(item.imgC).toBe('media/items/q1-c.jpg');
      expect(item.imgD).toBe('media/items/q1-d.jpg');
    });

    it('imgA-D default empty when image_asset_id missing', () => {
      const detail = {
        items: [
          {
            question_no: 1,
            options: optsAtoD(false),
          },
        ],
      };
      const state = initPoslechState('poslech_1', detail) as P12State;
      const item = state.items[0];
      expect(item.imgA).toBe('');
      expect(item.imgB).toBe('');
      expect(item.imgC).toBe('');
      expect(item.imgD).toBe('');
    });
  });

  describe('buildPoslechDetail (poslech_1) emits image_asset_id', () => {
    function stateWithImages(imgs: [string, string, string, string]): P12State {
      const item: P12Item = {
        question: 'Q1',
        text: 'Pani Novakova je doma.',
        optA: 'V praci',
        optB: 'Doma',
        optC: 'V obchode',
        optD: 'U lekare',
        imgA: imgs[0],
        imgB: imgs[1],
        imgC: imgs[2],
        imgD: imgs[3],
        answer: 'B',
      };
      const items: P12Item[] = Array.from({ length: 5 }, (_, i) =>
        i === 0
          ? item
          : {
              question: '',
              text: '',
              optA: '',
              optB: '',
              optC: '',
              optD: '',
              imgA: '',
              imgB: '',
              imgC: '',
              imgD: '',
              answer: '',
            },
      );
      return { type: 'poslech_1', items };
    }

    it('emits image_asset_id field when set', () => {
      const state = stateWithImages([
        'media/items/q1-a.jpg',
        'media/items/q1-b.jpg',
        'media/items/q1-c.jpg',
        'media/items/q1-d.jpg',
      ]);
      const detail = buildPoslechDetail(state, 'text') as {
        items: Array<{
          options: Array<{ key: string; text: string; image_asset_id?: string }>;
        }>;
      };
      const opts = detail.items[0].options;
      expect(opts).toHaveLength(4);
      expect(opts[0]).toEqual({
        key: 'A',
        text: 'V praci',
        image_asset_id: 'media/items/q1-a.jpg',
      });
      expect(opts[3].image_asset_id).toBe('media/items/q1-d.jpg');
    });

    it('omits image_asset_id field when empty (V26-compatible wire)', () => {
      const state = stateWithImages(['', '', '', '']);
      const detail = buildPoslechDetail(state, 'text') as {
        items: Array<{ options: Array<Record<string, unknown>> }>;
      };
      const opts = detail.items[0].options;
      for (const o of opts) {
        expect(o.image_asset_id).toBeUndefined();
      }
    });

    it('round-trips poslech_1 detail with images intact', () => {
      const detailIn = {
        items: [
          {
            question_no: 1,
            question: 'Kde je pani Novakova?',
            audio_source: { segments: [{ text: 'Pani Novakova je doma.' }] },
            options: optsAtoD(true),
          },
        ],
        correct_answers: { '1': 'B' },
      };
      const state = initPoslechState('poslech_1', detailIn);
      const detailOut = buildPoslechDetail(state, 'text') as {
        items: Array<{ options: Array<Record<string, unknown>> }>;
      };
      const out = detailOut.items[0].options;
      expect(out[0].image_asset_id).toBe('media/items/q1-a.jpg');
      expect(out[3].image_asset_id).toBe('media/items/q1-d.jpg');
    });
  });

  describe('countItemImages helper', () => {
    function makeItem(imgs: [string, string, string, string]): P12Item {
      return {
        question: '',
        text: '',
        optA: '',
        optB: '',
        optC: '',
        optD: '',
        imgA: imgs[0],
        imgB: imgs[1],
        imgC: imgs[2],
        imgD: imgs[3],
        answer: '',
      };
    }

    it('returns 0 when no images', () => {
      expect(countItemImages(makeItem(['', '', '', '']))).toBe(0);
    });

    it('returns 4 when all images set', () => {
      expect(countItemImages(makeItem(['a', 'b', 'c', 'd']))).toBe(4);
    });

    it('returns 2 for mixed state', () => {
      expect(countItemImages(makeItem(['a', '', 'c', '']))).toBe(2);
    });

    it('treats whitespace-only as empty', () => {
      expect(countItemImages(makeItem(['  ', '', '', '']))).toBe(0);
    });
  });

  describe('validation all-or-none image rule (V27)', () => {
    function poslech1Payload(opts: {
      imagesPerItem: number[]; // length 5 — count of image_asset_id per item
      status: 'draft' | 'published';
    }) {
      const items = opts.imagesPerItem.map((cnt, i) => {
        const options = ['A', 'B', 'C', 'D'].map((k, ki) => {
          const base: { key: string; text: string; image_asset_id?: string } = {
            key: k,
            text: `Option ${k}`,
          };
          if (ki < cnt) {
            base.image_asset_id = `media/q${i + 1}-${k.toLowerCase()}.jpg`;
          }
          return base;
        });
        return {
          question_no: i + 1,
          question: `Q${i + 1}`,
          audio_source: { segments: [{ text: `seg ${i + 1}` }] },
          options,
        };
      });
      return {
        title: 'Poslech 1 Image',
        module_id: 'mod-nghe',
        status: opts.status,
        detail: {
          items,
          correct_answers: { '1': 'A', '2': 'A', '3': 'A', '4': 'A', '5': 'A' },
        },
      };
    }

    it('rejects published exercise with mixed (2/4) images on any item', () => {
      const payload = poslech1Payload({
        imagesPerItem: [4, 4, 2, 4, 4],
        status: 'published',
      });
      const errors = validateExercise('poslech_1', payload);
      const hit = errors.find((e) => e.includes('Câu 3') && e.includes('ảnh'));
      expect(hit, `expected error mentioning Câu 3 ảnh, got: ${errors.join(' | ')}`).toBeTruthy();
    });

    it('accepts published exercise with all-empty (0/4) on every item', () => {
      const payload = poslech1Payload({
        imagesPerItem: [0, 0, 0, 0, 0],
        status: 'published',
      });
      const errors = validateExercise('poslech_1', payload);
      const imgErrors = errors.filter((e) => e.includes('ảnh'));
      expect(imgErrors).toEqual([]);
    });

    it('accepts published exercise with all-set (4/4) on every item', () => {
      const payload = poslech1Payload({
        imagesPerItem: [4, 4, 4, 4, 4],
        status: 'published',
      });
      const errors = validateExercise('poslech_1', payload);
      const imgErrors = errors.filter((e) => e.includes('ảnh'));
      expect(imgErrors).toEqual([]);
    });

    it('drafts skip the all-or-none rule (admin can save WIP with 1/4)', () => {
      const payload = poslech1Payload({
        imagesPerItem: [1, 4, 4, 4, 4],
        status: 'draft',
      });
      const errors = validateExercise('poslech_1', payload);
      const imgErrors = errors.filter((e) => e.includes('ảnh'));
      expect(imgErrors).toEqual([]);
    });

    it('reports all offending items, not just the first one', () => {
      const payload = poslech1Payload({
        imagesPerItem: [4, 2, 4, 1, 4],
        status: 'published',
      });
      const errors = validateExercise('poslech_1', payload);
      const offenders = errors.filter((e) => e.includes('ảnh'));
      expect(offenders.length).toBeGreaterThanOrEqual(2);
      expect(offenders.some((e) => e.includes('Câu 2'))).toBe(true);
      expect(offenders.some((e) => e.includes('Câu 4'))).toBe(true);
    });
  });

  describe('makeOptionImagePatcher (V28 — AI image wire)', () => {
    it('returns a setter that patches the matching imgK field', () => {
      let captured: Partial<P12Item> | null = null;
      const patch = (partial: Partial<P12Item>) => {
        captured = partial;
      };
      const patcher = makeOptionImagePatcher(patch, 'B');
      patcher('media/ai-generated-asset-xyz');
      expect(captured).toEqual({ imgB: 'media/ai-generated-asset-xyz' });
    });

    it('isolates A / B / C / D — calling A does not patch others', () => {
      const captured: Partial<P12Item>[] = [];
      const patch = (partial: Partial<P12Item>) => {
        captured.push(partial);
      };
      makeOptionImagePatcher(patch, 'A')('asset-A');
      makeOptionImagePatcher(patch, 'C')('asset-C');
      expect(captured).toEqual([{ imgA: 'asset-A' }, { imgC: 'asset-C' }]);
      // None of the patches should mention sibling keys.
      for (const p of captured) {
        expect(Object.keys(p)).toHaveLength(1);
      }
    });

    it('feeds buildPoslechDetail to emit image_asset_id through V27 wire', () => {
      // Simulate the full flow: AiImageButton fires onAssetCreated → patcher
      // → state update → buildPoslechDetail → wire shape.
      const baseItem: P12Item = {
        question: 'Q1',
        text: 'seg',
        optA: 'a', optB: 'b', optC: 'c', optD: 'd',
        imgA: '', imgB: '', imgC: '', imgD: '',
        answer: 'A',
      };
      const filler: P12Item = {
        question: '', text: '',
        optA: '', optB: '', optC: '', optD: '',
        imgA: '', imgB: '', imgC: '', imgD: '',
        answer: '',
      };
      const items = [baseItem, filler, filler, filler, filler];
      let state: P12State = { type: 'poslech_1', items };

      const patch = (partial: Partial<P12Item>) => {
        state = {
          ...state,
          items: state.items.map((it, i) =>
            i === 0 ? { ...it, ...partial } : it,
          ),
        };
      };
      makeOptionImagePatcher(patch, 'A')('media/q1-a-ai.jpg');

      expect(state.items[0].imgA).toBe('media/q1-a-ai.jpg');
      const detail = buildPoslechDetail(state, 'text') as {
        items: Array<{ options: Array<Record<string, unknown>> }>;
      };
      expect(detail.items[0].options[0].image_asset_id).toBe('media/q1-a-ai.jpg');
      // Sibling options stay text-only because their imgK is still empty.
      expect(detail.items[0].options[1].image_asset_id).toBeUndefined();
    });
  });

  describe('parseUploadResponse + uploadingKeyFor (V29 — manual upload)', () => {
    it('extracts asset.id from a happy upload response', () => {
      const json = {
        data: {
          asset: {
            id: 'media/uploads/abc123.jpg',
            asset_kind: 'image',
            mime_type: 'image/jpeg',
          },
        },
      };
      expect(parseUploadResponse(json)).toBe('media/uploads/abc123.jpg');
    });

    it('throws when data is missing', () => {
      expect(() => parseUploadResponse({})).toThrow(/asset.id/);
    });

    it('throws when asset.id is missing or empty', () => {
      expect(() => parseUploadResponse({ data: { asset: {} } })).toThrow(/asset.id/);
      expect(() => parseUploadResponse({ data: { asset: { id: '' } } })).toThrow(/asset.id/);
    });

    it('throws on null or non-object input', () => {
      expect(() => parseUploadResponse(null)).toThrow();
      expect(() => parseUploadResponse(undefined)).toThrow();
    });

    it('uploadingKeyFor encodes (item, option) deterministically', () => {
      expect(uploadingKeyFor(0, 'A')).toBe('0-A');
      expect(uploadingKeyFor(4, 'D')).toBe('4-D');
      // Different cells must yield different keys.
      expect(uploadingKeyFor(0, 'B')).not.toBe(uploadingKeyFor(0, 'A'));
    });
  });

  describe('poslech_2 cross-pollution (V26 scope guard)', () => {
    it('poslech_2 round-trip preserves wire shape — no image_asset_id leaked', () => {
      // V27 only changes poslech_1 authoring UX. poslech_2 has the same
      // P12State internals, but in practice no admin will populate imgA-D
      // for poslech_2 in V27 (no UI). Verify that an empty-image P12State
      // for poslech_2 produces a clean wire shape with no image_asset_id.
      const detailIn = {
        items: [
          {
            question_no: 1,
            options: [
              { key: 'A', text: 'a' },
              { key: 'B', text: 'b' },
              { key: 'C', text: 'c' },
              { key: 'D', text: 'd' },
            ],
          },
        ],
        correct_answers: { '1': 'A' },
      };
      const state = initPoslechState('poslech_2', detailIn);
      const detailOut = buildPoslechDetail(state, 'text') as {
        items: Array<{ options: Array<Record<string, unknown>> }>;
      };
      for (const o of detailOut.items[0].options) {
        expect(o.image_asset_id).toBeUndefined();
      }
    });
  });
});
