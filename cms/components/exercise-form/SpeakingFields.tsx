'use client';

import { ItemRepeater } from './ItemRepeater';

// ExerciseFormState fields used here (subset)
type SpeakingForm = {
  exerciseType: string;
  questions: string;
  scenarioTitle: string;
  scenarioPrompt: string;
  requiredInfoSlots: string;
  customQuestionHint: string;
  storyTitle: string;
  imageAssetIds: string;
  narrativeCheckpoints: string;
  grammarFocus: string;
  choiceScenarioPrompt: string;
  choiceOptions: string;
  expectedReasoningAxes: string;
  sampleAnswerText: string;
};

type Props = {
  form: SpeakingForm;
  setForm: (updater: (prev: SpeakingForm) => SpeakingForm) => void;
};

const labelStyle: React.CSSProperties = { fontSize: 13, fontWeight: 600, color: 'var(--ink-2)' };
const inputStyle: React.CSSProperties = { padding: '8px 10px', border: '1px solid var(--border-strong)', borderRadius: 8, fontSize: 14, fontFamily: 'inherit', width: '100%' };
const txStyle: React.CSSProperties = { padding: '8px 10px', border: '1px solid var(--border-strong)', borderRadius: 8, fontSize: 14, resize: 'vertical' as const, fontFamily: 'inherit' };

// Parse "slot_key | label | sample" lines into 3-column rows
type SlotRow = { key: string; label: string; sample: string };

function parseSlots(raw: string): SlotRow[] {
  const lines = raw.split('\n').map(l => l.trim()).filter(Boolean);
  if (lines.length === 0) return [{ key: '', label: '', sample: '' }];
  return lines.map(line => {
    const [k = '', lbl = '', s = ''] = line.split('|').map(p => p.trim());
    return { key: k, label: lbl, sample: s };
  });
}

function serializeSlots(rows: SlotRow[]): string {
  return rows.map(r => `${r.key} | ${r.label} | ${r.sample}`).join('\n');
}

// Parse "key | label | description" lines for choice options
type ChoiceRow = { key: string; label: string; description: string };

function parseChoiceOpts(raw: string): ChoiceRow[] {
  const lines = raw.split('\n').map(l => l.trim()).filter(Boolean);
  if (lines.length === 0) return [{ key: 'A', label: '', description: '' }];
  return lines.map(line => {
    const [k = '', lbl = '', desc = ''] = line.split('|').map(p => p.trim());
    return { key: k, label: lbl, description: desc };
  });
}

function serializeChoiceOpts(rows: ChoiceRow[]): string {
  return rows.map(r => [r.key, r.label, r.description].filter(Boolean).join(' | ')).join('\n');
}

const OPTION_KEYS = ['A', 'B', 'C', 'D'];

export function SpeakingFields({ form, setForm }: Props) {
  const set = <K extends keyof SpeakingForm>(key: K, val: SpeakingForm[K]) =>
    setForm(f => ({ ...f, [key]: val }));

  // Uloha 1 — question prompts list
  if (form.exerciseType === 'uloha_1_topic_answers') {
    const items = form.questions.split('\n').filter(Boolean);
    return (
      <ItemRepeater
        label="Question prompts (3-4 câu)"
        items={items.length ? items : ['']}
        onChange={rows => set('questions', rows.join('\n'))}
        placeholder="Prompt ngắn..."
        maxItems={4}
        minItems={3}
        rows={1}
        hint="3-4 câu hỏi ngắn cho learner trả lời."
      />
    );
  }

  // Uloha 2 — required info slots (structured 3-column rows)
  if (form.exerciseType === 'uloha_2_dialogue_questions') {
    const slots = parseSlots(form.requiredInfoSlots);
    return (
      <div style={{ display: 'grid', gap: 16 }}>
        <label style={{ display: 'grid', gap: 6 }}>
          <span style={labelStyle}>Scenario title</span>
          <input value={form.scenarioTitle} onChange={e => set('scenarioTitle', e.target.value)} style={inputStyle} placeholder="Tên tình huống..." />
        </label>
        <label style={{ display: 'grid', gap: 6 }}>
          <span style={labelStyle}>Scenario prompt</span>
          <textarea rows={4} value={form.scenarioPrompt} onChange={e => set('scenarioPrompt', e.target.value)} style={txStyle} placeholder="Mô tả tình huống..." />
        </label>
        <div style={{ display: 'grid', gap: 6 }}>
          <span style={labelStyle}>Required info slots</span>
          {slots.map((slot, i) => (
            <div key={i} style={{ display: 'grid', gridTemplateColumns: '1fr 2fr 3fr auto', gap: 6, alignItems: 'center' }}>
              <input value={slot.key} onChange={e => { const next = [...slots]; next[i] = { ...next[i], key: e.target.value }; set('requiredInfoSlots', serializeSlots(next)); }} placeholder="slot_key" style={{ ...inputStyle, fontSize: 13 }} />
              <input value={slot.label} onChange={e => { const next = [...slots]; next[i] = { ...next[i], label: e.target.value }; set('requiredInfoSlots', serializeSlots(next)); }} placeholder="Label (VD: Jméno)" style={{ ...inputStyle, fontSize: 13 }} />
              <input value={slot.sample} onChange={e => { const next = [...slots]; next[i] = { ...next[i], sample: e.target.value }; set('requiredInfoSlots', serializeSlots(next)); }} placeholder="Sample question (VD: Jak se jmenujete?)" style={{ ...inputStyle, fontSize: 13 }} />
              <button type="button" onClick={() => { if (slots.length <= 1) return; const next = slots.filter((_, j) => j !== i); set('requiredInfoSlots', serializeSlots(next)); }}
                disabled={slots.length <= 1}
                style={{ background: 'none', border: '1px solid var(--border)', borderRadius: 6, width: 28, height: 28, cursor: slots.length <= 1 ? 'default' : 'pointer', fontSize: 14, color: 'var(--error)', opacity: slots.length <= 1 ? 0.3 : 1 }}>×</button>
            </div>
          ))}
          <button type="button" onClick={() => set('requiredInfoSlots', serializeSlots([...slots, { key: '', label: '', sample: '' }]))}
            style={{ alignSelf: 'flex-start', background: 'none', border: '1px dashed var(--border-strong)', borderRadius: 8, padding: '5px 12px', cursor: 'pointer', fontSize: 13, color: 'var(--ink-3)' }}>
            + Thêm slot
          </button>
        </div>
        <label style={{ display: 'grid', gap: 6 }}>
          <span style={labelStyle}>Custom question hint</span>
          <input value={form.customQuestionHint} onChange={e => set('customQuestionHint', e.target.value)} style={inputStyle} placeholder="Gợi ý câu hỏi thêm..." />
        </label>
        <label style={{ display: 'grid', gap: 6 }}>
          <span style={labelStyle}>Sample answer</span>
          <textarea rows={3} value={form.sampleAnswerText} onChange={e => set('sampleAnswerText', e.target.value)} style={txStyle} placeholder="Câu trả lời mẫu..." />
        </label>
      </div>
    );
  }

  // Uloha 3 — story narration
  if (form.exerciseType === 'uloha_3_story_narration') {
    const checkpoints = form.narrativeCheckpoints.split('\n').filter(Boolean);
    return (
      <div style={{ display: 'grid', gap: 16 }}>
        <label style={{ display: 'grid', gap: 6 }}>
          <span style={labelStyle}>Story title</span>
          <input value={form.storyTitle} onChange={e => set('storyTitle', e.target.value)} style={inputStyle} placeholder="Tiêu đề câu chuyện..." />
        </label>
        <label style={{ display: 'grid', gap: 6 }}>
          <span style={labelStyle}>Image asset IDs (1 ID/dòng)</span>
          <textarea rows={5} value={form.imageAssetIds} onChange={e => set('imageAssetIds', e.target.value)} style={txStyle} placeholder="asset-id-1&#10;asset-id-2&#10;asset-id-3&#10;asset-id-4" />
        </label>
        <ItemRepeater
          label="Narrative checkpoints (4 điểm kể chuyện)"
          items={checkpoints.length ? checkpoints : ['']}
          onChange={rows => set('narrativeCheckpoints', rows.join('\n'))}
          placeholder="Điểm trong câu chuyện..."
          maxItems={4}
          minItems={1}
          rows={1}
        />
        <label style={{ display: 'grid', gap: 6 }}>
          <span style={labelStyle}>Grammar focus (1 điểm/dòng)</span>
          <textarea rows={3} value={form.grammarFocus} onChange={e => set('grammarFocus', e.target.value)} style={txStyle} placeholder="Thì quá khứ đơn&#10;Câu phức với because" />
        </label>
        <label style={{ display: 'grid', gap: 6 }}>
          <span style={labelStyle}>Sample answer</span>
          <textarea rows={3} value={form.sampleAnswerText} onChange={e => set('sampleAnswerText', e.target.value)} style={txStyle} placeholder="Câu trả lời mẫu..." />
        </label>
      </div>
    );
  }

  // Uloha 4 — choice reasoning
  const choiceRows = parseChoiceOpts(form.choiceOptions);
  const nextKey = OPTION_KEYS[choiceRows.length] ?? String.fromCharCode(65 + choiceRows.length);
  return (
    <div style={{ display: 'grid', gap: 16 }}>
      <label style={{ display: 'grid', gap: 6 }}>
        <span style={labelStyle}>Scenario prompt</span>
        <textarea rows={4} value={form.choiceScenarioPrompt} onChange={e => set('choiceScenarioPrompt', e.target.value)} style={txStyle} placeholder="Mô tả tình huống chọn lựa..." />
      </label>
      <div style={{ display: 'grid', gap: 6 }}>
        <span style={labelStyle}>Lựa chọn (key | label | mô tả)</span>
        {choiceRows.map((row, i) => (
          <div key={i} style={{ display: 'grid', gridTemplateColumns: 'auto 1fr 2fr auto', gap: 6, alignItems: 'center' }}>
            <span style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center', width: 28, height: 28, borderRadius: 6, background: 'var(--accent-soft)', color: 'var(--accent)', fontSize: 12, fontWeight: 700 }}>{row.key || OPTION_KEYS[i]}</span>
            <input value={row.label} onChange={e => { const next = [...choiceRows]; next[i] = { ...next[i], label: e.target.value }; set('choiceOptions', serializeChoiceOpts(next)); }} placeholder="Nhãn lựa chọn..." style={{ ...inputStyle, fontSize: 13 }} />
            <input value={row.description} onChange={e => { const next = [...choiceRows]; next[i] = { ...next[i], description: e.target.value }; set('choiceOptions', serializeChoiceOpts(next)); }} placeholder="Mô tả thêm (optional)..." style={{ ...inputStyle, fontSize: 13 }} />
            <button type="button" onClick={() => { if (choiceRows.length <= 2) return; const next = choiceRows.filter((_, j) => j !== i); set('choiceOptions', serializeChoiceOpts(next)); }}
              disabled={choiceRows.length <= 2}
              style={{ background: 'none', border: '1px solid var(--border)', borderRadius: 6, width: 28, height: 28, cursor: choiceRows.length <= 2 ? 'default' : 'pointer', fontSize: 14, color: 'var(--error)', opacity: choiceRows.length <= 2 ? 0.3 : 1 }}>×</button>
          </div>
        ))}
        {choiceRows.length < 4 && (
          <button type="button" onClick={() => set('choiceOptions', serializeChoiceOpts([...choiceRows, { key: nextKey, label: '', description: '' }]))}
            style={{ alignSelf: 'flex-start', background: 'none', border: '1px dashed var(--border-strong)', borderRadius: 8, padding: '5px 12px', cursor: 'pointer', fontSize: 13, color: 'var(--ink-3)' }}>
            + Thêm lựa chọn
          </button>
        )}
      </div>
      <label style={{ display: 'grid', gap: 6 }}>
        <span style={labelStyle}>Expected reasoning axes (1/dòng)</span>
        <textarea rows={3} value={form.expectedReasoningAxes} onChange={e => set('expectedReasoningAxes', e.target.value)} style={txStyle} placeholder="Tiêu chí lý luận 1&#10;Tiêu chí lý luận 2" />
      </label>
      <label style={{ display: 'grid', gap: 6 }}>
        <span style={labelStyle}>Sample answer</span>
        <textarea rows={3} value={form.sampleAnswerText} onChange={e => set('sampleAnswerText', e.target.value)} style={txStyle} placeholder="Câu trả lời mẫu..." />
      </label>
    </div>
  );
}
