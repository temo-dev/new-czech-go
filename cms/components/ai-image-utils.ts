export const AI_IMAGE_PROMPT_MIN = 3;
export const AI_IMAGE_PROMPT_MAX = 500;

export function validateAiPrompt(prompt: string): string | null {
  const p = prompt.trim();
  if (p.length < AI_IMAGE_PROMPT_MIN) return `Prompt phải có ít nhất ${AI_IMAGE_PROMPT_MIN} ký tự.`;
  if (p.length > AI_IMAGE_PROMPT_MAX) return `Prompt tối đa ${AI_IMAGE_PROMPT_MAX} ký tự.`;
  return null;
}

export interface AiImageApiResult {
  asset_id: string;
  storage_key: string;
  preview_url: string;
}

export interface AiImageResult {
  assetId: string;
  storageKey: string;
  previewUrl: string;
}

export function mapApiResult(data: AiImageApiResult): AiImageResult {
  return {
    assetId: data.asset_id,
    storageKey: data.storage_key,
    previewUrl: data.preview_url,
  };
}

export type AiImageState = 'idle' | 'open' | 'generating' | 'preview' | 'uploading' | 'error';

export function nextStateOnToggle(current: AiImageState): AiImageState {
  if (current === 'idle') return 'open';
  if (current === 'open' || current === 'error') return 'idle';
  return current; // generating/preview/uploading — don't toggle
}

export function canToggle(state: AiImageState): boolean {
  return state === 'idle' || state === 'open' || state === 'error';
}

export function canGenerate(state: AiImageState, prompt: string): boolean {
  return state === 'open' && validateAiPrompt(prompt) === null;
}
