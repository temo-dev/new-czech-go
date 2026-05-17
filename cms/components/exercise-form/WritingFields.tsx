'use client';

import { ItemRepeater } from './ItemRepeater';

type WritingForm = {
  exerciseType: string;
  formularQuestions: string;
  formularMinWords: number;
  emailPrompt: string;
  emailTopics: string;
  emailMinWords: number;
  imageAssetIds: string;
};

type Props = {
  form: WritingForm;
  setForm: (updater: (prev: WritingForm) => WritingForm) => void;
};

const labelStyle: React.CSSProperties = { fontSize: 13, fontWeight: 600, color: 'var(--ink-2)' };
const inputStyle: React.CSSProperties = { padding: '8px 10px', border: '1px solid var(--border-strong)', borderRadius: 8, fontSize: 14, fontFamily: 'inherit' };
const txStyle: React.CSSProperties = { padding: '8px 10px', border: '1px solid var(--border-strong)', borderRadius: 8, fontSize: 14, resize: 'vertical' as const, fontFamily: 'inherit' };

export function splitWritingRepeaterRows(value: string): string[] {
  return value.split('\n');
}

export function WritingFields({ form, setForm }: Props) {
  const set = <K extends keyof WritingForm>(key: K, val: WritingForm[K]) =>
    setForm(f => ({ ...f, [key]: val }));

  // Psaní 1 — formulář (1+ questions)
  if (form.exerciseType === 'psani_1_formular') {
    const questions = splitWritingRepeaterRows(form.formularQuestions);
    return (
      <div style={{ display: 'grid', gap: 16 }}>
        <ItemRepeater
          label="Câu hỏi formulář (ít nhất 1 câu)"
          items={questions.length ? questions : ['']}
          onChange={rows => set('formularQuestions', rows.join('\n'))}
          placeholder="Câu hỏi formulář..."
          minItems={1}
          rows={1}
          hint={`Có thể thêm nhiều câu tùy bài; mỗi câu trả lời cần ít nhất ${form.formularMinWords} từ.`}
        />
        <label style={{ display: 'grid', gap: 6 }}>
          <span style={labelStyle}>Số từ tối thiểu / câu</span>
          <input type="number" min={5} max={50} value={form.formularMinWords}
            onChange={e => set('formularMinWords', Number(e.target.value))}
            style={{ ...inputStyle, width: 100 }} />
        </label>
      </div>
    );
  }

  // Psaní 2 — email từ các gợi ý ảnh/topic
  const topics = splitWritingRepeaterRows(form.emailTopics);
  return (
    <div style={{ display: 'grid', gap: 16 }}>
      <label style={{ display: 'grid', gap: 6 }}>
        <span style={labelStyle}>Bối cảnh email (context prompt)</span>
        <textarea rows={3} value={form.emailPrompt} onChange={e => set('emailPrompt', e.target.value)} style={txStyle} placeholder="Jste na dovolené a chcete napsat své kamarádce." />
      </label>
      <ItemRepeater
        label="Topics / labels gợi ý (ít nhất 1)"
        items={topics.length ? topics : ['']}
        onChange={rows => set('emailTopics', rows.join('\n'))}
        placeholder="Chủ đề / mô tả ảnh..."
        minItems={1}
        rows={1}
        hint="Có thể thêm nhiều gợi ý tùy bài; mỗi dòng là một topic/ảnh prompt."
      />
      <label style={{ display: 'grid', gap: 6 }}>
        <span style={labelStyle}>Image asset IDs (1 ID/dòng, tùy số ảnh)</span>
        <textarea rows={5} value={form.imageAssetIds} onChange={e => set('imageAssetIds', e.target.value)} style={txStyle} placeholder="asset-id-1&#10;asset-id-2" />
      </label>
      <label style={{ display: 'grid', gap: 6 }}>
        <span style={labelStyle}>Số từ tối thiểu</span>
        <input type="number" min={20} max={100} value={form.emailMinWords}
          onChange={e => set('emailMinWords', Number(e.target.value))}
          style={{ ...inputStyle, width: 100 }} />
      </label>
    </div>
  );
}
