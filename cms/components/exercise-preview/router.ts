// V23 Phase C7 — pure routing helper for preview pane. Top 5 V23
// types render dedicated previews; everything else falls back to a
// placeholder card pointing the admin at Flutter for verification.

export type PreviewRendererName = 'uloha' | 'psani-email' | 'placeholder';

export function selectPreviewRenderer(exerciseType: string): PreviewRendererName {
  if (
    exerciseType === 'uloha_1_topic_answers' ||
    exerciseType === 'uloha_2_dialogue_questions' ||
    exerciseType === 'uloha_3_story_narration' ||
    exerciseType === 'uloha_4_choice_reasoning'
  ) {
    return 'uloha';
  }
  if (exerciseType === 'psani_2_email') {
    return 'psani-email';
  }
  return 'placeholder';
}
