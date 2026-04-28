'use client';

type Props = {
  label: string;
  items: string[];
  onChange: (items: string[]) => void;
  placeholder?: string;
  maxItems?: number;
  minItems?: number;
  rows?: number;
  hint?: string;
};

const inputStyle: React.CSSProperties = {
  flex: 1,
  padding: '8px 10px',
  border: '1px solid var(--border-strong)',
  borderRadius: 8,
  fontSize: 14,
  color: 'var(--ink)',
  background: 'var(--surface)',
  resize: 'vertical',
  fontFamily: 'inherit',
  lineHeight: 1.5,
};

const iconBtnStyle: React.CSSProperties = {
  background: 'none',
  border: '1px solid var(--border)',
  borderRadius: 6,
  width: 28,
  height: 28,
  cursor: 'pointer',
  fontSize: 14,
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  color: 'var(--ink-3)',
  flexShrink: 0,
};

export function ItemRepeater({ label, items, onChange, placeholder, maxItems, minItems = 1, rows = 2, hint }: Props) {
  function update(index: number, value: string) {
    const next = [...items];
    next[index] = value;
    onChange(next);
  }

  function add() {
    if (maxItems !== undefined && items.length >= maxItems) return;
    onChange([...items, '']);
  }

  function remove(index: number) {
    if (items.length <= minItems) return;
    onChange(items.filter((_, i) => i !== index));
  }

  function move(index: number, direction: -1 | 1) {
    const next = [...items];
    const target = index + direction;
    if (target < 0 || target >= next.length) return;
    [next[index], next[target]] = [next[target], next[index]];
    onChange(next);
  }

  const canAdd = maxItems === undefined || items.length < maxItems;

  return (
    <div style={{ display: 'grid', gap: 6 }}>
      <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--ink-2)' }}>{label}</span>
      <div style={{ display: 'grid', gap: 6 }}>
        {items.map((item, i) => (
          <div key={i} style={{ display: 'flex', gap: 4, alignItems: 'flex-start' }}>
            <textarea
              rows={rows}
              value={item}
              onChange={e => update(i, e.target.value)}
              placeholder={placeholder}
              style={inputStyle}
            />
            <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
              <button
                type="button"
                onClick={() => move(i, -1)}
                disabled={i === 0}
                title="Lên"
                style={{ ...iconBtnStyle, opacity: i === 0 ? 0.3 : 1, cursor: i === 0 ? 'default' : 'pointer' }}
              >↑</button>
              <button
                type="button"
                onClick={() => move(i, 1)}
                disabled={i === items.length - 1}
                title="Xuống"
                style={{ ...iconBtnStyle, opacity: i === items.length - 1 ? 0.3 : 1, cursor: i === items.length - 1 ? 'default' : 'pointer' }}
              >↓</button>
              <button
                type="button"
                onClick={() => remove(i)}
                disabled={items.length <= minItems}
                title="Xóa"
                style={{ ...iconBtnStyle, opacity: items.length <= minItems ? 0.3 : 1, cursor: items.length <= minItems ? 'default' : 'pointer', color: 'var(--error)' }}
              >×</button>
            </div>
          </div>
        ))}
      </div>
      {canAdd && (
        <button
          type="button"
          onClick={add}
          style={{
            alignSelf: 'flex-start',
            background: 'none',
            border: '1px dashed var(--border-strong)',
            borderRadius: 8,
            padding: '6px 14px',
            cursor: 'pointer',
            fontSize: 13,
            color: 'var(--ink-3)',
          }}
        >
          + Thêm{maxItems ? ` (${items.length}/${maxItems})` : ''}
        </button>
      )}
      {hint && <span style={{ fontSize: 12, color: 'var(--ink-4)' }}>{hint}</span>}
    </div>
  );
}
