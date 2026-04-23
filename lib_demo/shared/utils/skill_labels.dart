import 'package:app_czech/shared/models/question_model.dart';

/// Shared Vietnamese labels for skill areas.
/// Use these instead of duplicating the map in every widget.
abstract final class SkillLabels {
  static const Map<String, String> byKey = {
    'reading': 'Đọc hiểu',
    'listening': 'Nghe hiểu',
    'writing': 'Viết',
    'speaking': 'Nói',
    'grammar': 'Ngữ pháp',
    'vocabulary': 'Từ vựng',
  };

  static String forKey(String key) => byKey[key.toLowerCase()] ?? key;

  static String forArea(SkillArea area) => switch (area) {
        SkillArea.reading => 'Đọc hiểu',
        SkillArea.listening => 'Nghe hiểu',
        SkillArea.writing => 'Viết',
        SkillArea.speaking => 'Nói',
        SkillArea.grammar => 'Ngữ pháp',
        SkillArea.vocabulary => 'Từ vựng',
      };
}
