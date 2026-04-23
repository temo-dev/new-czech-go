class AppLocale {
  static const vi = 'vi';
  static const en = 'en';

  static const defaultCode = vi;

  static const List<String> all = [vi, en];

  static bool isSupported(String code) => all.contains(code);

  static String normalize(String? code) {
    if (code == null) return defaultCode;
    final trimmed = code.trim().toLowerCase();
    if (isSupported(trimmed)) return trimmed;
    return defaultCode;
  }

  static String label(String code) {
    switch (code) {
      case en:
        return 'English';
      case vi:
      default:
        return 'Tiếng Việt';
    }
  }
}
