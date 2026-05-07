'use client';

import { useState } from 'react';
import { adminFetch } from '../lib/api';
import { type ValidationFlags } from './validation-badges';
import { ValidationBadgeCluster } from './validation-badge-cluster';
import type { Exercise } from './exercise-utils';

// V23 Phase H6 — quick-fix modal exposed via row-click on the
// admin exercises list. Strict V23 scope: publish/unpublish toggle +
// regenerate audio for listening / dictation. Anything else routes
// the admin back to the full edit form.

// audioRegenSupported is the pure predicate driving the "Tạo lại
// audio" button visibility. Listening exercises always qualify;
// writing exercises only when the type is dictation (which generates
// per-sentence audio, not a single track).
export function audioRegenSupported(skillKind: string, exerciseType: string): boolean {
  if (skillKind === 'nghe') return true;
  if (exerciseType === 'psani_3_dictation') return true;
  return false;
}

type Props = {
  exercise: Exercise;
  flags: ValidationFlags | undefined;
  onClose: () => void;
  onApplied: () => void;
};

type ModalState =
  | { kind: 'idle' }
  | { kind: 'submitting' }
  | { kind: 'error'; message: string }
  | { kind: 'done' };

export function ExerciseQuickFixModal({ exercise, flags, onClose, onApplied }: Props) {
  const [status, setStatus] = useState<'draft' | 'published'>(
    (exercise.status as 'draft' | 'published') ?? 'draft',
  );
  const [state, setState] = useState<ModalState>({ kind: 'idle' });
  const audioEnabled = audioRegenSupported(
    exercise.skill_kind ?? '',
    exercise.exercise_type,
  );
  const busy = state.kind === 'submitting';

  async function applyStatus() {
    if (status === exercise.status) {
      onClose();
      return;
    }
    setState({ kind: 'submitting' });
    try {
      const res = await adminFetch(`/api/admin/exercises/${exercise.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status }),
      });
      if (!res.ok) {
        const p = await res.json().catch(() => ({}));
        throw new Error(p.error?.message ?? 'Cập nhật trạng thái thất bại');
      }
      setState({ kind: 'done' });
      onApplied();
      onClose();
    } catch (err) {
      setState({ kind: 'error', message: err instanceof Error ? err.message : 'Lỗi không xác định' });
    }
  }

  async function regenerateAudio() {
    setState({ kind: 'submitting' });
    try {
      const res = await adminFetch(`/api/admin/exercises/${exercise.id}/generate-audio`, {
        method: 'POST',
      });
      if (!res.ok) {
        const p = await res.json().catch(() => ({}));
        throw new Error(p.error?.message ?? 'Tạo lại audio thất bại');
      }
      setState({ kind: 'done' });
      onApplied();
      onClose();
    } catch (err) {
      setState({ kind: 'error', message: err instanceof Error ? err.message : 'Lỗi không xác định' });
    }
  }

  return (
    <div
      onClick={busy ? undefined : onClose}
      style={{
        position: 'fixed', inset: 0, background: 'rgba(20,18,14,0.55)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        zIndex: 1000, padding: 20,
      }}
      role="dialog"
      aria-modal="true"
    >
      <div
        onClick={(e) => e.stopPropagation()}
        style={{
          background: 'var(--surface)', borderRadius: 'var(--r3)',
          padding: 28, maxWidth: 520, width: '100%',
          boxShadow: '0 12px 40px rgba(20,18,14,0.25)',
        }}
      >
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 4, color: 'var(--ink)' }}>
          Hành động nhanh
        </h2>
        <p style={{ fontSize: 13, color: 'var(--ink-2)', margin: '0 0 16px' }}>
          {exercise.title}
        </p>

        {/* Flag list */}
        <div style={{ marginBottom: 16 }}>
          <p style={{ fontSize: 11, fontWeight: 700, color: 'var(--ink-3)', textTransform: 'uppercase', letterSpacing: 0.4, margin: '0 0 8px' }}>
            Tình trạng
          </p>
          {flags ? (
            <ValidationBadgeCluster flags={flags} variant="modal" />
          ) : (
            <p style={{ fontSize: 13, color: 'var(--ink-3)', margin: 0 }}>—</p>
          )}
        </div>

        {/* Status radio */}
        <fieldset style={{ border: '1px solid var(--border)', borderRadius: 8, padding: 12, marginBottom: 12 }}>
          <legend style={{ fontSize: 12, fontWeight: 600, color: 'var(--ink-2)', padding: '0 6px' }}>Trạng thái</legend>
          <label style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13, marginBottom: 4 }}>
            <input
              type="radio"
              checked={status === 'draft'}
              onChange={() => setStatus('draft')}
              disabled={busy}
            />
            Draft
          </label>
          <label style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13 }}>
            <input
              type="radio"
              checked={status === 'published'}
              onChange={() => setStatus('published')}
              disabled={busy}
            />
            Published
          </label>
        </fieldset>

        {/* Audio regen */}
        <div style={{ marginBottom: 16 }}>
          <button
            type="button"
            onClick={regenerateAudio}
            disabled={!audioEnabled || busy}
            style={{
              padding: '8px 14px', fontSize: 13, fontWeight: 600,
              borderRadius: 8, border: '1px solid var(--border)',
              background: audioEnabled ? 'var(--surface-alt)' : 'transparent',
              color: audioEnabled ? 'var(--ink)' : 'var(--ink-4)',
              cursor: audioEnabled && !busy ? 'pointer' : 'not-allowed',
            }}
            title={
              audioEnabled
                ? 'Gọi POST /v1/admin/exercises/:id/generate-audio'
                : 'Audio regen chỉ áp dụng cho skill=nghe và psani_3_dictation'
            }
          >
            🔊 Tạo lại audio
          </button>
        </div>

        {state.kind === 'error' && (
          <p style={{ color: 'var(--error)', fontSize: 12, margin: '0 0 12px' }}>
            {state.message}
          </p>
        )}

        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10 }}>
          <button onClick={onClose} disabled={busy} style={btnGhost}>
            Hủy
          </button>
          <button onClick={applyStatus} disabled={busy} style={btnPrimary}>
            {busy ? 'Đang áp dụng…' : 'Áp dụng'}
          </button>
        </div>
      </div>
    </div>
  );
}

const btnGhost: React.CSSProperties = {
  padding: '8px 16px', fontSize: 13, fontWeight: 600,
  borderRadius: 8, border: '1px solid var(--border)',
  background: 'transparent', color: 'var(--ink-2)', cursor: 'pointer',
};

const btnPrimary: React.CSSProperties = {
  padding: '8px 16px', fontSize: 13, fontWeight: 700,
  borderRadius: 8, border: 'none',
  background: 'var(--brand)', color: 'white', cursor: 'pointer',
};
