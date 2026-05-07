import { describe, it, expect } from 'vitest';
import {
  flagsToBadges,
  hasAnyIssue,
  type ValidationFlags,
} from '../components/validation-badges';

// V23 Phase H3 — Helper-level tests for validation badge translation.
// flagsToBadges turns the wire ValidationFlags into renderable badge
// specs; hasAnyIssue is the predicate used by the "Chỉ hiện vấn đề"
// filter.

const allFalse: ValidationFlags = {
  missing_audio: false,
  missing_sentence_audio: false,
  orphan: false,
  missing_sample: false,
  unpublished: false,
};

describe('flagsToBadges', () => {
  it('returns one ✓ ready badge when every flag is false', () => {
    const out = flagsToBadges(allFalse);
    expect(out).toHaveLength(1);
    expect(out[0].variant).toBe('ready');
    expect(out[0].icon).toBe('✓');
  });

  it('returns the orphan badge for orphan=true', () => {
    const out = flagsToBadges({ ...allFalse, orphan: true });
    const labels = out.map(b => b.label);
    expect(labels).toContain('Mồ côi');
    expect(out.find(b => b.label === 'Mồ côi')?.variant).toBe('error');
  });

  it('returns the missing-audio badge for missing_audio=true', () => {
    const out = flagsToBadges({ ...allFalse, missing_audio: true });
    expect(out.map(b => b.label)).toContain('Thiếu audio');
    expect(out.find(b => b.label === 'Thiếu audio')?.variant).toBe('error');
  });

  it('returns the missing-sentence-audio badge for missing_sentence_audio=true', () => {
    const out = flagsToBadges({ ...allFalse, missing_sentence_audio: true });
    expect(out.map(b => b.label)).toContain('Thiếu sentence audio');
  });

  it('returns the missing-sample badge for missing_sample=true', () => {
    const out = flagsToBadges({ ...allFalse, missing_sample: true });
    expect(out.map(b => b.label)).toContain('Thiếu sample');
    expect(out.find(b => b.label === 'Thiếu sample')?.variant).toBe('warning');
  });

  it('returns the draft badge for unpublished=true', () => {
    const out = flagsToBadges({ ...allFalse, unpublished: true });
    expect(out.map(b => b.label)).toContain('Draft');
    expect(out.find(b => b.label === 'Draft')?.variant).toBe('neutral');
  });

  it('returns multiple badges when multiple flags are true', () => {
    const out = flagsToBadges({
      missing_audio: true,
      missing_sentence_audio: false,
      orphan: true,
      missing_sample: false,
      unpublished: true,
    });
    expect(out.map(b => b.label)).toEqual(
      expect.arrayContaining(['Mồ côi', 'Thiếu audio', 'Draft']),
    );
    expect(out.find(b => b.icon === '✓')).toBeUndefined();
  });

  it('returns empty array when flags is undefined', () => {
    expect(flagsToBadges(undefined)).toEqual([]);
  });
});

describe('hasAnyIssue', () => {
  it('returns false when only unpublished is true (draft is not an issue)', () => {
    expect(hasAnyIssue({ ...allFalse, unpublished: true })).toBe(false);
  });

  it('returns true when any quality flag is true', () => {
    expect(hasAnyIssue({ ...allFalse, orphan: true })).toBe(true);
    expect(hasAnyIssue({ ...allFalse, missing_audio: true })).toBe(true);
    expect(hasAnyIssue({ ...allFalse, missing_sample: true })).toBe(true);
  });

  it('returns false for all-clean and undefined input', () => {
    expect(hasAnyIssue(allFalse)).toBe(false);
    expect(hasAnyIssue(undefined)).toBe(false);
  });
});
