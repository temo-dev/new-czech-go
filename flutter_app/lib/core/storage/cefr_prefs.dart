import 'package:shared_preferences/shared_preferences.dart';

/// Owns the V21.3 CEFR-related SharedPreferences keys.
///
/// Two flags live here:
///   - `cefr_existing_prompt_shown` — flipped after an existing-A2
///     learner has answered the one-time confirm dialog.
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

  bool get isExistingPromptShown => _prefs.getBool(_existingPromptKey) ?? false;

  Future<void> markExistingPromptShown() {
    return _prefs.setBool(_existingPromptKey, true);
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
      throw ArgumentError.value(level, 'level', 'must be a non-empty CEFR level');
    }
  }
}
