import { describe, it, expect } from 'vitest';
import {
  SKILL_GROUPS,
  EXERCISE_TYPE_LABEL,
  DEFAULT_MAX_POINTS,
  resequence,
  type SkillKind,
  type MockTestSectionLite,
} from '../components/mock-test-dashboard-utils';

// V36 — mock-test SKILL_GROUPS extended to include interview as the
// 5th skill group. Picker filter at runtime uses `prefix` to map
// exercise_type → group; missing entry was the root cause of
// "interview exercise can't be assigned to mock test" bug.

describe('SKILL_GROUPS (V36)', () => {
  it('includes interview as the 5th group with cyan color and interview_ prefix', () => {
    const interview = SKILL_GROUPS.find(g => g.kind === 'interview');
    expect(interview).toBeDefined();
    expect(interview?.prefix).toBe('interview_');
    expect(interview?.color).toBe('#0891B2');
    expect(interview?.label).toBe('Hội thoại AI');
  });

  it('preserves the original 4 groups in original order', () => {
    const kinds = SKILL_GROUPS.slice(0, 4).map(g => g.kind);
    expect(kinds).toEqual(['noi', 'nghe', 'doc', 'viet']);
  });

  it('places interview last', () => {
    expect(SKILL_GROUPS[SKILL_GROUPS.length - 1].kind).toBe('interview');
  });
});

describe('EXERCISE_TYPE_LABEL (V36)', () => {
  it('labels interview_conversation', () => {
    expect(EXERCISE_TYPE_LABEL.interview_conversation).toBe(
      'Hội thoại theo chủ đề',
    );
  });

  it('labels interview_choice_explain', () => {
    expect(EXERCISE_TYPE_LABEL.interview_choice_explain).toBe(
      'Chọn phương án + giải thích',
    );
  });
});

describe('DEFAULT_MAX_POINTS (V36)', () => {
  it('defaults both interview types to 20', () => {
    expect(DEFAULT_MAX_POINTS.interview_conversation).toBe(20);
    expect(DEFAULT_MAX_POINTS.interview_choice_explain).toBe(20);
  });
});

describe('resequence (V36)', () => {
  it('orders interview sections after noi/nghe/doc/viet', () => {
    const sections: MockTestSectionLite[] = [
      { sequence_no: 0, skill_kind: 'interview', exercise_id: 'iv-1', exercise_type: 'interview_conversation', max_points: 20 },
      { sequence_no: 0, skill_kind: 'noi',       exercise_id: 'sp-1', exercise_type: 'uloha_1_topic_answers', max_points: 8 },
      { sequence_no: 0, skill_kind: 'viet',      exercise_id: 'wr-1', exercise_type: 'psani_2_email',         max_points: 12 },
    ];
    const got = resequence(sections);
    expect(got.map(s => s.skill_kind as SkillKind)).toEqual(['noi', 'viet', 'interview']);
    expect(got.map(s => s.sequence_no)).toEqual([1, 2, 3]);
  });

  it('drops unknown skill_kind (no orphan slot)', () => {
    const sections: MockTestSectionLite[] = [
      { sequence_no: 0, skill_kind: 'noi',     exercise_id: 'a', exercise_type: 'uloha_1_topic_answers', max_points: 8 },
      { sequence_no: 0, skill_kind: 'unknown', exercise_id: 'b', exercise_type: 'mystery_1',             max_points: 5 },
    ];
    const got = resequence(sections);
    expect(got).toHaveLength(1);
    expect(got[0].skill_kind).toBe('noi');
  });
});
