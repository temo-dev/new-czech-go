import 'package:shared_preferences/shared_preferences.dart';

class VoicePreferenceService {
  const VoicePreferenceService._(this._prefs);

  static const _key = 'pref_voice_id';

  final SharedPreferences _prefs;

  static Future<VoicePreferenceService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return VoicePreferenceService._(prefs);
  }

  /// Currently selected voice slug, or empty string if none chosen.
  String get current => _prefs.getString(_key) ?? '';

  Future<void> save(String voiceId) => _prefs.setString(_key, voiceId);
}
