// Pure state + serialization helpers for the Poslech 1..5 form. Extracted
// from PoslechFields.tsx so tests can drive initState/buildDetail directly
// (matches the cteni-model.ts pattern).
//
// V27 — P12Item gains imgA-D fields and buildDetail emits image_asset_id
// per option (omitted when empty for V26-compatible wire shapes).

export type PoslechType =
  | 'poslech_1'
  | 'poslech_2'
  | 'poslech_3'
  | 'poslech_4'
  | 'poslech_5';

export type P12Item = {
  question: string;
  text: string;
  optA: string;
  optB: string;
  optC: string;
  optD: string;
  // V27 — image_asset_id per option key. Empty string = no image.
  imgA: string;
  imgB: string;
  imgC: string;
  imgD: string;
  answer: string;
};

export type MatchItem = { text: string; answer: string };
export type SharedOption = { key: string; label: string };
export type FillSlot = { answer: string };

export type P12State = { type: 'poslech_1' | 'poslech_2'; items: P12Item[] };
export type MatchState = {
  type: 'poslech_3' | 'poslech_4';
  items: MatchItem[];
  options: SharedOption[];
};
export type P5State = { type: 'poslech_5'; voiceText: string; slots: FillSlot[] };
export type PoslechState = P12State | MatchState | P5State;

export const ITEM_COUNT = 5;
export const OPTION_KEYS_3 = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];
export const OPTION_KEYS_4 = ['A', 'B', 'C', 'D', 'E', 'F'];

type RawOption = { key: string; text?: string; image_asset_id?: string };

export function initPoslechState(
  exerciseType: PoslechType,
  detail: Record<string, unknown>,
): PoslechState {
  const ca = (detail.correct_answers ?? {}) as Record<string, string>;

  if (exerciseType === 'poslech_1' || exerciseType === 'poslech_2') {
    const rawItems = (detail.items ?? []) as Array<Record<string, unknown>>;
    const items: P12Item[] = Array.from({ length: ITEM_COUNT }, (_, i) => {
      const raw = rawItems[i] as Record<string, unknown> | undefined;
      const segs = ((raw?.audio_source as Record<string, unknown>)?.segments ??
        []) as Array<{ speaker?: string; text: string }>;
      const opts = (raw?.options ?? []) as RawOption[];
      const text = segs
        .map((s) => (s.speaker ? `[${s.speaker}]: ${s.text}` : s.text))
        .join('\n');
      const get = (k: string) => opts.find((o) => o.key === k)?.text ?? '';
      const getImg = (k: string) =>
        opts.find((o) => o.key === k)?.image_asset_id ?? '';
      return {
        question: String(raw?.question ?? ''),
        text,
        optA: get('A'),
        optB: get('B'),
        optC: get('C'),
        optD: get('D'),
        imgA: getImg('A'),
        imgB: getImg('B'),
        imgC: getImg('C'),
        imgD: getImg('D'),
        answer: ca[String(i + 1)] ?? '',
      };
    });
    return { type: exerciseType, items };
  }

  if (exerciseType === 'poslech_3' || exerciseType === 'poslech_4') {
    const rawItems = (detail.items ?? []) as Array<Record<string, unknown>>;
    const rawOpts = (detail.options ?? []) as Array<Record<string, unknown>>;
    const keys = exerciseType === 'poslech_3' ? OPTION_KEYS_3 : OPTION_KEYS_4;
    const options: SharedOption[] = keys.map((k, i) => {
      const raw = rawOpts[i] as Record<string, unknown> | undefined;
      return { key: k, label: String(raw?.label ?? raw?.asset_id ?? '') };
    });
    const items: MatchItem[] = Array.from({ length: ITEM_COUNT }, (_, i) => {
      const raw = rawItems[i] as Record<string, unknown> | undefined;
      const segs = ((raw?.audio_source as Record<string, unknown>)?.segments ??
        []) as Array<{ speaker?: string; text: string }>;
      const text = segs
        .map((s) => (s.speaker ? `[${s.speaker}]: ${s.text}` : s.text))
        .join('\n');
      return { text, answer: ca[String(i + 1)] ?? '' };
    });
    return { type: exerciseType, items, options };
  }

  const segs = ((detail.audio_source as Record<string, unknown>)?.segments ??
    []) as Array<{ text: string }>;
  const slots: FillSlot[] = Array.from({ length: ITEM_COUNT }, (_, i) => ({
    answer: ca[String(i + 1)] ?? '',
  }));
  return {
    type: 'poslech_5',
    voiceText: segs.map((s) => s.text).join('\n'),
    slots,
  };
}

export function buildPoslechDetail(
  state: PoslechState,
  audioSource: 'text' | 'upload',
): Record<string, unknown> {
  const seg = (text: string) =>
    text
      .split('\n')
      .filter(Boolean)
      .map((t) => {
        const m = t.match(/^\[([^\]]+)\]:\s*(.+)/);
        return m
          ? { speaker: m[1].trim(), text: m[2].trim() }
          : { text: t.trim() };
      });

  if (state.type === 'poslech_1' || state.type === 'poslech_2') {
    const correct: Record<string, string> = {};
    const items = state.items.map((item, i) => {
      if (item.answer) correct[String(i + 1)] = item.answer;
      const buildOpt = (k: 'A' | 'B' | 'C' | 'D') => {
        const text = item[`opt${k}` as const];
        const img = item[`img${k}` as const];
        // image_asset_id omitted when empty so the wire shape matches V26
        // (and earlier) exercises that never had images.
        return img ? { key: k, text, image_asset_id: img } : { key: k, text };
      };
      return {
        question_no: i + 1,
        question: item.question,
        audio_source: { type: audioSource, segments: seg(item.text) },
        options: [buildOpt('A'), buildOpt('B'), buildOpt('C'), buildOpt('D')],
      };
    });
    return { items, correct_answers: correct };
  }

  if (state.type === 'poslech_3' || state.type === 'poslech_4') {
    const correct: Record<string, string> = {};
    const items = state.items.map((item, i) => {
      if (item.answer) correct[String(i + 1)] = item.answer;
      return {
        question_no: i + 1,
        audio_source: { type: audioSource, segments: seg(item.text) },
      };
    });
    const rawOptions =
      state.type === 'poslech_4'
        ? state.options.map((o) => ({ key: o.key, asset_id: o.label }))
        : state.options.map((o) => ({ key: o.key, label: o.label }));
    return { items, options: rawOptions, correct_answers: correct };
  }

  const s5 = state as P5State;
  const correct: Record<string, string> = {};
  s5.slots.forEach((slot, i) => {
    if (slot.answer) correct[String(i + 1)] = slot.answer;
  });
  return {
    audio_source: { type: audioSource, segments: seg(s5.voiceText) },
    questions: s5.slots.map((_, i) => ({ question_no: i + 1, prompt: '' })),
    correct_answers: correct,
  };
}

/**
 * V27 — count how many of A-D options on a single P12 item carry a non-empty
 * image_asset_id. Used by validation to enforce the all-or-none publish rule.
 * Returns 0 when none, 4 when all, 1-3 for the mixed (rejected) state.
 */
export function countItemImages(item: P12Item): number {
  return [item.imgA, item.imgB, item.imgC, item.imgD].filter((x) => x && x.trim() !== '').length;
}

export type OptionKey = 'A' | 'B' | 'C' | 'D';

/**
 * V28 — factory for the AiImageButton onAssetCreated callback per option.
 * Returns a setter that knows which option key to update on the parent
 * patch function. Extracted so tests can drive the wire without rendering
 * AiImageButton (no React Testing Library in this project).
 *
 * Usage:
 *   const patcher = makeOptionImagePatcher(patch, 'A');
 *   <AiImageButton onAssetCreated={(r) => patcher(r.assetId)} />
 */
export function makeOptionImagePatcher(
  onPatch: (partial: Partial<P12Item>) => void,
  optionKey: OptionKey,
): (assetId: string) => void {
  return (assetId) => {
    onPatch({ [`img${optionKey}`]: assetId } as Partial<P12Item>);
  };
}
