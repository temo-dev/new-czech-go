'use client';
import { FormEvent, useEffect, useRef, useState } from 'react';
import AiImageButton from './AiImageButton';

type Course = {
  id: string;
  slug: string;
  title: string;
  description: string;
  status: string;
  sequence_no: number;
  banner_image_id?: string;
};

const API = '/api/admin/courses';

const CARD_COLORS = [
  { header: '#FF6A14', text: '#fff', badge: 'rgba(255,255,255,0.25)' },
  { header: '#0F3D3A', text: '#fff', badge: 'rgba(255,255,255,0.2)' },
  { header: '#3060B8', text: '#fff', badge: 'rgba(255,255,255,0.2)' },
  { header: '#C28012', text: '#fff', badge: 'rgba(255,255,255,0.2)' },
  { header: '#1F8A4D', text: '#fff', badge: 'rgba(255,255,255,0.2)' },
];

export function CourseDashboard() {
  const [courses, setCourses] = useState<Course[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [uploadingBanner, setUploadingBanner] = useState<string | null>(null);
  const bannerInputRefs = useRef<Record<string, HTMLInputElement | null>>({});
  const [form, setForm] = useState({
    title: '',
    description: '',
    status: 'draft',
    sequence_no: 1,
  });

  useEffect(() => { load(); }, []);

  async function handleBannerUpload(courseId: string, file: File) {
    setUploadingBanner(courseId);
    try {
      const formData = new FormData();
      formData.set('file', file);
      const res = await fetch(`/api/admin/courses/${courseId}/banner`, { method: 'POST', body: formData });
      if (res.ok) await load();
    } finally {
      setUploadingBanner(null);
    }
  }

  async function handleBannerDelete(courseId: string) {
    await fetch(`/api/admin/courses/${courseId}/banner`, { method: 'DELETE' });
    await load();
  }

  async function load() {
    setLoading(true);
    try {
      const res = await fetch(API);
      const j = await res.json();
      setCourses(j.data ?? []);
    } catch {
      setError('Failed to load courses.');
    } finally {
      setLoading(false);
    }
  }

  function openCreate() {
    setEditingId(null);
    setForm({ title: '', description: '', status: 'draft', sequence_no: courses.length + 1 });
    setShowForm(true);
  }
  function openEdit(c: Course) {
    setEditingId(c.id);
    setForm({ title: c.title, description: c.description, status: c.status, sequence_no: c.sequence_no });
    setShowForm(true);
  }
  function cancel() { setShowForm(false); setEditingId(null); setError(''); }

  async function submit(e: FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError('');
    try {
      const url = editingId ? `${API}/${editingId}` : API;
      const method = editingId ? 'PATCH' : 'POST';
      const res = await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(form),
      });
      if (!res.ok) throw new Error((await res.json()).error?.message ?? 'Save failed');
      await load();
      cancel();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
    } finally {
      setSaving(false);
    }
  }

  async function del(id: string) {
    if (!confirm('Delete this course?')) return;
    try { await fetch(`${API}/${id}`, { method: 'DELETE' }); await load(); }
    catch { setError('Delete failed'); }
  }

  if (loading) return <p style={{ padding: 24, color: 'var(--ink-3)' }}>Loading…</p>;

  return (
    <div>
      {/* Page header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: 24 }}>
        <div>
          <div className="eyebrow" style={{ marginBottom: 4 }}>NỘI DUNG</div>
          <h1 className="page-title">Khóa học</h1>
        </div>
        <button
          onClick={openCreate}
          className="btn btn-primary"
          style={{ display: 'flex', alignItems: 'center', gap: 6 }}
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round"><line x1="12" y1="5" x2="12" y2="19" /><line x1="5" y1="12" x2="19" y2="12" /></svg>
          Khóa học mới
        </button>
      </div>

      {error && (
        <div style={{ padding: '10px 14px', background: 'var(--error-bg)', color: 'var(--error)', borderRadius: 'var(--r2)', marginBottom: 16, fontSize: 13 }}>
          {error}
        </div>
      )}

      {/* Course grid */}
      {!showForm && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16 }}>
          {courses.length === 0 && (
            <p style={{ color: 'var(--ink-3)', gridColumn: '1/-1', padding: '32px 0', textAlign: 'center' }}>
              Chưa có khóa học nào.
            </p>
          )}
          {courses.map((c, i) => {
            const colors = CARD_COLORS[i % CARD_COLORS.length];
            const isPublished = c.status === 'published';
            return (
              <div
                key={c.id}
                className="card"
                style={{ cursor: 'pointer', transition: 'box-shadow 120ms ease' }}
                onMouseEnter={e => (e.currentTarget.style.boxShadow = 'var(--shadow-md)')}
                onMouseLeave={e => (e.currentTarget.style.boxShadow = 'var(--shadow-sm)')}
              >
                {/* Banner header — shows uploaded image or solid color */}
                <div style={{
                  height: 96,
                  background: c.banner_image_id ? 'transparent' : colors.header,
                  borderRadius: 'var(--r3) var(--r3) 0 0',
                  display: 'flex',
                  alignItems: 'flex-end',
                  padding: '12px 16px',
                  position: 'relative',
                  overflow: 'hidden',
                }}>
                  {c.banner_image_id && (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={`/api/media/file?key=${encodeURIComponent(c.banner_image_id)}`}
                      alt="banner"
                      style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover', borderRadius: 'var(--r3) var(--r3) 0 0' }}
                    />
                  )}
                  {/* Overlay for text legibility */}
                  <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(to top, rgba(0,0,0,0.5) 0%, transparent 60%)', borderRadius: 'var(--r3) var(--r3) 0 0' }} />
                  <div style={{ position: 'relative', display: 'flex', alignItems: 'center', gap: 8, width: '100%' }}>
                    <span style={{
                      fontSize: 10, fontWeight: 700, letterSpacing: 0.6, textTransform: 'uppercase',
                      background: c.banner_image_id ? 'rgba(0,0,0,0.35)' : colors.badge,
                      color: '#fff',
                      padding: '3px 9px', borderRadius: 999,
                    }}>
                      #{c.sequence_no} · {c.status}
                    </span>
                    <label style={{ marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: 4, background: 'rgba(0,0,0,0.35)', color: '#fff', borderRadius: 6, padding: '3px 8px', cursor: 'pointer', fontSize: 10, fontWeight: 600, whiteSpace: 'nowrap' }}>
                      {uploadingBanner === c.id ? '⏳' : c.banner_image_id ? '🔄 Banner' : '🖼 Banner'}
                      <input
                        ref={el => { bannerInputRefs.current[c.id] = el; }}
                        type="file" accept="image/jpeg,image/png,image/webp" style={{ display: 'none' }}
                        disabled={uploadingBanner !== null}
                        onChange={e => { const f = e.target.files?.[0]; if (f) void handleBannerUpload(c.id, f); e.target.value = ''; }}
                      />
                    </label>
                    {c.banner_image_id && (
                      <button type="button" onClick={() => void handleBannerDelete(c.id)} style={{ background: 'rgba(0,0,0,0.35)', color: '#fff', border: 'none', borderRadius: 6, padding: '3px 8px', cursor: 'pointer', fontSize: 10, fontWeight: 600 }}>✕</button>
                    )}
                  </div>
                </div>

                {/* Card body */}
                <div className="card-padded">
                  <div style={{ fontWeight: 700, fontSize: 15, color: 'var(--ink)', marginBottom: 4, lineHeight: 1.3 }}>
                    {c.title}
                  </div>
                  {c.description && (
                    <div style={{ fontSize: 12.5, color: 'var(--ink-3)', marginBottom: 12, lineHeight: 1.5, display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>
                      {c.description}
                    </div>
                  )}

                  {/* Status badge */}
                  <span className={`badge ${isPublished ? 'badge-ready' : 'badge-neutral'}`}>
                    {isPublished ? 'Đang chạy' : 'Nháp'}
                  </span>
                </div>

                {/* Actions footer */}
                <div style={{
                  padding: '10px 16px',
                  borderTop: '1px solid var(--border)',
                  display: 'grid',
                  gap: 8,
                }}>
                  <AiImageButton
                    onAssetCreated={async result => {
                      await fetch('/api/admin/ai/set-banner', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ entity_type: 'course', entity_id: c.id, storage_key: result.storageKey }),
                      });
                      await load();
                    }}
                    disabled={false}
                    existingAssetId={c.banner_image_id}
                  />
                  <div style={{ display: 'flex', gap: 8 }}>
                    <button onClick={() => openEdit(c)} className="btn btn-ghost" style={{ flex: 1, justifyContent: 'center', fontSize: 12, padding: '6px 0' }}>
                      Chỉnh sửa
                    </button>
                    <button onClick={() => del(c.id)} className="btn btn-danger" style={{ fontSize: 12, padding: '6px 12px' }}>
                      Xoá
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Create / Edit form */}
      {showForm && (
        <div className="card" style={{ maxWidth: 560 }}>
          <div className="card-padded" style={{ borderBottom: '1px solid var(--border)' }}>
            <h2 style={{ margin: 0, fontSize: 18, fontFamily: 'Fraunces, serif' }}>
              {editingId ? 'Chỉnh sửa khóa học' : 'Khóa học mới'}
            </h2>
          </div>
          <form onSubmit={submit} className="card-padded">
            <div style={{ marginBottom: 14 }}>
              <label style={{ display: 'block', fontSize: 12, fontWeight: 600, color: 'var(--ink-2)', marginBottom: 5, textTransform: 'uppercase', letterSpacing: 0.4 }}>
                Tiêu đề *
              </label>
              <input
                required
                type="text"
                value={form.title}
                onChange={e => setForm(f => ({ ...f, title: e.target.value }))}
              />
            </div>
            <div style={{ marginBottom: 14 }}>
              <label style={{ display: 'block', fontSize: 12, fontWeight: 600, color: 'var(--ink-2)', marginBottom: 5, textTransform: 'uppercase', letterSpacing: 0.4 }}>
                Mô tả
              </label>
              <textarea
                value={form.description}
                onChange={e => setForm(f => ({ ...f, description: e.target.value }))}
                rows={3}
              />
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 14 }}>
              <div>
                <label style={{ display: 'block', fontSize: 12, fontWeight: 600, color: 'var(--ink-2)', marginBottom: 5, textTransform: 'uppercase', letterSpacing: 0.4 }}>
                  Thứ tự
                </label>
                <input
                  type="number"
                  min={1}
                  value={form.sequence_no}
                  onChange={e => setForm(f => ({ ...f, sequence_no: parseInt(e.target.value) || 1 }))}
                />
              </div>
              <div>
                <label style={{ display: 'block', fontSize: 12, fontWeight: 600, color: 'var(--ink-2)', marginBottom: 5, textTransform: 'uppercase', letterSpacing: 0.4 }}>
                  Trạng thái
                </label>
                <select
                  value={form.status}
                  onChange={e => setForm(f => ({ ...f, status: e.target.value }))}
                >
                  <option value="draft">Nháp</option>
                  <option value="published">Đã xuất bản</option>
                </select>
              </div>
            </div>
            {/* Banner image upload — only for saved courses */}
            {editingId && (() => {
              const course = courses.find(c => c.id === editingId);
              const hasBanner = !!course?.banner_image_id;
              return (
                <div>
                  <label style={{ display: 'block', fontSize: 12, fontWeight: 600, color: 'var(--ink-2)', marginBottom: 8, textTransform: 'uppercase', letterSpacing: 0.4 }}>
                    Ảnh banner
                  </label>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                    {hasBanner && course?.banner_image_id && (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img
                        src={`/api/media/file?key=${encodeURIComponent(course.banner_image_id)}`}
                        alt="banner preview"
                        style={{ width: 80, height: 52, objectFit: 'cover', borderRadius: 8, border: '1px solid var(--border)' }}
                      />
                    )}
                    <label style={{ display: 'flex', alignItems: 'center', gap: 6, border: `1px ${hasBanner ? 'solid #22c55e' : 'dashed var(--border)'}`, borderRadius: 8, padding: '7px 14px', cursor: 'pointer', fontSize: 13, fontWeight: 600, color: hasBanner ? '#15803d' : 'var(--ink-3)', background: hasBanner ? '#f0fdf4' : 'var(--surface-alt)' }}>
                      {uploadingBanner === editingId ? '⏳ Đang tải...' : hasBanner ? '🔄 Đổi banner' : '🖼 Tải banner lên'}
                      <input type="file" accept="image/jpeg,image/png,image/webp" style={{ display: 'none' }}
                        disabled={uploadingBanner !== null}
                        onChange={e => { const f = e.target.files?.[0]; if (f && editingId) void handleBannerUpload(editingId, f); e.target.value = ''; }} />
                    </label>
                    {hasBanner && editingId && (
                      <button type="button" onClick={() => void handleBannerDelete(editingId)}
                        style={{ border: '1px solid var(--border)', borderRadius: 8, padding: '7px 12px', cursor: 'pointer', fontSize: 13, background: 'transparent', color: 'var(--danger)' }}>
                        Xóa
                      </button>
                    )}
                  </div>
                </div>
              );
            })()}

            {!editingId && (
              <p style={{ fontSize: 12, color: 'var(--ink-4)', margin: '0 0 4px' }}>
                Tạo khóa học trước, sau đó upload banner ảnh.
              </p>
            )}

            {error && (
              <div style={{ color: 'var(--error)', fontSize: 13, marginBottom: 12 }}>{error}</div>
            )}
            <div style={{ display: 'flex', gap: 8 }}>
              <button type="submit" disabled={saving} className="btn btn-primary">
                {saving ? 'Đang lưu…' : editingId ? 'Lưu' : 'Tạo mới'}
              </button>
              <button type="button" onClick={cancel} className="btn btn-ghost">
                Huỷ
              </button>
            </div>
          </form>
        </div>
      )}
    </div>
  );
}
