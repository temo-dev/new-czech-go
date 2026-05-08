import { describe, it, expect } from 'vitest';
import { validateExercise } from '../components/exercise-form/validation';

const basePayload = (detail: Record<string, unknown>) => ({
  title: 'Bài đọc',
  module_id: 'module-1',
  detail,
});

describe('validateExercise reading forms', () => {
  it('cteni_2 still requires text', () => {
    const errors = validateExercise('cteni_2', basePayload({
      questions: Array.from({ length: 5 }, (_, i) => ({ question_no: 6 + i, prompt: `Q${i}` })),
    }));
    expect(errors).toContain('Cần nhập đoạn văn đọc.');
  });

  it('cteni_4 accepts optional context when six questions are present', () => {
    const errors = validateExercise('cteni_4', basePayload({
      questions: Array.from({ length: 6 }, (_, i) => ({ question_no: 15 + i, prompt: `Q${i}` })),
    }));
    expect(errors).toEqual([]);
  });
});
