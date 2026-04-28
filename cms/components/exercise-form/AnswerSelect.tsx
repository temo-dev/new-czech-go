'use client';

type Option = { key: string; label?: string };

type Props = {
  label: string;
  options: Option[];
  value: string;
  onChange: (key: string) => void;
};

export function AnswerSelect({ label, options, value, onChange }: Props) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
      <span style={{ fontSize: 13, color: 'var(--ink-2)', flexShrink: 0, fontWeight: 500 }}>
        {label}
      </span>
      <select
        value={value}
        onChange={e => onChange(e.target.value)}
        style={{
          padding: '5px 8px',
          border: '1px solid var(--border-strong)',
          borderRadius: 7,
          fontSize: 13,
          color: 'var(--ink)',
          background: 'var(--surface)',
          cursor: 'pointer',
          fontFamily: 'inherit',
          minWidth: 70,
        }}
      >
        <option value="">—</option>
        {options.map(opt => (
          <option key={opt.key} value={opt.key}>
            {opt.key}{opt.label ? ` — ${opt.label.slice(0, 30)}` : ''}
          </option>
        ))}
      </select>
    </div>
  );
}
