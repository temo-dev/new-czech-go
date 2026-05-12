// V22 mock-test list helpers. Pure functions extracted so unit tests
// can cover the badge + filter logic without touching the React
// component. Used by the mock-test-dashboard list view (C1 badge,
// C2 filter dropdown).

export type MockTestKind = 'all' | 'normal' | 'promotion' | 'placement';

export type MockTestForFilter = {
  is_promotion?: boolean;
  is_placement?: boolean;
};

// classifyMockTest collapses the two boolean flags into one of three
// mutually-exclusive kinds. is_promotion wins over is_placement when
// both are set (a state the DB constraint forbids; this guards against
// stale/malformed rows on the wire).
export function classifyMockTest(t: MockTestForFilter): 'promotion' | 'placement' | 'normal' {
  if (t.is_promotion) return 'promotion';
  if (t.is_placement) return 'placement';
  return 'normal';
}

// matchesKindFilter returns true when the test row should pass the
// given filter. "all" is the no-op pass.
export function matchesKindFilter(t: MockTestForFilter, filter: MockTestKind): boolean {
  if (filter === 'all') return true;
  return classifyMockTest(t) === filter;
}

export type GatingBadge = {
  label: string;
  cls: string;
};

// gatingBadge returns the badge spec rendered alongside statusBadge +
// examModeBadge in the mock-test list. Returns null for normal tests so
// the row stays uncluttered.
export function gatingBadge(t: {
  is_promotion?: boolean;
  is_placement?: boolean;
  target_level?: string;
}): GatingBadge | null {
  if (t.is_promotion) {
    const lvl = (t.target_level ?? '').toUpperCase();
    return {
      label: lvl ? `🎯 → ${lvl}` : '🎯 Promotion',
      cls: 'badge-promotion',
    };
  }
  if (t.is_placement) {
    return { label: '📍 Placement', cls: 'badge-placement' };
  }
  return null;
}

// PromotionFormSlice is the subset of FormState the conflict detector
// reads. Defined separately so the helper is decoupled from the heavier
// FormState type that mixes form-only fields with payload fields.
export type PromotionFormSlice = {
  is_promotion: boolean;
  status: 'draft' | 'published';
  target_level: string;
};

// MockTestRow is the subset of the list row shape the conflict detector
// inspects. Same surface as gatingBadge plus id + status + title for the
// inline warning copy.
export type MockTestRow = {
  id: string;
  title?: string;
  status?: string;
  is_promotion?: boolean;
  target_level?: string;
};

// findPromotionConflict scans the in-memory `tests` array (loaded from
// the CMS list endpoint on mount) for another published promotion at
// the same target_level. editingId is the id of the row currently being
// edited so it does not flag itself; pass empty string for a fresh
// create. Returns the conflicting row, or null when the form is safe to
// submit.
export function findPromotionConflict(
  tests: MockTestRow[],
  form: PromotionFormSlice,
  editingId: string,
): MockTestRow | null {
  if (!form.is_promotion || form.status !== 'published' || !form.target_level) {
    return null;
  }
  for (const t of tests) {
    if (!t.is_promotion) continue;
    if (t.status !== 'published') continue;
    if ((t.target_level ?? '') !== form.target_level) continue;
    if (t.id === editingId) continue;
    return t;
  }
  return null;
}

// V36 — skill groups for the mock-test section editor. Each group maps
// to an exercise_type prefix; the picker filters available exercises
// per group via `startsWith(prefix)`. The interview group lets admins
// assign interview_conversation / interview_choice_explain exercises
// (pool=exam) into a mock test alongside the original 4 skills.
export type SkillKind = 'noi' | 'nghe' | 'doc' | 'viet' | 'interview';

export type SkillGroup = {
  kind: SkillKind;
  label: string;
  color: string;
  prefix: string;
};

export const SKILL_GROUPS: SkillGroup[] = [
  { kind: 'noi',       label: 'Nói (Speaking)',    color: '#FF6A14', prefix: 'uloha_' },
  { kind: 'nghe',      label: 'Nghe (Listening)',  color: '#3060B8', prefix: 'poslech_' },
  { kind: 'doc',       label: 'Đọc (Reading)',     color: '#C28012', prefix: 'cteni_' },
  { kind: 'viet',      label: 'Viết (Writing)',    color: '#1F8A4D', prefix: 'psani_' },
  { kind: 'interview', label: 'Hội thoại AI',      color: '#0891B2', prefix: 'interview_' },
];

export const EXERCISE_TYPE_LABEL: Record<string, string> = {
  uloha_1_topic_answers: 'Úloha 1 — Topic answers',
  uloha_2_dialogue_questions: 'Úloha 2 — Dialogue questions',
  uloha_3_story_narration: 'Úloha 3 — Story narration',
  uloha_4_choice_reasoning: 'Úloha 4 — Choice & reasoning',
  psani_1_formular: 'Psaní 1 — Formulář',
  psani_2_email: 'Psaní 2 — E-mail',
  poslech_1: 'Poslech 1', poslech_2: 'Poslech 2', poslech_3: 'Poslech 3',
  poslech_4: 'Poslech 4', poslech_5: 'Poslech 5',
  cteni_1: 'Čtení 1', cteni_2: 'Čtení 2', cteni_3: 'Čtení 3',
  cteni_4: 'Čtení 4', cteni_5: 'Čtení 5',
  interview_conversation:   'Hội thoại theo chủ đề',
  interview_choice_explain: 'Chọn phương án + giải thích',
};

export const DEFAULT_MAX_POINTS: Record<string, number> = {
  uloha_1_topic_answers: 8,
  uloha_2_dialogue_questions: 12,
  uloha_3_story_narration: 10,
  uloha_4_choice_reasoning: 7,
  psani_1_formular: 8,
  psani_2_email: 12,
  poslech_1: 5, poslech_2: 5, poslech_3: 5, poslech_4: 5, poslech_5: 5,
  cteni_1: 5, cteni_2: 5, cteni_3: 4, cteni_4: 6, cteni_5: 5,
  interview_conversation:   20,
  interview_choice_explain: 20,
};

export type MockTestSectionLite = {
  sequence_no: number;
  skill_kind: string;
  exercise_id: string;
  exercise_type: string;
  max_points: number;
};

// resequence orders sections by SKILL_GROUPS order (noi → nghe → doc →
// viet → interview) and reassigns sequence_no starting at 1. Sections
// whose skill_kind is not in SKILL_GROUPS are dropped — the form keeps
// only what the editor can render.
export function resequence<T extends MockTestSectionLite>(sections: T[]): T[] {
  let seq = 0;
  return SKILL_GROUPS.flatMap(g =>
    sections.filter(s => s.skill_kind === g.kind).map(s => ({ ...s, sequence_no: ++seq })),
  );
}
