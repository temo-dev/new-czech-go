import { describe, it, expect } from 'vitest';
import {
  validateAiPrompt,
  mapApiResult,
  nextStateOnToggle,
  canToggle,
  canGenerate,
  AI_IMAGE_PROMPT_MIN,
  AI_IMAGE_PROMPT_MAX,
} from '../components/ai-image-utils';

describe('validateAiPrompt', () => {
  it('rejects prompt shorter than minimum', () => {
    expect(validateAiPrompt('ab')).not.toBeNull();
    expect(validateAiPrompt('')).not.toBeNull();
  });

  it('rejects prompt longer than maximum', () => {
    expect(validateAiPrompt('a'.repeat(AI_IMAGE_PROMPT_MAX + 1))).not.toBeNull();
  });

  it('accepts prompt at minimum length', () => {
    expect(validateAiPrompt('a'.repeat(AI_IMAGE_PROMPT_MIN))).toBeNull();
  });

  it('accepts prompt at maximum length', () => {
    expect(validateAiPrompt('a'.repeat(AI_IMAGE_PROMPT_MAX))).toBeNull();
  });

  it('trims whitespace before validation', () => {
    // "  ab  " trims to "ab" which is 2 chars — below min
    expect(validateAiPrompt('  ab  ')).not.toBeNull();
    // "  abc  " trims to "abc" — at min
    expect(validateAiPrompt('  abc  ')).toBeNull();
  });
});

describe('mapApiResult', () => {
  it('maps snake_case API fields to camelCase', () => {
    const result = mapApiResult({
      asset_id: 'asset-123',
      storage_key: 'ai-generated/asset-123.jpg',
      preview_url: 'https://replicate.delivery/img.jpg',
    });
    expect(result).toEqual({
      assetId: 'asset-123',
      storageKey: 'ai-generated/asset-123.jpg',
      previewUrl: 'https://replicate.delivery/img.jpg',
    });
  });
});

describe('nextStateOnToggle', () => {
  it('idle → open', () => {
    expect(nextStateOnToggle('idle')).toBe('open');
  });

  it('open → idle (cancel)', () => {
    expect(nextStateOnToggle('open')).toBe('idle');
  });

  it('error → idle (cancel)', () => {
    expect(nextStateOnToggle('error')).toBe('idle');
  });

  it('generating stays generating (no toggle during load)', () => {
    expect(nextStateOnToggle('generating')).toBe('generating');
  });

  it('preview stays preview (no toggle during preview)', () => {
    expect(nextStateOnToggle('preview')).toBe('preview');
  });
});

describe('canToggle', () => {
  it('allows toggle from idle, open, error', () => {
    expect(canToggle('idle')).toBe(true);
    expect(canToggle('open')).toBe(true);
    expect(canToggle('error')).toBe(true);
  });

  it('blocks toggle during generating, preview, uploading', () => {
    expect(canToggle('generating')).toBe(false);
    expect(canToggle('preview')).toBe(false);
    expect(canToggle('uploading')).toBe(false);
  });
});

describe('canGenerate', () => {
  it('allows generation when open and prompt valid', () => {
    expect(canGenerate('open', 'a café in Prague')).toBe(true);
  });

  it('blocks generation when prompt empty', () => {
    expect(canGenerate('open', '')).toBe(false);
    expect(canGenerate('open', '  ')).toBe(false);
  });

  it('blocks generation when prompt too short', () => {
    expect(canGenerate('open', 'ab')).toBe(false);
  });

  it('blocks generation from non-open states', () => {
    expect(canGenerate('idle', 'valid prompt here')).toBe(false);
    expect(canGenerate('generating', 'valid prompt here')).toBe(false);
    expect(canGenerate('preview', 'valid prompt here')).toBe(false);
  });
});
