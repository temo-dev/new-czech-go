'use client';

import { useEffect, useState } from 'react';

type Props = {
  systemPrompt: string;
  /** Override fetch for tests. */
  fetchImpl?: typeof fetch;
  /** Override debounce for tests. */
  debounceMs?: number;
};

type State =
  | { kind: 'idle' }
  | { kind: 'loading' }
  | { kind: 'ready'; displayPrompt: string }
  | { kind: 'error'; message: string };

const cardStyle: React.CSSProperties = {
  border: '1px dashed var(--border-strong)',
  borderRadius: 12,
  padding: '12px 14px',
  background: 'var(--surface-alt)',
  display: 'grid',
  gap: 8,
};

const labelStyle: React.CSSProperties = {
  fontSize: 11,
  fontWeight: 800,
  color: 'var(--orange)',
  letterSpacing: 1,
  textTransform: 'uppercase' as const,
};

const bodyStyle: React.CSSProperties = {
  fontSize: 13,
  color: 'var(--ink-2)',
  whiteSpace: 'pre-wrap' as const,
  lineHeight: 1.5,
};

export function PromptPreview({ systemPrompt, fetchImpl, debounceMs = 400 }: Props) {
  const [state, setState] = useState<State>({ kind: 'idle' });

  useEffect(() => {
    const trimmed = systemPrompt.trim();
    if (!trimmed) {
      setState({ kind: 'idle' });
      return;
    }
    const fetcher = fetchImpl ?? fetch;
    const controller = new AbortController();
    const timer = setTimeout(async () => {
      setState({ kind: 'loading' });
      try {
        const res = await fetcher('/api/admin/interview/preview-prompt', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ system_prompt: trimmed }),
          signal: controller.signal,
        });
        if (!res.ok) {
          setState({ kind: 'error', message: `Lỗi ${res.status}` });
          return;
        }
        const json = await res.json();
        const display = String(json?.data?.display_prompt ?? '');
        setState({ kind: 'ready', displayPrompt: display });
      } catch (err) {
        if (controller.signal.aborted) return;
        const msg = err instanceof Error ? err.message : 'unknown';
        setState({ kind: 'error', message: msg });
      }
    }, debounceMs);
    return () => {
      clearTimeout(timer);
      controller.abort();
    };
  }, [systemPrompt, fetchImpl, debounceMs]);

  if (state.kind === 'idle') {
    return (
      <div style={cardStyle} data-testid="prompt-preview-idle">
        <span style={labelStyle}>Preview cho học viên</span>
        <span style={{ ...bodyStyle, color: 'var(--ink-3)' }}>
          Nhập system prompt để xem đề bài học viên sẽ thấy.
        </span>
      </div>
    );
  }

  if (state.kind === 'loading') {
    return (
      <div style={cardStyle} data-testid="prompt-preview-loading">
        <span style={labelStyle}>Preview cho học viên</span>
        <span style={{ ...bodyStyle, color: 'var(--ink-3)' }}>Đang tải…</span>
      </div>
    );
  }

  if (state.kind === 'error') {
    return (
      <div style={{ ...cardStyle, borderColor: '#e53e3e' }} data-testid="prompt-preview-error">
        <span style={labelStyle}>Preview cho học viên</span>
        <span style={{ ...bodyStyle, color: '#e53e3e' }}>
          Không tải được preview ({state.message}).
        </span>
      </div>
    );
  }

  // ready
  return (
    <div style={cardStyle} data-testid="prompt-preview-ready">
      <span style={labelStyle}>Preview cho học viên</span>
      {state.displayPrompt ? (
        <span style={bodyStyle}>{state.displayPrompt}</span>
      ) : (
        <span style={{ ...bodyStyle, color: 'var(--ink-3)' }}>
          (System prompt chưa có khối ÚKOL/TASK rõ ràng — học viên sẽ không thấy đề bài)
        </span>
      )}
    </div>
  );
}
