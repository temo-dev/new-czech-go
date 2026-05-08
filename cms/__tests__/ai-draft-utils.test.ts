import { describe, it, expect } from 'vitest';
import {
  validateDraftInput,
  canSubmit,
  mapServerError,
  reduceDraftState,
  toGenerateDraftRequest,
  DRAFT_LIMITS,
  type DraftFormInput,
  type DraftState,
} from '../lib/ai-draft-utils';

const validInput = (overrides: Partial<DraftFormInput> = {}): DraftFormInput => ({
  exerciseType: 'cteni_2',
  topic: 'đi khám bác sĩ',
  grammarPointIds: ['grammar-1'],
  level: 'A2',
  extraInstructions: '',
  ...overrides,
});

// ── validateDraftInput ───────────────────────────────────────────────────────

describe('validateDraftInput', () => {
  it('accepts a fully populated valid input', () => {
    expect(validateDraftInput(validInput())).toEqual({ ok: true });
  });

  it('rejects empty topic', () => {
    const result = validateDraftInput(validInput({ topic: '  ' }));
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.field).toBe('topic');
  });

  it('rejects topic over max length', () => {
    const result = validateDraftInput(validInput({ topic: 'a'.repeat(DRAFT_LIMITS.topicMax + 1) }));
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.field).toBe('topic');
  });

  it('rejects empty grammar point list', () => {
    const result = validateDraftInput(validInput({ grammarPointIds: [] }));
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.field).toBe('grammarPointIds');
  });

  it('rejects more than max grammar points', () => {
    const result = validateDraftInput(validInput({ grammarPointIds: ['a', 'b', 'c', 'd'] }));
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.field).toBe('grammarPointIds');
  });

  it('ignores blank ids when counting grammar points', () => {
    const result = validateDraftInput(validInput({ grammarPointIds: ['', '  '] }));
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.field).toBe('grammarPointIds');
  });

  it('rejects missing level', () => {
    const result = validateDraftInput(validInput({ level: '' }));
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.field).toBe('level');
  });

  it('rejects extra instructions over max length', () => {
    const result = validateDraftInput(validInput({ extraInstructions: 'a'.repeat(DRAFT_LIMITS.extraMax + 1) }));
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.field).toBe('extraInstructions');
  });
});

describe('canSubmit', () => {
  it('mirrors validateDraftInput', () => {
    expect(canSubmit(validInput())).toBe(true);
    expect(canSubmit(validInput({ topic: '' }))).toBe(false);
  });
});

// ── mapServerError ───────────────────────────────────────────────────────────

describe('mapServerError', () => {
  it.each([
    ['invalid_request', 'Dữ liệu không hợp lệ. Kiểm tra lại các trường.'],
    ['grammar_point_not_found', 'Điểm ngữ pháp đã chọn không tồn tại. Tải lại trang.'],
    ['rate_limited', 'Quá nhiều lần sinh trong 1 phút. Đợi một chút rồi thử lại.'],
    ['schema_mismatch', 'AI trả output không đúng định dạng. Bấm Tạo lại.'],
    ['llm_error', 'Không kết nối được AI. Thử lại sau.'],
    ['timeout', 'Sinh nháp quá lâu (>30s). Thử lại.'],
    ['not_configured', 'Tính năng AI chưa được cấu hình trên server.'],
  ])('maps %s', (code, expected) => {
    expect(mapServerError(code)).toBe(expected);
  });

  it('falls back when code unknown', () => {
    expect(mapServerError('???')).toBe('Có lỗi không xác định. Thử lại.');
  });

  it('uses fallback for invalid_request when message is server-supplied', () => {
    expect(mapServerError('invalid_request', 'topic must be 3-200 characters.')).toBe(
      'topic must be 3-200 characters.',
    );
  });
});

// ── reduceDraftState ─────────────────────────────────────────────────────────

describe('reduceDraftState', () => {
  it('idle + submit → loading when form is clean', () => {
    const next = reduceDraftState({ status: 'idle' }, { type: 'submit', input: validInput(), formDirty: false });
    expect(next.status).toBe('loading');
  });

  it('idle + submit → loading even if dirty (first generation never confirms)', () => {
    const next = reduceDraftState({ status: 'idle' }, { type: 'submit', input: validInput(), formDirty: true });
    expect(next.status).toBe('loading');
  });

  it('success + submit (clean form) → loading', () => {
    const success: DraftState = { status: 'success', appliedAt: 0, lastInput: validInput() };
    const next = reduceDraftState(success, { type: 'submit', input: validInput(), formDirty: false });
    expect(next.status).toBe('loading');
  });

  it('success + submit (dirty form) → confirm-overwrite', () => {
    const success: DraftState = { status: 'success', appliedAt: 0, lastInput: validInput() };
    const next = reduceDraftState(success, { type: 'submit', input: validInput(), formDirty: true });
    expect(next.status).toBe('confirm-overwrite');
  });

  it('confirm-overwrite + confirm-overwrite event → loading', () => {
    const state: DraftState = { status: 'confirm-overwrite', pendingInput: validInput() };
    const next = reduceDraftState(state, { type: 'confirm-overwrite' });
    expect(next.status).toBe('loading');
  });

  it('confirm-overwrite + dismiss-overwrite → success (preserve previous fill)', () => {
    const state: DraftState = { status: 'confirm-overwrite', pendingInput: validInput() };
    const next = reduceDraftState(state, { type: 'dismiss-overwrite' });
    expect(next.status).toBe('success');
  });

  it('loading + response-ok → success', () => {
    const next = reduceDraftState({ status: 'loading' }, { type: 'response-ok', input: validInput() });
    expect(next.status).toBe('success');
  });

  it('loading + response-error → error with message', () => {
    const next = reduceDraftState({ status: 'loading' }, { type: 'response-error', message: 'X' });
    expect(next.status).toBe('error');
    if (next.status === 'error') expect(next.message).toBe('X');
  });

  it('loading + cancel → idle', () => {
    const next = reduceDraftState({ status: 'loading' }, { type: 'cancel' });
    expect(next.status).toBe('idle');
  });

  it('error + cancel → idle (admin can collapse panel)', () => {
    const next = reduceDraftState({ status: 'error', message: 'X' }, { type: 'cancel' });
    expect(next.status).toBe('idle');
  });

  it('confirm event ignored when not in confirm-overwrite state', () => {
    const state: DraftState = { status: 'idle' };
    const next = reduceDraftState(state, { type: 'confirm-overwrite' });
    expect(next).toBe(state);
  });
});

// ── toGenerateDraftRequest ───────────────────────────────────────────────────

describe('toGenerateDraftRequest', () => {
  it('serialises all fields including trimmed extra_instructions', () => {
    const req = toGenerateDraftRequest(validInput({ extraInstructions: '  tone neutral  ' }));
    expect(req).toEqual({
      exercise_type: 'cteni_2',
      topic: 'đi khám bác sĩ',
      grammar_point_ids: ['grammar-1'],
      level: 'A2',
      extra_instructions: 'tone neutral',
    });
  });

  it('omits extra_instructions when empty', () => {
    const req = toGenerateDraftRequest(validInput({ extraInstructions: '   ' }));
    expect(req.extra_instructions).toBeUndefined();
  });

  it('drops blank grammar_point_ids', () => {
    const req = toGenerateDraftRequest(validInput({ grammarPointIds: ['', 'g1', '  '] }));
    expect(req.grammar_point_ids).toEqual(['g1']);
  });

  it('throws when level missing', () => {
    expect(() => toGenerateDraftRequest(validInput({ level: '' }))).toThrow();
  });
});
