'use client';

import { useReducer, useRef, useState, type CSSProperties } from 'react';
import { adminFetch } from '../../lib/api';
import {
  reduceDraftState,
  validateDraftInput,
  toGenerateDraftRequest,
  mapServerError,
  type CteniDraftType,
  type DraftFormInput,
  type DraftLevel,
  type DraftState,
} from '../../lib/ai-draft-utils';
import { GrammarPointPicker } from './GrammarPointPicker';
import { LevelRadio } from './LevelRadio';

type Props = {
  exerciseType: CteniDraftType;
  formDirty: boolean;
  onApply: (detail: Record<string, unknown>) => void;
};

const initialInput = (exerciseType: CteniDraftType): DraftFormInput => ({
  exerciseType,
  topic: '',
  grammarPointIds: [],
  level: 'A2',
  extraInstructions: '',
});

const initialState: DraftState = { status: 'idle' };

const panelStyle: CSSProperties = {
  display: 'grid',
  gap: 10,
  marginBottom: 16,
  padding: 12,
  borderRadius: 12,
  border: '1px solid #c4b5fd',
  background: '#f5f3ff',
};
const headerStyle: CSSProperties = { display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 };
const titleWrapStyle: CSSProperties = { display: 'flex', alignItems: 'center', gap: 8 };
const titleStyle: CSSProperties = { margin: 0, fontSize: 14, fontWeight: 700, color: '#4c1d95' };
const toggleStyle: CSSProperties = { border: 0, background: 'transparent', color: '#6d28d9', cursor: 'pointer', fontSize: 12, fontWeight: 700 };
const bodyStyle: CSSProperties = { display: 'grid', gap: 12 };
const fieldStyle: CSSProperties = { display: 'grid', gap: 6 };
const labelStyle: CSSProperties = { fontSize: 13, fontWeight: 600, color: 'var(--ink-2)' };
const requiredStyle: CSSProperties = { color: '#dc2626' };
const inputStyle: CSSProperties = {
  width: '100%',
  border: '1px solid var(--border-strong)',
  borderRadius: 8,
  padding: '8px 10px',
  fontSize: 14,
  fontFamily: 'inherit',
  background: '#fff',
};
const helperStyle: CSSProperties = { margin: 0, fontSize: 12, color: '#5b21b6' };
const errorStyle: CSSProperties = { margin: 0, fontSize: 12, color: '#be123c' };
const alertStyle: CSSProperties = {
  border: '1px solid #fda4af',
  borderRadius: 8,
  background: '#fff1f2',
  color: '#881337',
  padding: '8px 10px',
  fontSize: 12,
};
const actionsStyle: CSSProperties = { display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: 8 };
const primaryButtonStyle: CSSProperties = {
  display: 'inline-flex',
  alignItems: 'center',
  gap: 6,
  border: 0,
  borderRadius: 8,
  background: '#7c3aed',
  color: '#fff',
  cursor: 'pointer',
  fontSize: 13,
  fontWeight: 700,
  padding: '8px 12px',
};
const secondaryButtonStyle: CSSProperties = {
  border: '1px solid var(--border-strong)',
  borderRadius: 8,
  background: '#fff',
  color: 'var(--ink-2)',
  cursor: 'pointer',
  fontSize: 13,
  fontWeight: 600,
  padding: '8px 12px',
};
const filledChipStyle: CSSProperties = {
  display: 'inline-flex',
  alignItems: 'center',
  gap: 4,
  borderRadius: 999,
  background: '#d1fae5',
  color: '#065f46',
  fontSize: 12,
  padding: '2px 8px',
};

// AiDraftPanel — collapsible inline panel sitting at the top of a reading
// exercise form. Submitting fires POST /api/admin/exercises/generate-draft;
// the server response is normalized via mapServerError and displayed
// inline. On success the parent receives the detail payload via onApply.
export function AiDraftPanel({ exerciseType, formDirty, onApply }: Props) {
  const [expanded, setExpanded] = useState(false);
  const [input, setInput] = useState<DraftFormInput>(initialInput(exerciseType));
  const [state, dispatch] = useReducer(reduceDraftState, initialState);
  const [validationErr, setValidationErr] = useState<string>('');
  const abortRef = useRef<AbortController | null>(null);

  const isLoading = state.status === 'loading';
  const isFilled = state.status === 'success';

  async function performGenerate(submitted: DraftFormInput) {
    abortRef.current?.abort();
    const ctrl = new AbortController();
    abortRef.current = ctrl;

    try {
      const res = await adminFetch('/api/admin/exercises/generate-draft', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(toGenerateDraftRequest(submitted)),
        signal: ctrl.signal,
      });
      // Guard: admin clicked Cancel after the response had already settled.
      // Without this, dispatch would push success/error over the idle state.
      if (ctrl.signal.aborted) return;
      const body: any = await res.json().catch(() => ({}));
      if (ctrl.signal.aborted) return;
      if (!res.ok) {
        const code: string | undefined = body?.error?.code;
        const message: string | undefined = body?.error?.message;
        dispatch({ type: 'response-error', message: mapServerError(code, message) });
        return;
      }
      const detail = body?.data?.detail as Record<string, unknown> | undefined;
      if (!detail) {
        dispatch({ type: 'response-error', message: mapServerError('schema_mismatch') });
        return;
      }
      onApply(detail);
      dispatch({ type: 'response-ok', input: submitted });
    } catch (err: unknown) {
      if ((err as Error)?.name === 'AbortError') return;
      if (ctrl.signal.aborted) return;
      dispatch({ type: 'response-error', message: mapServerError('llm_error') });
    }
  }

  function handleSubmit(e?: React.FormEvent) {
    e?.preventDefault();
    const v = validateDraftInput(input);
    if (!v.ok) {
      setValidationErr(v.message);
      return;
    }
    setValidationErr('');
    dispatch({ type: 'submit', input, formDirty });
    // Avoid running the request when the reducer kept us in confirm-overwrite.
    if (state.status === 'success' && formDirty) return;
    void performGenerate(input);
  }

  function handleConfirmOverwrite() {
    if (state.status !== 'confirm-overwrite') return;
    const pending = state.pendingInput;
    dispatch({ type: 'confirm-overwrite' });
    void performGenerate(pending);
  }

  function handleCancel() {
    abortRef.current?.abort();
    dispatch({ type: 'cancel' });
  }

  return (
    <section
      aria-label="Tạo nháp bằng AI"
      style={panelStyle}
    >
      <header style={headerStyle}>
        <div style={titleWrapStyle}>
          <SparklesIcon style={{ width: 18, height: 18, color: '#6d28d9', flexShrink: 0 }} />
          <h3 style={titleStyle}>Tạo nháp bằng AI</h3>
          {isFilled && (
            <span style={filledChipStyle}>
              ✨ Đã sinh nháp
            </span>
          )}
        </div>
        <button
          type="button"
          onClick={() => setExpanded((x) => !x)}
          style={toggleStyle}
          aria-expanded={expanded}
        >
          {expanded ? 'Thu gọn' : 'Mở rộng'}
        </button>
      </header>

      {!expanded && (
        <p style={helperStyle}>
          Nhập chủ đề + ngữ pháp + cấp độ, AI sinh đoạn văn + câu hỏi để bạn duyệt.
        </p>
      )}

      {expanded && (
        <div style={bodyStyle}>
          <div style={fieldStyle}>
            <label style={labelStyle}>
              Chủ đề <span style={requiredStyle}>*</span>
            </label>
            <input
              type="text"
              value={input.topic}
              onChange={(e) => setInput({ ...input, topic: e.target.value })}
              disabled={isLoading}
              maxLength={200}
              placeholder="vd: đi khám bác sĩ, mua hàng, đi du lịch Praha..."
              style={inputStyle}
            />
          </div>

          <GrammarPointPicker
            selectedIds={input.grammarPointIds}
            onChange={(ids) => setInput({ ...input, grammarPointIds: ids })}
            level={input.level || undefined}
            disabled={isLoading}
          />

          <LevelRadio
            value={input.level}
            onChange={(level) => setInput({ ...input, level })}
            disabled={isLoading}
          />

          <div style={fieldStyle}>
            <label style={labelStyle}>Hướng dẫn thêm (tùy chọn)</label>
            <textarea
              value={input.extraInstructions}
              onChange={(e) => setInput({ ...input, extraInstructions: e.target.value })}
              disabled={isLoading}
              maxLength={500}
              rows={2}
              placeholder="vd: dùng giọng văn thân mật, có 2 nhân vật..."
              style={{ ...inputStyle, resize: 'vertical', minHeight: 72 }}
            />
          </div>

          {validationErr && <p style={errorStyle}>{validationErr}</p>}

          {state.status === 'error' && (
            <div role="alert" style={alertStyle}>
              {state.message}
            </div>
          )}

          <div style={actionsStyle}>
            {isLoading ? (
              <>
                <div aria-live="polite" style={helperStyle}>
                  AI đang sinh nội dung... (~10s)
                </div>
                <button
                  type="button"
                  onClick={handleCancel}
                  style={secondaryButtonStyle}
                >
                  Hủy
                </button>
              </>
            ) : (
              <button
                type="button"
                onClick={() => handleSubmit()}
                disabled={isLoading}
                aria-busy={isLoading}
                style={{ ...primaryButtonStyle, opacity: isLoading ? 0.6 : 1 }}
              >
                <SparklesIcon style={{ width: 16, height: 16, flexShrink: 0 }} />
                {isFilled ? 'Tạo lại' : 'Sinh nháp'}
              </button>
            )}
          </div>
        </div>
      )}

      {state.status === 'confirm-overwrite' && (
        <ConfirmOverwriteDialog
          onConfirm={handleConfirmOverwrite}
          onDismiss={() => dispatch({ type: 'dismiss-overwrite' })}
        />
      )}
    </section>
  );
}

// ── Confirm-overwrite dialog ─────────────────────────────────────────────────

function ConfirmOverwriteDialog({ onConfirm, onDismiss }: { onConfirm: () => void; onDismiss: () => void }) {
  return (
    <div role="dialog" aria-modal="true" style={{ position: 'fixed', inset: 0, zIndex: 50, display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'rgba(0,0,0,0.4)', padding: 16 }}>
      <div style={{ width: '100%', maxWidth: 420, borderRadius: 12, background: '#fff', padding: 20, boxShadow: '0 20px 50px rgba(15,23,42,0.2)' }}>
        <h4 style={{ margin: 0, fontSize: 16, fontWeight: 700, color: 'var(--ink)' }}>Ghi đè nội dung hiện tại?</h4>
        <p style={{ margin: '8px 0 0', fontSize: 14, color: 'var(--ink-2)' }}>
          Đoạn văn và câu hỏi đang có trên form sẽ bị thay thế. Không thể hoàn tác.
        </p>
        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8, marginTop: 16 }}>
          <button
            type="button"
            onClick={onDismiss}
            style={secondaryButtonStyle}
          >
            Hủy
          </button>
          <button
            type="button"
            onClick={onConfirm}
            style={{ ...primaryButtonStyle, background: '#e11d48' }}
          >
            Ghi đè & Tạo lại
          </button>
        </div>
      </div>
    </div>
  );
}

function SparklesIcon({ style }: { style?: CSSProperties }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" style={style} aria-hidden>
      <path d="M12 3v3M12 18v3M3 12h3M18 12h3M5.6 5.6l2.1 2.1M16.3 16.3l2.1 2.1M5.6 18.4l2.1-2.1M16.3 7.7l2.1-2.1" />
    </svg>
  );
}
