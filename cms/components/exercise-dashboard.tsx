'use client';

import { FormEvent, useEffect, useState } from 'react';

type PromptAsset = {
  id: string;
  asset_kind: string;
  storage_key: string;
  mime_type: string;
  sequence_no?: number;
};

type Exercise = {
  id: string;
  module_id?: string;
  title: string;
  exercise_type: string;
  short_instruction: string;
  learner_instruction?: string;
  estimated_duration_sec?: number;
  prep_time_sec?: number;
  recording_time_limit_sec?: number;
  sample_answer_enabled?: boolean;
  status?: string;
  assets?: PromptAsset[];
  prompt?: {
    topic_label?: string;
    question_prompts?: string[];
  };
  detail?: Record<string, unknown>;
};

const adminApi = '/api/admin/exercises';

type ExerciseType =
  | 'uloha_1_topic_answers'
  | 'uloha_2_dialogue_questions'
  | 'uloha_3_story_narration'
  | 'uloha_4_choice_reasoning';

type ExerciseFormState = {
  exerciseType: ExerciseType;
  title: string;
  shortInstruction: string;
  learnerInstruction: string;
  moduleId: string;
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
};

const exerciseTypeOptions: Array<{
  value: ExerciseType;
  label: string;
  hint: string;
}> = [
  {
    value: 'uloha_1_topic_answers',
    label: 'Uloha 1',
    hint: 'Topic answers with 3-4 short prompts.',
  },
  {
    value: 'uloha_2_dialogue_questions',
    label: 'Uloha 2',
    hint: 'Dialogue task where the learner asks for missing information.',
  },
  {
    value: 'uloha_3_story_narration',
    label: 'Uloha 3',
    hint: 'Story narration from four images or checkpoints.',
  },
  {
    value: 'uloha_4_choice_reasoning',
    label: 'Uloha 4',
    hint: 'Choose one option and justify the choice.',
  },
];

function createInitialFormState(): ExerciseFormState {
  return {
    exerciseType: 'uloha_1_topic_answers',
    title: 'Pocasi 2',
    shortInstruction: 'Tra loi ngan gon va ro y.',
    learnerInstruction: 'Ban hay tra loi ngan gon theo chu de thoi tiet.',
    moduleId: 'module-day-1',
    questions:
      'Jake pocasi mate dnes?\nCo delate, kdyz je venku hezky?\nMate rad/a zimu?\nJake pocasi bude zitra?',
    scenarioTitle: 'Navsteva kina',
    scenarioPrompt:
      'Chcete jit do kina na vecerni film. Potrebujete zjistit cas zacatku, cenu listku a jestli je mozne koupit listky online.',
    requiredInfoSlots:
      'start_time | Cas zacatku | V kolik hodin film zacina?\nprice | Cena listku | Kolik stoji jeden listek?\nonline_ticket | Nakup online | Muzu si koupit listek online?',
    customQuestionHint:
      'Pridejte jeste jednu otazku, treba na sal nebo titulky.',
    storyTitle: 'Nakup televize',
    imageAssetIds: 'asset-tv-1\nasset-tv-2\nasset-tv-3\nasset-tv-4',
    narrativeCheckpoints:
      'Otec a syn sli do obchodu.\nDivali se na televize a porovnavali je.\nVybrali jednu televizi a zaplatili ji.\nOdvezli televizi domu autem.',
    grammarFocus: 'past_tense',
    choiceScenarioPrompt:
      'Hledate bydleni v Praze. Ktery byt si vyberete a proc?',
    choiceOptions:
      'flat_a | Byt A | Levnejsi, ale daleko od centra.\nflat_b | Byt B | Blizko centra, ale mensi.\nflat_c | Byt C | Vetsi a klidny, ale drazsi.',
    expectedReasoningAxes: 'price\nlocation\nspace',
  };
}

function parseRequiredInfoSlots(input: string) {
  return input
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      const [slotKey = '', label = '', sampleQuestion = ''] = line
        .split('|')
        .map((part) => part.trim());
      if (!slotKey || !label) {
        throw new Error(
          'Each required-info line must follow `slot_key | label | sample question`.',
        );
      }
      return {
        slot_key: slotKey,
        label,
        ...(sampleQuestion ? { sample_question: sampleQuestion } : {}),
      };
    });
}

function parseLineList(input: string) {
  return input
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean);
}

function parseChoiceOptions(input: string) {
  return input
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      const [optionKey = '', label = '', description = '', imageAssetId = ''] = line
        .split('|')
        .map((part) => part.trim());
      if (!optionKey || !label) {
        throw new Error(
          'Each choice-option line must follow `option_key | label | description`.',
        );
      }
      return {
        option_key: optionKey,
        label,
        ...(description ? { description } : {}),
        ...(imageAssetId ? { image_asset_id: imageAssetId } : {}),
      };
    });
}

function formStateFromExercise(item: Exercise): ExerciseFormState {
  const detail = item.detail ?? {};
  const prompt = item.prompt ?? {};

  return {
    exerciseType: item.exercise_type as ExerciseType,
    title: item.title ?? '',
    shortInstruction: item.short_instruction ?? '',
    learnerInstruction: item.learner_instruction ?? '',
    moduleId: item.module_id ?? 'module-day-1',
    questions: (prompt.question_prompts ?? []).join('\n'),
    scenarioTitle: String(detail.scenario_title ?? ''),
    scenarioPrompt: String(detail.scenario_prompt ?? ''),
    requiredInfoSlots: Array.isArray(detail.required_info_slots)
      ? (detail.required_info_slots as Array<Record<string, unknown>>)
          .map(
            (slot) =>
              `${slot.slot_key ?? ''} | ${slot.label ?? ''} | ${slot.sample_question ?? ''}`,
          )
          .join('\n')
      : '',
    customQuestionHint: String(detail.custom_question_hint ?? ''),
    storyTitle: String(detail.story_title ?? ''),
    imageAssetIds: Array.isArray(detail.image_asset_ids)
      ? (detail.image_asset_ids as unknown[]).map(String).join('\n')
      : '',
    narrativeCheckpoints: Array.isArray(detail.narrative_checkpoints)
      ? (detail.narrative_checkpoints as unknown[]).map(String).join('\n')
      : '',
    grammarFocus: Array.isArray(detail.grammar_focus)
      ? (detail.grammar_focus as unknown[]).map(String).join('\n')
      : '',
    choiceScenarioPrompt: String(detail.scenario_prompt ?? ''),
    choiceOptions: Array.isArray(detail.options)
      ? (detail.options as Array<Record<string, unknown>>)
          .map(
            (option) =>
              `${option.option_key ?? ''} | ${option.label ?? ''} | ${option.description ?? ''} | ${option.image_asset_id ?? ''}`,
          )
          .join('\n')
      : '',
    expectedReasoningAxes: Array.isArray(detail.expected_reasoning_axes)
      ? (detail.expected_reasoning_axes as unknown[]).map(String).join('\n')
      : '',
  };
}

function buildCreatePayload(form: ExerciseFormState) {
  if (form.exerciseType === 'uloha_1_topic_answers') {
    return {
      module_id: form.moduleId,
      exercise_type: form.exerciseType,
      title: form.title,
      short_instruction: form.shortInstruction,
      learner_instruction: form.learnerInstruction,
      estimated_duration_sec: 90,
      prep_time_sec: 10,
      recording_time_limit_sec: 45,
      sample_answer_enabled: true,
      questions: parseLineList(form.questions),
    };
  }

  if (form.exerciseType === 'uloha_2_dialogue_questions') {
    return {
      module_id: form.moduleId,
      exercise_type: form.exerciseType,
      title: form.title,
      short_instruction: form.shortInstruction,
      learner_instruction: form.learnerInstruction,
      estimated_duration_sec: 90,
      prep_time_sec: 10,
      recording_time_limit_sec: 45,
      sample_answer_enabled: true,
      detail: {
        scenario_title: form.scenarioTitle,
        scenario_prompt: form.scenarioPrompt,
        required_info_slots: parseRequiredInfoSlots(form.requiredInfoSlots),
        custom_question_hint: form.customQuestionHint,
      },
    };
  }

  if (form.exerciseType === 'uloha_3_story_narration') {
    return {
      module_id: form.moduleId,
      exercise_type: form.exerciseType,
      title: form.title,
      short_instruction: form.shortInstruction,
      learner_instruction: form.learnerInstruction,
      estimated_duration_sec: 120,
      prep_time_sec: 15,
      recording_time_limit_sec: 60,
      sample_answer_enabled: true,
      detail: {
        story_title: form.storyTitle,
        image_asset_ids: parseLineList(form.imageAssetIds),
        narrative_checkpoints: parseLineList(form.narrativeCheckpoints),
        grammar_focus: parseLineList(form.grammarFocus),
      },
    };
  }

  return {
    module_id: form.moduleId,
    exercise_type: form.exerciseType,
    title: form.title,
    short_instruction: form.shortInstruction,
    learner_instruction: form.learnerInstruction,
    estimated_duration_sec: 90,
    prep_time_sec: 10,
    recording_time_limit_sec: 45,
    sample_answer_enabled: true,
    detail: {
      scenario_prompt: form.choiceScenarioPrompt,
      options: parseChoiceOptions(form.choiceOptions),
      expected_reasoning_axes: parseLineList(form.expectedReasoningAxes),
    },
  };
}

function buildUpdatePayload(form: ExerciseFormState) {
  if (form.exerciseType === 'uloha_1_topic_answers') {
    return {
      module_id: form.moduleId,
      exercise_type: form.exerciseType,
      title: form.title,
      short_instruction: form.shortInstruction,
      learner_instruction: form.learnerInstruction,
      estimated_duration_sec: 90,
      prep_time_sec: 10,
      recording_time_limit_sec: 45,
      sample_answer_enabled: true,
      prompt: {
        topic_label: form.title,
        question_prompts: parseLineList(form.questions),
      },
    };
  }

  if (form.exerciseType === 'uloha_2_dialogue_questions') {
    return {
      module_id: form.moduleId,
      exercise_type: form.exerciseType,
      title: form.title,
      short_instruction: form.shortInstruction,
      learner_instruction: form.learnerInstruction,
      estimated_duration_sec: 90,
      prep_time_sec: 10,
      recording_time_limit_sec: 45,
      sample_answer_enabled: true,
      detail: {
        scenario_title: form.scenarioTitle,
        scenario_prompt: form.scenarioPrompt,
        required_info_slots: parseRequiredInfoSlots(form.requiredInfoSlots),
        custom_question_hint: form.customQuestionHint,
      },
    };
  }

  if (form.exerciseType === 'uloha_3_story_narration') {
    return {
      module_id: form.moduleId,
      exercise_type: form.exerciseType,
      title: form.title,
      short_instruction: form.shortInstruction,
      learner_instruction: form.learnerInstruction,
      estimated_duration_sec: 120,
      prep_time_sec: 15,
      recording_time_limit_sec: 60,
      sample_answer_enabled: true,
      detail: {
        story_title: form.storyTitle,
        image_asset_ids: parseLineList(form.imageAssetIds),
        narrative_checkpoints: parseLineList(form.narrativeCheckpoints),
        grammar_focus: parseLineList(form.grammarFocus),
      },
    };
  }

  return {
    module_id: form.moduleId,
    exercise_type: form.exerciseType,
    title: form.title,
    short_instruction: form.shortInstruction,
    learner_instruction: form.learnerInstruction,
    estimated_duration_sec: 90,
    prep_time_sec: 10,
    recording_time_limit_sec: 45,
    sample_answer_enabled: true,
    detail: {
      scenario_prompt: form.choiceScenarioPrompt,
      options: parseChoiceOptions(form.choiceOptions),
      expected_reasoning_axes: parseLineList(form.expectedReasoningAxes),
    },
  };
}

export function ExerciseDashboard() {
  const [items, setItems] = useState<Exercise[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [assetUploading, setAssetUploading] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [assetError, setAssetError] = useState<string | null>(null);
  const [form, setForm] = useState<ExerciseFormState>(createInitialFormState);

  const editingItem = editingId ? items.find((item) => item.id === editingId) ?? null : null;
  const currentAssets = editingItem?.assets ?? [];

  function resetForm() {
    setEditingId(null);
    setAssetError(null);
    setForm(createInitialFormState());
  }

  async function loadExercises() {
    setLoading(true);
    setError(null);
    try {
      const response = await fetch(adminApi);
      const payload = await response.json();
      if (!response.ok) {
        throw new Error(payload.error?.message ?? 'Could not load exercises.');
      }
      setItems(payload.data ?? []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadExercises();
  }, []);

  function startEditing(item: Exercise) {
    setError(null);
    setAssetError(null);
    setEditingId(item.id);
    setForm(formStateFromExercise(item));
  }

  async function handleAssetUpload(file: File) {
    if (!editingId) {
      setAssetError('Save the exercise first before uploading images.');
      return;
    }

    setAssetUploading(true);
    setAssetError(null);
    try {
      const formData = new FormData();
      formData.set('file', file);
      formData.set('asset_kind', 'image');
      formData.set('sequence_no', String(currentAssets.length + 1));

      const response = await fetch(`${adminApi}/${editingId}/assets/upload`, {
        method: 'POST',
        body: formData,
      });
      const payload = await response.json();
      if (!response.ok) {
        throw new Error(payload.error?.message ?? 'Could not upload asset.');
      }

      const assetId = payload.data?.asset?.id as string | undefined;
      await loadExercises();

      if (assetId && form.exerciseType === 'uloha_3_story_narration') {
        setForm((current) => ({
          ...current,
          imageAssetIds: appendLineIfMissing(current.imageAssetIds, assetId),
        }));
      }
    } catch (err) {
      setAssetError(err instanceof Error ? err.message : 'Unknown asset upload error');
    } finally {
      setAssetUploading(false);
    }
  }

  async function handleCopyAssetId(assetId: string) {
    try {
      await navigator.clipboard.writeText(assetId);
      setAssetError(`Copied ${assetId}.`);
    } catch {
      setAssetError(`Copy failed. Asset id: ${assetId}`);
    }
  }

  async function handleDelete(id: string) {
    if (!window.confirm('Delete this exercise? This cannot be undone.')) {
      return;
    }

    setError(null);
    try {
      const response = await fetch(`${adminApi}/${id}`, { method: 'DELETE' });
      const payload = await response.json();
      if (!response.ok) {
        throw new Error(payload.error?.message ?? 'Could not delete exercise.');
      }
      if (editingId === id) {
        resetForm();
      }
      await loadExercises();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
    }
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSaving(true);
    setError(null);

    try {
      const response = await fetch(editingId ? `${adminApi}/${editingId}` : adminApi, {
        method: editingId ? 'PATCH' : 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(editingId ? buildUpdatePayload(form) : buildCreatePayload(form)),
      });

      const payload = await response.json();
      if (!response.ok) {
        throw new Error(
          payload.error?.message ??
            (editingId ? 'Could not update exercise.' : 'Could not create exercise.'),
        );
      }

      if (editingId) {
        resetForm();
      } else {
        setForm((current) => ({ ...current, title: `${current.title} moi` }));
      }
      await loadExercises();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
    } finally {
      setSaving(false);
    }
  }

  return (
    <main style={{ display: 'grid', gap: 24 }}>
      <section
        style={{
          display: 'grid',
          gap: 18,
          padding: 28,
          borderRadius: 28,
          background: 'var(--surface)',
          border: '1px solid var(--border)',
          boxShadow: 'var(--shadow)',
        }}
      >
        <div style={{ display: 'grid', gap: 8 }}>
          <p style={eyebrowStyle}>A2 Mluveni CMS</p>
          <h1 style={{ margin: 0, fontSize: 'clamp(2.2rem, 3vw, 3.5rem)', lineHeight: 1.02 }}>
            Calm content ops for the first oral tasks
          </h1>
          <p style={{ margin: 0, maxWidth: 760, color: 'var(--text-secondary)', fontSize: 16, lineHeight: 1.55 }}>
            This desk keeps the speaking workflow light and focused. Right now the admin can create, edit, and delete
            explicit content for all four oral tasks, while the learner app stays centered on one task at a time.
          </p>
        </div>

        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
            gap: 14,
          }}
        >
          <div style={metricCardStyle}>
            <span style={metricLabelStyle}>Current slice</span>
            <strong style={metricValueStyle}>Full V1 oral set</strong>
            <span style={metricHintStyle}>Create, edit, and delete exercises</span>
          </div>
          <div style={metricCardStyle}>
            <span style={metricLabelStyle}>Content status</span>
            <strong style={metricValueStyle}>{items.length}</strong>
            <span style={metricHintStyle}>Exercises in admin list</span>
          </div>
          <div style={metricCardStyle}>
            <span style={metricLabelStyle}>Working mode</span>
            <strong style={metricValueStyle}>Task-specific</strong>
            <span style={metricHintStyle}>No generic schema builder</span>
          </div>
        </div>
      </section>

      <section
        style={{
          display: 'grid',
          gridTemplateColumns: 'minmax(320px, 420px) minmax(0, 1fr)',
          gap: 20,
          alignItems: 'start',
        }}
      >
        <form
          onSubmit={handleSubmit}
          style={{
            display: 'grid',
            gap: 14,
            padding: 24,
            borderRadius: 28,
            background: 'var(--surface)',
            border: '1px solid var(--border)',
            boxShadow: 'var(--shadow)',
          }}
        >
          <div style={{ display: 'grid', gap: 6 }}>
            <span style={eyebrowStyle}>Content editor</span>
            <h2 style={{ margin: 0, fontSize: 24 }}>
              {editingId ? 'Edit ' : 'Create '}
              {form.exerciseType === 'uloha_1_topic_answers'
                ? '`Uloha 1`'
                : form.exerciseType === 'uloha_2_dialogue_questions'
                  ? '`Uloha 2`'
                  : form.exerciseType === 'uloha_3_story_narration'
                    ? '`Uloha 3`'
                    : '`Uloha 4`'}
            </h2>
            <p style={{ margin: 0, color: 'var(--text-secondary)', lineHeight: 1.5 }}>
              Keep prompts short, specific, and easy to scan so learners can stay calm inside the speaking flow.
            </p>
          </div>

          {editingId ? (
            <div
              style={{
                padding: '12px 14px',
                borderRadius: 16,
                background: 'var(--surface-muted)',
                color: 'var(--text-secondary)',
                fontSize: 14,
              }}
            >
              Editing <code>{editingId}</code>
            </div>
          ) : null}

          <label style={{ display: 'grid', gap: 6 }}>
            <span style={fieldLabelStyle}>Task type</span>
            <select
              value={form.exerciseType}
              onChange={(event) =>
                setForm({ ...form, exerciseType: event.target.value as ExerciseType })
              }
              style={fieldStyle}
            >
              {exerciseTypeOptions.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.label} - {option.hint}
                </option>
              ))}
            </select>
          </label>

          <label style={{ display: 'grid', gap: 6 }}>
            <span style={fieldLabelStyle}>Title</span>
            <input
              value={form.title}
              onChange={(event) => setForm({ ...form, title: event.target.value })}
              style={fieldStyle}
            />
          </label>

          <label style={{ display: 'grid', gap: 6 }}>
            <span style={fieldLabelStyle}>Short instruction</span>
            <input
              value={form.shortInstruction}
              onChange={(event) =>
                setForm({ ...form, shortInstruction: event.target.value })
              }
              style={fieldStyle}
            />
          </label>

          <label style={{ display: 'grid', gap: 6 }}>
            <span style={fieldLabelStyle}>Learner instruction</span>
            <textarea
              rows={4}
              value={form.learnerInstruction}
              onChange={(event) =>
                setForm({ ...form, learnerInstruction: event.target.value })
              }
              style={fieldStyle}
            />
          </label>

          {form.exerciseType === 'uloha_1_topic_answers' ? (
            <label style={{ display: 'grid', gap: 6 }}>
              <span style={fieldLabelStyle}>Question prompts</span>
              <textarea
                rows={6}
                value={form.questions}
                onChange={(event) => setForm({ ...form, questions: event.target.value })}
                style={fieldStyle}
              />
            </label>
          ) : form.exerciseType === 'uloha_2_dialogue_questions' ? (
            <>
              <label style={{ display: 'grid', gap: 6 }}>
                <span style={fieldLabelStyle}>Scenario title</span>
                <input
                  value={form.scenarioTitle}
                  onChange={(event) =>
                    setForm({ ...form, scenarioTitle: event.target.value })
                  }
                  style={fieldStyle}
                />
              </label>

              <label style={{ display: 'grid', gap: 6 }}>
                <span style={fieldLabelStyle}>Scenario prompt</span>
                <textarea
                  rows={5}
                  value={form.scenarioPrompt}
                  onChange={(event) =>
                    setForm({ ...form, scenarioPrompt: event.target.value })
                  }
                  style={fieldStyle}
                />
              </label>

              <label style={{ display: 'grid', gap: 6 }}>
                <span style={fieldLabelStyle}>Required info slots</span>
                <textarea
                  rows={6}
                  value={form.requiredInfoSlots}
                  onChange={(event) =>
                    setForm({ ...form, requiredInfoSlots: event.target.value })
                  }
                  style={fieldStyle}
                />
              </label>

              <label style={{ display: 'grid', gap: 6 }}>
                <span style={fieldLabelStyle}>Extra question hint</span>
                <input
                  value={form.customQuestionHint}
                  onChange={(event) =>
                    setForm({ ...form, customQuestionHint: event.target.value })
                  }
                  style={fieldStyle}
                />
              </label>
            </>
          ) : form.exerciseType === 'uloha_3_story_narration' ? (
            <>
              <label style={{ display: 'grid', gap: 6 }}>
                <span style={fieldLabelStyle}>Story title</span>
                <input
                  value={form.storyTitle}
                  onChange={(event) =>
                    setForm({ ...form, storyTitle: event.target.value })
                  }
                  style={fieldStyle}
                />
              </label>

              <label style={{ display: 'grid', gap: 6 }}>
                <span style={fieldLabelStyle}>Image asset ids</span>
                <textarea
                  rows={5}
                  value={form.imageAssetIds}
                  onChange={(event) =>
                    setForm({ ...form, imageAssetIds: event.target.value })
                  }
                  style={fieldStyle}
                />
                <span style={fieldHintStyle}>
                  One asset id per line. Uploaded image ids can be inserted from the asset desk below.
                </span>
              </label>

              <label style={{ display: 'grid', gap: 6 }}>
                <span style={fieldLabelStyle}>Narrative checkpoints</span>
                <textarea
                  rows={6}
                  value={form.narrativeCheckpoints}
                  onChange={(event) =>
                    setForm({
                      ...form,
                      narrativeCheckpoints: event.target.value,
                    })
                  }
                  style={fieldStyle}
                />
              </label>

              <label style={{ display: 'grid', gap: 6 }}>
                <span style={fieldLabelStyle}>Grammar focus</span>
                <textarea
                  rows={3}
                  value={form.grammarFocus}
                  onChange={(event) =>
                    setForm({ ...form, grammarFocus: event.target.value })
                  }
                  style={fieldStyle}
                />
              </label>
            </>
          ) : (
            <>
              <label style={{ display: 'grid', gap: 6 }}>
                <span style={fieldLabelStyle}>Scenario prompt</span>
                <textarea
                  rows={5}
                  value={form.choiceScenarioPrompt}
                  onChange={(event) =>
                    setForm({
                      ...form,
                      choiceScenarioPrompt: event.target.value,
                    })
                  }
                  style={fieldStyle}
                />
              </label>

              <label style={{ display: 'grid', gap: 6 }}>
                <span style={fieldLabelStyle}>Choice options</span>
                <textarea
                  rows={6}
                  value={form.choiceOptions}
                  onChange={(event) =>
                    setForm({ ...form, choiceOptions: event.target.value })
                  }
                  style={fieldStyle}
                />
                <span style={fieldHintStyle}>
                  Format: <code>option_key | label | description | image_asset_id(optional)</code>
                </span>
              </label>

              <label style={{ display: 'grid', gap: 6 }}>
                <span style={fieldLabelStyle}>Expected reasoning axes</span>
                <textarea
                  rows={4}
                  value={form.expectedReasoningAxes}
                  onChange={(event) =>
                    setForm({
                      ...form,
                      expectedReasoningAxes: event.target.value,
                    })
                  }
                  style={fieldStyle}
                />
              </label>
            </>
          )}

          {(form.exerciseType === 'uloha_3_story_narration' ||
            form.exerciseType === 'uloha_4_choice_reasoning') ? (
            <section
              style={{
                display: 'grid',
                gap: 12,
                padding: 16,
                borderRadius: 20,
                background: 'var(--surface-muted)',
                border: '1px solid var(--border)',
              }}
            >
              <div style={{ display: 'grid', gap: 4 }}>
                <span style={fieldLabelStyle}>Prompt assets</span>
                <span style={fieldHintStyle}>
                  Upload image assets after the draft exists. For `Uloha 3`, uploaded ids are inserted into the image list automatically.
                </span>
              </div>

              {!editingId ? (
                <p style={{ margin: 0, color: 'var(--text-secondary)' }}>
                  Save this draft first, then come back to attach images.
                </p>
              ) : (
                <>
                  <label style={{ display: 'grid', gap: 8 }}>
                    <span style={fieldLabelStyle}>Upload image</span>
                    <input
                      type="file"
                      accept="image/*"
                      onChange={(event) => {
                        const file = event.target.files?.[0];
                        if (file) {
                          void handleAssetUpload(file);
                        }
                        event.currentTarget.value = '';
                      }}
                    />
                  </label>

                  {assetError ? (
                    <p
                      style={{
                        margin: 0,
                        color: assetError.startsWith('Copied ') ? 'var(--text-secondary)' : 'var(--danger)',
                      }}
                    >
                      {assetError}
                    </p>
                  ) : null}

                  {assetUploading ? (
                    <p style={{ margin: 0, color: 'var(--text-secondary)' }}>Uploading asset...</p>
                  ) : null}

                  <div style={{ display: 'grid', gap: 12 }}>
                    {currentAssets.length === 0 ? (
                      <p style={{ margin: 0, color: 'var(--text-secondary)' }}>
                        No prompt assets yet for this exercise.
                      </p>
                    ) : (
                      currentAssets.map((asset) => (
                        <article
                          key={asset.id}
                          style={{
                            display: 'grid',
                            gap: 10,
                            padding: 14,
                            borderRadius: 18,
                            border: '1px solid var(--border)',
                            background: 'var(--surface)',
                          }}
                        >
                          {asset.mime_type?.startsWith('image/') ? (
                            <>
                              {/* eslint-disable-next-line @next/next/no-img-element */}
                              <img
                                src={assetPreviewSrc(editingId, asset)}
                                alt={asset.id}
                                style={{
                                  width: '100%',
                                  maxHeight: 180,
                                  objectFit: 'cover',
                                  borderRadius: 14,
                                  border: '1px solid var(--border)',
                                }}
                              />
                            </>
                          ) : null}
                          <div style={{ display: 'grid', gap: 4 }}>
                            <strong>{asset.id}</strong>
                            <span style={fieldHintStyle}>{asset.storage_key}</span>
                          </div>
                          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                            <span style={badgeStyle}>{asset.asset_kind}</span>
                            <span style={badgeStyle}>seq {asset.sequence_no ?? 0}</span>
                          </div>
                          <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
                            {form.exerciseType === 'uloha_3_story_narration' ? (
                              <button
                                type="button"
                                onClick={() =>
                                  setForm((current) => ({
                                    ...current,
                                    imageAssetIds: appendLineIfMissing(current.imageAssetIds, asset.id),
                                  }))
                                }
                                style={secondaryActionStyle}
                              >
                                Insert into image list
                              </button>
                            ) : null}
                            <button
                              type="button"
                              onClick={() => void handleCopyAssetId(asset.id)}
                              style={secondaryActionStyle}
                            >
                              Copy asset id
                            </button>
                          </div>
                        </article>
                      ))
                    )}
                  </div>
                </>
              )}
            </section>
          ) : null}

          <button
            type="submit"
            disabled={saving}
            style={{
              border: 0,
              borderRadius: 18,
              background: saving
                ? 'color-mix(in srgb, var(--primary) 55%, white)'
                : 'var(--primary)',
              color: 'white',
              padding: '14px 18px',
              cursor: saving ? 'wait' : 'pointer',
              fontWeight: 700,
              boxShadow: '0 16px 28px rgba(240, 90, 40, 0.18)',
            }}
          >
            {saving
              ? 'Saving...'
              : editingId
                ? 'Update exercise'
                : 'Create exercise'}
          </button>

          {editingId ? (
            <button
              type="button"
              onClick={resetForm}
              style={{
                borderRadius: 18,
                border: '1px solid var(--border)',
                background: 'var(--surface-muted)',
                color: 'var(--text)',
                padding: '12px 18px',
                cursor: 'pointer',
                fontWeight: 700,
              }}
            >
              Cancel editing
            </button>
          ) : null}
        </form>

        <section
          style={{
            display: 'grid',
            gap: 14,
            padding: 24,
            borderRadius: 28,
            background: 'var(--surface)',
            border: '1px solid var(--border)',
            boxShadow: 'var(--shadow)',
            minHeight: 420,
          }}
        >
          <div
            style={{
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              gap: 12,
            }}
          >
            <div>
              <span style={eyebrowStyle}>Current inventory</span>
              <h2 style={{ margin: '6px 0 0' }}>Exercises</h2>
              <p
                style={{
                  margin: '6px 0 0',
                  color: 'var(--text-secondary)',
                }}
              >
                Pulled from `/v1/admin/exercises`.
              </p>
            </div>
            <button
              type="button"
              onClick={loadExercises}
              style={{
                borderRadius: 16,
                border: '1px solid var(--border)',
                background: 'var(--surface-muted)',
                padding: '10px 14px',
                cursor: 'pointer',
                fontWeight: 600,
              }}
            >
              Refresh
            </button>
          </div>

          {error ? (
            <p style={{ margin: 0, color: 'var(--danger)' }}>{error}</p>
          ) : null}

          {loading ? <p style={{ margin: 0 }}>Loading exercises...</p> : null}

          <div style={{ display: 'grid', gap: 12 }}>
            {items.map((item) => (
              <article
                key={item.id}
                style={{
                  display: 'grid',
                  gap: 10,
                  padding: 18,
                  borderRadius: 20,
                  background: 'var(--surface-muted)',
                  border: '1px solid var(--border)',
                }}
              >
                <div
                  style={{
                    display: 'flex',
                    justifyContent: 'space-between',
                    gap: 12,
                  }}
                >
                  <strong style={{ fontSize: 18 }}>{item.title}</strong>
                  <span style={badgeStyle}>{item.status ?? 'draft'}</span>
                </div>
                <span style={{ color: 'var(--accent)', fontWeight: 700 }}>
                  {item.exercise_type}
                </span>
                <p
                  style={{
                    margin: 0,
                    color: 'var(--text-secondary)',
                    lineHeight: 1.5,
                  }}
                >
                  {item.short_instruction}
                </p>
                <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
                  <button
                    type="button"
                    onClick={() => startEditing(item)}
                    style={secondaryActionStyle}
                  >
                    Edit
                  </button>
                  <button
                    type="button"
                    onClick={() => handleDelete(item.id)}
                    style={dangerActionStyle}
                  >
                    Delete
                  </button>
                </div>
                <code style={{ color: 'var(--text-secondary)' }}>{item.id}</code>
              </article>
            ))}
          </div>
        </section>
      </section>
    </main>
  );
}

const fieldStyle = {
  width: '100%',
  padding: '14px 16px',
  borderRadius: 16,
  border: '1px solid var(--border)',
  background: 'var(--surface-muted)',
  color: 'var(--text)',
  lineHeight: 1.5,
} as const;

const badgeStyle = {
  alignSelf: 'start',
  padding: '6px 12px',
  borderRadius: 999,
  background: 'var(--primary-soft)',
  color: 'var(--primary-strong)',
  fontSize: 12,
  fontWeight: 700,
  textTransform: 'uppercase' as const,
  letterSpacing: '0.06em',
} as const;

const eyebrowStyle = {
  margin: 0,
  color: 'var(--accent)',
  fontSize: 12,
  fontWeight: 700,
  textTransform: 'uppercase' as const,
  letterSpacing: '0.12em',
} as const;

const fieldLabelStyle = {
  color: 'var(--text)',
  fontWeight: 700,
} as const;

const fieldHintStyle = {
  color: 'var(--text-secondary)',
  fontSize: 13,
  lineHeight: 1.45,
} as const;

const metricCardStyle = {
  display: 'grid',
  gap: 6,
  padding: 18,
  borderRadius: 22,
  border: '1px solid var(--border)',
  background: 'var(--surface-warm)',
} as const;

const metricLabelStyle = {
  color: 'var(--text-secondary)',
  fontSize: 12,
  fontWeight: 700,
  textTransform: 'uppercase' as const,
  letterSpacing: '0.08em',
} as const;

const metricValueStyle = {
  color: 'var(--text)',
  fontSize: 22,
  lineHeight: 1.1,
} as const;

const metricHintStyle = {
  color: 'var(--text-secondary)',
  fontSize: 14,
} as const;

const secondaryActionStyle = {
  borderRadius: 14,
  border: '1px solid var(--border)',
  background: 'var(--surface)',
  padding: '10px 14px',
  cursor: 'pointer',
  fontWeight: 700,
  color: 'var(--text)',
} as const;

const dangerActionStyle = {
  borderRadius: 14,
  border: '1px solid color-mix(in srgb, var(--danger) 25%, white)',
  background: 'color-mix(in srgb, var(--danger) 8%, white)',
  padding: '10px 14px',
  cursor: 'pointer',
  fontWeight: 700,
  color: 'var(--danger)',
} as const;

function appendLineIfMissing(input: string, value: string) {
  const lines = parseLineList(input);
  if (lines.includes(value)) {
    return input;
  }
  return [...lines, value].join('\n');
}

function assetPreviewSrc(exerciseId: string, asset: PromptAsset) {
  if (asset.storage_key.startsWith('http://') || asset.storage_key.startsWith('https://')) {
    return asset.storage_key;
  }
  return `${adminApi}/${exerciseId}/assets/${asset.id}/file`;
}
