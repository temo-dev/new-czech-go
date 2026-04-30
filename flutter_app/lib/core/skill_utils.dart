import 'package:flutter/material.dart';
import 'package:flutter_app/l10n/generated/app_localizations.dart';

String skillKindForExerciseType(String exerciseType) {
  if (exerciseType.startsWith('uloha_')) return 'noi';
  if (exerciseType.startsWith('psani_')) return 'viet';
  if (exerciseType.startsWith('poslech_')) return 'nghe';
  if (exerciseType.startsWith('cteni_')) return 'doc';
  return '';
}

String skillLabel(AppLocalizations l, String skillKind) => switch (skillKind) {
      'noi' => l.skillNoi,
      'nghe' => l.skillNghe,
      'doc' => l.skillDoc,
      'viet' => l.skillViet,
      'tu_vung' => l.skillTuVung,
      'ngu_phap' => l.skillNguPhap,
      _ => skillKind.toUpperCase(),
    };

IconData skillIcon(String skillKind) => switch (skillKind) {
      'noi' => Icons.mic,
      'nghe' => Icons.headphones,
      'doc' => Icons.menu_book,
      'viet' => Icons.edit,
      'tu_vung' => Icons.abc,
      'ngu_phap' => Icons.rule,
      _ => Icons.school,
    };
