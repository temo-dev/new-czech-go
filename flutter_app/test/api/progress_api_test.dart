import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_app/core/api/api_client.dart';
import 'package:flutter_app/core/api/progress_api.dart';
import 'package:flutter_app/core/api/progress_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _samplePayload = {
  'overall_progress': 0.62,
  'overall_band': 'learning',
  'skills': [
    {
      'skill_kind': 'noi',
      'mastery': 0.55,
      'band': 'learning',
      'attempts_count': 12,
      'last_attempt_at': '2026-05-05T10:14:22Z',
      'modules': [
        {
          'module_id': 'giao-tiep-co-ban',
          'mastery': 0.60,
          'band': 'learning',
          'attempts_count': 8,
          'last_attempt_at': '2026-05-05T10:14:22Z',
        },
      ],
    },
    {
      'skill_kind': 'viet',
      'mastery': 0.30,
      'band': 'needs_work',
      'attempts_count': 3,
      'modules': [
        {
          'module_id': 'di-urad',
          'mastery': 0.30,
          'band': 'needs_work',
          'attempts_count': 3,
        },
      ],
    },
  ],
  'bands': {'needs_work': 0.40, 'solid': 0.70, 'ready': 0.85},
  'weights': {
    'noi': 25,
    'viet': 20,
    'nghe': 20,
    'doc': 20,
    'ngu_phap': 10,
    'tu_vung': 5,
    'interview': 0,
  },
};

Future<_FakeServer> _spawnServer({
  Map<String, dynamic> payload = _samplePayload,
  void Function(HttpRequest)? onProgress,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  var progressHits = 0;
  final sub = server.listen((request) async {
    if (request.uri.path == '/v1/auth/login') {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'data': {'access_token': 'test-token'},
          'meta': {},
        }));
      await request.response.close();
      return;
    }
    if (request.uri.path == '/v1/users/me/progress') {
      progressHits++;
      onProgress?.call(request);
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'data': payload, 'meta': {}}));
      await request.response.close();
      return;
    }
    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  });
  return _FakeServer(server, sub, () => progressHits);
}

class _FakeServer {
  _FakeServer(this.server, this.sub, this.hits);
  final HttpServer server;
  final StreamSubscription<HttpRequest> sub;
  final int Function() hits;
  String get baseUrl => 'http://127.0.0.1:${server.port}';
  Future<void> close() async {
    await sub.cancel();
    await server.close(force: true);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('UserProgress.fromApiJson parses backend wire shape', () {
    final progress = UserProgress.fromApiJson(_samplePayload);
    expect(progress.overallProgress, closeTo(0.62, 1e-9));
    expect(progress.overallBand, 'learning');
    expect(progress.skills, hasLength(2));
    expect(progress.skills.first.skillKind, 'noi');
    expect(progress.skills.first.mastery, closeTo(0.55, 1e-9));
    expect(progress.skills.first.modules.first.moduleId, 'giao-tiep-co-ban');
    expect(
      progress.skills.first.lastAttemptAt,
      DateTime.utc(2026, 5, 5, 10, 14, 22),
    );
    expect(progress.skills[1].lastAttemptAt, isNull);
    expect(progress.bands.needsWork, closeTo(0.40, 1e-9));
    expect(progress.bands.solid, closeTo(0.70, 1e-9));
    expect(progress.bands.ready, closeTo(0.85, 1e-9));
    expect(progress.weights['noi'], 25);
    expect(progress.weights['interview'], 0);
  });

  test('UserProgress JSON round-trip preserves fields', () {
    final progress = UserProgress.fromApiJson(_samplePayload);
    final encoded = jsonEncode(progress.toJson());
    final decoded = UserProgress.fromApiJson(
      jsonDecode(encoded) as Map<String, dynamic>,
    );
    expect(decoded.overallProgress, progress.overallProgress);
    expect(decoded.skills.length, progress.skills.length);
    expect(
      decoded.skills.first.modules.first.moduleId,
      progress.skills.first.modules.first.moduleId,
    );
    expect(decoded.weights, progress.weights);
  });

  test('UserProgress.empty renders zero state', () {
    final empty = UserProgress.empty();
    expect(empty.overallProgress, 0);
    expect(empty.skills, isEmpty);
    expect(empty.weights, isEmpty);
  });

  test('ProgressApi.fetch hits network and caches result', () async {
    final fake = await _spawnServer();
    addTearDown(fake.close);
    final client = ApiClient(baseUrl: fake.baseUrl);
    await client.login(email: 'a@b.com', password: 'pw');
    final prefs = await SharedPreferences.getInstance();
    final api = ProgressApi(client: client, prefs: prefs);

    final result = await api.fetch();
    expect(result.progress.overallBand, 'learning');
    expect(result.fromCache, isFalse);
    expect(result.isStale, isFalse);
    expect(fake.hits(), 1);
    expect(prefs.getString('v20.progress.cache'), isNotNull);
  });

  test('ProgressApi.fetch always hits network for fresh data', () async {
    final fake = await _spawnServer();
    addTearDown(fake.close);
    final client = ApiClient(baseUrl: fake.baseUrl);
    await client.login(email: 'a@b.com', password: 'pw');
    final prefs = await SharedPreferences.getInstance();
    final api = ProgressApi(client: client, prefs: prefs);

    await api.fetch();
    final second = await api.fetch();
    expect(second.fromCache, isFalse);
    expect(second.isStale, isFalse);
    expect(fake.hits(), 2,
        reason:
            'cache must not mask fresh server data — every fetch hits network');
  });

  test('ProgressApi.fetch ignores SharedPreferences cache when network OK',
      () async {
    final fake = await _spawnServer();
    addTearDown(fake.close);
    final client = ApiClient(baseUrl: fake.baseUrl);
    await client.login(email: 'a@b.com', password: 'pw');
    final prefs = await SharedPreferences.getInstance();

    final warmer = ProgressApi(client: client, prefs: prefs);
    await warmer.fetch();
    expect(fake.hits(), 1);

    // New instance — memory cache empty, prefs populated. Must still
    // refetch because cache is offline-only.
    final fresh = ProgressApi(client: client, prefs: prefs);
    final result = await fresh.fetch();
    expect(result.fromCache, isFalse);
    expect(fake.hits(), 2,
        reason: 'cache is offline fallback only, not a freshness gate');
  });

  test('ProgressApi.fetch falls back to stale cache on network error',
      () async {
    final fake = await _spawnServer();
    final client = ApiClient(baseUrl: fake.baseUrl);
    await client.login(email: 'a@b.com', password: 'pw');
    final prefs = await SharedPreferences.getInstance();

    final clockStart = DateTime.utc(2026, 1, 1, 12);
    var now = clockStart;
    final api = ProgressApi(
      client: client,
      prefs: prefs,
      now: () => now,
    );

    await api.fetch();
    await fake.close();

    now = clockStart.add(const Duration(hours: 48));
    final result = await api.fetch();
    expect(result.fromCache, isTrue);
    expect(result.isStale, isTrue);
    expect(result.progress.overallBand, 'learning');
  });

  test('ProgressApi.fetch rethrows when offline and no cache', () async {
    final fake = await _spawnServer();
    final url = fake.baseUrl;
    await fake.close();
    final client = ApiClient(baseUrl: url);
    final prefs = await SharedPreferences.getInstance();
    final api = ProgressApi(client: client, prefs: prefs);
    await expectLater(api.fetch(), throwsA(isA<Exception>()));
  });
}
