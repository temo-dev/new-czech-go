import { describe, it, expect } from 'vitest';
import {
  CEFR_LEVELS,
  DEFAULT_COURSE_LEVEL,
  cefrLevelRank,
  nextCefrLevel,
  canRaiseLevel,
  isCefrLevel,
  labelForLevel,
  isLowestLevel,
  sanitizeLevel,
} from '../lib/level';

describe('CEFR level utilities', () => {
  it('exposes the four CEFR levels in ascending order', () => {
    expect(CEFR_LEVELS).toEqual(['a0', 'a1', 'a2', 'b1']);
  });

  it('defaults course level to a2 — current product scope', () => {
    expect(DEFAULT_COURSE_LEVEL).toBe('a2');
  });

  it('sanitizeLevel returns input when valid, default otherwise', () => {
    expect(sanitizeLevel('a1')).toBe('a1');
    expect(sanitizeLevel('b1')).toBe('b1');
    expect(sanitizeLevel('')).toBe(DEFAULT_COURSE_LEVEL);
    expect(sanitizeLevel(null)).toBe(DEFAULT_COURSE_LEVEL);
    expect(sanitizeLevel('c1')).toBe(DEFAULT_COURSE_LEVEL);
  });

  it('isCefrLevel narrows to known values only', () => {
    expect(isCefrLevel('a0')).toBe(true);
    expect(isCefrLevel('A2')).toBe(false); // case-sensitive
    expect(isCefrLevel('')).toBe(false);
    expect(isCefrLevel(undefined)).toBe(false);
  });

  it('labelForLevel returns the Vietnamese label, falling back to uppercased code', () => {
    expect(labelForLevel('a2')).toContain('Trvalý pobyt');
    expect(labelForLevel('b1')).toContain('Občanství');
    // Unknown but non-empty strings: uppercased so admins still see a hint.
    expect(labelForLevel('c1')).toBe('C1');
    // Empty / unknown: falls back to default level's label.
    expect(labelForLevel(undefined)).toContain('Trvalý pobyt');
  });

  it('isLowestLevel only flags a0', () => {
    expect(isLowestLevel('a0')).toBe(true);
    expect(isLowestLevel('a1')).toBe(false);
    expect(isLowestLevel('a2')).toBe(false);
    expect(isLowestLevel('b1')).toBe(false);
  });

  it('ranks levels in progression order', () => {
    expect(cefrLevelRank('a0')).toBe(0);
    expect(cefrLevelRank('a1')).toBe(1);
    expect(cefrLevelRank('a2')).toBe(2);
    expect(cefrLevelRank('b1')).toBe(3);
    expect(cefrLevelRank('unknown')).toBe(0);
  });

  it('returns the next manual promotion target', () => {
    expect(nextCefrLevel('a0')).toBe('a1');
    expect(nextCefrLevel('a1')).toBe('a2');
    expect(nextCefrLevel('a2')).toBe('b1');
    expect(nextCefrLevel('b1')).toBeNull();
  });

  it('allows manual level changes only upward or idempotently', () => {
    expect(canRaiseLevel('a0', 'a1')).toBe(true);
    expect(canRaiseLevel('a1', 'a1')).toBe(true);
    expect(canRaiseLevel('a2', 'a1')).toBe(false);
    expect(canRaiseLevel('a0', 'c1')).toBe(false);
  });
});
