// V23 Phase H3 — per-exercise quality badge mapping. Pure helpers
// extracted so unit tests can assert label/icon/variant without
// rendering React components. Wire shape mirrors the
// ValidationFlags struct returned by GET /v1/admin/exercises.

export type ValidationFlags = {
  missing_audio: boolean;
  missing_sentence_audio: boolean;
  orphan: boolean;
  missing_sample: boolean;
  unpublished: boolean;
};

export type BadgeVariant = 'error' | 'warning' | 'neutral' | 'ready';

export type BadgeSpec = {
  variant: BadgeVariant;
  icon: '❌' | '⚠' | '📝' | '✓';
  label: string;
  tooltip: string;
};

const READY_BADGE: BadgeSpec = {
  variant: 'ready',
  icon: '✓',
  label: 'Sẵn sàng',
  tooltip: 'Tất cả check pass',
};

// flagsToBadges translates a ValidationFlags object into the list of
// badge specs the row renders. When every flag is false the result is
// a single ready (✓) badge so the column never collapses to empty.
export function flagsToBadges(flags: ValidationFlags | undefined): BadgeSpec[] {
  if (!flags) return [];
  const out: BadgeSpec[] = [];
  if (flags.orphan) {
    out.push({
      variant: 'error',
      icon: '❌',
      label: 'Mồ côi',
      tooltip: 'pool=course nhưng chưa gán module',
    });
  }
  if (flags.missing_audio) {
    out.push({
      variant: 'error',
      icon: '❌',
      label: 'Thiếu audio',
      tooltip: 'skill=nghe nhưng chưa có exercise_audio',
    });
  }
  if (flags.missing_sentence_audio) {
    out.push({
      variant: 'error',
      icon: '❌',
      label: 'Thiếu sentence audio',
      tooltip: 'dictation chưa có per-sentence audio',
    });
  }
  if (flags.missing_sample) {
    out.push({
      variant: 'warning',
      icon: '⚠',
      label: 'Thiếu sample',
      tooltip: 'sample_answer_enabled nhưng text rỗng',
    });
  }
  if (flags.unpublished) {
    out.push({
      variant: 'neutral',
      icon: '📝',
      label: 'Draft',
      tooltip: 'Chưa publish',
    });
  }
  return out.length > 0 ? out : [READY_BADGE];
}

// badgeColors centralises the variant → CSS variable lookup so the
// row badge cluster + the quick-fix modal flag list stay in sync.
// Returns inline style suitable for a `<span style={...}>`.
export function badgeStyle(variant: BadgeVariant): { background: string; color: string } {
  switch (variant) {
    case 'error':
      return { background: 'var(--not-ready-bg)', color: 'var(--not-ready)' };
    case 'warning':
      return { background: 'var(--almost-bg)', color: 'var(--almost)' };
    case 'ready':
      return { background: 'var(--ready-bg)', color: 'var(--ready)' };
    case 'neutral':
    default:
      return { background: 'var(--surface-alt)', color: 'var(--ink-3)' };
  }
}

// hasAnyIssue returns true when at least one quality flag fires.
// `unpublished` deliberately does not count — draft is a workflow
// state, not a content rot signal — so the "Chỉ hiện vấn đề" filter
// keeps drafts hidden when they are otherwise clean.
export function hasAnyIssue(flags: ValidationFlags | undefined): boolean {
  if (!flags) return false;
  return Boolean(
    flags.orphan ||
      flags.missing_audio ||
      flags.missing_sentence_audio ||
      flags.missing_sample,
  );
}
