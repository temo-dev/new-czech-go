import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

const sourceFor = (relativePath: string) => readFileSync(
  new URL(relativePath, import.meta.url),
  'utf8',
);

describe('AiDraftPanel markup', () => {
  it('does not render its own form inside the exercise editor form', () => {
    const source = sourceFor('../components/ai-draft/AiDraftPanel.tsx');

    expect(source).not.toContain('<form');
    expect(source).toContain('onClick={() => handleSubmit()}');
  });

  it('does not rely on Tailwind class names in the non-Tailwind CMS app', () => {
    for (const file of [
      '../components/ai-draft/AiDraftPanel.tsx',
      '../components/ai-draft/GrammarPointPicker.tsx',
      '../components/ai-draft/LevelRadio.tsx',
    ]) {
      expect(sourceFor(file), file).not.toContain('className=');
    }
  });

  it('lets the grammar picker commit the first search result with Enter', () => {
    const source = sourceFor('../components/ai-draft/GrammarPointPicker.tsx');

    expect(source).toContain("e.key !== 'Enter'");
    expect(source).toContain('if (first) add(first.id);');
    expect(source).toContain('Chỉ nhập chữ chưa được tính là đã chọn.');
  });
});
