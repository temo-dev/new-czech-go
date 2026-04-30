'use client';

import { CmsCourse, CmsModule, Exercise } from './exercise-utils';

// ─── Types ────────────────────────────────────────────────────────────────────

export type MatrixCell = { published: number; draft: number };

export type MatrixRow = {
  moduleId: string;
  moduleTitle: string;
  courseId: string;
  courseTitle: string;
  cells: Record<string, MatrixCell>;
};

// ─── Constants ────────────────────────────────────────────────────────────────

export const MATRIX_SKILL_KINDS = ['noi', 'nghe', 'viet', 'doc'] as const;
export type MatrixSkillKind = (typeof MATRIX_SKILL_KINDS)[number];

const SKILL_LABELS: Record<MatrixSkillKind, string> = {
  noi: 'Nói',
  nghe: 'Nghe',
  viet: 'Viết',
  doc: 'Đọc',
};

const COVERAGE_TARGET = 20;

// ─── buildMatrix ─────────────────────────────────────────────────────────────

export function buildMatrix(
  items: Exercise[],
  modules: CmsModule[],
  courses: CmsCourse[],
): MatrixRow[] {
  const courseMap = new Map(courses.map((c) => [c.id, c]));

  // Count published + draft per [module_id][skill_kind]
  const counts = new Map<string, Map<string, MatrixCell>>();
  for (const item of items) {
    if (!item.module_id || !item.skill_kind) continue;
    if (!(MATRIX_SKILL_KINDS as readonly string[]).includes(item.skill_kind)) continue;

    if (!counts.has(item.module_id)) counts.set(item.module_id, new Map());
    const bySkill = counts.get(item.module_id)!;
    if (!bySkill.has(item.skill_kind)) bySkill.set(item.skill_kind, { published: 0, draft: 0 });
    const cell = bySkill.get(item.skill_kind)!;
    if (item.status === 'published') cell.published++;
    else if (item.status === 'draft') cell.draft++;
  }

  // Build rows for all modules (even if count = 0)
  const rows: MatrixRow[] = modules
    .filter((m) => m.course_id) // skip orphan modules
    .map((m) => {
      const bySkill = counts.get(m.id) ?? new Map<string, MatrixCell>();
      const cells: Record<string, MatrixCell> = {};
      for (const sk of MATRIX_SKILL_KINDS) {
        cells[sk] = bySkill.get(sk) ?? { published: 0, draft: 0 };
      }
      return {
        moduleId: m.id,
        moduleTitle: m.title,
        courseId: m.course_id,
        courseTitle: courseMap.get(m.course_id)?.title ?? m.course_id,
        cells,
      };
    });

  // Sort: group by course (stable insertion order), then by sequence_no within course
  const courseOrder = new Map<string, number>();
  courses.forEach((c, i) => courseOrder.set(c.id, i));

  rows.sort((a, b) => {
    const ca = courseOrder.get(a.courseId) ?? 999;
    const cb = courseOrder.get(b.courseId) ?? 999;
    if (ca !== cb) return ca - cb;
    const ma = modules.find((m) => m.id === a.moduleId)?.sequence_no ?? 0;
    const mb = modules.find((m) => m.id === b.moduleId)?.sequence_no ?? 0;
    return ma - mb;
  });

  return rows;
}

// ─── Color helpers ────────────────────────────────────────────────────────────

function cellBg(published: number): string {
  if (published >= COVERAGE_TARGET) return '#6EE7B7';
  if (published >= 15) return '#D1FAE5';
  if (published >= 6) return '#FEF9C3';
  return '#FEE2E2';
}

function cellTextColor(published: number): string {
  return published >= COVERAGE_TARGET ? '#065F46' : '#1F2937';
}

// ─── ExerciseMatrix component ─────────────────────────────────────────────────

type Props = {
  items: Exercise[];
  modules: CmsModule[];
  courses: CmsCourse[];
  /** Active cell for highlight — set by parent on click (CM-2) */
  activeCell?: { moduleId: string | null; skillKind: string } | null;
  /** Called when a cell or Tổng-row cell is clicked */
  onCellClick?: (moduleId: string | null, skillKind: MatrixSkillKind) => void;
};

export function ExerciseMatrix({ items, modules, courses, activeCell, onCellClick }: Props) {
  const rows = buildMatrix(items, modules, courses);

  // Tổng row — sum across all modules per skill_kind
  const totals: Record<string, MatrixCell> = {};
  for (const sk of MATRIX_SKILL_KINDS) {
    totals[sk] = rows.reduce(
      (acc, r) => ({
        published: acc.published + (r.cells[sk]?.published ?? 0),
        draft: acc.draft + (r.cells[sk]?.draft ?? 0),
      }),
      { published: 0, draft: 0 },
    );
  }

  // Group rows by course for header rows
  const grouped: Array<{ courseId: string; courseTitle: string; rows: MatrixRow[] }> = [];
  for (const row of rows) {
    const last = grouped[grouped.length - 1];
    if (last && last.courseId === row.courseId) {
      last.rows.push(row);
    } else {
      grouped.push({ courseId: row.courseId, courseTitle: row.courseTitle, rows: [row] });
    }
  }

  const colWidth = `${Math.floor(60 / MATRIX_SKILL_KINDS.length)}%`;
  const gridCols = `1fr ${MATRIX_SKILL_KINDS.map(() => colWidth).join(' ')}`;

  function isActive(moduleId: string | null, sk: string) {
    return activeCell?.moduleId === moduleId && activeCell?.skillKind === sk;
  }

  function handleCellClick(moduleId: string | null, sk: MatrixSkillKind) {
    onCellClick?.(moduleId, sk);
  }

  return (
    <div
      style={{
        background: 'var(--surface)',
        borderRadius: 28,
        border: '1px solid var(--border)',
        boxShadow: 'var(--shadow-md)',
        overflow: 'hidden',
      }}
    >
      {/* Header row */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: gridCols,
          padding: '10px 20px',
          background: 'var(--surface-alt)',
          borderBottom: '2px solid var(--border)',
          gap: 4,
        }}
      >
        <span style={{ fontSize: 11, fontWeight: 700, color: 'var(--ink-3)', textTransform: 'uppercase', letterSpacing: 0.5 }}>
          Module
        </span>
        {MATRIX_SKILL_KINDS.map((sk) => (
          <span
            key={sk}
            style={{
              fontSize: 11,
              fontWeight: 700,
              color: 'var(--ink-3)',
              textTransform: 'uppercase',
              letterSpacing: 0.5,
              textAlign: 'center',
            }}
          >
            {SKILL_LABELS[sk]}
          </span>
        ))}
      </div>

      {/* Grouped rows */}
      {grouped.length === 0 && (
        <div style={{ padding: '40px 24px', textAlign: 'center', color: 'var(--ink-3)' }}>
          <p style={{ margin: 0 }}>Chưa có module nào. Tạo module trong trang Modules.</p>
        </div>
      )}
      {grouped.map(({ courseId, courseTitle, rows: courseRows }) => (
        <div key={courseId}>
          {/* Course header */}
          <div
            style={{
              padding: '7px 20px',
              background: 'color-mix(in srgb, var(--brand) 8%, var(--surface-alt))',
              borderBottom: '1px solid var(--border)',
              borderTop: '1px solid var(--border)',
              fontSize: 11,
              fontWeight: 700,
              color: 'var(--brand)',
              letterSpacing: 0.4,
              textTransform: 'uppercase',
            }}
          >
            📚 {courseTitle}
          </div>

          {/* Module rows */}
          {courseRows.map((row, idx) => (
            <div
              key={row.moduleId}
              style={{
                display: 'grid',
                gridTemplateColumns: gridCols,
                padding: '12px 20px',
                borderBottom:
                  idx < courseRows.length - 1 ? '1px solid var(--border)' : 'none',
                gap: 4,
                alignItems: 'center',
              }}
            >
              {/* Module name */}
              <span style={{ fontSize: 13, fontWeight: 500, color: 'var(--ink)', minWidth: 0, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                {row.moduleTitle}
              </span>

              {/* Skill cells */}
              {MATRIX_SKILL_KINDS.map((sk) => {
                const cell = row.cells[sk] ?? { published: 0, draft: 0 };
                const active = isActive(row.moduleId, sk);
                return (
                  <button
                    key={sk}
                    type="button"
                    onClick={() => handleCellClick(row.moduleId, sk)}
                    style={{
                      display: 'flex',
                      flexDirection: 'column',
                      alignItems: 'center',
                      justifyContent: 'center',
                      padding: '6px 4px',
                      borderRadius: 8,
                      border: active ? '2px solid #FF6A14' : '1px solid transparent',
                      background: cellBg(cell.published),
                      cursor: onCellClick ? 'pointer' : 'default',
                      gap: 1,
                      minWidth: 0,
                    }}
                  >
                    <span style={{ fontSize: 15, fontWeight: 700, color: cellTextColor(cell.published), lineHeight: 1 }}>
                      {cell.published}
                    </span>
                    {cell.draft > 0 && (
                      <span style={{ fontSize: 10, color: '#6B7280', lineHeight: 1 }}>
                        ({cell.draft} nháp)
                      </span>
                    )}
                  </button>
                );
              })}
            </div>
          ))}
        </div>
      ))}

      {/* Tổng row */}
      {grouped.length > 0 && (
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: gridCols,
            padding: '12px 20px',
            background: 'var(--surface-alt)',
            borderTop: '2px solid var(--border)',
            gap: 4,
            alignItems: 'center',
            position: 'sticky',
            bottom: 0,
          }}
        >
          <span style={{ fontSize: 12, fontWeight: 700, color: 'var(--ink-2)' }}>Tổng</span>
          {MATRIX_SKILL_KINDS.map((sk) => {
            const cell = totals[sk];
            const active = isActive(null, sk);
            return (
              <button
                key={sk}
                type="button"
                onClick={() => handleCellClick(null, sk)}
                style={{
                  display: 'flex',
                  flexDirection: 'column',
                  alignItems: 'center',
                  padding: '5px 4px',
                  borderRadius: 8,
                  border: active ? '2px solid #FF6A14' : '1px solid transparent',
                  background: 'transparent',
                  cursor: onCellClick ? 'pointer' : 'default',
                  gap: 1,
                }}
              >
                <span style={{ fontSize: 14, fontWeight: 700, color: 'var(--ink)', lineHeight: 1 }}>
                  {cell.published}
                </span>
                {cell.draft > 0 && (
                  <span style={{ fontSize: 10, color: '#6B7280', lineHeight: 1 }}>
                    ({cell.draft})
                  </span>
                )}
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
}
