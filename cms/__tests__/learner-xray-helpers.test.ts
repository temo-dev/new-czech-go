import { describe, it, expect } from 'vitest';
import {
  formatLevelLabel,
  formatMasteryScore,
  formatDate,
  formatDateTime,
  summarizeUnlockedLevels,
  readinessLabel,
  passedVariant,
  breadcrumbItems,
} from '../components/learner-xray-utils';

// V22 CMS Catch-Up — Phase B13. Helper-level coverage for the X-Ray
// formatters. Component render is delegated to manual smoke (CMS infra
// is pure-vitest without @testing-library/react).

describe('formatLevelLabel', () => {
  it('uppercases the level code', () => {
    expect(formatLevelLabel('a2')).toBe('A2');
    expect(formatLevelLabel('b1')).toBe('B1');
  });

  it('returns "—" on empty input', () => {
    expect(formatLevelLabel('')).toBe('—');
  });
});

describe('formatMasteryScore', () => {
  it('renders 0..1 score as percentage', () => {
    expect(formatMasteryScore(0)).toBe('0%');
    expect(formatMasteryScore(0.74)).toBe('74%');
    expect(formatMasteryScore(1)).toBe('100%');
  });

  it('clamps out-of-range values', () => {
    expect(formatMasteryScore(-0.5)).toBe('0%');
    expect(formatMasteryScore(1.5)).toBe('100%');
  });

  it('returns "—" for NaN / Infinity', () => {
    expect(formatMasteryScore(NaN)).toBe('—');
    expect(formatMasteryScore(Infinity)).toBe('—');
  });
});

describe('formatDate / formatDateTime', () => {
  it('returns "—" for empty / invalid', () => {
    expect(formatDate(undefined)).toBe('—');
    expect(formatDate('')).toBe('—');
    expect(formatDate('not-a-date')).toBe('—');
    expect(formatDateTime(undefined)).toBe('—');
  });

  it('renders DD/MM/YYYY for a known date', () => {
    // 2026-05-07 in local timezone — pinned to year/month/day, not to time.
    const out = formatDate('2026-05-07T12:00:00Z');
    // The day shifts +1 in tz UTC+12 etc, but yyyy / month / dd stays
    // valid as DD/MM/YYYY shape. Assert shape via regex.
    expect(out).toMatch(/^\d{2}\/\d{2}\/2026$/);
  });

  it('formatDateTime adds HH:MM block', () => {
    const out = formatDateTime('2026-05-07T12:00:00Z');
    expect(out).toMatch(/^\d{2}\/\d{2}\/2026 \d{2}:\d{2}$/);
  });
});

describe('summarizeUnlockedLevels', () => {
  it('joins sorted level codes with " · "', () => {
    expect(summarizeUnlockedLevels(['a0', 'a2'])).toBe('A0 · A2');
    expect(summarizeUnlockedLevels(['a2'])).toBe('A2');
  });

  it('returns "—" for empty / undefined', () => {
    expect(summarizeUnlockedLevels([])).toBe('—');
    expect(summarizeUnlockedLevels(undefined)).toBe('—');
  });
});

describe('readinessLabel', () => {
  it('translates known bands to VI copy', () => {
    expect(readinessLabel('not_ready')).toBe('Chưa sẵn sàng');
    expect(readinessLabel('almost_ready')).toBe('Gần sẵn sàng');
    expect(readinessLabel('ready_for_mock')).toBe('Sẵn sàng luyện đề');
    expect(readinessLabel('exam_ready')).toBe('Sẵn sàng thi');
  });

  it('returns "—" for undefined / empty', () => {
    expect(readinessLabel(undefined)).toBe('—');
    expect(readinessLabel('')).toBe('—');
  });

  it('passes through unknown values verbatim', () => {
    expect(readinessLabel('unexpected_band')).toBe('unexpected_band');
  });
});

describe('passedVariant', () => {
  it('maps true → Đạt + ready badge', () => {
    expect(passedVariant(true)).toEqual({ label: 'Đạt', cls: 'badge-ready' });
  });

  it('maps false → Trượt + error badge', () => {
    expect(passedVariant(false)).toEqual({ label: 'Trượt', cls: 'badge-error' });
  });
});

describe('breadcrumbItems', () => {
  it('uses the email when provided', () => {
    expect(breadcrumbItems('a@b.com')).toEqual(['Tài khoản', 'a@b.com']);
  });

  it('falls back to "—" for empty / undefined', () => {
    expect(breadcrumbItems(undefined)).toEqual(['Tài khoản', '—']);
    expect(breadcrumbItems('')).toEqual(['Tài khoản', '—']);
  });
});
