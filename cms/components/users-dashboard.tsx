'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import {
  CEFR_LEVELS,
  canRaiseLevel,
  isCefrLevel,
  labelForLevel,
  nextCefrLevel,
  type CefrLevel,
} from '../lib/level';

type AdminUser = {
  id: string;
  email: string;
  email_verified: boolean;
  display_name: string;
  role: string;
  pro_tier: string;
  pro_expires_at?: string;
  current_level: string;
  unlocked_levels: string[];
  grace_attempts_left: number;
  attempts_today: number;
  attempts_cap: number;
  created_at: string;
  updated_at: string;
};

type ListResponse = {
  data: AdminUser[];
  meta: { total: number; limit: number; offset: number };
};

const PAGE_SIZE = 50;

function fmtDate(iso: string): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (isNaN(d.getTime())) return '—';
  return d.toLocaleString();
}

export function UsersDashboard() {
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [total, setTotal] = useState(0);
  const [offset, setOffset] = useState(0);
  const [search, setSearch] = useState('');
  const [searchInput, setSearchInput] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [confirmId, setConfirmId] = useState<string | null>(null);
  const [deleting, setDeleting] = useState(false);
  const [resetId, setResetId] = useState<string | null>(null);
  const [resetUsageId, setResetUsageId] = useState<string | null>(null);
  const [resettingUsage, setResettingUsage] = useState(false);
  const [levelId, setLevelId] = useState<string | null>(null);
  const [proId, setProId] = useState<string | null>(null);

  useEffect(() => { void load(offset, search); }, [offset, search]);

  async function load(off: number, q: string) {
    setLoading(true);
    setError('');
    try {
      const params = new URLSearchParams();
      params.set('limit', String(PAGE_SIZE));
      params.set('offset', String(off));
      if (q.trim()) params.set('search', q.trim());
      const res = await fetch(`/api/admin/users?${params.toString()}`);
      const j: ListResponse = await res.json();
      if (!res.ok) {
        const msg = (j as unknown as { error?: { message?: string } | string })?.error;
        throw new Error(typeof msg === 'string' ? msg : (msg?.message ?? 'Load failed'));
      }
      setUsers(j.data ?? []);
      setTotal(j.meta?.total ?? 0);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
    } finally {
      setLoading(false);
    }
  }

  async function handleDelete(id: string) {
    setDeleting(true);
    setError('');
    try {
      const res = await fetch(`/api/admin/users/${encodeURIComponent(id)}`, { method: 'DELETE' });
      if (res.status !== 204 && !res.ok) {
        const j = await res.json().catch(() => ({}));
        const msg = (j as { message?: string })?.message ?? `Delete failed (${res.status})`;
        throw new Error(msg);
      }
      setConfirmId(null);
      // reload current page; if last item on page just deleted, step back
      const nextOffset = users.length === 1 && offset > 0 ? Math.max(0, offset - PAGE_SIZE) : offset;
      setOffset(nextOffset);
      if (nextOffset === offset) await load(offset, search);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
    } finally {
      setDeleting(false);
    }
  }

  async function handleResetUsage(id: string) {
    setResettingUsage(true);
    setError('');
    try {
      const res = await fetch(`/api/admin/users/${encodeURIComponent(id)}/usage/reset`, { method: 'POST' });
      if (res.status !== 204 && !res.ok) {
        const j = await res.json().catch(() => ({}));
        const msg = (j as { message?: string })?.message ?? `Reset failed (${res.status})`;
        throw new Error(msg);
      }
      setResetUsageId(null);
      await load(offset, search);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
    } finally {
      setResettingUsage(false);
    }
  }

  function submitSearch(e: React.FormEvent) {
    e.preventDefault();
    setOffset(0);
    setSearch(searchInput);
  }

  const confirmTarget = confirmId ? users.find(u => u.id === confirmId) ?? null : null;
  const resetTarget = resetId ? users.find(u => u.id === resetId) ?? null : null;
  const resetUsageTarget = resetUsageId ? users.find(u => u.id === resetUsageId) ?? null : null;
  const levelTarget = levelId ? users.find(u => u.id === levelId) ?? null : null;
  const proTarget = proId ? users.find(u => u.id === proId) ?? null : null;
  const pageEnd = Math.min(offset + users.length, total);

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: 24 }}>
        <div>
          <div className="eyebrow" style={{ marginBottom: 4 }}>QUẢN LÝ</div>
          <h1 className="page-title">Tài khoản</h1>
        </div>
        <button onClick={() => load(offset, search)} className="btn btn-ghost" style={{ fontSize: 12 }}>
          Làm mới
        </button>
      </div>

      <form onSubmit={submitSearch} style={{ display: 'flex', gap: 8, marginBottom: 20 }}>
        <input
          type="search"
          value={searchInput}
          onChange={e => setSearchInput(e.target.value)}
          placeholder="Tìm theo email hoặc tên…"
          style={{
            flex: 1, maxWidth: 400, padding: '8px 12px',
            borderRadius: 'var(--r2)', border: '1px solid var(--border-strong)',
            fontSize: 13,
          }}
        />
        <button type="submit" className="btn btn-primary" style={{ fontSize: 13 }}>Tìm</button>
        {search && (
          <button
            type="button"
            onClick={() => { setSearchInput(''); setSearch(''); setOffset(0); }}
            className="btn btn-ghost"
            style={{ fontSize: 13 }}
          >
            Xóa lọc
          </button>
        )}
      </form>

      {error && (
        <div style={{
          padding: '10px 14px', background: 'var(--error-bg)', color: 'var(--error)',
          borderRadius: 'var(--r2)', marginBottom: 16, fontSize: 13,
        }}>
          {error}
        </div>
      )}

      {loading ? (
        <p style={{ padding: 24, color: 'var(--ink-3)' }}>Đang tải…</p>
      ) : users.length === 0 ? (
        <p style={{ color: 'var(--ink-3)', textAlign: 'center', padding: '40px 0' }}>
          {search ? 'Không có tài khoản phù hợp.' : 'Chưa có tài khoản.'}
        </p>
      ) : (
        <div className="card" style={{ overflow: 'hidden' }}>
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
              <thead>
                <tr style={{ background: 'var(--surface-alt)' }}>
                  {['Email', 'Tên', 'Vai trò', 'Level', 'Pro', 'Verified', 'Hôm nay', 'Tạo lúc', ''].map(h => (
                    <th key={h} style={{
                      padding: '10px 14px', textAlign: 'left',
                      fontWeight: 600, fontSize: 11, color: 'var(--ink-3)',
                      textTransform: 'uppercase', letterSpacing: 0.4, whiteSpace: 'nowrap',
                    }}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {users.map((u, i) => (
                  <tr key={u.id} style={{ borderTop: i > 0 ? '1px solid var(--border)' : undefined }}>
                    <td style={{ padding: '10px 14px', fontFamily: 'monospace', fontSize: 12 }}>
                      <Link
                        href={`/users/${u.id}`}
                        style={{ color: 'var(--ink)', textDecoration: 'none' }}
                        title="Xem chi tiết X-Ray"
                      >
                        {u.email}
                      </Link>
                    </td>
                    <td style={{ padding: '10px 14px' }}>{u.display_name || '—'}</td>
                    <td style={{ padding: '10px 14px' }}>
                      <span className={`badge ${u.role === 'admin' ? 'badge-error' : 'badge-neutral'}`}>{u.role}</span>
                    </td>
                    <td style={{ padding: '10px 14px' }}>
                      <span className="badge badge-neutral">{currentUserLevel(u).toUpperCase()}</span>
                    </td>
                    <td style={{ padding: '10px 14px' }}>
                      {u.pro_tier === 'pro' ? (
                        <span className="badge badge-ready">PRO</span>
                      ) : (
                        <span style={{ color: 'var(--ink-3)' }}>free</span>
                      )}
                    </td>
                    <td style={{ padding: '10px 14px' }}>
                      {u.email_verified ? (
                        <span style={{ color: 'var(--ready)' }}>✓</span>
                      ) : (
                        <span style={{ color: 'var(--ink-4)' }}>—</span>
                      )}
                    </td>
                    <td style={{ padding: '10px 14px', fontSize: 12 }}>
                      {u.pro_tier === 'pro' ? (
                        <span style={{ color: 'var(--ink-4)' }}>∞</span>
                      ) : (
                        <span style={{
                          fontFamily: 'monospace',
                          color: u.attempts_today >= u.attempts_cap ? 'var(--error)' : 'var(--ink-2)',
                          fontWeight: u.attempts_today >= u.attempts_cap ? 700 : 400,
                        }}>
                          {u.attempts_today}/{u.attempts_cap}
                        </span>
                      )}
                    </td>
                    <td style={{ padding: '10px 14px', color: 'var(--ink-3)', fontSize: 12 }}>{fmtDate(u.created_at)}</td>
                    <td style={{ padding: '10px 14px', textAlign: 'right' }}>
                      {u.role === 'admin' ? (
                        <span style={{ fontSize: 11, color: 'var(--ink-4)' }}>—</span>
                      ) : (
                        <div style={{ display: 'flex', gap: 6, justifyContent: 'flex-end' }}>
                          {u.pro_tier !== 'pro' && u.attempts_today > 0 && (
                            <button
                              onClick={() => setResetUsageId(u.id)}
                              className="btn btn-ghost"
                              style={{ fontSize: 12 }}
                            >
                              Reset usage
                            </button>
                          )}
                          <button
                            onClick={() => setLevelId(u.id)}
                            className="btn btn-ghost"
                            style={{ fontSize: 12 }}
                          >
                            Nâng level
                          </button>
                          <button
                            onClick={() => setProId(u.id)}
                            className="btn btn-ghost"
                            style={{ fontSize: 12 }}
                          >
                            {u.pro_tier === 'pro' ? 'Quản lý Pro' : 'Nâng cấp Pro'}
                          </button>
                          <button
                            onClick={() => setResetId(u.id)}
                            className="btn btn-ghost"
                            style={{ fontSize: 12 }}
                          >
                            Đặt lại MK
                          </button>
                          <button
                            onClick={() => setConfirmId(u.id)}
                            className="btn btn-ghost"
                            style={{ fontSize: 12, color: 'var(--error)' }}
                          >
                            Xóa
                          </button>
                        </div>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div style={{
            padding: '10px 14px', borderTop: '1px solid var(--border)',
            display: 'flex', justifyContent: 'space-between', alignItems: 'center',
            fontSize: 12, color: 'var(--ink-3)',
          }}>
            <span>{offset + 1}–{pageEnd} / {total}</span>
            <div style={{ display: 'flex', gap: 8 }}>
              <button
                disabled={offset === 0}
                onClick={() => setOffset(Math.max(0, offset - PAGE_SIZE))}
                className="btn btn-ghost"
                style={{ fontSize: 12 }}
              >
                ← Trước
              </button>
              <button
                disabled={offset + users.length >= total}
                onClick={() => setOffset(offset + PAGE_SIZE)}
                className="btn btn-ghost"
                style={{ fontSize: 12 }}
              >
                Sau →
              </button>
            </div>
          </div>
        </div>
      )}

      {confirmTarget && (
        <ConfirmDelete
          user={confirmTarget}
          busy={deleting}
          onCancel={() => setConfirmId(null)}
          onConfirm={() => handleDelete(confirmTarget.id)}
        />
      )}

      {resetTarget && (
        <ResetPassword
          user={resetTarget}
          onCancel={() => setResetId(null)}
          onDone={() => setResetId(null)}
        />
      )}

      {resetUsageTarget && (
        <ConfirmResetUsage
          user={resetUsageTarget}
          busy={resettingUsage}
          onCancel={() => setResetUsageId(null)}
          onConfirm={() => handleResetUsage(resetUsageTarget.id)}
        />
      )}

      {levelTarget && (
        <LevelDialog
          user={levelTarget}
          onCancel={() => setLevelId(null)}
          onDone={() => { setLevelId(null); void load(offset, search); }}
        />
      )}

      {proTarget && (
        <ProDialog
          user={proTarget}
          onCancel={() => setProId(null)}
          onDone={() => { setProId(null); void load(offset, search); }}
        />
      )}
    </div>
  );
}

function currentUserLevel(user: AdminUser): CefrLevel {
  return isCefrLevel(user.current_level) ? user.current_level : 'a0';
}

function unlockedLevelSummary(user: AdminUser): string {
  const levels = Array.isArray(user.unlocked_levels) && user.unlocked_levels.length > 0
    ? user.unlocked_levels
    : [currentUserLevel(user)];
  return levels.map(l => String(l).toUpperCase()).join(' · ');
}

function LevelDialog({
  user, onCancel, onDone,
}: { user: AdminUser; onCancel: () => void; onDone: () => void }) {
  const current = currentUserLevel(user);
  const initialTarget = nextCefrLevel(current) ?? current;
  const [targetLevel, setTargetLevel] = useState<CefrLevel>(initialTarget);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const isTopLevel = nextCefrLevel(current) === null;
  const canSubmit = !busy && targetLevel !== current && canRaiseLevel(current, targetLevel);

  async function submit() {
    if (!canSubmit) return;
    setBusy(true);
    setError('');
    try {
      const res = await fetch(`/api/admin/users/${encodeURIComponent(user.id)}/level`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ current_level: targetLevel }),
      });
      if (res.ok) { onDone(); return; }
      const j = await res.json().catch(() => ({}));
      const msg = (j as { error?: { message?: string } | string })?.error;
      const text = typeof msg === 'string' ? msg : (msg?.message ?? `Thất bại (${res.status})`);
      throw new Error(text);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div
      onClick={busy ? undefined : onCancel}
      style={{
        position: 'fixed', inset: 0, background: 'rgba(20,18,14,0.55)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        zIndex: 1000, padding: 20,
      }}
    >
      <div
        onClick={e => e.stopPropagation()}
        style={{
          background: 'var(--surface)', borderRadius: 'var(--r3)',
          padding: 28, maxWidth: 500, width: '100%',
          boxShadow: '0 12px 40px rgba(20,18,14,0.25)',
        }}
      >
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 12, color: 'var(--ink)' }}>
          Nâng level learner
        </h2>
        <p style={{ fontSize: 13, color: 'var(--ink-2)', lineHeight: 1.55, marginBottom: 12 }}>
          Tài khoản <strong>{user.email}</strong>{user.display_name ? ` (${user.display_name})` : ''}.
        </p>

        <div style={{
          display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12,
          marginBottom: 16,
        }}>
          <div style={{ padding: 12, border: '1px solid var(--border)', borderRadius: 'var(--r2)' }}>
            <div style={{ fontSize: 11, fontWeight: 600, color: 'var(--ink-3)', textTransform: 'uppercase' }}>
              Hiện tại
            </div>
            <div style={{ marginTop: 6 }}>
              <span className="badge badge-ready">{current.toUpperCase()}</span>
            </div>
          </div>
          <div style={{ padding: 12, border: '1px solid var(--border)', borderRadius: 'var(--r2)' }}>
            <div style={{ fontSize: 11, fontWeight: 600, color: 'var(--ink-3)', textTransform: 'uppercase' }}>
              Đã mở
            </div>
            <div style={{ marginTop: 6, fontSize: 12.5, fontFamily: 'monospace', color: 'var(--ink-2)' }}>
              {unlockedLevelSummary(user)}
            </div>
          </div>
        </div>

        <label style={{ display: 'block', marginBottom: 14 }}>
          <span style={{ fontSize: 12, fontWeight: 600, color: 'var(--ink-2)', display: 'block', marginBottom: 4 }}>
            Level mới
          </span>
          <select
            value={targetLevel}
            onChange={e => {
              if (isCefrLevel(e.target.value)) setTargetLevel(e.target.value);
            }}
            disabled={busy || isTopLevel}
          >
            {CEFR_LEVELS.map(level => (
              <option
                key={level}
                value={level}
                disabled={!canRaiseLevel(current, level)}
              >
                {labelForLevel(level)}
              </option>
            ))}
          </select>
        </label>

        <p style={{ fontSize: 12.5, color: 'var(--ink-3)', lineHeight: 1.55, marginBottom: 18 }}>
          {isTopLevel
            ? 'Learner đã ở level cao nhất hiện có.'
            : 'Thao tác này cập nhật current_level và thêm level mới vào unlocked_levels. Hạ level không được hỗ trợ từ CMS.'}
        </p>

        {error && (
          <div style={{
            padding: '10px 12px', background: 'var(--error-bg)', color: 'var(--error)',
            borderRadius: 'var(--r2)', marginBottom: 16, fontSize: 12.5,
          }}>
            {error}
          </div>
        )}

        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10 }}>
          <button onClick={onCancel} className="btn btn-ghost" disabled={busy}>Hủy</button>
          <button
            onClick={submit}
            disabled={!canSubmit}
            className="btn btn-primary"
          >
            {busy ? 'Đang nâng…' : `Nâng lên ${targetLevel.toUpperCase()}`}
          </button>
        </div>
      </div>
    </div>
  );
}

function ConfirmResetUsage({
  user, busy, onCancel, onConfirm,
}: { user: AdminUser; busy: boolean; onCancel: () => void; onConfirm: () => void }) {
  return (
    <div
      onClick={busy ? undefined : onCancel}
      style={{
        position: 'fixed', inset: 0, background: 'rgba(20,18,14,0.55)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        zIndex: 1000, padding: 20,
      }}
    >
      <div
        onClick={e => e.stopPropagation()}
        style={{
          background: 'var(--surface)', borderRadius: 'var(--r3)',
          padding: 28, maxWidth: 480, width: '100%',
          boxShadow: '0 12px 40px rgba(20,18,14,0.25)',
        }}
      >
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 12, color: 'var(--ink)' }}>
          Reset usage hôm nay?
        </h2>
        <p style={{ fontSize: 13.5, color: 'var(--ink-2)', lineHeight: 1.55, marginBottom: 8 }}>
          Tài khoản <strong>{user.email}</strong>{user.display_name ? ` (${user.display_name})` : ''} hiện
          dùng <strong>{user.attempts_today}/{user.attempts_cap}</strong> lượt luyện hôm nay.
        </p>
        <p style={{ fontSize: 12.5, color: 'var(--ink-3)', marginBottom: 24 }}>
          Reset sẽ đưa attempts_count về 0 cho ngày hôm nay (giờ VN). Counter interview giữ nguyên.
        </p>
        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10 }}>
          <button onClick={onCancel} className="btn btn-ghost" disabled={busy}>Hủy</button>
          <button
            onClick={onConfirm}
            disabled={busy}
            className="btn btn-primary"
          >
            {busy ? 'Đang reset…' : 'Reset usage'}
          </button>
        </div>
      </div>
    </div>
  );
}

function ResetPassword({ user, onCancel, onDone }: { user: AdminUser; onCancel: () => void; onDone: () => void }) {
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [done, setDone] = useState(false);

  const tooShort = password.length > 0 && password.length < 8;
  const noNumberOrSymbol = password.length >= 8 && !/[^A-Za-zÀ-ÿĀ-žẠ-ỹ]/.test(password);
  const mismatch = confirm.length > 0 && password !== confirm;
  const canSubmit = !busy && password.length >= 8 && !noNumberOrSymbol && password === confirm;

  async function handleSubmit() {
    if (!canSubmit) return;
    setBusy(true);
    setError('');
    try {
      const res = await fetch(`/api/admin/users/${encodeURIComponent(user.id)}/reset-password`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ new_password: password }),
      });
      if (res.status === 204) {
        setDone(true);
        return;
      }
      const j = await res.json().catch(() => ({}));
      const msg = (j as { message?: string })?.message ?? `Reset failed (${res.status})`;
      throw new Error(msg);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div
      onClick={busy ? undefined : onCancel}
      style={{
        position: 'fixed', inset: 0, background: 'rgba(20,18,14,0.55)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        zIndex: 1000, padding: 20,
      }}
    >
      <div
        onClick={e => e.stopPropagation()}
        style={{
          background: 'var(--surface)', borderRadius: 'var(--r3)',
          padding: 28, maxWidth: 480, width: '100%',
          boxShadow: '0 12px 40px rgba(20,18,14,0.25)',
        }}
      >
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 12, color: 'var(--ink)' }}>
          Đặt lại mật khẩu
        </h2>
        <p style={{ fontSize: 13, color: 'var(--ink-2)', lineHeight: 1.55, marginBottom: 16 }}>
          Tài khoản <strong>{user.email}</strong>{user.display_name ? ` (${user.display_name})` : ''}.
          Mọi phiên đăng nhập sẽ bị huỷ; học viên cần đăng nhập lại bằng mật khẩu mới.
        </p>

        {done ? (
          <>
            <div style={{
              padding: '12px 14px', background: 'var(--success-bg, #e8f5ec)',
              color: 'var(--success, #0f6e3a)', borderRadius: 'var(--r2)',
              marginBottom: 16, fontSize: 13,
            }}>
              ✓ Đã đặt lại. Hãy chuyển mật khẩu mới cho học viên qua kênh an toàn.
            </div>
            <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
              <button onClick={onDone} className="btn btn-primary">Đóng</button>
            </div>
          </>
        ) : (
          <>
            <label style={{ display: 'block', marginBottom: 14 }}>
              <span style={{ fontSize: 12, fontWeight: 600, color: 'var(--ink-2)', display: 'block', marginBottom: 4 }}>
                Mật khẩu mới
              </span>
              <input
                type="text"
                value={password}
                onChange={e => setPassword(e.target.value)}
                autoFocus
                disabled={busy}
                placeholder="Tối thiểu 8 ký tự + 1 số/đặc biệt"
                style={{
                  width: '100%', padding: '8px 12px',
                  borderRadius: 'var(--r2)', border: '1px solid var(--border-strong)',
                  fontSize: 13, fontFamily: 'monospace',
                }}
              />
            </label>

            <label style={{ display: 'block', marginBottom: 8 }}>
              <span style={{ fontSize: 12, fontWeight: 600, color: 'var(--ink-2)', display: 'block', marginBottom: 4 }}>
                Nhập lại
              </span>
              <input
                type="text"
                value={confirm}
                onChange={e => setConfirm(e.target.value)}
                disabled={busy}
                style={{
                  width: '100%', padding: '8px 12px',
                  borderRadius: 'var(--r2)', border: '1px solid var(--border-strong)',
                  fontSize: 13, fontFamily: 'monospace',
                }}
              />
            </label>

            <div style={{ minHeight: 18, marginBottom: 14, fontSize: 12 }}>
              {tooShort && <span style={{ color: 'var(--error)' }}>Cần ít nhất 8 ký tự.</span>}
              {noNumberOrSymbol && <span style={{ color: 'var(--error)' }}>Cần ít nhất 1 chữ số hoặc ký tự đặc biệt.</span>}
              {mismatch && <span style={{ color: 'var(--error)' }}>Hai ô không khớp.</span>}
            </div>

            {error && (
              <div style={{
                padding: '10px 12px', background: 'var(--error-bg)', color: 'var(--error)',
                borderRadius: 'var(--r2)', marginBottom: 16, fontSize: 12.5,
              }}>
                {error}
              </div>
            )}

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10 }}>
              <button onClick={onCancel} className="btn btn-ghost" disabled={busy}>Hủy</button>
              <button
                onClick={handleSubmit}
                disabled={!canSubmit}
                className="btn btn-primary"
              >
                {busy ? 'Đang đặt lại…' : 'Đặt lại mật khẩu'}
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

function ConfirmDelete({
  user, busy, onCancel, onConfirm,
}: { user: AdminUser; busy: boolean; onCancel: () => void; onConfirm: () => void }) {
  return (
    <div
      onClick={onCancel}
      style={{
        position: 'fixed', inset: 0, background: 'rgba(20,18,14,0.55)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        zIndex: 1000, padding: 20,
      }}
    >
      <div
        onClick={e => e.stopPropagation()}
        style={{
          background: 'var(--surface)', borderRadius: 'var(--r3)',
          padding: 28, maxWidth: 480, width: '100%',
          boxShadow: '0 12px 40px rgba(20,18,14,0.25)',
        }}
      >
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 12, color: 'var(--ink)' }}>
          Xóa tài khoản?
        </h2>
        <p style={{ fontSize: 13.5, color: 'var(--ink-2)', lineHeight: 1.55, marginBottom: 8 }}>
          Tài khoản <strong>{user.email}</strong>{user.display_name ? ` (${user.display_name})` : ''} sẽ bị
          ẩn danh hóa và đăng xuất khỏi mọi thiết bị. Email được giải phóng để đăng ký lại.
        </p>
        <p style={{ fontSize: 12.5, color: 'var(--ink-3)', marginBottom: 24 }}>
          Lịch sử attempts vẫn giữ để phục vụ audit (soft-delete).
        </p>
        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10 }}>
          <button onClick={onCancel} className="btn btn-ghost" disabled={busy}>Hủy</button>
          <button
            onClick={onConfirm}
            disabled={busy}
            className="btn"
            style={{ background: 'var(--error)', color: '#fff' }}
          >
            {busy ? 'Đang xóa…' : 'Xóa vĩnh viễn'}
          </button>
        </div>
      </div>
    </div>
  );
}

const PRO_PRESETS: Array<{ days: number; label: string }> = [
  { days: 30, label: '30 ngày' },
  { days: 90, label: '90 ngày' },
  { days: 365, label: '1 năm' },
];

function fmtExpiry(iso?: string): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (isNaN(d.getTime())) return '—';
  return d.toLocaleDateString('vi-VN', { day: '2-digit', month: '2-digit', year: 'numeric' });
}

function ProDialog({
  user, onCancel, onDone,
}: { user: AdminUser; onCancel: () => void; onDone: () => void }) {
  const [customDays, setCustomDays] = useState('');
  const [confirmDowngrade, setConfirmDowngrade] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const isPro = user.pro_tier === 'pro';
  const customDaysNum = customDays.trim() === '' ? NaN : Number(customDays);
  const customValid = !isNaN(customDaysNum) && Number.isInteger(customDaysNum) &&
    customDaysNum > 0 && customDaysNum <= 3650;

  async function submit(durationDays: number) {
    setBusy(true);
    setError('');
    try {
      const res = await fetch(`/api/admin/users/${encodeURIComponent(user.id)}/pro`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ duration_days: durationDays }),
      });
      if (res.ok) { onDone(); return; }
      const j = await res.json().catch(() => ({}));
      const msg = (j as { error?: { message?: string } | string })?.error;
      const text = typeof msg === 'string' ? msg : (msg?.message ?? `Thất bại (${res.status})`);
      throw new Error(text);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div
      onClick={busy ? undefined : onCancel}
      style={{
        position: 'fixed', inset: 0, background: 'rgba(20,18,14,0.55)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        zIndex: 1000, padding: 20,
      }}
    >
      <div
        onClick={e => e.stopPropagation()}
        style={{
          background: 'var(--surface)', borderRadius: 'var(--r3)',
          padding: 28, maxWidth: 520, width: '100%',
          boxShadow: '0 12px 40px rgba(20,18,14,0.25)',
        }}
      >
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 12, color: 'var(--ink)' }}>
          {isPro ? 'Quản lý Pro' : 'Nâng cấp Pro'}
        </h2>
        <p style={{ fontSize: 13, color: 'var(--ink-2)', lineHeight: 1.55, marginBottom: 6 }}>
          Tài khoản <strong>{user.email}</strong>{user.display_name ? ` (${user.display_name})` : ''}.
        </p>
        <p style={{ fontSize: 12.5, color: 'var(--ink-3)', marginBottom: 18 }}>
          Trạng thái: {isPro ? (
            <>
              <span className="badge badge-ready" style={{ marginRight: 6 }}>PRO</span>
              hết hạn <strong>{fmtExpiry(user.pro_expires_at)}</strong>. Cộng dồn sẽ kéo dài từ ngày hết hạn hiện tại.
            </>
          ) : <>Free. Nâng cấp sẽ kích hoạt Pro ngay từ bây giờ.</>}
        </p>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginBottom: 18 }}>
          <div style={{ fontSize: 12, fontWeight: 600, color: 'var(--ink-2)' }}>Chọn thời lượng</div>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            {PRO_PRESETS.map(p => (
              <button
                key={p.days}
                onClick={() => submit(p.days)}
                disabled={busy}
                className="btn btn-primary"
                style={{ fontSize: 13 }}
              >
                {p.label}
              </button>
            ))}
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <input
              type="number"
              min={1}
              max={3650}
              step={1}
              value={customDays}
              onChange={e => setCustomDays(e.target.value)}
              placeholder="Số ngày tự nhập"
              disabled={busy}
              style={{
                width: 180, padding: '8px 12px',
                borderRadius: 'var(--r2)', border: '1px solid var(--border-strong)',
                fontSize: 13,
              }}
            />
            <button
              onClick={() => submit(customDaysNum)}
              disabled={busy || !customValid}
              className="btn btn-ghost"
              style={{ fontSize: 13 }}
            >
              Áp dụng
            </button>
          </div>
          {customDays && !customValid && (
            <span style={{ fontSize: 12, color: 'var(--error)' }}>Nhập số nguyên 1–3650.</span>
          )}
        </div>

        {isPro && (
          <div style={{ borderTop: '1px solid var(--border)', paddingTop: 16, marginBottom: 18 }}>
            <div style={{ fontSize: 12, fontWeight: 600, color: 'var(--ink-2)', marginBottom: 8 }}>
              Hạ về free
            </div>
            {confirmDowngrade ? (
              <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
                <span style={{ fontSize: 12.5, color: 'var(--ink-2)' }}>
                  Xác nhận hạ <strong>{user.email}</strong> về free? Pro mất hiệu lực ngay.
                </span>
                <button
                  onClick={() => submit(0)}
                  disabled={busy}
                  className="btn"
                  style={{ fontSize: 12, background: 'var(--error)', color: '#fff' }}
                >
                  {busy ? 'Đang hạ…' : 'Xác nhận hạ'}
                </button>
                <button
                  onClick={() => setConfirmDowngrade(false)}
                  disabled={busy}
                  className="btn btn-ghost"
                  style={{ fontSize: 12 }}
                >
                  Hủy
                </button>
              </div>
            ) : (
              <button
                onClick={() => setConfirmDowngrade(true)}
                disabled={busy}
                className="btn btn-ghost"
                style={{ fontSize: 12, color: 'var(--error)' }}
              >
                Hạ về free
              </button>
            )}
          </div>
        )}

        {error && (
          <div style={{
            padding: '10px 12px', background: 'var(--error-bg)', color: 'var(--error)',
            borderRadius: 'var(--r2)', marginBottom: 16, fontSize: 12.5,
          }}>
            {error}
          </div>
        )}

        <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
          <button onClick={onCancel} className="btn btn-ghost" disabled={busy}>Đóng</button>
        </div>
      </div>
    </div>
  );
}
