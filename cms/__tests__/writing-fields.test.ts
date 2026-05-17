import { describe, expect, it } from 'vitest';
import React from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { splitWritingRepeaterRows, WritingFields } from '../components/exercise-form/WritingFields';

(globalThis as unknown as { React: typeof React }).React = React;

describe('splitWritingRepeaterRows', () => {
  it('keeps the empty row created by the add button', () => {
    expect(splitWritingRepeaterRows('KDE JSTE?\n')).toEqual(['KDE JSTE?', '']);
  });

  it('keeps multiple empty draft rows while editing', () => {
    expect(splitWritingRepeaterRows('\n')).toEqual(['', '']);
  });
});

describe('WritingFields', () => {
  it('keeps the add button visible for Psaní 1 after three form questions', () => {
    const html = renderToStaticMarkup(
      React.createElement(WritingFields, {
        form: {
          exerciseType: 'psani_1_formular',
          formularQuestions: 'Otázka 1?\nOtázka 2?\nOtázka 3?',
          formularMinWords: 10,
          emailPrompt: '',
          emailTopics: '',
          emailMinWords: 35,
          imageAssetIds: '',
        },
        setForm: () => undefined,
      }),
    );

    expect(html).toContain('+ Thêm');
    expect(html).not.toContain('(3/3)');
  });
});
