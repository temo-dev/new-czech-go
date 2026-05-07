// V22 Learner X-Ray pure helpers. Extracted so unit tests can cover the
// formatting/grouping logic without touching the React component.

export type LearnerStateResponse = {
  user: {
    id: string;
    email: string;
    display_name: string;
    role: string;
    pro_tier: string;
    grace_attempts_left: number;
    created_at: string;
    updated_at: string;
    pro_expires_at?: string;
  };
  daily_usage: {
    day: string;
    attempts_count: number;
    attempts_cap: number;
  };
  level_state: {
    current_level: string;
    unlocked_levels: string[];
    placement_taken_at?: string;
  };
  mastery: Array<{
    skill_kind: string;
    module_id: string;
    module_label: string;
    score: number;
    attempts_count: number;
    updated_at: string;
  }>;
  promotion_attempts: Array<{
    id: string;
    target_level: string;
    source_level: string;
    score_pct: number;
    passed: boolean;
    created_at: string;
  }>;
  has_more_promotion: boolean;
  recent_attempts: Array<{
    id: string;
    exercise_id: string;
    exercise_label: string;
    skill_kind: string;
    readiness_level?: string;
    started_at: string;
    status?: string;
  }>;
};

export type XRayState =
  | { kind: 'loading' }
  | { kind: 'error'; message: string }
  | { kind: 'not-found' }
  | { kind: 'ready'; data: LearnerStateResponse };

// formatLevelLabel renders a CEFR code as the badge label. Empty string
// becomes "—" so empty rows do not collapse the column.
export function formatLevelLabel(level: string): string {
  if (!level) return '—';
  return level.toUpperCase();
}

// formatMasteryScore turns a 0..1 EMA score into a percentage string.
// Out-of-range values are clamped so a corrupt row still renders.
export function formatMasteryScore(score: number): string {
  if (!Number.isFinite(score)) return '—';
  const clamped = Math.max(0, Math.min(1, score));
  return `${Math.round(clamped * 100)}%`;
}

// formatDate renders an RFC3339 timestamp as DD/MM/YYYY in the local
// timezone. Empty / invalid input falls back to "—".
export function formatDate(iso: string | undefined | null): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (isNaN(d.getTime())) return '—';
  const dd = String(d.getDate()).padStart(2, '0');
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  return `${dd}/${mm}/${d.getFullYear()}`;
}

// formatDateTime adds HH:MM to formatDate.
export function formatDateTime(iso: string | undefined | null): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (isNaN(d.getTime())) return '—';
  const dd = String(d.getDate()).padStart(2, '0');
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const hh = String(d.getHours()).padStart(2, '0');
  const mi = String(d.getMinutes()).padStart(2, '0');
  return `${dd}/${mm}/${d.getFullYear()} ${hh}:${mi}`;
}

// summarizeUnlockedLevels joins the level codes with " · " for the
// collapsed unlock-state display. Empty array yields "—" so the surface
// still has a glyph.
export function summarizeUnlockedLevels(levels: string[] | undefined): string {
  if (!levels || levels.length === 0) return '—';
  return levels.map(l => l.toUpperCase()).join(' · ');
}

// readinessLabel translates the LLM readiness band into the VI copy the
// X-Ray table uses. Unknown values pass through capitalised.
export function readinessLabel(level: string | undefined): string {
  switch (level) {
    case 'not_ready':
      return 'Chưa sẵn sàng';
    case 'almost_ready':
      return 'Gần sẵn sàng';
    case 'ready_for_mock':
      return 'Sẵn sàng luyện đề';
    case 'exam_ready':
      return 'Sẵn sàng thi';
    case '':
    case undefined:
      return '—';
    default:
      return level;
  }
}

// passedVariant maps a passed boolean to a badge variant + label so the
// PromotionAttempts table renders consistently with the rest of the CMS
// (success / error variants from globals.css).
export function passedVariant(passed: boolean): { label: string; cls: string } {
  return passed
    ? { label: 'Đạt', cls: 'badge-ready' }
    : { label: 'Trượt', cls: 'badge-error' };
}

// breadcrumbItems builds the X-Ray header crumbs. Email defaults to "—"
// so loading state still renders without throwing.
export function breadcrumbItems(email: string | undefined): string[] {
  return ['Tài khoản', email && email.length > 0 ? email : '—'];
}
