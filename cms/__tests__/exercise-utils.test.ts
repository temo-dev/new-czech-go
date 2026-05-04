import { describe, it, expect } from 'vitest';
import {
  parseLineList,
  parseRequiredInfoSlots,
  parsePoslechCorrectAnswers,
  parseChoiceOptions,
  appendLineIfMissing,
  formStateFromExercise,
  buildCreatePayload,
  buildUpdatePayload,
  createInitialFormState,
  Exercise,
} from '../components/exercise-utils';

// ─── parseLineList ────────────────────────────────────────────────────────────

describe('parseLineList', () => {
  it('splits by newline and trims', () => {
    expect(parseLineList('a\nb\nc')).toEqual(['a', 'b', 'c']);
  });

  it('filters blank lines', () => {
    expect(parseLineList('a\n\nb\n  \nc')).toEqual(['a', 'b', 'c']);
  });

  it('returns empty array for empty string', () => {
    expect(parseLineList('')).toEqual([]);
  });

  it('trims leading/trailing whitespace per line', () => {
    expect(parseLineList('  hello  \n  world  ')).toEqual(['hello', 'world']);
  });
});

// ─── parsePoslechCorrectAnswers ───────────────────────────────────────────────

describe('parsePoslechCorrectAnswers', () => {
  it('parses key=value pairs', () => {
    expect(parsePoslechCorrectAnswers('1=B\n2=A\n3=C')).toEqual({ '1': 'B', '2': 'A', '3': 'C' });
  });

  it('trims whitespace around = sign', () => {
    expect(parsePoslechCorrectAnswers('1 = B\n2 = A')).toEqual({ '1': 'B', '2': 'A' });
  });

  it('ignores malformed lines without =', () => {
    expect(parsePoslechCorrectAnswers('1=B\nbad\n2=A')).toEqual({ '1': 'B', '2': 'A' });
  });

  it('returns empty object for empty input', () => {
    expect(parsePoslechCorrectAnswers('')).toEqual({});
  });
});

// ─── parseRequiredInfoSlots ───────────────────────────────────────────────────

describe('parseRequiredInfoSlots', () => {
  it('parses pipe-delimited slot definitions', () => {
    const result = parseRequiredInfoSlots('time | Čas | Kdy začíná?');
    expect(result).toEqual([{
      slot_key: 'time',
      label: 'Čas',
      sample_question: 'Kdy začíná?',
    }]);
  });

  it('omits sample_question when absent', () => {
    const result = parseRequiredInfoSlots('time | Čas');
    expect(result).toEqual([{ slot_key: 'time', label: 'Čas' }]);
  });

  it('throws when slot_key or label missing', () => {
    expect(() => parseRequiredInfoSlots('|')).toThrow();
  });

  it('handles multiple slots', () => {
    const result = parseRequiredInfoSlots('a | Label A\nb | Label B');
    expect(result).toHaveLength(2);
    expect(result[0].slot_key).toBe('a');
    expect(result[1].slot_key).toBe('b');
  });

  it('skips blank lines', () => {
    const result = parseRequiredInfoSlots('a | A\n\nb | B');
    expect(result).toHaveLength(2);
  });
});

// ─── parseChoiceOptions ───────────────────────────────────────────────────────

describe('parseChoiceOptions', () => {
  it('parses option_key | label | description', () => {
    const result = parseChoiceOptions('flat_a | Byt A | Levnější');
    expect(result).toEqual([{ option_key: 'flat_a', label: 'Byt A', description: 'Levnější' }]);
  });

  it('omits description when empty', () => {
    const result = parseChoiceOptions('flat_a | Byt A');
    expect(result[0]).not.toHaveProperty('description');
  });

  it('throws when option_key or label missing', () => {
    expect(() => parseChoiceOptions('|')).toThrow();
  });

  it('includes image_asset_id when provided', () => {
    const result = parseChoiceOptions('opt | Label | Desc | asset-123');
    expect(result[0].image_asset_id).toBe('asset-123');
  });
});

// ─── appendLineIfMissing ──────────────────────────────────────────────────────

describe('appendLineIfMissing', () => {
  it('appends value when not present', () => {
    expect(appendLineIfMissing('a\nb', 'c')).toBe('a\nb\nc');
  });

  it('does not append when already present', () => {
    expect(appendLineIfMissing('a\nb\nc', 'b')).toBe('a\nb\nc');
  });

  it('appends to empty string', () => {
    expect(appendLineIfMissing('', 'x')).toBe('x');
  });
});

// ─── formStateFromExercise ────────────────────────────────────────────────────

describe('formStateFromExercise', () => {
  const base: Exercise = {
    id: 'ex-1',
    title: 'Test',
    exercise_type: 'uloha_1_topic_answers',
    short_instruction: 'Short',
    learner_instruction: 'Long',
    module_id: 'mod-1',
    skill_kind: 'noi',
    status: 'draft',
    pool: 'course',
  };

  it('maps basic fields', () => {
    const state = formStateFromExercise(base);
    expect(state.title).toBe('Test');
    expect(state.moduleId).toBe('mod-1');
    expect(state.skillKind).toBe('noi');
    expect(state.status).toBe('draft');
    expect(state.pool).toBe('course');
  });

  it('defaults pool to course when absent', () => {
    const { pool: _, ...noPool } = base;
    const state = formStateFromExercise(noPool as Exercise);
    expect(state.pool).toBe('course');
  });

  it('defaults status to draft when absent', () => {
    const { status: _, ...noStatus } = base;
    const state = formStateFromExercise(noStatus as Exercise);
    expect(state.status).toBe('draft');
  });

  it('sets typePayload for poslech exercises', () => {
    const poslech: Exercise = { ...base, exercise_type: 'poslech_1', detail: { foo: 1 } };
    const state = formStateFromExercise(poslech);
    expect(state.typePayload).toEqual({ foo: 1 });
  });

  it('sets typePayload for cteni exercises', () => {
    const cteni: Exercise = { ...base, exercise_type: 'cteni_2', detail: { text: 'abc' } };
    const state = formStateFromExercise(cteni);
    expect(state.typePayload).toEqual({ text: 'abc' });
  });

  it('does not set typePayload for speaking exercises', () => {
    const state = formStateFromExercise(base);
    expect(state.typePayload).toBeUndefined();
  });

  it('parses required_info_slots from detail', () => {
    const ex: Exercise = {
      ...base,
      exercise_type: 'uloha_2_dialogue_questions',
      detail: {
        required_info_slots: [{ slot_key: 'time', label: 'Čas', sample_question: 'Kdy?' }],
      },
    };
    const state = formStateFromExercise(ex);
    expect(state.requiredInfoSlots).toContain('time | Čas | Kdy?');
  });
});

// ─── createInitialFormState ───────────────────────────────────────────────────

describe('createInitialFormState', () => {
  it('returns valid default state', () => {
    const state = createInitialFormState();
    expect(state.exerciseType).toBe('uloha_1_topic_answers');
    expect(state.status).toBe('draft');
    expect(state.pool).toBe('course');
  });
});

// ─── buildCreatePayload ───────────────────────────────────────────────────────

describe('buildCreatePayload', () => {
  it('builds uloha_1 payload with questions array', () => {
    const form = {
      ...createInitialFormState(),
      exerciseType: 'uloha_1_topic_answers' as const,
      title: 'Weather',
      skillKind: 'noi',
      moduleId: 'mod-1',
      questions: 'Q1?\nQ2?',
      status: 'draft',
      pool: 'course',
    };
    const payload = buildCreatePayload(form);
    expect((payload as { questions: string[] }).questions).toEqual(['Q1?', 'Q2?']);
    expect(payload.module_id).toBe('mod-1');
    expect(payload.status).toBe('draft');
  });

  it('uses typePayload for poslech when present', () => {
    const form = {
      ...createInitialFormState(),
      exerciseType: 'poslech_1' as const,
      typePayload: { items: [{ question_no: 1 }] },
      status: 'draft',
      pool: 'course',
    };
    const payload = buildCreatePayload(form);
    expect((payload as { detail: unknown }).detail).toEqual({ items: [{ question_no: 1 }] });
  });

  it('uses typePayload for cteni when present', () => {
    const form = {
      ...createInitialFormState(),
      exerciseType: 'cteni_2' as const,
      typePayload: { text: 'passage', questions: [] },
      status: 'draft',
      pool: 'course',
    };
    const payload = buildCreatePayload(form);
    expect((payload as { detail: unknown }).detail).toEqual({ text: 'passage', questions: [] });
  });

  it('builds psani_1 payload with detail.questions', () => {
    const form = {
      ...createInitialFormState(),
      exerciseType: 'psani_1_formular' as const,
      formularQuestions: 'Otázka 1?\nOtázka 2?',
      formularMinWords: 10,
      status: 'draft',
      pool: 'course',
    };
    const payload = buildCreatePayload(form);
    const detail = (payload as { detail: { questions: string[]; min_words: number } }).detail;
    expect(detail.questions).toEqual(['Otázka 1?', 'Otázka 2?']);
    expect(detail.min_words).toBe(10);
  });
});

// ─── buildUpdatePayload ───────────────────────────────────────────────────────

describe('buildUpdatePayload', () => {
  it('builds uloha_1 update payload with prompt structure', () => {
    const form = {
      ...createInitialFormState(),
      exerciseType: 'uloha_1_topic_answers' as const,
      title: 'Weather',
      questions: 'Q1?\nQ2?',
      skillKind: 'noi',
      moduleId: 'mod-1',
      status: 'published',
      pool: 'course',
    };
    const payload = buildUpdatePayload(form) as { prompt: { question_prompts: string[] } };
    expect(payload.prompt.question_prompts).toEqual(['Q1?', 'Q2?']);
  });
});

// ─── V13: Ano/Ne tests ────────────────────────────────────────────────────────

import { buildAnoNePayload, formStateFromAnoNe } from '../components/exercise-utils';

describe('buildAnoNePayload', () => {
  it('builds valid 3-statement payload', () => {
    const payload = buildAnoNePayload({
      passage: 'Vlašim text',
      statements: [
        { statement: 'Je zavřeno v pátek.', correct: 'ANO' },
        { statement: 'Polední přestávka je do 13h.', correct: 'NE' },
        { statement: 'Úřední hodiny v úterý končí ve 14h.', correct: 'ANO' },
      ],
      maxPoints: 3,
    });
    expect(payload.passage).toBe('Vlašim text');
    expect((payload.statements as unknown[]).length).toBe(3);
    expect(payload.correct_answers).toEqual({ '1': 'ANO', '2': 'NE', '3': 'ANO' });
    expect(payload.max_points).toBe(3);
  });

  it('throws for >5 statements', () => {
    expect(() =>
      buildAnoNePayload({
        passage: 'x',
        statements: Array(6).fill({ statement: 's', correct: 'ANO' as const }),
        maxPoints: 6,
      }),
    ).toThrow('1–5');
  });

  it('uppercase ANO/NE in correct_answers', () => {
    const payload = buildAnoNePayload({
      passage: 'x',
      statements: [{ statement: 's', correct: 'NE' }],
      maxPoints: 1,
    });
    expect((payload.correct_answers as Record<string, string>)['1']).toBe('NE');
  });
});

describe('formStateFromAnoNe', () => {
  it('roundtrip: buildAnoNePayload → formStateFromAnoNe', () => {
    const original = {
      passage: 'Test passage',
      statements: [
        { statement: 'Stmt A', correct: 'ANO' as const },
        { statement: 'Stmt B', correct: 'NE' as const },
      ],
      maxPoints: 2,
    };
    const payload = buildAnoNePayload(original);
    const restored = formStateFromAnoNe(payload);
    expect(restored.passage).toBe('Test passage');
    expect(restored.statements[0].correct).toBe('ANO');
    expect(restored.statements[1].correct).toBe('NE');
    expect(restored.maxPoints).toBe(2);
  });
});

// ─── V14: Interview helpers ───────────────────────────────────────────────────

import {
  buildInterviewConversationPayload,
  buildInterviewChoiceExplainPayload,
  formStateFromInterviewConversation,
  formStateFromInterviewChoiceExplain,
} from '../components/exercise-utils';

describe('buildInterviewConversationPayload', () => {
  it('builds valid payload with all fields', () => {
    const payload = buildInterviewConversationPayload({
      topic: 'Gia đình',
      tips: ['Trả lời đầy đủ', 'Dùng từ nối'],
      systemPrompt: 'You are Jana, a Czech examiner.',
      maxTurns: 8,
      showTranscript: true,
    });
    expect(payload.topic).toBe('Gia đình');
    expect(payload.tips).toEqual(['Trả lời đầy đủ', 'Dùng từ nối']);
    expect(payload.system_prompt).toBe('You are Jana, a Czech examiner.');
    expect(payload.max_turns).toBe(8);
    expect(payload.show_transcript).toBe(true);
  });

  it('throws for empty system_prompt', () => {
    expect(() =>
      buildInterviewConversationPayload({
        topic: 'Rodina',
        tips: [],
        systemPrompt: '',
        maxTurns: 8,
        showTranscript: false,
      }),
    ).toThrow('system_prompt');
  });

  it('roundtrip: buildPayload → formStateFrom', () => {
    const original = {
      topic: 'Práce',
      tips: ['Tip 1'],
      systemPrompt: 'You are Jana. Interview about work.',
      maxTurns: 6,
      showTranscript: false,
    };
    const payload = buildInterviewConversationPayload(original);
    const restored = formStateFromInterviewConversation(payload);
    expect(restored.topic).toBe('Práce');
    expect(restored.tips).toEqual(['Tip 1']);
    expect(restored.systemPrompt).toBe('You are Jana. Interview about work.');
    expect(restored.maxTurns).toBe(6);
    expect(restored.showTranscript).toBe(false);
  });
});

describe('buildInterviewChoiceExplainPayload', () => {
  const threeOptions = [
    { id: '1', label: 'Praha', imageAssetId: '', tips: [] },
    { id: '2', label: 'Brno', imageAssetId: '', tips: [] },
    { id: '3', label: 'Ostrava', imageAssetId: '', tips: [] },
  ];

  it('builds valid payload with 3 options', () => {
    const payload = buildInterviewChoiceExplainPayload({
      question: 'Kde chcete žít?',
      options: threeOptions,
      systemPrompt: 'You are Jana. The learner chose {selected_option}.',
      maxTurns: 6,
      showTranscript: false,
    });
    expect(payload.question).toBe('Kde chcete žít?');
    expect((payload.options as unknown[]).length).toBe(3);
    expect(payload.system_prompt).toContain('{selected_option}');
  });

  it('builds valid payload with 1 option', () => {
    const payload = buildInterviewChoiceExplainPayload({
      question: 'Jaké boty chcete?',
      options: [{ id: '1', label: 'Bílé boty', imageAssetId: '', tips: [] }],
      systemPrompt: 'You are Jana. The learner chose {selected_option}.',
      maxTurns: 2,
      showTranscript: false,
    });
    expect((payload.options as unknown[]).length).toBe(1);
    expect(payload.max_turns).toBe(2);
  });

  it('throws for no options', () => {
    expect(() =>
      buildInterviewChoiceExplainPayload({
        question: 'Q',
        options: [],
        systemPrompt: 'You are Jana.',
        maxTurns: 6,
        showTranscript: false,
      }),
    ).toThrow('1');
  });

  it('throws for more than 4 options', () => {
    expect(() =>
      buildInterviewChoiceExplainPayload({
        question: 'Q',
        options: Array(5).fill({ id: '1', label: 'X', imageAssetId: '', tips: [] }),
        systemPrompt: 'You are Jana.',
        maxTurns: 6,
        showTranscript: false,
      }),
    ).toThrow('4');
  });

  it('throws for empty system_prompt', () => {
    expect(() =>
      buildInterviewChoiceExplainPayload({
        question: 'Q',
        options: threeOptions,
        systemPrompt: '',
        maxTurns: 6,
        showTranscript: false,
      }),
    ).toThrow('system_prompt');
  });

  it('roundtrip: buildPayload → formStateFrom', () => {
    const original = {
      question: 'Kde bydlíte?',
      options: [
        { id: '1', label: 'Praha', imageAssetId: 'img-1', tips: ['památky', 'doprava'] },
        { id: '2', label: 'Brno', imageAssetId: '', tips: [] },
        { id: '3', label: 'Ostrava', imageAssetId: '', tips: [] },
      ],
      systemPrompt: 'You are Jana. The learner chose {selected_option}.',
      maxTurns: 5,
      showTranscript: true,
    };
    const payload = buildInterviewChoiceExplainPayload(original);
    const restored = formStateFromInterviewChoiceExplain(payload);
    expect(restored.question).toBe('Kde bydlíte?');
    expect(restored.options[0].label).toBe('Praha');
    expect(restored.options[0].imageAssetId).toBe('img-1');
    expect(restored.options[0].tips).toEqual(['památky', 'doprava']);
    expect(restored.options.length).toBe(3);
    expect(restored.showTranscript).toBe(true);
  });

  it('trims and drops blank learner tips per option', () => {
    const payload = buildInterviewChoiceExplainPayload({
      question: 'Jaké boty chcete?',
      options: [
        { id: '1', label: 'Bílé boty', imageAssetId: '', tips: [' velikost ', '', 'barva'] },
        { id: '2', label: 'Černé boty', imageAssetId: '', tips: [] },
        { id: '3', label: 'Modré boty', imageAssetId: '', tips: [' cena '] },
      ],
      systemPrompt: 'You are Jana. The learner chose {selected_option}.',
      maxTurns: 6,
      showTranscript: false,
    });

    const options = payload.options as Array<{ tips: string[] }>;
    expect(options[0].tips).toEqual(['velikost', 'barva']);
    expect(options[1].tips).toEqual([]);
    expect(options[2].tips).toEqual(['cena']);
  });
});
