'use client';

import { useEffect, useState } from 'react';
import { buildAnoNePayload, formStateFromAnoNe, type AnoNeStatementRow } from '../exercise-utils';

type AnoNeType = 'cteni_6' | 'poslech_6';

type Props = {
  exerciseType: AnoNeType;
  initialData: Record<string, unknown>;
  onChange: (detail: Record<string, unknown>) => void;
  editingId: string | null;
  audioGenerating: boolean;
  audioGenMsg: string | null;
  onGenerateAudio: () => void;
};

const MAX_STATEMENTS = 5;
const INDICES = ['A', 'B', 'C', 'D', 'E'];

const labelStyle: React.CSSProperties = {
  fontSize: 13, fontWeight: 600, color: 'var(--ink-2)',
};
const sectionStyle: React.CSSProperties = {
  border: '1px solid var(--border)', borderRadius: 12, padding: '14px 16px',
  display: 'grid', gap: 10, background: 'var(--surface-alt)',
};
const txStyle: React.CSSProperties = {
  padding: '8px 10px', border: '1px solid var(--border-strong)', borderRadius: 8,
  fontSize: 14, resize: 'vertical' as const, fontFamily: 'inherit',
};
const inputStyle: React.CSSProperties = {
  padding: '7px 10px', border: '1px solid var(--border-strong)', borderRadius: 8,
  fontSize: 13, fontFamily: 'inherit', flex: 1,
};

function emptyStatement(): AnoNeStatementRow {
  return { statement: '', correct: 'ANO' };
}

function initState(detail: Record<string, unknown>) {
  const state = formStateFromAnoNe(detail);
  return state.statements.length > 0
    ? state
    : { passage: state.passage, statements: [emptyStatement()], maxPoints: state.maxPoints };
}

export function AnoNeFields({
  exerciseType, initialData, onChange, editingId,
  audioGenerating, audioGenMsg, onGenerateAudio,
}: Props) {
  const [state, setState] = useState(() => initState(initialData));

  // Re-init when opening a different exercise in edit mode
  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => { setState(initState(initialData)); }, [editingId, JSON.stringify(initialData)]);

  function emit(next: typeof state) {
    setState(next);
    try {
      onChange(buildAnoNePayload(next));
    } catch {
      // invalid (e.g. 0 statements during construction) — don't emit
    }
  }

  function setPassage(passage: string) { emit({ ...state, passage }); }
  function setMaxPoints(maxPoints: number) { emit({ ...state, maxPoints }); }

  function setStatement(i: number, statement: string) {
    const statements = state.statements.map((s, idx) => idx === i ? { ...s, statement } : s);
    emit({ ...state, statements });
  }

  function setCorrect(i: number, correct: 'ANO' | 'NE') {
    const statements = state.statements.map((s, idx) => idx === i ? { ...s, correct } : s);
    emit({ ...state, statements });
  }

  function addStatement() {
    if (state.statements.length >= MAX_STATEMENTS) return;
    emit({ ...state, statements: [...state.statements, emptyStatement()] });
  }

  function removeStatement(i: number) {
    if (state.statements.length <= 1) return;
    emit({ ...state, statements: state.statements.filter((_, idx) => idx !== i) });
  }

  const isPoslech = exerciseType === 'poslech_6';

  return (
    <div style={{ display: 'grid', gap: 14 }}>

      {/* Passage */}
      <div style={sectionStyle}>
        <span style={labelStyle}>
          {isPoslech ? 'Script (prose cho Polly TTS) *' : 'Văn bản *'}
        </span>
        {isPoslech && (
          <p style={{ fontSize: 12, color: 'var(--ink-3)', margin: 0 }}>
            Nhập dạng văn xuôi — không dùng bảng cột. Ví dụ: &ldquo;V pondělí je úřad otevřen od osmi do jedenácti hodin třicet.&rdquo;
          </p>
        )}
        <textarea
          style={{ ...txStyle, minHeight: 100 }}
          value={state.passage}
          placeholder={isPoslech ? 'Vlašim. Městský úřad je otevřen v pondělí...' : 'Vlašim\nMěstský úřad – úřední hodiny\n...'}
          onChange={(e) => setPassage(e.target.value)}
        />
        {isPoslech && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <button
              type="button"
              disabled={audioGenerating || !editingId}
              onClick={onGenerateAudio}
              style={{
                padding: '7px 16px', borderRadius: 8, border: 'none',
                background: audioGenerating ? 'var(--surface-muted)' : 'var(--accent)',
                color: audioGenerating ? 'var(--ink-3)' : '#fff',
                fontWeight: 600, fontSize: 13, cursor: audioGenerating || !editingId ? 'not-allowed' : 'pointer',
              }}
            >
              {audioGenerating ? 'Đang tạo…' : '🔊 Tạo audio (Polly)'}
            </button>
            {!editingId && (
              <span style={{ fontSize: 12, color: 'var(--ink-3)' }}>Lưu bài trước khi tạo audio.</span>
            )}
            {audioGenMsg && (
              <span style={{ fontSize: 12, color: audioGenMsg.includes('Đã') ? 'var(--success)' : 'var(--error)' }}>
                {audioGenMsg}
              </span>
            )}
          </div>
        )}
      </div>

      {/* Max points */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
        <div>
          <span style={labelStyle}>Điểm tối đa *</span>
          <input
            type="number"
            min={1}
            max={20}
            style={{ ...inputStyle, marginTop: 4, width: '100%' }}
            value={state.maxPoints}
            onChange={(e) => setMaxPoints(Number(e.target.value) || 1)}
          />
        </div>
      </div>

      {/* Statements */}
      <div style={sectionStyle}>
        <span style={labelStyle}>Câu phát biểu (1–{MAX_STATEMENTS}) *</span>

        {state.statements.map((row, i) => (
          <div
            key={i}
            style={{ display: 'flex', alignItems: 'center', gap: 8 }}
          >
            {/* Index badge */}
            <div style={{
              width: 24, height: 24, borderRadius: '50%',
              background: 'var(--accent)', color: '#fff',
              fontSize: 11, fontWeight: 700,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              flexShrink: 0,
            }}>
              {INDICES[i]}
            </div>

            {/* Statement text */}
            <input
              style={inputStyle}
              placeholder={`Câu phát biểu ${INDICES[i]}…`}
              value={row.statement}
              onChange={(e) => setStatement(i, e.target.value)}
            />

            {/* ANO/NE toggle */}
            <div style={{ display: 'flex', gap: 4, flexShrink: 0 }}>
              {(['ANO', 'NE'] as const).map((ans) => (
                <button
                  key={ans}
                  type="button"
                  onClick={() => setCorrect(i, ans)}
                  style={{
                    height: 30, padding: '0 12px', borderRadius: 6, border: '1.5px solid',
                    fontWeight: 700, fontSize: 12, cursor: 'pointer',
                    borderColor: row.correct === ans
                      ? (ans === 'ANO' ? '#2E7D32' : '#C62828')
                      : 'var(--border-strong)',
                    background: row.correct === ans
                      ? (ans === 'ANO' ? '#2E7D32' : '#C62828')
                      : 'var(--surface)',
                    color: row.correct === ans ? '#fff' : 'var(--ink-2)',
                  }}
                >
                  {ans}
                </button>
              ))}
            </div>

            {/* Delete */}
            <button
              type="button"
              onClick={() => removeStatement(i)}
              disabled={state.statements.length <= 1}
              style={{
                width: 28, height: 28, borderRadius: '50%',
                border: '1px solid var(--border)', background: 'var(--surface)',
                cursor: state.statements.length <= 1 ? 'not-allowed' : 'pointer',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                opacity: state.statements.length <= 1 ? 0.4 : 1,
                flexShrink: 0,
              }}
              title="Xoá câu này"
            >
              ×
            </button>
          </div>
        ))}

        <button
          type="button"
          onClick={addStatement}
          disabled={state.statements.length >= MAX_STATEMENTS}
          style={{
            height: 34, border: '1.5px dashed var(--border-strong)', borderRadius: 8,
            background: 'transparent', color: 'var(--ink-2)',
            fontSize: 12, fontWeight: 600, cursor: state.statements.length >= MAX_STATEMENTS ? 'not-allowed' : 'pointer',
            opacity: state.statements.length >= MAX_STATEMENTS ? 0.5 : 1,
          }}
        >
          + Thêm câu {state.statements.length < MAX_STATEMENTS ? `(còn ${MAX_STATEMENTS - state.statements.length})` : '(đã đủ 5)'}
        </button>
      </div>
    </div>
  );
}
