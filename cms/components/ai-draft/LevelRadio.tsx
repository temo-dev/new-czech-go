'use client';

import type { CSSProperties } from 'react';
import { DRAFT_LEVELS, type DraftLevel } from '../../lib/ai-draft-utils';

type Props = {
  value: DraftLevel | '';
  onChange: (level: DraftLevel) => void;
  disabled?: boolean;
};

const fieldsetStyle: CSSProperties = { border: 0, display: 'grid', gap: 6, margin: 0, padding: 0 };
const legendStyle: CSSProperties = { color: 'var(--ink-2)', fontSize: 13, fontWeight: 600, marginBottom: 2 };
const requiredStyle: CSSProperties = { color: '#dc2626' };
const rowStyle: CSSProperties = { display: 'flex', flexWrap: 'wrap', gap: 12 };
const optionStyle: CSSProperties = { display: 'inline-flex', alignItems: 'center', gap: 5, color: 'var(--ink-2)', cursor: 'pointer', fontSize: 13, fontWeight: 600 };

export function LevelRadio({ value, onChange, disabled }: Props) {
  return (
    <fieldset style={fieldsetStyle}>
      <legend style={legendStyle}>Cấp độ <span style={requiredStyle}>*</span></legend>
      <div style={rowStyle}>
        {DRAFT_LEVELS.map((lvl) => (
          <label key={lvl} style={{ ...optionStyle, cursor: disabled ? 'not-allowed' : 'pointer' }}>
            <input
              type="radio"
              name="ai-draft-level"
              value={lvl}
              checked={value === lvl}
              disabled={disabled}
              onChange={() => onChange(lvl)}
              style={{ accentColor: '#7c3aed' }}
            />
            <span>{lvl}</span>
          </label>
        ))}
      </div>
    </fieldset>
  );
}
