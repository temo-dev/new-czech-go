'use client';

import { useEffect, useState } from 'react';
import {
  buildInterviewConversationPayload,
  formStateFromInterviewConversation,
  type InterviewConversationFormState,
} from '../exercise-utils';

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

function initState(detail: Record<string, unknown>): InterviewConversationFormState {
  const s = formStateFromInterviewConversation(detail);
  return s.topic ? s : { ...s, maxTurns: s.maxTurns || 8, showTranscript: s.showTranscript ?? true };
}

export function InterviewConversationFields({ initialData, onChange, editingId }: Props) {
  const [state, setState] = useState(() => initState(initialData));

  // Re-init when a different exercise is opened in edit mode.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => { setState(initState(initialData)); }, [editingId]);

  function emit(next: typeof state) {
    setState(next);
    try {
      onChange(buildInterviewConversationPayload(next));
    } catch {
      // validation error — do not propagate partial payload
    }
  }

  function updateTip(i: number, value: string) {
    const tips = [...state.tips];
    tips[i] = value;
    emit({ ...state, tips });
  }

  function addTip() {
    emit({ ...state, tips: [...state.tips, ''] });
  }

  function removeTip(i: number) {
    const tips = state.tips.filter((_, idx) => idx !== i);
    emit({ ...state, tips });
  }

  const isSystemPromptError = !state.systemPrompt.trim();

  return (
    <div style={{ display: 'grid', gap: 14 }}>
      <div style={sectionStyle}>
        <span style={labelStyle}>Chủ đề (hiển thị trong Intro screen cho learner) *</span>
        <input
          style={inputStyle}
          value={state.topic}
          onChange={(e) => emit({ ...state, topic: e.target.value })}
          placeholder="Ví dụ: Gia đình và bạn bè"
        />

        <span style={labelStyle}>System Prompt cho ElevenLabs Agent *</span>
        <div style={{ fontSize: 12, color: 'var(--ink-3)', marginTop: -6 }}>
          Agent dùng prompt này để đóng vai examiner Czech và dẫn dắt hội thoại A2.
        </div>
        <textarea
          style={{ ...txStyle, borderColor: isSystemPromptError ? '#e53e3e' : undefined }}
          value={state.systemPrompt}
          onChange={(e) => emit({ ...state, systemPrompt: e.target.value })}
          placeholder="You are Jana Nováková, a Czech A2 examiner. Ask 5-8 questions about the topic..."
        />
        {isSystemPromptError && (
          <span style={{ fontSize: 12, color: '#e53e3e' }}>System prompt là bắt buộc.</span>
        )}

        <div style={{ display: 'flex', gap: 16, alignItems: 'center' }}>
          <div style={{ flex: 1 }}>
            <span style={labelStyle}>Số lượt tối đa (max_turns)</span>
            <input
              style={{ ...inputStyle, width: 80 }}
              type="number"
              min={4}
              max={12}
              value={state.maxTurns}
              onChange={(e) => emit({ ...state, maxTurns: Number(e.target.value) })}
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
      </div>

      {/* Tips (optional) */}
      <div style={sectionStyle}>
        <span style={labelStyle}>Gợi ý cho learner (tuỳ chọn, tối đa 5)</span>
        <div style={{ fontSize: 12, color: 'var(--ink-3)', marginTop: -6 }}>
          Hiển thị trong Intro screen trước khi bắt đầu phỏng vấn.
        </div>
        {state.tips.map((tip, i) => (
          <div key={i} style={{ display: 'flex', gap: 6 }}>
            <input
              style={{ ...inputStyle, flex: 1 }}
              value={tip}
              onChange={(e) => updateTip(i, e.target.value)}
              placeholder={`Gợi ý ${i + 1}`}
            />
            <button
              type="button"
              onClick={() => removeTip(i)}
              style={{ padding: '6px 10px', borderRadius: 6, border: '1px solid var(--border)', cursor: 'pointer', fontSize: 12 }}
            >
              Xóa
            </button>
          </div>
        ))}
        {state.tips.length < 5 && (
          <button
            type="button"
            onClick={addTip}
            style={{ padding: '7px 14px', borderRadius: 8, border: '1px solid var(--border)', cursor: 'pointer', fontSize: 12, fontWeight: 600, color: 'var(--teal)', background: 'var(--teal-dim)', alignSelf: 'flex-start' }}
          >
            + Thêm gợi ý
          </button>
        )}
      </div>
    </div>
  );
}
