'use client';

import { useMemo, useState } from 'react';
import { useS } from '../lib/i18n';
import {
  buildExamExerciseMembershipIndex,
  examMembershipLabel,
} from './exam-exercise-membership';
import { hasAnyIssue } from './validation-badges';
import { ValidationBadgeCluster } from './validation-badge-cluster';
import {
  CmsCourse,
  CmsModule,
  CmsMockTest,
  Exercise,
  filterSelectStyle,
  SKILL_KIND_META,
} from './exercise-utils';

export type ExerciseListFilters = {
  courseId: string;
  moduleId: string;
  skillKind: string;
  mockTestId: string;
  text: string;
};

type Props = {
  items: Exercise[];
  modules: CmsModule[];
  courses: CmsCourse[];
  mockTests: CmsMockTest[];
  loading: boolean;
  error: string | null;
  filters: ExerciseListFilters;
  onFilterChange: (patch: Partial<ExerciseListFilters>) => void;
  onEdit: (item: Exercise) => void;
  onDelete: (id: string) => void;
  onClone?: (item: Exercise) => void | Promise<void>;
  onRowClick?: (item: Exercise) => void;
  onReload: () => void;
  onOpenCreate: () => void;
  showExamMembership?: boolean;
};

export function ExerciseList({
  items,
  modules,
  courses,
  mockTests,
  loading,
  error,
  filters,
  onFilterChange,
  onEdit,
  onDelete,
  onClone,
  onRowClick,
  onReload,
  onOpenCreate,
  showExamMembership = false,
}: Props) {
  const S = useS();
  const { courseId, moduleId, skillKind, mockTestId, text } = filters;

  const moduleMap = useMemo(() => new Map(modules.map((m) => [m.id, m])), [modules]);
  const examMembershipByExercise = useMemo(
    () => buildExamExerciseMembershipIndex(mockTests),
    [mockTests],
  );

  const mtExerciseIds = useMemo(
    () => mockTestId
      ? new Set((mockTests.find((t) => t.id === mockTestId)?.sections ?? []).map((s) => s.exercise_id))
      : null,
    [mockTestId, mockTests],
  );

  const modulesForCourse = useMemo(
    () => courseId ? modules.filter((m) => m.course_id === courseId) : modules,
    [courseId, modules],
  );

  const skillKindsInView = useMemo(
    () => [...new Set(items.map((i) => i.skill_kind).filter(Boolean))] as string[],
    [items],
  );

  const [problemOnly, setProblemOnly] = useState(false);
  const [aiOnly, setAiOnly] = useState(false);

  const filteredItems = useMemo(() => items.filter((item) => {
    if (skillKind && item.skill_kind !== skillKind) return false;
    if (moduleId && item.module_id !== moduleId) return false;
    if (courseId && !moduleId) {
      const mod = moduleMap.get(item.module_id ?? '');
      if (mod?.course_id !== courseId) return false;
    }
    if (mtExerciseIds && !mtExerciseIds.has(item.id)) return false;
    if (
      text &&
      !item.title.toLowerCase().includes(text.toLowerCase()) &&
      !item.exercise_type.toLowerCase().includes(text.toLowerCase())
    ) return false;
    if (problemOnly && !hasAnyIssue(item.validation_flags)) return false;
    if (aiOnly && !item.created_by_llm) return false;
    return true;
  }), [items, skillKind, moduleId, courseId, moduleMap, mtExerciseIds, text, problemOnly, aiOnly]);

  function clearFilters() {
    onFilterChange({ courseId: '', moduleId: '', skillKind: '', mockTestId: '', text: '' });
  }

  const hasFilter = !!(courseId || moduleId || skillKind || mockTestId || text);
  const gridTemplateColumns = showExamMembership
    ? 'minmax(240px, 2fr) minmax(110px, 0.8fr) minmax(190px, 1fr) 150px 220px'
    : '2fr 1fr 200px 240px';

  return (
    <section
      id="exercise-list"
      style={{
        background: 'var(--surface)',
        borderRadius: 28,
        border: '1px solid var(--border)',
        boxShadow: 'var(--shadow-md)',
        overflow: 'hidden',
      }}
    >
      {/* Toolbar */}
      <div
        style={{
          padding: '20px 24px',
          borderBottom: '1px solid var(--border)',
          display: 'flex',
          gap: 12,
          alignItems: 'center',
          flexWrap: 'wrap',
        }}
      >
        <div style={{ flex: '0 0 auto' }}>
          <span
            style={{
              fontSize: 11,
              fontWeight: 700,
              letterSpacing: 1,
              color: 'var(--brand)',
              textTransform: 'uppercase',
            }}
          >
            {S.exercise.inventoryEyebrow}
          </span>
          <h2 style={{ margin: '2px 0 0', fontSize: 20, fontWeight: 700 }}>
            {S.exercise.inventoryTitle}
          </h2>
        </div>
        <div style={{ flex: 1, minWidth: 180 }}>
          <input
            type="search"
            placeholder="Tìm theo tên, loại bài..."
            value={text}
            onChange={(e) => onFilterChange({ text: e.target.value })}
            style={{
              width: '100%',
              padding: '9px 14px',
              borderRadius: 12,
              border: '1px solid var(--border)',
              background: 'var(--surface-alt)',
              fontSize: 14,
              outline: 'none',
              boxSizing: 'border-box',
            }}
          />
        </div>
        <div style={{ display: 'flex', gap: 8, flexShrink: 0 }}>
          <button
            type="button"
            onClick={onReload}
            style={{
              borderRadius: 12,
              border: '1px solid var(--border)',
              background: 'transparent',
              padding: '9px 14px',
              cursor: 'pointer',
              fontWeight: 600,
              fontSize: 13,
              color: 'var(--ink-2)',
            }}
          >
            ↺
          </button>
          <button
            type="button"
            onClick={onOpenCreate}
            style={{
              borderRadius: 12,
              border: 'none',
              background: 'var(--brand)',
              color: '#fff',
              padding: '9px 18px',
              cursor: 'pointer',
              fontWeight: 700,
              fontSize: 13,
            }}
          >
            + {S.exercise.createCta}
          </button>
        </div>
      </div>

      {/* Filter bar — cascade for course pool; skill + mock test for exam pool. */}
      <div
        style={{
          padding: '12px 24px',
          borderBottom: '1px solid var(--border)',
          display: 'flex',
          gap: 6,
          alignItems: 'center',
          flexWrap: 'wrap',
          background: 'var(--surface-alt)',
        }}
      >
        {!showExamMembership && (
          <>
            {/* Course */}
            <select
              value={courseId}
              onChange={(e) => onFilterChange({ courseId: e.target.value, moduleId: '', skillKind: '', mockTestId: '' })}
              style={filterSelectStyle(!!courseId)}
            >
              <option value="">Khóa học</option>
              {courses.map((c) => (
                <option key={c.id} value={c.id}>{c.title}</option>
              ))}
            </select>

            <span style={{ color: 'var(--ink-4)', fontSize: 14, flexShrink: 0 }}>›</span>

            {/* Module — cascade from course */}
            <select
              value={moduleId}
              onChange={(e) => onFilterChange({ moduleId: e.target.value, skillKind: '', mockTestId: '' })}
              style={filterSelectStyle(!!moduleId)}
              disabled={modulesForCourse.length === 0}
            >
              <option value="">Module</option>
              {modulesForCourse.map((m) => (
                <option key={m.id} value={m.id}>{m.title}</option>
              ))}
            </select>

            <span style={{ color: 'var(--ink-4)', fontSize: 14, flexShrink: 0 }}>›</span>
          </>
        )}

        {/* Skill kind */}
        <select
          value={skillKind}
          onChange={(e) => onFilterChange(
            showExamMembership
              ? { skillKind: e.target.value }
              : { skillKind: e.target.value, mockTestId: '' },
          )}
          style={filterSelectStyle(!!skillKind)}
        >
          <option value="">Kỹ năng</option>
          {skillKindsInView.map((kind) => (
            <option key={kind} value={kind}>
              {SKILL_KIND_META[kind as keyof typeof SKILL_KIND_META]?.icon} {kind}
            </option>
          ))}
        </select>

        <span style={{ color: 'var(--ink-4)', fontSize: 14, flexShrink: 0 }}>|</span>

        {/* Mock test — independent */}
        <select
          value={mockTestId}
          onChange={(e) => onFilterChange(
            showExamMembership
              ? { mockTestId: e.target.value }
              : { mockTestId: e.target.value, courseId: '', moduleId: '', skillKind: '' },
          )}
          style={filterSelectStyle(!!mockTestId)}
        >
          <option value="">Đề thi</option>
          {mockTests.map((mt) => (
            <option key={mt.id} value={mt.id}>{mt.title}</option>
          ))}
        </select>

        {hasFilter && (
          <button
            type="button"
            onClick={clearFilters}
            style={{
              background: 'none',
              border: 'none',
              color: 'var(--brand)',
              cursor: 'pointer',
              fontSize: 12,
              fontWeight: 600,
              padding: '0 4px',
              flexShrink: 0,
            }}
          >
            ✕ Xoá
          </button>
        )}
        <label
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 6,
            fontSize: 12,
            color: 'var(--ink-2)',
            cursor: 'pointer',
            marginLeft: 'auto',
          }}
        >
          <input
            type="checkbox"
            checked={problemOnly}
            onChange={(e) => setProblemOnly(e.target.checked)}
          />
          Chỉ hiện vấn đề
        </label>
        <label
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 6,
            fontSize: 12,
            color: 'var(--ink-2)',
            cursor: 'pointer',
          }}
        >
          <input
            type="checkbox"
            checked={aiOnly}
            onChange={(e) => setAiOnly(e.target.checked)}
          />
          ✨ AI-drafted
        </label>
        <span
          style={{
            fontSize: 12,
            color: 'var(--ink-3)',
            fontVariantNumeric: 'tabular-nums',
            flexShrink: 0,
          }}
        >
          {filteredItems.length} / {items.length}
        </span>
      </div>

      {/* Table header */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns,
          gap: 0,
          padding: '8px 24px',
          background: 'var(--surface-alt)',
          borderBottom: '1px solid var(--border)',
        }}
      >
        {(showExamMembership
          ? ['Bài tập', 'Kỹ năng', 'Đề thi', 'Trạng thái', '']
          : ['Bài tập', 'Kỹ năng', 'Trạng thái', '']
        ).map((h, i) => (
          <span
            key={i}
            style={{
              fontSize: 11,
              fontWeight: 700,
              color: 'var(--ink-3)',
              letterSpacing: 0.5,
              textTransform: 'uppercase',
            }}
          >
            {h}
          </span>
        ))}
      </div>

      {/* Table body */}
      {error && <p style={{ margin: '16px 24px', color: 'var(--error)' }}>{error}</p>}
      {loading && <p style={{ margin: '24px', color: 'var(--ink-3)' }}>Đang tải...</p>}
      {!loading && filteredItems.length === 0 && (
        <div style={{ padding: '48px 24px', textAlign: 'center', color: 'var(--ink-3)' }}>
          <div style={{ fontSize: 32, marginBottom: 8 }}>📭</div>
          <p style={{ margin: 0, fontWeight: 600 }}>Không tìm thấy bài tập nào</p>
        </div>
      )}
      <div>
        {filteredItems.map((item, idx) => {
          const kind = item.skill_kind ?? '';
          const meta = SKILL_KIND_META[kind as keyof typeof SKILL_KIND_META];
          const modForRow = modules.find((m) => m.id === item.module_id) ?? null;
          const typeColor: Record<string, string> = {
            noi: '#FF6A14',
            viet: '#0F3D3A',
            nghe: '#7C3AED',
            doc: '#0369A1',
          };
          const typeBg: Record<string, string> = {
            noi: '#fff5ef',
            viet: '#d9e5e3',
            nghe: '#f3e8ff',
            doc: '#e0f2fe',
          };
          const color = typeColor[kind] ?? 'var(--ink-3)';
          const bg = typeBg[kind] ?? 'var(--surface-alt)';
          const examMembership = examMembershipByExercise.get(item.id) ?? [];

          return (
            <div
              key={item.id}
              style={{
                display: 'grid',
                gridTemplateColumns,
                gap: 0,
                padding: '14px 24px',
                borderBottom: idx < filteredItems.length - 1 ? '1px solid var(--border)' : 'none',
                alignItems: 'center',
                transition: 'background 120ms',
                cursor: onRowClick ? 'pointer' : 'default',
              }}
              onMouseEnter={(e) => (e.currentTarget.style.background = 'var(--surface-alt)')}
              onMouseLeave={(e) => (e.currentTarget.style.background = 'transparent')}
              onClick={() => onRowClick?.(item)}
            >
              {/* Title + type */}
              <div style={{ display: 'flex', flexDirection: 'column', gap: 4, minWidth: 0 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <span
                    style={{
                      fontSize: 10,
                      fontWeight: 700,
                      padding: '2px 7px',
                      borderRadius: 6,
                      background: bg,
                      color,
                      letterSpacing: 0.3,
                      whiteSpace: 'nowrap',
                      flexShrink: 0,
                    }}
                  >
                    {meta?.icon} {item.exercise_type.replace(/_/g, ' ').toUpperCase()}
                  </span>
                  <strong
                    style={{
                      fontSize: 14,
                      fontWeight: 600,
                      color: 'var(--ink)',
                      overflow: 'hidden',
                      textOverflow: 'ellipsis',
                      whiteSpace: 'nowrap',
                    }}
                  >
                    {item.title}
                  </strong>
                  {item.created_by_llm && (
                    <span
                      title="Đã tạo bằng AI draft generator"
                      aria-label="AI-drafted"
                      style={{
                        marginLeft: 6,
                        fontSize: 11,
                        color: 'var(--brand, #7c3aed)',
                        flexShrink: 0,
                      }}
                    >
                      ✨
                    </span>
                  )}
                </div>
                {item.short_instruction && (
                  <span
                    style={{
                      fontSize: 12,
                      color: 'var(--ink-3)',
                      overflow: 'hidden',
                      textOverflow: 'ellipsis',
                      whiteSpace: 'nowrap',
                    }}
                  >
                    {item.short_instruction}
                  </span>
                )}
              </div>

              {/* Skill + module */}
              <div style={{ display: 'flex', flexDirection: 'column', gap: 2, minWidth: 0 }}>
                <span
                  style={{
                    fontSize: 12,
                    fontWeight: 600,
                    color: 'var(--ink-2)',
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                    whiteSpace: 'nowrap',
                  }}
                >
                  {kind ? (
                    `${meta?.icon ?? ''} ${kind}`
                  ) : (
                    <em style={{ color: 'var(--ink-4)' }}>—</em>
                  )}
                </span>
                {modForRow && (
                  <span
                    style={{
                      fontSize: 11,
                      color: 'var(--ink-4)',
                      overflow: 'hidden',
                      textOverflow: 'ellipsis',
                      whiteSpace: 'nowrap',
                    }}
                  >
                    {modForRow.title}
                  </span>
                )}
              </div>

              {showExamMembership && (
                <div style={{ display: 'flex', flexDirection: 'column', gap: 4, minWidth: 0, paddingRight: 12 }}>
                  {examMembership.length === 0 ? (
                    <span
                      title="Bài pool=exam này chưa được gắn vào Mock Test nào."
                      style={{
                        width: 'fit-content',
                        maxWidth: '100%',
                        borderRadius: 8,
                        background: 'var(--needs-bg)',
                        color: 'var(--needs)',
                        fontSize: 11,
                        fontWeight: 700,
                        padding: '3px 8px',
                        overflow: 'hidden',
                        textOverflow: 'ellipsis',
                        whiteSpace: 'nowrap',
                      }}
                    >
                      Chưa gắn đề
                    </span>
                  ) : (
                    <>
                      {examMembership.slice(0, 2).map((membership) => (
                        <span
                          key={membership.mockTestId}
                          title={examMembershipLabel(membership)}
                          style={{
                            maxWidth: '100%',
                            overflow: 'hidden',
                            textOverflow: 'ellipsis',
                            whiteSpace: 'nowrap',
                            color: 'var(--ink-2)',
                            fontSize: 12,
                            fontWeight: 600,
                          }}
                        >
                          {examMembershipLabel(membership)}
                        </span>
                      ))}
                      {examMembership.length > 2 && (
                        <span style={{ color: 'var(--ink-4)', fontSize: 11 }}>
                          +{examMembership.length - 2} đề nữa
                        </span>
                      )}
                    </>
                  )}
                </div>
              )}

              {/* Status badge + V23 validation badges */}
              <div style={{
                display: 'flex', flexDirection: 'column', gap: 4,
                alignItems: 'flex-start',
                minWidth: 0,
                overflow: 'hidden',
              }}>
              <span
                style={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  width: 'fit-content',
                  fontSize: 11,
                  fontWeight: 700,
                  padding: '3px 9px',
                  borderRadius: 99,
                  letterSpacing: 0.3,
                  background:
                    item.status === 'published'
                      ? 'var(--ready-bg)'
                      : item.status === 'archived'
                        ? 'var(--surface-alt)'
                        : 'var(--needs-bg)',
                  color:
                    item.status === 'published'
                      ? 'var(--ready)'
                      : item.status === 'archived'
                        ? 'var(--ink-3)'
                        : 'var(--needs)',
                }}
              >
                {S.status[item.status as keyof typeof S.status] ?? item.status}
              </span>
              <ValidationBadgeCluster flags={item.validation_flags} variant="row" />
              </div>

              {/* Actions */}
              <div style={{ display: 'flex', gap: 6, justifyContent: 'flex-end' }} onClick={(e) => e.stopPropagation()}>
                <button
                  type="button"
                  onClick={() => onEdit(item)}
                  style={{
                    padding: '5px 12px',
                    borderRadius: 8,
                    border: '1px solid var(--border)',
                    background: 'transparent',
                    cursor: 'pointer',
                    fontSize: 12,
                    fontWeight: 600,
                    color: 'var(--ink-2)',
                  }}
                >
                  {S.action.edit}
                </button>
                {onClone && (
                  <button
                    type="button"
                    onClick={() => void onClone(item)}
                    style={{
                      padding: '5px 12px',
                      borderRadius: 8,
                      border: '1px solid var(--border)',
                      background: 'var(--brand-soft)',
                      cursor: 'pointer',
                      fontSize: 12,
                      fontWeight: 600,
                      color: 'var(--brand-deep)',
                    }}
                    title="Sao chép thành bài tập mới (status=draft, không clone audio)"
                  >
                    Sao chép
                  </button>
                )}
                <button
                  type="button"
                  onClick={() => onDelete(item.id)}
                  style={{
                    padding: '5px 10px',
                    borderRadius: 8,
                    border: 'none',
                    background: 'var(--error-bg)',
                    cursor: 'pointer',
                    fontSize: 12,
                    fontWeight: 600,
                    color: 'var(--error)',
                  }}
                >
                  {S.action.delete}
                </button>
              </div>
            </div>
          );
        })}
      </div>
    </section>
  );
}
