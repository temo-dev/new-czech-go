/// Compile-time environment config.
/// Values injected via --dart-define-from-file=env.<flavor>.json
/// Never put real secrets in source control.
abstract final class AppEnv {
  static const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
  static const appName =
      String.fromEnvironment('APP_NAME', defaultValue: 'Czech Exam');
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isDev => flavor == 'dev';
  static bool get isStaging => flavor == 'staging';
  static bool get isProd => flavor == 'prod';

  static void validate() {
    assert(supabaseUrl.isNotEmpty, 'SUPABASE_URL must be set');
    assert(supabaseAnonKey.isNotEmpty, 'SUPABASE_ANON_KEY must be set');
  }
}
