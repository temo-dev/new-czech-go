export type ExamMembershipSection = {
  exercise_id: string;
  sequence_no?: number;
  skill_kind?: string;
};

export type ExamMembershipMockTest = {
  id: string;
  title: string;
  status?: string;
  sections?: ExamMembershipSection[] | null;
};

export type ExamExerciseMembership = {
  mockTestId: string;
  mockTestTitle: string;
  mockTestStatus?: string;
  sequenceNos: number[];
  skillKinds: string[];
};

export function buildExamExerciseMembershipIndex(
  mockTests: ExamMembershipMockTest[],
): Map<string, ExamExerciseMembership[]> {
  const index = new Map<string, ExamExerciseMembership[]>();

  for (const test of mockTests) {
    const byExercise = new Map<string, ExamExerciseMembership>();

    for (const section of test.sections ?? []) {
      if (!section.exercise_id) continue;

      let membership = byExercise.get(section.exercise_id);
      if (!membership) {
        membership = {
          mockTestId: test.id,
          mockTestTitle: test.title,
          mockTestStatus: test.status,
          sequenceNos: [],
          skillKinds: [],
        };
        byExercise.set(section.exercise_id, membership);
      }

      if (typeof section.sequence_no === 'number' && section.sequence_no > 0) {
        membership.sequenceNos.push(section.sequence_no);
      }
      if (section.skill_kind && !membership.skillKinds.includes(section.skill_kind)) {
        membership.skillKinds.push(section.skill_kind);
      }
    }

    for (const [exerciseId, membership] of byExercise) {
      membership.sequenceNos.sort((a, b) => a - b);
      const memberships = index.get(exerciseId) ?? [];
      memberships.push(membership);
      index.set(exerciseId, memberships);
    }
  }

  return index;
}

export function examMembershipLabel(membership: ExamExerciseMembership): string {
  if (membership.sequenceNos.length === 0) return membership.mockTestTitle;
  return `${membership.mockTestTitle} · phần ${membership.sequenceNos.join(', ')}`;
}
