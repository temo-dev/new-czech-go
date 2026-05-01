'use client';

import { useEffect, useState } from 'react';
import { fieldHintStyle, fieldLabelStyle, fieldStyle } from '../exercise-utils';

type VGType = 'quizcard_basic' | 'fill_blank' | 'choice_word' | 'matching';

type QuizcardState = {
  front_text: string;
  back_text: string;
  example_sentence: string;
  example_translation: string;
  explanation: string;
};

type FillBlankState = {
  sentence: string;
  correct_answer: string;
  explanation: string;
};

type ChoiceOption = { key: string; text: string; image_asset_id: string };
type ChoiceWordState = {
  stem: string;
  options: ChoiceOption[];
  correct_key: string;
  grammar_note: string;
  explanation: string;
};

type MatchPair = { left_id: string; left: string; right_id: string; right: string };
type MatchingState = {
  pairs: MatchPair[];
  explanation: string;
};

type VGState =
  | { type: 'quizcard_basic' } & QuizcardState
  | { type: 'fill_blank' } & FillBlankState
  | { type: 'choice_word' } & ChoiceWordState
  | { type: 'matching' } & MatchingState;

// ── Init from exercise.detail ──────────────────────────────────────────────────

function initState(exerciseType: VGType, d: Record<string, unknown>): VGState {
  if (exerciseType === 'quizcard_basic') {
    return {
      type: 'quizcard_basic',
      front_text: String(d.front_text ?? ''),
      back_text: String(d.back_text ?? ''),
      example_sentence: String(d.example_sentence ?? ''),
      example_translation: String(d.example_translation ?? ''),
      explanation: String(d.explanation ?? ''),
    };
  }
  if (exerciseType === 'fill_blank') {
    const ca = (d.correct_answers ?? {}) as Record<string, string>;
    return {
      type: 'fill_blank',
      sentence: String(d.sentence ?? ''),
      correct_answer: ca['1'] ?? '',
      explanation: String(d.explanation ?? ''),
    };
  }
  if (exerciseType === 'choice_word') {
    const ca = (d.correct_answers ?? {}) as Record<string, string>;
    const rawOpts = (d.options ?? []) as Array<Record<string, unknown>>;
    const KEYS = ['A', 'B', 'C', 'D'];
    const options: ChoiceOption[] = KEYS.map((k, i) => {
      const raw = rawOpts[i] as Record<string, unknown> | undefined;
      return { key: k, text: String(raw?.text ?? ''), image_asset_id: String(raw?.image_asset_id ?? '') };
    });
    return {
      type: 'choice_word',
      stem: String(d.stem ?? ''),
      options,
      correct_key: ca['1'] ?? 'A',
      grammar_note: String(d.grammar_note ?? ''),
      explanation: String(d.explanation ?? ''),
    };
  }
  // matching
  const rawPairs = (d.pairs ?? []) as Array<Record<string, unknown>>;
  const pairs: MatchPair[] = rawPairs.map((p, i) => ({
    left_id: String(p.left_id ?? String(i + 1)),
    left: String(p.left ?? ''),
    right_id: String(p.right_id ?? String.fromCharCode(65 + i)),
    right: String(p.right ?? ''),
  }));
  if (pairs.length === 0) {
    pairs.push({ left_id: '1', left: '', right_id: 'A', right: '' });
  }
  return { type: 'matching', pairs, explanation: String(d.explanation ?? '') };
}

// ── Serialize back to detail payload ──────────────────────────────────────────

function toPayload(state: VGState): Record<string, unknown> {
  if (state.type === 'quizcard_basic') {
    return {
      front_text: state.front_text,
      back_text: state.back_text,
      example_sentence: state.example_sentence,
      example_translation: state.example_translation,
      explanation: state.explanation,
      correct_answers: { '1': 'known' },
    };
  }
  if (state.type === 'fill_blank') {
    return {
      sentence: state.sentence,
      explanation: state.explanation,
      correct_answers: { '1': state.correct_answer },
    };
  }
  if (state.type === 'choice_word') {
    return {
      stem: state.stem,
      options: state.options.map(o => ({ key: o.key, text: o.text, image_asset_id: o.image_asset_id })),
      grammar_note: state.grammar_note,
      explanation: state.explanation,
      correct_answers: { '1': state.correct_key },
    };
  }
  // matching
  const correctAnswers: Record<string, string> = {};
  state.pairs.forEach(p => { correctAnswers[p.left_id] = p.right_id; });
  return {
    pairs: state.pairs,
    explanation: state.explanation,
    correct_answers: correctAnswers,
  };
}

// ── Component ─────────────────────────────────────────────────────────────────

type Props = {
  exerciseType: VGType;
  initialData: Record<string, unknown>;
  onChange: (payload: Record<string, unknown>) => void;
};

const inputStyle: React.CSSProperties = {
  ...fieldStyle,
  width: '100%',
  boxSizing: 'border-box',
};

export function VocabGrammarFields({ exerciseType, initialData, onChange }: Props) {
  const [state, setState] = useState<VGState>(() => initState(exerciseType, initialData));

  useEffect(() => {
    setState(initState(exerciseType, initialData));
  // Re-init only when exerciseType or exercise id changes (initialData key)
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [exerciseType]);

  function update(next: VGState) {
    setState(next);
    onChange(toPayload(next));
  }

  if (state.type === 'quizcard_basic') {
    return (
      <div style={{ display: 'grid', gap: 12 }}>
        <label style={{ display: 'grid', gap: 6 }}>
          <span style={fieldLabelStyle}>Mặt trước (tiếng Czech) *</span>
          <input
            value={state.front_text}
            onChange={e => update({ ...state, front_text: e.target.value })}
            style={inputStyle}
            placeholder="On mluví česky."
          />
        </label>
        <label style={{ display: 'grid', gap: 6 }}>
          <span style={fieldLabelStyle}>Mặt sau (tiếng Việt) *</span>
          <input
            value={state.back_text}
            onChange={e => update({ ...state, back_text: e.target.value })}
            style={inputStyle}
            placeholder="Anh ấy nói tiếng Séc."
          />
        </label>
        <label style={{ display: 'grid', gap: 6 }}>
          <span style={fieldLabelStyle}>Câu ví dụ</span>
          <input
            value={state.example_sentence}
            onChange={e => update({ ...state, example_sentence: e.target.value })}
            style={inputStyle}
            placeholder="On mluví dobře česky."
          />
        </label>
        <label style={{ display: 'grid', gap: 6 }}>
          <span style={fieldLabelStyle}>Dịch câu ví dụ</span>
          <input
            value={state.example_translation}
            onChange={e => update({ ...state, example_translation: e.target.value })}
            style={inputStyle}
          />
        </label>
        <label style={{ display: 'grid', gap: 6 }}>
          <span style={fieldLabelStyle}>Giải thích</span>
          <textarea
            rows={2}
            value={state.explanation}
            onChange={e => update({ ...state, explanation: e.target.value })}
            style={inputStyle}
          />
        </label>
      </div>
    );
  }

  if (state.type === 'fill_blank') {
    return (
      <div style={{ display: 'grid', gap: 12 }}>
        <label style={{ display: 'grid', gap: 6 }}>
          <span style={fieldLabelStyle}>Câu có chỗ trống *</span>
          <textarea
            rows={2}
            value={state.sentence}
            onChange={e => update({ ...state, sentence: e.target.value })}
            style={inputStyle}
            placeholder="Já ___ česky."
          />
          <span style={fieldHintStyle}>Dùng ___ (ba dấu gạch dưới) cho chỗ trống.</span>
        </label>
        <label style={{ display: 'grid', gap: 6 }}>
          <span style={fieldLabelStyle}>Đáp án đúng *</span>
          <input
            value={state.correct_answer}
            onChange={e => update({ ...state, correct_answer: e.target.value })}
            style={inputStyle}
            placeholder="mluvím"
          />
        </label>
        <label style={{ display: 'grid', gap: 6 }}>
          <span style={fieldLabelStyle}>Giải thích</span>
          <textarea
            rows={2}
            value={state.explanation}
            onChange={e => update({ ...state, explanation: e.target.value })}
            style={inputStyle}
          />
        </label>
      </div>
    );
  }

  if (state.type === 'choice_word') {
    return (
      <div style={{ display: 'grid', gap: 12 }}>
        <label style={{ display: 'grid', gap: 6 }}>
          <span style={fieldLabelStyle}>Câu hỏi / Stem *</span>
          <textarea
            rows={2}
            value={state.stem}
            onChange={e => update({ ...state, stem: e.target.value })}
            style={inputStyle}
            placeholder="Já ___ do školy každý den."
          />
        </label>
        <div style={{ display: 'grid', gap: 8 }}>
          <span style={fieldLabelStyle}>Lựa chọn (4 options) *</span>
          {state.options.map((opt, i) => (
            <div key={opt.key} style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
              <span style={{ fontWeight: 700, minWidth: 20, color: 'var(--text-secondary)' }}>{opt.key}</span>
              <input
                value={opt.text}
                onChange={e => {
                  const next = state.options.map((o, j) => j === i ? { ...o, text: e.target.value } : o);
                  update({ ...state, options: next });
                }}
                style={{ ...inputStyle, flex: 1 }}
                placeholder={`Lựa chọn ${opt.key}`}
              />
              <label style={{ display: 'flex', alignItems: 'center', gap: 4, cursor: 'pointer', whiteSpace: 'nowrap' }}>
                <input
                  type="radio"
                  name="correct_option"
                  checked={state.correct_key === opt.key}
                  onChange={() => update({ ...state, correct_key: opt.key })}
                />
                <span style={{ fontSize: 12 }}>Đúng</span>
              </label>
            </div>
          ))}
        </div>
        <label style={{ display: 'grid', gap: 6 }}>
          <span style={fieldLabelStyle}>Ghi chú ngữ pháp</span>
          <input
            value={state.grammar_note}
            onChange={e => update({ ...state, grammar_note: e.target.value })}
            style={inputStyle}
          />
        </label>
        <label style={{ display: 'grid', gap: 6 }}>
          <span style={fieldLabelStyle}>Giải thích</span>
          <textarea
            rows={2}
            value={state.explanation}
            onChange={e => update({ ...state, explanation: e.target.value })}
            style={inputStyle}
          />
        </label>
      </div>
    );
  }

  // matching
  const RIGHT_KEYS = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
  return (
    <div style={{ display: 'grid', gap: 12 }}>
      <div style={{ display: 'grid', gap: 8 }}>
        <span style={fieldLabelStyle}>Các cặp ghép đôi (≥2 cặp) *</span>
        {state.pairs.map((pair, i) => (
          <div key={i} style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
            <input
              value={pair.left}
              onChange={e => {
                const next = state.pairs.map((p, j) => j === i ? { ...p, left: e.target.value } : p);
                update({ ...state, pairs: next });
              }}
              style={{ ...inputStyle, flex: 1 }}
              placeholder="Tiếng Czech"
            />
            <span style={{ color: 'var(--text-secondary)' }}>→</span>
            <input
              value={pair.right}
              onChange={e => {
                const next = state.pairs.map((p, j) => j === i ? { ...p, right: e.target.value } : p);
                update({ ...state, pairs: next });
              }}
              style={{ ...inputStyle, flex: 1 }}
              placeholder="Tiếng Việt"
            />
            <button
              type="button"
              onClick={() => {
                const next = state.pairs.filter((_, j) => j !== i);
                update({ ...state, pairs: next });
              }}
              style={{ border: 'none', background: 'none', cursor: 'pointer', color: 'var(--danger)', fontSize: 18, padding: '0 4px' }}
            >
              ×
            </button>
          </div>
        ))}
        <button
          type="button"
          onClick={() => {
            const i = state.pairs.length;
            const newPair: MatchPair = {
              left_id: String(i + 1),
              left: '',
              right_id: RIGHT_KEYS[i] ?? String.fromCharCode(65 + i),
              right: '',
            };
            update({ ...state, pairs: [...state.pairs, newPair] });
          }}
          style={{ alignSelf: 'start', padding: '4px 10px', borderRadius: 8, border: '1px dashed var(--border)', background: 'transparent', cursor: 'pointer', fontSize: 12 }}
        >
          + Thêm cặp
        </button>
      </div>
      <label style={{ display: 'grid', gap: 6 }}>
        <span style={fieldLabelStyle}>Giải thích</span>
        <textarea
          rows={2}
          value={state.explanation}
          onChange={e => update({ ...state, explanation: e.target.value })}
          style={inputStyle}
        />
      </label>
    </div>
  );
}
