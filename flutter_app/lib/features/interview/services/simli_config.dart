/// Build-time constants for Simli credentials.
///
/// Provide at runtime via dart-define:
///   flutter run --dart-define=SIMLI_API_KEY=... --dart-define=SIMLI_FACE_ID=... --dart-define=SIMLI_MODEL=artalk
///
/// This file has NO native dependencies so it is safe to import in unit tests.
abstract final class SimliConfig {
  static const apiKey = String.fromEnvironment(
    'SIMLI_API_KEY',
    defaultValue: '',
  );

  static const faceId = String.fromEnvironment(
    'SIMLI_FACE_ID',
    defaultValue: 'default',
  );

  /// Simli supports `fasttalk` and `artalk`; `artalk` favors visual quality.
  static const model = String.fromEnvironment(
    'SIMLI_MODEL',
    defaultValue: 'artalk',
  );
}
