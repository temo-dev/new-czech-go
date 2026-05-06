import '../../l10n/generated/app_localizations.dart';

/// Resolves a skill_kind token (as used by the V19 progress API) to its
/// localised display name. Centralised so HomeProgressCard, ProgressDetailScreen
/// and the profile entry tile all surface the same copy without duplicating
/// the switch statement.
///
/// Falls back to the raw token when an unknown skill_kind arrives — that
/// keeps the UI from showing an empty string if the backend ships a new
/// skill before the client picks up new ARB keys.
String skillKindLabel(AppLocalizations l, String kind) {
  switch (kind) {
    case 'noi':
      return l.progressSkillNoi;
    case 'viet':
      return l.progressSkillViet;
    case 'nghe':
      return l.progressSkillNghe;
    case 'doc':
      return l.progressSkillDoc;
    case 'tu_vung':
      return l.progressSkillTuVung;
    case 'ngu_phap':
      return l.progressSkillNguPhap;
    case 'interview':
      return l.progressSkillInterview;
    default:
      return kind;
  }
}
