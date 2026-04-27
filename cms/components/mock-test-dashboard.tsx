'use client';

import { FormEvent, useEffect, useState } from 'react';

type Exercise = {
  id: string;
  title: string;
  exercise_type: string;
  status?: string;
};

type MockTestSection = {
  sequence_no: number;
  exercise_id: string;
  exercise_type: string;
  max_points: number;
};

type MockTest = {
  id: string;
  title: string;
  description: string;
  estimated_duration_minutes: number;
  status: 'draft' | 'published';
  sections: MockTestSection[];
};

const DEFAULT_MAX_POINTS: Record<string, number> = {
  uloha_1_topic_answers: 8,
  uloha_2_dialogue_questions: 12,
  uloha_3_story_narration: 10,
  uloha_4_choice_reasoning: 7,
};

const EXERCISE_TYPE_LABEL: Record<string, string> = {
  uloha_1_topic_answers: 'Úloha 1 — Topic answers',
  uloha_2_dialogue_questions: 'Úloha 2 — Dialogue questions',
  uloha_3_story_narration: 'Úloha 3 — Story narration',
  uloha_4_choice_reasoning: 'Úloha 4 — Choice & reasoning',
};

const MOCK_TEST_API = '/api/admin/mock-tests';
const EXERCISES_API = '/api/admin/exercises';

type FormState = {
  title: string;
  description: string;
  estimated_duration_minutes: number;
  status: 'draft' | 'published';
  sections: MockTestSection[];
};

const emptyForm = (): FormState => ({
  title: '',
  description: '',
  estimated_duration_minutes: 15,
  status: 'draft',
  sections: [],
});

export function MockTestDashboard() {
  const [tests, setTests] = useState<MockTest[]>([]);
  const [exercises, setExercises] = useState<Exercise[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<FormState>(emptyForm());
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    Promise.all([fetchTests(), fetchExercises()]);
  }, []);

  async function fetchTests() {
    setLoading(true);
    try {
      const res = await fetch(MOCK_TEST_API);
      const json = await res.json();
      setTests(json.data ?? []);
    } catch {
      setError('Failed to load mock tests.');
    } finally {
      setLoading(false);
    }
  }

  async function fetchExercises() {
    try {
      const res = await fetch(EXERCISES_API + '?pool=exam');
      const json = await res.json();
      setExercises((json.data ?? []).filter((e: Exercise) => e.status === 'published' && (e as {pool?: string}).pool === 'exam'));
    } catch {
      // non-fatal
    }
  }

  function openCreate() {
    setEditingId(null);
    setForm(emptyForm());
    setShowForm(true);
  }

  function openEdit(t: MockTest) {
    setEditingId(t.id);
    setForm({
      title: t.title,
      description: t.description,
      estimated_duration_minutes: t.estimated_duration_minutes,
      status: t.status,
      sections: [...(t.sections ?? [])],
    });
    setShowForm(true);
  }

  function cancelForm() {
    setShowForm(false);
    setEditingId(null);
    setForm(emptyForm());
    setError('');
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError('');
    try {
      const payload = {
        title: form.title,
        description: form.description,
        estimated_duration_minutes: form.estimated_duration_minutes,
        status: form.status,
        sections: form.sections,
      };
      const url = editingId ? `${MOCK_TEST_API}/${editingId}` : MOCK_TEST_API;
      const method = editingId ? 'PATCH' : 'POST';
      const res = await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
      if (!res.ok) {
        const json = await res.json();
        throw new Error(json.error?.message ?? 'Save failed');
      }
      await fetchTests();
      cancelForm();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete(id: string) {
    if (!confirm('Delete this draft mock test?')) return;
    try {
      const res = await fetch(`${MOCK_TEST_API}/${id}`, { method: 'DELETE' });
      if (!res.ok) {
        const json = await res.json();
        throw new Error(json.error?.message ?? 'Delete failed');
      }
      await fetchTests();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Delete failed');
    }
  }

  function addSection() {
    const seq = (form.sections.length > 0 ? Math.max(...form.sections.map(s => s.sequence_no)) : 0) + 1;
    setForm(f => ({
      ...f,
      sections: [...f.sections, { sequence_no: seq, exercise_id: '', exercise_type: '', max_points: 0 }],
    }));
  }

  function removeSection(idx: number) {
    setForm(f => ({
      ...f,
      sections: f.sections.filter((_, i) => i !== idx).map((s, i) => ({ ...s, sequence_no: i + 1 })),
    }));
  }

  function updateSection(idx: number, exerciseId: string) {
    const ex = exercises.find(e => e.id === exerciseId);
    const exType = ex?.exercise_type ?? '';
    const maxPts = DEFAULT_MAX_POINTS[exType] ?? 0;
    setForm(f => ({
      ...f,
      sections: f.sections.map((s, i) =>
        i === idx ? { ...s, exercise_id: exerciseId, exercise_type: exType, max_points: maxPts } : s,
      ),
    }));
  }

  function updateSectionPoints(idx: number, pts: number) {
    setForm(f => ({
      ...f,
      sections: f.sections.map((s, i) => (i === idx ? { ...s, max_points: pts } : s)),
    }));
  }

  const statusBadge = (status: string) => {
    const colors: Record<string, string> = { published: '#16a34a', draft: '#6b7280' };
    return (
      <span style={{ background: colors[status] ?? '#6b7280', color: '#fff', borderRadius: 4, padding: '2px 8px', fontSize: 12, fontWeight: 600 }}>
        {status.toUpperCase()}
      </span>
    );
  };

  if (loading) return <p style={{ padding: 24 }}>Loading…</p>;

  return (
    <div style={{ maxWidth: 900, margin: '0 auto', padding: '24px 16px', fontFamily: 'sans-serif' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 24 }}>
        <h1 style={{ margin: 0, fontSize: 22, fontWeight: 700 }}>Mock Tests</h1>
        <button onClick={openCreate} style={btnStyle('primary')}>+ New mock test</button>
      </div>

      {error && <p style={{ color: 'red', marginBottom: 16 }}>{error}</p>}

      {!showForm && (
        <>
          {tests.length === 0 && <p style={{ color: '#6b7280' }}>No mock tests yet.</p>}
          {tests.map(t => (
            <div key={t.id} style={cardStyle}>
              <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 16 }}>
                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
                    {statusBadge(t.status)}
                    <strong>{t.title}</strong>
                  </div>
                  <p style={{ margin: '4px 0', color: '#6b7280', fontSize: 14 }}>{t.description}</p>
                  <p style={{ margin: '4px 0', fontSize: 13, color: '#9ca3af' }}>
                    {t.estimated_duration_minutes} min · {t.sections?.length ?? 0} sections ·{' '}
                    {t.sections?.reduce((s, sec) => s + sec.max_points, 0) ?? 0} pts
                  </p>
                </div>
                <div style={{ display: 'flex', gap: 8, flexShrink: 0 }}>
                  <button onClick={() => openEdit(t)} style={btnStyle('secondary')}>Edit</button>
                  {t.status === 'draft' && (
                    <button onClick={() => handleDelete(t.id)} style={btnStyle('danger')}>Delete</button>
                  )}
                </div>
              </div>
              {t.sections && t.sections.length > 0 && (
                <div style={{ marginTop: 12, display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                  {t.sections.map(sec => (
                    <span key={sec.sequence_no} style={sectionPillStyle}>
                      {sec.sequence_no}. {EXERCISE_TYPE_LABEL[sec.exercise_type] ?? sec.exercise_type} — {sec.max_points}pts
                    </span>
                  ))}
                </div>
              )}
            </div>
          ))}
        </>
      )}

      {showForm && (
        <form onSubmit={handleSubmit} style={{ ...cardStyle, borderColor: '#3b82f6' }}>
          <h2 style={{ margin: '0 0 16px', fontSize: 18 }}>
            {editingId ? 'Edit mock test' : 'New mock test'}
          </h2>

          <label style={labelStyle}>Title *</label>
          <input
            required
            value={form.title}
            onChange={e => setForm(f => ({ ...f, title: e.target.value }))}
            placeholder="Modelový test 2 — Mluvení"
            style={inputStyle}
          />

          <label style={labelStyle}>Description</label>
          <textarea
            value={form.description}
            onChange={e => setForm(f => ({ ...f, description: e.target.value }))}
            placeholder="Full A2 speaking exam: 4 sections, 40 points total."
            rows={2}
            style={{ ...inputStyle, resize: 'vertical' }}
          />

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <div>
              <label style={labelStyle}>Duration (minutes)</label>
              <input
                type="number"
                min={1}
                value={form.estimated_duration_minutes}
                onChange={e => setForm(f => ({ ...f, estimated_duration_minutes: parseInt(e.target.value) || 15 }))}
                style={inputStyle}
              />
            </div>
            <div>
              <label style={labelStyle}>Status</label>
              <select
                value={form.status}
                onChange={e => setForm(f => ({ ...f, status: e.target.value as 'draft' | 'published' }))}
                style={inputStyle}
              >
                <option value="draft">Draft</option>
                <option value="published">Published</option>
              </select>
            </div>
          </div>

          <div style={{ marginTop: 20 }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
              <label style={{ ...labelStyle, margin: 0, fontWeight: 600 }}>
                Sections ({form.sections.length})
              </label>
              <button type="button" onClick={addSection} style={btnStyle('secondary')}>+ Add section</button>
            </div>
            {form.sections.length === 0 && (
              <p style={{ color: '#9ca3af', fontSize: 13, margin: '4px 0 0' }}>No sections yet. Add at least one.</p>
            )}
            {form.sections.map((sec, idx) => (
              <div key={idx} style={{ display: 'grid', gridTemplateColumns: '1fr 120px 36px', gap: 8, marginBottom: 8, alignItems: 'center' }}>
                <select
                  value={sec.exercise_id}
                  onChange={e => updateSection(idx, e.target.value)}
                  style={inputStyle}
                  required
                >
                  <option value="">— Pick exercise —</option>
                  {exercises.map(ex => (
                    <option key={ex.id} value={ex.id}>
                      [{EXERCISE_TYPE_LABEL[ex.exercise_type] ?? ex.exercise_type}] {ex.title}
                    </option>
                  ))}
                </select>
                <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                  <input
                    type="number"
                    min={0}
                    max={40}
                    value={sec.max_points}
                    onChange={e => updateSectionPoints(idx, parseInt(e.target.value) || 0)}
                    style={{ ...inputStyle, margin: 0, width: '100%' }}
                    title="Max points"
                  />
                  <span style={{ fontSize: 12, color: '#6b7280', whiteSpace: 'nowrap' }}>pts</span>
                </div>
                <button type="button" onClick={() => removeSection(idx)} style={{ ...btnStyle('danger'), padding: '6px 8px' }}>✕</button>
              </div>
            ))}
            {form.sections.length > 0 && (
              <p style={{ fontSize: 12, color: '#6b7280', margin: '4px 0 0' }}>
                Total: {form.sections.reduce((s, sec) => s + sec.max_points, 0)} pts
                {' + 3 pts pronunciation = '}
                {form.sections.reduce((s, sec) => s + sec.max_points, 0) + 3} pts max
              </p>
            )}
          </div>

          {error && <p style={{ color: 'red', margin: '12px 0 0' }}>{error}</p>}

          <div style={{ display: 'flex', gap: 8, marginTop: 20 }}>
            <button type="submit" disabled={saving} style={btnStyle('primary')}>
              {saving ? 'Saving…' : editingId ? 'Save changes' : 'Create'}
            </button>
            <button type="button" onClick={cancelForm} style={btnStyle('secondary')}>Cancel</button>
          </div>
        </form>
      )}
    </div>
  );
}

// ── Styles ──────────────────────────────────────────────────────────────────

const cardStyle: React.CSSProperties = {
  border: '1px solid #e5e7eb',
  borderRadius: 8,
  padding: 16,
  marginBottom: 12,
  background: '#fff',
};

const sectionPillStyle: React.CSSProperties = {
  background: '#f3f4f6',
  border: '1px solid #e5e7eb',
  borderRadius: 4,
  padding: '2px 8px',
  fontSize: 12,
  color: '#374151',
};

const labelStyle: React.CSSProperties = {
  display: 'block',
  fontSize: 13,
  fontWeight: 500,
  color: '#374151',
  marginBottom: 4,
  marginTop: 12,
};

const inputStyle: React.CSSProperties = {
  width: '100%',
  padding: '7px 10px',
  border: '1px solid #d1d5db',
  borderRadius: 6,
  fontSize: 14,
  boxSizing: 'border-box',
  margin: 0,
};

function btnStyle(variant: 'primary' | 'secondary' | 'danger'): React.CSSProperties {
  const base: React.CSSProperties = { border: 'none', borderRadius: 6, padding: '8px 14px', fontSize: 13, cursor: 'pointer', fontWeight: 600 };
  if (variant === 'primary') return { ...base, background: '#3b82f6', color: '#fff' };
  if (variant === 'danger')  return { ...base, background: '#ef4444', color: '#fff' };
  return { ...base, background: '#f3f4f6', color: '#374151', border: '1px solid #d1d5db' };
}
