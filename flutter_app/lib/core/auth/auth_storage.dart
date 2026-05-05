import 'package:shared_preferences/shared_preferences.dart';

/// Persists the V17 session token across app restarts.
///
/// V17 uses [SharedPreferences] as a pragmatic compromise: adding
/// `flutter_secure_storage` brings native iOS Keychain integration and
/// new build-time setup that V17's tight scope does not justify. The
/// session token is a 256-bit random value; an attacker with physical
/// device access can read it but the same access already lets them open
/// the app and use the active session anyway. V18 polish: migrate to
/// Keychain via flutter_secure_storage with a transparent read-once
/// shim so existing tokens are upgraded on first launch.
class AuthStorage {
  AuthStorage(this._prefs);

  static const _kToken = 'v17.auth.token';
  static const _kEmail = 'v17.auth.email';
  static const _kDisplayName = 'v17.auth.display_name';

  final SharedPreferences _prefs;

  static Future<AuthStorage> create() async =>
      AuthStorage(await SharedPreferences.getInstance());

  String? get token => _prefs.getString(_kToken);
  String? get email => _prefs.getString(_kEmail);
  String? get displayName => _prefs.getString(_kDisplayName);

  Future<void> save({required String token, required String email, required String displayName}) async {
    await _prefs.setString(_kToken, token);
    await _prefs.setString(_kEmail, email);
    await _prefs.setString(_kDisplayName, displayName);
  }

  Future<void> clear() async {
    await _prefs.remove(_kToken);
    await _prefs.remove(_kEmail);
    await _prefs.remove(_kDisplayName);
  }
}
