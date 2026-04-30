import 'dart:convert';
import 'dart:io';

import '../voice/voice_option.dart';

const _kDefaultBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);

class ApiClient {
  ApiClient({this.baseUrl = _kDefaultBaseUrl});

  final String baseUrl;
  String? _token;

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _request(
      method: 'POST',
      path: '/v1/auth/login',
      body: {'email': email, 'password': password},
    );

    _token = response['data']['access_token'] as String;
    return response['data'] as Map<String, dynamic>;
  }

  Future<List<dynamic>> getModules() async {
    final payload = await _authed('GET', '/v1/modules');
    return payload['data'] as List<dynamic>? ?? const [];
  }

  Future<Map<String, dynamic>> getPlan() async {
    final payload = await _authed('GET', '/v1/plan');
    return payload['data'] as Map<String, dynamic>;
  }

  Future<List<dynamic>> listCourses() async {
    final payload = await _authed('GET', '/v1/courses');
    return payload['data'] as List<dynamic>? ?? const [];
  }

  Future<List<dynamic>> listCourseModules(String courseId) async {
    final payload = await _authed('GET', '/v1/courses/$courseId/modules');
    return payload['data'] as List<dynamic>? ?? const [];
  }

  Future<List<dynamic>> listModuleSkills(String moduleId) async {
    final payload = await _authed('GET', '/v1/modules/$moduleId/skills');
    return payload['data'] as List<dynamic>? ?? const [];
  }

  Future<List<dynamic>> listModuleExercises(
    String moduleId, {
    String? skillKind,
  }) async {
    final path = skillKind != null
        ? '/v1/modules/$moduleId/exercises?skill_kind=$skillKind'
        : '/v1/modules/$moduleId/exercises';
    final payload = await _authed('GET', path);
    return payload['data'] as List<dynamic>? ?? const [];
  }

  Future<List<dynamic>> getExercises(String moduleId) async {
    final payload = await _authed('GET', '/v1/modules/$moduleId/exercises');
    return payload['data'] as List<dynamic>? ?? const [];
  }

  Future<Map<String, dynamic>> getExercise(String exerciseId) async {
    final payload = await _authed('GET', '/v1/exercises/$exerciseId');
    return payload['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createAttempt(
    String exerciseId, {
    String? locale,
  }) async {
    final body = <String, dynamic>{
      'exercise_id': exerciseId,
      'client_platform': 'ios',
      'app_version': '0.1.0',
    };
    if (locale != null && locale.isNotEmpty) {
      body['locale'] = locale;
    }
    final payload = await _authed('POST', '/v1/attempts', body: body);
    return payload['data']['attempt'] as Map<String, dynamic>;
  }

  Future<void> markRecordingStarted(String attemptId) async {
    await _authed(
      'POST',
      '/v1/attempts/$attemptId/recording-started',
      body: {'recording_started_at': DateTime.now().toUtc().toIso8601String()},
    );
  }

  Future<void> submitRecordedAudio(
    String attemptId, {
    required String audioPath,
    required String mimeType,
    required int fileSizeBytes,
    int durationMs = 25000,
    int? sampleRateHz,
    int? channels,
    String? preferredVoiceId,
  }) async {
    final uploadPayload = await _authed(
      'POST',
      '/v1/attempts/$attemptId/upload-url',
      body: {
        'mime_type': mimeType,
        'file_size_bytes': fileSizeBytes,
        'duration_ms': durationMs,
      },
    );
    final upload = uploadPayload['data']['upload'] as Map<String, dynamic>;
    final binaryUploadResult = await _uploadBinary(
      method: upload['method'] as String,
      url: upload['url'] as String,
      headers: (upload['headers'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value as String),
      ),
      audioPath: audioPath,
      fileSizeBytes: fileSizeBytes,
    );
    final fileName = audioPath.split(Platform.pathSeparator).last;
    final uploadCompleteBody = <String, dynamic>{
      'storage_key':
          upload['storage_key'] as String? ??
          'device-local/$attemptId/$fileName',
      'mime_type': mimeType,
      'duration_ms': durationMs,
      'file_size_bytes': fileSizeBytes,
      'stored_file_path': binaryUploadResult['stored_file_path'] as String?,
    };
    if (sampleRateHz != null && sampleRateHz > 0) {
      uploadCompleteBody['sample_rate_hz'] = sampleRateHz;
    }
    if (channels != null && channels > 0) {
      uploadCompleteBody['channels'] = channels;
    }
    if (preferredVoiceId != null && preferredVoiceId.isNotEmpty) {
      uploadCompleteBody['preferred_voice_id'] = preferredVoiceId;
    }

    await _authed(
      'POST',
      '/v1/attempts/$attemptId/upload-complete',
      body: uploadCompleteBody,
    );
  }

  Future<Map<String, dynamic>> getAttempt(String attemptId) async {
    final payload = await _authed('GET', '/v1/attempts/$attemptId');
    return payload['data'] as Map<String, dynamic>;
  }

  /// Submit objective answers for poslech_* or cteni_* exercises (sync scoring).
  Future<Map<String, dynamic>> submitAnswers(
    String attemptId,
    Map<String, String> answers,
  ) async {
    final payload = await _authed(
      'POST',
      '/v1/attempts/$attemptId/submit-answers',
      body: {'answers': answers},
    );
    return payload['data'] as Map<String, dynamic>;
  }

  /// URI for streaming exercise audio (listening exercises).
  /// Use with AudioSource.uri(client.exerciseAudioUri(id), headers: client.authHeaders).
  Uri exerciseAudioUri(String exerciseId) {
    return Uri.parse('$baseUrl/v1/exercises/$exerciseId/audio');
  }

  /// Auth headers for use with just_audio AudioSource.uri.
  Map<String, String> get authHeaders {
    final t = _token;
    if (t == null) return const {};
    return {'Authorization': 'Bearer $t'};
  }

  /// Submit written text for psani_1_formular or psani_2_email.
  /// [answers] = 3 strings for psani_1, [text] = full email for psani_2.
  /// [preferredVoiceId] is optional; empty/null → backend uses default voice.
  Future<void> submitText(
    String attemptId, {
    List<String>? answers,
    String? text,
    String? preferredVoiceId,
  }) async {
    final body = <String, dynamic>{};
    if (answers != null) body['answers'] = answers;
    if (text != null) body['text'] = text;
    if (preferredVoiceId != null && preferredVoiceId.isNotEmpty) {
      body['preferred_voice_id'] = preferredVoiceId;
    }
    await _authed('POST', '/v1/attempts/$attemptId/submit-text', body: body);
  }

  /// Returns configured TTS voice list from GET /v1/voices.
  Future<List<VoiceOption>> getVoices() async {
    final payload = await _authed('GET', '/v1/voices');
    final data = payload['data'] as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(VoiceOption.fromJson)
        .toList();
  }

  /// Returns the audio preview URL for the given voice slug.
  /// Returns null on error (e.g. voice not found or TTS unavailable).
  Future<String?> getVoicePreviewUrl(String voiceId) async {
    try {
      final payload = await _authed('GET', '/v1/voices/$voiceId/preview');
      return (payload['data'] as Map<String, dynamic>?)?['url'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<List<dynamic>> getAttempts() async {
    final payload = await _authed('GET', '/v1/attempts');
    return payload['data'] as List<dynamic>? ?? const [];
  }

  Future<List<dynamic>> listMockTests() async {
    final payload = await _authed('GET', '/v1/mock-tests');
    return payload['data'] as List<dynamic>? ?? const [];
  }

  Future<Map<String, dynamic>> createMockExam({String? mockTestId}) async {
    final body = mockTestId != null && mockTestId.isNotEmpty
        ? {'mock_test_id': mockTestId}
        : <String, dynamic>{};
    final payload = await _authed('POST', '/v1/mock-exams', body: body);
    return payload['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMockExam(String id) async {
    final payload = await _authed('GET', '/v1/mock-exams/$id');
    return payload['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> advanceMockExam(
    String id, {
    required String attemptId,
  }) async {
    final payload = await _authed(
      'POST',
      '/v1/mock-exams/$id/advance',
      body: {'attempt_id': attemptId},
    );
    return payload['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> completeMockExam(String id) async {
    final payload = await _authed('POST', '/v1/mock-exams/$id/complete');
    return payload['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAttemptReview(String attemptId) async {
    final payload = await _authed('GET', '/v1/attempts/$attemptId/review');
    return payload['data'] as Map<String, dynamic>;
  }

  Future<AudioStreamInfo> getAttemptAudioUrl(String attemptId) async {
    final payload = await _authed('GET', '/v1/attempts/$attemptId/audio/url');
    return AudioStreamInfo.fromJson(payload['data'] as Map<String, dynamic>);
  }

  Future<AudioStreamInfo> getAttemptReviewAudioUrl(String attemptId) async {
    final payload =
        await _authed('GET', '/v1/attempts/$attemptId/review/audio/url');
    return AudioStreamInfo.fromJson(payload['data'] as Map<String, dynamic>);
  }

  Uri exerciseAssetUri(String exerciseId, String assetId) {
    return Uri.parse('$baseUrl/v1/exercises/$exerciseId/assets/$assetId/file');
  }

  /// Constructs URL for a vocabulary/grammar media file using its storage key.
  /// Used by QuizcardWidget to load flashcard images.
  Uri mediaUri(String storageKey) {
    return Uri.parse('$baseUrl/v1/media/file').replace(
      queryParameters: {'key': storageKey},
    );
  }

  Future<Map<String, dynamic>> _authed(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (_token == null) {
      throw const HttpException('Not authenticated.');
    }

    return _request(
      method: method,
      path: path,
      body: body,
      headers: {'Authorization': 'Bearer $_token'},
    );
  }

  Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$baseUrl$path');
      final request = await client.openUrl(method, uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      headers?.forEach(request.headers.set);
      if (body != null) {
        request.write(jsonEncode(body));
      }
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      final payload = jsonDecode(text) as Map<String, dynamic>;
      if (response.statusCode >= 400) {
        throw HttpException(
          payload['error']?['message'] as String? ?? 'Request failed.',
        );
      }
      return payload;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _uploadBinary({
    required String method,
    required String url,
    required Map<String, String> headers,
    required String audioPath,
    required int fileSizeBytes,
  }) async {
    final file = File(audioPath);
    final client = HttpClient();
    try {
      final uri = Uri.parse(url);
      final request = await client.openUrl(method, uri);
      headers.forEach(request.headers.set);
      if (_token != null && url.startsWith(baseUrl)) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
      }
      request.headers.contentLength = fileSizeBytes;
      await request.addStream(file.openRead());
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 400) {
        throw HttpException(text.isEmpty ? 'Binary upload failed.' : text);
      }
      if (text.isEmpty) {
        return const {};
      }
      return (jsonDecode(text) as Map<String, dynamic>)['data']
              as Map<String, dynamic>? ??
          const {};
    } finally {
      client.close(force: true);
    }
  }
}

class AudioStreamInfo {
  AudioStreamInfo({
    required this.url,
    required this.mimeType,
    required this.expiresAt,
  });

  factory AudioStreamInfo.fromJson(Map<String, dynamic> json) {
    final expiresRaw = json['expires_at'] as String?;
    return AudioStreamInfo(
      url: Uri.parse(json['url'] as String),
      mimeType: (json['mime_type'] as String?) ?? '',
      expiresAt: expiresRaw == null || expiresRaw.isEmpty
          ? DateTime.now().add(const Duration(minutes: 10))
          : DateTime.parse(expiresRaw),
    );
  }

  final Uri url;
  final String mimeType;
  final DateTime expiresAt;

  bool get isExpiringSoon =>
      expiresAt.difference(DateTime.now()).inSeconds < 60;
}
