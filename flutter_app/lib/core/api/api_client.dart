import 'dart:convert';
import 'dart:io';

class ApiClient {
  ApiClient({this.baseUrl = 'http://localhost:8080'});

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

  Future<List<dynamic>> getAttempts() async {
    final payload = await _authed('GET', '/v1/attempts');
    return payload['data'] as List<dynamic>? ?? const [];
  }

  Future<Map<String, dynamic>> createMockExam() async {
    final payload = await _authed('POST', '/v1/mock-exams');
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

  Map<String, String> authHeaders() {
    if (_token == null) {
      return const {};
    }
    return {'Authorization': 'Bearer $_token'};
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
