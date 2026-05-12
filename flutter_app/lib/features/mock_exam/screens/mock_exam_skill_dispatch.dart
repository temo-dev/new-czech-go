import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';

// V36 — mock-exam dispatcher helpers extracted so the unit test can
// cover skill_kind routing without rendering MockExamScreen. interview
// is mapped to the dedicated InterviewSessionScreen by _runSection;
// other kinds keep their pre-V36 routing.

String skillKindForExerciseType(String exerciseType) {
  if (exerciseType.startsWith('uloha_')) return 'noi';
  if (exerciseType.startsWith('poslech_')) return 'nghe';
  if (exerciseType.startsWith('cteni_')) return 'doc';
  if (exerciseType.startsWith('psani_')) return 'viet';
  if (exerciseType.startsWith('interview_')) return 'interview';
  return 'noi';
}

String sectionSkillKind(MockExamSection section) {
  return section.skillKind.isNotEmpty
      ? section.skillKind
      : skillKindForExerciseType(section.exerciseType);
}

String skillLabel(AppLocalizations l, String skillKind) => switch (skillKind) {
  'noi' => l.skillNoi,
  'nghe' => l.skillNghe,
  'doc' => l.skillDoc,
  'viet' => l.skillViet,
  'interview' => l.skillInterview,
  _ => skillKind.toUpperCase(),
};
