import 'package:shared_preferences/shared_preferences.dart';

/// Owns the V21.3 CEFR-related SharedPreferences keys.
///
/// Two flag families live here:
///   - `cefr_existing_prompt_shown_<user>_<level>` — flipped after an
///     existing-level learner has answered the one-time confirm dialog.
///   - `promo_banner_dismissed_for_<level>` — flipped after the
///     learner has passed the promotion exam for that target level
///     so the banner does not return for the same target.
///
/// All read/write of these keys must go through this helper. Direct
/// `SharedPreferences.getInstance()` calls for the raw key strings
/// will be rejected in code review.
class CefrPrefs {
  CefrPrefs._(this._prefs);

  static const _existingPromptKey = 'cefr_existing_prompt_shown';
  static const _bannerDismissPrefix = 'promo_banner_dismissed_for_';

  final SharedPreferences _prefs;

  static Future<CefrPrefs> create() async {
    final prefs = await SharedPreferences.getInstance();
    return CefrPrefs._(prefs);
  }

  bool isExistingPromptShownFor({
    required String userID,
    required String level,
  }) {
    return _prefs.getBool(_existingPromptKeyFor(userID, level)) ?? false;
  }

  Future<void> markExistingPromptShownFor({
    required String userID,
    required String level,
  }) {
    return _prefs.setBool(_existingPromptKeyFor(userID, level), true);
  }

  bool isBannerDismissedFor(String level) {
    _requireLevel(level);
    return _prefs.getBool('$_bannerDismissPrefix$level') ?? false;
  }

  Future<void> dismissBannerFor(String level) {
    _requireLevel(level);
    return _prefs.setBool('$_bannerDismissPrefix$level', true);
  }

  static void _requireLevel(String level) {
    if (level.isEmpty) {
      throw ArgumentError.value(
        level,
        'level',
        'must be a non-empty CEFR level',
      );
    }
  }

  static String _existingPromptKeyFor(String userID, String level) {
    final trimmedUserID = userID.trim();
    final trimmedLevel = level.trim();
    if (trimmedUserID.isEmpty) {
      throw ArgumentError.value(userID, 'userID', 'must be non-empty');
    }
    _requireLevel(trimmedLevel);
    return '${_existingPromptKey}_${_safeKeyPart(trimmedUserID)}_${_safeKeyPart(trimmedLevel)}';
  }

  static String _safeKeyPart(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
  }
}
