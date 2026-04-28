'use client';

type Props = {
  optionKey: string;
  label: string;
  onChange: (label: string) => void;
  onRemove?: () => void;
  placeholder?: string;
};

export function OptionRow({ optionKey, label, onChange, onRemove, placeholder }: Props) {
  return (
    <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
      <span style={{
        display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
        width: 28, height: 28, borderRadius: 6,
        background: 'var(--accent-soft)', color: 'var(--accent)',
        fontSize: 12, fontWeight: 700, flexShrink: 0,
      }}>
        {optionKey}
      </span>
      <input
        type="text"
        value={label}
        onChange={e => onChange(e.target.value)}
        placeholder={placeholder ?? `Nội dung lựa chọn ${optionKey}...`}
        style={{
          flex: 1,
          padding: '7px 10px',
          border: '1px solid var(--border-strong)',
          borderRadius: 8,
          fontSize: 14,
          color: 'var(--ink)',
          background: 'var(--surface)',
          fontFamily: 'inherit',
        }}
      />
      {onRemove && (
        <button
          type="button"
          onClick={onRemove}
          title="Xóa lựa chọn"
          style={{
            background: 'none', border: '1px solid var(--border)', borderRadius: 6,
            width: 28, height: 28, cursor: 'pointer', fontSize: 14,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: 'var(--error)', flexShrink: 0,
          }}
        >×</button>
      )}
    </div>
  );
}
