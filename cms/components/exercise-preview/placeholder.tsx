'use client';

// V23 Phase C6 — fallback card for the 11 exercise types that don't
// have a dedicated V23 preview. Top 5 covered: uloha_1, uloha_2,
// uloha_3, uloha_4, psani_2_email. Everything else falls through
// here so the layout still renders without runtime errors.
export function PreviewPlaceholder({ type }: { type: string }) {
  return (
    <div
      style={{
        padding: '24px 16px',
        textAlign: 'center',
        color: 'var(--ink-3)',
        background: 'var(--surface)',
        borderRadius: 8,
        border: '1px dashed var(--border)',
      }}
    >
      <p style={{ fontSize: 28, margin: '0 0 8px' }}>👁</p>
      <p style={{ margin: '0 0 6px', fontWeight: 600, color: 'var(--ink-2)' }}>
        Preview cho type <code>{type || '(chưa chọn)'}</code> chưa hỗ trợ V23.
      </p>
      <p style={{ fontSize: 12, margin: 0 }}>
        Top 5 type V23: <code>uloha_1</code>, <code>uloha_2</code>,
        {' '}<code>uloha_3</code>, <code>uloha_4</code>,
        {' '}<code>psani_2_email</code>. Test learner-side trên Flutter
        trước khi ship.
      </p>
    </div>
  );
}
