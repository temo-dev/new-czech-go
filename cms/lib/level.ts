// V21 CEFR level constants for the CMS course + mock-test forms. Single
// source of truth for the four levels A0/A1/A2/B1 so dropdowns, validators,
// and payload builders agree.
//
// Vietnamese labels are inline per the form-fields convention in
// AGENTS.md ("Form-field components use inline VI strings"); the
// `cms/lib/i18n.tsx` context is reserved for sidebar / dashboards / list
// views.

export const CEFR_LEVELS = ['a0', 'a1', 'a2', 'b1'] as const;

export type CefrLevel = (typeof CEFR_LEVELS)[number];

export const DEFAULT_COURSE_LEVEL: CefrLevel = 'a2';

// User-facing labels rendered inside the level dropdown. Description
// copy is the secondary hint shown under the select on focus.
export const LEVEL_LABELS_VI: Record<CefrLevel, string> = {
  a0: 'A0 — Mới bắt đầu',
  a1: 'A1 — Cơ bản',
  a2: 'A2 — Trvalý pobyt (mặc định)',
  b1: 'B1 — Občanství',
};

export function isCefrLevel(value: unknown): value is CefrLevel {
  return typeof value === 'string' && (CEFR_LEVELS as readonly string[]).includes(value);
}

// sanitizeLevel coerces an unknown server / form payload string into a
// valid CEFR level. Empty / unknown input falls back to DEFAULT_COURSE_LEVEL
// so a misconfigured row never breaks the form.
export function sanitizeLevel(value: unknown): CefrLevel {
  if (isCefrLevel(value)) return value;
  return DEFAULT_COURSE_LEVEL;
}

// labelForLevel returns the VI label for a level, falling back to the
// uppercased code when the level is unknown.
export function labelForLevel(value: unknown): string {
  if (isCefrLevel(value)) return LEVEL_LABELS_VI[value];
  if (typeof value === 'string' && value.length > 0) return value.toUpperCase();
  return LEVEL_LABELS_VI[DEFAULT_COURSE_LEVEL];
}

// isLowestLevel returns true when the given level is the bottom of the
// ladder. The CMS hides the "Demo exercise" field at this level — there
// is no upper-level course to taste-test toward.
export function isLowestLevel(value: CefrLevel): boolean {
  return value === CEFR_LEVELS[0];
}

export function cefrLevelRank(value: unknown): number {
  if (!isCefrLevel(value)) return 0;
  return CEFR_LEVELS.indexOf(value);
}

export function nextCefrLevel(value: unknown): CefrLevel | null {
  const currentRank = cefrLevelRank(value);
  return CEFR_LEVELS[currentRank + 1] ?? null;
}

export function canRaiseLevel(current: unknown, target: unknown): target is CefrLevel {
  if (!isCefrLevel(target)) return false;
  return cefrLevelRank(target) >= cefrLevelRank(current);
}
