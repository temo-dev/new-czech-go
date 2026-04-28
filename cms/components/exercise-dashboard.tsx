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

type CmsCourse = { id: string; title: string };
type CmsModule = { id: string; title: string; course_id: string };
type CmsSkill = { id: string; module_id: string; skill_kind: string; title: string };
type CmsMockTest = { id: string; title: string; sections: Array<{ exercise_id: string }> };

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
  | 'psani_2_email'
  | 'poslech_1'
  | 'poslech_2'
  | 'poslech_3'
  | 'poslech_4'
  | 'poslech_5'
  | 'cteni_1'
  | 'cteni_2'
  | 'cteni_3'
  | 'cteni_4'
  | 'cteni_5';

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
  // poslech_* shared
  poslechItems: string;        // one text segment block per line-group, items separated by ---
  poslechOptions: string;      // one option per line: A | Label (or A | asset_id for poslech_4)
  poslechCorrectAnswers: string; // one per line: 1=B, 2=A, ...
  poslechAudioSource: 'text' | 'upload'; // how audio is provided
  poslechGeneratingAudio: boolean;
  poslechAudioReady: boolean;
  // poslech_5 voicemail
  poslechVoicemailText: string;
  // cteni_* shared
  cteniText: string;           // main reading passage (cteni_2/4/5)
  cteniItems: string;          // items (cteni_1: image refs, cteni_3: text blocks) separated by ---
  cteniOptions: string;        // options A-H / A-E (key | label)
  cteniQuestions: string;      // questions (cteni_2/4: prompt + A-D options; cteni_5: prompts)
  cteniCorrectAnswers: string; // 6=A\n7=B\n...
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
  { value: 'poslech_1', label: 'Poslech 1', hint: 'Listening: 5 short passages → A-D (5 pts).' },
  { value: 'poslech_2', label: 'Poslech 2', hint: 'Listening: 5 short passages → A-D (5 pts).' },
  { value: 'poslech_3', label: 'Poslech 3', hint: 'Listening: 5 passages → match A-G (5 pts).' },
  { value: 'poslech_4', label: 'Poslech 4', hint: 'Listening: 5 dialogs → choose image A-F (5 pts).' },
  { value: 'poslech_5', label: 'Poslech 5', hint: 'Listening: voicemail → fill info (5 pts).' },
  { value: 'cteni_1', label: 'Čtení 1', hint: 'Reading: match 5 images/messages → A-H (5 pts).' },
  { value: 'cteni_2', label: 'Čtení 2', hint: 'Reading: read text → choose A-D, 5 questions (5 pts).' },
  { value: 'cteni_3', label: 'Čtení 3', hint: 'Reading: match 4 texts → persons A-E (4 pts).' },
  { value: 'cteni_4', label: 'Čtení 4', hint: 'Reading: choose A-D, 6 questions (6 pts).' },
  { value: 'cteni_5', label: 'Čtení 5', hint: 'Reading: read text → fill info, 5 items (5 pts).' },
];

const SKILL_KIND_EXERCISE_TYPES: Record<string, ExerciseType[]> = {
  noi:  ['uloha_1_topic_answers', 'uloha_2_dialogue_questions', 'uloha_3_story_narration', 'uloha_4_choice_reasoning'],
  viet: ['psani_1_formular', 'psani_2_email'],
  nghe: ['poslech_1', 'poslech_2', 'poslech_3', 'poslech_4', 'poslech_5'],
  doc:  ['cteni_1', 'cteni_2', 'cteni_3', 'cteni_4', 'cteni_5'],
};

const SKILL_KIND_META: Record<string, { label: string; icon: string; color: string }> = {
  noi:  { label: 'Nói',   icon: '🎙️', color: '#FF6A14' },
  viet: { label: 'Viết',  icon: '✏️', color: '#0F3D3A' },
  nghe: { label: 'Nghe',  icon: '🎧', color: '#7C3AED' },
  doc:  { label: 'Đọc',   icon: '📖', color: '#0369A1' },
};

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
    poslechItems: 'Kde je nádraží?\n---\nJak se jmenujete?',
    poslechOptions: 'A | Možnost A\nB | Možnost B\nC | Možnost C\nD | Možnost D',
    poslechCorrectAnswers: '1=B\n2=A\n3=D\n4=C\n5=B',
    poslechAudioSource: 'text',
    poslechGeneratingAudio: false,
    poslechAudioReady: false,
    poslechVoicemailText: 'Ahoj Lído, tady Eva. Dostala jsem lístky na balet.',
    cteniText: 'Přečtěte si text...',
    cteniItems: 'Položka 1\n---\nPoložka 2\n---\nPoložka 3\n---\nPoložka 4\n---\nPoložka 5',
    cteniOptions: 'A | Možnost A\nB | Možnost B\nC | Možnost C\nD | Možnost D',
    cteniQuestions: 'Otázka 1?\nOtázka 2?\nOtázka 3?\nOtázka 4?\nOtázka 5?',
    cteniCorrectAnswers: '1=A\n2=B\n3=C\n4=D\n5=A',
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
    poslechItems: '',
    poslechOptions: Array.isArray(detail.options)
      ? (detail.options as Array<Record<string, unknown>>)
          .map(o => `${o.key ?? ''} | ${o.label ?? o.asset_id ?? ''}`)
          .join('\n')
      : '',
    poslechCorrectAnswers: detail.correct_answers
      ? Object.entries(detail.correct_answers as Record<string, string>)
          .map(([k, v]) => `${k}=${v}`)
          .join('\n')
      : '',
    poslechAudioSource: 'text',
    poslechGeneratingAudio: false,
    poslechAudioReady: !!(item as unknown as Record<string, unknown>).hasAudio,
    poslechVoicemailText: (() => {
      const segs = (detail.audio_source as Record<string, unknown> | undefined)?.segments;
      return Array.isArray(segs)
        ? (segs as Array<Record<string, unknown>>).map(s => s.text ?? '').join('\n')
        : '';
    })(),
    cteniText: detail.text as string ?? '',
    cteniItems: (() => {
      if (Array.isArray(detail.items)) {
        return (detail.items as Array<Record<string, unknown>>).map(i => i.text ?? '').join('\n---\n');
      }
      if (Array.isArray(detail.texts)) {
        return (detail.texts as Array<Record<string, unknown>>).map(i => i.text ?? '').join('\n---\n');
      }
      return '';
    })(),
    cteniOptions: (() => {
      if (Array.isArray(detail.options)) {
        return (detail.options as Array<Record<string, unknown>>).map(o => `${o.key ?? ''} | ${o.text ?? o.label ?? ''}`).join('\n');
      }
      if (Array.isArray(detail.persons)) {
        return (detail.persons as Array<Record<string, unknown>>).map(p => `${p.key ?? ''} | ${p.name ?? ''}`).join('\n');
      }
      return '';
    })(),
    cteniQuestions: Array.isArray(detail.questions)
      ? (detail.questions as Array<Record<string, unknown>>).map(q => q.prompt ?? '').join('\n')
      : '',
    cteniCorrectAnswers: detail.correct_answers
      ? Object.entries(detail.correct_answers as Record<string, string>).map(([k, v]) => `${k}=${v}`).join('\n')
      : '',
  };
}

// Parse "A | Label" or "A | asset_id" lines into option objects
function parsePoslechOptions(input: string, type: 'choice' | 'match' | 'image') {
  return input.split('\n').map(line => line.trim()).filter(Boolean).map(line => {
    const [key = '', value = ''] = line.split('|').map(p => p.trim());
    if (type === 'image') return { key, asset_id: value };
    if (type === 'match') return { key, label: value };
    return { key, text: value };
  });
}

// Parse "1=B\n2=A" into {"1":"B","2":"A"}
function parsePoslechCorrectAnswers(input: string): Record<string, string> {
  const result: Record<string, string> = {};
  input.split('\n').map(l => l.trim()).filter(Boolean).forEach(line => {
    const [k, v] = line.split('=');
    if (k && v) result[k.trim()] = v.trim();
  });
  return result;
}

// Parse items: blocks separated by --- , each block is text lines (=segments)
function parsePoslechItems(input: string, questionCount: number) {
  const blocks = input.split(/\n---\n/).map(b => b.trim()).filter(Boolean);
  return Array.from({ length: questionCount }, (_, i) => {
    const block = blocks[i] ?? '';
    const segments = block.split('\n').filter(Boolean).map(t => ({ text: t.trim() }));
    return {
      question_no: i + 1,
      audio_source: { segments },
      options: [] as unknown[],
    };
  });
}

function buildPoslechPayload(form: ExerciseFormState) {
  const correct = parsePoslechCorrectAnswers(form.poslechCorrectAnswers);
  const base = {
    module_id: form.moduleId,
    skill_id: form.skillId,
    exercise_type: form.exerciseType,
    title: form.title,
    short_instruction: form.shortInstruction,
    learner_instruction: form.learnerInstruction,
    estimated_duration_sec: 1800,
    sample_answer_enabled: false,
    status: form.status,
    pool: form.pool,
  };
  if (form.exerciseType === 'poslech_5') {
    const segments = form.poslechVoicemailText.split('\n').filter(Boolean).map(t => ({ text: t.trim() }));
    return {
      ...base,
      detail: {
        audio_source: { segments },
        questions: Object.keys(correct).map(k => ({ question_no: parseInt(k), prompt: '' })),
        correct_answers: correct,
      },
    };
  }
  const items = parsePoslechItems(form.poslechItems, 5);
  const optionType = form.exerciseType === 'poslech_4' ? 'image' : form.exerciseType === 'poslech_3' ? 'match' : 'choice';
  const options = parsePoslechOptions(form.poslechOptions, optionType);
  return {
    ...base,
    detail: {
      items: items.map(item => ({ ...item, options: optionType === 'choice' ? options : [] })),
      options: optionType !== 'choice' ? options : undefined,
      correct_answers: correct,
    },
  };
}

function parseCteniCorrectAnswers(input: string): Record<string, string> {
  const result: Record<string, string> = {};
  input.split('\n').map(l => l.trim()).filter(Boolean).forEach(line => {
    const [k, v] = line.split('=');
    if (k && v) result[k.trim()] = v.trim();
  });
  return result;
}

function buildCteniPayload(form: ExerciseFormState) {
  const correct = parseCteniCorrectAnswers(form.cteniCorrectAnswers);
  const base = {
    module_id: form.moduleId, skill_id: form.skillId,
    exercise_type: form.exerciseType, title: form.title,
    short_instruction: form.shortInstruction, learner_instruction: form.learnerInstruction,
    estimated_duration_sec: 2400, sample_answer_enabled: false,
    status: form.status, pool: form.pool,
  };
  if (form.exerciseType === 'cteni_1') {
    const items = form.cteniItems.split(/\n---\n/).map((b, i) => ({ item_no: i + 1, text: b.trim() }));
    const options = parsePoslechOptions(form.cteniOptions, 'choice').map(o => ({ key: o.key, text: (o as Record<string, unknown>).text ?? '' }));
    return { ...base, detail: { items, options, correct_answers: correct } };
  }
  if (form.exerciseType === 'cteni_2' || form.exerciseType === 'cteni_4') {
    const questionPrompts = parseLineList(form.cteniQuestions);
    const questionOptions = parsePoslechOptions(form.cteniOptions, 'choice');
    const questions = questionPrompts.map((prompt, i) => ({
      question_no: i + (form.exerciseType === 'cteni_4' ? 15 : 6),
      prompt,
      options: questionOptions,
    }));
    return { ...base, detail: { text: form.cteniText.trim(), questions, correct_answers: correct } };
  }
  if (form.exerciseType === 'cteni_3') {
    const texts = form.cteniItems.split(/\n---\n/).map((b, i) => ({ item_no: i + 1, text: b.trim() }));
    const persons = form.cteniOptions.split('\n').filter(Boolean).map(line => {
      const [key = '', name = ''] = line.split('|').map(p => p.trim());
      return { key, name };
    });
    return { ...base, detail: { texts, persons, correct_answers: correct } };
  }
  // cteni_5
  const questions = parseLineList(form.cteniQuestions).map((prompt, i) => ({ question_no: i + 21, prompt }));
  return { ...base, detail: { text: form.cteniText.trim(), questions, correct_answers: correct } };
}

function buildCreatePayload(form: ExerciseFormState) {
  if (form.exerciseType.startsWith('cteni_')) return buildCteniPayload(form);
  if (form.exerciseType.startsWith('poslech_')) return buildPoslechPayload(form);
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
  if (form.exerciseType.startsWith('cteni_')) return buildCteniPayload(form);
  if (form.exerciseType.startsWith('poslech_')) return buildPoslechPayload(form);
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

function WizardTypeStep({ form, allSkills, onSelectType, onBack }: {
  form: ExerciseFormState;
  allSkills: CmsSkill[];
  onSelectType: (type: ExerciseType) => void;
  onBack: () => void;
}) {
  const skill = allSkills.find(s => s.id === form.skillId);
  const kind = skill?.skill_kind ?? '';
  const meta = SKILL_KIND_META[kind];
  const typeOptions = (SKILL_KIND_EXERCISE_TYPES[kind] ?? [])
    .map(v => exerciseTypeOptions.find(o => o.value === v))
    .filter((o): o is NonNullable<typeof o> => o != null);

  return (
    <div style={{ display: 'grid', gap: 16, padding: 24, borderRadius: 28, background: 'var(--surface)', border: '1px solid var(--border)', boxShadow: 'var(--shadow)' }}>
      <div>
        <p style={{ margin: '0 0 4px', fontSize: 11, fontWeight: 700, letterSpacing: 1, color: 'var(--primary)', textTransform: 'uppercase' }}>Bước 2 / 3</p>
        <h2 style={{ margin: '0 0 4px', fontSize: 22 }}>Chọn dạng bài</h2>
        <p style={{ margin: 0, color: 'var(--text-secondary)', fontSize: 14 }}>
          Kỹ năng: <strong style={{ color: meta?.color }}>{meta?.icon} {skill?.title}</strong>
        </p>
      </div>
      <div style={{ display: 'grid', gap: 8 }}>
        {typeOptions.map(opt => (
          <button
            key={opt.value}
            type="button"
            onClick={() => onSelectType(opt.value)}
            style={{ textAlign: 'left', padding: '12px 16px', borderRadius: 12, border: `2px solid ${form.exerciseType === opt.value ? 'var(--primary)' : 'var(--border)'}`, background: form.exerciseType === opt.value ? 'rgba(255,106,20,0.08)' : 'var(--surface-muted)', cursor: 'pointer' }}
          >
            <div style={{ fontWeight: 700, fontSize: 14, marginBottom: 2 }}>{opt.label}</div>
            <div style={{ fontSize: 12, color: 'var(--text-secondary)' }}>{opt.hint}</div>
          </button>
        ))}
      </div>
      <button type="button" onClick={onBack} style={{ alignSelf: 'start', background: 'none', border: 'none', color: 'var(--text-secondary)', cursor: 'pointer', fontSize: 13, padding: 0 }}>
        ← Quay lại chọn kỹ năng
      </button>
    </div>
  );
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
  const [audioGenerating, setAudioGenerating] = useState(false);
  const [audioGenMsg, setAudioGenMsg] = useState<string | null>(null);
  const [wizardStep, setWizardStep] = useState<'skill' | 'type' | 'content'>('skill');
  const [allSkills, setAllSkills] = useState<CmsSkill[]>([]);
  const [showModal, setShowModal] = useState(false);
  const [courses, setCourses] = useState<CmsCourse[]>([]);
  const [mockTests, setMockTests] = useState<CmsMockTest[]>([]);
  const [filterCourseId, setFilterCourseId] = useState('');
  const [filterSkillId, setFilterSkillId] = useState('');
  const [filterMockTestId, setFilterMockTestId] = useState('');

  const editingItem = editingId ? items.find((item) => item.id === editingId) ?? null : null;
  const currentAssets = editingItem?.assets ?? [];

  function resetForm() {
    setEditingId(null);
    setAssetError(null);
    setForm(createInitialFormState());
    setWizardStep('skill');
    setShowModal(false);
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
    loadAllSkills();
    loadCourses();
    loadMockTests();
  }, []);

  async function loadModules() {
    try {
      const res = await fetch('/api/admin/modules');
      const j = await res.json();
      setAvailableModules(j.data ?? []);
    } catch { /* non-fatal */ }
  }

  async function loadCourses() {
    try {
      const res = await fetch('/api/admin/courses');
      const j = await res.json();
      setCourses(j.data ?? []);
    } catch { /* non-fatal */ }
  }

  async function loadMockTests() {
    try {
      const res = await fetch('/api/admin/mock-tests');
      const j = await res.json();
      setMockTests(j.data ?? []);
    } catch { /* non-fatal */ }
  }

  async function loadAllSkills() {
    try {
      const [skillsRes, modulesRes] = await Promise.all([
        fetch('/api/admin/skills'),
        fetch('/api/admin/modules'),
      ]);
      const [skillsJ, modulesJ] = await Promise.all([skillsRes.json(), modulesRes.json()]);
      setAllSkills(skillsJ.data ?? []);
      setAvailableModules(prev => {
        const merged = new Map(prev.map((m: CmsModule) => [m.id, m]));
        for (const m of (modulesJ.data ?? [])) merged.set(m.id, m);
        return Array.from(merged.values());
      });
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
    setWizardStep('content');
    setShowModal(true);
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

  // ── Filtered inventory ─────────────────────────────────────────────────────
  const mtExerciseIds = filterMockTestId
    ? new Set((mockTests.find(t => t.id === filterMockTestId)?.sections ?? []).map(s => s.exercise_id))
    : null;

  const filteredItems = items.filter(item => {
    if (filterSkillId && item.skill_id !== filterSkillId) return false;
    if (filterCourseId) {
      const skill = allSkills.find(s => s.id === item.skill_id);
      const mod = availableModules.find((m: CmsModule) => m.id === skill?.module_id);
      if (mod?.course_id !== filterCourseId) return false;
    }
    if (mtExerciseIds && !mtExerciseIds.has(item.id)) return false;
    return true;
  });

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

      {/* ── Modal overlay ──────────────────────────────────────────────── */}
      {showModal && (
        <div
          onClick={resetForm}
          style={{
            position: 'fixed', inset: 0, zIndex: 100,
            background: 'rgba(20,18,14,0.55)', backdropFilter: 'blur(4px)',
            display: 'flex', alignItems: 'flex-start', justifyContent: 'center',
            padding: '40px 16px', overflowY: 'auto',
          }}
        >
          <div
            onClick={e => e.stopPropagation()}
            style={{
              width: '100%', maxWidth: 520,
              background: 'var(--surface)',
              borderRadius: 28,
              border: '1px solid var(--border)',
              boxShadow: '0 24px 64px rgba(20,18,14,0.22)',
              display: 'grid', gap: 0,
              position: 'relative',
            }}
          >
            {/* Close button */}
            <button
              type="button"
              onClick={resetForm}
              style={{
                position: 'absolute', top: 16, right: 16,
                width: 32, height: 32, borderRadius: '50%',
                border: '1px solid var(--border)',
                background: 'var(--surface-muted)',
                cursor: 'pointer', fontSize: 18, lineHeight: 1,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                color: 'var(--text-secondary)',
              }}
            >×</button>

            <div style={{ padding: 24, display: 'grid', gap: 16 }}>
        {/* ── Wizard: Step 1 — pick skill (creation only) ─────────────── */}
        {!editingId && wizardStep === 'skill' && (
          <div style={{ display: 'grid', gap: 16, padding: 24, borderRadius: 28, background: 'var(--surface)', border: '1px solid var(--border)', boxShadow: 'var(--shadow)' }}>
            <div>
              <p style={{ margin: '0 0 4px', fontSize: 11, fontWeight: 700, letterSpacing: 1, color: 'var(--primary)', textTransform: 'uppercase' }}>Bước 1 / 3</p>
              <h2 style={{ margin: '0 0 4px', fontSize: 22 }}>Chọn kỹ năng</h2>
              <p style={{ margin: 0, color: 'var(--text-secondary)', fontSize: 14 }}>Bài tập sẽ được gắn vào kỹ năng này.</p>
            </div>
            {allSkills.length === 0 ? (
              <p style={{ color: 'var(--text-secondary)', fontSize: 14 }}>Chưa có kỹ năng nào. Tạo skill trong Module trước.</p>
            ) : (
              <div style={{ display: 'grid', gap: 12 }}>
                {(['noi', 'viet', 'nghe', 'doc'] as const).map(kind => {
                  const kindSkills = allSkills.filter(s => s.skill_kind === kind);
                  if (kindSkills.length === 0) return null;
                  const meta = SKILL_KIND_META[kind];
                  return (
                    <div key={kind}>
                      <p style={{ margin: '0 0 6px', fontSize: 11, fontWeight: 700, color: meta.color, textTransform: 'uppercase', letterSpacing: 0.8 }}>
                        {meta.icon} {meta.label}
                      </p>
                      <div style={{ display: 'grid', gap: 4 }}>
                        {kindSkills.map(sk => {
                          const mod = availableModules.find((m: CmsModule) => m.id === sk.module_id);
                          const modLabel = mod?.title ?? `…${sk.module_id.slice(-8)}`;
                          return (
                            <button
                              key={sk.id}
                              type="button"
                              onClick={() => {
                                setForm(f => ({ ...f, skillId: sk.id, moduleId: sk.module_id, exerciseType: SKILL_KIND_EXERCISE_TYPES[kind]?.[0] ?? f.exerciseType }));
                                setWizardStep('type');
                              }}
                              style={{ textAlign: 'left', padding: '8px 12px', borderRadius: 10, border: '1px solid var(--border)', background: 'var(--surface-muted)', cursor: 'pointer' }}
                            >
                              <div style={{ fontWeight: 600, fontSize: 13 }}>{sk.title}</div>
                              <div style={{ fontSize: 11, color: 'var(--text-secondary)', marginTop: 1 }}>Module: {modLabel}</div>
                            </button>
                          );
                        })}
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        )}

        {/* ── Wizard: Step 2 — pick exercise type (creation only) ──────── */}
        {!editingId && wizardStep === 'type' && <WizardTypeStep
          form={form}
          allSkills={allSkills}
          onSelectType={type => { setForm(f => ({ ...f, exerciseType: type })); setWizardStep('content'); }}
          onBack={() => setWizardStep('skill')}
        />}

        {/* ── Step 3: content form (always shown when editing, or after wizard) */}
        {(editingId || wizardStep === 'content') && <form
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
                : form.exerciseType === 'psani_2_email' ? '`Psaní 2 — E-mail`'
                : form.exerciseType.startsWith('poslech_') ? `\`${form.exerciseType.replace('_', ' ').toUpperCase()}\``
                : form.exerciseType.startsWith('cteni_') ? `\`${form.exerciseType.replace('_', ' ').toUpperCase()}\``
                : '`Exercise`'}
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

          {form.exerciseType.startsWith('poslech_') ? (
            <PoslechFields
              form={form}
              setForm={setForm}
              editingId={editingId}
              audioGenerating={audioGenerating}
              audioGenMsg={audioGenMsg}
              onGenerateAudio={async () => {
                if (!editingId) { setAudioGenMsg('Save the draft first.'); return; }
                setAudioGenerating(true); setAudioGenMsg(null);
                try {
                  const res = await fetch(`${adminApi}/${editingId}/generate-audio`, { method: 'POST' });
                  const j = await res.json();
                  if (!res.ok) throw new Error(j.error?.message ?? 'Failed');
                  setAudioGenMsg(`Audio generated: ${j.data?.storage_key ?? 'ok'}`);
                } catch (e) {
                  setAudioGenMsg(e instanceof Error ? e.message : 'Error');
                } finally { setAudioGenerating(false); }
              }}
            />
          ) : null}

          {form.exerciseType.startsWith('cteni_') ? (
            <CteniFields form={form} setForm={setForm} />
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
              style={{ borderRadius: 18, border: '1px solid var(--border)', background: 'var(--surface-muted)', color: 'var(--text)', padding: '12px 18px', cursor: 'pointer', fontWeight: 700 }}
            >
              {S.exercise.cancelEditing}
            </button>
          ) : (
            <button
              type="button"
              onClick={() => setWizardStep('type')}
              style={{ background: 'none', border: 'none', color: 'var(--text-secondary)', cursor: 'pointer', fontSize: 13, padding: 0, textAlign: 'left' }}
            >
              ← Quay lại chọn dạng bài
            </button>
          )}
        </form>}
            </div>{/* end modal inner padding */}
          </div>{/* end modal card */}
        </div>
      )}{/* end modal overlay */}

      {/* ── Inventory — full width ──────────────────────────────────────── */}
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
            <div style={{ display: 'flex', gap: 8 }}>
              <button
                type="button"
                onClick={loadExercises}
                style={{ borderRadius: 16, border: '1px solid var(--border)', background: 'var(--surface-muted)', padding: '10px 14px', cursor: 'pointer', fontWeight: 600 }}
              >
                {S.exercise.refresh}
              </button>
              <button
                type="button"
                onClick={() => { resetForm(); setShowModal(true); }}
                style={{ borderRadius: 16, border: 'none', background: 'var(--primary)', color: '#fff', padding: '10px 18px', cursor: 'pointer', fontWeight: 700, fontSize: 14 }}
              >
                + {S.exercise.createCta}
              </button>
            </div>
          </div>

          {/* ── Filters ───────────────────────────────────────────────────── */}
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
            <select
              value={filterCourseId}
              onChange={e => { setFilterCourseId(e.target.value); setFilterSkillId(''); setFilterMockTestId(''); }}
              style={{ borderRadius: 10, border: '1px solid var(--border)', background: 'var(--surface-muted)', padding: '7px 10px', fontSize: 13, cursor: 'pointer' }}
            >
              <option value="">Tất cả khóa học</option>
              {courses.map(c => <option key={c.id} value={c.id}>{c.title}</option>)}
            </select>

            <select
              value={filterSkillId}
              onChange={e => { setFilterSkillId(e.target.value); setFilterMockTestId(''); }}
              style={{ borderRadius: 10, border: '1px solid var(--border)', background: 'var(--surface-muted)', padding: '7px 10px', fontSize: 13, cursor: 'pointer' }}
            >
              <option value="">Tất cả kỹ năng</option>
              {allSkills.map(sk => (
                <option key={sk.id} value={sk.id}>
                  {SKILL_KIND_META[sk.skill_kind]?.icon} {sk.title}
                </option>
              ))}
            </select>

            <select
              value={filterMockTestId}
              onChange={e => { setFilterMockTestId(e.target.value); setFilterCourseId(''); setFilterSkillId(''); }}
              style={{ borderRadius: 10, border: '1px solid var(--border)', background: 'var(--surface-muted)', padding: '7px 10px', fontSize: 13, cursor: 'pointer' }}
            >
              <option value="">Tất cả đề thi</option>
              {mockTests.map(mt => <option key={mt.id} value={mt.id}>{mt.title}</option>)}
            </select>

            {(filterCourseId || filterSkillId || filterMockTestId) && (
              <button
                type="button"
                onClick={() => { setFilterCourseId(''); setFilterSkillId(''); setFilterMockTestId(''); }}
                style={{ background: 'none', border: 'none', color: 'var(--primary)', cursor: 'pointer', fontSize: 13, fontWeight: 600, padding: '0 4px' }}
              >
                ✕ Xoá filter
              </button>
            )}
            <span style={{ fontSize: 12, color: 'var(--text-secondary)', marginLeft: 4 }}>
              {filteredItems.length} / {items.length} bài tập
            </span>
          </div>

          {error ? (
            <p style={{ margin: 0, color: 'var(--danger)' }}>{error}</p>
          ) : null}

          {loading ? <p style={{ margin: 0 }}>Loading exercises...</p> : null}

          <div style={{ display: 'grid', gap: 12 }}>
            {filteredItems.map((item) => (
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
    </main>
  );
}

type CteniFieldsProps = {
  form: ExerciseFormState;
  setForm: React.Dispatch<React.SetStateAction<ExerciseFormState>>;
};

function CteniFields({ form, setForm }: CteniFieldsProps) {
  const isCteni1 = form.exerciseType === 'cteni_1';
  const isCteni3 = form.exerciseType === 'cteni_3';
  const isCteni5 = form.exerciseType === 'cteni_5';
  const needsText = form.exerciseType === 'cteni_2' || form.exerciseType === 'cteni_4' || isCteni5;
  const needsItems = isCteni1 || isCteni3;

  return (
    <>
      {needsText && (
        <label style={{ display: 'grid', gap: 6 }}>
          <span style={fieldLabelStyle}>Đoạn văn đọc</span>
          <textarea
            rows={8}
            value={form.cteniText}
            onChange={e => setForm(f => ({ ...f, cteniText: e.target.value }))}
            style={fieldStyle}
            placeholder="Přečtěte si text..."
          />
        </label>
      )}

      {needsItems && (
        <label style={{ display: 'grid', gap: 6 }}>
          <span style={fieldLabelStyle}>
            {isCteni1 ? 'Các ảnh/tin nhắn (phân cách bằng ---)' : 'Các đoạn văn (phân cách bằng ---)'}
          </span>
          <textarea
            rows={8}
            value={form.cteniItems}
            onChange={e => setForm(f => ({ ...f, cteniItems: e.target.value }))}
            style={fieldStyle}
            placeholder={'Item 1...\n---\nItem 2...\n---\nItem 3...'}
          />
          <span style={fieldHintStyle}>
            {isCteni1 ? 'Cteni 1: 5 items. Dùng asset IDs hoặc text tin nhắn.' : 'Cteni 3: 4 đoạn văn.'}
          </span>
        </label>
      )}

      <label style={{ display: 'grid', gap: 6 }}>
        <span style={fieldLabelStyle}>
          {isCteni3 ? 'Nhân vật A-E (key | tên)' : isCteni1 ? 'Options A-H (key | nội dung)' : 'Options A-D (key | nội dung)'}
        </span>
        <textarea
          rows={isCteni1 ? 8 : isCteni3 ? 5 : 4}
          value={form.cteniOptions}
          onChange={e => setForm(f => ({ ...f, cteniOptions: e.target.value }))}
          style={fieldStyle}
          placeholder={isCteni3 ? 'A | Jana (IT)\nB | Petr (student)' : 'A | Celodenní parkování zdarma.'}
        />
      </label>

      {!isCteni1 && !isCteni3 && (
        <label style={{ display: 'grid', gap: 6 }}>
          <span style={fieldLabelStyle}>
            {isCteni5 ? 'Câu hỏi fill-in (1 câu/dòng)' : 'Câu hỏi (1 câu/dòng)'}
          </span>
          <textarea
            rows={6}
            value={form.cteniQuestions}
            onChange={e => setForm(f => ({ ...f, cteniQuestions: e.target.value }))}
            style={fieldStyle}
            placeholder={isCteni5 ? 'Podle receptu můžeme připravit...\nNa salát potřebujeme...' : 'Kdy se koná slavnostní otevření?\nKdo může zdarma...'}
          />
        </label>
      )}

      <label style={{ display: 'grid', gap: 6 }}>
        <span style={fieldLabelStyle}>Đáp án đúng (1=A, 2=B, ...)</span>
        <textarea
          rows={6}
          value={form.cteniCorrectAnswers}
          onChange={e => setForm(f => ({ ...f, cteniCorrectAnswers: e.target.value }))}
          style={fieldStyle}
          placeholder={isCteni5 ? '21=bramborový salát\n22=velkou cibuli' : '1=H\n2=A\n3=C\n4=D\n5=F'}
        />
        <span style={fieldHintStyle}>
          {isCteni5 ? 'Fill-in: so khớp substring (không phân biệt hoa/thường).' : 'Multiple choice: exact match key (A/B/C/D).'}
        </span>
      </label>
    </>
  );
}

type PoslechFieldsProps = {
  form: ExerciseFormState;
  setForm: React.Dispatch<React.SetStateAction<ExerciseFormState>>;
  editingId: string | null;
  audioGenerating: boolean;
  audioGenMsg: string | null;
  onGenerateAudio: () => void;
};

function PoslechFields({ form, setForm, editingId, audioGenerating, audioGenMsg, onGenerateAudio }: PoslechFieldsProps) {
  const isPoslech5 = form.exerciseType === 'poslech_5';
  const isPoslech4 = form.exerciseType === 'poslech_4';
  const isPoslech3 = form.exerciseType === 'poslech_3';

  return (
    <>
      {/* Audio source */}
      <div style={{ display: 'grid', gap: 6 }}>
        <span style={fieldLabelStyle}>Nguồn audio</span>
        <div style={{ display: 'flex', gap: 16 }}>
          {(['text', 'upload'] as const).map(src => (
            <label key={src} style={{ display: 'flex', gap: 6, cursor: 'pointer', alignItems: 'center' }}>
              <input
                type="radio"
                value={src}
                checked={form.poslechAudioSource === src}
                onChange={() => setForm(f => ({ ...f, poslechAudioSource: src }))}
              />
              {src === 'text' ? 'Nhập text → Polly TTS' : 'Upload file audio'}
            </label>
          ))}
        </div>
      </div>

      {/* Text input for Polly */}
      {form.poslechAudioSource === 'text' && (
        <>
          {isPoslech5 ? (
            <label style={{ display: 'grid', gap: 6 }}>
              <span style={fieldLabelStyle}>Nội dung voicemail (mỗi dòng = 1 câu)</span>
              <textarea
                rows={6}
                value={form.poslechVoicemailText}
                onChange={e => setForm(f => ({ ...f, poslechVoicemailText: e.target.value }))}
                style={fieldStyle}
                placeholder="Ahoj Lído, tady Eva.&#10;Dostala jsem lístky na balet."
              />
            </label>
          ) : (
            <label style={{ display: 'grid', gap: 6 }}>
              <span style={fieldLabelStyle}>Nội dung từng item (phân cách bằng dòng ---)</span>
              <textarea
                rows={8}
                value={form.poslechItems}
                onChange={e => setForm(f => ({ ...f, poslechItems: e.target.value }))}
                style={fieldStyle}
                placeholder={'Item 1 text...\n---\nItem 2 text...\n---\nItem 3 text...'}
              />
              <span style={fieldHintStyle}>Mỗi block là 1 câu hỏi. Dùng --- để phân cách.</span>
            </label>
          )}

          {/* Generate audio button */}
          <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
            <button
              type="button"
              onClick={onGenerateAudio}
              disabled={audioGenerating || !editingId}
              style={{
                ...secondaryActionStyle,
                opacity: (audioGenerating || !editingId) ? 0.5 : 1,
              }}
            >
              {audioGenerating ? 'Đang tạo...' : 'Tạo audio (Polly)'}
            </button>
            {audioGenMsg && <span style={fieldHintStyle}>{audioGenMsg}</span>}
          </div>
        </>
      )}

      {/* Options */}
      {(isPoslech3 || isPoslech4) && (
        <label style={{ display: 'grid', gap: 6 }}>
          <span style={fieldLabelStyle}>
            {isPoslech4 ? 'Options A-F (key | asset_id)' : 'Options A-G (key | label)'}
          </span>
          <textarea
            rows={7}
            value={form.poslechOptions}
            onChange={e => setForm(f => ({ ...f, poslechOptions: e.target.value }))}
            style={fieldStyle}
            placeholder={isPoslech4 ? 'A | asset-id-1\nB | asset-id-2' : 'A | Koníček: běh\nB | Koníček: vaření'}
          />
        </label>
      )}

      {!isPoslech3 && !isPoslech4 && !isPoslech5 && (
        <label style={{ display: 'grid', gap: 6 }}>
          <span style={fieldLabelStyle}>Options A-D (key | text)</span>
          <textarea
            rows={4}
            value={form.poslechOptions}
            onChange={e => setForm(f => ({ ...f, poslechOptions: e.target.value }))}
            style={fieldStyle}
            placeholder="A | Možnost A\nB | Možnost B\nC | Možnost C\nD | Možnost D"
          />
        </label>
      )}

      {/* Correct answers */}
      <label style={{ display: 'grid', gap: 6 }}>
        <span style={fieldLabelStyle}>Đáp án đúng (1=B, 2=A, ...)</span>
        <textarea
          rows={5}
          value={form.poslechCorrectAnswers}
          onChange={e => setForm(f => ({ ...f, poslechCorrectAnswers: e.target.value }))}
          style={fieldStyle}
          placeholder="1=B\n2=A\n3=D\n4=C\n5=B"
        />
        <span style={fieldHintStyle}>Fill-in (poslech_5): nhập toàn bộ nội dung câu trả lời, so khớp substring.</span>
      </label>
    </>
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
