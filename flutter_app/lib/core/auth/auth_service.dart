import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../api/api_client.dart';
import 'auth_models.dart';
import 'auth_storage.dart';

/// Owns the V17 auth state machine. Wraps [ApiClient] for the network
/// path and [AuthStorage] for cross-launch persistence. UI listens via
/// [ChangeNotifier] / [ValueListenable] for state changes.
///
/// Bootstrap flow (called once from `main()`):
///   1. Read the saved session token from storage.
///   2. If absent -> [AuthState.unauthenticated].
///   3. If present -> attach to ApiClient, call /v1/users/me, accept
///      whatever the server returns. A 401 means the token was revoked
///      (log-out-on-other-device, password reset, etc.) and the local
///      copy is wiped.
///
/// Mutation API (signup / login / logout / refresh) updates state in
/// the SAME tick the network call resolves so widgets that listen to
/// the notifier rebuild without an extra setState.
/// Sign-in-with-Apple credential factory. Wraps
/// `SignInWithApple.getAppleIDCredential` so unit tests can inject a
/// deterministic credential without a running iOS simulator.
typedef AppleCredentialFn = Future<AuthorizationCredentialAppleID> Function({
  required List<AppleIDAuthorizationScopes> scopes,
  required String nonce,
});

class AuthService extends ChangeNotifier {
  AuthService({
    required ApiClient apiClient,
    required AuthStorage storage,
    AppleCredentialFn? appleCredential,
  })  : _api = apiClient,
        _storage = storage,
        _appleCredential = appleCredential ?? _defaultAppleCredential;

  final ApiClient _api;
  final AuthStorage _storage;
  final AppleCredentialFn _appleCredential;

  static Future<AuthorizationCredentialAppleID> _defaultAppleCredential({
    required List<AppleIDAuthorizationScopes> scopes,
    required String nonce,
  }) =>
      SignInWithApple.getAppleIDCredential(scopes: scopes, nonce: nonce);

  AuthState _state = AuthState.loading;
  AuthUser? _user;

  AuthState get state => _state;
  AuthUser? get currentUser => _user;
  bool get isAuthenticated => _state == AuthState.authenticated || _state == AuthState.needsVerify;

  /// Read-only handle on the underlying [ApiClient] for screens that
  /// need to call public V17 endpoints without changing auth state
  /// (forgot-password, reset-password, etc). Mutating screens
  /// (signup/login/logout) MUST go through the AuthService methods so
  /// the state machine stays consistent.
  ApiClient get apiClientForScreens => _api;

  /// Bootstrap from persisted state. Safe to call more than once; a
  /// later call short-circuits if the state is already settled.
  Future<void> bootstrap() async {
    final savedToken = _storage.token;
    if (savedToken == null || savedToken.isEmpty) {
      _setState(AuthState.unauthenticated);
      return;
    }
    _api.setAuthToken(savedToken);
    try {
      final user = await _api.getMeV17();
      _adoptUser(user);
    } on AuthException catch (e) {
      if (e.statusCode == 401) {
        await _clearLocal();
        _setState(AuthState.unauthenticated);
      } else {
        // Network error / server hiccup — keep the saved token, allow
        // the user into the app, and let the next 401 from any
        // authenticated call evict them.
        _setState(AuthState.authenticated);
      }
    } catch (_) {
      _setState(AuthState.authenticated);
    }
  }

  Future<AuthSession> signup({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final session = await _api.signupV17(
      email: email,
      password: password,
      displayName: displayName,
    );
    await _persistSession(session);
    _adoptUser(session.user);
    return session;
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final session = await _api.loginV17(email: email, password: password);
    await _persistSession(session);
    _adoptUser(session.user);
    return session;
  }

  /// V25 — Sign in with Apple. Generates a fresh nonce per call,
  /// hashes it (Apple's recommended replay guard), invokes the native
  /// credential sheet, and posts the resulting identity_token to the
  /// backend. Surfaces canceled and platform errors as [AuthException]
  /// so the UI can handle all auth errors uniformly.
  Future<AuthSession> signInWithApple() async {
    final rawNonce = _generateRawNonce();
    final hashedNonce = _sha256Hex(rawNonce);

    final AuthorizationCredentialAppleID credential;
    try {
      credential = await _appleCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      throw AuthException(
        statusCode: 0,
        code: e.code == AuthorizationErrorCode.canceled
            ? 'sign_in_canceled'
            : 'apple_sign_in_failed',
        message: e.message,
      );
    }

    final identityToken = credential.identityToken;
    if (identityToken == null || identityToken.isEmpty) {
      throw AuthException(
        statusCode: 0,
        code: 'invalid_credential',
        message: 'Apple did not return a usable identity token.',
      );
    }

    final session = await _api.signInWithAppleV25(
      identityToken: identityToken,
      authorizationCode: credential.authorizationCode,
      nonce: hashedNonce,
      givenName: credential.givenName,
      familyName: credential.familyName,
    );
    await _persistSession(session);
    _adoptUser(session.user);
    return session;
  }

  Future<void> logout() async {
    try {
      await _api.logoutV17();
    } on AuthException {
      // Server-side revoke best-effort; local state is the truth here.
    }
    await _clearLocal();
    _setState(AuthState.unauthenticated);
  }

  /// Refresh the cached user payload from /v1/users/me. The Profile
  /// screen calls this after a PATCH so the AppShell + Home rerender
  /// with the new values.
  Future<void> refresh() async {
    try {
      final user = await _api.getMeV17();
      _adoptUser(user);
    } on AuthException catch (e) {
      if (e.statusCode == 401) {
        await _clearLocal();
        _setState(AuthState.unauthenticated);
      }
    }
  }

  /// Apply a freshly-fetched user without doing a network round trip.
  /// Used by the Profile screen after a successful PATCH so we do not
  /// need to re-issue /me just to refresh the cache.
  void adoptUser(AuthUser user) => _adoptUser(user);

  void _adoptUser(AuthUser user) {
    _user = user;
    final next = (!user.emailVerified && user.graceAttemptsLeft <= 0)
        ? AuthState.needsVerify
        : AuthState.authenticated;
    if (_state == next) {
      // State unchanged but user fields (display_name, avatar_asset_id, …)
      // may have been mutated by /v1/users/me refresh. Always notify so
      // listeners pick up the new payload.
      notifyListeners();
    } else {
      _setState(next);
    }
  }

  Future<void> _persistSession(AuthSession session) async {
    await _storage.save(
      token: session.token,
      email: session.user.email,
      displayName: session.user.displayName,
    );
  }

  Future<void> _clearLocal() async {
    _user = null;
    _api.setAuthToken(null);
    await _storage.clear();
  }

  void _setState(AuthState next) {
    if (_state == next) return;
    _state = next;
    notifyListeners();
  }

  /// 32-character random nonce. Apple recommends ≥ 32 chars; we draw
  /// from a URL-safe alphabet so the value can be passed verbatim
  /// through any wire format without escaping.
  String _generateRawNonce({int length = 32}) {
    const charset =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._';
    final rng = Random.secure();
    return List.generate(length, (_) => charset[rng.nextInt(charset.length)])
        .join();
  }

  String _sha256Hex(String input) =>
      sha256.convert(utf8.encode(input)).toString();
}
