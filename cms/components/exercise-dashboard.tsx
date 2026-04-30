'use client';

import { useEffect, useState } from 'react';
import { useS } from '../lib/i18n';
import { adminFetch } from '../lib/api';
import { ExerciseList, ExerciseListFilters } from './exercise-list';
import { ExerciseSlideOver } from './exercise-form';
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
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [listFilters, setListFilters] = useState<ExerciseListFilters>({
    courseId: '', moduleId: '', skillKind: '', mockTestId: '', text: '',
  });

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

      {/* Exercise list */}
      <ExerciseList
        items={items}
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
    </main>
  );
}
