import { describe, it, expect } from 'vitest';
import { cloneExercisePayload } from '../components/exercise-utils';
import type { Exercise } from '../components/exercise-utils';

// V23 Exercise Authoring Polish — Phase B1.
// Helper-level tests for cloneExercisePayload. Pure transform from
// source Exercise → POST payload. Strips id + audio (regen
// separately), prefixes title, preserves prompt + assets + sample.

const sampleSource: Exercise = {
  id: 'ex_source_1',
  module_id: 'mod_a2_basic',
  skill_kind: 'noi',
  pool: 'course',
  exercise_type: 'uloha_1_topic_answers',
  title: 'Pocasi 1',
  short_instruction: 'Trả lời 4 câu hỏi về thời tiết.',
  learner_instruction: 'Bạn sẽ trả lời 4 câu hỏi ngắn.',
  estimated_duration_sec: 90,
  prep_time_sec: 10,
  recording_time_limit_sec: 60,
  sample_answer_enabled: true,
  sample_answer_text: 'Pocasi je dnes hezke.',
  status: 'published',
  assets: [{ asset_id: 'a1', kind: 'image' }],
  prompt: { topic_label: 'Thời tiết', question_prompts: ['Q1?', 'Q2?'] },
  detail: { extra: 'value' },
};

describe('cloneExercisePayload', () => {
  it('prefixes title with "Copy of "', () => {
    const out = cloneExercisePayload(sampleSource);
    expect(out.title).toBe('Copy of Pocasi 1');
  });

  it('forces status to "draft" regardless of source status', () => {
    const out = cloneExercisePayload(sampleSource);
    expect(out.status).toBe('draft');
  });

  it('strips the source id from the payload', () => {
    const out = cloneExercisePayload(sampleSource);
    expect((out as { id?: string }).id).toBeUndefined();
  });

  it('preserves module / skill / type / prompt / assets / detail', () => {
    const out = cloneExercisePayload(sampleSource);
    expect(out.module_id).toBe('mod_a2_basic');
    expect(out.skill_kind).toBe('noi');
    expect(out.pool).toBe('course');
    expect(out.exercise_type).toBe('uloha_1_topic_answers');
    expect(out.prompt).toEqual({ topic_label: 'Thời tiết', question_prompts: ['Q1?', 'Q2?'] });
    expect(out.assets).toEqual([{ asset_id: 'a1', kind: 'image' }]);
    expect(out.detail).toEqual({ extra: 'value' });
  });

  it('preserves duration fields + sample answer block', () => {
    const out = cloneExercisePayload(sampleSource);
    expect(out.estimated_duration_sec).toBe(90);
    expect(out.prep_time_sec).toBe(10);
    expect(out.recording_time_limit_sec).toBe(60);
    expect(out.sample_answer_enabled).toBe(true);
    expect(out.sample_answer_text).toBe('Pocasi je dnes hezke.');
  });

  it('handles a source with missing optional fields', () => {
    const minimal: Exercise = {
      id: 'ex_min',
      title: 'Bare',
      exercise_type: 'cteni_1',
      short_instruction: 'Read text.',
    };
    const out = cloneExercisePayload(minimal);
    expect(out.title).toBe('Copy of Bare');
    expect(out.status).toBe('draft');
    expect(out.exercise_type).toBe('cteni_1');
    // Optional fields stay undefined; assets/prompt absent — OK.
  });
});
