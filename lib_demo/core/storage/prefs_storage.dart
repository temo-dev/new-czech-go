import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Wrapper for non-sensitive user preferences.
class PrefsStorage {
  PrefsStorage._(this._prefs);

  final SharedPreferences _prefs;
  static PrefsStorage? _instance;

  /// Raw prefs access for ad-hoc keys (e.g. exam answer buffering).
  SharedPreferences get prefs => _prefs;

  static Future<PrefsStorage> init() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(PrefsKeys.guestAccessToken)) {
      await prefs.setString(PrefsKeys.guestAccessToken, const Uuid().v4());
    }
    _instance = PrefsStorage._(prefs);
    return _instance!;
  }

  static PrefsStorage get instance {
    assert(_instance != null,
        'Call PrefsStorage.init() before accessing instance');
    return _instance!;
  }

  bool get onboardingComplete =>
      _prefs.getBool(PrefsKeys.onboardingComplete) ?? false;

  Future<void> setOnboardingComplete(bool value) =>
      _prefs.setBool(PrefsKeys.onboardingComplete, value);

  String get locale => _prefs.getString(PrefsKeys.locale) ?? 'vi';

  Future<void> setLocale(String locale) =>
      _prefs.setString(PrefsKeys.locale, locale);

  String? get pendingAttemptId => _prefs.getString(PrefsKeys.pendingAttemptId);

  String get guestAccessToken => _prefs.getString(PrefsKeys.guestAccessToken)!;

  Future<void> setPendingAttemptId(String id) =>
      _prefs.setString(PrefsKeys.pendingAttemptId, id);

  Future<void> clearPendingAttemptId() =>
      _prefs.remove(PrefsKeys.pendingAttemptId);

  Future<void> clear() => _prefs.clear();
}

abstract final class PrefsKeys {
  static const onboardingComplete = 'onboarding_complete';
  static const locale = 'locale';
  static const pendingAttemptId = 'pending_attempt_id';
  static const guestAccessToken = 'guest_access_token';
}
