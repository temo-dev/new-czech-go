'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import {
  formatDate,
  formatDateTime,
  formatLevelLabel,
  formatMasteryScore,
  passedVariant,
  readinessLabel,
  summarizeUnlockedLevels,
  type LearnerStateResponse,
  type XRayState,
} from './learner-xray-utils';

type Props = { userId: string };

export function LearnerXRay({ userId }: Props) {
  const [state, setState] = useState<XRayState>({ kind: 'loading' });
  const [resetBusy, setResetBusy] = useState(false);
  const [resetError, setResetError] = useState('');

  async function load() {
    setState({ kind: 'loading' });
    try {
      const res = await fetch(`/api/admin/users/${encodeURIComponent(userId)}/state`, {
        method: 'GET',
        cache: 'no-store',
      });
      if (res.status === 404) {
        setState({ kind: 'not-found' });
        return;
      }
      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        const msg = (body as { message?: string })?.message ?? `Lỗi tải dữ liệu (${res.status})`;
        setState({ kind: 'error', message: msg });
        return;
      }
      const data = (await res.json()) as LearnerStateResponse;
      setState({ kind: 'ready', data });
    } catch (err) {
      setState({ kind: 'error', message: err instanceof Error ? err.message : 'Lỗi không xác định' });
    }
  }

  useEffect(() => {
    void load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userId]);

  async function handleResetUsage() {
    if (state.kind !== 'ready') return;
    if (!window.confirm(`Reset usage hôm nay cho ${state.data.user.email}?`)) return;
    setResetBusy(true);
    setResetError('');
    try {
      const res = await fetch(`/api/admin/users/${encodeURIComponent(userId)}/usage/reset`, {
        method: 'POST',
      });
      if (res.status !== 204) {
        const body = await res.json().catch(() => ({}));
        const msg = (body as { message?: string })?.message ?? `Reset failed (${res.status})`;
        throw new Error(msg);
      }
      await load();
    } catch (err) {
      setResetError(err instanceof Error ? err.message : 'Lỗi không xác định');
    } finally {
      setResetBusy(false);
    }
  }

  return (
    <div>
      <Header email={state.kind === 'ready' ? state.data.user.email : undefined} />

      {state.kind === 'loading' && (
        <p style={{ padding: 24, color: 'var(--ink-3)' }}>Đang tải…</p>
      )}

      {state.kind === 'error' && (
        <ErrorBlock message={state.message} onRetry={load} />
      )}

      {state.kind === 'not-found' && <NotFoundBlock />}

      {state.kind === 'ready' && (
        <>
          <SectionGrid>
            <ProfileCard user={state.data.user} />
            <CefrCard
              level={state.data.level_state}
              dailyUsage={state.data.daily_usage}
              proTier={state.data.user.pro_tier}
            />
          </SectionGrid>

          <UnlockStateBlock unlockedLevels={state.data.level_state.unlocked_levels} />

          <MasteryTable rows={state.data.mastery} />

          <PromotionAttemptsTable
            rows={state.data.promotion_attempts}
            hasMore={state.data.has_more_promotion}
          />

          <RecentAttemptsTable rows={state.data.recent_attempts} />

          <ActionsFooter
            email={state.data.user.email}
            attemptsToday={state.data.daily_usage.attempts_count}
            proTier={state.data.user.pro_tier}
            busy={resetBusy}
            error={resetError}
            onResetUsage={handleResetUsage}
          />
        </>
      )}
    </div>
  );
}

// ── Layout ──────────────────────────────────────────────────────────────────

function Header({ email }: { email: string | undefined }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: 24 }}>
      <div>
        <div className="eyebrow" style={{ marginBottom: 4 }}>
          <Link href="/users" style={{ color: 'var(--ink-3)', textDecoration: 'none' }}>
            ← Tài khoản
          </Link>
        </div>
        <h1 className="page-title" style={{ fontFamily: 'monospace', fontSize: 18 }}>
          {email ?? '—'}
        </h1>
      </div>
    </div>
  );
}

function SectionGrid({ children }: { children: React.ReactNode }) {
  return (
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: 16, marginBottom: 20 }}>
      {children}
    </div>
  );
}

function SectionTitle({ children }: { children: React.ReactNode }) {
  return (
    <h2 style={{
      fontSize: 11, fontWeight: 600, color: 'var(--ink-3)',
      textTransform: 'uppercase', letterSpacing: 0.4, margin: '0 0 12px',
    }}>{children}</h2>
  );
}

// ── Cards ───────────────────────────────────────────────────────────────────

type LearnerUser = LearnerStateResponse['user'];
type LearnerLevel = LearnerStateResponse['level_state'];
type LearnerDailyUsage = LearnerStateResponse['daily_usage'];

function ProfileCard({ user }: { user: LearnerUser }) {
  return (
    <div className="card" style={{ padding: 20 }}>
      <SectionTitle>Hồ sơ</SectionTitle>
      <KvRow label="Email" value={user.email} mono />
      <KvRow label="Tên hiển thị" value={user.display_name || '—'} />
      <KvRow label="Vai trò" value={user.role} />
      <KvRow
        label="Pro tier"
        value={user.pro_tier === 'pro' ? 'PRO' : 'Free'}
        valueClass={user.pro_tier === 'pro' ? 'badge badge-ready' : undefined}
      />
      <KvRow label="Grace attempts" value={String(user.grace_attempts_left)} />
      <KvRow label="Tạo lúc" value={formatDate(user.created_at)} />
    </div>
  );
}

function CefrCard({
  level, dailyUsage, proTier,
}: { level: LearnerLevel; dailyUsage: LearnerDailyUsage; proTier: string }) {
  return (
    <div className="card" style={{ padding: 20 }}>
      <SectionTitle>Trạng thái CEFR</SectionTitle>
      <KvRow
        label="Level hiện tại"
        value={formatLevelLabel(level.current_level)}
        valueClass="badge badge-ready"
      />
      <KvRow
        label="Đã thi placement"
        value={level.placement_taken_at ? formatDate(level.placement_taken_at) : 'Chưa'}
      />
      <KvRow
        label="Hôm nay"
        value={
          proTier === 'pro'
            ? '∞'
            : `${dailyUsage.attempts_count}/${dailyUsage.attempts_cap}`
        }
        valueClass={
          proTier !== 'pro' && dailyUsage.attempts_count >= dailyUsage.attempts_cap
            ? 'mono-strong-error'
            : undefined
        }
        mono
      />
    </div>
  );
}

function KvRow({
  label, value, valueClass, mono,
}: { label: string; value: string; valueClass?: string; mono?: boolean }) {
  return (
    <div style={{
      display: 'flex', justifyContent: 'space-between', gap: 12,
      padding: '6px 0', borderBottom: '1px solid var(--border)',
      fontSize: 13,
    }}>
      <span style={{ color: 'var(--ink-3)' }}>{label}</span>
      <span
        className={valueClass}
        style={{
          color: 'var(--ink)',
          fontFamily: mono ? 'monospace' : undefined,
          fontSize: mono ? 12 : undefined,
        }}
      >{value}</span>
    </div>
  );
}

// ── Unlock state ────────────────────────────────────────────────────────────

function UnlockStateBlock({ unlockedLevels }: { unlockedLevels: string[] }) {
  const [showJSON, setShowJSON] = useState(false);
  return (
    <div className="card" style={{ padding: 20, marginBottom: 20 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
        <SectionTitle>Unlock state</SectionTitle>
        <button
          onClick={() => setShowJSON(s => !s)}
          className="btn btn-ghost"
          style={{ fontSize: 12 }}
        >
          {showJSON ? 'Tóm tắt' : 'Xem JSON gốc'}
        </button>
      </div>
      {!showJSON && (
        <p style={{ fontSize: 14, color: 'var(--ink)', margin: 0, fontFamily: 'monospace' }}>
          {summarizeUnlockedLevels(unlockedLevels)}
        </p>
      )}
      {showJSON && (
        <pre style={{
          margin: 0, padding: 12, background: 'var(--surface-alt)',
          borderRadius: 'var(--r2)', fontSize: 12,
          overflow: 'auto', color: 'var(--ink-2)',
        }}>
          <code>{JSON.stringify({ unlocked_levels: unlockedLevels }, null, 2)}</code>
        </pre>
      )}
    </div>
  );
}

// ── Mastery table ───────────────────────────────────────────────────────────

function MasteryTable({ rows }: { rows: LearnerStateResponse['mastery'] }) {
  return (
    <div className="card" style={{ padding: 20, marginBottom: 20 }}>
      <SectionTitle>Mastery (per skill × module)</SectionTitle>
      {rows.length === 0 ? (
        <p style={{ color: 'var(--ink-3)', fontSize: 13, margin: 0 }}>Chưa có dữ liệu mastery.</p>
      ) : (
        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
          <thead>
            <tr style={{ background: 'var(--surface-alt)' }}>
              {['Skill', 'Module', 'Score', 'Attempts', 'Cập nhật'].map(h => (
                <th key={h} scope="col" style={{
                  padding: '8px 12px', textAlign: 'left',
                  fontWeight: 600, fontSize: 11, color: 'var(--ink-3)',
                  textTransform: 'uppercase', letterSpacing: 0.4,
                }}>{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.map((r, i) => (
              <tr key={`${r.skill_kind}-${r.module_id}-${i}`} style={{ borderTop: '1px solid var(--border)' }}>
                <td style={{ padding: '8px 12px', fontWeight: 600 }}>{r.skill_kind}</td>
                <td style={{ padding: '8px 12px', color: 'var(--ink-2)' }}>
                  {r.module_label || (r.module_id ? r.module_id : '—')}
                </td>
                <td style={{ padding: '8px 12px', fontFamily: 'monospace' }}>{formatMasteryScore(r.score)}</td>
                <td style={{ padding: '8px 12px', fontFamily: 'monospace' }}>{r.attempts_count}</td>
                <td style={{ padding: '8px 12px', color: 'var(--ink-3)', fontSize: 12 }}>
                  {formatDateTime(r.updated_at)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}

// ── Promotion attempts ──────────────────────────────────────────────────────

function PromotionAttemptsTable({
  rows, hasMore,
}: { rows: LearnerStateResponse['promotion_attempts']; hasMore: boolean }) {
  return (
    <div className="card" style={{ padding: 20, marginBottom: 20 }}>
      <SectionTitle>Lần thi promotion</SectionTitle>
      {rows.length === 0 ? (
        <p style={{ color: 'var(--ink-3)', fontSize: 13, margin: 0 }}>Chưa có lần thi promotion nào.</p>
      ) : (
        <>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
            <thead>
              <tr style={{ background: 'var(--surface-alt)' }}>
                {['Target', 'Score', 'Kết quả', 'Bắt đầu'].map(h => (
                  <th key={h} scope="col" style={{
                    padding: '8px 12px', textAlign: 'left',
                    fontWeight: 600, fontSize: 11, color: 'var(--ink-3)',
                    textTransform: 'uppercase', letterSpacing: 0.4,
                  }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.map(r => {
                const variant = passedVariant(r.passed);
                return (
                  <tr key={r.id} style={{ borderTop: '1px solid var(--border)' }}>
                    <td style={{ padding: '8px 12px' }}>
                      <span className="badge badge-neutral">{formatLevelLabel(r.target_level)}</span>
                    </td>
                    <td style={{ padding: '8px 12px', fontFamily: 'monospace' }}>
                      {Number.isFinite(r.score_pct) ? `${Math.round(r.score_pct)}%` : '—'}
                    </td>
                    <td style={{ padding: '8px 12px' }}>
                      <span className={`badge ${variant.cls}`}>{variant.label}</span>
                    </td>
                    <td style={{ padding: '8px 12px', color: 'var(--ink-3)', fontSize: 12 }}>
                      {formatDateTime(r.created_at)}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
          {hasMore && (
            <p style={{ marginTop: 8, fontSize: 12, color: 'var(--ink-4)' }}>
              Còn lần thi cũ hơn (chỉ hiển thị 20 lần gần nhất).
            </p>
          )}
        </>
      )}
    </div>
  );
}

// ── Recent attempts ─────────────────────────────────────────────────────────

function RecentAttemptsTable({ rows }: { rows: LearnerStateResponse['recent_attempts'] }) {
  return (
    <div className="card" style={{ padding: 20, marginBottom: 20 }}>
      <SectionTitle>Attempt gần đây ({rows.length})</SectionTitle>
      {rows.length === 0 ? (
        <p style={{ color: 'var(--ink-3)', fontSize: 13, margin: 0 }}>Chưa có attempt nào.</p>
      ) : (
        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
          <thead>
            <tr style={{ background: 'var(--surface-alt)' }}>
              {['Bài tập', 'Skill', 'Readiness', 'Bắt đầu'].map(h => (
                <th key={h} scope="col" style={{
                  padding: '8px 12px', textAlign: 'left',
                  fontWeight: 600, fontSize: 11, color: 'var(--ink-3)',
                  textTransform: 'uppercase', letterSpacing: 0.4,
                }}>{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.map(r => (
              <tr key={r.id} style={{ borderTop: '1px solid var(--border)' }}>
                <td style={{ padding: '8px 12px' }}>
                  {r.exercise_label || r.exercise_id}
                </td>
                <td style={{ padding: '8px 12px', color: 'var(--ink-2)' }}>{r.skill_kind || '—'}</td>
                <td style={{ padding: '8px 12px', color: 'var(--ink-2)' }}>
                  {readinessLabel(r.readiness_level)}
                </td>
                <td style={{ padding: '8px 12px', color: 'var(--ink-3)', fontSize: 12 }}>
                  {formatDateTime(r.started_at)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}

// ── Footer ──────────────────────────────────────────────────────────────────

function ActionsFooter({
  email, attemptsToday, proTier, busy, error, onResetUsage,
}: {
  email: string;
  attemptsToday: number;
  proTier: string;
  busy: boolean;
  error: string;
  onResetUsage: () => void;
}) {
  const canResetUsage = proTier !== 'pro' && attemptsToday > 0;
  return (
    <div className="card" style={{ padding: 20 }}>
      <SectionTitle>Hành động</SectionTitle>
      <p style={{ fontSize: 12.5, color: 'var(--ink-3)', marginTop: 0, marginBottom: 12 }}>
        V22 chỉ cho reset usage hôm nay. Đặt lại mật khẩu / xóa tài khoản dùng bảng <strong>Tài khoản</strong>.
      </p>
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
        <button
          onClick={onResetUsage}
          disabled={!canResetUsage || busy}
          className="btn btn-primary"
          style={{ fontSize: 13 }}
          title={!canResetUsage ? 'Chỉ áp dụng khi user free + đã dùng > 0 lượt' : `Reset usage hôm nay cho ${email}`}
        >
          {busy ? 'Đang reset…' : 'Reset usage hôm nay'}
        </button>
        <Link href="/users" className="btn btn-ghost" style={{ fontSize: 13 }}>
          → Tới bảng Tài khoản
        </Link>
      </div>
      {error && (
        <p style={{ marginTop: 12, color: 'var(--error)', fontSize: 12 }}>{error}</p>
      )}
    </div>
  );
}

// ── States ──────────────────────────────────────────────────────────────────

function ErrorBlock({ message, onRetry }: { message: string; onRetry: () => void }) {
  return (
    <div className="card" style={{ padding: 20, borderLeft: '4px solid var(--error)' }}>
      <p style={{ margin: '0 0 12px', color: 'var(--error)', fontSize: 13 }}>{message}</p>
      <button onClick={onRetry} className="btn btn-ghost" style={{ fontSize: 12 }}>
        Thử lại
      </button>
    </div>
  );
}

function NotFoundBlock() {
  return (
    <div className="card" style={{ padding: 20 }}>
      <p style={{ margin: 0, color: 'var(--ink-2)', fontSize: 13 }}>
        Không tìm thấy người dùng. <Link href="/users">Quay về danh sách →</Link>
      </p>
    </div>
  );
}
