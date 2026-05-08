'use client';

import { useEffect, useMemo, useState } from 'react';
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

// GrammarPointPicker — free-text autocomplete that picks from
// /api/admin/grammar-rules. Falls back to free text when no rules in DB
// (admin can still type a label that the backend will reject as
// grammar_point_not_found, prompting them to create a rule first).
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
    <div className="flex flex-col gap-1.5">
      <label className="text-sm font-medium text-slate-700">
        Điểm ngữ pháp <span className="text-rose-600">*</span>
        <span className="ml-1 text-xs font-normal text-slate-500">
          ({selectedIds.length}/{DRAFT_LIMITS.grammarMax})
        </span>
      </label>

      {/* selected chips */}
      {selected.length > 0 && (
        <div className="flex flex-wrap gap-1.5">
          {selected.map((r) => (
            <button
              key={r.id}
              type="button"
              onClick={() => remove(r.id)}
              disabled={disabled}
              className="inline-flex items-center gap-1 rounded-full border border-violet-200 bg-violet-50 px-2 py-0.5 text-xs text-violet-900 hover:bg-violet-100"
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
        disabled={disabled || atCap}
        placeholder={atCap ? 'Đã đủ 3 điểm' : 'Tìm theo tên (vd: minulý čas)...'}
        className="rounded-md border border-slate-300 px-3 py-1.5 text-sm focus:border-violet-500 focus:outline-none focus:ring-1 focus:ring-violet-500 disabled:bg-slate-100"
      />

      {loading && <p className="text-xs text-slate-500">Đang tải danh sách...</p>}

      {!loading && rules.length === 0 && (
        <p className="text-xs text-amber-700">
          Chưa có grammar nào trong DB. Tạo grammar trước rồi quay lại.
        </p>
      )}

      {!loading && filtered.length > 0 && query && (
        <ul className="max-h-44 overflow-y-auto rounded-md border border-slate-200 bg-white shadow-sm">
          {filtered.map((r) => {
            const isSelected = selectedIds.includes(r.id);
            return (
              <li key={r.id}>
                <button
                  type="button"
                  onClick={() => add(r.id)}
                  disabled={isSelected || atCap || disabled}
                  className="flex w-full items-center justify-between px-3 py-1.5 text-left text-sm hover:bg-slate-50 disabled:opacity-50"
                >
                  <span>{r.title}</span>
                  {r.level && <span className="text-xs text-slate-500">{r.level}</span>}
                </button>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
