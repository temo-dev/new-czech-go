'use client';

import { useEffect, useState } from 'react';
import { adminFetch } from '../../lib/api';

type GrammarRule = {
  id: string; module_id: string; title: string; level: string;
  explanation_vi: string; rule_table: Record<string, string>;
  constraints_text: string; status: string; image_asset_id?: string;
};
type Course = { id: string; title: string };
type Module = { id: string; title: string; course_id: string };
type GeneratedExercise = {
  exercise_type: string;
  prompt?: string; options?: string[]; correct_answer?: string;
  pairs?: Array<{ left: string; right: string }>;
  explanation: string;
};

const EXERCISE_TYPES_GRAMMAR = [
  { value: 'fill_blank',  label: 'Điền từ',  hint: 'Câu có ___' },
  { value: 'choice_word', label: 'Chọn từ',  hint: '4 lựa chọn A-D' },
  { value: 'matching',    label: 'Ghép đôi', hint: 'Ghép form → nghĩa' },
];
const LEVELS = ['A1', 'A2', 'B1'];
const TERMINAL = ['generated', 'failed', 'rejected', 'published'];

const inputStyle: React.CSSProperties = {
  padding: '7px 10px', borderRadius: 8, border: '1px solid var(--border)',
  background: 'var(--surface-alt)', fontSize: 13, resize: 'vertical' as const,
};

// ── Inline editors ────────────────────────────────────────────────────────────

function FillBlankEditor({ ex, onChange }: { ex: GeneratedExercise; onChange: (e: GeneratedExercise) => void }) {
  const hasBlank = (ex.prompt ?? '').includes('___');
  return (
    <div style={{ display: 'grid', gap: 8 }}>
      <label style={{ display: 'grid', gap: 4, fontSize: 13 }}>
        Câu (phải chứa ___)
        <textarea rows={2} value={ex.prompt ?? ''} onChange={e => onChange({ ...ex, prompt: e.target.value })}
          style={{ ...inputStyle, borderColor: !hasBlank ? '#c03a28' : undefined }} />
        {!hasBlank && <span style={{ fontSize: 11, color: '#c03a28' }}>⚠ Thiếu ___</span>}
      </label>
      <label style={{ display: 'grid', gap: 4, fontSize: 13 }}>
        Đáp án đúng
        <input value={ex.correct_answer ?? ''} onChange={e => onChange({ ...ex, correct_answer: e.target.value })} style={inputStyle} />
      </label>
      <label style={{ display: 'grid', gap: 4, fontSize: 13 }}>
        Giải thích
        <textarea rows={2} value={ex.explanation ?? ''} onChange={e => onChange({ ...ex, explanation: e.target.value })} style={inputStyle} />
      </label>
    </div>
  );
}

function ChoiceWordEditor({ ex, onChange }: { ex: GeneratedExercise; onChange: (e: GeneratedExercise) => void }) {
  const opts = ex.options ?? ['', '', '', ''];
  return (
    <div style={{ display: 'grid', gap: 8 }}>
      <label style={{ display: 'grid', gap: 4, fontSize: 13 }}>
        Câu hỏi
        <textarea rows={2} value={ex.prompt ?? ''} onChange={e => onChange({ ...ex, prompt: e.target.value })} style={inputStyle} />
      </label>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 6 }}>
        {(['A', 'B', 'C', 'D'] as const).map((key, i) => (
          <label key={key} style={{ display: 'grid', gap: 4, fontSize: 13 }}>
            Lựa chọn {key}
            <input value={opts[i] ?? ''} onChange={e => {
              const next = [...opts]; next[i] = e.target.value;
              onChange({ ...ex, options: next });
            }} style={inputStyle} />
          </label>
        ))}
      </div>
      <label style={{ display: 'grid', gap: 4, fontSize: 13 }}>
        Đáp án đúng
        <select value={ex.correct_answer ?? ''} onChange={e => onChange({ ...ex, correct_answer: e.target.value })} style={inputStyle}>
          <option value="">— chọn —</option>
          {opts.filter(Boolean).map(o => <option key={o} value={o}>{o}</option>)}
        </select>
      </label>
      <label style={{ display: 'grid', gap: 4, fontSize: 13 }}>
        Giải thích
        <textarea rows={2} value={ex.explanation ?? ''} onChange={e => onChange({ ...ex, explanation: e.target.value })} style={inputStyle} />
      </label>
    </div>
  );
}

function MatchingEditor({ ex, onChange }: { ex: GeneratedExercise; onChange: (e: GeneratedExercise) => void }) {
  const pairs = ex.pairs ?? [];
  const setPairs = (next: Array<{ left: string; right: string }>) => onChange({ ...ex, pairs: next });
  return (
    <div style={{ display: 'grid', gap: 8 }}>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 32px', gap: 6, fontSize: 12, color: 'var(--ink-3)', fontWeight: 700 }}>
        <span>Czech (left)</span><span>Nghĩa (right)</span><span />
      </div>
      {pairs.map((p, i) => (
        <div key={i} style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 32px', gap: 6 }}>
          <input value={p.left} onChange={e => { const n = [...pairs]; n[i] = { ...p, left: e.target.value }; setPairs(n); }} style={inputStyle} placeholder="Czech" />
          <input value={p.right} onChange={e => { const n = [...pairs]; n[i] = { ...p, right: e.target.value }; setPairs(n); }} style={inputStyle} placeholder="Nghĩa" />
          <button type="button" onClick={() => setPairs(pairs.filter((_, j) => j !== i))} style={{ border: 'none', background: 'none', cursor: 'pointer', color: '#c03a28', fontSize: 18 }}>×</button>
        </div>
      ))}
      <button type="button" onClick={() => setPairs([...pairs, { left: '', right: '' }])}
        style={{ alignSelf: 'start', padding: '4px 10px', borderRadius: 8, border: '1px dashed var(--border)', background: 'transparent', cursor: 'pointer', fontSize: 12 }}>
        + Thêm cặp
      </button>
      <label style={{ display: 'grid', gap: 4, fontSize: 13 }}>
        Giải thích
        <textarea rows={2} value={ex.explanation ?? ''} onChange={e => onChange({ ...ex, explanation: e.target.value })} style={inputStyle} />
      </label>
    </div>
  );
}

// ── Main page ─────────────────────────────────────────────────────────────────

export default function GrammarPage() {
  const [rules, setRules]     = useState<GrammarRule[]>([]);
  const [courses, setCourses] = useState<Course[]>([]);
  const [modules, setModules] = useState<Module[]>([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal]   = useState(false);
  const [editingRule, setEditingRule] = useState<GrammarRule | null>(null);
  const [deletingId, setDeletingId] = useState<string | null>(null);

  // Form fields
  const [fTitle, setFTitle]   = useState('');
  const [fCourse, setFCourse] = useState('');
  const [fModule, setFModule] = useState('');
  const [fLevel, setFLevel]   = useState('A2');
  const [fExpl, setFExpl]     = useState('');
  const [fForms, setFForms]   = useState<Array<{ pronoun: string; form: string }>>([{ pronoun: '', form: '' }]);
  const [fConstr, setFConstr] = useState('');
  const [saving, setSaving]   = useState(false);
  const [formErr, setFormErr] = useState('');

  // Generation
  const [genPhase, setGenPhase]     = useState<'scope' | 'polling' | 'review' | null>(null);
  const [genRuleId, setGenRuleId]   = useState('');
  const [genModuleId, setGenModuleId] = useState('');
  const [genTypes, setGenTypes]     = useState<Record<string, boolean>>({ fill_blank: true, choice_word: true });
  const [genCount, setGenCount]     = useState<Record<string, number>>({ fill_blank: 8, choice_word: 8, matching: 4 });
  const [jobId, setJobId]           = useState('');
  const [jobStatus, setJobStatus]   = useState('');
  const [jobError, setJobError]     = useState('');
  const [exercises, setExercises]   = useState<GeneratedExercise[]>([]);
  const [publishing, setPublishing] = useState(false);
  const [publishOk, setPublishOk]   = useState(false);
  const [publishErr, setPublishErr] = useState('');
  const [savingDraft, setSavingDraft] = useState(false);
  const [draftSaved, setDraftSaved]   = useState(false);

  // Draft resume
  const [resumableJobs, setResumableJobs] = useState<Record<string, string>>({});
  const LS_KEY = 'grammar-draft-jobs';

  function saveDraftJob(ruleId: string, jid: string) {
    const map = JSON.parse(localStorage.getItem(LS_KEY) ?? '{}') as Record<string, string>;
    map[ruleId] = jid; localStorage.setItem(LS_KEY, JSON.stringify(map));
    setResumableJobs({ ...map });
  }
  function clearDraftJob(ruleId: string) {
    const map = JSON.parse(localStorage.getItem(LS_KEY) ?? '{}') as Record<string, string>;
    delete map[ruleId]; localStorage.setItem(LS_KEY, JSON.stringify(map));
    setResumableJobs({ ...map });
  }

  useEffect(() => {
    const map = JSON.parse(localStorage.getItem(LS_KEY) ?? '{}') as Record<string, string>;
    setResumableJobs(map);
    loadAll();
  }, []);

  async function loadAll() {
    setLoading(true);
    const [rulesRes, coursesRes] = await Promise.all([
      adminFetch('/api/admin/grammar-rules').then(r => r.json()),
      adminFetch('/api/admin/courses').then(r => r.json()),
    ]);
    setRules(rulesRes.data ?? []);
    setCourses(coursesRes.data ?? []);
    setLoading(false);
  }

  async function loadModules(courseId: string) {
    const res = await adminFetch(`/api/admin/modules?course_id=${courseId}`).then(r => r.json());
    setModules(res.data ?? []);
  }

  function openCreate() {
    setEditingRule(null);
    setFTitle(''); setFCourse(''); setFModule(''); setFLevel('A2');
    setFExpl(''); setFForms([{ pronoun: '', form: '' }]); setFConstr('');
    setFormErr(''); setShowModal(true);
  }

  async function openEdit(rule: GrammarRule) {
    setEditingRule(rule);
    setFTitle(rule.title); setFLevel(rule.level); setFExpl(rule.explanation_vi);
    setFConstr(rule.constraints_text ?? '');
    const forms = Object.entries(rule.rule_table ?? {}).map(([pronoun, form]) => ({ pronoun, form }));
    setFForms(forms.length ? forms : [{ pronoun: '', form: '' }]);
    setFCourse(''); setFModule(''); setFormErr(''); setShowModal(true);
  }

  async function handleRuleImageUpload(file: File) {
    if (!editingRule?.id) return;
    const formData = new FormData();
    formData.set('file', file);
    const res = await adminFetch(`/api/admin/grammar-rules/${editingRule.id}/image`, { method: 'POST', body: formData });
    const j = await res.json();
    if (res.ok && j.data?.image_asset_id) {
      setEditingRule(r => r ? { ...r, image_asset_id: j.data.image_asset_id } : r);
    }
  }

  async function handleSave() {
    const isEdit = editingRule !== null;
    if (!fTitle.trim() || (!isEdit && !fModule)) { setFormErr(isEdit ? 'Nhập tên.' : 'Nhập tên và chọn module.'); return; }
    setSaving(true); setFormErr('');
    const rule_table: Record<string, string> = {};
    fForms.filter(f => f.pronoun.trim() && f.form.trim()).forEach(f => { rule_table[f.pronoun] = f.form; });

    if (isEdit && editingRule) {
      const res = await adminFetch(`/api/admin/grammar-rules/${editingRule.id}`, {
        method: 'PATCH', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ title: fTitle, level: fLevel, explanation_vi: fExpl, rule_table, constraints_text: fConstr }),
      });
      setSaving(false);
      if (!res.ok) { setFormErr('Lỗi khi cập nhật.'); return; }
      setShowModal(false); loadAll();
      return;
    }

    const body = { title: fTitle, module_id: fModule, level: fLevel, explanation_vi: fExpl, rule_table, constraints_text: fConstr };
    const res = await adminFetch('/api/admin/grammar-rules', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
    const j = await res.json();
    setSaving(false);
    if (!res.ok) { setFormErr(j.error?.message ?? 'Lỗi khi lưu.'); return; }
    setShowModal(false); loadAll();
    setGenRuleId(j.data.id); setGenModuleId(fModule);
    setGenPhase('scope'); setPublishOk(false); setPublishErr(''); setExercises([]);
  }

  async function handleDelete(id: string) {
    const res = await adminFetch(`/api/admin/grammar-rules/${id}`, { method: 'DELETE' });
    if (res.ok) setRules(prev => prev.filter(r => r.id !== id));
    setDeletingId(null);
  }

  async function handleGenerate() {
    const exerciseTypes = EXERCISE_TYPES_GRAMMAR.filter(t => genTypes[t.value]).map(t => t.value);
    if (!exerciseTypes.length) { alert('Chọn ít nhất 1 dạng bài.'); return; }
    const numPerType: Record<string, number> = {};
    exerciseTypes.forEach(t => { numPerType[t] = genCount[t] ?? 8; });
    const body = { source_type: 'grammar_rule', source_id: genRuleId, module_id: genModuleId, exercise_types: exerciseTypes, num_per_type: numPerType };
    const res = await adminFetch('/api/admin/content-generation-jobs', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
    const j = await res.json();
    if (!res.ok) { alert(j.error?.message ?? 'Không tạo được job.'); return; }
    setJobId(j.data.job_id); setJobStatus('pending'); setJobError(''); setGenPhase('polling');
  }

  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => {
    if (genPhase !== 'polling' || !jobId) return;
    const id = setInterval(async () => {
      const res = await adminFetch(`/api/admin/content-generation-jobs/${jobId}`);
      const j = await res.json();
      const status = j.data?.status ?? '';
      setJobStatus(status);
      if (status === 'generated') {
        setExercises((j.data.edited_payload ?? j.data.generated_payload)?.exercises ?? []);
        setGenPhase('review');
        clearInterval(id);
        saveDraftJob(genRuleId, jobId);
      } else if (status === 'failed') {
        setJobError(j.data.error_message ?? 'Thất bại.');
        clearInterval(id);
      } else if (TERMINAL.includes(status)) { clearInterval(id); }
    }, 2000);
    return () => clearInterval(id);
  }, [genPhase, jobId, genRuleId]);

  async function saveDraft(showFeedback = false) {
    if (showFeedback) setSavingDraft(true);
    await adminFetch(`/api/admin/content-generation-jobs/${jobId}?action=draft`, {
      method: 'PATCH', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ edited_payload: { exercises } }),
    });
    if (showFeedback) {
      setSavingDraft(false); setDraftSaved(true);
      setTimeout(() => setDraftSaved(false), 2500);
    }
  }

  async function handlePublish() {
    await saveDraft();
    setPublishing(true); setPublishErr(''); setPublishOk(false);
    const res = await adminFetch(`/api/admin/content-generation-jobs/${jobId}?action=publish`, { method: 'POST' });
    const j = await res.json();
    setPublishing(false);
    if (!res.ok) { setPublishErr(j.error?.message ?? 'Lỗi publish.'); return; }
    setPublishOk(true);
    clearDraftJob(genRuleId);
    await loadAll();
    setTimeout(() => { setGenPhase(null); setJobId(''); setPublishOk(false); }, 2000);
  }

  async function handleReject() {
    await adminFetch(`/api/admin/content-generation-jobs/${jobId}?action=reject`, { method: 'POST' });
    clearDraftJob(genRuleId);
    setGenPhase(null); setJobId('');
  }

  async function handleResume(ruleId: string, jid: string) {
    const res = await adminFetch(`/api/admin/content-generation-jobs/${jid}`);
    const j = await res.json();
    if (!res.ok || !j.data) { clearDraftJob(ruleId); return; }
    const payload = j.data.edited_payload ?? j.data.generated_payload;
    setExercises(payload?.exercises ?? []);
    setGenRuleId(ruleId); setJobId(jid);
    setGenPhase('review'); setPublishOk(false); setPublishErr('');
  }

  const filteredModules = modules.filter(m => !fCourse || m.course_id === fCourse);

  return (
    <div style={{ display: 'grid', gap: 24, maxWidth: 900 }}>
      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <p style={{ margin: 0, fontSize: 11, fontWeight: 700, letterSpacing: 1, color: 'var(--accent)', textTransform: 'uppercase' }}>NGỮ PHÁP</p>
          <h1 style={{ margin: '2px 0 0', fontSize: 28, fontWeight: 700 }}>Quy tắc ngữ pháp</h1>
          <p style={{ margin: '4px 0 0', color: 'var(--ink-3)', fontSize: 14 }}>Nhập rule → LLM tạo bài → Admin duyệt → Publish</p>
        </div>
        <button onClick={openCreate}
          style={{ padding: '10px 18px', borderRadius: 12, border: 'none', background: 'var(--accent)', color: '#fff', fontWeight: 700, fontSize: 13, cursor: 'pointer' }}>
          + Tạo quy tắc mới
        </button>
      </div>

      {/* Rules table */}
      <div style={{ background: 'var(--surface)', borderRadius: 20, border: '1px solid var(--border)', overflow: 'hidden' }}>
        <div style={{ display: 'grid', gridTemplateColumns: '2fr 80px 100px 1fr', padding: '8px 20px', background: 'var(--surface-alt)', borderBottom: '1px solid var(--border)', fontSize: 11, fontWeight: 700, color: 'var(--ink-3)', textTransform: 'uppercase', letterSpacing: 0.5 }}>
          <span>Tên quy tắc</span><span>Level</span><span>Trạng thái</span><span />
        </div>
        {loading && <p style={{ padding: '16px 20px', color: 'var(--ink-3)', margin: 0 }}>Đang tải...</p>}
        {!loading && rules.length === 0 && <p style={{ padding: '32px 20px', color: 'var(--ink-3)', margin: 0, textAlign: 'center' }}>Chưa có quy tắc nào.</p>}
        {rules.map(r => (
          <div key={r.id} style={{ display: 'grid', gridTemplateColumns: '2fr 80px 100px 1fr', padding: '12px 20px', borderBottom: '1px solid var(--border)', alignItems: 'center', fontSize: 14 }}>
            <strong style={{ fontWeight: 600 }}>{r.title}</strong>
            <span style={{ color: 'var(--ink-2)' }}>{r.level}</span>
            <span style={{ fontSize: 11, fontWeight: 700, padding: '3px 9px', borderRadius: 99, background: r.status === 'published' ? 'var(--ready-bg)' : 'var(--needs-bg)', color: r.status === 'published' ? 'var(--ready)' : 'var(--needs)', width: 'fit-content' }}>{r.status}</span>
            <div style={{ display: 'flex', gap: 6, justifyContent: 'flex-end', alignItems: 'center' }}>
              {resumableJobs[r.id] && (
                <button onClick={() => handleResume(r.id, resumableJobs[r.id])}
                  style={{ padding: '4px 10px', borderRadius: 8, border: '1px solid var(--accent)', background: 'var(--accent-soft)', color: 'var(--accent)', cursor: 'pointer', fontSize: 12, fontWeight: 600 }}>
                  Draft →
                </button>
              )}
              <button onClick={() => openEdit(r)}
                style={{ padding: '4px 10px', borderRadius: 8, border: '1px solid var(--border)', background: 'transparent', cursor: 'pointer', fontSize: 12 }}>Sửa</button>
              <button onClick={() => { setGenRuleId(r.id); setGenModuleId(''); setGenPhase('scope'); setPublishOk(false); setPublishErr(''); setExercises([]); }}
                style={{ padding: '4px 10px', borderRadius: 8, border: '1px solid var(--border)', background: 'transparent', cursor: 'pointer', fontSize: 12, fontWeight: 600 }}>Generate</button>
              {deletingId === r.id ? (
                <>
                  <button onClick={() => handleDelete(r.id)} style={{ padding: '4px 10px', borderRadius: 8, border: 'none', background: 'var(--error)', color: '#fff', cursor: 'pointer', fontSize: 12, fontWeight: 600 }}>Xác nhận xóa</button>
                  <button onClick={() => setDeletingId(null)} style={{ padding: '4px 8px', borderRadius: 8, border: '1px solid var(--border)', background: 'transparent', cursor: 'pointer', fontSize: 12 }}>Hủy</button>
                </>
              ) : (
                <button onClick={() => setDeletingId(r.id)} style={{ padding: '4px 8px', borderRadius: 8, border: '1px solid var(--border)', background: 'transparent', cursor: 'pointer', fontSize: 12, color: 'var(--error)' }}>Xóa</button>
              )}
            </div>
          </div>
        ))}
      </div>

      {/* Create/Edit modal */}
      {showModal && (
        <div onClick={() => setShowModal(false)} style={{ position: 'fixed', inset: 0, zIndex: 100, background: 'rgba(20,18,14,0.55)', backdropFilter: 'blur(4px)', display: 'flex', alignItems: 'flex-start', justifyContent: 'center', padding: '40px 16px', overflowY: 'auto' }}>
          <div onClick={e => e.stopPropagation()} style={{ width: '100%', maxWidth: 560, background: 'var(--surface)', borderRadius: 24, border: '1px solid var(--border)', padding: 28, display: 'grid', gap: 16, position: 'relative' }}>
            <button onClick={() => setShowModal(false)} style={{ position: 'absolute', top: 14, right: 14, width: 30, height: 30, borderRadius: '50%', border: '1px solid var(--border)', background: 'var(--surface-alt)', cursor: 'pointer', fontSize: 16 }}>×</button>
            <h2 style={{ margin: 0, fontSize: 20 }}>{editingRule ? `Sửa: ${editingRule.title}` : 'Tạo quy tắc ngữ pháp'}</h2>
            <label style={{ display: 'grid', gap: 6, fontSize: 13 }}>Tên quy tắc *<input value={fTitle} onChange={e => setFTitle(e.target.value)} style={inputStyle} placeholder="VD: Verb být ở hiện tại" /></label>
            {!editingRule && (
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                <label style={{ display: 'grid', gap: 6, fontSize: 13 }}>Khóa học *
                  <select value={fCourse} onChange={e => { setFCourse(e.target.value); setFModule(''); loadModules(e.target.value); }} style={inputStyle}>
                    <option value="">— chọn —</option>
                    {courses.map(c => <option key={c.id} value={c.id}>{c.title}</option>)}
                  </select>
                </label>
                <label style={{ display: 'grid', gap: 6, fontSize: 13 }}>Module *
                  <select value={fModule} onChange={e => setFModule(e.target.value)} style={inputStyle}>
                    <option value="">— chọn —</option>
                    {filteredModules.map(m => <option key={m.id} value={m.id}>{m.title}</option>)}
                  </select>
                </label>
              </div>
            )}
            <label style={{ display: 'grid', gap: 6, fontSize: 13 }}>Level
              <select value={fLevel} onChange={e => setFLevel(e.target.value)} style={inputStyle}>
                {LEVELS.map(l => <option key={l} value={l}>{l}</option>)}
              </select>
            </label>
            <label style={{ display: 'grid', gap: 6, fontSize: 13 }}>Giải thích (tiếng Việt)
              <textarea rows={3} value={fExpl} onChange={e => setFExpl(e.target.value)} style={inputStyle} placeholder="VD: Động từ 'být' nghĩa là 'là/ở'..." />
            </label>
            <div>
              <p style={{ margin: '0 0 8px', fontSize: 13, fontWeight: 700 }}>Bảng chia / biến cách</p>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 32px', gap: 6, fontSize: 11, color: 'var(--ink-3)', fontWeight: 700, marginBottom: 6 }}><span>Chủ ngữ</span><span>Dạng</span><span /></div>
              {fForms.map((f, i) => (
                <div key={i} style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 32px', gap: 6, marginBottom: 6 }}>
                  <input value={f.pronoun} placeholder="já" onChange={e => { const n = [...fForms]; n[i] = { ...f, pronoun: e.target.value }; setFForms(n); }} style={inputStyle} />
                  <input value={f.form} placeholder="jsem" onChange={e => { const n = [...fForms]; n[i] = { ...f, form: e.target.value }; setFForms(n); }} style={inputStyle} />
                  <button onClick={() => setFForms(fForms.filter((_, j) => j !== i))} style={{ border: 'none', background: 'none', cursor: 'pointer', color: '#c03a28', fontSize: 18 }}>×</button>
                </div>
              ))}
              <button onClick={() => setFForms([...fForms, { pronoun: '', form: '' }])} style={{ padding: '4px 10px', borderRadius: 8, border: '1px dashed var(--border)', background: 'transparent', cursor: 'pointer', fontSize: 12 }}>+ Thêm dòng</button>
            </div>
            <label style={{ display: 'grid', gap: 6, fontSize: 13 }}>Ràng buộc (constraints)
              <textarea rows={2} value={fConstr} onChange={e => setFConstr(e.target.value)} style={inputStyle} placeholder="VD: Chỉ dùng câu đơn giản A1..." />
            </label>

            {/* Image upload — only for existing rules */}
            {editingRule?.id && (
              <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <div style={{ width: 44, height: 44, borderRadius: 8, border: `1.5px ${editingRule.image_asset_id ? 'solid #22c55e' : 'dashed var(--border)'}`, overflow: 'hidden', background: 'var(--surface-alt)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                  {editingRule.image_asset_id ? <span style={{ fontSize: 20 }}>🖼</span> : <span style={{ fontSize: 10, color: 'var(--ink-4)' }}>img</span>}
                </div>
                <label style={{ display: 'flex', alignItems: 'center', gap: 6, border: `1px ${editingRule.image_asset_id ? 'solid #22c55e' : 'dashed var(--border)'}`, borderRadius: 8, padding: '6px 12px', cursor: 'pointer', fontSize: 12, fontWeight: 600, color: editingRule.image_asset_id ? '#15803d' : 'var(--ink-3)', background: editingRule.image_asset_id ? '#f0fdf4' : 'transparent' }}>
                  {editingRule.image_asset_id ? '✓ Đã có ảnh — Đổi' : '+ Tải ảnh ngữ cảnh'}
                  <input type="file" accept="image/jpeg,image/png,image/webp" style={{ display: 'none' }} onChange={e => { const f = e.target.files?.[0]; if (f) handleRuleImageUpload(f); e.target.value = ''; }} />
                </label>
              </div>
            )}

            {formErr && <p style={{ margin: 0, color: 'var(--error)', fontSize: 13 }}>{formErr}</p>}
            <button onClick={handleSave} disabled={saving} style={{ padding: '12px', borderRadius: 12, border: 'none', background: 'var(--accent)', color: '#fff', fontWeight: 700, fontSize: 14, cursor: saving ? 'not-allowed' : 'pointer' }}>
              {saving ? 'Đang lưu...' : editingRule ? 'Cập nhật' : 'Lưu & tiếp tục'}
            </button>
          </div>
        </div>
      )}

      {/* Generation panel */}
      {genPhase && (
        <div style={{ background: 'var(--surface)', borderRadius: 20, border: '1px solid var(--border)', padding: 24, display: 'grid', gap: 16 }}>

          {/* Step indicator */}
          <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
            {(['scope', 'polling', 'review'] as const).map((p, i) => (
              <div key={p} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <div style={{ width: 28, height: 28, borderRadius: '50%', background: genPhase === p ? 'var(--accent)' : 'var(--surface-alt)', color: genPhase === p ? '#fff' : 'var(--ink-3)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 13, fontWeight: 700, border: '1px solid var(--border)' }}>{i + 1}</div>
                <span style={{ fontSize: 12, fontWeight: genPhase === p ? 700 : 400, color: genPhase === p ? 'var(--ink)' : 'var(--ink-3)' }}>
                  {p === 'scope' ? 'Cấu hình' : p === 'polling' ? 'Đang tạo...' : 'Chỉnh sửa & Publish'}
                </span>
                {i < 2 && <span style={{ color: 'var(--ink-4)' }}>→</span>}
              </div>
            ))}
          </div>

          {/* Scope */}
          {genPhase === 'scope' && (
            <div style={{ display: 'grid', gap: 12 }}>
              <h3 style={{ margin: 0 }}>Cấu hình generate</h3>
              {EXERCISE_TYPES_GRAMMAR.map(t => (
                <label key={t.value} style={{ display: 'flex', alignItems: 'center', gap: 10, fontSize: 13 }}>
                  <input type="checkbox" checked={!!genTypes[t.value]} onChange={e => setGenTypes(g => ({ ...g, [t.value]: e.target.checked }))} />
                  <strong>{t.label}</strong><span style={{ color: 'var(--ink-3)' }}>{t.hint}</span>
                  {genTypes[t.value] && (
                    <span style={{ marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: 6, fontSize: 12 }}>
                      Số lượng:
                      <input type="number" min={1} max={20} value={genCount[t.value] ?? 8}
                        onChange={e => setGenCount(g => ({ ...g, [t.value]: parseInt(e.target.value) || 8 }))}
                        style={{ ...inputStyle, width: 60, padding: '4px 8px', resize: 'none' }} />
                    </span>
                  )}
                </label>
              ))}
              <button onClick={handleGenerate} style={{ padding: '12px 20px', borderRadius: 12, border: 'none', background: 'var(--accent)', color: '#fff', fontWeight: 700, fontSize: 14, cursor: 'pointer', width: 'fit-content' }}>
                ⚡ Tạo bài tập với AI
              </button>
            </div>
          )}

          {/* Polling */}
          {genPhase === 'polling' && (
            <div style={{ textAlign: 'center', padding: '24px 0' }}>
              <div style={{ fontSize: 40, marginBottom: 8 }}>⏳</div>
              <h3 style={{ margin: '0 0 8px' }}>AI đang tạo...</h3>
              <p style={{ margin: '0 0 16px', color: 'var(--ink-3)', fontSize: 13 }}>Trạng thái: <strong>{jobStatus}</strong></p>
              {jobError && <p style={{ color: 'var(--error)', fontSize: 13 }}>{jobError}</p>}
              <button onClick={handleReject} style={{ padding: '8px 16px', borderRadius: 10, border: '1px solid var(--border)', background: 'transparent', cursor: 'pointer', fontSize: 13 }}>Huỷ</button>
            </div>
          )}

          {/* Review / Edit draft */}
          {genPhase === 'review' && (
            <div style={{ display: 'grid', gap: 16 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: 8 }}>
                <div>
                  <h3 style={{ margin: 0 }}>Chỉnh sửa nháp — {exercises.length} bài tập</h3>
                  <p style={{ margin: '4px 0 0', fontSize: 12, color: 'var(--ink-3)' }}>Sửa trực tiếp từng bài, rồi Lưu nháp hoặc Publish.</p>
                </div>
                <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
                  <button onClick={() => { setGenPhase(null); setJobId(''); }}
                    style={{ padding: '8px 14px', borderRadius: 10, border: '1px solid var(--border)', background: 'transparent', cursor: 'pointer', fontSize: 12 }}>← Thoát</button>
                  <button onClick={handleReject}
                    style={{ padding: '8px 14px', borderRadius: 10, border: '1px solid var(--border)', background: 'transparent', cursor: 'pointer', fontSize: 12, color: 'var(--error)' }}>Từ chối</button>
                  <button onClick={() => saveDraft(true)} disabled={savingDraft}
                    style={{ padding: '8px 14px', borderRadius: 10, border: '1px solid var(--border)', background: draftSaved ? 'var(--ready-bg)' : 'transparent', color: draftSaved ? 'var(--ready)' : 'inherit', cursor: savingDraft ? 'wait' : 'pointer', fontSize: 12 }}>
                    {savingDraft ? 'Đang lưu...' : draftSaved ? '✓ Đã lưu nháp' : 'Lưu nháp'}
                  </button>
                  <button onClick={handlePublish} disabled={publishing}
                    style={{ padding: '8px 14px', borderRadius: 10, border: 'none', background: 'var(--accent)', color: '#fff', cursor: publishing ? 'not-allowed' : 'pointer', fontSize: 12, fontWeight: 700 }}>
                    {publishing ? 'Đang publish...' : `Publish ${exercises.length} bài`}
                  </button>
                </div>
              </div>
              {draftSaved && <p style={{ margin: 0, fontSize: 12, color: 'var(--ready)' }}>✓ Đã lưu nháp — tiếp tục chỉnh sửa hoặc ấn Publish khi xong.</p>}
              {publishErr && <p style={{ color: 'var(--error)', fontSize: 13, margin: 0 }}>{publishErr}</p>}
              {publishOk && <p style={{ color: 'var(--ready)', fontSize: 13, margin: 0 }}>✓ Publish thành công! Bài tập đã vào inventory.</p>}

              {exercises.map((ex, i) => (
                <div key={i} style={{ border: '1px solid var(--border)', borderRadius: 14, padding: 16, background: 'var(--surface-alt)' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
                    <span style={{ fontSize: 11, fontWeight: 700, padding: '3px 9px', borderRadius: 99, background: 'var(--accent-soft)', color: 'var(--accent)' }}>{ex.exercise_type}</span>
                    <button onClick={() => setExercises(exercises.filter((_, j) => j !== i))}
                      style={{ border: 'none', background: 'none', cursor: 'pointer', color: '#c03a28', fontSize: 16 }}>×</button>
                  </div>
                  {ex.exercise_type === 'fill_blank' && <FillBlankEditor ex={ex} onChange={u => setExercises(exercises.map((e, j) => j === i ? u : e))} />}
                  {ex.exercise_type === 'choice_word' && <ChoiceWordEditor ex={ex} onChange={u => setExercises(exercises.map((e, j) => j === i ? u : e))} />}
                  {ex.exercise_type === 'matching' && <MatchingEditor ex={ex} onChange={u => setExercises(exercises.map((e, j) => j === i ? u : e))} />}
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
