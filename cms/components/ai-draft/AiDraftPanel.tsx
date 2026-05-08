'use client';

import { useReducer, useRef, useState } from 'react';
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
      className="mb-4 rounded-lg border border-violet-200 bg-violet-50 p-3"
    >
      <header className="flex items-center justify-between gap-2">
        <div className="flex items-center gap-2">
          <SparklesIcon className="h-4 w-4 text-violet-600" />
          <h3 className="text-sm font-semibold text-violet-900">Tạo nháp bằng AI</h3>
          {isFilled && (
            <span className="ml-2 inline-flex items-center gap-1 rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-900">
              ✨ Đã sinh nháp
            </span>
          )}
        </div>
        <button
          type="button"
          onClick={() => setExpanded((x) => !x)}
          className="text-xs font-medium text-violet-700 hover:underline"
          aria-expanded={expanded}
        >
          {expanded ? 'Thu gọn' : 'Mở rộng'}
        </button>
      </header>

      {!expanded && (
        <p className="mt-1 text-xs text-violet-800">
          Nhập chủ đề + ngữ pháp + cấp độ, AI sinh đoạn văn + câu hỏi để bạn duyệt.
        </p>
      )}

      {expanded && (
        <form onSubmit={handleSubmit} className="mt-3 flex flex-col gap-3">
          <div className="flex flex-col gap-1.5">
            <label className="text-sm font-medium text-slate-700">
              Chủ đề <span className="text-rose-600">*</span>
            </label>
            <input
              type="text"
              value={input.topic}
              onChange={(e) => setInput({ ...input, topic: e.target.value })}
              disabled={isLoading}
              maxLength={200}
              placeholder="vd: đi khám bác sĩ, mua hàng, đi du lịch Praha..."
              className="rounded-md border border-slate-300 px-3 py-1.5 text-sm focus:border-violet-500 focus:outline-none focus:ring-1 focus:ring-violet-500 disabled:bg-slate-100"
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

          <div className="flex flex-col gap-1.5">
            <label className="text-sm font-medium text-slate-700">Hướng dẫn thêm (tùy chọn)</label>
            <textarea
              value={input.extraInstructions}
              onChange={(e) => setInput({ ...input, extraInstructions: e.target.value })}
              disabled={isLoading}
              maxLength={500}
              rows={2}
              placeholder="vd: dùng giọng văn thân mật, có 2 nhân vật..."
              className="rounded-md border border-slate-300 px-3 py-1.5 text-sm focus:border-violet-500 focus:outline-none focus:ring-1 focus:ring-violet-500 disabled:bg-slate-100"
            />
          </div>

          {validationErr && <p className="text-xs text-rose-700">{validationErr}</p>}

          {state.status === 'error' && (
            <div role="alert" className="rounded-md border border-rose-300 bg-rose-50 px-3 py-2 text-xs text-rose-900">
              {state.message}
            </div>
          )}

          <div className="flex items-center justify-end gap-2">
            {isLoading ? (
              <>
                <div aria-live="polite" className="text-xs text-violet-800">
                  AI đang sinh nội dung... (~10s)
                </div>
                <button
                  type="button"
                  onClick={handleCancel}
                  className="rounded-md border border-slate-300 bg-white px-3 py-1.5 text-sm text-slate-700 hover:bg-slate-50"
                >
                  Hủy
                </button>
              </>
            ) : (
              <button
                type="submit"
                disabled={isLoading}
                aria-busy={isLoading}
                className="inline-flex items-center gap-1.5 rounded-md bg-violet-600 px-3 py-1.5 text-sm font-medium text-white hover:bg-violet-700 disabled:bg-violet-300"
              >
                <SparklesIcon className="h-4 w-4" />
                {isFilled ? 'Tạo lại' : 'Sinh nháp'}
              </button>
            )}
          </div>
        </form>
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
    <div role="dialog" aria-modal="true" className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="w-full max-w-md rounded-lg bg-white p-5 shadow-xl">
        <h4 className="text-base font-semibold text-slate-900">Ghi đè nội dung hiện tại?</h4>
        <p className="mt-2 text-sm text-slate-700">
          Đoạn văn và câu hỏi đang có trên form sẽ bị thay thế. Không thể hoàn tác.
        </p>
        <div className="mt-4 flex justify-end gap-2">
          <button
            type="button"
            onClick={onDismiss}
            className="rounded-md border border-slate-300 bg-white px-3 py-1.5 text-sm text-slate-700 hover:bg-slate-50"
          >
            Hủy
          </button>
          <button
            type="button"
            onClick={onConfirm}
            className="rounded-md bg-rose-600 px-3 py-1.5 text-sm font-medium text-white hover:bg-rose-700"
          >
            Ghi đè & Tạo lại
          </button>
        </div>
      </div>
    </div>
  );
}

function SparklesIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" className={className} aria-hidden>
      <path d="M12 3v3M12 18v3M3 12h3M18 12h3M5.6 5.6l2.1 2.1M16.3 16.3l2.1 2.1M5.6 18.4l2.1-2.1M16.3 7.7l2.1-2.1" />
    </svg>
  );
}
