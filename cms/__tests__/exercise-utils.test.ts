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
