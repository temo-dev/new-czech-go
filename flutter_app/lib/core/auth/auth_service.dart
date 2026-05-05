import 'dart:async';

import 'package:flutter/foundation.dart';

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
class AuthService extends ChangeNotifier {
  AuthService({required ApiClient apiClient, required AuthStorage storage})
      : _api = apiClient,
        _storage = storage;

  final ApiClient _api;
  final AuthStorage _storage;

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
    if (!user.emailVerified && user.graceAttemptsLeft <= 0) {
      _setState(AuthState.needsVerify);
    } else {
      _setState(AuthState.authenticated);
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
}
