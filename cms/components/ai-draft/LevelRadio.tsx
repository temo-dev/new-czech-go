'use client';

import { DRAFT_LEVELS, type DraftLevel } from '../../lib/ai-draft-utils';

type Props = {
  value: DraftLevel | '';
  onChange: (level: DraftLevel) => void;
  disabled?: boolean;
};

export function LevelRadio({ value, onChange, disabled }: Props) {
  return (
    <fieldset className="flex flex-col gap-1.5">
      <legend className="text-sm font-medium text-slate-700">Cấp độ <span className="text-rose-600">*</span></legend>
      <div className="flex flex-wrap gap-3">
        {DRAFT_LEVELS.map((lvl) => (
          <label key={lvl} className="inline-flex cursor-pointer items-center gap-1.5 text-sm text-slate-700">
            <input
              type="radio"
              name="ai-draft-level"
              value={lvl}
              checked={value === lvl}
              disabled={disabled}
              onChange={() => onChange(lvl)}
              className="h-4 w-4 accent-violet-600"
            />
            <span className="font-medium">{lvl}</span>
          </label>
        ))}
      </div>
    </fieldset>
  );
}
