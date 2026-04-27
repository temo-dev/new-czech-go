'use client';

type Stat = {
  label: string;
  value: string;
  delta: string;
  positive: boolean;
};

// Hardcoded for now — replace with real API when learner analytics exist
const STATS: Stat[] = [
  { label: 'Học viên active (7d)', value: '—',     delta: '',      positive: true },
  { label: 'Bài hoàn thành/ngày',  value: '—',     delta: '',      positive: true },
  { label: 'Pass rate Mock A2',     value: '—',     delta: '',      positive: false },
  { label: 'AI / reviewer đồng ý', value: '—',     delta: '',      positive: true },
];

export function DashboardStatsBar() {
  return (
    <div className="stats-grid" style={{ marginBottom: 28 }}>
      {STATS.map((s, i) => (
        <div key={i} className="stat-card">
          <div className="stat-label">{s.label}</div>
          <div className="stat-value">{s.value}</div>
          {s.delta && (
            <div
              className="stat-delta"
              style={{ color: s.positive ? 'var(--success)' : 'var(--error)' }}
            >
              {s.delta}
            </div>
          )}
        </div>
      ))}
    </div>
  );
}
