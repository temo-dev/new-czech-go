'use client';

import { useState, type ReactNode } from 'react';
import { useMediaQuery } from './exercise-preview/use-media-query';
import { PreviewPane } from './exercise-preview';
import type { ExerciseFormState } from './exercise-utils';

// V23 Phase C1 — split-pane wrapper around the existing form
// content. Width ≥ 1280: form 60% / preview 40% side-by-side.
// Width < 1280: form full + button "Xem preview" → drawer overlay
// from the right.

type Props = {
  children: ReactNode;
  form: ExerciseFormState;
};

export function ExerciseEditLayout({ children, form }: Props) {
  const isWide = useMediaQuery('(min-width: 1280px)');
  const [drawerOpen, setDrawerOpen] = useState(false);

  if (isWide) {
    return (
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: '60% 40%',
          gap: 16,
          alignItems: 'flex-start',
        }}
      >
        <div style={{ minWidth: 0 }}>{children}</div>
        <PreviewPane form={form} />
      </div>
    );
  }

  return (
    <div>
      <div style={{ marginBottom: 12, display: 'flex', justifyContent: 'flex-end' }}>
        <button
          type="button"
          onClick={() => setDrawerOpen(true)}
          style={{
            padding: '8px 14px',
            fontSize: 13,
            fontWeight: 600,
            borderRadius: 8,
            border: '1px solid var(--border)',
            background: 'var(--surface-alt)',
            color: 'var(--ink-2)',
            cursor: 'pointer',
          }}
        >
          🔍 Xem preview
        </button>
      </div>
      {children}
      {drawerOpen && (
        <div
          onClick={() => setDrawerOpen(false)}
          style={{
            position: 'fixed', inset: 0, background: 'rgba(20,18,14,0.55)',
            zIndex: 1000,
          }}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            style={{
              position: 'absolute', top: 0, right: 0, bottom: 0,
              width: 'min(420px, 90vw)',
              background: 'var(--surface)',
              padding: 16,
              overflow: 'auto',
              boxShadow: '-12px 0 40px rgba(20,18,14,0.25)',
            }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
              <strong style={{ fontSize: 14 }}>Preview</strong>
              <button
                type="button"
                onClick={() => setDrawerOpen(false)}
                style={{
                  padding: '4px 10px', fontSize: 12, borderRadius: 6,
                  border: '1px solid var(--border)', background: 'transparent', cursor: 'pointer',
                }}
              >
                Đóng
              </button>
            </div>
            <PreviewPane form={form} />
          </div>
        </div>
      )}
    </div>
  );
}
