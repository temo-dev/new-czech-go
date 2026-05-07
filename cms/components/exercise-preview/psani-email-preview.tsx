'use client';

import type { ExerciseFormState } from '../exercise-utils';

// V23 Phase C5 — preview for psani_2_email. Renders a low-fidelity
// mock of the email composer the learner sees on Flutter. Real send
// flow is intentionally disabled (textarea only, no submit button).

type Props = { form: ExerciseFormState };

export function PsaniEmailPreview({ form }: Props) {
  return (
    <div style={cardStyle}>
      <header style={{ borderBottom: '1px solid var(--border)', paddingBottom: 8, marginBottom: 12 }}>
        <p style={eyebrow}>Psaní 2 — E-mail</p>
        <h3 style={{ margin: '4px 0 0', fontSize: 16, fontWeight: 700 }}>
          {form.title || '(Chưa có tiêu đề)'}
        </h3>
        {form.shortInstruction && (
          <p style={{ margin: '6px 0 0', fontSize: 13, color: 'var(--ink-2)' }}>
            {form.shortInstruction}
          </p>
        )}
      </header>

      {form.scenarioPrompt && (
        <div style={{ marginBottom: 12, padding: 10, background: 'var(--surface-alt)', borderRadius: 6, fontSize: 13 }}>
          <p style={{ margin: 0, fontWeight: 600, color: 'var(--ink-2)' }}>Tình huống:</p>
          <p style={{ margin: '4px 0 0', color: 'var(--ink)' }}>{form.scenarioPrompt}</p>
        </div>
      )}

      {form.requiredInfoSlots && (
        <div style={{ marginBottom: 12, fontSize: 12, color: 'var(--ink-3)' }}>
          <strong>Thông tin bắt buộc:</strong> {form.requiredInfoSlots}
        </div>
      )}

      <label style={{ display: 'block', fontSize: 12, fontWeight: 600, color: 'var(--ink-2)', marginBottom: 4 }}>
        Câu trả lời (preview — disabled)
      </label>
      <textarea
        disabled
        rows={6}
        placeholder="Trả lời email tại đây..."
        style={{
          width: '100%',
          padding: 10,
          fontSize: 13,
          border: '1px solid var(--border)',
          borderRadius: 6,
          background: 'var(--surface-alt)',
          color: 'var(--ink-3)',
          resize: 'none',
        }}
      />

      <p style={{ margin: '8px 0 0', fontSize: 11, color: 'var(--ink-4)' }}>
        Hướng dẫn: viết e-mail 50-70 từ.
      </p>
    </div>
  );
}

const cardStyle: React.CSSProperties = {
  padding: 16,
  background: 'var(--surface)',
  borderRadius: 10,
  border: '1px solid var(--border)',
};

const eyebrow: React.CSSProperties = {
  fontSize: 11,
  fontWeight: 700,
  color: 'var(--ink-3)',
  textTransform: 'uppercase',
  letterSpacing: 0.4,
  margin: 0,
};
