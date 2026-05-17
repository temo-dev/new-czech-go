import { describe, it, expect } from 'vitest';
import {
  initPoslechState,
  buildPoslechDetail,
  countItemImages,
  makeOptionImagePatcher,
  makeSharedOptionImagePatcher,
  parseUploadResponse,
  sharedUploadingKeyFor,
  stripPoslechItemAudioAssetIds,
  uploadingKeyFor,
  type MatchState,
  type P12State,
  type P12Item,
  type P5State,
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
  describe('poslech_3 question names', () => {
    it('round-trips learner-facing item names', () => {
      const detailIn = {
        items: [
          {
            question_no: 11,
            question: 'Leila',
            audio_source: {
              segments: [{ text: 'Jmenuji se Leila. Baví mě plavání.' }],
            },
          },
        ],
        options: [
          { key: 'A', label: 'běh' },
          { key: 'B', label: 'vaření' },
          { key: 'C', label: 'kreslení' },
          { key: 'D', label: 'sledování televize' },
          { key: 'E', label: 'čtení' },
          { key: 'F', label: 'plavání' },
          { key: 'G', label: 'fotografování' },
        ],
        correct_answers: { '11': 'F' },
      };
      const state = initPoslechState('poslech_3', detailIn) as MatchState;
      expect(state.items[0].questionNo).toBe(11);
      expect(state.items[0].question).toBe('Leila');
      expect(state.items[0].answer).toBe('F');

      const detailOut = buildPoslechDetail(state, 'text') as {
        items: Array<{ question_no: number; question?: string }>;
        correct_answers: Record<string, string>;
      };
      expect(detailOut.items[0].question_no).toBe(11);
      expect(detailOut.items[0].question).toBe('Leila');
      expect(detailOut.correct_answers['11']).toBe('F');
    });
  });

  describe('poslech_5 fill questions', () => {
    it('round-trips learner-facing prompts and exam question numbers', () => {
      const detailIn = {
        audio_source: {
          segments: [{ text: 'Ahoj Lído, tady Eva. Dostala jsem lístky.' }],
        },
        questions: [
          { question_no: 21, prompt: 'KDO dal Evě lístky?' },
          { question_no: 22, prompt: 'KOLIKÁTÉHO bude balet?' },
          { question_no: 23, prompt: 'KTERÝ DEN bude balet?' },
          { question_no: 24, prompt: 'JAK se jmenuje restaurace?' },
          { question_no: 25, prompt: 'TELEFON Evy?' },
        ],
        correct_answers: {
          '21': 'sestra Ivana',
          '22': '23',
          '23': 'úterý',
          '24': 'Klášterní',
          '25': '773 932 504',
        },
      };

      const state = initPoslechState('poslech_5', detailIn) as P5State;
      expect(state.slots[0]).toEqual({
        questionNo: 21,
        prompt: 'KDO dal Evě lístky?',
        answer: 'sestra Ivana',
      });
      expect(state.slots[4].questionNo).toBe(25);
      expect(state.slots[4].prompt).toBe('TELEFON Evy?');
      expect(state.slots[4].answer).toBe('773 932 504');

      const detailOut = buildPoslechDetail(state, 'text') as {
        questions: Array<{ question_no: number; prompt: string }>;
        correct_answers: Record<string, string>;
      };
      expect(detailOut.questions.map((q) => q.question_no)).toEqual([
        21, 22, 23, 24, 25,
      ]);
      expect(detailOut.questions[0].prompt).toBe('KDO dal Evě lístky?');
      expect(detailOut.correct_answers['21']).toBe('sestra Ivana');
      expect(detailOut.correct_answers['25']).toBe('773 932 504');
    });

    it('uses 21-25 for new poslech_5 slots instead of blank 1-5 prompts', () => {
      const state = initPoslechState('poslech_5', {}) as P5State;
      expect(state.slots.map((slot) => slot.questionNo)).toEqual([
        21, 22, 23, 24, 25,
      ]);

      const next: P5State = {
        ...state,
        voiceText: 'Ahoj, tady Eva.',
        slots: state.slots.map((slot, i) =>
          i === 0
            ? { ...slot, prompt: 'KDO volá?', answer: 'Eva' }
            : slot,
        ),
      };
      const detailOut = buildPoslechDetail(next, 'text') as {
        questions: Array<{ question_no: number; prompt: string }>;
        correct_answers: Record<string, string>;
      };
      expect(detailOut.questions[0]).toEqual({
        question_no: 21,
        prompt: 'KDO volá?',
      });
      expect(detailOut.correct_answers).toEqual({ '21': 'Eva' });
    });

    it('normalizes legacy 1-5 slots to 21-25 while preserving answers', () => {
      const state = initPoslechState('poslech_5', {
        questions: [
          { question_no: 1, prompt: 'KDO volá?' },
          { question_no: 2, prompt: 'KAM jde?' },
          { question_no: 3, prompt: 'KDY?' },
          { question_no: 4, prompt: 'KDE?' },
          { question_no: 5, prompt: 'TELEFON?' },
        ],
        correct_answers: {
          '1': 'Eva',
          '2': 'balet',
          '3': 'úterý',
          '4': 'Klášterní',
          '5': '773',
        },
      }) as P5State;

      expect(state.slots.map((slot) => slot.questionNo)).toEqual([
        21, 22, 23, 24, 25,
      ]);
      expect(state.slots[0].prompt).toBe('KDO volá?');
      expect(state.slots[0].answer).toBe('Eva');

      const detailOut = buildPoslechDetail(state, 'text') as {
        questions: Array<{ question_no: number; prompt: string }>;
        correct_answers: Record<string, string>;
      };
      expect(detailOut.questions[0]).toEqual({
        question_no: 21,
        prompt: 'KDO volá?',
      });
      expect(detailOut.correct_answers['21']).toBe('Eva');
      expect(detailOut.correct_answers['1']).toBeUndefined();
    });

    it('validation rejects published-shaped payloads with blank prompts', () => {
      const errors = validateExercise('poslech_5', {
        title: 'Poslech 5',
        module_id: 'mod-nghe',
        detail: {
          questions: Array.from({ length: 5 }, (_, i) => ({
            question_no: 21 + i,
            prompt: i === 2 ? '' : `Otázka ${21 + i}?`,
          })),
          correct_answers: {
            '21': 'a',
            '22': 'b',
            '23': 'c',
            '24': 'd',
            '25': 'e',
          },
        },
      });
      expect(errors.some((e) => e.includes('câu 23'))).toBe(true);
    });

    it('validation accepts five prompted poslech_5 fill slots', () => {
      const errors = validateExercise('poslech_5', {
        title: 'Poslech 5',
        module_id: 'mod-nghe',
        detail: {
          questions: Array.from({ length: 5 }, (_, i) => ({
            question_no: 21 + i,
            prompt: `Otázka ${21 + i}?`,
          })),
          correct_answers: {
            '21': 'a',
            '22': 'b',
            '23': 'c',
            '24': 'd',
            '25': 'e',
          },
        },
      });
      expect(errors).toEqual([]);
    });
  });

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
        audioAssetId: '',
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
              audioAssetId: '',
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

    it('round-trips per-item audio asset_id after Polly generation', () => {
      const detailIn = {
        items: [
          {
            question_no: 1,
            question: 'Kde je pani Novakova?',
            audio_source: {
              asset_id: 'exercise-audio/ex-1/item-1.mp3',
              segments: [{ text: 'Pani Novakova je doma.' }],
            },
            options: optsAtoD(false),
          },
        ],
        correct_answers: { '1': 'B' },
      };
      const state = initPoslechState('poslech_1', detailIn) as P12State;
      expect(state.items[0].audioAssetId).toBe(
        'exercise-audio/ex-1/item-1.mp3',
      );

      const detailOut = buildPoslechDetail(state, 'text') as {
        items: Array<{ audio_source: Record<string, unknown> }>;
      };
      expect(detailOut.items[0].audio_source.asset_id).toBe(
        'exercise-audio/ex-1/item-1.mp3',
      );
      expect(detailOut.items[0].audio_source.segments).toEqual([
        { text: 'Pani Novakova je doma.' },
      ]);
    });

    it('strips audio asset ids only for the pre-generate save payload', () => {
      const detailIn = {
        items: [
          {
            question_no: 1,
            audio_source: {
              type: 'text',
              asset_id: 'exercise-audio/ex-1/item-1.mp3',
              segments: [{ text: 'Pani Novakova je doma.' }],
            },
          },
        ],
        correct_answers: { '1': 'B' },
      };
      const stripped = stripPoslechItemAudioAssetIds(detailIn);
      const audio = (
        stripped.items as Array<{ audio_source: Record<string, unknown> }>
      )[0].audio_source;
      expect(audio.asset_id).toBeUndefined();
      expect(audio.type).toBe('text');
      expect(audio.segments).toEqual([{ text: 'Pani Novakova je doma.' }]);
      expect(detailIn.items[0].audio_source.asset_id).toBe(
        'exercise-audio/ex-1/item-1.mp3',
      );
    });

    it('keeps wrapped speaker transcript lines on the previous speaker turn', () => {
      const state = stateWithImages(['', '', '', '']);
      state.items[0].text =
        '[Žena]: Dobrý den, tady jazyková škola Atlas. Vy jste poslal přihlášku\n' +
        'do kurzu češtiny pro cizince?\n' +
        '[Muž]: Ano, poslal jsem ji minulý týden.';

      const detail = buildPoslechDetail(state, 'text') as {
        items: Array<{
          audio_source: {
            segments: Array<{ speaker?: string; text: string }>;
          };
        }>;
      };

      expect(detail.items[0].audio_source.segments).toEqual([
        {
          speaker: 'Žena',
          text:
            'Dobrý den, tady jazyková škola Atlas. Vy jste poslal přihlášku do kurzu češtiny pro cizince?',
        },
        { speaker: 'Muž', text: 'Ano, poslal jsem ji minulý týden.' },
      ]);
    });
  });

  describe('countItemImages helper', () => {
    function makeItem(imgs: [string, string, string, string]): P12Item {
      return {
        question: '',
        text: '',
        audioAssetId: '',
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
        audioAssetId: '',
        optA: 'a', optB: 'b', optC: 'c', optD: 'd',
        imgA: '', imgB: '', imgC: '', imgD: '',
        answer: 'A',
      };
      const filler: P12Item = {
        question: '', text: '',
        audioAssetId: '',
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

  describe('poslech_4 shared image options', () => {
    it('round-trips A-F image asset ids through the poslech_4 wire', () => {
      const detailIn = {
        items: [
          {
            question_no: 16,
            audio_source: {
              segments: [{ speaker: 'A', text: 'Máte tyhle boty?' }],
            },
          },
        ],
        options: [
          { key: 'A', asset_id: 'media/poslech4/a.jpg' },
          { key: 'B', asset_id: 'media/poslech4/b.jpg' },
          { key: 'C', asset_id: 'media/poslech4/c.jpg' },
          { key: 'D', asset_id: 'media/poslech4/d.jpg' },
          { key: 'E', asset_id: 'media/poslech4/e.jpg' },
          { key: 'F', asset_id: 'media/poslech4/f.jpg' },
        ],
        correct_answers: { '16': 'A' },
      };

      const state = initPoslechState('poslech_4', detailIn) as MatchState;
      expect(state.options.map((o) => o.label)).toEqual([
        'media/poslech4/a.jpg',
        'media/poslech4/b.jpg',
        'media/poslech4/c.jpg',
        'media/poslech4/d.jpg',
        'media/poslech4/e.jpg',
        'media/poslech4/f.jpg',
      ]);

      const detailOut = buildPoslechDetail(state, 'text') as {
        options: Array<{ key: string; asset_id: string }>;
      };
      expect(detailOut.options).toEqual(detailIn.options);
    });

    it('patches only the selected shared option for upload or AI generation', () => {
      const captured: Array<{ optionKey: string; assetId: string }> = [];
      const patcher = makeSharedOptionImagePatcher((optionKey, assetId) => {
        captured.push({ optionKey, assetId });
      }, 'F');

      patcher('media/poslech4/f-generated.jpg');

      expect(captured).toEqual([
        { optionKey: 'F', assetId: 'media/poslech4/f-generated.jpg' },
      ]);
      expect(sharedUploadingKeyFor('F')).toBe('shared-F');
    });
  });

  describe('parseUploadResponse + uploadingKeyFor (V29 — manual upload)', () => {
    it('extracts asset.storage_key from a happy upload response (V30 hotfix)', () => {
      // Backend register response shape: data.asset = {id, asset_kind,
      // storage_key, mime_type}. Flutter mediaUri queries ?key=<storage_key>
      // so we MUST store storage_key — not the asset.id — into imgK,
      // otherwise /v1/media/file 404s and learners see letter placeholders.
      const json = {
        data: {
          asset: {
            id: 'asset-abc123',
            asset_kind: 'image',
            storage_key: 'exercises/ex1/asset-abc123.jpg',
            mime_type: 'image/jpeg',
          },
        },
      };
      expect(parseUploadResponse(json)).toBe('exercises/ex1/asset-abc123.jpg');
    });

    it('throws when data is missing', () => {
      expect(() => parseUploadResponse({})).toThrow(/storage_key/);
    });

    it('throws when storage_key is missing or empty', () => {
      expect(() => parseUploadResponse({ data: { asset: { id: 'x' } } })).toThrow(/storage_key/);
      expect(() => parseUploadResponse({ data: { asset: { id: 'x', storage_key: '' } } })).toThrow(/storage_key/);
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
