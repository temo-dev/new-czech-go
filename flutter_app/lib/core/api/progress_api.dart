import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'progress_models.dart';

/// V20: typed wrapper around `ApiClient.getProgress()` with a 24 h cache.
///
/// In-memory cache serves repeat reads in the same session; SharedPreferences
/// holds the same payload across app restarts so a cold launch can render the
/// last-known progress while the network call is in flight. On network
/// failure we serve whatever cache is available with `isStale=true` so the UI
/// can show an "Đang offline" chip.
class ProgressApi {
  ProgressApi({
    required ApiClient client,
    required SharedPreferences prefs,
    Duration ttl = const Duration(hours: 24),
    DateTime Function() now = _defaultNow,
  })  : _client = client,
        _prefs = prefs,
        _ttl = ttl,
        _now = now;

  static const _cacheKey = 'v20.progress.cache';
  static DateTime _defaultNow() => DateTime.now().toUtc();

  final ApiClient _client;
  final SharedPreferences _prefs;
  final Duration _ttl;
  final DateTime Function() _now;

  _Cached? _memory;

  Future<ProgressFetchResult> fetch({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _readCache();
      if (cached != null && !_isExpired(cached.fetchedAt)) {
        return ProgressFetchResult(
          progress: cached.progress,
          fromCache: true,
          isStale: false,
          fetchedAt: cached.fetchedAt,
        );
      }
    }

    try {
      final raw = await _client.getProgress();
      final progress = UserProgress.fromApiJson(raw);
      final fetchedAt = _now();
      await _writeCache(progress, fetchedAt);
      return ProgressFetchResult(
        progress: progress,
        fromCache: false,
        isStale: false,
        fetchedAt: fetchedAt,
      );
    } catch (err) {
      final cached = _readCache();
      if (cached != null) {
        return ProgressFetchResult(
          progress: cached.progress,
          fromCache: true,
          isStale: true,
          fetchedAt: cached.fetchedAt,
        );
      }
      rethrow;
    }
  }

  /// Drops both in-memory and persistent caches. Useful on logout.
  Future<void> clear() async {
    _memory = null;
    await _prefs.remove(_cacheKey);
  }

  bool _isExpired(DateTime fetchedAt) =>
      _now().difference(fetchedAt) > _ttl;

  _Cached? _readCache() {
    if (_memory != null) return _memory;
    final raw = _prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final envelope = jsonDecode(raw) as Map<String, dynamic>;
      final fetchedAt =
          DateTime.tryParse(envelope['fetched_at'] as String? ?? '')?.toUtc();
      final payload = envelope['payload'] as Map<String, dynamic>?;
      if (fetchedAt == null || payload == null) return null;
      final progress = UserProgress.fromApiJson(payload);
      _memory = _Cached(progress: progress, fetchedAt: fetchedAt);
      return _memory;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(UserProgress progress, DateTime fetchedAt) async {
    _memory = _Cached(progress: progress, fetchedAt: fetchedAt);
    final envelope = {
      'fetched_at': fetchedAt.toUtc().toIso8601String(),
      'payload': progress.toJson(),
    };
    await _prefs.setString(_cacheKey, jsonEncode(envelope));
  }
}

class ProgressFetchResult {
  const ProgressFetchResult({
    required this.progress,
    required this.fromCache,
    required this.isStale,
    required this.fetchedAt,
  });

  final UserProgress progress;
  final bool fromCache;
  final bool isStale;
  final DateTime fetchedAt;
}

class _Cached {
  const _Cached({required this.progress, required this.fetchedAt});
  final UserProgress progress;
  final DateTime fetchedAt;
}
