// Models for the V17 self-serve auth flow. Kept separate from
// ApiClient so the rest of the app can describe auth state without
// importing the network layer.

/// Coarse-grained state machine that drives the AppShell router.
///
/// `loading` is the bootstrap window (read token from storage, hit
/// /v1/users/me to validate); `unauthenticated` shows the welcome /
/// login flow; `needsVerify` keeps the learner inside the app but
/// blocks gated endpoints once the grace allowance is exhausted; and
/// `authenticated` is the normal happy state.
enum AuthState {
  loading,
  unauthenticated,
  needsVerify,
  authenticated,
}

/// AuthUser is the tiny client-side projection of the V17
/// `/v1/users/me` payload — only the fields the app actually renders.
/// The pro_tier + grace counters drive the verify banner and Pro chip;
/// onboarding fields are echoed back to the profile editor.
class AuthUser {
  AuthUser({
    required this.id,
    required this.email,
    required this.emailVerified,
    required this.displayName,
    required this.role,
    required this.proTier,
    required this.graceAttemptsLeft,
    this.avatarAssetId,
    this.onboardingGoal,
    this.onboardingLevel,
    this.dailyReminderAt,
    this.timezone,
  });

  final String id;
  final String email;
  final bool emailVerified;
  final String displayName;
  final String role;
  final String proTier;
  final int graceAttemptsLeft;
  final String? avatarAssetId;
  final String? onboardingGoal;
  final String? onboardingLevel;
  final String? dailyReminderAt;
  final String? timezone;

  bool get isPro => proTier == 'pro';

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      emailVerified: json['email_verified'] as bool? ?? false,
      displayName: json['display_name'] as String? ?? '',
      role: json['role'] as String? ?? 'learner',
      proTier: json['pro_tier'] as String? ?? 'free',
      graceAttemptsLeft: (json['grace_attempts_left'] as num?)?.toInt() ?? 0,
      avatarAssetId: json['avatar_asset_id'] as String?,
      onboardingGoal: json['onboarding_goal'] as String?,
      onboardingLevel: json['onboarding_level'] as String?,
      dailyReminderAt: json['daily_reminder_at'] as String?,
      timezone: json['timezone'] as String?,
    );
  }
}

/// Result of a successful signup or login. The auth handler dispatches
/// the email verify on a goroutine so the client treats the missing
/// `email_verified` flag as the trigger for the VerifyPending screen.
class AuthSession {
  AuthSession({required this.user, required this.token, required this.expiresAt});

  final AuthUser user;
  final String token;
  final DateTime expiresAt;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      token: json['session_token'] as String? ?? '',
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? '') ?? DateTime.now().add(const Duration(days: 30)),
    );
  }
}

/// A typed exception the V17 auth surface throws. The `code` is what
/// the UI switches on (e.g. `email_taken`, `invalid_credentials`,
/// `weak_password`); the `message` is the server's human string for
/// the error toast.
class AuthException implements Exception {
  AuthException({required this.statusCode, required this.code, required this.message});

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => 'AuthException($statusCode, $code): $message';
}
