'use client';

import Link from 'next/link';
import { useState } from 'react';
import {
  entityLink,
  formatCount,
  hasAnyIssue,
  summarizeTotal,
  type Check,
  type CheckItem,
  type ContentHealthResponse,
  type ContentHealthState,
} from './content-health-utils';

export function ContentHealth() {
  const [state, setState] = useState<ContentHealthState>({ kind: 'initial' });
  const [expandedId, setExpandedId] = useState<string | null>(null);

  async function runCheck() {
    setState({ kind: 'running' });
    setExpandedId(null);
    try {
      const res = await fetch('/api/admin/content-health', { cache: 'no-store' });
      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        const msg = (body as { error?: { message?: string } }).error?.message ?? `Lỗi (${res.status})`;
        throw new Error(msg);
      }
      const data = (await res.json()) as ContentHealthResponse;
      setState({ kind: 'loaded', data });
    } catch (err) {
      setState({ kind: 'error', message: err instanceof Error ? err.message : 'Lỗi không xác định' });
    }
  }

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: 24 }}>
        <div>
          <div className="eyebrow" style={{ marginBottom: 4 }}>QUẢN LÝ</div>
          <h1 className="page-title">Sức khỏe nội dung</h1>
        </div>
        <button
          onClick={runCheck}
          disabled={state.kind === 'running'}
          className="btn btn-primary"
          style={{ fontSize: 13 }}
        >
          {state.kind === 'running' ? 'Đang chạy…' : '⟳ Chạy kiểm tra'}
        </button>
      </div>

      <Header state={state} />

      {state.kind === 'initial' && <Grid checks={initialPlaceholders()} expandedId={null} onToggle={() => {}} placeholder />}
      {state.kind === 'running' && <Grid checks={initialPlaceholders()} expandedId={null} onToggle={() => {}} placeholder />}
      {state.kind === 'error' && (
        <div className="card" style={{ padding: 20, borderLeft: '4px solid var(--error)' }}>
          <p style={{ color: 'var(--error)', margin: '0 0 12px', fontSize: 13 }}>{state.message}</p>
          <button onClick={runCheck} className="btn btn-ghost" style={{ fontSize: 12 }}>Thử lại</button>
        </div>
      )}
      {state.kind === 'loaded' && (
        <Grid
          checks={state.data.checks}
          expandedId={expandedId}
          onToggle={id => setExpandedId(prev => (prev === id ? null : id))}
        />
      )}
    </div>
  );
}

function Header({ state }: { state: ContentHealthState }) {
  if (state.kind === 'initial') {
    return (
      <p style={{ fontSize: 13, color: 'var(--ink-3)', marginBottom: 16 }}>
        Bấm <strong>Chạy kiểm tra</strong> để quét 6 quy tắc phát hiện rot.
      </p>
    );
  }
  if (state.kind === 'running') {
    return (
      <p style={{ fontSize: 13, color: 'var(--ink-3)', marginBottom: 16 }}>Đang chạy 6 kiểm tra…</p>
    );
  }
  if (state.kind === 'loaded') {
    const ts = new Date(state.data.checked_at);
    const tsLabel = isNaN(ts.getTime()) ? state.data.checked_at : ts.toLocaleString('vi-VN');
    return (
      <p style={{ fontSize: 13, color: 'var(--ink-3)', marginBottom: 16 }}>
        Lần chạy gần nhất: <strong>{tsLabel}</strong> · {summarizeTotal(state.data.checks)}
        {!hasAnyIssue(state.data.checks) && (
          <span style={{ marginLeft: 8, color: 'var(--ready)' }}>✓ Mọi mục đều sạch.</span>
        )}
      </p>
    );
  }
  return null;
}

function Grid({
  checks, expandedId, onToggle, placeholder,
}: {
  checks: Check[];
  expandedId: string | null;
  onToggle: (id: string) => void;
  placeholder?: boolean;
}) {
  const expanded = checks.find(c => c.id === expandedId) ?? null;
  return (
    <div>
      <div style={{
        display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
        gap: 12, marginBottom: 16,
      }}>
        {checks.map(c => (
          <Card
            key={c.id}
            check={c}
            placeholder={placeholder}
            expanded={expandedId === c.id}
            onToggle={() => onToggle(c.id)}
          />
        ))}
      </div>
      {expanded && expanded.items.length > 0 && (
        <ItemsTable check={expanded} />
      )}
    </div>
  );
}

function Card({
  check, expanded, onToggle, placeholder,
}: {
  check: Check;
  expanded: boolean;
  onToggle: () => void;
  placeholder?: boolean;
}) {
  const isClean = !placeholder && check.count === 0;
  const isProblem = !placeholder && check.count > 0;
  return (
    <div
      className="card"
      style={{
        padding: 16,
        opacity: placeholder ? 0.6 : 1,
        background: isClean ? 'var(--surface-alt)' : 'var(--surface)',
        outline: expanded ? '2px solid var(--brand)' : undefined,
      }}
    >
      <p style={{
        margin: '0 0 6px', fontSize: 11, fontWeight: 700, color: 'var(--ink-3)',
        textTransform: 'uppercase', letterSpacing: 0.4,
      }}>
        {check.label}
      </p>
      <p style={{
        margin: '0 0 6px',
        fontSize: 28,
        fontWeight: 700,
        fontFamily: 'monospace',
        color: isProblem ? 'var(--error)' : 'var(--ink-3)',
      }}>
        {placeholder ? '—' : formatCount(check.count)}
      </p>
      <p style={{ margin: '0 0 10px', fontSize: 12, color: 'var(--ink-4)' }}>
        {check.description}
      </p>
      {isProblem && (
        <button
          onClick={onToggle}
          className="btn btn-ghost"
          style={{ fontSize: 12 }}
        >
          {expanded ? 'Đóng' : 'Xem chi tiết'}
        </button>
      )}
    </div>
  );
}

function ItemsTable({ check }: { check: Check }) {
  return (
    <div className="card" style={{ padding: 20 }}>
      <p style={{
        margin: '0 0 12px', fontSize: 11, fontWeight: 700, color: 'var(--ink-3)',
        textTransform: 'uppercase', letterSpacing: 0.4,
      }}>
        {check.label} ({check.count}{check.truncated ? '+, hiển thị 50 đầu' : ''})
      </p>
      <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
        <thead>
          <tr style={{ background: 'var(--surface-alt)' }}>
            {['Loại', 'ID', 'Tên', 'Ghi chú'].map(h => (
              <th key={h} scope="col" style={{
                padding: '8px 12px', textAlign: 'left',
                fontWeight: 600, fontSize: 11, color: 'var(--ink-3)',
                textTransform: 'uppercase', letterSpacing: 0.4,
              }}>{h}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {check.items.map((item, i) => (
            <ItemRow key={`${item.entity_type}-${item.entity_id}-${i}`} item={item} />
          ))}
        </tbody>
      </table>
    </div>
  );
}

function ItemRow({ item }: { item: CheckItem }) {
  return (
    <tr style={{ borderTop: '1px solid var(--border)' }}>
      <td style={{ padding: '8px 12px', color: 'var(--ink-2)' }}>{item.entity_type}</td>
      <td style={{ padding: '8px 12px', fontFamily: 'monospace', fontSize: 12 }}>
        <Link href={entityLink(item)} style={{ color: 'var(--brand-deep)' }}>
          {item.entity_id} →
        </Link>
      </td>
      <td style={{ padding: '8px 12px' }}>{item.label || '—'}</td>
      <td style={{ padding: '8px 12px', color: 'var(--ink-3)', fontSize: 12 }}>
        {item.extra || '—'}
      </td>
    </tr>
  );
}

// initialPlaceholders renders a 6-card grey grid before the first
// run-check fires. Same shape as the loaded response so the Grid
// component does not branch on state.
function initialPlaceholders(): Check[] {
  return [
    { id: 'orphan_exercises', label: 'Bài tập mồ côi', description: 'pool=course nhưng module_id rỗng', count: 0, items: [], truncated: false },
    { id: 'missing_audio_listening', label: 'Bài nghe thiếu audio', description: 'skill_kind=nghe chưa có exercise_audio', count: 0, items: [], truncated: false },
    { id: 'module_empty', label: 'Module trống', description: 'module không có bài tập nào', count: 0, items: [], truncated: false },
    { id: 'mock_test_missing_section', label: 'Mock test thiếu section', description: 'mock_test chưa có phần thi nào', count: 0, items: [], truncated: false },
    { id: 'course_missing_module', label: 'Course thiếu module', description: 'course chưa có module nào', count: 0, items: [], truncated: false },
    { id: 'dictation_missing_sentence_audio', label: 'Dictation thiếu audio câu', description: 'psani_3_dictation chưa có exercise_sentence_audio', count: 0, items: [], truncated: false },
  ];
}
