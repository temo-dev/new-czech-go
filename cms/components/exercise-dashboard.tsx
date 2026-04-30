'use client';

import { useEffect, useRef, useState } from 'react';
import { useS } from '../lib/i18n';
import { adminFetch } from '../lib/api';
import { ExerciseList, ExerciseListFilters } from './exercise-list';
import { ExerciseSlideOver } from './exercise-form';
import { ExerciseMatrix, MatrixSkillKind } from './exercise-matrix';
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
  const [activeCell, setActiveCell] = useState<ActiveCell>(null);
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
    // Toggle: clicking active cell clears filters
    if (activeCell?.moduleId === moduleId && activeCell?.skillKind === skillKind) {
      setActiveCell(null);
      patchFilters({ moduleId: '', skillKind: '' });
      return;
    }
    setActiveCell({ moduleId, skillKind });
    patchFilters({ moduleId: moduleId ?? '', skillKind });
    // Scroll to list
    listRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  // ── Form callbacks ───────────────────────────────────────────────────────────
  function openCreate() {
    setEditingId(null);
    setShowForm(true);
  }

  function startEditing(item: Exercise) {
    setEditingId(item.id);
    setShowForm(true);
  }

  function handleClose() {
    setShowForm(false);
    setEditingId(null);
  }

  async function handleSaved() {
    await loadExercises();
  }

  async function handleDeleted(_id: string) {
    await loadExercises();
  }

  // ── Tab styles ───────────────────────────────────────────────────────────────
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

  // ── Exam pool items ──────────────────────────────────────────────────────────
  const examItems = items.filter((i) => i.pool === 'exam');

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
          <p
            style={{
              margin: 0,
              maxWidth: 760,
              color: 'var(--text-secondary)',
              fontSize: 16,
              lineHeight: 1.55,
            }}
          >
            {S.exercise.heroDesc}
          </p>
        </div>
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
            gap: 14,
          }}
        >
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

      {/* Slide-over form */}
      <ExerciseSlideOver
        open={showForm}
        editingItem={editingItem}
        modules={availableModules}
        onSaved={handleSaved}
        onDeleted={handleDeleted}
        onClose={handleClose}
      />

      {/* Tab bar */}
      <div
        style={{
          display: 'flex',
          borderBottom: '1px solid var(--border)',
          background: 'var(--surface)',
          borderRadius: '16px 16px 0 0',
          paddingTop: 4,
          overflow: 'hidden',
          border: '1px solid var(--border)',
        }}
      >
        <button style={tabStyle(activeTab === 'course')} onClick={() => setActiveTab('course')}>
          Khoá học
        </button>
        <button style={tabStyle(activeTab === 'exam')} onClick={() => setActiveTab('exam')}>
          Exam Pool
          {examItems.length > 0 && (
            <span
              style={{
                marginLeft: 6,
                fontSize: 11,
                background: 'var(--surface-alt)',
                color: 'var(--ink-3)',
                padding: '1px 6px',
                borderRadius: 99,
                fontWeight: 600,
              }}
            >
              {examItems.length}
            </span>
          )}
        </button>
      </div>

      {/* Tab: Khoá học */}
      {activeTab === 'course' && (
        <>
          <ExerciseMatrix
            items={items}
            modules={availableModules}
            courses={courses}
            activeCell={activeCell}
            onCellClick={handleCellClick}
          />
          <div ref={listRef}>
            <ExerciseList
              items={items.filter((i) => i.pool !== 'exam')}
              modules={availableModules}
              courses={courses}
              mockTests={mockTests}
              loading={loading}
              error={error}
              filters={listFilters}
              onFilterChange={patchFilters}
              onEdit={startEditing}
              onDelete={async (id) => {
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
              }}
              onReload={loadExercises}
              onOpenCreate={openCreate}
            />
          </div>
        </>
      )}

      {/* Tab: Exam Pool */}
      {activeTab === 'exam' && (
        <ExerciseList
          items={examItems}
          modules={availableModules}
          courses={courses}
          mockTests={mockTests}
          loading={loading}
          error={error}
          filters={{ courseId: '', moduleId: '', skillKind: '', mockTestId: '', text: listFilters.text }}
          onFilterChange={(patch) => patchFilters({ text: patch.text ?? listFilters.text })}
          onEdit={startEditing}
          onDelete={async (id) => {
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
          }}
          onReload={loadExercises}
          onOpenCreate={openCreate}
        />
      )}
    </main>
  );
}
