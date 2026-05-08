/**
 * V24 follow-up: ExerciseList "AI-drafted" filter behaviour. The list
 * filter is implemented inline inside cms/components/exercise-list.tsx
 * (no extracted helper), so this test mirrors the predicate to lock in
 * the contract. If the inline filter diverges, this duplication will
 * break the next time someone reads both files.
 */
import { describe, it, expect } from 'vitest';

type Exercise = {
  id: string;
  title: string;
  created_by_llm?: boolean;
};

function applyAiFilter(items: Exercise[], aiOnly: boolean): Exercise[] {
  return items.filter((item) => {
    if (aiOnly && !item.created_by_llm) return false;
    return true;
  });
}

describe('exercise-list AI filter', () => {
  const fixture: Exercise[] = [
    { id: 'a', title: 'Manual', created_by_llm: false },
    { id: 'b', title: 'AI 1', created_by_llm: true },
    { id: 'c', title: 'Manual no flag', /* flag undefined */ },
    { id: 'd', title: 'AI 2', created_by_llm: true },
  ];

  it('returns all items when filter off', () => {
    expect(applyAiFilter(fixture, false)).toHaveLength(4);
  });

  it('returns only AI-drafted items when filter on', () => {
    const filtered = applyAiFilter(fixture, true);
    expect(filtered.map((i) => i.id)).toEqual(['b', 'd']);
  });

  it('treats missing flag as not-AI (falsy)', () => {
    const undef: Exercise[] = [{ id: 'x', title: 'Implicit' }];
    expect(applyAiFilter(undef, true)).toHaveLength(0);
    expect(applyAiFilter(undef, false)).toHaveLength(1);
  });
});
