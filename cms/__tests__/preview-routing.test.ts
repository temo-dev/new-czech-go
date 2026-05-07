import { describe, it, expect } from 'vitest';
import { selectPreviewRenderer } from '../components/exercise-preview/router';

// V23 Phase C7 — preview routing helper. Top 5 type render real
// preview cards; everything else falls back to a placeholder so the
// admin still sees the form / preview layout for unsupported types
// without a runtime crash.

describe('selectPreviewRenderer', () => {
  it('returns "uloha" for the four speaking exercise types', () => {
    expect(selectPreviewRenderer('uloha_1_topic_answers')).toBe('uloha');
    expect(selectPreviewRenderer('uloha_2_dialogue_questions')).toBe('uloha');
    expect(selectPreviewRenderer('uloha_3_story_narration')).toBe('uloha');
    expect(selectPreviewRenderer('uloha_4_choice_reasoning')).toBe('uloha');
  });

  it('returns "psani-email" for psani_2_email', () => {
    expect(selectPreviewRenderer('psani_2_email')).toBe('psani-email');
  });

  it('returns "placeholder" for cteni_*', () => {
    expect(selectPreviewRenderer('cteni_1')).toBe('placeholder');
    expect(selectPreviewRenderer('cteni_5')).toBe('placeholder');
  });

  it('returns "placeholder" for poslech_*', () => {
    expect(selectPreviewRenderer('poslech_1')).toBe('placeholder');
    expect(selectPreviewRenderer('poslech_4')).toBe('placeholder');
  });

  it('returns "placeholder" for other writing types', () => {
    expect(selectPreviewRenderer('psani_1_formular')).toBe('placeholder');
    expect(selectPreviewRenderer('psani_3_dictation')).toBe('placeholder');
  });

  it('returns "placeholder" for unknown / empty type', () => {
    expect(selectPreviewRenderer('')).toBe('placeholder');
    expect(selectPreviewRenderer('totally_made_up')).toBe('placeholder');
  });
});
