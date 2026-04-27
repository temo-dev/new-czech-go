'use client';
import { FormEvent, useEffect, useState } from 'react';

type Module = { id: string; title: string; course_id: string };
type Skill = { id: string; module_id: string; skill_kind: string; title: string; sequence_no: number; status: string };
const SKILLS_API = '/api/admin/skills';
const MODULES_API = '/api/admin/modules';

const SKILL_KINDS = [
  { value: 'noi', label: 'Nói (Speaking)' },
  { value: 'nghe', label: 'Nghe (Listening)' },
  { value: 'doc', label: 'Đọc (Reading)' },
  { value: 'viet', label: 'Viết (Writing)' },
  { value: 'tu_vung', label: 'Từ vựng (Vocabulary)' },
  { value: 'ngu_phap', label: 'Ngữ pháp (Grammar)' },
];

const card: React.CSSProperties = { border: '1px solid #e5e7eb', borderRadius: 8, padding: 16, marginBottom: 12, background: '#fff' };
const label: React.CSSProperties = { display: 'block', fontSize: 13, fontWeight: 500, color: '#374151', marginBottom: 4, marginTop: 12 };
const input: React.CSSProperties = { width: '100%', padding: '7px 10px', border: '1px solid #d1d5db', borderRadius: 6, fontSize: 14, boxSizing: 'border-box' };
function btn(v: 'primary' | 'secondary' | 'danger'): React.CSSProperties {
  const base: React.CSSProperties = { border: 'none', borderRadius: 6, padding: '8px 14px', fontSize: 13, cursor: 'pointer', fontWeight: 600 };
  if (v === 'primary') return { ...base, background: '#3b82f6', color: '#fff' };
  if (v === 'danger') return { ...base, background: '#ef4444', color: '#fff' };
  return { ...base, background: '#f3f4f6', color: '#374151', border: '1px solid #d1d5db' };
}

export function SkillDashboard() {
  const [skills, setSkills] = useState<Skill[]>([]);
  const [modules, setModules] = useState<Module[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [filterModule, setFilterModule] = useState('');
  const [form, setForm] = useState({ module_id: '', skill_kind: 'noi', title: 'Kỹ năng nói', sequence_no: 1, status: 'draft' });

  useEffect(() => { loadModules(); }, []);

  async function loadSkills(moduleId: string) {
    if (!moduleId) { setSkills([]); setLoading(false); return; }
    setLoading(true);
    try { const res = await fetch(`${SKILLS_API}?module_id=${moduleId}`); const j = await res.json(); setSkills(j.data ?? []); }
    catch { setError('Failed.'); }
    finally { setLoading(false); }
  }
  async function loadModules() {
    try { const res = await fetch(MODULES_API); const j = await res.json(); setModules(j.data ?? []); setLoading(false); }
    catch { setLoading(false); }
  }

  function onModuleFilter(id: string) { setFilterModule(id); loadSkills(id); }
  function kindLabel(kind: string) { return SKILL_KINDS.find(k => k.value === kind)?.label ?? kind; }
  function onKindChange(kind: string) {
    const labels: Record<string, string> = { noi: 'Kỹ năng nói', nghe: 'Kỹ năng nghe', doc: 'Kỹ năng đọc', viet: 'Kỹ năng viết', tu_vung: 'Từ vựng', ngu_phap: 'Ngữ pháp' };
    setForm(f => ({ ...f, skill_kind: kind, title: labels[kind] ?? '' }));
  }

  function openCreate() { setEditingId(null); setForm({ module_id: filterModule, skill_kind: 'noi', title: 'Kỹ năng nói', sequence_no: skills.length + 1, status: 'draft' }); setShowForm(true); }
  function openEdit(sk: Skill) { setEditingId(sk.id); setForm({ module_id: sk.module_id, skill_kind: sk.skill_kind, title: sk.title, sequence_no: sk.sequence_no, status: sk.status }); setShowForm(true); }
  function cancel() { setShowForm(false); setEditingId(null); setError(''); }

  async function submit(e: FormEvent) {
    e.preventDefault(); setSaving(true); setError('');
    try {
      const url = editingId ? `${SKILLS_API}/${editingId}` : SKILLS_API;
      const method = editingId ? 'PATCH' : 'POST';
      const res = await fetch(url, { method, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(form) });
      if (!res.ok) throw new Error((await res.json()).error?.message ?? 'Save failed');
      await loadSkills(filterModule); cancel();
    } catch (err) { setError(err instanceof Error ? err.message : 'Unknown error'); }
    finally { setSaving(false); }
  }

  async function del(id: string) {
    if (!confirm('Delete this skill?')) return;
    try { await fetch(`${SKILLS_API}/${id}`, { method: 'DELETE' }); await loadSkills(filterModule); }
    catch { setError('Delete failed'); }
  }

  return (
    <div style={{ maxWidth: 900, margin: '0 auto', padding: '24px 16px', fontFamily: 'sans-serif' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
        <h1 style={{ margin: 0, fontSize: 22 }}>Skills</h1>
        <button onClick={openCreate} disabled={!filterModule} style={btn('primary')}>+ New skill</button>
      </div>
      <div style={{ marginBottom: 16 }}>
        <label style={{ ...label, marginTop: 0 }}>Filter by module:</label>
        <select value={filterModule} onChange={e => onModuleFilter(e.target.value)} style={{ ...input, width: 400 }}>
          <option value="">— Pick a module to see its skills —</option>
          {modules.map(m => <option key={m.id} value={m.id}>{m.title}</option>)}
        </select>
      </div>
      {error && <p style={{ color: 'red' }}>{error}</p>}
      {!filterModule && <p style={{ color: '#9ca3af' }}>Select a module above to manage its skills.</p>}
      {filterModule && !loading && skills.length === 0 && <p style={{ color: '#9ca3af' }}>No skills for this module yet.</p>}
      {!showForm && skills.map(sk => (
        <div key={sk.id} style={card}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <span style={{ fontSize: 11, fontWeight: 700, background: sk.status === 'published' ? '#16a34a' : '#6b7280', color: '#fff', borderRadius: 4, padding: '2px 8px', marginRight: 8 }}>{sk.status?.toUpperCase()}</span>
              <strong>{sk.title}</strong>
              <span style={{ marginLeft: 8, fontSize: 12, color: '#6b7280' }}>{kindLabel(sk.skill_kind)} · #{sk.sequence_no}</span>
            </div>
            <div style={{ display: 'flex', gap: 8 }}>
              <button onClick={() => openEdit(sk)} style={btn('secondary')}>Edit</button>
              <button onClick={() => del(sk.id)} style={btn('danger')}>Delete</button>
            </div>
          </div>
        </div>
      ))}
      {showForm && (
        <form onSubmit={submit} style={{ ...card, borderColor: '#3b82f6' }}>
          <h2 style={{ margin: '0 0 12px', fontSize: 18 }}>{editingId ? 'Edit skill' : 'New skill'}</h2>
          <label style={label}>Skill kind *</label>
          <select required value={form.skill_kind} onChange={e => onKindChange(e.target.value)} style={input}>
            {SKILL_KINDS.map(k => <option key={k.value} value={k.value}>{k.label}</option>)}
          </select>
          <label style={label}>Title</label>
          <input value={form.title} onChange={e => setForm(f => ({ ...f, title: e.target.value }))} style={input} />
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <div><label style={label}>Seq No</label><input type="number" min={1} value={form.sequence_no} onChange={e => setForm(f => ({ ...f, sequence_no: parseInt(e.target.value) || 1 }))} style={input} /></div>
            <div><label style={label}>Status</label>
              <select value={form.status} onChange={e => setForm(f => ({ ...f, status: e.target.value }))} style={input}>
                <option value="draft">draft</option><option value="published">published</option>
              </select></div>
          </div>
          {error && <p style={{ color: 'red', marginTop: 8 }}>{error}</p>}
          <div style={{ display: 'flex', gap: 8, marginTop: 16 }}>
            <button type="submit" disabled={saving} style={btn('primary')}>{saving ? 'Saving…' : editingId ? 'Save' : 'Create'}</button>
            <button type="button" onClick={cancel} style={btn('secondary')}>Cancel</button>
          </div>
        </form>
      )}
    </div>
  );
}
