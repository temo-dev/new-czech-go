import { describe, it, expect } from 'vitest';
import {
  splitTranscriptIntoSentences,
  validateDictation,
  buildDictationPayload,
  formStateFromDictation,
  emptyDictationFormState,
  type DictationFormState,
  DICTATION_MAX_SENTENCES,
} from '../components/exercise-utils';
import { validateExercise } from '../components/exercise-form/validation';

// ─── splitTranscriptIntoSentences ─────────────────────────────────────────────

describe('splitTranscriptIntoSentences', () => {
  it('splits on .!? followed by whitespace', () => {
    const got = splitTranscriptIntoSentences(
      'Pavel jde do kavárny. Chce si dát čaj a koláč. Děkuji.'
    );
    expect(got).toEqual([
      'Pavel jde do kavárny.',
      'Chce si dát čaj a koláč.',
      'Děkuji.',
    ]);
  });

  it('preserves Czech abbreviations like Mgr. and Ph.D.', () => {
    const got = splitTranscriptIntoSentences(
      'Mgr. Pavel jde domů. Dr. Lenka pracuje. Ph.D. Karel čte.'
    );
    expect(got.length).toBe(3);
    expect(got[0]).toBe('Mgr. Pavel jde domů.');
    expect(got[1]).toBe('Dr. Lenka pracuje.');
    expect(got[2]).toBe('Ph.D. Karel čte.');
  });

  it('trims whitespace and filters empty', () => {
    const got = splitTranscriptIntoSentences('  Ahoj.    Děkuji.   ');
    expect(got).toEqual(['Ahoj.', 'Děkuji.']);
  });

  it('returns empty array for blank input', () => {
    expect(splitTranscriptIntoSentences('')).toEqual([]);
    expect(splitTranscriptIntoSentences('   \n   ')).toEqual([]);
  });

  it('handles ! and ? terminators', () => {
    const got = splitTranscriptIntoSentences('Skvěle! Opravdu? Ano.');
    expect(got).toEqual(['Skvěle!', 'Opravdu?', 'Ano.']);
  });
});

// ─── validateDictation ────────────────────────────────────────────────────────

function fixtureValidForm(): DictationFormState {
  return {
    topic: 'Trong quán cafe',
    contextImageAssetId: null,
    sentences: [
      { idx: 0, text: 'Pavel jde do kavárny.', audioAssetId: 'a-0' },
      { idx: 1, text: 'Chce si dát čaj.', audioAssetId: 'a-1' },
      { idx: 2, text: 'Děkuji.', audioAssetId: 'a-2' },
    ],
    maxReplaysPerSentence: 3,
    voiceId: 'Tomas',
    maxPoints: 10,
    passThresholdPercent: 60,
    submissionMode: 'type',
  };
}

describe('validateDictation', () => {
  it('passes a fully populated form', () => {
    const r = validateDictation(fixtureValidForm());
    expect(r.ok).toBe(true);
    expect(r.errors).toEqual([]);
  });

  it('fails when topic is empty', () => {
    const f = fixtureValidForm();
    f.topic = '   ';
    const r = validateDictation(f);
    expect(r.ok).toBe(false);
    expect(r.errors.join(' ')).toMatch(/Chủ đề/);
  });

  it('fails when fewer than 3 sentences', () => {
    const f = fixtureValidForm();
    f.sentences = f.sentences.slice(0, 2);
    const r = validateDictation(f);
    expect(r.ok).toBe(false);
    expect(r.errors.join(' ')).toMatch(/ít nhất 3/);
  });

  it('fails when more than 8 sentences', () => {
    const f = fixtureValidForm();
    f.sentences = Array.from({ length: 9 }, (_, i) => ({
      idx: i, text: `Câu ${i}.`, audioAssetId: `a-${i}`,
    }));
    const r = validateDictation(f);
    expect(r.ok).toBe(false);
    expect(r.errors.join(' ')).toMatch(/Tối đa 8/);
  });

  it('fails when a sentence has no text', () => {
    const f = fixtureValidForm();
    f.sentences[1].text = '   ';
    const r = validateDictation(f);
    expect(r.ok).toBe(false);
    expect(r.errors.join(' ')).toMatch(/Câu 2/);
  });

  it('fails when a sentence has no audio (default requireAudio=true)', () => {
    const f = fixtureValidForm();
    f.sentences[2].audioAssetId = null;
    const r = validateDictation(f);
    expect(r.ok).toBe(false);
    expect(r.errors.join(' ')).toMatch(/Câu 3/);
  });

  it('skips audio check when requireAudio=false', () => {
    const f = fixtureValidForm();
    f.sentences[2].audioAssetId = null;
    const r = validateDictation(f, { requireAudio: false });
    expect(r.ok).toBe(true);
  });

  it('fails when sentence text exceeds 200 runes', () => {
    const f = fixtureValidForm();
    f.sentences[0].text = 'á'.repeat(201);
    const r = validateDictation(f);
    expect(r.ok).toBe(false);
    expect(r.errors.join(' ')).toMatch(/quá 200/);
  });

  it('fails when max_replays_per_sentence is out of range', () => {
    const f = fixtureValidForm();
    f.maxReplaysPerSentence = 11;
    const r = validateDictation(f);
    expect(r.ok).toBe(false);
    expect(r.errors.join(' ')).toMatch(/0–10/);
  });

  it('fails when pass_threshold_percent is out of range', () => {
    const f = fixtureValidForm();
    f.passThresholdPercent = 150;
    const r = validateDictation(f);
    expect(r.ok).toBe(false);
    expect(r.errors.join(' ')).toMatch(/1–100%/);
  });
});

describe('validateExercise psani_3_dictation', () => {
  it('blocks published dictation exercises when a sentence lacks audio', () => {
    const f = fixtureValidForm();
    f.sentences[1].audioAssetId = null;
    const errors = validateExercise('psani_3_dictation', {
      title: 'Viết chính tả',
      module_id: 'mod-viet',
      status: 'published',
      detail: buildDictationPayload(f),
    });

    expect(errors.join(' ')).toMatch(/Câu 2/);
    expect(errors.join(' ')).toMatch(/audio/i);
  });

  it('allows draft dictation exercises before audio is generated', () => {
    const f = fixtureValidForm();
    f.sentences[1].audioAssetId = null;
    const errors = validateExercise('psani_3_dictation', {
      title: 'Viết chính tả',
      module_id: 'mod-viet',
      status: 'draft',
      detail: buildDictationPayload(f),
    });

    expect(errors).toEqual([]);
  });
});

// ─── buildDictationPayload ────────────────────────────────────────────────────

describe('buildDictationPayload', () => {
  it('serialises a valid form into the backend shape', () => {
    const payload = buildDictationPayload(fixtureValidForm()) as Record<string, unknown>;
    expect(payload.topic).toBe('Trong quán cafe');
    expect(payload.context_image_asset_id).toBe('');
    expect(payload.max_replays_per_sentence).toBe(3);
    expect(payload.voice_id).toBe('Tomas');
    expect(payload.max_points).toBe(10);
    expect(payload.pass_threshold_percent).toBe(60);
    const sentences = payload.sentences as Array<Record<string, unknown>>;
    expect(sentences.length).toBe(3);
    expect(sentences[1]).toEqual({ idx: 1, text: 'Chce si dát čaj.', audio_asset_id: 'a-1' });
  });

  it('reindexes sentences from 0', () => {
    const f = fixtureValidForm();
    f.sentences = [
      { idx: 99, text: 'Ahoj.', audioAssetId: 'a-x' },
      { idx: 100, text: 'Děkuji.', audioAssetId: 'a-y' },
      { idx: 101, text: 'Na shledanou.', audioAssetId: 'a-z' },
    ];
    const payload = buildDictationPayload(f) as Record<string, unknown>;
    const sentences = payload.sentences as Array<Record<string, unknown>>;
    expect(sentences.map((s) => s.idx)).toEqual([0, 1, 2]);
  });

  it('emits empty-string audio_asset_id for missing audio', () => {
    const f = fixtureValidForm();
    f.sentences[0].audioAssetId = null;
    const payload = buildDictationPayload(f) as Record<string, unknown>;
    const sentences = payload.sentences as Array<Record<string, unknown>>;
    expect(sentences[0].audio_asset_id).toBe('');
  });

  it('caps sentence count via DICTATION_MAX_SENTENCES (caller validates)', () => {
    expect(DICTATION_MAX_SENTENCES).toBe(8);
  });
});

// ─── formStateFromDictation roundtrip ─────────────────────────────────────────

describe('formStateFromDictation', () => {
  it('roundtrips back into a payload-equal shape', () => {
    const original = fixtureValidForm();
    const payload = buildDictationPayload(original);
    const back = formStateFromDictation(payload);
    expect(back.topic).toBe(original.topic);
    expect(back.sentences.length).toBe(original.sentences.length);
    expect(back.sentences[1].text).toBe('Chce si dát čaj.');
    expect(back.sentences[1].audioAssetId).toBe('a-1');
    expect(back.maxReplaysPerSentence).toBe(3);
    expect(back.passThresholdPercent).toBe(60);
  });

  it('returns sane defaults for an empty detail', () => {
    const empty = emptyDictationFormState();
    expect(empty.sentences).toEqual([]);
    expect(empty.maxPoints).toBe(10);
    expect(empty.passThresholdPercent).toBe(60);
    expect(empty.maxReplaysPerSentence).toBe(3);
  });
});

// ─── V18.1 submissionMode ─────────────────────────────────────────────────────

describe('submissionMode (V18.1)', () => {
  it('defaults to "type" for empty form', () => {
    const empty = emptyDictationFormState();
    expect(empty.submissionMode).toBe('type');
  });

  it('defaults to "type" when detail JSON omits the field (V18 backward-compat)', () => {
    const v18Detail = buildDictationPayload(fixtureValidForm());
    delete (v18Detail as Record<string, unknown>).submission_mode;
    const back = formStateFromDictation(v18Detail);
    expect(back.submissionMode).toBe('type');
  });

  it('round-trips each enum value', () => {
    for (const mode of ['type', 'ocr', 'both'] as const) {
      const f = fixtureValidForm();
      f.submissionMode = mode;
      const payload = buildDictationPayload(f) as Record<string, unknown>;
      expect(payload.submission_mode).toBe(mode);
      const back = formStateFromDictation(payload);
      expect(back.submissionMode).toBe(mode);
    }
  });

  it('validateDictation accepts all 3 modes', () => {
    for (const mode of ['type', 'ocr', 'both'] as const) {
      const f = fixtureValidForm();
      f.submissionMode = mode;
      const r = validateDictation(f);
      expect(r.ok).toBe(true);
    }
  });

  it('validateDictation rejects an invalid mode value', () => {
    const f = fixtureValidForm();
    (f as { submissionMode: string }).submissionMode = 'bogus';
    const r = validateDictation(f);
    expect(r.ok).toBe(false);
    expect(r.errors.join(' ')).toMatch(/submission_mode|chế độ/i);
  });
});
