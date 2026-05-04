'use client';

import { useEffect, useState } from 'react';
import {
  buildInterviewChoiceExplainPayload,
  clampAudioBufferTimeoutMs,
  formStateFromInterviewChoiceExplain,
  type InterviewOptionRow,
  type InterviewChoiceExplainFormState,
} from '../exercise-utils';
import { PromptPreview } from '../PromptPreview';

type Props = {
  initialData: Record<string, unknown>;
  onChange: (detail: Record<string, unknown>) => void;
  editingId: string | null;
};

const labelStyle: React.CSSProperties = {
  fontSize: 13, fontWeight: 600, color: 'var(--ink-2)',
};
const sectionStyle: React.CSSProperties = {
  border: '1px solid var(--border)', borderRadius: 12, padding: '14px 16px',
  display: 'grid', gap: 10, background: 'var(--surface-alt)',
};
const inputStyle: React.CSSProperties = {
  padding: '7px 10px', border: '1px solid var(--border-strong)', borderRadius: 8,
  fontSize: 13, fontFamily: 'inherit', width: '100%',
};
const txStyle: React.CSSProperties = {
  ...inputStyle, height: 120, resize: 'vertical' as const,
};

const MAX_OPTIONS = 4;
const MIN_OPTIONS = 3;

function emptyOption(i: number): InterviewOptionRow {
  return { id: String(i + 1), label: '', imageAssetId: '' };
}

function initState(detail: Record<string, unknown>): InterviewChoiceExplainFormState {
  const s = formStateFromInterviewChoiceExplain(detail);
  // Ensure at least 3 options on first open
  if (s.options.length < MIN_OPTIONS) {
    const padded = [...s.options];
    while (padded.length < MIN_OPTIONS) padded.push(emptyOption(padded.length));
    return { ...s, options: padded };
  }
  return s;
}

export function InterviewChoiceExplainFields({ initialData, onChange, editingId }: Props) {
  const [state, setState] = useState(() => initState(initialData));

  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => { setState(initState(initialData)); }, [editingId]);

  function emit(next: typeof state) {
    setState(next);
    try {
      onChange(buildInterviewChoiceExplainPayload(next));
    } catch {
      // validation error — do not propagate partial payload
    }
  }

  function updateOption(i: number, field: keyof InterviewOptionRow, value: string) {
    const options = state.options.map((o, idx) => idx === i ? { ...o, [field]: value } : o);
    emit({ ...state, options });
  }

  function addOption() {
    if (state.options.length >= MAX_OPTIONS) return;
    emit({ ...state, options: [...state.options, emptyOption(state.options.length)] });
  }

  function removeOption(i: number) {
    if (state.options.length <= MIN_OPTIONS) return;
    const options = state.options.filter((_, idx) => idx !== i);
    emit({ ...state, options });
  }

  const isSystemPromptError = !state.systemPrompt.trim();
  const tooFew = state.options.length < MIN_OPTIONS;

  return (
    <div style={{ display: 'grid', gap: 14 }}>
      <div style={sectionStyle}>
        <span style={labelStyle}>Câu hỏi chính (hiển thị cho learner) *</span>
        <input
          style={inputStyle}
          value={state.question}
          onChange={(e) => emit({ ...state, question: e.target.value })}
          placeholder="Ví dụ: Bạn muốn đi du lịch ở đâu?"
        />

        <span style={labelStyle}>System Prompt cho ElevenLabs Agent *</span>
        <div style={{ fontSize: 12, color: 'var(--ink-3)', marginTop: -6 }}>
          Dùng <code style={{ background: 'var(--surface)', padding: '1px 4px', borderRadius: 4 }}>
            {'{selected_option}'}
          </code> để agent biết learner đã chọn phương án nào.
        </div>
        <textarea
          style={{ ...txStyle, borderColor: isSystemPromptError ? '#e53e3e' : undefined }}
          value={state.systemPrompt}
          onChange={(e) => emit({ ...state, systemPrompt: e.target.value })}
          placeholder="You are Jana. The learner chose {selected_option}. Ask 4-6 follow-up questions..."
        />
        {isSystemPromptError && (
          <span style={{ fontSize: 12, color: '#e53e3e' }}>System prompt là bắt buộc.</span>
        )}
        {!isSystemPromptError && !state.systemPrompt.includes('{selected_option}') && (
          <span style={{ fontSize: 12, color: '#d97706' }}>
            Gợi ý: thêm <code>{'{selected_option}'}</code> để agent biết lựa chọn của learner.
          </span>
        )}

        <div style={{ display: 'flex', gap: 16, alignItems: 'center', flexWrap: 'wrap' }}>
          <div>
            <span style={labelStyle}>Số lượt tối đa (max_turns)</span>
            <input
              style={{ ...inputStyle, width: 80 }}
              type="number"
              min={4}
              max={10}
              value={state.maxTurns}
              onChange={(e) => emit({ ...state, maxTurns: Number(e.target.value) })}
            />
          </div>
          <div>
            <span style={labelStyle}>Audio buffer timeout (ms)</span>
            <input
              style={{ ...inputStyle, width: 100 }}
              type="number"
              min={500}
              max={5000}
              step={100}
              value={state.audioBufferTimeoutMs}
              onChange={(e) => emit({
                ...state,
                audioBufferTimeoutMs: clampAudioBufferTimeoutMs(e.target.value),
              })}
            />
          </div>
          <div>
            <span style={labelStyle}>Hiển thị transcript realtime</span>
            <label style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 4 }}>
              <input
                type="checkbox"
                checked={state.showTranscript}
                onChange={(e) => emit({ ...state, showTranscript: e.target.checked })}
              />
              <span style={{ fontSize: 13 }}>Bật phụ đề dưới avatar</span>
            </label>
          </div>
        </div>
        <div style={{ fontSize: 11, color: 'var(--ink-3)' }}>
          V16: thời gian buffer audio đầu khi Simli avatar chưa render frame đầu (range 500-5000ms, mặc định 1500).
        </div>

        <PromptPreview systemPrompt={state.systemPrompt} />
      </div>

      {/* Options (3–4) */}
      <div style={sectionStyle}>
        <span style={labelStyle}>
          Các phương án ({MIN_OPTIONS}–{MAX_OPTIONS} phương án) *
        </span>
        {tooFew && (
          <span style={{ fontSize: 12, color: '#e53e3e' }}>Cần ít nhất {MIN_OPTIONS} phương án.</span>
        )}
        {state.options.map((opt, i) => (
          <div key={i} style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
            <div style={{
              width: 24, height: 24, borderRadius: '50%', background: 'var(--teal-dim)',
              color: 'var(--teal)', fontSize: 11, fontWeight: 700,
              display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
            }}>
              {i + 1}
            </div>
            <input
              style={{ ...inputStyle, flex: 1 }}
              value={opt.label}
              onChange={(e) => updateOption(i, 'label', e.target.value)}
              placeholder={`Phương án ${i + 1} (vd: Praha)`}
            />
            {state.options.length > MIN_OPTIONS && (
              <button
                type="button"
                onClick={() => removeOption(i)}
                style={{ padding: '6px 10px', borderRadius: 6, border: '1px solid var(--border)', cursor: 'pointer', fontSize: 12 }}
              >
                Xóa
              </button>
            )}
          </div>
        ))}
        {state.options.length < MAX_OPTIONS && (
          <button
            type="button"
            onClick={addOption}
            style={{ padding: '7px 14px', borderRadius: 8, border: '1px solid var(--border)', cursor: 'pointer', fontSize: 12, fontWeight: 600, color: 'var(--teal)', background: 'var(--teal-dim)', alignSelf: 'flex-start' }}
          >
            + Thêm phương án
          </button>
        )}
      </div>
    </div>
  );
}
