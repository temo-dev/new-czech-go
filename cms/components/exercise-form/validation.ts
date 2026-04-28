// Per-type validation for exercise form submission.
// Returns an array of human-readable error strings (empty = valid).

type ExerciseType = string;
type AnyPayload = Record<string, unknown>;

export function validateExercise(exerciseType: ExerciseType, payload: AnyPayload): string[] {
  const errors: string[] = [];

  // Common
  const title = String(payload.title ?? '').trim();
  if (!title) errors.push('Tiêu đề không được để trống.');
  const skillId = String(payload.skill_id ?? '').trim();
  if (!skillId) errors.push('Phải chọn Skill.');

  const detail = (payload.detail ?? {}) as Record<string, unknown>;

  // Poslech 1/2: need 5 items with text + correct_answers
  if (exerciseType === 'poslech_1' || exerciseType === 'poslech_2') {
    const items = (detail.items ?? []) as unknown[];
    if (items.length < 5) errors.push(`Poslech 1/2 cần đúng 5 đoạn nghe (hiện có ${items.length}).`);
    const ca = detail.correct_answers as Record<string, string> | undefined;
    if (!ca || Object.keys(ca).length < 5) errors.push('Cần nhập đáp án cho tất cả 5 câu.');
  }

  // Poslech 3: need 5 items + options A-G + answers
  if (exerciseType === 'poslech_3') {
    const items = (detail.items ?? []) as unknown[];
    const options = (detail.options ?? []) as unknown[];
    if (items.length < 5) errors.push(`Poslech 3 cần 5 đoạn nghe (hiện có ${items.length}).`);
    if (options.length < 7) errors.push(`Poslech 3 cần 7 options A-G (hiện có ${options.length}).`);
  }

  // Poslech 4: need 5 items + options A-F + answers
  if (exerciseType === 'poslech_4') {
    const items = (detail.items ?? []) as unknown[];
    const options = (detail.options ?? []) as unknown[];
    if (items.length < 5) errors.push(`Poslech 4 cần 5 đoạn (hiện có ${items.length}).`);
    if (options.length < 6) errors.push(`Poslech 4 cần 6 options A-F (hiện có ${options.length}).`);
  }

  // Poslech 5: voicemail + 5 fill slots
  if (exerciseType === 'poslech_5') {
    const ca = detail.correct_answers as Record<string, string> | undefined;
    if (!ca || Object.values(ca).every(v => !v)) errors.push('Cần nhập ít nhất 1 đáp án điền vào.');
  }

  // Cteni 1: need 5 items + 8 options + answers
  if (exerciseType === 'cteni_1') {
    const items = (detail.items ?? []) as unknown[];
    const options = (detail.options ?? []) as unknown[];
    if (items.length < 5) errors.push(`Čtení 1 cần 5 items (hiện có ${items.length}).`);
    if (options.length < 8) errors.push(`Čtení 1 cần 8 options A-H (hiện có ${options.length}).`);
  }

  // Cteni 2/4: need reading text + questions + answers
  if (exerciseType === 'cteni_2' || exerciseType === 'cteni_4') {
    const text = String(detail.text ?? '').trim();
    if (!text) errors.push('Cần nhập đoạn văn đọc.');
    const questions = (detail.questions ?? []) as unknown[];
    const minQ = exerciseType === 'cteni_4' ? 6 : 5;
    if (questions.length < minQ) errors.push(`${exerciseType.toUpperCase()} cần ${minQ} câu hỏi (hiện có ${questions.length}).`);
  }

  // Cteni 3: need 4 texts + 5 persons + answers
  if (exerciseType === 'cteni_3') {
    const texts = (detail.texts ?? []) as unknown[];
    const persons = (detail.persons ?? []) as unknown[];
    if (texts.length < 4) errors.push(`Čtení 3 cần 4 đoạn văn (hiện có ${texts.length}).`);
    if (persons.length < 5) errors.push(`Čtení 3 cần 5 nhân vật A-E (hiện có ${persons.length}).`);
  }

  // Cteni 5: need text + 5 slots
  if (exerciseType === 'cteni_5') {
    const text = String(detail.text ?? '').trim();
    if (!text) errors.push('Cần nhập đoạn văn đọc.');
    const questions = (detail.questions ?? []) as unknown[];
    if (questions.length < 5) errors.push(`Čtení 5 cần 5 câu điền vào (hiện có ${questions.length}).`);
  }

  // Psaní 1: need exactly 3 questions
  if (exerciseType === 'psani_1_formular') {
    const d = detail as Record<string, unknown>;
    const questions = (d.questions ?? []) as unknown[];
    if (questions.length !== 3) errors.push(`Psaní 1 cần đúng 3 câu hỏi (hiện có ${questions.length}).`);
  }

  // Psaní 2: need prompt + 5 topics
  if (exerciseType === 'psani_2_email') {
    const d = detail as Record<string, unknown>;
    const topics = (d.topics ?? []) as unknown[];
    if (topics.length !== 5) errors.push(`Psaní 2 cần đúng 5 chủ đề ảnh (hiện có ${topics.length}).`);
  }

  return errors;
}

export function hasValidationErrors(exerciseType: ExerciseType, payload: AnyPayload): boolean {
  return validateExercise(exerciseType, payload).length > 0;
}
