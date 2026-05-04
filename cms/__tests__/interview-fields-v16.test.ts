import { describe, it, expect } from 'vitest';
import {
  buildInterviewConversationPayload,
  buildInterviewChoiceExplainPayload,
  clampAudioBufferTimeoutMs,
  formStateFromInterviewConversation,
  formStateFromInterviewChoiceExplain,
} from '../components/exercise-utils';

describe('clampAudioBufferTimeoutMs (V16)', () => {
  it('snaps undefined to default 1500', () => {
    expect(clampAudioBufferTimeoutMs(undefined)).toBe(1500);
  });

  it('snaps 0 / negatives to default 1500', () => {
    expect(clampAudioBufferTimeoutMs(0)).toBe(1500);
    expect(clampAudioBufferTimeoutMs(-100)).toBe(1500);
  });

  it('clamps below minimum to 500', () => {
    expect(clampAudioBufferTimeoutMs(100)).toBe(500);
    expect(clampAudioBufferTimeoutMs(499)).toBe(500);
  });

  it('clamps above maximum to 5000', () => {
    expect(clampAudioBufferTimeoutMs(9999)).toBe(5000);
    expect(clampAudioBufferTimeoutMs(5001)).toBe(5000);
  });

  it('passes through valid values', () => {
    expect(clampAudioBufferTimeoutMs(500)).toBe(500);
    expect(clampAudioBufferTimeoutMs(1500)).toBe(1500);
    expect(clampAudioBufferTimeoutMs(5000)).toBe(5000);
  });

  it('coerces numeric strings (input event values)', () => {
    expect(clampAudioBufferTimeoutMs('2000')).toBe(2000);
    expect(clampAudioBufferTimeoutMs('not-a-number')).toBe(1500);
  });

  it('rounds fractional values', () => {
    expect(clampAudioBufferTimeoutMs(1500.7)).toBe(1501);
  });
});

describe('buildInterviewConversationPayload (V16)', () => {
  it('writes audio_buffer_timeout_ms with form value', () => {
    const payload = buildInterviewConversationPayload({
      topic: 'Gia đình',
      tips: [],
      systemPrompt: 'You are an examiner.',
      maxTurns: 8,
      showTranscript: true,
      audioBufferTimeoutMs: 2500,
    });
    expect(payload.audio_buffer_timeout_ms).toBe(2500);
  });

  it('falls back to default 1500 when audioBufferTimeoutMs is omitted', () => {
    const payload = buildInterviewConversationPayload({
      topic: 'x',
      tips: [],
      systemPrompt: 'y',
      maxTurns: 8,
      showTranscript: true,
    });
    expect(payload.audio_buffer_timeout_ms).toBe(1500);
  });

  it('clamps out-of-range values', () => {
    const low = buildInterviewConversationPayload({
      topic: 'x', tips: [], systemPrompt: 'y',
      maxTurns: 8, showTranscript: true, audioBufferTimeoutMs: 100,
    });
    expect(low.audio_buffer_timeout_ms).toBe(500);

    const high = buildInterviewConversationPayload({
      topic: 'x', tips: [], systemPrompt: 'y',
      maxTurns: 8, showTranscript: true, audioBufferTimeoutMs: 9999,
    });
    expect(high.audio_buffer_timeout_ms).toBe(5000);
  });
});

describe('buildInterviewChoiceExplainPayload (V16)', () => {
  it('writes audio_buffer_timeout_ms with form value', () => {
    const payload = buildInterviewChoiceExplainPayload({
      question: 'Pick one',
      options: [
        { id: '1', label: 'A', imageAssetId: '' },
        { id: '2', label: 'B', imageAssetId: '' },
        { id: '3', label: 'C', imageAssetId: '' },
      ],
      systemPrompt: 'Examiner.',
      maxTurns: 6,
      showTranscript: false,
      audioBufferTimeoutMs: 800,
    });
    expect(payload.audio_buffer_timeout_ms).toBe(800);
  });
});

describe('formStateFromInterviewConversation (V16)', () => {
  it('reads audio_buffer_timeout_ms from detail', () => {
    const s = formStateFromInterviewConversation({
      system_prompt: 'x',
      audio_buffer_timeout_ms: 2200,
    });
    expect(s.audioBufferTimeoutMs).toBe(2200);
  });

  it('defaults to 1500 when missing', () => {
    const s = formStateFromInterviewConversation({ system_prompt: 'x' });
    expect(s.audioBufferTimeoutMs).toBe(1500);
  });
});

describe('formStateFromInterviewChoiceExplain (V16)', () => {
  it('reads + clamps audio_buffer_timeout_ms', () => {
    const s = formStateFromInterviewChoiceExplain({
      system_prompt: 'x',
      audio_buffer_timeout_ms: 100,
    });
    expect(s.audioBufferTimeoutMs).toBe(500);
  });
});
