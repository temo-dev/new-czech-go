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
