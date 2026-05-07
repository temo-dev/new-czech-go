// V22 Content Health helpers. Pure functions extracted for unit
// coverage; used by content-health.tsx (component renders, helpers
// compute).

export type CheckItem = {
  entity_type: string;
  entity_id: string;
  label: string;
  extra?: string;
};

export type Check = {
  id: string;
  label: string;
  description: string;
  count: number;
  items: CheckItem[];
  truncated: boolean;
};

export type ContentHealthResponse = {
  checked_at: string;
  checks: Check[];
};

export type ContentHealthState =
  | { kind: 'initial' }
  | { kind: 'running' }
  | { kind: 'loaded'; data: ContentHealthResponse }
  | { kind: 'error'; message: string };

// entityLink maps a check item to the CMS route for the offending
// entity. Unknown types fall back to the home dashboard so a click
// never lands on an undefined route.
export function entityLink(item: CheckItem): string {
  switch (item.entity_type) {
    case 'exercise':
      return `/exercises/${encodeURIComponent(item.entity_id)}`;
    case 'mock_test':
      return `/mock-tests/${encodeURIComponent(item.entity_id)}`;
    case 'course':
      return `/courses/${encodeURIComponent(item.entity_id)}`;
    case 'module':
      return `/modules/${encodeURIComponent(item.entity_id)}`;
    default:
      return '/';
  }
}

// formatCount renders the per-card count. count=0 displays as a
// success glyph; positive counts render the integer with a thousands
// separator so a 5-digit count stays legible.
export function formatCount(count: number): string {
  if (count <= 0) return '✓';
  return count.toLocaleString('vi-VN');
}

// summarizeTotal is the "X vấn đề được phát hiện" header copy. Singular
// in VN doesn't decline so this is a single template.
export function summarizeTotal(checks: Check[]): string {
  const total = checks.reduce((sum, c) => sum + c.count, 0);
  if (total === 0) return 'Không có vấn đề nào được phát hiện.';
  return `${total.toLocaleString('vi-VN')} vấn đề được phát hiện.`;
}

// hasAnyIssue is the predicate used to decide whether the "all clean"
// hero copy should override the per-card grid display.
export function hasAnyIssue(checks: Check[]): boolean {
  return checks.some(c => c.count > 0);
}
