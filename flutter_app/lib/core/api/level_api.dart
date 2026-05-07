import 'dart:convert';
import 'dart:io';

import 'package:flutter_app/core/level_utils.dart';
import 'package:flutter_app/models/models.dart';

/// LevelApi is the typed client for the V21 CEFR gating endpoints. Lives
/// alongside ApiClient so the home / onboarding / promotion flows do not
/// have to thread raw `Map<String, dynamic>` payloads through every screen.
///
/// Error envelope tolerance: the backend ships two shapes (per
/// AGENTS.md notes on api_client tolerance):
///   `{"error": {"code": "...", "message": "...", "retry_after": "..."}}`
///   `{"error": "code", "message": "text"}`
/// LevelApiException collapses both into a single typed surface so screens
/// can switch on `code` without re-parsing.
class LevelApi {
  LevelApi({
    required this.baseUrl,
    required String? Function() tokenProvider,
  }) : _tokenProvider = tokenProvider;

  final String baseUrl;
  final String? Function() _tokenProvider;

  /// GET /v1/users/me/level-progress
  Future<LevelProgressResponse> fetchLevelProgress() async {
    final raw = await _request('GET', '/v1/users/me/level-progress');
    final data = (raw['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    return LevelProgressResponse.fromJson(data);
  }

  /// POST /v1/users/me/placement-test/start
  /// Returns the seeded mock test + fresh full_session_id.
  Future<PlacementStartResult> startPlacement({bool force = false}) async {
    final path = force
        ? '/v1/users/me/placement-test/start?force=true'
        : '/v1/users/me/placement-test/start';
    final raw = await _request('POST', path);
    final data = (raw['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    return PlacementStartResult(
      mockTestId: data['mock_test_id'] as String? ?? '',
      fullSessionId: data['full_session_id'] as String? ?? '',
    );
  }

  /// POST /v1/users/me/placement-test/complete
  /// Server reads OverallScore from the session, maps to a level, persists.
  Future<PlacementCompleteResult> completePlacement(String fullSessionId) async {
    final raw = await _request(
      'POST',
      '/v1/users/me/placement-test/complete',
      body: {'full_session_id': fullSessionId},
    );
    final data = (raw['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    final unlocked = ((data['unlocked_levels'] as List?) ?? const [])
        .whereType<String>()
        .map(parseLevel)
        .toSet();
    return PlacementCompleteResult(
      assignedLevel: parseLevel(data['assigned_level'] as String?),
      scorePct: (data['score_pct'] as num?)?.toDouble() ?? 0.0,
      currentLevel: parseLevel(data['current_level'] as String?),
      unlockedLevels: unlocked,
      placementTakenAt:
          DateTime.tryParse(data['placement_taken_at'] as String? ?? ''),
    );
  }

  /// POST /v1/promotion-attempts
  /// Creates a session + ledger row when all gates pass.
  Future<PromotionAttemptResult> createPromotionAttempt(String mockTestId) async {
    final raw = await _request(
      'POST',
      '/v1/promotion-attempts',
      body: {'mock_test_id': mockTestId},
    );
    final data = (raw['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    return PromotionAttemptResult(
      promotionAttemptId: data['promotion_attempt_id'] as String? ?? '',
      fullSessionId: data['full_session_id'] as String? ?? '',
      targetLevel: parseLevel(data['target_level'] as String?),
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = _tokenProvider();
    final client = HttpClient();
    try {
      final uri = Uri.parse('$baseUrl$path');
      final request = await client.openUrl(method, uri);
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json; charset=utf-8',
      );
      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (body != null) {
        request.write(jsonEncode(body));
      }
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      Map<String, dynamic>? payload;
      if (text.isNotEmpty) {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) {
          payload = decoded;
        }
      }
      if (response.statusCode >= 400) {
        throw _parseError(response.statusCode, payload);
      }
      return payload ?? const {};
    } finally {
      client.close(force: true);
    }
  }

  LevelApiException _parseError(int statusCode, Map<String, dynamic>? payload) {
    if (payload == null) {
      return LevelApiException(
        statusCode: statusCode,
        code: 'unknown',
        message: 'Request failed with status $statusCode.',
      );
    }
    final err = payload['error'];
    String code = '';
    String message = '';
    DateTime? retryAfter;

    if (err is Map) {
      code = (err['code'] as String?) ?? '';
      message = (err['message'] as String?) ?? '';
      final retryRaw = err['retry_after'];
      if (retryRaw is String && retryRaw.isNotEmpty) {
        retryAfter = DateTime.tryParse(retryRaw);
      }
    } else if (err is String) {
      // Flat envelope: `{"error": "<code>", "message": "<text>"}`.
      code = err;
      message = (payload['message'] as String?) ?? '';
    }
    if (message.isEmpty) {
      message = 'Request failed with status $statusCode.';
    }
    return LevelApiException(
      statusCode: statusCode,
      code: code.isEmpty ? 'unknown' : code,
      message: message,
      retryAfter: retryAfter,
    );
  }
}

/// Typed exception preserving the backend error code so screens can switch
/// on it (`promotion_locked`, `cooldown_active`, …).
class LevelApiException implements Exception {
  const LevelApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.retryAfter,
  });

  final int statusCode;
  final String code;
  final String message;
  final DateTime? retryAfter;

  @override
  String toString() =>
      'LevelApiException(status=$statusCode, code=$code, message=$message)';
}

class PlacementStartResult {
  const PlacementStartResult({
    required this.mockTestId,
    required this.fullSessionId,
  });
  final String mockTestId;
  final String fullSessionId;
}

class PlacementCompleteResult {
  const PlacementCompleteResult({
    required this.assignedLevel,
    required this.scorePct,
    required this.currentLevel,
    required this.unlockedLevels,
    required this.placementTakenAt,
  });
  final CefrLevel assignedLevel;
  final double scorePct;
  final CefrLevel currentLevel;
  final Set<CefrLevel> unlockedLevels;
  final DateTime? placementTakenAt;
}

class PromotionAttemptResult {
  const PromotionAttemptResult({
    required this.promotionAttemptId,
    required this.fullSessionId,
    required this.targetLevel,
  });
  final String promotionAttemptId;
  final String fullSessionId;
  final CefrLevel targetLevel;
}
