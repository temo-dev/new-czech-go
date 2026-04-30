'use client';

import { FormEvent, useEffect, useRef, useState } from 'react';
import { useS } from '../lib/i18n';

type Exercise = {
  id: string;
  title: string;
  exercise_type: string;
  status?: string;
};

type MockTestSection = {
  sequence_no: number;
  skill_kind: string; // noi | nghe | doc | viet
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
  exam_mode?: string;
  pass_threshold_percent?: number;
  banner_image_id?: string;
  sections: MockTestSection[];
};

const DEFAULT_MAX_POINTS: Record<string, number> = {
  uloha_1_topic_answers: 8,
  uloha_2_dialogue_questions: 12,
  uloha_3_story_narration: 10,
  uloha_4_choice_reasoning: 7,
  psani_1_formular: 8,
  psani_2_email: 12,
  poslech_1: 5, poslech_2: 5, poslech_3: 5, poslech_4: 5, poslech_5: 5,
  cteni_1: 5, cteni_2: 5, cteni_3: 4, cteni_4: 6, cteni_5: 5,
};

const EXERCISE_TYPE_LABEL: Record<string, string> = {
  uloha_1_topic_answers: 'Úloha 1 — Topic answers',
  uloha_2_dialogue_questions: 'Úloha 2 — Dialogue questions',
  uloha_3_story_narration: 'Úloha 3 — Story narration',
  uloha_4_choice_reasoning: 'Úloha 4 — Choice & reasoning',
  psani_1_formular: 'Psaní 1 — Formulář',
  psani_2_email: 'Psaní 2 — E-mail',
  poslech_1: 'Poslech 1', poslech_2: 'Poslech 2', poslech_3: 'Poslech 3',
  poslech_4: 'Poslech 4', poslech_5: 'Poslech 5',
  cteni_1: 'Čtení 1', cteni_2: 'Čtení 2', cteni_3: 'Čtení 3',
  cteni_4: 'Čtení 4', cteni_5: 'Čtení 5',
};

const MOCK_TEST_API = '/api/admin/mock-tests';
const EXERCISES_API = '/api/admin/exercises';

type SkillKind = 'noi' | 'nghe' | 'doc' | 'viet';

const SKILL_GROUPS: { kind: SkillKind; label: string; color: string; prefix: string }[] = [
  { kind: 'noi',  label: 'Nói (Speaking)',   color: '#FF6A14', prefix: 'uloha_' },
  { kind: 'nghe', label: 'Nghe (Listening)', color: '#3060B8', prefix: 'poslech_' },
  { kind: 'doc',  label: 'Đọc (Reading)',    color: '#C28012', prefix: 'cteni_' },
  { kind: 'viet', label: 'Viết (Writing)',   color: '#1F8A4D', prefix: 'psani_' },
];

function resequence(sections: MockTestSection[]): MockTestSection[] {
  let seq = 0;
  return SKILL_GROUPS.flatMap(g =>
    sections.filter(s => s.skill_kind === g.kind).map(s => ({ ...s, sequence_no: ++seq }))
  );
}

type FormState = {
  title: string;
  description: string;
  estimated_duration_minutes: number;
  status: 'draft' | 'published';
  exam_mode: 'real' | 'practice';
  pass_threshold_percent: number;
  sections: MockTestSection[];
};

const emptyForm = (): FormState => ({
  title: '',
  description: '',
  estimated_duration_minutes: 15,
  status: 'draft',
  exam_mode: 'practice',
  pass_threshold_percent: 80,
  sections: [],
});

export function MockTestDashboard() {
  const S = useS();
  const [tests, setTests] = useState<MockTest[]>([]);
  const [exercises, setExercises] = useState<Exercise[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<FormState>(emptyForm());
  const [saving, setSaving] = useState(false);
  const [uploadingBanner, setUploadingBanner] = useState<string | null>(null);
  const bannerInputRefs = useRef<Record<string, HTMLInputElement | null>>({});

  useEffect(() => {
    Promise.all([fetchTests(), fetchExercises()]);
  }, []);

  async function handleBannerUpload(testId: string, file: File) {
    setUploadingBanner(testId);
    try {
      const formData = new FormData();
      formData.set('file', file);
      const res = await fetch(`/api/admin/mock-tests/${testId}/banner`, { method: 'POST', body: formData });
      if (res.ok) await fetchTests();
    } finally {
      setUploadingBanner(null);
    }
  }

  async function handleBannerDelete(testId: string) {
    await fetch(`/api/admin/mock-tests/${testId}/banner`, { method: 'DELETE' });
    await fetchTests();
  }

  async function fetchTests() {
    setLoading(true);
    try {
      const res = await fetch(MOCK_TEST_API);
      const json = await res.json();
      if (!res.ok) throw new Error(json.error?.message ?? 'Failed to load mock tests.');
      setTests(json.data ?? []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load mock tests.');
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
      exam_mode: (t.exam_mode === 'real' ? 'real' : 'practice'),
      pass_threshold_percent: t.pass_threshold_percent ?? 80,
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
        exam_mode: form.exam_mode,
        pass_threshold_percent: form.pass_threshold_percent,
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
    if (!confirm('Delete this mock test? This cannot be undone.')) return;
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

  function addExerciseToGroup(kind: SkillKind) {
    setForm(f => {
      const newSec: MockTestSection = { sequence_no: 0, skill_kind: kind, exercise_id: '', exercise_type: '', max_points: 0 };
      return { ...f, sections: resequence([...f.sections, newSec]) };
    });
  }

  function removeExerciseFromGroup(kind: SkillKind, localIdx: number) {
    setForm(f => {
      const kindSections = f.sections.filter(s => s.skill_kind === kind);
      const toRemove = kindSections[localIdx];
      const remaining = f.sections.filter(s => s !== toRemove);
      return { ...f, sections: resequence(remaining) };
    });
  }

  function updateExerciseInGroup(kind: SkillKind, localIdx: number, exerciseId: string) {
    const ex = exercises.find(e => e.id === exerciseId);
    const exType = ex?.exercise_type ?? '';
    const maxPts = DEFAULT_MAX_POINTS[exType] ?? 0;
    setForm(f => {
      const kindSections = f.sections.filter(s => s.skill_kind === kind);
      const target = kindSections[localIdx];
      const updated = f.sections.map(s =>
        s === target ? { ...s, exercise_id: exerciseId, exercise_type: exType, max_points: maxPts } : s
      );
      return { ...f, sections: resequence(updated) };
    });
  }

  function updateGroupExercisePoints(kind: SkillKind, localIdx: number, pts: number) {
    setForm(f => {
      const kindSections = f.sections.filter(s => s.skill_kind === kind);
      const target = kindSections[localIdx];
      const updated = f.sections.map(s => s === target ? { ...s, max_points: pts } : s);
      return { ...f, sections: updated };
    });
  }

  const statusBadge = (status: string) => {
    const colors: Record<string, string> = { published: '#16a34a', draft: '#6b7280' };
    return (
      <span style={{ background: colors[status] ?? '#6b7280', color: '#fff', borderRadius: 4, padding: '2px 8px', fontSize: 12, fontWeight: 600 }}>
        {status.toUpperCase()}
      </span>
    );
  };

  const examModeBadge = (mode?: string) => {
    const isReal = mode === 'real';
    return (
      <span style={{ background: isReal ? '#7c3aed' : '#0891b2', color: '#fff', borderRadius: 4, padding: '2px 8px', fontSize: 12, fontWeight: 600 }}>
        {isReal ? 'Thi thật' : 'Luyện thi'}
      </span>
    );
  };

  if (loading) return <p style={{ padding: 24 }}>Loading…</p>;

  return (
    <div style={{ maxWidth: 900, margin: '0 auto', padding: '24px 16px', fontFamily: 'sans-serif' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 24 }}>
        <h1 style={{ margin: 0, fontSize: 22, fontWeight: 700 }}>Mock Tests</h1>
        <button onClick={openCreate} style={btnStyle('primary')}>{S.mockTest.newCta}</button>
      </div>

      {error && <p style={{ color: 'red', marginBottom: 16 }}>{error}</p>}

      {!showForm && (
        <>
          {tests.length === 0 && <p style={{ color: '#6b7280' }}>No mock tests yet.</p>}
          {tests.map(t => (
            <div key={t.id} style={cardStyle}>
              {/* Banner image strip */}
              {t.banner_image_id && (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={`/api/media/file?key=${encodeURIComponent(t.banner_image_id)}`}
                  alt="banner"
                  style={{ width: 'calc(100% + 32px)', height: 80, objectFit: 'cover', borderRadius: '8px 8px 0 0', display: 'block', marginTop: -16, marginLeft: -16, marginRight: -16, marginBottom: 12 }}
                />
              )}
              <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 16 }}>
                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
                    {statusBadge(t.status)}
                    {examModeBadge(t.exam_mode)}
                    <strong>{t.title}</strong>
                  </div>
                  <p style={{ margin: '4px 0', color: '#6b7280', fontSize: 14 }}>{t.description}</p>
                  <p style={{ margin: '4px 0', fontSize: 13, color: '#9ca3af' }}>
                    {t.estimated_duration_minutes} min · {t.sections?.length ?? 0} sections ·{' '}
                    {t.sections?.reduce((s, sec) => s + sec.max_points, 0) ?? 0} pts ·{' '}
                    <span style={{ color: '#3b82f6', fontWeight: 600 }}>
                      pass ≥{t.pass_threshold_percent ?? 60}%
                    </span>
                  </p>
                </div>
                <div style={{ display: 'flex', gap: 8, flexShrink: 0, alignItems: 'flex-start' }}>
                  <label style={{ display: 'flex', alignItems: 'center', gap: 4, padding: '5px 10px', borderRadius: 6, border: `1px ${t.banner_image_id ? 'solid #22c55e' : 'dashed #d1d5db'}`, cursor: 'pointer', fontSize: 12, fontWeight: 600, color: t.banner_image_id ? '#15803d' : '#6b7280', background: t.banner_image_id ? '#f0fdf4' : 'transparent', whiteSpace: 'nowrap' }}>
                    {uploadingBanner === t.id ? '⏳' : t.banner_image_id ? '🖼 ✓' : '🖼'}
                    <input ref={el => { bannerInputRefs.current[t.id] = el; }} type="file" accept="image/jpeg,image/png,image/webp" style={{ display: 'none' }} disabled={uploadingBanner !== null} onChange={e => { const f = e.target.files?.[0]; if (f) void handleBannerUpload(t.id, f); e.target.value = ''; }} />
                  </label>
                  <button onClick={() => openEdit(t)} style={btnStyle('secondary')}>{S.action.edit}</button>
                  <button onClick={() => handleDelete(t.id)} style={btnStyle('danger')}>{S.action.delete}</button>
                </div>
              </div>
              {t.sections && t.sections.length > 0 && (
                <div style={{ marginTop: 10, display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                  {SKILL_GROUPS.map(g => {
                    const gs = t.sections.filter(s => s.skill_kind === g.kind);
                    if (gs.length === 0) return null;
                    return (
                      <span key={g.kind} style={{ ...sectionPillStyle, borderColor: g.color + '80', color: g.color, fontWeight: 600 }}>
                        {g.label.split(' ')[0]}: {gs.length} bài · {gs.reduce((sum, s) => sum + s.max_points, 0)}pts
                      </span>
                    );
                  })}
                </div>
              )}
            </div>
          ))}
        </>
      )}

      {showForm && (
        <form onSubmit={handleSubmit} style={{ ...cardStyle, borderColor: '#3b82f6' }}>
          <h2 style={{ margin: '0 0 16px', fontSize: 18 }}>
            {editingId ? S.mockTest.editTitle : S.mockTest.createTitle}
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

          <label style={labelStyle}>Chế độ thi</label>
          <div style={{ display: 'flex', gap: 20, marginBottom: 4 }}>
            {(['practice', 'real'] as const).map(mode => (
              <label key={mode} style={{ display: 'flex', alignItems: 'center', gap: 6, cursor: 'pointer', fontSize: 14 }}>
                <input
                  type="radio"
                  name="exam_mode"
                  value={mode}
                  checked={form.exam_mode === mode}
                  onChange={() => setForm(f => ({ ...f, exam_mode: mode }))}
                />
                {mode === 'real' ? 'Thi thật' : 'Luyện thi'}
              </label>
            ))}
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 12 }}>
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
              <label style={labelStyle}>Ngưỡng pass (%)</label>
              <input
                type="number"
                min={1}
                max={100}
                value={form.pass_threshold_percent}
                onChange={e => setForm(f => ({ ...f, pass_threshold_percent: parseInt(e.target.value) || 80 }))}
                style={inputStyle}
                title="Pass threshold percent (default 80 for sprint, 60 for full A2 exam)"
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
          <p style={{ fontSize: 12, color: '#6b7280', margin: '4px 0' }}>
            Sprint luyện tập: 80%. Đề thi chuẩn A2 (full speaking): 60%.
          </p>

          <div style={{ marginTop: 20 }}>
            <label style={{ ...labelStyle, fontWeight: 600, marginBottom: 12 }}>
              Các phần thi ({form.sections.length} bài tập)
            </label>

            {SKILL_GROUPS.map(group => {
              const groupSections = form.sections.filter(s => s.skill_kind === group.kind);
              const groupExercises = exercises.filter(ex => ex.exercise_type.startsWith(group.prefix));
              return (
                <div key={group.kind} style={{ marginBottom: 12, border: '1px solid #e5e7eb', borderRadius: 8, overflow: 'hidden' }}>
                  {/* Group header */}
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '8px 12px', background: group.color + '18', borderBottom: groupSections.length > 0 ? '1px solid #e5e7eb' : 'none' }}>
                    <span style={{ fontWeight: 600, fontSize: 13, color: group.color }}>
                      {group.label}
                      {groupSections.length > 0 && (
                        <span style={{ color: '#6b7280', fontWeight: 400, marginLeft: 8 }}>
                          ({groupSections.length} bài · {groupSections.reduce((s, x) => s + x.max_points, 0)} pts)
                        </span>
                      )}
                    </span>
                    <button type="button" onClick={() => addExerciseToGroup(group.kind as SkillKind)} style={{ ...btnStyle('secondary'), padding: '4px 10px', fontSize: 12 }}>
                      + Thêm bài
                    </button>
                  </div>

                  {/* Exercise rows */}
                  {groupSections.length === 0 && (
                    <p style={{ margin: 0, padding: '8px 12px', fontSize: 12, color: '#9ca3af' }}>Chưa có bài tập nào.</p>
                  )}
                  {groupSections.map((sec, localIdx) => (
                    <div key={localIdx} style={{ display: 'grid', gridTemplateColumns: '1fr 100px 36px', gap: 8, padding: '8px 12px', borderTop: localIdx > 0 ? '1px solid #f3f4f6' : undefined, alignItems: 'center' }}>
                      <select
                        value={sec.exercise_id}
                        onChange={e => updateExerciseInGroup(group.kind as SkillKind, localIdx, e.target.value)}
                        style={{ ...inputStyle, margin: 0 }}
                        required
                      >
                        <option value="">— Chọn bài tập —</option>
                        {groupExercises.map(ex => (
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
                          onChange={e => updateGroupExercisePoints(group.kind as SkillKind, localIdx, parseInt(e.target.value) || 0)}
                          style={{ ...inputStyle, margin: 0 }}
                          title="Max points"
                        />
                        <span style={{ fontSize: 12, color: '#6b7280', whiteSpace: 'nowrap' }}>pts</span>
                      </div>
                      <button type="button" onClick={() => removeExerciseFromGroup(group.kind as SkillKind, localIdx)} style={{ ...btnStyle('danger'), padding: '6px 8px' }}>✕</button>
                    </div>
                  ))}
                </div>
              );
            })}

            {form.sections.length > 0 && (
              <p style={{ fontSize: 12, color: '#6b7280', margin: '4px 0 0' }}>
                Tổng: {form.sections.reduce((s, sec) => s + sec.max_points, 0)} pts + 3 pts phát âm ={' '}
                <strong>{form.sections.reduce((s, sec) => s + sec.max_points, 0) + 3} pts</strong>
              </p>
            )}
          </div>

          {/* Banner upload — only for saved tests */}
          {editingId && (() => {
            const test = tests.find(t => t.id === editingId);
            const hasBanner = !!test?.banner_image_id;
            return (
              <div style={{ marginTop: 16 }}>
                <p style={{ margin: '0 0 8px', fontSize: 12, fontWeight: 600, color: '#374151', textTransform: 'uppercase', letterSpacing: 0.4 }}>Ảnh banner</p>
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  {hasBanner && test?.banner_image_id && (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={`/api/media/file?key=${encodeURIComponent(test.banner_image_id)}`} alt="banner" style={{ width: 80, height: 52, objectFit: 'cover', borderRadius: 6, border: '1px solid #e5e7eb' }} />
                  )}
                  <label style={{ display: 'flex', alignItems: 'center', gap: 6, border: `1px ${hasBanner ? 'solid #22c55e' : 'dashed #d1d5db'}`, borderRadius: 6, padding: '6px 12px', cursor: 'pointer', fontSize: 12, fontWeight: 600, color: hasBanner ? '#15803d' : '#6b7280', background: hasBanner ? '#f0fdf4' : 'transparent' }}>
                    {uploadingBanner === editingId ? '⏳ Đang tải...' : hasBanner ? '🔄 Đổi banner' : '🖼 Tải banner'}
                    <input type="file" accept="image/jpeg,image/png,image/webp" style={{ display: 'none' }} disabled={uploadingBanner !== null} onChange={e => { const f = e.target.files?.[0]; if (f && editingId) void handleBannerUpload(editingId, f); e.target.value = ''; }} />
                  </label>
                  {hasBanner && editingId && (
                    <button type="button" onClick={() => void handleBannerDelete(editingId)} style={{ ...btnStyle('danger'), fontSize: 12, padding: '6px 10px' }}>Xóa</button>
                  )}
                </div>
              </div>
            );
          })()}
          {!editingId && <p style={{ margin: '16px 0 0', fontSize: 12, color: '#9ca3af' }}>Tạo đề thi trước, sau đó upload banner.</p>}

          {error && <p style={{ color: 'red', margin: '12px 0 0' }}>{error}</p>}

          <div style={{ display: 'flex', gap: 8, marginTop: 20 }}>
            <button type="submit" disabled={saving} style={btnStyle('primary')}>
              {saving ? S.action.saving : editingId ? S.mockTest.updateCta : S.mockTest.createCta}
            </button>
            <button type="button" onClick={cancelForm} style={btnStyle('secondary')}>{S.action.cancel}</button>
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
