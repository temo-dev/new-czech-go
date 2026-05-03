'use client';

import { useEffect, useRef, useState } from 'react';
import { adminFetch } from '../../lib/api';
import { adminApi } from '../exercise-utils';
import { AnswerSelect } from './AnswerSelect';
import { ItemRepeater } from './ItemRepeater';
import { OptionRow } from './OptionRow';
import AiImageButton from '../AiImageButton';

// ── Types ─────────────────────────────────────────────────────────────────────

type CteniType = 'cteni_1' | 'cteni_2' | 'cteni_3' | 'cteni_4' | 'cteni_5';

// cteni_1: 5 items (each is either an uploaded image or a short text message) → match A-H
type C1Item = { mode: 'image' | 'text'; text: string; assetId: string; answer: string };
type C1State = {
  type: 'cteni_1';
  items: C1Item[];
  options: { key: string; text: string }[];
};

// cteni_2 / cteni_4: reading passage → questions → A-D
type CQItem = { prompt: string; optA: string; optB: string; optC: string; optD: string; answer: string };
type C24State = { type: 'cteni_2' | 'cteni_4'; text: string; questions: CQItem[] };

// cteni_3: 4 text blocks → match persons A-E
type C3State = {
  type: 'cteni_3';
  texts: { text: string; answer: string }[];      // 4 text blocks
  persons: { key: string; name: string }[];        // A-E persons
};

// cteni_5: reading passage → fill-in 5 slots
type C5State = { type: 'cteni_5'; text: string; slots: { prompt: string; answer: string }[] };

type CteniState = C1State | C24State | C3State | C5State;

// ── Defaults ──────────────────────────────────────────────────────────────────

const OPTION_KEYS_1 = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
const OPTION_KEYS_3 = ['A', 'B', 'C', 'D', 'E'];
const emptyQ = (): CQItem => ({ prompt: '', optA: '', optB: '', optC: '', optD: '', answer: '' });

// ── Init from exercise.detail ─────────────────────────────────────────────────

function initState(type: CteniType, detail: Record<string, unknown>): CteniState {
  const ca = (detail.correct_answers ?? {}) as Record<string, string>;

  if (type === 'cteni_1') {
    const rawItems = (detail.items ?? []) as Array<{ item_no?: number; text?: string; asset_id?: string }>;
    const rawOpts  = (detail.options ?? []) as Array<{ key?: string; text?: string }>;
    const items: C1Item[] = Array.from({ length: 5 }, (_, i) => {
      const raw = rawItems[i];
      const assetId = raw?.asset_id ?? '';
      return {
        mode: assetId ? 'image' : 'text',
        text: raw?.text ?? '',
        assetId,
        answer: ca[String(i + 1)] ?? '',
      };
    });
    const options = OPTION_KEYS_1.map((k, i) => ({
      key: k,
      text: rawOpts.find(o => o.key === k)?.text ?? rawOpts[i]?.text ?? '',
    }));
    return { type, items, options };
  }

  if (type === 'cteni_2' || type === 'cteni_4') {
    const startNo = type === 'cteni_4' ? 15 : 6;
    const count   = type === 'cteni_4' ? 6 : 5;
    const rawQs   = (detail.questions ?? []) as Array<Record<string, unknown>>;
    const questions: CQItem[] = Array.from({ length: count }, (_, i) => {
      const rq  = rawQs[i] as Record<string, unknown> | undefined;
      const opts = (rq?.options ?? []) as Array<{ key: string; text: string }>;
      const get  = (k: string) => opts.find(o => o.key === k)?.text ?? '';
      return {
        prompt: String(rq?.prompt ?? ''),
        optA: get('A'), optB: get('B'), optC: get('C'), optD: get('D'),
        answer: ca[String(startNo + i)] ?? '',
      };
    });
    return { type, text: String(detail.text ?? ''), questions };
  }

  if (type === 'cteni_3') {
    const rawTexts  = (detail.texts ?? []) as Array<{ item_no?: number; text?: string }>;
    const rawPerson = (detail.persons ?? []) as Array<{ key?: string; name?: string }>;
    const texts = Array.from({ length: 4 }, (_, i) => ({
      text: rawTexts[i]?.text ?? '',
      answer: ca[String(i + 1)] ?? '',
    }));
    const persons = OPTION_KEYS_3.map((k, i) => ({
      key: k,
      name: rawPerson.find(p => p.key === k)?.name ?? rawPerson[i]?.name ?? '',
    }));
    return { type, texts, persons };
  }

  // cteni_5
  const rawQs = (detail.questions ?? []) as Array<{ question_no?: number; prompt?: string }>;
  const slots = Array.from({ length: 5 }, (_, i) => ({
    prompt: rawQs[i]?.prompt ?? '',
    answer: ca[String(21 + i)] ?? '',
  }));
  return { type: 'cteni_5', text: String(detail.text ?? ''), slots };
}

// ── Serialization ─────────────────────────────────────────────────────────────

function buildDetail(state: CteniState): Record<string, unknown> {
  if (state.type === 'cteni_1') {
    const correct: Record<string, string> = {};
    state.items.forEach((item, i) => { if (item.answer) correct[String(i + 1)] = item.answer; });
    return {
      items: state.items.map((it, i) => ({
        item_no: i + 1,
        ...(it.mode === 'image' && it.assetId ? { asset_id: it.assetId } : { text: it.text }),
      })),
      options: state.options.map(o => ({ key: o.key, text: o.text })),
      correct_answers: correct,
    };
  }

  if (state.type === 'cteni_2' || state.type === 'cteni_4') {
    const startNo = state.type === 'cteni_4' ? 15 : 6;
    const correct: Record<string, string> = {};
    const questions = state.questions.map((q, i) => {
      if (q.answer) correct[String(startNo + i)] = q.answer;
      return {
        question_no: startNo + i,
        prompt: q.prompt,
        options: [{ key: 'A', text: q.optA }, { key: 'B', text: q.optB }, { key: 'C', text: q.optC }, { key: 'D', text: q.optD }],
      };
    });
    return { text: state.text, questions, correct_answers: correct };
  }

  if (state.type === 'cteni_3') {
    const correct: Record<string, string> = {};
    state.texts.forEach((t, i) => { if (t.answer) correct[String(i + 1)] = t.answer; });
    return {
      texts: state.texts.map((t, i) => ({ item_no: i + 1, text: t.text })),
      persons: state.persons.map(p => ({ key: p.key, name: p.name })),
      correct_answers: correct,
    };
  }

  // cteni_5
  const s5 = state as C5State;
  const correct: Record<string, string> = {};
  s5.slots.forEach((slot, i) => { if (slot.answer) correct[String(21 + i)] = slot.answer; });
  return {
    text: s5.text,
    questions: s5.slots.map((slot, i) => ({ question_no: 21 + i, prompt: slot.prompt })),
    correct_answers: correct,
  };
}

// ── Component ─────────────────────────────────────────────────────────────────

type Props = {
  exerciseType: CteniType;
  initialData: Record<string, unknown>;
  onChange: (detail: Record<string, unknown>) => void;
  exerciseId?: string | null;
};

const labelStyle: React.CSSProperties = { fontSize: 13, fontWeight: 600, color: 'var(--ink-2)' };
const sectionStyle: React.CSSProperties = { border: '1px solid var(--border)', borderRadius: 12, padding: '14px 16px', display: 'grid', gap: 10, background: 'var(--surface-alt)' };
const txStyle: React.CSSProperties = { padding: '8px 10px', border: '1px solid var(--border-strong)', borderRadius: 8, fontSize: 14, resize: 'vertical' as const, fontFamily: 'inherit' };

export function CteniFields({ exerciseType, initialData, onChange, exerciseId }: Props) {
  const [state, setState] = useState<CteniState>(() => initState(exerciseType, initialData));
  const [uploadingItem, setUploadingItem] = useState<number | null>(null);
  const [uploadError, setUploadError] = useState<string | null>(null);
  const fileInputRefs = useRef<(HTMLInputElement | null)[]>([]);

  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => { setState(initState(exerciseType, initialData)); }, [exerciseType, JSON.stringify(initialData)]);

  function update(next: CteniState) { setState(next); onChange(buildDetail(next)); }

  async function handleC1ImageUpload(file: File, itemIndex: number) {
    if (!exerciseId) { setUploadError('Lưu bài tập trước rồi upload ảnh.'); return; }
    setUploadingItem(itemIndex);
    setUploadError(null);
    try {
      const formData = new FormData();
      formData.set('file', file);
      formData.set('asset_kind', 'image');
      const res = await adminFetch(`${adminApi}/${exerciseId}/assets/upload`, { method: 'POST', body: formData });
      const payload = await res.json();
      if (!res.ok) throw new Error(payload.error?.message ?? 'Upload failed.');
      const assetId = payload.data?.asset?.id as string | undefined;
      if (!assetId) throw new Error('No asset ID returned.');
      if (state.type !== 'cteni_1') return;
      const next = [...state.items] as C1Item[];
      next[itemIndex] = { ...next[itemIndex], mode: 'image', assetId };
      update({ ...state, items: next });
    } catch (err) {
      setUploadError(err instanceof Error ? err.message : 'Unknown error.');
    } finally {
      setUploadingItem(null);
    }
  }

  const c1    = state.type === 'cteni_1' ? state : null;
  const c24   = (state.type === 'cteni_2' || state.type === 'cteni_4') ? state : null;
  const c3    = state.type === 'cteni_3' ? state : null;
  const c5    = state.type === 'cteni_5' ? state : null;

  return (
    <div style={{ display: 'grid', gap: 16 }}>

      {/* ── Čtení 1 — images/msgs → A-H ───────────────────────────── */}
      {c1 && (
        <>
          <div style={{ display: 'grid', gap: 6 }}>
            <span style={labelStyle}>Options A-H (nội dung lựa chọn)</span>
            {c1.options.map((opt, oi) => (
              <OptionRow
                key={opt.key}
                optionKey={opt.key}
                label={opt.text}
                placeholder={`Nội dung lựa chọn ${opt.key}...`}
                onChange={v => {
                  const next = [...c1.options];
                  next[oi] = { ...next[oi], text: v };
                  update({ ...c1, options: next });
                }}
              />
            ))}
          </div>
          <div style={{ display: 'grid', gap: 8 }}>
            <span style={labelStyle}>5 ảnh / tin nhắn</span>
            {uploadError && <p style={{ margin: 0, fontSize: 12, color: 'var(--danger)' }}>{uploadError}</p>}
            {c1.items.map((item, i) => (
              <div key={i} style={sectionStyle}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                  <span style={{ ...labelStyle, color: 'var(--accent)', fontSize: 12 }}>Item {i + 1}</span>
                  {/* Mode toggle */}
                  <div style={{ display: 'flex', gap: 4 }}>
                    {(['image', 'text'] as const).map(m => (
                      <button key={m} type="button"
                        onClick={() => {
                          const next = [...c1.items] as C1Item[];
                          next[i] = { ...next[i], mode: m };
                          update({ ...c1, items: next });
                        }}
                        style={{ padding: '3px 10px', borderRadius: 6, border: `1px solid ${item.mode === m ? 'var(--brand)' : 'var(--border)'}`, background: item.mode === m ? 'var(--brand)' : 'transparent', color: item.mode === m ? '#fff' : 'var(--ink-3)', fontSize: 11, fontWeight: 600, cursor: 'pointer' }}
                      >
                        {m === 'image' ? '🖼 Ảnh' : '💬 Văn bản'}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Image mode */}
                {item.mode === 'image' && (
                  <div style={{ display: 'grid', gap: 8 }}>
                    {item.assetId && exerciseId && (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img
                        src={`${adminApi}/${exerciseId}/assets/${item.assetId}/file`}
                        alt={`item ${i + 1}`}
                        style={{ width: '100%', maxHeight: 160, objectFit: 'cover', borderRadius: 8, border: '1px solid var(--border)' }}
                      />
                    )}
                    {!item.assetId && (
                      <p style={{ margin: 0, fontSize: 12, color: 'var(--ink-4)' }}>Chưa có ảnh.</p>
                    )}
                    {!exerciseId ? (
                      <p style={{ margin: 0, fontSize: 12, color: 'var(--ink-4)' }}>Lưu bài tập trước rồi upload ảnh.</p>
                    ) : (
                      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
                        <label style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6, border: '1px dashed var(--border)', borderRadius: 8, padding: '8px 12px', cursor: 'pointer', fontSize: 12, fontWeight: 600, color: 'var(--ink-3)', background: 'var(--surface-alt)' }}>
                          {uploadingItem === i ? '⏳ Đang tải...' : item.assetId ? '🔄 Đổi ảnh' : '📁 Tải ảnh lên'}
                          <input
                            ref={el => { fileInputRefs.current[i] = el; }}
                            type="file" accept="image/jpeg,image/png,image/webp" style={{ display: 'none' }}
                            disabled={uploadingItem !== null}
                            onChange={e => {
                              const f = e.target.files?.[0];
                              if (f) void handleC1ImageUpload(f, i);
                              e.target.value = '';
                            }}
                          />
                        </label>
                        <AiImageButton
                          onAssetCreated={async result => {
                            if (!exerciseId) return;
                            await adminFetch(`/api/admin/exercises/${exerciseId}/assets`, {
                              method: 'POST',
                              headers: { 'Content-Type': 'application/json' },
                              body: JSON.stringify({ id: result.assetId, asset_kind: 'image', storage_key: result.storageKey, mime_type: 'image/jpeg' }),
                            });
                            const next = [...c1.items] as C1Item[];
                            next[i] = { ...next[i], mode: 'image', assetId: result.assetId };
                            update({ ...c1, items: next });
                          }}
                          disabled={!exerciseId}
                          existingAssetId={item.assetId || undefined}
                        />
                      </div>
                    )}
                  </div>
                )}

                {/* Text mode */}
                {item.mode === 'text' && (
                  <input
                    type="text"
                    value={item.text}
                    onChange={e => {
                      const next = [...c1.items] as C1Item[];
                      next[i] = { ...next[i], text: e.target.value };
                      update({ ...c1, items: next });
                    }}
                    placeholder="Nội dung tin nhắn ngắn..."
                    style={{ padding: '7px 10px', border: '1px solid var(--border-strong)', borderRadius: 8, fontSize: 14, fontFamily: 'inherit' }}
                  />
                )}

                <AnswerSelect
                  label="Đáp án:"
                  options={c1.options.map(o => ({ key: o.key, label: o.text }))}
                  value={item.answer}
                  onChange={v => {
                    const next = [...c1.items] as C1Item[];
                    next[i] = { ...next[i], answer: v };
                    update({ ...c1, items: next });
                  }}
                />
              </div>
            ))}
          </div>
        </>
      )}

      {/* ── Čtení 2 / 4 — reading passage → questions → A-D ──────── */}
      {c24 && (
        <>
          <label style={{ display: 'grid', gap: 6 }}>
            <span style={labelStyle}>Đoạn văn đọc</span>
            <textarea
              rows={10}
              value={c24.text}
              onChange={e => update({ ...c24, text: e.target.value })}
              placeholder="Přečtěte si text..."
              style={txStyle}
            />
          </label>
          {c24.questions.map((q, i) => {
            const startNo = state.type === 'cteni_4' ? 15 : 6;
            const opts = [{ key: 'A', label: q.optA }, { key: 'B', label: q.optB }, { key: 'C', label: q.optC }, { key: 'D', label: q.optD }];
            function patchQ(partial: Partial<CQItem>) {
              const next = [...c24!.questions];
              next[i] = { ...next[i], ...partial };
              update({ ...c24!, questions: next });
            }
            return (
              <div key={i} style={sectionStyle}>
                <span style={{ ...labelStyle, color: 'var(--accent)', fontSize: 12 }}>Câu {startNo + i}</span>
                <label style={{ display: 'grid', gap: 4 }}>
                  <span style={labelStyle}>Đề câu hỏi</span>
                  <input type="text" value={q.prompt} onChange={e => patchQ({ prompt: e.target.value })} placeholder="Câu hỏi..." style={{ padding: '7px 10px', border: '1px solid var(--border-strong)', borderRadius: 8, fontSize: 14, fontFamily: 'inherit' }} />
                </label>
                <div style={{ display: 'grid', gap: 4 }}>
                  <span style={labelStyle}>Lựa chọn A-D</span>
                  {(['A', 'B', 'C', 'D'] as const).map(k => (
                    <OptionRow key={k} optionKey={k} label={(q as Record<string, string>)[`opt${k}`] ?? ''} onChange={v => patchQ({ [`opt${k}`]: v } as Partial<CQItem>)} />
                  ))}
                </div>
                <AnswerSelect label="Đáp án đúng:" options={opts} value={q.answer} onChange={v => patchQ({ answer: v })} />
              </div>
            );
          })}
          <button type="button" onClick={() => update({ ...c24, questions: [...c24.questions, emptyQ()] })}
            style={{ alignSelf: 'flex-start', background: 'none', border: '1px dashed var(--border-strong)', borderRadius: 8, padding: '6px 14px', cursor: 'pointer', fontSize: 13, color: 'var(--ink-3)' }}>
            + Thêm câu hỏi
          </button>
        </>
      )}

      {/* ── Čtení 3 — 4 texts → persons A-E ──────────────────────── */}
      {c3 && (
        <>
          <div style={{ display: 'grid', gap: 6 }}>
            <span style={labelStyle}>Nhân vật A-E</span>
            {c3.persons.map((p, pi) => (
              <div key={p.key} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center', width: 28, height: 28, borderRadius: 6, background: 'var(--accent-soft)', color: 'var(--accent)', fontSize: 12, fontWeight: 700, flexShrink: 0 }}>{p.key}</span>
                <input type="text" value={p.name} onChange={e => { const next = [...c3.persons]; next[pi] = { ...next[pi], name: e.target.value }; update({ ...c3, persons: next }); }}
                  placeholder={`Tên nhân vật ${p.key} (nghề nghiệp)...`}
                  style={{ flex: 1, padding: '7px 10px', border: '1px solid var(--border-strong)', borderRadius: 8, fontSize: 14, fontFamily: 'inherit' }} />
              </div>
            ))}
          </div>
          {c3.texts.map((t, i) => (
            <div key={i} style={sectionStyle}>
              <span style={{ ...labelStyle, color: 'var(--accent)', fontSize: 12 }}>Đoạn {i + 1}</span>
              <textarea rows={4} value={t.text}
                onChange={e => { const next = [...c3.texts]; next[i] = { ...next[i], text: e.target.value }; update({ ...c3, texts: next }); }}
                placeholder="Nội dung đoạn văn..." style={txStyle} />
              <AnswerSelect label="Nhân vật:" options={c3.persons.map(p => ({ key: p.key, label: p.name }))} value={t.answer}
                onChange={v => { const next = [...c3.texts]; next[i] = { ...next[i], answer: v }; update({ ...c3, texts: next }); }} />
            </div>
          ))}
        </>
      )}

      {/* ── Čtení 5 — reading + fill-in 5 slots ───────────────────── */}
      {c5 && (
        <>
          <label style={{ display: 'grid', gap: 6 }}>
            <span style={labelStyle}>Đoạn văn đọc</span>
            <textarea rows={10} value={c5.text} onChange={e => update({ ...c5, text: e.target.value })} placeholder="Přečtěte si text..." style={txStyle} />
          </label>
          <div style={{ display: 'grid', gap: 8 }}>
            <span style={labelStyle}>Câu điền vào (5 câu)</span>
            {c5.slots.map((slot, i) => (
              <div key={i} style={sectionStyle}>
                <span style={{ ...labelStyle, color: 'var(--accent)', fontSize: 12 }}>Câu {21 + i}</span>
                <input type="text" value={slot.prompt}
                  onChange={e => { const next = [...c5.slots]; next[i] = { ...next[i], prompt: e.target.value }; update({ ...c5, slots: next }); }}
                  placeholder="Đề câu điền vào..." style={{ padding: '7px 10px', border: '1px solid var(--border-strong)', borderRadius: 8, fontSize: 14, fontFamily: 'inherit' }} />
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <span style={{ fontSize: 13, color: 'var(--ink-3)', flexShrink: 0 }}>Đáp án:</span>
                  <input type="text" value={slot.answer}
                    onChange={e => { const next = [...c5.slots]; next[i] = { ...next[i], answer: e.target.value }; update({ ...c5, slots: next }); }}
                    placeholder="Đáp án đúng (substring match)..."
                    style={{ flex: 1, padding: '7px 10px', border: '1px solid var(--border-strong)', borderRadius: 8, fontSize: 14, fontFamily: 'inherit' }} />
                </div>
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  );
}
