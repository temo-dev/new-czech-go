import type { CSSProperties } from 'react';

// ─── Types ───────────────────────────────────────────────────────────────────

export type PromptAsset = {
  id: string;
  asset_kind: string;
  storage_key: string;
  mime_type: string;
  sequence_no?: number;
};

export type CmsCourse = { id: string; title: string };
export type CmsModule = { id: string; title: string; course_id: string; sequence_no?: number };
export type CmsMockTest = { id: string; title: string; sections: Array<{ exercise_id: string }> };

export type Exercise = {
  id: string;
  module_id?: string;
  skill_kind?: string;
  pool?: string;
  title: string;
  exercise_type: string;
  short_instruction: string;
  learner_instruction?: string;
  estimated_duration_sec?: number;
  prep_time_sec?: number;
  recording_time_limit_sec?: number;
  sample_answer_enabled?: boolean;
  sample_answer_text?: string;
  status?: string;
  assets?: PromptAsset[];
  prompt?: {
    topic_label?: string;
    question_prompts?: string[];
  };
  detail?: Record<string, unknown>;
};

export type ExerciseType =
  | 'uloha_1_topic_answers'
  | 'uloha_2_dialogue_questions'
  | 'uloha_3_story_narration'
  | 'uloha_4_choice_reasoning'
  | 'psani_1_formular'
  | 'psani_2_email'
  | 'poslech_1'
  | 'poslech_2'
  | 'poslech_3'
  | 'poslech_4'
  | 'poslech_5'
  | 'poslech_6'
  | 'cteni_1'
  | 'cteni_2'
  | 'cteni_3'
  | 'cteni_4'
  | 'cteni_5'
  | 'cteni_6'
  | 'quizcard_basic'
  | 'matching'
  | 'fill_blank'
  | 'choice_word'
  | 'interview_conversation'
  | 'interview_choice_explain';

export type ExerciseFormState = {
  exerciseType: ExerciseType;
  title: string;
  shortInstruction: string;
  learnerInstruction: string;
  moduleId: string;
  skillKind: string;
  questions: string;
  scenarioTitle: string;
  scenarioPrompt: string;
  requiredInfoSlots: string;
  customQuestionHint: string;
  storyTitle: string;
  imageAssetIds: string;
  narrativeCheckpoints: string;
  grammarFocus: string;
  choiceScenarioPrompt: string;
  choiceOptions: string;
  expectedReasoningAxes: string;
  sampleAnswerText: string;
  status: string;
  pool: string;
  formularQuestions: string;
  formularMinWords: number;
  emailPrompt: string;
  emailTopics: string;
  emailMinWords: number;
  poslechItems: string;
  poslechOptions: string;
  poslechCorrectAnswers: string;
  poslechAudioSource: 'text' | 'upload';
  poslechVoicemailText: string;
  cteniText: string;
  cteniItems: string;
  cteniOptions: string;
  cteniQuestions: string;
  cteniCorrectAnswers: string;
  typePayload?: Record<string, unknown>;
};

// ─── Constants ────────────────────────────────────────────────────────────────

export const adminApi = '/api/admin/exercises';

export const exerciseTypeOptions: Array<{ value: ExerciseType; label: string; hint: string }> = [
  { value: 'uloha_1_topic_answers',    label: 'Uloha 1',             hint: 'Topic answers with 3-4 short prompts.' },
  { value: 'uloha_2_dialogue_questions', label: 'Uloha 2',           hint: 'Dialogue task where the learner asks for missing information.' },
  { value: 'uloha_3_story_narration',  label: 'Uloha 3',             hint: 'Story narration from four images or checkpoints.' },
  { value: 'uloha_4_choice_reasoning', label: 'Uloha 4',             hint: 'Choose one option and justify the choice.' },
  { value: 'psani_1_formular',         label: 'Psaní 1 — Formulář',  hint: 'Writing: 3 form questions, ≥10 words each (8 pts).' },
  { value: 'psani_2_email',            label: 'Psaní 2 — E-mail',    hint: 'Writing: email from 5 image prompts, ≥35 words (12 pts).' },
  { value: 'poslech_1',  label: 'Poslech 1', hint: 'Listening: 5 short passages → A-D (5 pts).' },
  { value: 'poslech_2',  label: 'Poslech 2', hint: 'Listening: 5 short passages → A-D (5 pts).' },
  { value: 'poslech_3',  label: 'Poslech 3', hint: 'Listening: 5 passages → match A-G (5 pts).' },
  { value: 'poslech_4',  label: 'Poslech 4', hint: 'Listening: 5 dialogs → choose image A-F (5 pts).' },
  { value: 'poslech_5',  label: 'Poslech 5', hint: 'Listening: voicemail → fill info (5 pts).' },
  { value: 'poslech_6',  label: 'Poslech 6 — Ano/Ne', hint: 'Listening: hear passage → 1-5 Ano/Ne statements.' },
  { value: 'cteni_1',    label: 'Čtení 1',   hint: 'Reading: match 5 images/messages → A-H (5 pts).' },
  { value: 'cteni_2',    label: 'Čtení 2',   hint: 'Reading: read text → choose A-D, 5 questions (5 pts).' },
  { value: 'cteni_3',    label: 'Čtení 3',   hint: 'Reading: match 4 texts → persons A-E (4 pts).' },
  { value: 'cteni_4',    label: 'Čtení 4',   hint: 'Reading: choose A-D, 6 questions (6 pts).' },
  { value: 'cteni_5',    label: 'Čtení 5',   hint: 'Reading: read text → fill info, 5 items (5 pts).' },
  { value: 'cteni_6',    label: 'Čtení 6 — Ano/Ne', hint: 'Reading: read passage → 1-5 Ano/Ne statements.' },
  { value: 'quizcard_basic', label: 'Flashcard', hint: 'Từ vựng — lật thẻ, biết/ôn lại.' },
  { value: 'matching',       label: 'Ghép đôi',  hint: 'Ghép 4-6 cặp Czech→Vietnamese. Exact match.' },
  { value: 'fill_blank',     label: 'Điền từ',   hint: 'Câu với ___ — điền từ thích hợp.' },
  { value: 'choice_word',    label: 'Chọn từ',   hint: 'Câu + 4 lựa chọn A-D — chọn từ đúng.' },
  { value: 'interview_conversation',   label: 'Hội thoại theo chủ đề',      hint: 'Hội thoại real-time với avatar Czech examiner AI. Admin nhập system_prompt và chủ đề.' },
  { value: 'interview_choice_explain', label: 'Chọn phương án + giải thích', hint: 'Learner chọn 1 trong 3–4 phương án, rồi hội thoại giải thích lý do với examiner AI.' },
];

export const SKILL_KIND_EXERCISE_TYPES: Record<string, ExerciseType[]> = {
  noi:       ['uloha_1_topic_answers', 'uloha_2_dialogue_questions', 'uloha_3_story_narration', 'uloha_4_choice_reasoning'],
  viet:      ['psani_1_formular', 'psani_2_email'],
  nghe:      ['poslech_1', 'poslech_2', 'poslech_3', 'poslech_4', 'poslech_5', 'poslech_6'],
  doc:       ['cteni_1', 'cteni_2', 'cteni_3', 'cteni_4', 'cteni_5', 'cteni_6'],
  tu_vung:   ['quizcard_basic', 'matching', 'fill_blank', 'choice_word'],
  ngu_phap:  ['matching', 'fill_blank', 'choice_word'],
  interview: ['interview_conversation', 'interview_choice_explain'],
};

export const SKILL_KIND_META: Record<string, { label: string; icon: string; color: string }> = {
  noi:       { label: 'Nói',           icon: '🎙️', color: '#FF6A14' },
  viet:      { label: 'Viết',          icon: '✏️',  color: '#0F3D3A' },
  nghe:      { label: 'Nghe',          icon: '🎧',  color: '#7C3AED' },
  doc:       { label: 'Đọc',           icon: '📖',  color: '#0369A1' },
  tu_vung:   { label: 'Từ vựng',       icon: '📚',  color: '#059669' },
  ngu_phap:  { label: 'Ngữ pháp',      icon: '📝',  color: '#DC2626' },
  interview: { label: 'Phỏng vấn AI',  icon: '🎙',  color: '#0891B2' },
};

// ─── Style constants ──────────────────────────────────────────────────────────

export const fieldStyle = {
  width: '100%',
  padding: '14px 16px',
  borderRadius: 16,
  border: '1px solid var(--border)',
  background: 'var(--surface-muted)',
  color: 'var(--text)',
  lineHeight: 1.5,
} as const satisfies CSSProperties;

export const badgeStyle = {
  alignSelf: 'start',
  padding: '6px 12px',
  borderRadius: 999,
  background: 'var(--primary-soft)',
  color: 'var(--primary-strong)',
  fontSize: 12,
  fontWeight: 700,
  textTransform: 'uppercase' as const,
  letterSpacing: '0.06em',
} as const satisfies CSSProperties;

export const eyebrowStyle = {
  margin: 0,
  color: 'var(--accent)',
  fontSize: 12,
  fontWeight: 700,
  textTransform: 'uppercase' as const,
  letterSpacing: '0.12em',
} as const satisfies CSSProperties;

export const fieldLabelStyle = {
  color: 'var(--text)',
  fontWeight: 700,
} as const satisfies CSSProperties;

export const fieldHintStyle = {
  color: 'var(--text-secondary)',
  fontSize: 13,
  lineHeight: 1.45,
} as const satisfies CSSProperties;

export const metricCardStyle = {
  display: 'grid',
  gap: 6,
  padding: 18,
  borderRadius: 22,
  border: '1px solid var(--border)',
  background: 'var(--surface-warm)',
} as const satisfies CSSProperties;

export const metricLabelStyle = {
  color: 'var(--text-secondary)',
  fontSize: 12,
  fontWeight: 700,
  textTransform: 'uppercase' as const,
  letterSpacing: '0.08em',
} as const satisfies CSSProperties;

export const metricValueStyle = {
  color: 'var(--text)',
  fontSize: 22,
  lineHeight: 1.1,
} as const satisfies CSSProperties;

export const metricHintStyle = {
  color: 'var(--text-secondary)',
  fontSize: 14,
} as const satisfies CSSProperties;

export const secondaryActionStyle = {
  borderRadius: 14,
  border: '1px solid var(--border)',
  background: 'var(--surface)',
  padding: '10px 14px',
  cursor: 'pointer',
  fontWeight: 700,
  color: 'var(--text)',
} as const satisfies CSSProperties;

export const dangerActionStyle = {
  borderRadius: 14,
  border: '1px solid color-mix(in srgb, var(--danger) 25%, white)',
  background: 'color-mix(in srgb, var(--danger) 8%, white)',
  padding: '10px 14px',
  cursor: 'pointer',
  fontWeight: 700,
  color: 'var(--danger)',
} as const satisfies CSSProperties;

// ─── Pure functions ───────────────────────────────────────────────────────────

export function filterSelectStyle(active: boolean): CSSProperties {
  return {
    borderRadius: 8,
    border: `1px solid ${active ? 'var(--brand)' : 'var(--border)'}`,
    background: active ? 'rgba(255,106,20,0.06)' : 'var(--surface)',
    padding: '6px 10px',
    fontSize: 12,
    cursor: 'pointer',
    color: active ? 'var(--brand)' : 'var(--ink-3)',
    fontWeight: active ? 700 : 400,
    outline: 'none',
  };
}

export function createInitialFormState(): ExerciseFormState {
  return {
    exerciseType: 'uloha_1_topic_answers',
    title: 'Pocasi 2',
    shortInstruction: 'Tra loi ngan gon va ro y.',
    learnerInstruction: 'Ban hay tra loi ngan gon theo chu de thoi tiet.',
    moduleId: 'module-day-1',
    skillKind: '',
    questions:
      'Jake pocasi mate dnes?\nCo delate, kdyz je venku hezky?\nMate rad/a zimu?\nJake pocasi bude zitra?',
    scenarioTitle: 'Navsteva kina',
    scenarioPrompt:
      'Chcete jit do kina na vecerni film. Potrebujete zjistit cas zacatku, cenu listku a jestli je mozne koupit listky online.',
    requiredInfoSlots:
      'start_time | Cas zacatku | V kolik hodin film zacina?\nprice | Cena listku | Kolik stoji jeden listek?\nonline_ticket | Nakup online | Muzu si koupit listek online?',
    customQuestionHint: 'Pridejte jeste jednu otazku, treba na sal nebo titulky.',
    storyTitle: 'Nakup televize',
    imageAssetIds: 'asset-tv-1\nasset-tv-2\nasset-tv-3\nasset-tv-4',
    narrativeCheckpoints:
      'Otec a syn sli do obchodu.\nDivali se na televize a porovnavali je.\nVybrali jednu televizi a zaplatili ji.\nOdvezli televizi domu autem.',
    grammarFocus: 'past_tense',
    choiceScenarioPrompt: 'Hledate bydleni v Praze. Ktery byt si vyberete a proc?',
    choiceOptions:
      'flat_a | Byt A | Levnejsi, ale daleko od centra.\nflat_b | Byt B | Blizko centra, ale mensi.\nflat_c | Byt C | Vetsi a klidny, ale drazsi.',
    expectedReasoningAxes: 'price\nlocation\nspace',
    sampleAnswerText: '',
    status: 'draft',
    pool: 'course',
    formularQuestions:
      'Jak jste získal/a informace o našem e-shopu?\nProč v našem e-shopu nakupujete?\nKteré služby nebo informace vám v našem e-shopu chybí?',
    formularMinWords: 10,
    emailPrompt: 'Jste na dovolené a chcete napsat své kamarádce.',
    emailTopics:
      'KDE JSTE?\nJAK DLOUHO TAM JSTE?\nKDE BYDLÍTE?\nCO DĚLÁTE DOPOLEDNE?\nCO DĚLÁTE ODPOLEDNE?',
    emailMinWords: 35,
    poslechItems: 'Kde je nádraží?\n---\nJak se jmenujete?',
    poslechOptions: 'A | Možnost A\nB | Možnost B\nC | Možnost C\nD | Možnost D',
    poslechCorrectAnswers: '1=B\n2=A\n3=D\n4=C\n5=B',
    poslechAudioSource: 'text',
    poslechVoicemailText: 'Ahoj Lído, tady Eva. Dostala jsem lístky na balet.',
    cteniText: 'Přečtěte si text...',
    cteniItems: 'Položka 1\n---\nPoložka 2\n---\nPoložka 3\n---\nPoložka 4\n---\nPoložka 5',
    cteniOptions: 'A | Možnost A\nB | Možnost B\nC | Možnost C\nD | Možnost D',
    cteniQuestions: 'Otázka 1?\nOtázka 2?\nOtázka 3?\nOtázka 4?\nOtázka 5?',
    cteniCorrectAnswers: '1=A\n2=B\n3=C\n4=D\n5=A',
  };
}

export function parseLineList(input: string): string[] {
  return input.split('\n').map((line) => line.trim()).filter(Boolean);
}

export function parseRequiredInfoSlots(input: string) {
  return input
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      const [slotKey = '', label = '', sampleQuestion = ''] = line
        .split('|')
        .map((part) => part.trim());
      if (!slotKey || !label) {
        throw new Error(
          'Each required-info line must follow `slot_key | label | sample question`.',
        );
      }
      return {
        slot_key: slotKey,
        label,
        ...(sampleQuestion ? { sample_question: sampleQuestion } : {}),
      };
    });
}

export function parseChoiceOptions(input: string) {
  return input
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      const [optionKey = '', label = '', description = '', imageAssetId = ''] = line
        .split('|')
        .map((part) => part.trim());
      if (!optionKey || !label) {
        throw new Error(
          'Each choice-option line must follow `option_key | label | description`.',
        );
      }
      return {
        option_key: optionKey,
        label,
        ...(description ? { description } : {}),
        ...(imageAssetId ? { image_asset_id: imageAssetId } : {}),
      };
    });
}

export function parsePoslechOptions(input: string, type: 'choice' | 'match' | 'image') {
  return input
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      const [key = '', value = ''] = line.split('|').map((p) => p.trim());
      if (type === 'image') return { key, asset_id: value };
      if (type === 'match') return { key, label: value };
      return { key, text: value };
    });
}

export function parsePoslechCorrectAnswers(input: string): Record<string, string> {
  const result: Record<string, string> = {};
  input
    .split('\n')
    .map((l) => l.trim())
    .filter(Boolean)
    .forEach((line) => {
      const [k, v] = line.split('=');
      if (k && v) result[k.trim()] = v.trim();
    });
  return result;
}

export function parsePoslechItems(input: string, questionCount: number) {
  const blocks = input.split(/\n---\n/).map((b) => b.trim()).filter(Boolean);
  return Array.from({ length: questionCount }, (_, i) => {
    const block = blocks[i] ?? '';
    const segments = block.split('\n').filter(Boolean).map((t) => ({ text: t.trim() }));
    return {
      question_no: i + 1,
      audio_source: { segments },
      options: [] as unknown[],
    };
  });
}

export function parseCteniCorrectAnswers(input: string): Record<string, string> {
  const result: Record<string, string> = {};
  input
    .split('\n')
    .map((l) => l.trim())
    .filter(Boolean)
    .forEach((line) => {
      const [k, v] = line.split('=');
      if (k && v) result[k.trim()] = v.trim();
    });
  return result;
}

export function appendLineIfMissing(input: string, value: string): string {
  const lines = parseLineList(input);
  if (lines.includes(value)) return input;
  return [...lines, value].join('\n');
}

export function assetPreviewSrc(exerciseId: string, asset: PromptAsset): string {
  if (
    asset.storage_key.startsWith('http://') ||
    asset.storage_key.startsWith('https://')
  ) {
    return asset.storage_key;
  }
  return `${adminApi}/${exerciseId}/assets/${asset.id}/file`;
}

export function formStateFromExercise(item: Exercise): ExerciseFormState {
  const detail = item.detail ?? {};
  const prompt = item.prompt ?? {};

  return {
    exerciseType: item.exercise_type as ExerciseType,
    title: item.title ?? '',
    shortInstruction: item.short_instruction ?? '',
    learnerInstruction: item.learner_instruction ?? '',
    moduleId: item.module_id ?? '',
    skillKind: item.skill_kind ?? '',
    questions: (prompt.question_prompts ?? []).join('\n'),
    scenarioTitle: String(detail.scenario_title ?? ''),
    scenarioPrompt: String(detail.scenario_prompt ?? ''),
    requiredInfoSlots: Array.isArray(detail.required_info_slots)
      ? (detail.required_info_slots as Array<Record<string, unknown>>)
          .map(
            (slot) =>
              `${slot.slot_key ?? ''} | ${slot.label ?? ''} | ${slot.sample_question ?? ''}`,
          )
          .join('\n')
      : '',
    customQuestionHint: String(detail.custom_question_hint ?? ''),
    storyTitle: String(detail.story_title ?? ''),
    imageAssetIds: Array.isArray(detail.image_asset_ids)
      ? (detail.image_asset_ids as unknown[]).map(String).join('\n')
      : '',
    narrativeCheckpoints: Array.isArray(detail.narrative_checkpoints)
      ? (detail.narrative_checkpoints as unknown[]).map(String).join('\n')
      : '',
    grammarFocus: Array.isArray(detail.grammar_focus)
      ? (detail.grammar_focus as unknown[]).map(String).join('\n')
      : '',
    choiceScenarioPrompt: String(detail.scenario_prompt ?? ''),
    choiceOptions: Array.isArray(detail.options)
      ? (detail.options as Array<Record<string, unknown>>)
          .map(
            (option) =>
              `${option.option_key ?? ''} | ${option.label ?? ''} | ${option.description ?? ''} | ${option.image_asset_id ?? ''}`,
          )
          .join('\n')
      : '',
    expectedReasoningAxes: Array.isArray(detail.expected_reasoning_axes)
      ? (detail.expected_reasoning_axes as unknown[]).map(String).join('\n')
      : '',
    sampleAnswerText: item.sample_answer_text ?? '',
    status: item.status ?? 'draft',
    pool: (item as { pool?: string }).pool ?? 'course',
    formularQuestions: Array.isArray(detail.questions)
      ? (detail.questions as unknown[]).map(String).join('\n')
      : '',
    formularMinWords: typeof detail.min_words === 'number' ? detail.min_words : 10,
    emailPrompt: String(detail.prompt ?? ''),
    emailTopics: Array.isArray(detail.topics)
      ? (detail.topics as unknown[]).map(String).join('\n')
      : '',
    emailMinWords: typeof detail.min_words === 'number' ? detail.min_words : 35,
    poslechItems: '',
    poslechOptions: Array.isArray(detail.options)
      ? (detail.options as Array<Record<string, unknown>>)
          .map((o) => `${o.key ?? ''} | ${o.label ?? o.asset_id ?? ''}`)
          .join('\n')
      : '',
    poslechCorrectAnswers: detail.correct_answers
      ? Object.entries(detail.correct_answers as Record<string, string>)
          .map(([k, v]) => `${k}=${v}`)
          .join('\n')
      : '',
    poslechAudioSource: 'text',
    poslechVoicemailText: (() => {
      const segs = (detail.audio_source as Record<string, unknown> | undefined)?.segments;
      return Array.isArray(segs)
        ? (segs as Array<Record<string, unknown>>).map((s) => s.text ?? '').join('\n')
        : '';
    })(),
    cteniText: (detail.text as string) ?? '',
    cteniItems: (() => {
      if (Array.isArray(detail.items)) {
        return (detail.items as Array<Record<string, unknown>>)
          .map((i) => i.text ?? '')
          .join('\n---\n');
      }
      if (Array.isArray(detail.texts)) {
        return (detail.texts as Array<Record<string, unknown>>)
          .map((i) => i.text ?? '')
          .join('\n---\n');
      }
      return '';
    })(),
    cteniOptions: (() => {
      if (Array.isArray(detail.options)) {
        return (detail.options as Array<Record<string, unknown>>)
          .map((o) => `${o.key ?? ''} | ${o.text ?? o.label ?? ''}`)
          .join('\n');
      }
      if (Array.isArray(detail.persons)) {
        return (detail.persons as Array<Record<string, unknown>>)
          .map((p) => `${p.key ?? ''} | ${p.name ?? ''}`)
          .join('\n');
      }
      return '';
    })(),
    cteniQuestions: Array.isArray(detail.questions)
      ? (detail.questions as Array<Record<string, unknown>>)
          .map((q) => q.prompt ?? '')
          .join('\n')
      : '',
    cteniCorrectAnswers: detail.correct_answers
      ? Object.entries(detail.correct_answers as Record<string, string>)
          .map(([k, v]) => `${k}=${v}`)
          .join('\n')
      : '',
    typePayload:
      item.exercise_type.startsWith('poslech_') ||
      item.exercise_type.startsWith('cteni_') ||
      item.exercise_type === 'quizcard_basic' ||
      item.exercise_type === 'matching' ||
      item.exercise_type === 'fill_blank' ||
      item.exercise_type === 'choice_word' ||
      item.exercise_type === 'interview_conversation' ||
      item.exercise_type === 'interview_choice_explain'
        ? (detail as Record<string, unknown>)
        : undefined,
  };
}

export function buildPoslechBase(form: ExerciseFormState) {
  return {
    module_id: form.moduleId,
    skill_kind: form.skillKind,
    exercise_type: form.exerciseType,
    title: form.title,
    short_instruction: form.shortInstruction,
    learner_instruction: form.learnerInstruction,
    estimated_duration_sec: 1800,
    sample_answer_enabled: false,
    status: form.status,
    pool: form.pool,
  };
}

export function buildCteniBase(form: ExerciseFormState) {
  return {
    module_id: form.moduleId,
    skill_kind: form.skillKind,
    exercise_type: form.exerciseType,
    title: form.title,
    short_instruction: form.shortInstruction,
    learner_instruction: form.learnerInstruction,
    estimated_duration_sec: 2400,
    sample_answer_enabled: false,
    status: form.status,
    pool: form.pool,
  };
}

export function buildPoslechPayload(form: ExerciseFormState) {
  const correct = parsePoslechCorrectAnswers(form.poslechCorrectAnswers);
  const base = buildPoslechBase(form);
  if (form.exerciseType === 'poslech_5') {
    const segments = form.poslechVoicemailText
      .split('\n')
      .filter(Boolean)
      .map((t) => ({ text: t.trim() }));
    return {
      ...base,
      detail: {
        audio_source: { segments },
        questions: Object.keys(correct).map((k) => ({ question_no: parseInt(k), prompt: '' })),
        correct_answers: correct,
      },
    };
  }
  const items = parsePoslechItems(form.poslechItems, 5);
  const optionType =
    form.exerciseType === 'poslech_4'
      ? 'image'
      : form.exerciseType === 'poslech_3'
        ? 'match'
        : 'choice';
  const options = parsePoslechOptions(form.poslechOptions, optionType);
  return {
    ...base,
    detail: {
      items: items.map((item) => ({
        ...item,
        options: optionType === 'choice' ? options : [],
      })),
      options: optionType !== 'choice' ? options : undefined,
      correct_answers: correct,
    },
  };
}

export function buildCteniPayload(form: ExerciseFormState) {
  const correct = parseCteniCorrectAnswers(form.cteniCorrectAnswers);
  const base = buildCteniBase(form);
  if (form.exerciseType === 'cteni_1') {
    const items = form.cteniItems
      .split(/\n---\n/)
      .map((b, i) => ({ item_no: i + 1, text: b.trim() }));
    const options = parsePoslechOptions(form.cteniOptions, 'choice').map((o) => ({
      key: o.key,
      text: (o as Record<string, unknown>).text ?? '',
    }));
    return { ...base, detail: { items, options, correct_answers: correct } };
  }
  if (form.exerciseType === 'cteni_2' || form.exerciseType === 'cteni_4') {
    const questionPrompts = parseLineList(form.cteniQuestions);
    const questionOptions = parsePoslechOptions(form.cteniOptions, 'choice');
    const questions = questionPrompts.map((prompt, i) => ({
      question_no: i + (form.exerciseType === 'cteni_4' ? 15 : 6),
      prompt,
      options: questionOptions,
    }));
    return {
      ...base,
      detail: { text: form.cteniText.trim(), questions, correct_answers: correct },
    };
  }
  if (form.exerciseType === 'cteni_3') {
    const texts = form.cteniItems
      .split(/\n---\n/)
      .map((b, i) => ({ item_no: i + 1, text: b.trim() }));
    const persons = form.cteniOptions
      .split('\n')
      .filter(Boolean)
      .map((line) => {
        const [key = '', name = ''] = line.split('|').map((p) => p.trim());
        return { key, name };
      });
    return { ...base, detail: { texts, persons, correct_answers: correct } };
  }
  const questions = parseLineList(form.cteniQuestions).map((prompt, i) => ({
    question_no: i + 21,
    prompt,
  }));
  return {
    ...base,
    detail: { text: form.cteniText.trim(), questions, correct_answers: correct },
  };
}

export function buildCreatePayload(form: ExerciseFormState) {
  if (form.exerciseType === 'interview_conversation' || form.exerciseType === 'interview_choice_explain') {
    return {
      module_id: form.moduleId, skill_kind: form.skillKind,
      exercise_type: form.exerciseType, title: form.title,
      short_instruction: form.shortInstruction, learner_instruction: form.learnerInstruction,
      estimated_duration_sec: 600, sample_answer_enabled: false,
      status: form.status, pool: form.pool,
      detail: form.typePayload ?? {},
    };
  }
  if (form.exerciseType.startsWith('cteni_')) {
    if (form.typePayload !== undefined) return { ...buildCteniBase(form), detail: form.typePayload };
    return buildCteniPayload(form);
  }
  if (form.exerciseType.startsWith('poslech_')) {
    if (form.typePayload !== undefined) return { ...buildPoslechBase(form), detail: form.typePayload };
    return buildPoslechPayload(form);
  }
  if (form.exerciseType === 'uloha_1_topic_answers') {
    return {
      module_id: form.moduleId, skill_kind: form.skillKind,
      exercise_type: form.exerciseType, title: form.title,
      short_instruction: form.shortInstruction, learner_instruction: form.learnerInstruction,
      estimated_duration_sec: 90, prep_time_sec: 10, recording_time_limit_sec: 45,
      sample_answer_enabled: true, sample_answer_text: form.sampleAnswerText.trim(),
      status: form.status, pool: form.pool,
      questions: parseLineList(form.questions),
    };
  }
  if (form.exerciseType === 'uloha_2_dialogue_questions') {
    return {
      module_id: form.moduleId, skill_kind: form.skillKind,
      exercise_type: form.exerciseType, title: form.title,
      short_instruction: form.shortInstruction, learner_instruction: form.learnerInstruction,
      estimated_duration_sec: 90, prep_time_sec: 10, recording_time_limit_sec: 45,
      sample_answer_enabled: true, sample_answer_text: form.sampleAnswerText.trim(),
      status: form.status, pool: form.pool,
      detail: {
        scenario_title: form.scenarioTitle, scenario_prompt: form.scenarioPrompt,
        required_info_slots: parseRequiredInfoSlots(form.requiredInfoSlots),
        custom_question_hint: form.customQuestionHint,
      },
    };
  }
  if (form.exerciseType === 'uloha_3_story_narration') {
    return {
      module_id: form.moduleId, skill_kind: form.skillKind,
      exercise_type: form.exerciseType, title: form.title,
      short_instruction: form.shortInstruction, learner_instruction: form.learnerInstruction,
      estimated_duration_sec: 120, prep_time_sec: 15, recording_time_limit_sec: 60,
      sample_answer_enabled: true, sample_answer_text: form.sampleAnswerText.trim(),
      status: form.status, pool: form.pool,
      detail: {
        story_title: form.storyTitle,
        image_asset_ids: parseLineList(form.imageAssetIds),
        narrative_checkpoints: parseLineList(form.narrativeCheckpoints),
        grammar_focus: parseLineList(form.grammarFocus),
      },
    };
  }
  if (form.exerciseType === 'psani_1_formular') {
    return {
      module_id: form.moduleId, skill_kind: form.skillKind,
      exercise_type: form.exerciseType, title: form.title,
      short_instruction: form.shortInstruction, learner_instruction: form.learnerInstruction,
      estimated_duration_sec: 600, sample_answer_enabled: false,
      sample_answer_text: form.sampleAnswerText.trim(),
      status: form.status, pool: form.pool,
      detail: { questions: parseLineList(form.formularQuestions), min_words: form.formularMinWords },
    };
  }
  if (form.exerciseType === 'psani_2_email') {
    return {
      module_id: form.moduleId, skill_kind: form.skillKind,
      exercise_type: form.exerciseType, title: form.title,
      short_instruction: form.shortInstruction, learner_instruction: form.learnerInstruction,
      estimated_duration_sec: 900, sample_answer_enabled: false,
      sample_answer_text: form.sampleAnswerText.trim(),
      status: form.status, pool: form.pool,
      detail: {
        prompt: form.emailPrompt.trim(), topics: parseLineList(form.emailTopics),
        image_asset_ids: parseLineList(form.imageAssetIds), min_words: form.emailMinWords,
      },
    };
  }
  if (['quizcard_basic', 'matching', 'fill_blank', 'choice_word'].includes(form.exerciseType)) {
    return {
      module_id: form.moduleId, skill_kind: form.skillKind,
      exercise_type: form.exerciseType, title: form.title,
      short_instruction: form.shortInstruction, learner_instruction: form.learnerInstruction,
      status: form.status, pool: form.pool,
      detail: form.typePayload ?? {},
    };
  }
  return {
    module_id: form.moduleId, exercise_type: form.exerciseType, title: form.title,
    short_instruction: form.shortInstruction, learner_instruction: form.learnerInstruction,
    estimated_duration_sec: 90, prep_time_sec: 10, recording_time_limit_sec: 45,
    sample_answer_enabled: true, sample_answer_text: form.sampleAnswerText.trim(),
    status: form.status,
    detail: {
      scenario_prompt: form.choiceScenarioPrompt,
      options: parseChoiceOptions(form.choiceOptions),
      expected_reasoning_axes: parseLineList(form.expectedReasoningAxes),
    },
  };
}

export function buildUpdatePayload(form: ExerciseFormState) {
  if (form.exerciseType === 'interview_conversation' || form.exerciseType === 'interview_choice_explain') {
    return {
      module_id: form.moduleId, skill_kind: form.skillKind,
      exercise_type: form.exerciseType, title: form.title,
      short_instruction: form.shortInstruction, learner_instruction: form.learnerInstruction,
      estimated_duration_sec: 600, sample_answer_enabled: false,
      status: form.status, pool: form.pool,
      detail: form.typePayload ?? {},
    };
  }
  if (form.exerciseType.startsWith('cteni_')) {
    if (form.typePayload !== undefined) return { ...buildCteniBase(form), detail: form.typePayload };
    return buildCteniPayload(form);
  }
  if (form.exerciseType.startsWith('poslech_')) {
    if (form.typePayload !== undefined) return { ...buildPoslechBase(form), detail: form.typePayload };
    return buildPoslechPayload(form);
  }
  if (form.exerciseType === 'uloha_1_topic_answers') {
    return {
      module_id: form.moduleId, skill_kind: form.skillKind,
      exercise_type: form.exerciseType, title: form.title,
      short_instruction: form.shortInstruction, learner_instruction: form.learnerInstruction,
      estimated_duration_sec: 90, prep_time_sec: 10, recording_time_limit_sec: 45,
      sample_answer_enabled: true, sample_answer_text: form.sampleAnswerText.trim(),
      status: form.status, pool: form.pool,
      prompt: { topic_label: form.title, question_prompts: parseLineList(form.questions) },
    };
  }
  if (form.exerciseType === 'uloha_2_dialogue_questions') {
    return {
      module_id: form.moduleId, skill_kind: form.skillKind,
      exercise_type: form.exerciseType, title: form.title,
      short_instruction: form.shortInstruction, learner_instruction: form.learnerInstruction,
      estimated_duration_sec: 90, prep_time_sec: 10, recording_time_limit_sec: 45,
      sample_answer_enabled: true, sample_answer_text: form.sampleAnswerText.trim(),
      status: form.status, pool: form.pool,
      detail: {
        scenario_title: form.scenarioTitle, scenario_prompt: form.scenarioPrompt,
        required_info_slots: parseRequiredInfoSlots(form.requiredInfoSlots),
        custom_question_hint: form.customQuestionHint,
      },
    };
  }
  if (form.exerciseType === 'uloha_3_story_narration') {
    return {
      module_id: form.moduleId, skill_kind: form.skillKind,
      exercise_type: form.exerciseType, title: form.title,
      short_instruction: form.shortInstruction, learner_instruction: form.learnerInstruction,
      estimated_duration_sec: 120, prep_time_sec: 15, recording_time_limit_sec: 60,
      sample_answer_enabled: true, sample_answer_text: form.sampleAnswerText.trim(),
      status: form.status, pool: form.pool,
      detail: {
        story_title: form.storyTitle,
        image_asset_ids: parseLineList(form.imageAssetIds),
        narrative_checkpoints: parseLineList(form.narrativeCheckpoints),
        grammar_focus: parseLineList(form.grammarFocus),
      },
    };
  }
  if (form.exerciseType === 'psani_1_formular') {
    return {
      module_id: form.moduleId, skill_kind: form.skillKind,
      exercise_type: form.exerciseType, title: form.title,
      short_instruction: form.shortInstruction, learner_instruction: form.learnerInstruction,
      estimated_duration_sec: 600, sample_answer_enabled: false,
      sample_answer_text: form.sampleAnswerText.trim(),
      status: form.status, pool: form.pool,
      detail: { questions: parseLineList(form.formularQuestions), min_words: form.formularMinWords },
    };
  }
  if (form.exerciseType === 'psani_2_email') {
    return {
      module_id: form.moduleId, skill_kind: form.skillKind,
      exercise_type: form.exerciseType, title: form.title,
      short_instruction: form.shortInstruction, learner_instruction: form.learnerInstruction,
      estimated_duration_sec: 900, sample_answer_enabled: false,
      sample_answer_text: form.sampleAnswerText.trim(),
      status: form.status, pool: form.pool,
      detail: {
        prompt: form.emailPrompt.trim(), topics: parseLineList(form.emailTopics),
        image_asset_ids: parseLineList(form.imageAssetIds), min_words: form.emailMinWords,
      },
    };
  }
  if (['quizcard_basic', 'matching', 'fill_blank', 'choice_word'].includes(form.exerciseType)) {
    return {
      module_id: form.moduleId, skill_kind: form.skillKind,
      exercise_type: form.exerciseType, title: form.title,
      short_instruction: form.shortInstruction, learner_instruction: form.learnerInstruction,
      status: form.status, pool: form.pool,
      detail: form.typePayload ?? {},
    };
  }
  return {
    module_id: form.moduleId, exercise_type: form.exerciseType, title: form.title,
    short_instruction: form.shortInstruction, learner_instruction: form.learnerInstruction,
    estimated_duration_sec: 90, prep_time_sec: 10, recording_time_limit_sec: 45,
    sample_answer_enabled: true, sample_answer_text: form.sampleAnswerText.trim(),
    status: form.status,
    detail: {
      scenario_prompt: form.choiceScenarioPrompt,
      options: parseChoiceOptions(form.choiceOptions),
      expected_reasoning_axes: parseLineList(form.expectedReasoningAxes),
    },
  };
}

// ─── V14: Interview helpers ───────────────────────────────────────────────────

export type InterviewOptionRow = {
  id: string;
  label: string;
  imageAssetId: string;
};

export type InterviewConversationFormState = {
  topic: string;
  tips: string[];
  systemPrompt: string;
  maxTurns: number;
  showTranscript: boolean;
};

export type InterviewChoiceExplainFormState = {
  question: string;
  options: InterviewOptionRow[];
  systemPrompt: string;
  maxTurns: number;
  showTranscript: boolean;
};

export function buildInterviewConversationPayload(
  form: InterviewConversationFormState,
): Record<string, unknown> {
  if (!form.systemPrompt.trim()) {
    throw new Error('system_prompt is required for interview_conversation');
  }
  return {
    topic: form.topic,
    tips: form.tips.filter((t) => t.trim()),
    system_prompt: form.systemPrompt,
    max_turns: form.maxTurns,
    show_transcript: form.showTranscript,
  };
}

export function buildInterviewChoiceExplainPayload(
  form: InterviewChoiceExplainFormState,
): Record<string, unknown> {
  if (!form.systemPrompt.trim()) {
    throw new Error('system_prompt is required for interview_choice_explain');
  }
  if (form.options.length < 3) {
    throw new Error(`interview_choice_explain requires at least 3 options, got ${form.options.length}`);
  }
  if (form.options.length > 4) {
    throw new Error(`interview_choice_explain requires at most 4 options, got ${form.options.length}`);
  }
  return {
    question: form.question,
    options: form.options.map((o) => ({
      id: o.id,
      label: o.label,
      image_asset_id: o.imageAssetId,
    })),
    system_prompt: form.systemPrompt,
    max_turns: form.maxTurns,
    show_transcript: form.showTranscript,
  };
}

export function formStateFromInterviewConversation(
  detail: Record<string, unknown>,
): InterviewConversationFormState {
  return {
    topic: String(detail.topic ?? ''),
    tips: Array.isArray(detail.tips) ? (detail.tips as unknown[]).map(String) : [],
    systemPrompt: String(detail.system_prompt ?? ''),
    maxTurns: typeof detail.max_turns === 'number' ? detail.max_turns : 8,
    showTranscript: detail.show_transcript === true,
  };
}

export function formStateFromInterviewChoiceExplain(
  detail: Record<string, unknown>,
): InterviewChoiceExplainFormState {
  const rawOptions = Array.isArray(detail.options)
    ? (detail.options as Array<Record<string, unknown>>)
    : [];
  return {
    question: String(detail.question ?? ''),
    options: rawOptions.map((o) => ({
      id: String(o.id ?? ''),
      label: String(o.label ?? ''),
      imageAssetId: String(o.image_asset_id ?? ''),
    })),
    systemPrompt: String(detail.system_prompt ?? ''),
    maxTurns: typeof detail.max_turns === 'number' ? detail.max_turns : 6,
    showTranscript: detail.show_transcript === true,
  };
}

// ─── V13: Ano/Ne helpers ──────────────────────────────────────────────────────

export type AnoNeStatementRow = { statement: string; correct: 'ANO' | 'NE' };

export type AnoNeFormState = {
  passage: string;
  statements: AnoNeStatementRow[];
  maxPoints: number;
};

export function buildAnoNePayload(form: AnoNeFormState): Record<string, unknown> {
  if (form.statements.length < 1 || form.statements.length > 5) {
    throw new Error(`statements length must be 1–5, got ${form.statements.length}`);
  }
  const correct_answers: Record<string, string> = {};
  const statements = form.statements.map((s, i) => {
    correct_answers[String(i + 1)] = s.correct;
    return { question_no: i + 1, statement: s.statement };
  });
  return {
    passage: form.passage,
    statements,
    correct_answers,
    max_points: form.maxPoints,
  };
}

export function formStateFromAnoNe(detail: Record<string, unknown>): AnoNeFormState {
  const rawStatements = Array.isArray(detail.statements)
    ? (detail.statements as Array<Record<string, unknown>>)
    : [];
  const correctAnswers = (detail.correct_answers ?? {}) as Record<string, string>;
  return {
    passage: String(detail.passage ?? ''),
    statements: rawStatements.map((s, i) => ({
      statement: String(s.statement ?? ''),
      correct: (correctAnswers[String(i + 1)] === 'ANO' ? 'ANO' : 'NE') as 'ANO' | 'NE',
    })),
    maxPoints: typeof detail.max_points === 'number' ? detail.max_points : 3,
  };
}
