'use client';

import type { ExerciseFormState } from '../exercise-utils';
import { selectPreviewRenderer } from './router';
import { useDebouncedForm } from './use-debounced-form';
import { UlohaPreview } from './uloha-preview';
import { PsaniEmailPreview } from './psani-email-preview';
import { PreviewPlaceholder } from './placeholder';

// V23 Phase C2 — preview pane wrapper. Renders the disclaimer band
// always-on top + dispatches to the per-type renderer. aria-hidden
// because the preview is a visual aid; the form itself is the
// source of truth for screen readers.

type Props = { form: ExerciseFormState };

export function PreviewPane({ form }: Props) {
  const debounced = useDebouncedForm(form, 200);
  const which = selectPreviewRenderer(debounced.exerciseType);

  return (
    <aside
      aria-hidden="true"
      style={{
        background: 'var(--surface-alt)',
        padding: 16,
        borderRadius: 10,
        border: '1px solid var(--border)',
        position: 'sticky',
        top: 16,
        maxHeight: 'calc(100vh - 32px)',
        overflow: 'auto',
      }}
    >
      <DisclaimerBand />
      {which === 'uloha' && <UlohaPreview form={debounced} />}
      {which === 'psani-email' && <PsaniEmailPreview form={debounced} />}
      {which === 'placeholder' && <PreviewPlaceholder type={debounced.exerciseType} />}
    </aside>
  );
}

function DisclaimerBand() {
  return (
    <div
      style={{
        background: '#fff8d6',
        borderLeft: '4px solid #facc15',
        color: '#7c4a03',
        padding: '8px 12px',
        marginBottom: 12,
        borderRadius: 4,
        fontSize: 12,
      }}
    >
      🔍 Preview low-fidelity. Hãy test trên Flutter trước khi ship.
    </div>
  );
}
