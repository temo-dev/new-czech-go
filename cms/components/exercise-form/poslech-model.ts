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
  // V32 — hidden form state for per-item Polly output. The learner app reads
  // detail.items[i].audio_source.asset_id to decide whether to render the
  // mini-player for each poslech_1 item.
  audioAssetId: string;
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

export type MatchItem = {
  questionNo: number;
  question: string;
  text: string;
  answer: string;
};
export type SharedOption = { key: string; label: string };
export type FillSlot = { questionNo: number; prompt: string; answer: string };

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

function readQuestionNo(raw: Record<string, unknown> | undefined, fallback: number): number {
  const n = Number(raw?.question_no);
  return Number.isFinite(n) && n > 0 ? n : fallback;
}

export function initPoslechState(
  exerciseType: PoslechType,
  detail: Record<string, unknown>,
): PoslechState {
  const ca = (detail.correct_answers ?? {}) as Record<string, string>;

  if (exerciseType === 'poslech_1' || exerciseType === 'poslech_2') {
    const rawItems = (detail.items ?? []) as Array<Record<string, unknown>>;
    const items: P12Item[] = Array.from({ length: ITEM_COUNT }, (_, i) => {
      const raw = rawItems[i] as Record<string, unknown> | undefined;
      const audio = (raw?.audio_source as Record<string, unknown>) ?? {};
      const segs = (audio.segments ?? []) as Array<{ speaker?: string; text: string }>;
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
        audioAssetId: String(audio.asset_id ?? ''),
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
      const questionNo = readQuestionNo(raw, i + 1);
      const segs = ((raw?.audio_source as Record<string, unknown>)?.segments ??
        []) as Array<{ speaker?: string; text: string }>;
      const text = segs
        .map((s) => (s.speaker ? `[${s.speaker}]: ${s.text}` : s.text))
        .join('\n');
      return {
        questionNo,
        question: String(raw?.question ?? ''),
        text,
        answer: ca[String(questionNo)] ?? ca[String(i + 1)] ?? '',
      };
    });
    return { type: exerciseType, items, options };
  }

  const segs = ((detail.audio_source as Record<string, unknown>)?.segments ??
    []) as Array<{ text: string }>;
  const rawQs = (detail.questions ?? []) as Array<Record<string, unknown>>;
  const slots: FillSlot[] = Array.from({ length: ITEM_COUNT }, (_, i) => {
    const fallbackNo = 21 + i;
    const raw =
      rawQs.find((q) => Number(q.question_no) === fallbackNo) ?? rawQs[i];
    const legacyNo = readQuestionNo(raw, i + 1);
    return {
      questionNo: fallbackNo,
      prompt: String(raw?.prompt ?? ''),
      answer:
        ca[String(fallbackNo)] ?? ca[String(legacyNo)] ?? ca[String(i + 1)] ?? '',
    };
  });
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
        audio_source: {
          type: audioSource,
          ...(item.audioAssetId ? { asset_id: item.audioAssetId } : {}),
          segments: seg(item.text),
        },
        options: [buildOpt('A'), buildOpt('B'), buildOpt('C'), buildOpt('D')],
      };
    });
    return { items, correct_answers: correct };
  }

  if (state.type === 'poslech_3' || state.type === 'poslech_4') {
    const correct: Record<string, string> = {};
    const items = state.items.map((item, i) => {
      const questionNo = item.questionNo > 0 ? item.questionNo : i + 1;
      if (item.answer) correct[String(questionNo)] = item.answer;
      return {
        question_no: questionNo,
        ...(state.type === 'poslech_3' && item.question.trim()
          ? { question: item.question }
          : {}),
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
    const questionNo = slot.questionNo > 0 ? slot.questionNo : 21 + i;
    if (slot.answer) correct[String(questionNo)] = slot.answer;
  });
  return {
    audio_source: { type: audioSource, segments: seg(s5.voiceText) },
    questions: s5.slots.map((slot, i) => ({
      question_no: slot.questionNo > 0 ? slot.questionNo : 21 + i,
      prompt: slot.prompt,
    })),
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
export type SharedImageOptionKey = 'A' | 'B' | 'C' | 'D' | 'E' | 'F';

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

/**
 * POSLECH 4 stores the six shared image choices as `options[].asset_id`.
 * This mirrors makeOptionImagePatcher for the shared A-F option pool so the
 * upload and AI callbacks can update exactly one option.
 */
export function makeSharedOptionImagePatcher(
  onPatch: (optionKey: SharedImageOptionKey, assetId: string) => void,
  optionKey: SharedImageOptionKey,
): (assetId: string) => void {
  return (assetId) => onPatch(optionKey, assetId);
}

/**
 * V32 — generate-audio needs to synthesize fresh files from the current
 * transcript text. Normal CMS saves preserve audio_source.asset_id, but the
 * pre-generate PATCH intentionally clears item asset ids so the backend does
 * not treat already-generated files as uploaded audio and skip regeneration.
 */
export function stripPoslechItemAudioAssetIds(
  detail: Record<string, unknown>,
): Record<string, unknown> {
  const items = detail.items;
  if (!Array.isArray(items)) return detail;
  return {
    ...detail,
    items: items.map((raw) => {
      if (raw == null || typeof raw !== 'object' || Array.isArray(raw)) return raw;
      const item = raw as Record<string, unknown>;
      const audio = item.audio_source;
      if (audio == null || typeof audio !== 'object' || Array.isArray(audio)) return item;
      const { asset_id: _assetId, ...restAudio } = audio as Record<string, unknown>;
      return {
        ...item,
        audio_source: restAudio,
      };
    }),
  };
}

/**
 * V29 — extract the storage_key from a successful upload response. The
 * asset upload endpoint returns
 * `{ data: { asset: { id, storage_key, ... } } }`. Throws when storage_key
 * is missing so callers don't silently leave imgK empty after an "ok"
 * response.
 *
 * V30 hotfix — earlier wire stored `asset.id` here, but Flutter
 * `mediaUri(imgK)` queries `/v1/media/file?key=<imgK>` and the server
 * resolves the key as a storage_key (not an asset_id). Storing the id
 * caused `option.imageAssetId` lookups to 404 and the learner UI to fall
 * back to letter placeholders.
 */
export function parseUploadResponse(json: unknown): string {
  const data = (json as { data?: { asset?: { storage_key?: unknown } } } | null)?.data;
  const storageKey = data?.asset?.storage_key;
  if (typeof storageKey !== 'string' || storageKey === '') {
    throw new Error('Upload response missing asset.storage_key');
  }
  return storageKey;
}

/**
 * V29 — uploading-key encodes which (item index, option key) cell is
 * currently uploading. Used as a single-flight guard so admins can't
 * double-fire while a request is in flight.
 */
export function uploadingKeyFor(itemIndex: number, optionKey: OptionKey): string {
  return `${itemIndex}-${optionKey}`;
}

export function sharedUploadingKeyFor(optionKey: SharedImageOptionKey): string {
  return `shared-${optionKey}`;
}
