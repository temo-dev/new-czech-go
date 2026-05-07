'use client';

import type { ExerciseFormState } from '../exercise-utils';

// V23 Phase C4 — preview for the four Speaking (Úloha) exercise
// types. Renders a low-fidelity mock of the learner-side card so
// the admin can spot-check Czech text + question count before
// shipping to Flutter. The "record" button is intentionally
// disabled — no audio playback, no recording. Disclaimer band on
// the parent pane already warns about fidelity.

type Props = { form: ExerciseFormState };

const TYPE_LABEL: Record<string, string> = {
  uloha_1_topic_answers: 'Úloha 1 — Topic answers',
  uloha_2_dialogue_questions: 'Úloha 2 — Dialogue questions',
  uloha_3_story_narration: 'Úloha 3 — Story narration',
  uloha_4_choice_reasoning: 'Úloha 4 — Choice & reasoning',
};

export function UlohaPreview({ form }: Props) {
  const label = TYPE_LABEL[form.exerciseType] ?? 'Úloha';
  const isStory = form.exerciseType === 'uloha_3_story_narration';
  const isChoice = form.exerciseType === 'uloha_4_choice_reasoning';
  const questions = form.questions
    ? form.questions.split('\n').map((q) => q.trim()).filter(Boolean)
    : [];

  return (
    <div style={cardStyle}>
      <header style={{ borderBottom: '1px solid var(--border)', paddingBottom: 8, marginBottom: 12 }}>
        <p style={eyebrow}>{label}</p>
        <h3 style={{ margin: '4px 0 0', fontSize: 16, fontWeight: 700 }}>
          {form.title || '(Chưa có tiêu đề)'}
        </h3>
        {form.shortInstruction && (
          <p style={{ margin: '6px 0 0', fontSize: 13, color: 'var(--ink-2)' }}>
            {form.shortInstruction}
          </p>
        )}
      </header>

      {/* Topic / story / scenario block */}
      {isStory && form.storyTitle && (
        <p style={{ margin: '0 0 12px', fontSize: 13, color: 'var(--ink-2)' }}>
          <strong>Câu chuyện:</strong> {form.storyTitle}
        </p>
      )}
      {!isStory && !isChoice && form.scenarioTitle && (
        <p style={{ margin: '0 0 12px', fontSize: 13, color: 'var(--ink-2)' }}>
          <strong>Chủ đề:</strong> {form.scenarioTitle}
        </p>
      )}
      {isChoice && form.scenarioPrompt && (
        <p style={{ margin: '0 0 12px', fontSize: 13, color: 'var(--ink-2)' }}>
          {form.scenarioPrompt}
        </p>
      )}

      {/* Question list */}
      {questions.length > 0 && (
        <ol style={{ paddingLeft: 18, margin: '0 0 16px', fontSize: 13, color: 'var(--ink)' }}>
          {questions.map((q, i) => (
            <li key={i} style={{ marginBottom: 4 }}>{q}</li>
          ))}
        </ol>
      )}

      {/* Narrative checkpoints (uloha_3) */}
      {isStory && form.narrativeCheckpoints && (
        <p style={{ margin: '0 0 16px', fontSize: 12, color: 'var(--ink-3)' }}>
          <strong>Mốc kể chuyện:</strong> {form.narrativeCheckpoints}
        </p>
      )}

      {/* Disabled record button — visual only */}
      <button
        disabled
        style={{
          padding: '10px 16px',
          fontSize: 13,
          fontWeight: 600,
          borderRadius: 8,
          border: '1px solid var(--border)',
          background: 'var(--surface-alt)',
          color: 'var(--ink-3)',
          cursor: 'not-allowed',
          width: '100%',
        }}
      >
        🎤 Bắt đầu ghi âm (preview — disabled)
      </button>

      {/* Duration hint */}
      <p style={{ margin: '12px 0 0', fontSize: 11, color: 'var(--ink-4)' }}>
        Chuẩn bị 10s · ghi {form.exerciseType === 'uloha_3_story_narration' ? '120' : '90'}s
        {' '}(estimate)
      </p>
    </div>
  );
}

const cardStyle: React.CSSProperties = {
  padding: 16,
  background: 'var(--surface)',
  borderRadius: 10,
  border: '1px solid var(--border)',
};

const eyebrow: React.CSSProperties = {
  fontSize: 11,
  fontWeight: 700,
  color: 'var(--ink-3)',
  textTransform: 'uppercase',
  letterSpacing: 0.4,
  margin: 0,
};
