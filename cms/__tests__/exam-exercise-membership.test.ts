import { describe, expect, it } from 'vitest';
import {
  buildExamExerciseMembershipIndex,
  examMembershipLabel,
} from '../components/exam-exercise-membership';

describe('buildExamExerciseMembershipIndex', () => {
  it('maps an exam-pool exercise to every mock test that uses it', () => {
    const index = buildExamExerciseMembershipIndex([
      {
        id: 'mock-a',
        title: 'Modelovy test A',
        status: 'published',
        sections: [
          { exercise_id: 'ex-1', sequence_no: 1, skill_kind: 'noi' },
          { exercise_id: 'ex-2', sequence_no: 2, skill_kind: 'doc' },
        ],
      },
      {
        id: 'mock-b',
        title: 'Modelovy test B',
        status: 'draft',
        sections: [
          { exercise_id: 'ex-1', sequence_no: 3, skill_kind: 'viet' },
        ],
      },
    ]);

    expect(index.get('ex-1')?.map(m => m.mockTestTitle)).toEqual([
      'Modelovy test A',
      'Modelovy test B',
    ]);
    expect(index.get('ex-2')?.map(m => m.mockTestTitle)).toEqual(['Modelovy test A']);
  });

  it('collapses repeated use inside one mock test into one membership', () => {
    const index = buildExamExerciseMembershipIndex([
      {
        id: 'mock-a',
        title: 'Modelovy test A',
        sections: [
          { exercise_id: 'ex-1', sequence_no: 4, skill_kind: 'noi' },
          { exercise_id: 'ex-1', sequence_no: 2, skill_kind: 'noi' },
        ],
      },
    ]);

    const membership = index.get('ex-1')?.[0];
    expect(membership?.sequenceNos).toEqual([2, 4]);
    expect(examMembershipLabel(membership!)).toBe('Modelovy test A · phần 2, 4');
  });

  it('skips empty exercise ids and tolerates missing sections', () => {
    const index = buildExamExerciseMembershipIndex([
      { id: 'mock-a', title: 'Empty', sections: [{ exercise_id: '' }] },
      { id: 'mock-b', title: 'No sections', sections: null },
    ]);

    expect(index.size).toBe(0);
  });
});
