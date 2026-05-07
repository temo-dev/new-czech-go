import { describe, it, expect } from 'vitest';
import {
  classifyMockTest,
  matchesKindFilter,
  gatingBadge,
  findPromotionConflict,
  type MockTestRow,
} from '../components/mock-test-dashboard-utils';

// V22 CMS Catch-Up — Phase C3 + D5. Helper-level coverage for the
// mock-test list extension. List badge + filter logic are pure
// functions kept in mock-test-dashboard-utils.ts so the React
// component stays a thin renderer.

describe('classifyMockTest', () => {
  it('returns "promotion" when is_promotion is true', () => {
    expect(classifyMockTest({ is_promotion: true })).toBe('promotion');
  });

  it('returns "placement" when is_placement is true (and is_promotion false)', () => {
    expect(classifyMockTest({ is_placement: true })).toBe('placement');
  });

  it('returns "normal" when neither flag is set', () => {
    expect(classifyMockTest({})).toBe('normal');
    expect(classifyMockTest({ is_promotion: false, is_placement: false })).toBe('normal');
  });
});

describe('matchesKindFilter', () => {
  it('"all" passes anything', () => {
    expect(matchesKindFilter({}, 'all')).toBe(true);
    expect(matchesKindFilter({ is_promotion: true }, 'all')).toBe(true);
    expect(matchesKindFilter({ is_placement: true }, 'all')).toBe(true);
  });

  it('"promotion" only passes promotion mocks', () => {
    expect(matchesKindFilter({ is_promotion: true }, 'promotion')).toBe(true);
    expect(matchesKindFilter({ is_placement: true }, 'promotion')).toBe(false);
    expect(matchesKindFilter({}, 'promotion')).toBe(false);
  });

  it('"placement" only passes placement mocks', () => {
    expect(matchesKindFilter({ is_placement: true }, 'placement')).toBe(true);
    expect(matchesKindFilter({ is_promotion: true }, 'placement')).toBe(false);
    expect(matchesKindFilter({}, 'placement')).toBe(false);
  });

  it('"normal" excludes both gated kinds', () => {
    expect(matchesKindFilter({}, 'normal')).toBe(true);
    expect(matchesKindFilter({ is_promotion: true }, 'normal')).toBe(false);
    expect(matchesKindFilter({ is_placement: true }, 'normal')).toBe(false);
  });
});

describe('gatingBadge', () => {
  it('returns null for a normal mock test', () => {
    expect(gatingBadge({})).toBeNull();
    expect(gatingBadge({ is_promotion: false, is_placement: false })).toBeNull();
  });

  it('returns promotion badge with arrow + uppercase level', () => {
    const got = gatingBadge({ is_promotion: true, target_level: 'a2' });
    expect(got).not.toBeNull();
    expect(got?.label).toBe('🎯 → A2');
    expect(got?.cls).toBe('badge-promotion');
  });

  it('returns promotion badge without arrow when target_level is missing', () => {
    const got = gatingBadge({ is_promotion: true });
    expect(got?.label).toBe('🎯 Promotion');
    expect(got?.cls).toBe('badge-promotion');
  });

  it('returns placement badge for is_placement', () => {
    const got = gatingBadge({ is_placement: true });
    expect(got?.label).toBe('📍 Placement');
    expect(got?.cls).toBe('badge-placement');
  });

  it('promotion takes precedence when both flags are set (defensive — DB constraint forbids)', () => {
    const got = gatingBadge({ is_promotion: true, is_placement: true, target_level: 'b1' });
    expect(got?.cls).toBe('badge-promotion');
    expect(got?.label).toBe('🎯 → B1');
  });
});

describe('findPromotionConflict (D3 inline warning)', () => {
  const sampleA2: MockTestRow = {
    id: 'mt-a2-existing',
    title: 'Đề pilot A2 cũ',
    status: 'published',
    is_promotion: true,
    target_level: 'a2',
  };
  const sampleB1: MockTestRow = {
    id: 'mt-b1-existing',
    title: 'Đề pilot B1',
    status: 'published',
    is_promotion: true,
    target_level: 'b1',
  };
  const sampleNormal: MockTestRow = {
    id: 'mt-normal',
    title: 'Đề luyện',
    status: 'published',
    is_promotion: false,
    target_level: 'a2',
  };

  it('returns null when form is not promotion', () => {
    expect(findPromotionConflict(
      [sampleA2],
      { is_promotion: false, status: 'published', target_level: 'a2' },
      '',
    )).toBeNull();
  });

  it('returns null when form is draft (only published triggers the guard)', () => {
    expect(findPromotionConflict(
      [sampleA2],
      { is_promotion: true, status: 'draft', target_level: 'a2' },
      '',
    )).toBeNull();
  });

  it('returns null when target_level is empty', () => {
    expect(findPromotionConflict(
      [sampleA2],
      { is_promotion: true, status: 'published', target_level: '' },
      '',
    )).toBeNull();
  });

  it('returns the conflicting row when one published promotion already exists at the level', () => {
    const got = findPromotionConflict(
      [sampleA2, sampleB1],
      { is_promotion: true, status: 'published', target_level: 'a2' },
      '',
    );
    expect(got).not.toBeNull();
    expect(got?.id).toBe('mt-a2-existing');
  });

  it('excludes the row currently being edited (editingId match)', () => {
    expect(findPromotionConflict(
      [sampleA2],
      { is_promotion: true, status: 'published', target_level: 'a2' },
      'mt-a2-existing',
    )).toBeNull();
  });

  it('ignores non-promotion rows even when level matches', () => {
    expect(findPromotionConflict(
      [sampleNormal],
      { is_promotion: true, status: 'published', target_level: 'a2' },
      '',
    )).toBeNull();
  });

  it('ignores draft rows even when level + promotion match', () => {
    const draft: MockTestRow = { ...sampleA2, id: 'mt-draft', status: 'draft' };
    expect(findPromotionConflict(
      [draft],
      { is_promotion: true, status: 'published', target_level: 'a2' },
      '',
    )).toBeNull();
  });
});
