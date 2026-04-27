'use client';
import { FormEvent, useEffect, useState } from 'react';
import { S } from '../lib/strings';

type Course = { id: string; title: string };
type Module = { id: string; course_id: string; slug: string; title: string; description: string; module_kind: string; sequence_no: number; status: string };
const API = '/api/admin/modules';
const COURSES_API = '/api/admin/courses';

const card: React.CSSProperties = { border: '1px solid #e5e7eb', borderRadius: 8, padding: 16, marginBottom: 12, background: '#fff' };
const label: React.CSSProperties = { display: 'block', fontSize: 13, fontWeight: 500, color: '#374151', marginBottom: 4, marginTop: 12 };
const input: React.CSSProperties = { width: '100%', padding: '7px 10px', border: '1px solid #d1d5db', borderRadius: 6, fontSize: 14, boxSizing: 'border-box' };
function btn(v: 'primary' | 'secondary' | 'danger'): React.CSSProperties {
  const base: React.CSSProperties = { border: 'none', borderRadius: 6, padding: '8px 14px', fontSize: 13, cursor: 'pointer', fontWeight: 600 };
  if (v === 'primary') return { ...base, background: '#3b82f6', color: '#fff' };
  if (v === 'danger') return { ...base, background: '#ef4444', color: '#fff' };
  return { ...base, background: '#f3f4f6', color: '#374151', border: '1px solid #d1d5db' };
}

export function ModuleDashboard() {
  const [modules, setModules] = useState<Module[]>([]);
  const [courses, setCourses] = useState<Course[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [filterCourse, setFilterCourse] = useState('');
  const [form, setForm] = useState({ title: '', description: '', course_id: '', module_kind: 'daily_plan', sequence_no: 1, status: 'draft' });

  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => { Promise.all([load(), loadCourses()]); }, []);

  async function load() {
    setLoading(true);
    try {
      const qs = filterCourse ? `?course_id=${filterCourse}` : '';
      const res = await fetch(API + qs); const j = await res.json(); setModules(j.data ?? []);
    } catch { setError('Failed.'); }
    finally { setLoading(false); }
  }
  async function loadCourses() {
    try { const res = await fetch(COURSES_API); const j = await res.json(); setCourses(j.data ?? []); }
    catch { /* non-fatal */ }
  }

  function openCreate() { setEditingId(null); setForm({ title: '', description: '', course_id: courses[0]?.id ?? '', module_kind: 'daily_plan', sequence_no: modules.length + 1, status: 'draft' }); setShowForm(true); }
  function openEdit(m: Module) { setEditingId(m.id); setForm({ title: m.title, description: m.description, course_id: m.course_id, module_kind: m.module_kind, sequence_no: m.sequence_no, status: m.status }); setShowForm(true); }
  function cancel() { setShowForm(false); setEditingId(null); setError(''); }

  async function submit(e: FormEvent) {
    e.preventDefault(); setSaving(true); setError('');
    try {
      const url = editingId ? `${API}/${editingId}` : API;
      const method = editingId ? 'PATCH' : 'POST';
      const res = await fetch(url, { method, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(form) });
      if (!res.ok) throw new Error((await res.json()).error?.message ?? 'Save failed');
      await load(); cancel();
    } catch (err) { setError(err instanceof Error ? err.message : 'Unknown error'); }
    finally { setSaving(false); }
  }

  async function del(id: string) {
    if (!confirm('Delete this module?')) return;
    try { await fetch(`${API}/${id}`, { method: 'DELETE' }); await load(); }
    catch { setError('Delete failed'); }
  }

  const courseTitle = (id: string) => courses.find(c => c.id === id)?.title ?? id;
  if (loading) return <p style={{ padding: 24 }}>Loading…</p>;

  return (
    <div style={{ maxWidth: 900, margin: '0 auto', padding: '24px 16px', fontFamily: 'sans-serif' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
        <h1 style={{ margin: 0, fontSize: 22 }}>Modules</h1>
        <button onClick={openCreate} style={btn('primary')}>{S.module.newCta}</button>
      </div>
      <div style={{ marginBottom: 16 }}>
        <label style={{ ...label, marginTop: 0 }}>{S.module.filterLabel}</label>
        <select value={filterCourse} onChange={e => { setFilterCourse(e.target.value); }} style={{ ...input, width: 300 }}>
          <option value="">{S.pick.allCourses}</option>
          {courses.map(c => <option key={c.id} value={c.id}>{c.title}</option>)}
        </select>
        <button onClick={load} style={{ ...btn('secondary'), marginLeft: 8 }}>{S.module.filterCta}</button>
      </div>
      {error && <p style={{ color: 'red' }}>{error}</p>}
      {!showForm && modules.map(m => (
        <div key={m.id} style={card}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div>
              <span style={{ fontSize: 11, fontWeight: 700, background: m.status === 'published' ? '#16a34a' : '#6b7280', color: '#fff', borderRadius: 4, padding: '2px 8px', marginRight: 8 }}>{m.status?.toUpperCase()}</span>
              <strong>#{m.sequence_no} {m.title}</strong>
              <span style={{ marginLeft: 8, fontSize: 11, color: '#9ca3af' }}>{m.module_kind}</span>
              <p style={{ margin: '4px 0 0', fontSize: 12, color: '#6b7280' }}>Course: {courseTitle(m.course_id)} · {m.description}</p>
            </div>
            <div style={{ display: 'flex', gap: 8 }}>
              <button onClick={() => openEdit(m)} style={btn('secondary')}>{S.action.edit}</button>
              <button onClick={() => del(m.id)} style={btn('danger')}>{S.action.delete}</button>
            </div>
          </div>
        </div>
      ))}
      {showForm && (
        <form onSubmit={submit} style={{ ...card, borderColor: '#3b82f6' }}>
          <h2 style={{ margin: '0 0 12px', fontSize: 18 }}>{editingId ? S.module.editTitle : S.module.createTitle}</h2>
          <label style={label}>Course *</label>
          <select required value={form.course_id} onChange={e => setForm(f => ({ ...f, course_id: e.target.value }))} style={input}>
            <option value="">{S.pick.course}</option>
            {courses.map(c => <option key={c.id} value={c.id}>{c.title}</option>)}
          </select>
          <label style={label}>Title *</label>
          <input required value={form.title} onChange={e => setForm(f => ({ ...f, title: e.target.value }))} style={input} />
          <label style={label}>Description</label>
          <textarea value={form.description} onChange={e => setForm(f => ({ ...f, description: e.target.value }))} rows={2} style={{ ...input, resize: 'vertical' }} />
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 12 }}>
            <div><label style={label}>Kind</label>
              <select value={form.module_kind} onChange={e => setForm(f => ({ ...f, module_kind: e.target.value }))} style={input}>
                <option value="daily_plan">daily_plan</option><option value="practice">practice</option>
              </select></div>
            <div><label style={label}>Seq No</label><input type="number" min={1} value={form.sequence_no} onChange={e => setForm(f => ({ ...f, sequence_no: parseInt(e.target.value) || 1 }))} style={input} /></div>
            <div><label style={label}>Status</label>
              <select value={form.status} onChange={e => setForm(f => ({ ...f, status: e.target.value }))} style={input}>
                <option value="draft">draft</option><option value="published">published</option>
              </select></div>
          </div>
          {error && <p style={{ color: 'red', marginTop: 8 }}>{error}</p>}
          <div style={{ display: 'flex', gap: 8, marginTop: 16 }}>
            <button type="submit" disabled={saving} style={btn('primary')}>{saving ? S.action.saving : editingId ? S.action.saveChanges : S.action.create}</button>
            <button type="button" onClick={cancel} style={btn('secondary')}>{S.action.cancel}</button>
          </div>
        </form>
      )}
    </div>
  );
}
