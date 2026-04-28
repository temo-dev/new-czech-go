'use client';

import { useEffect, useState } from 'react';

// ── Types ─────────────────────────────────────────────────────────────────────

type VocabItem = { term: string; meaning: string; part_of_speech?: string };

type VocabSet = {
  id: string; skill_id: string; title: string;
  level: string; explanation_lang: string; status: string;
};

type Course = { id: string; title: string };
type Module = { id: string; title: string; course_id: string };

type GeneratedExercise = {
  exercise_type: string;
  front_text?: string; back_text?: string; example_sentence?: string; example_translation?: string;
  prompt?: string; options?: string[]; correct_answer?: string; grammar_note?: string;
  pairs?: Array<{ left: string; right: string }>;
  explanation: string;
};

type GenerationJob = {
  job_id?: string; id?: string; status: string;
  generated_payload?: { exercises: GeneratedExercise[] };
  edited_payload?: { exercises: GeneratedExercise[] };
  error_message?: string;
};

// ── Helpers ───────────────────────────────────────────────────────────────────

const EXERCISE_TYPES = [
  { value: 'quizcard_basic', label: 'Flashcard', hint: 'Lật thẻ — biết / ôn lại' },
  { value: 'matching',       label: 'Ghép đôi',  hint: 'Ghép Czech → Vietnamese' },
  { value: 'fill_blank',     label: 'Điền từ',   hint: 'Câu có ___' },
  { value: 'choice_word',    label: 'Chọn từ',   hint: '4 lựa chọn A-D' },
];

const LEVELS = ['A1', 'A2', 'B1'];
const LANGS  = [{ value: 'vi', label: 'Tiếng Việt' }, { value: 'en', label: 'English' }, { value: 'cs', label: 'Czech' }];
const TERMINAL = ['generated', 'failed', 'rejected', 'published'];

// ── Draft editors ─────────────────────────────────────────────────────────────

function QuizcardEditor({ ex, onChange }: { ex: GeneratedExercise; onChange: (e: GeneratedExercise) => void }) {
  return (
    <div style={{ display: 'grid', gap: 8 }}>
      <label style={{ display: 'grid', gap: 4, fontSize: 13 }}>
        Mặt trước (Czech)
        <textarea rows={2} value={ex.front_text ?? ''} onChange={e => onChange({ ...ex, front_text: e.target.value })} style={inputStyle} />
      </label>
      <label style={{ display: 'grid', gap: 4, fontSize: 13 }}>
        Mặt sau (Vietnamese)
        <textarea rows={2} value={ex.back_text ?? ''} onChange={e => onChange({ ...ex, back_text: e.target.value })} style={inputStyle} />
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
        Câu hỏi / câu điền
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
        Đáp án đúng (full text)
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

function MatchingEditor({ ex, onChange }: { ex: GeneratedExercise; onChange: (e: GeneratedExercise) => void }) {
  const pairs = ex.pairs ?? [];
  const setPairs = (next: Array<{ left: string; right: string }>) => onChange({ ...ex, pairs: next });
  return (
    <div style={{ display: 'grid', gap: 8 }}>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 32px', gap: 6, fontSize: 12, color: 'var(--ink-3)', fontWeight: 700 }}>
        <span>Czech (left)</span><span>Vietnamese (right)</span><span />
      </div>
      {pairs.map((p, i) => (
        <div key={i} style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 32px', gap: 6 }}>
          <input value={p.left} onChange={e => { const n = [...pairs]; n[i] = { ...p, left: e.target.value }; setPairs(n); }} style={inputStyle} placeholder="Czech" />
          <input value={p.right} onChange={e => { const n = [...pairs]; n[i] = { ...p, right: e.target.value }; setPairs(n); }} style={inputStyle} placeholder="Vietnamese" />
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

const inputStyle: React.CSSProperties = {
  padding: '7px 10px', borderRadius: 8, border: '1px solid var(--border)',
  background: 'var(--surface-alt)', fontSize: 13, resize: 'vertical',
};

// ── Validation helpers ────────────────────────────────────────────────────────

function validateExercise(ex: GeneratedExercise): string[] {
  const errs: string[] = [];
  if (!ex.explanation?.trim()) errs.push('Thiếu giải thích');
  if (ex.exercise_type === 'quizcard_basic') {
    if (!ex.front_text?.trim()) errs.push('Thiếu mặt trước');
    if (!ex.back_text?.trim()) errs.push('Thiếu mặt sau');
  } else if (ex.exercise_type === 'choice_word') {
    if (!ex.prompt?.trim()) errs.push('Thiếu câu hỏi');
    if ((ex.options ?? []).filter(Boolean).length < 2) errs.push('Cần ≥2 lựa chọn');
    if (!ex.correct_answer?.trim()) errs.push('Thiếu đáp án');
    if (ex.correct_answer && !(ex.options ?? []).includes(ex.correct_answer)) errs.push('Đáp án không nằm trong options');
  } else if (ex.exercise_type === 'fill_blank') {
    if (!ex.prompt?.includes('___')) errs.push('Câu phải chứa ___');
    if (!ex.correct_answer?.trim()) errs.push('Thiếu đáp án');
  } else if (ex.exercise_type === 'matching') {
    if ((ex.pairs ?? []).length < 2) errs.push('Cần ≥2 cặp');
  }
  return errs;
}

// ── Main page ─────────────────────────────────────────────────────────────────

export default function VocabularyPage() {
  const [sets, setSets]         = useState<VocabSet[]>([]);
  const [courses, setCourses]   = useState<Course[]>([]);
  const [modules, setModules]   = useState<Module[]>([]);
  const [loading, setLoading]   = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [editingSet, setEditingSet] = useState<VocabSet | null>(null);

  // Form state
  const [fTitle, setFTitle]     = useState('');
  const [fCourse, setFCourse]   = useState('');
  const [fModule, setFModule]   = useState('');
  const [fLevel, setFLevel]     = useState('A2');
  const [fLang, setFLang]       = useState('vi');
  const [fItems, setFItems]     = useState<VocabItem[]>([{ term: '', meaning: '' }]);
  const [saving, setSaving]     = useState(false);
  const [formErr, setFormErr]   = useState('');

  // Generation state
  const [genPhase, setGenPhase] = useState<'scope' | 'polling' | 'review' | null>(null);
  const [genSetId, setGenSetId] = useState('');
  const [genTypes, setGenTypes] = useState<Record<string, boolean>>({ quizcard_basic: true, fill_blank: true });
  const [genCount, setGenCount] = useState<Record<string, number>>({ quizcard_basic: 5, matching: 3, fill_blank: 5, choice_word: 5 });
  const [jobId, setJobId]       = useState('');
  const [jobStatus, setJobStatus] = useState('');
  const [jobError, setJobError] = useState('');
  const [exercises, setExercises] = useState<GeneratedExercise[]>([]);
  const [publishing, setPublishing] = useState(false);
  const [publishErr, setPublishErr] = useState('');
  const [publishOk, setPublishOk]   = useState(false);

  useEffect(() => { loadAll(); }, []);

  async function loadAll() {
    setLoading(true);
    const [setsRes, coursesRes] = await Promise.all([
      fetch('/api/admin/vocabulary-sets').then(r => r.json()),
      fetch('/api/admin/courses').then(r => r.json()),
    ]);
    setSets(setsRes.data ?? []);
    setCourses(coursesRes.data ?? []);
    setLoading(false);
  }

  async function loadModules(courseId: string) {
    if (!courseId) { setModules([]); return; }
    const res = await fetch(`/api/admin/modules?course_id=${courseId}`).then(r => r.json());
    setModules(res.data ?? []);
  }

  function openCreate() {
    setEditingSet(null);
    setFTitle(''); setFCourse(''); setFModule(''); setFLevel('A2'); setFLang('vi');
    setFItems([{ term: '', meaning: '' }]);
    setFormErr('');
    setShowModal(true);
  }

  async function handleSave() {
    if (!fTitle.trim() || !fModule) { setFormErr('Nhập tên và chọn module.'); return; }
    if (fItems.filter(i => i.term.trim() && i.meaning.trim()).length === 0) {
      setFormErr('Nhập ít nhất 1 từ.'); return;
    }
    setSaving(true); setFormErr('');
    const items = fItems.filter(i => i.term.trim() && i.meaning.trim());
    const body = { title: fTitle, module_id: fModule, level: fLevel, explanation_lang: fLang, items };
    const res = await fetch('/api/admin/vocabulary-sets', {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
    });
    const j = await res.json();
    setSaving(false);
    if (!res.ok) { setFormErr(j.error?.message ?? 'Lỗi khi lưu.'); return; }
    setShowModal(false);
    loadAll();
    // Open generation for newly created set
    setGenSetId(j.data.id);
    setGenPhase('scope');
    setPublishOk(false); setPublishErr(''); setExercises([]);
  }

  async function handleGenerate() {
    const exerciseTypes = EXERCISE_TYPES.filter(t => genTypes[t.value]).map(t => t.value);
    if (exerciseTypes.length === 0) { alert('Chọn ít nhất 1 dạng bài.'); return; }
    const numPerType: Record<string, number> = {};
    exerciseTypes.forEach(t => { numPerType[t] = genCount[t] ?? 5; });
    const body = { source_type: 'vocabulary_set', source_id: genSetId, module_id: modules.find(m => m.id === fModule)?.id ?? fModule, exercise_types: exerciseTypes, num_per_type: numPerType };
    const res = await fetch('/api/admin/content-generation-jobs', {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
    });
    const j = await res.json();
    if (!res.ok) { alert(j.error?.message ?? 'Không tạo được job.'); return; }
    setJobId(j.data.job_id);
    setJobStatus('pending');
    setJobError('');
    setGenPhase('polling');
  }

  // Polling
  useEffect(() => {
    if (genPhase !== 'polling' || !jobId) return;
    const id = setInterval(async () => {
      const res = await fetch(`/api/admin/content-generation-jobs/${jobId}`);
      const j = await res.json();
      const status = j.data?.status ?? '';
      setJobStatus(status);
      if (status === 'generated') {
        const payload = j.data.edited_payload ?? j.data.generated_payload;
        setExercises(payload?.exercises ?? []);
        setGenPhase('review');
        clearInterval(id);
      } else if (status === 'failed') {
        setJobError(j.data.error_message ?? 'Generation failed.');
        clearInterval(id);
      } else if (TERMINAL.includes(status)) {
        clearInterval(id);
      }
    }, 2000);
    return () => clearInterval(id);
  }, [genPhase, jobId]);

  async function saveDraft() {
    await fetch(`/api/admin/content-generation-jobs/${jobId}?action=draft`, {
      method: 'PATCH', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ edited_payload: { exercises } }),
    });
  }

  async function handlePublish() {
    await saveDraft();
    setPublishing(true); setPublishErr(''); setPublishOk(false);
    const res = await fetch(`/api/admin/content-generation-jobs/${jobId}?action=publish`, { method: 'POST' });
    const j = await res.json();
    setPublishing(false);
    if (!res.ok) {
      const ve = j.error?.validation_errors;
      setPublishErr(ve ? `${ve.length} lỗi validation. Kiểm tra và sửa trước khi publish.` : (j.error?.message ?? 'Lỗi publish.'));
      return;
    }
    setPublishOk(true);
    loadAll();
  }

  async function handleReject() {
    await fetch(`/api/admin/content-generation-jobs/${jobId}?action=reject`, { method: 'POST' });
    setGenPhase(null); setJobId('');
  }

  const filteredModules = modules.filter(m => !fCourse || m.course_id === fCourse);

  return (
    <div style={{ display: 'grid', gap: 24, maxWidth: 900 }}>
      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <p style={{ margin: 0, fontSize: 11, fontWeight: 700, letterSpacing: 1, color: 'var(--brand)', textTransform: 'uppercase' }}>TỪ VỰNG</p>
          <h1 style={{ margin: '2px 0 0', fontSize: 28, fontWeight: 700 }}>Bộ từ vựng</h1>
          <p style={{ margin: '4px 0 0', color: 'var(--ink-3)', fontSize: 14 }}>Nhập từ → LLM tạo bài tập nháp → Admin duyệt → Publish</p>
        </div>
        <button onClick={openCreate}
          style={{ padding: '10px 18px', borderRadius: 12, border: 'none', background: 'var(--brand)', color: '#fff', fontWeight: 700, fontSize: 13, cursor: 'pointer' }}>
          + Tạo bộ từ mới
        </button>
      </div>

      {/* Sets table */}
      <div style={{ background: 'var(--surface)', borderRadius: 20, border: '1px solid var(--border)', overflow: 'hidden' }}>
        <div style={{ display: 'grid', gridTemplateColumns: '2fr 80px 80px 100px 120px', padding: '8px 20px', background: 'var(--surface-alt)', borderBottom: '1px solid var(--border)', fontSize: 11, fontWeight: 700, color: 'var(--ink-3)', textTransform: 'uppercase', letterSpacing: 0.5 }}>
          <span>Tên bộ từ</span><span>Level</span><span>Ngôn ngữ</span><span>Trạng thái</span><span></span>
        </div>
        {loading && <p style={{ padding: '16px 20px', color: 'var(--ink-3)', margin: 0 }}>Đang tải...</p>}
        {!loading && sets.length === 0 && (
          <p style={{ padding: '32px 20px', color: 'var(--ink-3)', margin: 0, textAlign: 'center' }}>Chưa có bộ từ nào. Tạo mới để bắt đầu.</p>
        )}
        {sets.map(s => (
          <div key={s.id} style={{ display: 'grid', gridTemplateColumns: '2fr 80px 80px 100px 120px', padding: '12px 20px', borderBottom: '1px solid var(--border)', alignItems: 'center', fontSize: 14 }}>
            <strong style={{ fontWeight: 600 }}>{s.title}</strong>
            <span style={{ color: 'var(--ink-2)' }}>{s.level}</span>
            <span style={{ color: 'var(--ink-2)' }}>{s.explanation_lang.toUpperCase()}</span>
            <span style={{ fontSize: 11, fontWeight: 700, padding: '3px 9px', borderRadius: 99, background: s.status === 'published' ? 'var(--ready-bg)' : 'var(--needs-bg)', color: s.status === 'published' ? 'var(--ready)' : 'var(--needs)', width: 'fit-content' }}>
              {s.status}
            </span>
            <div style={{ display: 'flex', gap: 6, justifyContent: 'flex-end' }}>
              <button onClick={() => { setGenSetId(s.id); setGenPhase('scope'); setPublishOk(false); setPublishErr(''); setExercises([]); }}
                style={{ padding: '4px 10px', borderRadius: 8, border: '1px solid var(--border)', background: 'transparent', cursor: 'pointer', fontSize: 12, fontWeight: 600 }}>
                Generate
              </button>
            </div>
          </div>
        ))}
      </div>

      {/* Create/Edit modal */}
      {showModal && (
        <div onClick={() => setShowModal(false)} style={{ position: 'fixed', inset: 0, zIndex: 100, background: 'rgba(20,18,14,0.55)', backdropFilter: 'blur(4px)', display: 'flex', alignItems: 'flex-start', justifyContent: 'center', padding: '40px 16px', overflowY: 'auto' }}>
          <div onClick={e => e.stopPropagation()} style={{ width: '100%', maxWidth: 560, background: 'var(--surface)', borderRadius: 24, border: '1px solid var(--border)', padding: 28, display: 'grid', gap: 16, position: 'relative' }}>
            <button onClick={() => setShowModal(false)} style={{ position: 'absolute', top: 14, right: 14, width: 30, height: 30, borderRadius: '50%', border: '1px solid var(--border)', background: 'var(--surface-alt)', cursor: 'pointer', fontSize: 16 }}>×</button>
            <h2 style={{ margin: 0, fontSize: 20 }}>Tạo bộ từ vựng mới</h2>

            <label style={{ display: 'grid', gap: 6, fontSize: 13 }}>
              Tên bộ từ *
              <input value={fTitle} onChange={e => setFTitle(e.target.value)} style={inputStyle} placeholder="VD: Động từ di chuyển" />
            </label>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <label style={{ display: 'grid', gap: 6, fontSize: 13 }}>
                Khóa học *
                <select value={fCourse} onChange={e => { setFCourse(e.target.value); setFModule(''); loadModules(e.target.value); }} style={inputStyle}>
                  <option value="">— chọn —</option>
                  {courses.map(c => <option key={c.id} value={c.id}>{c.title}</option>)}
                </select>
              </label>
              <label style={{ display: 'grid', gap: 6, fontSize: 13 }}>
                Module *
                <select value={fModule} onChange={e => setFModule(e.target.value)} style={inputStyle}>
                  <option value="">— chọn —</option>
                  {filteredModules.map(m => <option key={m.id} value={m.id}>{m.title}</option>)}
                </select>
              </label>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <label style={{ display: 'grid', gap: 6, fontSize: 13 }}>
                Level
                <select value={fLevel} onChange={e => setFLevel(e.target.value)} style={inputStyle}>
                  {LEVELS.map(l => <option key={l} value={l}>{l}</option>)}
                </select>
              </label>
              <label style={{ display: 'grid', gap: 6, fontSize: 13 }}>
                Ngôn ngữ giải thích
                <select value={fLang} onChange={e => setFLang(e.target.value)} style={inputStyle}>
                  {LANGS.map(l => <option key={l.value} value={l.value}>{l.label}</option>)}
                </select>
              </label>
            </div>

            {/* Word list */}
            <div>
              <p style={{ margin: '0 0 8px', fontSize: 13, fontWeight: 700 }}>Danh sách từ</p>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 100px 32px', gap: 6, fontSize: 11, color: 'var(--ink-3)', fontWeight: 700, marginBottom: 6 }}>
                <span>Từ Czech</span><span>Nghĩa Vietnamese</span><span>Loại từ</span><span />
              </div>
              {fItems.map((item, i) => (
                <div key={i} style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 100px 32px', gap: 6, marginBottom: 6 }}>
                  <input value={item.term} placeholder="chodím" onChange={e => { const n = [...fItems]; n[i] = { ...item, term: e.target.value }; setFItems(n); }} style={inputStyle} />
                  <input value={item.meaning} placeholder="đi bộ" onChange={e => { const n = [...fItems]; n[i] = { ...item, meaning: e.target.value }; setFItems(n); }} style={inputStyle} />
                  <input value={item.part_of_speech ?? ''} placeholder="verb" onChange={e => { const n = [...fItems]; n[i] = { ...item, part_of_speech: e.target.value }; setFItems(n); }} style={inputStyle} />
                  <button onClick={() => setFItems(fItems.filter((_, j) => j !== i))} style={{ border: 'none', background: 'none', cursor: 'pointer', color: '#c03a28', fontSize: 18 }}>×</button>
                </div>
              ))}
              <button onClick={() => setFItems([...fItems, { term: '', meaning: '' }])}
                style={{ padding: '4px 10px', borderRadius: 8, border: '1px dashed var(--border)', background: 'transparent', cursor: 'pointer', fontSize: 12 }}>
                + Thêm từ
              </button>
            </div>

            {formErr && <p style={{ margin: 0, color: 'var(--error)', fontSize: 13 }}>{formErr}</p>}
            <button onClick={handleSave} disabled={saving}
              style={{ padding: '12px', borderRadius: 12, border: 'none', background: 'var(--brand)', color: '#fff', fontWeight: 700, fontSize: 14, cursor: saving ? 'not-allowed' : 'pointer' }}>
              {saving ? 'Đang lưu...' : 'Lưu & tiếp tục'}
            </button>
          </div>
        </div>
      )}

      {/* Generation flow */}
      {genPhase && (
        <div style={{ background: 'var(--surface)', borderRadius: 20, border: '1px solid var(--border)', padding: 24 }}>
          {/* Step indicator */}
          <div style={{ display: 'flex', gap: 8, marginBottom: 20 }}>
            {(['scope', 'polling', 'review'] as const).map((p, i) => (
              <div key={p} style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                <div style={{ width: 24, height: 24, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 12, fontWeight: 700,
                  background: genPhase === p ? 'var(--brand)' : 'var(--surface-alt)',
                  color: genPhase === p ? '#fff' : 'var(--ink-3)',
                  border: `1px solid ${genPhase === p ? 'var(--brand)' : 'var(--border)'}` }}>
                  {i + 1}
                </div>
                <span style={{ fontSize: 12, fontWeight: genPhase === p ? 700 : 400, color: genPhase === p ? 'var(--ink)' : 'var(--ink-3)' }}>
                  {p === 'scope' ? 'Cấu hình' : p === 'polling' ? 'Đang tạo...' : 'Review & Publish'}
                </span>
                {i < 2 && <span style={{ color: 'var(--ink-4)' }}>→</span>}
              </div>
            ))}
          </div>

          {/* Scope panel */}
          {genPhase === 'scope' && (
            <div style={{ display: 'grid', gap: 16 }}>
              <h3 style={{ margin: 0 }}>Cấu hình generate</h3>
              <p style={{ margin: 0, fontSize: 13, color: 'var(--ink-3)' }}>Bộ từ: <strong>{sets.find(s => s.id === genSetId)?.title ?? genSetId}</strong></p>
              <div>
                <p style={{ margin: '0 0 10px', fontSize: 13, fontWeight: 700 }}>Dạng bài muốn tạo:</p>
                <div style={{ display: 'grid', gap: 8 }}>
                  {EXERCISE_TYPES.map(t => (
                    <label key={t.value} style={{ display: 'flex', alignItems: 'center', gap: 10, fontSize: 13, cursor: 'pointer' }}>
                      <input type="checkbox" checked={!!genTypes[t.value]} onChange={e => setGenTypes(g => ({ ...g, [t.value]: e.target.checked }))} />
                      <strong>{t.label}</strong>
                      <span style={{ color: 'var(--ink-3)' }}>{t.hint}</span>
                      {genTypes[t.value] && (
                        <span style={{ marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: 6, fontSize: 12 }}>
                          Số lượng:
                          <input type="number" min={1} max={20} value={genCount[t.value] ?? 5}
                            onChange={e => setGenCount(g => ({ ...g, [t.value]: parseInt(e.target.value) || 5 }))}
                            style={{ ...inputStyle, width: 60, padding: '4px 8px' }} />
                        </span>
                      )}
                    </label>
                  ))}
                </div>
              </div>
              <button onClick={handleGenerate}
                style={{ padding: '12px 20px', borderRadius: 12, border: 'none', background: 'var(--brand)', color: '#fff', fontWeight: 700, fontSize: 14, cursor: 'pointer', width: 'fit-content' }}>
                ⚡ Tạo bài tập với AI
              </button>
            </div>
          )}

          {/* Polling panel */}
          {genPhase === 'polling' && (
            <div style={{ textAlign: 'center', padding: '32px 0' }}>
              <div style={{ fontSize: 40, marginBottom: 12 }}>⏳</div>
              <h3 style={{ margin: '0 0 8px' }}>AI đang tạo bài tập...</h3>
              <p style={{ margin: '0 0 16px', color: 'var(--ink-3)', fontSize: 13 }}>Trạng thái: <strong>{jobStatus}</strong></p>
              {jobError && <p style={{ color: 'var(--error)', fontSize: 13 }}>{jobError}</p>}
              <button onClick={handleReject} style={{ padding: '8px 16px', borderRadius: 10, border: '1px solid var(--border)', background: 'transparent', cursor: 'pointer', fontSize: 13 }}>
                Huỷ
              </button>
            </div>
          )}

          {/* Review panel */}
          {genPhase === 'review' && (
            <div style={{ display: 'grid', gap: 16 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <h3 style={{ margin: 0 }}>Review {exercises.length} bài tập</h3>
                <div style={{ display: 'flex', gap: 8 }}>
                  <button onClick={handleReject} style={{ padding: '8px 14px', borderRadius: 10, border: '1px solid var(--border)', background: 'transparent', cursor: 'pointer', fontSize: 12 }}>Từ chối</button>
                  <button onClick={saveDraft} style={{ padding: '8px 14px', borderRadius: 10, border: '1px solid var(--border)', background: 'transparent', cursor: 'pointer', fontSize: 12 }}>Lưu nháp</button>
                  <button onClick={handlePublish} disabled={publishing}
                    style={{ padding: '8px 14px', borderRadius: 10, border: 'none', background: 'var(--brand)', color: '#fff', cursor: publishing ? 'not-allowed' : 'pointer', fontSize: 12, fontWeight: 700 }}>
                    {publishing ? 'Đang publish...' : `Publish ${exercises.length} bài`}
                  </button>
                </div>
              </div>
              {publishErr && <p style={{ color: 'var(--error)', fontSize: 13, margin: 0 }}>{publishErr}</p>}
              {publishOk && <p style={{ color: 'var(--ready)', fontSize: 13, margin: 0 }}>✓ Publish thành công! Bài tập đã vào inventory.</p>}

              {exercises.map((ex, i) => {
                const errs = validateExercise(ex);
                return (
                  <div key={i} style={{ border: `1px solid ${errs.length ? '#c03a28' : 'var(--border)'}`, borderRadius: 14, padding: 16, background: 'var(--surface-alt)' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
                      <span style={{ fontSize: 11, fontWeight: 700, padding: '3px 9px', borderRadius: 99, background: 'var(--brand-soft)', color: 'var(--brand)' }}>
                        {ex.exercise_type}
                      </span>
                      <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
                        {errs.length > 0 && <span style={{ fontSize: 11, color: '#c03a28', fontWeight: 600 }}>⚠ {errs.join(', ')}</span>}
                        <button onClick={() => setExercises(exercises.filter((_, j) => j !== i))}
                          style={{ border: 'none', background: 'none', cursor: 'pointer', color: '#c03a28', fontSize: 16, padding: '0 4px' }}>×</button>
                      </div>
                    </div>
                    {ex.exercise_type === 'quizcard_basic' && <QuizcardEditor ex={ex} onChange={updated => setExercises(exercises.map((e, j) => j === i ? updated : e))} />}
                    {ex.exercise_type === 'choice_word' && <ChoiceWordEditor ex={ex} onChange={updated => setExercises(exercises.map((e, j) => j === i ? updated : e))} />}
                    {ex.exercise_type === 'fill_blank' && <FillBlankEditor ex={ex} onChange={updated => setExercises(exercises.map((e, j) => j === i ? updated : e))} />}
                    {ex.exercise_type === 'matching' && <MatchingEditor ex={ex} onChange={updated => setExercises(exercises.map((e, j) => j === i ? updated : e))} />}
                  </div>
                );
              })}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
