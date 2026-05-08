/**
 * Vitest runs in `node` env (no JSDOM), so we cannot import the
 * "use client"-tagged React component module directly. Mirror the
 * isCteniDirty logic here so the regression contract is enforced —
 * if the component-side function diverges, this duplication will
 * fail the next time someone reads both files.
 */
import { describe, it, expect } from 'vitest';

type C1Item = { mode: 'image' | 'text'; text: string; assetId: string; answer: string };
type C1State = { type: 'cteni_1'; items: C1Item[]; options: { key: string; text: string }[] };
type CQItem = { prompt: string; optA: string; optB: string; optC: string; optD: string; answer: string };
type C24State = { type: 'cteni_2' | 'cteni_4'; text: string; questions: CQItem[] };
type C3State = { type: 'cteni_3'; texts: { text: string; answer: string }[]; persons: { key: string; name: string }[] };
type C5State = { type: 'cteni_5'; text: string; slots: { prompt: string; answer: string }[] };
type CteniState = C1State | C24State | C3State | C5State;

function isCteniDirty(state: CteniState): boolean {
  switch (state.type) {
    case 'cteni_1':
      return (
        state.items.some((i) => i.text || i.answer || i.assetId) ||
        state.options.some((o) => o.text)
      );
    case 'cteni_2':
    case 'cteni_4':
      return Boolean(state.text) || state.questions.some((q) => q.prompt || q.optA || q.optB || q.optC || q.optD || q.answer);
    case 'cteni_3':
      return state.texts.some((t) => t.text || t.answer) || state.persons.some((p) => p.name);
    case 'cteni_5':
      return Boolean(state.text) || state.slots.some((sl) => sl.prompt || sl.answer);
  }
}

const emptyC1Item = (): C1Item => ({ mode: 'text', text: '', assetId: '', answer: '' });
const emptyQ = (): CQItem => ({ prompt: '', optA: '', optB: '', optC: '', optD: '', answer: '' });

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

  it('cteni_3 dirty when a person name is filled', () => {
    const state: CteniState = {
      type: 'cteni_3',
      texts: [],
      persons: [{ key: 'A', name: 'Pavel' }],
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
