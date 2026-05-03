'use client';

import React, { useEffect, useRef, useState } from 'react';
import { adminFetch } from '../lib/api';
import { validateAiPrompt, mapApiResult, type AiImageResult, type AiImageState } from './ai-image-utils';

interface Props {
  onAssetCreated: (result: AiImageResult) => void;
  disabled?: boolean;
  existingAssetId?: string;
  initialPrompt?: string;
}

type State = AiImageState;

interface GenerateResponse {
  asset_id: string;
  storage_key: string;
  preview_url: string;
}


export default function AiImageButton({
  onAssetCreated,
  disabled = false,
  existingAssetId,
  initialPrompt = '',
}: Props) {
  const [state, setState] = useState<State>('idle');
  const [prompt, setPrompt] = useState(initialPrompt);
  const [result, setResult] = useState<GenerateResponse | null>(null);
  const [errorMsg, setErrorMsg] = useState('');
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  // Focus textarea when panel opens.
  useEffect(() => {
    if (state === 'open' && textareaRef.current) {
      textareaRef.current.focus();
    }
  }, [state]);

  function toggle() {
    if (disabled) return;
    if (state === 'idle') {
      setState('open');
    } else if (state === 'open' || state === 'error') {
      setState('idle');
    }
  }

  function cancel() {
    setState('idle');
    setResult(null);
    setErrorMsg('');
  }

  async function generate() {
    if (validateAiPrompt(prompt) !== null || state === 'generating') return;
    setState('generating');
    setErrorMsg('');
    try {
      const resp = await adminFetch('/api/admin/ai/generate-image', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ prompt: prompt.trim() }),
      });
      const json = await resp.json() as { data?: GenerateResponse; error?: { message: string } };
      if (!resp.ok) {
        setErrorMsg(json.error?.message ?? 'Tạo ảnh thất bại. Thử lại.');
        setState('error');
        return;
      }
      setResult(json.data ?? null);
      setState('preview');
    } catch {
      setErrorMsg('Lỗi kết nối. Thử lại.');
      setState('error');
    }
  }

  async function confirm() {
    if (!result) return;
    setState('uploading');
    onAssetCreated(mapApiResult(result));
    setState('idle');
    setResult(null);
    setPrompt('');
  }

  function retry() {
    setState('open');
    setResult(null);
    setErrorMsg('');
    // prompt preserved intentionally
  }

  const panelOpen = state === 'open' || state === 'generating' || state === 'preview' || state === 'error' || state === 'uploading';
  const btnLabel = existingAssetId ? '✨ Tạo lại bằng AI' : '✨ Tạo bằng AI';
  const btnActive = panelOpen;

  const prefersReducedMotion = typeof window !== 'undefined' &&
    window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  return (
    <div style={{ display: 'contents' }}>
      {/* Trigger button */}
      <button
        type="button"
        onClick={toggle}
        disabled={disabled || state === 'generating' || state === 'uploading'}
        title={disabled ? 'Lưu bài tập trước để tạo ảnh AI' : undefined}
        style={{
          flex: 1,
          display: 'inline-flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 6,
          border: `1.5px solid ${btnActive ? '#7c3aed' : '#c4b5fd'}`,
          borderRadius: 8,
          padding: '7px 14px',
          fontSize: 12,
          fontWeight: 700,
          cursor: disabled ? 'not-allowed' : 'pointer',
          background: btnActive ? '#ede9fe' : '#f3f0ff',
          color: '#7c3aed',
          opacity: disabled || state === 'generating' || state === 'uploading' ? 0.5 : 1,
          transition: 'all 0.15s',
          lineHeight: 1,
        }}
      >
        {btnLabel} {panelOpen ? '▲' : '▼'}
      </button>

      {/* Collapsible panel */}
      {panelOpen && (
        <div
          style={{
            gridColumn: '1 / -1',
            background: '#f3f0ff',
            border: '1.5px solid #c4b5fd',
            borderRadius: 10,
            padding: 12,
            display: 'grid',
            gap: 10,
            animation: prefersReducedMotion ? undefined : 'aiPanelSlideDown 0.18s ease-out',
          }}
        >
          <style>{`
            @keyframes aiPanelSlideDown {
              from { opacity: 0; transform: translateY(-6px); }
              to   { opacity: 1; transform: translateY(0); }
            }
          `}</style>

          <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 12, fontWeight: 700, color: '#7c3aed' }}>
            <span style={{ width: 20, height: 20, background: '#7c3aed', color: '#fff', borderRadius: 5, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', fontSize: 11 }}>✨</span>
            {state === 'generating' ? 'Đang tạo ảnh...' :
             state === 'preview' || state === 'uploading' ? 'Ảnh đã tạo xong — xem trước' :
             state === 'error' ? 'Tạo ảnh thất bại' :
             'Mô tả ảnh bạn muốn tạo (tiếng Anh)'}
          </div>

          {/* Error message */}
          {state === 'error' && (
            <div style={{ background: '#fef2f2', border: '1.5px solid #fecaca', borderRadius: 8, padding: '10px 12px', fontSize: 12, color: '#dc2626' }}>
              {errorMsg}
            </div>
          )}

          {/* Generating progress */}
          {state === 'generating' && (
            <div style={{ background: '#fff', borderRadius: 8, padding: '16px 12px', textAlign: 'center', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8 }}>
              <div style={{ fontSize: 24 }}>🎨</div>
              <div style={{ fontSize: 12, fontWeight: 600, color: '#7c3aed' }}>Flux đang vẽ ảnh cho bạn...</div>
              <div style={{ width: '100%', height: 4, background: '#c4b5fd', borderRadius: 2, overflow: 'hidden' }}>
                <div style={{ height: '100%', background: '#7c3aed', borderRadius: 2, animation: 'aiProgress 1.5s ease-in-out infinite', width: '60%' }} />
              </div>
              <style>{`
                @keyframes aiProgress {
                  0% { width: 0%; }
                  50% { width: 80%; }
                  100% { width: 100%; }
                }
              `}</style>
              <div style={{ fontSize: 11, color: '#7c3aed', opacity: 0.7 }}>Thường mất 3–8 giây</div>
            </div>
          )}

          {/* Preview */}
          {(state === 'preview' || state === 'uploading') && result && (
            <div style={{ display: 'grid', gridTemplateColumns: '120px 1fr', gap: 12, alignItems: 'center' }}>
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={result.preview_url}
                alt="AI generated preview"
                style={{ width: 120, height: 80, objectFit: 'cover', borderRadius: 8, border: '2px solid #c4b5fd' }}
              />
              <div style={{ display: 'grid', gap: 6 }}>
                <div style={{ fontSize: 11, fontWeight: 700, color: '#7c3aed' }}>✨ Ảnh do AI tạo</div>
                <button
                  type="button"
                  onClick={() => void confirm()}
                  disabled={state === 'uploading'}
                  style={{ width: '100%', background: '#f0fdf4', border: '1.5px solid #bbf7d0', borderRadius: 8, padding: '7px 12px', fontSize: 12, fontWeight: 700, color: '#16a34a', cursor: 'pointer' }}
                >
                  {state === 'uploading' ? '⏳ Đang lưu...' : '✓ Dùng ảnh này'}
                </button>
                <div style={{ display: 'flex', gap: 6 }}>
                  <button type="button" onClick={retry} disabled={state === 'uploading'} style={{ flex: 1, background: 'transparent', border: '1.5px solid var(--border)', borderRadius: 8, padding: '5px 8px', fontSize: 11, fontWeight: 600, color: 'var(--ink-3)', cursor: 'pointer' }}>
                    🔄 Thử lại
                  </button>
                  <button type="button" onClick={cancel} disabled={state === 'uploading'} style={{ flex: 1, background: 'transparent', border: '1.5px solid var(--border)', borderRadius: 8, padding: '5px 8px', fontSize: 11, fontWeight: 600, color: 'var(--ink-4)', cursor: 'pointer' }}>
                    ✕ Hủy
                  </button>
                </div>
              </div>
            </div>
          )}

          {/* Prompt input */}
          {(state === 'open' || state === 'error') && (
            <div style={{ display: 'flex', gap: 8, alignItems: 'flex-end' }}>
              <textarea
                ref={textareaRef}
                value={prompt}
                onChange={e => setPrompt(e.target.value)}
                placeholder='e.g. A cozy Czech café with a couple having coffee, warm lighting, photorealistic'
                rows={3}
                style={{
                  flex: 1,
                  border: '1.5px solid #c4b5fd',
                  borderRadius: 8,
                  padding: '8px 10px',
                  fontSize: 12,
                  fontFamily: 'inherit',
                  color: 'var(--ink)',
                  background: '#fff',
                  resize: 'vertical',
                  lineHeight: 1.5,
                  outline: 'none',
                }}
                onKeyDown={e => {
                  // Enter = newline, not submit
                  if (e.key === 'Enter' && !e.shiftKey) {
                    // allow default (newline)
                  }
                }}
              />
              <button
                type="button"
                onClick={() => void generate()}
                disabled={validateAiPrompt(prompt) !== null}
                style={{
                  background: validateAiPrompt(prompt) !== null ? '#a78bfa' : '#7c3aed',
                  color: '#fff',
                  border: 'none',
                  borderRadius: 8,
                  padding: '8px 14px',
                  fontSize: 12,
                  fontWeight: 700,
                  cursor: validateAiPrompt(prompt) !== null ? 'not-allowed' : 'pointer',
                  height: 72, // matches 3-row textarea
                  display: 'flex',
                  alignItems: 'center',
                  gap: 6,
                  whiteSpace: 'nowrap',
                }}
              >
                ▶ Tạo
              </button>
            </div>
          )}

          {(state === 'open') && (
            <p style={{ margin: 0, fontSize: 11, color: '#7c3aed', opacity: 0.8 }}>
              💡 Mô tả bằng tiếng Anh cho kết quả tốt hơn. Flux Schnell ~3–5s/ảnh.
            </p>
          )}
        </div>
      )}
    </div>
  );
}
