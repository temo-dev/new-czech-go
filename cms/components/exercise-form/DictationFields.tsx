'use client';

import { useEffect, useState } from 'react';
import {
  type DictationFormState,
  type DictationSentenceForm,
  formStateFromDictation,
  buildDictationPayload,
  splitTranscriptIntoSentences,
  validateDictation,
  emptyDictationFormState,
  DICTATION_MIN_SENTENCES,
  DICTATION_MAX_SENTENCES,
  DICTATION_MAX_SENTENCE_CHARS,
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
  fontSize: 13, fontFamily: 'inherit', flex: 1,
};
const txStyle: React.CSSProperties = {
  ...inputStyle, resize: 'vertical' as const, minHeight: 96,
};

function initState(detail: Record<string, unknown>): DictationFormState {
  const state = formStateFromDictation(detail);
  if (state.sentences.length === 0 && !state.topic) {
    return emptyDictationFormState();
  }
  return state;
}

export function DictationFields({ initialData, onChange, editingId }: Props) {
  const [state, setState] = useState(() => initState(initialData));
  const [transcript, setTranscript] = useState('');
  const [busyIdx, setBusyIdx] = useState<number | null>(null);
  const [rowError, setRowError] = useState<string | null>(null);

  // Re-init only when editingId changes (matches AnoNeFields pattern).
  // Reconstruct the raw transcript from sentences so admins re-opening an
  // edit see their original paragraph back in the textarea.
  useEffect(() => {
    const next = initState(initialData);
    setState(next);
    setTranscript(next.sentences.map((s) => s.text).join(' '));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [editingId]);

  function emit(next: DictationFormState) {
    setState(next);
    onChange(buildDictationPayload(next));
  }

  function setTopic(topic: string) { emit({ ...state, topic }); }
  function setMaxReplays(n: number) { emit({ ...state, maxReplaysPerSentence: n }); }
  function setMaxPoints(n: number) { emit({ ...state, maxPoints: n }); }
  function setThreshold(n: number) { emit({ ...state, passThresholdPercent: n }); }
  function setVoiceId(v: string) { emit({ ...state, voiceId: v }); }

  function setSentenceText(i: number, text: string) {
    const sentences = state.sentences.map((s, idx) => idx === i ? { ...s, text } : s);
    emit({ ...state, sentences });
  }

  function addSentence() {
    if (state.sentences.length >= DICTATION_MAX_SENTENCES) return;
    const next: DictationSentenceForm = { idx: state.sentences.length, text: '', audioAssetId: null };
    emit({ ...state, sentences: [...state.sentences, next] });
  }

  function removeSentence(i: number) {
    const sentences = state.sentences.filter((_, idx) => idx !== i).map((s, idx) => ({ ...s, idx }));
    emit({ ...state, sentences });
  }

  function applySplit() {
    const parts = splitTranscriptIntoSentences(transcript);
    if (parts.length === 0) return;
    const sentences: DictationSentenceForm[] = parts.slice(0, DICTATION_MAX_SENTENCES).map((text, idx) => ({
      idx, text, audioAssetId: null,
    }));
    emit({ ...state, sentences });
  }

  async function generateRowAudio(i: number) {
    if (!editingId) {
      setRowError('Lưu bài (Lưu nháp) trước khi tạo audio.');
      return;
    }
    const text = state.sentences[i]?.text.trim();
    if (!text) {
      setRowError(`Câu ${i + 1}: thiếu nội dung.`);
      return;
    }
    setBusyIdx(i);
    setRowError(null);
    try {
      const res = await fetch(
        `/api/admin/exercises/${editingId}/dictation/sentences/${i}/audio`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ text }),
        }
      );
      if (!res.ok) {
        const body = await res.text();
        throw new Error(body || `HTTP ${res.status}`);
      }
      const payload = await res.json() as { data?: { storage_key?: string } };
      const storageKey = payload.data?.storage_key ?? '';
      const sentences = state.sentences.map((s, idx) => idx === i ? { ...s, audioAssetId: storageKey } : s);
      emit({ ...state, sentences });
    } catch (err) {
      setRowError(`Câu ${i + 1}: ${err instanceof Error ? err.message : 'tạo audio thất bại'}`);
    } finally {
      setBusyIdx(null);
    }
  }

  async function deleteRowAudio(i: number) {
    if (!editingId) return;
    setBusyIdx(i);
    setRowError(null);
    try {
      await fetch(`/api/admin/exercises/${editingId}/dictation/sentences/${i}/audio`, { method: 'DELETE' });
      const sentences = state.sentences.map((s, idx) => idx === i ? { ...s, audioAssetId: null } : s);
      emit({ ...state, sentences });
    } finally {
      setBusyIdx(null);
    }
  }

  const validation = validateDictation(state, { requireAudio: false });
  const tooManySentences = state.sentences.length > DICTATION_MAX_SENTENCES;

  return (
    <div style={{ display: 'grid', gap: 14 }}>

      {/* Topic */}
      <div>
        <span style={labelStyle}>Chủ đề *</span>
        <input
          style={{ ...inputStyle, marginTop: 4, width: '100%' }}
          value={state.topic}
          onChange={(e) => setTopic(e.target.value)}
          placeholder="Trong quán cafe"
          maxLength={80}
        />
      </div>

      {/* Transcript split */}
      <div style={sectionStyle}>
        <span style={labelStyle}>Transcript (3–{DICTATION_MAX_SENTENCES} câu)</span>
        <p style={{ fontSize: 12, color: 'var(--ink-3)', margin: 0 }}>
          Dán đoạn văn rồi bấm &ldquo;Tách câu tự động&rdquo; để điền các dòng câu bên dưới.
          Các viết tắt như Mgr., Dr., Ph.D. được giữ nguyên (không bị tách nhầm).
        </p>
        <textarea
          style={txStyle}
          value={transcript}
          onChange={(e) => setTranscript(e.target.value)}
          placeholder="Pavel jde do kavárny. Chce si dát čaj a koláč. Číšník ho zdraví. ..."
        />
        <div>
          <button
            type="button"
            onClick={applySplit}
            disabled={!transcript.trim()}
            style={{
              padding: '7px 14px', borderRadius: 8, border: 'none',
              background: transcript.trim() ? 'var(--accent)' : 'var(--surface-muted)',
              color: transcript.trim() ? '#fff' : 'var(--ink-3)',
              fontWeight: 600, fontSize: 13, cursor: transcript.trim() ? 'pointer' : 'not-allowed',
            }}
          >
            Tách câu tự động
          </button>
        </div>
      </div>

      {/* Sentences */}
      <div style={sectionStyle}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span style={labelStyle}>
            Câu ({state.sentences.length}/{DICTATION_MAX_SENTENCES})
          </span>
          <button
            type="button"
            onClick={addSentence}
            disabled={tooManySentences}
            style={{
              padding: '6px 12px', borderRadius: 8, border: '1px solid var(--border-strong)',
              background: 'var(--surface)', color: tooManySentences ? 'var(--ink-3)' : 'var(--ink-2)',
              fontSize: 12, cursor: tooManySentences ? 'not-allowed' : 'pointer',
            }}
          >
            + Thêm câu
          </button>
        </div>

        {state.sentences.length === 0 && (
          <p style={{ fontSize: 12, color: 'var(--ink-3)', margin: 0 }}>
            Chưa có câu nào. Dùng &ldquo;Tách câu tự động&rdquo; bên trên hoặc bấm &ldquo;+ Thêm câu&rdquo;.
          </p>
        )}

        {state.sentences.map((row, i) => {
          const overLimit = Array.from(row.text.trim()).length > DICTATION_MAX_SENTENCE_CHARS;
          return (
            <div
              key={i}
              style={{
                border: '1px solid var(--border)',
                borderRadius: 8,
                padding: 8,
                background: 'var(--surface)',
                display: 'grid', gap: 6,
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <div style={{
                  width: 24, height: 24, borderRadius: '50%',
                  background: 'var(--accent)', color: '#fff',
                  fontSize: 11, fontWeight: 700,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  flexShrink: 0,
                }}>
                  {i + 1}
                </div>
                <input
                  style={{
                    ...inputStyle,
                    borderColor: overLimit ? 'var(--error)' : 'var(--border-strong)',
                  }}
                  placeholder={`Câu ${i + 1}…`}
                  value={row.text}
                  onChange={(e) => setSentenceText(i, e.target.value)}
                />
                <button
                  type="button"
                  onClick={() => removeSentence(i)}
                  style={{
                    width: 28, height: 28, borderRadius: '50%',
                    border: '1px solid var(--border)', background: 'var(--surface)',
                    cursor: 'pointer', flexShrink: 0,
                  }}
                  title="Xoá câu"
                >
                  ✕
                </button>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <button
                  type="button"
                  disabled={busyIdx !== null || !editingId}
                  onClick={() => generateRowAudio(i)}
                  style={{
                    padding: '6px 12px', borderRadius: 6, border: 'none',
                    background: row.audioAssetId ? 'var(--surface-muted)' : 'var(--accent)',
                    color: row.audioAssetId ? 'var(--ink-2)' : '#fff',
                    fontSize: 12, fontWeight: 600,
                    cursor: busyIdx === i || !editingId ? 'not-allowed' : 'pointer',
                  }}
                >
                  {busyIdx === i
                    ? 'Đang tạo…'
                    : row.audioAssetId ? '↻ Tạo lại audio' : '🔊 Tạo audio (Polly)'}
                </button>
                {row.audioAssetId && (
                  <>
                    <span style={{ fontSize: 11, color: 'var(--success)' }}>
                      ✓ {row.audioAssetId.split('/').pop()}
                    </span>
                    <button
                      type="button"
                      onClick={() => deleteRowAudio(i)}
                      disabled={busyIdx !== null}
                      style={{
                        padding: '4px 10px', borderRadius: 6,
                        border: '1px solid var(--border)', background: 'var(--surface)',
                        fontSize: 11, color: 'var(--ink-3)', cursor: 'pointer',
                      }}
                    >
                      🗑 Xoá
                    </button>
                  </>
                )}
                {overLimit && (
                  <span style={{ fontSize: 11, color: 'var(--error)' }}>
                    Quá {DICTATION_MAX_SENTENCE_CHARS} ký tự
                  </span>
                )}
              </div>
            </div>
          );
        })}

        {!editingId && state.sentences.length > 0 && (
          <p style={{ fontSize: 11, color: 'var(--ink-3)', margin: 0 }}>
            Lưu nháp để tạo audio cho từng câu.
          </p>
        )}
      </div>

      {/* Settings */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12 }}>
        <div>
          <span style={labelStyle}>Số lần nghe lại</span>
          <input
            type="number"
            min={0}
            max={10}
            style={{ ...inputStyle, marginTop: 4, width: '100%' }}
            value={state.maxReplaysPerSentence}
            onChange={(e) => setMaxReplays(Number(e.target.value) || 0)}
          />
          <span style={{ fontSize: 10, color: 'var(--ink-3)' }}>0 = không giới hạn</span>
        </div>
        <div>
          <span style={labelStyle}>Điểm tối đa</span>
          <input
            type="number"
            min={1}
            max={20}
            style={{ ...inputStyle, marginTop: 4, width: '100%' }}
            value={state.maxPoints}
            onChange={(e) => setMaxPoints(Number(e.target.value) || 1)}
          />
        </div>
        <div>
          <span style={labelStyle}>Ngưỡng đạt (%)</span>
          <input
            type="number"
            min={1}
            max={100}
            style={{ ...inputStyle, marginTop: 4, width: '100%' }}
            value={state.passThresholdPercent}
            onChange={(e) => setThreshold(Number(e.target.value) || 60)}
          />
        </div>
        <div>
          <span style={labelStyle}>Voice ID</span>
          <input
            style={{ ...inputStyle, marginTop: 4, width: '100%' }}
            value={state.voiceId}
            onChange={(e) => setVoiceId(e.target.value)}
            placeholder="Tomas"
          />
        </div>
      </div>

      {/* Validation banner */}
      {!validation.ok && state.sentences.length > 0 && (
        <div
          role="alert"
          style={{
            border: '1px solid var(--error)', borderRadius: 8,
            padding: '8px 12px', background: 'rgba(214, 67, 67, 0.06)',
            fontSize: 12, color: 'var(--error)',
          }}
        >
          {validation.errors.slice(0, 3).map((e, i) => <div key={i}>• {e}</div>)}
          {validation.errors.length > 3 && (
            <div>... và {validation.errors.length - 3} lỗi khác</div>
          )}
        </div>
      )}

      {rowError && (
        <div style={{ fontSize: 12, color: 'var(--error)' }}>{rowError}</div>
      )}

      {state.sentences.length < DICTATION_MIN_SENTENCES && (
        <p style={{ fontSize: 11, color: 'var(--ink-3)', margin: 0 }}>
          Cần ít nhất {DICTATION_MIN_SENTENCES} câu để publish.
        </p>
      )}
    </div>
  );
}
