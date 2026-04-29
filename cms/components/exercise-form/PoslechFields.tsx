'use client';

import { useEffect, useState } from 'react';
import { AnswerSelect } from './AnswerSelect';
import { OptionRow } from './OptionRow';

// ── Types ─────────────────────────────────────────────────────────────────────

type PoslechType = 'poslech_1' | 'poslech_2' | 'poslech_3' | 'poslech_4' | 'poslech_5';

type P12Item = { question: string; text: string; optA: string; optB: string; optC: string; optD: string; answer: string };
type MatchItem = { text: string; answer: string };
type SharedOption = { key: string; label: string };
type FillSlot = { answer: string };

type P12State  = { type: 'poslech_1' | 'poslech_2'; items: P12Item[] };
type MatchState = { type: 'poslech_3' | 'poslech_4'; items: MatchItem[]; options: SharedOption[] };
type P5State   = { type: 'poslech_5'; voiceText: string; slots: FillSlot[] };
type PoslechState = P12State | MatchState | P5State;

// ── Defaults ──────────────────────────────────────────────────────────────────

const ITEM_COUNT = 5;
const OPTION_KEYS_3 = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];
const OPTION_KEYS_4 = ['A', 'B', 'C', 'D', 'E', 'F'];

// ── Initialization from exercise.detail ───────────────────────────────────────

function initState(exerciseType: PoslechType, detail: Record<string, unknown>): PoslechState {
  const ca = (detail.correct_answers ?? {}) as Record<string, string>;

  if (exerciseType === 'poslech_1' || exerciseType === 'poslech_2') {
    const rawItems = (detail.items ?? []) as Array<Record<string, unknown>>;
    const items: P12Item[] = Array.from({ length: ITEM_COUNT }, (_, i) => {
      const raw = rawItems[i] as Record<string, unknown> | undefined;
      const segs = ((raw?.audio_source as Record<string, unknown>)?.segments ?? []) as Array<{ text: string }>;
      const opts = (raw?.options ?? []) as Array<{ key: string; text?: string }>;
      const get = (k: string) => opts.find(o => o.key === k)?.text ?? '';
      return { question: String(raw?.question ?? ''), text: segs.map(s => s.text).join('\n'), optA: get('A'), optB: get('B'), optC: get('C'), optD: get('D'), answer: ca[String(i + 1)] ?? '' };
    });
    return { type: exerciseType, items };
  }

  if (exerciseType === 'poslech_3' || exerciseType === 'poslech_4') {
    const rawItems = (detail.items ?? []) as Array<Record<string, unknown>>;
    const rawOpts  = (detail.options ?? []) as Array<Record<string, unknown>>;
    const keys = exerciseType === 'poslech_3' ? OPTION_KEYS_3 : OPTION_KEYS_4;
    const options: SharedOption[] = keys.map((k, i) => {
      const raw = rawOpts[i] as Record<string, unknown> | undefined;
      return { key: k, label: String(raw?.label ?? raw?.asset_id ?? '') };
    });
    const items: MatchItem[] = Array.from({ length: ITEM_COUNT }, (_, i) => {
      const raw = rawItems[i] as Record<string, unknown> | undefined;
      const segs = ((raw?.audio_source as Record<string, unknown>)?.segments ?? []) as Array<{ text: string }>;
      return { text: segs.map(s => s.text).join('\n'), answer: ca[String(i + 1)] ?? '' };
    });
    return { type: exerciseType, items, options };
  }

  const segs = ((detail.audio_source as Record<string, unknown>)?.segments ?? []) as Array<{ text: string }>;
  const slots: FillSlot[] = Array.from({ length: ITEM_COUNT }, (_, i) => ({ answer: ca[String(i + 1)] ?? '' }));
  return { type: 'poslech_5', voiceText: segs.map(s => s.text).join('\n'), slots };
}

// ── Serialization ─────────────────────────────────────────────────────────────

function buildDetail(state: PoslechState, audioSource: 'text' | 'upload'): Record<string, unknown> {
  const seg = (text: string) => text.split('\n').filter(Boolean).map(t => ({ text: t }));

  if (state.type === 'poslech_1' || state.type === 'poslech_2') {
    const correct: Record<string, string> = {};
    const items = state.items.map((item, i) => {
      if (item.answer) correct[String(i + 1)] = item.answer;
      return { question_no: i + 1, question: item.question, audio_source: { type: audioSource, segments: seg(item.text) }, options: [{ key: 'A', text: item.optA }, { key: 'B', text: item.optB }, { key: 'C', text: item.optC }, { key: 'D', text: item.optD }] };
    });
    return { items, correct_answers: correct };
  }

  if (state.type === 'poslech_3' || state.type === 'poslech_4') {
    const correct: Record<string, string> = {};
    const items = state.items.map((item, i) => {
      if (item.answer) correct[String(i + 1)] = item.answer;
      return { question_no: i + 1, audio_source: { type: audioSource, segments: seg(item.text) } };
    });
    const rawOptions = state.type === 'poslech_4'
      ? state.options.map(o => ({ key: o.key, asset_id: o.label }))
      : state.options.map(o => ({ key: o.key, label: o.label }));
    return { items, options: rawOptions, correct_answers: correct };
  }

  // poslech_5 — explicit cast since TS doesn't narrow union-in-type after || checks
  const s5 = state as P5State;
  const correct: Record<string, string> = {};
  s5.slots.forEach((slot, i) => { if (slot.answer) correct[String(i + 1)] = slot.answer; });
  return { audio_source: { type: audioSource, segments: seg(s5.voiceText) }, questions: s5.slots.map((_, i) => ({ question_no: i + 1, prompt: '' })), correct_answers: correct };
}

// ── Component ─────────────────────────────────────────────────────────────────

type Props = {
  exerciseType: PoslechType;
  initialData: Record<string, unknown>;
  onChange: (detail: Record<string, unknown>) => void;
  editingId: string | null;
  audioGenerating: boolean;
  audioGenMsg: string | null;
  onGenerateAudio: () => void;
};

const labelStyle: React.CSSProperties = { fontSize: 13, fontWeight: 600, color: 'var(--ink-2)' };
const sectionStyle: React.CSSProperties = { border: '1px solid var(--border)', borderRadius: 12, padding: '14px 16px', display: 'grid', gap: 10, background: 'var(--surface-alt)' };
const txStyle: React.CSSProperties = { padding: '8px 10px', border: '1px solid var(--border-strong)', borderRadius: 8, fontSize: 14, resize: 'vertical' as const, fontFamily: 'inherit' };

export function PoslechFields({ exerciseType, initialData, onChange, editingId, audioGenerating, audioGenMsg, onGenerateAudio }: Props) {
  const [state, setState] = useState<PoslechState>(() => initState(exerciseType, initialData));
  const [audioSource, setAudioSource] = useState<'text' | 'upload'>('text');

  // Re-init when switching exercise or opening a different one in edit mode
  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => { setState(initState(exerciseType, initialData)); }, [exerciseType, JSON.stringify(initialData)]);

  function update(next: PoslechState) { setState(next); onChange(buildDetail(next, audioSource)); }
  function updateAudioSrc(src: 'text' | 'upload') { setAudioSource(src); onChange(buildDetail(state, src)); }

  // Explicit narrowing to avoid union-in-closure issues
  const p12  = (state.type === 'poslech_1' || state.type === 'poslech_2') ? state : null;
  const match = (state.type === 'poslech_3' || state.type === 'poslech_4') ? state : null;
  const p5   = state.type === 'poslech_5' ? state : null;

  return (
    <div style={{ display: 'grid', gap: 16 }}>

      {/* Audio source radio */}
      <div style={{ display: 'grid', gap: 6 }}>
        <span style={labelStyle}>Nguồn audio</span>
        <div style={{ display: 'flex', gap: 16 }}>
          {(['text', 'upload'] as const).map(src => (
            <label key={src} style={{ display: 'flex', gap: 6, cursor: 'pointer', alignItems: 'center', fontSize: 14 }}>
              <input type="radio" value={src} checked={audioSource === src} onChange={() => updateAudioSrc(src)} />
              {src === 'text' ? 'Nhập text → Polly TTS' : 'Upload file audio'}
            </label>
          ))}
        </div>
      </div>

      {/* ── Poslech 1 / 2 — per-item A-D options ──────────────────── */}
      {p12 && p12.items.map((item, i) => {
        const opts = [{ key: 'A', label: item.optA }, { key: 'B', label: item.optB }, { key: 'C', label: item.optC }, { key: 'D', label: item.optD }];
        function patch(partial: Partial<P12Item>) {
          // p12 is non-null here (we're inside {p12 && p12.items.map(...)})
          const next = [...p12!.items];
          next[i] = { ...next[i], ...partial };
          update({ ...p12!, items: next });
        }
        return (
          <div key={i} style={sectionStyle}>
            <span style={{ ...labelStyle, color: 'var(--accent)', fontSize: 12 }}>Câu {i + 1}</span>
            <label style={{ display: 'grid', gap: 4 }}>
              <span style={labelStyle}>Câu hỏi (hiển thị cho học viên)</span>
              <input type="text" value={item.question} onChange={e => patch({ question: e.target.value })} placeholder="Ví dụ: Co se dozvíte z tohoto sdělení?" style={{ padding: '8px 10px', border: '1px solid var(--border-strong)', borderRadius: 8, fontSize: 14, fontFamily: 'inherit' }} />
            </label>
            {audioSource === 'text' && (
              <label style={{ display: 'grid', gap: 4 }}>
                <span style={labelStyle}>Transcript</span>
                <textarea rows={2} value={item.text} onChange={e => patch({ text: e.target.value })} placeholder="Nội dung đoạn nghe..." style={txStyle} />
              </label>
            )}
            <div style={{ display: 'grid', gap: 4 }}>
              <span style={labelStyle}>Lựa chọn A-D</span>
              {(['A', 'B', 'C', 'D'] as const).map(k => (
                <OptionRow key={k} optionKey={k} label={(item as Record<string, string>)[`opt${k}`] ?? ''} onChange={v => patch({ [`opt${k}`]: v } as Partial<P12Item>)} />
              ))}
            </div>
            <AnswerSelect label="Đáp án đúng:" options={opts} value={item.answer} onChange={v => patch({ answer: v })} />
          </div>
        );
      })}

      {/* ── Poslech 3 / 4 — shared options pool ───────────────────── */}
      {match && (
        <>
          <div style={{ display: 'grid', gap: 6 }}>
            <span style={labelStyle}>{match.type === 'poslech_4' ? 'Options A-F (Asset ID ảnh)' : 'Options A-G (nội dung)'}</span>
            {match.options.map((opt, oi) => (
              <OptionRow
                key={opt.key}
                optionKey={opt.key}
                label={opt.label}
                placeholder={match.type === 'poslech_4' ? `Asset ID ảnh ${opt.key}` : `Nội dung ${opt.key}`}
                onChange={v => {
                  const next = [...match.options];
                  next[oi] = { ...next[oi], label: v };
                  update({ ...match, options: next });
                }}
              />
            ))}
          </div>
          {match.items.map((item, i) => (
            <div key={i} style={sectionStyle}>
              <span style={{ ...labelStyle, color: 'var(--accent)', fontSize: 12 }}>Câu {i + 1}</span>
              {audioSource === 'text' && (
                <label style={{ display: 'grid', gap: 4 }}>
                  <span style={labelStyle}>Transcript</span>
                  <textarea rows={3} value={item.text}
                    onChange={e => {
                      const next = [...match.items];
                      next[i] = { ...next[i], text: e.target.value };
                      update({ ...match, items: next });
                    }}
                    placeholder="Nội dung đoạn nghe..." style={txStyle}
                  />
                </label>
              )}
              <AnswerSelect
                label="Đáp án đúng:"
                options={match.options.map(o => ({ key: o.key, label: o.label }))}
                value={item.answer}
                onChange={v => {
                  const next = [...match.items];
                  next[i] = { ...next[i], answer: v };
                  update({ ...match, items: next });
                }}
              />
            </div>
          ))}
        </>
      )}

      {/* ── Poslech 5 — voicemail fill-in ─────────────────────────── */}
      {p5 && (
        <>
          {audioSource === 'text' && (
            <label style={{ display: 'grid', gap: 6 }}>
              <span style={labelStyle}>Nội dung voicemail (mỗi dòng = 1 câu)</span>
              <textarea rows={6} value={p5.voiceText}
                onChange={e => update({ ...p5, voiceText: e.target.value })}
                placeholder={'Ahoj Lído, tady Eva.\nDostala jsem lístky na balet.'}
                style={txStyle}
              />
            </label>
          )}
          <div style={{ display: 'grid', gap: 8 }}>
            <span style={labelStyle}>Đáp án điền vào (5 ô)</span>
            {p5.slots.map((slot, i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span style={{ fontSize: 13, color: 'var(--ink-3)', width: 52, flexShrink: 0 }}>Câu {i + 1}:</span>
                <input type="text" value={slot.answer}
                  onChange={e => {
                    const next = [...p5.slots];
                    next[i] = { answer: e.target.value };
                    update({ ...p5, slots: next });
                  }}
                  placeholder="Đáp án đúng..."
                  style={{ flex: 1, padding: '7px 10px', border: '1px solid var(--border-strong)', borderRadius: 8, fontSize: 14, fontFamily: 'inherit' }}
                />
              </div>
            ))}
          </div>
        </>
      )}

      {/* Audio generate button (text mode only) */}
      {audioSource === 'text' && (
        <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
          <button type="button" onClick={onGenerateAudio} disabled={audioGenerating || !editingId}
            style={{ background: 'var(--accent-soft)', color: 'var(--accent)', border: 'none', borderRadius: 8, padding: '7px 14px', cursor: (!editingId || audioGenerating) ? 'not-allowed' : 'pointer', fontSize: 13, fontWeight: 600, opacity: (audioGenerating || !editingId) ? 0.5 : 1 }}
          >
            {audioGenerating ? 'Đang tạo...' : 'Tạo audio (Polly TTS)'}
          </button>
          {!editingId && <span style={{ fontSize: 12, color: 'var(--ink-3)' }}>Lưu bài trước khi tạo audio.</span>}
          {audioGenMsg && <span style={{ fontSize: 12, color: 'var(--ink-3)' }}>{audioGenMsg}</span>}
        </div>
      )}
    </div>
  );
}
