import { describe, it, expect } from 'vitest';
import {
  initPoslechState,
  buildPoslechDetail,
  countItemImages,
  type P12State,
  type P12Item,
} from '../components/exercise-form/poslech-model';

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
