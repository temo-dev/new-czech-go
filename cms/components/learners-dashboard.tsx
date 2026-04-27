'use client';

import { useEffect, useState } from 'react';

type Attempt = {
  id: string;
  user_id: string;
  exercise_id: string;
  exercise_type?: string;
  status: string;
  attempt_no: number;
  started_at: string;
  completed_at?: string;
  readiness_level?: string;
  client_platform?: string;
  feedback?: {
    overall_summary?: string;
    readiness_level?: string;
    task_completion?: {
      criteria_results?: Array<{ criterion_key: string; label: string; met: boolean }>;
    };
  };
};

type LearnerStat = {
  userId: string;
  total: number;
  completed: number;
  ready: number;
  almost: number;
  needs: number;
  notReady: number;
  lastSeen: string;
  platform: string;
  attempts: Attempt[];
};

type ReadinessFilter = 'all' | 'ready' | 'almost_ready' | 'needs_work' | 'not_ready';
type ViewMode = 'attempts' | 'learners';

const FILTERS: { key: ReadinessFilter; label: string }[] = [
  { key: 'all',          label: 'Tất cả' },
  { key: 'ready',        label: 'READY' },
  { key: 'almost_ready', label: 'ALMOST' },
  { key: 'needs_work',   label: 'NEEDS' },
  { key: 'not_ready',    label: 'NOT READY' },
];

function isReady(level = '')    { return (level.includes('ready') && !level.includes('almost') && !level.includes('not')) || level === 'exam_ready'; }
function isAlmost(level = '')   { return level.includes('almost'); }
function isNeeds(level = '')    { return level.includes('needs'); }
function isNotReady(level = '') { return level.includes('not_ready'); }

function readinessTone(level: string): string {
  if (isReady(level))    return 'badge-ready';
  if (isAlmost(level))  return 'badge-almost';
  if (isNeeds(level))   return 'badge-needs';
  return 'badge-error';
}

function readinessLabel(level: string): string {
  if (isReady(level))    return 'READY';
  if (isAlmost(level))  return 'ALMOST';
  if (isNeeds(level))   return 'NEEDS WORK';
  if (isNotReady(level)) return 'NOT READY';
  return level.toUpperCase() || '—';
}

function ulohaLabel(type?: string): string {
  if (!type) return '—';
  if (type.startsWith('uloha_1')) return 'Úloha 1';
  if (type.startsWith('uloha_2')) return 'Úloha 2';
  if (type.startsWith('uloha_3')) return 'Úloha 3';
  if (type.startsWith('uloha_4')) return 'Úloha 4';
  return type;
}

function timeAgo(dateStr: string): string {
  if (!dateStr) return '—';
  const diff = Date.now() - new Date(dateStr).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 60) return `${mins}p trước`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h trước`;
  return `${Math.floor(hrs / 24)}d trước`;
}

function groupByLearner(attempts: Attempt[]): LearnerStat[] {
  const map = new Map<string, Attempt[]>();
  for (const a of attempts) {
    const uid = a.user_id || 'anonymous';
    if (!map.has(uid)) map.set(uid, []);
    map.get(uid)!.push(a);
  }
  return [...map.entries()].map(([userId, atts]) => {
    const completed = atts.filter(a => a.status === 'completed');
    const levels = completed.map(a => a.feedback?.readiness_level ?? a.readiness_level ?? '');
    const sorted = [...atts].sort((a, b) => new Date(b.started_at).getTime() - new Date(a.started_at).getTime());
    return {
      userId,
      total: atts.length,
      completed: completed.length,
      ready:    levels.filter(isReady).length,
      almost:   levels.filter(isAlmost).length,
      needs:    levels.filter(isNeeds).length,
      notReady: levels.filter(isNotReady).length,
      lastSeen: sorted[0]?.started_at ?? '',
      platform: sorted[0]?.client_platform ?? '—',
      attempts: sorted,
    };
  }).sort((a, b) => new Date(b.lastSeen).getTime() - new Date(a.lastSeen).getTime());
}

export function LearnersDashboard() {
  const [attempts, setAttempts] = useState<Attempt[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [filter, setFilter] = useState<ReadinessFilter>('all');
  const [view, setView] = useState<ViewMode>('attempts');
  const [expandedUser, setExpandedUser] = useState<string | null>(null);

  useEffect(() => { load(); }, []);

  async function load() {
    setLoading(true);
    setError('');
    try {
      const res = await fetch('/api/admin/attempts');
      const j = await res.json();
      if (!res.ok) throw new Error(j.error?.message ?? 'Load failed');
      const all: Attempt[] = j.data ?? [];
      all.sort((a, b) => new Date(b.started_at).getTime() - new Date(a.started_at).getTime());
      setAttempts(all);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
    } finally {
      setLoading(false);
    }
  }

  const filtered = filter === 'all'
    ? attempts
    : attempts.filter(a => {
        const level = a.feedback?.readiness_level ?? a.readiness_level ?? '';
        if (filter === 'ready')        return isReady(level);
        if (filter === 'almost_ready') return isAlmost(level);
        if (filter === 'needs_work')   return isNeeds(level);
        if (filter === 'not_ready')    return isNotReady(level);
        return true;
      });

  const learners = groupByLearner(attempts);

  const completed = attempts.filter(a => a.status === 'completed');
  const readyCnt  = completed.filter(a => isReady(a.feedback?.readiness_level ?? a.readiness_level ?? '')).length;
  const passRate  = completed.length > 0 ? Math.round((readyCnt / completed.length) * 100) : 0;
  const uniqueUsers = new Set(attempts.map(a => a.user_id)).size;

  if (loading) return <p style={{ padding: 24, color: 'var(--ink-3)' }}>Đang tải…</p>;

  return (
    <div>
      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: 24 }}>
        <div>
          <div className="eyebrow" style={{ marginBottom: 4 }}>HOẠT ĐỘNG</div>
          <h1 className="page-title">Học viên</h1>
        </div>
        <button onClick={load} className="btn btn-ghost" style={{ fontSize: 12 }}>Làm mới</button>
      </div>

      {error && (
        <div style={{ padding: '10px 14px', background: 'var(--error-bg)', color: 'var(--error)', borderRadius: 'var(--r2)', marginBottom: 20, fontSize: 13 }}>
          {error}
        </div>
      )}

      {/* Stats grid */}
      <div className="stats-grid" style={{ marginBottom: 24 }}>
        <div className="stat-card">
          <div className="stat-label">Học viên</div>
          <div className="stat-value">{uniqueUsers}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Tổng lượt nộp</div>
          <div className="stat-value">{attempts.length}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Pass rate (READY)</div>
          <div className="stat-value">{passRate}%</div>
          <div className="stat-delta" style={{ color: passRate >= 60 ? 'var(--success)' : 'var(--warning)' }}>
            {readyCnt}/{completed.length}
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Đang xử lý</div>
          <div className="stat-value">{attempts.filter(a => a.status === 'processing' || a.status === 'uploading').length}</div>
        </div>
      </div>

      {/* View toggle */}
      <div style={{ display: 'flex', gap: 0, marginBottom: 20, background: 'rgba(20,18,14,0.05)', borderRadius: 999, padding: 4, width: 'fit-content' }}>
        {(['attempts', 'learners'] as const).map(v => (
          <button
            key={v}
            onClick={() => setView(v)}
            style={{
              padding: '7px 20px',
              borderRadius: 999,
              border: 'none',
              background: view === v ? 'var(--surface)' : 'transparent',
              color: view === v ? 'var(--ink)' : 'var(--ink-3)',
              fontWeight: view === v ? 600 : 400,
              fontSize: 13,
              cursor: 'pointer',
              boxShadow: view === v ? '0 1px 4px rgba(40,28,16,0.10)' : 'none',
              transition: 'all 120ms ease',
            }}
          >
            {v === 'attempts' ? 'Lượt nộp' : 'Học viên'}
          </button>
        ))}
      </div>

      {view === 'attempts' && (
        <>
          {/* Filter pills */}
          <div style={{ display: 'flex', gap: 8, marginBottom: 20, flexWrap: 'wrap' }}>
            {FILTERS.map(f => (
              <button
                key={f.key}
                onClick={() => setFilter(f.key)}
                style={{
                  padding: '6px 14px',
                  borderRadius: 999,
                  border: filter === f.key ? '1.5px solid var(--brand)' : '1px solid var(--border-strong)',
                  background: filter === f.key ? 'var(--brand-soft)' : 'transparent',
                  color: filter === f.key ? 'var(--brand-ink)' : 'var(--ink-2)',
                  fontSize: 12.5,
                  fontWeight: filter === f.key ? 700 : 400,
                  cursor: 'pointer',
                }}
              >
                {f.label}
              </button>
            ))}
            <span style={{ marginLeft: 'auto', fontSize: 12, color: 'var(--ink-3)', alignSelf: 'center' }}>
              {filtered.length} / {attempts.length}
            </span>
          </div>

          <AttemptsTable attempts={filtered} />
        </>
      )}

      {view === 'learners' && (
        <LearnersTable
          learners={learners}
          expandedUser={expandedUser}
          onToggle={(uid) => setExpandedUser(expandedUser === uid ? null : uid)}
        />
      )}
    </div>
  );
}

// ── Attempts table ─────────────────────────────────────────────────────────────

function AttemptsTable({ attempts }: { attempts: Attempt[] }) {
  if (attempts.length === 0) {
    return <p style={{ color: 'var(--ink-3)', textAlign: 'center', padding: '40px 0' }}>Chưa có dữ liệu.</p>;
  }
  return (
    <div className="card" style={{ overflow: 'hidden' }}>
      <div style={{
        display: 'grid',
        gridTemplateColumns: '130px 1fr 120px 64px 100px',
        gap: 12, padding: '10px 18px',
        borderBottom: '1px solid var(--divider)',
        fontSize: 11, fontWeight: 700, letterSpacing: 0.5,
        textTransform: 'uppercase', color: 'var(--ink-3)',
      }}>
        <div>Thời gian</div><div>Bài tập</div><div>Trạng thái</div><div>Lần</div><div>Nền tảng</div>
      </div>
      {attempts.slice(0, 100).map((a, i) => {
        const level = a.feedback?.readiness_level ?? a.readiness_level ?? '';
        return (
          <div key={a.id} style={{
            display: 'grid',
            gridTemplateColumns: '130px 1fr 120px 64px 100px',
            gap: 12, padding: '11px 18px',
            borderTop: i > 0 ? '1px solid var(--divider)' : 'none',
            background: i % 2 === 0 ? 'var(--surface)' : 'var(--surface-alt)',
            fontSize: 13, alignItems: 'center',
          }}>
            <div style={{ color: 'var(--ink-3)', fontSize: 12 }}>{timeAgo(a.started_at)}</div>
            <div>
              <div style={{ fontWeight: 500, color: 'var(--ink)', fontSize: 13 }}>{ulohaLabel(a.exercise_type)}</div>
              <div style={{ color: 'var(--ink-4)', fontSize: 11, marginTop: 1 }}>{a.exercise_id.slice(0, 24)}…</div>
            </div>
            <div>
              {level ? (
                <span className={`badge ${readinessTone(level)}`}>{readinessLabel(level)}</span>
              ) : (
                <span className="badge badge-neutral">{a.status.toUpperCase()}</span>
              )}
            </div>
            <div style={{ color: 'var(--ink-3)', textAlign: 'center' }}>#{a.attempt_no}</div>
            <div style={{ color: 'var(--ink-3)', fontSize: 12 }}>{a.client_platform ?? '—'}</div>
          </div>
        );
      })}
      {attempts.length > 100 && (
        <div style={{ padding: '12px 18px', borderTop: '1px solid var(--divider)', fontSize: 12, color: 'var(--ink-3)' }}>
          Hiển thị 100 / {attempts.length}
        </div>
      )}
    </div>
  );
}

// ── Learners table ─────────────────────────────────────────────────────────────

function LearnersTable({ learners, expandedUser, onToggle }: {
  learners: LearnerStat[];
  expandedUser: string | null;
  onToggle: (uid: string) => void;
}) {
  if (learners.length === 0) {
    return <p style={{ color: 'var(--ink-3)', textAlign: 'center', padding: '40px 0' }}>Chưa có dữ liệu.</p>;
  }
  return (
    <div className="card" style={{ overflow: 'hidden' }}>
      {/* Header */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: '1fr 80px 80px 180px 120px',
        gap: 12, padding: '10px 18px',
        borderBottom: '1px solid var(--divider)',
        fontSize: 11, fontWeight: 700, letterSpacing: 0.5,
        textTransform: 'uppercase', color: 'var(--ink-3)',
      }}>
        <div>Học viên</div><div>Lượt</div><div>Hoàn thành</div><div>Phân bố readiness</div><div>Gần nhất</div>
      </div>

      {learners.map((l, i) => {
        const isExpanded = expandedUser === l.userId;
        const total = l.completed || 1;
        const shortId = l.userId.length > 20 ? l.userId.slice(0, 8) + '…' + l.userId.slice(-6) : l.userId;

        return (
          <div key={l.userId}>
            {/* Learner row */}
            <div
              onClick={() => onToggle(l.userId)}
              style={{
                display: 'grid',
                gridTemplateColumns: '1fr 80px 80px 180px 120px',
                gap: 12, padding: '12px 18px',
                borderTop: i > 0 ? '1px solid var(--divider)' : 'none',
                background: isExpanded ? 'var(--brand-soft)' : i % 2 === 0 ? 'var(--surface)' : 'var(--surface-alt)',
                fontSize: 13, alignItems: 'center',
                cursor: 'pointer',
              }}
            >
              {/* ID */}
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <div style={{
                  width: 30, height: 30, borderRadius: '50%',
                  background: 'var(--accent-soft)', color: 'var(--accent)',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: 12, fontWeight: 700, flexShrink: 0,
                }}>
                  {l.userId.slice(0, 2).toUpperCase()}
                </div>
                <div>
                  <div style={{ fontWeight: 500, color: 'var(--ink)', fontSize: 12 }}>{shortId}</div>
                  <div style={{ color: 'var(--ink-4)', fontSize: 11 }}>{l.platform}</div>
                </div>
              </div>

              {/* Counts */}
              <div style={{ color: 'var(--ink)', fontWeight: 600, textAlign: 'center' }}>{l.total}</div>
              <div style={{ color: 'var(--ink-2)', textAlign: 'center' }}>{l.completed}</div>

              {/* Readiness bars */}
              <div>
                <div style={{ display: 'flex', height: 8, borderRadius: 999, overflow: 'hidden', gap: 1 }}>
                  {l.ready    > 0 && <div style={{ flex: l.ready,    background: 'var(--ready)' }} />}
                  {l.almost   > 0 && <div style={{ flex: l.almost,   background: 'var(--almost)' }} />}
                  {l.needs    > 0 && <div style={{ flex: l.needs,    background: 'var(--needs)' }} />}
                  {l.notReady > 0 && <div style={{ flex: l.notReady, background: 'var(--not-ready)' }} />}
                  {(l.ready + l.almost + l.needs + l.notReady) === 0 && (
                    <div style={{ flex: 1, background: 'var(--border)' }} />
                  )}
                </div>
                <div style={{ display: 'flex', gap: 6, marginTop: 4, fontSize: 10, color: 'var(--ink-3)' }}>
                  {l.ready    > 0 && <span style={{ color: 'var(--ready)' }}>R:{l.ready}</span>}
                  {l.almost   > 0 && <span style={{ color: 'var(--almost)' }}>A:{l.almost}</span>}
                  {l.needs    > 0 && <span style={{ color: 'var(--needs)' }}>N:{l.needs}</span>}
                  {l.notReady > 0 && <span style={{ color: 'var(--not-ready)' }}>X:{l.notReady}</span>}
                </div>
              </div>

              {/* Last seen */}
              <div style={{ color: 'var(--ink-3)', fontSize: 12, textAlign: 'right' }}>
                {timeAgo(l.lastSeen)}
                <div style={{ fontSize: 10, color: 'var(--ink-4)', marginTop: 1 }}>
                  {isExpanded ? '▲ Thu gọn' : '▼ Chi tiết'}
                </div>
              </div>
            </div>

            {/* Expanded detail */}
            {isExpanded && (
              <div style={{
                padding: '12px 18px 16px',
                background: 'var(--surface-alt)',
                borderTop: '1px solid var(--brand-soft)',
              }}>
                <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--ink-3)', letterSpacing: 0.5, textTransform: 'uppercase', marginBottom: 10 }}>
                  Lịch sử gần nhất
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                  {l.attempts.slice(0, 8).map(a => {
                    const level = a.feedback?.readiness_level ?? a.readiness_level ?? '';
                    return (
                      <div key={a.id} style={{
                        display: 'flex', alignItems: 'center', gap: 10,
                        padding: '8px 12px',
                        background: 'var(--surface)',
                        borderRadius: 'var(--r2)',
                        border: '1px solid var(--border)',
                        fontSize: 12,
                      }}>
                        <div style={{ width: 70, color: 'var(--ink-3)', flexShrink: 0 }}>{timeAgo(a.started_at)}</div>
                        <div style={{ flex: 1, color: 'var(--ink)', fontWeight: 500 }}>{ulohaLabel(a.exercise_type)}</div>
                        <div>
                          {level ? (
                            <span className={`badge ${readinessTone(level)}`} style={{ fontSize: 10 }}>{readinessLabel(level)}</span>
                          ) : (
                            <span className="badge badge-neutral" style={{ fontSize: 10 }}>{a.status}</span>
                          )}
                        </div>
                      </div>
                    );
                  })}
                </div>

                {/* Criteria failures (most common unmet) */}
                <CriteriaFailures attempts={l.attempts} />
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}

// ── Criteria failure analysis ─────────────────────────────────────────────────

function CriteriaFailures({ attempts }: { attempts: Attempt[] }) {
  const failMap = new Map<string, { label: string; count: number }>();
  for (const a of attempts) {
    for (const c of a.feedback?.task_completion?.criteria_results ?? []) {
      if (!c.met) {
        const prev = failMap.get(c.criterion_key);
        failMap.set(c.criterion_key, { label: c.label, count: (prev?.count ?? 0) + 1 });
      }
    }
  }
  const failures = [...failMap.entries()]
    .map(([key, v]) => ({ key, ...v }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 5);

  if (failures.length === 0) return null;

  return (
    <div style={{ marginTop: 14 }}>
      <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--ink-3)', letterSpacing: 0.5, textTransform: 'uppercase', marginBottom: 8 }}>
        Tiêu chí hay không đạt
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
        {failures.map(f => (
          <div key={f.key} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <div style={{ flex: 1, fontSize: 12, color: 'var(--ink-2)' }}>{f.label}</div>
            <div style={{ fontSize: 11, color: 'var(--error)', fontWeight: 600 }}>{f.count}×</div>
          </div>
        ))}
      </div>
    </div>
  );
}
