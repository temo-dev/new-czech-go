/**
 * V24 reading-draft generator — pure helpers.
 *
 * Components in components/ai-draft delegate validation, error mapping, and
 * state-machine transitions to this module so the logic stays unit-testable
 * under vitest's `node` environment (no JSDOM).
 */

export type CteniDraftType = 'cteni_1' | 'cteni_2' | 'cteni_3' | 'cteni_4' | 'cteni_5' | 'cteni_6';
export type DraftLevel = 'A0' | 'A1' | 'A2' | 'B1';

export const DRAFT_LEVELS: DraftLevel[] = ['A0', 'A1', 'A2', 'B1'];

export const DRAFT_LIMITS = {
  topicMin: 3,
  topicMax: 200,
  extraMax: 500,
  grammarMin: 1,
  grammarMax: 3,
} as const;

// ── Input validation ─────────────────────────────────────────────────────────

export type DraftFormInput = {
  exerciseType: CteniDraftType;
  topic: string;
  grammarPointIds: string[];
  level: DraftLevel | '';
  extraInstructions: string;
};

export type ValidationResult = { ok: true } | { ok: false; field: keyof DraftFormInput; message: string };

export function validateDraftInput(input: DraftFormInput): ValidationResult {
  const topic = input.topic.trim();
  if (topic.length < DRAFT_LIMITS.topicMin) {
    return { ok: false, field: 'topic', message: `Chủ đề phải có ít nhất ${DRAFT_LIMITS.topicMin} ký tự.` };
  }
  if (topic.length > DRAFT_LIMITS.topicMax) {
    return { ok: false, field: 'topic', message: `Chủ đề tối đa ${DRAFT_LIMITS.topicMax} ký tự.` };
  }
  const ids = input.grammarPointIds.filter((s) => s.trim().length > 0);
  if (ids.length < DRAFT_LIMITS.grammarMin) {
    return { ok: false, field: 'grammarPointIds', message: 'Chọn ít nhất 1 điểm ngữ pháp.' };
  }
  if (ids.length > DRAFT_LIMITS.grammarMax) {
    return { ok: false, field: 'grammarPointIds', message: `Tối đa ${DRAFT_LIMITS.grammarMax} điểm ngữ pháp.` };
  }
  if (!input.level) {
    return { ok: false, field: 'level', message: 'Chọn cấp độ.' };
  }
  if (input.extraInstructions.length > DRAFT_LIMITS.extraMax) {
    return {
      ok: false,
      field: 'extraInstructions',
      message: `Hướng dẫn thêm tối đa ${DRAFT_LIMITS.extraMax} ký tự.`,
    };
  }
  return { ok: true };
}

// canSubmit returns true when validateDraftInput would pass. Used to enable
// the "Sinh nháp" button without surfacing the error message until submit.
export function canSubmit(input: DraftFormInput): boolean {
  return validateDraftInput(input).ok;
}

// ── Server-error → user-message mapping ──────────────────────────────────────

export type ServerErrorCode =
  | 'invalid_request'
  | 'grammar_point_not_found'
  | 'rate_limited'
  | 'schema_mismatch'
  | 'llm_error'
  | 'timeout'
  | 'not_configured'
  | 'forbidden'
  | 'unauthorized'
  | 'unknown';

export function mapServerError(code: string | undefined, fallback?: string): string {
  switch (code as ServerErrorCode) {
    case 'invalid_request':
      return fallback ?? 'Dữ liệu không hợp lệ. Kiểm tra lại các trường.';
    case 'grammar_point_not_found':
      return 'Điểm ngữ pháp đã chọn không tồn tại. Tải lại trang.';
    case 'rate_limited':
      return 'Quá nhiều lần sinh trong 1 phút. Đợi một chút rồi thử lại.';
    case 'schema_mismatch':
      return 'AI trả output không đúng định dạng. Bấm Tạo lại.';
    case 'llm_error':
      return 'Không kết nối được AI. Thử lại sau.';
    case 'timeout':
      return 'Sinh nháp quá lâu (>30s). Thử lại.';
    case 'not_configured':
      return 'Tính năng AI chưa được cấu hình trên server.';
    case 'forbidden':
      return 'Bạn không có quyền sử dụng tính năng này.';
    case 'unauthorized':
      return 'Phiên đăng nhập hết hạn. Đăng nhập lại.';
    default:
      return fallback ?? 'Có lỗi không xác định. Thử lại.';
  }
}

// ── Panel state machine ──────────────────────────────────────────────────────

export type DraftState =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'success'; appliedAt: number; lastInput: DraftFormInput }
  | { status: 'error'; message: string }
  | { status: 'confirm-overwrite'; pendingInput: DraftFormInput };

export type DraftEvent =
  | { type: 'submit'; input: DraftFormInput; formDirty: boolean }
  | { type: 'response-ok'; input: DraftFormInput }
  | { type: 'response-error'; message: string }
  | { type: 'cancel' }
  | { type: 'confirm-overwrite' }
  | { type: 'dismiss-overwrite' };

export function reduceDraftState(state: DraftState, event: DraftEvent): DraftState {
  switch (event.type) {
    case 'submit':
      // First-time generation (form clean) — go straight to loading.
      // Regenerate over a dirty form — confirm before overwriting fields.
      if (state.status === 'success' && event.formDirty) {
        return { status: 'confirm-overwrite', pendingInput: event.input };
      }
      return { status: 'loading' };
    case 'response-ok':
      return { status: 'success', appliedAt: Date.now(), lastInput: event.input };
    case 'response-error':
      return { status: 'error', message: event.message };
    case 'cancel':
      return { status: 'idle' };
    case 'confirm-overwrite':
      if (state.status !== 'confirm-overwrite') return state;
      return { status: 'loading' };
    case 'dismiss-overwrite':
      if (state.status !== 'confirm-overwrite') return state;
      return { status: 'success', appliedAt: Date.now(), lastInput: state.pendingInput };
    default:
      return state;
  }
}

// ── Request payload mapper ───────────────────────────────────────────────────

export type GenerateDraftRequest = {
  exercise_type: CteniDraftType;
  topic: string;
  grammar_point_ids: string[];
  level: DraftLevel;
  extra_instructions?: string;
};

export function toGenerateDraftRequest(input: DraftFormInput): GenerateDraftRequest {
  if (!input.level) {
    throw new Error('toGenerateDraftRequest: level required');
  }
  const req: GenerateDraftRequest = {
    exercise_type: input.exerciseType,
    topic: input.topic.trim(),
    grammar_point_ids: input.grammarPointIds.map((s) => s.trim()).filter((s) => s.length > 0),
    level: input.level,
  };
  const extra = input.extraInstructions.trim();
  if (extra) req.extra_instructions = extra;
  return req;
}
