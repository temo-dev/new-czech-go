// Per-type validation for exercise form submission.
// Returns an array of human-readable error strings (empty = valid).

type ExerciseType = string;
type AnyPayload = Record<string, unknown>;

export function validateExercise(exerciseType: ExerciseType, payload: AnyPayload): string[] {
  const errors: string[] = [];

  // Common
  const title = String(payload.title ?? '').trim();
  if (!title) errors.push('Tiêu đề không được để trống.');
  // Module chỉ bắt buộc cho pool=course. pool=exam (mock test) thì
  // module_id="" hợp lệ — bài thi gắn vào MockTestSection chứ không Module.
  const pool = String(payload.pool ?? 'course').trim();
  const moduleId = String(payload.module_id ?? '').trim();
  if (pool !== 'exam' && !moduleId) errors.push('Phải chọn Module.');

  const detail = (payload.detail ?? {}) as Record<string, unknown>;

  // Poslech 1/2: items with text + correct_answers.
  // V38 — poslech_1 + poslech_2 cho phép số câu tùy ý (≥1).
  if (exerciseType === 'poslech_1' || exerciseType === 'poslech_2') {
    const items = (detail.items ?? []) as Array<Record<string, unknown>>;
    const ca = detail.correct_answers as Record<string, string> | undefined;
    const label = exerciseType === 'poslech_1' ? 'Poslech 1' : 'Poslech 2';
    if (items.length < 1) errors.push(`${label} cần ít nhất 1 câu hỏi.`);
    const need = items.length;
    const have = ca ? Object.keys(ca).filter(k => String(ca[k] ?? '').trim()).length : 0;
    if (have < need) errors.push(`Cần nhập đáp án cho tất cả ${need} câu (hiện có ${have}).`);

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

  // Poslech 3/4: items động + options pool động (giữ ≥2 options để có distractor).
  // V38 — cho phép admin tùy biến số câu/lựa chọn.
  if (exerciseType === 'poslech_3' || exerciseType === 'poslech_4') {
    const items = (detail.items ?? []) as unknown[];
    const options = (detail.options ?? []) as unknown[];
    const label = exerciseType === 'poslech_3' ? 'Poslech 3' : 'Poslech 4';
    if (items.length < 1) errors.push(`${label} cần ít nhất 1 câu hỏi.`);
    if (options.length < 2) errors.push(`${label} cần ít nhất 2 lựa chọn (hiện có ${options.length}).`);
    const ca = detail.correct_answers as Record<string, string> | undefined;
    const need = items.length;
    const have = ca ? Object.keys(ca).filter(k => String(ca[k] ?? '').trim()).length : 0;
    if (need > 0 && have < need) errors.push(`Cần nhập đáp án cho tất cả ${need} câu (hiện có ${have}).`);
  }

  // Poslech 5: voicemail + fill slots (V38 — số slot tùy ý, ≥1).
  if (exerciseType === 'poslech_5') {
    const questions = (detail.questions ?? []) as Array<Record<string, unknown>>;
    if (questions.length < 1) errors.push('Poslech 5 cần ít nhất 1 câu hỏi điền vào.');
    questions.forEach((q, i) => {
      if (!String(q.prompt ?? '').trim()) {
        const qn = Number(q.question_no) || 21 + i;
        errors.push(`Poslech 5 câu ${qn}: thiếu câu hỏi hiển thị cho học viên.`);
      }
    });
    const ca = detail.correct_answers as Record<string, string> | undefined;
    const need = questions.length;
    const have = ca ? Object.values(ca).filter(v => String(v ?? '').trim()).length : 0;
    if (need > 0 && have < need) errors.push(`Poslech 5 cần nhập đáp án cho đủ ${need} câu (hiện có ${have}).`);
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
