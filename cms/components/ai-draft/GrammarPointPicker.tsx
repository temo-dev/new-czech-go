'use client';

import { useEffect, useMemo, useState, type CSSProperties } from 'react';
import { adminFetch } from '../../lib/api';
import { DRAFT_LIMITS } from '../../lib/ai-draft-utils';

type GrammarRule = {
  id: string;
  title: string;
  level?: string;
  module_id?: string;
};

type Props = {
  selectedIds: string[];
  onChange: (ids: string[]) => void;
  level?: string;
  disabled?: boolean;
};

const wrapStyle: CSSProperties = { display: 'grid', gap: 6 };
const labelStyle: CSSProperties = { fontSize: 13, fontWeight: 600, color: 'var(--ink-2)' };
const requiredStyle: CSSProperties = { color: '#dc2626' };
const countStyle: CSSProperties = { marginLeft: 4, color: 'var(--ink-3)', fontSize: 12, fontWeight: 400 };
const chipRowStyle: CSSProperties = { display: 'flex', flexWrap: 'wrap', gap: 6 };
const chipStyle: CSSProperties = {
  display: 'inline-flex',
  alignItems: 'center',
  gap: 4,
  border: '1px solid #c4b5fd',
  borderRadius: 999,
  background: '#f5f3ff',
  color: '#4c1d95',
  cursor: 'pointer',
  fontSize: 12,
  padding: '3px 8px',
};
const inputStyle: CSSProperties = {
  width: '100%',
  border: '1px solid var(--border-strong)',
  borderRadius: 8,
  padding: '8px 10px',
  fontSize: 14,
  fontFamily: 'inherit',
  background: '#fff',
};
const hintStyle: CSSProperties = { margin: 0, color: 'var(--ink-3)', fontSize: 12 };
const warningStyle: CSSProperties = { margin: 0, color: '#b45309', fontSize: 12 };
const listStyle: CSSProperties = {
  maxHeight: 176,
  overflowY: 'auto',
  border: '1px solid var(--border)',
  borderRadius: 8,
  background: '#fff',
  boxShadow: '0 6px 20px rgba(15,23,42,0.08)',
  listStyle: 'none',
  margin: 0,
  padding: 0,
};
const optionButtonStyle: CSSProperties = {
  width: '100%',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'space-between',
  gap: 8,
  border: 0,
  background: 'transparent',
  cursor: 'pointer',
  padding: '8px 10px',
  textAlign: 'left',
  fontSize: 13,
};
const selectedOptionStyle: CSSProperties = { ...optionButtonStyle, cursor: 'not-allowed', opacity: 0.5 };

// GrammarPointPicker — free-text autocomplete that picks from
// /api/admin/grammar-rules. The backend requires IDs, so typed text is only
// a search query until the admin selects a row.
export function GrammarPointPicker({ selectedIds, onChange, level, disabled }: Props) {
  const [rules, setRules] = useState<GrammarRule[]>([]);
  const [loading, setLoading] = useState(false);
  const [query, setQuery] = useState('');

  useEffect(() => {
    let aborted = false;
    setLoading(true);
    adminFetch('/api/admin/grammar-rules')
      .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
      .then((body) => {
        if (aborted) return;
        const items = (body?.data ?? []) as GrammarRule[];
        setRules(items);
      })
      .catch(() => { if (!aborted) setRules([]); })
      .finally(() => { if (!aborted) setLoading(false); });
    return () => { aborted = true; };
  }, []);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    let pool = rules;
    if (level) pool = pool.filter((r) => !r.level || r.level === level);
    if (!q) return pool.slice(0, 8);
    return pool.filter((r) => r.title.toLowerCase().includes(q)).slice(0, 8);
  }, [rules, query, level]);

  const selected = selectedIds
    .map((id) => rules.find((r) => r.id === id))
    .filter((r): r is GrammarRule => Boolean(r));

  const atCap = selectedIds.length >= DRAFT_LIMITS.grammarMax;

  function add(id: string) {
    if (atCap || selectedIds.includes(id)) return;
    onChange([...selectedIds, id]);
    setQuery('');
  }

  function remove(id: string) {
    onChange(selectedIds.filter((x) => x !== id));
  }

  return (
    <div style={wrapStyle}>
      <label style={labelStyle}>
        Điểm ngữ pháp <span style={requiredStyle}>*</span>
        <span style={countStyle}>
          ({selectedIds.length}/{DRAFT_LIMITS.grammarMax})
        </span>
      </label>

      {/* selected chips */}
      {selected.length > 0 && (
        <div style={chipRowStyle}>
          {selected.map((r) => (
            <button
              key={r.id}
              type="button"
              onClick={() => remove(r.id)}
              disabled={disabled}
              style={chipStyle}
              aria-label={`Bỏ ${r.title}`}
            >
              <span>{r.title}</span>
              <span aria-hidden>×</span>
            </button>
          ))}
        </div>
      )}

      <input
        type="text"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        onKeyDown={(e) => {
          if (e.key !== 'Enter') return;
          e.preventDefault();
          const first = filtered.find((r) => !selectedIds.includes(r.id));
          if (first) add(first.id);
        }}
        disabled={disabled || atCap}
        placeholder={atCap ? 'Đã đủ 3 điểm' : 'Gõ để tìm, bấm vào kết quả để chọn...'}
        style={{ ...inputStyle, background: disabled || atCap ? 'var(--surface-muted)' : '#fff' }}
      />

      {loading && <p style={hintStyle}>Đang tải danh sách...</p>}

      {!loading && rules.length === 0 && (
        <p style={warningStyle}>
          Chưa có grammar nào trong DB. Tạo grammar trước rồi quay lại.
        </p>
      )}

      {!loading && rules.length > 0 && query && filtered.length === 0 && (
        <p style={warningStyle}>
          Không tìm thấy điểm ngữ pháp khớp với &quot;{query}&quot;. Hãy chọn một grammar có sẵn trong danh sách.
        </p>
      )}

      {!loading && rules.length > 0 && selectedIds.length === 0 && !query && (
        <p style={hintStyle}>Gõ tên grammar rồi bấm vào một kết quả. Chỉ nhập chữ chưa được tính là đã chọn.</p>
      )}

      {!loading && filtered.length > 0 && query && (
        <ul style={listStyle}>
          {filtered.map((r) => {
            const isSelected = selectedIds.includes(r.id);
            return (
              <li key={r.id} style={{ borderBottom: '1px solid var(--border)' }}>
                <button
                  type="button"
                  onClick={() => add(r.id)}
                  disabled={isSelected || atCap || disabled}
                  style={isSelected || atCap || disabled ? selectedOptionStyle : optionButtonStyle}
                >
                  <span>{r.title}</span>
                  {r.level && <span style={{ color: 'var(--ink-3)', fontSize: 12 }}>{r.level}</span>}
                </button>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
