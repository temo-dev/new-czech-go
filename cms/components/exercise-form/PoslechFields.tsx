'use client';

import { useEffect, useRef, useState } from 'react';
import { AnswerSelect } from './AnswerSelect';
import { OptionRow } from './OptionRow';
import AiImageButton from '../AiImageButton';
import { adminFetch } from '../../lib/api';
import {
  initPoslechState,
  buildPoslechDetail,
  makeOptionImagePatcher,
  makeSharedOptionImagePatcher,
  parseUploadResponse,
  sharedUploadingKeyFor,
  uploadingKeyFor,
  type OptionKey,
  type P12Item,
  type P5State,
  type PoslechState,
  type PoslechType,
  type SharedImageOptionKey,
} from './poslech-model';

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
const imgInputStyle: React.CSSProperties = { flex: 1, padding: '7px 10px', border: '1px solid var(--border-strong)', borderRadius: 8, fontSize: 13, color: 'var(--ink)', background: 'var(--surface)', fontFamily: 'inherit' };

export function PoslechFields({ exerciseType, initialData, onChange, editingId, audioGenerating, audioGenMsg, onGenerateAudio }: Props) {
  const [state, setState] = useState<PoslechState>(() => initPoslechState(exerciseType, initialData));
  const [audioSource, setAudioSource] = useState<'text' | 'upload'>('text');
  // V29 — manual image upload per (item, option). Single-flight: the key
  // identifies which cell is currently uploading; null = idle.
  const [uploadingKey, setUploadingKey] = useState<string | null>(null);
  const [uploadError, setUploadError] = useState<{ key: string; message: string } | null>(null);
  const fileInputRefs = useRef<Record<string, HTMLInputElement | null>>({});

  // Re-init when switching exercise or opening a different one in edit mode
  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => { setState(initPoslechState(exerciseType, initialData)); }, [exerciseType, JSON.stringify(initialData)]);

  function update(next: PoslechState) { setState(next); onChange(buildPoslechDetail(next, audioSource)); }
  function updateAudioSrc(src: 'text' | 'upload') { setAudioSource(src); onChange(buildPoslechDetail(state, src)); }

  async function handleOptionImageUpload(
    file: File,
    key: string,
    setImg: (assetId: string) => void,
  ) {
    if (!editingId) {
      setUploadError({ key, message: 'Lưu bài tập trước rồi upload ảnh.' });
      return;
    }
    setUploadingKey(key);
    setUploadError(null);
    try {
      const formData = new FormData();
      formData.set('file', file);
      formData.set('asset_kind', 'image');
      const res = await adminFetch(`/api/admin/exercises/${editingId}/assets/upload`, {
        method: 'POST',
        body: formData,
      });
      const json = await res.json();
      if (!res.ok) {
        const errMsg = (json?.error?.message as string | undefined) ?? 'Upload thất bại.';
        throw new Error(errMsg);
      }
      const assetId = parseUploadResponse(json);
      setImg(assetId);
    } catch (err) {
      setUploadError({ key, message: err instanceof Error ? err.message : 'Upload thất bại.' });
    } finally {
      setUploadingKey(null);
    }
  }

  async function registerGeneratedImage(
    result: { assetId: string; storageKey: string },
    setImg: (assetId: string) => void,
  ) {
    if (!editingId) return;
    // Register the freshly generated blob as an exercise asset so the same
    // /v1/media/file route the learner uses can serve it.
    await adminFetch(`/api/admin/exercises/${editingId}/assets`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        id: result.assetId,
        asset_kind: 'image',
        storage_key: result.storageKey,
        mime_type: 'image/jpeg',
      }),
    });
    // Store storage_key, not registry id. Flutter mediaUri resolves ?key=...
    setImg(result.storageKey);
  }

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
            <div style={{ display: 'grid', gap: 8 }}>
              <span style={labelStyle}>Lựa chọn A-D (V27: paste asset_id, V28: ✨ AI tạo)</span>
              {(['A', 'B', 'C', 'D'] as const).map(k => {
                const imgK = (item as Record<string, string>)[`img${k}`] ?? '';
                const setImg = makeOptionImagePatcher(patch, k as OptionKey);
                const cellKey = uploadingKeyFor(i, k as OptionKey);
                const isUploading = uploadingKey === cellKey;
                const cellError = uploadError?.key === cellKey ? uploadError.message : null;
                const otherUploadingBlocks = uploadingKey !== null && uploadingKey !== cellKey;
                return (
                  <div key={k} style={{ display: 'grid', gap: 4, gridTemplateColumns: '1fr' }}>
                    <OptionRow optionKey={k} label={(item as Record<string, string>)[`opt${k}`] ?? ''} onChange={v => patch({ [`opt${k}`]: v } as Partial<P12Item>)} />
                    <input
                      type="text"
                      value={imgK}
                      onChange={e => setImg(e.target.value)}
                      placeholder={`Storage key ảnh ${k} (vd. exercises/<id>/<asset>.jpg — paste, hoặc dùng ✨ AI / 📁 Upload)`}
                      style={imgInputStyle}
                    />
                    <div style={{ display: 'flex', gap: 6, alignItems: 'stretch' }}>
                      <label style={{
                        flex: 1,
                        display: 'inline-flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        gap: 6,
                        border: '1.5px solid var(--border-strong)',
                        borderRadius: 8,
                        padding: '7px 14px',
                        fontSize: 12,
                        fontWeight: 700,
                        cursor: (!editingId || otherUploadingBlocks) ? 'not-allowed' : 'pointer',
                        background: 'var(--surface)',
                        color: 'var(--ink-2)',
                        opacity: (!editingId || otherUploadingBlocks) ? 0.5 : 1,
                        lineHeight: 1,
                      }}>
                        {isUploading ? '⏳ Đang tải...' : imgK ? '🔄 Đổi ảnh' : '📁 Tải ảnh lên'}
                        <input
                          ref={el => { fileInputRefs.current[cellKey] = el; }}
                          type="file"
                          accept="image/jpeg,image/png,image/webp"
                          style={{ display: 'none' }}
                          disabled={!editingId || otherUploadingBlocks || isUploading}
                          onChange={e => {
                            const f = e.target.files?.[0];
                            if (f) void handleOptionImageUpload(f, cellKey, setImg);
                            e.target.value = '';
                          }}
                        />
                      </label>
                      <AiImageButton
                        onAssetCreated={(result) => registerGeneratedImage(result, setImg)}
                        disabled={!editingId || otherUploadingBlocks}
                        existingAssetId={imgK || undefined}
                      />
                    </div>
                    {cellError && (
                      <div style={{ fontSize: 11, color: 'var(--error)', marginTop: 2 }}>
                        {cellError}
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
            <AnswerSelect label="Đáp án đúng:" options={opts} value={item.answer} onChange={v => patch({ answer: v })} />
          </div>
        );
      })}

      {/* ── Poslech 3 / 4 — shared options pool ───────────────────── */}
      {match && (
        <>
          <div style={{ display: 'grid', gap: 6 }}>
            <span style={labelStyle}>
              {match.type === 'poslech_4' ? 'Options A-F (ảnh)' : 'Options A-G (nội dung)'}
            </span>
            {match.options.map((opt, oi) => {
              const optionKey = opt.key as SharedImageOptionKey;
              const patchSharedImage = makeSharedOptionImagePatcher((key, assetId) => {
                const next = [...match.options];
                const targetIndex = next.findIndex((o) => o.key === key);
                if (targetIndex < 0) return;
                next[targetIndex] = { ...next[targetIndex], label: assetId };
                update({ ...match, options: next });
              }, optionKey);

              if (match.type !== 'poslech_4') {
                return (
                  <OptionRow
                    key={opt.key}
                    optionKey={opt.key}
                    label={opt.label}
                    placeholder={`Nội dung ${opt.key}`}
                    onChange={v => {
                      const next = [...match.options];
                      next[oi] = { ...next[oi], label: v };
                      update({ ...match, options: next });
                    }}
                  />
                );
              }

              const cellKey = sharedUploadingKeyFor(optionKey);
              const isUploading = uploadingKey === cellKey;
              const cellError = uploadError?.key === cellKey ? uploadError.message : null;
              const otherUploadingBlocks = uploadingKey !== null && uploadingKey !== cellKey;
              return (
                <div key={opt.key} style={{ display: 'grid', gap: 4 }}>
                  <OptionRow
                    optionKey={opt.key}
                    label={opt.label}
                    placeholder={`Storage key ảnh ${opt.key} (paste, upload hoặc AI tạo)`}
                    onChange={patchSharedImage}
                  />
                  <div style={{ display: 'flex', gap: 6, alignItems: 'stretch', paddingLeft: 34 }}>
                    <label style={{
                      flex: 1,
                      display: 'inline-flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      gap: 6,
                      border: '1.5px solid var(--border-strong)',
                      borderRadius: 8,
                      padding: '7px 14px',
                      fontSize: 12,
                      fontWeight: 700,
                      cursor: (!editingId || otherUploadingBlocks) ? 'not-allowed' : 'pointer',
                      background: 'var(--surface)',
                      color: 'var(--ink-2)',
                      opacity: (!editingId || otherUploadingBlocks) ? 0.5 : 1,
                      lineHeight: 1,
                    }}>
                      {isUploading ? '⏳ Đang tải...' : opt.label ? '🔄 Đổi ảnh' : '📁 Tải ảnh lên'}
                      <input
                        ref={el => { fileInputRefs.current[cellKey] = el; }}
                        type="file"
                        accept="image/jpeg,image/png,image/webp"
                        style={{ display: 'none' }}
                        disabled={!editingId || otherUploadingBlocks || isUploading}
                        onChange={e => {
                          const f = e.target.files?.[0];
                          if (f) void handleOptionImageUpload(f, cellKey, patchSharedImage);
                          e.target.value = '';
                        }}
                      />
                    </label>
                    <AiImageButton
                      onAssetCreated={(result) => registerGeneratedImage(result, patchSharedImage)}
                      disabled={!editingId || otherUploadingBlocks}
                      existingAssetId={opt.label || undefined}
                    />
                  </div>
                  {cellError && (
                    <div style={{ fontSize: 11, color: 'var(--error)', marginTop: 2, paddingLeft: 34 }}>
                      {cellError}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
          {match.items.map((item, i) => {
            const displayNo = item.questionNo > 0 ? item.questionNo : i + 1;
            return (
              <div key={i} style={sectionStyle}>
                <span style={{ ...labelStyle, color: 'var(--accent)', fontSize: 12 }}>Câu {displayNo}</span>
                {match.type === 'poslech_3' && (
                  <label style={{ display: 'grid', gap: 4 }}>
                    <span style={labelStyle}>Tên câu hỏi (hiển thị cho học viên)</span>
                    <input
                      type="text"
                      value={item.question}
                      onChange={e => {
                        const next = [...match.items];
                        next[i] = { ...next[i], question: e.target.value };
                        update({ ...match, items: next });
                      }}
                      placeholder="Ví dụ: Leila"
                      style={{ padding: '8px 10px', border: '1px solid var(--border-strong)', borderRadius: 8, fontSize: 14, fontFamily: 'inherit' }}
                    />
                  </label>
                )}
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
            );
          })}
        </>
      )}

      {/* ── Poslech 5 — voicemail fill-in ─────────────────────────── */}
      {p5 && (
        <>
          {audioSource === 'text' && (
            <label style={{ display: 'grid', gap: 6 }}>
              <span style={labelStyle}>Nội dung voicemail (mỗi dòng = 1 câu)</span>
              <textarea rows={6} value={(p5 as P5State).voiceText}
                onChange={e => update({ ...p5, voiceText: e.target.value })}
                placeholder={'Ahoj Lído, tady Eva.\nDostala jsem lístky na balet.'}
                style={txStyle}
              />
            </label>
          )}
          <div style={{ display: 'grid', gap: 8 }}>
            <span style={labelStyle}>Câu hỏi + đáp án điền vào (5 câu)</span>
            {(p5 as P5State).slots.map((slot, i) => (
              <div key={i} style={sectionStyle}>
                <span style={{ ...labelStyle, color: 'var(--accent)', fontSize: 12 }}>
                  Câu {slot.questionNo > 0 ? slot.questionNo : 21 + i}
                </span>
                <input type="text" value={slot.prompt}
                  onChange={e => {
                    const next = [...(p5 as P5State).slots];
                    next[i] = { ...next[i], prompt: e.target.value };
                    update({ ...p5, slots: next });
                  }}
                  placeholder="Ví dụ: KDO dal Evě lístky?"
                  style={{ padding: '7px 10px', border: '1px solid var(--border-strong)', borderRadius: 8, fontSize: 14, fontFamily: 'inherit' }}
                />
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <span style={{ fontSize: 13, color: 'var(--ink-3)', flexShrink: 0 }}>Đáp án:</span>
                  <input type="text" value={slot.answer}
                    onChange={e => {
                      const next = [...(p5 as P5State).slots];
                      next[i] = { ...next[i], answer: e.target.value };
                      update({ ...p5, slots: next });
                    }}
                    placeholder="Đáp án đúng..."
                    style={{ flex: 1, padding: '7px 10px', border: '1px solid var(--border-strong)', borderRadius: 8, fontSize: 14, fontFamily: 'inherit' }}
                  />
                </div>
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
