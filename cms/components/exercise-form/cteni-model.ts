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

// V39 — số item / option mặc định khớp template A2. Dynamic counts cho phép admin thêm/xóa.
export const CTENI_1_DEFAULT_ITEM_COUNT = 5;
export const CTENI_1_DEFAULT_OPTION_COUNT = 8;
export const CTENI_2_DEFAULT_QUESTION_COUNT = 5;
export const CTENI_3_DEFAULT_TEXT_COUNT = 4;
export const CTENI_3_DEFAULT_PERSON_COUNT = 5;
export const CTENI_4_DEFAULT_QUESTION_COUNT = 6;
export const CTENI_5_DEFAULT_SLOT_COUNT = 5;

export const OPTION_KEYS_1 = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
export const OPTION_KEYS_3 = ['A', 'B', 'C', 'D', 'E'];

// Sinh key A, B, ..., Z theo index. Trả '' nếu vượt Z (cap 26 options).
export function optionKeyAt(index: number): string {
  if (index < 0 || index >= 26) return '';
  return String.fromCharCode(65 + index);
}

// Tìm key A-Z chưa dùng trong used. Trả '' nếu đã đầy 26 keys.
export function nextFreeKey(used: Iterable<string>): string {
  const set = new Set(used);
  for (let i = 0; i < 26; i += 1) {
    const k = optionKeyAt(i);
    if (!set.has(k)) return k;
  }
  return '';
}

export const emptyQ = (): CQItem => ({ prompt: '', optA: '', optB: '', optC: '', optD: '', answer: '' });
export const emptyC1Item = (): C1Item => ({ mode: 'text', text: '', assetId: '', answer: '' });
export const emptyC1Option = (key: string) => ({ key, text: '' });
export const emptyC3Text = () => ({ text: '', answer: '' });
export const emptyC3Person = (key: string) => ({ key, name: '', description: '' });
export const emptyC5Slot = () => ({ prompt: '', answer: '' });

export function initCteniState(type: CteniType, detail: Record<string, unknown>): CteniState {
  const ca = (detail.correct_answers ?? {}) as Record<string, string>;

  if (type === 'cteni_1') {
    const rawItems = (detail.items ?? []) as Array<{ item_no?: number; text?: string; asset_id?: string }>;
    const rawOpts = (detail.options ?? []) as Array<{ key?: string; text?: string }>;
    // V39 — count động: dùng raw length nếu có data, không thì default.
    const itemCount = rawItems.length > 0 ? rawItems.length : CTENI_1_DEFAULT_ITEM_COUNT;
    const items: C1Item[] = Array.from({ length: itemCount }, (_, i) => {
      const raw = rawItems.find((item) => item.item_no === i + 1) ?? rawItems[i];
      const assetId = raw?.asset_id ?? '';
      return {
        mode: assetId ? 'image' : 'text',
        text: raw?.text ?? '',
        assetId,
        answer: ca[String(i + 1)] ?? '',
      };
    });
    const optCount = rawOpts.length > 0 ? rawOpts.length : CTENI_1_DEFAULT_OPTION_COUNT;
    const options = Array.from({ length: optCount }, (_, i) => {
      const fallbackKey = optionKeyAt(i);
      const raw = rawOpts.find((o) => o.key === fallbackKey) ?? rawOpts[i];
      return { key: String(raw?.key ?? fallbackKey), text: String(raw?.text ?? '') };
    });
    return { type, items, options };
  }

  if (type === 'cteni_2' || type === 'cteni_4') {
    const startNo = type === 'cteni_4' ? 15 : 6;
    const defaultCount = type === 'cteni_4' ? CTENI_4_DEFAULT_QUESTION_COUNT : CTENI_2_DEFAULT_QUESTION_COUNT;
    const rawQs = (detail.questions ?? []) as Array<Record<string, unknown>>;
    // V39 — count động.
    const count = rawQs.length > 0 ? rawQs.length : defaultCount;
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
    // V39 — count động cho cả texts và persons.
    const textCount = rawTexts.length > 0 ? rawTexts.length : CTENI_3_DEFAULT_TEXT_COUNT;
    const texts = Array.from({ length: textCount }, (_, i) => {
      const raw = rawTexts.find((txt) => txt.item_no === i + 1) ?? rawTexts[i];
      return {
        text: raw?.text ?? '',
        answer: ca[String(i + 1)] ?? '',
      };
    });
    const personCount = rawPerson.length > 0 ? rawPerson.length : CTENI_3_DEFAULT_PERSON_COUNT;
    const persons = Array.from({ length: personCount }, (_, i) => {
      const fallbackKey = optionKeyAt(i);
      const raw = rawPerson.find((p) => p.key === fallbackKey) ?? rawPerson[i];
      return {
        key: String(raw?.key ?? fallbackKey),
        name: raw?.name ?? '',
        description: raw?.description ?? '',
      };
    });
    return { type, texts, persons };
  }

  const rawQs = (detail.questions ?? []) as Array<{ question_no?: number; prompt?: string }>;
  // V39 — count động.
  const slotCount = rawQs.length > 0 ? rawQs.length : CTENI_5_DEFAULT_SLOT_COUNT;
  const slots = Array.from({ length: slotCount }, (_, i) => {
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
