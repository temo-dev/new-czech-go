'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import { useS } from '../lib/i18n';
import { adminFetch } from '../lib/api';
import { ExerciseList, ExerciseListFilters } from './exercise-list';
import { ExerciseSlideOver } from './exercise-form';
import { ExerciseMatrix, ExamPoolMatrix, MatrixSkillKind } from './exercise-matrix';
import {
  CmsCourse,
  CmsModule,
  CmsMockTest,
  Exercise,
  eyebrowStyle,
  metricCardStyle,
  metricHintStyle,
  metricLabelStyle,
  metricValueStyle,
} from './exercise-utils';

type ActiveCell = { moduleId: string | null; skillKind: MatrixSkillKind } | null;
type FormPrefill = { moduleId?: string; skillKind?: string; pool?: string } | null;

function tabStyle(active: boolean): React.CSSProperties {
  return {
    padding: '10px 20px',
    fontSize: 14,
    fontWeight: active ? 700 : 500,
    color: active ? 'var(--brand)' : 'var(--ink-3)',
    background: 'none',
    border: 'none',
    borderBottom: active ? '2px solid var(--brand)' : '2px solid transparent',
    cursor: 'pointer',
    transition: 'color 150ms, border-color 150ms',
  };
}

function MatrixSkeleton() {
  return (
    <div
      style={{
        background: 'var(--surface)',
        borderRadius: 28,
        border: '1px solid var(--border)',
        padding: 24,
        display: 'grid',
        gap: 12,
      }}
    >
      {[1, 2, 3, 4].map((n) => (
        <div
          key={n}
          style={{
            height: 44,
            borderRadius: 8,
            background: 'linear-gradient(90deg, var(--surface-alt) 25%, var(--border) 50%, var(--surface-alt) 75%)',
            backgroundSize: '200% 100%',
            animation: 'shimmer 1.4s infinite',
            opacity: 0.7,
          }}
        />
      ))}
      <style>{`@keyframes shimmer { 0%{background-position:200% 0} 100%{background-position:-200% 0} }`}</style>
    </div>
  );
}

export function ExerciseDashboard() {
  const S = useS();

  // ── Data state ──────────────────────────────────────────────────────────────
  const [items, setItems] = useState<Exercise[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [availableModules, setAvailableModules] = useState<CmsModule[]>([]);
  const [courses, setCourses] = useState<CmsCourse[]>([]);
  const [mockTests, setMockTests] = useState<CmsMockTest[]>([]);

  // ── UI state ─────────────────────────────────────────────────────────────────
  const [activeTab, setActiveTab] = useState<'course' | 'exam'>('course');
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [formPrefill, setFormPrefill] = useState<FormPrefill>(null);
  const [activeCell, setActiveCell] = useState<ActiveCell>(null);
  const [activeExamType, setActiveExamType] = useState<string | null>(null);
  const [listFilters, setListFilters] = useState<ExerciseListFilters>({
    courseId: '', moduleId: '', skillKind: '', mockTestId: '', text: '',
  });
  const listRef = useRef<HTMLDivElement>(null);

  const editingItem = editingId ? (items.find((i) => i.id === editingId) ?? null) : null;

  function patchFilters(patch: Partial<ExerciseListFilters>) {
    setListFilters((f) => ({ ...f, ...patch }));
  }

  // ── Data fetchers ────────────────────────────────────────────────────────────
  async function loadExercises() {
    setLoading(true);
    setError(null);
    try {
      const res = await adminFetch('/api/admin/exercises');
      const payload = await res.json();
      if (!res.ok) throw new Error(payload.error?.message ?? 'Could not load exercises.');
      setItems(payload.data ?? []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
    } finally {
      setLoading(false);
    }
  }

  async function loadModules() {
    try {
      const res = await adminFetch('/api/admin/modules');
      const j = await res.json();
      setAvailableModules(j.data ?? []);
    } catch { /* non-fatal */ }
  }

  async function loadCourses() {
    try {
      const res = await adminFetch('/api/admin/courses');
      const j = await res.json();
      setCourses(j.data ?? []);
    } catch { /* non-fatal */ }
  }

  async function loadMockTests() {
    try {
      const res = await adminFetch('/api/admin/mock-tests');
      const j = await res.json();
      setMockTests(j.data ?? []);
    } catch { /* non-fatal */ }
  }

  useEffect(() => {
    void loadExercises();
    void loadModules();
    void loadCourses();
    void loadMockTests();
  }, []);

  // ── Matrix cell click ────────────────────────────────────────────────────────
  function handleCellClick(moduleId: string | null, skillKind: MatrixSkillKind) {
    if (activeCell?.moduleId === moduleId && activeCell?.skillKind === skillKind) {
      setActiveCell(null);
      patchFilters({ moduleId: '', skillKind: '' });
      return;
    }
    setActiveCell({ moduleId, skillKind });
    patchFilters({ moduleId: moduleId ?? '', skillKind });
    listRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  // ── Form callbacks ───────────────────────────────────────────────────────────
  function openCreate(prefill?: FormPrefill) {
    setFormPrefill(prefill ?? null);
    setEditingId(null);
    setShowForm(true);
  }

  function startEditing(item: Exercise) {
    setFormPrefill(null);
    setEditingId(item.id);
    setShowForm(true);
  }

  function handleClose() {
    setShowForm(false);
    setEditingId(null);
    setFormPrefill(null);
  }

  async function handleSaved() {
    await loadExercises();
  }

  // Called by slide-over after form-based deletion; id ignored, just reload
  async function handleFormDeleted(_id: string) {
    await loadExercises();
  }

  async function handleDelete(id: string) {
    if (!window.confirm(S.exercise.deleteConfirm)) return;
    try {
      const res = await adminFetch(`/api/admin/exercises/${id}`, { method: 'DELETE' });
      if (!res.ok) {
        const p = await res.json();
        throw new Error(p.error?.message ?? 'Could not delete exercise.');
      }
      await loadExercises();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
    }
  }

  // ── Derived data (memoized) ───────────────────────────────────────────────────
  const courseItems = useMemo(() => items.filter((i) => i.pool !== 'exam'), [items]);
  const examItems = useMemo(() => items.filter((i) => i.pool === 'exam'), [items]);
  const examFiltered = useMemo(
    () => (activeExamType ? examItems.filter((i) => i.exercise_type === activeExamType) : examItems),
    [examItems, activeExamType],
  );

  // ── Render ───────────────────────────────────────────────────────────────────
  return (
    <main style={{ display: 'grid', gap: 24 }}>
      {/* Hero + metrics */}
      <section
        style={{
          display: 'grid',
          gap: 18,
          padding: 28,
          borderRadius: 28,
          background: 'var(--surface)',
          border: '1px solid var(--border)',
          boxShadow: 'var(--shadow)',
        }}
      >
        <div style={{ display: 'grid', gap: 8 }}>
          <p style={eyebrowStyle}>A2 Mluveni CMS</p>
          <h1 style={{ margin: 0, fontSize: 'clamp(2.2rem, 3vw, 3.5rem)', lineHeight: 1.02 }}>
            {S.exercise.heroTitle}
          </h1>
          <p style={{ margin: 0, maxWidth: 760, color: 'var(--text-secondary)', fontSize: 16, lineHeight: 1.55 }}>
            {S.exercise.heroDesc}
          </p>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 14 }}>
          <div style={metricCardStyle}>
            <span style={metricLabelStyle}>{S.exercise.metricSliceLabel}</span>
            <strong style={metricValueStyle}>{S.exercise.metricSliceValue}</strong>
            <span style={metricHintStyle}>{S.exercise.metricSliceHint}</span>
          </div>
          <div style={metricCardStyle}>
            <span style={metricLabelStyle}>{S.exercise.metricStatusLabel}</span>
            <strong style={metricValueStyle}>{items.length}</strong>
            <span style={metricHintStyle}>{S.exercise.metricStatusHint}</span>
          </div>
          <div style={metricCardStyle}>
            <span style={metricLabelStyle}>{S.exercise.metricModeLabel}</span>
            <strong style={metricValueStyle}>{S.exercise.metricModeValue}</strong>
            <span style={metricHintStyle}>{S.exercise.metricModeHint}</span>
          </div>
        </div>
      </section>

      {/* API error banner */}
      {error && (
        <div
          style={{
            padding: '12px 18px',
            background: 'var(--error-bg)',
            borderRadius: 12,
            border: '1px solid var(--error)',
            display: 'flex',
            gap: 12,
            alignItems: 'center',
          }}
        >
          <span style={{ flex: 1, color: 'var(--error)', fontSize: 14 }}>{error}</span>
          <button
            onClick={() => { setError(null); void loadExercises(); }}
            style={{ background: 'var(--error)', color: '#fff', border: 'none', borderRadius: 8, padding: '5px 12px', cursor: 'pointer', fontSize: 13, fontWeight: 600 }}
          >
            Thử lại
          </button>
        </div>
      )}

      {/* Slide-over form */}
      <ExerciseSlideOver
        open={showForm}
        editingItem={editingItem}
        modules={availableModules}
        prefillModuleId={formPrefill?.moduleId}
        prefillSkillKind={formPrefill?.skillKind}
        prefillPool={formPrefill?.pool}
        onSaved={handleSaved}
        onDeleted={handleFormDeleted}
        onClose={handleClose}
      />

      {/* Tab bar */}
      <div
        style={{
          display: 'flex',
          background: 'var(--surface)',
          borderRadius: '16px 16px 0 0',
          overflow: 'hidden',
          border: '1px solid var(--border)',
          borderBottom: 'none',
          marginBottom: -1,
        }}
      >
        <button style={tabStyle(activeTab === 'course')} onClick={() => setActiveTab('course')}>
          Khoá học
        </button>
        <button style={tabStyle(activeTab === 'exam')} onClick={() => setActiveTab('exam')}>
          Exam Pool
          {examItems.length > 0 && (
            <span style={{ marginLeft: 6, fontSize: 11, background: 'var(--surface-alt)', color: 'var(--ink-3)', padding: '1px 6px', borderRadius: 99, fontWeight: 600 }}>
              {examItems.length}
            </span>
          )}
        </button>
      </div>

      {/* Tab: Khoá học */}
      {activeTab === 'course' && (
        <>
          {loading ? (
            <MatrixSkeleton />
          ) : (
            <ExerciseMatrix
              items={courseItems}
              modules={availableModules}
              courses={courses}
              activeCell={activeCell}
              onCellClick={handleCellClick}
            />
          )}
          <div ref={listRef}>
            <ExerciseList
              items={courseItems}
              modules={availableModules}
              courses={courses}
              mockTests={mockTests}
              loading={loading}
              error={null}
              filters={listFilters}
              onFilterChange={(patch) => {
                patchFilters(patch);
                // Clear active cell if user manually changes filters
                if (patch.moduleId !== undefined || patch.skillKind !== undefined) {
                  setActiveCell(null);
                }
              }}
              onEdit={startEditing}
              onDelete={handleDelete}
              onReload={loadExercises}
              onOpenCreate={() =>
                openCreate(
                  activeCell
                    ? { moduleId: activeCell.moduleId ?? '', skillKind: activeCell.skillKind }
                    : undefined,
                )
              }
            />
          </div>
        </>
      )}

      {/* Tab: Exam Pool */}
      {activeTab === 'exam' && (
        <div style={{ display: 'grid', gap: 16 }}>
          <ExamPoolMatrix
            items={examItems}
            activeType={activeExamType}
            onTypeClick={setActiveExamType}
          />
          <ExerciseList
            items={examFiltered}
            modules={availableModules}
            courses={courses}
            mockTests={[]}
            loading={loading}
            error={null}
            filters={{ courseId: '', moduleId: '', skillKind: '', mockTestId: '', text: listFilters.text }}
            onFilterChange={(patch) => patchFilters({ text: patch.text ?? listFilters.text })}
            onEdit={startEditing}
            onDelete={handleDelete}
            onReload={loadExercises}
            onOpenCreate={() => openCreate({ pool: 'exam' })}
          />
        </div>
      )}
    </main>
  );
}
