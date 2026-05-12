import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/api/level_api.dart';
import 'package:flutter_app/core/level_utils.dart';

Future<HttpServer> _bindServer(
  void Function(HttpRequest req) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  unawaited(server.forEach(handler));
  return server;
}

LevelApi _client(HttpServer server, {String token = 'test-token'}) {
  return LevelApi(
    baseUrl: 'http://${server.address.host}:${server.port}',
    tokenProvider: () => token,
  );
}

void main() {
  test('LevelApi reuses an injected HttpClient (S3)', () {
    final shared = HttpClient();
    addTearDown(() => shared.close(force: true));
    final api = LevelApi(
      baseUrl: 'http://example.test',
      tokenProvider: () => null,
      httpClient: shared,
    );
    expect(api.httpClient, same(shared));
  });

  test('LevelApi defaults to a self-managed HttpClient when none injected (S3)', () {
    final api = LevelApi(
      baseUrl: 'http://example.test',
      tokenProvider: () => null,
    );
    expect(api.httpClient, isNotNull);
    addTearDown(api.dispose);
  });

  test('fetchLevelProgress parses the full server payload', () async {
    final server = await _bindServer((request) async {
      expect(request.method, 'GET');
      expect(request.uri.path, '/v1/users/me/level-progress');
      expect(request.headers.value('authorization'), 'Bearer test-token');
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'data': {
            'user_id': 'u_1',
            'current_level': 'a2',
            'unlocked_levels': ['a0', 'a1', 'a2'],
            'next_level': 'b1',
            'skill_mastery': {
              'noi': {'pct': 78.0, 'threshold_pct': 70.0, 'passes': true},
            },
            'coverage_pct': 82.0,
            'coverage_threshold_pct': 80.0,
            'all_skills_pass': false,
            'promotion_unlocked': false,
          },
          'meta': {},
        }));
      await request.response.close();
    });

    final api = _client(server);
    try {
      final progress = await api.fetchLevelProgress();
      expect(progress.userID, 'u_1');
      expect(progress.currentLevel, CefrLevel.a2);
      expect(progress.nextLevel, CefrLevel.b1);
      expect(progress.skillMastery['noi']?.pct, closeTo(78.0, 1e-6));
    } finally {
      await server.close(force: true);
    }
  });

  test('startPlacement returns {mock_test_id, full_session_id}', () async {
    final server = await _bindServer((request) async {
      expect(request.method, 'POST');
      expect(request.uri.path, '/v1/users/me/placement-test/start');
      expect(request.uri.queryParameters['force'], isNull);
      request.response
        ..statusCode = HttpStatus.created
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'data': {
            'mock_test_id': 'mt_placement',
            'full_session_id': 'fes_1',
          },
          'meta': {},
        }));
      await request.response.close();
    });

    final api = _client(server);
    try {
      final result = await api.startPlacement();
      expect(result.mockTestId, 'mt_placement');
      expect(result.fullSessionId, 'fes_1');
    } finally {
      await server.close(force: true);
    }
  });

  test('startPlacement with force=true sends ?force=true', () async {
    final server = await _bindServer((request) async {
      expect(request.uri.queryParameters['force'], 'true');
      request.response
        ..statusCode = HttpStatus.created
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'data': {'mock_test_id': 'mt_x', 'full_session_id': 'fes_2'},
          'meta': {},
        }));
      await request.response.close();
    });

    final api = _client(server);
    try {
      await api.startPlacement(force: true);
    } finally {
      await server.close(force: true);
    }
  });

  test('createPromotionAttempt cooldown_active throws LevelApiException with retry_after', () async {
    final server = await _bindServer((request) async {
      expect(request.uri.path, '/v1/promotion-attempts');
      request.response
        ..statusCode = HttpStatus.badRequest
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'error': {
            'code': 'cooldown_active',
            'message': 'Wait before attempting this promotion again.',
            'retry_after': '2026-05-08T12:00:00Z',
          },
        }));
      await request.response.close();
    });

    final api = _client(server);
    try {
      await api.createPromotionAttempt('mt_b1');
      fail('expected LevelApiException for cooldown_active');
    } on LevelApiException catch (e) {
      expect(e.code, 'cooldown_active');
      expect(e.statusCode, 400);
      expect(e.retryAfter, isNotNull);
      expect(e.retryAfter!.toUtc().year, 2026);
    } finally {
      await server.close(force: true);
    }
  });

  test('createPromotionAttempt tolerates flat {"error":"<code>"} envelope', () async {
    final server = await _bindServer((request) async {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'error': 'promotion_locked',
          'message': 'Mastery / coverage gates not met.',
        }));
      await request.response.close();
    });

    final api = _client(server);
    try {
      await api.createPromotionAttempt('mt_b1');
      fail('expected LevelApiException for flat envelope');
    } on LevelApiException catch (e) {
      expect(e.code, 'promotion_locked');
      expect(e.statusCode, 400);
      expect(e.message, contains('Mastery'));
    } finally {
      await server.close(force: true);
    }
  });

  test('skipPlacement parks learner at A0 + sets placement_taken_at', () async {
    final server = await _bindServer((request) async {
      expect(request.method, 'POST');
      expect(request.uri.path, '/v1/users/me/placement-test/skip');
      expect(request.headers.value('authorization'), 'Bearer test-token');
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'data': {
            'assigned_level': 'a0',
            'current_level': 'a0',
            'unlocked_levels': ['a0'],
            'placement_taken_at': '2026-05-07T12:00:00Z',
          },
          'meta': {},
        }));
      await request.response.close();
    });

    final api = _client(server);
    try {
      final result = await api.skipPlacement();
      expect(result.assignedLevel, CefrLevel.a0);
      expect(result.currentLevel, CefrLevel.a0);
      expect(result.unlockedLevels, {CefrLevel.a0});
      expect(result.placementTakenAt, isNotNull);
      expect(result.placementTakenAt!.toUtc().year, 2026);
    } finally {
      await server.close(force: true);
    }
  });

  test('skipPlacement surfaces 409 placement_already_taken as exception', () async {
    final server = await _bindServer((request) async {
      request.response
        ..statusCode = HttpStatus.conflict
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'error': {
            'code': 'placement_already_taken',
            'message': 'You have already taken or skipped the placement test.',
          },
        }));
      await request.response.close();
    });

    final api = _client(server);
    try {
      await api.skipPlacement();
      fail('expected LevelApiException for placement_already_taken');
    } on LevelApiException catch (e) {
      expect(e.statusCode, 409);
      expect(e.code, 'placement_already_taken');
    } finally {
      await server.close(force: true);
    }
  });

  test('completePlacement returns assigned level + level state', () async {
    final server = await _bindServer((request) async {
      expect(request.method, 'POST');
      expect(request.uri.path, '/v1/users/me/placement-test/complete');
      final body = jsonDecode(await utf8.decoder.bind(request).join());
      expect(body['full_session_id'], 'fes_done');

      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'data': {
            'assigned_level': 'a2',
            'score_pct': 60.0,
            'current_level': 'a2',
            'unlocked_levels': ['a0', 'a1', 'a2'],
            'placement_taken_at': '2026-05-07T12:00:00Z',
          },
          'meta': {},
        }));
      await request.response.close();
    });

    final api = _client(server);
    try {
      final result = await api.completePlacement('fes_done');
      expect(result.assignedLevel, CefrLevel.a2);
      expect(result.currentLevel, CefrLevel.a2);
      expect(result.unlockedLevels.contains(CefrLevel.a2), isTrue);
      expect(result.placementTakenAt, isNotNull);
    } finally {
      await server.close(force: true);
    }
  });
}
