export type CteniType = 'cteni_1' | 'cteni_2' | 'cteni_3' | 'cteni_4' | 'cteni_5';

export type C1Item = { mode: 'image' | 'text'; text: string; assetId: string; answer: string };
export type C1State = {
  type: 'cteni_1';
  items: C1Item[];
  options: { key: string; text: string }[];
};

export type CQItem = { prompt: string; optA: string; optB: string; optC: string; optD: string; answer: string };
export type C24State = { type: 'cteni_2' | 'cteni_4'; text: string; questions: CQItem[] };

export type C3State = {
  type: 'cteni_3';
  texts: { text: string; answer: string }[];
  persons: { key: string; name: string; description: string }[];
};

export type C5State = { type: 'cteni_5'; text: string; slots: { prompt: string; answer: string }[] };

export type CteniState = C1State | C24State | C3State | C5State;

export const OPTION_KEYS_1 = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
export const OPTION_KEYS_3 = ['A', 'B', 'C', 'D', 'E'];

export const emptyQ = (): CQItem => ({ prompt: '', optA: '', optB: '', optC: '', optD: '', answer: '' });

export function initCteniState(type: CteniType, detail: Record<string, unknown>): CteniState {
  const ca = (detail.correct_answers ?? {}) as Record<string, string>;

  if (type === 'cteni_1') {
    const rawItems = (detail.items ?? []) as Array<{ item_no?: number; text?: string; asset_id?: string }>;
    const rawOpts = (detail.options ?? []) as Array<{ key?: string; text?: string }>;
    const items: C1Item[] = Array.from({ length: 5 }, (_, i) => {
      const raw = rawItems.find((item) => item.item_no === i + 1) ?? rawItems[i];
      const assetId = raw?.asset_id ?? '';
      return {
        mode: assetId ? 'image' : 'text',
        text: raw?.text ?? '',
        assetId,
        answer: ca[String(i + 1)] ?? '',
      };
    });
    const options = OPTION_KEYS_1.map((k, i) => ({
      key: k,
      text: rawOpts.find((o) => o.key === k)?.text ?? rawOpts[i]?.text ?? '',
    }));
    return { type, items, options };
  }

  if (type === 'cteni_2' || type === 'cteni_4') {
    const startNo = type === 'cteni_4' ? 15 : 6;
    const count = type === 'cteni_4' ? 6 : 5;
    const rawQs = (detail.questions ?? []) as Array<Record<string, unknown>>;
    const questions: CQItem[] = Array.from({ length: count }, (_, i) => {
      const qNo = startNo + i;
      const rq = rawQs.find((q) => q.question_no === qNo) ?? rawQs[i];
      const opts = (rq?.options ?? []) as Array<{ key: string; text: string }>;
      const get = (k: string) => opts.find((o) => o.key === k)?.text ?? '';
      return {
        prompt: String(rq?.prompt ?? ''),
        optA: get('A'), optB: get('B'), optC: get('C'), optD: get('D'),
        answer: ca[String(qNo)] ?? '',
      };
    });
    const body = type === 'cteni_4' ? (detail.context ?? detail.text ?? '') : (detail.text ?? '');
    return { type, text: String(body), questions };
  }

  if (type === 'cteni_3') {
    const rawTexts = (detail.texts ?? []) as Array<{ item_no?: number; text?: string }>;
    const rawPerson = (detail.persons ?? []) as Array<{ key?: string; name?: string; description?: string }>;
    const texts = Array.from({ length: 4 }, (_, i) => {
      const raw = rawTexts.find((txt) => txt.item_no === i + 1) ?? rawTexts[i];
      return {
        text: raw?.text ?? '',
        answer: ca[String(i + 1)] ?? '',
      };
    });
    const persons = OPTION_KEYS_3.map((k, i) => {
      const raw = rawPerson.find((p) => p.key === k) ?? rawPerson[i];
      return {
        key: k,
        name: raw?.name ?? '',
        description: raw?.description ?? '',
      };
    });
    return { type, texts, persons };
  }

  const rawQs = (detail.questions ?? []) as Array<{ question_no?: number; prompt?: string }>;
  const slots = Array.from({ length: 5 }, (_, i) => {
    const qNo = 21 + i;
    const raw = rawQs.find((q) => q.question_no === qNo) ?? rawQs[i];
    return {
      prompt: raw?.prompt ?? '',
      answer: ca[String(qNo)] ?? '',
    };
  });
  return { type: 'cteni_5', text: String(detail.text ?? ''), slots };
}

export function buildCteniDetail(state: CteniState): Record<string, unknown> {
  if (state.type === 'cteni_1') {
    const correct: Record<string, string> = {};
    state.items.forEach((item, i) => { if (item.answer) correct[String(i + 1)] = item.answer; });
    return {
      items: state.items.map((it, i) => ({
        item_no: i + 1,
        ...(it.mode === 'image' && it.assetId ? { asset_id: it.assetId } : { text: it.text }),
      })),
      options: state.options.map((o) => ({ key: o.key, text: o.text })),
      correct_answers: correct,
    };
  }

  if (state.type === 'cteni_2' || state.type === 'cteni_4') {
    const startNo = state.type === 'cteni_4' ? 15 : 6;
    const correct: Record<string, string> = {};
    const questions = state.questions.map((q, i) => {
      if (q.answer) correct[String(startNo + i)] = q.answer;
      return {
        question_no: startNo + i,
        prompt: q.prompt,
        options: [{ key: 'A', text: q.optA }, { key: 'B', text: q.optB }, { key: 'C', text: q.optC }, { key: 'D', text: q.optD }],
      };
    });
    const body = state.type === 'cteni_4'
      ? { ...(state.text.trim() ? { context: state.text } : {}) }
      : { text: state.text };
    return { ...body, questions, correct_answers: correct };
  }

  if (state.type === 'cteni_3') {
    const correct: Record<string, string> = {};
    state.texts.forEach((t, i) => { if (t.answer) correct[String(i + 1)] = t.answer; });
    return {
      texts: state.texts.map((t, i) => ({ item_no: i + 1, text: t.text })),
      persons: state.persons.map((p) => ({
        key: p.key,
        name: p.name,
        ...(p.description.trim() ? { description: p.description } : {}),
      })),
      correct_answers: correct,
    };
  }

  if (state.type === 'cteni_5') {
    const correct: Record<string, string> = {};
    state.slots.forEach((slot, i) => { if (slot.answer) correct[String(21 + i)] = slot.answer; });
    return {
      text: state.text,
      questions: state.slots.map((slot, i) => ({ question_no: 21 + i, prompt: slot.prompt })),
      correct_answers: correct,
    };
  }

  return {};
}

export function isCteniDirty(state: CteniState): boolean {
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
      return state.texts.some((t) => t.text || t.answer) || state.persons.some((p) => p.name || p.description);
    case 'cteni_5':
      return Boolean(state.text) || state.slots.some((sl) => sl.prompt || sl.answer);
  }
}
