import 'package:shared_preferences/shared_preferences.dart';

class InterviewPreferenceService {
  const InterviewPreferenceService._(this._prefs);

  static const _avatarEnabledKey = 'pref_interview_avatar_enabled';
  static const _localAudioVolumeKey = 'pref_interview_local_audio_volume';

  static const double minLocalAudioVolume = 1.0;
  static const double maxLocalAudioVolume = 1.8;
  static const double defaultLocalAudioVolume = 1.35;

  final SharedPreferences _prefs;

  static Future<InterviewPreferenceService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return InterviewPreferenceService._(prefs);
  }

  /// Simli is opt-in because avatar playback can lag far behind agent audio.
  bool get avatarEnabled => _prefs.getBool(_avatarEnabledKey) ?? false;

  Future<void> setAvatarEnabled(bool enabled) {
    return _prefs.setBool(_avatarEnabledKey, enabled);
  }

  /// Gain applied to local sound-wave interview audio.
  ///
  /// The default is intentionally above 1.0 because direct PCM playback is
  /// quieter than the WebRTC avatar audio on iOS devices.
  double get localAudioVolume {
    return normalizeLocalAudioVolume(
      _prefs.getDouble(_localAudioVolumeKey) ?? defaultLocalAudioVolume,
    );
  }

  Future<void> setLocalAudioVolume(double volume) {
    return _prefs.setDouble(
      _localAudioVolumeKey,
      normalizeLocalAudioVolume(volume),
    );
  }

  /// One-shot read for interview startup without threading a service instance.
  static Future<bool> readAvatarEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_avatarEnabledKey) ?? false;
  }

  static Future<double> readLocalAudioVolume() async {
    final prefs = await SharedPreferences.getInstance();
    return normalizeLocalAudioVolume(
      prefs.getDouble(_localAudioVolumeKey) ?? defaultLocalAudioVolume,
    );
  }

  static double normalizeLocalAudioVolume(double volume) {
    if (volume.isNaN || volume.isInfinite) return defaultLocalAudioVolume;
    return volume.clamp(minLocalAudioVolume, maxLocalAudioVolume).toDouble();
  }
}
