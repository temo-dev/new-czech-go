import { describe, it, expect } from 'vitest';
import { buildMatrix, MATRIX_SKILL_KINDS, COVERAGE_TARGET } from '../components/exercise-matrix';
import { Exercise, CmsModule, CmsCourse } from '../components/exercise-utils';

// ─── Fixtures ─────────────────────────────────────────────────────────────────

const courses: CmsCourse[] = [
  { id: 'course-a', title: 'Khóa A' },
  { id: 'course-b', title: 'Khóa B' },
];

const modules: CmsModule[] = [
  { id: 'mod-1', title: 'Module 1', course_id: 'course-a', sequence_no: 1 },
  { id: 'mod-2', title: 'Module 2', course_id: 'course-a', sequence_no: 2 },
  { id: 'mod-3', title: 'Module 3', course_id: 'course-b', sequence_no: 1 },
];

function makeExercise(overrides: Partial<Exercise>): Exercise {
  return {
    id: overrides.id ?? 'ex-1',
    title: 'Test',
    exercise_type: 'uloha_1_topic_answers',
    short_instruction: '',
    module_id: 'mod-1',
    skill_kind: 'noi',
    status: 'published',
    pool: 'course',
    ...overrides,
  };
}

// ─── buildMatrix ─────────────────────────────────────────────────────────────

describe('buildMatrix', () => {
  it('returns one row per module', () => {
    const rows = buildMatrix([], modules, courses);
    expect(rows).toHaveLength(3);
  });

  it('counts published exercises per cell', () => {
    const items = [
      makeExercise({ id: '1', module_id: 'mod-1', skill_kind: 'noi', status: 'published' }),
      makeExercise({ id: '2', module_id: 'mod-1', skill_kind: 'noi', status: 'published' }),
    ];
    const rows = buildMatrix(items, modules, courses);
    const mod1 = rows.find(r => r.moduleId === 'mod-1')!;
    expect(mod1.cells.noi.published).toBe(2);
    expect(mod1.cells.noi.draft).toBe(0);
  });

  it('counts draft exercises separately from published', () => {
    const items = [
      makeExercise({ id: '1', module_id: 'mod-1', skill_kind: 'nghe', status: 'published' }),
      makeExercise({ id: '2', module_id: 'mod-1', skill_kind: 'nghe', status: 'draft' }),
      makeExercise({ id: '3', module_id: 'mod-1', skill_kind: 'nghe', status: 'draft' }),
    ];
    const rows = buildMatrix(items, modules, courses);
    const mod1 = rows.find(r => r.moduleId === 'mod-1')!;
    expect(mod1.cells.nghe.published).toBe(1);
    expect(mod1.cells.nghe.draft).toBe(2);
  });

  it('ignores archived exercises (not counted in published or draft)', () => {
    const items = [
      makeExercise({ id: '1', module_id: 'mod-1', skill_kind: 'noi', status: 'archived' }),
    ];
    const rows = buildMatrix(items, modules, courses);
    const mod1 = rows.find(r => r.moduleId === 'mod-1')!;
    expect(mod1.cells.noi.published).toBe(0);
    expect(mod1.cells.noi.draft).toBe(0);
  });

  it('excludes tu_vung and ngu_phap skill kinds from matrix', () => {
    const items = [
      makeExercise({ id: '1', module_id: 'mod-1', skill_kind: 'tu_vung', status: 'published' }),
      makeExercise({ id: '2', module_id: 'mod-1', skill_kind: 'ngu_phap', status: 'published' }),
    ];
    const rows = buildMatrix(items, modules, courses);
    const mod1 = rows.find(r => r.moduleId === 'mod-1')!;
    // Matrix only has 4 skill kinds: noi, nghe, viet, doc
    expect(Object.keys(mod1.cells)).toEqual(MATRIX_SKILL_KINDS as unknown as string[]);
    expect(mod1.cells).not.toHaveProperty('tu_vung');
    expect(mod1.cells).not.toHaveProperty('ngu_phap');
  });

  it('skips items with no module_id (exam pool)', () => {
    const items = [
      makeExercise({ id: '1', module_id: undefined, skill_kind: 'noi', status: 'published' }),
    ];
    const rows = buildMatrix(items, modules, courses);
    // No rows should be affected
    rows.forEach(r => {
      expect(r.cells.noi.published).toBe(0);
    });
  });

  it('skips items with no skill_kind', () => {
    const items = [
      makeExercise({ id: '1', module_id: 'mod-1', skill_kind: undefined, status: 'published' }),
    ];
    const rows = buildMatrix(items, modules, courses);
    const mod1 = rows.find(r => r.moduleId === 'mod-1')!;
    expect(mod1.cells.noi.published).toBe(0);
  });

  it('sorts modules by sequence_no within course', () => {
    const rows = buildMatrix([], modules, courses);
    const courseARows = rows.filter(r => r.courseId === 'course-a');
    expect(courseARows[0].moduleId).toBe('mod-1');
    expect(courseARows[1].moduleId).toBe('mod-2');
  });

  it('groups modules by course order', () => {
    const rows = buildMatrix([], modules, courses);
    // All course-a rows before course-b rows
    const courseAIndices = rows.map((r, i) => r.courseId === 'course-a' ? i : -1).filter(i => i >= 0);
    const courseBIndices = rows.map((r, i) => r.courseId === 'course-b' ? i : -1).filter(i => i >= 0);
    expect(Math.max(...courseAIndices)).toBeLessThan(Math.min(...courseBIndices));
  });

  it('skips modules with no course_id', () => {
    const orphanModules: CmsModule[] = [
      ...modules,
      { id: 'orphan', title: 'Orphan', course_id: '', sequence_no: 99 },
    ];
    const rows = buildMatrix([], orphanModules, courses);
    expect(rows.find(r => r.moduleId === 'orphan')).toBeUndefined();
  });

  it('populates courseTitle from courses map', () => {
    const rows = buildMatrix([], modules, courses);
    const mod1 = rows.find(r => r.moduleId === 'mod-1')!;
    expect(mod1.courseTitle).toBe('Khóa A');
  });

  it('returns cell with zero counts for module with no matching exercises', () => {
    const rows = buildMatrix([], modules, courses);
    const mod1 = rows.find(r => r.moduleId === 'mod-1')!;
    for (const sk of MATRIX_SKILL_KINDS) {
      expect(mod1.cells[sk]).toEqual({ published: 0, draft: 0 });
    }
  });

  it('isolates counts per module — mod-2 not affected by mod-1 items', () => {
    const items = [
      makeExercise({ id: '1', module_id: 'mod-1', skill_kind: 'noi', status: 'published' }),
    ];
    const rows = buildMatrix(items, modules, courses);
    const mod2 = rows.find(r => r.moduleId === 'mod-2')!;
    expect(mod2.cells.noi.published).toBe(0);
  });
});

// ─── MATRIX_SKILL_KINDS constant ─────────────────────────────────────────────

describe('MATRIX_SKILL_KINDS', () => {
  it('contains exactly noi, nghe, viet, doc', () => {
    expect([...MATRIX_SKILL_KINDS]).toEqual(['noi', 'nghe', 'viet', 'doc']);
  });

  it('does not contain tu_vung or ngu_phap', () => {
    expect(MATRIX_SKILL_KINDS).not.toContain('tu_vung');
    expect(MATRIX_SKILL_KINDS).not.toContain('ngu_phap');
  });
});

// ─── COVERAGE_TARGET export ───────────────────────────────────────────────────

describe('COVERAGE_TARGET', () => {
  it('is 20', () => {
    expect(COVERAGE_TARGET).toBe(20);
  });
});
