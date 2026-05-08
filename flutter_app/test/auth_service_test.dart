import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:flutter_app/core/api/api_client.dart';
import 'package:flutter_app/core/auth/auth_models.dart';
import 'package:flutter_app/core/auth/auth_service.dart';
import 'package:flutter_app/core/auth/auth_storage.dart';

/// Spawns a test HTTP server on a random loopback port and registers
/// path handlers. Each test gets its own instance.
class _MockServer {
  late final HttpServer _server;
  final Map<String, void Function(HttpRequest, Map<String, dynamic>)> _handlers = {};

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((req) async {
      final bodyText = await utf8.decoder.bind(req).join();
      final body = bodyText.isEmpty ? <String, dynamic>{} : jsonDecode(bodyText) as Map<String, dynamic>;
      final key = '${req.method} ${req.uri.path}';
      final handler = _handlers[key];
      if (handler == null) {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
        return;
      }
      handler(req, body);
    });
  }

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  void on(String method, String path, void Function(HttpRequest, Map<String, dynamic>) handler) {
    _handlers['$method $path'] = handler;
  }

  Future<void> close() => _server.close(force: true);
}

void writeJson(HttpRequest req, int status, Map<String, dynamic> body) {
  req.response
    ..statusCode = status
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body));
  req.response.close();
}

Future<AuthService> _newService(
  String baseUrl, {
  String? seedToken,
  AppleCredentialFn? appleCredential,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(
    seedToken != null ? {'v17.auth.token': seedToken, 'v17.auth.email': 'x', 'v17.auth.display_name': 'X'} : {},
  );
  final storage = await AuthStorage.create();
  final api = ApiClient(baseUrl: baseUrl);
  return AuthService(
    apiClient: api,
    storage: storage,
    appleCredential: appleCredential,
  );
}

AuthorizationCredentialAppleID _fakeCred({
  String? identityToken = 'fake.identity.token',
  String authorizationCode = 'auth_code_001',
  String? givenName = 'Anh',
  String? familyName = 'Nguyễn',
  String? email = 'anh@privaterelay.appleid.com',
  String? userIdentifier = 'apple_sub_001',
}) {
  return AuthorizationCredentialAppleID(
    userIdentifier: userIdentifier,
    givenName: givenName,
    familyName: familyName,
    email: email,
    authorizationCode: authorizationCode,
    identityToken: identityToken,
    state: null,
  );
}

void main() {
  test('signup persists token + adopts user + emits authenticated state', () async {
    final mock = _MockServer();
    await mock.start();
    addTearDown(mock.close);
    mock.on('POST', '/v1/auth/signup', (req, body) {
      expect(body['email'], 'a@x.com');
      writeJson(req, 200, {
        'user': {
          'id': 'u1',
          'email': 'a@x.com',
          'email_verified': false,
          'display_name': 'An',
          'role': 'learner',
          'pro_tier': 'free',
          'grace_attempts_left': 3,
        },
        'session_token': 'tok-abc',
        'expires_at': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      });
    });

    final svc = await _newService(mock.baseUrl);
    int notifyCount = 0;
    svc.addListener(() => notifyCount++);

    final session = await svc.signup(email: 'a@x.com', password: 'Strong1Password!', displayName: 'An');
    expect(session.token, 'tok-abc');
    expect(svc.state, AuthState.authenticated);
    expect(svc.currentUser?.email, 'a@x.com');
    expect(notifyCount, greaterThan(0));
  });

  test('signup with grace=0 unverified -> needsVerify state', () async {
    final mock = _MockServer();
    await mock.start();
    addTearDown(mock.close);
    mock.on('POST', '/v1/auth/signup', (req, _) {
      writeJson(req, 200, {
        'user': {
          'id': 'u', 'email': 'e@x.com', 'email_verified': false,
          'display_name': 'E', 'role': 'learner', 'pro_tier': 'free',
          'grace_attempts_left': 0,
        },
        'session_token': 't',
        'expires_at': DateTime.now().toIso8601String(),
      });
    });

    final svc = await _newService(mock.baseUrl);
    await svc.signup(email: 'e@x.com', password: 'Strong1Password!', displayName: 'E');
    expect(svc.state, AuthState.needsVerify);
  });

  test('login throws AuthException with code on 401', () async {
    final mock = _MockServer();
    await mock.start();
    addTearDown(mock.close);
    mock.on('POST', '/v1/auth/login', (req, _) {
      writeJson(req, 401, {'error': 'invalid_credentials', 'message': 'wrong'});
    });

    final svc = await _newService(mock.baseUrl);
    await expectLater(
      () => svc.login(email: 'e@x.com', password: 'wrong'),
      throwsA(predicate((e) => e is AuthException && e.code == 'invalid_credentials')),
    );
    expect(svc.state, AuthState.loading); // unchanged on failure
  });

  test('logout revokes server token + clears local + transitions to unauth', () async {
    final mock = _MockServer();
    await mock.start();
    addTearDown(mock.close);
    bool logoutCalled = false;
    mock.on('POST', '/v1/auth/logout', (req, _) {
      logoutCalled = true;
      req.response.statusCode = 204;
      req.response.close();
    });
    mock.on('POST', '/v1/auth/login', (req, _) {
      writeJson(req, 200, {
        'user': {
          'id': 'u', 'email': 'e@x.com', 'email_verified': true,
          'display_name': 'E', 'role': 'learner', 'pro_tier': 'free', 'grace_attempts_left': 999,
        },
        'session_token': 'tk',
        'expires_at': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      });
    });

    final svc = await _newService(mock.baseUrl);
    await svc.login(email: 'e@x.com', password: 'pwd');
    await svc.logout();
    expect(logoutCalled, isTrue);
    expect(svc.state, AuthState.unauthenticated);
    expect(svc.currentUser, isNull);
  });

  test('bootstrap with valid stored token authenticates via /me', () async {
    final mock = _MockServer();
    await mock.start();
    addTearDown(mock.close);
    mock.on('GET', '/v1/users/me', (req, _) {
      expect(req.headers.value('authorization'), 'Bearer stored-tok');
      writeJson(req, 200, {
        'user': {
          'id': 'u', 'email': 'r@x.com', 'email_verified': true,
          'display_name': 'R', 'role': 'learner', 'pro_tier': 'free', 'grace_attempts_left': 999,
        },
        'streak': {},
        'usage_today': {},
        'pro': {},
      });
    });

    final svc = await _newService(mock.baseUrl, seedToken: 'stored-tok');
    await svc.bootstrap();
    expect(svc.state, AuthState.authenticated);
    expect(svc.currentUser?.email, 'r@x.com');
  });

  test('bootstrap with revoked token -> unauthenticated + clears storage', () async {
    final mock = _MockServer();
    await mock.start();
    addTearDown(mock.close);
    mock.on('GET', '/v1/users/me', (req, _) {
      writeJson(req, 401, {'error': 'invalid_token', 'message': 'gone'});
    });

    final svc = await _newService(mock.baseUrl, seedToken: 'revoked-tok');
    await svc.bootstrap();
    expect(svc.state, AuthState.unauthenticated);
    expect(svc.currentUser, isNull);
  });

  test('bootstrap with empty storage -> unauthenticated', () async {
    final mock = _MockServer();
    await mock.start();
    addTearDown(mock.close);
    final svc = await _newService(mock.baseUrl);
    await svc.bootstrap();
    expect(svc.state, AuthState.unauthenticated);
  });

  // ── V25 Sign-in with Apple ─────────────────────────────────────────────

  test('signInWithApple happy path: posts identity_token + adopts session',
      () async {
    final mock = _MockServer();
    await mock.start();
    addTearDown(mock.close);

    Map<String, dynamic>? receivedBody;
    mock.on('POST', '/v1/auth/apple', (req, body) {
      receivedBody = body;
      writeJson(req, 200, {
        'user': {
          'id': 'u_apple_1',
          'email': 'anh@privaterelay.appleid.com',
          'email_verified': true,
          'display_name': 'Anh Nguyễn',
          'role': 'learner',
          'pro_tier': 'free',
          'grace_attempts_left': 999,
        },
        'session_token': 'apple-session-tok',
        'expires_at':
            DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      });
    });

    final svc = await _newService(
      mock.baseUrl,
      appleCredential: ({required scopes, required nonce}) async {
        // The handler passes the SHA256-hashed nonce to Apple; the
        // string is opaque to us but must round-trip into the body.
        return _fakeCred();
      },
    );

    final session = await svc.signInWithApple();
    expect(session.token, 'apple-session-tok');
    expect(svc.state, AuthState.authenticated);
    expect(svc.currentUser?.email, 'anh@privaterelay.appleid.com');

    expect(receivedBody, isNotNull);
    expect(receivedBody!['identity_token'], 'fake.identity.token');
    expect(receivedBody!['authorization_code'], 'auth_code_001');
    expect(receivedBody!['nonce'], isA<String>());
    expect((receivedBody!['nonce'] as String).length, 64); // SHA256 hex
    expect(receivedBody!['given_name'], 'Anh');
    expect(receivedBody!['family_name'], 'Nguyễn');
  });

  test('signInWithApple cancel -> AuthException(sign_in_canceled)', () async {
    final mock = _MockServer();
    await mock.start();
    addTearDown(mock.close);

    final svc = await _newService(
      mock.baseUrl,
      appleCredential: ({required scopes, required nonce}) async {
        throw const SignInWithAppleAuthorizationException(
          code: AuthorizationErrorCode.canceled,
          message: 'user dismissed sheet',
        );
      },
    );

    await expectLater(
      svc.signInWithApple(),
      throwsA(isA<AuthException>()
          .having((e) => e.code, 'code', 'sign_in_canceled')),
    );
    // State should remain whatever it was (loading, since no bootstrap).
    expect(svc.state, AuthState.loading);
    expect(svc.currentUser, isNull);
  });

  test('signInWithApple invalid_token -> AuthException surfaces backend error',
      () async {
    final mock = _MockServer();
    await mock.start();
    addTearDown(mock.close);

    mock.on('POST', '/v1/auth/apple', (req, _) {
      writeJson(req, 400, {
        'error': 'invalid_token',
        'message': 'identity_token did not validate',
      });
    });

    final svc = await _newService(
      mock.baseUrl,
      appleCredential: ({required scopes, required nonce}) async => _fakeCred(),
    );

    await expectLater(
      svc.signInWithApple(),
      throwsA(isA<AuthException>()
          .having((e) => e.code, 'code', 'invalid_token')
          .having((e) => e.statusCode, 'statusCode', 400)),
    );
  });

  test('signInWithApple missing identity_token -> AuthException(invalid_credential)',
      () async {
    final mock = _MockServer();
    await mock.start();
    addTearDown(mock.close);

    final svc = await _newService(
      mock.baseUrl,
      appleCredential: ({required scopes, required nonce}) async =>
          _fakeCred(identityToken: null),
    );

    await expectLater(
      svc.signInWithApple(),
      throwsA(isA<AuthException>()
          .having((e) => e.code, 'code', 'invalid_credential')),
    );
  });
}
