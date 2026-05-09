// Per-type validation for exercise form submission.
// Returns an array of human-readable error strings (empty = valid).

type ExerciseType = string;
type AnyPayload = Record<string, unknown>;

export function validateExercise(exerciseType: ExerciseType, payload: AnyPayload): string[] {
  const errors: string[] = [];

  // Common
  const title = String(payload.title ?? '').trim();
  if (!title) errors.push('Tiêu đề không được để trống.');
  const moduleId = String(payload.module_id ?? '').trim();
  if (!moduleId) errors.push('Phải chọn Module.');

  const detail = (payload.detail ?? {}) as Record<string, unknown>;

  // Poslech 1/2: need 5 items with text + correct_answers
  if (exerciseType === 'poslech_1' || exerciseType === 'poslech_2') {
    const items = (detail.items ?? []) as Array<Record<string, unknown>>;
    if (items.length < 5) errors.push(`Poslech 1/2 cần đúng 5 đoạn nghe (hiện có ${items.length}).`);
    const ca = detail.correct_answers as Record<string, string> | undefined;
    if (!ca || Object.keys(ca).length < 5) errors.push('Cần nhập đáp án cho tất cả 5 câu.');

    // V27 — poslech_1 image_asset_id all-or-none per item. Drafts can hold
    // partial state while admin is uploading; published exercises must be
    // 0/4 or 4/4 because Flutter only switches to image grid when ALL four
    // options carry an asset_id (mixed state silently falls back to text).
    const isPublished = String(payload.status ?? '') === 'published';
    if (exerciseType === 'poslech_1' && isPublished) {
      items.forEach((rawItem, i) => {
        const opts = (rawItem?.options ?? []) as Array<Record<string, unknown>>;
        const withImage = opts.filter((o) => {
          const v = String(o.image_asset_id ?? '').trim();
          return v !== '';
        }).length;
        if (withImage !== 0 && withImage !== 4) {
          errors.push(
            `Câu ${i + 1}: hoặc tất cả 4 đáp án có ảnh, hoặc không đáp án nào có ảnh (hiện có ${withImage}/4 ảnh).`,
          );
        }
      });
    }
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

  // Cteni 2 needs a reading text. Cteni 4 context is optional per V24,
  // so it only needs the six A-D questions.
  if (exerciseType === 'cteni_2' || exerciseType === 'cteni_4') {
    if (exerciseType === 'cteni_2') {
      const text = String(detail.text ?? '').trim();
      if (!text) errors.push('Cần nhập đoạn văn đọc.');
    }
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

  // Psaní 3: dictation needs complete sentence rows. Audio is required only
  // when publishing so admins can save a draft before calling Polly per row.
  if (exerciseType === 'psani_3_dictation') {
    const d = detail as Record<string, unknown>;
    const topic = String(d.topic ?? '').trim();
    if (!topic) errors.push('Chủ đề chính tả không được để trống.');
    const sentences = Array.isArray(d.sentences)
      ? (d.sentences as Array<Record<string, unknown>>)
      : [];
    if (sentences.length < 3) errors.push(`Chính tả cần ít nhất 3 câu (hiện có ${sentences.length}).`);
    if (sentences.length > 8) errors.push(`Chính tả tối đa 8 câu (hiện có ${sentences.length}).`);
    const requireAudio = String(payload.status ?? '') === 'published';
    sentences.forEach((s, i) => {
      const text = String(s.text ?? '').trim();
      if (!text) {
        errors.push(`Câu ${i + 1}: thiếu nội dung.`);
      } else if (Array.from(text).length > 200) {
        errors.push(`Câu ${i + 1}: quá 200 ký tự.`);
      }
      if (requireAudio && !String(s.audio_asset_id ?? '').trim()) {
        errors.push(`Câu ${i + 1}: chưa tạo audio.`);
      }
    });
    const mode = String(d.submission_mode ?? 'type');
    if (!['type', 'ocr', 'both'].includes(mode)) {
      errors.push('Chế độ nộp bài (submission_mode) không hợp lệ.');
    }
  }

  return errors;
}

export function hasValidationErrors(exerciseType: ExerciseType, payload: AnyPayload): boolean {
  return validateExercise(exerciseType, payload).length > 0;
}
