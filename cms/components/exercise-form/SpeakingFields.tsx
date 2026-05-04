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
    const grammarItems = form.grammarFocus.split('\n').filter(Boolean);
    const imageIds = form.imageAssetIds.split('\n').filter(Boolean);
    const imageCount = imageIds.length;

    return (
      <div style={{ display: 'grid', gap: 20 }}>

        {/* Story title */}
        <label style={{ display: 'grid', gap: 6 }}>
          <span style={labelStyle}>Tiêu đề câu chuyện</span>
          <input
            value={form.storyTitle}
            onChange={e => set('storyTitle', e.target.value)}
            style={inputStyle}
            placeholder="VD: Nákup televize, Výlet do Prahy..."
          />
        </label>

        {/* Divider */}
        <div style={{ height: 1, background: 'var(--border)' }} />

        {/* Image asset IDs */}
        <div style={{ display: 'grid', gap: 8 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span style={labelStyle}>Ảnh câu chuyện</span>
            <span style={{
              fontSize: 11, fontWeight: 700, padding: '2px 8px', borderRadius: 20,
              background: imageCount > 0 ? 'var(--accent-soft)' : 'var(--surface-alt)',
              color: imageCount > 0 ? 'var(--accent)' : 'var(--ink-3)',
            }}>
              {imageCount}/4 ảnh
            </span>
          </div>

          {/* ID pills — read-only visual */}
          {imageCount > 0 && (
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
              {imageIds.map((id, i) => (
                <span key={i} style={{
                  fontSize: 11, fontFamily: 'monospace', padding: '3px 10px',
                  borderRadius: 20, background: 'var(--surface-alt)',
                  border: '1px solid var(--border-strong)', color: 'var(--ink-2)',
                  maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
                }}>
                  {id}
                </span>
              ))}
            </div>
          )}

          {/* Empty state */}
          {imageCount === 0 && (
            <div style={{
              padding: '10px 14px', borderRadius: 10,
              background: 'var(--brand-soft)', border: '1px dashed var(--brand)',
              fontSize: 12, color: 'var(--brand-ink)', lineHeight: 1.5,
            }}>
              Chưa có ảnh. Upload trong mục <strong>Ảnh / tài nguyên</strong> phía dưới — ID sẽ tự động thêm vào đây.
            </div>
          )}

          {/* Editable textarea for manual override */}
          <details style={{ marginTop: 2 }}>
            <summary style={{ fontSize: 12, color: 'var(--ink-3)', cursor: 'pointer', userSelect: 'none' }}>
              Chỉnh sửa thủ công ({imageCount} ID)
            </summary>
            <textarea
              rows={4}
              value={form.imageAssetIds}
              onChange={e => set('imageAssetIds', e.target.value)}
              style={{ ...txStyle, marginTop: 6, fontFamily: 'monospace', fontSize: 12, background: 'var(--surface-alt)' }}
              placeholder="asset-id-1&#10;asset-id-2&#10;asset-id-3&#10;asset-id-4"
            />
          </details>
        </div>

        {/* Divider */}
        <div style={{ height: 1, background: 'var(--border)' }} />

        {/* Narrative checkpoints */}
        <div style={{ display: 'grid', gap: 8 }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <span style={labelStyle}>Trình tự câu chuyện</span>
            <span style={{
              fontSize: 11, fontWeight: 700, padding: '2px 8px', borderRadius: 20,
              background: checkpoints.length >= 4 ? 'var(--success-bg)' : 'var(--warning-bg)',
              color: checkpoints.length >= 4 ? 'var(--success)' : 'var(--warning)',
            }}>
              {checkpoints.length}/4 bước
            </span>
          </div>
          <p style={{ margin: 0, fontSize: 12, color: 'var(--ink-3)', lineHeight: 1.4 }}>
            4 điểm then chốt trong câu chuyện — học viên kể lại theo thứ tự.
          </p>
          <ItemRepeater
            label=""
            items={checkpoints.length ? checkpoints : ['']}
            onChange={rows => set('narrativeCheckpoints', rows.join('\n'))}
            placeholder="VD: Họ vào cửa hàng và nhìn xung quanh..."
            maxItems={4}
            minItems={1}
            rows={2}
          />
        </div>

        {/* Divider */}
        <div style={{ height: 1, background: 'var(--border)' }} />

        {/* Grammar focus */}
        <div style={{ display: 'grid', gap: 8 }}>
          <span style={labelStyle}>Trọng tâm ngữ pháp</span>
          <p style={{ margin: 0, fontSize: 12, color: 'var(--ink-3)' }}>
            Các điểm ngữ pháp cần chú ý. VD: Thì quá khứ, Câu phức với <em>protože</em>.
          </p>
          <ItemRepeater
            label=""
            items={grammarItems.length ? grammarItems : ['']}
            onChange={rows => set('grammarFocus', rows.join('\n'))}
            placeholder="VD: Động từ chia ở thì quá khứ..."
            maxItems={6}
            minItems={1}
            rows={1}
          />
        </div>

        {/* Divider */}
        <div style={{ height: 1, background: 'var(--border)' }} />

        {/* Sample answer */}
        <label style={{ display: 'grid', gap: 6 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span style={labelStyle}>Câu trả lời mẫu</span>
            <span style={{ fontSize: 11, padding: '2px 7px', borderRadius: 20, background: 'var(--surface-alt)', color: 'var(--ink-3)', fontWeight: 600 }}>
              🇨🇿 Tiếng Séc
            </span>
          </div>
          <textarea
            rows={4}
            value={form.sampleAnswerText}
            onChange={e => set('sampleAnswerText', e.target.value)}
            style={txStyle}
            placeholder="VD: Otec a syn šli do obchodu s elektronikou. Dívali se na různé televize..."
          />
          {form.sampleAnswerText && (
            <span style={{ fontSize: 11, color: 'var(--ink-4)', textAlign: 'right' }}>
              {form.sampleAnswerText.trim().split(/\s+/).filter(Boolean).length} từ
            </span>
          )}
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
