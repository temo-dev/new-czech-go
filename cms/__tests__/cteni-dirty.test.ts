import { describe, it, expect } from 'vitest';
import {
  buildCteniDetail,
  emptyQ,
  initCteniState,
  isCteniDirty,
  type C1Item,
  type CteniState,
} from '../components/exercise-form/cteni-model';

const emptyC1Item = (): C1Item => ({ mode: 'text', text: '', assetId: '', answer: '' });

describe('isCteniDirty', () => {
  it('returns false for a freshly initialised cteni_2', () => {
    const state: CteniState = {
      type: 'cteni_2',
      text: '',
      questions: Array.from({ length: 5 }, () => emptyQ()),
    };
    expect(isCteniDirty(state)).toBe(false);
  });

  it('returns true once cteni_2 has any text content', () => {
    const state: CteniState = {
      type: 'cteni_2',
      text: 'Pavel',
      questions: Array.from({ length: 5 }, () => emptyQ()),
    };
    expect(isCteniDirty(state)).toBe(true);
  });

  it('returns true when only a single answer is filled', () => {
    const state: CteniState = {
      type: 'cteni_4',
      text: '',
      questions: [{ ...emptyQ(), answer: 'A' }, ...Array.from({ length: 5 }, () => emptyQ())],
    };
    expect(isCteniDirty(state)).toBe(true);
  });

  it('cteni_1 dirty when an asset_id is present', () => {
    const state: CteniState = {
      type: 'cteni_1',
      items: [
        { ...emptyC1Item(), assetId: 'img-1' },
        emptyC1Item(),
        emptyC1Item(),
        emptyC1Item(),
        emptyC1Item(),
      ],
      options: [],
    };
    expect(isCteniDirty(state)).toBe(true);
  });

  it('cteni_3 dirty when a person description is filled', () => {
    const state: CteniState = {
      type: 'cteni_3',
      texts: [],
      persons: [{ key: 'A', name: '', description: 'učitelka' }],
    };
    expect(isCteniDirty(state)).toBe(true);
  });

  it('cteni_5 dirty when a slot prompt is filled', () => {
    const state: CteniState = {
      type: 'cteni_5',
      text: '',
      slots: [{ prompt: 'Jméno:', answer: '' }],
    };
    expect(isCteniDirty(state)).toBe(true);
  });
});

describe('cteni draft form mapping', () => {
  it('round-trips cteni_4 context instead of text', () => {
    const state = initCteniState('cteni_4', {
      context: 'Krátký kontext',
      questions: [
        { question_no: 15, prompt: 'Q15?', options: [{ key: 'A', text: 'ano' }] },
        { question_no: 16, prompt: 'Q16?', options: [{ key: 'B', text: 'ne' }] },
      ],
      correct_answers: { '15': 'A', '16': 'B' },
    });
    expect(state.type).toBe('cteni_4');
    if (state.type !== 'cteni_4') return;
    expect(state.text).toBe('Krátký kontext');
    expect(state.questions[0].prompt).toBe('Q15?');
    expect(state.questions[1].answer).toBe('B');

    const detail = buildCteniDetail(state);
    expect(detail.context).toBe('Krátký kontext');
    expect(detail.text).toBeUndefined();
  });

  it('falls back to legacy cteni_4 text when context is absent', () => {
    const state = initCteniState('cteni_4', {
      text: 'Legacy text field',
      questions: [],
      correct_answers: {},
    });
    expect(state.type).toBe('cteni_4');
    if (state.type !== 'cteni_4') return;
    expect(state.text).toBe('Legacy text field');
  });

  it('preserves cteni_3 person descriptions from AI drafts', () => {
    const state = initCteniState('cteni_3', {
      texts: [{ item_no: 1, text: 'Text A' }],
      persons: [{ key: 'A', name: 'Marie', description: 'učitelka' }],
      correct_answers: { '1': 'A' },
    });
    expect(state.type).toBe('cteni_3');
    if (state.type !== 'cteni_3') return;
    expect(state.persons[0]).toEqual({ key: 'A', name: 'Marie', description: 'učitelka' });

    const detail = buildCteniDetail(state);
    const persons = detail.persons as Array<Record<string, unknown>>;
    expect(persons[0]).toMatchObject({ key: 'A', name: 'Marie', description: 'učitelka' });
  });
});
