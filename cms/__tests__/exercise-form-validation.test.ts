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

describe('validateExercise pool=exam skips module check (V38 fix)', () => {
  it('does not require module_id when pool=exam', () => {
    const errors = validateExercise('cteni_2', {
      title: 'Bài thi mock',
      pool: 'exam',
      module_id: '',
      detail: {
        text: 'Đoạn văn',
        questions: Array.from({ length: 5 }, (_, i) => ({ question_no: 6 + i, prompt: `Q${i}` })),
      },
    });
    expect(errors).not.toContain('Phải chọn Module.');
  });

  it('still requires module_id when pool=course', () => {
    const errors = validateExercise('cteni_2', {
      title: 'Bài luyện',
      pool: 'course',
      module_id: '',
      detail: {
        text: 'Đoạn văn',
        questions: Array.from({ length: 5 }, (_, i) => ({ question_no: 6 + i, prompt: `Q${i}` })),
      },
    });
    expect(errors).toContain('Phải chọn Module.');
  });

  it('applies pool=exam exemption across exercise types', () => {
    for (const type of ['poslech_1', 'cteni_5', 'psani_1_formular', 'uloha_1']) {
      const errors = validateExercise(type, { title: 'T', pool: 'exam', module_id: '', detail: {} });
      expect(errors).not.toContain('Phải chọn Module.');
    }
  });
});
