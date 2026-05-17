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
      correct_answers: { '15': 'A', '16': 'A', '17': 'A', '18': 'A', '19': 'A', '20': 'A' },
    }));
    expect(errors).toEqual([]);
  });

  it('cteni_5 requires a correct answer for every fill slot', () => {
    const errors = validateExercise('cteni_5', basePayload({
      text: 'Hledám podnájemníka do pokoje v Praze 4.',
      questions: [
        { question_no: 21, prompt: 'Kdy je pokoj volný?' },
        { question_no: 22, prompt: 'Co je v ceně?' },
        { question_no: 23, prompt: 'Od kolika hodin můžete volat?' },
      ],
      correct_answers: { '21': '1. června', '22': 'poplatky' },
    }));
    expect(errors).toContain('Čtení 5 cần nhập đáp án cho đủ 3 câu (hiện có 2).');
  });
});

describe('validateExercise writing forms', () => {
  it('psani_1_formular accepts a single form question', () => {
    const errors = validateExercise('psani_1_formular', basePayload({
      questions: ['Jak se jmenujete?'],
      min_words: 10,
    }));
    expect(errors).toEqual([]);
  });

  it('psani_1_formular accepts more than three form questions', () => {
    const errors = validateExercise('psani_1_formular', basePayload({
      questions: ['Q1?', 'Q2?', 'Q3?', 'Q4?', 'Q5?'],
      min_words: 10,
    }));
    expect(errors).toEqual([]);
  });

  it('psani_1_formular still rejects an empty question list', () => {
    const errors = validateExercise('psani_1_formular', basePayload({
      questions: [],
      min_words: 10,
    }));
    expect(errors).toContain('Psaní 1 cần ít nhất 1 câu hỏi.');
  });

  it('psani_2_email accepts a single topic prompt', () => {
    const errors = validateExercise('psani_2_email', basePayload({
      prompt: 'Napište kamarádce e-mail.',
      topics: ['KDE JSTE?'],
      min_words: 35,
    }));
    expect(errors).toEqual([]);
  });

  it('psani_2_email accepts more than five topic prompts', () => {
    const errors = validateExercise('psani_2_email', basePayload({
      prompt: 'Napište kamarádce e-mail.',
      topics: ['KDE JSTE?', 'JAK DLOUHO?', 'KDE BYDLÍTE?', 'CO DĚLÁTE?', 'CO KUPUJETE?', 'KDY SE VRÁTÍTE?'],
      min_words: 35,
    }));
    expect(errors).toEqual([]);
  });

  it('psani_2_email still rejects an empty topic list', () => {
    const errors = validateExercise('psani_2_email', basePayload({
      prompt: 'Napište kamarádce e-mail.',
      topics: [],
      min_words: 35,
    }));
    expect(errors).toContain('Psaní 2 cần ít nhất 1 chủ đề/gợi ý ảnh.');
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
