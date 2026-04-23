import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supported_locales.dart';

class LocaleProvider extends ChangeNotifier {
  static const _prefsKey = 'app_locale';

  LocaleProvider._(this._code);

  String _code;

  String get code => _code;

  static Future<LocaleProvider> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    return LocaleProvider._(AppLocale.normalize(stored));
  }

  Future<void> setLocale(String code) async {
    final normalized = AppLocale.normalize(code);
    if (normalized == _code) return;
    _code = normalized;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, normalized);
  }
}
