import { describe, it, expect } from 'vitest';
import { audioRegenSupported } from '../components/exercise-quick-fix-modal';

// V23 Phase H6 — quick-fix modal helper. The modal renders a "Tạo lại
// audio" button only when audio regen is meaningful for the exercise:
// listening (nghe) exercises, plus the dictation type (psani_3_dictation)
// which generates per-sentence audio. Other skills don't have an audio
// pipeline so the button stays hidden.

describe('audioRegenSupported', () => {
  it('returns true for any nghe (listening) exercise', () => {
    expect(audioRegenSupported('nghe', 'poslech_1')).toBe(true);
    expect(audioRegenSupported('nghe', 'poslech_4')).toBe(true);
    expect(audioRegenSupported('nghe', 'poslech_6')).toBe(true);
  });

  it('returns true for psani_3_dictation regardless of skill_kind', () => {
    expect(audioRegenSupported('viet', 'psani_3_dictation')).toBe(true);
    expect(audioRegenSupported('', 'psani_3_dictation')).toBe(true);
  });

  it('returns false for writing exercises that are not dictation', () => {
    expect(audioRegenSupported('viet', 'psani_1_formular')).toBe(false);
    expect(audioRegenSupported('viet', 'psani_2_email')).toBe(false);
  });

  it('returns false for skills without an audio pipeline', () => {
    expect(audioRegenSupported('noi', 'uloha_1_topic_answers')).toBe(false);
    expect(audioRegenSupported('doc', 'cteni_1')).toBe(false);
    expect(audioRegenSupported('tu_vung', 'quizcard_basic')).toBe(false);
    expect(audioRegenSupported('', '')).toBe(false);
  });
});
