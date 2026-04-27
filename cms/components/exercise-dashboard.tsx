'use client';

import { FormEvent, useEffect, useState } from 'react';
import { useS } from '../lib/i18n';

type PromptAsset = {
  id: string;
  asset_kind: string;
  storage_key: string;
  mime_type: string;
  sequence_no?: number;
};

type CmsModule = { id: string; title: string; course_id: string };
type CmsSkill = { id: string; module_id: string; skill_kind: string; title: string };

type Exercise = {
  id: string;
  module_id?: string;
  skill_id?: string;
  pool?: string;
  title: string;
  exercise_type: string;
  short_instruction: string;
  learner_instruction?: string;
  estimated_duration_sec?: number;
  prep_time_sec?: number;
  recording_time_limit_sec?: number;
  sample_answer_enabled?: boolean;
  sample_answer_text?: string;
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
  | 'uloha_4_choice_reasoning'
  | 'psani_1_formular'
  | 'psani_2_email';

type ExerciseFormState = {
  exerciseType: ExerciseType;
  title: string;
  shortInstruction: string;
  learnerInstruction: string;
  moduleId: string;
  skillId: string;
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
  status: string;
  pool: string;
  // psani_1_formular
  formularQuestions: string;
  formularMinWords: number;
  // psani_2_email
  emailPrompt: string;
  emailTopics: string;
  emailMinWords: number;
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
  {
    value: 'psani_1_formular',
    label: 'Psaní 1 — Formulář',
    hint: 'Writing: 3 form questions, ≥10 words each (8 pts).',
  },
  {
    value: 'psani_2_email',
    label: 'Psaní 2 — E-mail',
    hint: 'Writing: email from 5 image prompts, ≥35 words (12 pts).',
  },
];

function createInitialFormState(): ExerciseFormState {
  return {
    exerciseType: 'uloha_1_topic_answers',
    title: 'Pocasi 2',
    shortInstruction: 'Tra loi ngan gon va ro y.',
    learnerInstruction: 'Ban hay tra loi ngan gon theo chu de thoi tiet.',
    moduleId: 'module-day-1',
    skillId: '',
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
    sampleAnswerText: '',
    status: 'draft',
    pool: 'course',
    formularQuestions: 'Jak jste získal/a informace o našem e-shopu?\nProč v našem e-shopu nakupujete?\nKteré služby nebo informace vám v našem e-shopu chybí?',
    formularMinWords: 10,
    emailPrompt: 'Jste na dovolené a chcete napsat své kamarádce.',
    emailTopics: 'KDE JSTE?\nJAK DLOUHO TAM JSTE?\nKDE BYDLÍTE?\nCO DĚLÁTE DOPOLEDNE?\nCO DĚLÁTE ODPOLEDNE?',
    emailMinWords: 35,
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
    skillId: item.skill_id ?? '',
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
    sampleAnswerText: item.sample_answer_text ?? '',
    status: item.status ?? 'draft',
    pool: (item as { pool?: string }).pool ?? 'course',
    formularQuestions: Array.isArray(detail.questions)
      ? (detail.questions as unknown[]).map(String).join('\n')
      : '',
    formularMinWords: typeof detail.min_words === 'number' ? detail.min_words : 10,
    emailPrompt: String(detail.prompt ?? ''),
    emailTopics: Array.isArray(detail.topics)
      ? (detail.topics as unknown[]).map(String).join('\n')
      : '',
    emailMinWords: typeof detail.min_words === 'number' ? detail.min_words : 35,
  };
}

function buildCreatePayload(form: ExerciseFormState) {
  if (form.exerciseType === 'uloha_1_topic_answers') {
    return {
      module_id: form.moduleId,
      skill_id: form.skillId,
      exercise_type: form.exerciseType,
      title: form.title,
      short_instruction: form.shortInstruction,
      learner_instruction: form.learnerInstruction,
      estimated_duration_sec: 90,
      prep_time_sec: 10,
      recording_time_limit_sec: 45,
      sample_answer_enabled: true,
      sample_answer_text: form.sampleAnswerText.trim(),
      status: form.status,
      pool: form.pool,
      questions: parseLineList(form.questions),
    };
  }

  if (form.exerciseType === 'uloha_2_dialogue_questions') {
    return {
      module_id: form.moduleId,
      skill_id: form.skillId,
      exercise_type: form.exerciseType,
      title: form.title,
      short_instruction: form.shortInstruction,
      learner_instruction: form.learnerInstruction,
      estimated_duration_sec: 90,
      prep_time_sec: 10,
      recording_time_limit_sec: 45,
      sample_answer_enabled: true,
      sample_answer_text: form.sampleAnswerText.trim(),
      status: form.status,
      pool: form.pool,
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
      skill_id: form.skillId,
      exercise_type: form.exerciseType,
      title: form.title,
      short_instruction: form.shortInstruction,
      learner_instruction: form.learnerInstruction,
      estimated_duration_sec: 120,
      prep_time_sec: 15,
      recording_time_limit_sec: 60,
      sample_answer_enabled: true,
      sample_answer_text: form.sampleAnswerText.trim(),
      status: form.status,
      pool: form.pool,
      detail: {
        story_title: form.storyTitle,
        image_asset_ids: parseLineList(form.imageAssetIds),
        narrative_checkpoints: parseLineList(form.narrativeCheckpoints),
        grammar_focus: parseLineList(form.grammarFocus),
      },
    };
  }

  if (form.exerciseType === 'psani_1_formular') {
    return {
      module_id: form.moduleId,
      skill_id: form.skillId,
      exercise_type: form.exerciseType,
      title: form.title,
      short_instruction: form.shortInstruction,
      learner_instruction: form.learnerInstruction,
      estimated_duration_sec: 600,
      sample_answer_enabled: false,
      sample_answer_text: form.sampleAnswerText.trim(),
      status: form.status,
      pool: form.pool,
      detail: {
        questions: parseLineList(form.formularQuestions),
        min_words: form.formularMinWords,
      },
    };
  }

  if (form.exerciseType === 'psani_2_email') {
    return {
      module_id: form.moduleId,
      skill_id: form.skillId,
      exercise_type: form.exerciseType,
      title: form.title,
      short_instruction: form.shortInstruction,
      learner_instruction: form.learnerInstruction,
      estimated_duration_sec: 900,
      sample_answer_enabled: false,
      sample_answer_text: form.sampleAnswerText.trim(),
      status: form.status,
      pool: form.pool,
      detail: {
        prompt: form.emailPrompt.trim(),
        topics: parseLineList(form.emailTopics),
        image_asset_ids: parseLineList(form.imageAssetIds),
        min_words: form.emailMinWords,
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
    sample_answer_text: form.sampleAnswerText.trim(),
    status: form.status,
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
      skill_id: form.skillId,
      exercise_type: form.exerciseType,
      title: form.title,
      short_instruction: form.shortInstruction,
      learner_instruction: form.learnerInstruction,
      estimated_duration_sec: 90,
      prep_time_sec: 10,
      recording_time_limit_sec: 45,
      sample_answer_enabled: true,
      sample_answer_text: form.sampleAnswerText.trim(),
      status: form.status,
      pool: form.pool,
      prompt: {
        topic_label: form.title,
        question_prompts: parseLineList(form.questions),
      },
    };
  }

  if (form.exerciseType === 'uloha_2_dialogue_questions') {
    return {
      module_id: form.moduleId,
      skill_id: form.skillId,
      exercise_type: form.exerciseType,
      title: form.title,
      short_instruction: form.shortInstruction,
      learner_instruction: form.learnerInstruction,
      estimated_duration_sec: 90,
      prep_time_sec: 10,
      recording_time_limit_sec: 45,
      sample_answer_enabled: true,
      sample_answer_text: form.sampleAnswerText.trim(),
      status: form.status,
      pool: form.pool,
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
      skill_id: form.skillId,
      exercise_type: form.exerciseType,
      title: form.title,
      short_instruction: form.shortInstruction,
      learner_instruction: form.learnerInstruction,
      estimated_duration_sec: 120,
      prep_time_sec: 15,
      recording_time_limit_sec: 60,
      sample_answer_enabled: true,
      sample_answer_text: form.sampleAnswerText.trim(),
      status: form.status,
      pool: form.pool,
      detail: {
        story_title: form.storyTitle,
        image_asset_ids: parseLineList(form.imageAssetIds),
        narrative_checkpoints: parseLineList(form.narrativeCheckpoints),
        grammar_focus: parseLineList(form.grammarFocus),
      },
    };
  }

  if (form.exerciseType === 'psani_1_formular') {
    return {
      module_id: form.moduleId,
      skill_id: form.skillId,
      exercise_type: form.exerciseType,
      title: form.title,
      short_instruction: form.shortInstruction,
      learner_instruction: form.learnerInstruction,
      estimated_duration_sec: 600,
      sample_answer_enabled: false,
      sample_answer_text: form.sampleAnswerText.trim(),
      status: form.status,
      pool: form.pool,
      detail: {
        questions: parseLineList(form.formularQuestions),
        min_words: form.formularMinWords,
      },
    };
  }

  if (form.exerciseType === 'psani_2_email') {
    return {
      module_id: form.moduleId,
      skill_id: form.skillId,
      exercise_type: form.exerciseType,
      title: form.title,
      short_instruction: form.shortInstruction,
      learner_instruction: form.learnerInstruction,
      estimated_duration_sec: 900,
      sample_answer_enabled: false,
      sample_answer_text: form.sampleAnswerText.trim(),
      status: form.status,
      pool: form.pool,
      detail: {
        prompt: form.emailPrompt.trim(),
        topics: parseLineList(form.emailTopics),
        image_asset_ids: parseLineList(form.imageAssetIds),
        min_words: form.emailMinWords,
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
    sample_answer_text: form.sampleAnswerText.trim(),
    status: form.status,
    detail: {
      scenario_prompt: form.choiceScenarioPrompt,
      options: parseChoiceOptions(form.choiceOptions),
      expected_reasoning_axes: parseLineList(form.expectedReasoningAxes),
    },
  };
}

export function ExerciseDashboard() {
  const S = useS();
  const [items, setItems] = useState<Exercise[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [assetUploading, setAssetUploading] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [assetError, setAssetError] = useState<string | null>(null);
  const [form, setForm] = useState<ExerciseFormState>(createInitialFormState);
  const [availableModules, setAvailableModules] = useState<CmsModule[]>([]);
  const [availableSkills, setAvailableSkills] = useState<CmsSkill[]>([]);
  const [formTab, setFormTab] = useState(0);

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
    loadModules();
  }, []);

  async function loadModules() {
    try {
      const res = await fetch('/api/admin/modules');
      const j = await res.json();
      setAvailableModules(j.data ?? []);
    } catch { /* non-fatal */ }
  }

  async function loadSkillsForModule(moduleId: string) {
    if (!moduleId) { setAvailableSkills([]); return; }
    try {
      const res = await fetch(`/api/admin/skills?module_id=${moduleId}`);
      const j = await res.json();
      setAvailableSkills(j.data ?? []);
    } catch { setAvailableSkills([]); }
  }

  function handleModuleChange(moduleId: string) {
    setForm(f => ({ ...f, moduleId, skillId: '' }));
    loadSkillsForModule(moduleId);
  }

  function handleSkillChange(skillId: string) {
    const skill = availableSkills.find(s => s.id === skillId);
    setForm(f => ({ ...f, skillId, moduleId: skill?.module_id ?? f.moduleId }));
  }

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
    if (!window.confirm(S.exercise.deleteConfirm)) {
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
            {S.exercise.heroTitle}
          </h1>
          <p style={{ margin: 0, maxWidth: 760, color: 'var(--text-secondary)', fontSize: 16, lineHeight: 1.55 }}>
            {S.exercise.heroDesc}
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
            <span style={metricLabelStyle}>{S.exercise.metricSliceLabel}</span>
            <strong style={metricValueStyle}>{S.exercise.metricSliceValue}</strong>
            <span style={metricHintStyle}>{S.exercise.metricSliceHint}</span>
          </div>
          <div style={metricCardStyle}>
            <span style={metricLabelStyle}>{S.exercise.metricStatusLabel}</span>
            <strong style={metricValueStyle}>{items.length}</strong>
            <span style={metricHintStyle}>{S.exercise.metricStatusHint}</span>
          </div>
          <div style={metricCardStyle}>
            <span style={metricLabelStyle}>{S.exercise.metricModeLabel}</span>
            <strong style={metricValueStyle}>{S.exercise.metricModeValue}</strong>
            <span style={metricHintStyle}>{S.exercise.metricModeHint}</span>
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
            <span style={eyebrowStyle}>{S.exercise.editorEyebrow}</span>
            <h2 style={{ margin: 0, fontSize: 24 }}>
              {editingId ? 'Chỉnh sửa ' : 'Tạo '}
              {form.exerciseType === 'uloha_1_topic_answers' ? '`Uloha 1`'
                : form.exerciseType === 'uloha_2_dialogue_questions' ? '`Uloha 2`'
                : form.exerciseType === 'uloha_3_story_narration' ? '`Uloha 3`'
                : form.exerciseType === 'uloha_4_choice_reasoning' ? '`Uloha 4`'
                : form.exerciseType === 'psani_1_formular' ? '`Psaní 1 — Formulář`'
                : '`Psaní 2 — E-mail`'}
            </h2>
            <p style={{ margin: 0, color: 'var(--text-secondary)', lineHeight: 1.5 }}>
              {S.exercise.editorHint}
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

          {/* Tab bar */}
          <div style={{
            display: 'flex',
            gap: 2,
            padding: 4,
            background: 'rgba(20,18,14,0.05)',
            borderRadius: 999,
            marginBottom: 4,
          }}>
            {[S.exercise.tabPrompt, S.exercise.tabSample, S.exercise.tabMetadata].map((tab, i) => (
              <button
                key={i}
                type="button"
                onClick={() => setFormTab(i)}
                style={{
                  flex: 1,
                  padding: '8px 0',
                  borderRadius: 999,
                  border: 'none',
                  background: formTab === i ? 'var(--surface)' : 'transparent',
                  color: formTab === i ? 'var(--ink)' : 'var(--ink-3)',
                  fontWeight: formTab === i ? 600 : 400,
                  fontSize: 13,
                  cursor: 'pointer',
                  boxShadow: formTab === i ? '0 1px 4px rgba(40,28,16,0.10)' : 'none',
                  transition: 'all 120ms ease',
                }}
              >
                {tab}
              </button>
            ))}
          </div>

          {formTab === 0 && <>
          <label style={{ display: 'grid', gap: 6 }}>
            <span style={fieldLabelStyle}>{S.exercise.fieldTaskType}</span>
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
            <span style={fieldLabelStyle}>{S.exercise.fieldTitle}</span>
            <input
              value={form.title}
              onChange={(event) => setForm({ ...form, title: event.target.value })}
              style={fieldStyle}
            />
          </label>

          <label style={{ display: 'grid', gap: 6 }}>
            <span style={fieldLabelStyle}>{S.exercise.fieldShortInstruction}</span>
            <input
              value={form.shortInstruction}
              onChange={(event) =>
                setForm({ ...form, shortInstruction: event.target.value })
              }
              style={fieldStyle}
            />
          </label>

          <label style={{ display: 'grid', gap: 6 }}>
            <span style={fieldLabelStyle}>{S.exercise.fieldLearnerInstruction}</span>
            <textarea
              rows={4}
              value={form.learnerInstruction}
              onChange={(event) =>
                setForm({ ...form, learnerInstruction: event.target.value })
              }
              style={fieldStyle}
            />
          </label>

          </>} {/* end formTab === 0 prompt fields */}

          {formTab === 1 && <>
          <label style={{ display: 'grid', gap: 6 }}>
            <span style={fieldLabelStyle}>{S.exercise.fieldSampleAnswer}</span>
            <textarea
              rows={4}
              value={form.sampleAnswerText}
              onChange={(event) =>
                setForm({ ...form, sampleAnswerText: event.target.value })
              }
              style={fieldStyle}
              placeholder="Optional. Authored Czech model answer shown in review. Leave blank to auto-generate."
            />
            <span style={fieldHintStyle}>
              When set, this overrides rule-based and LLM-generated model answers in the learner review.
            </span>
          </label>

          </>} {/* end formTab === 1 sample fields */}

          {formTab === 2 && (
          <>{/* Module + Skill — only for pool=course */}
          {form.pool === 'course' && (
            <>
              <label style={{ display: 'grid', gap: 6 }}>
                <span style={fieldLabelStyle}>{S.exercise.fieldModule}</span>
                <select
                  value={form.moduleId}
                  onChange={(e) => handleModuleChange(e.target.value)}
                  style={fieldStyle}
                >
                  <option value="">{S.pick.module}</option>
                  {availableModules.map(m => (
                    <option key={m.id} value={m.id}>{m.title}</option>
                  ))}
                </select>
                <span style={fieldHintStyle}>Exercise belongs to this module&apos;s skill.</span>
              </label>
              <label style={{ display: 'grid', gap: 6 }}>
                <span style={fieldLabelStyle}>{S.exercise.fieldSkill}</span>
                <select
                  value={form.skillId}
                  onChange={(e) => handleSkillChange(e.target.value)}
                  style={fieldStyle}
                  disabled={availableSkills.length === 0}
                >
                  <option value="">{S.pick.skill}</option>
                  {availableSkills.map(s => (
                    <option key={s.id} value={s.id}>{s.title} ({s.skill_kind})</option>
                  ))}
                </select>
                <span style={fieldHintStyle}>Select a module first to load its skills.</span>
              </label>
            </>
          )}

          <label style={{ display: 'grid', gap: 6 }}>
            <span style={fieldLabelStyle}>{S.exercise.fieldStatus}</span>
            <select
              value={form.status}
              onChange={(event) => setForm({ ...form, status: event.target.value })}
              style={fieldStyle}
            >
              <option value="draft">draft</option>
              <option value="published">published</option>
              <option value="archived">archived</option>
            </select>
            <span style={fieldHintStyle}>
              Only published exercises are surfaced to learners on the home screen. Archived items are hidden.
            </span>
          </label>

          <label style={{ display: 'grid', gap: 6 }}>
            <span style={fieldLabelStyle}>{S.exercise.fieldPool}</span>
            <select
              value={form.pool}
              onChange={(event) => setForm({ ...form, pool: event.target.value })}
              style={fieldStyle}
            >
              <option value="course">Bài luyện khóa học (course)</option>
              <option value="exam">Bài thi mock exam (exam)</option>
            </select>
            <span style={fieldHintStyle}>
              course = dùng trong Course → Skill. exam = dùng trong MockTest → Section. Hai pool không dùng chung.
            </span>
          </label>

          </> )} {/* end formTab === 2 metadata */}

          {formTab === 0 && <>{form.exerciseType === 'uloha_1_topic_answers' ? (
            <label style={{ display: 'grid', gap: 6 }}>
              <span style={fieldLabelStyle}>{S.exercise.fieldQuestionPrompts}</span>
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
                <span style={fieldLabelStyle}>{S.exercise.fieldScenarioPrompt}</span>
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
                <span style={fieldLabelStyle}>{S.exercise.fieldExtraQuestionHint}</span>
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
                <span style={fieldLabelStyle}>{S.exercise.fieldNarrativeCheckpoints}</span>
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
                <span style={fieldLabelStyle}>{S.exercise.fieldScenarioPrompt}</span>
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

          {form.exerciseType === 'psani_1_formular' ? (
            <>
              <label style={{ display: 'grid', gap: 6 }}>
                <span style={fieldLabelStyle}>Câu hỏi (1 câu/dòng, cần đúng 3 câu)</span>
                <textarea
                  rows={5}
                  value={form.formularQuestions}
                  onChange={(e) => setForm({ ...form, formularQuestions: e.target.value })}
                  style={fieldStyle}
                  placeholder={'Câu hỏi 1\nCâu hỏi 2\nCâu hỏi 3'}
                />
                <span style={fieldHintStyle}>Mỗi câu trả lời phải có ít nhất {form.formularMinWords} từ.</span>
              </label>
              <label style={{ display: 'grid', gap: 6 }}>
                <span style={fieldLabelStyle}>Số từ tối thiểu / câu</span>
                <input
                  type="number"
                  min={5}
                  max={50}
                  value={form.formularMinWords}
                  onChange={(e) => setForm({ ...form, formularMinWords: Number(e.target.value) })}
                  style={fieldStyle}
                />
              </label>
            </>
          ) : form.exerciseType === 'psani_2_email' ? (
            <>
              <label style={{ display: 'grid', gap: 6 }}>
                <span style={fieldLabelStyle}>Bối cảnh (context prompt)</span>
                <textarea
                  rows={3}
                  value={form.emailPrompt}
                  onChange={(e) => setForm({ ...form, emailPrompt: e.target.value })}
                  style={fieldStyle}
                  placeholder="Jste na dovolené a chcete napsat své kamarádce."
                />
              </label>
              <label style={{ display: 'grid', gap: 6 }}>
                <span style={fieldLabelStyle}>Chủ đề theo ảnh (1 chủ đề/dòng, cần 5 dòng)</span>
                <textarea
                  rows={6}
                  value={form.emailTopics}
                  onChange={(e) => setForm({ ...form, emailTopics: e.target.value })}
                  style={fieldStyle}
                  placeholder={'KDE JSTE?\nJAK DLOUHO TAM JSTE?\nKDE BYDLÍTE?\nCO DĚLÁTE DOPOLEDNE?\nCO DĚLÁTE ODPOLEDNE?'}
                />
                <span style={fieldHintStyle}>Mỗi dòng tương ứng với 1 ảnh gợi ý.</span>
              </label>
              <label style={{ display: 'grid', gap: 6 }}>
                <span style={fieldLabelStyle}>Asset IDs ảnh gợi ý (1 id/dòng)</span>
                <textarea
                  rows={6}
                  value={form.imageAssetIds}
                  onChange={(e) => setForm({ ...form, imageAssetIds: e.target.value })}
                  style={fieldStyle}
                  placeholder="Upload ảnh bên dưới rồi copy asset id vào đây."
                />
                <span style={fieldHintStyle}>Cần 5 ảnh. Thứ tự tương ứng với thứ tự chủ đề bên trên.</span>
              </label>
              <label style={{ display: 'grid', gap: 6 }}>
                <span style={fieldLabelStyle}>Số từ tối thiểu tổng cộng</span>
                <input
                  type="number"
                  min={20}
                  max={100}
                  value={form.emailMinWords}
                  onChange={(e) => setForm({ ...form, emailMinWords: Number(e.target.value) })}
                  style={fieldStyle}
                />
              </label>
            </>
          ) : null}

          {(form.exerciseType === 'uloha_3_story_narration' ||
            form.exerciseType === 'uloha_4_choice_reasoning' ||
            form.exerciseType === 'psani_2_email') ? (
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
                <span style={fieldLabelStyle}>{S.exercise.fieldPromptAssets}</span>
                <span style={fieldHintStyle}>
                  Upload ảnh sau khi đã save draft. Uloha 3: id tự động thêm vào danh sách. Psaní 2: copy id vào trường &quot;Asset IDs&quot;.
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
                        {S.exercise.noAssets}
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
                            {(form.exerciseType === 'uloha_3_story_narration' || form.exerciseType === 'psani_2_email') ? (
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
          ) : null}</>} {/* end formTab === 0 task-specific fields */}

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
              ? S.action.saving
              : editingId
                ? S.exercise.updateCta
                : S.exercise.createCta}
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
              {S.exercise.cancelEditing}
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
              <span style={eyebrowStyle}>{S.exercise.inventoryEyebrow}</span>
              <h2 style={{ margin: '6px 0 0' }}>{S.exercise.inventoryTitle}</h2>
              <p
                style={{
                  margin: '6px 0 0',
                  color: 'var(--text-secondary)',
                }}
              >
                {S.exercise.inventorySubtitle}
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
              {S.exercise.refresh}
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
                  <span style={badgeStyle}>{S.status[item.status as keyof typeof S.status] ?? item.status}</span>
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
                    {S.action.edit}
                  </button>
                  <button
                    type="button"
                    onClick={() => handleDelete(item.id)}
                    style={dangerActionStyle}
                  >
                    {S.action.delete}
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
