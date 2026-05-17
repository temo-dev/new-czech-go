'use client';

import { useEffect, useRef, useState } from 'react';
import { adminFetch } from '../../lib/api';
import { adminApi } from '../exercise-utils';
import { AnswerSelect } from './AnswerSelect';
import { ItemRepeater } from './ItemRepeater';
import { OptionRow } from './OptionRow';
import AiImageButton from '../AiImageButton';
import { AiDraftPanel } from '../ai-draft/AiDraftPanel';
import {
  buildCteniDetail,
  emptyQ,
  emptyC1Item,
  emptyC1Option,
  emptyC3Text,
  emptyC3Person,
  emptyC5Slot,
  initCteniState,
  isCteniDirty,
  nextFreeKey,
  type C1Item,
  type CQItem,
  type CteniState,
  type CteniType,
} from './cteni-model';

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
  const [state, setState] = useState<CteniState>(() => initCteniState(exerciseType, initialData));
  const [uploadingItem, setUploadingItem] = useState<number | null>(null);
  const [uploadError, setUploadError] = useState<string | null>(null);
  const fileInputRefs = useRef<(HTMLInputElement | null)[]>([]);

  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => { setState(initCteniState(exerciseType, initialData)); }, [exerciseType, JSON.stringify(initialData)]);

  function update(next: CteniState) { setState(next); onChange(buildCteniDetail(next)); }

  function handleAiApply(detail: Record<string, unknown>) {
    const next = initCteniState(exerciseType, detail);
    update(next);
  }

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

  const formDirty = isCteniDirty(state);

  return (
    <div style={{ display: 'grid', gap: 16 }}>

      <AiDraftPanel
        exerciseType={exerciseType}
        formDirty={formDirty}
        onApply={handleAiApply}
      />

      {/* ── Čtení 1 — images/msgs → A..Z ──────────────────────────── */}
      {c1 && (
        <>
          <div style={{ display: 'grid', gap: 6 }}>
            <span style={labelStyle}>Options (nội dung lựa chọn) — {c1.options.length} lựa chọn</span>
            {c1.options.map((opt, oi) => {
              const canRemoveOpt = c1!.options.length > 2;
              function removeOption() {
                const removedKey = opt.key;
                const nextOpts = c1!.options.filter((_, idx) => idx !== oi);
                // V39 — clear answers tham chiếu tới option đã xóa.
                const nextItems = c1!.items.map((it) =>
                  it.answer === removedKey ? { ...it, answer: '' } : it,
                );
                update({ ...c1!, options: nextOpts, items: nextItems });
              }
              return (
                <div key={opt.key} style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                  <div style={{ flex: 1 }}>
                    <OptionRow
                      optionKey={opt.key}
                      label={opt.text}
                      placeholder={`Nội dung lựa chọn ${opt.key}...`}
                      onChange={v => {
                        const next = [...c1.options];
                        next[oi] = { ...next[oi], text: v };
                        update({ ...c1, options: next });
                      }}
                    />
                  </div>
                  {canRemoveOpt && (
                    <button type="button" onClick={removeOption}
                      style={{ background: 'transparent', color: 'var(--error)', border: '1px solid var(--error)', borderRadius: 6, padding: '4px 10px', cursor: 'pointer', fontSize: 11, fontWeight: 600 }}>
                      Xóa
                    </button>
                  )}
                </div>
              );
            })}
            <button type="button"
              disabled={c1.options.length >= 26}
              onClick={() => {
                const newKey = nextFreeKey(c1.options.map((o) => o.key));
                if (!newKey) return;
                update({ ...c1, options: [...c1.options, emptyC1Option(newKey)] });
              }}
              style={{ alignSelf: 'flex-start', background: 'var(--surface)', color: 'var(--accent)', border: '1px dashed var(--accent)', borderRadius: 8, padding: '6px 14px', cursor: c1.options.length >= 26 ? 'not-allowed' : 'pointer', fontSize: 12, fontWeight: 600, marginTop: 4, opacity: c1.options.length >= 26 ? 0.5 : 1 }}>
              + Thêm lựa chọn
            </button>
          </div>
          <div style={{ display: 'grid', gap: 8 }}>
            <span style={labelStyle}>{c1.items.length} ảnh / tin nhắn</span>
            {uploadError && <p style={{ margin: 0, fontSize: 12, color: 'var(--danger)' }}>{uploadError}</p>}
            {c1.items.map((item, i) => {
              const canRemoveItem = c1.items.length > 1;
              return (
              <div key={i} style={sectionStyle}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                  <span style={{ ...labelStyle, color: 'var(--accent)', fontSize: 12 }}>Item {i + 1}</span>
                  <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
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
                    {canRemoveItem && (
                      <button type="button"
                        onClick={() => update({ ...c1, items: c1.items.filter((_, idx) => idx !== i) })}
                        style={{ background: 'transparent', color: 'var(--error)', border: '1px solid var(--error)', borderRadius: 6, padding: '3px 10px', cursor: 'pointer', fontSize: 12, fontWeight: 600 }}>
                        Xóa item
                      </button>
                    )}
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
              );
            })}
            <button type="button"
              onClick={() => update({ ...c1, items: [...c1.items, emptyC1Item()] })}
              style={{ alignSelf: 'flex-start', background: 'var(--accent-soft)', color: 'var(--accent)', border: 'none', borderRadius: 8, padding: '8px 16px', cursor: 'pointer', fontSize: 13, fontWeight: 600 }}>
              + Thêm item
            </button>
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
            const canRemoveQ = c24!.questions.length > 1;
            return (
              <div key={i} style={sectionStyle}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ ...labelStyle, color: 'var(--accent)', fontSize: 12 }}>Câu {startNo + i}</span>
                  {canRemoveQ && (
                    <button type="button"
                      onClick={() => update({ ...c24!, questions: c24!.questions.filter((_, idx) => idx !== i) })}
                      style={{ background: 'transparent', color: 'var(--error)', border: '1px solid var(--error)', borderRadius: 6, padding: '3px 10px', cursor: 'pointer', fontSize: 12, fontWeight: 600 }}>
                      Xóa câu này
                    </button>
                  )}
                </div>
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

      {/* ── Čtení 3 — texts → persons A..Z ──────────────────────── */}
      {c3 && (
        <>
          <div style={{ display: 'grid', gap: 6 }}>
            <span style={labelStyle}>Nhân vật ({c3.persons.length})</span>
            {c3.persons.map((p, pi) => {
              const canRemovePerson = c3.persons.length > 2;
              return (
              <div key={p.key} style={{ display: 'grid', gridTemplateColumns: '28px minmax(0, 1fr) minmax(0, 1fr) auto', alignItems: 'center', gap: 8 }}>
                <span style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center', width: 28, height: 28, borderRadius: 6, background: 'var(--accent-soft)', color: 'var(--accent)', fontSize: 12, fontWeight: 700, flexShrink: 0 }}>{p.key}</span>
                <input type="text" value={p.name} onChange={e => { const next = [...c3.persons]; next[pi] = { ...next[pi], name: e.target.value }; update({ ...c3, persons: next }); }}
                  placeholder={`Tên nhân vật ${p.key}...`}
                  style={{ width: '100%', padding: '7px 10px', border: '1px solid var(--border-strong)', borderRadius: 8, fontSize: 14, fontFamily: 'inherit' }} />
                <input type="text" value={p.description} onChange={e => { const next = [...c3.persons]; next[pi] = { ...next[pi], description: e.target.value }; update({ ...c3, persons: next }); }}
                  placeholder="Mô tả / nghề nghiệp..."
                  style={{ width: '100%', padding: '7px 10px', border: '1px solid var(--border-strong)', borderRadius: 8, fontSize: 14, fontFamily: 'inherit' }} />
                {canRemovePerson ? (
                  <button type="button"
                    onClick={() => {
                      const removedKey = p.key;
                      const nextPersons = c3.persons.filter((_, idx) => idx !== pi);
                      const nextTexts = c3.texts.map((t) =>
                        t.answer === removedKey ? { ...t, answer: '' } : t,
                      );
                      update({ ...c3, persons: nextPersons, texts: nextTexts });
                    }}
                    style={{ background: 'transparent', color: 'var(--error)', border: '1px solid var(--error)', borderRadius: 6, padding: '4px 10px', cursor: 'pointer', fontSize: 11, fontWeight: 600 }}>
                    Xóa
                  </button>
                ) : <span />}
              </div>
              );
            })}
            <button type="button"
              disabled={c3.persons.length >= 26}
              onClick={() => {
                const newKey = nextFreeKey(c3.persons.map((p) => p.key));
                if (!newKey) return;
                update({ ...c3, persons: [...c3.persons, emptyC3Person(newKey)] });
              }}
              style={{ alignSelf: 'flex-start', background: 'var(--surface)', color: 'var(--accent)', border: '1px dashed var(--accent)', borderRadius: 8, padding: '6px 14px', cursor: c3.persons.length >= 26 ? 'not-allowed' : 'pointer', fontSize: 12, fontWeight: 600, marginTop: 4, opacity: c3.persons.length >= 26 ? 0.5 : 1 }}>
              + Thêm nhân vật
            </button>
          </div>
          {c3.texts.map((t, i) => {
            const canRemoveText = c3.texts.length > 1;
            return (
            <div key={i} style={sectionStyle}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ ...labelStyle, color: 'var(--accent)', fontSize: 12 }}>Đoạn {i + 1}</span>
                {canRemoveText && (
                  <button type="button"
                    onClick={() => update({ ...c3, texts: c3.texts.filter((_, idx) => idx !== i) })}
                    style={{ background: 'transparent', color: 'var(--error)', border: '1px solid var(--error)', borderRadius: 6, padding: '3px 10px', cursor: 'pointer', fontSize: 12, fontWeight: 600 }}>
                    Xóa đoạn
                  </button>
                )}
              </div>
              <textarea rows={4} value={t.text}
                onChange={e => { const next = [...c3.texts]; next[i] = { ...next[i], text: e.target.value }; update({ ...c3, texts: next }); }}
                placeholder="Nội dung đoạn văn..." style={txStyle} />
              <AnswerSelect label="Nhân vật:" options={c3.persons.map(p => ({ key: p.key, label: p.name }))} value={t.answer}
                onChange={v => { const next = [...c3.texts]; next[i] = { ...next[i], answer: v }; update({ ...c3, texts: next }); }} />
            </div>
            );
          })}
          <button type="button"
            onClick={() => update({ ...c3, texts: [...c3.texts, emptyC3Text()] })}
            style={{ alignSelf: 'flex-start', background: 'var(--accent-soft)', color: 'var(--accent)', border: 'none', borderRadius: 8, padding: '8px 16px', cursor: 'pointer', fontSize: 13, fontWeight: 600 }}>
            + Thêm đoạn văn
          </button>
        </>
      )}

      {/* ── Čtení 5 — reading + fill-in slots ───────────────────── */}
      {c5 && (
        <>
          <label style={{ display: 'grid', gap: 6 }}>
            <span style={labelStyle}>Đoạn văn đọc</span>
            <textarea rows={10} value={c5.text} onChange={e => update({ ...c5, text: e.target.value })} placeholder="Přečtěte si text..." style={txStyle} />
          </label>
          <div style={{ display: 'grid', gap: 8 }}>
            <span style={labelStyle}>Câu điền vào ({c5.slots.length} câu)</span>
            {c5.slots.map((slot, i) => {
              const canRemoveSlot = c5.slots.length > 1;
              return (
              <div key={i} style={sectionStyle}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ ...labelStyle, color: 'var(--accent)', fontSize: 12 }}>Câu {21 + i}</span>
                  {canRemoveSlot && (
                    <button type="button"
                      onClick={() => update({ ...c5, slots: c5.slots.filter((_, idx) => idx !== i) })}
                      style={{ background: 'transparent', color: 'var(--error)', border: '1px solid var(--error)', borderRadius: 6, padding: '3px 10px', cursor: 'pointer', fontSize: 12, fontWeight: 600 }}>
                      Xóa câu này
                    </button>
                  )}
                </div>
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
              );
            })}
            <button type="button"
              onClick={() => update({ ...c5, slots: [...c5.slots, emptyC5Slot()] })}
              style={{ alignSelf: 'flex-start', background: 'var(--accent-soft)', color: 'var(--accent)', border: 'none', borderRadius: 8, padding: '8px 16px', cursor: 'pointer', fontSize: 13, fontWeight: 600, marginTop: 4 }}>
              + Thêm câu điền
            </button>
          </div>
        </>
      )}
    </div>
  );
}
