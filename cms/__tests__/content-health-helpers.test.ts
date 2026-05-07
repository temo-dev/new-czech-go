import { describe, it, expect } from 'vitest';
import {
  entityLink,
  formatCount,
  hasAnyIssue,
  summarizeTotal,
  type Check,
} from '../components/content-health-utils';

// V22 CMS Catch-Up — Phase E7. Helper-level coverage for the Content
// Health Report. CMS render is delegated to manual smoke per plan.

describe('entityLink', () => {
  it('maps known entity_type to its CMS route', () => {
    expect(entityLink({ entity_type: 'exercise', entity_id: 'ex_1', label: '' })).toBe('/exercises/ex_1');
    expect(entityLink({ entity_type: 'mock_test', entity_id: 'mt_1', label: '' })).toBe('/mock-tests/mt_1');
    expect(entityLink({ entity_type: 'course', entity_id: 'c_1', label: '' })).toBe('/courses/c_1');
    expect(entityLink({ entity_type: 'module', entity_id: 'm_1', label: '' })).toBe('/modules/m_1');
  });

  it('escapes special characters in entity_id', () => {
    expect(entityLink({ entity_type: 'exercise', entity_id: 'a/b c', label: '' })).toBe('/exercises/a%2Fb%20c');
  });

  it('falls back to "/" for unknown entity types', () => {
    expect(entityLink({ entity_type: 'unexpected', entity_id: 'x', label: '' })).toBe('/');
  });
});

describe('formatCount', () => {
  it('renders 0 as the success glyph', () => {
    expect(formatCount(0)).toBe('✓');
    expect(formatCount(-3)).toBe('✓');
  });

  it('renders positive integers with vi-VN thousands separator', () => {
    expect(formatCount(3)).toBe('3');
    expect(formatCount(12345)).toMatch(/^12[.,\s]345$/);
  });
});

describe('summarizeTotal', () => {
  function check(count: number): Check {
    return { id: 'x', label: 'x', description: '', count, items: [], truncated: false };
  }

  it('returns "no issues" copy when total is 0', () => {
    expect(summarizeTotal([check(0), check(0)])).toBe('Không có vấn đề nào được phát hiện.');
  });

  it('sums counts across checks', () => {
    expect(summarizeTotal([check(2), check(3), check(0)])).toMatch(/^5/);
  });
});

describe('hasAnyIssue', () => {
  function check(count: number): Check {
    return { id: 'x', label: 'x', description: '', count, items: [], truncated: false };
  }

  it('returns false when all checks are 0', () => {
    expect(hasAnyIssue([check(0), check(0)])).toBe(false);
  });

  it('returns true when at least one check has a positive count', () => {
    expect(hasAnyIssue([check(0), check(1)])).toBe(true);
  });

  it('returns false on empty input', () => {
    expect(hasAnyIssue([])).toBe(false);
  });
});
