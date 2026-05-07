import { describe, it, expect } from 'vitest';
import {
  emptyMockTestFlags,
  togglePromotion,
  togglePlacement,
  setTargetLevel,
  validateMockTestFlags,
  mockTestFlagsPayload,
} from '../lib/mockTestFlags';

describe('togglePromotion', () => {
  it('turning promotion ON clears placement (mutex)', () => {
    const start = { ...emptyMockTestFlags(), is_placement: true };
    const next = togglePromotion(start, true);
    expect(next.is_promotion).toBe(true);
    expect(next.is_placement).toBe(false);
  });

  it('turning promotion OFF clears target_level so a re-toggle does not inherit stale state', () => {
    const start = { is_promotion: true, is_placement: false, target_level: 'b1' as const };
    const next = togglePromotion(start, false);
    expect(next.is_promotion).toBe(false);
    expect(next.target_level).toBe('');
  });

  it('keeps the typed target_level when promotion is being turned ON', () => {
    const start = { ...emptyMockTestFlags(), target_level: 'a2' as const };
    const next = togglePromotion(start, true);
    expect(next.target_level).toBe('a2');
  });
});

describe('togglePlacement', () => {
  it('turning placement ON clears promotion + target_level (placement has no target)', () => {
    const start = { is_promotion: true, is_placement: false, target_level: 'b1' as const };
    const next = togglePlacement(start, true);
    expect(next.is_placement).toBe(true);
    expect(next.is_promotion).toBe(false);
    expect(next.target_level).toBe('');
  });

  it('turning placement OFF leaves the rest untouched', () => {
    const start = { is_promotion: false, is_placement: true, target_level: '' as const };
    const next = togglePlacement(start, false);
    expect(next).toEqual({ is_promotion: false, is_placement: false, target_level: '' });
  });
});

describe('setTargetLevel', () => {
  it('accepts the four CEFR levels', () => {
    const start = emptyMockTestFlags();
    expect(setTargetLevel(start, 'a0').target_level).toBe('a0');
    expect(setTargetLevel(start, 'b1').target_level).toBe('b1');
  });

  it('coerces unknown values to empty', () => {
    const start = emptyMockTestFlags();
    expect(setTargetLevel(start, 'c1').target_level).toBe('');
    expect(setTargetLevel(start, 'A2').target_level).toBe(''); // case-sensitive
  });

  it('allows clearing the field', () => {
    const start = { ...emptyMockTestFlags(), target_level: 'a2' as const };
    expect(setTargetLevel(start, '').target_level).toBe('');
  });
});

describe('validateMockTestFlags', () => {
  it('passes when both flags are off', () => {
    expect(validateMockTestFlags(emptyMockTestFlags())).toBeNull();
  });

  it('rejects mutex violation when both flags are on', () => {
    const state = { is_promotion: true, is_placement: true, target_level: 'a2' as const };
    expect(validateMockTestFlags(state)).toMatch(/promotion vừa là placement/);
  });

  it('rejects promotion without target_level', () => {
    const state = { is_promotion: true, is_placement: false, target_level: '' as const };
    expect(validateMockTestFlags(state)).toMatch(/target level/);
  });

  it('passes promotion with a valid target_level', () => {
    const state = { is_promotion: true, is_placement: false, target_level: 'b1' as const };
    expect(validateMockTestFlags(state)).toBeNull();
  });

  it('passes placement (no target needed)', () => {
    const state = { is_promotion: false, is_placement: true, target_level: '' as const };
    expect(validateMockTestFlags(state)).toBeNull();
  });
});

describe('mockTestFlagsPayload', () => {
  it('includes target_level only when valid', () => {
    expect(mockTestFlagsPayload({
      is_promotion: true, is_placement: false, target_level: 'b1',
    })).toEqual({
      is_promotion: true, is_placement: false, target_level: 'b1',
    });

    expect(mockTestFlagsPayload({
      is_promotion: false, is_placement: false, target_level: '',
    })).toEqual({
      is_promotion: false, is_placement: false,
    });
  });

  it('omits target_level when target is empty even on a promotion (server CHECK still rejects)', () => {
    const out = mockTestFlagsPayload({
      is_promotion: true, is_placement: false, target_level: '',
    });
    expect(out).toEqual({ is_promotion: true, is_placement: false });
  });
});
